-- Draws the HUD and menus, handles placing items, plays sounds, points at the next
-- task, animates the townsfolk, and shows only your own bakery's prompts.
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
local setRunningEvent = ReplicatedStorage:WaitForChild("SetRunning")

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
-- Deliveries and the Cookbook open at their counters in the bakery, so they have no button.
local employeesButton = button("EmployeesButton", UDim2.fromOffset(120, 44), UDim2.fromOffset(10, 174), TOP_LEFT, BLUE)
employeesButton.Text = "Employees"
local boostButton = button("BoostButton", UDim2.fromOffset(120, 44), UDim2.fromOffset(10, 222), TOP_LEFT, BLUE)
boostButton.Text = "Boosts"
local storeButton = button("StoreButton", UDim2.fromOffset(44, 68), UDim2.fromOffset(134, 6), TOP_LEFT, GREEN)
storeButton.Text = "+"
-- Bake Together. It sits up here because the left column is already full on phones.
local friendsButton = button("FriendsButton", UDim2.fromOffset(44, 44), UDim2.fromOffset(134, 78), TOP_LEFT, PINK)
friendsButton.Text = "👫"
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

-- Walk/Run switch, to the right of the hotbar. The server sets the speed, and the switch
-- shows the new choice straight away.
local moveSwitch = Instance.new("Frame")
moveSwitch.Name = "MoveSwitch"
moveSwitch.Size = UDim2.fromOffset(64, SLOT_SIZE)
moveSwitch.Position = UDim2.new(0.5, HOTBAR_WIDTH / 2 + SLOT_GAP * 2, 1, -8)
moveSwitch.AnchorPoint = Vector2.new(0, 1)
moveSwitch.BackgroundTransparency = 1
moveSwitch.Parent = gui

local function moveButton(name, top)
	local position = top and UDim2.new() or UDim2.new(0, 0, 0.5, 2)
	local object = button(name .. "Button", UDim2.new(1, 0, 0.5, -2), position, TOP_LEFT, CREAM, moveSwitch)
	object.Text = name
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = PINK
	stroke.Thickness = SLOT_NORMAL_STROKE
	stroke.Parent = object
	return object
end

local walkButton = moveButton("Walk", true)
local runButton = moveButton("Run", false)
local isRunning = false

local function showRunning(on)
	isRunning = on
	walkButton.BackgroundColor3 = on and CREAM or BLUE
	walkButton.TextColor3 = on and BROWN or WHITE
	runButton.BackgroundColor3 = on and GREEN or CREAM
	runButton.TextColor3 = on and WHITE or BROWN
end
showRunning(false)

local function setRunning(on)
	if on ~= isRunning then
		showRunning(on)
		setRunningEvent:FireServer(on)
	end
end
walkButton.Activated:Connect(function()
	setRunning(false)
end)
runButton.Activated:Connect(function()
	setRunning(true)
end)

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
-- label, and TextColor is white unless given. icon is an optional image shown on the left.
local function addRow(title, detail, actions, icon)
	rowOrder += 1
	local row = style(Instance.new("Frame"), "Row", UDim2.new(1, -12, 0, 62), UDim2.new(), TOP_LEFT, WHITE)
	row.LayoutOrder = rowOrder
	row.ZIndex = 6
	row.Parent = rowList
	local reserved = #actions * 104 + 10
	local textX = 4
	if icon then
		local picture = Instance.new("ImageLabel")
		picture.Name = "Icon"
		picture.Size = UDim2.fromOffset(54, 54)
		picture.Position = UDim2.fromOffset(4, 4)
		picture.BackgroundTransparency = 1
		picture.Image = icon
		picture.ZIndex = 7
		picture.Parent = row
		textX = 62
	end
	local textWidth = UDim2.new(1, 4 - reserved - textX, 0, 28)
	local titleLabel = label("Heading", textWidth, UDim2.fromOffset(textX, 3), TOP_LEFT, WHITE, BROWN, row)
	titleLabel.Text = title
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 7
	local detailLabel = label("Detail", textWidth, UDim2.fromOffset(textX, 31), TOP_LEFT, WHITE, BROWN, row)
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

-- Several helpers take an optional source: state.Work, the bakery a co-baker is working
-- in, instead of the player's own state.
local function salePrice(recipe, source)
	local bonus = Config.GetUpgrade("Ingredients").Levels[(source or state).Levels.Ingredients].PriceBonus
	-- Rounded to the nearest coin, as the server does.
	return math.floor(recipe.Price * (1 + bonus) + 0.5)
end

-- Boosts. Their times count down here from the server's clock.
local function secondsUntil(time)
	return math.max(0, math.ceil(time - Workspace:GetServerTimeNow()))
end

local function clockText(seconds)
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function bakeSaleLeft(source)
	return secondsUntil((source or state).BakeSaleAt + Config.BakeSale.Duration)
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
local function customerPrice(recipe, source)
	local price = salePrice(recipe, source)
	if bakeSaleLeft(source) > 0 then
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

-- Each ingredient a recipe uses as needed/in the pantry, like "Flour 1/12, Butter 1/0",
-- with the short ones in red (for a RichText label). Also returns true when any is short.
local function ingredientCounts(recipe, source)
	local pantry = (source or state).Pantry
	local parts = {}
	local short = false
	for _, ingredient in Config.Ingredients do
		local need = recipe.Ingredients[ingredient.Id]
		if need then
			local text = ("%s %d/%d"):format(ingredient.Name, need, pantry[ingredient.Id])
			if pantry[ingredient.Id] < need then
				short = true
				text = ('<font color="#D23C3C">%s</font>'):format(text)
			end
			table.insert(parts, text)
		end
	end
	return table.concat(parts, ", "), short
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
local currentPanel = nil
local refreshPanel
local refreshHotbarVisible
local startPlacing
-- The dressing room for employees, built further down.
local wardrobe

local panels = {}
-- The Sweet Stash: placing Stash Shelves in its room, and Customize mode, where tapping a
-- display case chooses its treat. Its functions are defined further down.
local stash = {}

