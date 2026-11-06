-- Edit-time builder: adds a LuxuryOven to each bakery, a copy of the regular oven in
-- black enamel and gold with a "Luxury" plaque on the hood. Safe to run again: it
-- replaces the copy. It keeps the oven's part names (Body with its Prompt and Status,
-- Window, Burners, Chimney with its Smoke), which BakerySystem uses. The server hides it
-- until the owner buys it, and it starts beside the regular oven.

local ENAMEL = Color3.fromRGB(40, 32, 48)
local GOLD = Color3.fromRGB(230, 185, 70)
local GOLD_PARTS = { "Trim", "BacksplashTrim", "Handle", "DoorFrame", "Chimney", "Knob" }
-- The control panel stays dark so the gold knobs stand out on it.
local ENAMEL_PARTS = { "Body", "Hood", "Backsplash", "Panel" }
-- How far along the back wall it sits from the regular oven, in floor space.
local OFFSET_X = -9

for _, plot in workspace.Plots:GetChildren() do
	local old = plot:FindFirstChild("LuxuryOven")
	if old then
		old:Destroy()
	end
	local floor = plot.Floor
	local oven = plot.Oven:Clone()
	oven.Name = "LuxuryOven"
	local pivot = oven:GetPivot()
	local shift = floor.CFrame:VectorToWorldSpace(Vector3.new(OFFSET_X, 0, 0))
	oven:PivotTo(pivot + shift)

	for _, part in oven:GetDescendants() do
		if part:IsA("BasePart") then
			if table.find(GOLD_PARTS, part.Name) then
				part.Color = GOLD
				part.Material = Enum.Material.Foil
			elseif table.find(ENAMEL_PARTS, part.Name) then
				part.Color = ENAMEL
				part.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	oven.Body.Prompt.ObjectText = "Luxury Oven"

	local hood = oven.Hood
	local plaque = Instance.new("Part")
	plaque.Name = "Plaque"
	plaque.Anchored = true
	plaque.CanCollide = false
	plaque.Size = Vector3.new(3.4, 0.9, 0.1)
	plaque.CFrame = hood.CFrame * CFrame.new(0, 0, hood.Size.Z / 2 + 0.05)
	plaque.Color = GOLD
	plaque.Material = Enum.Material.Foil
	plaque.TopSurface = Enum.SurfaceType.Smooth
	plaque.BottomSurface = Enum.SurfaceType.Smooth
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(340, 90)
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = ENAMEL
	text.Text = "Luxury"
	text.Parent = gui
	gui.Parent = plaque
	plaque.Parent = oven

	oven.Parent = plot
end
