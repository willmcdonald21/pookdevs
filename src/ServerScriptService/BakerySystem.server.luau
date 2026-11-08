-- Runs the bakeries: baking, display cases, shopping customers, deliveries,
-- the shop, and placed items. All game state lives on the server.
-- Prompts are always Enabled here; the client shows them based on each prompt's
-- Active attribute and the plot's OwnerId. Prompts with the CoBake attribute also show
-- for the bakery's co-bakers.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local ItemBuilder = require(ReplicatedStorage:WaitForChild("ItemBuilder"))
local Layout = require(ReplicatedStorage:WaitForChild("Layout"))
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))
local PurchaseHandler = require(ServerScriptService:WaitForChild("PurchaseHandler"))

local REACH_BUFFER = 8
local PANEL_REACH = 25
local CRATE_REACH = 16
local GROCERY_REACH = 20
local FIRST_CRATE_DELAY = 15
local SLOT_ITEM_SCALE = 0.5
local TRAY_ITEM_SCALE = 0.6
-- How high a person's root part sits above the floor, as tools/build_townsfolk.luau measures it.
local CUSTOMER_HEIGHT = 3
-- The Roblox avatars townsfolk and helpers are cloned from, made by tools/build_townsfolk.luau.
local LOOKS = ServerStorage:WaitForChild("TownsfolkLooks")

