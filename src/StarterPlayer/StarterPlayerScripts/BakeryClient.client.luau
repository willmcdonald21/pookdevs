-- Draws the HUD and menus, handles placing items, plays sounds, points at the next
-- task, swings customers' limbs, and shows only your own bakery's prompts.
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local ItemBuilder = require(ReplicatedStorage:WaitForChild("ItemBuilder"))

local player = Players.LocalPlayer
local plotsFolder = Workspace:WaitForChild("Plots")
local notifyEvent = ReplicatedStorage:WaitForChild("Notify")
local stateEvent = ReplicatedStorage:WaitForChild("State")
local openPanelEvent = ReplicatedStorage:WaitForChild("OpenPanel")
local purchaseEvent = ReplicatedStorage:WaitForChild("Purchase")
local bakeEvent = ReplicatedStorage:WaitForChild("Bake")
local placeEvent = ReplicatedStorage:WaitForChild("Place")
local shipEvent = ReplicatedStorage:WaitForChild("Ship")
local newOrderEvent = ReplicatedStorage:WaitForChild("NewOrder")
local selectSlotEvent = ReplicatedStorage:WaitForChild("SelectSlot")
local popupEvent = ReplicatedStorage:WaitForChild("Popup")
local claimDailyEvent = ReplicatedStorage:WaitForChild("ClaimDaily")
local claimGoalEvent = ReplicatedStorage:WaitForChild("ClaimGoal")

local PINK = Color3.fromRGB(240, 150, 175)
local BROWN = Color3.fromRGB(90, 60, 70)
local CREAM = Color3.fromRGB(255, 250, 240)
local GREEN = Color3.fromRGB(110, 195, 125)
local GREY = Color3.fromRGB(190, 185, 185)
local GOLD = Color3.fromRGB(235, 175, 60)
local BLUE = Color3.fromRGB(110, 175, 215)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.FredokaOne
local TOP_LEFT = Vector2.new(0, 0)
local TOP_CENTER = Vector2.new(0.5, 0)

local state = nil

local gui = Instance.new("ScreenGui")
gui.Name = "BakeryHud"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local function style(object, name, size, position, anchor, background, textColor)
	object.Name = name
	object.Size = size
	object.Position = position
	object.AnchorPoint = anchor
	object.BackgroundColor3 = background
	object.BorderSizePixel = 0
	if object:IsA("TextLabel") or object:IsA("TextButton") then
		object.TextColor3 = textColor
		object.Font = FONT
		object.TextScaled = true
		object.Text = ""
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.PaddingTop = UDim.new(0, 4)
		padding.PaddingBottom = UDim.new(0, 4)
		padding.Parent = object
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = object
	return object
end

local function label(name, size, position, anchor, background, textColor, parent)
	local object = style(Instance.new("TextLabel"), name, size, position, anchor, background, textColor)
	object.Parent = parent or gui
	return object
end

local function button(name, size, position, anchor, background, parent)
	local object = style(Instance.new("TextButton"), name, size, position, anchor, background, WHITE)
	object.Parent = parent or gui
	return object
end

-- HUD
local coinsLabel = label("Coins", UDim2.fromOffset(120, 32), UDim2.fromOffset(10, 6), TOP_LEFT, PINK, WHITE)
local starsLabel = label("Stars", UDim2.fromOffset(120, 32), UDim2.fromOffset(10, 42), TOP_LEFT, GOLD, WHITE)
local shopButton = button("ShopButton", UDim2.fromOffset(120, 44), UDim2.fromOffset(10, 78), TOP_LEFT, PINK)
shopButton.Text = "Shop"
local decorButton = button("DecorButton", UDim2.fromOffset(120, 44), UDim2.fromOffset(10, 126), TOP_LEFT, BLUE)
decorButton.Text = "Decorate"
local deliveryButton = button("DeliveryButton", UDim2.fromOffset(120, 44), UDim2.fromOffset(10, 174), TOP_LEFT, BLUE)
deliveryButton.Text = "Deliveries"
local cookbookButton = button("CookbookButton", UDim2.fromOffset(120, 44), UDim2.fromOffset(10, 222), TOP_LEFT, BLUE)
cookbookButton.Text = "Cookbook"
local storeButton = button("StoreButton", UDim2.fromOffset(44, 68), UDim2.fromOffset(134, 6), TOP_LEFT, GREEN)
storeButton.Text = "+"
local hintLabel = label("Hint", UDim2.new(0.5, 0, 0, 32), UDim2.new(0.5, 0, 0, 6), TOP_CENTER, CREAM, BROWN)
local toastLabel = label("Toast", UDim2.new(0.5, 0, 0, 32), UDim2.new(0.5, 0, 0, 42), TOP_CENTER, BROWN, WHITE)
toastLabel.Visible = false

