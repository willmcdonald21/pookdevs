-- Edit-time builder: arranges the bakeries around a town square and builds the plaza,
-- paths, fountain, lamps, benches, trees and the grocery store.
-- Safe to run again: plots are placed from the LOTS table (not moved relative to where they
-- are), and everything else is rebuilt from scratch in workspace.Town and workspace.GroceryStore.

local Config = require(game.ReplicatedStorage.Config)
local ItemBuilder = require(game.ReplicatedStorage.ItemBuilder)

local PLAZA_RADIUS = 60
local PATH_WIDTH = 10
local GROUND_Y = 0.5 -- floor centers sit here, so floor tops are at 1

-- Angle around the plaza (degrees), distance from its center, and a small twist so the
-- town doesn't look like a grid. Every lot faces the plaza.
local LOTS = {
	{ Name = "Plot1", Angle = 0, Radius = 88, Yaw = 5 },
	{ Name = "Plot2", Angle = 52, Radius = 96, Yaw = -6 },
	{ Name = "Plot3", Angle = 104, Radius = 84, Yaw = 4 },
	{ Name = "GroceryStore", Angle = 155, Radius = 78, Yaw = 0 },
	{ Name = "Plot4", Angle = 205, Radius = 92, Yaw = -5 },
	{ Name = "Plot5", Angle = 257, Radius = 85, Yaw = 7 },
	{ Name = "Plot6", Angle = 308, Radius = 98, Yaw = -4 },
}

local STONE = Color3.fromRGB(215, 210, 220)
local DARK_STONE = Color3.fromRGB(170, 165, 175)
local WATER = Color3.fromRGB(120, 190, 230)
local WOOD = Color3.fromRGB(150, 100, 70)
local LEAF = Color3.fromRGB(110, 185, 110)
local WHITE = Color3.fromRGB(255, 255, 255)
local GROCER_GREEN = Color3.fromRGB(90, 170, 110)
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

-- Where a lot's floor center goes. +Z of the result points at the plaza.
local function lotCFrame(lot)
	local angle = math.rad(lot.Angle)
	local position = Vector3.new(math.cos(angle) * lot.Radius, GROUND_Y, math.sin(angle) * lot.Radius)
	local toCenter = Vector3.new(-math.cos(angle), 0, -math.sin(angle))
	return CFrame.lookAt(position, position - toCenter) * CFrame.Angles(0, math.rad(lot.Yaw), 0)
end

-- A path from the plaza's edge to a building's front wall at local z = frontZ.
local function addPath(town, cframe, frontZ)
	local reach = (cframe.Position * Vector3.new(1, 0, 1)).Magnitude
	local length = math.max(reach - PLAZA_RADIUS - frontZ + 3, 2)
	part("Path", Vector3.new(PATH_WIDTH, 0.4, length), cframe * CFrame.new(0, -0.3, frontZ + length / 2 - 1), STONE, Enum.Material.Cobblestone, town)
end

-- Plots
for _, lot in LOTS do
	local plot = workspace.Plots:FindFirstChild(lot.Name)
	if plot then
		local move = lotCFrame(lot) * plot.Floor.CFrame:Inverse()
		plot:PivotTo(move * plot:GetPivot())
	end
end

local street = workspace:FindFirstChild("Street")
if street then
	street:Destroy()