local function remote(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = ReplicatedStorage
	return event
end

local notifyEvent = remote("Notify")
local stateEvent = remote("State")
local openPanelEvent = remote("OpenPanel")
local purchaseEvent = remote("Purchase")
local bakeEvent = remote("Bake")
local placeEvent = remote("Place")
local shipEvent = remote("Ship")
local newOrderEvent = remote("NewOrder")
local selectSlotEvent = remote("SelectSlot")
local popupEvent = remote("Popup")
local claimDailyEvent = remote("ClaimDaily")
local claimGoalEvent = remote("ClaimGoal")
local unpackCrateEvent = remote("UnpackCrate")
local buyGroceriesEvent = remote("BuyGroceries")
local startBakeSaleEvent = remote("StartBakeSale")
local takeFlyersEvent = remote("TakeFlyers")
local setRunningEvent = remote("SetRunning")

local plots = {}
local playerPlots = {}
local carriedTrays = {}
local hotbars = {}
-- Players who've switched to running. It lasts the visit, through respawns.
local running = {}
local refreshEmployees
-- Bake Together. coBakers maps each co-baker to the bakery they're working in, and
-- lastAction to when they last did something there. friendPairs[a][b] is true when a and
-- b are Roblox friends in this server.
local coBakers = {}
local lastAction = {}
local friendPairs = {}

local function notify(player, text, sound)
	notifyEvent:FireClient(player, text, sound)
end

local function setActive(prompt, active)
	prompt:SetAttribute("Active", active)
end

-- The bakery a player is working in: the one they're co-baking in, or their own.
local function workPlot(player)
	return coBakers[player] or playerPlots[player]
end

local function coBakersOf(plot)
	local list = {}
	for coBaker, coPlot in coBakers do
		if coPlot == plot then
			table.insert(list, coBaker)
		end
	end
	return list
end

-- Co-bakers who've done something in the bakery recently. Only they share in its sales.
local function activeCoBakers(plot)
	local list = {}
	for _, coBaker in coBakersOf(plot) do
		if os.clock() - (lastAction[coBaker] or -math.huge) <= Config.CoBake.ActiveSeconds then
			table.insert(list, coBaker)
		end
	end
	return list
end

local function markActive(player)
	lastAction[player] = os.clock()
end

local function friendBoost(player)
	local count = 0
	for _ in friendPairs[player] or {} do
		count += 1
	end
	return math.min(Config.FriendBoost.Max, count * Config.FriendBoost.PerFriend)
end

local function upgradeLevel(data, id)
	return Config.GetUpgrade(id).Levels[data[id .. "Level"]]
end

local function salePrice(data, recipe)
	return math.floor(recipe.Price * (1 + upgradeLevel(data, "Ingredients").PriceBonus))
end

-- 2x Coins and the timed boost each double coins earned from customers and deliveries,
-- and the Friend Boost adds a little for each friend in town.
local function coinMultiplier(player, data)
	local multiplier = 1
	if PurchaseHandler.OwnsPass(player, "DoubleCoins") then
		multiplier *= 2
	end
	if data.BoostUntil > os.time() then
		multiplier *= 2
	end
	return multiplier * (1 + friendBoost(player))
end

local function bakeSaleOn(data)
	return os.time() < data.BakeSaleAt + Config.BakeSale.Duration
end

-- How fast customers come: 1 normally, plus each boost's Rush while it's on.
local function rushPower(data)
	local now = os.time()
	local power = 1
	if bakeSaleOn(data) then
		power += Config.BakeSale.Rush
	end
	if data.BuzzUntil > now then
		power += Config.Buzz.Rush
	end
	if data.BoostUntil > now then
		power += Config.BoostRush
	end
	return power
end

-- Coins are always whole. The tiny extra stops rounding error from losing a coin, as in
-- 25 * 1.2 coming out a hair under 30.
local function earn(player, data, amount)
	local coins = math.floor(amount * coinMultiplier(player, data) + 1e-6)
	data.Coins += coins
	return coins
end

-- Days start at midnight US Eastern time, so everyone's new day starts at the same moment.
-- Servers have no time zone data, so daylight time is worked out here: EDT (UTC-4) runs from
-- 2am on the 2nd Sunday of March (07:00 UTC) to 2am on the 1st Sunday of November (06:00 UTC),
-- and EST (UTC-5) the rest of the year.
local function today()
	local now = os.time()
	local year = DateTime.fromUnixTimestamp(now):ToUniversalTime().Year
	local function nthSunday(month, n, hourUtc)
		local first = DateTime.fromUniversalTime(year, month, 1).UnixTimestamp
		-- 1970-01-01 was a Thursday, so (day + 4) % 7 is 0 on a Sunday.
		local untilSunday = (7 - (first // 86400 + 4) % 7) % 7
		return first + (untilSunday + 7 * (n - 1)) * 86400 + hourUtc * 3600
	end
	local summer = now >= nthSunday(3, 2, 7) and now < nthSunday(11, 1, 6)
	return (now - (summer and 4 or 5) * 3600) // 86400
end

-- New goals each day. Rewards scale with the best recipe unlocked.
local function ensureGoals(data)
	if data.Goals.Day == today() then
		return
	end
	local kinds = table.clone(Config.Goals.Kinds)
	local reward = Config.Recipes[data.RecipesUnlocked].Price * Config.Goals.CoinsPerPrice
	local list = {}
	for _ = 1, math.min(Config.Goals.DailyCount, #kinds) do
		local kind = table.remove(kinds, math.random(#kinds))
		table.insert(list, {
			Kind = kind.Id,
			Recipe = kind.Id == "SellRecipe" and math.random(data.RecipesUnlocked) or 0,
			Target = math.random(kind.Min, kind.Max),
			Progress = 0,
			Reward = reward,
			Claimed = false,
		})
	end
	data.Goals = { Day = today(), List = list }
end

-- A sale counts toward both "sell treats" and a matching "sell this recipe" goal.
local function addGoalProgress(data, kind, recipeIndex)
	ensureGoals(data)
	for _, goal in data.Goals.List do
		local matches = goal.Kind == kind
			or (kind == "Sell" and goal.Kind == "SellRecipe" and goal.Recipe == recipeIndex)
		if matches then
			goal.Progress = math.min(goal.Target, goal.Progress + 1)
		end
	end
end

local function bakeTime(data, recipe)
	return upgradeLevel(data, "Oven").BakeTime * recipe.BakeScale
end

local function trayCapacity(data)
	return upgradeLevel(data, "Tray").Capacity
end

local function pantryCapacity(data)
	return upgradeLevel(data, "Pantry").Capacity
end

-- Returns text like "1 Butter, 2 Eggs" for what's missing, or nil when there's enough.
local function missingIngredients(data, recipe)
	local missing = {}
	for _, ingredient in Config.Ingredients do
		local need = recipe.Ingredients[ingredient.Id]
		if need and data.Pantry[ingredient.Id] < need then
			table.insert(missing, ("%d %s"):format(need - data.Pantry[ingredient.Id], ingredient.Name))
		end
	end
	return #missing > 0 and table.concat(missing, ", ") or nil
end

local function canBakeAnything(data)
	for index = 1, data.RecipesUnlocked do
		if not missingIngredients(data, Config.Recipes[index]) then
			return true
		end
	end
	return false
end

local function trayTotal(data)
	local total = 0
	for _, count in data.Tray do
		total += count
	end
	return total
end

local function placedCount(data, itemId)
	local count = 0
	for _, entry in data.Placed do
		if entry.Id == itemId then
			count += 1
		end
	end
	return count
end

local function placedCaseCount(data)
	local count = 0
	for _, entry in data.Placed do
		if Config.GetItem(entry.Id).Slots then
			count += 1
		end
	end
	return count
end

-- Extra copies of a game pass item, bought with coins, add no Charm.
local function totalCharm(data)
	local charm = 0
	local counted = {}
	for _, entry in data.Placed do
		local item = Config.GetItem(entry.Id)
		if not (item.ExtraCoins and counted[item.Id]) then
			charm += item.Charm
			counted[item.Id] = true
		end
	end
	return charm
end

local function canUnlockRecipe(data)
	local nextRecipe = Config.Recipes[data.RecipesUnlocked + 1]
	return nextRecipe ~= nil and data.Coins >= nextRecipe.UnlockCost
end

local function canAffordUpgrade(data)
	for _, upgrade in Config.Upgrades do
		local nextLevel = upgrade.Levels[data[upgrade.Id .. "Level"] + 1]
		if nextLevel and data.Coins >= nextLevel.Cost then
			return true
		end
	end
	return false
end

local function hasOrderItems(data, order)
	for index, count in order.Items do
		if data.Tray[index] < count then
			return false
		end
	end
	return true
end

local function findCaseWithRoom(plot, data)
	for key, case in plot.cases do
		if #data.Stock[key] < #case.slots then
			return key, case
		end
	end
	return nil
end

-- A bought station, like the Luxury Oven, is only in the bakery once its owner has
-- bought it.
local function hasStation(data, id)
	return not Layout.GetStation(id).Bought or (data ~= nil and data[id] == true)
end

local function ownedOvens(plot, data)
	local ovens = {}
	for _, oven in plot.ovens do
		if hasStation(data, oven.model.Name) then
			table.insert(ovens, oven)
		end
	end
	return ovens
end

-- Co-bakers are guided around the bakery they're working in, using its owner's ovens,
-- cases and pantry, and their own tray.
local function updateGuide(player)
	local plot = workPlot(player)
	local data = PlayerData.Get(player)
	local host = plot and plot.owner and PlayerData.Get(plot.owner)
	if not host then
		plot = nil
	end
	local hint, target = "", nil
	local ready, idle, baking
	if plot and data then
		for _, oven in ownedOvens(plot, host) do
			if oven.state == "ready" then
				ready = ready or oven
			elseif oven.state == "idle" then
				idle = idle or oven
			else
				baking = baking or oven
			end
		end
	end
	if not plot or not data then
		hint = "All bakeries are taken right now. Have a look around!"
	elseif plot.line[1] and plot.line[1].atSpot and not plot.cashierReady then
		-- Customers can't pay until someone checks them out.
		hint = "A customer is waiting! Tap E at the register"
		target = "Checkout"
	elseif ready then
		hint = ("Your %s batch is ready! Collect it from the %s"):format(ready.recipe.Name:lower(), ready.name:lower())
		target = ready.model.Name
	elseif trayTotal(data) > 0 then
		local _, case = findCaseWithRoom(plot, host)
		if case then
			hint = "Put your treats in a display case"
			target = case.model.Name
		else
			hint = "Your cases are full! Pack a delivery or wait for customers"
			target = "PackingStation"
		end
	elseif not idle then
		hint = ("Baking %s..."):format(baking.recipe.Name:lower())
	elseif not canBakeAnything(host) then
		hint = "Out of ingredients! Unpack your delivery crate or visit the grocery store"
		target = "IngredientCrate"
	else
		hint = ("Choose a treat to bake at the %s"):format(idle.name:lower())
		target = idle.model.Name
	end
	player:SetAttribute("Hint", hint)
	player:SetAttribute("Target", target)
end

-- The tray shows the selected hotbar treat, or the first one if none is selected.
local function trayTreat(player)
	local bar = hotbars[player]
	if not bar then
		return nil
	end
	local selected = bar.Selected and bar.Slots[bar.Selected]
	if selected and selected ~= 0 then
		return selected
	end
	for _, recipeIndex in bar.Slots do
		if recipeIndex ~= 0 then
			return recipeIndex
		end
	end
	return nil
end

local function updateCarriedTray(player, data)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local tray = carriedTrays[player]
	local total = trayTotal(data)
	if total == 0 or not root then
		if tray then
			tray:Destroy()
			carriedTrays[player] = nil
		end
		return
	end
	if not (tray and tray.Parent) then
		tray = Instance.new("Part")
		tray.Name = "CarriedTray"
		tray.Size = Vector3.new(2.6, 0.25, 1.6)
		tray.Color = Color3.fromRGB(240, 150, 175)
		tray.CanCollide = false
		tray.CanQuery = false
		tray.CanTouch = false
		tray.Massless = true
		tray.CFrame = root.CFrame * CFrame.new(0, 0.2, -1.6)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = tray
		weld.Parent = tray
		tray.Parent = character
		carriedTrays[player] = tray
	end

	local showing = trayTreat(player)
	if tray:GetAttribute("Showing") == showing then
		return
	end
	tray:SetAttribute("Showing", showing)
	local old = tray:FindFirstChild("Treat")
	if old then
		old:Destroy()
	end
	if showing then
		local treat = ItemBuilder.Build(
			Config.Recipes[showing],
			TRAY_ITEM_SCALE,
			tray.CFrame * CFrame.new(0, tray.Size.Y / 2 + 0.1, 0)
		)
		treat.Name = "Treat"
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = tray
		weld.Part1 = treat.PrimaryPart
		weld.Parent = treat.PrimaryPart
		treat.Parent = tray
	end
end

-- Pantry shelf: each jar fills up to show how much of that ingredient the owner has.
-- Passing no data empties the shelf, for when nobody owns the bakery.
local function updatePantryShelf(plot, data)
	local capacity = data and pantryCapacity(data) or 1
	for _, ingredient in Config.Ingredients do
		local slot = plot.pantrySlots:FindFirstChild(ingredient.Id)
		local count = data and data.Pantry[ingredient.Id] or 0
		local shown = data and ("%d/%d"):format(count, capacity) or ""
		if slot and slot:GetAttribute("Shown") ~= shown then
			slot:SetAttribute("Shown", shown)
			local jar = slot.Jar
			local fill = slot.Fill
			local height = math.max((jar.Size.X - 0.1) * math.min(count / capacity, 1), 0.05)
			fill.Transparency = count > 0 and 0 or 1
			fill.Size = Vector3.new(height, fill.Size.Y, fill.Size.Z)
			-- The jar is a cylinder stood on end, so its X axis points up.
			fill.CFrame = jar.CFrame * CFrame.new(-jar.Size.X / 2 + 0.05 + height / 2, 0, 0)
			slot.LabelAnchor.Label.Text.Text = data and ("%s %s"):format(ingredient.Name, shown) or ingredient.Name
		end
	end
end

-- Each hotbar box holds one kind of treat. A kind keeps its box until it runs out.
local function refreshHotbar(player, data)
	local bar = hotbars[player]
	if not bar then
		bar = { Slots = table.create(Config.HotbarSize, 0), Selected = nil }
		hotbars[player] = bar
	end
	for slot, recipeIndex in bar.Slots do
		if recipeIndex ~= 0 and data.Tray[recipeIndex] == 0 then
			bar.Slots[slot] = 0
			if bar.Selected == slot then
				bar.Selected = nil
			end
		end
	end
	for recipeIndex, count in data.Tray do
		if count > 0 and not table.find(bar.Slots, recipeIndex) then
			local free = table.find(bar.Slots, 0)
			if free then
				bar.Slots[free] = recipeIndex
			end
		end
	end
	return bar
end

-- Stations: the oven, cookbook counter, pantry shelf, checkout counter and packing
-- table. Each one remembers where its parts sit around its centre, so it can move to
-- any grid entry and back to its default spot.
local function floorPoint(plot, point, height)
	return (plot.floorTop * CFrame.new(point.X, height, point.Z)).Position
end

local function setUpStation(plot, station)
	local root = plot.model[station.Path]
	local parts = root:GetDescendants()
	table.insert(parts, root)
	local minX, maxX, minZ, maxZ, top = math.huge, -math.huge, math.huge, -math.huge, 0
	for _, part in parts do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local half = part.Size / 2
			for _, corner in { Vector3.new(1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1) } do
				for _, y in { -1, 1 } do
					local point = plot.floorTop:PointToObjectSpace(part.CFrame * (half * (corner + Vector3.new(0, y, 0))))
					minX, maxX = math.min(minX, point.X), math.max(maxX, point.X)
					minZ, maxZ = math.min(minZ, point.Z), math.max(maxZ, point.Z)
					top = math.max(top, point.Y)
				end
			end
		end
	end
	root:SetAttribute("FootW", Layout.Cells(maxX - minX))
	root:SetAttribute("FootD", Layout.Cells(maxZ - minZ))
	root:SetAttribute("FootH", top)
	local shape = Layout.StationShape(station, root)
	local center = Vector3.new((minX + maxX) / 2, 0, (minZ + maxZ) / 2)
	local origin = plot.floorTop * CFrame.new(center)
	local offsets = {}
	for _, part in parts do
		if part:IsA("BasePart") then
			offsets[part] = origin:ToObjectSpace(part.CFrame)
		end
	end
	plot.stations[station.Id] = {
		root = root,
		offsets = offsets,
		shape = shape,
		default = Layout.EntryAt(shape, center, 0),
	}
	plot.stationShapes[station.Id] = shape
end

-- The owner's floor inside the walls, or the starting size when nobody owns the bakery.
local function plotBounds(data)
	return Layout.Bounds(data and data.Expansion or 0)
end

local function stationEntry(plot, data, id)
	return data and data.Stations[id] or plot.stations[id].default
end

local function stationThing(plot, data, id)
	return Layout.StationThing(Layout.GetStation(id), plot.stations[id].shape, stationEntry(plot, data, id))
end

local function moveStation(plot, id, entry)
	local station = plot.stations[id]
	local origin = Layout.CFrame(plot.floorTop, station.shape, entry)
	for part, offset in station.offsets do
		part.CFrame = origin * offset
	end
end

-- Puts every station where the owner left it, or at its default spot when data is nil.
-- A saved spot that no longer fits inside the walls goes back to the default.
local function placeStations(plot, data)
	for id, station in plot.stations do
		if data and data.Stations[id] then
			local rect = Layout.Rect(station.shape, data.Stations[id])
			if not Layout.Inside(rect, plotBounds(data)) then
				data.Stations[id] = nil
			end
		end
		moveStation(plot, id, stationEntry(plot, data, id))
	end
end

-- Bought stations that the owner hasn't bought wait here, out of sight and out of reach.
local hiddenStations = Instance.new("Folder")
hiddenStations.Name = "HiddenStations"
hiddenStations.Parent = ServerStorage

local function showBoughtStations(plot, data)
	for _, station in Layout.Stations do
		if station.Bought then
			plot.stations[station.Id].root.Parent = hasStation(data, station.Id) and plot.model or hiddenStations
		end
	end
end

-- How each wall part changes as the bakery grows, per stud the side walls move out and
-- per stud the back wall moves back. Side and Back are how far the part slides, and
-- GrowX and GrowZ are how much longer it gets, all in floor space.
local WALL_GROWTH = {
	BackWall = { Side = 0, Back = -1, GrowX = 2, GrowZ = 0 },
	TrimBack = { Side = 0, Back = -1, GrowX = 2, GrowZ = 0 },
	LeftWall = { Side = -1, Back = -0.5, GrowX = 0, GrowZ = 1 },
	TrimLeft = { Side = -1, Back = -0.5, GrowX = 0, GrowZ = 1 },
	RightWall = { Side = 1, Back = -0.5, GrowX = 0, GrowZ = 1 },
	TrimRight = { Side = 1, Back = -0.5, GrowX = 0, GrowZ = 1 },
	FrontLeft = { Side = -0.5, Back = 0, GrowX = 1, GrowZ = 0 },
	TrimFrontLeft = { Side = -0.5, Back = 0, GrowX = 1, GrowZ = 0 },
	FrontRight = { Side = 0.5, Back = 0, GrowX = 1, GrowZ = 0 },
	TrimFrontRight = { Side = 0.5, Back = 0, GrowX = 1, GrowZ = 0 },
}

-- Moves the walls out to an expansion level and lays floor under the new space. The
-- original floor never moves, since floor space is measured from it. The extra floor sits
-- just below it, so the two never flicker where they overlap.
local function applyExpansion(plot, level)
	local bounds = Layout.Bounds(level)
	local side = Layout.Start.MinX - bounds.MinX
	local back = Layout.Start.MinZ - bounds.MinZ
	for part, start in plot.wallStarts do
		local rule = WALL_GROWTH[part.Name]
		part.Size = start.Size + Vector3.new(rule.GrowX * side, 0, rule.GrowZ * back)
		part.CFrame = start.CFrame + plot.floorTop:VectorToWorldSpace(Vector3.new(rule.Side * side, 0, rule.Back * back))
	end
	local floor, extension = plot.model.Floor, plot.floorExtension
	if level == 0 then
		extension.Parent = nil
		return
	end
	extension.Size = floor.Size + Vector3.new(2 * side, 0, back)
	extension.CFrame = floor.CFrame * CFrame.new(0, -0.02, -back / 2)
	extension.Parent = plot.model
end

-- Colours the walls and oven with the owner's paint, or their starting colours when
-- data is nil. Display cases are painted when they're built.
local function applyPaint(plot, data)
	for _, target in Config.PaintTargets do
		local paint = data and Config.GetPaint(data.Paint[target.Id])
		for part, original in plot.paintParts[target.Id] do
			part.Color = paint and paint.Color or original
		end
	end
end

local function stationEntries(plot, data)
	local entries = {}
	for id in plot.stations do
		if hasStation(data, id) then
			entries[id] = stationEntry(plot, data, id)
		end
	end
	return entries
end

local function layoutThings(plot, data)
	return Layout.AllThings(data.Placed, stationEntries(plot, data), plot.stationShapes)
end

-- Where a newly bought station goes: its default spot if that's free, or else the
-- first free spot, searching from the back wall forward.
local function freeStationSpot(plot, data, id)
	local station = Layout.GetStation(id)
	local shape = plot.stations[id].shape
	local others = layoutThings(plot, data)
	local bounds = plotBounds(data)
	local function fits(entry)
		return (Layout.Check(Layout.StationThing(station, shape, entry), others, bounds))
	end
	local default = plot.stations[id].default
	if fits(default) then
		return { X = default.X, Z = default.Z, R = default.R }
	end
	for z = bounds.MinZ - Layout.MinZ, bounds.MaxZ - Layout.MinZ - shape.D do
		for x = bounds.MinX - Layout.MinX, bounds.MaxX - Layout.MinX - shape.W do
			local entry = { X = x, Z = z, R = 0 }
			if fits(entry) then
				return entry
			end
		end
	end
	return nil
end

local function upgradeLevels(data)
	local levels = {}
	for _, upgrade in Config.Upgrades do
		levels[upgrade.Id] = data[upgrade.Id .. "Level"]
	end
	return levels
end

local function deliveryOrders(plot)
	local orders = {}
	for slot = 1, #Config.DeliveryTiers do
		local order = plot.orders[slot]
		orders[slot] = order or { Waiting = true, Name = Config.DeliveryTiers[slot].Name }
	end
	return orders
end

-- Syncing a bakery's owner also syncs its co-bakers, who see the owner's pantry and
-- orders. skipCoBakers stops two players baking in each other's bakeries from syncing
-- each other forever.
local function syncStats(player, skipCoBakers)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	ensureGoals(data)
	local bar = refreshHotbar(player, data)
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("Stars", data.Stars)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Coins.Value = data.Coins
	end

	local plot = playerPlots[player]
	local orders = {}
	local myCoBakers = {}
	if plot then
		updatePantryShelf(plot, data)
		orders = deliveryOrders(plot)
		for _, coBaker in coBakersOf(plot) do
			table.insert(myCoBakers, { UserId = coBaker.UserId, Name = coBaker.DisplayName })
		end
	end
	-- What a co-baker needs from the bakery they're working in.
	local work = nil
	local coPlot = coBakers[player]
	local host = coPlot and coPlot.owner and PlayerData.Get(coPlot.owner)
	if host then
		work = {
			OwnerName = coPlot.owner.DisplayName,
			RecipesUnlocked = host.RecipesUnlocked,
			Levels = upgradeLevels(host),
			Pantry = host.Pantry,
			PantryCapacity = pantryCapacity(host),
			Orders = deliveryOrders(coPlot),
			BakeSaleAt = host.BakeSaleAt,
		}
	end
	-- Employees go to the client with their names as everyone sees them, once filtered.
	local staff = {}
	local canTrain = false
	for slot, employee in data.Employees do
		local name = plot and plot.employeeNames[slot]
		table.insert(staff, {
			Name = name and name.Raw == employee.Name and name.Shown or "",
			Job = employee.Job,
			Trained = employee.Trained,
			Look = employee.Look,
		})
		canTrain = canTrain or (not employee.Trained and data.Coins >= Config.Employees.TrainCost)
	end
	local hireCost = Config.Employees.HireCost[#data.Employees + 1]
	stateEvent:FireClient(player, {
		Coins = data.Coins,
		Stars = data.Stars,
		RecipesUnlocked = data.RecipesUnlocked,
		Levels = upgradeLevels(data),
		Tray = data.Tray,
		TrayCapacity = trayCapacity(data),
		Pantry = data.Pantry,
		PantryCapacity = pantryCapacity(data),
		Hotbar = bar.Slots,
		SelectedSlot = bar.Selected,
		Passes = PurchaseHandler.OwnedPasses(player),
		Multiplier = coinMultiplier(player, data),
		BoostUntil = data.BoostUntil,
		BakeSaleAt = data.BakeSaleAt,
		BuzzUntil = data.BuzzUntil,
		Flyers = plot and plot.flyers or 0,
		Running = running[player] == true,
		FlyersReadyAt = plot and plot.flyersReadyAt or 0,
		Goals = data.Goals.List,
		Owned = data.Owned,
		Placed = data.Placed,
		Stations = plot and stationEntries(plot, data) or {},
		LuxuryOven = data.LuxuryOven,
		Expansion = data.Expansion,
		Paint = data.Paint,
		Charm = totalCharm(data),
		Orders = orders,
		CanAfford = canAffordUpgrade(data),
		CanUnlockRecipe = canUnlockRecipe(data),
		CanBuy = PlayerData.CanSave(player),
		Work = work,
		CoBakers = myCoBakers,
		FriendBoost = friendBoost(player),
		Employees = staff,
		CanHire = hireCost ~= nil and data.Coins >= hireCost,
		CanTrain = canTrain,
	})
	updateCarriedTray(player, data)
	updateGuide(player)
	if plot and not skipCoBakers then
		for _, coBaker in coBakersOf(plot) do
			syncStats(coBaker, true)
		end
	end
end

-- After a co-baker changes a bakery, both they and its owner need fresh state. Syncing the
-- owner also syncs the co-bakers.
local function syncWork(player, plot)
	if plot and plot.owner and plot.owner ~= player then
		syncStats(plot.owner)
	else
		syncStats(player)
	end
end

local function applyWalkSpeed(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = running[player] and Config.RunSpeed or Config.WalkSpeed
	end
end

setRunningEvent.OnServerEvent:Connect(function(player, on)
	if type(on) ~= "boolean" then
		return
	end
	running[player] = on or nil
	applyWalkSpeed(player)
	syncStats(player)
end)

local function isNear(player, position, reach)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - position).Magnitude <= reach
end

-- The owner can use any of their bakery's prompts, and co-bakers the ones marked CoBake.
local function canUse(player, plot, prompt)
	local allowed = player.UserId == plot.ownerId or (coBakers[player] == plot and prompt:GetAttribute("CoBake") == true)
	if not allowed or not prompt:GetAttribute("Active") then
		return false
	end
	return isNear(player, prompt.Parent.Position, prompt.MaxActivationDistance + REACH_BUFFER)
end

selectSlotEvent.OnServerEvent:Connect(function(player, slot)
	local bar = hotbars[player]
	if not bar or type(slot) ~= "number" or (bar.Slots[slot] or 0) == 0 then
		return
	end
	bar.Selected = bar.Selected ~= slot and slot or nil
	syncStats(player)
end)

-- Ovens. Every bakery has the regular oven, and the Luxury Oven once it's bought. Each
-- one bakes one batch at a time, and the Luxury Oven bakes faster.
local function makeOven(model)
	local body = model.Body
	body.Prompt:SetAttribute("CoBake", true)
	return {
		model = model,
		name = Layout.GetStation(model.Name).Name,
		timeScale = model.Name == "LuxuryOven" and Config.LuxuryOven.BakeTimeScale or 1,
		state = "idle",
		recipe = nil,
		count = 0,
		finishNow = false,
		changedAt = 0,
		window = model.Window,
		burners = model.Burners:GetChildren(),
		smoke = model.Chimney.Smoke,
		prompt = body.Prompt,
		status = body.Status.Label,
	}
end

local function setOvenWindow(oven, color, material)
	oven.window.Color = color
	oven.window.Material = material
end

local function setBurners(oven, on)
	for _, burner in oven.burners do
		burner.Color = on and Color3.fromRGB(255, 90, 40) or Color3.fromRGB(85, 80, 85)
		burner.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	end
end

local function resetOven(oven)
	oven.state = "idle"
	oven.recipe = nil
	oven.count = 0
	oven.finishNow = false
	oven.changedAt = os.clock()
	oven.prompt.ActionText = "Bake"
	oven.prompt.HoldDuration = 0
	oven.status.Text = ""
	oven.smoke.Enabled = false
	setOvenWindow(oven, Color3.fromRGB(70, 50, 60), Enum.Material.Glass)
	setBurners(oven, false)
end

-- Callers check missingIngredients first. The batch's ingredients are used up here. A
-- co-baker bakes with the owner's ingredients and upgrades, and it counts toward the
-- co-baker's own goals.
local function startBake(plot, oven, player, recipe)
	local data = PlayerData.Get(plot.owner)
	local own = PlayerData.Get(player)
	local session = plot.session
	for id, count in recipe.Ingredients do
		data.Pantry[id] -= count
	end
	oven.state = "baking"
	oven.recipe = recipe
	oven.count = upgradeLevel(data, "Batch").BatchSize
	oven.finishNow = false
	oven.prompt.ActionText = ("Finish Now (%d Star)"):format(Config.FinishBakeStars)
	oven.prompt.HoldDuration = 0.5
	oven.smoke.Enabled = true
	setOvenWindow(oven, Color3.fromRGB(255, 150, 60), Enum.Material.Neon)
	setBurners(oven, true)
	data.LastRecipe = table.find(Config.Recipes, recipe)
	addGoalProgress(own, "Bake")
	syncWork(player, plot)

	task.spawn(function()
		local finishAt = os.clock() + bakeTime(data, recipe) * oven.timeScale
		while os.clock() < finishAt and not oven.finishNow do
			if plot.session ~= session then
				return
			end
			oven.status.Text = ("Baking... %ds"):format(math.ceil(finishAt - os.clock()))
			task.wait(0.1)
		end
		if plot.session ~= session then
			return
		end
		oven.state = "ready"
		oven.changedAt = os.clock()
		oven.prompt.ActionText = ("Collect %d %s"):format(oven.count, recipe.Name)
		oven.prompt.HoldDuration = 0
		oven.status.Text = "Ready!"
		oven.smoke.Enabled = false
		setOvenWindow(oven, Color3.fromRGB(255, 225, 130), Enum.Material.Neon)
		setBurners(oven, false)
		notify(player, nil, "Ding")
		updateGuide(plot.owner)
		for _, coBaker in coBakersOf(plot) do
			updateGuide(coBaker)
		end
	end)
end

-- Co-bakers collect onto their own tray and pay for Finish Now with their own Stars.
local function onOvenPrompt(plot, oven, player)
	if not canUse(player, plot, oven.prompt) then
		return
	end
	markActive(player)
	local data = PlayerData.Get(player)
	if oven.state == "idle" then
		openPanelEvent:FireClient(player, "Bake")
	elseif oven.state == "baking" then
		if oven.finishNow then
			return
		end
		if data.Stars < Config.FinishBakeStars then
			notify(player, "You need a Sugar Star. Big deliveries earn them!")
			return
		end
		data.Stars -= Config.FinishBakeStars
		oven.finishNow = true
		syncWork(player, plot)
	else
		local space = trayCapacity(data) - trayTotal(data)
		if space <= 0 then
			notify(player, "Your tray is full! Stock a case or pack a delivery first")
			return
		end
		local taken = math.min(space, oven.count)
		local index = table.find(Config.Recipes, oven.recipe)
		data.Tray[index] += taken
		oven.count -= taken
		if oven.count > 0 then
			oven.prompt.ActionText = ("Collect %d %s"):format(oven.count, oven.recipe.Name)
			notify(player, ("Your tray is full! The rest is still in the %s"):format(oven.name:lower()))
		else
			resetOven(oven)
		end
		syncWork(player, plot)
	end
end

-- The Bake menu bakes in the nearest empty oven the player is standing by.
local function nearestIdleOven(plot, data, player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local nearest, nearestDistance = nil, PANEL_REACH
	for _, oven in ownedOvens(plot, data) do
		local distance = (root.Position - oven.prompt.Parent.Position).Magnitude
		if oven.state == "idle" and distance <= nearestDistance then
			nearest, nearestDistance = oven, distance
		end
	end
	return nearest
end

bakeEvent.OnServerEvent:Connect(function(player, index)
	-- Co-bakers bake the owner's recipes with the owner's ingredients.
	local plot = workPlot(player)
	local data = plot and plot.owner and PlayerData.Get(plot.owner)
	if not plot or not data or type(index) ~= "number" then
		return
	end
	local recipe = Config.Recipes[index]
	if not recipe or index > data.RecipesUnlocked then
		return
	end
	local oven = nearestIdleOven(plot, data, player)
	if not oven then
		notify(player, "Go to an empty oven to bake")
		return
	end
	local missing = missingIngredients(data, recipe)
	if missing then
		notify(player, "You need " .. missing .. " more")
		return
	end
	markActive(player)
	startBake(plot, oven, player, recipe)
end)

-- Display cases
local function refreshCase(plot, data, key)
	local case = plot.cases[key]
	if not case then
		return
	end
	case.items:ClearAllChildren()
	local stock = data.Stock[key]
	for slot, recipeIndex in stock do
		local item = ItemBuilder.Build(
			Config.Recipes[recipeIndex],
			SLOT_ITEM_SCALE,
			case.origin * CFrame.new(case.slots[slot])
		)
		ItemBuilder.Anchor(item)
		item.Parent = case.items
	end
	case.prompt.ObjectText = ("%d/%d treats"):format(#stock, #case.slots)
end

-- Treats move from the player's own tray into the case, which belongs to the bakery's
-- owner. For an owner, both are the same save.
local function stockCase(plot, player, key)
	local data = PlayerData.Get(player)
	local host = plot.owner and PlayerData.Get(plot.owner)
	local case = plot.cases[key]
	if not case or not data or not host or not canUse(player, plot, case.prompt) then
		return
	end
	if trayTotal(data) == 0 then
		notify(player, "Your tray is empty. Bake something first!")
		return
	end
	local stock = host.Stock[key]
	if #stock >= #case.slots then
		notify(player, "This case is full")
		return
	end
	markActive(player)
	-- A selected hotbar box stocks only that treat. Otherwise the priciest treats go first.
	local bar = hotbars[player]
	local selected = bar and bar.Selected and bar.Slots[bar.Selected]
	for index = #Config.Recipes, 1, -1 do
		if not selected or index == selected then
			while data.Tray[index] > 0 and #stock < #case.slots do
				data.Tray[index] -= 1
				table.insert(stock, index)
			end
		end
	end
	data.TutorialDone = true
	refreshCase(plot, host, key)
	syncWork(player, plot)
end

local function addCase(plot, key, model, origin, slots, promptParent, stand)
	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = model
	local prompt = promptParent:FindFirstChild("Prompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Prompt"
		prompt.ActionText = "Stock Case"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = promptParent
	end
	prompt:SetAttribute("Active", true)
	prompt:SetAttribute("CoBake", true)
	local connection = prompt.Triggered:Connect(function(player)
		stockCase(plot, player, key)
	end)
	plot.cases[key] = {
		model = model,
		origin = origin,
		slots = slots,
		items = items,
		prompt = prompt,
		stand = stand,
		connection = connection,
	}
end

-- Placed items
local function buildPlaced(plot, data, key)
	local entry = data.Placed[key]
	local item = Config.GetItem(entry.Id)
	local origin = Layout.CFrame(plot.floorTop, Layout.ItemShape(item), entry)
	-- Wall pieces aren't solid, so nobody gets caught on them or stands on top of them.
	-- A painted display case is built in its colour.
	local paint = entry.Paint and Config.GetPaint(entry.Paint)
	local model = ItemBuilder.Build(item, 1, origin, not item.Flat and not item.Wall, paint and paint.Color)
	ItemBuilder.Anchor(model)
	model.Name = "Placed_" .. key
	if item.Sparkles then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 225, 130)
		sparkles.Parent = model.PrimaryPart
	end
	model.Parent = plot.placedFolder
	if item.Slots then
		local front = Layout.ItemThing(key, entry).Front
		local stand = floorPoint(plot, Layout.Center(front), CUSTOMER_HEIGHT)
		addCase(plot, key, model, origin, item.Slots, model.PrimaryPart, stand)
		refreshCase(plot, data, key)
	end
end

-- Takes an item's model and case out of the bakery but leaves it in the save.
local function unbuildPlaced(plot, key)
	local case = plot.cases[key]
	if case then
		case.connection:Disconnect()
		plot.cases[key] = nil
	end
	local model = plot.placedFolder:FindFirstChild("Placed_" .. key)
	if model then
		model:Destroy()
	end
end

local function storePlaced(plot, data, key)
	unbuildPlaced(plot, key)
	for _, recipeIndex in data.Stock[key] or {} do
		data.Tray[recipeIndex] += 1
	end
	data.Stock[key] = nil
	data.Placed[key] = nil
end

local function nextPlacedKey(data)
	local index = 1
	while data.Placed[tostring(index)] or data.Stock[tostring(index)] do
		index += 1
	end
	return tostring(index)
end

-- Sells one owned copy of an item, if it can be sold, and says what it paid. The money is
-- added straight to the save, so no boost ever makes a sale pay more than its share.
local function sellOne(player, data, item)
	local amount, currency = Config.SellValue(item, data.Owned[item.Id])
	if not amount then
		notify(player, currency)
		return
	end
	data.Owned[item.Id] -= 1
	data[currency] += amount
	local paid = currency == "Stars" and ("%d Sugar %s"):format(amount, amount == 1 and "Star" or "Stars")
		or ("%d coins"):format(amount)
	notify(player, ("Sold %s for %s"):format(item.Name, paid), "Coin")
end

-- "New" places an item from storage, "Move" moves a placed item or a station, and
-- "Store" puts a placed item back in storage. "Sell" sells a placed item, and "SellSpare"
-- sells one stored copy of an item. Wall pieces also send y, their height.
-- Every spot is checked here, whatever the client's preview said.
placeEvent.OnServerEvent:Connect(function(player, action, id, x, z, r, y)
	local plot = playerPlots[player]
	local data = PlayerData.Get(player)
	if not plot or not data or type(id) ~= "string" then
		return
	end
	if action == "Store" or action == "Sell" then
		local entry = data.Placed[id]
		if not entry then
			return
		end
		local item = Config.GetItem(entry.Id)
		local amount, reason = Config.SellValue(item, data.Owned[item.Id])
		if item.Slots and placedCaseCount(data) <= 1 then
			notify(player, "Keep at least one display case so customers can shop")
		elseif action == "Sell" and not amount then
			notify(player, reason)
		else
			storePlaced(plot, data, id)
			if action == "Sell" then
				sellOne(player, data, item)
			end
			refreshEmployees(plot, data)
		end
		syncStats(player)
		return
	end
	if action == "SellSpare" then
		local item = Config.GetItem(id)
		if item and Config.IsAllowed(item, player.UserId) and data.Owned[id] - placedCount(data, id) > 0 then
			sellOne(player, data, item)
			syncStats(player)
		end
		return
	end
	local entry = Layout.CleanEntry(x, z, r, y)
	if not entry or (action ~= "New" and action ~= "Move") then
		return
	end
	local key, thing
	if action == "New" then
		local item = Config.GetItem(id)
		if not item or placedCount(data, id) >= data.Owned[id] then
			return
		end
		entry.Id = id
		key = nextPlacedKey(data)
		thing = Layout.ItemThing(key, entry)
	elseif plot.stations[id] and hasStation(data, id) then
		thing = Layout.StationThing(Layout.GetStation(id), plot.stations[id].shape, entry)
	elseif data.Placed[id] then
		entry.Id = data.Placed[id].Id
		-- A painted case keeps its colour when it moves.
		entry.Paint = data.Placed[id].Paint
		key = id
		thing = Layout.ItemThing(key, entry)
	else
		return
	end
	-- Only wall pieces have a height. Floor pieces and stations never do.
	local wall = key ~= nil and Config.GetItem(entry.Id).Wall == true
	if wall ~= (entry.Y ~= nil) then
		return
	end
	local fits, reason = Layout.Check(thing, layoutThings(plot, data), plotBounds(data))
	if not fits then
		notify(player, reason)
		syncStats(player)
		return
	end
	if not key then
		data.Stations[id] = entry
		moveStation(plot, id, entry)
	else
		if action == "Move" then
			unbuildPlaced(plot, key)
		elseif Config.GetItem(id).Slots then
			data.Stock[key] = {}
		end
		data.Placed[key] = entry
		buildPlaced(plot, data, key)
	end
	refreshEmployees(plot, data)
	syncStats(player)
end)

-- When the bakery grows from the old bounds to the new, wall pieces go with the wall they
-- hang on. Furniture and stations stay where they are.
local function moveWallPieces(plot, data, old, new)
	for key, entry in data.Placed do
		local item = Config.GetItem(entry.Id)
		if item.Wall then
			local rect = Layout.Rect(Layout.ItemShape(item), entry)
			local moved = true
			if entry.R == 0 and rect.MinZ == old.MinZ then
				entry.Z -= old.MinZ - new.MinZ
			elseif entry.R == 1 and rect.MaxX == old.MaxX then
				entry.X += new.MaxX - old.MaxX
			elseif entry.R == 3 and rect.MinX == old.MinX then
				entry.X -= old.MinX - new.MinX
			else
				moved = false
			end
			if moved then
				unbuildPlaced(plot, key)
				buildPlaced(plot, data, key)
			end
		end
	end
end

-- Shop
local function buy(player, data, cost)
	if data.Coins < cost then
		notify(player, ("You need %d more coins"):format(cost - data.Coins))
		return false
	end
	data.Coins -= cost
	return true
end

local function buyWithStars(player, data, cost)
	if data.Stars < cost then
		notify(player, ("You need %d more Sugar Stars"):format(cost - data.Stars))
		return false
	end
	data.Stars -= cost
	return true
end

-- "Paint" takes a paint target's Id and a paint Id, and "PaintCase" a placed display
-- case's key and a paint Id.
purchaseEvent.OnServerEvent:Connect(function(player, kind, id, paintId)
	local data = PlayerData.Get(player)
	local plot = playerPlots[player]
	if not data or not plot then
		return
	end
	if kind == "Recipe" then
		local recipe = Config.Recipes[data.RecipesUnlocked + 1]
		if recipe and buy(player, data, recipe.UnlockCost) then
			data.RecipesUnlocked += 1
			syncStats(player)
			notify(player, recipe.Name .. " unlocked!", "Coin")
		end
	elseif kind == "Upgrade" and type(id) == "string" then
		local upgrade = Config.GetUpgrade(id)
		if not upgrade then
			return
		end
		local key = upgrade.Id .. "Level"
		local nextLevel = upgrade.Levels[data[key] + 1]
		if nextLevel and buy(player, data, nextLevel.Cost) then
			data[key] += 1
			refreshEmployees(plot, data)
			syncStats(player)
			notify(player, upgrade.Name .. " upgraded!", "Coin")
		end
	elseif kind == "Item" and type(id) == "string" then
		local item = Config.GetItem(id)
		if not item or item.OnlyFor then
			return
		end
		-- Only a pass's owners can buy more of its items.
		if item.Pass and not (item.ExtraCoins and PurchaseHandler.OwnsPass(player, item.Pass)) then
			return
		end
		local paid
		if item.Pass then
			paid = buy(player, data, item.ExtraCoins)
		elseif item.Stars then
			paid = buyWithStars(player, data, item.Stars)
		else
			paid = buy(player, data, item.Coins)
		end
		if paid then
			data.Owned[id] += 1
			syncStats(player)
			notify(player, item.Name .. " bought! Press Place to put it in your bakery", "Coin")
		end
	elseif kind == "LuxuryOven" and not data.LuxuryOven then
		local cost = Config.LuxuryOven.Coins
		local entry = data.Coins >= cost and freeStationSpot(plot, data, "LuxuryOven")
		if data.Coins >= cost and not entry then
			notify(player, "Make some room in your bakery for the Luxury Oven first")
			return
		end
		if buy(player, data, cost) then
			data.LuxuryOven = true
			data.Stations.LuxuryOven = entry
			showBoughtStations(plot, data)
			moveStation(plot, "LuxuryOven", entry)
			syncStats(player)
			notify(player, "Luxury Oven bought! It's in your bakery. Move it any time with Decorate", "Coin")
		end
	elseif kind == "Expand" then
		local step = Config.Expansions[data.Expansion + 1]
		if step and buy(player, data, step.Coins) then
			local old = plotBounds(data)
			data.Expansion += 1
			applyExpansion(plot, data.Expansion)
			moveWallPieces(plot, data, old, plotBounds(data))
			syncStats(player)
			notify(player, "Your bakery is bigger! Decorate the new space", "Coin")
		end
	elseif kind == "Buzz" then
		if buyWithStars(player, data, Config.Buzz.Stars) then
			-- Buying again while it's on adds more time.
			data.BuzzUntil = math.max(data.BuzzUntil, os.time()) + Config.Buzz.Minutes * 60
			syncStats(player)
			local left = math.ceil((data.BuzzUntil - os.time()) / 60)
			notify(player, ("Bakery Buzz! Extra customers for the next %d min"):format(left), "Ding")
		end
	elseif kind == "Paint" or kind == "PaintCase" then
		local paint = Config.GetPaint(paintId)
		local target = kind == "Paint" and Config.GetPaintTarget(id)
		local case = kind == "PaintCase" and type(id) == "string" and data.Placed[id]
		local name, current, cost
		if target and paint and Config.CanPaint(target, paint) then
			name, current, cost = target.Name, data.Paint[target.Id] or target.Original, target.Coins
		elseif case and paint and Config.GetItem(case.Id).Slots then
			name, current, cost = Config.GetItem(case.Id).Name, case.Paint or Config.CaseOriginalPaint, Config.CasePaintCoins
		else
			return
		end
		if current == paint.Id then
			notify(player, ("It's already %s"):format(paint.Name))
		elseif buy(player, data, cost) then
			if target then
				data.Paint[target.Id] = paint.Id
				applyPaint(plot, data)
			else
				case.Paint = paint.Id
				unbuildPlaced(plot, id)
				buildPlaced(plot, data, id)
				refreshEmployees(plot, data)
			end
			syncStats(player)
			notify(player, ("%s painted %s!"):format(name, paint.Name), "Coin")
		end
	end
end)

-- Grocery store: shared by everyone on the town square.
local groceryCounter = Workspace:WaitForChild("GroceryStore"):WaitForChild("Counter")

groceryCounter:WaitForChild("Prompt").Triggered:Connect(function(player)
	openPanelEvent:FireClient(player, "Grocery")
end)

-- Buys a bundle, or as much of one as fits in the pantry at the same price per item.
buyGroceriesEvent.OnServerEvent:Connect(function(player, id)
	local data = PlayerData.Get(player)
	local ingredient = type(id) == "string" and Config.GetIngredient(id)
	if not data or not ingredient then
		return
	end
	if not isNear(player, groceryCounter.Position, GROCERY_REACH) then
		notify(player, "Go to the grocery store counter to buy ingredients")
		return
	end
	local space = pantryCapacity(data) - data.Pantry[id]
	if space <= 0 then
		notify(player, ("Your pantry has no room for more %s"):format(ingredient.Name))
		return
	end
	local amount = math.min(Config.GroceryBundle, space)
	local price = math.ceil(ingredient.BundlePrice * amount / Config.GroceryBundle)
	if not buy(player, data, price) then
		return
	end
	data.Pantry[id] += amount
	syncStats(player)
	notify(player, ("Bought %d %s for %d coins"):format(amount, ingredient.Name, price), "Coin")
end)

-- Deliveries
local function makeOrder(data, slot)
	local tier = Config.DeliveryTiers[slot]
	local capacity = trayCapacity(data)
	local total = math.random(math.min(tier.Min, capacity), math.min(tier.Max, capacity))
	local items = {}
	for index in Config.Recipes do
		items[index] = 0
	end
	local value = 0
	for _ = 1, total do
		local index = math.random(data.RecipesUnlocked)
		items[index] += 1
		value += salePrice(data, Config.Recipes[index])
	end
	return {
		Name = tier.Name,
		Items = items,
		Coins = math.floor(value * tier.PayScale),
		Stars = tier.Stars,
	}
end

local function fillOrder(plot, data, slot)
	plot.orderTokens[slot] += 1
	plot.orders[slot] = makeOrder(data, slot)
end

local function queueOrder(plot, player, slot)
	plot.orders[slot] = nil
	plot.orderTokens[slot] += 1
	local token = plot.orderTokens[slot]
	local session = plot.session
	task.delay(Config.DeliveryTiers[slot].Cooldown, function()
		if plot.session ~= session or plot.orderTokens[slot] ~= token then
			return
		end
		local data = PlayerData.Get(player)
		if data then
			fillOrder(plot, data, slot)
			syncStats(player)
		end
	end)
end

-- A parcel appears on the counter beside the laptop, lifts up and shrinks away. It works
-- wherever the counter has been moved.
local function animateBox(plot)
	local top = plot.packingTop
	local start = top.CFrame * CFrame.new(-2.2, top.Size.Y / 2 + 1, 0)
	local box = Instance.new("Part")
	box.Name = "DeliveryBox"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Size = Vector3.new(2.4, 2, 2.4)
	box.Color = Color3.fromRGB(205, 165, 115)
	box.Material = Enum.Material.Cardboard
	box.CFrame = start
	box.Parent = plot.model
	local lift = TweenService:Create(box, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		CFrame = start * CFrame.new(0, 1.2, 0),
	})
	local vanish = TweenService:Create(box, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = start * CFrame.new(0, 2.5, 0),
		Size = Vector3.one * 0.2,
		Transparency = 1,
	})
	lift.Completed:Connect(function()
		vanish:Play()
	end)
	vanish.Completed:Connect(function()
		box:Destroy()
	end)
	lift:Play()
end

-- Whoever packs an order gets paid for it from their own tray, even in a friend's bakery.
shipEvent.OnServerEvent:Connect(function(player, slot)
	local plot = workPlot(player)
	local data = PlayerData.Get(player)
	if not plot or not plot.owner or not data or type(slot) ~= "number" then
		return
	end
	local order = plot.orders[slot]
	if not order then
		return
	end
	if not isNear(player, plot.packingTable.Position, PANEL_REACH) then
		notify(player, "Go to the packing table to ship this")
		return
	end
	if not hasOrderItems(data, order) then
		notify(player, "Your tray doesn't have everything for this order yet")
		return
	end
	for index, count in order.Items do
		data.Tray[index] -= count
	end
	markActive(player)
	local earned = earn(player, data, order.Coins)
	data.Stars += order.Stars
	addGoalProgress(data, "Ship")
	data.TutorialDone = true
	queueOrder(plot, plot.owner, slot)
	animateBox(plot)
	syncWork(player, plot)
	if order.Stars > 0 then
		local starWord = order.Stars == 1 and "Sugar Star" or "Sugar Stars"
		notify(player, ("Shipped! +%d coins, +%d %s"):format(earned, order.Stars, starWord), "Coin")
	else
		notify(player, ("Shipped! +%d coins"):format(earned), "Coin")
	end
end)

-- A co-baker can swap one of the owner's orders with their own Stars.
newOrderEvent.OnServerEvent:Connect(function(player, slot)
	local plot = workPlot(player)
	local data = PlayerData.Get(player)
	local host = plot and plot.owner and PlayerData.Get(plot.owner)
	if not plot or not data or not host or type(slot) ~= "number" or not Config.DeliveryTiers[slot] then
		return
	end
	if buyWithStars(player, data, Config.NewOrderStars) then
		fillOrder(plot, host, slot)
		syncWork(player, plot)
	end
end)

-- Delivery crate
-- Contents lean toward what the owner's unlocked recipes use, but anything can turn up.
local function crateContents(data)
	local weights = {}
	local total = 0
	for index = 1, data.RecipesUnlocked do
		for id, count in Config.Recipes[index].Ingredients do
			weights[id] = (weights[id] or 0) + count
		end
	end
	for _, ingredient in Config.Ingredients do
		weights[ingredient.Id] = (weights[ingredient.Id] or 0) + 1
		total += weights[ingredient.Id]
	end
	local contents = {}
	for _ = 1, Config.Crate.Size do
		local roll = math.random() * total
		for index, ingredient in Config.Ingredients do
			roll -= weights[ingredient.Id]
			if roll <= 0 or index == #Config.Ingredients then
				contents[ingredient.Id] = (contents[ingredient.Id] or 0) + 1
				break
			end
		end
	end
	return contents
end

local function setCrateLabel(crate)
	crate.label.Text = "Free ingredients!\n" .. Config.DescribeIngredients(crate.contents)
end

local function buildCrate(plot, contents)
	local model = Instance.new("Model")
	model.Name = "IngredientCrate"
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Anchored = true
	box.Size = Vector3.new(2.8, 2, 2.8)
	box.CFrame = plot.crateSpot * CFrame.new(0, 1, 0)
	box.Color = Color3.fromRGB(190, 140, 90)
	box.Material = Enum.Material.WoodPlanks
	box.Parent = model
	model.PrimaryPart = box
	for _, y in { -0.55, 0.55 } do
		local slat = Instance.new("Part")
		slat.Name = "Slat"
		slat.Anchored = true
		slat.CanCollide = false
		slat.Size = Vector3.new(2.9, 0.25, 2.9)
		slat.CFrame = box.CFrame * CFrame.new(0, y, 0)
		slat.Color = Color3.fromRGB(150, 100, 65)
		slat.Material = Enum.Material.Wood
		slat.Parent = model
	end
	local shown = 0
	for _, ingredient in Config.Ingredients do
		if contents[ingredient.Id] and shown < 3 then
			local icon = ItemBuilder.Build(ingredient, 0.7, box.CFrame * CFrame.new(-0.8 + shown * 0.8, 1, 0))
			ItemBuilder.Anchor(icon)
			icon.Parent = model
			shown += 1
		end
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 44)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(255, 250, 240)
	label.TextColor3 = Color3.fromRGB(90, 60, 70)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = label
	label.Parent = billboard
	billboard.Parent = box

	-- The client fires UnpackCrate when this prompt is used.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = "Unpack Crate"
	prompt.ObjectText = "Free ingredients"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Active", true)
	prompt:SetAttribute("Action", "UnpackCrate")
	prompt:SetAttribute("CoBake", true)
	prompt.Parent = box

	model.Parent = plot.model
	local crate = { model = model, label = label, contents = contents }
	setCrateLabel(crate)
	return crate
end

local function removeCrate(plot)
	if plot.crate then
		plot.crate.model:Destroy()
		plot.crate = nil
	end
end

-- A crate arrives soon after the owner joins, then Config.Crate.Interval after each is emptied.
local function runCrates(plot, session, player)
	plot.crateDueAt = os.clock() + FIRST_CRATE_DELAY
	while plot.session == session do
		task.wait(1)
		local data = PlayerData.Get(player)
		if plot.session ~= session or not data then
			return
		end
		if not plot.crate and os.clock() >= plot.crateDueAt then
			plot.crate = buildCrate(plot, crateContents(data))
			notify(player, "A free ingredient crate arrived outside your door!", "Ding")
		end
	end
end

-- A co-baker unpacks the owner's crate into the owner's pantry.
unpackCrateEvent.OnServerEvent:Connect(function(player)
	local plot = workPlot(player)
	local data = plot and plot.owner and PlayerData.Get(plot.owner)
	local crate = plot and plot.crate
	if not crate or not data or not isNear(player, crate.model.PrimaryPart.Position, CRATE_REACH) then
		return
	end
	markActive(player)
	local capacity = pantryCapacity(data)
	local taken = {}
	for id, count in crate.contents do
		local take = math.min(count, capacity - data.Pantry[id])
		if take > 0 then
			data.Pantry[id] += take
			taken[id] = take
		end
		crate.contents[id] = count - take > 0 and count - take or nil
	end
	if next(crate.contents) == nil then
		removeCrate(plot)
		plot.crateDueAt = os.clock() + Config.Crate.Interval
	else
		setCrateLabel(crate)
	end
	syncWork(player, plot)
	if next(taken) == nil and plot.owner ~= player then
		notify(player, "This pantry is full! Bake something first")
	elseif next(taken) == nil then
		notify(player, "Your pantry is full! Bake something or buy a Bigger Pantry")
	elseif plot.crate then
		notify(player, "Unpacked " .. Config.DescribeIngredients(taken) .. ". The rest didn't fit", "Coin")
	else
		notify(player, "Unpacked " .. Config.DescribeIngredients(taken), "Coin")
	end
end)

-- Bake Sale. While one is on, a banner above the bakery's sign tells everyone.
local SALE_PINK = Color3.fromRGB(255, 120, 160)
local SALE_CREAM = Color3.fromRGB(255, 250, 240)

local function showSaleBanner(plot, on)
	if on and not plot.saleBanner then
		local banner = Instance.new("BillboardGui")
		banner.Name = "SaleBanner"
		-- Scale sizes on a BillboardGui are in studs.
		banner.Size = UDim2.fromScale(20, 3.4)
		banner.StudsOffset = Vector3.new(0, 4.6, 0)
		banner.LightInfluence = 0
		banner.MaxDistance = 250
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = SALE_PINK
		label.TextColor3 = SALE_CREAM
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = ("BAKE SALE · %d%% OFF"):format(math.floor(Config.BakeSale.Discount * 100 + 0.5))
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = SALE_CREAM
		stroke.Thickness = 3
		stroke.Parent = label
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0.05, 0)
		padding.PaddingRight = UDim.new(0.05, 0)
		padding.Parent = label
		label.Parent = banner
		banner.Parent = plot.model.Sign
		plot.saleBanner = banner
	elseif not on and plot.saleBanner then
		plot.saleBanner:Destroy()
		plot.saleBanner = nil
	end
end

-- Shows the banner until the sale ends. Also runs when the owner comes back mid-sale.
local function runBakeSale(plot, session, player)
	local data = PlayerData.Get(player)
	if not data or not bakeSaleOn(data) then
		return
	end
	showSaleBanner(plot, true)
	task.wait(data.BakeSaleAt + Config.BakeSale.Duration - os.time())
	if plot.session == session then
		showSaleBanner(plot, false)
		syncStats(player)
		notify(player, "The Bake Sale is over, and prices are back to normal")
	end
end

startBakeSaleEvent.OnServerEvent:Connect(function(player)
	local plot = playerPlots[player]
	local data = PlayerData.Get(player)
	if not plot or not data then
		return
	end
	local readyAt = data.BakeSaleAt + Config.BakeSale.Cooldown
	if os.time() < readyAt then
		notify(player, ("Your next Bake Sale is ready in %d min"):format(math.ceil((readyAt - os.time()) / 60)))
		return
	end
	data.BakeSaleAt = os.time()
	task.spawn(runBakeSale, plot, plot.session, player)
	syncStats(player)
	notify(
		player,
		("Bake Sale! Everything is %d%% off, and more customers are on their way"):format(
			math.floor(Config.BakeSale.Discount * 100 + 0.5)
		),
		"Ding"
	)
end)

-- Customers
-- A person is a clone of one of the looks, with a speech bubble over their head. Their root
-- part is anchored and moved by tweening, and the client plays their walk and idle
-- animations. Passing keep uses the look itself instead of a clone, which an employee
-- needs so a change of clothes replaces what they wore.
local function buildPerson(name, look, keep)
	local model = keep and look or look:Clone()
	model.Name = name
	local root = model.PrimaryPart

	local bubble = Instance.new("BillboardGui")
	bubble.Name = "Bubble"
	bubble.Size = UDim2.fromOffset(170, 38)
	bubble.StudsOffset = Vector3.new(0, 4, 0)
	bubble.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(90, 60, 70)
	label.Text = ""
	label.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.4, 0)
	corner.Parent = label
	label.Parent = bubble
	bubble.Parent = root
	return model, label
end

-- Townsfolk wear a random look. Golden customers wear a crown and sparkle.
local function buildCustomer(golden)
	local looks = LOOKS.People:GetChildren()
	local model, label = buildPerson("Customer", looks[math.random(#looks)])
	if golden then
		local head = model.Head
		local crown = Instance.new("Part")
		crown.Name = "Crown"
		crown.Size = Vector3.new(1.25, 0.5, 1.25)
		crown.Color = Color3.fromRGB(255, 200, 60)
		crown.Material = Enum.Material.Foil
		crown.CanCollide = false
		crown.Massless = true
		crown.CFrame = head.CFrame * CFrame.new(0, 0.95, 0)
		-- A joint with a fixed offset, so the crown follows the head once the customer moves.
		local joint = Instance.new("Motor6D")
		joint.Part0 = head
		joint.Part1 = crown
		joint.C0 = CFrame.new(0, 0.95, 0)
		joint.Parent = crown
		crown.Parent = model
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 225, 130)
		sparkles.Parent = model.PrimaryPart
	end
	CollectionService:AddTag(model, "Customer")
	return model, label
end

-- Customers walk at CustomerSpeed. Helpers pass their own speed.
-- Passing stop lets the walk end early, where they are, as soon as stop returns true.
local function walkCustomer(model, to, speed, stop)
	local root = model.PrimaryPart
	local from = root.Position
	local distance = (to - from).Magnitude
	if distance < 0.1 then
		return
	end
	speed = speed or Config.CustomerSpeed
	local duration = distance / speed
	root.CFrame = CFrame.lookAt(from, to)
	-- The client times their steps to this.
	model:SetAttribute("Speed", speed)
	model:SetAttribute("Walking", true)
	local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(to, to + (to - from)),
	})
	tween:Play()
	if stop then
		local arriveAt = os.clock() + duration
		while os.clock() < arriveAt and not stop() do
			task.wait(0.1)
		end
	else
		task.wait(duration)
	end
	tween:Cancel()
	model:SetAttribute("Walking", false)
end

local PATH_SETTINGS = { AgentRadius = 1.2, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = math.huge }
local PATH_GROUND = Vector3.new(0, CUSTOMER_HEIGHT - 0.5, 0)

-- Outside, the baseplate, plaza, paths and bakery floors sit at different heights, so a
-- person's height comes from the ground under them. setUpTown fills in the ground parts.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

local function groundPoint(point)
	local hit = Workspace:Raycast(Vector3.new(point.X, 50, point.Z), Vector3.new(0, -100, 0), groundParams)
	return Vector3.new(point.X, (hit and hit.Position.Y or 0) + CUSTOMER_HEIGHT, point.Z)
end

-- Walks around furniture inside the bakery, or around the fountain, benches and buildings
-- outside, where each step follows the ground. If there's no way through, walks straight.
-- Passing stop ends the walk early, as in walkCustomer.
local function walkAround(model, to, speed, outside, stop)
	local function stopped()
		return not model.Parent or (stop ~= nil and stop())
	end
	local path = PathfindingService:CreatePath(PATH_SETTINGS)
	local ok = pcall(function()
		path:ComputeAsync(model.PrimaryPart.Position - PATH_GROUND, to - PATH_GROUND)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		for index = 2, #waypoints do
			if stopped() then
				return
			end
			local point = waypoints[index].Position
			walkCustomer(model, outside and groundPoint(point) or Vector3.new(point.X, to.Y, point.Z), speed, stop)
		end
	end
	if not stopped() then
		walkCustomer(model, to, speed, stop)
	end
end

local function say(label, text)
	label.Text = text
	label.Visible = true
end

-- A random case holding the wanted treat, or else any stocked case, or nil when all are empty.
local function pickStockedCase(plot, data, wanted)
	local stocked, hasWanted = {}, {}
	for key in plot.cases do
		local stock = data.Stock[key]
		if #stock > 0 then
			table.insert(stocked, key)
		end
		if table.find(stock, wanted) then
			table.insert(hasWanted, key)
		end
	end
	local keys = #hasWanted > 0 and hasWanted or stocked
	if #keys == 0 then
		return nil
	end
	return keys[math.random(#keys)]
end

-- Townsfolk. People walk in from the edge of town, stroll between spots on the plaza, and
-- walk out again. A bakery's customers are townsfolk who head in from the plaza and go back
-- to it afterwards, so nobody appears or vanishes beside a bakery.
local FADE_TIME = 1
local townsfolkFolder = Instance.new("Folder")
townsfolkFolder.Name = "Townsfolk"
townsfolkFolder.Parent = Workspace
-- Filled in by setUpTown. Each stroll spot has a Position to stand at and a Look point to face.
local town = { center = Vector3.zero, strolls = {}, edges = {} }
local townsfolk = {}

local function randomBetween(range)
	return range[1] + math.random() * (range[2] - range[1])
end

local function flatDistance(a, b)
	return ((a - b) * Vector3.new(1, 0, 1)).Magnitude
end

-- Fades a person in (to 0) or out (to 1) at the edge of town. Their root part stays invisible.
local function fade(model, to)
	for _, part in model:GetDescendants() do
		if (part:IsA("BasePart") and part ~= model.PrimaryPart) or part:IsA("Decal") then
			TweenService:Create(part, TweenInfo.new(FADE_TIME), { Transparency = to }):Play()
		elseif part:IsA("Sparkles") then
			part.Enabled = to == 0
		end
	end
	task.wait(FADE_TIME)
end

local function turnTo(model, point)
	local root = model.PrimaryPart
	local position = root.Position
	local look = Vector3.new(point.X, position.Y, point.Z)
	if flatDistance(look, position) > 0.1 then
		TweenService:Create(root, TweenInfo.new(0.3), { CFrame = CFrame.lookAt(position, look) }):Play()
	end
end

-- A random spot on the plaza. Sometimes it's in front of a bakery someone owns, as if
-- window shopping.
local function pickStroll()
	local owned = {}
	for _, plot in plots do
		if plot.ownerId then
			table.insert(owned, plot)
		end
	end
	if #owned > 0 and math.random() < 0.25 then
		local plot = owned[math.random(#owned)]
		return { Position = plot.mouth, Look = plot.door.Position }
	end
	return town.strolls[math.random(#town.strolls)]
end

-- One of the two edges of town nearest a point, so nobody crosses the whole plaza to leave.
local function edgeNear(point)
	local edges = table.clone(town.edges)
	table.sort(edges, function(a, b)
		return flatDistance(a, point) < flatDistance(b, point)
	end)
	return edges[math.random(math.min(2, #edges))]
end

-- The checkout line. Customers who've chosen a treat wait in single file in front of the
-- register, and pay when a Cashier employee or a player checks the first one out.
-- plot.line holds them in order, and person.atSpot says whether they've reached their
-- place in it. plot.cashierReady is true while a Cashier is standing at the register.
local checkout = {}
-- How far apart people stand in line.
checkout.GAP = 2.5

-- The point at the front of the counter in line with the register, the way customers
-- face the counter, and the counter's depth, all on the floor's grid.
function checkout.frame(plot, data)
	local thing = stationThing(plot, data, "Checkout")
	local facing, rect = thing.Facing, thing.Rect
	local depth = math.abs(facing:Dot(Vector3.new(rect.MaxX - rect.MinX, 0, rect.MaxZ - rect.MinZ)))
	local center = Layout.Center(rect)
	local across = Vector3.new(facing.Z, 0, -facing.X)
	local register = plot.floorTop:PointToObjectSpace(plot.registerPart.Position)
	return center + across * across:Dot(register - center), facing, depth
end

function checkout.insideWalls(data, point)
	local bounds = plotBounds(data)
	return Vector3.new(math.clamp(point.X, bounds.MinX + 1, bounds.MaxX - 1), 0, math.clamp(point.Z, bounds.MinZ + 1, bounds.MaxZ - 1))
end

-- Where the index-th person in line stands: the first at the register, and each after
-- them a step further out, kept inside the walls. Also returns the point they face.
function checkout.spot(plot, data, index)
	local point, facing, depth = checkout.frame(plot, data)
	local spot = checkout.insideWalls(data, point + facing * (depth / 2 + 1.5 + (index - 1) * checkout.GAP))
	return floorPoint(plot, spot, CUSTOMER_HEIGHT), floorPoint(plot, point, CUSTOMER_HEIGHT)
end

-- Where a Cashier stands: behind the register, facing the customers.
function checkout.cashierSpot(plot, data)
	local point, facing, depth = checkout.frame(plot, data)
	local spot = floorPoint(plot, checkout.insideWalls(data, point - facing * (depth / 2 + 1.2)), CUSTOMER_HEIGHT)
	return CFrame.lookAt(spot, floorPoint(plot, point + facing * 5, CUSTOMER_HEIGHT))
end

-- Called whenever the line or the Cashier changes. The register's prompt shows while the
-- first person is waiting at it, and when nobody is there to check them out, the owner is
-- told and guided to the register.
function checkout.update(plot)
	local front = plot.line[1]
	local waiting = front ~= nil and front.atSpot == true
	if plot.registerPrompt:GetAttribute("Active") ~= waiting then
		setActive(plot.registerPrompt, waiting)
	end
	if waiting then
		say(front.label, "Ready to pay!")
		if not plot.cashierReady and plot.owner and os.clock() >= plot.nextLineNotice then
			plot.nextLineNotice = os.clock() + 10
			notify(plot.owner, "A customer is ready to pay at the register!", "Ding")
		end
	end
	if plot.owner then
		updateGuide(plot.owner)
		for _, coBaker in coBakersOf(plot) do
			updateGuide(coBaker)
		end
	end
end

-- Pays the owner for what the person chose. They tip when it's the treat they wanted,
-- and golden customers pay more and sometimes give a Sugar Star.
function checkout.pay(plot, person)
	local owner = plot.owner
	local data = owner and PlayerData.Get(owner)
	if not data then
		return
	end
	local recipe = person.recipe
	local price = salePrice(data, recipe)
	if bakeSaleOn(data) then
		price = math.max(1, math.floor(price * (1 - Config.BakeSale.Discount)))
	end
	local stars = 0
	if person.golden then
		price *= Config.GoldenCustomer.PayScale
		if math.random() < Config.GoldenCustomer.StarChance then
			stars = 1
		end
	end
	-- Bake Together: the owner gets a bonus for each active co-baker, and each of them
	-- gets a share of the price. These are new coins, so nobody earns less.
	local helping = activeCoBakers(plot)
	local coins = earn(owner, data, price * (1 + Config.CoBake.OwnerBonus * #helping))
	for _, coBaker in helping do
		local coData = PlayerData.Get(coBaker)
		local share = coData and earn(coBaker, coData, price * Config.CoBake.Share) or 0
		-- Syncing the owner below syncs co-bakers too.
		if share > 0 then
			notify(coBaker, ("+%d coins: you helped sell a %s"):format(share, recipe.Name:lower()), "Coin")
		end
	end
	local tipCoins = 0
	if person.gotWanted then
		local share = Config.WantedTip.Min + math.random() * (Config.WantedTip.Max - Config.WantedTip.Min)
		local tip = math.floor(price * share + 0.5)
		if tip > 0 then
			tipCoins = earn(owner, data, tip)
		end
	end
	data.Stars += stars
	addGoalProgress(data, "Sell", table.find(Config.Recipes, recipe))
	syncStats(owner)
	if person.golden then
		local tips = {}
		if tipCoins > 0 then
			table.insert(tips, ("%d coins"):format(tipCoins))
		end
		if stars > 0 then
			table.insert(tips, "a Sugar Star")
		end
		local tipText = #tips > 0 and " and tipped " .. table.concat(tips, " and ") or ""
		notify(owner, ("+%d coins: a golden customer bought %s%s!"):format(coins, recipe.Name:lower(), tipText), "Coin")
	elseif tipCoins > 0 then
		notify(owner, ("+%d coins: %s sold, +%d tip!"):format(coins, recipe.Name, tipCoins), "Coin")
	else
		notify(owner, ("+%d coins: %s sold"):format(coins, recipe.Name), "Coin")
	end
end

-- Checks out the first person in line, once they're standing at the register. Returns
-- whether anyone was checked out.
function checkout.checkOut(plot)
	local person = plot.line[1]
	if not person or not person.atSpot then
		return false
	end
	table.remove(plot.line, 1)
	person.paid = true
	say(person.label, "Thank you!")
	checkout.pay(plot, person)
	checkout.update(plot)
	return true
end

-- A customer joins the end of the line and waits there until they've paid, stepping up as
-- the line moves and following the register if the counter moves. Returns false if the
-- owner leaves first.
function checkout.wait(plot, session, person)
	local model = person.model
	person.paid, person.atSpot = false, false
	table.insert(plot.line, person)
	local standing = nil
	while plot.session == session and not person.paid do
		local data = PlayerData.Get(plot.owner)
		local index = table.find(plot.line, person)
		if data and index then
			local spot, register = checkout.spot(plot, data, index)
			if not standing or (spot - standing).Magnitude > 0.5 then
				person.atSpot = false
				if index == 1 then
					checkout.update(plot)
				end
				if (spot - model.PrimaryPart.Position).Magnitude > 4 then
					walkAround(model, spot, person.speed)
				else
					walkCustomer(model, spot, person.speed)
				end
				if plot.session ~= session then
					break
				end
				turnTo(model, register)
				standing = spot
				person.atSpot = true
				checkout.update(plot)
			end
		end
		task.wait(0.2)
	end
	return person.paid
end

-- Seats. After paying, a customer sits at a random free seat, on a piece with Seats in
-- Config, for a while before leaving. plot.seated holds whoever has each seat, by the
-- piece's key and the seat's number, as in "3:1".
local seats = {}
-- How far a sitting person's root is above the top of the seat, so that in Roblox's sit
-- pose their legs rest on it.
seats.HEIGHT = 1.5

-- Every free seat in the bakery, with its piece's model and where the piece stands.
function seats.free(plot, data)
	local free = {}
	for key, entry in data.Placed do
		local item = Config.GetItem(entry.Id)
		local model = item and item.Seats and plot.placedFolder:FindFirstChild("Placed_" .. key)
		if model then
			local origin = Layout.CFrame(plot.floorTop, Layout.ItemShape(item), entry)
			for index, seat in item.Seats do
				local id = key .. ":" .. index
				if not plot.seated[id] then
					table.insert(free, { id = id, seat = seat, model = model, origin = origin })
				end
			end
		end
	end
	return free
end

-- Walks a person to a random free seat and sits them down for SitTime seconds, then stands
-- them up where they stepped in. They get up early if the piece is moved or put away, or
-- the owner leaves. Does nothing when every seat is taken.
function seats.sit(plot, session, person, data)
	local free = seats.free(plot, data)
	if #free == 0 then
		return
	end
	local choice = free[math.random(#free)]
	local seat, model = choice.seat, person.model
	local root = model.PrimaryPart
	plot.seated[choice.id] = person
	local function moved()
		return plot.session ~= session or choice.model.Parent ~= plot.placedFolder
	end
	-- Where they step in from, kept inside the walls, and the seat at standing height.
	local from = plot.floorTop:PointToObjectSpace(choice.origin * Vector3.new(seat.From.X, 0, seat.From.Z))
	local stand = floorPoint(plot, checkout.insideWalls(data, from), CUSTOMER_HEIGHT)
	local over = choice.origin * Vector3.new(seat.At.X, CUSTOMER_HEIGHT, seat.At.Z)
	local look = choice.origin:VectorToWorldSpace(seat.Look)
	walkAround(model, stand, person.speed, false, moved)
	if not moved() then
		walkCustomer(model, over, person.speed, moved)
	end
	if not moved() then
		local top = choice.origin * (seat.At + Vector3.new(0, seats.HEIGHT, 0))
		person.label.Visible = false
		TweenService:Create(root, TweenInfo.new(0.4), { CFrame = CFrame.lookAt(top, top + look) }):Play()
		model:SetAttribute("Sitting", true)
		local getUpAt = os.clock() + randomBetween(Config.SitTime)
		while os.clock() < getUpAt and not moved() do
			task.wait(0.25)
		end
		model:SetAttribute("Sitting", false)
		TweenService:Create(root, TweenInfo.new(0.4), { CFrame = CFrame.lookAt(over, over + look) }):Play()
		task.wait(0.4)
		walkCustomer(model, stand, person.speed)
	end
	if plot.seated[choice.id] == person then
		plot.seated[choice.id] = nil
	end
end

-- Inside a bakery: a case with the treat they want if there is one, then the line at the
-- register to pay, then a seat for a while if one is free. They settle for something else
-- if their treat isn't there, and tip when it is. Stops early if the owner leaves.
local function shopAt(plot, session, person)
	local model, label = person.model, person.label
	local wanted = person.wants
	local function gone()
		return plot.session ~= session
	end

	local owner = plot.owner
	local data = PlayerData.Get(owner)
	local key = data and pickStockedCase(plot, data, wanted)
	local recipe, gotWanted
	if key then
		walkAround(model, plot.cases[key].stand, person.speed)
		if gone() then
			return
		end
		task.wait(Config.BrowseTime)
		if gone() then
			return
		end
		-- Another customer may have emptied this case, or the owner may have moved it.
		local stock = plot.cases[key] and data.Stock[key]
		if stock and #stock > 0 then
			local slot = table.find(stock, wanted)
			gotWanted = slot ~= nil
			recipe = Config.Recipes[table.remove(stock, slot or math.random(#stock))]
			refreshCase(plot, data, key)
			syncStats(owner)
		end
	end

	-- The thought bubble goes once they've chosen, and they say what they think instead.
	model:SetAttribute("Wants", nil)
	if recipe then
		if gotWanted then
			say(label, "Just what I wanted!")
		else
			-- Every treat's name takes an "s", like "cupcakes".
			say(label, ("No %ss... %s it is!"):format(Config.Recipes[wanted].Name:lower(), recipe.Name:lower()))
		end
		person.recipe, person.gotWanted = recipe, gotWanted
		if not checkout.wait(plot, session, person) then
			return
		end
		task.wait(0.8)
		seats.sit(plot, session, person, data)
	else
		say(label, "Nothing to buy!")
		task.wait(1.2)
	end
end

-- Takes a person from wherever they are to a bakery's path, up it and through the door to
-- shop, then back out and down the path to the plaza. They come wanting one of the
-- owner's unlocked treats, shown in a thought bubble. If the owner leaves on the way, the
-- person heads back to the plaza.
local function visitBakery(person)
	local plot, session = person.visit, person.visitSession
	local model = person.model
	local door = plot.door.Position + Vector3.new(0, 3, 0)
	local data = PlayerData.Get(plot.owner)
	person.wants = math.random(data and data.RecipesUnlocked or 1)
	model:SetAttribute("Wants", person.wants)
	walkAround(model, plot.mouth, person.speed, true)
	if plot.session == session then
		walkCustomer(model, door, person.speed)
		if plot.session == session then
			shopAt(plot, session, person)
			walkAround(model, door, person.speed)
		end
		person.label.Visible = false
		walkCustomer(model, plot.mouth, person.speed)
	end
	person.visit = nil
	person.label.Visible = false
	model:SetAttribute("Wants", nil)
end

-- A person strolls between a few spots, shopping whenever a bakery calls them in, then
-- walks out of town. Being called in stops a stroll where they are.
local function runPerson(person)
	local model = person.model
	model.Parent = townsfolkFolder
	fade(model, 0)
	local function called()
		return person.visit ~= nil
	end
	local stops = math.random(Config.Townsfolk.Stops[1], Config.Townsfolk.Stops[2])
	while true do
		if person.visit then
			visitBakery(person)
			stops = math.random(Config.Townsfolk.StopsAfterShopping[1], Config.Townsfolk.StopsAfterShopping[2])
		elseif stops <= 0 then
			break
		else
			local spot = pickStroll()
			walkAround(model, spot.Position, person.speed, true, called)
			if not person.visit then
				turnTo(model, spot.Look)
				local leaveAt = os.clock() + randomBetween(Config.Townsfolk.StopTime)
				while os.clock() < leaveAt and not person.visit do
					task.wait(0.25)
				end
			end
			stops -= 1
		end
	end
	person.leaving = true
	walkAround(model, edgeNear(model.PrimaryPart.Position), person.speed, true)
	fade(model, 1)
	townsfolk[person] = nil
	model:Destroy()
end

-- A new person, invisible until they fade in. They start walking on the next frame, so a
-- caller can send them to a bakery first.
local function spawnPerson(position)
	local golden = math.random() < Config.GoldenCustomer.Chance
	local model, label = buildCustomer(golden)
	model.PrimaryPart.CFrame = CFrame.lookAt(position, Vector3.new(town.center.X, position.Y, town.center.Z))
	for _, part in model:GetDescendants() do
		if (part:IsA("BasePart") and part ~= model.PrimaryPart) or part:IsA("Decal") then
			part.Transparency = 1
		elseif part:IsA("Sparkles") then
			part.Enabled = false
		end
	end
	local person = {
		model = model,
		label = label,
		golden = golden,
		speed = Config.CustomerSpeed * randomBetween(Config.Townsfolk.Speed),
		visit = nil,
		visitSession = nil,
		-- The Config.Recipes index they want on a bakery visit.
		wants = nil,
		leaving = false,
	}
	townsfolk[person] = true
	task.defer(runPerson, person)
	return person
end

local function sendVisitor(plot, session, person)
	person.visit = plot
	person.visitSession = session
end

-- Sends someone to a bakery: one of the three free townsfolk nearest its path, or a
-- newcomer from the nearest edge of town when everyone's busy.
local function requestCustomer(plot, session)
	local free = {}
	for person in townsfolk do
		if not person.visit and not person.leaving then
			table.insert(free, person)
		end
	end
	table.sort(free, function(a, b)
		return flatDistance(a.model.PrimaryPart.Position, plot.mouth) < flatDistance(b.model.PrimaryPart.Position, plot.mouth)
	end)
	local person = free[math.random(math.clamp(#free, 1, 3))] or spawnPerson(edgeNear(plot.mouth))
	sendVisitor(plot, session, person)
end

-- How many people should be strolling: more when more bakeries are open.
local function crowdTarget()
	local owned = 0
	for _, plot in plots do
		if plot.ownerId then
			owned += 1
		end
	end
	local settings = Config.Townsfolk
	return math.min(settings.Base + owned * settings.PerBakery, settings.Max)
end

-- Keeps the plaza busy. People shopping or leaving don't count, so the plaza stays lively
-- while bakeries are busy.
local function runCrowd()
	while true do
		local strolling = 0
		for person in townsfolk do
			if not person.visit and not person.leaving then
				strolling += 1
			end
		end
		if strolling < crowdTarget() then
			spawnPerson(town.edges[math.random(#town.edges)])
		end
		task.wait(randomBetween(Config.Townsfolk.ArrivalGap))
	end
end

-- Works out the stroll spots, each bakery's path mouth and the edges of town from the world
-- that tools/build_town.luau built.
local function setUpTown()
	local townModel = Workspace:WaitForChild("Town")
	local plaza = townModel:WaitForChild("Plaza")
	town.center = plaza.Position
	-- The plaza is a cylinder lying on its side, so its Y and Z sizes are its diameter.
	local radius = plaza.Size.Y / 2

	local ground = { plaza }
	for _, part in townModel:GetChildren() do
		if part.Name == "Path" or part.Name == "PlazaRim" then
			table.insert(ground, part)
		end
	end
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		table.insert(ground, baseplate)
	end
	for _, plot in plots do
		table.insert(ground, plot.model.Floor)
	end
	groundParams.FilterDescendantsInstances = ground

	local function addStroll(position, look)
		table.insert(town.strolls, { Position = groundPoint(position), Look = look })
	end
	local function direction(degrees)
		local angle = math.rad(degrees)
		return Vector3.new(math.cos(angle), 0, math.sin(angle))
	end
	-- Around the fountain, looking at it.
	local fountainRadius = townModel.Fountain.Basin.Size.Y / 2
	for step = 0, 7 do
		addStroll(town.center + direction(step * 45 + 22.5) * (fountainRadius + 4), town.center)
	end
	-- Further out, looking at the bakeries.
	for step = 0, 9 do
		local out = direction(step * 36)
		addStroll(town.center + out * radius * 0.57, town.center + out * radius)
	end
	-- In front of each bench, looking at the fountain.
	for _, bench in townModel:GetChildren() do
		if bench.Name == "Bench" then
			local position = bench:GetPivot().Position
			local inward = ((town.center - position) * Vector3.new(1, 0, 1)).Unit
			addStroll(position + inward * 2.5, town.center)
		end
	end

	-- Each bakery's path meets the plaza a little inside its edge. The door's +Z faces the plaza.
	local angles = {}
	local farthest = 0
	for _, plot in plots do
		local point = plot.door.Position
		for _ = 1, 200 do
			if flatDistance(point, town.center) <= radius - 4 then
				break
			end
			point += plot.door.ZVector
		end
		plot.mouth = groundPoint(point)
		local offset = plot.model.Floor.Position - town.center
		farthest = math.max(farthest, flatDistance(plot.model.Floor.Position, town.center))
		table.insert(angles, math.atan2(offset.Z, offset.X))
	end
	local grocery = Workspace:FindFirstChild("GroceryStore")
	if grocery then
		local offset = grocery:GetPivot().Position - town.center
		table.insert(angles, math.atan2(offset.Z, offset.X))
	end
	-- Edges of town: out past the trees in each gap between buildings, a little to one side
	-- of the tree there.
	table.sort(angles)
	for index, angle in angles do
		local gap = (angles[index % #angles + 1] - angle) % (2 * math.pi)
		local between = math.deg(angle + gap / 2) + 5
		table.insert(town.edges, groundPoint(town.center + direction(between) * (farthest + 70)))
	end
end

-- The average gap between customers without boosts. Charm shortens it, by less for each
-- piece, up to CharmSpeed.Max.
local function customerInterval(data)
	local charm = totalCharm(data)
	local speed = 1 + Config.CharmSpeed.Max * charm / (charm + Config.CharmSpeed.Half)
	return Config.CustomerInterval / speed
end

-- The average wait factor and group size, used to even out waits so that customers still
-- come once per interval on average.
local GAP_WEIGHT, GAP_AVERAGE, GROUP_AVERAGE = 0, 0, 1
for _, kind in Config.CustomerGap.Kinds do
	GAP_WEIGHT += kind.Weight
	GAP_AVERAGE += kind.Weight * (kind.Factor[1] + kind.Factor[2]) / 2
end
GAP_AVERAGE /= GAP_WEIGHT
for size, chance in Config.CustomerGap.Groups do
	GROUP_AVERAGE += chance * (size - 1)
end

-- A random wait factor from one of the CustomerGap kinds: right behind the last customer, a
-- usual wait, or a quiet spell. It stretches to make up for groups.
local function customerGap()
	local kinds = Config.CustomerGap.Kinds
	local roll = math.random() * GAP_WEIGHT
	for index, kind in kinds do
		roll -= kind.Weight
		if roll <= 0 or index == #kinds then
			return randomBetween(kind.Factor) * GROUP_AVERAGE / GAP_AVERAGE
		end
	end
	return 1
end

-- How many friends arrive together, usually 1.
local function groupSize()
	local roll = math.random()
	for size, chance in Config.CustomerGap.Groups do
		roll -= chance
		if roll < 0 then
			return size
		end
	end
	return 1
end

-- Every SPAWN_STEP seconds the bakery gets a step closer to its next customer, with bigger
-- steps during boosts, so a boost brings people straight away. The first customer comes a
-- few seconds after the owner arrives.
local SPAWN_STEP = 0.5
local FIRST_CUSTOMER_HEAD_START = 0.7

local function runCustomerSpawner(plot, session, player)
	local progress, gap = FIRST_CUSTOMER_HEAD_START, 1
	while true do
		task.wait(SPAWN_STEP)
		local data = PlayerData.Get(player)
		if plot.session ~= session or not data then
			return
		end
		local interval = math.max(Config.CustomerMinInterval, customerInterval(data) / rushPower(data))
		progress += SPAWN_STEP / (interval * gap)
		if progress >= 1 then
			progress, gap = 0, customerGap()
			for _ = 1, groupSize() do
				requestCustomer(plot, session)
			end
		end
	end
end

-- Flyers. The owner takes a stack from the stand outside the door, and townsfolk who come
-- near them on the plaza take one and head to the bakery.
local FLYER_COLOR = Color3.fromRGB(255, 170, 200)
local FLYER_WOOD = Color3.fromRGB(190, 140, 90)
local FLYER_LEG_WOOD = Color3.fromRGB(150, 100, 65)
local FLYER_SAYING = "Ooh, I'll take a look!"

local function flyerPart(name, size, cframe, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

-- A little wooden table with a pink stack of flyers on it.
local function buildFlyerStand(plot)
	local model = Instance.new("Model")
	model.Name = "FlyerStand"
	-- It stands on the ground outside, which is lower than the bakery floor.
	local spot = plot.flyerSpot
	local base = spot + Vector3.new(0, groundPoint(spot.Position).Y - CUSTOMER_HEIGHT - spot.Position.Y, 0)
	local top = flyerPart("Top", Vector3.new(3, 0.3, 2), base * CFrame.new(0, 2.6, 0), FLYER_WOOD, Enum.Material.WoodPlanks, model)
	top.CanCollide = true
	model.PrimaryPart = top
	for _, x in { -1.3, 1.3 } do
		for _, z in { -0.8, 0.8 } do
			flyerPart("Leg", Vector3.new(0.3, 2.45, 0.3), base * CFrame.new(x, 1.225, z), FLYER_LEG_WOOD, Enum.Material.Wood, model)
		end
	end
	local stack = flyerPart("Stack", Vector3.new(1.6, 0.35, 1.15), base * CFrame.new(0, 2.925, 0), FLYER_COLOR, Enum.Material.SmoothPlastic, model)
	-- A few loose flyers at angles, so it reads as paper.
	for index, angle in { -12, 8, 20 } do
		flyerPart(
			"Sheet",
			Vector3.new(1.6, 0.05, 1.15),
			stack.CFrame * CFrame.new(0, 0.2 + index * 0.03, 0) * CFrame.Angles(0, math.rad(angle), 0),
			index == 2 and Color3.fromRGB(255, 250, 240) or FLYER_COLOR,
			Enum.Material.SmoothPlastic,
			model
		)
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(170, 44)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(255, 250, 240)
	label.TextColor3 = Color3.fromRGB(90, 60, 70)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = label
	label.Parent = billboard
	billboard.Parent = top

	-- The client fires TakeFlyers when this prompt is used.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = "Take Flyers"
	prompt.ObjectText = "Flyers"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Active", true)
	prompt:SetAttribute("Action", "TakeFlyers")
	prompt:SetAttribute("CoBake", true)
	prompt.Parent = top

	model.Parent = plot.model
	return { model = model, label = label, prompt = prompt }
end

local function removeFlyerStand(plot)
	if plot.flyerStand then
		plot.flyerStand.model:Destroy()
		plot.flyerStand = nil
	end
end

local function refreshFlyerStand(plot)
	local stand = plot.flyerStand
	if not stand then
		return
	end
	local left = plot.flyersReadyAt - os.time()
	local text = left > 0 and ("More flyers in %d:%02d"):format(left // 60, left % 60) or "Free flyers!\nTake a stack"
	if stand.label.Text ~= text then
		stand.label.Text = text
	end
	if stand.prompt:GetAttribute("Active") ~= (left <= 0) then
		setActive(stand.prompt, left <= 0)
	end
end

-- The stack in the holder's right hand, one sheet for each flyer left. If the holder stops
-- working in the bakery, the owner takes over the stack.
local function updateHeldFlyers(plot)
	local holder = plot.flyerHolder
	if holder and workPlot(holder) ~= plot then
		holder = plot.owner
		plot.flyerHolder = holder
	end
	local character = holder and plot.flyers > 0 and holder.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	local grip = hand and hand:FindFirstChild("RightGripAttachment")
	local held = plot.heldFlyers
	if held and held.Parent == character and held:GetAttribute("Count") == plot.flyers then
		return
	end
	if held then
		held:Destroy()
		plot.heldFlyers = nil
	end
	if not grip then
		return
	end
	local model = Instance.new("Model")
	model.Name = "HeldFlyers"
	model:SetAttribute("Count", plot.flyers)
	-- Pinched by the top edge, hanging below the hand, turned so it shows from behind.
	local base = hand.CFrame * grip.CFrame * CFrame.new(0, 0, -0.5) * CFrame.Angles(0, 0, math.rad(45))
	for index = 1, plot.flyers do
		local sheet = flyerPart(
			"Sheet",
			Vector3.new(0.05, 0.9, 1.2),
			base * CFrame.new((index - 1) * 0.07, 0, 0) * CFrame.Angles(math.rad((index % 2) * 6 - 3), 0, 0),
			index == plot.flyers - 1 and Color3.fromRGB(255, 250, 240) or FLYER_COLOR,
			Enum.Material.SmoothPlastic,
			model
		)
		sheet.Anchored = false
		sheet.CanQuery = false
		sheet.CanTouch = false
		sheet.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = sheet
		weld.Parent = sheet
	end
	model.Parent = character
	plot.heldFlyers = model
end

-- A flyer flies from the holder's hand to the person who takes it.
local function tossFlyer(from, person)
	local root = person.model.PrimaryPart
	local flyer = flyerPart("Flyer", Vector3.new(0.8, 0.05, 1.1), CFrame.new(from), FLYER_COLOR, Enum.Material.SmoothPlastic, Workspace)
	local tween = TweenService:Create(flyer, TweenInfo.new(0.35), {
		CFrame = CFrame.new(root.Position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.rad(180), math.rad(20)),
	})
	tween:Play()
	tween.Completed:Connect(function()
		flyer:Destroy()
	end)
end

-- The free townsperson nearest a point, within reach.
local function nearestFree(point, reach)
	local nearest, nearestDistance = nil, reach
	for person in townsfolk do
		local root = person.model.PrimaryPart
		if not person.visit and not person.leaving and root then
			local distance = flatDistance(root.Position, point)
			if distance <= nearestDistance then
				nearest, nearestDistance = person, distance
			end
		end
	end
	return nearest
end

-- Whoever took the stack, the owner or a co-baker, carries it in their hand and hands out
-- flyers to the townsfolk they walk past.
local function runFlyers(plot, session)
	local nextHandOut = 0
	while plot.session == session do
		task.wait(0.25)
		refreshFlyerStand(plot)
		updateHeldFlyers(plot)
		local holder = plot.flyerHolder
		if holder and plot.flyers > 0 and os.clock() >= nextHandOut then
			local character = holder.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local person = root and nearestFree(root.Position, Config.Flyers.Reach)
			if person then
				local held = plot.heldFlyers and plot.heldFlyers:FindFirstChild("Sheet")
				nextHandOut = os.clock() + Config.Flyers.Gap
				plot.flyers -= 1
				sendVisitor(plot, session, person)
				tossFlyer(held and held.Position or root.Position + Vector3.new(0, 1, 0), person)
				updateHeldFlyers(plot)
				say(person.label, FLYER_SAYING)
				task.delay(2.5, function()
					if person.label.Text == FLYER_SAYING then
						person.label.Visible = false
					end
				end)
				if plot.flyers > 0 then
					notify(holder, ("Handed out a flyer! %d left"):format(plot.flyers), "Ding")
				else
					notify(holder, "That was the last flyer. Get more at the stand outside the door", "Ding")
				end
				markActive(holder)
				syncWork(holder, plot)
			end
		end
	end
end

takeFlyersEvent.OnServerEvent:Connect(function(player)
	local plot = workPlot(player)
	local stand = plot and plot.flyerStand
	if not stand or not isNear(player, stand.model.PrimaryPart.Position, CRATE_REACH) then
		return
	end
	markActive(player)
	if os.time() < plot.flyersReadyAt then
		notify(player, "The next stack of flyers isn't ready yet")
		return
	end
	plot.flyers = Config.Flyers.Stack
	plot.flyersReadyAt = os.time() + Config.Flyers.Restock
	plot.flyerHolder = player
	refreshFlyerStand(plot)
	updateHeldFlyers(plot)
	syncWork(player, plot)
	notify(player, ("You have %d flyers. Walk near people on the plaza to hand them out!"):format(plot.flyers), "Coin")
end)

-- Employees. An owner hires up to Config.Employees.Max, and each does a different job: the
-- Baker carries ingredients from the pantry shelf to an empty oven, the Stocker carries
-- finished batches to the display cases, and the Cashier checks customers out at the
-- register. Between jobs, employee 1 waits at one front corner of the regular oven and
-- employee 2 at the other. Each is a Roblox avatar dressed the way the owner chose, in the
-- bakery's pink apron, with a name tag.

-- A spot in front of a piece, facing it. side -1 and 1 are its front corners, and 0 is
-- the middle of its front.
local function spotBy(plot, thing, side)
	local rect = thing.Rect
	local size = Vector3.new(rect.MaxX - rect.MinX, 0, rect.MaxZ - rect.MinZ)
	local across = Vector3.new(thing.Facing.Z, 0, -thing.Facing.X)
	local center = Layout.Center(rect)
	local spot = center
		+ thing.Facing * (math.abs(size:Dot(thing.Facing)) / 2 + 1.5)
		+ across * side * (math.abs(size:Dot(across)) / 2 + 1.5)
	local position = floorPoint(plot, spot, CUSTOMER_HEIGHT)
	return CFrame.lookAt(position, floorPoint(plot, center, CUSTOMER_HEIGHT))
end

-- "donuts", or "donut" for one. Every treat's name takes an "s".
local function treatWord(recipe, count)
	return recipe.Name:lower() .. (count == 1 and "" or "s")
end

-- Where an employee stands to use an oven, which is also where they wait at the regular oven.
local function ovenSpot(plot, data, slot, ovenId)
	return spotBy(plot, stationThing(plot, data, ovenId or "Oven"), slot == 1 and 1 or -1)
end

-- Builds, dresses and names employees, and handles the Employees menu. It's a function so
-- its locals don't count toward the script's limit of 200.
local function setUpEmployees()
	local TextService = game:GetService("TextService")
	local APRON = Color3.fromRGB(240, 150, 175)
	local BODY_COLORS = { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" }
	local actionEvent = remote("EmployeeAction")
	local nextAction = {}

	-- A short text for a look, so a model can tell whether it's wearing the saved one.
	local function lookKey(look)
		local parts = {}
		for _, category in Config.Wardrobe do
			table.insert(parts, tostring(look[category.Id]))
		end
		return table.concat(parts, "|")
	end

	local function describe(look)
		local description = Instance.new("HumanoidDescription")
		local skin = Config.WardrobeItem("Skin", look.Skin).Color
		for _, field in BODY_COLORS do
			description[field] = skin
		end
		description.Shirt = look.Shirt
		description.Pants = look.Pants
		local accessories = { { AssetId = look.Hair, AccessoryType = Enum.AccessoryType.Hair } }
		if look.Hat ~= 0 then
			table.insert(accessories, { AssetId = look.Hat, AccessoryType = Enum.AccessoryType.Hat })
		end
		description:SetAccessories(accessories, true)
		return description
	end

	-- Like the townsfolk looks: nothing collides, and the root is anchored and moved by
	-- tweening. Run again after a change of clothes, which can add parts.
	local function prepare(model)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.Massless = true
			end
		end
		local root = model.HumanoidRootPart
		root.Anchored = true
		root.Massless = false
		model.PrimaryPart = root
	end

	local function apronPart(model, bodyPartName, name, size, offset)
		local bodyPart = model[bodyPartName]
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = APRON
		part.Material = Enum.Material.SmoothPlastic
		part.CFrame = bodyPart.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = bodyPart
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end

	-- A new avatar in a look, wearing the apron. If Roblox can't build it, a townsperson's
	-- look stands in.
	local function build(look)
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(describe(look), Enum.HumanoidRigType.R15)
		end)
		if not ok then
			warn("BakerySystem: could not build an employee: " .. tostring(model))
			return LOOKS.People:GetChildren()[1]:Clone()
		end
		local animate = model:FindFirstChild("Animate")
		if animate then
			animate:Destroy()
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.EvaluateStateMachine = false
		apronPart(model, "UpperTorso", "ApronBib", Vector3.new(1.3, 1, 0.08), CFrame.new(0, -0.2, -0.62))
		apronPart(model, "LowerTorso", "ApronSkirt", Vector3.new(1.7, 1.3, 0.08), CFrame.new(0, -0.35, -0.6))
		prepare(model)
		return model
	end

	-- The name tag reads "Maple · Cashier". Until a name has been filtered, it says Employee.
	local function showName(plot, data, slot)
		local employee = data.Employees[slot]
		local model = plot.helpersFolder:FindFirstChild("Employee" .. slot)
		local tag = model and model.PrimaryPart.Bubble:FindFirstChild("NameTag")
		if employee and tag then
			local name = plot.employeeNames[slot]
			local shown = name and name.Raw == employee.Name and name.Shown or "Employee"
			tag.Text = ("%s · %s"):format(shown, employee.Job)
		end
	end

	-- Names are what the owner typed, so everyone sees them filtered by Roblox.
	local function filterName(plot, slot, raw)
		local entry = { Raw = raw, Shown = nil }
		plot.employeeNames[slot] = entry
		local ownerId = plot.ownerId
		local ok, shown = pcall(function()
			return TextService:FilterStringAsync(raw, ownerId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
		end)
		if not ok then
			warn("BakerySystem: could not filter an employee's name: " .. tostring(shown))
		end
		if plot.employeeNames[slot] ~= entry or not plot.owner then
			return
		end
		entry.Shown = ok and shown or nil
		local data = PlayerData.Get(plot.owner)
		if data then
			showName(plot, data, slot)
			syncStats(plot.owner)
		end
	end

	-- Puts an employee in their saved look. If the look changes again while they change,
	-- they change once more afterwards. The client's preview reloads when LookKey changes.
	local function dress(plot, slot)
		if plot.dressing[slot] then
			return
		end
		plot.dressing[slot] = true
		while true do
			local data = plot.owner and PlayerData.Get(plot.owner)
			local employee = data and data.Employees[slot]
			local model = plot.helpersFolder:FindFirstChild("Employee" .. slot)
			local key = employee and lookKey(employee.Look)
			if not model or not key or model:GetAttribute("LookKey") == key then
				break
			end
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local ok, err = pcall(function()
				humanoid:ApplyDescription(describe(employee.Look))
			end)
			if not ok then
				warn("BakerySystem: could not dress an employee: " .. tostring(err))
			end
			if model.Parent then
				prepare(model)
			end
			model:SetAttribute("LookKey", key)
		end
		plot.dressing[slot] = nil
	end

	-- Hired employees appear at the oven. After that they walk wherever their work takes
	-- them. Their name tag, job and look follow the save.
	refreshEmployees = function(plot, data)
		for slot, employee in data.Employees do
			local name = "Employee" .. slot
			local model = plot.helpersFolder:FindFirstChild(name)
			if not model and not plot.building[slot] then
				plot.building[slot] = true
				local session = plot.session
				local key = lookKey(employee.Look)
				task.spawn(function()
					local look = build(employee.Look)
					if plot.session ~= session then
						look:Destroy()
						return
					end
					plot.building[slot] = nil
					local built, label = buildPerson(name, look, true)
					-- The bubble sits above the name tag, and both stay just above the head
					-- however far away the camera is.
					local bubble = label.Parent
					bubble.Size = UDim2.fromOffset(170, 64)
					bubble.StudsOffset = Vector3.new(0, 2.8, 0)
					bubble.SizeOffset = Vector2.new(0, 0.5)
					label.Size = UDim2.new(1, 0, 0, 38)
					local tag = Instance.new("TextLabel")
					tag.Name = "NameTag"
					tag.Size = UDim2.new(1, 0, 0, 22)
					tag.Position = UDim2.fromOffset(0, 42)
					tag.BackgroundColor3 = APRON
					tag.Font = Enum.Font.FredokaOne
					tag.TextScaled = true
					tag.TextColor3 = Color3.new(1, 1, 1)
					local corner = Instance.new("UICorner")
					corner.CornerRadius = UDim.new(0.4, 0)
					corner.Parent = tag
					tag.Parent = bubble
					built:SetAttribute("Slot", slot)
					built:SetAttribute("LookKey", key)
					built:PivotTo(ovenSpot(plot, data, slot))
					-- The client plays their walk and idle animations, like the townsfolk's.
					CollectionService:AddTag(built, "Helper")
					built.Parent = plot.helpersFolder
					local current = plot.owner and PlayerData.Get(plot.owner)
					if current then
						refreshEmployees(plot, current)
					end
				end)
			elseif model then
				model:SetAttribute("Job", employee.Job)
				if model:GetAttribute("LookKey") ~= lookKey(employee.Look) then
					task.spawn(dress, plot, slot)
				end
			end
			local filtered = plot.employeeNames[slot]
			if not filtered or filtered.Raw ~= employee.Name then
				task.spawn(filterName, plot, slot, employee.Name)
			end
			showName(plot, data, slot)
		end
	end

	-- The Employees menu: Hire, Train, SetJob (swapping with whoever had that job),
	-- SetLook (a wardrobe category and item) and Rename. Only for the player's own bakery.
	actionEvent.OnServerEvent:Connect(function(player, kind, slot, value, extra)
		local data = PlayerData.Get(player)
		local plot = playerPlots[player]
		if not data or not plot or os.clock() < (nextAction[player] or 0) then
			return
		end
		nextAction[player] = os.clock() + 0.1
		local employee = type(slot) == "number" and data.Employees[slot] or nil
		if kind == "Hire" then
			local cost = Config.Employees.HireCost[#data.Employees + 1]
			if not cost or not buy(player, data, cost) then
				return
			end
			local hire = PlayerData.NewEmployee(data.Employees)
			table.insert(data.Employees, hire)
			notify(player, ("Welcome, %s! They'll work as your %s. Tap them in Employees to change that"):format(hire.Name, hire.Job:lower()), "Coin")
		elseif not employee then
			return
		elseif kind == "Train" then
			if employee.Trained or not buy(player, data, Config.Employees.TrainCost) then
				return
			end
			employee.Trained = true
			notify(player, "Training done! They walk faster, and check customers out faster", "Coin")
		elseif kind == "SetJob" then
			if type(value) ~= "string" or not table.find(Config.Employees.Jobs, value) or employee.Job == value then
				return
			end
			for _, other in data.Employees do
				if other ~= employee and other.Job == value then
					other.Job = employee.Job
				end
			end
			employee.Job = value
		elseif kind == "SetLook" then
			if type(value) ~= "string" or not Config.WardrobeItem(value, extra) then
				return
			end
			employee.Look[value] = extra
		elseif kind == "Rename" then
			local name = PlayerData.CleanName(value)
			if not name or name == employee.Name then
				return
			end
			employee.Name = name
		else
			return
		end
		refreshEmployees(plot, data)
		syncStats(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		nextAction[player] = nil
	end)
end
setUpEmployees()

-- Walks an employee somewhere and turns them to face the way the spot faces. Returns false
-- when the owner has left on the way, so the employee's job ends.
local function helperWalk(plot, session, model, spot, speed)
	walkAround(model, spot.Position, speed)
	if plot.session ~= session or not model.Parent then
		return false
	end
	model:PivotTo(spot)
	return true
end

-- Sends an employee back to wait at the regular oven when they've wandered off, for
-- example after a job or after the oven moved.
local function helperGoHome(plot, session, model, data, slot, speed)
	local home = ovenSpot(plot, data, slot)
	if (model.PrimaryPart.Position - home.Position).Magnitude > 1 then
		helperWalk(plot, session, model, home, speed)
	end
end

local function firstOven(plot, data, state)
	for _, oven in ownedOvens(plot, data) do
		if oven.state == state and (state ~= "ready" or oven.count > 0) then
			return oven
		end
	end
	return nil
end

-- The Stocker holds the treats they're carrying on a tray, like the one you carry.
local function setHelperTray(model, recipeIndex)
	local old = model:FindFirstChild("CarriedTray")
	if old then
		old:Destroy()
	end
	if not recipeIndex then
		return
	end
	local root = model.PrimaryPart
	local tray = Instance.new("Part")
	tray.Name = "CarriedTray"
	tray.Size = Vector3.new(2.6, 0.25, 1.6)
	tray.Color = Color3.fromRGB(240, 150, 175)
	tray.CanCollide = false
	tray.CanQuery = false
	tray.CanTouch = false
	tray.Massless = true
	tray.CFrame = root.CFrame * CFrame.new(0, 0.2, -1.6)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = tray
	weld.Parent = tray
	local treat = ItemBuilder.Build(Config.Recipes[recipeIndex], TRAY_ITEM_SCALE, tray.CFrame * CFrame.new(0, tray.Size.Y / 2 + 0.1, 0))
	local treatWeld = Instance.new("WeldConstraint")
	treatWeld.Part0 = tray
	treatWeld.Part1 = treat.PrimaryPart
	treatWeld.Parent = treat.PrimaryPart
	treat.Parent = tray
	tray.Parent = model
end

-- A random unlocked recipe there are ingredients for, or nil when there's none.
local function randomBakeable(data)
	local bakeable = {}
	for index = 1, data.RecipesUnlocked do
		if not missingIngredients(data, Config.Recipes[index]) then
			table.insert(bakeable, Config.Recipes[index])
		end
	end
	return bakeable[math.random(math.max(#bakeable, 1))]
end

local function caseRoom(plot, data)
	local room = 0
	for key, case in plot.cases do
		room += #case.slots - #data.Stock[key]
	end
	return room
end

-- The nearest display case with room left.
local function caseWithRoom(plot, data, from)
	local best, bestDistance = nil, math.huge
	for key, case in plot.cases do
		local distance = (case.stand - from).Magnitude
		if #data.Stock[key] < #case.slots and distance < bestDistance then
			best, bestDistance = key, distance
		end
	end
	return best
end

-- One loop for each employee slot. Each pass does one whole task of the employee's job, so
-- a new job starts once the current task is done. Returns when the owner leaves.
--
-- The Baker fetches ingredients from the pantry shelf, carries them to an empty oven, and
-- bakes a random treat you have ingredients for once they're standing at it.
--
-- The Stocker takes as much of a finished batch as the cases have room for, walks it to
-- the cases one at a time, and puts each treat in when they get there. Treats they're
-- still carrying when the cases fill up wait on their tray until there's room again, even
-- if their job changes. What they carry is lost if the owner leaves, like a batch left in
-- an oven.
--
-- The Cashier stands behind the register and checks out whoever is first in line.
local function runEmployee(plot, session, player, slot)
	local carrying = nil
	while plot.session == session do
		task.wait(0.25)
		local data = PlayerData.Get(player)
		if plot.session ~= session or not data then
			return
		end
		local employee = data.Employees[slot]
		local model = plot.helpersFolder:FindFirstChild("Employee" .. slot)
		local job = employee and (carrying and "Stocker" or employee.Job)
		if plot.cashierSlot == slot and job ~= "Cashier" then
			plot.cashierSlot, plot.cashierReady = nil, false
			checkout.update(plot)
		end
		if employee and model and model.PrimaryPart then
			local speed = employee.Trained and Config.Employees.TrainedWalkSpeed or Config.Employees.WalkSpeed
			local label = model.PrimaryPart.Bubble.Label
			if job == "Baker" then
				local recipe = randomBakeable(data)
				local oven = recipe and firstOven(plot, data, "idle")
				if oven then
					say(label, "Getting ingredients")
					if not helperWalk(plot, session, model, spotBy(plot, stationThing(plot, data, "Pantry"), 0), speed) then
						return
					end
					task.wait(0.5)
					say(label, "Baking " .. treatWord(recipe, 2))
					if not helperWalk(plot, session, model, ovenSpot(plot, data, slot, oven.model.Name), speed) then
						return
					end
					-- You may have used the oven or the ingredients while the Baker was walking.
					-- If that treat can't be baked now, they bake another one they can.
					if missingIngredients(data, recipe) then
						recipe = randomBakeable(data)
					end
					if oven.state == "idle" and hasStation(data, oven.model.Name) and recipe then
						startBake(plot, oven, player, recipe)
					end
					label.Visible = false
				else
					helperGoHome(plot, session, model, data, slot, speed)
				end
			elseif job == "Stocker" then
				local oven = not carrying and caseRoom(plot, data) > 0 and firstOven(plot, data, "ready")
				if oven then
					say(label, "Fetching treats")
					if not helperWalk(plot, session, model, ovenSpot(plot, data, slot, oven.model.Name), speed) then
						return
					end
					-- You may have collected the batch while the Stocker was walking.
					local take = oven.state == "ready" and math.min(oven.count, caseRoom(plot, data)) or 0
					if take > 0 then
						carrying = { Recipe = table.find(Config.Recipes, oven.recipe), Count = take }
						oven.count -= take
						if oven.count == 0 then
							resetOven(oven)
						else
							oven.prompt.ActionText = ("Collect %d %s"):format(oven.count, oven.recipe.Name)
						end
						setHelperTray(model, carrying.Recipe)
						syncStats(player)
					end
				end
				local key = carrying and caseWithRoom(plot, data, model.PrimaryPart.Position)
				if key then
					local recipe = Config.Recipes[carrying.Recipe]
					if employee.Job == "Stocker" then
						say(label, ("Carrying %d %s"):format(carrying.Count, treatWord(recipe, carrying.Count)))
					else
						say(label, "Finishing up")
					end
					local target = plot.cases[key]
					local facing = Vector3.new(target.origin.Position.X, target.stand.Y, target.origin.Position.Z)
					if not helperWalk(plot, session, model, CFrame.lookAt(target.stand, facing), speed) then
						return
					end
					-- The case may have been moved, stored or filled while the Stocker walked.
					local case, stock = plot.cases[key], data.Stock[key]
					if case and stock then
						while carrying.Count > 0 and #stock < #case.slots do
							table.insert(stock, carrying.Recipe)
							carrying.Count -= 1
						end
						refreshCase(plot, data, key)
						syncStats(player)
					end
					if carrying.Count == 0 then
						carrying = nil
						setHelperTray(model, nil)
						label.Visible = false
					end
				elseif not oven then
					if carrying then
						say(label, "Cases are full!")
					end
					helperGoHome(plot, session, model, data, slot, speed)
				end
			elseif job == "Cashier" then
				local spot = checkout.cashierSpot(plot, data)
				if (model.PrimaryPart.Position - spot.Position).Magnitude > 1 then
					if plot.cashierReady then
						plot.cashierReady = false
						checkout.update(plot)
					end
					say(label, "Off to the register")
					if not helperWalk(plot, session, model, spot, speed) then
						return
					end
					label.Visible = false
				else
					if not plot.cashierReady then
						plot.cashierSlot, plot.cashierReady = slot, true
						checkout.update(plot)
					end
					local front = plot.line[1]
					if front and front.atSpot then
						say(label, "Ringing you up!")
						task.wait(employee.Trained and Config.Employees.TrainedCheckoutTime or Config.Employees.CheckoutTime)
						if plot.session ~= session then
							return
						end
						-- You may have checked them out yourself, or changed this job, meanwhile.
						if plot.line[1] == front and data.Employees[slot] == employee and employee.Job == "Cashier" then
							checkout.checkOut(plot)
						end
						label.Visible = false
					end
				end
			else
				helperGoHome(plot, session, model, data, slot, speed)
			end
		end
	end
end

-- Plots
local function sendToPlot(player, plot)
	local character = player.Character
	if character and plot then
		character:PivotTo(plot.playerSpawn.CFrame + Vector3.new(0, 4, 0))
	end
end

-- Bake Together. A player asks at another bakery's door, and its owner answers in a
-- popup. It's in a block so its locals don't count toward the script's limit of 200.
-- Only buildDoorPrompt and endCoBakingFor are used outside it.
local buildDoorPrompt, endCoBakingFor
do
	local coBakeRequestEvent = remote("CoBakeRequest")
	local answerCoBakeEvent = remote("AnswerCoBake")
	local leaveCoBakeEvent = remote("LeaveCoBake")
	local removeCoBakerEvent = remote("RemoveCoBaker")
	-- Open asks by the player asking, and when each player last asked.
	local requests = {}
	local lastAsk = {}
	local nextRequestId = 0

	-- leaving is true when the player is leaving the game, so they aren't sent anywhere.
	local function stopCoBaking(player, leaving)
		local plot = coBakers[player]
		if not plot then
			return
		end
		coBakers[player] = nil
		lastAction[player] = nil
		player:SetAttribute("CoBaking", nil)
		if not leaving then
			sendToPlot(player, playerPlots[player])
			syncStats(player)
		end
		if plot.owner then
			syncStats(plot.owner)
		end
	end

	local function startCoBaking(player, plot)
		local owner = plot.owner
		coBakers[player] = plot
		markActive(player)
		player:SetAttribute("CoBaking", plot.model.Name)
		sendToPlot(player, plot)
		notify(player, ("You're baking with %s! Bake, fill their cases and pack their orders"):format(owner.DisplayName), "Ding")
		notify(owner, ("%s is baking with you!"):format(player.DisplayName), "Ding")
		syncStats(owner)
	end

	-- Why a player can't join this bakery right now, or nil if they can. An empty string
	-- means there's nothing worth telling them.
	local function coBakeProblem(player, plot)
		local owner = plot.owner
		if not owner or owner == player or not player.Parent then
			return ""
		end
		if coBakers[player] == plot then
			return "You're already baking here"
		end
		if coBakers[player] then
			return ("You're baking with %s. Stop in the Friends menu first"):format(coBakers[player].owner.DisplayName)
		end
		if #coBakersOf(plot) >= Config.CoBake.Max then
			return ("%s's bakery already has %d co-bakers"):format(owner.DisplayName, Config.CoBake.Max)
		end
		return nil
	end

	local function askToCoBake(player, plot)
		if not plot.doorPart or not isNear(player, plot.doorPart.Position, plot.doorPart.Prompt.MaxActivationDistance + REACH_BUFFER) then
			return
		end
		local problem = coBakeProblem(player, plot)
		if problem then
			if problem ~= "" then
				notify(player, problem)
			end
			return
		end
		local owner = plot.owner
		if requests[player] then
			notify(player, ("Waiting for %s to answer..."):format(requests[player].owner.DisplayName))
			return
		end
		local wait = Config.CoBake.AskCooldown - (os.clock() - (lastAsk[player] or -math.huge))
		if wait > 0 then
			notify(player, ("Wait %d seconds before asking again"):format(math.ceil(wait)))
			return
		end
		-- An owner answers one request at a time.
		for _, request in requests do
			if request.owner == owner then
				notify(player, ("%s is answering someone else. Try again in a moment"):format(owner.DisplayName))
				return
			end
		end
		lastAsk[player] = os.clock()
		nextRequestId += 1
		local request = { id = nextRequestId, owner = owner, plot = plot }
		requests[player] = request
		coBakeRequestEvent:FireClient(owner, { Id = request.id, Name = player.DisplayName, Seconds = Config.CoBake.AnswerSeconds })
		notify(player, ("Asked %s. Waiting for an answer..."):format(owner.DisplayName))
		task.delay(Config.CoBake.AnswerSeconds, function()
			if requests[player] == request then
				requests[player] = nil
				notify(player, ("%s didn't answer this time"):format(owner.DisplayName))
			end
		end)
	end

	answerCoBakeEvent.OnServerEvent:Connect(function(owner, id, yes)
		if type(id) ~= "number" or type(yes) ~= "boolean" then
			return
		end
		for asker, request in requests do
			if request.id == id and request.owner == owner then
				requests[asker] = nil
				if not yes then
					notify(asker, ("%s said no thanks this time"):format(owner.DisplayName))
					return
				end
				if request.plot.owner ~= owner then
					return
				end
				local problem = coBakeProblem(asker, request.plot)
				if problem then
					if problem ~= "" then
						notify(asker, problem)
						notify(owner, ("%s can't join right now"):format(asker.DisplayName))
					end
					return
				end
				startCoBaking(asker, request.plot)
				return
			end
		end
	end)

	leaveCoBakeEvent.OnServerEvent:Connect(function(player)
		local plot = coBakers[player]
		if not plot then
			return
		end
		local owner = plot.owner
		stopCoBaking(player)
		notify(player, "You're back in your own bakery")
		if owner then
			notify(owner, ("%s stopped baking with you"):format(player.DisplayName))
		end
	end)

	removeCoBakerEvent.OnServerEvent:Connect(function(owner, userId)
		local plot = playerPlots[owner]
		if not plot or type(userId) ~= "number" then
			return
		end
		for _, coBaker in coBakersOf(plot) do
			if coBaker.UserId == userId then
				stopCoBaking(coBaker)
				notify(coBaker, ("%s finished baking together for now. You're back in your own bakery"):format(owner.DisplayName))
				notify(owner, ("%s isn't baking with you any more"):format(coBaker.DisplayName))
			end
		end
	end)

	-- Ends everything a leaving player is part of: co-baking somewhere, their own co-bakers,
	-- and open requests.
	function endCoBakingFor(player)
		local plot = coBakers[player]
		if plot then
			stopCoBaking(player, true)
			if plot.owner then
				notify(plot.owner, ("%s left Sweetopia, so they've stopped baking with you"):format(player.DisplayName))
			end
		end
		local own = playerPlots[player]
		for _, coBaker in own and coBakersOf(own) or {} do
			stopCoBaking(coBaker)
			notify(coBaker, ("%s left Sweetopia, so you're back in your own bakery"):format(player.DisplayName))
		end
		requests[player] = nil
		for asker, request in requests do
			if request.owner == player then
				requests[asker] = nil
				notify(asker, ("%s left Sweetopia"):format(player.DisplayName))
			end
		end
		lastAsk[player] = nil
	end

	-- An invisible spot in the doorway with the "Ask to Bake Together" prompt, which the
	-- client shows only to other players.
	function buildDoorPrompt(plot)
		local part = Instance.new("Part")
		part.Name = "BakeTogether"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(1, 1, 1)
		part.CFrame = plot.door * CFrame.new(0, 2.5, 0)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Prompt"
		prompt.ActionText = "Ask to Bake Together"
		prompt.ObjectText = plot.owner.DisplayName .. "'s Bakery"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Active", true)
		prompt:SetAttribute("Door", true)
		prompt.Triggered:Connect(function(player)
			askToCoBake(player, plot)
		end)
		prompt.Parent = part
		part.Parent = plot.model
		return part
	end
end

local function claimPlot(player)
	for _, plot in plots do
		if not plot.ownerId then
			local data = PlayerData.Get(player)
			plot.owner = player
			plot.ownerId = player.UserId
			plot.session += 1
			plot.model:SetAttribute("OwnerId", player.UserId)
			plot.signLabel.Text = player.DisplayName .. "'s Bakery"
			playerPlots[player] = plot
			for _, oven in plot.ovens do
				resetOven(oven)
				setActive(oven.prompt, true)
			end
			setActive(plot.cookbookPrompt, true)
			setActive(plot.pantryPrompt, true)
			setActive(plot.packingPrompt, true)
			applyExpansion(plot, data.Expansion)
			applyPaint(plot, data)
			showBoughtStations(plot, data)
			placeStations(plot, data)
			for key in data.Placed do
				buildPlaced(plot, data, key)
			end
			for slot = 1, #Config.DeliveryTiers do
				fillOrder(plot, data, slot)
			end
			task.spawn(runCustomerSpawner, plot, plot.session, player)
			task.spawn(runBakeSale, plot, plot.session, player)
			plot.flyers, plot.flyersReadyAt = 0, 0
			plot.flyerStand = buildFlyerStand(plot)
			task.spawn(runFlyers, plot, plot.session)
			plot.doorPart = buildDoorPrompt(plot)
			refreshEmployees(plot, data)
			for slot = 1, Config.Employees.Max do
				task.spawn(runEmployee, plot, plot.session, player, slot)
			end
			task.spawn(runCrates, plot, plot.session, player)
			return plot
		end
	end
	return nil
end

local function releasePlot(player)
	local plot = playerPlots[player]
	playerPlots[player] = nil
	if not plot then
		return
	end
	plot.owner = nil
	plot.ownerId = nil
	plot.session += 1
	plot.model:SetAttribute("OwnerId", nil)
	plot.signLabel.Text = "Empty Bakery"
	for _, oven in plot.ovens do
		resetOven(oven)
		setActive(oven.prompt, false)
	end
	setActive(plot.cookbookPrompt, false)
	setActive(plot.pantryPrompt, false)
	setActive(plot.packingPrompt, false)
	updatePantryShelf(plot, nil)
	for _, case in plot.cases do
		case.connection:Disconnect()
		case.items:Destroy()
		setActive(case.prompt, false)
	end
	plot.cases = {}
	plot.orders = {}
	plot.placedFolder:ClearAllChildren()
	if plot.doorPart then
		plot.doorPart:Destroy()
		plot.doorPart = nil
	end
	-- Customers on their way or inside see the session change and head back to the plaza.
	plot.seated = {}
	plot.line = {}
	plot.cashierSlot, plot.cashierReady = nil, false
	setActive(plot.registerPrompt, false)
	plot.helpersFolder:ClearAllChildren()
	plot.employeeNames, plot.building, plot.dressing = {}, {}, {}
	showBoughtStations(plot, nil)
	placeStations(plot, nil)
	applyExpansion(plot, 0)
	applyPaint(plot, nil)
	removeCrate(plot)
	showSaleBanner(plot, false)
	removeFlyerStand(plot)
	plot.flyers = 0
	plot.flyerHolder = nil
	updateHeldFlyers(plot)
end

-- Gives exclusive and game pass items to their owners, and removes them from anyone
-- else's save. Owners keep any extra copies they bought.
local function applyExclusiveItems(player, data)
	for _, item in Config.Items do
		if item.OnlyFor or item.Pass then
			local allowed = Config.IsAllowed(item, player.UserId)
				and (not item.Pass or PurchaseHandler.OwnsPass(player, item.Pass))
			if not allowed then
				data.Owned[item.Id] = 0
			elseif item.ExtraCoins then
				data.Owned[item.Id] = math.max(data.Owned[item.Id], 1)
			else
				data.Owned[item.Id] = 1
			end
			if not allowed then
				for key, entry in data.Placed do
					if entry.Id == item.Id then
						data.Placed[key] = nil
						data.Stock[key] = nil
					end
				end
			end
		end
	end
end

local function updateVipTag(player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return
	end
	local tag = head:FindFirstChild("VipTag")
	if player:GetAttribute("VIP") ~= true then
		if tag then
			tag:Destroy()
		end
		return
	end
	if tag then
		return
	end
	tag = Instance.new("BillboardGui")
	tag.Name = "VipTag"
	tag.Size = UDim2.fromOffset(60, 24)
	tag.StudsOffset = Vector3.new(0, 2.8, 0)
	tag.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(235, 175, 60)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "VIP"
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.4, 0)
	corner.Parent = label
	label.Parent = tag
	tag.Parent = head
end

-- The Starter Pack pays out once per account, and only when progress can be saved,
-- so it can't pay out again on a later visit.
local function applyPassRewards(player, data)
	if
		PurchaseHandler.OwnsPass(player, "StarterPack")
		and not data.StarterPackClaimed
		and PlayerData.CanSave(player)
	then
		data.StarterPackClaimed = true
		data.Coins += Config.StarterPack.Coins
		data.Stars += Config.StarterPack.Stars
		notify(
			player,
			("Starter Pack: +%d coins, +%d Sugar Stars"):format(Config.StarterPack.Coins, Config.StarterPack.Stars),
			"Coin"
		)
	end
	player:SetAttribute("VIP", PurchaseHandler.OwnsPass(player, "VIP"))
	updateVipTag(player)
end

-- Customers keep shopping while the owner is away, but only from treats left in cases.
local function sellWhileAway(player, data)
	if data.LastSeen == 0 then
		return
	end
	local away = math.clamp(os.time() - data.LastSeen, 0, Config.OfflineMaxSeconds)
	local visits = math.floor(away / customerInterval(data))
	local sold, coins = 0, 0
	while sold < visits do
		local stocked = {}
		for _, stock in data.Stock do
			if #stock > 0 then
				table.insert(stocked, stock)
			end
		end
		if #stocked == 0 then
			break
		end
		local stock = stocked[math.random(#stocked)]
		local recipeIndex = table.remove(stock, math.random(#stock))
		coins += salePrice(data, Config.Recipes[recipeIndex])
		sold += 1
	end
	if sold > 0 then
		popupEvent:FireClient(player, "Away", { Sold = sold, Coins = earn(player, data, coins) })
	end
end

-- Returns which streak day can be claimed today, or nil if today's reward is taken.
local function dailyStreakDay(data)
	local day = today()
	if data.DailyDay >= day then
		return nil
	end
	if data.DailyDay == day - 1 then
		return data.DailyStreak % #Config.DailyRewards + 1
	end
	return 1
end

-- Only offered when progress can be saved, so a failed load can't hand it out again.
local function offerDaily(player, data)
	local streakDay = PlayerData.CanSave(player) and dailyStreakDay(data)
	if streakDay then
		popupEvent:FireClient(player, "Daily", {
			Day = streakDay,
			Vip = PurchaseHandler.OwnsPass(player, "VIP"),
		})
	end
end

claimDailyEvent.OnServerEvent:Connect(function(player)
	local data = PlayerData.Get(player)
	local streakDay = data and PlayerData.CanSave(player) and dailyStreakDay(data)
	if not streakDay then
		return
	end
	local reward = Config.DailyRewards[streakDay]
	local stars = reward.Stars or 0
	if PurchaseHandler.OwnsPass(player, "VIP") then
		stars += Config.VipDailyStars
	end
	data.Coins += reward.Coins or 0
	data.Stars += stars
	data.DailyDay = today()
	data.DailyStreak = streakDay
	syncStats(player)
	notify(player, ("Day %d reward claimed!"):format(streakDay), "Coin")
end)

claimGoalEvent.OnServerEvent:Connect(function(player, index)
	local data = PlayerData.Get(player)
	if not data or type(index) ~= "number" then
		return
	end
	ensureGoals(data)
	local goal = data.Goals.List[index]
	if not goal or goal.Claimed or goal.Progress < goal.Target then
		return
	end
	goal.Claimed = true
	data.Coins += goal.Reward
	data.Stars += Config.Goals.Stars
	syncStats(player)
	local starWord = Config.Goals.Stars == 1 and "Sugar Star" or "Sugar Stars"
	notify(player, ("Goal complete! +%d coins, +%d %s"):format(goal.Reward, Config.Goals.Stars, starWord), "Coin")
end)

local function onPassGranted(player, pass)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	applyExclusiveItems(player, data)
	applyPassRewards(player, data)
	syncStats(player)
	notify(player, ("Thank you! %s unlocked"):format(pass.Name), "Coin")
end

-- Friend Boost and invite rewards, in a block for the same reason as Bake Together.
local addFriendPairs, removeFriendPairs, checkInvites
do
	-- Friend Boost. Each pair of players is checked once, when the second of them joins.
	function addFriendPairs(player)
		friendPairs[player] = friendPairs[player] or {}
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
				if ok and isFriend and player.Parent and other.Parent and friendPairs[player] then
					friendPairs[player][other] = true
					friendPairs[other] = friendPairs[other] or {}
					friendPairs[other][player] = true
					for _, pair in { { player, other }, { other, player } } do
						local percent = math.floor(friendBoost(pair[1]) * 100 + 0.5)
						notify(pair[1], ("%s is in town! Friend Boost: +%d%% coins"):format(pair[2].DisplayName, percent), "Ding")
						syncStats(pair[1])
					end
				end
			end
		end
	end

	function removeFriendPairs(player)
		for other in friendPairs[player] or {} do
			if friendPairs[other] then
				friendPairs[other][player] = nil
				syncStats(other)
			end
		end
		friendPairs[player] = nil
	end

	-- Invite rewards. A friend's first visit through an invite pays them at once and adds
	-- them to the inviter's record, so each invited friend is only ever counted once. The
	-- inviter collects their Stars whenever they're in a server that can save.
	local DataStoreService = game:GetService("DataStoreService")
	local REFERRAL_HISTORY = 50
	-- Invites waiting to be rewarded, by inviter: { Pending = { userId }, Claimed = { userId } }.
	local referralStore
	do
		local ok, err = pcall(function()
			referralStore = DataStoreService:GetDataStore("Referrals_v1")
		end)
		if not ok then
			warn("BakerySystem: referral store unavailable: " .. tostring(err))
		end
	end

	local function claimReferrals(player)
		local data = PlayerData.Get(player)
		if not referralStore or not data or not PlayerData.CanSave(player) then
			return
		end
		local count = 0
		local ok, err = pcall(function()
			referralStore:UpdateAsync("inviter_" .. player.UserId, function(old)
				count = 0
				if type(old) ~= "table" or type(old.Pending) ~= "table" or #old.Pending == 0 then
					return nil
				end
				old.Claimed = type(old.Claimed) == "table" and old.Claimed or {}
				for _, userId in old.Pending do
					table.insert(old.Claimed, userId)
					count += 1
				end
				old.Pending = {}
				while #old.Claimed > REFERRAL_HISTORY do
					table.remove(old.Claimed, 1)
				end
				return old
			end)
		end)
		if not ok then
			warn(("BakerySystem: could not claim invite rewards for %s: %s"):format(player.Name, tostring(err)))
			return
		end
		local rewarded = math.min(count, math.max(0, Config.Referral.MaxRewards - data.ReferralRewards))
		if rewarded > 0 then
			local stars = rewarded * Config.Referral.Stars
			data.ReferralRewards += rewarded
			data.Stars += stars
			notify(player, ("Thanks for inviting friends to Sweetopia! +%d Sugar Stars"):format(stars), "Coin")
			syncStats(player)
		end
	end

	local function addReferral(inviterId, inviteeId)
		if not referralStore then
			return
		end
		local ok, err = pcall(function()
			referralStore:UpdateAsync("inviter_" .. inviterId, function(old)
				old = type(old) == "table" and old or {}
				old.Pending = type(old.Pending) == "table" and old.Pending or {}
				old.Claimed = type(old.Claimed) == "table" and old.Claimed or {}
				if table.find(old.Pending, inviteeId) or table.find(old.Claimed, inviteeId) then
					return nil
				end
				table.insert(old.Pending, inviteeId)
				return old
			end)
		end)
		if not ok then
			warn(("BakerySystem: could not record an invite from %d: %s"):format(inviterId, tostring(err)))
		end
	end

	-- Only a first visit counts, so players can't rejoin through invites for more Stars.
	local function checkInvite(player, data, loaded)
		if not loaded or data.LastSeen ~= 0 or data.ReferredBy ~= 0 then
			return
		end
		local ok, joinData = pcall(player.GetJoinData, player)
		local inviterId = ok and type(joinData) == "table" and tonumber(joinData.ReferredByPlayerId) or 0
		if inviterId <= 0 or inviterId == player.UserId then
			return
		end
		data.ReferredBy = inviterId
		data.Stars += Config.Referral.Stars
		notify(player, ("Welcome to Sweetopia! Your friend's invite gave you %d Sugar Stars"):format(Config.Referral.Stars), "Coin")
		addReferral(inviterId, player.UserId)
		local inviter = Players:GetPlayerByUserId(inviterId)
		if inviter then
			claimReferrals(inviter)
		end
	end

	-- Pays a first visit through an invite, then collects any invite rewards waiting.
	function checkInvites(player, data, loaded)
		checkInvite(player, data, loaded)
		claimReferrals(player)
	end
end

local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	leaderstats.Parent = player
	task.spawn(addFriendPairs, player)

	player.CharacterAdded:Connect(function()
		carriedTrays[player] = nil
		task.defer(function()
			sendToPlot(player, workPlot(player))
			applyWalkSpeed(player)
			updateVipTag(player)
			if PlayerData.Get(player) then
				syncStats(player)
			end
		end)
	end)

	player:SetAttribute("Hint", "Loading your bakery...")
	local data, loaded = PlayerData.Load(player)
	if not player.Parent then
		return
	end
	PurchaseHandler.LoadPasses(player)
	if not player.Parent then
		return
	end
	applyExclusiveItems(player, data)
	applyPassRewards(player, data)
	if not loaded then
		notify(player, "Your saved progress couldn't load, so this visit won't be saved.")
	end
	sellWhileAway(player, data)
	if data.ShoesRefund then
		notify(
			player,
			("Everyone can run now, so Comfy Shoes are gone from the Shop. You got your %d coins back!"):format(data.ShoesRefund),
			"Coin"
		)
		data.ShoesRefund = nil
	end

	local plot = claimPlot(player)
	syncStats(player)
	sendToPlot(player, plot)
	applyWalkSpeed(player)
	player:SetAttribute("ShowWelcome", not data.TutorialDone)
	offerDaily(player, data)
	task.spawn(function()
		checkInvites(player, data, loaded)
		syncStats(player)
	end)
end

-- A function rather than a loop body, so its locals don't count toward the script's
-- limit of 200.
local function setUpPlot(model)
	local floor = model.Floor
	local helpersFolder = Instance.new("Folder")
	helpersFolder.Name = "Helpers"
	helpersFolder.Parent = model
	local plot = {
		model = model,
		owner = nil,
		ownerId = nil,
		session = 0,
		ovens = { makeOven(model.Oven), makeOven(model.LuxuryOven) },
		cases = {},
		orders = {},
		orderTokens = {},
		cookbookPrompt = model.UpgradeStation.Prompt,
		pantryPrompt = model.PantryShelf.Back.Prompt,
		pantrySlots = model.PantryShelf.Slots,
		packingTable = model.PackingStation.PackingTable,
		packingTop = model.PackingStation.Top,
		packingPrompt = model.PackingStation.PackingTable.Prompt,
		signLabel = model.Sign.SignGui.Label,
		placedFolder = model.Placed,
		floorTop = floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0),
		stations = {},
		stationShapes = {},
		playerSpawn = model.Spots.PlayerSpawn,
		door = floor.CFrame * CFrame.new(0, 0.6, 19),
		-- Where the bakery's path meets the plaza, set by setUpTown.
		mouth = nil,
		-- Customers sitting down, by seat. See seats.
		seated = {},
		-- Customers waiting to pay, first in line first. See checkout.
		line = {},
		-- The register's Body part and its Check out prompt, set up below.
		registerPart = nil,
		registerPrompt = nil,
		-- The slot of the Cashier standing at the register, if one is.
		cashierSlot = nil,
		cashierReady = false,
		-- When the owner may next be told someone is waiting to pay.
		nextLineNotice = 0,
		helpersFolder = helpersFolder,
		-- Each employee slot's name as typed (Raw) and as filtered for everyone (Shown),
		-- and the slots being built or changing clothes.
		employeeNames = {},
		building = {},
		dressing = {},
		-- Outside the door, beside the customer path.
		crateSpot = floor.CFrame * CFrame.new(9, floor.Size.Y / 2, 24),
		crate = nil,
		crateDueAt = 0,
		-- Across the customer path from the crate.
		flyerSpot = floor.CFrame * CFrame.new(-9, floor.Size.Y / 2, 24),
		flyerStand = nil,
		flyers = 0,
		flyersReadyAt = 0,
		-- Who took the stack, and the HeldFlyers model in their hand.
		flyerHolder = nil,
		heldFlyers = nil,
		saleBanner = nil,
	}
	for slot in Config.DeliveryTiers do
		plot.orderTokens[slot] = 0
	end
	-- The walls' starting sizes and spots, and spare floor for bigger bakeries.
	plot.wallStarts = {}
	for _, part in model.Walls:GetChildren() do
		if WALL_GROWTH[part.Name] then
			plot.wallStarts[part] = { Size = part.Size, CFrame = part.CFrame }
		end
	end
	plot.floorExtension = floor:Clone()
	plot.floorExtension.Name = "FloorExtension"
	-- Each paintable wall and oven part's starting colour, by paint target.
	plot.paintParts = {}
	for _, target in Config.PaintTargets do
		local parts = {}
		for _, name in target.Walls or {} do
			parts[model.Walls[name]] = model.Walls[name].Color
		end
		for _, name in target.Oven or {} do
			parts[model.Oven[name]] = model.Oven[name].Color
		end
		plot.paintParts[target.Id] = parts
	end
	for _, station in Layout.Stations do
		setUpStation(plot, station)
	end
	placeStations(plot, nil)
	showBoughtStations(plot, nil)
	for _, oven in plot.ovens do
		setActive(oven.prompt, false)
		oven.prompt.Triggered:Connect(function(player)
			onOvenPrompt(plot, oven, player)
		end)
	end
	setActive(plot.cookbookPrompt, false)
	setActive(plot.pantryPrompt, false)
	setActive(plot.packingPrompt, false)
	-- Co-bakers can use the pantry shelf, the packing table and the register. At the
	-- cookbook counter they see their own recipes and daily goals.
	plot.pantryPrompt:SetAttribute("CoBake", true)
	plot.packingPrompt:SetAttribute("CoBake", true)
	plot.cookbookPrompt:SetAttribute("CoBake", true)
	-- Customers pay when someone taps the register's prompt, or when a Cashier is there.
	plot.registerPart = model.Checkout.Register.Body
	local registerPrompt = Instance.new("ProximityPrompt")
	registerPrompt.Name = "CheckoutPrompt"
	registerPrompt.ActionText = "Check out"
	registerPrompt.ObjectText = "Register"
	registerPrompt.HoldDuration = 0
	registerPrompt.MaxActivationDistance = 10
	registerPrompt.RequiresLineOfSight = false
	registerPrompt:SetAttribute("CoBake", true)
	setActive(registerPrompt, false)
	registerPrompt.Parent = plot.registerPart
	plot.registerPrompt = registerPrompt
	registerPrompt.Triggered:Connect(function(player)
		if canUse(player, plot, registerPrompt) and checkout.checkOut(plot) then
			markActive(player)
		end
	end)
	plot.cookbookPrompt.Triggered:Connect(function(player)
		if canUse(player, plot, plot.cookbookPrompt) then
			openPanelEvent:FireClient(player, "Cookbook")
		end
	end)
	plot.pantryPrompt.Triggered:Connect(function(player)
		if canUse(player, plot, plot.pantryPrompt) then
			openPanelEvent:FireClient(player, "Pantry")
		end
	end)
	plot.packingPrompt.Triggered:Connect(function(player)
		if canUse(player, plot, plot.packingPrompt) then
			openPanelEvent:FireClient(player, "Deliveries")
		end
	end)
	table.insert(plots, plot)
end

for _, model in Workspace:WaitForChild("Plots"):GetChildren() do
	setUpPlot(model)
end
table.sort(plots, function(a, b)
	return a.model.Name < b.model.Name
end)

-- The plaza starts with people already strolling, then more walk in from the edges.
setUpTown()
for _ = 1, Config.Townsfolk.Base do
	spawnPerson(town.strolls[math.random(#town.strolls)].Position)
end
task.spawn(runCrowd)

PurchaseHandler.Start(function(player, product)
	syncStats(player)
	if product.Currency == "Boost" then
		notify(player, ("Thank you! Double coins and customers for %d more minutes"):format(product.Amount), "Coin")
		return
	end
	local unit = product.Currency == "Stars" and "Sugar Stars" or "coins"
	notify(player, ("Thank you! +%d %s"):format(product.Amount, unit), "Coin")
end, onPassGranted)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	endCoBakingFor(player)
	removeFriendPairs(player)
	releasePlot(player)
	carriedTrays[player] = nil
	hotbars[player] = nil
	running[player] = nil
end)
