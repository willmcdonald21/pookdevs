-- Placement rules for the grid on each bakery floor and its garden. The server checks
-- every move with these, and the client runs the same checks to colour the preview.
-- Positions are in floor space: the floor's centre is the origin and the door is at +Z.
-- A grid entry is { X, Z, R }. X and Z are the whole-number cell of the piece's corner
-- with the lowest coordinates, and R is how many quarter turns it has been rotated.
-- A wall piece's entry also has Y, the height of its bottom. Its cells are the strip along
-- the wall it hangs on, and its R makes it face away from that wall.
-- Cell 0, 0 is the back left corner of the starting bakery. A bigger bakery adds cells to
-- the left and back, which have negative numbers, so saved spots never need to change.
-- The rules take the bakery's bounds, its floor inside the walls, from Layout.Bounds.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local Layout = {}

-- Saves made before free placement have no version and are converted on load.
Layout.Version = 2

-- The starting floor inside the walls, one cell per stud.
Layout.MinX = -24
Layout.MinZ = -19
Layout.Columns = 48
Layout.Rows = 38
Layout.MaxX = Layout.MinX + Layout.Columns
Layout.MaxZ = Layout.MinZ + Layout.Rows

-- The floor inside the walls at an expansion level, where 0 is the starting size. Each
-- step moves the back wall back and the side walls out. The front never moves.
function Layout.Bounds(level)
	local back, side = 0, 0
	for index = 1, level do
		back += Config.Expansions[index].Back
		side += Config.Expansions[index].Side
	end
	return { MinX = Layout.MinX - side, MaxX = Layout.MaxX + side, MinZ = Layout.MinZ - back, MaxZ = Layout.MaxZ }
end