end
for _, name in { "Town", "GroceryStore" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local town = Instance.new("Folder")
town.Name = "Town"
town.Parent = workspace

-- Plaza and paths
part("Plaza", Vector3.new(0.4, PLAZA_RADIUS * 2, PLAZA_RADIUS * 2), CFrame.new(0, 0.2, 0) * UPRIGHT, STONE, Enum.Material.Cobblestone, town, Enum.PartType.Cylinder)
part("PlazaRim", Vector3.new(0.3, PLAZA_RADIUS * 2 + 3, PLAZA_RADIUS * 2 + 3), CFrame.new(0, 0.15, 0) * UPRIGHT, DARK_STONE, Enum.Material.Slate, town, Enum.PartType.Cylinder)
for _, lot in LOTS do
	addPath(town, lotCFrame(lot), lot.Name == "GroceryStore" and 15 or 19.5)
end

-- Fountain
local fountain = Instance.new("Model")
fountain.Name = "Fountain"
fountain.Parent = town
part("Basin", Vector3.new(1.4, 18, 18), CFrame.new(0, 1.1, 0) * UPRIGHT, DARK_STONE, Enum.Material.Marble, fountain, Enum.PartType.Cylinder)
part("Water", Vector3.new(0.3, 16, 16), CFrame.new(0, 1.75, 0) * UPRIGHT, WATER, Enum.Material.Glass, fountain, Enum.PartType.Cylinder).Transparency = 0.25
part("Column", Vector3.new(5, 1.6, 1.6), CFrame.new(0, 4, 0) * UPRIGHT, STONE, Enum.Material.Marble, fountain, Enum.PartType.Cylinder)
part("Bowl", Vector3.new(0.8, 7, 7), CFrame.new(0, 6.6, 0) * UPRIGHT, STONE, Enum.Material.Marble, fountain, Enum.PartType.Cylinder)
part("BowlWater", Vector3.new(0.2, 6.2, 6.2), CFrame.new(0, 7, 0) * UPRIGHT, WATER, Enum.Material.Glass, fountain, Enum.PartType.Cylinder).Transparency = 0.25
local spout = part("Spout", Vector3.new(1, 1, 1), CFrame.new(0, 7.6, 0), WATER, Enum.Material.Glass, fountain, Enum.PartType.Ball)
local splash = Instance.new("ParticleEmitter")
splash.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
splash.Size = NumberSequence.new(0.4, 0.1)
splash.Transparency = NumberSequence.new(0.2, 1)
splash.Speed = NumberRange.new(6, 8)
splash.SpreadAngle = Vector2.new(25, 25)
splash.Acceleration = Vector3.new(0, -25, 0)
splash.Lifetime = NumberRange.new(0.6, 0.9)
splash.Rate = 40
splash.EmissionDirection = Enum.NormalId.Top
splash.Parent = spout

-- Lamps between the lots, benches facing the fountain, trees behind the buildings.
for index, lot in LOTS do
	local nextLot = LOTS[index % #LOTS + 1]
	local between = (lot.Angle + ((nextLot.Angle - lot.Angle) % 360) / 2) % 360
	local angle = math.rad(between)
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))

	local lampBase = direction * (PLAZA_RADIUS - 5)
	local lamp = Instance.new("Model")
	lamp.Name = "Lamp"
	lamp.Parent = town
	part("Pole", Vector3.new(9, 0.4, 0.4), CFrame.new(lampBase + Vector3.new(0, 4.9, 0)) * UPRIGHT, Color3.fromRGB(60, 55, 65), Enum.Material.Metal, lamp, Enum.PartType.Cylinder)
	local bulb = part("Bulb", Vector3.new(1.4, 1.4, 1.4), CFrame.new(lampBase + Vector3.new(0, 9.8, 0)), Color3.fromRGB(255, 235, 170), Enum.Material.Neon, lamp, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 225, 170)
	light.Parent = bulb

	local treeBase = direction * (PLAZA_RADIUS + 52)
	local tree = Instance.new("Model")
	tree.Name = "Tree"
	tree.Parent = town
	part("Trunk", Vector3.new(7, 1.4, 1.4), CFrame.new(treeBase + Vector3.new(0, 3.5, 0)) * UPRIGHT, Color3.fromRGB(120, 85, 60), Enum.Material.Wood, tree, Enum.PartType.Cylinder)
	part("Leaves", Vector3.new(8, 8, 8), CFrame.new(treeBase + Vector3.new(0, 9, 0)), LEAF, Enum.Material.Grass, tree, Enum.PartType.Ball)
	part("Leaves", Vector3.new(5.5, 5.5, 5.5), CFrame.new(treeBase + Vector3.new(1.8, 12, 1)), LEAF, Enum.Material.Grass, tree, Enum.PartType.Ball)

	if index % 2 == 0 then
		local benchCFrame = CFrame.lookAt(direction * 24 + Vector3.new(0, 0.4, 0), Vector3.new(0, 0.4, 0))
		local bench = Instance.new("Model")
		bench.Name = "Bench"
		bench.Parent = town
		part("Seat", Vector3.new(6, 0.4, 2), benchCFrame * CFrame.new(0, 1.6, 0), WOOD, Enum.Material.Wood, bench)
		part("Back", Vector3.new(6, 1.6, 0.3), benchCFrame * CFrame.new(0, 2.6, 0.9), WOOD, Enum.Material.Wood, bench)
		for _, x in { -2.5, 2.5 } do
			part("Leg", Vector3.new(0.4, 1.4, 1.8), benchCFrame * CFrame.new(x, 0.7, 0), Color3.fromRGB(60, 55, 65), Enum.Material.Metal, bench)
		end
	end
