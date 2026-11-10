-- Builds a treat or placeable item from its part list in Config.
local ItemBuilder = {}

-- Parts are welded to the first part. Callers anchor or weld that part.
-- Parts are only solid when solid is true. A Disc lies flat like a plate on a table, and
-- a Plate faces the front like a clock on a wall. A part with Light = range glows in its
-- own colour. When paint is a Color3, parts with Paint = true take that colour instead.
-- A Ball with a Size instead of a Diameter is squashed or stretched to it. Turn tilts a part
-- by that many degrees around X, Y and Z. A part with Petals = true drops cherry blossom
-- petals, like the park's cherry trees. A part with Art (a Treat Designer drawing, see
-- TreatDesign) is an invisible plate with a TreatArt decal on top. The decal keeps the
-- drawing in its Art attribute, and the client paints it (see TreatArt).
function ItemBuilder.Build(definition, scale, cframe, solid, paint)
	local model = Instance.new("Model")
	model.Name = definition.Name
	local first
	for _, spec in definition.Parts do
		local part = Instance.new("Part")
		local offset = CFrame.new((spec.X or 0) * scale, spec.Y * scale, (spec.Z or 0) * scale)
		if spec.Turn then
			offset *= CFrame.Angles(math.rad(spec.Turn.X), math.rad(spec.Turn.Y), math.rad(spec.Turn.Z))
		end
		if spec.Kind == "Disc" then
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(spec.Height, spec.Diameter, spec.Diameter) * scale
			part.CFrame = cframe * offset * CFrame.Angles(0, 0, math.rad(90))
		elseif spec.Kind == "Plate" then
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(spec.Height, spec.Diameter, spec.Diameter) * scale
			part.CFrame = cframe * offset * CFrame.Angles(0, math.rad(90), 0)
		elseif spec.Kind == "Ball" then
			part.Shape = Enum.PartType.Ball
			part.Size = (spec.Size or Vector3.one * spec.Diameter) * scale
			part.CFrame = cframe * offset
		else
			part.Size = spec.Size * scale
			part.CFrame = cframe * offset
		end
		part.Color = spec.Paint and paint or spec.Color
		part.Material = spec.Material or Enum.Material.SmoothPlastic
		part.Transparency = spec.Transparency or 0
		part.CanCollide = solid == true
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		if spec.Light then
			local light = Instance.new("PointLight")
			light.Color = spec.Color
			light.Range = spec.Light * scale
			light.Brightness = 1.5
			light.Parent = part
		end
		if spec.Petals then
			ItemBuilder.AddPetals(part)
		end
		if spec.Art then
			part.Transparency = 1
			part.CastShadow = false
			local decal = Instance.new("Decal")
			decal.Name = "TreatArt"
			decal.Face = Enum.NormalId.Top
			decal:SetAttribute("Art", spec.Art)
			decal.Parent = part
		end
		if first then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = first
			weld.Part1 = part
			weld.Parent = part
		else
			first = part
			model.PrimaryPart = part
		end
		part.Parent = model
	end
	return model
end

-- Pink petals drifting down from a part, set up like the park's cherry trees.
function ItemBuilder.AddPetals(part)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxassetid://74180373620457"
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
	emitter.Parent = part
end

function ItemBuilder.Anchor(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
end

return ItemBuilder