Layout.Start = Layout.Bounds(0)
Layout.Largest = Layout.Bounds(#Config.Expansions)

-- The Sweet Stash, a room behind the back wall that moves back with it. MinX and MaxX are
-- its inside walls, and it's Depth studs deep behind the back wall, which is 1 stud thick.
-- The door is a gap in the back wall from DoorMinX to DoorMaxX, DoorHeight tall. The
-- whiteboard hangs on the room's right wall, WhiteboardZ studs behind the back wall.
Layout.Stash = {
	MinX = -3,
	MaxX = 21,
	Depth = 14,
	Wall = 1,
	DoorMinX = 6,
	DoorMaxX = 11,
	DoorHeight = 9,
	WhiteboardZ = 6,
	WhiteboardWidth = 6,
}

-- The floor inside The Sweet Stash at an expansion level.
function Layout.StashBounds(level)
	local stash = Layout.Stash
	local maxZ = Layout.Bounds(level).MinZ - stash.Wall
	return { MinX = stash.MinX, MaxX = stash.MaxX, MinZ = maxZ - stash.Depth, MaxZ = maxZ }
end

-- The garden, the lawn around the outside of the bakery, once it's bought. It reaches Ring
-- studs past the walls of the biggest bakery at the sides and back, and out to FrontZ in
-- front. Its pieces stand on the lawn, LawnDrop studs (a plot attribute) below the floor.
-- They can go anywhere in it except where Layout.GardenThings keeps clear: the bakery as
-- big as it is now, The Sweet Stash, the path to the door, the ingredient crate's and flyer
-- stand's spots, and the town around it: the plaza, the townsfolk's ways in and out of
-- town, the grocery store and the neighbours' gardens. So a small bakery has a bigger yard,
-- until it grows. FrontWall is the outside face of the front wall, and PathHalf is half the
-- path's width, with a stud to spare each side. Spots are the crate and the flyer stand,
-- Half studs each way from their middle. Reasons says why each kind of cell in the
-- GardenMask is kept clear.
Layout.Garden = {
	Ring = 6,
	FrontZ = 30,
	FrontWall = 20,
	PathHalf = 6,
	Reasons = {
		P = "Keep the plaza clear",
		W = "Keep the townsfolk's path clear",
		G = "Keep clear of the grocery store",
		N = "That's your neighbour's garden",
	},
	Spots = {
		{ Key = "Crate", X = 9, Z = 24, Half = 2.5, Reason = "Keep the ingredient crate's spot clear" },
		{ Key = "Flyers", X = -9, Z = 24, Half = 2.5, Reason = "Keep the flyer stand's spot clear" },
	},
}

function Layout.GardenBounds()
	local largest, garden, wall = Layout.Largest, Layout.Garden, Layout.Stash.Wall
	return {
		MinX = largest.MinX - wall - garden.Ring,
		MaxX = largest.MaxX + wall + garden.Ring,
		MinZ = largest.MinZ - wall - garden.Ring,
		MaxZ = garden.FrontZ,
	}
end

-- Where an item can go: The Sweet Stash or the garden for an item with that Room, or
-- else the bakery.
function Layout.BoundsFor(item, level)
	if item.Room == "Stash" then
		return Layout.StashBounds(level)
	elseif item.Room == "Garden" then
		return Layout.GardenBounds()
	end
	return Layout.Bounds(level)
end

-- Saved and sent cells must fit in the biggest bakery, its stash or its garden.
local farthestStash = Layout.StashBounds(#Config.Expansions)
local garden = Layout.GardenBounds()
Layout.Farthest = {
	MinX = math.min(Layout.Largest.MinX, farthestStash.MinX, garden.MinX),
	MaxX = math.max(Layout.Largest.MaxX, farthestStash.MaxX, garden.MaxX),
	MinZ = math.min(farthestStash.MinZ, garden.MinZ),
	MaxZ = math.max(Layout.Largest.MaxZ, garden.MaxZ),
}

-- The CFrame a piece's cells are measured from: the floor's top, or the lawn for a garden
-- piece. plot is the bakery's model in the workspace.
function Layout.TopFor(item, floorTop, plot)
	if item.Room == "Garden" then
		return floorTop * CFrame.new(0, -(plot:GetAttribute("LawnDrop") or 0), 0)
	end
	return floorTop
end

-- Just inside the door. Solid pieces can't go here, so customers can always get in.
Layout.Entrance = { MinX = -7, MaxX = 7, MinZ = 15, MaxZ = 19 }
-- Display cases and the checkout counter keep this many cells clear in front.
Layout.FrontDepth = 3
-- Wall pieces hang on the back, left and right walls, below the trim along the top. The
-- front is a low wall under the sign, so nothing hangs there.
Layout.WallHeight = 13

-- Bakery pieces that can be moved but not stored. Path is the instance's name in the
-- plot, and Facing is the side that faces customers before any rotation.
Layout.Stations = {
	{ Id = "Oven", Name = "Oven", Path = "Oven", Facing = Vector3.zAxis },
	{ Id = "Cookbook", Name = "Cookbook Counter", Path = "UpgradeStation", Facing = Vector3.zAxis },
	{ Id = "Pantry", Name = "Pantry Shelf", Path = "PantryShelf", Facing = Vector3.xAxis },
	{ Id = "Checkout", Name = "Checkout Counter", Path = "Checkout", Facing = Vector3.zAxis, NeedsFront = true },
	{ Id = "Packing", Name = "Delivery Counter", Path = "PackingStation", Facing = Vector3.zAxis },
	-- Bought stations are only in a bakery once the owner has bought them. The save
	-- field with the station's Id is true when they have.
	{ Id = "LuxuryOven", Name = "Luxury Oven", Path = "LuxuryOven", Facing = Vector3.zAxis, Bought = true },
}

function Layout.GetStation(id)
	for _, station in Layout.Stations do
		if station.Id == id then
			return station
		end
	end
	return nil
end

-- A piece slightly bigger than its cells may hang over the edge a little.
function Layout.Cells(size)
	return math.max(1, math.ceil(size - 0.3))
end

local itemShapes = {}

-- An item's size in cells, its height, and the centre of its parts, in its own space,
-- where the front is -Z. Unrotated, it is turned to face the door. A wall item's back
-- sits on the edge of its cells, so it hangs flat against the wall.
function Layout.ItemShape(item)
	local shape = itemShapes[item.Id]
	if shape then
		return shape
	end
	local minX, maxX, minZ, maxZ, top = math.huge, -math.huge, math.huge, -math.huge, 0
	for _, spec in item.Parts do
		-- Discs are cylinders stood upright, so their Height is vertical. Plates face the
		-- front, so their Height is their depth.
		local halfX, halfZ, halfY
		if spec.Kind == "Disc" then
			halfX, halfZ, halfY = spec.Diameter / 2, spec.Diameter / 2, spec.Height / 2
		elseif spec.Kind == "Plate" then
			halfX, halfZ, halfY = spec.Diameter / 2, spec.Height / 2, spec.Diameter / 2
		elseif spec.Kind == "Ball" then
			local size = spec.Size or Vector3.one * spec.Diameter
			halfX, halfZ, halfY = size.X / 2, size.Z / 2, size.Y / 2
		else
			halfX, halfZ, halfY = spec.Size.X / 2, spec.Size.Z / 2, spec.Size.Y / 2
		end
		local x, z = spec.X or 0, spec.Z or 0
		minX = math.min(minX, x - halfX)
		maxX = math.max(maxX, x + halfX)
		minZ = math.min(minZ, z - halfZ)
		maxZ = math.max(maxZ, z + halfZ)
		top = math.max(top, spec.Y + halfY)
	end
	local depth = Layout.Cells(maxZ - minZ)
	shape = {
		W = Layout.Cells(maxX - minX),
		D = depth,
		H = top,
		CenterX = (minX + maxX) / 2,
		CenterZ = item.Wall and maxZ - depth / 2 or (minZ + maxZ) / 2,
		Facing = -Vector3.zAxis,
		BaseYaw = math.pi,
	}
	itemShapes[item.Id] = shape
	return shape
end

-- The server measures each station when it starts and stores its size on it.
function Layout.StationShape(station, instance)
	local w, d, h = instance:GetAttribute("FootW"), instance:GetAttribute("FootD"), instance:GetAttribute("FootH")
	if not w or not d or not h then
		return nil
	end
	return { W = w, D = d, H = h, CenterX = 0, CenterZ = 0, Facing = station.Facing, BaseYaw = 0 }
end

local function turnedSize(shape, r)
	if r % 2 == 1 then
		return shape.D, shape.W
	end
	return shape.W, shape.D
end

function Layout.Rect(shape, entry)
	local w, d = turnedSize(shape, entry.R)
	local minX = Layout.MinX + entry.X
	local minZ = Layout.MinZ + entry.Z
	return { MinX = minX, MaxX = minX + w, MinZ = minZ, MaxZ = minZ + d }
end

function Layout.Center(rect)
	return Vector3.new((rect.MinX + rect.MaxX) / 2, 0, (rect.MinZ + rect.MaxZ) / 2)
end

function Layout.Yaw(shape, r)
	return shape.BaseYaw - r * math.pi / 2
end

-- The way a piece faces on the floor, as a unit vector along X or Z.
function Layout.Facing(shape, r)
	local facing = CFrame.Angles(0, Layout.Yaw(shape, r), 0):VectorToWorldSpace(shape.Facing)
	return Vector3.new(math.round(facing.X), 0, math.round(facing.Z))
end

function Layout.FrontRect(rect, facing)
	local depth = Layout.FrontDepth
	if facing.X > 0 then
		return { MinX = rect.MaxX, MaxX = rect.MaxX + depth, MinZ = rect.MinZ, MaxZ = rect.MaxZ }
	elseif facing.X < 0 then
		return { MinX = rect.MinX - depth, MaxX = rect.MinX, MinZ = rect.MinZ, MaxZ = rect.MaxZ }
	elseif facing.Z > 0 then
		return { MinX = rect.MinX, MaxX = rect.MaxX, MinZ = rect.MaxZ, MaxZ = rect.MaxZ + depth }
	end
	return { MinX = rect.MinX, MaxX = rect.MaxX, MinZ = rect.MinZ - depth, MaxZ = rect.MinZ }
end

-- Where a piece's own origin goes so its parts sit centred on its cells, lifted to its
-- height on the wall. floorTop is the floor's CFrame moved up to its top surface.
function Layout.CFrame(floorTop, shape, entry)
	local center = Layout.Center(Layout.Rect(shape, entry)) + Vector3.new(0, entry.Y or 0, 0)
	return floorTop
		* CFrame.new(center)
		* CFrame.Angles(0, Layout.Yaw(shape, entry.R), 0)
		* CFrame.new(-shape.CenterX, 0, -shape.CenterZ)
end

-- The entry that puts the piece's centre as near as the grid allows to a floor point,
-- kept inside the walls.
function Layout.EntryAt(shape, point, r, bounds)
	bounds = bounds or Layout.Start
	local w, d = turnedSize(shape, r)
	return {
		X = math.clamp(math.round(point.X - w / 2), bounds.MinX, bounds.MaxX - w) - Layout.MinX,
		Z = math.clamp(math.round(point.Z - d / 2), bounds.MinZ, bounds.MaxZ - d) - Layout.MinZ,
		R = r,
	}
end

-- One quarter turn, keeping the piece where it was.
function Layout.Rotated(shape, entry, bounds)
	return Layout.EntryAt(shape, Layout.Center(Layout.Rect(shape, entry)), (entry.R + 1) % 4, bounds)
end

-- The wall entry that puts a wall piece's centre as near as it can to a point, on the
-- nearest of the back (R 0), right (R 1) and left (R 3) walls. point is in floor space,
-- with Y the height above the floor.
function Layout.WallEntryAt(shape, point, bounds)
	bounds = bounds or Layout.Start
	local toBack, toLeft, toRight = point.Z - bounds.MinZ, point.X - bounds.MinX, bounds.MaxX - point.X
	local r = 3
	if toBack <= toLeft and toBack <= toRight then
		r = 0
	elseif toRight <= toLeft then
		r = 1
	end
	local entry = Layout.EntryAt(shape, point, r, bounds)
	if r == 0 then
		entry.Z = bounds.MinZ - Layout.MinZ
	elseif r == 1 then
		entry.X = bounds.MaxX - shape.D - Layout.MinX
	else
		entry.X = bounds.MinX - Layout.MinX
	end
	local highest = math.max(0, math.floor(Layout.WallHeight - shape.H))
	entry.Y = math.clamp(math.round(point.Y - shape.H / 2), 0, highest)
	return entry
end

-- Turns saved or sent values into an entry, or nil when they aren't whole numbers inside
-- the biggest bakery, its stash or its garden. y is only given for wall pieces.
function Layout.CleanEntry(x, z, r, y)
	if type(x) ~= "number" or type(z) ~= "number" or type(r) ~= "number" then
		return nil
	end
	if x % 1 ~= 0 or z % 1 ~= 0 or r % 1 ~= 0 then
		return nil
	end
	local largest = Layout.Farthest
	local inX = x >= largest.MinX - Layout.MinX and x < largest.MaxX - Layout.MinX
	local inZ = z >= largest.MinZ - Layout.MinZ and z < largest.MaxZ - Layout.MinZ
	if not inX or not inZ or r < 0 or r > 3 then
		return nil
	end
	if y ~= nil and (type(y) ~= "number" or y % 1 ~= 0 or y < 0 or y >= Layout.WallHeight) then
		return nil
	end
	return { X = x, Z = z, R = r, Y = y }
end

local function describe(key, name, shape, entry, flat, needsFront, wall)
	local rect = Layout.Rect(shape, entry)
	local facing = Layout.Facing(shape, entry.R)
	return {
		Key = key,
		Name = name,
		Rect = rect,
		Bottom = entry.Y or 0,
		Height = shape.H,
		Facing = facing,
		Flat = flat,
		Wall = wall,
		Front = needsFront and Layout.FrontRect(rect, facing) or nil,
	}
end

-- A piece as the placement rules see it. entry.Id is the item's Id.
function Layout.ItemThing(key, entry)
	local item = Config.GetItem(entry.Id)
	local thing = describe(key, item.Name, Layout.ItemShape(item), entry, item.Flat == true, item.Slots ~= nil, item.Wall == true)
	thing.Room = item.Room
	return thing
end

function Layout.StationThing(station, shape, entry)
	return describe(station.Id, station.Name, shape, entry, false, station.NeedsFront == true, false)
end

-- Every piece in a bakery. stationShapes maps each station Id to its shape.
function Layout.AllThings(placed, stations, stationShapes)
	local things = {}
	for key, entry in placed do
		table.insert(things, Layout.ItemThing(key, entry))
	end
	for _, station in Layout.Stations do
		local entry, shape = stations[station.Id], stationShapes[station.Id]
		if entry and shape then
			table.insert(things, Layout.StationThing(station, shape, entry))
		end
	end
	return things
end

-- The parts of The Sweet Stash that nothing can be put on, as things for Check: the
-- doorway on both sides of the back wall, all the way up so no wall piece hangs over the
-- door, and the whiteboard with room to stand in front of it.
function Layout.StashThings(level)
	local stash, bounds, room = Layout.Stash, Layout.Bounds(level), Layout.StashBounds(level)
	local function fixed(key, name, rect, reason)
		return { Key = key, Name = name, Rect = rect, Bottom = 0, Height = Layout.WallHeight, Reason = reason }
	end
	local doorway = { MinX = stash.DoorMinX - 1, MaxX = stash.DoorMaxX + 1 }
	local reason = ("Keep the door to %s clear"):format(Config.Stash.Name)
	local whiteboardMaxZ = room.MaxZ - stash.WhiteboardZ + stash.WhiteboardWidth / 2
	return {
		fixed("StashDoor", "Stash door", {
			MinX = doorway.MinX,
			MaxX = doorway.MaxX,
			MinZ = bounds.MinZ,
			MaxZ = bounds.MinZ + Layout.FrontDepth,
		}, reason),
		fixed("StashDoorInside", "Stash door", {
			MinX = doorway.MinX,
			MaxX = doorway.MaxX,
			MinZ = room.MaxZ - Layout.FrontDepth,
			MaxZ = room.MaxZ,
		}, reason),
		fixed("Whiteboard", "Whiteboard", {
			MinX = room.MaxX - 1 - Layout.FrontDepth,
			MaxX = room.MaxX,
			MinZ = whiteboardMaxZ - stash.WhiteboardWidth,
			MaxZ = whiteboardMaxZ,
		}, "Keep the whiteboard clear"),
	}
end

-- What garden pieces can't go on, as things for Check: the bakery at its size now, walls
-- included, The Sweet Stash's room when stashBought, the path, the crate's and flyer
-- stand's spots, and the town around the bakery (plot is its model). The server works out
-- which cells of the garden the town needs, once, and stores them on the plot as the
-- GardenMask attribute: runs of cells down each column, "x,minZ,maxZ,Kind;" with a Kind
-- from Layout.Garden.Reasons, like W for the townsfolk's way in and out of town.
function Layout.GardenThings(level, stashBought, plot)
	local bounds, garden, wall = Layout.Bounds(level), Layout.Garden, Layout.Stash.Wall
	local area = Layout.GardenBounds()
	local function fixed(key, rect, reason)
		return { Key = key, Name = key, Rect = rect, Bottom = -1, Height = 100, Reason = reason }
	end
	local things = {
		fixed("Bakery", {
			MinX = bounds.MinX - wall,
			MaxX = bounds.MaxX + wall,
			MinZ = bounds.MinZ - wall,
			MaxZ = garden.FrontWall,
		}, "Keep it out of your bakery"),
		fixed("Path", {
			MinX = -garden.PathHalf,
			MaxX = garden.PathHalf,
			MinZ = garden.FrontWall,
			MaxZ = area.MaxZ,
		}, "Keep the path clear for customers"),
	}
	for _, spot in garden.Spots do
		table.insert(things, fixed(spot.Key, {
			MinX = spot.X - spot.Half,
			MaxX = spot.X + spot.Half,
			MinZ = spot.Z - spot.Half,
			MaxZ = spot.Z + spot.Half,
		}, spot.Reason))
	end
	if stashBought then
		local room = Layout.StashBounds(level)
		table.insert(things, fixed("Stash", {
			MinX = room.MinX - wall,
			MaxX = room.MaxX + wall,
			MinZ = room.MinZ - wall,
			MaxZ = room.MaxZ,
		}, ("Keep it off %s"):format(Config.Stash.Name)))
	end
	local mask = plot and plot:GetAttribute("GardenMask") or ""
	for x, minZ, maxZ, kind in mask:gmatch("(%-?%d+),(%-?%d+),(%-?%d+),(%a)") do
		local rect = { MinX = tonumber(x), MaxX = tonumber(x) + 1, MinZ = tonumber(minZ), MaxZ = tonumber(maxZ) }
		table.insert(things, fixed(kind, rect, garden.Reasons[kind]))
	end
	return things
end

local function overlaps(a, b)
	return a.MinX < b.MaxX and b.MinX < a.MaxX and a.MinZ < b.MaxZ and b.MinZ < a.MaxZ
end

function Layout.Inside(rect, bounds)
	return rect.MinX >= bounds.MinX and rect.MaxX <= bounds.MaxX and rect.MinZ >= bounds.MinZ and rect.MaxZ <= bounds.MaxZ
end

local function overlapsHeight(a, b)
	return a.Bottom < b.Bottom + b.Height and b.Bottom < a.Bottom + a.Height
end

-- True when a wall piece is inside the bakery, against the wall it faces away from, and
-- below the trim.
function Layout.OnWall(thing, bounds)
	bounds = bounds or Layout.Start
	local rect, facing = thing.Rect, thing.Facing
	local against = (facing.Z > 0 and rect.MinZ == bounds.MinZ)
		or (facing.X < 0 and rect.MaxX == bounds.MaxX)
		or (facing.X > 0 and rect.MinX == bounds.MinX)
	return against
		and Layout.Inside(rect, bounds)
		and thing.Bottom >= 0
		and thing.Bottom + thing.Height <= Layout.WallHeight
end

local function roomInFront(name)
	return ("Customers need room in front of the %s"):format(name:lower())
end

local function inTheWay(thing, other)
	if thing.Wall and not other.Wall and other.Bottom + other.Height + thing.Height <= Layout.WallHeight then
		return ("Hang it above the %s"):format(other.Name:lower())
	elseif thing.Wall or other.Wall then
		return ("The %s is in the way"):format(other.Name:lower())
	end
	return "Something's in the way"
end

-- Returns true when the piece fits among the others, or false and a reason to show.
-- Rugs only clash with other rugs, so they can go under furniture and in the doorway.
-- Solid pieces clash where their cells and their heights overlap, so a wall piece can
-- hang above furniture. Wall pieces are up out of the way of the doorway and customers.
-- A thing with a Reason, like the stash door, gives that reason when something is on it.
function Layout.Check(thing, others, bounds)
	bounds = bounds or Layout.Start
	if not Layout.Inside(thing.Rect, bounds) then
		if thing.Room == "Stash" then
			return false, ("Put the %s in %s"):format(thing.Name:lower(), Config.Stash.Name)
		elseif thing.Room == "Garden" then
			return false, "Keep it in your garden"
		end
		return false, "Keep it inside your bakery"
	end
	if thing.Wall and not Layout.OnWall(thing, bounds) then
		return false, "Hang it on the back or side walls"
	end
	if thing.Front and not Layout.Inside(thing.Front, bounds) then
		return false, roomInFront(thing.Name)
	end
	if not thing.Flat and not thing.Wall and thing.Room ~= "Garden" and overlaps(thing.Rect, Layout.Entrance) then
		return false, "Keep the doorway clear for customers"
	end
	for _, other in others do
		if other.Key ~= thing.Key then
			if thing.Flat then
				if other.Flat and overlaps(thing.Rect, other.Rect) then
					return false, "There's already a rug there"
				end
			elseif not other.Flat then
				if overlaps(thing.Rect, other.Rect) and overlapsHeight(thing, other) then
					return false, other.Reason or inTheWay(thing, other)
				end
				if not thing.Wall and not other.Wall then
					if other.Front and overlaps(thing.Rect, other.Front) then
						return false, roomInFront(other.Name)
					end
					if thing.Front and overlaps(thing.Front, other.Rect) then
						return false, roomInFront(thing.Name)
					end
				end
			end
		end
	end
	return true
end

-- Floor tiles. The floor is a grid of TileSize-stud squares, each laid in its own style.
-- Tile i, j starts TileSize * i studs right of MinX and TileSize * j studs in front of
-- MinZ, so tiles line up with the middle of the floor and the starting back wall, and
-- never move as the bakery grows. Tiles at the walls are cut to fit. Keys are "i,j".
Layout.TileSize = 4

function Layout.TileKey(i, j)
	return i .. "," .. j
end

-- The i and j in a key, or nil when it isn't one.
function Layout.TileOfKey(key)
	if type(key) ~= "string" then
		return nil
	end
	local i, j = key:match("^(%-?%d+),(%-?%d+)$")
	if not i then
		return nil
	end
	return tonumber(i), tonumber(j)
end

-- Tile i, j's square, cut to fit inside the walls, or nil when it's outside them.
function Layout.TileRect(i, j, bounds)
	local size = Layout.TileSize
	local rect = {
		MinX = math.max(Layout.MinX + i * size, bounds.MinX),
		MaxX = math.min(Layout.MinX + (i + 1) * size, bounds.MaxX),
		MinZ = math.max(Layout.MinZ + j * size, bounds.MinZ),
		MaxZ = math.min(Layout.MinZ + (j + 1) * size, bounds.MaxZ),
	}
	if rect.MinX >= rect.MaxX or rect.MinZ >= rect.MaxZ then
		return nil
	end
	return rect
end

local function tile(i, j, bounds)
	local rect = Layout.TileRect(i, j, bounds)
	return rect and { Key = Layout.TileKey(i, j), I = i, J = j, Rect = rect }
end

-- The tile at a floor point, as { Key, I, J, Rect }, or nil outside the walls.
function Layout.TileAt(point, bounds)
	local size = Layout.TileSize
	return tile(math.floor((point.X - Layout.MinX) / size), math.floor((point.Z - Layout.MinZ) / size), bounds)
end

-- Every tile inside the walls, from the back left.
function Layout.Tiles(bounds)
	local size = Layout.TileSize
	local tiles = {}
	for j = math.floor((bounds.MinZ - Layout.MinZ) / size), math.ceil((bounds.MaxZ - Layout.MinZ) / size) - 1 do
		for i = math.floor((bounds.MinX - Layout.MinX) / size), math.ceil((bounds.MaxX - Layout.MinX) / size) - 1 do
			table.insert(tiles, tile(i, j, bounds))
		end
	end
	return tiles
end

return Layout
