-- Edit-time builder for free placement decorating. Safe to run again. In each bakery it:
-- removes the 16 decoration squares and the countertop display case (everyone gets a
-- free floor-standing case instead), groups the checkout counter into a Checkout model
-- with a cash register where the case was, groups the packing table and belt into a
-- PackingStation model, and moves the player spawn just inside the door, which is
-- always kept clear.

local CREAM = Color3.fromRGB(255, 245, 230)
local PINK = Color3.fromRGB(240, 150, 175)
local DARK = Color3.fromRGB(70, 55, 65)
local SCREEN = Color3.fromRGB(170, 230, 200)

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

local function group(plot, name, partNames)
	local model = plot:FindFirstChild(name)
	if not model then
		model = Instance.new("Model")
		model.Name = name
		for _, partName in partNames do
			plot[partName].Parent = model
		end
		model.Parent = plot
	end
	return model
end

for _, plot in workspace.Plots:GetChildren() do
	local floor = plot.Floor
	for _, name in { "DecorSpots", "DisplayCase" } do
		local old = plot:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local payMarker = plot.Spots:FindFirstChild("CustomerCounter")
	if payMarker then
		payMarker:Destroy()
	end

	local checkout = group(plot, "Checkout", { "CounterBase", "CounterTop", "CakeBase", "CakeIcing", "Cherry" })
	local oldRegister = checkout:FindFirstChild("Register")
	if oldRegister then
		oldRegister:Destroy()
	end
	-- The cashier stands on the kitchen side (-Z), so the screen and drawer face that way.
	local top = checkout.CounterTop
	local base = top.CFrame * CFrame.new(4.5, top.Size.Y / 2, 0)
	local register = Instance.new("Model")
	register.Name = "Register"
	part("Body", Vector3.new(2.4, 1, 1.8), base * CFrame.new(0, 0.5, 0), CREAM, nil, register)
	part("Trim", Vector3.new(2.5, 0.15, 1.9), base * CFrame.new(0, 1.05, 0), PINK, nil, register)
	part("Drawer", Vector3.new(2, 0.35, 0.1), base * CFrame.new(0, 0.35, -0.92), PINK, nil, register)
	local screenCFrame = base * CFrame.new(0, 1.65, -0.35) * CFrame.Angles(math.rad(-15), 0, 0)
	part("Screen", Vector3.new(1.6, 0.9, 0.15), screenCFrame, DARK, nil, register)
	part("Display", Vector3.new(1.35, 0.65, 0.05), screenCFrame * CFrame.new(0, 0, -0.08), SCREEN, Enum.Material.Neon, register)
	register.Parent = checkout

	group(plot, "PackingStation", { "PackingTable", "PackingBelt" })

	plot.Spots.PlayerSpawn.CFrame = floor.CFrame * CFrame.new(0, 0.6, 16)
end
