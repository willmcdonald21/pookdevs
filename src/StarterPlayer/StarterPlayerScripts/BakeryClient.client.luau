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
local Layout = require(ReplicatedStorage:WaitForChild("Layout"))

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
local unpackCrateEvent = ReplicatedStorage:WaitForChild("UnpackCrate")
local buyGroceriesEvent = ReplicatedStorage:WaitForChild("BuyGroceries")
local startBakeSaleEvent = ReplicatedStorage:WaitForChild("StartBakeSale")
local takeFlyersEvent = ReplicatedStorage:WaitForChild("TakeFlyers")

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
local boostButton = button("BoostButton", UDim2.fromOffset(120, 44), UDim2.fromOffset(10, 270), TOP_LEFT, BLUE)
boostButton.Text = "Boosts"
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

-- Shows a treat in a ViewportFrame, seen from a little above.
local function showTreat(viewport, recipeIndex)
	local model = ItemBuilder.Build(Config.Recipes[recipeIndex], 1, CFrame.new())
	ItemBuilder.Anchor(model)
	model.Parent = viewport
	local center, extents = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(center.Position + Vector3.new(0, 0.7, 1).Unit * extents.Magnitude * 1.15, center.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function setSlotIcon(entry, recipeIndex)
	entry.recipeIndex = recipeIndex
	entry.icon:ClearAllChildren()
	if recipeIndex == 0 then
		return
	end
	showTreat(entry.icon, recipeIndex)
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

-- Tabs under the title, for menus that have them. The list moves down to make room.
local TAB_HEIGHT = 40
local tabBar = Instance.new("Frame")
tabBar.Name = "Tabs"
tabBar.Size = UDim2.new(1, -16, 0, TAB_HEIGHT)
tabBar.Position = UDim2.fromOffset(8, 54)
tabBar.BackgroundTransparency = 1
tabBar.Visible = false
tabBar.ZIndex = 6
tabBar.Parent = panel
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

-- Tabs share the bar's width, up to 110 pixels each, so they fit on a small phone.
local function showTabs(names, current, onPick)
	for index, name in names do
		local size = UDim2.new(1 / #names, -8, 0, TAB_HEIGHT)
		local tab = button(name .. "Tab", size, UDim2.new(), TOP_LEFT, name == current and PINK or GREY, tabBar)
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(110, TAB_HEIGHT)
		limit.Parent = tab
		tab.Text = name
		tab.LayoutOrder = index
		tab.ZIndex = 7
		tab.Activated:Connect(function()
			onPick(name)
		end)
	end
	tabBar.Visible = true
	rowList.Position = UDim2.fromOffset(8, 54 + TAB_HEIGHT + 6)
	rowList.Size = UDim2.new(1, -16, 1, -60 - TAB_HEIGHT - 6)
end

local function hideTabs()
	for _, child in tabBar:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	tabBar.Visible = false
	rowList.Position = UDim2.fromOffset(8, 54)
	rowList.Size = UDim2.new(1, -16, 1, -60)
end

local rowOrder = 0
-- actions is a list of { Text, Color, OnClick, TextColor }. OnClick is nil for a plain
-- label, and TextColor is white unless given.
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
		actionButton.TextColor3 = action.TextColor or WHITE
		actionButton.ZIndex = 7
		actionButton.AutoButtonColor = action.OnClick ~= nil
		if action.OnClick then
			actionButton.Activated:Connect(action.OnClick)
		end
	end
	return row
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

-- 25000 becomes "25,000".
local function withCommas(count)
	local text = tostring(count)
	repeat
		local changed
		text, changed = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
	until changed == 0
	return text
end

local function salePrice(recipe)
	local bonus = Config.GetUpgrade("Ingredients").Levels[state.Levels.Ingredients].PriceBonus
	return math.floor(recipe.Price * (1 + bonus))
end

-- Boosts. Their times count down here from the server's clock.
local function secondsUntil(time)
	return math.max(0, math.ceil(time - Workspace:GetServerTimeNow()))
end

local function clockText(seconds)
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function bakeSaleLeft()
	return secondsUntil(state.BakeSaleAt + Config.BakeSale.Duration)
end

local function bakeSaleReadyIn()
	return secondsUntil(state.BakeSaleAt + Config.BakeSale.Cooldown)
end

-- How many times the usual number of customers are coming, worked out as the server does.
local function rushNow()
	local rush = 1
	if bakeSaleLeft() > 0 then
		rush += Config.BakeSale.Rush
	end
	if secondsUntil(state.BuzzUntil) > 0 then
		rush += Config.Buzz.Rush
	end
	if secondsUntil(state.BoostUntil) > 0 then
		rush += Config.BoostRush
	end
	return rush
end

-- What customers pay, and true during a Bake Sale, when it's less.
local function customerPrice(recipe)
	local price = salePrice(recipe)
	if bakeSaleLeft() > 0 then
		return math.max(1, math.floor(price * (1 - Config.BakeSale.Discount))), true
	end
	return price, false
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
	for _, entry in state.Placed do
		if entry.Id == itemId then
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
		local price, onSale = customerPrice(recipe)
		local detail = ("%s %d coins. Uses %s"):format(
			onSale and "On sale for" or "Sells for",
			price,
			Config.DescribeIngredients(recipe.Ingredients)
		)
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

function panels.Grocery()
	panelTitle.Text = "Grocery Store"
	addHeader(("Bundles of %d. Your pantry holds %d of each"):format(Config.GroceryBundle, state.PantryCapacity))
	for _, ingredient in Config.Ingredients do
		local have = state.Pantry[ingredient.Id]
		local amount = math.min(Config.GroceryBundle, state.PantryCapacity - have)
		local detail = ("You have %d of %d"):format(have, state.PantryCapacity)
		if amount <= 0 then
			addRow(ingredient.Name, detail, { { Text = "Full", Color = GREY } })
		else
			-- Same price per item as the server charges for a partly full pantry.
			local price = math.ceil(ingredient.BundlePrice * amount / Config.GroceryBundle)
			addRow(("%s x%d"):format(ingredient.Name, amount), detail, {
				{
					Text = price .. " coins",
					Color = state.Coins >= price and GREEN or GREY,
					OnClick = function()
						buyGroceriesEvent:FireServer(ingredient.Id)
					end,
				},
			})
		end
	end
end

function panels.Bake()
	panelTitle.Text = "What should we bake?"
	local ovenTime = Config.GetUpgrade("Oven").Levels[state.Levels.Oven].BakeTime
	local batch = Config.GetUpgrade("Batch").Levels[state.Levels.Batch].BatchSize
	addRow("Your pantry", pantrySummary(), {})
	for index = 1, state.RecipesUnlocked do
		local recipe = Config.Recipes[index]
		local title =
			("%s: %d in %.1fs, %d coins each"):format(recipe.Name, batch, ovenTime * recipe.BakeScale, (customerPrice(recipe)))
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

-- Dark writing on pale buttons and white writing on dark ones, so prices stay readable.
local function textOn(color)
	return (0.299 * color.R + 0.587 * color.G + 0.114 * color.B) > 0.6 and BROWN or WHITE
end

-- Roughly where a piece stands, as seen from the door: "Front left", "Back", "Middle".
local function whereIs(rect)
	local bounds = Layout.Bounds(state.Expansion)
	local center = Layout.Center(rect)
	local across = (center.X - bounds.MinX) / (bounds.MaxX - bounds.MinX)
	local deep = (center.Z - bounds.MinZ) / (bounds.MaxZ - bounds.MinZ)
	local words = {}
	if deep > 2 / 3 then
		table.insert(words, "front")
	elseif deep < 1 / 3 then
		table.insert(words, "back")
	end
	if across > 2 / 3 then
		table.insert(words, "right")
	elseif across < 1 / 3 then
		table.insert(words, "left")
	end
	local text = #words > 0 and table.concat(words, " ") or "middle"
	return text:sub(1, 1):upper() .. text:sub(2)
end

-- Your display cases in a steady order, each with a numbered name and where it stands.
local function paintableCases()
	local keys = {}
	for key, entry in state.Placed do
		if Config.GetItem(entry.Id).Slots then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	local counts, cases = {}, {}
	for _, key in keys do
		local entry = state.Placed[key]
		local item = Config.GetItem(entry.Id)
		counts[item.Id] = (counts[item.Id] or 0) + 1
		local rect = Layout.Rect(Layout.ItemShape(item), entry)
		table.insert(cases, { Key = key, Name = ("%s %d"):format(item.Name, counts[item.Id]), Where = whereIs(rect) })
	end
	return cases
end

-- The Paint tab lists everything that can be painted. Choosing one lists its colours, and
-- paintChoice remembers which it is: { Target = paint target } or { CaseKey, Name }.
local paintChoice = nil

local function choosePaint(choice)
	paintChoice = choice
	setPanel("Decorate")
end

local function paintRows()
	if paintChoice and paintChoice.CaseKey and not state.Placed[paintChoice.CaseKey] then
		paintChoice = nil
	end
	if paintChoice then
		local target, key = paintChoice.Target, paintChoice.CaseKey
		local name, current, cost
		if target then
			name, current, cost = target.Name, state.Paint[target.Id] or target.Original, target.Coins
		else
			name, current, cost = paintChoice.Name, state.Placed[key].Paint or Config.CaseOriginalPaint, Config.CasePaintCoins
		end
		addRow("Painting: " .. name, "Pick a colour, or go back to the list", {
			{
				Text = "Back",
				Color = BLUE,
				OnClick = function()
					choosePaint(nil)
				end,
			},
		})
		for _, paint in Config.Paints do
			if not target or Config.CanPaint(target, paint) then
				local isNow = paint.Id == current
				local action = { Text = isNow and "Now" or (cost .. " coins"), Color = paint.Color, TextColor = textOn(paint.Color) }
				if not isNow then
					action.OnClick = function()
						if target then
							purchaseEvent:FireServer("Paint", target.Id, paint.Id)
						else
							purchaseEvent:FireServer("PaintCase", key, paint.Id)
						end
					end
				end
				addRow(paint.Name, isNow and "Its colour now" or ("Paint it %s"):format(paint.Name), { action })
			end
		end
		return
	end
	for _, target in Config.PaintTargets do
		local current = Config.GetPaint(state.Paint[target.Id] or target.Original)
		addRow(target.Name, ("%s now. %d coins to repaint"):format(current.Name, target.Coins), {
			{
				Text = "Paint",
				Color = BLUE,
				OnClick = function()
					choosePaint({ Target = target })
				end,
			},
		})
	end
	if state.LuxuryOven then
		addRow(Config.LuxuryOven.Name, "Gold finish, can't be repainted", {})
	end
	for _, case in paintableCases() do
		local current = Config.GetPaint(state.Placed[case.Key].Paint or Config.CaseOriginalPaint)
		addRow(case.Name, ("%s. %s now, %d coins to repaint"):format(case.Where, current.Name, Config.CasePaintCoins), {
			{
				Text = "Paint",
				Color = BLUE,
				OnClick = function()
					choosePaint({ CaseKey = case.Key, Name = case.Name })
				end,
			},
		})
	end
end

local function sizeText(bounds)
	return ("%d x %d"):format(bounds.MaxX - bounds.MinX, bounds.MaxZ - bounds.MinZ)
end

-- The Expansion tab: a bigger bakery, one step at a time, and the Luxury Oven.
local function expansionRows()
	local level = state.Expansion
	local step = Config.Expansions[level + 1]
	if step then
		local detail = ("Now %s. Step %d of %d makes it %s"):format(
			sizeText(Layout.Bounds(level)),
			level + 1,
			#Config.Expansions,
			sizeText(Layout.Bounds(level + 1))
		)
		addRow("Bigger Bakery", detail, {
			{
				Text = withCommas(step.Coins) .. " coins",
				Color = state.Coins >= step.Coins and GOLD or GREY,
				OnClick = function()
					purchaseEvent:FireServer("Expand")
				end,
			},
		})
	else
		addRow("Bigger Bakery", "As big as it gets: " .. sizeText(Layout.Bounds(level)), { { Text = "Biggest!", Color = PINK } })
	end
	local luxury = Config.LuxuryOven
	if state.LuxuryOven then
		addRow(luxury.Name, "In your bakery. Move it any time with Move things", { { Text = "Owned", Color = PINK } })
	else
		addRow(luxury.Name, luxury.Detail, {
			{
				Text = withCommas(luxury.Coins) .. " coins",
				Color = state.Coins >= luxury.Coins and GOLD or GREY,
				OnClick = function()
					purchaseEvent:FireServer("LuxuryOven")
				end,
			},
		})
	end
end

-- Floor has everything that stands on the floor, Wall has wall pieces, Paint colours the
-- walls, oven and cases, and Expansion makes the bakery bigger.
local DECOR_TABS = { "Floor", "Wall", "Paint", "Expansion" }
local decorTab = "Floor"

function panels.Decorate()
	panelTitle.Text = ("Decorate (Charm %d)"):format(state.Charm)
	showTabs(DECOR_TABS, decorTab, function(name)
		decorTab = name
		choosePaint(nil)
	end)
	if decorTab == "Paint" then
		paintRows()
		return
	elseif decorTab == "Expansion" then
		expansionRows()
		return
	end
	addRow("Move things", "Move or turn anything in your bakery, including the oven and counters", {
		{
			Text = "Move",
			Color = BLUE,
			OnClick = function()
				startPlacing(nil)
			end,
		},
	})
	for _, item in Config.Items do
		if Config.IsAllowed(item, player.UserId) and (item.Wall == true) == (decorTab == "Wall") then
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
		local detail = ("Double coins and customers for %d minutes"):format(product.Amount)
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

-- Rows in the Boosts menu whose text counts down, each with a function giving its text.
local boostLive = {}
local boostPhase = nil

-- Changes when the Boosts menu needs different buttons, not just new times.
local function currentBoostPhase()
	local sale = bakeSaleLeft() > 0 and "On" or bakeSaleReadyIn() > 0 and "Wait" or "Ready"
	local flyers = state.Flyers > 0 and "Have" or secondsUntil(state.FlyersReadyAt) > 0 and "Wait" or "Ready"
	return ("%s %s %g"):format(sale, flyers, rushNow())
end

local function timeLeftText(text, untilTime)
	local left = secondsUntil(untilTime)
	return left > 0 and ("%s. On: %s left"):format(text, clockText(left)) or text
end

function panels.Boosts()
	panelTitle.Text = "Boosts"
	table.clear(boostLive)
	boostPhase = currentBoostPhase()
	local function live(object, text)
		object.Text = text()
		table.insert(boostLive, { object = object, text = text })
	end

	local customersRow = addRow("Customers", "", {})
	live(customersRow.Detail, function()
		local rush = rushNow()
		return rush > 1 and ("%gx as many as usual right now"):format(rush) or "As many as usual. Boosts bring more"
	end)

	local sale = Config.BakeSale
	local saleDetail = ("%d%% off and %d%% more customers for %d min, once an hour"):format(
		math.floor(sale.Discount * 100 + 0.5),
		math.floor(sale.Rush * 100 + 0.5),
		sale.Duration // 60
	)
	local saleAction
	if bakeSaleLeft() > 0 then
		saleAction = { Text = "", Color = PINK }
	elseif bakeSaleReadyIn() > 0 then
		saleAction = { Text = "", Color = GREY }
	else
		saleAction = {
			Text = "Start",
			Color = GREEN,
			OnClick = function()
				startBakeSaleEvent:FireServer()
			end,
		}
	end
	local saleRow = addRow("Bake Sale", saleDetail, { saleAction })
	if not saleAction.OnClick then
		live(saleRow.Action1, function()
			local left = bakeSaleLeft()
			if left > 0 then
				return clockText(left) .. " left"
			end
			return ("In %d min"):format(math.ceil(bakeSaleReadyIn() / 60))
		end)
	end

	local flyerWait = secondsUntil(state.FlyersReadyAt)
	local flyerColor = state.Flyers > 0 and PINK or flyerWait > 0 and GREY or GREEN
	local flyerRow = addRow("Flyers", "", { { Text = "", Color = flyerColor } })
	live(flyerRow.Detail, function()
		if state.Flyers > 0 then
			return "Walk near people on the plaza to hand them out"
		elseif secondsUntil(state.FlyersReadyAt) > 0 then
			return "A new stack is coming to the stand outside your door"
		end
		return ("Take a stack of %d from the stand outside your door"):format(Config.Flyers.Stack)
	end)
	live(flyerRow.Action1, function()
		if state.Flyers > 0 then
			return ("%d left"):format(state.Flyers)
		end
		local wait = secondsUntil(state.FlyersReadyAt)
		return wait > 0 and clockText(wait) or "Ready"
	end)

	local buzzRow = addRow("Bakery Buzz", "", {
		{
			Text = starText(Config.Buzz.Stars),
			Color = state.Stars >= Config.Buzz.Stars and GOLD or GREY,
			OnClick = function()
				purchaseEvent:FireServer("Buzz")
			end,
		},
	})
	live(buzzRow.Detail, function()
		return timeLeftText(("Twice the customers for %d min"):format(Config.Buzz.Minutes), state.BuzzUntil)
	end)

	for _, product in Config.Products do
		if product.Currency == "Boost" then
			local action = robuxAction(product.ProductId, productPrices[product.ProductId], GOLD, function()
				buyProduct(product)
			end)
			local boostRow = addRow(product.Name, "", { action })
			live(boostRow.Detail, function()
				return timeLeftText(("Double coins and customers for %d min"):format(product.Amount), state.BoostUntil)
			end)
		end
	end
end

-- The Boosts button counts down while a boost is on, and is green when a Bake Sale is ready.
local function refreshBoostButton()
	if rushNow() > 1 then
		local ends = math.max(bakeSaleLeft(), secondsUntil(state.BuzzUntil), secondsUntil(state.BoostUntil))
		boostButton.Text = "Rush " .. clockText(ends)
		boostButton.BackgroundColor3 = GOLD
	elseif bakeSaleReadyIn() == 0 then
		boostButton.Text = "Boosts!"
		boostButton.BackgroundColor3 = GREEN
	else
		boostButton.Text = "Boosts"
		boostButton.BackgroundColor3 = BLUE
	end
end

local currentPanel = nil

local function refreshPanel()
	if not currentPanel or not state then
		return
	end
	local scroll = rowList.CanvasPosition
	clearRows()
	hideTabs()
	panels[currentPanel]()
	rowList.CanvasPosition = scroll
end

setPanel = function(name)
	if not state then
		return
	end
	-- Opening a menu starts the Paint tab at its list, not partway through a choice.
	if name ~= currentPanel then
		paintChoice = nil
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
boostButton.Activated:Connect(function()
	togglePanel("Boosts")
end)

-- Once a second, boost times count down on the button and in the Boosts menu. The menu is
-- only rebuilt when its buttons change, so a tap on one isn't lost.
task.spawn(function()
	while true do
		task.wait(1)
		if state then
			refreshBoostButton()
			if currentPanel == "Boosts" then
				if currentBoostPhase() ~= boostPhase then
					refreshPanel()
				else
					for _, entry in boostLive do
						entry.object.Text = entry.text()
					end
				end
			end
		end
	end
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

-- Decorating
-- Pieces snap to a grid on your floor, or on your walls for wall pieces, while the camera
-- and controls work as normal. The preview uses the same Layout rules as the server,
-- which checks every spot again.
local OK_COLOR = Color3.fromRGB(120, 220, 140)
local BLOCKED_COLOR = Color3.fromRGB(225, 95, 95)
local FRONT_COLOR = Color3.fromRGB(150, 200, 255)
local DOORWAY_COLOR = Color3.fromRGB(255, 200, 120)
local GHOST_TRANSPARENCY = 0.45
local ARROW_ANGLE = math.rad(35)
local MOVE_HINT = "Tap or click anything in your bakery to move it"
local ROTATE_HINT = "Pick something up first, then rotate it"
local WALL_ROTATE_HINT = "Wall pieces always face into the room"
local BANNER_HINT_TIME = 2
-- A new wall piece starts with its middle at about head height.
local WALL_START_HEIGHT = 6
local WALL_NAMES = { "BackWall", "LeftWall", "RightWall" }
-- Copies of a station keep their parts but none of their prompts, labels or effects.
local GHOST_REMOVES =
	{ "ProximityPrompt", "BillboardGui", "ParticleEmitter", "Sparkles", "Sound", "ClickDetector", "PointLight" }

local decorating = false
local held = nil
local pending = nil
local grid = nil
local wallGrid = nil
local hiddenGuis = {}
local bannerHintUntil = 0

local placeBanner = label("PlaceBanner", UDim2.new(0.5, 0, 0, 32), UDim2.new(0.5, 0, 0, 78), TOP_CENTER, GREEN, WHITE)
placeBanner.Visible = false
placeBanner.ZIndex = 3

local placeBar = Instance.new("Frame")
placeBar.Name = "PlaceBar"
placeBar.Size = UDim2.fromOffset(440, 46)
placeBar.Position = UDim2.new(0.5, 0, 1, -10)
placeBar.AnchorPoint = BOTTOM_CENTER
placeBar.BackgroundTransparency = 1
placeBar.Visible = false
placeBar.Parent = gui
local placeBarLayout = Instance.new("UIListLayout")
placeBarLayout.FillDirection = Enum.FillDirection.Horizontal
placeBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
placeBarLayout.Padding = UDim.new(0, 8)
placeBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
placeBarLayout.Parent = placeBar

local function barButton(name, order, color)
	local object = button(name, UDim2.fromOffset(100, 46), UDim2.new(), TOP_LEFT, color, placeBar)
	object.Text = name
	object.LayoutOrder = order
	return object
end

local rotateButton = barButton("Rotate", 1, BLUE)
local placeButton = barButton("Place", 2, GREEN)
local putAwayButton = barButton("Store", 3, GOLD)
local cancelButton = barButton("Cancel", 4, PINK)
local doneButton = barButton("Done", 5, PINK)

-- The hotbar shares the bottom of the screen with these buttons and sits under open menus.
refreshHotbarVisible = function()
	local show = currentPanel == nil and not decorating
	hotbar.Visible = show
	trayLabel.Visible = show
end

local function floorTop(plot)
	local floor = plot.Floor
	return floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)
end

-- Your bakery's floor inside the walls, which grows when you expand it.
local function myBounds()
	return Layout.Bounds(state.Expansion)
end

local function allThings(plot)
	local shapes = {}
	for _, station in Layout.Stations do
		local instance = plot:FindFirstChild(station.Path)
		shapes[station.Id] = instance and Layout.StationShape(station, instance)
	end
	return Layout.AllThings(state.Placed, state.Stations, shapes)
end

local function pieceInstance(plot, key)
	local station = Layout.GetStation(key)
	if station then
		return plot:FindFirstChild(station.Path)
	end
	return plot.Placed:FindFirstChild("Placed_" .. key)
end

local function markerPart(name, size, color, transparency, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Size = size
	part.Color = color
	part.Transparency = transparency
	part.Parent = parent
	return part
end

-- Grid lines on your floor, with the doorway that must stay clear tinted. gridLevel is
-- the bakery size they were drawn for.
local gridLevel = nil

local function showGrid(plot)
	local top = floorTop(plot)
	local bounds = myBounds()
	gridLevel = state.Expansion
	grid = Instance.new("Folder")
	grid.Name = "DecorGrid"
	local columns, rows = bounds.MaxX - bounds.MinX, bounds.MaxZ - bounds.MinZ
	local middleX = (bounds.MinX + bounds.MaxX) / 2
	local middleZ = (bounds.MinZ + bounds.MaxZ) / 2
	for column = 0, columns do
		local line = markerPart("Line", Vector3.new(0.06, 0.02, rows), WHITE, 0.55, grid)
		line.CFrame = top * CFrame.new(bounds.MinX + column, 0.02, middleZ)
	end
	for row = 0, rows do
		local line = markerPart("Line", Vector3.new(columns, 0.02, 0.06), WHITE, 0.55, grid)
		line.CFrame = top * CFrame.new(middleX, 0.02, bounds.MinZ + row)
	end
	local entrance = Layout.Entrance
	local doorwaySize = Vector3.new(entrance.MaxX - entrance.MinX, 0.02, entrance.MaxZ - entrance.MinZ)
	local doorway = markerPart("Doorway", doorwaySize, DOORWAY_COLOR, 0.55, grid)
	doorway.CFrame = top * CFrame.new(Layout.Center(entrance) + Vector3.new(0, 0.03, 0))
	grid.Parent = Workspace
end

-- Grid lines on the back and side walls while a wall piece is held. Each wall is given by
-- one end on the floor, the way it runs, its length and the way it faces.
local function showWallGrid(plot)
	local top = floorTop(plot)
	local height = Layout.WallHeight
	local bounds = myBounds()
	local columns, rows = bounds.MaxX - bounds.MinX, bounds.MaxZ - bounds.MinZ
	local corner = Vector3.new(bounds.MinX, 0, bounds.MinZ)
	local walls = {
		{ start = corner, along = Vector3.xAxis, length = columns, facing = Vector3.zAxis },
		{ start = corner, along = Vector3.zAxis, length = rows, facing = Vector3.xAxis },
		{ start = Vector3.new(bounds.MaxX, 0, bounds.MinZ), along = Vector3.zAxis, length = rows, facing = -Vector3.xAxis },
	}
	wallGrid = Instance.new("Folder")
	wallGrid.Name = "WallGrid"
	for _, wall in walls do
		local base = wall.start + wall.facing * 0.02
		-- Turns a line so its X runs along the wall.
		local turn = CFrame.lookAt(Vector3.zero, wall.facing)
		for step = 0, wall.length do
			local line = markerPart("Line", Vector3.new(0.06, height, 0.02), WHITE, 0.55, wallGrid)
			line.CFrame = top * CFrame.new(base + wall.along * step + Vector3.new(0, height / 2, 0)) * turn
		end
		for row = 0, height do
			local line = markerPart("Line", Vector3.new(wall.length, 0.06, 0.02), WHITE, 0.55, wallGrid)
			line.CFrame = top * CFrame.new(base + wall.along * (wall.length / 2) + Vector3.new(0, row, 0)) * turn
		end
	end
	wallGrid.Parent = Workspace
end

local function hideWallGrid()
	if wallGrid then
		wallGrid:Destroy()
		wallGrid = nil
	end
end

-- The outline under the preview: green or red, a blue strip where customers stand, and
-- an arrow showing which way the piece faces. A wall piece's outline is on the wall
-- behind it, with no arrow.
local marker = Instance.new("Model")
marker.Name = "PlaceMarker"
local markerPad = markerPart("Pad", Vector3.one, OK_COLOR, 0.35, marker)
local markerFront = markerPart("Front", Vector3.one, FRONT_COLOR, 0.5, marker)
local arrowShaft = markerPart("Shaft", Vector3.new(0.3, 0.06, 1), WHITE, 0, marker)
local arrowLeft = markerPart("ArrowLeft", Vector3.new(0.3, 0.06, 1.2), WHITE, 0, marker)
local arrowRight = markerPart("ArrowRight", Vector3.new(0.3, 0.06, 1.2), WHITE, 0, marker)

local ghostHighlight = Instance.new("Highlight")
ghostHighlight.Name = "GhostHighlight"
ghostHighlight.FillTransparency = 0.65
ghostHighlight.Parent = gui
local hoverHighlight = Instance.new("Highlight")
hoverHighlight.Name = "HoverHighlight"
hoverHighlight.FillTransparency = 1
hoverHighlight.OutlineColor = GOLD
hoverHighlight.Parent = gui

local function flatSize(rect, height)
	return Vector3.new(rect.MaxX - rect.MinX, height, rect.MaxZ - rect.MinZ)
end

local function updateMarker(top, thing, ok)
	local rect = thing.Rect
	local center = Layout.Center(rect)
	markerPad.Color = ok and OK_COLOR or BLOCKED_COLOR
	for _, part in { arrowShaft, arrowLeft, arrowRight } do
		part.Transparency = thing.Wall and 1 or 0
	end
	if thing.Wall then
		local size = flatSize(rect, 0)
		local depth = math.abs(size:Dot(thing.Facing))
		local back = center
			- thing.Facing * (depth / 2 - 0.03)
			+ Vector3.new(0, thing.Bottom + thing.Height / 2, 0)
		markerPad.Size = Vector3.new(size.X + size.Z - depth, thing.Height, 0.05)
		markerPad.CFrame = top * CFrame.lookAt(back, back + thing.Facing)
		markerFront.Transparency = 1
		return
	end
	markerPad.Size = flatSize(rect, 0.05)
	markerPad.CFrame = top * CFrame.new(center + Vector3.new(0, 0.05, 0))
	markerFront.Transparency = thing.Front and 0.5 or 1
	if thing.Front then
		markerFront.Size = flatSize(thing.Front, 0.05)
		markerFront.CFrame = top * CFrame.new(Layout.Center(thing.Front) + Vector3.new(0, 0.05, 0))
	end
	local length = math.abs(flatSize(rect, 0):Dot(thing.Facing)) / 2 + 1
	local base = Vector3.new(center.X, 0.12, center.Z)
	local arrow = top * CFrame.lookAt(base, base + thing.Facing)
	arrowShaft.Size = Vector3.new(0.3, 0.06, length)
	arrowShaft.CFrame = arrow * CFrame.new(0, 0, -length / 2)
	local tip = arrow * CFrame.new(0, 0, -length)
	arrowLeft.CFrame = tip * CFrame.Angles(0, ARROW_ANGLE, 0) * CFrame.new(0, 0, 0.6)
	arrowRight.CFrame = tip * CFrame.Angles(0, -ARROW_ANGLE, 0) * CFrame.new(0, 0, 0.6)
end

-- Hides a piece on this screen only while its preview is being moved.
local function setHidden(instance, hide)
	if not instance then
		return
	end
	local objects = instance:GetDescendants()
	table.insert(objects, instance)
	for _, object in objects do
		if object:IsA("BasePart") then
			object.LocalTransparencyModifier = hide and 1 or 0
		elseif object:IsA("BillboardGui") then
			if hide then
				hiddenGuis[object] = object.Enabled
				object.Enabled = false
			elseif hiddenGuis[object] ~= nil then
				object.Enabled = hiddenGuis[object]
				hiddenGuis[object] = nil
			end
		end
	end
end

local function makeGhost(model)
	for _, object in model:GetDescendants() do
		if object:IsA("BasePart") then
			object.Anchored = true
			object.CanCollide = false
			object.CanQuery = false
			object.CanTouch = false
			object.CastShadow = false
			object.LocalTransparencyModifier = 0
			object.Transparency = math.max(object.Transparency, GHOST_TRANSPARENCY)
		elseif table.find(GHOST_REMOVES, object.ClassName) then
			object:Destroy()
		end
	end
	model.Parent = Workspace
	return model
end

local function heldThing()
	local entry = held.entry
	if held.stationId then
		return Layout.StationThing(Layout.GetStation(held.stationId), held.shape, entry)
	end
	return Layout.ItemThing(held.key or "new", { Id = held.itemId, X = entry.X, Z = entry.Z, R = entry.R, Y = entry.Y })
end

local function refreshHeld()
	local plot = myPlot()
	if not held or not plot then
		return
	end
	local top = floorTop(plot)
	held.ghost:PivotTo(Layout.CFrame(top, held.shape, held.entry) * held.base)
	local thing = heldThing()
	local ok, reason = Layout.Check(thing, allThings(plot), myBounds())
	held.ok = ok
	updateMarker(top, thing, ok)
	local color = ok and OK_COLOR or BLOCKED_COLOR
	ghostHighlight.FillColor = color
	ghostHighlight.OutlineColor = color
	local action = held.key and "Moving" or "Placing"
	local surface = held.wall and "a wall" or "the floor"
	placeBanner.Text = ok and ("%s %s: tap or click %s to move it"):format(action, held.name, surface) or reason
	placeBanner.BackgroundColor3 = ok and GREEN or BLOCKED_COLOR
	placeButton.BackgroundColor3 = ok and GREEN or GREY
end

-- Rotate always shows while decorating so players know it's there. It's grey until
-- something is picked up, and for wall pieces, which always face into the room.
local function refreshBar()
	placeBanner.Visible = decorating
	placeBar.Visible = decorating
	rotateButton.BackgroundColor3 = (held and not held.wall) and BLUE or GREY
	placeButton.Visible = held ~= nil
	putAwayButton.Visible = held ~= nil and held.key ~= nil and held.stationId == nil
	cancelButton.Visible = held ~= nil
	doneButton.Visible = held == nil
	if decorating and not held then
		placeBanner.Text = MOVE_HINT
		placeBanner.BackgroundColor3 = GREEN
	end
end

local function hold(info)
	held = info
	setHidden(info.original, true)
	if info.wall then
		showWallGrid(myPlot())
	end
	marker.Parent = Workspace
	ghostHighlight.Adornee = info.ghost
	hoverHighlight.Adornee = nil
	refreshHeld()
	refreshBar()
end

local function pointInFront(plot)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local position = root and root.Position + root.CFrame.LookVector * 8 or plot.Floor.Position
	return plot.Floor.CFrame:PointToObjectSpace(position)
end

-- A new item starts in front of you, facing the door, or on the wall nearest that spot.
-- A placed one starts where it is.
local function holdItem(itemId, key)
	local plot = myPlot()
	local item = Config.GetItem(itemId)
	local shape = Layout.ItemShape(item)
	local entry, paint
	if key then
		local saved = state.Placed[key]
		entry = { X = saved.X, Z = saved.Z, R = saved.R, Y = saved.Y }
		paint = saved.Paint and Config.GetPaint(saved.Paint)
	elseif item.Wall then
		local spot = pointInFront(plot)
		entry = Layout.WallEntryAt(shape, Vector3.new(spot.X, WALL_START_HEIGHT, spot.Z), myBounds())
	else
		entry = Layout.EntryAt(shape, pointInFront(plot), 0, myBounds())
	end
	local ghost = makeGhost(ItemBuilder.Build(item, 1, CFrame.new(), false, paint and paint.Color))
	hold({
		itemId = itemId,
		key = key,
		wall = item.Wall == true,
		name = item.Name,
		shape = shape,
		entry = entry,
		ghost = ghost,
		base = ghost:GetPivot(),
		original = key and pieceInstance(plot, key),
	})
end

local function holdStation(id)
	local plot = myPlot()
	local station = Layout.GetStation(id)
	local instance = plot:FindFirstChild(station.Path)
	local shape = instance and Layout.StationShape(station, instance)
	local saved = state.Stations[id]
	if not shape or not saved then
		return
	end
	local entry = { X = saved.X, Z = saved.Z, R = saved.R }
	local ghost = Instance.new("Model")
	ghost.Name = "Ghost"
	instance:Clone().Parent = ghost
	makeGhost(ghost)
	hold({
		stationId = id,
		key = id,
		name = station.Name,
		shape = shape,
		entry = entry,
		ghost = ghost,
		base = Layout.CFrame(floorTop(plot), shape, entry):ToObjectSpace(ghost:GetPivot()),
		original = instance,
	})
end

local function finishPending()
	if pending then
		pending.ghost:Destroy()
		setHidden(pending.original, false)
		pending = nil
	end
end

-- Lets go of the held piece. When waiting, its preview stays until the server's next
-- update, so the piece doesn't flicker back to its old spot first.
local function drop(waiting)
	if not held then
		return
	end
	local current = held
	held = nil
	ghostHighlight.Adornee = nil
	marker.Parent = nil
	hideWallGrid()
	if waiting then
		finishPending()
		pending = current
	else
		current.ghost:Destroy()
		setHidden(current.original, false)
	end
	refreshBar()
end

local function setDecorating(on)
	if decorating == on then
		return
	end
	decorating = on
	if on then
		local plot = myPlot()
		if plot then
			showGrid(plot)
		end
	else
		drop(false)
		finishPending()
		if grid then
			grid:Destroy()
			grid = nil
		end
		hoverHighlight.Adornee = nil
	end
	refreshHotbarVisible()
	refreshBar()
end

-- With an item Id, holds that item from storage. With nil, starts Move mode.
startPlacing = function(itemId)
	setPanel(nil)
	if not myPlot() then
		return
	end
	setDecorating(true)
	drop(false)
	if itemId then
		holdItem(itemId, nil)
	end
end

-- Where the pointer meets the floor, including the extra floor of a bigger bakery, or the
-- back and side walls while a wall piece is held. The point is in floor space, with Y the
-- height above the floor.
local function surfacePointAt(plot, ray)
	local surfaces = { plot.Floor, plot:FindFirstChild("FloorExtension") }
	if held and held.wall then
		surfaces = {}
		for _, name in WALL_NAMES do
			table.insert(surfaces, plot.Walls[name])
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = surfaces
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	return result and floorTop(plot):PointToObjectSpace(result.Position)
end

-- The nearest piece the pointer passes through. Each piece is a box made of its grid
-- cells and its height, so clicking the front of a tall piece by a wall still finds it,
-- and a wall piece is found up on its wall.
local function pieceOnRay(plot, ray)
	local top = floorTop(plot)
	local origin = top:PointToObjectSpace(ray.Origin)
	local direction = top:VectorToObjectSpace(ray.Direction)
	local nearest, nearestDistance = nil, math.huge
	for _, thing in allThings(plot) do
		local rect = thing.Rect
		local low = Vector3.new(rect.MinX, thing.Bottom, rect.MinZ)
		local high = Vector3.new(rect.MaxX, thing.Bottom + thing.Height, rect.MaxZ)
		local enter, exit = 0, math.huge
		for _, axis in { "X", "Y", "Z" } do
			local start, step = origin[axis], direction[axis]
			if math.abs(step) < 1e-6 then
				if start < low[axis] or start > high[axis] then
					enter = math.huge
				end
			else
				local near, far = (low[axis] - start) / step, (high[axis] - start) / step
				enter = math.max(enter, math.min(near, far))
				exit = math.min(exit, math.max(near, far))
			end
		end
		if enter <= exit and enter < nearestDistance then
			nearest, nearestDistance = thing, enter
		end
	end
	return nearest
end

local function pickUp(thing)
	finishPending()
	if Layout.GetStation(thing.Key) then
		holdStation(thing.Key)
	else
		holdItem(state.Placed[thing.Key].Id, thing.Key)
	end
end

-- A wall piece moves along the walls and up them, and can go to another wall.
local function moveHeldTo(point)
	local current = held.entry
	local entry
	if held.wall then
		entry = Layout.WallEntryAt(held.shape, point, myBounds())
	else
		entry = Layout.EntryAt(held.shape, point, current.R, myBounds())
	end
	if entry.X ~= current.X or entry.Z ~= current.Z or entry.R ~= current.R or entry.Y ~= current.Y then
		held.entry = entry
		refreshHeld()
	end
end

-- The held piece's middle, in the same space as surfacePointAt.
local function heldMiddle()
	local middle = Layout.Center(Layout.Rect(held.shape, held.entry))
	if held.wall then
		return middle + Vector3.new(0, held.entry.Y + held.shape.H / 2, 0)
	end
	return middle
end

local function rotateHeld()
	if held and held.wall then
		placeBanner.Text = WALL_ROTATE_HINT
		bannerHintUntil = os.clock() + BANNER_HINT_TIME
	elseif held then
		held.entry = Layout.Rotated(held.shape, held.entry, myBounds())
		refreshHeld()
	elseif decorating then
		placeBanner.Text = ROTATE_HINT
		bannerHintUntil = os.clock() + BANNER_HINT_TIME
	end
end

local function tryPlace()
	if not held or not held.ok then
		return
	end
	local entry = held.entry
	if held.key then
		placeEvent:FireServer("Move", held.key, entry.X, entry.Z, entry.R, entry.Y)
	else
		placeEvent:FireServer("New", held.itemId, entry.X, entry.Z, entry.R, entry.Y)
	end
	drop(true)
end

rotateButton.Activated:Connect(rotateHeld)
placeButton.Activated:Connect(tryPlace)
cancelButton.Activated:Connect(function()
	drop(false)
end)
putAwayButton.Activated:Connect(function()
	if held and held.key then
		placeEvent:FireServer("Store", held.key)
		drop(true)
	end
end)
doneButton.Activated:Connect(function()
	setDecorating(false)
end)

local function pointerOverGui(position)
	for _, object in player.PlayerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
		if object:IsDescendantOf(gui) then
			return true
		end
	end
	return false
end

-- With a mouse and nothing held, the piece under the pointer is outlined.
RunService.RenderStepped:Connect(function()
	local plot = myPlot()
	if not decorating or held or not plot or not UserInputService.MouseEnabled then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	if pointerOverGui(mouse - GuiService:GetGuiInset()) then
		return
	end
	local thing = pieceOnRay(plot, Workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y))
	hoverHighlight.Adornee = thing and pieceInstance(plot, thing.Key)
	if os.clock() >= bannerHintUntil then
		placeBanner.Text = thing and ("Click to move the " .. thing.Name:lower()) or MOVE_HINT
	end
end)

local function screenPoint(plot, position)
	return surfacePointAt(plot, Workspace.CurrentCamera:ScreenPointToRay(position.X, position.Y))
end

-- With a mouse, clicking a piece picks it up, and clicking or dragging on the floor, or
-- on a wall for a wall piece, moves the held piece. It stays put when the pointer goes to
-- the Rotate or Place button. While dragging, the piece keeps its offset from the pointer
-- so it doesn't jump.
local dragOffset = nil

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not decorating then
		return
	end
	local plot = myPlot()
	if input.KeyCode == Enum.KeyCode.R then
		rotateHeld()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and plot then
		if held then
			local point = screenPoint(plot, input.Position)
			if point then
				moveHeldTo(point)
				dragOffset = Vector3.zero
			end
		else
			local ray = Workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y)
			local thing = pieceOnRay(plot, ray)
			if thing then
				pickUp(thing)
				local point = held and screenPoint(plot, input.Position)
				dragOffset = point and heldMiddle() - point
			end
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	local plot = myPlot()
	if dragOffset and held and plot and input.UserInputType == Enum.UserInputType.MouseMovement then
		local point = screenPoint(plot, input.Position)
		if point then
			moveHeldTo(point + dragOffset)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragOffset = nil
	end
end)

