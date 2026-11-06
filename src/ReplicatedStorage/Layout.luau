-- Placement rules for the grid on each bakery floor. The server checks every move with
-- these, and the client runs the same checks to colour the preview.
-- Positions are in floor space: the floor's centre is the origin and the door is at +Z.
-- A grid entry is { X, Z, R }. X and Z are the whole-number cell of the piece's corner
-- with the lowest coordinates, and R is how many quarter turns it has been rotated.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local Layout = {}

-- Saves made before free placement have no version and are converted on load.
Layout.Version = 2

-- The floor inside the walls, one cell per stud.
Layout.MinX = -24
Layout.MinZ = -19
Layout.Columns = 48
Layout.Rows = 38
Layout.MaxX = Layout.MinX + Layout.Columns
Layout.MaxZ = Layout.MinZ + Layout.Rows

-- Just inside the door. Solid pieces can't go here, so customers can always get in.
Layout.Entrance = { MinX = -7, MaxX = 7, MinZ = 15, MaxZ = 19 }
-- Display cases and the checkout counter keep this many cells clear in front.
Layout.FrontDepth = 3

-- Bakery pieces that can be moved but not stored. Path is the instance's name in the
-- plot, and Facing is the side that faces customers before any rotation.
Layout.Stations = {
	{ Id = "Oven", Name = "Oven", Path = "Oven", Facing = Vector3.zAxis },
	{ Id = "Cookbook", Name = "Cookbook Counter", Path = "UpgradeStation", Facing = Vector3.zAxis },
	{ Id = "Pantry", Name = "Pantry Shelf", Path = "PantryShelf", Facing = Vector3.xAxis },
	{ Id = "Checkout", Name = "Checkout Counter", Path = "Checkout", Facing = Vector3.zAxis, NeedsFront = true },
	{ Id = "Packing", Name = "Delivery Counter", Path = "PackingStation", Facing = Vector3.zAxis },
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
-- where the front is -Z. Unrotated, it is turned to face the door.
function Layout.ItemShape(item)
	local shape = itemShapes[item.Id]
	if shape then
		return shape
	end
	local minX, maxX, minZ, maxZ, top = math.huge, -math.huge, math.huge, -math.huge, 0
	for _, spec in item.Parts do
		-- Discs are cylinders stood upright, so their Height is vertical.
		local halfX, halfZ, halfY
		if spec.Kind == "Disc" then
			halfX, halfZ, halfY = spec.Diameter / 2, spec.Diameter / 2, spec.Height / 2
		elseif spec.Kind == "Ball" then
			halfX, halfZ, halfY = spec.Diameter / 2, spec.Diameter / 2, spec.Diameter / 2
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
	shape = {
		W = Layout.Cells(maxX - minX),
		D = Layout.Cells(maxZ - minZ),
		H = top,
		CenterX = (minX + maxX) / 2,
		CenterZ = (minZ + maxZ) / 2,
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

-- Where a piece's own origin goes so its parts sit centred on its cells. floorTop is
-- the floor's CFrame moved up to its top surface.
function Layout.CFrame(floorTop, shape, entry)
	local center = Layout.Center(Layout.Rect(shape, entry))
	return floorTop
		* CFrame.new(center)
		* CFrame.Angles(0, Layout.Yaw(shape, entry.R), 0)
		* CFrame.new(-shape.CenterX, 0, -shape.CenterZ)
end

-- The entry that puts the piece's centre as near as the grid allows to a floor point,
-- kept inside the walls.
function Layout.EntryAt(shape, point, r)
	local w, d = turnedSize(shape, r)
	return {
		X = math.clamp(math.round(point.X - w / 2 - Layout.MinX), 0, Layout.Columns - w),
		Z = math.clamp(math.round(point.Z - d / 2 - Layout.MinZ), 0, Layout.Rows - d),
		R = r,
	}
end

-- One quarter turn, keeping the piece where it was.
function Layout.Rotated(shape, entry)
	return Layout.EntryAt(shape, Layout.Center(Layout.Rect(shape, entry)), (entry.R + 1) % 4)
end

-- Turns saved or sent values into an entry, or nil when they aren't whole numbers in range.
function Layout.CleanEntry(x, z, r)
	if type(x) ~= "number" or type(z) ~= "number" or type(r) ~= "number" then
		return nil
	end
	if x % 1 ~= 0 or z % 1 ~= 0 or r % 1 ~= 0 then
		return nil
	end
	if x < 0 or x >= Layout.Columns or z < 0 or z >= Layout.Rows or r < 0 or r > 3 then
		return nil
	end
	return { X = x, Z = z, R = r }
end

local function describe(key, name, shape, entry, flat, needsFront)
	local rect = Layout.Rect(shape, entry)
	local facing = Layout.Facing(shape, entry.R)
	return {
		Key = key,
		Name = name,
		Rect = rect,
		Height = shape.H,
		Facing = facing,
		Flat = flat,
		Front = needsFront and Layout.FrontRect(rect, facing) or nil,
	}
end

-- A piece as the placement rules see it. entry.Id is the item's Id.
function Layout.ItemThing(key, entry)
	local item = Config.GetItem(entry.Id)
	return describe(key, item.Name, Layout.ItemShape(item), entry, item.Flat == true, item.Slots ~= nil)
end

function Layout.StationThing(station, shape, entry)
	return describe(station.Id, station.Name, shape, entry, false, station.NeedsFront == true)
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

local function overlaps(a, b)
	return a.MinX < b.MaxX and b.MinX < a.MaxX and a.MinZ < b.MaxZ and b.MinZ < a.MaxZ
end

local function inside(rect)
	return rect.MinX >= Layout.MinX and rect.MaxX <= Layout.MaxX and rect.MinZ >= Layout.MinZ and rect.MaxZ <= Layout.MaxZ
end

local function roomInFront(name)
	return ("Customers need room in front of the %s"):format(name:lower())
end

-- Returns true when the piece fits among the others, or false and a reason to show.
-- Rugs only clash with other rugs, so they can go under furniture and in the doorway.
function Layout.Check(thing, others)
	if not inside(thing.Rect) then
		return false, "Keep it inside your bakery"
	end
	if thing.Front and not inside(thing.Front) then
		return false, roomInFront(thing.Name)
	end
	if not thing.Flat and overlaps(thing.Rect, Layout.Entrance) then
		return false, "Keep the doorway clear for customers"
	end
	for _, other in others do
		if other.Key ~= thing.Key then
			if thing.Flat then
				if other.Flat and overlaps(thing.Rect, other.Rect) then
					return false, "There's already a rug there"
				end
			elseif not other.Flat then
				if overlaps(thing.Rect, other.Rect) then
					return false, "Something's in the way"
				end
				if other.Front and overlaps(thing.Rect, other.Front) then
					return false, roomInFront(other.Name)
				end
				if thing.Front and overlaps(thing.Front, other.Rect) then
					return false, roomInFront(thing.Name)
				end
			end
		end
	end
	return true
end

return Layout