-- Hotbar
local SLOT_SIZE = 58
local SLOT_GAP = 6
local SLOT_NORMAL_STROKE = 2
local SLOT_SELECTED_STROKE = 4
local HOTBAR_WIDTH = Config.HotbarSize * SLOT_SIZE + (Config.HotbarSize - 1) * SLOT_GAP
local BOTTOM_CENTER = Vector2.new(0.5, 1)

local hotbar = Instance.new("Frame")
hotbar.Name = "Hotbar"
hotbar.Size = UDim2.fromOffset(HOTBAR_WIDTH, SLOT_SIZE)
hotbar.Position = UDim2.new(0.5, 0, 1, -8)
hotbar.AnchorPoint = BOTTOM_CENTER
hotbar.BackgroundTransparency = 1
hotbar.Parent = gui
local hotbarLayout = Instance.new("UIListLayout")
hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
hotbarLayout.Padding = UDim.new(0, SLOT_GAP)
hotbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
hotbarLayout.Parent = hotbar

local trayLabel = label(
	"Tray",
	UDim2.fromOffset(HOTBAR_WIDTH, 24),
	UDim2.new(0.5, 0, 1, -(SLOT_SIZE + 12)),
	BOTTOM_CENTER,
	WHITE,
	BROWN
)

local hotbarSlots = {}
for slot = 1, Config.HotbarSize do
	local box = button("Slot" .. slot, UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE), UDim2.new(), TOP_LEFT, CREAM, hotbar)
	box.LayoutOrder = slot
	box.UIPadding:Destroy()
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = PINK
	stroke.Thickness = SLOT_NORMAL_STROKE
	stroke.Parent = box
	local icon = Instance.new("ViewportFrame")
	icon.Name = "Icon"
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Ambient = Color3.fromRGB(200, 200, 200)
	icon.LightColor = WHITE
	icon.Active = false
	icon.Parent = box
	local count = label("Count", UDim2.fromOffset(24, 18), UDim2.new(1, -2, 1, -2), Vector2.new(1, 1), BROWN, WHITE, box)
	count.UIPadding:Destroy()
	count.Visible = false
	count.ZIndex = 2
	local key = label("Key", UDim2.fromOffset(16, 16), UDim2.fromOffset(2, 2), TOP_LEFT, CREAM, BROWN, box)
	key.UIPadding:Destroy()
	key.BackgroundTransparency = 1
	key.Text = tostring(slot)
	key.ZIndex = 2
	box.Activated:Connect(function()
		selectSlotEvent:FireServer(slot)
	end)
	hotbarSlots[slot] = { box = box, stroke = stroke, icon = icon, count = count, recipeIndex = 0 }
end

local function setSlotIcon(entry, recipeIndex)
	entry.recipeIndex = recipeIndex
	entry.icon:ClearAllChildren()
	if recipeIndex == 0 then
		return
	end
	local model = ItemBuilder.Build(Config.Recipes[recipeIndex], 1, CFrame.new())
	ItemBuilder.Anchor(model)
	model.Parent = entry.icon
	local center, extents = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(center.Position + Vector3.new(0, 0.7, 1).Unit * extents.Magnitude * 1.15, center.Position)
	camera.Parent = entry.icon
	entry.icon.CurrentCamera = camera
end

-- Sounds
local sounds = {}
for name, id in Config.Sounds do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = 0.6
	sound.Parent = gui
	sounds[name] = sound
end

local toastToken = 0
notifyEvent.OnClientEvent:Connect(function(text, soundName)
	if soundName and sounds[soundName] then
		sounds[soundName]:Play()
	end
	if not text then
		return
	end
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.Visible = true
	toastLabel.Position = UDim2.new(0.5, 0, 0, 34)
	TweenService:Create(toastLabel, TweenInfo.new(0.2), { Position = UDim2.new(0.5, 0, 0, 42) }):Play()
	task.delay(2.5, function()
		if token == toastToken then
			toastLabel.Visible = false
		end
	end)
end)

-- Menu panel
local panel = style(
	Instance.new("Frame"),
	"Panel",
	UDim2.fromScale(0.9, 0.86),
	UDim2.fromScale(0.5, 0.5),
	Vector2.new(0.5, 0.5),
	CREAM
)
panel.Visible = false
panel.ZIndex = 5
panel.Parent = gui
local panelLimit = Instance.new("UISizeConstraint")
panelLimit.MaxSize = Vector2.new(640, 500)
panelLimit.Parent = panel

local panelTitle = label("Title", UDim2.new(1, -70, 0, 40), UDim2.fromOffset(10, 8), TOP_LEFT, CREAM, BROWN, panel)
panelTitle.TextXAlignment = Enum.TextXAlignment.Left
panelTitle.ZIndex = 6
local closeButton = button("Close", UDim2.fromOffset(44, 44), UDim2.new(1, -8, 0, 6), Vector2.new(1, 0), PINK, panel)
closeButton.Text = "X"
closeButton.ZIndex = 6