end

local spawn = workspace:FindFirstChild("SpawnLocation")
if spawn then
	-- Beside the fountain, clear of the benches. Players only wait here while their bakery
	-- loads, or when all six are taken, so the pad is invisible and can be walked through.
	spawn.CFrame = CFrame.new(14, 0.9, 14)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CastShadow = false
end

-- Grocery store. Local frame: floor center at the origin, +Z toward the plaza.
local groceryLot
for _, lot in LOTS do
	if lot.Name == "GroceryStore" then
		groceryLot = lot
	end
end
local base = lotCFrame(groceryLot)
local function at(x, y, z)
	return base * CFrame.new(x, y, z)
end

local store = Instance.new("Model")
store.Name = "GroceryStore"
store.Parent = workspace
local floor = part("Floor", Vector3.new(40, 1, 30), at(0, 0, 0), Color3.fromRGB(240, 238, 230), Enum.Material.Marble, store)
store.PrimaryPart = floor
local walls = Instance.new("Folder")
walls.Name = "Walls"
walls.Parent = store
part("BackWall", Vector3.new(40, 14, 1), at(0, 7.5, -14.5), WHITE, nil, walls)
part("LeftWall", Vector3.new(1, 14, 30), at(-19.5, 7.5, 0), WHITE, nil, walls)
part("RightWall", Vector3.new(1, 14, 30), at(19.5, 7.5, 0), WHITE, nil, walls)
part("FrontLeft", Vector3.new(13, 14, 1), at(-13.5, 7.5, 14.5), WHITE, nil, walls)
part("FrontRight", Vector3.new(13, 14, 1), at(13.5, 7.5, 14.5), WHITE, nil, walls)
part("Lintel", Vector3.new(14, 4, 1), at(0, 12.5, 14.5), WHITE, nil, walls)
part("Trim", Vector3.new(41, 1, 31), at(0, 14.9, 0), GROCER_GREEN, nil, walls).CanCollide = false
part("Roof", Vector3.new(40, 0.6, 30), at(0, 14.3, 0), Color3.fromRGB(235, 235, 235), nil, walls)

-- Striped awning over the front, tilted down toward the plaza.
for stripe = 0, 7 do
	local x = -17.5 + stripe * 5
	part("Awning", Vector3.new(5, 0.3, 5), at(x, 10.2, 17) * CFrame.Angles(math.rad(18), 0, 0), stripe % 2 == 0 and GROCER_GREEN or WHITE, Enum.Material.Fabric, store).CanCollide = false
end

-- Sign. A SurfaceGui draws on the part's Front (-Z), so turn the part to face the plaza.
local sign = part("Sign", Vector3.new(22, 3.6, 0.6), at(0, 16.8, 14.8) * CFrame.Angles(0, math.pi, 0), GROCER_GREEN, nil, store)
local signGui = Instance.new("SurfaceGui")
signGui.Face = Enum.NormalId.Front
signGui.CanvasSize = Vector2.new(440, 72)
local signText = Instance.new("TextLabel")
signText.Size = UDim2.fromScale(1, 1)
signText.BackgroundTransparency = 1
signText.Font = Enum.Font.FredokaOne
signText.TextScaled = true
signText.TextColor3 = WHITE
signText.Text = "Grocery"
signText.Parent = signGui
signGui.Parent = sign

