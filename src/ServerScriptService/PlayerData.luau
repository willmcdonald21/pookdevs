-- Loads and saves each player's progress.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Layout = require(ReplicatedStorage:WaitForChild("Layout"))

local RETRIES = 3
local RETRY_DELAY = 1
local LOCK_EXPIRY = 180
local LOCK_RETRIES = 6
local LOCK_RETRY_DELAY = 5
local MAX_RECEIPTS = 100
-- The most restaurants a save keeps besides the one being managed. The oldest go first.
local MAX_RESTAURANTS = 50

local PlayerData = {}
local sessions = {}
local leavingUsers = {}

local store
do
	local ok, err = pcall(function()
		store = DataStoreService:GetDataStore("PlayerData_v1")
	end)
	if not ok then
		warn("PlayerData: data store unavailable: " .. tostring(err))
	end
end

local function withRetries(action)
	local ok, result
	for attempt = 1, RETRIES do
		ok, result = pcall(action)
		if ok then
			return true, result
		end
		if attempt < RETRIES then
			task.wait(RETRY_DELAY)
		end
	end
	return false, result
end

-- Coins spent on Comfy Shoes by each level, from the Shop's last prices.
local SHOES_REFUNDS = { 0, 40, 340, 1840 }

-- What belongs to one restaurant. Opening a new restaurant starts these over, and the rest
-- of a save (Stars, receipts, boosts, the daily streak, invites) stays with the player.
local RESTAURANT_FIELDS = {
	"Coins", "RecipesUnlocked", "BakeryLevel", "BakeryXp", "Tray", "Owned", "Placed", "Stock",
	"Stations", "LayoutVersion", "LuxuryOven", "Stash", "Expansion", "Paint", "Exterior",
	"BakeryName", "Garden", "Floor", "Goals", "Employees", "LastRecipe", "SparePaint", "Pantry",
}
for _, upgrade in Config.Upgrades do
	table.insert(RESTAURANT_FIELDS, upgrade.Id .. "Level")
end

local function cleanLevel(value, max)
	return math.clamp(math.floor(tonumber(value) or 1), 1, max)
end

local function cleanCount(value)
	return math.max(0, math.floor(tonumber(value) or 0))
end

local function cleanStock(saved, capacity)
	local stock = {}
	if type(saved) == "table" then
		for _, recipeIndex in saved do
			if #stock < capacity and Config.Recipes[recipeIndex] then
				table.insert(stock, recipeIndex)
			end
		end
	end
	return stock
end

-- Goals for a day that has passed are replaced when the player next syncs.
local function cleanGoals(saved)
	local goals = { Day = 0, List = {} }
	if type(saved) ~= "table" or type(saved.List) ~= "table" then
		return goals
	end
	goals.Day = cleanCount(saved.Day)
	for _, goal in saved.List do
		if type(goal) == "table" and Config.GetGoalKind(goal.Kind) then
			local recipe = cleanCount(goal.Recipe)
			if goal.Kind ~= "SellRecipe" or Config.Recipes[recipe] then
				table.insert(goals.List, {
					Kind = goal.Kind,
					Recipe = recipe,
					Target = math.max(1, cleanCount(goal.Target)),
					Progress = cleanCount(goal.Progress),
					Reward = cleanCount(goal.Reward),
					Claimed = goal.Claimed == true,
				})
			end
		end
	end
	return goals
end

-- Paint Ids by target Id. A colour the target can't use is dropped, so it shows its
-- original colour.
local function cleanPaint(saved)
	local paint = {}
	if type(saved) == "table" then
		for _, target in Config.PaintTargets do
			local chosen = Config.GetPaint(saved[target.Id])
			if chosen and Config.CanPaint(target, chosen) then
				paint[target.Id] = chosen.Id
			end
		end
	end
	return paint
end

-- Floor style Ids by tile key, for tiles inside the biggest bakery. The original floor
-- isn't saved, since it's what a tile shows until something is laid on it.
local function cleanFloor(saved)
	local floor = {}
	if type(saved) == "table" then
		for key, id in saved do
			local i, j = Layout.TileOfKey(key)
			local style = Config.GetFloor(id)
			if i and style and style.Id ~= "Original" and Layout.TileRect(i, j, Layout.Largest) then
				floor[Layout.TileKey(i, j)] = style.Id
			end
		end
	end
	return floor
