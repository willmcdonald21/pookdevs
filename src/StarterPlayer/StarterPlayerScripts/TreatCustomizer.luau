-- The Treat Designer popup, opened by the Customize button beside a known recipe in the
-- Cookbook. On the left the treat turns slowly (drag it round), with Reset to original
-- under it. On the right are three tabs: Colours for the pastry, frosting and filling,
-- Toppings for sprinkles, cherries, whipped cream and candles, and Draw, a Grid x Grid
-- canvas to draw on the top in frosting. Save sends the design to the server, which builds
-- every one of that treat in the bakery that way. Saving is free. Closing with unsaved
-- changes, Reset and Clear each need a second tap.
-- BakeryClient requires this and calls the function it returns with the helpers it shares
-- (ctx), like ExteriorPanel. That gives back { open(recipeIndex), refresh() }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local TreatDesign = require(ReplicatedStorage:WaitForChild("TreatDesign"))
local TreatArt = require(script.Parent:WaitForChild("TreatArt"))

local GRID = TreatDesign.Grid
local CELLS = TreatDesign.Cells
local EMPTY_ART = string.rep("0", CELLS)
local TABS = { "Colours", "Toppings", "Draw" }
local ROLE_NAMES = { Dough = "Pastry", Frosting = "Frosting", Filling = "Filling" }
local FIELDS = { "Dough", "Frosting", "Filling", "Sprinkles", "Cherries", "Cream", "Candles", "CandleColor", "Art" }
local TOOLS = { "Pen", "Big", "Eraser", "Fill" }
local SWATCH = 34
-- How long a button waits for its second tap.
local CONFIRM_SECONDS = 3
local Z = 20

