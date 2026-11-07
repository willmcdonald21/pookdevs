-- Edit-time builder: the three-tier fountain in the middle of the plaza, rebuilt from scratch
-- in workspace.Town.Fountain. Run it after build_town, which rebuilds the whole Town folder.
-- Safe to run again.
--
-- The water moves by itself: sheets of water spill over each bowl as Beams whose streaks
-- scroll down, with splashes and ripples where they land. Eight jets on the ledge and the
-- spray on top are aimed every frame by PlazaClient, which makes them dance. Everything the
-- client moves sits in the invisible WaterFX part:
--   JetFrom1..8 / JetTo1..8 / JetBeam1..8: each jet's nozzle, landing point and stream, with
--     a Drops emitter at the nozzle and Splash and Ripple emitters at JetSplash1..8.
--   SprayFrom1..6 / SprayTo1..6 / SprayBeam1..6 / SpraySplash1..6: the same for the
--     umbrella of small arcs on top, falling into the top bowl.
-- Splash and Ripple emitters carry a BaseRate attribute, their rate for a 4-stud jet.
-- Shimmer textures on the water carry SpeedU and SpeedV attributes for the client to scroll.
-- setUpTown in BakerySystem reads Basin's size for the ring of spots around the fountain, so
-- Basin stays a cylinder lying on its side with Size.Y as its diameter.

local WaterArc = require(game.ReplicatedStorage.WaterArc)

local WATER_STREAK = "rbxassetid://85429443771374"
local RIPPLE = "rbxassetid://136264013809055"
local SHIMMER = "rbxassetid://136162882548820"
local DROPLET = "rbxassetid://109115073089942"
local MIST = "rbxasset://textures/particles/smoke_main.dds"
local SOUND = "rbxassetid://9120557577"

local WATER_GRAVITY = WaterArc.Gravity

local MARBLE = Color3.fromRGB(242, 236, 230)
local MARBLE_SHADE = Color3.fromRGB(226, 216, 212)
local PINK = Color3.fromRGB(240, 182, 200)
local DARK_STONE = Color3.fromRGB(150, 145, 158)
local BRASS = Color3.fromRGB(226, 188, 112)
local TILE = Color3.fromRGB(72, 170, 192)
local WATER = Color3.fromRGB(125, 205, 238)
local FOAM = Color3.fromRGB(235, 248, 255)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X, so stand them up

local town = workspace.Town
local base = town.Plaza.Position + Vector3.new(0, town.Plaza.Size.X / 2, 0) -- the plaza's top
local function at(y)
	return base + Vector3.new(0, y, 0)
end

-- Heights above the plaza.
local PLINTH_TOP = 0.3
local BASIN_TOP = 1.3
local POOL_WATER = 1.9
local LEDGE_TOP = 2.3
local CAP_TOP = 2.65
local MIDDLE_WATER = 6.3
local TOP_WATER = 9.45

local POOL_RADIUS = 9.3
local LEDGE_RADIUS = 10.5
local MIDDLE_RADIUS = 4.2
local TOP_RADIUS = 2.2
local JET_COUNT = 8
local JET_LANDING_RADIUS = 6.4
-- How high the jets and the spray rise before PlazaClient starts moving them.
local JET_APEX = 4
local SPRAY_APEX = 1.6
local SPRAY_COUNT = 6
local SPRAY_LANDING_RADIUS = 1.45

local old = town:FindFirstChild("Fountain")
if old then
	old:Destroy()
end
local fountain = Instance.new("Model")
fountain.Name = "Fountain"