-- On a phone, a tap moves the preview there, or picks up the piece that was tapped. A
-- wall piece moves to the wall that was tapped.
UserInputService.TouchTap:Connect(function(positions, processed)
	local plot = myPlot()
	if processed or not decorating or not plot then
		return
	end
	local position = positions[1]
	local ray = Workspace.CurrentCamera:ScreenPointToRay(position.X, position.Y)
	if held then
		local point = surfacePointAt(plot, ray)
		if point then
			moveHeldTo(point)
		end
	else
		local thing = pieceOnRay(plot, ray)
		if thing then
			pickUp(thing)
		end
	end
end)

-- Drops a held piece that has gone from storage or from the bakery, and rechecks the
-- preview against the latest layout.
local function refreshDecorating()
	finishPending()
	if not decorating then
		return
	end
	-- The bakery grew, so the grids are drawn again at the new size.
	local plot = myPlot()
	if plot and gridLevel ~= state.Expansion then
		if grid then
			grid:Destroy()
		end
		showGrid(plot)
		if wallGrid then
			hideWallGrid()
			showWallGrid(plot)
		end
	end
	if held and not held.stationId then
		local gone = held.key ~= nil and state.Placed[held.key] == nil
		local noneLeft = held.key == nil and state.Owned[held.itemId] - placedCount(held.itemId) <= 0
		if gone or noneLeft then
			drop(false)
		end
	end
	refreshHeld()
	refreshBar()
