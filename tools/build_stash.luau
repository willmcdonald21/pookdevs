-- Edit-time builder: makes ServerStorage.StashRoom, the template for The Sweet Stash, a
-- storage room behind a bakery's back wall. BakerySystem clones it into each bakery whose
-- owner has bought it, and moves it back with the back wall as the bakery grows. Safe to
-- run again: the old template is replaced.
--
-- The template is in floor space (+Z faces the plaza) with its pivot on the inside face of
-- the back wall, so it goes at floorTop * CFrame.new(0, 0, bounds.MinZ). Sizes come from
-- Layout.Stash: the room's inside walls are at MinX and MaxX, it's Depth deep behind the
-- 1-stud back wall, and the door is the gap from DoorMinX to DoorMaxX, DoorHeight tall.
-- BakerySystem cuts that gap in the back wall itself. Only the floor and walls are solid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Layout = require(ReplicatedStorage.Layout)

local stash = Layout.Stash
local WALL = stash.Wall
local HEIGHT = 14 -- like the bakery walls, from 0.5 below the floor to the trim's top
local BACK = -WALL - stash.Depth -- the room's back wall's inside face
local MID_X = (stash.MinX + stash.MaxX) / 2
local MID_Z = (-WALL + BACK) / 2
local WIDTH = stash.MaxX - stash.MinX + 2 * WALL
local DEPTH = stash.Depth

local CREAM = Color3.fromRGB(255, 240, 225)
local PINK = Color3.fromRGB(240, 150, 175)
local FLOOR = Color3.fromRGB(214, 176, 132)
local MINT = Color3.fromRGB(175, 225, 205)
local GOLD = Color3.fromRGB(235, 195, 95)
local SILVER = Color3.fromRGB(200, 200, 210)
local WHITE = Color3.fromRGB(252, 252, 252)
local MARKER = Color3.fromRGB(60, 120, 200)
local WARM = Color3.fromRGB(255, 220, 170)

