-- Edit-time builder for free placement decorating. Safe to run again. In each bakery it:
-- removes the 16 decoration squares and the countertop display case (everyone gets a
-- free floor-standing case instead), groups the checkout counter into a Checkout model
-- with a cash register where the case was, rebuilds the delivery station as a
-- PackingStation counter with a laptop (removing the hatch and board on the back wall,
-- which couldn't move with it), and moves the player spawn just inside the door, which
-- is always kept clear.

local CREAM = Color3.fromRGB(255, 245, 230)
local PINK = Color3.fromRGB(240, 150, 175)
local DARK = Color3.fromRGB(70, 55, 65)
local SCREEN = Color3.fromRGB(170, 230, 200)
-- The same wood and marble as the checkout counter.
local COUNTER_WOOD = Color3.fromRGB(190, 130, 95)
local COUNTER_MARBLE = Color3.fromRGB(255, 250, 245)
local LAPTOP = Color3.fromRGB(75, 75, 88)
local KEYS = Color3.fromRGB(40, 40, 48)
local LAPTOP_SCREEN = Color3.fromRGB(205, 232, 255)
-- The delivery counter stands against the back wall where the old packing table was.
local PACKING_X = 17
local PACKING_Z = -17.2

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

	local packing = group(plot, "PackingStation", { "PackingTable", "PackingBelt" })
	for _, name in { "Hatch", "DeliveryBoard" } do
		local wallPart = plot:FindFirstChild(name)
		if wallPart then
			wallPart:Destroy()
		end
	end
	for _, name in { "PackingBelt", "Top", "Laptop" } do
		local old = packing:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	-- The table part keeps its name and its Pack Delivery prompt, and becomes the
	-- counter's wooden base.
	local floorTop = floor.CFrame * CFrame.new(PACKING_X, floor.Size.Y / 2, PACKING_Z)
	local counter = packing.PackingTable
	counter.Size = Vector3.new(8, 3.4, 3)
	counter.CFrame = floorTop * CFrame.new(0, 1.7, 0)
	counter.Color = COUNTER_WOOD
	counter.Material = Enum.Material.Wood
	local top = part("Top", Vector3.new(8.6, 0.4, 3.6), floorTop * CFrame.new(0, 3.6, 0), COUNTER_MARBLE, Enum.Material.Marble, packing)
	top.CanCollide = true

	-- The laptop faces the player, who stands on the +Z side. Its screen hinges at the back.
	local laptopBase = floorTop * CFrame.new(0.8, 3.8, 0)
	local laptop = Instance.new("Model")
	laptop.Name = "Laptop"
	part("Base", Vector3.new(2.4, 0.12, 1.7), laptopBase * CFrame.new(0, 0.06, 0), LAPTOP, nil, laptop)
	part("Keys", Vector3.new(2.1, 0.02, 0.85), laptopBase * CFrame.new(0, 0.13, 0.3), KEYS, nil, laptop)
	local screenCFrame = laptopBase * CFrame.new(0, 0.12, -0.8) * CFrame.Angles(math.rad(-15), 0, 0) * CFrame.new(0, 0.8, 0)
	part("Screen", Vector3.new(2.4, 1.6, 0.1), screenCFrame, LAPTOP, nil, laptop)
	local display = part("Display", Vector3.new(2.15, 1.35, 0.02), screenCFrame * CFrame.new(0, 0, 0.06), LAPTOP_SCREEN, Enum.Material.Neon, laptop)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(215, 135)
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(90, 60, 110)
	text.Text = "Deliveries"
	text.Parent = gui
	gui.Parent = display
	laptop.Parent = packing

	plot.Spots.PlayerSpawn.CFrame = floor.CFrame * CFrame.new(0, 0.6, 16)
end
