-- Runs the bakeries: baking, display cases, shopping customers, deliveries,
-- the shop, and placed items. All game state lives on the server.
-- Prompts are always Enabled here; the client shows them based on each prompt's
-- Active attribute and the plot's OwnerId.
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
-- How high a customer's root part sits above the floor.
local CUSTOMER_HEIGHT = 3.1
local CUSTOMER_COLORS = {
	Color3.fromRGB(255, 170, 165),
	Color3.fromRGB(165, 200, 255),
	Color3.fromRGB(190, 230, 170),
	Color3.fromRGB(255, 215, 140),
	Color3.fromRGB(205, 175, 240),
}
local SKIN_COLORS = {
	Color3.fromRGB(255, 220, 185),
	Color3.fromRGB(225, 175, 130),
	Color3.fromRGB(165, 115, 80),
	Color3.fromRGB(110, 75, 55),
}

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

local plots = {}
local playerPlots = {}
local carriedTrays = {}
local hotbars = {}
local refreshHelpers

local function notify(player, text, sound)
	notifyEvent:FireClient(player, text, sound)
end

local function setActive(prompt, active)
	prompt:SetAttribute("Active", active)
end

local function upgradeLevel(data, id)
	return Config.GetUpgrade(id).Levels[data[id .. "Level"]]
end

local function salePrice(data, recipe)
	return math.floor(recipe.Price * (1 + upgradeLevel(data, "Ingredients").PriceBonus))
end

-- 2x Coins and the timed boost each double coins earned from customers and deliveries.
local function coinMultiplier(player, data)
	local multiplier = 1
	if PurchaseHandler.OwnsPass(player, "DoubleCoins") then
		multiplier *= 2
	end
	if data.BoostUntil > os.time() then
		multiplier *= 2
	end
	return multiplier
end

local function earn(player, data, amount)
	local coins = amount * coinMultiplier(player, data)
	data.Coins += coins
	return coins
end

-- Days are counted in UTC, so everyone's new day starts at the same moment.
local function today()
	return os.time() // 86400
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

local function totalCharm(data)
	local charm = 0
	for _, entry in data.Placed do
		charm += Config.GetItem(entry.Id).Charm
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

local function updateGuide(player)
	local plot = playerPlots[player]
	local data = PlayerData.Get(player)
	local hint, target = "", nil
	local ready, idle, baking
	if plot and data then
		for _, oven in ownedOvens(plot, data) do
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
	elseif ready then
		hint = ("Your %s batch is ready! Collect it from the %s"):format(ready.recipe.Name:lower(), ready.name:lower())
		target = ready.model.Name
	elseif trayTotal(data) > 0 then
		local _, case = findCaseWithRoom(plot, data)
		if case then
			hint = "Put your treats in a display case"
			target = case.model.Name
		else
			hint = "Your cases are full! Pack a delivery or wait for customers"
			target = "PackingStation"
		end
	elseif not idle then
		hint = ("Baking %s..."):format(baking.recipe.Name:lower())
	elseif not canBakeAnything(data) then
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

local function syncStats(player)
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

	local levels = {}
	for _, upgrade in Config.Upgrades do
		levels[upgrade.Id] = data[upgrade.Id .. "Level"]
	end
	local plot = playerPlots[player]
	local orders = {}
	if plot then
		updatePantryShelf(plot, data)
		for slot = 1, #Config.DeliveryTiers do
			local order = plot.orders[slot]
			orders[slot] = order or { Waiting = true, Name = Config.DeliveryTiers[slot].Name }
		end
	end
	stateEvent:FireClient(player, {
		Coins = data.Coins,
		Stars = data.Stars,
		RecipesUnlocked = data.RecipesUnlocked,
		Levels = levels,
		Tray = data.Tray,
		TrayCapacity = trayCapacity(data),
		Pantry = data.Pantry,
		PantryCapacity = pantryCapacity(data),
		Hotbar = bar.Slots,
		SelectedSlot = bar.Selected,
		Passes = PurchaseHandler.OwnedPasses(player),
		Multiplier = coinMultiplier(player, data),
		BoostUntil = data.BoostUntil,
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
	})
	updateCarriedTray(player, data)
	updateGuide(player)
