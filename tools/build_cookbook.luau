-- Edit-time builder: turns every plot's UpgradeStation into a wooden counter with an
-- open cookbook on top. Safe to run again: it removes its own parts first.
-- The part keeps the name UpgradeStation, with its Prompt and Status, so scripts still find it.

-- The wooden base's height. With the marble slab on top, the counter is 3.8 studs tall,
-- the same as the delivery counter.
local BASE_HEIGHT = 3.5
-- How far the "Cookbook" label floats above the top of the base.
local LABEL_HEIGHT = 2

local WOOD = Color3.fromRGB(160, 110, 75)
local MARBLE = Color3.fromRGB(245, 240, 235)
local COVER = Color3.fromRGB(190, 45, 65)
local PAGE = Color3.fromRGB(255, 248, 230)
local INK = Color3.fromRGB(90, 60, 70)

local function part(name, size, cframe, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

for _, plot in workspace.Plots:GetChildren() do
	local station = plot.UpgradeStation
	for _, name in { "CounterSlab", "Cookbook" } do
		local old = station:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	station.Color = WOOD
	station.Material = Enum.Material.Wood
	-- Resize from the bottom so the counter stays standing on the floor.
	local bottom = station.CFrame * CFrame.new(0, -station.Size.Y / 2, 0)
	station.Size = Vector3.new(station.Size.X, BASE_HEIGHT, station.Size.Z)
	station.CFrame = bottom * CFrame.new(0, BASE_HEIGHT / 2, 0)
	station.Status.StudsOffset = Vector3.new(0, BASE_HEIGHT / 2 + LABEL_HEIGHT, 0)
	local top = station.Size.Y / 2
	local slab = part("CounterSlab", Vector3.new(station.Size.X + 0.4, 0.3, station.Size.Z + 0.4), station.CFrame * CFrame.new(0, top + 0.15, 0), MARBLE, Enum.Material.Marble, station)
	slab.CanCollide = true

	-- The open book tilts toward the room (+Z) so its pages face whoever is reading.
	local book = Instance.new("Model")
	book.Name = "Cookbook"
	book.Parent = station
	local origin = station.CFrame * CFrame.new(0, top + 0.9, 0.2) * CFrame.Angles(math.rad(22), 0, 0)
	part("Stand", Vector3.new(1.2, 1, 1.2), station.CFrame * CFrame.new(0, top + 0.5, 0.2), COVER, nil, book)
	part("Cover", Vector3.new(4.6, 0.2, 3.3), origin, COVER, nil, book)
	for _, side in { -1, 1 } do
		local page = part("Page", Vector3.new(2.1, 0.3, 3), origin * CFrame.new(side * 1.12, 0.22, 0) * CFrame.Angles(0, 0, math.rad(side * 5)), PAGE, nil, book)
		for line = 1, 5 do
			part("Line", Vector3.new(1.5, 0.02, 0.1), page.CFrame * CFrame.new(0, 0.16, -1.2 + line * 0.4), INK, nil, book)
		end
	end
	part("Spine", Vector3.new(0.22, 0.4, 3.1), origin * CFrame.new(0, 0.2, 0), COVER, nil, book)
	part("Ribbon", Vector3.new(0.22, 0.04, 1.8), origin * CFrame.new(0.25, 0.4, 2), Color3.fromRGB(255, 200, 70), nil, book)

	station.Status.Label.Text = "Cookbook"
	station.Prompt.ActionText = "Open Cookbook"
	station.Prompt.ObjectText = "Recipes and goals"
end