local function part(name, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Marble
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = fountain
	return p
end

-- An upright disc or column centred on the fountain's axis, from bottom to top.
local function disc(name, radius, bottom, top, color, material)
	return part(name, Vector3.new(top - bottom, radius * 2, radius * 2), CFrame.new(at((bottom + top) / 2)) * UPRIGHT, color, material, Enum.PartType.Cylinder)
end

local function direction(radians)
	return Vector3.new(math.cos(radians), 0, math.sin(radians))
end

-- A ring of count flat blocks between two radii, so it reads as a many-sided wall.
local function ring(name, count, inner, outer, bottom, top, color, material)
	local length = 2 * outer * math.tan(math.pi / count)
	for index = 0, count - 1 do
		local out = direction(index * 2 * math.pi / count)
		local center = at((bottom + top) / 2) + out * (inner + outer) / 2
		local block = part(name, Vector3.new(length, top - bottom, outer - inner), CFrame.lookAt(center, center + out), color, material)
		block.CastShadow = top - bottom > 0.3
	end
end


local function water(name, radius, top)
	local surface = disc(name, radius, top - 0.2, top, WATER, Enum.Material.Glass)
	surface.Transparency = 0.35
	surface.Reflectance = 0.12
	surface.CanCollide = false
	surface.CastShadow = false
	-- Two layers of light ripples drifting different ways. The cylinder stands on its side,
	-- so its top is the Right face.
	for _, speed in { Vector2.new(0.6, 0.25), Vector2.new(-0.35, 0.5) } do
		local shimmer = Instance.new("Texture")
		shimmer.Name = "Shimmer"
		shimmer.Texture = SHIMMER
		shimmer.Face = Enum.NormalId.Right
		shimmer.StudsPerTileU = 7
		shimmer.StudsPerTileV = 7
		shimmer.Transparency = 0.55
		shimmer.Color3 = FOAM
		shimmer:SetAttribute("SpeedU", speed.X)
		shimmer:SetAttribute("SpeedV", speed.Y)
		shimmer.Parent = surface
	end
	return surface
end

-- Stone: plinth, basin and the many-sided ledge, with a pink band under its cap.
disc("Plinth", LEDGE_RADIUS + 1.1, 0, PLINTH_TOP, DARK_STONE, Enum.Material.Slate)
disc("Basin", LEDGE_RADIUS, PLINTH_TOP, BASIN_TOP, MARBLE_SHADE)
disc("PoolFloor", POOL_RADIUS + 0.2, BASIN_TOP, BASIN_TOP + 0.1, TILE, Enum.Material.CeramicTiles)
ring("Ledge", 16, POOL_RADIUS, LEDGE_RADIUS, BASIN_TOP, LEDGE_TOP, MARBLE)
ring("Trim", 16, LEDGE_RADIUS - 0.05, LEDGE_RADIUS + 0.08, LEDGE_TOP - 0.35, LEDGE_TOP - 0.1, PINK, Enum.Material.SmoothPlastic)
ring("Cap", 16, POOL_RADIUS - 0.25, LEDGE_RADIUS + 0.3, LEDGE_TOP, CAP_TOP, MARBLE)
water("PoolWater", POOL_RADIUS + 0.2, POOL_WATER)

-- Fluted pedestal up to the middle bowl.
disc("PedestalFoot", 1.7, BASIN_TOP, BASIN_TOP + 0.7, MARBLE_SHADE)
disc("Pedestal", 0.9, BASIN_TOP + 0.7, 5.1, MARBLE)
for index = 0, 7 do
	local flute = part("Flute", Vector3.new(5.1 - BASIN_TOP - 0.7, 0.36, 0.36), CFrame.new(at((BASIN_TOP + 0.7 + 5.1) / 2) + direction(index * math.pi / 4) * 0.85) * UPRIGHT, MARBLE, Enum.Material.Marble, Enum.PartType.Cylinder)
	flute.CastShadow = false
end
disc("PedestalCollar", 1.25, 4.8, 5.1, PINK, Enum.Material.SmoothPlastic)

-- Middle bowl: a curved underside of widening discs, and a lip with a pink band under it.
disc("MiddleBowl", 1.6, 5.1, 5.35, MARBLE)
disc("MiddleBowl", 2.6, 5.35, 5.6, MARBLE)
disc("MiddleBowl", 3.5, 5.6, 5.85, MARBLE)
disc("MiddleBowl", MIDDLE_RADIUS, 5.85, MIDDLE_WATER - 0.15, MARBLE)
ring("MiddleLip", 16, MIDDLE_RADIUS - 0.25, MIDDLE_RADIUS + 0.15, MIDDLE_WATER - 0.15, MIDDLE_WATER + 0.1, MARBLE)
ring("MiddleTrim", 16, MIDDLE_RADIUS - 0.1, MIDDLE_RADIUS + 0.08, MIDDLE_WATER - 0.4, MIDDLE_WATER - 0.2, PINK, Enum.Material.SmoothPlastic)
water("MiddleWater", MIDDLE_RADIUS - 0.2, MIDDLE_WATER)

-- Column with a knop, the top bowl and its finial.
disc("UpperColumn", 0.55, MIDDLE_WATER - 0.15, 8.75, MARBLE)
part("Knop", Vector3.new(1.4, 1.4, 1.4), CFrame.new(at(7.4)), PINK, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
disc("TopBowl", 0.9, 8.75, 8.95, MARBLE)
disc("TopBowl", 1.6, 8.95, 9.15, MARBLE)
disc("TopBowl", TOP_RADIUS, 9.15, TOP_WATER - 0.15, MARBLE)
ring("TopLip", 12, TOP_RADIUS - 0.2, TOP_RADIUS + 0.12, TOP_WATER - 0.15, TOP_WATER + 0.08, MARBLE)
ring("TopTrim", 12, TOP_RADIUS - 0.1, TOP_RADIUS + 0.06, TOP_WATER - 0.38, TOP_WATER - 0.2, PINK, Enum.Material.SmoothPlastic)
water("TopWater", TOP_RADIUS - 0.15, TOP_WATER)
disc("FinialStem", 0.32, TOP_WATER - 0.15, 10.1, MARBLE)
part("Finial", Vector3.new(0.9, 0.9, 0.9), CFrame.new(at(10.4)), PINK, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
part("FinialTip", Vector3.new(0.4, 0.4, 0.4), CFrame.new(at(10.85)), BRASS, Enum.Material.Metal, Enum.PartType.Ball)

-- Effects
local fx = part("WaterFX", Vector3.new(1, 1, 1), CFrame.new(at(0)), WATER, Enum.Material.SmoothPlastic)
fx.Transparency = 1
fx.CanCollide = false
fx.CanQuery = false
fx.CanTouch = false

local function attachment(name, position, cframe)
	local a = Instance.new("Attachment")
	a.Name = name
	a.WorldCFrame = cframe or CFrame.new(position)
	a.Parent = fx
	return a
end

local function beam(name, from, to, width0, width1)
	local b = Instance.new("Beam")
	b.Name = name
	b.Attachment0 = from
	b.Attachment1 = to
	b.Texture = WATER_STREAK
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = 2.5
	b.TextureSpeed = 1.6
	b.Color = ColorSequence.new(FOAM, WATER)
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.85, 0.35),
		NumberSequenceKeypoint.new(1, 0.7),
	})
	b.LightEmission = 0.35
	b.LightInfluence = 0.7
	b.Width0 = width0
	b.Width1 = width1
	b.Segments = 12
	b.Parent = fx
	return b