function panels.Shop()
	panelTitle.Text = "Bakery Shop"
	for _, upgrade in Config.Upgrades do
		local levelIndex = state.Levels[upgrade.Id]
		local nextLevel = upgrade.Levels[levelIndex + 1]
		if nextLevel and nextLevel.NeedLevel and state.BakeryLevel < nextLevel.NeedLevel then
			addRow(upgrade.Name, upgrade.Describe(nextLevel), { { Text = "Level " .. nextLevel.NeedLevel, Color = GREY } })
		elseif nextLevel then
			local color = state.Coins >= nextLevel.Cost and GREEN or GREY
			addRow(upgrade.Name, upgrade.Describe(nextLevel), {
				{
					Text = withCommas(nextLevel.Cost) .. " coins",
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
	-- The Sweet Stash is bought once.
	local room = Config.Stash
	if state.Stash then
		addRow(room.Name, "Bought! It's through the door in your back wall", { { Text = "Owned", Color = GREY } })
	else
		addRow(room.Name, room.Detail, {
			{
				Text = withCommas(room.Coins) .. " coins",
				Color = state.Coins >= room.Coins and GREEN or GREY,
				OnClick = function()
					purchaseEvent:FireServer("Stash")
				end,
			},
		})
	end
end

-- A co-baker opens this at their friend's counter, and sees their own recipes and goals.
function panels.Cookbook()
	panelTitle.Text = state.Work and "Your Cookbook" or "Cookbook"
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
		elseif recipe.UnlockLevel then
			-- Learned on reaching a Bakery Level, once the recipes before it are known.
			addRow(recipe.Name, detail, { { Text = "Level " .. recipe.UnlockLevel, Color = GREY } })
		elseif index == state.RecipesUnlocked + 1 then
			addRow(recipe.Name, detail, {
				{
					Text = withCommas(recipe.UnlockCost) .. " coins",
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
	if state.Work then
		return
	end
	addHeader(("Restaurant %d"):format(state.Restaurant))
	local need = ("At Bakery Level %d with %d employees, open a new restaurant. It starts over with its own coins and gets %d%% more customers, and this one keeps running by itself."):format(
		Config.BakeryLevel.Max,
		Config.Restaurants.Employees,
		math.floor(Config.Restaurants.CustomerBonus * 100 + 0.5)
	)
	addRow("Open a new restaurant", need, {
		state.CanOpenRestaurant and {
			Text = "Open",
			Color = GREEN,
			OnClick = function()
				panels.askYesNo(
					("Open Restaurant %d?"):format(state.RestaurantsOpened + 1),
					"It starts over: coins, level, recipes, upgrades, decor and employees. Stars and passes come with you",
					function()
						ReplicatedStorage:WaitForChild("OpenRestaurant"):FireServer()
					end
				)
			end,
		} or { Text = "Locked", Color = GREY },
	})
end

-- A co-baker sees the pantry of the bakery they're working in.
function panels.Pantry()
	local work = state.Work or state
	local whose = state.Work and state.Work.OwnerName .. "'s pantry" or "Pantry"
	panelTitle.Text = ("%s (holds %d of each)"):format(whose, work.PantryCapacity)
	for _, ingredient in Config.Ingredients do
		local count = work.Pantry[ingredient.Id]
		local detail = ("%s %d of %d"):format(state.Work and "It has" or "You have", count, work.PantryCapacity)
		addRow(ingredient.Name, detail, { { Text = tostring(count), Color = count > 0 and GREEN or GREY } })
	end
	addHeader("Getting more")
	addRow("Free delivery crate", ("Arrives outside your door every %d seconds"):format(Config.Crate.Interval), {})
	addRow("Grocery store", ("On the town square: %d of anything for a few coins"):format(Config.GroceryBundle), {})
	addRow("Bigger Pantry", "Buy it in the Shop to store more of each", {})
end

-- The grocery store. Each ingredient has its bundle button and, when more than a bundle
-- fits, a fill-up button on its left. Buy all at the top fills every ingredient, after a
-- box over the menu shows the total. The box closes with the menu (see setPanel).
do
	local box = style(
		Instance.new("Frame"),
		"Confirm",
		UDim2.fromOffset(360, 200),
		UDim2.fromScale(0.5, 0.5),
		Vector2.new(0.5, 0.5),
		CREAM
	)
	box.Active = true
	box.Visible = false
	box.ZIndex = 12
	box.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = PINK
	stroke.Thickness = 3
	stroke.Parent = box
	local question = label("Question", UDim2.new(1, -16, 0, 64), UDim2.fromOffset(8, 10), TOP_LEFT, CREAM, BROWN, box)
	question.ZIndex = 13
	local note = label("Note", UDim2.new(1, -16, 0, 34), UDim2.fromOffset(8, 78), TOP_LEFT, CREAM, BROWN, box)
	note.ZIndex = 13
	local no = button("No", UDim2.new(0.5, -12, 0, 52), UDim2.new(0, 8, 1, -10), Vector2.new(0, 1), PINK, box)
	no.Text = "No"
	no.ZIndex = 13
	local yes = button("Yes", UDim2.new(0.5, -12, 0, 52), UDim2.new(1, -8, 1, -10), Vector2.new(1, 1), GREEN, box)
	yes.Text = "Yes"
	yes.ZIndex = 13
	local ok = button("Ok", UDim2.new(0.5, -12, 0, 52), UDim2.new(0.5, 0, 1, -10), Vector2.new(0.5, 1), GREEN, box)
	ok.Text = "OK"
	ok.ZIndex = 13
	-- Other menus borrow this box through panels.askYesNo. While they do, Yes runs theirs.
	local custom = nil

	-- How many ingredients filling the pantry takes, and what they cost.
	local function everything()
		local count, total = 0, 0
		for _, ingredient in Config.Ingredients do
			local room = state.PantryCapacity - state.Pantry[ingredient.Id]
			if room > 0 then
				count += room
				total += Config.GroceryPrice(ingredient, room)
			end
		end
		return count, total
	end

	-- The box asks Yes / No when the coins are there, and otherwise just says how many more
	-- are needed, with OK. If that changes while it's open, it closes rather than swap the
	-- buttons under the player's finger.
	local function updateBox(opening)
		if custom then
			return
		end
		local count, total = everything()
		local short = total - state.Coins
		if count == 0 or (not opening and (short <= 0) ~= yes.Visible) then
			box.Visible = false
			return
		end
		yes.Visible = short <= 0
		no.Visible = short <= 0
		ok.Visible = short > 0
		if short > 0 then
			question.Text = ("Filling your pantry costs %s coins"):format(withCommas(total))
			note.Text = ("You need %s more coins"):format(withCommas(short))
		else
			question.Text = ("Buy %d ingredients for %s coins?"):format(count, withCommas(total))
			note.Text = "This fills your whole pantry"
		end
	end

	for _, close in { no, ok } do
		close.Activated:Connect(function()
			box.Visible = false
			custom = nil
		end)
	end
	yes.Activated:Connect(function()
		if custom then
			local run = custom
			custom = nil
			box.Visible = false
			run()
			return
		end
		local count, total = everything()
		if count > 0 and total <= state.Coins then
			buyGroceriesEvent:FireServer("All", total)
			box.Visible = false
		end
	end)

	-- A Yes / No box over any menu. It isn't a menu itself, so setPanel never opens it.
	function panels.askYesNo(questionText, noteText, onYes)
		custom = onYes
		question.Text = questionText
		note.Text = noteText
		yes.Visible, no.Visible, ok.Visible = true, true, false
		box.Visible = true
	end

	function panels.Grocery()
		panelTitle.Text = "Grocery Store"
		local fillAll = everything() > 0 and {
			Text = "Buy all",
			Color = GOLD,
			OnClick = function()
				custom = nil
				updateBox(true)
				box.Visible = true
			end,
		} or { Text = "Full", Color = GREY }
		addRow("Buy all", ("Fills every ingredient up to %d"):format(state.PantryCapacity), { fillAll })
		addHeader(("Bundles of %d. Your pantry holds %d of each"):format(Config.GroceryBundle, state.PantryCapacity))
		for _, ingredient in Config.Ingredients do
			local have = state.Pantry[ingredient.Id]
			local space = state.PantryCapacity - have
			local amount = math.min(Config.GroceryBundle, space)
			local detail = ("You have %d of %d"):format(have, state.PantryCapacity)
			if amount <= 0 then
				addRow(ingredient.Name, detail, { { Text = "Full", Color = GREY } })
			else
				local price = Config.GroceryPrice(ingredient, amount)
				local actions = {
					{
						Text = Config.CoinText(price),
						Color = state.Coins >= price and GREEN or GREY,
						OnClick = function()
							buyGroceriesEvent:FireServer(ingredient.Id)
						end,
					},
				}
				-- When more than a bundle fits, this one fills the rest in one go.
				if space > Config.GroceryBundle then
					local fillPrice = Config.GroceryPrice(ingredient, space)
					table.insert(actions, {
						Text = ("x%d\n%s"):format(space, Config.CoinText(fillPrice)),
						Color = state.Coins >= fillPrice and GREEN or GREY,
						OnClick = function()
							buyGroceriesEvent:FireServer(ingredient.Id, "Fill")
						end,
					})
				end
				addRow(("%s x%d"):format(ingredient.Name, amount), detail, actions)
			end
		end
		if box.Visible then
			updateBox()
		end
	end
end

-- A co-baker bakes the owner's recipes with the owner's ingredients and oven upgrades.
function panels.Bake()
	panelTitle.Text = "What should we bake?"
	local work = state.Work or state
	local ovenTime = Config.GetUpgrade("Oven").Levels[work.Levels.Oven].BakeTime
	local batch = Config.GetUpgrade("Batch").Levels[work.Levels.Batch].BatchSize
	for index = 1, work.RecipesUnlocked do
		local recipe = Config.Recipes[index]
		local title =
			("%s: %d in %.1fs, %s each"):format(recipe.Name, batch, ovenTime * recipe.BakeScale, Config.CoinText((customerPrice(recipe, work))))
		local counts, short = ingredientCounts(recipe, work)
		local action = short and { Text = "Need more", Color = GREY }
			or {
				Text = "Bake",
				Color = GREEN,
				OnClick = function()
					bakeEvent:FireServer(index)
					setPanel(nil)
				end,
			}
		addRow(title, counts, { action }).Detail.RichText = true
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

-- Your paintable pieces, like display cases, in a steady order, each with a numbered name
-- and where it stands.
local function paintablePieces()
	local keys = {}
	for key, entry in state.Placed do
		if Config.IsPaintable(Config.GetItem(entry.Id)) then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	local counts, pieces = {}, {}
	for _, key in keys do
		local entry = state.Placed[key]
		local item = Config.GetItem(entry.Id)
		counts[item.Id] = (counts[item.Id] or 0) + 1
		local rect = Layout.Rect(Layout.ItemShape(item), entry)
		table.insert(pieces, { Key = key, Item = item, Name = ("%s %d"):format(item.Name, counts[item.Id]), Where = whereIs(rect) })
	end
	return pieces
end

-- Laying floor tiles, set up with the other decorating further down.
local tiling = {}

-- The Paint tab lists everything that can be painted. Choosing one lists its colours, and
-- paintChoice remembers which it is: { Target = paint target }, { PieceKey, Item, Name }
-- or { Floor = true } for the floor tile styles. Buying a paintable piece lists its
-- colours too, with { NewItem = item, Price = its price as text }.
local paintChoice = nil

local function choosePaint(choice)
	paintChoice = choice
	setPanel("Decorate")
end

-- A heading with Back, then a row per colour with a button in that colour showing
-- priceText. current is the colour it has now and original the one it started in, if
-- any. canUse can leave colours out, and onPick is given the chosen paint.
local function colourRows(heading, detail, current, original, priceText, canUse, onPick)
	addRow(heading, detail, {
		{
			Text = "Back",
			Color = BLUE,
			OnClick = function()
				choosePaint(nil)
			end,
		},
	})
	for _, paint in Config.Paints do
		if not canUse or canUse(paint) then
			local isNow = paint.Id == current
			local action = { Text = isNow and "Now" or priceText, Color = paint.Color, TextColor = textOn(paint.Color) }
			if not isNow then
				action.OnClick = function()
					onPick(paint)
				end
			end
			local about = ("Paint it %s"):format(paint.Name)
			if isNow then
				about = "Its colour now"
			elseif paint.Id == original then
				about = "Its original colour"
			end
			addRow(paint.Name, about, { action })
		end
	end
end

local function paintRows()
	if paintChoice and paintChoice.PieceKey and not state.Placed[paintChoice.PieceKey] then
		paintChoice = nil
	end
	local target = paintChoice and paintChoice.Target
	if target then
		colourRows(
			"Painting: " .. target.Name,
			"Pick a colour, or go back to the list",
			state.Paint[target.Id] or target.Original,
			target.Original,
			target.Coins .. " coins",
			function(paint)
				return Config.CanPaint(target, paint)
			end,
			function(paint)
				purchaseEvent:FireServer("Paint", target.Id, paint.Id)
			end
		)
		return
	elseif paintChoice and paintChoice.PieceKey then
		local key, item = paintChoice.PieceKey, paintChoice.Item
		colourRows(
			"Painting: " .. paintChoice.Name,
			"Pick a colour, or go back to the list",
			state.Placed[key].Paint or Config.OriginalPaint(item),
			Config.OriginalPaint(item),
			Config.PiecePaintCoins .. " coins",
			nil,
			function(paint)
				purchaseEvent:FireServer("PaintCase", key, paint.Id)
			end
		)
		return
	elseif paintChoice and paintChoice.Floor then
		addRow("Floor tiles", "Pick a style, then tap the tiles on your floor to lay it", {
			{
				Text = "Back",
				Color = BLUE,
				OnClick = function()
					choosePaint(nil)
				end,
			},
		})
		for _, style in Config.Floors do
			local free = style.Coins == 0
			local detail = free and "Your bakery's own floor. Takes tiles up for free"
				or ("%s a tile%s"):format(Config.CoinText(style.Coins), style.Check and ", in a checkerboard" or "")
			addRow(style.Name, detail, {
				{
					Text = free and "Free" or Config.CoinText(style.Coins),
					Color = style.Color,
					TextColor = textOn(style.Color),
					OnClick = function()
						tiling.start(style)
					end,
				},
			})
		end
		return
	end
	local cheapest, dearest = math.huge, 0
	for _, style in Config.Floors do
		if style.Coins > 0 then
			cheapest, dearest = math.min(cheapest, style.Coins), math.max(dearest, style.Coins)
		end
	end
	addRow("Floor tiles", ("Tile your floor in wood, marble, stone or pastels, %d to %d coins a tile"):format(cheapest, dearest), {
		{
			Text = "Tiles",
			Color = BLUE,
			OnClick = function()
				choosePaint({ Floor = true })
			end,
		},
	})
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
	for _, piece in paintablePieces() do
		local current = Config.GetPaint(state.Placed[piece.Key].Paint or Config.OriginalPaint(piece.Item))
		addRow(piece.Name, ("%s. %s now, %d coins to repaint"):format(piece.Where, current.Name, Config.PiecePaintCoins), {
			{
				Text = "Paint",
				Color = BLUE,
				OnClick = function()
					choosePaint({ PieceKey = piece.Key, Item = piece.Item, Name = piece.Name })
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
		if state.Garden then
			detail ..= ". Garden plants in the way go to your Inventory"
		end
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

-- What selling one of an item pays, as text like "30 coins", or nil and why it can't be
-- sold. Placed is true for a piece in the bakery, since your last display case stays.
local function saleText(item, placed)
	if placed and item.Slots and not item.Room then
		local cases = 0
		for _, entry in state.Placed do
			local piece = Config.GetItem(entry.Id)
			if piece.Slots and not piece.Room then
				cases += 1
			end
		end
		if cases <= 1 then
			return nil, "Keep at least one display case so customers can shop"
		end
	end
	local amount, currency = Config.SellValue(item, state.Owned[item.Id])
	if not amount then
		return nil, currency
	end
	return currency == "Stars" and starText(amount) or withCommas(amount) .. " coins"
end

-- The Inventory tab's Sell needs a second tap, so sellConfirm remembers which item is
-- waiting for it and until when: { Id, Until }.
local sellConfirm = nil

local function inventoryRows()
	local any = false
	for _, item in Config.Items do
		local stored = state.Owned[item.Id] - placedCount(item.Id)
		if Config.IsAllowed(item, player.UserId) and stored > 0 then
			any = true
			local price, reason = saleText(item, false)
			local actions = {
				{
					Text = "Place",
					Color = BLUE,
					OnClick = function()
						startPlacing(item.Id)
					end,
				},
			}
			if price then
				local asking = sellConfirm and sellConfirm.Id == item.Id and os.clock() < sellConfirm.Until
				table.insert(actions, {
					Text = asking and "Sure?" or "Sell",
					Color = GOLD,
					OnClick = function()
						if sellConfirm and sellConfirm.Id == item.Id and os.clock() < sellConfirm.Until then
							sellConfirm = nil
							placeEvent:FireServer("SellSpare", item.Id)
							return
						end
						local confirm = { Id = item.Id, Until = os.clock() + Config.SellConfirmSeconds }
						sellConfirm = confirm
						refreshPanel()
						task.delay(Config.SellConfirmSeconds, function()
							if sellConfirm == confirm then
								sellConfirm = nil
								if currentPanel == "Decorate" then
									refreshPanel()
								end
							end
						end)
					end,
				})
			end
			local detail = price and ("You have %d. Sells for %s each"):format(stored, price)
				or ("You have %d. %s"):format(stored, reason)
			addRow(item.Name, detail, actions)
		end
	end
	if not any then
		addRow("Your inventory is empty", "Pick something up with Move things and press Inventory to keep it here", {})
	end
end

-- Floor has everything that stands on the floor, Wall has wall pieces, Inventory has the
-- pieces you've put away, Paint colours the walls, oven and pieces and tiles the floor,
-- and Expansion makes the bakery bigger.
local DECOR_TABS = { "Floor", "Wall", "Inventory", "Paint", "Expansion" }
local decorTab = "Floor"

function panels.Decorate()
	panelTitle.Text = ("Decorate (Charm %d)"):format(state.Charm)
	showTabs(DECOR_TABS, decorTab, function(name)
		decorTab = name
		choosePaint(nil)
	end)
	-- Buying a paintable piece: its colour comes with it.
	local newItem = paintChoice and paintChoice.NewItem
	if newItem then
		local heading = "New " .. newItem.Name
		local detail = ("Pick its colour. It's free with the %s"):format(newItem.Name:lower())
		colourRows(heading, detail, nil, Config.OriginalPaint(newItem), paintChoice.Price, nil, function(paint)
			purchaseEvent:FireServer("Item", newItem.Id, paint.Id)
			choosePaint(nil)
		end)
		return
	end
	if decorTab == "Paint" then
		paintRows()
		return
	elseif decorTab == "Expansion" then
		expansionRows()
		return
	elseif decorTab == "Inventory" then
		inventoryRows()
		return
	end
	-- A paintable piece you can pay for asks for its colour first. Otherwise the server
	-- buys it, or says what's missing.
	local function buyItem(item, priceText, canPay)
		if canPay and Config.IsPaintable(item) then
			choosePaint({ NewItem = item, Price = priceText })
		else
			purchaseEvent:FireServer("Item", item.Id)
		end
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
	-- Stash Shelves are bought at The Sweet Stash's whiteboard instead.
	for _, item in Config.Items do
		local tab = (item.Wall == true) == (decorTab == "Wall")
		if Config.IsAllowed(item, player.UserId) and tab and not item.Room then
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
				if state.Passes[item.Pass] and item.ExtraCoins then
					detail = ("Charm +%d for the first one only. You have %d to place"):format(item.Charm, stored)
					local canPay = state.Coins >= item.ExtraCoins
					actions = {
						{
							Text = item.ExtraCoins .. " coins",
							Color = canPay and GREEN or GREY,
							OnClick = function()
								buyItem(item, item.ExtraCoins .. " coins", canPay)
							end,
						},
					}
				elseif state.Passes[item.Pass] then
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
							buyItem(item, priceText, canPay)
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

-- The Sweet Stash's whiteboard: Stash Shelves to buy and place, and Customize mode.
function panels.Whiteboard()
	panelTitle.Text = Config.Stash.Name
	local shelf = Config.GetItem("StashShelf")
	local stored = state.Owned[shelf.Id] - placedCount(shelf.Id)
	local actions = {
		{
			Text = shelf.Coins .. " coins",
			Color = state.Coins >= shelf.Coins and GREEN or GREY,
			OnClick = function()
				purchaseEvent:FireServer("Item", shelf.Id)
			end,
		},
	}
	if stored > 0 then
		table.insert(actions, {
			Text = "Place",
			Color = BLUE,
			OnClick = function()
				startPlacing(shelf.Id)
			end,
		})
	end
	addRow(shelf.Name, ("Holds %d extra treats for the Stocker. You have %d to place"):format(#shelf.Slots, stored), actions)
	addRow("Customize store shelves", "Choose which treat the Stocker puts in each display case", {
		{
			Text = "Start",
			Color = BLUE,
			OnClick = function()
				stash.startMarking()
			end,
		},
	})
end

-- Choosing the one treat the Stocker puts in the display case tapped in Customize mode.
function panels.CaseTreat()
	local key = stash.caseKey
	local entry = key and state.Placed[key]
	if not entry then
		panelTitle.Text = "Display case"
		addRow("That case has moved", "Close this and tap it again", {})
		return
	end
	panelTitle.Text = Config.GetItem(entry.Id).Name .. ": which treat?"
	local function choose(treat)
		local chosen = entry.Treat == treat
		return {
			{
				Text = chosen and "Chosen" or "Choose",
				Color = chosen and GREY or GREEN,
				OnClick = function()
					placeEvent:FireServer("Treat", key, treat)
					setPanel(nil)
				end,
			},
		}
	end
	addRow("Any treat", "First come, first served: the Stocker puts any treat here", choose(nil))
	for index = 1, state.RecipesUnlocked do
		local recipe = Config.Recipes[index]
		local row = addRow(recipe.Name .. "s", ("The Stocker only puts %ss here"):format(recipe.Name:lower()), choose(index), "")
		local picture = Instance.new("ViewportFrame")
		picture.Size = UDim2.fromScale(1, 1)
		picture.BackgroundTransparency = 1
		picture.ZIndex = 7
		picture.Parent = row.Icon
		showTreat(picture, index)
	end
end

-- A co-baker sees the orders of the bakery they're working in, and packs from their own tray.
function panels.Deliveries()
	panelTitle.Text = state.Work and state.Work.OwnerName .. "'s Deliveries" or "Deliveries"
	local carrying = itemList(state.Tray)
	addRow("You're carrying", carrying ~= "" and carrying or "Nothing yet", {})
	for slot, order in (state.Work or state).Orders do
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

-- Employees: a card for each place, with a picture of the employee, their job buttons, and
-- Customize and Train. An empty place offers the next hire. Picking a job the other
-- employee has swaps their jobs.
function panels.Employees()
	local settings = Config.Employees
	local action = ReplicatedStorage:WaitForChild("EmployeeAction")
	panelTitle.Text = "Employees"
	addRow("Your staff", "Each one does a different job, and you do the job left over", {})
	rowOrder += 1
	local cards = Instance.new("Frame")
	cards.Name = "Cards"
	cards.Size = UDim2.new(1, -12, 0, 290)
	cards.BackgroundTransparency = 1
	cards.LayoutOrder = rowOrder
	cards.ZIndex = 6
	cards.Parent = rowList
	for slot = 1, settings.Max do
		local card = style(
			Instance.new("Frame"),
			"Card" .. slot,
			UDim2.new(0.5, -4, 1, 0),
			UDim2.new((slot - 1) * 0.5, (slot - 1) * 8, 0, 0),
			TOP_LEFT,
			WHITE
		)
		card.ZIndex = 6
		card.Parent = cards
		local function cardButton(name, text, color, size, position, onClick)
			local object = button(name, size, position, TOP_LEFT, color, card)
			object.Text = text
			object.ZIndex = 7
			object.AutoButtonColor = onClick ~= nil
			if onClick then
				object.Activated:Connect(onClick)
			end
			return object
		end
		local employee = state.Employees[slot]
		if employee then
			local picture = Instance.new("ViewportFrame")
			picture.Name = "Picture"
			picture.Size = UDim2.new(1, -12, 0, 118)
			picture.Position = UDim2.fromOffset(6, 6)
			picture.BackgroundColor3 = CREAM
			picture.Ambient = Color3.fromRGB(200, 200, 200)
			picture.LightColor = WHITE
			picture.ZIndex = 7
			picture.Parent = card
			Instance.new("UICorner").Parent = picture
			if not wardrobe.show(picture, slot, true) then
				local waiting = label("Waiting", UDim2.fromScale(1, 1), UDim2.new(), TOP_LEFT, CREAM, BROWN, picture)
				waiting.BackgroundTransparency = 1
				waiting.Text = "On their way..."
				waiting.ZIndex = 8
			end
			local name = label("EmployeeName", UDim2.new(1, -12, 0, 28), UDim2.fromOffset(6, 128), TOP_LEFT, WHITE, BROWN, card)
			name.Text = (employee.Name ~= "" and employee.Name or "Employee " .. slot) .. (employee.Trained and " (trained)" or "")
			name.ZIndex = 7
			local info = label("Info", UDim2.new(1, -12, 0, 20), UDim2.fromOffset(6, 156), TOP_LEFT, WHITE, BROWN, card)
			info.Text = settings.JobInfo[employee.Job] or ""
			info.ZIndex = 7
			-- Another employee's job is gold, because picking it swaps jobs with them.
			local taken = {}
			for otherSlot, other in state.Employees do
				if otherSlot ~= slot then
					taken[other.Job] = true
				end
			end
			for index, job in settings.Jobs do
				local color = employee.Job == job and PINK or taken[job] and GOLD or BLUE
				cardButton(
					job .. "Job",
					job,
					color,
					UDim2.new(1 / 3, -6, 0, 40),
					UDim2.new((index - 1) / 3, 4, 0, 182),
					employee.Job ~= job and function()
						action:FireServer("SetJob", slot, job)
					end or nil
				)
			end
			cardButton("Customize", "Customize", PINK, UDim2.new(0.5, -9, 0, 44), UDim2.fromOffset(6, 232), function()
				wardrobe.open(slot)
			end)
			if employee.Trained then
				cardButton("Train", "Trained!", GREY, UDim2.new(0.5, -9, 0, 44), UDim2.new(0.5, 3, 0, 232))
			else
				local cost = settings.TrainCost
				cardButton(
					"Train",
					"Train: " .. withCommas(cost),
					state.Coins >= cost and GREEN or GREY,
					UDim2.new(0.5, -9, 0, 44),
					UDim2.new(0.5, 3, 0, 232),
					function()
						action:FireServer("Train", slot)
					end
				)
			end
		else
			local title = label("EmployeeName", UDim2.new(1, -12, 0, 30), UDim2.fromOffset(6, 40), TOP_LEFT, WHITE, BROWN, card)
			title.Text = "Employee " .. slot
			title.ZIndex = 7
			local info = label("Info", UDim2.new(1, -12, 0, 60), UDim2.fromOffset(6, 80), TOP_LEFT, WHITE, BROWN, card)
			info.TextWrapped = true
			info.ZIndex = 7
			if slot == #state.Employees + 1 then
				local cost = settings.HireCost[slot]
				info.Text = "Hire someone to run the register, bake or stock your cases"
				cardButton(
					"Hire",
					"Hire: " .. withCommas(cost) .. " coins",
					state.Coins >= cost and GREEN or GREY,
					UDim2.new(1, -12, 0, 50),
					UDim2.fromOffset(6, 160),
					function()
						action:FireServer("Hire")
					end
				)
			else
				info.Text = ("Hire your first employee, then this one for %s coins"):format(withCommas(settings.HireCost[slot]))
			end
		end
	end
	local cashier = false
	for _, employee in state.Employees do
		cashier = cashier or employee.Job == "Cashier"
	end
	if not cashier then
		addRow("No Cashier?", "Customers wait at the register until you tap E there", {})
	end
end

-- Bake Together: whose bakery you're in, who's in yours, and inviting friends.
function panels.Friends()
	panelTitle.Text = "Bake Together"
	local co = Config.CoBake
	if state.Work then
		addRow(("Baking with %s"):format(state.Work.OwnerName), "Bake, fill their cases and pack their orders", {
			{
				Text = "Stop",
				Color = PINK,
				OnClick = function()
					ReplicatedStorage.LeaveCoBake:FireServer()
				end,
			},
		})
	end
	addHeader("Baking in your bakery")
	if #state.CoBakers == 0 then
		addRow("Nobody yet", "Other bakers can ask at your door to bake with you", {})
	end
	for _, coBaker in state.CoBakers do
		addRow(coBaker.Name, "Helping in your bakery", {
			{
				Text = "Remove",
				Color = GREY,
				TextColor = BROWN,
				OnClick = function()
					ReplicatedStorage.RemoveCoBaker:FireServer(coBaker.UserId)
				end,
			},
		})
	end
	-- 0.1 becomes 10. Rounding matters, since 0.1 * 100 is a hair over 10.
	local function percent(share)
		return math.floor(share * 100 + 0.5)
	end
	addHeader("How it works")
	addRow("Ask at a bakery's door", ("The owner says yes or no. Up to %d can join one bakery"):format(co.Max), {})
	addRow(
		"Everyone earns more",
		("Owners get +%d%% per helper, helpers get %d%% of each sale"):format(percent(co.OwnerBonus), percent(co.Share)),
		{}
	)
	local boost = Config.FriendBoost
	local boostDetail = state.FriendBoost > 0 and ("You have +%d%% coins right now"):format(percent(state.FriendBoost))
		or ("+%d%% coins for each Roblox friend in town, up to +%d%%"):format(percent(boost.PerFriend), percent(boost.Max))
	addRow("Friend Boost", boostDetail, {})
	addRow("Invite friends", ("A friend's first visit gives you both %s"):format(starText(Config.Referral.Stars)), {
		{
			Text = "Invite",
			Color = GREEN,
			OnClick = function()
				local SocialService = game:GetService("SocialService")
				task.spawn(function()
					local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
					if ok and canInvite then
						local options = Instance.new("ExperienceInviteOptions")
						options.PromptMessage = "Come bake with me in Sweetopia!"
						pcall(SocialService.PromptGameInvite, SocialService, player, options)
					end
				end)
			end,
		},
	})
end

-- Prices and icons come from Roblox, so the store always shows what the player will really
-- pay, and the picture set in Creator Hub.
local productPrices = {}
local passPrices = {}
local storeIcons = { Products = {}, Passes = {} }

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
				addRow(pass.Name, pass.Detail, { action }, storeIcons.Passes[pass.GamePassId])
			end
		end
	end
	addHeader("Coins, Stars and Boosts")
	for _, product in Config.Products do
		local color = product.Currency == "Coins" and GREEN or GOLD
		local action = robuxAction(product.ProductId, productPrices[product.ProductId], color, function()
			buyProduct(product)
		end)
		addRow(product.Name, productDetail(product), { action }, storeIcons.Products[product.ProductId])
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
			local boostRow = addRow(product.Name, "", { action }, storeIcons.Products[product.ProductId])
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

refreshPanel = function()
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
	-- Opening a menu starts the Paint tab at its list, not partway through a choice, and
	-- closes the grocery store's Buy all box.
	if name ~= currentPanel then
		paintChoice = nil
		panel.Confirm.Visible = false
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
	wardrobe.refresh()
end

local function togglePanel(name)
	setPanel(currentPanel ~= name and name or nil)
end

-- The dressing room, laid out like the avatar editor on the Roblox website: on the left the
-- employee's name over a picture of them turning slowly, which can be dragged round, and
-- on the right a tab for each part of the wardrobe over a grid of pictures. Tapping a
-- picture dresses the employee in the bakery too, and the picture here follows once they've
-- changed. wardrobe.show draws an employee in any ViewportFrame, for the Employees cards.
wardrobe = (function()
	local action = ReplicatedStorage:WaitForChild("EmployeeAction")
	local api = {}
	-- The employee being dressed, the look picked here (the server catches up), and changes
	-- not yet sent, by category. Changes go one at a time, a moment apart.
	local current, look, category = nil, nil, Config.Wardrobe[1].Id
	local unsent, sending = {}, false
	local preview, watching = nil, nil
	local angle, dragging, dragX = 0, false, 0

	local function liveModel(slot)
		for _, plot in plotsFolder:GetChildren() do
			if plot:GetAttribute("OwnerId") == player.UserId then
				local helpers = plot:FindFirstChild("Helpers")
				return helpers and helpers:FindFirstChild("Employee" .. slot)
			end
		end
		return nil
	end

	-- The same text the server keeps on the model as LookKey.
	local function lookKey(chosen)
		local parts = {}
		for _, wardrobeCategory in Config.Wardrobe do
			table.insert(parts, tostring(chosen[wardrobeCategory.Id]))
		end
		return table.concat(parts, "|")
	end

	-- Draws a copy of the employee: their head and shoulders, or all of them. Returns the
	-- copy, or nil when they haven't arrived yet.
	function api.show(viewport, slot, headAndShoulders)
		for _, child in viewport:GetChildren() do
			if child:IsA("WorldModel") or child:IsA("Camera") then
				child:Destroy()
			end
		end
		local model = liveModel(slot)
		if not model then
			return nil
		end
		local copy = model:Clone()
		for _, part in copy:GetDescendants() do
			if part:IsA("BillboardGui") or part.Name == "CarriedTray" then
				part:Destroy()
			end
		end
		copy:PivotTo(CFrame.new())
		local world = Instance.new("WorldModel")
		copy.Parent = world
		world.Parent = viewport
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		if headAndShoulders then
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.6, -5), Vector3.new(0, 1.2, 0))
		else
			camera.CFrame = CFrame.lookAt(Vector3.new(0, -0.2, -10.5), Vector3.new(0, -0.6, 0))
		end
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		return copy
	end

	-- A little below the middle, so the hint along the top still shows.
	local window = style(Instance.new("Frame"), "Wardrobe", UDim2.fromScale(0.94, 0.86), UDim2.new(0.5, 0, 0.5, 12), Vector2.new(0.5, 0.5), CREAM)
	window.Visible = false
	window.ZIndex = 20
	window.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(760, 500)
	limit.Parent = window
	local title = label("Title", UDim2.new(1, -130, 0, 40), UDim2.fromOffset(10, 8), TOP_LEFT, CREAM, BROWN, window)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 21
	local done = button("Done", UDim2.fromOffset(100, 44), UDim2.new(1, -8, 0, 6), Vector2.new(1, 0), GREEN, window)
	done.Text = "Done"
	done.ZIndex = 21

	local nameBox = style(Instance.new("TextBox"), "NameBox", UDim2.new(0.4, -14, 0, 40), UDim2.fromOffset(10, 54), TOP_LEFT, WHITE)
	nameBox.Font = FONT
	nameBox.TextScaled = true
	nameBox.TextColor3 = BROWN
	nameBox.PlaceholderText = "Type a name"
	nameBox.ClearTextOnFocus = false
	nameBox.Text = ""
	nameBox.ZIndex = 21
	nameBox.Parent = window
	local view = Instance.new("ViewportFrame")
	view.Name = "Preview"
	view.Size = UDim2.new(0.4, -14, 1, -106)
	view.Position = UDim2.fromOffset(10, 100)
	view.BackgroundColor3 = WHITE
	view.Ambient = Color3.fromRGB(200, 200, 200)
	view.LightColor = WHITE
	view.ZIndex = 21
	view.Parent = window
	Instance.new("UICorner").Parent = view
	local note = label("Note", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 1, -8), Vector2.new(0, 1), CREAM, BROWN, view)
	note.BackgroundTransparency = 0.2
	note.ZIndex = 22

	local tabBox = Instance.new("Frame")
	tabBox.Name = "Tabs"
	tabBox.Size = UDim2.new(0.6, -10, 0, 40)
	tabBox.Position = UDim2.new(0.4, 4, 0, 54)
	tabBox.BackgroundTransparency = 1
	tabBox.ZIndex = 21
	tabBox.Parent = window
	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.Padding = UDim.new(0, 6)
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Parent = tabBox
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Items"
	grid.Size = UDim2.new(0.6, -10, 1, -106)
	grid.Position = UDim2.new(0.4, 4, 0, 100)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 8
	grid.ScrollBarImageColor3 = PINK
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ZIndex = 21
	grid.Parent = window
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(92, 112)
	gridLayout.CellPadding = UDim2.fromOffset(8, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local function send()
		local categoryId, id = next(unsent)
		if sending or not categoryId then
			return
		end
		unsent[categoryId] = nil
		sending = true
		action:FireServer("SetLook", current, categoryId, id)
		task.delay(0.25, function()
			sending = false
			send()
		end)
	end

	-- "Dressing..." while the employee changes, and a hint once they're wearing it.
	local function refreshNote()
		local model = current and liveModel(current)
		if not model then
			note.Text = "On their way..."
		elseif model:GetAttribute("LookKey") ~= lookKey(look) then
			note.Text = "Dressing..."
		else
			note.Text = "Drag to turn"
		end
	end

	local refreshGrid
	local function showTabs()
		for _, child in tabBox:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		for index, wardrobeCategory in Config.Wardrobe do
			local tab = button(wardrobeCategory.Id .. "Tab", UDim2.new(1 / #Config.Wardrobe, -6, 1, 0), UDim2.new(), TOP_LEFT, wardrobeCategory.Id == category and PINK or GREY, tabBox)
			tab.Text = wardrobeCategory.Name
			tab.LayoutOrder = index
			tab.ZIndex = 22
			tab.Activated:Connect(function()
				category = wardrobeCategory.Id
				showTabs()
				refreshGrid()
				grid.CanvasPosition = Vector2.zero
			end)
		end
	end

	refreshGrid = function()
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local items
		for _, wardrobeCategory in Config.Wardrobe do
			if wardrobeCategory.Id == category then
				items = wardrobeCategory.Items
			end
		end
		for index, item in items do
			local tile = style(Instance.new("ImageButton"), "Item" .. index, UDim2.new(), UDim2.new(), TOP_LEFT, WHITE)
			tile.LayoutOrder = index
			tile.ZIndex = 22
			tile.ScaleType = Enum.ScaleType.Fit
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = PINK
			stroke.Thickness = 4
			stroke.Enabled = look[category] == item.Id
			stroke.Parent = tile
			if item.Color then
				local swatch = Instance.new("Frame")
				swatch.Size = UDim2.fromScale(0.7, 0.7)
				swatch.Position = UDim2.fromScale(0.5, 0.5)
				swatch.AnchorPoint = Vector2.new(0.5, 0.5)
				swatch.SizeConstraint = Enum.SizeConstraint.RelativeXX
				swatch.BackgroundColor3 = item.Color
				swatch.ZIndex = 23
				local round = Instance.new("UICorner")
				round.CornerRadius = UDim.new(0.5, 0)
				round.Parent = swatch
				swatch.Parent = tile
			else
				if item.Id ~= 0 then
					tile.Image = ("rbxthumb://type=Asset&id=%d&w=150&h=150"):format(item.Id)
				end
				local name = label("Label", UDim2.new(1, -4, 0, 26), UDim2.new(0, 2, 1, -2), Vector2.new(0, 1), WHITE, BROWN, tile)
				name.BackgroundTransparency = 0.15
				name.TextWrapped = true
				name.Text = item.Name
				name.ZIndex = 23
				name.UIPadding:Destroy()
				-- Short names would otherwise grow to fill the label.
				local textLimit = Instance.new("UITextSizeConstraint")
				textLimit.MaxTextSize = 13
				textLimit.Parent = name
			end
			tile.Parent = grid
			tile.Activated:Connect(function()
				if look[category] == item.Id then
					return
				end
				look[category] = item.Id
				unsent[category] = item.Id
				send()
				refreshGrid()
				refreshNote()
			end)
		end
	end

	local function showPreview()
		preview = current and api.show(view, current, false)
		refreshNote()
	end

	-- Follows the employee in the bakery: their picture is taken again whenever they change.
	local function watch()
		if watching then
			watching:Disconnect()
			watching = nil
		end
		local model = current and liveModel(current)
		if model then
			watching = model:GetAttributeChangedSignal("LookKey"):Connect(showPreview)
		end
		showPreview()
	end

	local function close()
		window.Visible = false
		current = nil
		preview = nil
		if watching then
			watching:Disconnect()
			watching = nil
		end
		panel.Visible = currentPanel ~= nil
	end
	done.Activated:Connect(close)

	function api.open(slot)
		local employee = state.Employees[slot]
		if not employee then
			return
		end
		current = slot
		look = table.clone(employee.Look)
		table.clear(unsent)
		nameBox.Text = employee.Name
		title.Text = "Dress " .. (employee.Name ~= "" and employee.Name or "your employee")
		angle = 0
		window.Visible = true
		panel.Visible = false
		showTabs()
		refreshGrid()
		watch()
	end

	-- After each state update and menu change: closes with the Employees menu, and shows
	-- the name once Roblox has filtered it.
	function api.refresh()
		if not current then
			return
		end
		local employee = state.Employees[current]
		if currentPanel ~= "Employees" or not employee then
			close()
			return
		end
		if not nameBox:IsFocused() then
			nameBox.Text = employee.Name
		end
		title.Text = "Dress " .. (employee.Name ~= "" and employee.Name or "your employee")
		if not watching then
			watch()
		end
		refreshNote()
	end

	nameBox:GetPropertyChangedSignal("Text"):Connect(function()
		local length = utf8.len(nameBox.Text)
		if length and length > Config.Employees.NameLength then
			nameBox.Text = nameBox.Text:sub(1, utf8.offset(nameBox.Text, Config.Employees.NameLength + 1) - 1)
		end
	end)
	nameBox.FocusLost:Connect(function()
		local employee = current and state.Employees[current]
		if employee and nameBox.Text ~= employee.Name then
			action:FireServer("Rename", current, nameBox.Text)
		end
	end)

	view.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragX = true, input.Position.X
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			angle += (input.Position.X - dragX) * 0.012
			dragX = input.Position.X
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	RunService.RenderStepped:Connect(function(delta)
		if preview and window.Visible then
			if not dragging then
				angle += delta * 0.5
			end
			preview:PivotTo(CFrame.Angles(0, angle, 0))
		end
	end)

	return api
end)()

shopButton.Activated:Connect(function()
	togglePanel("Shop")
end)
decorButton.Activated:Connect(function()
	togglePanel("Decorate")
end)
employeesButton.Activated:Connect(function()
	togglePanel("Employees")
end)
storeButton.Activated:Connect(function()
	togglePanel("Store")
end)
boostButton.Activated:Connect(function()
	togglePanel("Boosts")
end)
friendsButton.Activated:Connect(function()
	togglePanel("Friends")
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

local function loadPrice(id, infoType, prices, icons)
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		if not ok then
			return
		end
		if info.IconImageAssetId and info.IconImageAssetId ~= 0 then
			icons[id] = "rbxassetid://" .. info.IconImageAssetId
		end
		if info.IsForSale then
			prices[id] = info.PriceInRobux
		end
		refreshPanel()
	end)
end

for _, product in Config.Products do
	if product.ProductId ~= 0 then
		loadPrice(product.ProductId, Enum.InfoType.Product, productPrices, storeIcons.Products)
	end
end
for _, pass in Config.Passes do
	if pass.GamePassId ~= 0 then
		loadPrice(pass.GamePassId, Enum.InfoType.GamePass, passPrices, storeIcons.Passes)
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

-- A bouncing "!" over the Delivery Counter when an order can be packed, and over the
-- Cookbook Counter when a goal can be claimed or a recipe unlocked, in the bakery you're
-- working in. setCounterAlerts(deliveries, cookbook) turns them on and off.
local setCounterAlerts = (function()
	local alerts = {}
	for _, stationName in { "PackingStation", "UpgradeStation" } do
		local alert = Instance.new("BillboardGui")
		alert.Name = stationName .. "Alert"
		alert.Size = UDim2.fromOffset(52, 52)
		alert.StudsOffset = Vector3.new(0, 4.5, 0)
		alert.MaxDistance = 120
		alert.Enabled = false
		local mark = label("Mark", UDim2.fromScale(1, 1), UDim2.new(), TOP_LEFT, GOLD, WHITE, alert)
		mark.Text = "!"
		mark.UICorner.CornerRadius = UDim.new(0.5, 0)
		alert.Parent = gui
		TweenService:Create(
			alert,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ StudsOffset = Vector3.new(0, 5.3, 0) }
		):Play()
		alerts[stationName] = alert
	end
	return function(deliveries, cookbook)
		local coBaking = player:GetAttribute("CoBaking")
		local plot = coBaking and plotsFolder:FindFirstChild(coBaking) or myPlot()
		for stationName, on in { PackingStation = deliveries, UpgradeStation = cookbook } do
			local station = plot and plot:FindFirstChild(stationName)
			local part = station and (station:IsA("BasePart") and station or station:FindFirstChildWhichIsA("BasePart", true))
			alerts[stationName].Adornee = part
			alerts[stationName].Enabled = on and part ~= nil
		end
	end
end)()

-- Decorating
-- Pieces snap to a grid on your floor, or on your walls for wall pieces, while the camera
-- and controls work as normal. The preview uses the same Layout rules as the server,
-- which checks every spot again.
local OK_COLOR = Color3.fromRGB(120, 220, 140)
local BLOCKED_COLOR = Color3.fromRGB(225, 95, 95)
local FRONT_COLOR = Color3.fromRGB(150, 200, 255)
local GHOST_TRANSPARENCY = 0.45
local ARROW_ANGLE = math.rad(35)
local MOVE_HINT = "Tap or click anything in your bakery to move it"
local ROTATE_HINT = "Pick something up first, then rotate it"
local WALL_ROTATE_HINT = "Wall pieces always face into the room"
local BANNER_HINT_TIME = 2
-- A new wall piece starts with its middle at about head height.
local WALL_START_HEIGHT = 6
-- BackWallRight and BackWallTop are the back wall either side of and above the door to
-- The Sweet Stash, once it's bought.
local WALL_NAMES = { "BackWall", "BackWallRight", "BackWallTop", "LeftWall", "RightWall" }
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
placeBar.Size = UDim2.fromOffset(540, 46)
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

-- The buttons along the bottom while decorating, by name, such as barButtons.Rotate. They
-- share one table to keep the script within Luau's limit of 200 local variables.
local barButtons = {}

local function barButton(name, order, color)
	local object = button(name, UDim2.fromOffset(100, 46), UDim2.new(), TOP_LEFT, color, placeBar)
	object.Text = name
	object.LayoutOrder = order
	barButtons[name] = object
end

barButton("Rotate", 1, BLUE)
barButton("Place", 2, GREEN)
barButton("Sell", 3, GOLD)
barButton("Inventory", 4, BLUE)
barButton("Cancel", 5, PINK)
-- Fill floor shows only while laying tiles, when Cancel doesn't.
barButton("Fill", 5, GOLD)
barButtons.Fill.Size = UDim2.fromOffset(200, 46)
barButton("Done", 6, PINK)

-- The hotbar shares the bottom of the screen with these buttons and sits under open menus.
refreshHotbarVisible = function()
	local show = currentPanel == nil and not decorating
	hotbar.Visible = show
	trayLabel.Visible = show
	moveSwitch.Visible = show
end

-- The floor's top, or the lawn's for a garden piece (item).
local function floorTop(plot, item)
	local floor = plot.Floor
	local top = floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)
	return item and Layout.TopFor(item, top, plot) or top
end

-- Your bakery's floor inside the walls, which grows when you expand it, or The Sweet
-- Stash's floor while a Stash Shelf is held, or the garden while a garden plant is.
local function myBounds()
	local item = held and held.itemId and Config.GetItem(held.itemId)
	return item and Layout.BoundsFor(item, state.Expansion) or Layout.Bounds(state.Expansion)
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

-- The lines sit just above any floor tiles. While laying tiles, they mark the tiles'
-- edges instead of every stud, and the doorway isn't tinted.
local function showGrid(plot)
	local item = held and held.itemId and Config.GetItem(held.itemId)
	local top = floorTop(plot, item)
	local bounds = myBounds()
	gridLevel = state.Expansion
	stash.gridRoom = item and item.Room or false
	grid = Instance.new("Folder")
	grid.Name = "DecorGrid"
	-- Customize mode has nothing to place, so no grid.
	if stash.marking then
		grid.Parent = Workspace
		return
	end
	local columns, rows = bounds.MaxX - bounds.MinX, bounds.MaxZ - bounds.MinZ
	local middleX = (bounds.MinX + bounds.MaxX) / 2
	local middleZ = (bounds.MinZ + bounds.MaxZ) / 2
	local xs, zs = {}, {}
	if tiling.style then
		for _, tile in Layout.Tiles(bounds) do
			xs[tile.Rect.MinX], xs[tile.Rect.MaxX] = true, true
			zs[tile.Rect.MinZ], zs[tile.Rect.MaxZ] = true, true
		end
	else
		for column = 0, columns do
			xs[bounds.MinX + column] = true
		end
		for row = 0, rows do
			zs[bounds.MinZ + row] = true
		end
	end
	for x in xs do
		local line = markerPart("Line", Vector3.new(0.06, 0.02, rows), WHITE, 0.55, grid)
		line.CFrame = top * CFrame.new(x, 0.05, middleZ)
	end
	for z in zs do
		local line = markerPart("Line", Vector3.new(columns, 0.02, 0.06), WHITE, 0.55, grid)
		line.CFrame = top * CFrame.new(middleX, 0.05, z)
	end
	-- The doorway, and The Sweet Stash's door and whiteboard, are tinted orange where
	-- they're drawn. The colour is written here, not in its own local, to keep the script
	-- within Luau's limit of 200 local variables.
	if not tiling.style then
		local clear = { Layout.Entrance }
		if state.Stash then
			for _, fixed in Layout.StashThings(state.Expansion) do
				table.insert(clear, fixed.Rect)
			end
		end
		-- In the garden, everything it keeps clear: the path, the crate's and flyer stand's
		-- spots, the townsfolk's way and the neighbours' gardens. The bakery, the stash and
		-- the plaza (P) are clear to see already.
		if stash.gridRoom == "Garden" then
			clear = {}
			for _, fixed in Layout.GardenThings(state.Expansion, state.Stash, plot) do
				if fixed.Key ~= "Bakery" and fixed.Key ~= "P" and fixed.Key ~= "Stash" then
					table.insert(clear, fixed.Rect)
				end
			end
		end
		for _, rect in clear do
			if Layout.Inside(rect, bounds) then
				local size = Vector3.new(rect.MaxX - rect.MinX, 0.02, rect.MaxZ - rect.MinZ)
				local doorway = markerPart("Doorway", size, Color3.fromRGB(255, 200, 120), 0.55, grid)
				doorway.CFrame = top * CFrame.new(Layout.Center(rect) + Vector3.new(0, 0.06, 0))
			end
		end
	end
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
	local item = held.itemId and Config.GetItem(held.itemId)
	local garden = item ~= nil and item.Room == "Garden"
	local top = floorTop(plot, item)
	held.ghost:PivotTo(Layout.CFrame(top, held.shape, held.entry) * held.base)
	local thing = heldThing()
	local others = allThings(plot)
	if state.Stash then
		for _, fixed in Layout.StashThings(state.Expansion) do
			table.insert(others, fixed)
		end
	end
	if garden then
		for _, fixed in Layout.GardenThings(state.Expansion, state.Stash, plot) do
			table.insert(others, fixed)
		end
	end
	local ok, reason = Layout.Check(thing, others, myBounds())
	held.ok = ok
	updateMarker(top, thing, ok)
	local color = ok and OK_COLOR or BLOCKED_COLOR
	ghostHighlight.FillColor = color
	ghostHighlight.OutlineColor = color
	local action = held.key and "Moving" or "Placing"
	local surface = held.wall and "a wall" or garden and "the lawn" or "the floor"
	placeBanner.Text = ok and ("%s %s: tap or click %s to move it"):format(action, held.name, surface) or reason
	placeBanner.BackgroundColor3 = ok and GREEN or BLOCKED_COLOR
	barButtons.Place.BackgroundColor3 = ok and GREEN or GREY
end

-- Rotate always shows while decorating so players know it's there. It's grey until
-- something is picked up, and for wall pieces, which always face into the room. Sell and
-- Inventory show for a placed piece but never a station. Sell is grey when the piece
-- can't be sold, and reads "Sure?" while it waits for the second tap.
local function refreshBar()
	placeBanner.Visible = decorating
	placeBar.Visible = decorating
	local laying = tiling.style ~= nil
	barButtons.Rotate.Visible = not laying and not stash.marking
	barButtons.Fill.Visible = laying
	barButtons.Rotate.BackgroundColor3 = (held and not held.wall) and BLUE or GREY
	barButtons.Place.Visible = held ~= nil
	local piece = held ~= nil and held.key ~= nil and held.stationId == nil
	barButtons.Sell.Visible = piece
	barButtons.Inventory.Visible = piece
	if piece then
		local selling = held.sellUntil ~= nil and os.clock() < held.sellUntil
		barButtons.Sell.Text = selling and "Sure?" or "Sell"
		barButtons.Sell.BackgroundColor3 = saleText(Config.GetItem(held.itemId), true) and GOLD or GREY
		if selling then
			placeBanner.Text = held.sellQuestion
			placeBanner.BackgroundColor3 = GOLD
		end
	end
	barButtons.Cancel.Visible = held ~= nil
	barButtons.Done.Visible = held == nil
	if decorating and not held and not laying then
		placeBanner.Text = stash.marking and stash.HINT or MOVE_HINT
		placeBanner.BackgroundColor3 = GREEN
	end
	if laying then
		tiling.refresh()
	end
end

local function hold(info)
	held = info
	stash.regrid()
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
		-- A Stash Shelf starts in The Sweet Stash, nearest the spot in front of you, and a
		-- garden plant in the garden. If that spot's taken, the plant starts at the first
		-- free one in the front yard, from the left.
		local bounds = Layout.BoundsFor(item, state.Expansion)
		entry = Layout.EntryAt(shape, pointInFront(plot), 0, bounds)
		if item.Room == "Garden" then
			local others = allThings(plot)
			for _, fixed in Layout.GardenThings(state.Expansion, state.Stash, plot) do
				table.insert(others, fixed)
			end
			local function fits(spot)
				return (Layout.Check(Layout.ItemThing("new", { Id = itemId, X = spot.X, Z = spot.Z, R = 0 }), others, bounds))
			end
			local found = fits(entry) and entry
			for z = Layout.Garden.FrontWall - Layout.MinZ, bounds.MaxZ - Layout.MinZ - 1 do
				for x = bounds.MinX - Layout.MinX, bounds.MaxX - Layout.MinX - 1 do
					found = found or (fits({ X = x, Z = z }) and { X = x, Z = z, R = 0 })
				end
			end
			entry = found or entry
		end
	end
	-- A new piece shows the colour it will be: the newest one bought or put away for it.
	if not key then
		local spare = state.SparePaint[itemId]
		paint = spare and Config.GetPaint(spare[#spare])
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
	stash.regrid()
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
		tiling.style = nil
		tiling.fillUntil = 0
		tiling.hover.Parent = nil
		stash.stopMarking()
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
	if tiling.style or stash.marking then
		setDecorating(false)
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
	local room = plot:FindFirstChild("StashRoom")
	if room then
		table.insert(surfaces, room.Floor)
	end
	if held and held.wall then
		surfaces = {}
		for _, name in WALL_NAMES do
			table.insert(surfaces, plot.Walls:FindFirstChild(name))
		end
	end
	-- A garden plant follows the lawn, under the bakery too, so it never lands on the floor.
	local item = held and held.itemId and Config.GetItem(held.itemId)
	if item and item.Room == "Garden" then
		surfaces = { plot:FindFirstChild("GardenGround") }
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = surfaces
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	return result and floorTop(plot):PointToObjectSpace(result.Position)
end

-- Laying floor tiles. tiling.style is the floor style being laid, or nil. A tap or click
-- lays the tile under it, and dragging with a mouse lays each tile it crosses. sent holds
-- the tiles sent during a drag, so each is sent once, and fillUntil is when Fill floor
-- stops waiting for its second tap.
tiling.style = nil
tiling.dragging = false
tiling.sent = {}
tiling.fillUntil = 0
-- A see-through tile in the style, under the mouse, showing how it will look.
tiling.hover = markerPart("TileHover", Vector3.one, WHITE, 0.35, nil)

function tiling.start(style)
	setPanel(nil)
	if not myPlot() then
		return
	end
	setDecorating(false)
	tiling.style = style
	setDecorating(true)
end

-- How many tiles Fill floor would change, and what it would cost.
function tiling.fillCost()
	local style = tiling.style
	local count = 0
	for _, tile in Layout.Tiles(myBounds()) do
		if (state.Floor[tile.Key] or "Original") ~= style.Id then
			count += 1
		end
	end
	return count, count * style.Coins
end

-- The banner and the Fill floor button, which reads "Sure?" while it waits.
function tiling.refresh()
	local style = tiling.style
	local count, cost = tiling.fillCost()
	local asking = os.clock() < tiling.fillUntil
	local free = style.Coins == 0
	barButtons.Fill.Text = asking and "Sure?" or (free and "Clear floor" or ("Fill floor: %s coins"):format(withCommas(cost)))
	barButtons.Fill.BackgroundColor3 = count > 0 and GOLD or GREY
	if asking then
		placeBanner.Text = free and ("Take up all %d tiles? Tap Sure? to do it"):format(count)
			or ("Lay %s on %d tiles for %s coins? Tap Sure? to do it"):format(style.Name, count, withCommas(cost))
		placeBanner.BackgroundColor3 = GOLD
	elseif os.clock() >= bannerHintUntil then
		placeBanner.Text = free and "Tap or drag across tiles to take them up"
			or ("Laying %s, %s a tile. Tap or drag across your floor"):format(style.Name, Config.CoinText(style.Coins))
		placeBanner.BackgroundColor3 = GREEN
	end
end

function tiling.tileAt(plot, ray)
	local point = surfacePointAt(plot, ray)
	return point and Layout.TileAt(point, myBounds())
end

-- Lays the style on the tile a ray points at, unless it's that style already.
function tiling.layAt(plot, ray)
	local style = tiling.style
	local tile = tiling.tileAt(plot, ray)
	if not tile or tiling.sent[tile.Key] or (state.Floor[tile.Key] or "Original") == style.Id then
		return
	end
	if state.Coins < style.Coins then
		placeBanner.Text = ("You need %d more coins for a tile"):format(style.Coins - state.Coins)
		placeBanner.BackgroundColor3 = BLOCKED_COLOR
		bannerHintUntil = os.clock() + BANNER_HINT_TIME
		return
	end
	if tiling.dragging then
		tiling.sent[tile.Key] = true
	end
	purchaseEvent:FireServer("Floor", style.Id, { tile.Key })
end

function tiling.showHover(plot, ray)
	local tile = tiling.tileAt(plot, ray)
	local hover = tiling.hover
	if not tile then
		hover.Parent = nil
		return
	end
	local rect = tile.Rect
	hover.Size = Vector3.new(rect.MaxX - rect.MinX, 0.04, rect.MaxZ - rect.MinZ)
	hover.CFrame = floorTop(plot) * CFrame.new(Layout.Center(rect) + Vector3.new(0, 0.06, 0))
	hover.Color = Config.TileColor(tiling.style, tile.I, tile.J)
	hover.Material = tiling.style.Material
	hover.Parent = Workspace
end

-- The nearest piece the pointer passes through. Each piece is a box made of its grid
-- cells and its height, so clicking the front of a tall piece by a wall still finds it,
-- and a wall piece is found up on its wall.
local function pieceOnRay(plot, ray)
	local top = floorTop(plot)
	local origin = top:PointToObjectSpace(ray.Origin)
	local direction = top:VectorToObjectSpace(ray.Direction)
	local nearest, nearestDistance = nil, math.huge
	-- Garden plants stand on the lawn, below the floor.
	local drop = plot:GetAttribute("LawnDrop") or 0
	for _, thing in allThings(plot) do
		local rect = thing.Rect
		local bottom = thing.Bottom - (thing.Room == "Garden" and drop or 0)
		local low = Vector3.new(rect.MinX, bottom, rect.MinZ)
		local high = Vector3.new(rect.MaxX, bottom + thing.Height, rect.MaxZ)
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

barButtons.Rotate.Activated:Connect(rotateHeld)
barButtons.Place.Activated:Connect(tryPlace)
barButtons.Cancel.Activated:Connect(function()
	drop(false)
end)
-- The first tap asks, and a second tap within a few seconds sells. A piece that can't be
-- sold says why instead.
barButtons.Sell.Activated:Connect(function()
	if not held or not held.key or held.stationId then
		return
	end
	local item = Config.GetItem(held.itemId)
	local price, reason = saleText(item, true)
	if not price then
		placeBanner.Text = reason
		placeBanner.BackgroundColor3 = BLOCKED_COLOR
	elseif held.sellUntil and os.clock() < held.sellUntil then
		placeEvent:FireServer("Sell", held.key)
		drop(true)
	else
		local asking = held
		held.sellUntil = os.clock() + Config.SellConfirmSeconds
		held.sellQuestion = ("Sell your %s for %s? Tap Sure? to sell it"):format(item.Name, price)
		refreshBar()
		task.delay(Config.SellConfirmSeconds, function()
			if held == asking then
				refreshHeld()
				refreshBar()
			end
		end)
	end
end)
barButtons.Inventory.Activated:Connect(function()
	if held and held.key then
		placeEvent:FireServer("Store", held.key)
		drop(true)
	end
end)
-- The first tap shows the total, and a second tap within a few seconds lays every tile.
barButtons.Fill.Activated:Connect(function()
	local style = tiling.style
	if not style then
		return
	end
	if tiling.fillCost() == 0 then
		placeBanner.Text = style.Coins == 0 and "There are no tiles to take up"
			or ("Your whole floor is %s already"):format(style.Name)
		bannerHintUntil = os.clock() + BANNER_HINT_TIME
		return
	end
	if os.clock() < tiling.fillUntil then
		tiling.fillUntil = 0
		purchaseEvent:FireServer("FloorFill", style.Id)
	else
		local asking = os.clock() + Config.FloorFill.ConfirmSeconds
		tiling.fillUntil = asking
		task.delay(Config.FloorFill.ConfirmSeconds, function()
			if tiling.fillUntil == asking then
				refreshBar()
			end
		end)
	end
	refreshBar()
end)
barButtons.Done.Activated:Connect(function()
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

-- Customize mode for The Sweet Stash runs inside decorate mode, like laying tiles.
-- stash.marking is true while it's on, and tapping a display case opens
-- panels.CaseTreat for it, with its key in stash.caseKey. While it's on, cases kept for
-- one treat show a tag with that treat, in the stash.tags folder. gridRoom is true while
-- the grid is drawn in the stash, for a held Stash Shelf.
stash.HINT = "Tap a display case to choose its treat"
stash.marking = false
stash.caseKey = nil
stash.tags = nil
stash.gridRoom = false

function stash.startMarking()
	setPanel(nil)
	if not myPlot() then
		return
	end
	setDecorating(false)
	stash.marking = true
	setDecorating(true)
	stash.refreshTags()
end

function stash.stopMarking()
	stash.marking = false
	stash.caseKey = nil
	if stash.tags then
		stash.tags:Destroy()
		stash.tags = nil
	end
end

-- The key of a display case in the store, or nil for anything else, like a Stash Shelf.
function stash.caseOf(thing)
	local entry = thing and state.Placed[thing.Key]
	local item = entry and Config.GetItem(entry.Id)
	return item and item.Slots and not item.Room and thing.Key or nil
end

function stash.pick(plot, ray)
	local key = stash.caseOf(pieceOnRay(plot, ray))
	if key then
		stash.caseKey = key
		setPanel("CaseTreat")
	end
end

-- Draws the grid again when the held piece goes between the bakery, the stash and the
-- garden. gridRoom is the Room the grid is drawn in, or false for the bakery.
function stash.regrid()
	local plot = myPlot()
	local item = held and held.itemId and Config.GetItem(held.itemId)
	local room = item and item.Room or false
	if grid and plot and room ~= stash.gridRoom then
		grid:Destroy()
		showGrid(plot)
	end
end

-- A tag over each display case kept for one treat, showing the treat and its name.
function stash.refreshTags()
	if stash.tags then
		stash.tags:Destroy()
		stash.tags = nil
	end
	local plot = myPlot()
	if not stash.marking or not plot then
		return
	end
	stash.tags = Instance.new("Folder")
	stash.tags.Name = "TreatTags"
	for key, entry in state.Placed do
		local model = entry.Treat and plot.Placed:FindFirstChild("Placed_" .. key)
		if model and model.PrimaryPart then
			local box, size = model:GetBoundingBox()
			local tag = Instance.new("BillboardGui")
			tag.Adornee = model.PrimaryPart
			tag.Size = UDim2.fromOffset(110, 100)
			tag.StudsOffsetWorldSpace = Vector3.new(0, box.Y + size.Y / 2 - model.PrimaryPart.Position.Y + 2, 0)
			tag.AlwaysOnTop = true
			tag.Parent = stash.tags
			local card = Instance.new("Frame")
			card.Size = UDim2.fromScale(1, 1)
			card.BackgroundColor3 = WHITE
			card.Parent = tag
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 12)
			corner.Parent = card
			local picture = Instance.new("ViewportFrame")
			picture.Size = UDim2.fromScale(1, 0.7)
			picture.BackgroundTransparency = 1
			picture.Parent = card
			showTreat(picture, entry.Treat)
			local name = Instance.new("TextLabel")
			name.Position = UDim2.fromScale(0.05, 0.68)
			name.Size = UDim2.fromScale(0.9, 0.28)
			name.BackgroundTransparency = 1
			name.Font = FONT
			name.TextScaled = true
			name.TextColor3 = BROWN
			name.Text = Config.Recipes[entry.Treat].Name .. "s"
			name.Parent = card
		end
	end
	stash.tags.Parent = Workspace
end

-- With a mouse and nothing held, the piece under the pointer is outlined.
RunService.RenderStepped:Connect(function()
	local plot = myPlot()
	if not decorating or held or not plot or not UserInputService.MouseEnabled then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	if pointerOverGui(mouse - GuiService:GetGuiInset()) then
		tiling.hover.Parent = nil
		return
	end
	if tiling.style then
		tiling.showHover(plot, Workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y))
		return
	end
	local thing = pieceOnRay(plot, Workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y))
	-- In Customize mode, only display cases light up.
	if stash.marking then
		hoverHighlight.Adornee = stash.caseOf(thing) and pieceInstance(plot, thing.Key)
		return
	end
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
		if tiling.style then
			tiling.dragging = true
			tiling.sent = {}
			tiling.layAt(plot, Workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y))
		elseif stash.marking then
			stash.pick(plot, Workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y))
		elseif held then
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
	local moved = input.UserInputType == Enum.UserInputType.MouseMovement
	if tiling.dragging and tiling.style and plot and moved and not pointerOverGui(input.Position) then
		tiling.layAt(plot, Workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y))
	end
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
		tiling.dragging = false
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
	if tiling.style then
		tiling.layAt(plot, ray)
	elseif stash.marking then
		stash.pick(plot, ray)
	elseif held then
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
	-- A case's treat may have changed.
	stash.refreshTags()
end

-- The popup that opens when you tap your own bakery's sign: its name, its outside colours
-- and its garden. It's a separate module because this script is at Luau's limit of 200
-- local variables, so it's given what it needs here rather than as new locals.
panels.Exterior = require(script.Parent:WaitForChild("ExteriorPanel"))({
	player = player,
	gui = gui,
	panel = panel,
	panelTitle = panelTitle,
	colours = { PINK = PINK, BROWN = BROWN, CREAM = CREAM, GREEN = GREEN, GREY = GREY, GOLD = GOLD, BLUE = BLUE, WHITE = WHITE },
	font = FONT,
	label = label,
	button = button,
	addRow = addRow,
	showTabs = showTabs,
	textOn = textOn,
	withCommas = withCommas,
	starText = starText,
	placedCount = placedCount,
	isMine = isMine,
	myPlot = myPlot,
	setPanel = function(name)
		setPanel(name)
	end,
	refreshPanel = function()
		refreshPanel()
	end,
	startPlacing = function(itemId)
		startPlacing(itemId)
	end,
	getState = function()
		return state
	end,
	currentPanel = function()
		return currentPanel
	end,
	isDecorating = function()
		return decorating
	end,
	purchaseEvent = purchaseEvent,
})

local SLOT_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }

UserInputService.InputBegan:Connect(function(input, processed)
	local slot = table.find(SLOT_KEYS, input.KeyCode)
	if not processed and slot and hotbar.Visible then
		selectSlotEvent:FireServer(slot)
	end
end)

-- State updates
-- The Bakery Level badge, in its own module for the same reason as ExteriorPanel.
do
	local updateLevelBadge = require(script.Parent:WaitForChild("LevelBadge"))({
		gui = gui,
		colours = { BROWN = BROWN, GOLD = GOLD, WHITE = WHITE },
		font = FONT,
	})
	stateEvent.OnClientEvent:Connect(updateLevelBadge)
end

stateEvent.OnClientEvent:Connect(function(newState)
	state = newState
	showRunning(state.Running)
	-- The Friend Boost makes multipliers like 2.2, so show one decimal place when there is one.
	local multiplierText = state.Multiplier > 1 and (" x%g"):format(math.floor(state.Multiplier * 10 + 0.5) / 10) or ""
	coinsLabel.Text = ("%d coins%s"):format(state.Coins, multiplierText)
	starsLabel.Text = starText(state.Stars)
	shopButton.BackgroundColor3 = state.CanAfford and GREEN or PINK
	shopButton.Text = state.CanAfford and "Shop!" or "Shop"
	local ready = false
	for _, order in (state.Work or state).Orders do
		if canShip(order) then
			ready = true
		end
	end
	friendsButton.BackgroundColor3 = (state.Work or #state.CoBakers > 0) and GREEN or PINK
	local cookbookReady = state.CanUnlockRecipe
	for _, goal in state.Goals do
		if not goal.Claimed and goal.Progress >= goal.Target then
			cookbookReady = true
		end
	end
	setCounterAlerts(ready, cookbookReady)
	local hiring = state.CanHire or state.CanTrain
	employeesButton.BackgroundColor3 = hiring and GREEN or BLUE
	employeesButton.Text = hiring and "Employees!" or "Employees"
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
	wardrobe.refresh()
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
		"1. Bake treats at the oven\n2. Put them in a display case\n3. Customers line up at the register: tap E there to check them out\n4. Pack deliveries for big rewards and Sugar Stars\nBuy cases and decorations to grow your bakery!",
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
	elseif kind == "LevelUp" then
		-- "A", "A and B", or "A, B and C".
		local learned = table.clone(info.Learned)
		local last = table.remove(learned)
		local names = #learned > 0 and table.concat(learned, ", ") .. " and " .. last or last
		local body = ("Your bakery reached level %d!\n\nYou learned to bake %s. Find %s at the oven."):format(
			info.Level,
			names,
			#learned > 0 and "them" or "it"
		)
		if info.Max then
			body ..= "\n\nThat's the top level. Amazing baking!"
		end
		queuePopup("Level up!", body, "Yay!")
	elseif kind == "NewRestaurant" then
		local body = ("Welcome to Restaurant %d! It starts fresh, with its own coins, and gets %d%% more customers.\n\nRestaurant %d keeps running by itself on a free plot. Walk up to its door to manage it again."):format(
			info.Number,
			math.floor(Config.Restaurants.CustomerBonus * 100 + 0.5),
			info.Old
		)
		queuePopup("A new restaurant!", body, "Let's bake!")
	end
end)

-- Bake Together requests: a small card under the toast, so the game stays playable, with
-- Yes and No thanks. It closes itself when the time to answer runs out.
do
	local requestEvent = ReplicatedStorage:WaitForChild("CoBakeRequest")
	local answerEvent = ReplicatedStorage:WaitForChild("AnswerCoBake")
	local card = style(Instance.new("Frame"), "CoBakeRequest", UDim2.fromOffset(340, 116), UDim2.new(0.5, 0, 0, 80), TOP_CENTER, CREAM)
	card.Visible = false
	card.ZIndex = 9
	card.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = PINK
	stroke.Thickness = 3
	stroke.Parent = card
	local text = label("Text", UDim2.new(1, -16, 0, 44), UDim2.fromOffset(8, 6), TOP_LEFT, CREAM, BROWN, card)
	text.ZIndex = 10
	local yes = button("Yes", UDim2.new(0.5, -12, 0, 48), UDim2.new(0, 8, 1, -8), Vector2.new(0, 1), GREEN, card)
	yes.Text = "Yes!"
	yes.ZIndex = 10
	local no = button("No", UDim2.new(0.5, -12, 0, 48), UDim2.new(1, -8, 1, -8), Vector2.new(1, 1), GREY, card)
	no.TextColor3 = BROWN
	no.ZIndex = 10
	local current = nil

	local function answer(said)
		if current then
			answerEvent:FireServer(current, said)
			current = nil
		end
		card.Visible = false
	end
	yes.Activated:Connect(function()
		answer(true)
	end)
	no.Activated:Connect(function()
		answer(false)
	end)

	requestEvent.OnClientEvent:Connect(function(info)
		local id = info.Id
		current = id
		text.Text = info.Text or ("%s wants to bake with you!"):format(info.Name)
		card.Visible = true
		if sounds.Ding then
			sounds.Ding:Play()
		end
		task.spawn(function()
			for left = info.Seconds, 1, -1 do
				if current ~= id then
					return
				end
				no.Text = ("No thanks (%d)"):format(left)
				task.wait(1)
			end
			if current == id then
				current = nil
				card.Visible = false
			end
		end)
	end)
end

-- Prompts. Owners see all of their bakery's prompts, and co-bakers the ones marked CoBake
-- in the bakery they're working in. The door's "Ask to Bake Together" prompt shows on
-- other players' bakeries only.
local function refreshPrompt(prompt)
	local plot = plotOf(prompt)
	local active = prompt:GetAttribute("Active") == true
	local coBaking = plot ~= nil and player:GetAttribute("CoBaking") == plot.Name
	if prompt:GetAttribute("ManageFor") then
		-- "Manage this bakery" on one of your own restaurants that runs just for show.
		prompt.Enabled = active and prompt:GetAttribute("ManageFor") == player.UserId
	elseif prompt:GetAttribute("Door") then
		prompt.Enabled = active and plot ~= nil and plot:GetAttribute("OwnerId") ~= nil and not isMine(plot) and not coBaking
	else
		prompt.Enabled = active and (isMine(plot) or (coBaking and prompt:GetAttribute("CoBake") == true))
	end
end

local function watchPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt:GetAttributeChangedSignal("Active"):Connect(function()
		refreshPrompt(prompt)
	end)
	prompt:GetAttributeChangedSignal("CoBake"):Connect(function()
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

-- A co-baker is guided around the bakery they're working in.
local function refreshGuide()
	local coBaking = player:GetAttribute("CoBaking")
	local plot = coBaking and plotsFolder:FindFirstChild(coBaking) or myPlot()
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
player:GetAttributeChangedSignal("CoBaking"):Connect(function()
	for _, instance in plotsFolder:GetDescendants() do
		if instance:IsA("ProximityPrompt") then
			refreshPrompt(instance)
		end
	end
	refreshGuide()
end)
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
-- Townsfolk and helpers are Roblox avatars moved by the server. Each one plays Roblox's
-- default walk while its Walking attribute is on, timed to its Speed attribute, the default
-- sit while its Sitting attribute is on, and the default idle otherwise, and blinks now
-- and then. This sits in a block, and its numbers are written in place, because the script
-- is close to Luau's limit of 200 locals.
do
	local function watchCustomer(model)
		local humanoid = model:WaitForChild("Humanoid", 5)
		local animator = humanoid and humanoid:WaitForChild("Animator", 5)
		if not animator then
			return
		end
		local function load(id)
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local track = animator:LoadAnimation(animation)
			track.Looped = true
			return track
		end
		local walk = load("rbxassetid://913402848")
		local idle = load("rbxassetid://507766388")
		local sit = load("rbxassetid://2506281703")
		idle:Play(0)
		load("rbxassetid://14366558676"):Play()
		local function update()
			-- Roblox's Animate script plays the walk at normal speed for 6.4 studs a second.
			local speed = (model:GetAttribute("Speed") or Config.CustomerSpeed) / 6.4
			if model:GetAttribute("Sitting") then
				walk:Stop(0.2)
				idle:Stop(0.2)
				sit:Play(0.3)
			elseif model:GetAttribute("Walking") then
				if walk.IsPlaying then
					walk:AdjustSpeed(speed)
				else
					walk:Play(0.2, 1, speed)
					idle:Stop(0.2)
					sit:Stop(0.2)
				end
			else
				-- Pathfinding walks a person from step to step, so a short stop doesn't end
				-- the walk.
				task.delay(0.15, function()
					local busy = model:GetAttribute("Walking") or model:GetAttribute("Sitting")
					if not busy and (walk.IsPlaying or sit.IsPlaying) then
						walk:Stop(0.25)
						sit:Stop(0.25)
						idle:Play(0.25)
					end
				end)
			end
		end
		model:GetAttributeChangedSignal("Walking"):Connect(update)
		model:GetAttributeChangedSignal("Sitting"):Connect(update)
		update()
	end

	-- Helpers walk around the bakery too, so they're animated the same way.
	for _, tag in { "Customer", "Helper" } do
		for _, model in CollectionService:GetTagged(tag) do
			task.spawn(watchCustomer, model)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(watchCustomer)
	end
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
	local root = model:WaitForChild("HumanoidRootPart", 5)
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