end

local function applyWalkSpeed(player)
	local data = PlayerData.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if data and humanoid then
		humanoid.WalkSpeed = upgradeLevel(data, "Shoes").WalkSpeed
	end
end

local function isNear(player, position, reach)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - position).Magnitude <= reach
end

local function canUse(player, plot, prompt)
	if player.UserId ~= plot.ownerId or not prompt:GetAttribute("Active") then
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

-- Callers check missingIngredients first. The batch's ingredients are used up here.
local function startBake(plot, oven, player, recipe)
	local data = PlayerData.Get(player)
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
	addGoalProgress(data, "Bake")
	syncStats(player)

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
		updateGuide(player)
	end)
end

local function onOvenPrompt(plot, oven, player)
	if not canUse(player, plot, oven.prompt) then
		return
	end
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
		syncStats(player)
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
		syncStats(player)
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
	local plot = playerPlots[player]
	local data = PlayerData.Get(player)
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

local function stockCase(plot, player, key)
	local data = PlayerData.Get(player)
	local case = plot.cases[key]
	if not case or not canUse(player, plot, case.prompt) then
		return
	end
	if trayTotal(data) == 0 then
		notify(player, "Your tray is empty. Bake something first!")
		return
	end
	local stock = data.Stock[key]
	if #stock >= #case.slots then
		notify(player, "This case is full")
		return
	end
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
	refreshCase(plot, data, key)
	syncStats(player)
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

