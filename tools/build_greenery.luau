-- Edit-time builder: a spring park around the plaza. The baseplate becomes a grass lawn, and
-- workspace.Town.Greenery gets round planters with a tree on the plaza, flower beds along its
-- rim, pots by the benches, baskets on the lamps, and trees, bushes and flower patches out
-- on the lawn, thinning into a ring of trees past the edge of town. Cherry trees drop petals.
-- Run it after build_town, which rebuilds the whole Town folder. Safe to run again: it
-- rebuilds Greenery from a fixed seed, so the same park comes out.
--
-- Nothing goes where a bakery could grow to (its largest expansion), in front of a bakery
-- or the grocery store (their paths, crates and the flyer stand), on the townsfolk's ways in
-- and out of town, or on their spots on the plaza. setUpTown in BakerySystem works those
-- out the same way.

local Layout = require(game.ReplicatedStorage.Layout)

local SEED = 515

local BARK = Color3.fromRGB(125, 88, 64)
local CHERRY_BARK = Color3.fromRGB(105, 72, 62)
local LEAVES = { Color3.fromRGB(104, 178, 98), Color3.fromRGB(88, 160, 90), Color3.fromRGB(132, 196, 112) }
local BLOSSOMS = { Color3.fromRGB(255, 168, 200), Color3.fromRGB(255, 140, 182), Color3.fromRGB(255, 200, 222) }
local FLOWERS = {
	Color3.fromRGB(255, 168, 198), -- pink
	Color3.fromRGB(255, 250, 244), -- white
	Color3.fromRGB(255, 226, 122), -- butter yellow
	Color3.fromRGB(200, 172, 240), -- lavender
	Color3.fromRGB(255, 150, 140), -- coral
}
local BED = Color3.fromRGB(78, 148, 82)
local MARBLE = Color3.fromRGB(242, 236, 230)
local PINK = Color3.fromRGB(240, 182, 200)
local STONE = Color3.fromRGB(205, 200, 210)
local TERRACOTTA = Color3.fromRGB(206, 122, 92)
local WICKER = Color3.fromRGB(176, 128, 82)
local LAWN = Color3.fromRGB(128, 190, 104)
local PETAL = "rbxassetid://74180373620457"
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X, so stand them up

-- How far bakeries and the grocery store keep clear around them, in their own floor's frame
-- (+Z faces the plaza). Bakeries use their largest expansion, walls included.
local largest = Layout.Largest
local BAKERY_BOX = { MinX = largest.MinX - 4, MaxX = largest.MaxX + 4, MinZ = largest.MinZ - 4, MaxZ = largest.MaxZ + 4 }
local BAKERY_FRONT_HALF = 14 -- the path, the crate at x 9 and the flyer stand at x -9
local GROCERY_BOX = { MinX = -23, MaxX = 23, MinZ = -18, MaxZ = 22 }
local GROCERY_FRONT_HALF = 12
local WAY_HALF = 7 -- each side of the townsfolk's ways in and out of town
local WAY_END = 185 -- past where they appear and disappear
local OUTER = 240 -- how far out the lawn is planted

local town = workspace.Town
local plaza = town.Plaza
local center = plaza.Position * Vector3.new(1, 0, 1)
local PLAZA_RADIUS = plaza.Size.Y / 2
local PLAZA_TOP = plaza.Position.Y + plaza.Size.X / 2
local baseplate = workspace.Baseplate
local LAWN_TOP = baseplate.Position.Y + baseplate.Size.Y / 2
local RIM_RADIUS = town.PlazaRim.Size.Y / 2

local random = Random.new(SEED)

baseplate.Material = Enum.Material.Grass
baseplate.Color = LAWN

local old = town:FindFirstChild("Greenery")
if old then
	old:Destroy()
end
-- The ball-on-a-stick trees that older versions of build_town made.
for _, child in town:GetChildren() do
	if child.Name == "Tree" then
		child:Destroy()
	end
end
local greenery = Instance.new("Folder")
greenery.Name = "Greenery"