end

-- Drops of water flying along a jet's arc. WaterArc sets their speed and lifetime.
local function drops(parent, rate, size)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Drops"
	e.Texture = DROPLET
	e.Color = ColorSequence.new(FOAM)
	e.LightEmission = 0.3
	e.Size = NumberSequence.new(size, size * 0.6)
	e.Transparency = NumberSequence.new(0.3, 0.7)
	e.EmissionDirection = Enum.NormalId.Right
	e.SpreadAngle = Vector2.new(3, 3)
	e.Rate = rate
	e.Parent = parent
	return e
end

-- Little drops jumping up where falling water lands, and rings spreading on the water. They
-- sit on their own upright attachment, so they point up whichever way the water arrives.
local function splash(name, position, rate, size)
	local parent = attachment(name, position + Vector3.new(0, 0.04, 0))
	local e = Instance.new("ParticleEmitter")
	e.Name = "Splash"
	e.Texture = DROPLET
	e.Color = ColorSequence.new(FOAM)
	e.LightEmission = 0.3
	e.Size = NumberSequence.new(size, size * 0.5)
	e.Transparency = NumberSequence.new(0.2, 0.8)
	e.Acceleration = Vector3.new(0, -WATER_GRAVITY, 0)
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(35, 35)
	e.Speed = NumberRange.new(3, 6)
	e.Lifetime = NumberRange.new(0.3, 0.45)
	e.Rate = rate
	e:SetAttribute("BaseRate", rate)
	e.Parent = parent
	local r = Instance.new("ParticleEmitter")
	r.Name = "Ripple"
	r.Texture = RIPPLE
	r.Color = ColorSequence.new(FOAM)
	r.LightEmission = 0.2
	r.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	r.EmissionDirection = Enum.NormalId.Top
	r.Speed = NumberRange.new(0.01)
	r.Size = NumberSequence.new(size * 1.2, size * 9)
	r.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	r.Lifetime = NumberRange.new(1.1, 1.4)
	r.Rate = rate * 0.15
	r:SetAttribute("BaseRate", r.Rate)
	r.Parent = parent
end