local rowList = Instance.new("ScrollingFrame")
rowList.Name = "List"
rowList.Size = UDim2.new(1, -16, 1, -60)
rowList.Position = UDim2.fromOffset(8, 54)
rowList.BackgroundTransparency = 1
rowList.BorderSizePixel = 0
rowList.ScrollBarThickness = 8
rowList.ScrollBarImageColor3 = PINK
rowList.AutomaticCanvasSize = Enum.AutomaticSize.Y
rowList.CanvasSize = UDim2.new()
rowList.ZIndex = 6
rowList.Parent = panel
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = rowList

local rowOrder = 0
-- actions is a list of { Text, Color, OnClick }. OnClick is nil for a plain label.
local function addRow(title, detail, actions)
	rowOrder += 1
	local row = style(Instance.new("Frame"), "Row", UDim2.new(1, -12, 0, 62), UDim2.new(), TOP_LEFT, WHITE)
	row.LayoutOrder = rowOrder
	row.ZIndex = 6
	row.Parent = rowList
	local reserved = #actions * 104 + 10
	local titleLabel =
		label("Heading", UDim2.new(1, -reserved, 0, 28), UDim2.fromOffset(4, 3), TOP_LEFT, WHITE, BROWN, row)
	titleLabel.Text = title
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 7
	local detailLabel =
		label("Detail", UDim2.new(1, -reserved, 0, 28), UDim2.fromOffset(4, 31), TOP_LEFT, WHITE, BROWN, row)
	detailLabel.Text = detail
	detailLabel.TextXAlignment = Enum.TextXAlignment.Left
	detailLabel.ZIndex = 7
	for index, action in actions do
		local x = -6 - (index - 1) * 104
		local actionButton =
			button("Action" .. index, UDim2.fromOffset(98, 48), UDim2.new(1, x, 0.5, 0), Vector2.new(1, 0.5), action.Color, row)
		actionButton.Text = action.Text
		actionButton.ZIndex = 7
		actionButton.AutoButtonColor = action.OnClick ~= nil
		if action.OnClick then
			actionButton.Activated:Connect(action.OnClick)
		end
	end
end

local function addHeader(text)
	rowOrder += 1
	local row = Instance.new("Frame")
	row.Name = "Header"
	row.Size = UDim2.new(1, -12, 0, 30)
	row.BackgroundTransparency = 1
	row.LayoutOrder = rowOrder
	row.ZIndex = 6
	row.Parent = rowList
	local heading = label("Text", UDim2.fromScale(1, 1), UDim2.new(), TOP_LEFT, CREAM, BROWN, row)
	heading.BackgroundTransparency = 1
	heading.Text = text
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.ZIndex = 7
end

local function clearRows()
	for _, child in rowList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	rowOrder = 0
end

local function starText(count)
	return ("%d %s"):format(count, count == 1 and "Star" or "Stars")
end

local function salePrice(recipe)
	local bonus = Config.GetUpgrade("Ingredients").Levels[state.Levels.Ingredients].PriceBonus
	return math.floor(recipe.Price * (1 + bonus))
end

local function trayTotal()
	local total = 0
	for _, count in state.Tray do
		total += count
	end
	return total
end

local function itemList(counts)
	local parts = {}
	for index, count in counts do
		if count > 0 then
			table.insert(parts, ("%d %s"):format(count, Config.Recipes[index].Name))
		end
	end
	return table.concat(parts, ", ")
end

local function canShip(order)
	if order.Waiting then
		return false
	end
	for index, count in order.Items do
		if state.Tray[index] < count then
			return false
		end
	end
	return true
end

-- Returns text like "1 Butter, 2 Eggs" for what's missing, or nil when there's enough.
local function missingIngredients(recipe)
	local missing = {}
	for _, ingredient in Config.Ingredients do
		local need = recipe.Ingredients[ingredient.Id]
		if need and state.Pantry[ingredient.Id] < need then
			table.insert(missing, ("%d %s"):format(need - state.Pantry[ingredient.Id], ingredient.Name))
		end
	end
	return #missing > 0 and table.concat(missing, ", ") or nil
end

local function pantrySummary()
	local parts = {}
	for _, ingredient in Config.Ingredients do
		table.insert(parts, ("%s %d"):format(ingredient.Name, state.Pantry[ingredient.Id]))
	end
	return table.concat(parts, ", ")
end

local function placedCount(itemId)
	local count = 0
	for _, placedId in state.Placed do
		if placedId == itemId then
			count += 1
		end
	end
	return count
end

-- Panel contents
local setPanel
local refreshHotbarVisible
local startPlacing

local panels = {}

