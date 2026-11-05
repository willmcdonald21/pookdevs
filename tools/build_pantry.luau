-- Edit-time builder: adds a pantry shelf against each bakery's left wall, between the
-- cookbook counter and the first decoration square. Safe to run again: it replaces the shelf.
-- Each ingredient gets a glass jar with a Fill part and a Label. BakerySystem resizes the
-- fill and sets the label from the owner's pantry.

local Config = require(game.ReplicatedStorage.Config)
local ItemBuilder = require(game.ReplicatedStorage.ItemBuilder)

local WOOD = Color3.fromRGB(150, 100, 70)
local GLASS = Color3.fromRGB(210, 235, 245)
local SHELF_HEIGHTS = { 0.2, 2.6, 5 } -- top of each board above the floor
local SLOT_Z = { -1.1, 1.1 }
local JAR_HEIGHT = 1.5
local JAR_WIDTH = 1.3
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X, so stand them up

local function part(name, size, cframe, color, material, parent, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

for _, plot in workspace.Plots:GetChildren() do
	local old = plot:FindFirstChild("PantryShelf")
	if old then
		old:Destroy()
	end
	local floor = plot.Floor
	local floorTop = floor.Size.Y / 2
	-- Shelf origin on the floor against the left wall. Its +X faces into the room.
	local origin = floor.CFrame * CFrame.new(-23, floorTop, -10.7)

	local shelf = Instance.new("Model")
	shelf.Name = "PantryShelf"
	shelf.Parent = plot
	local back = part("Back", Vector3.new(0.3, 7, 4.8), origin * CFrame.new(-0.85, 3.5, 0), WOOD, Enum.Material.Wood, shelf)
	shelf.PrimaryPart = back
	for _, z in { -2.35, 2.35 } do
		part("Side", Vector3.new(2, 7, 0.2), origin * CFrame.new(0, 3.5, z), WOOD, Enum.Material.Wood, shelf)
	end
	for _, y in SHELF_HEIGHTS do
		part("Board", Vector3.new(2, 0.2, 4.6), origin * CFrame.new(0, y - 0.1, 0), WOOD, Enum.Material.Wood, shelf)
	end
	part("Top", Vector3.new(2.2, 0.25, 5), origin * CFrame.new(0, 7.1, 0), WOOD, Enum.Material.Wood, shelf)

	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = shelf
	for index, ingredient in Config.Ingredients do
		local level = math.ceil(index / #SLOT_Z)
		local z = SLOT_Z[(index - 1) % #SLOT_Z + 1]
		local base = origin * CFrame.new(0.1, SHELF_HEIGHTS[level], z)

		local slot = Instance.new("Model")
		slot.Name = ingredient.Id
		slot.Parent = slots
		local jar = part("Jar", Vector3.new(JAR_HEIGHT, JAR_WIDTH, JAR_WIDTH), base * CFrame.new(0, JAR_HEIGHT / 2, 0) * UPRIGHT, GLASS, Enum.Material.Glass, slot, Enum.PartType.Cylinder)
		jar.Transparency = 0.6
		jar.CanCollide = false
		local fill = part("Fill", Vector3.new(0.05, JAR_WIDTH - 0.2, JAR_WIDTH - 0.2), jar.CFrame, ingredient.Color, nil, slot, Enum.PartType.Cylinder)
		fill.CanCollide = false
		fill.Transparency = 1
		local lid = part("Lid", Vector3.new(0.15, JAR_WIDTH + 0.1, JAR_WIDTH + 0.1), base * CFrame.new(0, JAR_HEIGHT + 0.07, 0) * UPRIGHT, WOOD, Enum.Material.Wood, slot, Enum.PartType.Cylinder)
		lid.CanCollide = false
		local icon = ItemBuilder.Build(ingredient, 0.6,base * CFrame.new(0, JAR_HEIGHT + 0.15, 0) * CFrame.Angles(0, math.rad(90), 0))
		ItemBuilder.Anchor(icon)
		icon.Name = "Icon"
		icon.Parent = slot

		-- The label hangs on an invisible marker in front of the jar so the glass doesn't hide it.
		local anchor = part("LabelAnchor", Vector3.new(0.2, 0.2, 0.2), base * CFrame.new(0.9, JAR_HEIGHT / 2 - 0.45, 0), WOOD, nil, slot)
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		local label = Instance.new("BillboardGui")
		label.Name = "Label"
		label.Size = UDim2.fromOffset(96, 22)
		label.MaxDistance = 25
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundColor3 = Color3.fromRGB(255, 250, 240)
		text.BackgroundTransparency = 0.15
		text.TextColor3 = Color3.fromRGB(90, 60, 70)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.Text = ingredient.Name
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.4, 0)
		corner.Parent = text
		text.Parent = label
		label.Parent = anchor
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = "Check Pantry"
	prompt.ObjectText = "Ingredients"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = back
end
