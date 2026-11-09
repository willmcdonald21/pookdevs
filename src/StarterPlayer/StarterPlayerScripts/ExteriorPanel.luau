-- The popup that opens when you tap your own bakery's sign. Its title is the bakery's
-- name, which you can tap to rename it. The Colours tab paints the outside walls and the
-- trim, and the Garden tab buys the garden and the plants for it.
-- BakeryClient requires this and calls the function it returns with the helpers and
-- state it shares (ctx). That gives back the panel's function, panels.Exterior.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

-- How far away the sign can be tapped from, in studs.
local SIGN_REACH = 150
local TABS = { "Colours", "Garden" }

return function(ctx)
	local colours = ctx.colours
	local nameEvent = ReplicatedStorage:WaitForChild("BakeryName")
	local tab = "Colours"
	-- The Config.Exterior part whose colours are listed, or nil for the list of parts.
	local choosing = nil
	-- Buying the garden needs a second tap before this os.clock().
	local gardenAskUntil = 0

	-- The name box sits over the panel's title while this panel is open. It isn't one of
	-- the rows, so a refresh while you type doesn't take it away.
	local nameBox = Instance.new("TextBox")
	nameBox.Name = "BakeryNameBox"
	nameBox.Size = UDim2.new(1, -120, 0, 40)
	nameBox.Position = UDim2.fromOffset(10, 8)
	nameBox.BackgroundColor3 = colours.WHITE
	nameBox.BorderSizePixel = 0
	nameBox.TextColor3 = colours.BROWN
	nameBox.PlaceholderText = "Name your bakery"
	nameBox.PlaceholderColor3 = colours.GREY
	nameBox.Font = ctx.font
	nameBox.TextScaled = true
	nameBox.TextXAlignment = Enum.TextXAlignment.Left
	nameBox.ClearTextOnFocus = false
	nameBox.Visible = false
	nameBox.ZIndex = 7
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = nameBox
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = nameBox
	nameBox.Parent = ctx.panel
	-- A pencil after the name shows it can be changed.
	local pencil = ctx.label("Pencil", UDim2.fromOffset(40, 40), UDim2.new(1, -106, 0, 8), Vector2.new(0, 0), colours.CREAM, colours.BROWN, ctx.panel)
	pencil.Text = "✏️"
	pencil.Visible = false
	pencil.ZIndex = 7

	local function showName()
		local state = ctx.getState()
		if state and not nameBox:IsFocused() then
			nameBox.Text = state.SignName
		end
	end

	-- Every other panel sets its own title, so the box goes when another panel opens.
	ctx.panelTitle:GetPropertyChangedSignal("Text"):Connect(function()
		local open = ctx.currentPanel() == "Exterior"
		nameBox.Visible = open
		pencil.Visible = open
	end)
	ctx.panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not ctx.panel.Visible then
			nameBox:ReleaseFocus()
		end
	end)
	nameBox.Focused:Connect(function()
		-- You edit the name as you typed it, not as the filter shows it to everyone.
		local state = ctx.getState()
		nameBox.Text = state and (state.BakeryName or state.SignName) or ""
	end)
	nameBox:GetPropertyChangedSignal("Text"):Connect(function()
		local text = nameBox.Text
		local length = Config.Exterior.NameLength
		if utf8.len(text) and utf8.len(text) > length then
			nameBox.Text = text:sub(1, utf8.offset(text, length + 1) - 1)
		end
	end)
	nameBox.FocusLost:Connect(function()
		local state = ctx.getState()
		if state and nameBox.Text ~= (state.BakeryName or state.SignName) then
			nameEvent:FireServer(nameBox.Text)
		end
		showName()
	end)

	-- A message over the menu with only an OK button, for when you can't afford something.
	local notice = Instance.new("Frame")
	notice.Name = "ExteriorNotice"
	notice.Size = UDim2.new(0.8, 0, 0, 150)
	notice.Position = UDim2.fromScale(0.5, 0.5)
	notice.AnchorPoint = Vector2.new(0.5, 0.5)
	notice.BackgroundColor3 = colours.CREAM
	notice.BorderSizePixel = 0
	notice.Visible = false
	notice.ZIndex = 20
	local noticeCorner = Instance.new("UICorner")
	noticeCorner.CornerRadius = UDim.new(0, 12)
	noticeCorner.Parent = notice
	local noticeStroke = Instance.new("UIStroke")
	noticeStroke.Color = colours.PINK
	noticeStroke.Thickness = 3
	noticeStroke.Parent = notice
	local noticeText = ctx.label("Text", UDim2.new(1, -20, 0, 70), UDim2.fromOffset(10, 10), Vector2.new(0, 0), colours.CREAM, colours.BROWN, notice)
	noticeText.ZIndex = 21
	local ok = ctx.button("Ok", UDim2.fromOffset(120, 46), UDim2.new(0.5, 0, 1, -10), Vector2.new(0.5, 1), colours.GREEN, notice)
	ok.Text = "OK"
	ok.ZIndex = 21
	ok.Activated:Connect(function()
		notice.Visible = false
	end)
	notice.Parent = ctx.panel
	ctx.panelTitle:GetPropertyChangedSignal("Text"):Connect(function()
		notice.Visible = false
	end)

	local function showNotice(text)
		noticeText.Text = text
		notice.Visible = true
	end

	local function paintName(id)
		local paint = Config.GetPaint(id)
		return paint and paint.Name or "Its original colour"
	end

	local function colourRows(state)
		local part = choosing
		local current = state.Exterior[part.Id]
		ctx.addRow("Painting: " .. part.Name, part.Detail, {
			{
				Text = "Back",
				Color = colours.BLUE,
				OnClick = function()
					choosing = nil
					ctx.refreshPanel()
				end,
			},
		})
		local original = { Text = current and "Free" or "Now", Color = colours.WHITE, TextColor = colours.BROWN }
		if current then
			original.OnClick = function()
				ctx.purchaseEvent:FireServer("Exterior", part.Id, "Original")
			end
		end
		ctx.addRow("Original", current and "The colour your bakery was built in" or "Its colour now", { original })
		for _, paint in Config.Paints do
			local isNow = paint.Id == current
			local action = {
				Text = isNow and "Now" or (part.Coins .. " coins"),
				Color = paint.Color,
				TextColor = ctx.textOn(paint.Color),
			}
			if not isNow then
				action.OnClick = function()
					ctx.purchaseEvent:FireServer("Exterior", part.Id, paint.Id)
				end
			end
			ctx.addRow(paint.Name, isNow and "Its colour now" or ("Paint it %s"):format(paint.Name), { action })
		end
	end

	local function colourTab(state)
		if choosing then
			colourRows(state)
			return
		end
		for _, part in Config.Exterior.Parts do
			local now = paintName(state.Exterior[part.Id])
			ctx.addRow(part.Name, ("%s. %s now, %d coins to repaint"):format(part.Detail, now, part.Coins), {
				{
					Text = "Paint",
					Color = colours.BLUE,
					OnClick = function()
						choosing = part
						ctx.refreshPanel()
					end,
				},
			})
		end
	end

	local function buyGarden(state)
		local cost = Config.Garden.Coins
		if state.Coins < cost then
			showNotice(("A garden costs %s coins. You need %s more coins"):format(ctx.withCommas(cost), ctx.withCommas(cost - state.Coins)))
			return
		end
		if os.clock() < gardenAskUntil then
			gardenAskUntil = 0
			ctx.purchaseEvent:FireServer("Garden")
			return
		end
		local asking = os.clock() + Config.SellConfirmSeconds
		gardenAskUntil = asking
		ctx.refreshPanel()
		task.delay(Config.SellConfirmSeconds, function()
			if gardenAskUntil == asking and ctx.currentPanel() == "Exterior" then
				ctx.refreshPanel()
			end
		end)
	end

	local function gardenTab(state)
		local garden = Config.Garden
		if not state.Garden then
			local asking = os.clock() < gardenAskUntil
			local detail = asking and ("Buy the garden for %s coins? Tap Sure? to buy it"):format(ctx.withCommas(garden.Coins))
				or garden.Detail
			ctx.addRow(garden.Name, detail, {
				{
					Text = asking and "Sure?" or (ctx.withCommas(garden.Coins) .. " coins"),
					Color = state.Coins >= garden.Coins and colours.GOLD or colours.GREY,
					OnClick = function()
						buyGarden(state)
					end,
				},
			})
			return
		end
		ctx.addRow("Your garden", "Buy plants here and place them on the lawn around your bakery", {
			{
				Text = "Move",
				Color = colours.BLUE,
				OnClick = function()
					ctx.startPlacing(nil)
				end,
			},
		})
		for _, item in Config.Items do
			if item.Room == "Garden" and Config.IsAllowed(item, ctx.player.UserId) then
				local stored = state.Owned[item.Id] - ctx.placedCount(item.Id)
				local priceText, canPay
				if item.Stars then
					priceText = ctx.starText(item.Stars)
					canPay = state.Stars >= item.Stars
				else
					priceText = ctx.withCommas(item.Coins) .. " coins"
					canPay = state.Coins >= item.Coins
				end
				local actions = {
					{
						Text = priceText,
						Color = canPay and (item.Stars and colours.GOLD or colours.GREEN) or colours.GREY,
						OnClick = function()
							ctx.purchaseEvent:FireServer("Item", item.Id)
						end,
					},
				}
				if stored > 0 then
					table.insert(actions, {
						Text = "Place",
						Color = colours.BLUE,
						OnClick = function()
							ctx.startPlacing(item.Id)
						end,
					})
				end
				local deluxe = item.Stars and "Deluxe! " or ""
				ctx.addRow(item.Name, ("%sCharm +%d. You have %d to place"):format(deluxe, item.Charm, stored), actions)
			end
		end
	end

	-- Tapping or clicking your own sign opens the popup, unless you're decorating or the
	-- tap was on a button or menu.
	local signParams = RaycastParams.new()
	signParams.FilterType = Enum.RaycastFilterType.Include

	local function tapAt(position)
		local plot = ctx.myPlot()
		local sign = plot and plot:FindFirstChild("Sign")
		if not sign or ctx.isDecorating() or not ctx.getState() then
			return
		end
		local ray = Workspace.CurrentCamera:ScreenPointToRay(position.X, position.Y)
		signParams.FilterDescendantsInstances = { sign }
		if Workspace:Raycast(ray.Origin, ray.Direction * SIGN_REACH, signParams) then
			choosing = nil
			ctx.setPanel("Exterior")
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			tapAt(input.Position)
		end
	end)
	UserInputService.TouchTap:Connect(function(positions, processed)
		if not processed then
			tapAt(positions[1])
		end
	end)

	-- A tag over your own sign, so you know it can be tapped.
	local tag = Instance.new("BillboardGui")
	tag.Name = "SignTag"
	tag.Size = UDim2.fromOffset(170, 30)
	tag.ExtentsOffsetWorldSpace = Vector3.new(0, 1.2, 0)
	tag.MaxDistance = SIGN_REACH
	tag.Enabled = false
	local tagText = ctx.label("Text", UDim2.fromScale(1, 1), UDim2.new(), Vector2.new(0, 0), colours.CREAM, colours.BROWN, tag)
	tagText.Text = "✏️ Tap to customize"
	tag.Parent = ctx.gui

	local function refreshTag()
		local plot = ctx.myPlot()
		local sign = plot and plot:FindFirstChild("Sign")
		tag.Adornee = sign
		tag.Enabled = sign ~= nil
	end
	local plotsFolder = Workspace:WaitForChild("Plots")
	for _, plot in plotsFolder:GetChildren() do
		plot:GetAttributeChangedSignal("OwnerId"):Connect(refreshTag)
	end
	refreshTag()

	return function()
		local state = ctx.getState()
		ctx.panelTitle.Text = ""
		nameBox.Visible = true
		pencil.Visible = true
		showName()
		ctx.showTabs(TABS, tab, function(name)
			tab = name
			choosing = nil
			ctx.refreshPanel()
		end)
		if tab == "Garden" then
			gardenTab(state)
		else
			colourTab(state)
		end
	end
end