-- "New" places an item from storage, "Move" moves a placed item or a station, and
-- "Store" puts a placed item back in storage. Wall pieces also send y, their height.
-- Every spot is checked here, whatever the client's preview said.
placeEvent.OnServerEvent:Connect(function(player, action, id, x, z, r, y)
	local plot = playerPlots[player]
	local data = PlayerData.Get(player)
	if not plot or not data or type(id) ~= "string" then
		return
	end
	if action == "Store" then
		local entry = data.Placed[id]
		if not entry then
			return
		end
		if Config.GetItem(entry.Id).Slots and placedCaseCount(data) <= 1 then
			notify(player, "Keep at least one display case so customers can shop")
		else
			storePlaced(plot, data, id)
			refreshHelpers(plot, data)
		end
		syncStats(player)
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
	refreshHelpers(plot, data)
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
			applyWalkSpeed(player)
			refreshHelpers(plot, data)
			syncStats(player)
			notify(player, upgrade.Name .. " upgraded!", "Coin")
		end
	elseif kind == "Item" and type(id) == "string" then
		local item = Config.GetItem(id)
		if not item or item.OnlyFor or item.Pass then
			return
		end
		local paid
		if item.Stars then
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
				refreshHelpers(plot, data)
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

shipEvent.OnServerEvent:Connect(function(player, slot)
	local plot = playerPlots[player]
	local data = PlayerData.Get(player)
	if not plot or not data or type(slot) ~= "number" then
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
	local earned = earn(player, data, order.Coins)
	data.Stars += order.Stars
	addGoalProgress(data, "Ship")
	data.TutorialDone = true
	queueOrder(plot, player, slot)
	animateBox(plot)
	syncStats(player)
	if order.Stars > 0 then
		local starWord = order.Stars == 1 and "Sugar Star" or "Sugar Stars"
		notify(player, ("Shipped! +%d coins, +%d %s"):format(earned, order.Stars, starWord), "Coin")
	else
		notify(player, ("Shipped! +%d coins"):format(earned), "Coin")
	end
end)

newOrderEvent.OnServerEvent:Connect(function(player, slot)
	local plot = playerPlots[player]
	local data = PlayerData.Get(player)
	if not plot or not data or type(slot) ~= "number" or not Config.DeliveryTiers[slot] then
		return
	end
	if buyWithStars(player, data, Config.NewOrderStars) then
		fillOrder(plot, data, slot)
		syncStats(player)
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

unpackCrateEvent.OnServerEvent:Connect(function(player)
	local plot = playerPlots[player]
	local data = PlayerData.Get(player)
	local crate = plot and plot.crate
	if not crate or not data or not isNear(player, crate.model.PrimaryPart.Position, CRATE_REACH) then
		return
	end
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
	syncStats(player)
	if next(taken) == nil then
		notify(player, "Your pantry is full! Bake something or buy a Bigger Pantry")
	elseif plot.crate then
		notify(player, "Unpacked " .. Config.DescribeIngredients(taken) .. ". The rest didn't fit", "Coin")
	else
		notify(player, "Unpacked " .. Config.DescribeIngredients(taken), "Coin")
	end
end)

-- Customers
local function buildPerson(name, shirt, skin)
	local model = Instance.new("Model")
	model.Name = name

	local root = Instance.new("Part")
	root.Name = "Torso"
	root.Anchored = true
	root.CanCollide = false
	root.Size = Vector3.new(2, 2, 1)
	root.Color = shirt
	root.Parent = model
	model.PrimaryPart = root

	-- Limbs hang from Motor6Ds so the client can swing them while walking.
	local function limb(name, size, offset, color, swing)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.CanCollide = false
		part.Massless = true
		part.CFrame = root.CFrame * offset
		part.Parent = model
		local joint = Instance.new("Motor6D")
		joint.Name = name .. "Joint"
		joint.Part0 = root
		joint.Part1 = part
		local hinge = size.Y / 2
		joint.C0 = offset * CFrame.new(0, hinge, 0)
		joint.C1 = CFrame.new(0, hinge, 0)
		if swing then
			joint:SetAttribute("Swing", swing)
		end
		joint.Parent = root
		return part
	end

	local head = limb("Head", Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 1.7, 0), skin)
	limb("LeftArm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 0, 0), skin, -1)
	limb("RightArm", Vector3.new(1, 2, 1), CFrame.new(1.5, 0, 0), skin, 1)
	limb("LeftLeg", Vector3.new(0.95, 2, 1), CFrame.new(-0.5, -2, 0), Color3.fromRGB(80, 80, 110), 1)
	limb("RightLeg", Vector3.new(0.95, 2, 1), CFrame.new(0.5, -2, 0), Color3.fromRGB(80, 80, 110), -1)
	local face = Instance.new("Decal")
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

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

-- Golden customers wear a crown and sparkle.
local function buildCustomer(golden)
	local shirt = CUSTOMER_COLORS[math.random(#CUSTOMER_COLORS)]
	local skin = SKIN_COLORS[math.random(#SKIN_COLORS)]
	local model, label = buildPerson("Customer", shirt, skin)
	if golden then
		local head = model.Head
		local crown = Instance.new("Part")
		crown.Name = "Crown"
		crown.Size = Vector3.new(1.1, 0.5, 1.1)
		crown.Color = Color3.fromRGB(255, 200, 60)
		crown.Material = Enum.Material.Foil
		crown.CanCollide = false
		crown.Massless = true
		crown.CFrame = head.CFrame * CFrame.new(0, 0.95, 0)
		-- A joint with a fixed offset, like the limbs, so the crown follows the head after
		-- the customer is moved into place.
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
local function walkCustomer(model, to, speed)
	local root = model.PrimaryPart
	local from = root.Position
	local distance = (to - from).Magnitude
	if distance < 0.1 then
		return
	end
	local duration = distance / (speed or Config.CustomerSpeed)
	root.CFrame = CFrame.lookAt(from, to)
	model:SetAttribute("Walking", true)
	local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(to, to + (to - from)),
	})
	tween:Play()
	task.wait(duration)
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
local function walkAround(model, to, speed, outside)
	local path = PathfindingService:CreatePath(PATH_SETTINGS)
	local ok = pcall(function()
		path:ComputeAsync(model.PrimaryPart.Position - PATH_GROUND, to - PATH_GROUND)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		for index = 2, #waypoints do
			if not model.Parent then
				return
			end
			local point = waypoints[index].Position
			walkCustomer(model, outside and groundPoint(point) or Vector3.new(point.X, to.Y, point.Z), speed)
		end
	end
	if model.Parent then
		walkCustomer(model, to, speed)
	end
end

-- A spot along the front of the checkout counter, where customers pay.
local function payPosition(plot, data)
	local thing = stationThing(plot, data, "Checkout")
	local front = thing.Front
	local along = Vector3.new(thing.Facing.Z, 0, -thing.Facing.X)
	local length = math.abs(along:Dot(Vector3.new(front.MaxX - front.MinX, 0, front.MaxZ - front.MinZ)))
	local spread = math.clamp(length / 2 - 1.5, 0, 5)
	local point = Layout.Center(front) + along * (math.random() * 2 - 1) * spread
	return floorPoint(plot, point, CUSTOMER_HEIGHT)
end

local function say(label, text)
	label.Text = text
	label.Visible = true
end

local function pickStockedCase(plot, data)
	local keys = {}
	for key in plot.cases do
		if #data.Stock[key] > 0 then
			table.insert(keys, key)
		end
	end
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

-- Fades a person in (to 0) or out (to 1) at the edge of town.
local function fade(model, to)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then
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

-- Inside a bakery: a stocked case, then the counter to pay. Stops early if the owner leaves.
local function shopAt(plot, session, person)
	local model, label = person.model, person.label
	local function gone()
		return plot.session ~= session
	end

	local owner = plot.owner
	local data = PlayerData.Get(owner)
	local key = data and pickStockedCase(plot, data)
	local recipe
	if key then
		walkAround(model, plot.cases[key].stand, person.speed)
		if gone() then
			return
		end
		say(label, "Hmm, let me see...")
		task.wait(Config.BrowseTime)
		if gone() then
			return
		end
		-- Another customer may have emptied this case, or the owner may have moved it.
		local stock = plot.cases[key] and data.Stock[key]
		if stock and #stock > 0 then
			local recipeIndex = table.remove(stock, math.random(#stock))
			recipe = Config.Recipes[recipeIndex]
			refreshCase(plot, data, key)
			syncStats(owner)
		end
	end

	if recipe then
		say(label, ("Mmm, %s!"):format(recipe.Name:lower()))
		walkAround(model, payPosition(plot, data), person.speed)
		if gone() then
			return
		end
		local price = salePrice(data, recipe)
		local tip = 0
		if person.golden then
			price *= Config.GoldenCustomer.PayScale
			if math.random() < Config.GoldenCustomer.StarChance then
				tip = 1
			end
		end
		local coins = earn(owner, data, price)
		data.Stars += tip
		addGoalProgress(data, "Sell", table.find(Config.Recipes, recipe))
		syncStats(owner)
		if person.golden then
			local tipText = tip > 0 and " and tipped a Sugar Star" or ""
			notify(owner, ("+%d coins: a golden customer bought %s%s!"):format(coins, recipe.Name:lower(), tipText), "Coin")
		else
			notify(owner, ("+%d coins: %s sold"):format(coins, recipe.Name), "Coin")
		end
		say(label, "Thank you!")
		task.wait(0.8)
	else
		say(label, "Nothing to buy!")
		task.wait(1.2)
	end
end

-- Takes a person from wherever they are to a bakery's path, up it and through the door to
-- shop, then back out and down the path to the plaza. If the owner leaves on the way, the
-- person heads back to the plaza.
local function visitBakery(person)
	local plot, session = person.visit, person.visitSession
	local model = person.model
	local door = plot.door.Position + Vector3.new(0, 3, 0)
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
	if plot.session == session then
		plot.visitors -= 1
	end
	person.visit = nil
	person.label.Visible = false
end

-- A person strolls between a few spots, shopping whenever a bakery calls them in, then
-- walks out of town.
local function runPerson(person)
	local model = person.model
	model.Parent = townsfolkFolder
	fade(model, 0)
	local stops = math.random(Config.Townsfolk.Stops[1], Config.Townsfolk.Stops[2])
	while true do
		if person.visit then
			visitBakery(person)
			stops = math.random(Config.Townsfolk.StopsAfterShopping[1], Config.Townsfolk.StopsAfterShopping[2])
		elseif stops <= 0 then
			break
		else
			local spot = pickStroll()
			walkAround(model, spot.Position, person.speed, true)
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
		if part:IsA("BasePart") or part:IsA("Decal") then
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
		leaving = false,
	}
	townsfolk[person] = true
	task.defer(runPerson, person)
	return person
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
	person.visit = plot
	person.visitSession = session
	plot.visitors += 1
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

local function customerInterval(data)
	local speed = 1 + totalCharm(data) * Config.CharmSpeedBonus
	return math.max(Config.CustomerMinInterval, Config.CustomerInterval / speed)
end

local function runCustomerSpawner(plot, session, player)
	while plot.session == session do
		if plot.visitors < Config.MaxCustomers then
			requestCustomer(plot, session)
		end
		local data = PlayerData.Get(player)
		if not data then
			return
		end
		task.wait(customerInterval(data))
	end
end

-- Helpers. They walk to do their jobs: the Baker from the pantry shelf to an empty oven,
-- and the Stocker from a finished oven to the display cases. Between jobs they wait at the
-- regular oven, the Baker at one front corner and the Stocker at the other.
local HELPER_APRON = Color3.fromRGB(255, 255, 255)
local HELPERS = { "Baker", "Stocker" }
local HELPER_SIDES = { Baker = 1, Stocker = -1 }

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

-- Where a helper stands to use an oven, which is also where they wait at the regular oven.
local function ovenSpot(plot, data, id, ovenId)
	return spotBy(plot, stationThing(plot, data, ovenId or "Oven"), HELPER_SIDES[id])
end

-- Hired helpers appear at the oven. After that they walk wherever their work takes them.
refreshHelpers = function(plot, data)
	for _, id in HELPERS do
		if upgradeLevel(data, id).WalkSpeed and not plot.helpersFolder:FindFirstChild(id) then
			local model, label = buildPerson(id, HELPER_APRON, SKIN_COLORS[math.random(#SKIN_COLORS)])
			say(label, id)
			model:PivotTo(ovenSpot(plot, data, id))
			-- The client swings helpers' arms and legs while they walk, like customers'.
			CollectionService:AddTag(model, "Helper")
			model.Parent = plot.helpersFolder
		end
	end
end

-- Walks a helper somewhere and turns them to face the way the spot faces. Returns false
-- when the owner has left on the way, so the helper's job ends.
local function helperWalk(plot, session, model, spot, speed)
	walkAround(model, spot.Position, speed)
	if plot.session ~= session or not model.Parent then
		return false
	end
	model:PivotTo(spot)
	return true
end

-- Sends a helper back to wait at the regular oven when they've wandered off, for example
-- after a job or after the oven moved.
local function helperGoHome(plot, session, model, data, id, speed)
	local home = ovenSpot(plot, data, id)
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

-- The Baker fetches ingredients from the pantry shelf, carries them to an empty oven, and
-- bakes a random treat you have ingredients for once they're standing at it.
local function runBaker(plot, session, player)
	while plot.session == session do
		task.wait(0.5)
		local data = PlayerData.Get(player)
		if plot.session ~= session or not data then
			return
		end
		local speed = upgradeLevel(data, "Baker").WalkSpeed
		local model = plot.helpersFolder:FindFirstChild("Baker")
		if speed and model then
			local label = model.PrimaryPart.Bubble.Label
			local recipe = randomBakeable(data)
			local oven = recipe and firstOven(plot, data, "idle")
			if oven then
				say(label, "Getting ingredients")
				if not helperWalk(plot, session, model, spotBy(plot, stationThing(plot, data, "Pantry"), 0), speed) then
					return
				end
				task.wait(0.5)
				say(label, "Baking " .. treatWord(recipe, 2))
				if not helperWalk(plot, session, model, ovenSpot(plot, data, "Baker", oven.model.Name), speed) then
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
				say(label, "Baker")
			else
				helperGoHome(plot, session, model, data, "Baker", speed)
			end
		end
	end
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

-- The Stocker takes as much of a finished batch as the cases have room for, walks it to
-- the cases one at a time, and puts each treat in when they get there. Treats they're
-- still carrying when the cases fill up wait on their tray until there's room again.
-- What they carry is lost if the owner leaves, like a batch left in an oven.
local function runStocker(plot, session, player)
	local carrying = nil
	while plot.session == session do
		task.wait(0.5)
		local data = PlayerData.Get(player)
		if plot.session ~= session or not data then
			return
		end
		local speed = upgradeLevel(data, "Stocker").WalkSpeed
		local model = plot.helpersFolder:FindFirstChild("Stocker")
		if speed and model then
			local label = model.PrimaryPart.Bubble.Label
			local oven = not carrying and caseRoom(plot, data) > 0 and firstOven(plot, data, "ready")
			if oven then
				say(label, "Fetching treats")
				if not helperWalk(plot, session, model, ovenSpot(plot, data, "Stocker", oven.model.Name), speed) then
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
				say(label, ("Carrying %d %s"):format(carrying.Count, treatWord(recipe, carrying.Count)))
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
					say(label, "Stocker")
				end
			elseif not oven then
				if carrying then
					say(label, "Cases are full!")
				end
				helperGoHome(plot, session, model, data, "Stocker", speed)
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
			refreshHelpers(plot, data)
			task.spawn(runBaker, plot, plot.session, player)
			task.spawn(runStocker, plot, plot.session, player)
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
	-- Customers on their way or inside see the session change and head back to the plaza.
	plot.visitors = 0
	plot.helpersFolder:ClearAllChildren()
	showBoughtStations(plot, nil)
	placeStations(plot, nil)
	applyExpansion(plot, 0)
	applyPaint(plot, nil)
	removeCrate(plot)
end

-- Gives exclusive and game pass items to their owners, and removes them from anyone
-- else's save.
local function applyExclusiveItems(player, data)
	for _, item in Config.Items do
		if item.OnlyFor or item.Pass then
			local allowed = Config.IsAllowed(item, player.UserId)
				and (not item.Pass or PurchaseHandler.OwnsPass(player, item.Pass))
			data.Owned[item.Id] = allowed and 1 or 0
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

local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	leaderstats.Parent = player

	player.CharacterAdded:Connect(function()
		carriedTrays[player] = nil
		task.defer(function()
			sendToPlot(player, playerPlots[player])
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

	local plot = claimPlot(player)
	syncStats(player)
	sendToPlot(player, plot)
	applyWalkSpeed(player)
	player:SetAttribute("ShowWelcome", not data.TutorialDone)
	offerDaily(player, data)
end

for _, model in Workspace:WaitForChild("Plots"):GetChildren() do
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
		-- Customers on their way to the bakery or inside it.
		visitors = 0,
		helpersFolder = helpersFolder,
		-- Outside the door, beside the customer path.
		crateSpot = floor.CFrame * CFrame.new(9, floor.Size.Y / 2, 24),
		crate = nil,
		crateDueAt = 0,
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
		notify(player, ("Thank you! Double coins for %d more minutes"):format(product.Amount), "Coin")
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
	releasePlot(player)
	carriedTrays[player] = nil
	hotbars[player] = nil
end)
