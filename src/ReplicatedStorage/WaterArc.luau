-- Aims the fountain's jets. Water leaves one attachment, rises to a height and comes down on
-- another under Gravity, like a thrown ball. The drops fly that arc, and the jet's Beam is
-- bent to exactly the same curve, so the stream and its drops line up.
-- Used by tools/build_fountain.luau at edit time and by PlazaClient every frame.

local WaterArc = {}

-- Studs per second squared: real gravity at Roblox's scale, gentler than the game's 196.2.
WaterArc.Gravity = 35

-- Turns an attachment to face along axis (its X), standing at position.
local function point(attachment, position, axis)
	local up = math.abs(axis.Y) > 0.99 and Vector3.xAxis or Vector3.yAxis
	attachment.WorldCFrame = CFrame.lookAt(position, position + axis, up) * CFrame.Angles(0, math.pi / 2, 0)
end

-- Sends water from `from` up `apex` studs and down onto `to`. Returns how long it's in the air.
function WaterArc.Aim(from, to, apex, beam, drops)
	local start = from.WorldPosition
	local finish = to.WorldPosition
	local gravity = WaterArc.Gravity
	local rise = math.sqrt(2 * gravity * apex)
	local fall = math.max(apex + start.Y - finish.Y, 0)
	local time = rise / gravity + math.sqrt(2 * fall / gravity)
	local velocity = (finish - start) * Vector3.new(1, 0, 1) / time + Vector3.new(0, rise, 0)
	-- A thrown arc is a quadratic Bézier with its control point here. A Beam draws a cubic,
	-- which matches it when each end's handle reaches two thirds of the way to that point.
	local control = start + velocity * time / 2
	point(from, start, velocity.Unit)
	point(to, finish, (finish - control).Unit)
	if beam then
		beam.CurveSize0 = (control - start).Magnitude * 2 / 3
		beam.CurveSize1 = (finish - control).Magnitude * 2 / 3
	end
	if drops then
		drops.Speed = NumberRange.new(velocity.Magnitude)
		drops.Lifetime = NumberRange.new(time)
		drops.Acceleration = Vector3.new(0, -gravity, 0)
	end
	return time
end

return WaterArc
