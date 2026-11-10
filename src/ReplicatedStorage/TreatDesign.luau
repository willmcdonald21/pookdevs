-- The Treat Designer's shared rules: what a design holds, how a saved one is checked, and
-- the part list a designed treat is built from. The server and the client both use it.
--
-- A design is { Dough, Frosting, Filling, Sprinkles, Cherries, Cream, Candles, CandleColor,
-- Art }. Dough, Frosting and Filling are Config.TreatColors Ids, or nil for the recipe's own
-- colour. Sprinkles is "Rainbow", a colour Id, or nil for none. Cherries, Cream (whipped
-- cream dollops) and Candles are counts. Art is the drawing: one letter per cell of the
-- Grid x Grid canvas, row by row from the far side of the treat, "0" for an empty cell and
-- "a" for the first of Config.TreatColors, or nil when nothing is drawn.
-- No design (nil) means the treat looks the way its recipe does.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local ItemBuilder = require(ReplicatedStorage:WaitForChild("ItemBuilder"))

local TreatDesign = {}

local settings = Config.TreatDesign
local GRID = settings.Grid
local CELLS = GRID * GRID
local COLOR_ROLES = { "Dough", "Frosting", "Filling" }
local LAST_LETTER = string.char(string.byte("a") + #Config.TreatColors - 1)
local RAINBOW = { "Bubblegum", "Lemon", "Mint", "Sky", "Lavender", "Orange", "Cherry", "Snow" }
-- Where the sprinkles land, as fractions of the top's half width and depth, and how they
-- turn, so every sprinkled treat of a recipe looks the same.
local SPRINKLES = {
	{ 0.3, 0.1, 20 },
	{ -0.45, 0.3, 75 },
	{ 0.1, -0.55, 130 },
	{ -0.2, -0.25, 165 },
	{ 0.55, -0.3, 45 },
	{ -0.6, -0.15, 100 },
	{ 0.25, 0.55, 150 },
	{ -0.05, 0.4, 10 },
}

TreatDesign.Grid = GRID
TreatDesign.Cells = CELLS
TreatDesign.ColorRoles = COLOR_ROLES

local function hasRole(recipe, role)
	for _, spec in recipe.Parts do
		if spec.Role == role then
			return true
		end
	end
	return false
end

local function countRole(recipe, role)
	local count = 0
	for _, spec in recipe.Parts do
		if spec.Role == role then
			count += 1
		end
	end
	return count
end

function TreatDesign.Color(id)
	local color = Config.GetTreatColor(id)
	return color and color.Color
end

-- Which colours a recipe's design can change. A treat with no frosting can get some when
-- its Top allows Icing.
function TreatDesign.Roles(recipe)
	return {
		Dough = hasRole(recipe, "Dough"),
		Frosting = hasRole(recipe, "Frosting") or (recipe.Top and recipe.Top.Icing == true),
		Filling = hasRole(recipe, "Filling"),
	}
end

function TreatDesign.CanDraw(recipe)
	return recipe.Top ~= nil and not recipe.Top.NoArt
end

-- The drawing's size in the treat's own studs.
function TreatDesign.ArtSize(recipe)
	local top = recipe.Top
	local width = top.ArtWidth or (top.Icing and top.Width * 0.92) or top.Width
	local depth = top.ArtDepth or (top.Depth and top.Depth * width / top.Width) or width
	return width, depth
end

-- Whether a canvas cell (column and row from 0) is on the treat. The canvas is round,
-- with the donut's hole left out.
function TreatDesign.InShape(recipe, column, row)
	local u = (column + 0.5) / GRID * 2 - 1
	local v = (row + 0.5) / GRID * 2 - 1
	local distance = u * u + v * v
	if distance > 1 then
		return false
	end
	local hole = recipe.Top.Hole
	if hole then
		local width = TreatDesign.ArtSize(recipe)
		local clear = hole / width + 0.06
		return distance >= clear * clear
	end
	return true
end

-- The design the Treat Designer starts from for a recipe never changed: its own colours,
-- and as many cherries and candles as it already has.
function TreatDesign.Default(recipe)
	return {
		Cherries = countRole(recipe, "Cherry"),
		Cream = 0,
		Candles = countRole(recipe, "Candle"),
		CandleColor = settings.DefaultCandle,
	}
end

local function cleanCount(value, max, fallback)
	if type(value) ~= "number" or value ~= value then
		return fallback
	end
	return math.clamp(math.floor(value), 0, max)
end

local function isColor(value)
	return type(value) == "string" and Config.GetTreatColor(value) ~= nil
end

-- A checked copy of a design sent by a client or loaded from a save, or nil when it's the
-- same as the recipe's own look. Anything it doesn't understand goes back to the default.
function TreatDesign.Clean(raw, recipe)
	if type(raw) ~= "table" or not recipe or not recipe.Top then
		return nil
	end
	local default = TreatDesign.Default(recipe)
	local roles = TreatDesign.Roles(recipe)
	local design = {}
	for _, role in COLOR_ROLES do
		if roles[role] and isColor(raw[role]) then
			design[role] = raw[role]
		end
	end
	if raw.Sprinkles == "Rainbow" or isColor(raw.Sprinkles) then
		design.Sprinkles = raw.Sprinkles
	end
	design.Cherries = cleanCount(raw.Cherries, settings.MaxCherries, default.Cherries)
	design.Cream = cleanCount(raw.Cream, settings.MaxCream, default.Cream)
	design.Candles = cleanCount(raw.Candles, settings.MaxCandles, default.Candles)
	design.CandleColor = design.Candles > 0 and isColor(raw.CandleColor) and raw.CandleColor or default.CandleColor
	if TreatDesign.CanDraw(recipe) and type(raw.Art) == "string" and #raw.Art == CELLS then
		local cells = table.create(CELLS, "0")
		local drawn = false
		for index = 1, CELLS do
			local letter = string.sub(raw.Art, index, index)
			if letter >= "a" and letter <= LAST_LETTER and TreatDesign.InShape(recipe, (index - 1) % GRID, (index - 1) // GRID) then
				cells[index] = letter
				drawn = true
			end
		end
		if drawn then
			design.Art = table.concat(cells)
		end
	end
	local changed = design.Dough or design.Frosting or design.Filling or design.Sprinkles or design.Art
	if
		not changed
		and design.Cherries == default.Cherries
		and design.Cream == default.Cream
		and design.Candles == default.Candles
		and design.CandleColor == default.CandleColor
	then
		return nil
	end
	return design
end

-- A ring of count points at a radius (a fraction of the top's half size), starting at turn
-- (also a fraction of a full turn).
local function ring(count, radius, turn)
	local points = {}
	for index = 1, count do
		local angle = (index - 1 + turn) / count * math.pi * 2
		table.insert(points, { math.cos(angle) * radius, math.sin(angle) * radius })
	end
	return points
end

-- The part list for a recipe made with a design, for ItemBuilder.Build. With no design it's
-- the recipe itself.
function TreatDesign.Definition(recipe, design)
	if not design or not recipe.Top then
		return recipe
	end
	local parts = {}
	for _, spec in recipe.Parts do
		local role = spec.Role
		if role == "Cherry" or role == "Candle" or role == "Flame" then
			continue
		end
		local colorId = role and design[role]
		if colorId and TreatDesign.Color(colorId) then
			local copy = table.clone(spec)
			copy.Color = TreatDesign.Color(colorId)
			table.insert(parts, copy)
		else
			table.insert(parts, spec)
		end
	end

	local top = recipe.Top
	local width, depth = top.Width, top.Depth or top.Width
	local surface = top.Y
	if top.Icing and design.Frosting and not hasRole(recipe, "Frosting") then
		table.insert(parts, {
			Kind = "Disc",
			Height = 0.08,
			Diameter = width * 0.92,
			Y = surface + 0.04,
			Color = TreatDesign.Color(design.Frosting),
		})
		surface += 0.08
	end
	-- Positions are fractions of the top's half size. On a domed top things sit lower
	-- toward the edge.
	local function at(u, v)
		local height = surface
		if top.Dome then
			height = top.Dome.Y + top.Dome.Height * math.sqrt(math.max(0, 1 - u * u - v * v))
		end
		return u * width / 2, height, v * depth / 2
	end
	local hole = top.Hole and top.Hole / width or 0
	local busy = top.Busy or hole > 0

	if design.Art and TreatDesign.CanDraw(recipe) then
		local artWidth, artDepth = TreatDesign.ArtSize(recipe)
		local peak = top.Dome and top.Dome.Y + top.Dome.Height or surface
		table.insert(parts, {
			Kind = "Box",
			Size = Vector3.new(artWidth, 0.02, artDepth),
			Y = peak + 0.012,
			-- A Top decal's image runs toward +Z, so the plate turns round to put the
			-- canvas's top row at the far side.
			Turn = { X = 0, Y = 180, Z = 0 },
			Color = Color3.new(1, 1, 1),
			Art = design.Art,
		})
	end

	if design.Sprinkles then
		for index, sprinkle in SPRINKLES do
			local u, v = sprinkle[1], sprinkle[2]
			local distance = math.sqrt(u * u + v * v)
			if hole > 0 and distance < hole + 0.12 then
				local push = (hole + 0.12) / math.max(distance, 0.01)
				u, v = u * push, v * push
			end
			local x, y, z = at(u, v)
			local colorId = design.Sprinkles == "Rainbow" and RAINBOW[(index - 1) % #RAINBOW + 1] or design.Sprinkles
			table.insert(parts, {
				Kind = "Box",
				Size = Vector3.new(0.24, 0.05, 0.07),
				X = x,
				Y = y + 0.03,
				Z = z,
				Turn = { X = 0, Y = sprinkle[3], Z = 0 },
				Color = TreatDesign.Color(colorId),
			})
		end
	end

	-- Whipped cream goes round the edge, then a candle takes the middle when there's just
	-- one and the middle is free, and the cherries go in a ring inside the cream.
	for _, point in ring(design.Cream, 0.72, 0.125) do
		local x, y, z = at(point[1], point[2])
		table.insert(parts, { Kind = "Ball", Diameter = 0.4, X = x, Y = y + 0.1, Z = z, Color = settings.CreamColor })
		table.insert(parts, { Kind = "Ball", Diameter = 0.2, X = x, Y = y + 0.3, Z = z, Color = settings.CreamColor })
	end
	local candleSpots
	if design.Candles == 1 and not busy then
		candleSpots = { { 0, 0 } }
	else
		candleSpots = ring(design.Candles, hole > 0 and hole + 0.3 or 0.5, 0.5)
	end
	local candleColor = TreatDesign.Color(design.CandleColor) or TreatDesign.Color(settings.DefaultCandle)
	for _, point in candleSpots do
		local x, y, z = at(point[1], point[2])
		table.insert(parts, { Kind = "Disc", Height = 0.6, Diameter = 0.2, X = x, Y = y + 0.3, Z = z, Color = candleColor })
		table.insert(parts, { Kind = "Ball", Diameter = 0.25, X = x, Y = y + 0.7, Z = z, Color = settings.FlameColor })
	end
	local cherrySpots
	if design.Cherries == 1 and not busy and design.Candles ~= 1 then
		cherrySpots = { { 0, 0 } }
	else
		cherrySpots = ring(design.Cherries, hole > 0 and hole + 0.22 or 0.38, 0)
	end
	for _, point in cherrySpots do
		local x, y, z = at(point[1], point[2])
		table.insert(parts, { Kind = "Ball", Diameter = 0.42, X = x, Y = y + 0.12, Z = z, Color = settings.CherryColor })
		table.insert(parts, { Kind = "Box", Size = Vector3.new(0.04, 0.2, 0.04), X = x, Y = y + 0.4, Z = z, Color = Color3.fromRGB(90, 130, 60) })
	end

	return { Name = recipe.Name, Parts = parts }
end

-- Builds recipe recipeIndex with a design (or nil for its own look), like ItemBuilder.Build.
function TreatDesign.Build(recipeIndex, design, scale, cframe)
	return ItemBuilder.Build(TreatDesign.Definition(Config.Recipes[recipeIndex], design), scale, cframe)
end

-- Designs travel to clients as JSON in a plot's TreatDesigns attribute, keyed by recipe
-- index as text.
function TreatDesign.Encode(designs)
	local out = {}
	for index, design in designs do
		out[tostring(index)] = design
	end
	return HttpService:JSONEncode(out)
end

function TreatDesign.Decode(text)
	local designs = {}
	local ok, raw = pcall(HttpService.JSONDecode, HttpService, text or "")
	if ok and type(raw) == "table" then
		for key, design in raw do
			local index = tonumber(key)
			local recipe = index and Config.Recipes[index]
			if recipe then
				designs[index] = TreatDesign.Clean(design, recipe)
			end
		end
	end
	return designs
end

return TreatDesign