function panels.Shop()
	panelTitle.Text = "Bakery Shop"
	for _, upgrade in Config.Upgrades do
		local levelIndex = state.Levels[upgrade.Id]
		local nextLevel = upgrade.Levels[levelIndex + 1]
		if nextLevel then
			local color = state.Coins >= nextLevel.Cost and GREEN or GREY
			addRow(upgrade.Name, upgrade.Describe(nextLevel), {
				{
					Text = nextLevel.Cost .. " coins",
					Color = color,
					OnClick = function()
						purchaseEvent:FireServer("Upgrade", upgrade.Id)
					end,
				},
			})
		else
			addRow(upgrade.Name, upgrade.Describe(upgrade.Levels[levelIndex]), { { Text = "Max", Color = GREY } })
		end
	end
end

function panels.Cookbook()
	panelTitle.Text = "Cookbook"
	addHeader("Recipes")
	for index, recipe in Config.Recipes do
		local detail = ("Sells for %d coins. Uses %s"):format(salePrice(recipe), Config.DescribeIngredients(recipe.Ingredients))
		if index <= state.RecipesUnlocked then
			addRow(recipe.Name, detail, { { Text = "Unlocked", Color = PINK } })
		elseif index == state.RecipesUnlocked + 1 then
			addRow(recipe.Name, detail, {
				{
					Text = recipe.UnlockCost .. " coins",
					Color = state.Coins >= recipe.UnlockCost and GREEN or GREY,
					OnClick = function()
						purchaseEvent:FireServer("Recipe")
					end,
				},
			})
		else
			addRow(recipe.Name, detail, { { Text = "Locked", Color = GREY } })
		end
	end
	addHeader("Daily Goals")
	for index, goal in state.Goals do
		local detail = ("Reward: %d coins + %s"):format(goal.Reward, starText(Config.Goals.Stars))
		local action
		if goal.Claimed then
			action = { Text = "Done", Color = GREY }
		elseif goal.Progress >= goal.Target then
			action = {
				Text = "Claim",
				Color = GREEN,
				OnClick = function()
					claimGoalEvent:FireServer(index)
				end,
			}
		else
			action = { Text = ("%d/%d"):format(goal.Progress, goal.Target), Color = BLUE }
		end
		addRow(Config.DescribeGoal(goal), detail, { action })
	end
	addRow("New goals every day", "Come back tomorrow for more", {})
end

function panels.Pantry()
	panelTitle.Text = ("Pantry (holds %d of each)"):format(state.PantryCapacity)
	for _, ingredient in Config.Ingredients do
		local count = state.Pantry[ingredient.Id]
		local detail = ("You have %d of %d"):format(count, state.PantryCapacity)
		addRow(ingredient.Name, detail, { { Text = tostring(count), Color = count > 0 and GREEN or GREY } })
	end
	addHeader("Getting more")
	addRow("Free delivery crate", ("Arrives outside your door every %d seconds"):format(Config.Crate.Interval), {})
	addRow("Grocery store", ("On the town square: %d of anything for a few coins"):format(Config.GroceryBundle), {})
	addRow("Bigger Pantry", "Buy it in the Shop to store more of each", {})
end

function panels.Bake()
	panelTitle.Text = "What should we bake?"
	local ovenTime = Config.GetUpgrade("Oven").Levels[state.Levels.Oven].BakeTime
	local batch = Config.GetUpgrade("Batch").Levels[state.Levels.Batch].BatchSize
	addRow("Your pantry", pantrySummary(), {})
	for index = 1, state.RecipesUnlocked do
		local recipe = Config.Recipes[index]
		local title = ("%s: %d in %.1fs, %d coins each"):format(recipe.Name, batch, ovenTime * recipe.BakeScale, salePrice(recipe))
		local missing = missingIngredients(recipe)
		if missing then
			addRow(title, "Missing " .. missing, { { Text = "Need more", Color = GREY } })
		else
			addRow(title, "Uses " .. Config.DescribeIngredients(recipe.Ingredients), {
				{
					Text = "Bake",
					Color = GREEN,
					OnClick = function()
						bakeEvent:FireServer(index)
						setPanel(nil)
					end,
				},
			})
		end
	end
end