end

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
	refreshBoostButton()
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
	refreshDecorating()
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
	if prompt:GetAttribute("Action") == "UnpackCrate" then
		prompt.Triggered:Connect(function()
			unpackCrateEvent:FireServer()
		end)
	elseif prompt:GetAttribute("Action") == "TakeFlyers" then
		prompt.Triggered:Connect(function()
			takeFlyersEvent:FireServer()
		end)
	end
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

-- Helpers walk around the bakery too, so their limbs swing the same way.
for _, tag in { "Customer", "Helper" } do
	for _, model in CollectionService:GetTagged(tag) do
		task.spawn(watchCustomer, model)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(watchCustomer)
end

-- A customer on their way to a bakery thinks of the treat they want: a white cloud with
-- two small puffs trailing down to their head, sized in studs so it shrinks with distance.
local function thoughtBubble(root, recipeIndex)
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "Thought"
	bubble.Size = UDim2.fromScale(3, 3)
	bubble.StudsOffset = Vector3.new(1.2, 4.3, 0)
	bubble.MaxDistance = 80
	local function puff(size, position)
		local circle = Instance.new("Frame")
		circle.Size = size
		circle.Position = position
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.BackgroundColor3 = WHITE
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = circle
		local stroke = Instance.new("UIStroke")
		stroke.Color = PINK
		stroke.Thickness = 2
		stroke.Parent = circle
		circle.Parent = bubble
		return circle
	end
	puff(UDim2.fromScale(0.12, 0.12), UDim2.fromScale(0.12, 0.94))
	puff(UDim2.fromScale(0.2, 0.2), UDim2.fromScale(0.26, 0.78))
	local cloud = puff(UDim2.fromScale(0.72, 0.72), UDim2.fromScale(0.6, 0.38))
	local icon = Instance.new("ViewportFrame")
	icon.Size = UDim2.fromScale(0.8, 0.8)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.Ambient = Color3.fromRGB(200, 200, 200)
	icon.LightColor = WHITE
	icon.Parent = cloud
	showTreat(icon, recipeIndex)
	bubble.Parent = root
	return bubble
end

local function watchWants(model)
	local root = model:WaitForChild("Torso", 5)
	if not root then
		return
	end
	local bubble
	local function update()
		if bubble then
			bubble:Destroy()
			bubble = nil
		end
		local recipeIndex = model:GetAttribute("Wants")
		if recipeIndex and Config.Recipes[recipeIndex] then
			bubble = thoughtBubble(root, recipeIndex)
		end
	end
	model:GetAttributeChangedSignal("Wants"):Connect(update)
	update()
end

for _, model in CollectionService:GetTagged("Customer") do
	task.spawn(watchWants, model)
end
CollectionService:GetInstanceAddedSignal("Customer"):Connect(watchWants)

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
