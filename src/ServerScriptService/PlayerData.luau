-- Loads and saves each player's progress.
local DataStoreService = game:GetService("DataStoreService")
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

-- Keeps placed items that are owned and inside the walls, and moved stations. Wall items
-- keep their height and must still be on a wall. Overlaps were checked when each piece
-- was placed.
local function cleanLayout(data, savedPlaced, savedStock, savedStations)
	local bounds = Layout.Bounds(data.Expansion)
	local placedCounts = {}
	for key, saved in savedPlaced do
		local item = type(key) == "string" and type(saved) == "table" and Config.GetItem(saved.Id)
		local entry = item and Layout.CleanEntry(saved.X, saved.Z, saved.R, item.Wall and saved.Y or nil)
		if entry and (placedCounts[item.Id] or 0) < data.Owned[item.Id] then
			entry.Id = item.Id
			-- A display case keeps the colour it was painted.
			local paint = item.Slots and Config.GetPaint(saved.Paint)
			entry.Paint = paint and paint.Id or nil
			local fits = Layout.Inside(Layout.Rect(Layout.ItemShape(item), entry), bounds)
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
		-- How many times the bakery has been made bigger. 0 is the starting size.
		Expansion = math.clamp(math.floor(tonumber(saved.Expansion) or 0), 0, #Config.Expansions),
		Paint = cleanPaint(saved.Paint),
		LastSeen = cleanCount(saved.LastSeen),
		DailyDay = cleanCount(saved.DailyDay),
		DailyStreak = math.min(cleanCount(saved.DailyStreak), #Config.DailyRewards),
		Goals = cleanGoals(saved.Goals),
	}
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

	-- New saves start with a stocked pantry. Counts never go above the pantry's capacity.
	data.Pantry = {}
	local savedPantry = type(saved.Pantry) == "table" and saved.Pantry or nil
	local capacity = Config.GetUpgrade("Pantry").Levels[data.PantryLevel].Capacity
	for _, ingredient in Config.Ingredients do
		local count = savedPantry and cleanCount(savedPantry[ingredient.Id]) or Config.StartingPantry
		data.Pantry[ingredient.Id] = math.min(count, capacity)
	end
	return data
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