function panels.Decorate()
	panelTitle.Text = ("Decorate (Charm %d)"):format(state.Charm)
	for _, item in Config.Items do
		if Config.IsAllowed(item, player.UserId) then
			local owned = state.Owned[item.Id]
			local stored = owned - placedCount(item.Id)
			local detail
			if item.Slots then
				detail = ("Holds %d treats. You have %d to place"):format(#item.Slots, stored)
			else
				detail = ("Charm +%d. You have %d to place"):format(item.Charm, stored)
			end
			local actions
			if item.OnlyFor then
				actions = { { Text = "Just for you", Color = PINK } }
			elseif item.Pass then
				local pass = Config.GetPass(item.Pass)
				if state.Passes[item.Pass] then
					actions = { { Text = pass.Name, Color = PINK } }
				else
					detail = ("Charm +%d. Comes with %s"):format(item.Charm, pass.Name)
					actions = {
						{
							Text = "In Store",
							Color = GOLD,
							OnClick = function()
								setPanel("Store")
							end,
						},
					}
				end
			else
				local priceText, canPay
				if item.Stars then
					priceText = starText(item.Stars)
					canPay = state.Stars >= item.Stars
				else
					priceText = item.Coins .. " coins"
					canPay = state.Coins >= item.Coins
				end
				actions = {
					{
						Text = priceText,
						Color = canPay and (item.Stars and GOLD or GREEN) or GREY,
						OnClick = function()
							purchaseEvent:FireServer("Item", item.Id)
						end,
					},
				}
			end
			if stored > 0 then
				table.insert(actions, {
					Text = "Place",
					Color = BLUE,
					OnClick = function()
						startPlacing(item.Id)
					end,
				})
			end
			addRow(item.Name, detail, actions)
		end
	end
	addRow("Move or store items", "Tap a placed item to put it back in storage", {
		{
			Text = "Edit",
			Color = BLUE,
			OnClick = function()
				startPlacing(nil)
			end,
		},
	})
end

function panels.Deliveries()
	panelTitle.Text = "Deliveries"
	local carrying = itemList(state.Tray)
	addRow("You're carrying", carrying ~= "" and carrying or "Nothing yet", {})
	for slot, order in state.Orders do
		local skip = {
			Text = Config.NewOrderStars .. " Star: New",
			Color = state.Stars >= Config.NewOrderStars and GOLD or GREY,
			OnClick = function()
				newOrderEvent:FireServer(slot)
			end,
		}
		if order.Waiting then
			addRow(order.Name, "A new order is on the way...", { skip })
		else
			local pay = order.Coins .. " coins"
			if order.Stars > 0 then
				pay ..= " + " .. starText(order.Stars)
			end
			addRow(order.Name .. ": " .. pay, itemList(order.Items), {
				skip,
				{
					Text = "Pack & Ship",
					Color = canShip(order) and GREEN or GREY,
					OnClick = function()
						shipEvent:FireServer(slot)
					end,
				},
			})
		end
	end
end

-- Prices come from Roblox, so the store always shows what the player will really pay.
local productPrices = {}
local passPrices = {}

local function buyProduct(product)
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, product.ProductId)
	end)
	if not ok then
		warn("Could not open purchase prompt: " .. tostring(err))
	end
end

local function buyPass(pass)
	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, pass.GamePassId)
	end)
	if not ok then
		warn("Could not open purchase prompt: " .. tostring(err))
	end
end

local function robuxAction(id, price, color, onClick)
	if not state.CanBuy then
		return { Text = "Unavailable", Color = GREY }
	elseif id == 0 or not price then
		return { Text = "Soon", Color = GREY }
	end
	return { Text = price .. " Robux", Color = color, OnClick = onClick }
end

local function productDetail(product)
	if product.Currency == "Boost" then
		local detail = ("Double coins for %d minutes"):format(product.Amount)
		local left = state.BoostUntil - Workspace:GetServerTimeNow()
		if left > 0 then
			detail ..= (" (%d min left)"):format(math.ceil(left / 60))
		end
		return detail
	end
	local unit = product.Currency == "Stars" and "Sugar Stars" or "coins"
	return ("%d %s"):format(product.Amount, unit)
end

function panels.Store()
	panelTitle.Text = "Get More"
	for _, section in { "Passes", "Packs" } do
		addHeader(section)
		for _, pass in Config.Passes do
			if pass.Section == section then
				local action
				if state.Passes[pass.Id] then
					action = { Text = "Owned", Color = PINK }
				else
					action = robuxAction(pass.GamePassId, passPrices[pass.GamePassId], GOLD, function()
						buyPass(pass)
					end)
				end
				addRow(pass.Name, pass.Detail, { action })
			end
		end
	end
	addHeader("Coins, Stars and Boosts")
	for _, product in Config.Products do
		local color = product.Currency == "Coins" and GREEN or GOLD
		local action = robuxAction(product.ProductId, productPrices[product.ProductId], color, function()
			buyProduct(product)
		end)
		addRow(product.Name, productDetail(product), { action })
	end
end

local currentPanel = nil

local function refreshPanel()
	if not currentPanel or not state then
		return
	end
	local scroll = rowList.CanvasPosition
	clearRows()
	panels[currentPanel]()
	rowList.CanvasPosition = scroll
end

setPanel = function(name)
	if not state then
		return
	end
	currentPanel = name
	local open = name ~= nil
	panel.Visible = open
	-- The joystick, jump button, and leaderboard would otherwise cover the panel
	-- and swallow taps on its buttons.
	GuiService.TouchControlsEnabled = not open
	refreshHotbarVisible()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not open)
	if open then
		rowList.CanvasPosition = Vector2.zero
		refreshPanel()
	end
end

local function togglePanel(name)
	setPanel(currentPanel ~= name and name or nil)
end