return function(ctx)
	local colours = ctx.colours
	local label, button, style = ctx.label, ctx.button, ctx.style
	local designEvent = ReplicatedStorage:WaitForChild("DesignTreat")
	local api = {}

	-- What's being designed. design holds everything but the drawing, which is in cells.
	local recipeIndex, recipe = nil, nil
	local design = nil
	local cells = nil
	-- The design as last saved (nil for the original look), to tell when there are changes.
	local saved = nil
	local tab = "Colours"
	local tool = "Pen"
	local brush = 1
	local waiting = {}
	-- previewPivot is how the preview's first part sits before it turns: a lying-down
	-- cylinder for most treats.
	local preview, previewKey, previewPivot = nil, nil, nil
	local angle, dragging, dragX = 0, false, 0
	local painting, lastCell = false, nil
	-- The server takes one save a second, so the button waits that long too.
	local lastSave = 0
	-- The canvas is also the preview's drawing, so the treat changes as you draw.
	local canvasImage = TreatArt.NewImage()

	-- Window
	local window = style(Instance.new("Frame"), "TreatDesigner", UDim2.fromScale(0.94, 0.86), UDim2.new(0.5, 0, 0.5, 12), Vector2.new(0.5, 0.5), colours.CREAM)
	window.Visible = false
	window.Active = true
	window.ZIndex = Z
	-- Everything in the window draws over it, deeper things over shallower ones.
	window.DescendantAdded:Connect(function(object)
		if object:IsA("GuiObject") then
			local depth, parent = 1, object.Parent
			while parent and parent ~= window do
				depth += 1
				parent = parent.Parent
			end
			object.ZIndex = Z + depth
		end
	end)
	window.Parent = ctx.gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(780, 520)
	limit.Parent = window

	local title = label("Title", UDim2.new(1, -230, 0, 40), UDim2.fromOffset(10, 8), Vector2.zero, colours.CREAM, colours.BROWN, window)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local saveButton = button("Save", UDim2.fromOffset(100, 44), UDim2.new(1, -114, 0, 6), Vector2.new(1, 0), colours.GREEN, window)
	saveButton.Text = "Save"
	local closeButton = button("Close", UDim2.fromOffset(100, 44), UDim2.new(1, -8, 0, 6), Vector2.new(1, 0), colours.PINK, window)
	closeButton.Text = "Close"

	local view = Instance.new("ViewportFrame")
	view.Name = "Preview"
	view.Size = UDim2.new(0.4, -14, 1, -112)
	view.Position = UDim2.fromOffset(10, 54)
	view.BackgroundColor3 = colours.WHITE
	view.Ambient = Color3.fromRGB(200, 200, 200)
	view.LightColor = colours.WHITE
	view.Parent = window
	Instance.new("UICorner").Parent = view
	local camera = Instance.new("Camera")
	camera.Parent = view
	view.CurrentCamera = camera
	local resetButton = button("Reset", UDim2.new(0.4, -14, 0, 44), UDim2.new(0, 10, 1, -8), Vector2.new(0, 1), colours.BLUE, window)
	resetButton.Text = "Reset to original"

	local tabBox = Instance.new("Frame")
	tabBox.Name = "Tabs"
	tabBox.Size = UDim2.new(0.6, -10, 0, 40)
	tabBox.Position = UDim2.new(0.4, 4, 0, 54)
	tabBox.BackgroundTransparency = 1
	tabBox.Parent = window
	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.Padding = UDim.new(0, 8)
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Parent = tabBox
	local tabButtons = {}
	for index, name in TABS do
		local tabButton = button(name .. "Tab", UDim2.new(1 / #TABS, -8, 1, 0), UDim2.new(), Vector2.zero, colours.GREY, tabBox)
		tabButton.Text = name
		tabButton.LayoutOrder = index
		tabButtons[name] = tabButton
	end

	-- The Colours and Toppings tabs are rows in a scrolling list.
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Size = UDim2.new(0.6, -10, 1, -108)
	body.Position = UDim2.new(0.4, 4, 0, 100)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 8
	body.ScrollBarImageColor3 = colours.PINK
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = window
	local bodyList = Instance.new("UIListLayout")
	bodyList.Padding = UDim.new(0, 6)
	bodyList.SortOrder = Enum.SortOrder.LayoutOrder
	bodyList.Parent = body

	-- The Draw tab: the canvas, with the tools and colours in a column on its right.
	local drawArea = Instance.new("Frame")
	drawArea.Name = "Draw"
	drawArea.Size = body.Size
	drawArea.Position = body.Position
	drawArea.BackgroundTransparency = 1
	drawArea.Visible = false
	drawArea.Parent = window
	local board = Instance.new("Frame")
	board.Name = "Board"
	board.Size = UDim2.new(1, -104, 1, 0)
	board.BackgroundTransparency = 1
	board.Parent = drawArea
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio = 1
	square.Parent = board
	-- The treat's top in its colour, a round shape under the canvas, with the donut's hole.
	local shape = Instance.new("Frame")
	shape.Name = "Shape"
	shape.Size = UDim2.fromScale(1, 1)
	shape.BorderSizePixel = 0
	shape.Parent = board
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = shape
	local hole = Instance.new("Frame")
	hole.Name = "Hole"
	hole.AnchorPoint = Vector2.new(0.5, 0.5)
	hole.Position = UDim2.fromScale(0.5, 0.5)
	hole.BackgroundColor3 = colours.CREAM
	hole.BorderSizePixel = 0
	hole.Parent = shape
	round:Clone().Parent = hole
	local shapeStroke = Instance.new("UIStroke")
	shapeStroke.Color = colours.PINK
	shapeStroke.Thickness = 2
	shapeStroke.Parent = shape
	local canvas = Instance.new("ImageLabel")
	canvas.Name = "Canvas"
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundTransparency = 1
	canvas.ResampleMode = Enum.ResamplerMode.Pixelated
	canvas.Active = true
	if canvasImage then
		canvas.ImageContent = Content.fromObject(canvasImage)
	end
	canvas.Parent = board
	local notice = label("Notice", UDim2.new(1, -8, 0, 80), UDim2.fromOffset(0, 10), Vector2.zero, colours.CREAM, colours.BROWN, drawArea)
	notice.Visible = false

	local toolColumn = Instance.new("ScrollingFrame")
	toolColumn.Name = "Tools"
	toolColumn.Size = UDim2.new(0, 96, 1, 0)
	toolColumn.Position = UDim2.fromScale(1, 0)
	toolColumn.AnchorPoint = Vector2.new(1, 0)
	toolColumn.BackgroundTransparency = 1
	toolColumn.BorderSizePixel = 0
	toolColumn.ScrollBarThickness = 4
	toolColumn.ScrollBarImageColor3 = colours.PINK
	toolColumn.AutomaticCanvasSize = Enum.AutomaticSize.Y
	toolColumn.CanvasSize = UDim2.new()
	toolColumn.Parent = drawArea
	local toolGrid = Instance.new("UIGridLayout")
	toolGrid.CellSize = UDim2.fromOffset(42, 32)
	toolGrid.CellPadding = UDim2.fromOffset(4, 4)
	toolGrid.SortOrder = Enum.SortOrder.LayoutOrder
	toolGrid.Parent = toolColumn
	local toolButtons = {}
	for index, name in TOOLS do
		local toolButton = button(name, UDim2.new(), UDim2.new(), Vector2.zero, colours.GREY, toolColumn)
		toolButton.Text = name
		toolButton.LayoutOrder = index
		toolButtons[name] = toolButton
	end
	local clearButton = button("Clear", UDim2.new(), UDim2.new(), Vector2.zero, colours.PINK, toolColumn)
	clearButton.Text = "Clear"
	clearButton.LayoutOrder = #TOOLS + 1
	local paletteButtons = {}
	for index, color in Config.TreatColors do
		local swatch = button(color.Id, UDim2.new(), UDim2.new(), Vector2.zero, color.Color, toolColumn)
		swatch.LayoutOrder = 10 + index
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = colours.BROWN
		stroke.Parent = swatch
		paletteButtons[index] = stroke
	end

	-- The design as the server would keep it, or nil for the original look.
	local function current()
		local raw = table.clone(design)
		raw.Art = table.concat(cells)
		return TreatDesign.Clean(raw, recipe)
	end

	local function same(a, b)
		if a == nil or b == nil then
			return a == b
		end
		for _, field in FIELDS do
			if a[field] ~= b[field] then
				return false
			end
		end
		return true
	end

	-- The colour a role starts in, or nil when the recipe has none (frosting on a treat
	-- that can have Icing).
	local function originalColor(role)
		for _, spec in recipe.Parts do
			if spec.Role == role then
				return spec.Color
			end
		end
		return nil
	end

	-- The colour of the treat's top, for under the canvas: the highest part a design can
	-- colour, or the icing when there is some.
	local function topColor()
		if recipe.Top.Icing and design.Frosting and not originalColor("Frosting") then
			return TreatDesign.Color(design.Frosting)
		end
		local best, bestHeight = nil, -math.huge
		for _, spec in recipe.Parts do
			if spec.Role == "Dough" or spec.Role == "Frosting" or spec.Role == "Filling" then
				local height = spec.Y + (spec.Height or (spec.Size and spec.Size.Y) or spec.Diameter or 0) / 2
				if height >= bestHeight then
					best, bestHeight = spec, height
				end
			end
		end
		if not best then
			return colours.WHITE
		end
		return design[best.Role] and TreatDesign.Color(design[best.Role]) or best.Color
	end

	local function drawCanvas()
		if canvasImage then
			TreatArt.Write(canvasImage, table.concat(cells))
		end
	end

	-- Builds the preview again when anything but the drawing changes. The drawing is the
	-- canvas itself, so it changes on its own.
	local function refreshPreview()
		local cleaned = current()
		local key = "original"
		if cleaned then
			local copy = table.clone(cleaned)
			copy.Art = copy.Art and "drawn" or nil
			local parts = {}
			for _, field in FIELDS do
				table.insert(parts, tostring(copy[field]))
			end
			key = table.concat(parts, ",")
		end
		if key ~= previewKey then
			previewKey = key
			if preview then
				preview:Destroy()
			end
			preview = TreatDesign.Build(recipeIndex, cleaned, 1, CFrame.new())
			for _, object in preview:GetDescendants() do
				if object:IsA("BasePart") then
					object.Anchored = true
				elseif object.Name == "TreatArt" and object:IsA("Decal") and canvasImage then
					object.TextureContent = Content.fromObject(canvasImage)
				end
			end
			preview.Parent = view
			previewPivot = preview:GetPivot()
			local center, extents = preview:GetBoundingBox()
			camera.CFrame = CFrame.lookAt(center.Position + Vector3.new(0, 1, 0.9).Unit * extents.Magnitude * 1.05, center.Position)
		end
		local changed = not same(cleaned, saved)
		saveButton.Text = changed and "Save" or "Saved"
		saveButton.BackgroundColor3 = changed and colours.GREEN or colours.GREY
		saveButton.AutoButtonColor = changed
	end

	-- Rows for the Colours and Toppings tabs
	local order = 0
	local function addHeading(text)
		order += 1
		local heading = label("Heading", UDim2.new(1, -12, 0, 28), UDim2.new(), Vector2.zero, colours.CREAM, colours.BROWN, body)
		heading.BackgroundTransparency = 1
		heading.TextXAlignment = Enum.TextXAlignment.Left
		heading.Text = text
		heading.LayoutOrder = order
	end

	-- options is a list of { Id, Color, Text }. Tapping one calls onPick with its Id.
	local function addSwatches(options, selected, onPick)
		order += 1
		local holder = Instance.new("Frame")
		holder.Name = "Swatches"
		holder.Size = UDim2.new(1, -12, 0, 0)
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.BackgroundTransparency = 1
		holder.LayoutOrder = order
		holder.Parent = body
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(SWATCH, SWATCH)
		grid.CellPadding = UDim2.fromOffset(6, 6)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = holder
		for index, option in options do
			local swatch = button("Swatch", UDim2.new(), UDim2.new(), Vector2.zero, option.Color, holder)
			swatch.LayoutOrder = index
			swatch.Text = option.Text or ""
			swatch.TextColor3 = colours.BROWN
			swatch.UIPadding:Destroy()
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = option.Id == selected and colours.BROWN or colours.GREY
			stroke.Thickness = option.Id == selected and 4 or 1
			stroke.Parent = swatch
			swatch.Activated:Connect(function()
				onPick(option.Id)
			end)
		end
	end

	local function colorOptions(first)
		local options = { first }
		for _, color in Config.TreatColors do
			table.insert(options, { Id = color.Id, Color = color.Color })
		end
		return options
	end

	local function addStepper(name, value, max, onChange)
		order += 1
		local row = style(Instance.new("Frame"), "Stepper", UDim2.new(1, -12, 0, 48), UDim2.new(), Vector2.zero, colours.WHITE)
		row.LayoutOrder = order
		row.Parent = body
		local text = label("Label", UDim2.new(1, -170, 1, -8), UDim2.fromOffset(4, 4), Vector2.zero, colours.WHITE, colours.BROWN, row)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Text = name
		local less = button("Less", UDim2.fromOffset(44, 40), UDim2.new(1, -112, 0.5, 0), Vector2.new(1, 0.5), value > 0 and colours.PINK or colours.GREY, row)
		less.Text = "-"
		local count = label("Count", UDim2.fromOffset(52, 40), UDim2.new(1, -56, 0.5, 0), Vector2.new(1, 0.5), colours.CREAM, colours.BROWN, row)
		count.Text = tostring(value)
		local more = button("More", UDim2.fromOffset(44, 40), UDim2.new(1, -6, 0.5, 0), Vector2.new(1, 0.5), value < max and colours.GREEN or colours.GREY, row)
		more.Text = "+"
		less.Activated:Connect(function()
			if value > 0 then
				onChange(value - 1)
			end
		end)
		more.Activated:Connect(function()
			if value < max then
				onChange(value + 1)
			end
		end)
	end

	local render
	local function change(field, value)
		design[field] = value
		render()
	end

	local function showColours()
		local roles = TreatDesign.Roles(recipe)
		for _, role in TreatDesign.ColorRoles do
			if roles[role] then
				addHeading(ROLE_NAMES[role])
				local original = originalColor(role)
				local first = original and { Color = original, Text = "↺" } or { Color = colours.WHITE, Text = "None" }
				addSwatches(colorOptions(first), design[role], function(id)
					change(role, id)
				end)
			end
		end
	end

	local function showToppings()
		local settings = Config.TreatDesign
		addHeading("Sprinkles")
		local options = colorOptions({ Color = colours.WHITE, Text = "None" })
		table.insert(options, 2, { Id = "Rainbow", Color = colours.WHITE, Text = "🌈" })
		addSwatches(options, design.Sprinkles, function(id)
			change("Sprinkles", id)
		end)
		addStepper("Cherries", design.Cherries, settings.MaxCherries, function(value)
			change("Cherries", value)
		end)
		addStepper("Whipped cream", design.Cream, settings.MaxCream, function(value)
			change("Cream", value)
		end)
		addStepper("Candles", design.Candles, settings.MaxCandles, function(value)
			change("Candles", value)
		end)
		if design.Candles > 0 then
			addHeading("Candle colour")
			local candle = {}
			for _, color in Config.TreatColors do
				table.insert(candle, { Id = color.Id, Color = color.Color })
			end
			addSwatches(candle, design.CandleColor, function(id)
				change("CandleColor", id)
			end)
		end
	end

	local function showDraw()
		local canDraw = TreatDesign.CanDraw(recipe) and canvasImage ~= nil
		board.Visible = canDraw
		toolColumn.Visible = canDraw
		notice.Visible = not canDraw
		if not TreatDesign.CanDraw(recipe) then
			notice.Text = ("The %s is too curvy to draw on. Try the colours and toppings!"):format(recipe.Name:lower())
		elseif not canvasImage then
			notice.Text = "Drawing isn't ready in this game yet. Colours and toppings still work!"
		end
		if not canDraw then
			return
		end
		shape.BackgroundColor3 = topColor()
		local holeSize = recipe.Top.Hole and recipe.Top.Hole / TreatDesign.ArtSize(recipe) or 0
		hole.Visible = holeSize > 0
		hole.Size = UDim2.fromScale(holeSize, holeSize)
		for name, toolButton in toolButtons do
			toolButton.BackgroundColor3 = name == tool and colours.PINK or colours.GREY
		end
		for index, stroke in paletteButtons do
			stroke.Thickness = index == brush and tool ~= "Eraser" and 4 or 1
		end
	end

	render = function()
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		order = 0
		for name, tabButton in tabButtons do
			tabButton.BackgroundColor3 = name == tab and colours.PINK or colours.GREY
		end
		body.Visible = tab ~= "Draw"
		drawArea.Visible = tab == "Draw"
		if tab == "Colours" then
			showColours()
		elseif tab == "Toppings" then
			showToppings()
		else
			showDraw()
		end
		refreshPreview()
	end

	for name, tabButton in tabButtons do
		tabButton.Activated:Connect(function()
			tab = name
			render()
		end)
	end

	-- A button that needs a second tap: the first one asks, and the second, within a few
	-- seconds, runs it.
	local function secondTap(target, normalText, askText, run)
		if waiting[target] and os.clock() < waiting[target] then
			waiting[target] = nil
			target.Text = normalText
			run()
			return
		end
		waiting[target] = os.clock() + CONFIRM_SECONDS
		target.Text = askText
		task.delay(CONFIRM_SECONDS, function()
			if waiting[target] and os.clock() >= waiting[target] then
				waiting[target] = nil
				target.Text = normalText
			end
		end)
	end

	-- Drawing
	local function setCell(column, row, letter)
		if column >= 0 and column < GRID and row >= 0 and row < GRID and TreatDesign.InShape(recipe, column, row) then
			cells[row * GRID + column + 1] = letter
		end
	end

	local function stamp(column, row)
		local letter = tool == "Eraser" and "0" or string.char(96 + brush)
		if tool == "Pen" then
			setCell(column, row, letter)
		else
			for dy = -1, 1 do
				for dx = -1, 1 do
					setCell(column + dx, row + dy, letter)
				end
			end
		end
	end

	-- Fill paints every touching cell that's the same as the one tapped.
	local function fill(column, row)
		local target = cells[row * GRID + column + 1]
		local letter = string.char(96 + brush)
		if target == letter or not TreatDesign.InShape(recipe, column, row) then
			return
		end
		local queue = { { column, row } }
		while #queue > 0 do
			local cell = table.remove(queue)
			local x, y = cell[1], cell[2]
			local index = y * GRID + x + 1
			if x >= 0 and x < GRID and y >= 0 and y < GRID and cells[index] == target and TreatDesign.InShape(recipe, x, y) then
				cells[index] = letter
				table.insert(queue, { x + 1, y })
				table.insert(queue, { x - 1, y })
				table.insert(queue, { x, y + 1 })
				table.insert(queue, { x, y - 1 })
			end
		end
	end

	local function cellAt(position)
		local size = canvas.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return nil
		end
		local relative = (Vector2.new(position.X, position.Y) - canvas.AbsolutePosition) / size
		if relative.X < 0 or relative.X >= 1 or relative.Y < 0 or relative.Y >= 1 then
			return nil
		end
		return { math.floor(relative.X * GRID), math.floor(relative.Y * GRID) }
	end

	-- A drag paints every cell between the last spot and this one, so fast strokes
	-- don't leave gaps.
	local function paintTo(position)
		local cell = cellAt(position)
		if not cell then
			lastCell = nil
			return
		end
		local from = lastCell or cell
		local steps = math.max(math.abs(cell[1] - from[1]), math.abs(cell[2] - from[2]), 1)
		for step = 0, steps do
			local t = step / steps
			stamp(math.floor(from[1] + (cell[1] - from[1]) * t + 0.5), math.floor(from[2] + (cell[2] - from[2]) * t + 0.5))
		end
		lastCell = cell
		drawCanvas()
	end

	local function isPress(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end

	canvas.InputBegan:Connect(function(input)
		if not isPress(input) or not recipe or tab ~= "Draw" then
			return
		end
		if tool == "Fill" then
			local cell = cellAt(input.Position)
			if cell then
				fill(cell[1], cell[2])
				drawCanvas()
				refreshPreview()
			end
			return
		end
		painting, lastCell = true, nil
		paintTo(input.Position)
	end)
	UserInputService.InputChanged:Connect(function(input)
		if painting and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			paintTo(input.Position)
		elseif dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			angle += (input.Position.X - dragX) * 0.012
			dragX = input.Position.X
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isPress(input) then
			if painting then
				painting, lastCell = false, nil
				refreshPreview()
			end
			dragging = false
		end
	end)

	for name, toolButton in toolButtons do
		toolButton.Activated:Connect(function()
			tool = name
			showDraw()
		end)
	end
	for index, stroke in paletteButtons do
		stroke.Parent.Activated:Connect(function()
			brush = index
			if tool == "Eraser" then
				tool = "Pen"
			end
			showDraw()
		end)
	end
	clearButton.Activated:Connect(function()
		secondTap(clearButton, "Clear", "Sure?", function()
			cells = string.split(EMPTY_ART, "")
			drawCanvas()
			refreshPreview()
		end)
	end)

	-- Turning the preview
	view.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging, dragX = true, input.Position.X
		end
	end)
	RunService.RenderStepped:Connect(function(delta)
		if preview and window.Visible then
			if not dragging then
				angle += delta * 0.5
			end
			preview:PivotTo(CFrame.Angles(0, angle, 0) * previewPivot)
		end
	end)

	-- Opening, saving and closing
	local function load(from)
		local base = from or TreatDesign.Default(recipe)
		design = {}
		for _, field in FIELDS do
			if field ~= "Art" then
				design[field] = base[field]
			end
		end
		cells = string.split(from and from.Art or EMPTY_ART, "")
		drawCanvas()
	end

	local function close()
		window.Visible = false
		recipeIndex, recipe = nil, nil
		painting, dragging = false, false
		if preview then
			preview:Destroy()
			preview = nil
		end
		previewKey = nil
		ctx.panel.Visible = ctx.currentPanel() ~= nil
	end

	saveButton.Activated:Connect(function()
		local cleaned = recipe and current()
		if not recipe or same(cleaned, saved) or os.clock() - lastSave < Config.TreatDesign.SaveSeconds then
			return
		end
		lastSave = os.clock()
		local raw = table.clone(design)
		raw.Art = table.concat(cells)
		designEvent:FireServer(recipeIndex, raw)
		saved = cleaned
		refreshPreview()
	end)
	closeButton.Activated:Connect(function()
		if recipe and not same(current(), saved) then
			secondTap(closeButton, "Close", "Discard?", close)
		else
			close()
		end
	end)
	resetButton.Activated:Connect(function()
		if not recipe then
			return
		end
		secondTap(resetButton, "Reset to original", "Tap again to reset", function()
			if saved then
				lastSave = os.clock()
				designEvent:FireServer(recipeIndex, "Reset")
			end
			saved = nil
			load(nil)
			render()
		end)
	end)

	function api.open(index)
		recipeIndex, recipe = index, Config.Recipes[index]
		if not recipe then
			return
		end
		saved = TreatArt.DesignFor(ctx.myPlot(), index)
		load(saved)
		tab, angle, previewKey = "Colours", 0, nil
		title.Text = "Decorate your " .. recipe.Name
		for target, text in { [saveButton] = "Save", [closeButton] = "Close", [resetButton] = "Reset to original", [clearButton] = "Clear" } do
			waiting[target] = nil
			target.Text = text
		end
		window.Visible = true
		ctx.panel.Visible = false
		render()
	end

	-- After each menu change: the designer closes with the Cookbook.
	function api.refresh()
		if recipe and ctx.currentPanel() ~= "Cookbook" then
			close()
		end
	end

	return api
end
