-- Moves the fountain in the middle of the plaza, built by tools/build_fountain.luau. The jets
-- on its ledge rise and fall in patterns, the umbrella spray on top breathes, light ripples
-- drift over the water, and the water sound plays. The dance is timed by the server's
-- clock, so every player sees the same one.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WaterArc = require(ReplicatedStorage:WaitForChild("WaterArc"))

-- Jet and spray heights, from low to high, in studs above their nozzles.
local JET_LOW, JET_HIGH = 2, 6
local SPRAY_LOW, SPRAY_HIGH = 1.2, 2.2
-- The jets' splash rates are set for a jet this high, and scale with height.
local BASE_HEIGHT = 4
-- Each pattern plays for PATTERN_TIME seconds, then blends into the next over BLEND_TIME.
local PATTERN_TIME = 12
local BLEND_TIME = 3
-- Nothing moves while the camera is further away than this.
local FAR = 220

-- How high jet number index of count is in each pattern at time t, from 0 to 1.
local PATTERNS = {
	-- A wave running around the ring.
	function(t, index, count)
		return 0.5 + 0.5 * math.sin(t * 1.6 - index * 2 * math.pi / count)
	end,
	-- All together, rising and falling.
	function(t)
		return 0.5 + 0.5 * math.sin(t * 1.1)
	end,
	-- Every other jet in turn.
	function(t, index)
		return 0.5 + 0.5 * math.sin(t * 1.3) * (index % 2 == 0 and 1 or -1)
	end,
}

local function level(t, index, count)
	local cycle = t / PATTERN_TIME
	local current = math.floor(cycle) % #PATTERNS + 1
	local nextPattern = current % #PATTERNS + 1
	local into = (cycle % 1) * PATTERN_TIME - (PATTERN_TIME - BLEND_TIME)
	local blend = 0
	if into > 0 then
		blend = into / BLEND_TIME
		blend = blend * blend * (3 - 2 * blend)
	end
	local from = PATTERNS[current](t, index, count)
	return from + (PATTERNS[nextPattern](t, index, count) - from) * blend
end

local fountain = Workspace:WaitForChild("Town"):WaitForChild("Fountain")

-- The jets or sprays in the effects part, numbered from 1.
local function findJets(fx, prefix)
	local list = {}
	local index = 1
	while fx:FindFirstChild(prefix .. "From" .. index) do
		local from = fx[prefix .. "From" .. index]
		local splash = fx:FindFirstChild(prefix .. "Splash" .. index)
		table.insert(list, {
			from = from,
			to = fx[prefix .. "To" .. index],
			beam = fx:FindFirstChild(prefix .. "Beam" .. index),
			drops = from:FindFirstChild("Drops"),
			splash = splash and splash:FindFirstChild("Splash"),
			ripple = splash and splash:FindFirstChild("Ripple"),
		})
		index += 1
	end
	return list
end

-- Sets an emitter's rate to its BaseRate times strength, unless that's barely different.
local function setRate(emitter, strength)
	if emitter then
		local rate = (emitter:GetAttribute("BaseRate") or emitter.Rate) * strength
		if math.abs(emitter.Rate - rate) > 0.5 then
			emitter.Rate = rate
		end
	end
end

-- With streaming, parts of the fountain can arrive late or leave, so the effects part is
-- looked up again whenever it's missing.
local fx, jets, sprays
local shimmers = {}

local function track(texture)
	if texture:IsA("Texture") and texture.Name == "Shimmer" then
		shimmers[texture] = true
	end
end
for _, descendant in fountain:GetDescendants() do
	track(descendant)
end
fountain.DescendantAdded:Connect(track)
fountain.DescendantRemoving:Connect(function(descendant)
	shimmers[descendant] = nil
end)

RunService.Heartbeat:Connect(function()
	if not fx or not fx.Parent then
		fx = fountain:FindFirstChild("WaterFX")
		if not fx then
			return
		end
		jets = findJets(fx, "Jet")
		sprays = findJets(fx, "Spray")
		local sound = fx:FindFirstChild("FountainSound")
		if sound then
			sound:Play()
		end
	end
	local camera = Workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - fx.Position).Magnitude > FAR then
		return
	end
	local t = Workspace:GetServerTimeNow()
	for index, jet in jets do
		local height = JET_LOW + (JET_HIGH - JET_LOW) * level(t, index, #jets)
		WaterArc.Aim(jet.from, jet.to, height, jet.beam, jet.drops)
		setRate(jet.splash, height / BASE_HEIGHT)
		setRate(jet.ripple, height / BASE_HEIGHT)
	end
	local breath = 0.5 + 0.5 * math.sin(t * 0.9)
	for _, spray in sprays do
		WaterArc.Aim(spray.from, spray.to, SPRAY_LOW + (SPRAY_HIGH - SPRAY_LOW) * breath, spray.beam, spray.drops)
	end
	for texture in shimmers do
		texture.OffsetStudsU = (t * (texture:GetAttribute("SpeedU") or 0)) % texture.StudsPerTileU
		texture.OffsetStudsV = (t * (texture:GetAttribute("SpeedV") or 0)) % texture.StudsPerTileV
	end
end)
