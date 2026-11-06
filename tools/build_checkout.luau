-- Edit-time builder: shrinks every plot's checkout counter to the size of the delivery
-- counter, moves the cake decoration to one end, and builds a retro cash register at the
-- other. Safe to run again: sizes and spots are set from the counter's centre, and the
-- register is rebuilt from scratch.
-- Customers pay on the +Z side. The cashier stands on the -Z (kitchen) side, so the keys,
-- drawer and cashier display face that way, and a second display faces the customers.

-- The same base and top as the delivery counter, so the counters match.
local BASE_SIZE = Vector3.new(8, 3.4, 3)
local TOP_SIZE = Vector3.new(8.6, 0.4, 3.6)
-- Along the counter from its centre.
local REGISTER_X = 2.2
local CAKE_X = -2.4

local CREAM = Color3.fromRGB(255, 245, 230)
local PINK = Color3.fromRGB(240, 150, 175)
local DEEP_PINK = Color3.fromRGB(215, 105, 140)
local SILVER = Color3.fromRGB(205, 205, 215)
local SCREEN = Color3.fromRGB(170, 230, 200)
local SCREEN_TEXT = Color3.fromRGB(35, 85, 60)
local KEY_GREEN = Color3.fromRGB(110, 195, 125)
local KEY_RED = Color3.fromRGB(225, 95, 95)
local PAPER = Color3.fromRGB(255, 255, 255)
local DARK = Color3.fromRGB(70, 55, 65)

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

-- A small LCD on a part's face, with text in a digital font.
local function display(name, cframe, face, text, parent)
	local screen = part(name, Vector3.new(1.2, 0.36, 0.04), cframe, SCREEN, Enum.Material.Neon, parent)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(240, 72)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.TextColor3 = SCREEN_TEXT
	label.Text = text
	label.Parent = gui
	gui.Parent = screen
	return screen
end

for _, plot in workspace.Plots:GetChildren() do
	local checkout = plot.Checkout
	local base, top = checkout.CounterBase, checkout.CounterTop
	base.Size = BASE_SIZE
	top.Size = TOP_SIZE

	-- The cake keeps its height and turn, and moves along the counter to one end.
	for _, name in { "CakeBase", "CakeIcing", "Cherry" } do
		local cakePart = checkout[name]
		local offset = top.CFrame:ToObjectSpace(cakePart.CFrame)
		cakePart.CFrame = top.CFrame * CFrame.new(CAKE_X, offset.Y, offset.Z) * offset.Rotation
	end

	local oldRegister = checkout:FindFirstChild("Register")
	if oldRegister then
		oldRegister:Destroy()
	end
	local register = Instance.new("Model")
	register.Name = "Register"
	-- On the counter's top surface, at the register's centre.
	local at = top.CFrame * CFrame.new(REGISTER_X, top.Size.Y / 2, 0)

	-- The cash drawer along the bottom, with a silver handle.
	part("DrawerBox", Vector3.new(2.8, 0.7, 2.4), at * CFrame.new(0, 0.35, 0), CREAM, nil, register)
	part("Drawer", Vector3.new(2.5, 0.45, 0.08), at * CFrame.new(0, 0.35, -1.22), DEEP_PINK, nil, register)
	part("Handle", Vector3.new(0.8, 0.12, 0.12), at * CFrame.new(0, 0.38, -1.3), SILVER, Enum.Material.Metal, register)

	-- The body behind the keys.
	part("Body", Vector3.new(2.6, 0.9, 1.3), at * CFrame.new(0, 1.15, 0.5), PINK, nil, register)
	part("Trim", Vector3.new(2.7, 0.1, 1.4), at * CFrame.new(0, 1.62, 0.5), CREAM, nil, register)

	-- The key deck slopes down toward the cashier. A wedge's sloped face points to -Z.
	local deckSize = Vector3.new(2.6, 0.55, 1.2)
	local deck = Instance.new("WedgePart")
	deck.Name = "KeyDeck"
	deck.Anchored = true
	deck.CanCollide = false
	deck.Size = deckSize
	deck.CFrame = at * CFrame.new(0, 0.7 + deckSize.Y / 2, -0.6)
	deck.Color = PINK
	deck.Material = Enum.Material.SmoothPlastic
	deck.Parent = register
	-- The slope's own frame: its up is the slope's face and its Z runs down and up the slope.
	local slope = deck.CFrame * CFrame.Angles(-math.atan2(deckSize.Y, deckSize.Z), 0, 0)
	-- Round keys stand out of the slope: four columns of three, with a few in pink.
	for column, x in { -1.0, -0.55, -0.1, 0.35 } do
		for row, z in { -0.4, 0, 0.4 } do
			local color = (column + row) % 4 == 0 and DEEP_PINK or CREAM
			local key = part("Key", Vector3.new(0.12, 0.3, 0.3), slope * CFrame.new(x, 0.06, z) * CFrame.Angles(0, 0, math.rad(90)), color, nil, register)
			key.Shape = Enum.PartType.Cylinder
		end
	end
	part("EnterKey", Vector3.new(0.4, 0.12, 0.7), slope * CFrame.new(0.9, 0.06, -0.2), KEY_GREEN, nil, register)
	local clear = part("ClearKey", Vector3.new(0.12, 0.3, 0.3), slope * CFrame.new(0.9, 0.06, 0.4) * CFrame.Angles(0, 0, math.rad(90)), KEY_RED, nil, register)
	clear.Shape = Enum.PartType.Cylinder

	-- A pop-up display on a post, with one screen for the cashier and one for customers.
	part("DisplayPost", Vector3.new(0.25, 0.45, 0.25), at * CFrame.new(-0.4, 1.9, 0.5), SILVER, Enum.Material.Metal, register)
	local box = part("DisplayBox", Vector3.new(1.45, 0.55, 0.36), at * CFrame.new(-0.4, 2.4, 0.5), DARK, nil, register)
	display("CashierDisplay", box.CFrame * CFrame.new(0, 0, -0.19), Enum.NormalId.Front, "TOTAL 12", register)
	display("CustomerDisplay", box.CFrame * CFrame.new(0, 0, 0.19), Enum.NormalId.Back, "THANK YOU!", register)

	-- A receipt printer with paper curling out toward the cashier.
	part("Printer", Vector3.new(0.6, 0.3, 0.6), at * CFrame.new(0.85, 1.82, 0.6), CREAM, nil, register)
	part("PrinterSlot", Vector3.new(0.45, 0.04, 0.08), at * CFrame.new(0.85, 1.98, 0.4), DARK, nil, register)
	part("Paper", Vector3.new(0.4, 0.5, 0.02), at * CFrame.new(0.85, 2.2, 0.36) * CFrame.Angles(math.rad(-25), 0, 0), PAPER, nil, register)

	-- The crank handle on the side, like an old-fashioned register.
	part("CrankArm", Vector3.new(0.12, 0.6, 0.12), at * CFrame.new(1.47, 1.1, 0.5), SILVER, Enum.Material.Metal, register)
	local knob = part("CrankKnob", Vector3.new(0.28, 0.28, 0.28), at * CFrame.new(1.47, 1.45, 0.5), DEEP_PINK, nil, register)
	knob.Shape = Enum.PartType.Ball

	register.Parent = checkout
end
