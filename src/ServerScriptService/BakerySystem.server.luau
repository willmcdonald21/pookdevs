-- Runs the bakeries: baking, display cases, shopping customers, deliveries,
-- the shop, and placed items. All game state lives on the server.
-- Prompts are always Enabled here; the client shows them based on each prompt's
-- Active attribute and the plot's OwnerId.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local ItemBuilder = require(ReplicatedStorage:WaitForChild("ItemBuilder"))
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))
local PurchaseHandler = require(ServerScriptService:WaitForChild("PurchaseHandler"))

local REACH_BUFFER = 8
local PANEL_REACH = 25
local SLOT_ITEM_SCALE = 0.5
local TRAY_ITEM_SCALE = 0.6
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

local function trayTotal(data)
	local total = 0
	for _, count in data.Tray do
		total += count
	end
	return total
end

local function placedCount(data, itemId)
	local count = 0
	for _, placedId in data.Placed do
		if placedId == itemId then
			count += 1
		end
	end
	return count
end

local function totalCharm(data)
	local charm = 0
	for _, itemId in data.Placed do
		charm += Config.GetItem(itemId).Charm
	end
	return charm
end

local function canAffordSomething(data)
	local nextRecipe = Config.Recipes[data.RecipesUnlocked + 1]
	if nextRecipe and data.Coins >= nextRecipe.UnlockCost then
		return true
	end
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

local function updateGuide(player)
	local plot = playerPlots[player]
	local data = PlayerData.Get(player)
	local hint, target = "", nil
	if not plot or not data then
		hint = "All bakeries are taken right now. Have a look around!"
	elseif plot.ovenState == "ready" then
		hint = ("Your %s batch is ready! Collect it from the oven"):format(plot.bakeRecipe.Name:lower())
		target = "Oven"
	elseif trayTotal(data) > 0 then
		local _, case = findCaseWithRoom(plot, data)
		if case then
			hint = "Put your treats in a display case"
			target = case.model.Name
		else
			hint = "Your cases are full! Pack a delivery or wait for customers"
			target = "PackingTable"
		end
	elseif plot.ovenState == "baking" then
		hint = ("Baking %s..."):format(plot.bakeRecipe.Name:lower())
	else
		hint = "Choose a treat to bake at the oven"
		target = "Oven"
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
		Hotbar = bar.Slots,
		SelectedSlot = bar.Selected,
		Passes = PurchaseHandler.OwnedPasses(player),
		Multiplier = coinMultiplier(player, data),
		BoostUntil = data.BoostUntil,
		Goals = data.Goals.List,
		Owned = data.Owned,
		Placed = data.Placed,
		Charm = totalCharm(data),
		Orders = orders,
		CanAfford = canAffordSomething(data),
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

-- Oven
local function setOvenWindow(plot, color, material)
	plot.window.Color = color
	plot.window.Material = material
end

local function setBurners(plot, on)
	for _, burner in plot.burners do
		burner.Color = on and Color3.fromRGB(255, 90, 40) or Color3.fromRGB(85, 80, 85)
		burner.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	end
end

local function resetOven(plot)
	plot.ovenState = "idle"
	plot.bakeRecipe = nil
	plot.ovenCount = 0
	plot.finishNow = false
	plot.ovenChangedAt = os.clock()
	plot.ovenPrompt.ActionText = "Bake"
	plot.ovenPrompt.HoldDuration = 0
	plot.ovenStatus.Text = ""
	plot.smoke.Enabled = false
	setOvenWindow(plot, Color3.fromRGB(70, 50, 60), Enum.Material.Glass)
	setBurners(plot, false)
end

local function startBake(plot, player, recipe)
	local data = PlayerData.Get(player)
	local session = plot.session
	plot.ovenState = "baking"
	plot.bakeRecipe = recipe
	plot.ovenCount = upgradeLevel(data, "Batch").BatchSize
	plot.finishNow = false
	plot.ovenPrompt.ActionText = ("Finish Now (%d Star)"):format(Config.FinishBakeStars)
	plot.ovenPrompt.HoldDuration = 0.5
	plot.smoke.Enabled = true
	setOvenWindow(plot, Color3.fromRGB(255, 150, 60), Enum.Material.Neon)
	setBurners(plot, true)
	data.LastRecipe = table.find(Config.Recipes, recipe)
	addGoalProgress(data, "Bake")
	syncStats(player)

	task.spawn(function()
		local finishAt = os.clock() + bakeTime(data, recipe)
		while os.clock() < finishAt and not plot.finishNow do
			if plot.session ~= session then
				return
			end
			plot.ovenStatus.Text = ("Baking... %ds"):format(math.ceil(finishAt - os.clock()))
			task.wait(0.1)
		end
		if plot.session ~= session then
			return
		end
		plot.ovenState = "ready"
		plot.ovenChangedAt = os.clock()
		plot.ovenPrompt.ActionText = ("Collect %d %s"):format(plot.ovenCount, recipe.Name)
		plot.ovenPrompt.HoldDuration = 0
		plot.ovenStatus.Text = "Ready!"
		plot.smoke.Enabled = false
		setOvenWindow(plot, Color3.fromRGB(255, 225, 130), Enum.Material.Neon)
		setBurners(plot, false)
		notify(player, nil, "Ding")
		updateGuide(player)
	end)