end

-- The outside colours, as paint Ids by Config.Exterior part Id. A part with none is the
-- colour the bakery was built in.
local function cleanExterior(saved)
	local exterior = {}
	if type(saved) == "table" then
		for _, part in Config.Exterior.Parts do
			local chosen = Config.GetPaint(saved[part.Id])
			exterior[part.Id] = chosen and chosen.Id or nil
		end
	end
	return exterior
end

-- Keeps placed items that are owned and inside the walls, and moved stations. Wall items
-- keep their height and must still be on a wall, Stash Shelves must be in The Sweet Stash,
-- and garden plants in the garden. Overlaps were checked when each piece was placed.
local function cleanLayout(data, savedPlaced, savedStock, savedStations)
	local bounds = Layout.Bounds(data.Expansion)
	local placedCounts = {}
	for key, saved in savedPlaced do
		local item = type(key) == "string" and type(saved) == "table" and Config.GetItem(saved.Id)
		local entry = item and Layout.CleanEntry(saved.X, saved.Z, saved.R, item.Wall and saved.Y or nil)
		if entry and (placedCounts[item.Id] or 0) < data.Owned[item.Id] then
			entry.Id = item.Id
			-- A paintable piece keeps the colour it was painted.
			local paint = Config.IsPaintable(item) and Config.GetPaint(saved.Paint)
			entry.Paint = paint and paint.Id or nil
			-- A display case keeps the treat the Stocker fills it with (a Config.Recipes index).
			local treat = saved.Treat
			if item.Slots and not item.Room and type(treat) == "number" and Config.Recipes[treat] and treat % 1 == 0 then
				entry.Treat = treat
			end
			local fits = Layout.Inside(Layout.Rect(Layout.ItemShape(item), entry), Layout.BoundsFor(item, data.Expansion))
			-- A Room is The Sweet Stash or the garden, and data.Stash or data.Garden is true
			-- once it's bought.
			if item.Room and not data[item.Room] then
				fits = false
			end
			if item.Wall then
				fits = entry.Y ~= nil and Layout.OnWall(Layout.ItemThing(key, entry), bounds)
			end
			if fits then
				placedCounts[item.Id] = (placedCounts[item.Id] or 0) + 1
				data.Placed[key] = entry
				if item.Slots then
					data.Stock[key] = cleanStock(savedStock[key], #item.Slots)
				end
			end
		end
	end
	if type(savedStations) == "table" then
		for _, station in Layout.Stations do
			local saved = savedStations[station.Id]
			local entry = type(saved) == "table" and Layout.CleanEntry(saved.X, saved.Z, saved.R)
			if entry then
				data.Stations[station.Id] = entry
			end
		end
	end
end

-- Paint Ids by item Id for paintable pieces that are bought or put away but not placed,
-- newest last. Placing one takes the newest colour. Each list keeps the newest colours,
-- no more than there are such copies.
local function cleanSparePaint(data, saved)
	local spare = {}
	if type(saved) ~= "table" then
		return spare
	end
	local placed = {}
	for _, entry in data.Placed do
		placed[entry.Id] = (placed[entry.Id] or 0) + 1
	end
	for _, item in Config.Items do
		local list = saved[item.Id]
		if Config.IsPaintable(item) and type(list) == "table" then
			local colours = {}
			for _, id in list do
				local paint = Config.GetPaint(id)
				if paint then
					table.insert(colours, paint.Id)
				end
			end
			while #colours > data.Owned[item.Id] - (placed[item.Id] or 0) do
				table.remove(colours, 1)
			end
			if #colours > 0 then
				spare[item.Id] = colours
			end
		end
	end
	return spare
end

-- Saves from before free placement had items on 16 fixed squares and a case on the
-- counter. Those items go back into storage with their treats returned to the tray, and
-- the counter case becomes a free floor case that keeps its treats. New saves get the
-- free case this way too.
local function convertLayout(data, savedStock)
	for key, stock in savedStock do
		if key ~= Config.StarterCase.Key and type(stock) == "table" then
			for _, recipeIndex in cleanStock(stock, math.huge) do
				data.Tray[recipeIndex] += 1
			end
		end
	end
	local starter = Config.StarterCase
	local item = Config.GetItem(starter.Item)
	data.Owned[item.Id] += 1
	data.Placed[starter.Key] = { Id = item.Id, X = starter.X, Z = starter.Z, R = starter.R }
	data.Stock[starter.Key] = cleanStock(savedStock[starter.Key], #item.Slots)
end

-- Employees. Each one does a different job, so a new one gets the first job nobody has.
local function firstFreeJob(employees)
	for _, job in Config.Employees.Jobs do
		local taken = false
		for _, employee in employees do
			taken = taken or employee.Job == job
		end
		if not taken then
			return job
		end
	end
	return ""
end

-- A name with its spaces tidied, cut to length characters (Config.Employees.NameLength
-- unless given), or nil when there's nothing left.
local function cleanName(value, length)
	length = length or Config.Employees.NameLength
	if type(value) ~= "string" or not utf8.len(value) then
		return nil
	end
	local name = value:gsub("%s+", " "):match("^ ?(.-) ?$")
	if utf8.len(name) > length then
		name = name:sub(1, utf8.offset(name, length + 1) - 1)
	end
	return name ~= "" and name or nil
end

-- A new employee in a random outfit, with a name none of the others has. New hires
-- start without a hat.
local function newEmployee(employees, job)
	local taken = {}
	for _, employee in employees do
		taken[employee.Name] = true
	end
	local names = {}
	for _, name in Config.Employees.Names do
		if not taken[name] then
			table.insert(names, name)
		end
	end
	local look = {}
	for _, category in Config.Wardrobe do
		look[category.Id] = category.Id == "Hat" and 0 or category.Items[math.random(#category.Items)].Id
	end
	return { Name = names[math.random(#names)], Job = job or firstFreeJob(employees), Trained = false, Look = look }
end

-- Saves from before employees had a Baker Helper and a Stocker Helper instead, each with
-- a level: 1 not hired, 2 hired, 3 walking faster. They become trained employees at 3.
local function cleanEmployees(saved)
	local employees = {}
	if type(saved.Employees) ~= "table" then
		for _, job in { "Baker", "Stocker" } do
			local level = cleanLevel(saved[job .. "Level"], 3)
			if level >= 2 then
				local employee = newEmployee(employees, job)
				employee.Trained = level == 3
				table.insert(employees, employee)
			end
		end
		return employees
	end
	for _, entry in saved.Employees do
		if type(entry) == "table" and #employees < Config.Employees.Max then
			local employee = newEmployee(employees, "")
			employee.Name = cleanName(entry.Name) or employee.Name
			employee.Trained = entry.Trained == true
			local look = type(entry.Look) == "table" and entry.Look or {}
			for _, category in Config.Wardrobe do
				if Config.WardrobeItem(category.Id, look[category.Id]) then
					employee.Look[category.Id] = look[category.Id]
				end
			end
			local taken = false
			for _, other in employees do
				taken = taken or other.Job == entry.Job
			end
			if table.find(Config.Employees.Jobs, entry.Job) and not taken then
				employee.Job = entry.Job
			end
			table.insert(employees, employee)
		end
	end
	for _, employee in employees do
		if employee.Job == "" then
			employee.Job = firstFreeJob(employees)
		end
	end
	return employees
end

PlayerData.CleanName = cleanName
PlayerData.NewEmployee = newEmployee

-- Tables with holes don't survive saving, so Placed and Stock use string keys.
local function clean(saved)
	saved = type(saved) == "table" and saved or {}
	local data = {
		Coins = cleanCount(saved.Coins),
		Stars = saved.Stars == nil and Config.StartingStars or cleanCount(saved.Stars),
		RecipesUnlocked = cleanLevel(saved.RecipesUnlocked, #Config.Recipes),
		TutorialDone = saved.TutorialDone == true,
		Tray = {},
		Owned = {},
		Placed = {},
		Stock = {},
		-- Only stations the player has moved. The rest stay at their default spots.
		Stations = {},
		LayoutVersion = Layout.Version,
		Receipts = {},
		BoostUntil = cleanCount(saved.BoostUntil),
		-- When the last Bake Sale started, so one can only start every Config.BakeSale.Cooldown.
		BakeSaleAt = cleanCount(saved.BakeSaleAt),
		BuzzUntil = cleanCount(saved.BuzzUntil),
		StarterPackClaimed = saved.StarterPackClaimed == true,
		-- True once the Luxury Oven has been bought.
		LuxuryOven = saved.LuxuryOven == true,
		-- True once The Sweet Stash, the storage room behind the back wall, has been bought.
		Stash = saved.Stash == true,
		-- How many times the bakery has been made bigger. 0 is the starting size.
		Expansion = math.clamp(math.floor(tonumber(saved.Expansion) or 0), 0, #Config.Expansions),
		Paint = cleanPaint(saved.Paint),
		-- The outside colours. See Config.Exterior.
		Exterior = cleanExterior(saved.Exterior),
		-- The bakery's name as its owner typed it, or nil for "<DisplayName>'s Bakery". It's
		-- filtered before anyone sees it on the sign.
		BakeryName = cleanName(saved.BakeryName, Config.Exterior.NameLength),
		-- True once the garden around the bakery has been bought.
		Garden = saved.Garden == true,
		-- Floor style Ids by tile key. See Layout.TileSize.
		Floor = cleanFloor(saved.Floor),
		-- 0 until the first save, so a 0 here means this is the player's first visit.
		LastSeen = cleanCount(saved.LastSeen),
		-- Who invited this player (a userId), or 0. Set on a first visit through an invite.
		ReferredBy = cleanCount(saved.ReferredBy),
		-- How many invited friends this player has been rewarded for.
		ReferralRewards = cleanCount(saved.ReferralRewards),
		DailyDay = cleanCount(saved.DailyDay),
		DailyStreak = math.min(cleanCount(saved.DailyStreak), #Config.DailyRewards),
		Goals = cleanGoals(saved.Goals),
		-- Up to Config.Employees.Max of { Name, Job, Trained, Look }. Name is what the player
		-- typed, and is filtered before anyone sees it.
		Employees = cleanEmployees(saved),
	}
	-- The Bakery Level and the XP earned toward the next one (see Config.BakeryLevel). Saves
	-- from before levels start at the level matching the recipes they had.
	local levels = Config.BakeryLevel
	if saved.BakeryLevel == nil then
		data.BakeryLevel = math.min(data.RecipesUnlocked, levels.Max)
	else
		data.BakeryLevel = cleanLevel(saved.BakeryLevel, levels.Max)
	end
	local needed = levels.Xp[data.BakeryLevel]
	data.BakeryXp = needed and math.min(cleanCount(saved.BakeryXp), needed - 1) or 0
	-- The Baker helper re-bakes this recipe. 0 means nothing has been baked yet.
	data.LastRecipe = math.min(cleanCount(saved.LastRecipe), data.RecipesUnlocked)
	if type(saved.Receipts) == "table" then
		for _, receiptId in saved.Receipts do
			if type(receiptId) == "string" then
				table.insert(data.Receipts, receiptId)
			end
		end
	end
	for _, upgrade in Config.Upgrades do
		local key = upgrade.Id .. "Level"
		data[key] = cleanLevel(saved[key], #upgrade.Levels)
	end
	-- Comfy Shoes left the Shop when running became free for everyone. Anyone who bought
	-- them gets those coins back. ShoesLevel isn't saved any more, so this happens once.
	-- ShoesRefund isn't saved either: it's only there to tell the player.
	local shoesRefund = SHOES_REFUNDS[cleanLevel(saved.ShoesLevel, #SHOES_REFUNDS)]
	if shoesRefund > 0 then
		data.Coins += shoesRefund
		data.ShoesRefund = shoesRefund
	end
	local savedTray = type(saved.Tray) == "table" and saved.Tray or {}
	for index in Config.Recipes do
		data.Tray[index] = cleanCount(savedTray[index])
	end
	local savedOwned = type(saved.Owned) == "table" and saved.Owned or {}
	for _, item in Config.Items do
		data.Owned[item.Id] = cleanCount(savedOwned[item.Id])
	end

	local savedPlaced = type(saved.Placed) == "table" and saved.Placed or {}
	local savedStock = type(saved.Stock) == "table" and saved.Stock or {}
	if saved.LayoutVersion == Layout.Version then
		cleanLayout(data, savedPlaced, savedStock, saved.Stations)
	else
		convertLayout(data, savedStock)
	end
	data.SparePaint = cleanSparePaint(data, saved.SparePaint)

	-- New saves start with a stocked pantry. Counts never go above the pantry's capacity.
	data.Pantry = {}
	local savedPantry = type(saved.Pantry) == "table" and saved.Pantry or nil
	local capacity = Config.GetUpgrade("Pantry").Levels[data.PantryLevel].Capacity
	for _, ingredient in Config.Ingredients do
		local count = savedPantry and cleanCount(savedPantry[ingredient.Id]) or Config.StartingPantry
		data.Pantry[ingredient.Id] = math.min(count, capacity)
	end

	-- Restaurants. RestaurantNumber is the one being managed (1 is the first bakery), and
	-- Restaurants holds the others, each with its Number and its RESTAURANT_FIELDS.
	data.RestaurantNumber = math.max(1, cleanCount(saved.RestaurantNumber))
	data.RestaurantsOpened = math.max(data.RestaurantNumber, cleanCount(saved.RestaurantsOpened))
	data.Restaurants = {}
	local seen = { [data.RestaurantNumber] = true }
	for _, entry in type(saved.Restaurants) == "table" and saved.Restaurants or {} do
		local number = type(entry) == "table" and tonumber(entry.Number)
		if number and number % 1 == 0 and number >= 1 and not seen[number] then
			seen[number] = true
			local restaurant = clean(entry)
			local kept = { Number = number }
			for _, field in RESTAURANT_FIELDS do
				kept[field] = restaurant[field]
			end
			table.insert(data.Restaurants, kept)
			data.RestaurantsOpened = math.max(data.RestaurantsOpened, number)
		end
	end
	table.sort(data.Restaurants, function(a, b)
		return a.Number > b.Number
	end)
	while #data.Restaurants > MAX_RESTAURANTS do
		table.remove(data.Restaurants)
	end
	return data
end

-- Copies the managed restaurant's fields out of a save, tagged with its number.
local function takeRestaurant(data)
	local entry = { Number = data.RestaurantNumber }
	for _, field in RESTAURANT_FIELDS do
		entry[field] = data[field]
	end
	return entry
end

local function putRestaurant(data, entry)
	for _, field in RESTAURANT_FIELDS do
		data[field] = entry[field]
	end
	data.RestaurantNumber = entry.Number
end

-- Opens a new restaurant: the one being managed joins Restaurants, and the save gets a
-- fresh start for every restaurant field. The caller rebuilds the bakery.
function PlayerData.OpenRestaurant(player)
	local data = PlayerData.Get(player)
	table.insert(data.Restaurants, takeRestaurant(data))
	table.sort(data.Restaurants, function(a, b)
		return a.Number > b.Number
	end)
	while #data.Restaurants > MAX_RESTAURANTS do
		table.remove(data.Restaurants)
	end
	data.RestaurantsOpened += 1
	local fresh = clean({})
	fresh.Number = data.RestaurantsOpened
	putRestaurant(data, fresh)
end

-- Makes restaurant number the managed one, and puts the one being managed with the others.
-- Returns false when the save has no such restaurant.
function PlayerData.SwapRestaurant(player, number)
	local data = PlayerData.Get(player)
	for index, entry in data.Restaurants do
		if entry.Number == number then
			data.Restaurants[index] = takeRestaurant(data)
			putRestaurant(data, entry)
			table.sort(data.Restaurants, function(a, b)
				return a.Number > b.Number
			end)
			return true
		end
	end
	return false
end

-- A restaurant nobody is managing can still open on a free plot, just for show. Its stand-in
-- owner (a table, not a Player) gets a copy of its save that is never saved, so nothing it
-- does counts. Showcase(standIn, entry) sets that up, and Forget(standIn) ends it.
function PlayerData.Showcase(standIn, entry)
	local data = clean(HttpService:JSONDecode(HttpService:JSONEncode(entry)))
	data.RestaurantNumber = entry.Number
	sessions[standIn] = { data = data, canSave = false, released = true }
	return data
end

function PlayerData.Forget(standIn)
	sessions[standIn] = nil
end

local function newLock()
	return { JobId = game.JobId, Time = os.time() }
end

local function lockedElsewhere(saved)
	return type(saved) == "table" and type(saved.Lock) == "table" and saved.Lock.JobId ~= game.JobId
end

-- Claims the save for this server, so another server can't overwrite newer progress.
-- Returns whether the claim succeeded, the saved data, and whether the service failed.
local function claimSave(player)
	local key = "player_" .. player.UserId
	local claimed = false
	local saved = nil
	local ok, err = withRetries(function()
		store:UpdateAsync(key, function(old)
			claimed = false
			if lockedElsewhere(old) and os.time() - (tonumber(old.Lock.Time) or 0) < LOCK_EXPIRY then
				return nil
			end
			saved = type(old) == "table" and old or {}
			saved.Lock = newLock()
			claimed = true
			return saved, { player.UserId }
		end)
	end)
	if not ok then
		warn(("PlayerData: could not load %s: %s"):format(player.Name, tostring(err)))
		return false, nil, true
	end
	return claimed, saved, false
end

-- A failed load must never save, or it would replace real progress with a fresh start.
function PlayerData.Load(player)
	while leavingUsers[player.UserId] do
		task.wait(0.1)
	end
	local ok, saved = false, nil
	if store then
		for attempt = 1, LOCK_RETRIES do
			local failed
			ok, saved, failed = claimSave(player)
			if ok or failed or attempt == LOCK_RETRIES or not player.Parent then
				break
			end
			task.wait(LOCK_RETRY_DELAY)
		end
	end
	sessions[player] = { data = clean(ok and saved or nil), canSave = ok, released = false }
	return sessions[player].data, ok
end

function PlayerData.Get(player)
	local session = sessions[player]
	return session and session.data
end

function PlayerData.CanSave(player)
	local session = sessions[player]
	return session ~= nil and session.canSave
end

-- Remembers a purchase so it can never be granted twice, keeping the newest ones.
function PlayerData.AddReceipt(player, receiptId)
	local receipts = sessions[player].data.Receipts
	table.insert(receipts, receiptId)
	while #receipts > MAX_RECEIPTS do
		table.remove(receipts, 1)
	end
end

-- Saves progress. Passing release gives up this server's claim, for when the player leaves.
function PlayerData.Save(player, release)
	local session = sessions[player]
	if not session or not session.canSave then
		return false
	end
	if release then
		session.released = true
	elseif session.released then
		return false
	end
	local key = "player_" .. player.UserId
	local saved = false
	local lostClaim = false
	local ok, err = withRetries(function()
		store:UpdateAsync(key, function(old)
			saved = false
			lostClaim = lockedElsewhere(old)
			if lostClaim or (session.released and not release) then
				return nil
			end
			local value = table.clone(session.data)
			value.Lock = not release and newLock() or nil
			value.LastSeen = os.time()
			saved = true
			return value, { player.UserId }
		end)
	end)
	if not ok then
		warn(("PlayerData: could not save %s: %s"):format(player.Name, tostring(err)))
		return false
	end
	if lostClaim then
		session.canSave = false
		warn(("PlayerData: %s is now saving from another server"):format(player.Name))
	end
	return saved
end

local function saveAndForget(player)
	leavingUsers[player.UserId] = true
	PlayerData.Save(player, true)
	sessions[player] = nil
	leavingUsers[player.UserId] = nil
end

Players.PlayerRemoving:Connect(saveAndForget)

game:BindToClose(function()
	local pending = 0
	for player in pairs(sessions) do
		pending += 1
		task.spawn(function()
			PlayerData.Save(player, true)
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait()
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for player in pairs(sessions) do
			task.spawn(PlayerData.Save, player)
		end
	end
end)

return PlayerData
