-- Edit-time builder: makes the looks of the people on the plaza. Each look is a real Roblox
-- R15 avatar dressed in free Roblox-made hair and clothes, kept in
-- ServerStorage.TownsfolkLooks: People holds the townsfolk and customers, and Helpers holds
-- the Baker and the Stocker. BakerySystem clones a look for each person.
-- Safe to run again: it rebuilds the folder from scratch with the same seed, so the same
-- looks come out.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local SEED = 2026
local LOOK_COUNT = 36

local HAIR = {
	62234425, -- Brown Hair
	63690008, -- Pal Hair
	376524487, -- Blonde Spiked Hair
	376526888, -- Straight Blonde Hair
	376548738, -- Brown Charmer Hair
	451221329, -- True Blue Hair
	1103003368, -- Orange Beanie with Black Hair
	2956239660, -- Belle Of Belfast Long Red Hair
	6993758617, -- Short and Sleek - Brown
	7193397693, -- Short Fringe - Blonde
	7193401217, -- Short Fringe - Black
	7193452166, -- Short Curls - Black
	7193454569, -- Braided Hair - Black
	7193455510, -- Braided Hair - Red
	9174354743, -- Top Knot - Black
	9243976603, -- Short Fringe - Brown
	9243983205, -- Short Fringe - Red
	9243987340, -- Short and Sleek - Blonde
	9243992729, -- Short and Sleek - Black
	9244057408, -- Top Knot - Blonde
	9244060144, -- Top Knot - Brown
	9244134513, -- Short Curls - Blonde
	9244137452, -- Short Curls - Cool Brown
	9244145658, -- Short Curls - Red
	9244148336, -- Braided Hair - Blonde
	9244150641, -- Braided Hair - Cool Brown
}
-- Classic shirts and pants, drawn on the body.
local SHIRTS = {
	144076358, -- Blue and Black Motorcycle Shirt
	144076436, -- Grey Striped Shirt with Denim Jacket
	382537085, -- I <3 Pizza Shirt
	382537702, -- Teal Shirt
	382538295, -- Guitar Tee with Black Jacket
	398633584, -- Denim Jacket with White Hoodie
	398634295, -- Pastel Starburst Top with Gray Jacket
	398635081, -- Blue Plaid Shirt
	3670737444, -- Roblox Shirt - Simple Pattern
	4047884939, -- My Favorite Pizza Shirt
	4047886060, -- Purple and Teal Top
}
local PANTS = {
	144076760, -- Dark Green Jeans
	382537569, -- Black Jeans
	382537806, -- Jean Shorts
	382537950, -- Jean Shorts with White Shoes
	382538503, -- Black Jeans with Sneakers
	398633812, -- Black Jeans with White Shoes
	398634487, -- Beautiful You Jeans
	398635338, -- Ripped Skater Pants
}
-- 3D clothes worn over the classic ones. Phones have to fit them to the body, so only a
-- few looks get one.
local LAYERED_TOPS = {
	{ 9112474888, Enum.AccessoryType.TShirt }, -- Basic T-Shirt - Gray
	{ 9112483644, Enum.AccessoryType.TShirt }, -- Striped T-Shirt - White
	{ 9240752338, Enum.AccessoryType.Shirt }, -- Tie-Front Top - White
	{ 6984769289, Enum.AccessoryType.Sweater }, -- Knit Sweater - Beige
	{ 9240758221, Enum.AccessoryType.Sweater }, -- Knit Sweater - Gray
	{ 8516609675, Enum.AccessoryType.Jacket }, -- Denim Jacket - Light Wash
	{ 8516620262, Enum.AccessoryType.Jacket }, -- Hooded Jacket - Gray
}
local LAYERED_BOTTOMS = {
	{ 9240776381, Enum.AccessoryType.DressSkirt }, -- Long Ruffle Skirt - White
	{ 6984740059, Enum.AccessoryType.Pants }, -- Cargo Pants - Brown
	{ 9174391966, Enum.AccessoryType.Shorts }, -- Bermuda Shorts - Black
}
local CAPS = {
	48474313, -- Red Roblox Cap
	607702162, -- Roblox Baseball Cap
}
local LAYERED_TOP_CHANCE = 0.25
local LAYERED_BOTTOM_CHANCE = 0.2
local CAP_CHANCE = 0.1

local SKIN_COLORS = {
	Color3.fromRGB(255, 224, 196),
	Color3.fromRGB(245, 205, 165),
	Color3.fromRGB(225, 175, 130),
	Color3.fromRGB(190, 135, 95),
	Color3.fromRGB(150, 100, 70),
	Color3.fromRGB(105, 70, 50),
}

local WHITE = Color3.fromRGB(255, 255, 255)
local PINK = Color3.fromRGB(240, 150, 175)

local random = Random.new(SEED)