end

local function onOvenPrompt(plot, player)
	if not canUse(player, plot, plot.ovenPrompt) then
		return
	end
	local data = PlayerData.Get(player)
	if plot.ovenState == "idle" then
		openPanelEvent:FireClient(player, "Bake")
	elseif plot.ovenState == "baking" then
		if plot.finishNow then
			return
		end
		if data.Stars < Config.FinishBakeStars then
			notify(player, "You need a Sugar Star. Big deliveries earn them!")
			return
		end
		data.Stars -= Config.FinishBakeStars
		plot.finishNow = true
		syncStats(player)
	else
		local space = trayCapacity(data) - trayTotal(data)
		if space <= 0 then
			notify(player, "Your tray is full! Stock a case or pack a delivery first")
			return
		end
		local taken = math.min(space, plot.ovenCount)
		local index = table.find(Config.Recipes, plot.bakeRecipe)
		data.Tray[index] += taken
		plot.ovenCount -= taken
		if plot.ovenCount > 0 then
			plot.ovenPrompt.ActionText = ("Collect %d %s"):format(plot.ovenCount, plot.bakeRecipe.Name)
			notify(player, "Your tray is full! The rest is still in the oven")
		else
			resetOven(plot)
		end
		syncStats(player)
	end
end

bakeEvent.OnServerEvent:Connect(function(player, index)
	local plot = playerPlots[player]
	local data = PlayerData.Get(player)
	if not plot or not data or type(index) ~= "number" then
		return
	end
	local recipe = Config.Recipes[index]
	if not recipe or index > data.RecipesUnlocked or plot.ovenState ~= "idle" then
		return
	end
	if not isNear(player, plot.ovenPrompt.Parent.Position, PANEL_REACH) then
		notify(player, "Go to your oven to bake")
		return
	end
	startBake(plot, player, recipe)
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
local function padOrigin(plot, spot)
	local pad = plot.pads:FindFirstChild(tostring(spot))
	return pad.CFrame * CFrame.new(0, -pad.Size.Y / 2, 0), pad
end

local function buildPlaced(plot, data, spot)
	local key = tostring(spot)
	local item = Config.GetItem(data.Placed[key])
	local origin = padOrigin(plot, spot)
	local model = ItemBuilder.Build(item, 1, origin, not item.Flat)
	ItemBuilder.Anchor(model)
	model.Name = "Placed_" .. key
	if item.Sparkles then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 225, 130)
		sparkles.Parent = model.PrimaryPart
	end
	model.Parent = plot.placedFolder
	if item.Slots then
		local stand = (origin * CFrame.new(0, 3.1, -4.5)).Position
		addCase(plot, key, model, origin, item.Slots, model.PrimaryPart, stand)
		refreshCase(plot, data, key)
	end
end

local function removePlaced(plot, data, key)
	local case = plot.cases[key]
	if case then
		case.connection:Disconnect()
		plot.cases[key] = nil
		for _, recipeIndex in data.Stock[key] do
			data.Tray[recipeIndex] += 1
		end
		data.Stock[key] = nil
	end
	local model = plot.placedFolder:FindFirstChild("Placed_" .. key)
	if model then
		model:Destroy()
	end
	data.Placed[key] = nil
end

placeEvent.OnServerEvent:Connect(function(player, spot, itemId)
	local plot = playerPlots[player]
	local data = PlayerData.Get(player)
	if not plot or not data or type(spot) ~= "number" or spot % 1 ~= 0 then
		return
	end
	if spot < 1 or spot > Config.SpotCount then
		return
	end
	local item
	if itemId ~= nil then
		item = type(itemId) == "string" and Config.GetItem(itemId)
		if not item or placedCount(data, itemId) >= data.Owned[itemId] then
			return
		end
	end
	local key = tostring(spot)
	if data.Placed[key] then
		removePlaced(plot, data, key)
	end
	if item then
		data.Placed[key] = item.Id
		if item.Slots then
			data.Stock[key] = {}
		end
		buildPlaced(plot, data, spot)
	end
	syncStats(player)
end)

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