shopButton.Activated:Connect(function()
	togglePanel("Shop")
end)
decorButton.Activated:Connect(function()
	togglePanel("Decorate")
end)
deliveryButton.Activated:Connect(function()
	togglePanel("Deliveries")
end)
storeButton.Activated:Connect(function()
	togglePanel("Store")
end)
cookbookButton.Activated:Connect(function()
	togglePanel("Cookbook")
end)
closeButton.Activated:Connect(function()
	setPanel(nil)
end)

local function loadPrice(id, infoType, prices)
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		if ok and info.IsForSale then
			prices[id] = info.PriceInRobux
			refreshPanel()
		end
	end)
end

for _, product in Config.Products do
	if product.ProductId ~= 0 then
		loadPrice(product.ProductId, Enum.InfoType.Product, productPrices)
	end
end
for _, pass in Config.Passes do
	if pass.GamePassId ~= 0 then
		loadPrice(pass.GamePassId, Enum.InfoType.GamePass, passPrices)
	end
end
openPanelEvent.OnClientEvent:Connect(setPanel)

-- Plots
local function plotOf(instance)
	local current = instance
	while current and current.Parent ~= plotsFolder do
		current = current.Parent
	end
	return current
end

local function isMine(plot)
	return plot ~= nil and plot:GetAttribute("OwnerId") == player.UserId
end

local function myPlot()
	for _, plot in plotsFolder:GetChildren() do
		if isMine(plot) then
			return plot
		end
	end
	return nil
end

-- Placing items
local EMPTY_PAD = Color3.fromRGB(120, 220, 140)
local FULL_PAD = Color3.fromRGB(255, 180, 90)
local PLACING_CAMERA_HEIGHT = 58
local PLACING_CAMERA_BACK = 12
local placing = false
local placingItem = nil

local placeBanner = label("PlaceBanner", UDim2.new(0.5, 0, 0, 32), UDim2.new(0.5, 0, 0, 42), TOP_CENTER, GREEN, WHITE)
placeBanner.Visible = false
placeBanner.ZIndex = 3
local placeDone =
	button("PlaceDone", UDim2.fromOffset(120, 46), UDim2.new(0.5, 0, 1, -10), Vector2.new(0.5, 1), PINK)
placeDone.Text = "Done"
placeDone.Visible = false

-- The hotbar shares the bottom of the screen with Done and sits under open menus.
refreshHotbarVisible = function()
	local show = currentPanel == nil and not placing
	hotbar.Visible = show
	trayLabel.Visible = show
end

local function refreshPads()
	local plot = myPlot()
	if not plot then
		return
	end
	for _, pad in plot.DecorSpots:GetChildren() do
		if placing then
			local full = state.Placed[pad.Name] ~= nil
			pad.Color = full and FULL_PAD or EMPTY_PAD
			pad.Transparency = 0.45
		else
			pad.Transparency = 1
		end
	end
end

local function refreshBanner()
	if placingItem then
		local item = Config.GetItem(placingItem)
		placeBanner.Text = ("Tap a green square to place: %s"):format(item.Name)
	else
		placeBanner.Text = "Tap an orange square to store that item"
	end
end

-- Placing uses a top-down camera so every square in the bakery can be seen and tapped.
local function setPlacingCamera(active)
	local camera = Workspace.CurrentCamera
	local plot = myPlot()
	if active and plot then
		local center = plot.Floor.Position
		local eye = (plot.Floor.CFrame * CFrame.new(0, PLACING_CAMERA_HEIGHT, PLACING_CAMERA_BACK)).Position
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(eye, center)
	else
		camera.CameraType = Enum.CameraType.Custom
	end
end

startPlacing = function(itemId)
	placing = true
	placingItem = itemId
	setPanel(nil)
	setPlacingCamera(true)
	placeBanner.Visible = true
	placeDone.Visible = true
	refreshHotbarVisible()
	refreshBanner()
	refreshPads()
end

local function stopPlacing()
	placing = false
	placingItem = nil
	setPlacingCamera(false)
	placeBanner.Visible = false
	placeDone.Visible = false
	refreshHotbarVisible()
	refreshPads()
end

placeDone.Activated:Connect(stopPlacing)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not placing then
		return
	end
	local isClick = input.UserInputType == Enum.UserInputType.MouseButton1
	if not isClick and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local plot = myPlot()
	if not plot then
		return
	end
	local camera = Workspace.CurrentCamera
	local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { plot.DecorSpots }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	if not result then
		return
	end
	local spot = tonumber(result.Instance.Name)
	if placingItem then
		placeEvent:FireServer(spot, placingItem)
	elseif state.Placed[result.Instance.Name] then
		placeEvent:FireServer(spot, nil)
	end
end)

local SLOT_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }

UserInputService.InputBegan:Connect(function(input, processed)
	local slot = table.find(SLOT_KEYS, input.KeyCode)
	if not processed and slot and hotbar.Visible then
		selectSlotEvent:FireServer(slot)
	end
end)

