-- Edit-time builder: restyles every plot's oven as a retro kitchen range.
-- Run once in Studio (command bar or MCP). Safe to run again: it removes its own parts first.
-- Keeps the parts the scripts use: Body (with Prompt and Status), Window, Handle, Chimney (with Smoke).

local CREAM = Color3.fromRGB(175, 225, 205) -- pastel mint, so the range stands out from the white walls
local PINK = Color3.fromRGB(240, 150, 175)
local STEEL = Color3.fromRGB(205, 210, 215)
local DARK = Color3.fromRGB(55, 50, 55)
local BUILT = { "Trim", "KickPlate", "Stovetop", "Burners", "Controls", "DoorFrame", "Backsplash", "BacksplashTrim", "Hood" }

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
	local oven = plot.Oven
	for _, name in BUILT do
		local old = oven:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local body = oven.Body
	local base = body.CFrame -- +Z of the body faces into the room
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end

	body.Color = CREAM
	body.Material = Enum.Material.SmoothPlastic
	part("Trim", Vector3.new(9.05, 0.5, 5.05), at(0, 1.6, 0), PINK, nil, oven)
	part("KickPlate", Vector3.new(8.6, 0.6, 0.2), at(0, -3.6, 2.55), DARK, nil, oven)
	part("Stovetop", Vector3.new(9.2, 0.3, 5.2), at(0, 4.15, 0), DARK, Enum.Material.Metal, oven)

	local burners = Instance.new("Folder")
	burners.Name = "Burners"
	burners.Parent = oven
	for _, x in { -2.2, 2.2 } do
		for _, z in { -1.2, 1.2 } do
			-- Cylinders run along X, so turn them to stand flat on the stovetop.
			local burner = part("Burner", Vector3.new(0.12, 1.8, 1.8), at(x, 4.33, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(85, 80, 85), nil, burners, Enum.PartType.Cylinder)
			burner.CanCollide = false
		end
	end

	local controls = Instance.new("Model")
	controls.Name = "Controls"
	controls.Parent = oven
	part("Panel", Vector3.new(8.6, 1, 0.2), at(0, 3.2, 2.6), STEEL, Enum.Material.Metal, controls)
	for _, x in { -2.8, 0, 2.8 } do
		-- Knobs point out of the front of the oven.
		local knob = part("Knob", Vector3.new(0.35, 0.6, 0.6), at(x, 3.2, 2.85) * CFrame.Angles(0, math.rad(90), 0), DARK, nil, controls, Enum.PartType.Cylinder)
		knob.CanCollide = false
	end

	-- Steel frame behind the oven window.
	local window = oven.Window
	local frame = part("DoorFrame", Vector3.new(window.Size.X + 0.8, window.Size.Y + 0.8, 0.15), window.CFrame * CFrame.new(0, 0, -0.05), STEEL, Enum.Material.Metal, oven)
	frame.CanCollide = false
	oven.Handle.Color = STEEL

	part("Backsplash", Vector3.new(9.2, 2.6, 0.4), at(0, 5.6, -2.4), CREAM, nil, oven)
	part("BacksplashTrim", Vector3.new(9.25, 0.4, 0.45), at(0, 6.7, -2.4), PINK, nil, oven)
	part("Hood", Vector3.new(8, 1.4, 4.2), at(0, 8.4, -0.4), CREAM, nil, oven)
	local chimney = oven.Chimney
	chimney.Size = Vector3.new(1.6, 3, 1.6)
	chimney.CFrame = at(0, 10.6, -0.5)
	chimney.Color = STEEL
	chimney.Material = Enum.Material.Metal
end