purchaseEvent.OnServerEvent:Connect(function(player, kind, id)
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
	end
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

local function animateBox(plot)
	local start = plot.packingTable.CFrame * CFrame.new(0, 2.2, 0)
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
	local tween = TweenService:Create(box, TweenInfo.new(1.4, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(plot.hatch.Position) * start.Rotation,
	})
	tween:Play()
	tween.Completed:Connect(function()
		box:Destroy()
	end)
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

local function walkCustomer(model, to)
	local root = model.PrimaryPart
	local from = root.Position
	local distance = (to - from).Magnitude
	if distance < 0.1 then
		return
	end
	local duration = distance / Config.CustomerSpeed
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

-- Walks one customer through: door, a stocked case, the counter to pay, then out.
local function runCustomer(plot, session)
	local golden = math.random() < Config.GoldenCustomer.Chance
	local model, label = buildCustomer(golden)
	local root = model.PrimaryPart
	local start = plot.customerStart.Position + Vector3.new(0, 2.2, 0)
	local door = plot.door.Position + Vector3.new(0, 3, 0)
	root.CFrame = CFrame.new(start)
	model.Parent = plot.customersFolder
	local function gone()
		return plot.session ~= session or not model.Parent
	end

	walkCustomer(model, door)
	if gone() then
		model:Destroy()
		return
	end

	local owner = plot.owner
	local data = PlayerData.Get(owner)
	local key = data and pickStockedCase(plot, data)
	local recipe
	if key then
		walkCustomer(model, plot.cases[key].stand)
		if gone() then
			model:Destroy()
			return
		end
		say(label, "Hmm, let me see...")
		task.wait(Config.BrowseTime)
		if gone() then
			model:Destroy()
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
		local x = math.random(-50, 50) / 10
		walkCustomer(model, plot.customerCounter.Position + plot.counterRight * x + Vector3.new(0, 3, 0))
		if gone() then
			model:Destroy()
			return
		end
		local price = salePrice(data, recipe)
		local tip = 0
		if golden then
			price *= Config.GoldenCustomer.PayScale
			if math.random() < Config.GoldenCustomer.StarChance then
				tip = 1
			end
		end
		local coins = earn(owner, data, price)
		data.Stars += tip
		addGoalProgress(data, "Sell", table.find(Config.Recipes, recipe))
		syncStats(owner)
		if golden then
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
	if gone() then
		model:Destroy()
		return
	end
	walkCustomer(model, door)
	if not gone() then
		label.Visible = false
		walkCustomer(model, start)
	end
	model:Destroy()
end

local function customerInterval(data)
	local speed = 1 + totalCharm(data) * Config.CharmSpeedBonus
	return math.max(Config.CustomerMinInterval, Config.CustomerInterval / speed)
end

local function runCustomerSpawner(plot, session, player)
	while plot.session == session do
		if #plot.customersFolder:GetChildren() < Config.MaxCustomers then
			task.spawn(runCustomer, plot, session)
		end
		local data = PlayerData.Get(player)
		if not data then
			return
		end
		task.wait(customerInterval(data))
	end
end

-- Helpers
local HELPER_APRON = Color3.fromRGB(255, 255, 255)
local HELPERS = { "Baker", "Stocker" }

-- Baker stands beside the oven and Stocker beside the starter case, on the room side.
local function helperSpot(plot, id)
	local target = id == "Baker" and plot.ovenPrompt.Parent or plot.model.DisplayCase.Base
	local floor = plot.model.Floor
	local inward = ((floor.Position - target.Position) * Vector3.new(1, 0, 1)).Unit
	local side = inward:Cross(Vector3.yAxis)
	local position = target.Position + inward * 3 + side * 4
	position = Vector3.new(position.X, floor.Position.Y + floor.Size.Y / 2 + 3, position.Z)
	return CFrame.lookAt(position, position + inward)
end

refreshHelpers = function(plot, data)
	for _, id in HELPERS do
		local hired = upgradeLevel(data, id).Delay ~= nil
		if hired and not plot.helpersFolder:FindFirstChild(id) then
			local model, label = buildPerson(id, HELPER_APRON, SKIN_COLORS[math.random(#SKIN_COLORS)])
			say(label, id)
			model:PivotTo(helperSpot(plot, id))
			model.Parent = plot.helpersFolder
		end
	end
end

-- Moves a finished batch straight from the oven into cases with room.
local function stockFromOven(plot, data)
	local recipeIndex = table.find(Config.Recipes, plot.bakeRecipe)
	local changed = {}
	for key, case in plot.cases do
		local stock = data.Stock[key]
		while plot.ovenCount > 0 and #stock < #case.slots do
			table.insert(stock, recipeIndex)
			plot.ovenCount -= 1
			changed[key] = true
		end
	end
	for key in changed do
		refreshCase(plot, data, key)
	end
	return next(changed) ~= nil
end

local function runHelpers(plot, session, player)
	while plot.session == session do
		task.wait(0.5)
		local data = PlayerData.Get(player)
		if plot.session ~= session or not data then
			return
		end
		local waited = os.clock() - plot.ovenChangedAt
		local stocker = upgradeLevel(data, "Stocker")
		local baker = upgradeLevel(data, "Baker")
		if plot.ovenState == "ready" and stocker.Delay and waited >= stocker.Delay then
			if stockFromOven(plot, data) then
				if plot.ovenCount == 0 then
					resetOven(plot)
				else
					plot.ovenPrompt.ActionText = ("Collect %d %s"):format(plot.ovenCount, plot.bakeRecipe.Name)
				end
				syncStats(player)
			end
		elseif plot.ovenState == "idle" and baker.Delay and waited >= baker.Delay then
			local recipe = Config.Recipes[data.LastRecipe]
			if recipe then
				startBake(plot, player, recipe)
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
			resetOven(plot)
			setActive(plot.ovenPrompt, true)
			setActive(plot.shopPrompt, true)
			setActive(plot.packingPrompt, true)
			local baseCFrame = plot.model.DisplayCase.Base.CFrame
			addCase(
				plot,
				Config.StarterCaseKey,
				plot.model.DisplayCase,
				baseCFrame,
				Config.StarterCaseSlots,
				plot.model.DisplayCase.Base,
				plot.customerCounter.Position + Vector3.new(0, 3, 0)
			)
			refreshCase(plot, data, Config.StarterCaseKey)
			for spot = 1, Config.SpotCount do
				if data.Placed[tostring(spot)] then
					buildPlaced(plot, data, spot)
				end
			end
			for slot = 1, #Config.DeliveryTiers do
				fillOrder(plot, data, slot)
			end
			task.spawn(runCustomerSpawner, plot, plot.session, player)
			refreshHelpers(plot, data)
			task.spawn(runHelpers, plot, plot.session, player)
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
	resetOven(plot)
	setActive(plot.ovenPrompt, false)
	setActive(plot.shopPrompt, false)
	setActive(plot.packingPrompt, false)
	for _, case in plot.cases do
		case.connection:Disconnect()
		case.items:Destroy()
		setActive(case.prompt, false)
	end
	plot.cases = {}
	plot.orders = {}
	plot.placedFolder:ClearAllChildren()
	plot.customersFolder:ClearAllChildren()
	plot.helpersFolder:ClearAllChildren()
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
				for key, placedId in data.Placed do
					if placedId == item.Id then
						data.Placed[key] = nil
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
	local body = model.Oven.Body
	local floor = model.Floor
	local helpersFolder = Instance.new("Folder")
	helpersFolder.Name = "Helpers"
	helpersFolder.Parent = model
	local plot = {
		model = model,
		owner = nil,
		ownerId = nil,
		session = 0,
		ovenState = "idle",
		bakeRecipe = nil,
		ovenCount = 0,
		finishNow = false,
		ovenChangedAt = 0,
		cases = {},
		orders = {},
		orderTokens = {},
		window = model.Oven.Window,
		burners = model.Oven.Burners:GetChildren(),
		smoke = model.Oven.Chimney.Smoke,
		ovenPrompt = body.Prompt,
		ovenStatus = body.Status.Label,
		shopPrompt = model.UpgradeStation.Prompt,
		packingTable = model.PackingTable,
		packingPrompt = model.PackingTable.Prompt,
		hatch = model.Hatch,
		signLabel = model.Sign.SignGui.Label,
		pads = model.DecorSpots,
		placedFolder = model.Placed,
		playerSpawn = model.Spots.PlayerSpawn,
		customerStart = model.Spots.CustomerStart,
		customerCounter = model.Spots.CustomerCounter,
		counterRight = floor.CFrame.RightVector,
		door = floor.CFrame * CFrame.new(0, 0.6, 19),
		customersFolder = model.Customers,
		helpersFolder = helpersFolder,
	}
	for slot in Config.DeliveryTiers do
		plot.orderTokens[slot] = 0
	end
	setActive(plot.ovenPrompt, false)
	setActive(plot.shopPrompt, false)
	setActive(plot.packingPrompt, false)
	setActive(model.DisplayCase.Base.Prompt, false)
	plot.ovenPrompt.Triggered:Connect(function(player)
		onOvenPrompt(plot, player)
	end)
	plot.shopPrompt.Triggered:Connect(function(player)
		if canUse(player, plot, plot.shopPrompt) then
			openPanelEvent:FireClient(player, "Shop")
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