-- State updates
stateEvent.OnClientEvent:Connect(function(newState)
	state = newState
	local multiplierText = state.Multiplier > 1 and (" x%d"):format(state.Multiplier) or ""
	coinsLabel.Text = ("%d coins%s"):format(state.Coins, multiplierText)
	starsLabel.Text = starText(state.Stars)
	shopButton.BackgroundColor3 = state.CanAfford and GREEN or PINK
	shopButton.Text = state.CanAfford and "Shop!" or "Shop"
	local ready = false
	for _, order in state.Orders do
		if canShip(order) then
			ready = true
		end
	end
	deliveryButton.BackgroundColor3 = ready and GREEN or BLUE
	deliveryButton.Text = ready and "Deliveries!" or "Deliveries"
	local cookbookReady = state.CanUnlockRecipe
	for _, goal in state.Goals do
		if not goal.Claimed and goal.Progress >= goal.Target then
			cookbookReady = true
		end
	end
	cookbookButton.BackgroundColor3 = cookbookReady and GREEN or BLUE
	cookbookButton.Text = cookbookReady and "Cookbook!" or "Cookbook"
	for slot, entry in hotbarSlots do
		local recipeIndex = state.Hotbar[slot]
		if recipeIndex ~= entry.recipeIndex then
			setSlotIcon(entry, recipeIndex)
		end
		entry.count.Visible = recipeIndex ~= 0
		entry.count.Text = recipeIndex ~= 0 and tostring(state.Tray[recipeIndex]) or ""
		local selected = state.SelectedSlot == slot
		entry.stroke.Color = selected and GOLD or PINK
		entry.stroke.Thickness = selected and SLOT_SELECTED_STROKE or SLOT_NORMAL_STROKE
	end
	local carrying = ("Carrying %d/%d"):format(trayTotal(), state.TrayCapacity)
	if state.SelectedSlot then
		local recipe = Config.Recipes[state.Hotbar[state.SelectedSlot]]
		trayLabel.Text = ("%s: stocking only %s"):format(carrying, recipe.Name)
	else
		trayLabel.Text = carrying
	end
	refreshPanel()
	if placing then
		if placingItem and state.Owned[placingItem] - placedCount(placingItem) <= 0 then
			placingItem = nil
			refreshBanner()
		end
		refreshPads()
	end
end)

local function refreshHint()
	local hint = player:GetAttribute("Hint") or ""
	hintLabel.Text = hint
	hintLabel.Visible = hint ~= ""
end
player:GetAttributeChangedSignal("Hint"):Connect(refreshHint)
refreshHint()

-- Popups show one at a time, in the order they arrive.
local popupQueue = {}
local popupOpen = false

local function showNextPopup()
	if popupOpen or #popupQueue == 0 then
		return
	end
	popupOpen = true
	local info = table.remove(popupQueue, 1)
	local popup = style(
		Instance.new("Frame"),
		"Popup",
		UDim2.fromScale(0.8, 0.8),
		UDim2.fromScale(0.5, 0.5),
		Vector2.new(0.5, 0.5),
		CREAM
	)
	popup.ZIndex = 10
	popup.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(540, 360)
	limit.Parent = popup
	local title = label("Title", UDim2.new(1, -20, 0.18, 0), UDim2.fromScale(0.5, 0.03), TOP_CENTER, CREAM, BROWN, popup)
	title.Text = info.Title
	title.ZIndex = 11
	local body = label("Body", UDim2.new(1, -30, 0.55, 0), UDim2.fromScale(0.5, 0.22), TOP_CENTER, CREAM, BROWN, popup)
	body.Text = info.Body
	body.ZIndex = 11
	local ok = button("Ok", UDim2.fromOffset(150, 46), UDim2.fromScale(0.5, 0.97), Vector2.new(0.5, 1), GREEN, popup)
	ok.Text = info.Button
	ok.ZIndex = 11
	ok.Activated:Connect(function()
		popup:Destroy()
		popupOpen = false
		if info.OnClose then
			info.OnClose()
		end
		showNextPopup()
	end)
end

local function queuePopup(title, body, buttonText, onClose)
	table.insert(popupQueue, { Title = title, Body = body, Button = buttonText, OnClose = onClose })
	showNextPopup()
end

local welcomeShown = false
local function showWelcome()
	if welcomeShown or player:GetAttribute("ShowWelcome") ~= true then
		return
	end
	welcomeShown = true
	queuePopup(
		"Welcome to your bakery!",
		"1. Bake treats at the oven\n2. Put them in a display case\n3. Customers shop and pay you\n4. Pack deliveries for big rewards and Sugar Stars\nBuy cases and decorations to grow your bakery!",
		"Let's bake!"
	)
end
player:GetAttributeChangedSignal("ShowWelcome"):Connect(showWelcome)
showWelcome()