local function pick(list)
	return list[random:NextInteger(1, #list)]
end

local function describe(skin, hair, shirt, pants, accessories)
	local description = Instance.new("HumanoidDescription")
	for _, field in { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" } do
		description[field] = skin
	end
	description.Shirt = shirt or 0
	description.Pants = pants or 0
	local list = { { AssetId = hair, AccessoryType = Enum.AccessoryType.Hair } }
	for order, accessory in accessories do
		table.insert(list, { AssetId = accessory[1], AccessoryType = accessory[2], IsLayered = accessory[3], Order = order })
	end
	description:SetAccessories(list, true)
	return description
end

-- A part fixed to a body part, for the helpers' hats and aprons.
local function attach(model, bodyPartName, name, size, offset, color, shape)
	local bodyPart = model[bodyPartName]
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.CFrame = bodyPart.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bodyPart
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

-- Builds a look from a description and gets it ready to be moved by tweening its root:
-- the root is anchored, nothing collides, and the Humanoid shows no name or health and
-- runs no physics states of its own. The client plays its walk and idle animations.
local function build(name, description, dress)
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = name
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.EvaluateStateMachine = false
	model:PivotTo(CFrame.new(0, 3, 0))
	if dress then
		dress(model)
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
		end
	end
	local root = model.HumanoidRootPart
	root.Anchored = true
	root.Massless = false
	model.PrimaryPart = root
	return model
end

local old = ServerStorage:FindFirstChild("TownsfolkLooks")
if old then
	old:Destroy()
end
local looks = Instance.new("Folder")
looks.Name = "TownsfolkLooks"
local people = Instance.new("Folder")
people.Name = "People"
people.Parent = looks
local helpers = Instance.new("Folder")
helpers.Name = "Helpers"
helpers.Parent = looks

local failed = {}
for index = 1, LOOK_COUNT do
	local accessories = {}
	if random:NextNumber() < LAYERED_TOP_CHANCE then
		local top = pick(LAYERED_TOPS)
		table.insert(accessories, { top[1], top[2], true })
	end
	if random:NextNumber() < LAYERED_BOTTOM_CHANCE then
		local bottom = pick(LAYERED_BOTTOMS)
		table.insert(accessories, { bottom[1], bottom[2], true })
	end
	if random:NextNumber() < CAP_CHANCE then
		table.insert(accessories, { pick(CAPS), Enum.AccessoryType.Hat, false })
	end
	local description = describe(pick(SKIN_COLORS), pick(HAIR), pick(SHIRTS), pick(PANTS), accessories)
	local name = ("Look%02d"):format(index)
	local ok, model = pcall(build, name, description)
	if ok then
		model.Parent = people
	else
		table.insert(failed, name .. ": " .. tostring(model))
	end
	task.wait()
end

-- The Baker wears a white tee, a pink apron and a chef's hat. The Stocker wears a striped
-- tee, the same apron and a pink cap.
local function apron(model)
	attach(model, "UpperTorso", "ApronBib", Vector3.new(1.3, 1, 0.08), CFrame.new(0, -0.2, -0.62), PINK)
	attach(model, "LowerTorso", "ApronSkirt", Vector3.new(1.7, 1.3, 0.08), CFrame.new(0, -0.35, -0.6), PINK)
end
local helperLooks = {
	Baker = {
		description = describe(SKIN_COLORS[3], 6993758617, nil, 382537569, {
			{ 7178737816, Enum.AccessoryType.TShirt, true }, -- Roblox T-Shirt - White
		}),
		dress = function(model)
			apron(model)
			attach(model, "Head", "HatBand", Vector3.new(0.5, 1.25, 1.25), CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, math.rad(90)), WHITE, Enum.PartType.Cylinder)
			attach(model, "Head", "HatPuff", Vector3.new(1.55, 0.9, 1.55), CFrame.new(0, 1.2, 0), WHITE, Enum.PartType.Ball)
		end,
	},
	Stocker = {
		description = describe(SKIN_COLORS[2], 9244134513, nil, 144076760, {
			{ 9112483644, Enum.AccessoryType.TShirt, true }, -- Striped T-Shirt - White
		}),
		dress = function(model)
			apron(model)
			attach(model, "Head", "CapCrown", Vector3.new(0.45, 1.25, 1.25), CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)), PINK, Enum.PartType.Cylinder)
			attach(model, "Head", "CapBrim", Vector3.new(0.9, 0.08, 0.6), CFrame.new(0, 0.45, -0.75), PINK)
		end,
	},
}
for name, look in helperLooks do
	local ok, model = pcall(build, name, look.description, look.dress)
	if ok then
		model.Parent = helpers
	else
		table.insert(failed, name .. ": " .. tostring(model))
	end
	task.wait()
end

looks.Parent = ServerStorage

-- How high the root sits above the soles, which BakerySystem's CUSTOMER_HEIGHT should match.
local sample = people:GetChildren()[1]
local soles = math.huge
for _, part in sample:GetChildren() do
	if part:IsA("BasePart") and part.Name:find("Foot") then
		soles = math.min(soles, part.Position.Y - part.Size.Y / 2)
	end
end
print(("Built %d people and %d helpers. Root height %.3f"):format(#people:GetChildren(), #helpers:GetChildren(), sample.HumanoidRootPart.Position.Y - soles))
for _, line in failed do
	warn("Failed " .. line)
end