local function part(name, size, cframe, color, material, parent, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- Small or leafy pieces nobody needs to bump into.
local function soft(p, shadow)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = shadow == true
	return p
end

local function model(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = greenery
	return m
end

local function flat(position)
	return Vector3.new(position.X, 0, position.Z)
end

local function direction(radians)
	return Vector3.new(math.cos(radians), 0, math.sin(radians))
end

local function pick(list)
	return list[random:NextInteger(1, #list)]
end

-- Keep-clear zones

local function outsideBox(cframe, box, position, radius)
	local p = cframe:PointToObjectSpace(position)
	return p.X < box.MinX - radius or p.X > box.MaxX + radius or p.Z < box.MinZ - radius or p.Z > box.MaxZ + radius
end

-- Each building: its floor, the box it can fill, how wide the clear strip in front is, and
-- where that strip reaches the plaza.
local buildings = {}
local angles = {}
for _, plot in workspace.Plots:GetChildren() do
	local floor = plot:FindFirstChild("Floor")
	if floor then
		local reach = flat(floor.Position - center).Magnitude
		table.insert(buildings, { cframe = floor.CFrame, box = BAKERY_BOX, front = BAKERY_FRONT_HALF, reach = reach })
		local offset = floor.Position - center
		table.insert(angles, math.atan2(offset.Z, offset.X))
	end
end
local grocery = workspace:FindFirstChild("GroceryStore")
if grocery then
	local floor = grocery.Floor
	local reach = flat(floor.Position - center).Magnitude
	table.insert(buildings, { cframe = floor.CFrame, box = GROCERY_BOX, front = GROCERY_FRONT_HALF, reach = reach })
	local offset = grocery:GetPivot().Position - center
	table.insert(angles, math.atan2(offset.Z, offset.X))
end

-- The townsfolk's ways in and out: from the plaza out through each gap between buildings,
-- 5 degrees to one side of the gap's middle, as in setUpTown. gaps keeps each gap's middle.
table.sort(angles)
local ways, gaps = {}, {}
for index, angle in angles do
	local gap = (angles[index % #angles + 1] - angle) % (2 * math.pi)
	table.insert(gaps, { middle = angle + gap / 2, width = gap })
	table.insert(ways, direction(angle + gap / 2 + math.rad(5)))
end

-- Spots the townsfolk stand at on the plaza, as in setUpTown.
local strolls = {}
local fountainRadius = town.Fountain.Basin.Size.Y / 2
for step = 0, 7 do
	table.insert(strolls, center + direction(math.rad(step * 45 + 22.5)) * (fountainRadius + 4))
end
for step = 0, 9 do
	table.insert(strolls, center + direction(math.rad(step * 36)) * PLAZA_RADIUS * 0.57)
end
local benches, lamps = {}, {}
for _, child in town:GetChildren() do
	if child.Name == "Bench" then
		table.insert(benches, child)
		local position = flat(child:GetPivot().Position)
		table.insert(strolls, position + (center - position).Unit * 2.5)
	elseif child.Name == "Lamp" then
		table.insert(lamps, child)
	end
end
local spawn = workspace:FindFirstChild("SpawnLocation")

local placed = {}

-- Whether a plant of this radius fits here. Plants on the lawn also keep off the plaza and
-- its flower beds (lawn = true).
local function isClear(position, radius, lawn)
	position = flat(position)
	local fromCenter = (position - center).Magnitude
	if lawn and fromCenter < RIM_RADIUS + 5 + radius then
		return false
	end
	if fromCenter < fountainRadius + 6 + radius then
		return false
	end
	for _, building in buildings do
		if not outsideBox(building.cframe, building.box, position, radius) then
			return false
		end
		local front = { MinX = -building.front, MaxX = building.front, MinZ = 0, MaxZ = building.reach - PLAZA_RADIUS + 2 }
		if not outsideBox(building.cframe, front, position, radius) then
			return false
		end
	end
	for _, way in ways do
		local along = (position - center):Dot(way)
		if along > 0 and along < WAY_END and (position - center - way * along).Magnitude < WAY_HALF + radius then
			return false
		end
	end
	for _, spot in strolls do
		if (position - flat(spot)).Magnitude < 3 + radius then
			return false
		end
	end
	for _, bench in benches do
		if (position - flat(bench:GetPivot().Position)).Magnitude < 4.5 + radius then
			return false
		end
	end
	for _, lamp in lamps do
		if (position - flat(lamp:GetPivot().Position)).Magnitude < 1.5 + radius then
			return false
		end
	end
	if spawn and (position - flat(spawn.Position)).Magnitude < 6 + radius then
		return false
	end
	for _, other in placed do
		if (position - other.position).Magnitude < other.radius + radius + 1 then
			return false
		end
	end
	return true
end

local function claim(position, radius)
	table.insert(placed, { position = flat(position), radius = radius })
end

-- Plants. Each takes a CFrame on the ground, turned any way, and a scale.

local function flower(parent, position, size)
	local bloom = part("Flower", Vector3.new(size, size * 0.55, size), CFrame.new(position) * CFrame.Angles(0, random:NextNumber() * math.pi, 0), pick(FLOWERS), Enum.Material.SmoothPlastic, parent, Enum.PartType.Ball)
	soft(bloom)
end

local function greenTree(ground, scale)
	local tree = model("Tree")
	local height = 6 * scale
	part("Trunk", Vector3.new(height, 1.2 * scale, 1.2 * scale), ground * CFrame.new(0, height / 2, 0) * UPRIGHT, BARK, Enum.Material.Wood, tree, Enum.PartType.Cylinder)
	for _, ball in {
		{ Vector3.new(0, 2.4, 0), 8 },
		{ Vector3.new(1.9, 3.6, 0.9), 6 },
		{ Vector3.new(-1.7, 3.2, -1), 6.2 },
		{ Vector3.new(0.3, 5.2, -0.4), 5 },
	} do
		local size = ball[2] * scale
		soft(part("Leaves", Vector3.new(size, size, size), ground * CFrame.new(Vector3.new(0, height, 0) + ball[1] * scale), pick(LEAVES), Enum.Material.LeafyGrass, tree, Enum.PartType.Ball), true)
	end
	return tree
end

-- A leaning trunk, two branches and a cloud of pink blossom. With petals, an invisible box
-- under the blossom lets petals drift down.
local function cherryTree(ground, scale, petals)
	local tree = model("CherryTree")
	local height = 5 * scale
	local lean = ground * CFrame.Angles(0, 0, math.rad(5))
	part("Trunk", Vector3.new(height, 1 * scale, 1 * scale), lean * CFrame.new(0, height / 2, 0) * UPRIGHT, CHERRY_BARK, Enum.Material.Wood, tree, Enum.PartType.Cylinder)
	local top = lean * CFrame.new(0, height, 0)
	for _, side in { -1, 1 } do
		local branch = 3 * scale
		part("Branch", Vector3.new(branch, 0.45 * scale, 0.45 * scale), top * CFrame.new(0, -0.8 * scale, 0) * CFrame.Angles(0, side * math.rad(70), 0) * CFrame.Angles(0, 0, math.rad(40)) * CFrame.new(branch / 2, 0, 0), CHERRY_BARK, Enum.Material.Wood, tree, Enum.PartType.Cylinder)
	end
	for index = 1, 7 do
		local angle = index * 2 * math.pi / 7 + random:NextNumber() * 0.5
		local out = index == 7 and 0 or random:NextNumber(1.6, 2.8)
		local offset = Vector3.new(math.cos(angle) * out, random:NextNumber(0.6, 2.4) + (index == 7 and 1.2 or 0), math.sin(angle) * out) * scale
		local size = random:NextNumber(3.6, 5.2) * scale
		soft(part("Blossom", Vector3.new(size, size * 0.85, size), top * CFrame.new(offset), pick(BLOSSOMS), Enum.Material.LeafyGrass, tree, Enum.PartType.Ball), true)
	end
	if petals then
		local box = soft(part("Petals", Vector3.new(6 * scale, 0.5, 6 * scale), top * CFrame.new(0, 0.6 * scale, 0), BLOSSOMS[1], Enum.Material.SmoothPlastic, tree))
		box.Transparency = 1
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = PETAL
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 196, 214))
		emitter.LightInfluence = 1
		emitter.Size = NumberSequence.new(0.3)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.85, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.Speed = NumberRange.new(0.5, 1.2)
		emitter.SpreadAngle = Vector2.new(50, 50)
		emitter.Acceleration = Vector3.new(0.5, -1.6, 0.3)
		emitter.Drag = 0.6
		emitter.Lifetime = NumberRange.new(3.5, 5)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-120, 120)
		emitter.Rate = 1.5
		emitter.Parent = box
	end
	return tree
end

local function bush(ground, scale, blooms, parent)
	local shrub = parent or model("Bush")
	local balls = random:NextInteger(2, 3)
	for index = 1, balls do
		local size = random:NextNumber(2.2, 3.2) * scale
		local offset = Vector3.new((index - 2) * 0.9, size * 0.38, random:NextNumber(-0.5, 0.5)) * Vector3.new(scale, 1, scale)
		local ball = part("Leaves", Vector3.new(size, size * 0.85, size), ground * CFrame.new(offset), pick(LEAVES), Enum.Material.LeafyGrass, shrub, Enum.PartType.Ball)
		ball.CanQuery = false
		ball.CastShadow = scale > 0.7
		if blooms then
			for _ = 1, 2 do
				local up = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(0.4, 1), random:NextNumber(-1, 1)).Unit
				flower(shrub, ball.Position + up * Vector3.new(size, size * 0.85, size) * 0.47, 0.5 * scale + 0.15)
			end
		end
	end
	return shrub
end

local function flowerPatch(ground)
	local patch = model("FlowerPatch")
	soft(part("Bed", Vector3.new(0.3, 4.4, 4.4), ground * CFrame.new(0, 0.1, 0) * UPRIGHT, BED, Enum.Material.LeafyGrass, patch, Enum.PartType.Cylinder))
	for _ = 1, 8 do
		local angle = random:NextNumber() * 2 * math.pi
		local out = math.sqrt(random:NextNumber()) * 1.8
		flower(patch, (ground * CFrame.new(math.cos(angle) * out, 0.35, math.sin(angle) * out)).Position, random:NextNumber(0.55, 0.75))
	end
	return patch
end

-- Round raised planters on the plaza, one in each gap between buildings, a little before
-- the townsfolk's way out. Cherry and green trees take turns.
local PLANTER_RADIUS = 4.5
local PLANTER_HEIGHT = 1.2
for index, gap in gaps do
	local spot
	for shift = 8, 20, 2 do
		local try = center + direction(gap.middle - math.rad(shift)) * 46
		if isClear(try, PLANTER_RADIUS) then
			spot = try
			break
		end
	end
	if spot then
		claim(spot, PLANTER_RADIUS)
		local ground = CFrame.new(spot.X, PLAZA_TOP, spot.Z)
		local planter = model("Planter")
		part("Curb", Vector3.new(PLANTER_HEIGHT, PLANTER_RADIUS * 2, PLANTER_RADIUS * 2), ground * CFrame.new(0, PLANTER_HEIGHT / 2, 0) * UPRIGHT, MARBLE, Enum.Material.Marble, planter, Enum.PartType.Cylinder)
		soft(part("Trim", Vector3.new(0.18, PLANTER_RADIUS * 2 + 0.1, PLANTER_RADIUS * 2 + 0.1), ground * CFrame.new(0, PLANTER_HEIGHT - 0.3, 0) * UPRIGHT, PINK, Enum.Material.SmoothPlastic, planter, Enum.PartType.Cylinder))
		soft(part("Soil", Vector3.new(0.1, PLANTER_RADIUS * 2 - 0.8, PLANTER_RADIUS * 2 - 0.8), ground * CFrame.new(0, PLANTER_HEIGHT + 0.05, 0) * UPRIGHT, BED, Enum.Material.LeafyGrass, planter, Enum.PartType.Cylinder))
		local soil = ground * CFrame.new(0, PLANTER_HEIGHT + 0.1, 0)
		local tree = index % 2 == 1 and cherryTree(soil, 0.85, true) or greenTree(soil, 0.75)
		tree.Parent = planter
		for step = 1, 3 do
			local angle = step * 2 * math.pi / 3 + random:NextNumber() * 0.6
			bush(soil * CFrame.new(math.cos(angle) * 2.5, 0, math.sin(angle) * 2.5) * CFrame.Angles(0, -angle, 0), 0.55, true, planter)
		end
		for step = 1, 10 do
			local angle = (step + 0.5) * 2 * math.pi / 10
			flower(planter, (soil * CFrame.new(math.cos(angle) * 3.4, 0.25, math.sin(angle) * 3.4)).Position, 0.65)
		end
	end
end

-- Flower beds just outside the plaza's rim, wherever they're clear of paths and ways.
local BED_RADIUS = RIM_RADIUS + 2.5
local BED_STEP = 3.6
for step = 0, math.floor(2 * math.pi * BED_RADIUS / BED_STEP) - 1 do
	local angle = step * BED_STEP / BED_RADIUS
	local out = direction(angle)
	local spot = center + out * BED_RADIUS
	if isClear(spot, 2) then
		local segment = CFrame.lookAt(Vector3.new(spot.X, LAWN_TOP, spot.Z), Vector3.new(spot.X, LAWN_TOP, spot.Z) + out)
		local bed = model("FlowerBed")
		soft(part("Bed", Vector3.new(BED_STEP + 0.1, 0.3, 2.6), segment * CFrame.new(0, 0.15, 0), BED, Enum.Material.LeafyGrass, bed))
		soft(part("Edging", Vector3.new(BED_STEP + 0.1, 0.4, 0.3), segment * CFrame.new(0, 0.2, -1.45), STONE, Enum.Material.Slate, bed))
		for _ = 1, 5 do
			flower(bed, (segment * CFrame.new(random:NextNumber(-1.6, 1.6), 0.4, random:NextNumber(-1, 1))).Position, random:NextNumber(0.55, 0.75))
		end
	end
end

-- Pots of flowering bushes at each end of the benches.
for _, bench in benches do
	local seat = bench.Seat.CFrame
	for _, side in { -4.1, 4.1 } do
		local ground = CFrame.new((seat * CFrame.new(side, 0, 0)).Position * Vector3.new(1, 0, 1) + Vector3.new(0, PLAZA_TOP, 0))
		local pot = model("Pot")
		part("Pot", Vector3.new(1.2, 1.5, 1.5), ground * CFrame.new(0, 0.6, 0) * UPRIGHT, TERRACOTTA, Enum.Material.Concrete, pot, Enum.PartType.Cylinder)
		part("Rim", Vector3.new(0.25, 1.75, 1.75), ground * CFrame.new(0, 1.15, 0) * UPRIGHT, TERRACOTTA, Enum.Material.Concrete, pot, Enum.PartType.Cylinder).CastShadow = false
		bush(ground * CFrame.new(0, 1.0, 0), 0.5, true, pot)
	end
end

-- A basket of flowers hanging on each lamp post.
for _, lamp in lamps do
	local pole = lamp.Pole.Position
	local basket = model("Basket")
	local spot = Vector3.new(pole.X, 0, pole.Z)
	local toCenter = (center - spot).Unit
	local hang = CFrame.new(spot + toCenter * 0.75 + Vector3.new(0, 6.6, 0))
	soft(part("Basket", Vector3.new(0.7, 1.3, 1.3), hang * UPRIGHT, WICKER, Enum.Material.Fabric, basket, Enum.PartType.Cylinder))
	soft(part("Leaves", Vector3.new(1.5, 1.1, 1.5), hang * CFrame.new(0, 0.45, 0), LEAVES[2], Enum.Material.LeafyGrass, basket, Enum.PartType.Ball))
	for index = 1, 5 do
		local angle = index * 2 * math.pi / 5
		flower(basket, (hang * CFrame.new(math.cos(angle) * 0.6, 0.55 - (index % 2) * 0.5, math.sin(angle) * 0.6)).Position, 0.42)
	end
end

-- Trees, bushes and flower patches on the lawn: more flowers and bushes near the plaza,
-- trees further out, and petals only where people can see them.
local counts = { tree = 0, bush = 0, patch = 0 }
local limits = { tree = 75, bush = 45, patch = 22 }
for _ = 1, 4000 do
	local reach = RIM_RADIUS + 6 + (OUTER - RIM_RADIUS - 6) * random:NextNumber() ^ 1.4
	local spot = center + direction(random:NextNumber() * 2 * math.pi) * reach
	local roll = random:NextNumber()
	local kind
	if reach < 100 then
		kind = roll < 0.4 and "bush" or roll < 0.7 and "patch" or "tree"
	elseif reach < 150 then
		kind = roll < 0.3 and "bush" or "tree"
	else
		kind = roll < 0.15 and "bush" or "tree"
	end
	if counts[kind] < limits[kind] then
		local scale = kind == "tree" and random:NextNumber(0.9, 1.1) * (reach > 150 and 1.3 or 1) or random:NextNumber(0.8, 1.15)
		local radius = kind == "tree" and 4 * scale or kind == "bush" and 2 * scale or 2.3
		if isClear(spot, radius, true) then
			claim(spot, radius)
			counts[kind] += 1
			local ground = CFrame.new(spot.X, LAWN_TOP, spot.Z) * CFrame.Angles(0, random:NextNumber() * 2 * math.pi, 0)
			if kind == "tree" then
				if random:NextNumber() < 0.35 then
					cherryTree(ground, scale, reach < 130)
				else
					greenTree(ground, scale)
				end
			elseif kind == "bush" then
				bush(ground, scale, random:NextNumber() < 0.5)
			else
				flowerPatch(ground)
			end
		end
	end
end

greenery.Parent = town
local parts = 0
for _, p in greenery:GetDescendants() do
	if p:IsA("BasePart") then
		parts += 1
	end
end
print(("Greenery built: %d trees, %d bushes, %d flower patches, %d parts"):format(counts.tree, counts.bush, counts.patch, parts))