-- A sheet of water spilling all around a bowl's rim, falling outward onto the water below.
-- A Beam that doesn't face the camera spreads its width along its attachments' Y, so each
-- beam's attachments point down the fall (X) and along the rim (Y).
local function overflow(name, count, rimRadius, rimY, landRadius, landY)
	for index = 0, count - 1 do
		local out = direction((index + 0.5) * 2 * math.pi / count)
		local along = Vector3.new(-out.Z, 0, out.X)
		local top = at(rimY) + out * rimRadius
		local bottom = at(landY) + out * landRadius
		local spill = (out * 0.6 - Vector3.yAxis).Unit
		local fall = (bottom - top).Unit
		local from = attachment(name .. "From", nil, CFrame.fromMatrix(top, spill, along))
		local to = attachment(name .. "To", nil, CFrame.fromMatrix(bottom, fall, along))
		local sheet = beam(name, from, to, 2 * math.pi * rimRadius / count * 1.15, 2 * math.pi * landRadius / count * 1.15)
		sheet.FaceCamera = false
		sheet.CurveSize0 = (rimY - landY) * 0.25
		sheet.CurveSize1 = 0
		splash(name .. "Splash", bottom, 6, 0.22)
	end
end
overflow("TopSheet", 12, TOP_RADIUS + 0.12, TOP_WATER + 0.05, MIDDLE_RADIUS - 1.0, MIDDLE_WATER)
overflow("MiddleSheet", 16, MIDDLE_RADIUS + 0.15, MIDDLE_WATER + 0.05, MIDDLE_RADIUS + 1.2, POOL_WATER)

-- Jets: brass nozzles on the ledge, arcing in toward the pedestal.
for index = 1, JET_COUNT do
	local out = direction((index - 1) * 2 * math.pi / JET_COUNT)
	local nozzle = at(CAP_TOP + 0.3) + out * (POOL_RADIUS + 0.2)
	part("Nozzle", Vector3.new(0.7, 0.7, 0.7), CFrame.new(at(CAP_TOP + 0.1) + out * (POOL_RADIUS + 0.35)), BRASS, Enum.Material.Metal, Enum.PartType.Ball).CastShadow = false
	local landing = at(POOL_WATER) + out * JET_LANDING_RADIUS
	local from = attachment("JetFrom" .. index, nozzle)
	local to = attachment("JetTo" .. index, landing)
	local stream = beam("JetBeam" .. index, from, to, 0.35, 0.25)
	stream.TextureLength = 1.5
	stream.TextureSpeed = 2.4
	WaterArc.Aim(from, to, JET_APEX, stream, drops(from, 24, 0.2))
	splash("JetSplash" .. index, landing, 18, 0.3)
end

-- An umbrella of small arcs from the finial's tip, falling into the top bowl.
for index = 1, SPRAY_COUNT do
	local out = direction((index - 0.5) * 2 * math.pi / SPRAY_COUNT)
	local landing = at(TOP_WATER) + out * SPRAY_LANDING_RADIUS
	local from = attachment("SprayFrom" .. index, at(11))
	local to = attachment("SprayTo" .. index, landing)
	local arc = beam("SprayBeam" .. index, from, to, 0.22, 0.16)
	arc.TextureLength = 1.2
	arc.TextureSpeed = 2.4
	local sprayDrops = drops(from, 10, 0.16)
	sprayDrops.SpreadAngle = Vector2.new(6, 6)
	WaterArc.Aim(from, to, SPRAY_APEX, arc, sprayDrops)
	splash("SpraySplash" .. index, landing, 8, 0.18)
end

-- Faint mist drifting over the pool.
local mistAt = attachment("Mist", at(POOL_WATER + 0.5))
local mist = Instance.new("ParticleEmitter")
mist.Name = "Mist"
mist.Texture = MIST
mist.Color = ColorSequence.new(FOAM)
mist.Size = NumberSequence.new(3, 7)
mist.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.3, 0.88),
	NumberSequenceKeypoint.new(1, 1),
})
mist.Speed = NumberRange.new(2, 4)
mist.SpreadAngle = Vector2.new(180, 15)
mist.EmissionDirection = Enum.NormalId.Right
mist.Drag = 1
mist.Acceleration = Vector3.new(0, 0.4, 0)
mist.Lifetime = NumberRange.new(3, 5)
mist.Rate = 3
mist.RotSpeed = NumberRange.new(-15, 15)
mist.Parent = mistAt

-- The sound of the water. PlazaClient starts it.
local sound = Instance.new("Sound")
sound.Name = "FountainSound"
sound.SoundId = SOUND
sound.Looped = true
sound.Volume = 0.6
sound.RollOffMode = Enum.RollOffMode.InverseTapered
sound.RollOffMinDistance = 15
sound.RollOffMaxDistance = 75
sound.Parent = fx

fountain.PrimaryPart = fountain.Basin
fountain.Parent = town
print(("Fountain built: %d parts"):format(#fountain:GetChildren()))