local function rewardText(reward, isVip)
	local parts = {}
	if reward.Coins then
		table.insert(parts, reward.Coins .. " coins")
	end
	local stars = (reward.Stars or 0) + (isVip and Config.VipDailyStars or 0)
	if stars > 0 then
		table.insert(parts, starText(stars))
	end
	return table.concat(parts, " + ")
end

popupEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "Daily" then
		local tomorrow = Config.DailyRewards[info.Day % #Config.DailyRewards + 1]
		local body = ("Day %d of %d\n\nToday: %s\nTomorrow: %s\n\nCome back every day to keep your streak!"):format(
			info.Day,
			#Config.DailyRewards,
			rewardText(Config.DailyRewards[info.Day], info.Vip),
			rewardText(tomorrow, info.Vip)
		)
		queuePopup("Daily Reward", body, "Claim", function()
			claimDailyEvent:FireServer()
		end)
	elseif kind == "Away" then
		local body = ("Customers bought %d treats from your cases while you were away.\n\n+%d coins"):format(
			info.Sold,
			info.Coins
		)
		queuePopup("Welcome back!", body, "Yay!")
	end
end)

-- Prompts
local function refreshPrompt(prompt)
	prompt.Enabled = isMine(plotOf(prompt)) and prompt:GetAttribute("Active") == true
end

local function watchPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt:GetAttributeChangedSignal("Active"):Connect(function()
		refreshPrompt(prompt)
	end)
	refreshPrompt(prompt)
end

for _, instance in plotsFolder:GetDescendants() do
	watchPrompt(instance)
end
plotsFolder.DescendantAdded:Connect(watchPrompt)

-- Guide arrow and highlight
local highlight = Instance.new("Highlight")
highlight.Name = "GuideHighlight"
highlight.FillColor = Color3.fromRGB(255, 225, 130)
highlight.FillTransparency = 0.75
highlight.OutlineColor = Color3.fromRGB(255, 200, 60)
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.Parent = gui

local arrow = Instance.new("BillboardGui")
arrow.Name = "GuideArrow"
arrow.Size = UDim2.fromOffset(50, 50)
arrow.AlwaysOnTop = true
arrow.StudsOffset = Vector3.new(0, 6, 0)
local arrowText = Instance.new("TextLabel")
arrowText.Size = UDim2.fromScale(1, 1)
arrowText.BackgroundTransparency = 1
arrowText.Font = FONT
arrowText.TextScaled = true
arrowText.Text = "V"
arrowText.TextColor3 = Color3.fromRGB(255, 200, 60)
arrowText.TextStrokeTransparency = 0
arrowText.Parent = arrow
arrow.Parent = gui

local function refreshGuide()
	local plot = myPlot()
	local target = player:GetAttribute("Target")
	local instance = nil
	if plot and target then
		instance = plot:FindFirstChild(target) or plot.Placed:FindFirstChild(target)
	end
	highlight.Adornee = instance
	arrow.Adornee = instance
end

player:GetAttributeChangedSignal("Target"):Connect(refreshGuide)
for _, plot in plotsFolder:GetChildren() do
	plot:GetAttributeChangedSignal("OwnerId"):Connect(function()
		for _, instance in plot:GetDescendants() do
			if instance:IsA("ProximityPrompt") then
				refreshPrompt(instance)
			end
		end
		refreshGuide()
	end)
end
refreshGuide()

-- VIP chat tag
TextChatService.OnIncomingMessage = function(message)
	local properties = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local speaker = source and Players:GetPlayerByUserId(source.UserId)
	if speaker and speaker:GetAttribute("VIP") == true then
		properties.PrefixText = '<font color="#EBAF3C">[VIP]</font> ' .. message.PrefixText
	end
	return properties
end

-- Customer walking
local SWING_ANGLE = math.rad(35)
local SWING_SPEED = 7
local joints = {}

local function watchCustomer(model)
	local root = model:WaitForChild("Torso", 5)
	if not root then
		return
	end
	local function addJoint(joint)
		if joint:IsA("Motor6D") and joint:GetAttribute("Swing") then
			joints[joint] = { model = model, c0 = joint.C0, swing = joint:GetAttribute("Swing") }
		end
	end
	for _, joint in root:GetChildren() do
		addJoint(joint)
	end
	root.ChildAdded:Connect(addJoint)
end

for _, model in CollectionService:GetTagged("Customer") do
	task.spawn(watchCustomer, model)
end
CollectionService:GetInstanceAddedSignal("Customer"):Connect(watchCustomer)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for joint, info in joints do
		if not joint:IsDescendantOf(Workspace) then
			joints[joint] = nil
		else
			local angle = 0
			if info.model:GetAttribute("Walking") then
				angle = math.sin(now * SWING_SPEED) * SWING_ANGLE * info.swing
			end
			joint.C0 = info.c0 * CFrame.Angles(angle, 0, 0)
		end
	end
end)