local function part(name, size, cframe, color, parent, solid, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanTouch = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function label(parent, face, text, color, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = font
	textLabel.TextScaled = true
	textLabel.TextColor3 = color
	textLabel.Text = text
	textLabel.Parent = gui
	gui.Parent = parent
	return textLabel
end

local old = ServerStorage:FindFirstChild("StashRoom")
if old then
	old:Destroy()
end
local room = Instance.new("Model")
room.Name = "StashRoom"

-- Floor, level with the bakery floor, under the side walls too.
part("Floor", Vector3.new(WIDTH, 1, DEPTH + WALL), CFrame.new(MID_X, -0.5, (BACK - WALL - WALL) / 2), FLOOR, room, true, Enum.Material.WoodPlanks)

-- Walls, with the pink trim along the top like the bakery's.
local walls = Instance.new("Folder")
walls.Name = "Walls"
walls.Parent = room
local wallY = HEIGHT / 2 - 0.5
local sides = {
	{ "LeftWall", Vector3.new(WALL, HEIGHT, DEPTH), CFrame.new(stash.MinX - WALL / 2, wallY, MID_Z) },
	{ "RightWall", Vector3.new(WALL, HEIGHT, DEPTH), CFrame.new(stash.MaxX + WALL / 2, wallY, MID_Z) },
	{ "BackWall", Vector3.new(WIDTH, HEIGHT, WALL), CFrame.new(MID_X, wallY, BACK - WALL / 2) },
}
for _, side in sides do
	local name, size, cframe = side[1], side[2], side[3]
	part(name, size, cframe, CREAM, walls, true)
	local trimSize = size.X > size.Z and Vector3.new(size.X, 1, 1.2) or Vector3.new(1.2, 1, size.Z)
	part("Trim" .. name, trimSize, CFrame.new(cframe.X, HEIGHT - 0.5, cframe.Z), PINK, walls)
end

-- The door frame on the bakery side, and the mint door swung open into the room.
local door = Instance.new("Model")
door.Name = "Door"
door.Parent = room
local doorMid = (stash.DoorMinX + stash.DoorMaxX) / 2
local doorWidth = stash.DoorMaxX - stash.DoorMinX
for _, x in { stash.DoorMinX - 0.2, stash.DoorMaxX + 0.2 } do
	part("Post", Vector3.new(0.4, stash.DoorHeight + 0.4, WALL + 0.4), CFrame.new(x, (stash.DoorHeight + 0.4) / 2 - 0.5, -WALL / 2), PINK, door)
end
part("Header", Vector3.new(doorWidth + 0.8, 0.4, WALL + 0.4), CFrame.new(doorMid, stash.DoorHeight - 0.1, -WALL / 2), PINK, door)
local leafWidth = doorWidth - 0.4
local leaf = part(
	"Leaf",
	Vector3.new(0.25, stash.DoorHeight - 0.6, leafWidth),
	CFrame.new(stash.DoorMinX + 0.15, (stash.DoorHeight - 0.6) / 2, -WALL - leafWidth / 2),
	MINT,
	door
)
part("Panel", Vector3.new(0.3, 2.6, leafWidth - 1.2), leaf.CFrame * CFrame.new(0, 1.6, 0), Color3.fromRGB(150, 205, 185), door)
part("Panel", Vector3.new(0.3, 2.6, leafWidth - 1.2), leaf.CFrame * CFrame.new(0, -1.8, 0), Color3.fromRGB(150, 205, 185), door)
local knob = part("Knob", Vector3.new(0.5, 0.5, 0.5), leaf.CFrame * CFrame.new(0.3, -0.6, leafWidth / 2 - 0.5), GOLD, door, false, Enum.Material.Metal)
knob.Shape = Enum.PartType.Ball

-- "The Sweet Stash" over the door, on the bakery side, below the trim.
local sign = part("Sign", Vector3.new(doorWidth + 2, 2, 0.2), CFrame.new(doorMid, stash.DoorHeight + 1.6, 0.1), CREAM, door)
part("SignBorder", Vector3.new(doorWidth + 2.4, 2.4, 0.15), CFrame.new(doorMid, stash.DoorHeight + 1.6, 0.05), PINK, door)
local title = label(sign, Enum.NormalId.Back, "The Sweet Stash", Color3.fromRGB(215, 95, 135), Enum.Font.FredokaOne)
title.Position = UDim2.fromScale(0.04, 0.1)
title.Size = UDim2.fromScale(0.92, 0.8)

-- Two warm lamps on the back wall.
for _, x in { stash.MinX + 6, stash.MaxX - 6 } do
	local lamp = part("Lamp", Vector3.new(1.2, 0.8, 0.5), CFrame.new(x, 10, BACK + 0.25), WARM, room, false, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Range = 22
	light.Brightness = 1.2
	light.Shadows = true
	light.Parent = lamp
end

-- The whiteboard on the right wall, facing into the room.
local whiteboard = Instance.new("Model")
whiteboard.Name = "Whiteboard"
whiteboard.Parent = room
local boardZ = -WALL - stash.WhiteboardZ
local width = stash.WhiteboardWidth
local facing = CFrame.lookAt(Vector3.new(stash.MaxX - 0.1, 4.6, boardZ), Vector3.new(stash.MaxX - 10, 4.6, boardZ))
part("Frame", Vector3.new(width + 0.3, 4.3, 0.15), facing, SILVER, whiteboard, false, Enum.Material.Metal)
local board = part("Board", Vector3.new(width, 4, 0.1), facing * CFrame.new(0, 0, -0.1), WHITE, whiteboard)
part("Tray", Vector3.new(width - 1, 0.15, 0.4), facing * CFrame.new(0, -2.15, -0.25), SILVER, whiteboard, false, Enum.Material.Metal)
for index, color in { MARKER, PINK, Color3.fromRGB(90, 170, 110) } do
	local marker = part("Marker", Vector3.new(0.8, 0.15, 0.15), facing * CFrame.new(-1.5 + index * 0.9, -2, -0.3), color, whiteboard)
	marker.Shape = Enum.PartType.Cylinder
end

local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Front
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 50
gui.Parent = board
local lines = {
	{ "Stash list", 0.04, 0.2, MARKER },
	{ "♥ shelves for spare treats", 0.3, 0.13, PINK },
	{ "★ pick a treat for each case", 0.46, 0.13, MARKER },
	{ "✓ the Stocker does the rest!", 0.62, 0.13, Color3.fromRGB(70, 150, 95) },
	{ "( tap to use )", 0.82, 0.1, Color3.fromRGB(150, 150, 160) },
}
for _, line in lines do
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromScale(0.06, line[2])
	text.Size = UDim2.fromScale(0.88, line[3])
	text.Font = Enum.Font.PermanentMarker
	text.TextScaled = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextColor3 = line[4]
	text.Text = line[1]
	text.Parent = gui
end

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "Prompt"
prompt.ActionText = "Use Whiteboard"
prompt.ObjectText = "The Sweet Stash"
prompt.MaxActivationDistance = 8
prompt.RequiresLineOfSight = false
prompt.Parent = board

room.WorldPivot = CFrame.new()
room.Parent = ServerStorage
return ("StashRoom: %d parts"):format(#room:GetDescendants())
