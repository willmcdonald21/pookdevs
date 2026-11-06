-- Builds a treat or placeable item from its part list in Config.
local ItemBuilder = {}

-- Parts are welded to the first part. Callers anchor or weld that part.
-- Parts are only solid when solid is true. A Disc lies flat like a plate on a table, and
-- a Plate faces the front like a clock on a wall. A part with Light = range glows in its
-- own colour. When paint is a Color3, parts with Paint = true take that colour instead.
function ItemBuilder.Build(definition, scale, cframe, solid, paint)
	local model = Instance.new("Model")
	model.Name = definition.Name
	local first
	for _, spec in definition.Parts do
		local part = Instance.new("Part")
		local offset = CFrame.new((spec.X or 0) * scale, spec.Y * scale, (spec.Z or 0) * scale)
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
			part.Size = Vector3.one * spec.Diameter * scale
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

function ItemBuilder.Anchor(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
end

return ItemBuilder