-- Shelves along the back and side walls, stocked with every ingredient.
local shelves = Instance.new("Folder")
shelves.Name = "Shelves"
shelves.Parent = store
local function shelf(cframe, length)
	part("ShelfBack", Vector3.new(length, 6, 0.3), cframe * CFrame.new(0, 3.5, -0.85), WOOD, Enum.Material.Wood, shelves)
	for level, y in { 0.7, 2.6, 4.5 } do
		part("Board", Vector3.new(length, 0.2, 1.8), cframe * CFrame.new(0, y, 0), WOOD, Enum.Material.Wood, shelves)
		local count = math.floor(length / 2)
		for slot = 1, count do
			local ingredient = Config.Ingredients[(slot + level) % #Config.Ingredients + 1]
			local x = -length / 2 + (slot - 0.5) * (length / count)
			local item = ItemBuilder.Build(ingredient, 0.8, cframe * CFrame.new(x, y + 0.1, 0))
			ItemBuilder.Anchor(item)
			item.Parent = shelves
		end
	end
end
shelf(at(-4, 0.5, -13), 22)
-- Side shelves turn so their fronts face into the store.
shelf(at(-18, 0.5, -2) * CFrame.Angles(0, math.rad(90), 0), 16)
shelf(at(18, 0.5, -6) * CFrame.Angles(0, math.rad(-90), 0), 12)

-- Checkout counter by the door, with a cashier behind it. Its prompt opens the Grocery menu.
local counter = part("Counter", Vector3.new(8, 3.4, 3), at(10, 2.2, 6), GROCER_GREEN, nil, store)
part("CounterTop", Vector3.new(8.4, 0.3, 3.4), at(10, 4.05, 6), Color3.fromRGB(240, 238, 230), Enum.Material.Marble, store)
part("Register", Vector3.new(1.6, 1, 1.2), at(12, 4.7, 5.8), Color3.fromRGB(60, 55, 65), Enum.Material.Metal, store)
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "Prompt"
prompt.ActionText = "Shop Groceries"
prompt.ObjectText = "Grocery Store"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 10
prompt.RequiresLineOfSight = false
prompt.Parent = counter

local cashier = Instance.new("Model")
cashier.Name = "Cashier"
cashier.Parent = store
local skin = Color3.fromRGB(225, 175, 130)
local cashierBase = at(10, 0.5, 3)
part("Torso", Vector3.new(2, 2, 1), cashierBase * CFrame.new(0, 3, 0), GROCER_GREEN, nil, cashier)
local head = part("Head", Vector3.new(1.4, 1.4, 1.4), cashierBase * CFrame.new(0, 4.7, 0), skin, nil, cashier)
local face = Instance.new("Decal")
face.Face = Enum.NormalId.Back -- +Z of the cashier, toward the door
face.Texture = "rbxasset://textures/face.png"
face.Parent = head
part("LeftArm", Vector3.new(1, 2, 1), cashierBase * CFrame.new(-1.5, 3, 0), skin, nil, cashier)
part("RightArm", Vector3.new(1, 2, 1), cashierBase * CFrame.new(1.5, 3, 0), skin, nil, cashier)
part("LeftLeg", Vector3.new(0.95, 2, 1), cashierBase * CFrame.new(-0.5, 1, 0), Color3.fromRGB(80, 80, 110), nil, cashier)
part("RightLeg", Vector3.new(0.95, 2, 1), cashierBase * CFrame.new(0.5, 1, 0), Color3.fromRGB(80, 80, 110), nil, cashier)

-- Produce crates by the door, sitting on the path (local y -0.1 is the path's surface).
for _, x in { -9, -5 } do
	part("ProduceCrate", Vector3.new(3, 1.6, 2.4), at(x, 0.7, 18.5), Color3.fromRGB(190, 140, 90), Enum.Material.WoodPlanks, store)
	local produce = ItemBuilder.Build(Config.GetIngredient(x < -6 and "Berries" or "Eggs"), 1, at(x, 1.5, 18.5))
	ItemBuilder.Anchor(produce)
	produce.Parent = store
end
