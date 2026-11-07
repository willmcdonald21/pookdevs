-- Every tunable game value lives here.
local Config = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Ingredients. A recipe's Ingredients are used once per batch, whatever the batch size.
-- BundlePrice is the grocery price for Config.GroceryBundle of them. Parts draw a small
-- model for shelves, crates and menus.
Config.Ingredients = {
	{
		Id = "Flour",
		Name = "Flour",
		Color = rgb(245, 235, 215),
		BundlePrice = 4,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(1.4, 1.8, 1), Y = 0.9, Color = rgb(245, 235, 215), Material = Enum.Material.Fabric },
			{ Kind = "Box", Size = Vector3.new(1.42, 0.5, 1.02), Y = 1.1, Color = rgb(110, 175, 215) },
		},
	},
	{
		Id = "Sugar",
		Name = "Sugar",
		Color = rgb(255, 255, 255),
		BundlePrice = 4,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(1.3, 1.6, 0.9), Y = 0.8, Color = rgb(255, 255, 255), Material = Enum.Material.Fabric },
			{ Kind = "Box", Size = Vector3.new(1.32, 0.45, 0.92), Y = 1, Color = rgb(240, 150, 175) },
		},
	},
	{
		Id = "Eggs",
		Name = "Eggs",
		Color = rgb(250, 235, 205),
		BundlePrice = 6,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(1.6, 0.5, 1), Y = 0.25, Color = rgb(200, 185, 165) },
			{ Kind = "Ball", Diameter = 0.45, X = -0.4, Y = 0.6, Z = -0.2, Color = rgb(250, 235, 205) },
			{ Kind = "Ball", Diameter = 0.45, X = 0.1, Y = 0.6, Z = 0.2, Color = rgb(250, 235, 205) },
			{ Kind = "Ball", Diameter = 0.45, X = 0.5, Y = 0.6, Z = -0.15, Color = rgb(250, 235, 205) },
		},
	},
	{
		Id = "Butter",
		Name = "Butter",
		Color = rgb(255, 220, 110),
		BundlePrice = 6,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(1.4, 0.15, 0.9), Y = 0.08, Color = rgb(230, 230, 235) },
			{ Kind = "Box", Size = Vector3.new(1.1, 0.55, 0.6), Y = 0.42, Color = rgb(255, 220, 110) },
		},
	},
	{
		Id = "Milk",
		Name = "Milk",
		Color = rgb(235, 245, 255),
		BundlePrice = 6,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(0.9, 1.6, 0.9), Y = 0.8, Color = rgb(240, 248, 255) },
			{ Kind = "Box", Size = Vector3.new(0.92, 0.5, 0.92), Y = 0.9, Color = rgb(110, 175, 215) },
			{ Kind = "Box", Size = Vector3.new(0.5, 0.35, 0.5), Y = 1.75, Color = rgb(240, 248, 255) },
		},
	},
	{
		Id = "Berries",
		Name = "Berries",
		Color = rgb(200, 40, 80),
		BundlePrice = 8,
		Parts = {
			{ Kind = "Disc", Height = 0.5, Diameter = 1.5, Y = 0.25, Color = rgb(190, 140, 90), Material = Enum.Material.WoodPlanks },
			{ Kind = "Ball", Diameter = 0.45, X = -0.3, Y = 0.6, Color = rgb(200, 40, 80) },
			{ Kind = "Ball", Diameter = 0.45, X = 0.3, Y = 0.6, Z = 0.1, Color = rgb(120, 60, 160) },
			{ Kind = "Ball", Diameter = 0.45, Y = 0.65, Z = -0.3, Color = rgb(200, 40, 80) },
		},
	},
}

function Config.GetIngredient(id)
	for _, ingredient in Config.Ingredients do
		if ingredient.Id == id then
			return ingredient
		end
	end
	return nil
end

-- Ingredients for a recipe as text, in Config.Ingredients order, like "Flour 1, Sugar 1".
function Config.DescribeIngredients(needs)
	local parts = {}
	for _, ingredient in Config.Ingredients do
		local count = needs[ingredient.Id]
		if count then
			table.insert(parts, ("%s %d"):format(ingredient.Name, count))
		end
	end
	return table.concat(parts, ", ")
end

Config.StartingPantry = 15
Config.GroceryBundle = 5
-- A free crate of Size ingredients arrives outside the door every Interval seconds.
Config.Crate = { Interval = 90, Size = 12 }

-- Recipes unlock in this order. BakeScale multiplies the oven's bake time.
Config.Recipes = {
	{
		Name = "Cookie",
		Price = 4,
		BakeScale = 1,
		UnlockCost = 0,
		Ingredients = { Flour = 1, Sugar = 1, Butter = 1 },
		Parts = {
			{ Kind = "Disc", Height = 0.4, Diameter = 2, Y = 0, Color = rgb(190, 130, 75) },
			{ Kind = "Ball", Diameter = 0.35, X = 0.4, Y = 0.2, Color = rgb(70, 40, 30) },
			{ Kind = "Ball", Diameter = 0.35, X = -0.4, Y = 0.2, Z = 0.3, Color = rgb(70, 40, 30) },
		},
	},
	{
		Name = "Cupcake",
		Price = 8,
		BakeScale = 1.3,
		UnlockCost = 100,
		Ingredients = { Flour = 1, Sugar = 1, Eggs = 1, Milk = 1 },
		Parts = {
			{ Kind = "Disc", Height = 0.8, Diameter = 1.5, Y = 0, Color = rgb(190, 130, 75) },
			{ Kind = "Ball", Diameter = 1.6, Y = 0.7, Color = rgb(255, 180, 205) },
			{ Kind = "Ball", Diameter = 0.45, Y = 1.5, Color = rgb(215, 50, 70) },
		},
	},
	{
		Name = "Donut",
		Price = 18,
		BakeScale = 1.6,
		UnlockCost = 500,
		Ingredients = { Flour = 2, Sugar = 1, Eggs = 1, Milk = 1 },
		Parts = {
			{ Kind = "Disc", Height = 0.6, Diameter = 2, Y = 0, Color = rgb(215, 160, 95) },
			{ Kind = "Disc", Height = 0.15, Diameter = 1.9, Y = 0.35, Color = rgb(255, 150, 190) },
			{ Kind = "Disc", Height = 0.2, Diameter = 0.6, Y = 0.38, Color = rgb(90, 60, 70) },
		},
	},
	{
		Name = "Pie",
		Price = 35,
		BakeScale = 2,
		UnlockCost = 2500,
		Ingredients = { Flour = 2, Butter = 1, Berries = 2 },
		Parts = {
			{ Kind = "Disc", Height = 0.6, Diameter = 2.4, Y = 0, Color = rgb(225, 175, 110) },
			{ Kind = "Disc", Height = 0.15, Diameter = 1.9, Y = 0.33, Color = rgb(170, 40, 70) },
		},
	},
	{
		Name = "Birthday Cake",
		Price = 70,
		BakeScale = 2.5,
		UnlockCost = 10000,
		Ingredients = { Flour = 2, Sugar = 2, Eggs = 2, Butter = 1, Milk = 1 },
		Parts = {
			{ Kind = "Disc", Height = 0.9, Diameter = 2.4, Y = 0, Color = rgb(255, 180, 205) },
			{ Kind = "Disc", Height = 0.25, Diameter = 2.5, Y = 0.55, Color = rgb(255, 245, 230) },
			{ Kind = "Disc", Height = 0.6, Diameter = 0.2, Y = 0.95, Color = rgb(130, 200, 215) },
			{ Kind = "Ball", Diameter = 0.25, Y = 1.35, Color = rgb(255, 190, 60) },
		},
	},
}

-- How fast players move. The Walk/Run switch beside the hotbar picks one.
Config.WalkSpeed = 16
Config.RunSpeed = 28

-- Level 1 of each upgrade is free. Cost is the price of reaching that level.
Config.Upgrades = {
	{
		Id = "Oven",
		Name = "Faster Oven",
		Levels = {
			{ BakeTime = 5 },
			{ BakeTime = 3.5, Cost = 25 },
			{ BakeTime = 2.5, Cost = 150 },
			{ BakeTime = 1.5, Cost = 800 },
		},
		Describe = function(level)
			return ("Cookies bake in %s seconds"):format(level.BakeTime)
		end,
	},
	{
		Id = "Batch",
		Name = "Bigger Batches",
		Levels = {
			{ BatchSize = 2 },
			{ BatchSize = 3, Cost = 50 },
			{ BatchSize = 4, Cost = 400 },
			{ BatchSize = 6, Cost = 2000 },
		},
		Describe = function(level)
			return ("Bake %d treats at a time"):format(level.BatchSize)
		end,
	},
	{
		Id = "Tray",
		Name = "Bigger Tray",
		Levels = {
			{ Capacity = 8 },
			{ Capacity = 12, Cost = 40 },
			{ Capacity = 16, Cost = 250 },
			{ Capacity = 24, Cost = 1200 },
		},
		Describe = function(level)
			return ("Carry %d treats"):format(level.Capacity)
		end,
	},
	{
		Id = "Pantry",
		Name = "Bigger Pantry",
		Levels = {
			{ Capacity = 30 },
			{ Capacity = 50, Cost = 150 },
			{ Capacity = 80, Cost = 800 },
			{ Capacity = 120, Cost = 3000 },
		},
		Describe = function(level)
			return ("Store %d of each ingredient"):format(level.Capacity)
		end,
	},
	{
		Id = "Ingredients",
		Name = "Better Ingredients",
		Levels = {
			{ PriceBonus = 0 },
			{ PriceBonus = 0.25, Cost = 200 },
			{ PriceBonus = 0.5, Cost = 1500 },
			{ PriceBonus = 1, Cost = 6000 },
		},
		Describe = function(level)
			return ("Everything sells for %d%% more"):format(level.PriceBonus * 100)
		end,
	},
	-- Helpers: level 1 means not hired. Delay is how long they wait before working.
	{
		-- Helpers walk to do their jobs, so each level makes them walk faster. Customers walk
		-- at CustomerSpeed and you start at 16.
		Id = "Baker",
		Name = "Baker Helper",
		Levels = {
			{},
			{ WalkSpeed = 10, Cost = 2000 },
			{ WalkSpeed = 18, Cost = 6000 },
		},
		Describe = function(level)
			if not level.WalkSpeed then
				return "Not hired yet"
			end
			return ("Fetches ingredients and bakes a random treat you have them for. Walks at speed %d"):format(level.WalkSpeed)
		end,
	},
	{
		Id = "Stocker",
		Name = "Stocker Helper",
		Levels = {
			{},
			{ WalkSpeed = 10, Cost = 3500 },
			{ WalkSpeed = 18, Cost = 9000 },
		},
		Describe = function(level)
			if not level.WalkSpeed then
				return "Not hired yet"
			end
			return ("Carries finished batches to your cases. Walks at speed %d"):format(level.WalkSpeed)
		end,
	},
}

function Config.GetUpgrade(id)
	for _, upgrade in Config.Upgrades do
		if upgrade.Id == id then
			return upgrade
		end
	end
	return nil
end

-- Placeable items. Costs are in Coins or Stars. Part positions are relative to the
-- item's origin on the floor, and the front is -Z. Display cases hold treats at their Slots.
-- An item with OnlyFor = { userId, ... } is a free gift for those accounts, and
-- nobody else can see or get it. An item with Pass = "<pass Id>" comes with that
-- game pass, and everyone can see it in the Decorate menu. If it has ExtraCoins, the
-- pass's owners can buy more for that many coins each, but only one copy adds Charm.
-- An item with Wall = true hangs on a wall and shows in the Decorate menu's Wall tab.
-- Its origin is on the wall at the item's bottom, and its parts stick out toward -Z.
-- On a display case, parts with Paint = true take the colour the owner paints it.
local CASE_PINK = rgb(240, 150, 175)
local GLASS = rgb(210, 235, 245)

-- Display cases hold one row of three treats on each shelf, so every treat shows through
-- the glass. Shelves are SHELF_GAP studs apart, above a cabinet base studs tall, and the
-- tallest treat at case size is about 1.1 studs. The cabinet is the first part, because a
-- case's first part holds its Stock prompt.
local SHELF_GAP = 1.5

local function displayCase(item, shelves, base)
	local glassTop = base + shelves * SHELF_GAP - 0.2
	item.Slots = {}
	item.Parts = {
		{ Kind = "Box", Size = Vector3.new(4.6, base, 2.8), Y = base / 2, Color = CASE_PINK, Paint = true },
	}
	for shelf = 1, shelves do
		local surface = base + (shelf - 1) * SHELF_GAP
		if shelf > 1 then
			table.insert(item.Parts, {
				Kind = "Box",
				Size = Vector3.new(4.6, 0.2, 2.8),
				Y = surface - 0.1,
				Color = CASE_PINK,
				Paint = true,
				Transparency = 0.5,
			})
		end
		-- Treats sink up to a quarter stud below their slot, so slots sit that far above the shelf.
		for _, x in { -1.4, 0, 1.4 } do
			table.insert(item.Slots, Vector3.new(x, surface + 0.25, 0))
		end
	end
	table.insert(item.Parts, {
		Kind = "Box",
		Size = Vector3.new(4.6, glassTop - base, 2.8),
		Y = (base + glassTop) / 2,
		Color = GLASS,
		Material = Enum.Material.Glass,
		Transparency = 0.75,
	})
	table.insert(item.Parts, {
		Kind = "Box",
		Size = Vector3.new(4.8, 0.25, 3),
		Y = glassTop + 0.1,
		Color = CASE_PINK,
		Paint = true,
		Transparency = 0.5,
	})
	return item
end

Config.Items = {
	-- Two shelves of three, the same height as before.
	displayCase({ Id = "SmallCase", Name = "Display Case", Coins = 100, Charm = 0 }, 2, 2.2),
	-- Four shelves of three. It stays under 7 studs, so wall pieces hung above it still fit.
	displayCase({ Id = "BigCase", Name = "Tall Display Case", Coins = 800, Charm = 1 }, 4, 0.9),
	{
		Id = "Rug",
		Name = "Cozy Rug",
		Coins = 60,
		Charm = 1,
		Flat = true,
		Parts = {
			{ Kind = "Disc", Height = 0.12, Diameter = 4.8, Y = 0.1, Color = rgb(235, 120, 150) },
			{ Kind = "Disc", Height = 0.12, Diameter = 3, Y = 0.14, Color = rgb(255, 225, 200) },
		},
	},
	{
		Id = "Plant",
		Name = "Potted Plant",
		Coins = 50,
		Charm = 1,
		Parts = {
			{ Kind = "Disc", Height = 1.6, Diameter = 1.8, Y = 0.8, Color = rgb(200, 120, 90) },
			{ Kind = "Ball", Diameter = 3, Y = 3, Color = rgb(110, 185, 110) },
			{ Kind = "Ball", Diameter = 2, X = 0.7, Y = 4.2, Color = rgb(130, 205, 125) },
		},
	},
	{
		Id = "Balloons",
		Name = "Balloon Bunch",
		Coins = 40,
		Charm = 1,
		Parts = {
			{ Kind = "Disc", Height = 0.4, Diameter = 1.4, Y = 0.2, Color = rgb(255, 225, 200) },
			{ Kind = "Disc", Height = 5, Diameter = 0.12, Y = 2.7, Color = rgb(255, 255, 255) },
			{ Kind = "Ball", Diameter = 2, X = -0.9, Y = 6, Color = rgb(255, 150, 190) },
			{ Kind = "Ball", Diameter = 2, X = 0.9, Y = 6.2, Color = rgb(165, 200, 255) },
			{ Kind = "Ball", Diameter = 2, Y = 7.4, Color = rgb(255, 215, 140) },
		},
	},
	{
		Id = "Lamp",
		Name = "Floor Lamp",
		Coins = 80,
		Charm = 1,
		Parts = {
			{ Kind = "Disc", Height = 0.3, Diameter = 2, Y = 0.15, Color = rgb(90, 60, 70) },
			{ Kind = "Disc", Height = 6, Diameter = 0.3, Y = 3.2, Color = rgb(90, 60, 70) },
			{ Kind = "Ball", Diameter = 2.2, Y = 7, Color = rgb(255, 235, 170), Material = Enum.Material.Neon },
		},
	},
	{
		Id = "Table",
		Name = "Cafe Table",
		Coins = 120,
		Charm = 2,
		Parts = {
			{ Kind = "Disc", Height = 0.3, Diameter = 3.6, Y = 3, Color = rgb(255, 245, 230) },
			{ Kind = "Disc", Height = 3, Diameter = 0.4, Y = 1.5, Color = rgb(190, 130, 95) },
			{ Kind = "Disc", Height = 0.3, Diameter = 1.4, X = -1.9, Y = 1.6, Color = rgb(240, 150, 175) },
			{ Kind = "Disc", Height = 1.6, Diameter = 0.3, X = -1.9, Y = 0.8, Color = rgb(190, 130, 95) },
			{ Kind = "Disc", Height = 0.3, Diameter = 1.4, X = 1.9, Y = 1.6, Color = rgb(240, 150, 175) },
			{ Kind = "Disc", Height = 1.6, Diameter = 0.3, X = 1.9, Y = 0.8, Color = rgb(190, 130, 95) },
		},
	},
	{
		Id = "GiantCupcake",
		Name = "Giant Cupcake",
		Stars = 8,
		Charm = 5,
		Parts = {
			{ Kind = "Disc", Height = 2.4, Diameter = 3.6, Y = 1.2, Color = rgb(190, 130, 75) },
			{ Kind = "Ball", Diameter = 4.2, Y = 3.8, Color = rgb(255, 180, 205) },
			{ Kind = "Ball", Diameter = 1.1, Y = 6, Color = rgb(215, 50, 70) },
		},
	},
	{
		Id = "RainbowArch",
		Name = "Rainbow Arch",
		Stars = 15,
		Charm = 8,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(0.8, 6, 0.8), X = -2, Y = 3, Color = rgb(255, 150, 165) },
			{ Kind = "Box", Size = Vector3.new(0.8, 6, 0.8), X = 2, Y = 3, Color = rgb(165, 200, 255) },
			{ Kind = "Box", Size = Vector3.new(4.8, 0.8, 0.8), Y = 6.4, Color = rgb(255, 215, 140) },
			{ Kind = "Box", Size = Vector3.new(3.4, 0.8, 0.8), Y = 7.2, Color = rgb(190, 230, 170) },
			{ Kind = "Box", Size = Vector3.new(2, 0.8, 0.8), Y = 8, Color = rgb(205, 175, 240) },
		},
	},
	{
		Id = "GoldenCake",
		Name = "Golden Cake Statue",
		Stars = 25,
		Charm = 12,
		Sparkles = true,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(3.4, 1.2, 3.4), Y = 0.6, Color = rgb(255, 245, 230), Material = Enum.Material.Marble },
			{ Kind = "Disc", Height = 1.5, Diameter = 3, Y = 2, Color = rgb(255, 200, 70), Material = Enum.Material.Foil },
			{ Kind = "Disc", Height = 1.2, Diameter = 2, Y = 3.35, Color = rgb(255, 215, 90), Material = Enum.Material.Foil },
			{ Kind = "Ball", Diameter = 0.8, Y = 4.3, Color = rgb(255, 235, 140), Material = Enum.Material.Neon },
		},
	},
	{
		Id = "RedCarpet",
		Name = "Red Carpet",
		Pass = "VIP",
		Charm = 4,
		Flat = true,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(3.6, 0.1, 5.6), Y = 0.06, Color = rgb(190, 30, 50) },
			{ Kind = "Box", Size = Vector3.new(0.25, 0.12, 5.6), X = -1.8, Y = 0.07, Color = rgb(255, 200, 70), Material = Enum.Material.Foil },
			{ Kind = "Box", Size = Vector3.new(0.25, 0.12, 5.6), X = 1.8, Y = 0.07, Color = rgb(255, 200, 70), Material = Enum.Material.Foil },
		},
	},
	{
		Id = "VelvetRope",
		Name = "Velvet Rope",
		Pass = "VIP",
		Charm = 4,
		Parts = {
			{ Kind = "Disc", Height = 0.2, Diameter = 1.2, X = -2, Y = 0.1, Color = rgb(255, 200, 70), Material = Enum.Material.Foil },
			{ Kind = "Disc", Height = 0.2, Diameter = 1.2, X = 2, Y = 0.1, Color = rgb(255, 200, 70), Material = Enum.Material.Foil },
			{ Kind = "Disc", Height = 3, Diameter = 0.4, X = -2, Y = 1.6, Color = rgb(255, 200, 70), Material = Enum.Material.Foil },
			{ Kind = "Disc", Height = 3, Diameter = 0.4, X = 2, Y = 1.6, Color = rgb(255, 200, 70), Material = Enum.Material.Foil },
			{ Kind = "Ball", Diameter = 0.6, X = -2, Y = 3.2, Color = rgb(255, 200, 70), Material = Enum.Material.Foil },
			{ Kind = "Ball", Diameter = 0.6, X = 2, Y = 3.2, Color = rgb(255, 200, 70), Material = Enum.Material.Foil },
			{ Kind = "Box", Size = Vector3.new(4, 0.3, 0.3), Y = 2.6, Color = rgb(190, 30, 50), Material = Enum.Material.Fabric },
		},
	},
	{
		Id = "PartyBunting",
		Name = "Party Bunting",
		Pass = "StarterPack",
		ExtraCoins = 150,
		Charm = 3,
		Parts = {
			{ Kind = "Disc", Height = 5, Diameter = 0.25, X = -2.2, Y = 2.5, Color = rgb(255, 255, 255) },
			{ Kind = "Disc", Height = 5, Diameter = 0.25, X = 2.2, Y = 2.5, Color = rgb(255, 255, 255) },
			{ Kind = "Box", Size = Vector3.new(4.4, 0.08, 0.08), Y = 4.8, Color = rgb(255, 255, 255) },
			{ Kind = "Box", Size = Vector3.new(0.6, 0.7, 0.08), X = -1.5, Y = 4.4, Color = rgb(255, 150, 190) },
			{ Kind = "Box", Size = Vector3.new(0.6, 0.7, 0.08), X = -0.5, Y = 4.4, Color = rgb(165, 200, 255) },
			{ Kind = "Box", Size = Vector3.new(0.6, 0.7, 0.08), X = 0.5, Y = 4.4, Color = rgb(255, 215, 140) },
			{ Kind = "Box", Size = Vector3.new(0.6, 0.7, 0.08), X = 1.5, Y = 4.4, Color = rgb(190, 230, 170) },
		},
	},
	{
		Id = "Fireplace",
		Name = "Fireplace",
		Pass = "CozyPack",
		ExtraCoins = 400,
		Charm = 4,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(4.4, 3.6, 1.6), Y = 1.8, Color = rgb(170, 85, 70), Material = Enum.Material.Brick },
			{ Kind = "Box", Size = Vector3.new(2.6, 2, 0.2), Y = 1.2, Z = -0.75, Color = rgb(45, 30, 30) },
			{ Kind = "Ball", Diameter = 1, Y = 0.7, Z = -0.6, Color = rgb(255, 140, 40), Material = Enum.Material.Neon },
			{ Kind = "Box", Size = Vector3.new(4.8, 0.3, 1.9), Y = 3.75, Color = rgb(150, 100, 70), Material = Enum.Material.Wood },
		},
	},
	{
		Id = "Bookshelf",
		Name = "Bookshelf",
		Pass = "CozyPack",
		ExtraCoins = 300,
		Charm = 4,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(3.6, 5, 1.4), Y = 2.5, Color = rgb(150, 100, 70), Material = Enum.Material.Wood },
			{ Kind = "Box", Size = Vector3.new(0.8, 1, 0.6), X = -1, Y = 1.3, Z = -0.45, Color = rgb(235, 120, 150) },
			{ Kind = "Box", Size = Vector3.new(0.8, 1, 0.6), X = 0.1, Y = 1.3, Z = -0.45, Color = rgb(110, 175, 215) },
			{ Kind = "Box", Size = Vector3.new(0.8, 1, 0.6), X = 1, Y = 2.8, Z = -0.45, Color = rgb(190, 230, 170) },
			{ Kind = "Box", Size = Vector3.new(0.8, 1, 0.6), X = -0.4, Y = 2.8, Z = -0.45, Color = rgb(255, 215, 140) },
			{ Kind = "Box", Size = Vector3.new(0.8, 1, 0.6), X = -1, Y = 4.2, Z = -0.45, Color = rgb(205, 175, 240) },
			{ Kind = "Box", Size = Vector3.new(0.8, 1, 0.6), X = 0.6, Y = 4.2, Z = -0.45, Color = rgb(235, 120, 150) },
		},
	},
	{
		Id = "Armchair",
		Name = "Armchair",
		Pass = "CozyPack",
		ExtraCoins = 250,
		Charm = 4,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(3, 1.2, 3), Y = 0.9, Color = rgb(235, 120, 150), Material = Enum.Material.Fabric },
			{ Kind = "Box", Size = Vector3.new(3, 2.6, 0.7), Y = 2.1, Z = 1.15, Color = rgb(235, 120, 150), Material = Enum.Material.Fabric },
			{ Kind = "Box", Size = Vector3.new(0.6, 1.8, 3), X = -1.5, Y = 1.4, Color = rgb(215, 100, 130), Material = Enum.Material.Fabric },
			{ Kind = "Box", Size = Vector3.new(0.6, 1.8, 3), X = 1.5, Y = 1.4, Color = rgb(215, 100, 130), Material = Enum.Material.Fabric },
			{ Kind = "Box", Size = Vector3.new(2.4, 0.4, 2.2), Y = 1.65, Z = -0.2, Color = rgb(255, 225, 200), Material = Enum.Material.Fabric },
		},
	},
	{
		Id = "ChristmasTree",
		Name = "Christmas Tree",
		Pass = "WinterPack",
		ExtraCoins = 400,
		Charm = 5,
		Parts = {
			{ Kind = "Disc", Height = 1, Diameter = 0.8, Y = 0.5, Color = rgb(120, 80, 55) },
			{ Kind = "Disc", Height = 1.4, Diameter = 4.2, Y = 1.6, Color = rgb(60, 140, 80) },
			{ Kind = "Disc", Height = 1.3, Diameter = 3.2, Y = 2.9, Color = rgb(70, 155, 90) },
			{ Kind = "Disc", Height = 1.2, Diameter = 2.2, Y = 4.1, Color = rgb(80, 170, 100) },
			{ Kind = "Disc", Height = 1, Diameter = 1.2, Y = 5.1, Color = rgb(90, 180, 110) },
			{ Kind = "Ball", Diameter = 0.8, Y = 5.9, Color = rgb(255, 220, 90), Material = Enum.Material.Neon },
			{ Kind = "Ball", Diameter = 0.45, X = 1.6, Y = 1.9, Z = -1, Color = rgb(215, 50, 70) },
			{ Kind = "Ball", Diameter = 0.45, X = -1.2, Y = 3.1, Z = -0.9, Color = rgb(110, 175, 215) },
			{ Kind = "Ball", Diameter = 0.45, X = 0.6, Y = 4.3, Z = -0.8, Color = rgb(255, 200, 70) },
		},
	},
	{
		Id = "Snowman",
		Name = "Snowman",
		Pass = "WinterPack",
		ExtraCoins = 300,
		Charm = 5,
		Parts = {
			{ Kind = "Ball", Diameter = 3, Y = 1.5, Color = rgb(250, 250, 255) },
			{ Kind = "Ball", Diameter = 2.2, Y = 3.6, Color = rgb(250, 250, 255) },
			{ Kind = "Ball", Diameter = 1.6, Y = 5.1, Color = rgb(250, 250, 255) },
			{ Kind = "Box", Size = Vector3.new(0.25, 0.25, 0.9), Y = 5.1, Z = -0.9, Color = rgb(255, 140, 40) },
			{ Kind = "Ball", Diameter = 0.2, X = -0.3, Y = 5.35, Z = -0.72, Color = rgb(30, 30, 30) },
			{ Kind = "Ball", Diameter = 0.2, X = 0.3, Y = 5.35, Z = -0.72, Color = rgb(30, 30, 30) },
			{ Kind = "Disc", Height = 0.15, Diameter = 1.6, Y = 5.85, Color = rgb(40, 35, 40) },
			{ Kind = "Disc", Height = 0.9, Diameter = 1.1, Y = 6.35, Color = rgb(40, 35, 40) },
			{ Kind = "Disc", Height = 0.25, Diameter = 2.3, Y = 4.4, Color = rgb(215, 50, 70), Material = Enum.Material.Fabric },
		},
	},
	{
		Id = "GingerbreadHouse",
		Name = "Gingerbread House",
		Pass = "WinterPack",
		ExtraCoins = 350,
		Charm = 5,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(3.6, 2.6, 3.6), Y = 1.3, Color = rgb(170, 100, 55) },
			{ Kind = "Box", Size = Vector3.new(4.2, 0.5, 4.2), Y = 2.85, Color = rgb(255, 250, 245) },
			{ Kind = "Box", Size = Vector3.new(3.2, 0.5, 3.2), Y = 3.35, Color = rgb(170, 100, 55) },
			{ Kind = "Box", Size = Vector3.new(2.2, 0.5, 2.2), Y = 3.85, Color = rgb(255, 250, 245) },
			{ Kind = "Box", Size = Vector3.new(1.2, 0.5, 1.2), Y = 4.35, Color = rgb(170, 100, 55) },
			{ Kind = "Box", Size = Vector3.new(1, 1.6, 0.1), Y = 0.8, Z = -1.85, Color = rgb(240, 150, 175) },
			{ Kind = "Ball", Diameter = 0.4, X = -1.2, Y = 1.9, Z = -1.85, Color = rgb(215, 50, 70) },
			{ Kind = "Ball", Diameter = 0.4, X = 1.2, Y = 1.9, Z = -1.85, Color = rgb(110, 200, 125) },
		},
	},
	{
		Id = "Sconce",
		Name = "Wall Sconce",
		Wall = true,
		Coins = 70,
		Charm = 1,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(0.8, 1.8, 0.2), Y = 0.9, Z = -0.1, Color = rgb(205, 160, 80), Material = Enum.Material.Metal },
			{ Kind = "Box", Size = Vector3.new(0.2, 0.2, 0.6), Y = 0.9, Z = -0.4, Color = rgb(205, 160, 80), Material = Enum.Material.Metal },
			{ Kind = "Disc", Height = 0.3, Diameter = 0.6, Y = 1.1, Z = -0.7, Color = rgb(205, 160, 80), Material = Enum.Material.Metal },
			{ Kind = "Ball", Diameter = 0.7, Y = 1.55, Z = -0.7, Color = rgb(255, 225, 160), Material = Enum.Material.Neon, Light = 12 },
		},
	},
	{
		Id = "HeartSign",
		Name = "Neon Heart Sign",
		Wall = true,
		Stars = 10,
		Charm = 5,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(4, 3.6, 0.2), Y = 1.8, Z = -0.1, Color = rgb(60, 45, 60) },
			{ Kind = "Box", Size = Vector3.new(0.45, 0.45, 0.15), Y = 0.6, Z = -0.275, Color = rgb(255, 90, 170), Material = Enum.Material.Neon },
			{ Kind = "Box", Size = Vector3.new(1.35, 0.45, 0.15), Y = 1.05, Z = -0.275, Color = rgb(255, 90, 170), Material = Enum.Material.Neon },
			{ Kind = "Box", Size = Vector3.new(2.25, 0.45, 0.15), Y = 1.5, Z = -0.275, Color = rgb(255, 90, 170), Material = Enum.Material.Neon },
			{ Kind = "Box", Size = Vector3.new(3.15, 0.9, 0.15), Y = 2.175, Z = -0.275, Color = rgb(255, 90, 170), Material = Enum.Material.Neon, Light = 14 },
			{ Kind = "Box", Size = Vector3.new(0.9, 0.45, 0.15), X = -0.675, Y = 2.85, Z = -0.275, Color = rgb(255, 90, 170), Material = Enum.Material.Neon },
			{ Kind = "Box", Size = Vector3.new(0.9, 0.45, 0.15), X = 0.675, Y = 2.85, Z = -0.275, Color = rgb(255, 90, 170), Material = Enum.Material.Neon },
		},
	},
	{
		Id = "HangingIvy",
		Name = "Hanging Ivy",
		Wall = true,
		Coins = 60,
		Charm = 1,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(0.5, 0.5, 0.1), Y = 4, Z = -0.05, Color = rgb(70, 60, 60), Material = Enum.Material.Metal },
			{ Kind = "Box", Size = Vector3.new(0.15, 0.15, 0.8), Y = 4, Z = -0.4, Color = rgb(70, 60, 60), Material = Enum.Material.Metal },
			{ Kind = "Box", Size = Vector3.new(0.06, 0.6, 0.06), Y = 3.6, Z = -0.7, Color = rgb(70, 60, 60), Material = Enum.Material.Metal },
			{ Kind = "Disc", Height = 0.9, Diameter = 1.1, Y = 2.85, Z = -0.65, Color = rgb(200, 120, 90) },
			{ Kind = "Ball", Diameter = 1.2, Y = 3.3, Z = -0.65, Color = rgb(90, 170, 95) },
			{ Kind = "Box", Size = Vector3.new(0.1, 2.4, 0.1), X = -0.4, Y = 1.3, Z = -0.75, Color = rgb(60, 130, 70) },
			{ Kind = "Box", Size = Vector3.new(0.1, 1.8, 0.1), X = 0.35, Y = 1.6, Z = -0.75, Color = rgb(60, 130, 70) },
			{ Kind = "Ball", Diameter = 0.45, X = -0.4, Y = 2, Z = -0.75, Color = rgb(110, 185, 100) },
			{ Kind = "Ball", Diameter = 0.45, X = -0.4, Y = 1.15, Z = -0.75, Color = rgb(70, 150, 80) },
			{ Kind = "Ball", Diameter = 0.45, X = -0.4, Y = 0.225, Z = -0.75, Color = rgb(110, 185, 100) },
			{ Kind = "Ball", Diameter = 0.45, X = 0.35, Y = 1.9, Z = -0.75, Color = rgb(70, 150, 80) },
			{ Kind = "Ball", Diameter = 0.45, X = 0.35, Y = 0.9, Z = -0.75, Color = rgb(110, 185, 100) },
		},
	},
	{
		Id = "WallPlanter",
		Name = "Wall Planter",
		Wall = true,
		Coins = 80,
		Charm = 2,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(3.6, 0.9, 1), Y = 1.25, Z = -0.5, Color = rgb(190, 130, 95), Material = Enum.Material.WoodPlanks },
			{ Kind = "Box", Size = Vector3.new(0.3, 1.3, 0.12), X = -1.4, Y = 0.65, Z = -0.06, Color = rgb(150, 100, 70), Material = Enum.Material.Wood },
			{ Kind = "Box", Size = Vector3.new(0.3, 1.3, 0.12), X = 1.4, Y = 0.65, Z = -0.06, Color = rgb(150, 100, 70), Material = Enum.Material.Wood },
			{ Kind = "Box", Size = Vector3.new(3.4, 0.1, 0.8), Y = 1.72, Z = -0.5, Color = rgb(90, 60, 45) },
			{ Kind = "Ball", Diameter = 0.7, X = -1.3, Y = 1.9, Z = -0.5, Color = rgb(110, 185, 110) },
			{ Kind = "Ball", Diameter = 0.7, X = -0.4, Y = 1.9, Z = -0.5, Color = rgb(90, 170, 95) },
			{ Kind = "Ball", Diameter = 0.7, X = 0.5, Y = 1.9, Z = -0.5, Color = rgb(110, 185, 110) },
			{ Kind = "Ball", Diameter = 0.7, X = 1.35, Y = 1.9, Z = -0.5, Color = rgb(90, 170, 95) },
			{ Kind = "Ball", Diameter = 0.55, X = -1, Y = 2.4, Z = -0.55, Color = rgb(255, 150, 190) },
			{ Kind = "Ball", Diameter = 0.55, X = -0.1, Y = 2.5, Z = -0.55, Color = rgb(255, 215, 90) },
			{ Kind = "Ball", Diameter = 0.55, X = 0.8, Y = 2.4, Z = -0.55, Color = rgb(255, 250, 245) },
			{ Kind = "Ball", Diameter = 0.55, X = 1.5, Y = 2.35, Z = -0.55, Color = rgb(255, 150, 190) },
		},
	},
	{
		Id = "CupcakePainting",
		Name = "Cupcake Painting",
		Wall = true,
		Coins = 90,
		Charm = 2,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(3.2, 3.8, 0.2), Y = 1.9, Z = -0.1, Color = rgb(255, 200, 70), Material = Enum.Material.Foil },
			{ Kind = "Box", Size = Vector3.new(2.7, 3.3, 0.06), Y = 1.9, Z = -0.23, Color = rgb(200, 235, 220) },
			{ Kind = "Box", Size = Vector3.new(1.2, 0.9, 0.08), Y = 1.05, Z = -0.3, Color = rgb(190, 130, 75) },
			{ Kind = "Plate", Height = 0.1, Diameter = 1.5, Y = 1.9, Z = -0.3, Color = rgb(255, 180, 205) },
			{ Kind = "Plate", Height = 0.1, Diameter = 1, Y = 2.45, Z = -0.32, Color = rgb(255, 180, 205) },
			{ Kind = "Plate", Height = 0.06, Diameter = 0.45, Y = 2.95, Z = -0.35, Color = rgb(215, 50, 70) },
			{ Kind = "Box", Size = Vector3.new(0.06, 0.3, 0.04), Y = 3.3, Z = -0.34, Color = rgb(80, 130, 70) },
			{ Kind = "Box", Size = Vector3.new(0.15, 0.06, 0.04), X = -0.4, Y = 1.95, Z = -0.37, Color = rgb(110, 175, 215) },
			{ Kind = "Box", Size = Vector3.new(0.15, 0.06, 0.04), X = 0.35, Y = 2.05, Z = -0.37, Color = rgb(255, 215, 90) },
			{ Kind = "Box", Size = Vector3.new(0.15, 0.06, 0.04), X = 0.05, Y = 2.5, Z = -0.39, Color = rgb(190, 230, 170) },
		},
	},
	{
		Id = "SunsetPainting",
		Name = "Sunset Painting",
		Wall = true,
		Coins = 110,
		Charm = 2,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(4.6, 3.2, 0.2), Y = 1.6, Z = -0.1, Color = rgb(150, 100, 70), Material = Enum.Material.Wood },
			{ Kind = "Box", Size = Vector3.new(4.1, 0.9, 0.06), Y = 2.5, Z = -0.23, Color = rgb(205, 175, 240) },
			{ Kind = "Box", Size = Vector3.new(4.1, 0.6, 0.06), Y = 1.75, Z = -0.23, Color = rgb(255, 150, 190) },
			{ Kind = "Box", Size = Vector3.new(4.1, 0.3, 0.06), Y = 1.3, Z = -0.23, Color = rgb(255, 180, 110) },
			{ Kind = "Plate", Height = 0.04, Diameter = 1.1, Y = 1.25, Z = -0.28, Color = rgb(255, 215, 90) },
			{ Kind = "Box", Size = Vector3.new(4.1, 0.95, 0.06), Y = 0.7, Z = -0.33, Color = rgb(110, 175, 215) },
			{ Kind = "Box", Size = Vector3.new(0.6, 0.06, 0.02), Y = 0.95, Z = -0.37, Color = rgb(255, 215, 90) },
			{ Kind = "Box", Size = Vector3.new(0.4, 0.06, 0.02), Y = 0.7, Z = -0.37, Color = rgb(255, 215, 90) },
		},
	},
	{
		Id = "WallClock",
		Name = "Wall Clock",
		Wall = true,
		Coins = 80,
		Charm = 1,
		Parts = {
			{ Kind = "Plate", Height = 0.25, Diameter = 2.6, Y = 1.3, Z = -0.125, Color = rgb(240, 150, 175) },
			{ Kind = "Plate", Height = 0.05, Diameter = 2.2, Y = 1.3, Z = -0.27, Color = rgb(255, 250, 245) },
			{ Kind = "Box", Size = Vector3.new(0.1, 0.25, 0.03), Y = 2.25, Z = -0.31, Color = rgb(70, 55, 65) },
			{ Kind = "Box", Size = Vector3.new(0.1, 0.25, 0.03), Y = 0.35, Z = -0.31, Color = rgb(70, 55, 65) },
			{ Kind = "Box", Size = Vector3.new(0.25, 0.1, 0.03), X = -0.95, Y = 1.3, Z = -0.31, Color = rgb(70, 55, 65) },
			{ Kind = "Box", Size = Vector3.new(0.25, 0.1, 0.03), X = 0.95, Y = 1.3, Z = -0.31, Color = rgb(70, 55, 65) },
			{ Kind = "Box", Size = Vector3.new(0.12, 0.6, 0.04), Y = 1.6, Z = -0.31, Color = rgb(70, 55, 65) },
			{ Kind = "Box", Size = Vector3.new(0.8, 0.1, 0.04), X = 0.4, Y = 1.3, Z = -0.33, Color = rgb(70, 55, 65) },
			{ Kind = "Plate", Height = 0.06, Diameter = 0.2, Y = 1.3, Z = -0.36, Color = rgb(255, 200, 70), Material = Enum.Material.Foil },
		},
	},
	{
		Id = "Chalkboard",
		Name = "Chalkboard Menu",
		Wall = true,
		Coins = 100,
		Charm = 2,
		Parts = {
			{ Kind = "Box", Size = Vector3.new(3.6, 4.4, 0.2), Y = 2.2, Z = -0.1, Color = rgb(150, 100, 70), Material = Enum.Material.Wood },
			{ Kind = "Box", Size = Vector3.new(3.1, 3.9, 0.06), Y = 2.2, Z = -0.23, Color = rgb(45, 75, 60), Material = Enum.Material.Slate },
			{ Kind = "Box", Size = Vector3.new(1.8, 0.25, 0.03), Y = 3.6, Z = -0.275, Color = rgb(245, 245, 240) },
			{ Kind = "Box", Size = Vector3.new(1.8, 0.1, 0.03), X = -0.35, Y = 2.9, Z = -0.275, Color = rgb(245, 245, 240) },
			{ Kind = "Box", Size = Vector3.new(1.8, 0.1, 0.03), X = -0.35, Y = 2.4, Z = -0.275, Color = rgb(245, 245, 240) },
			{ Kind = "Box", Size = Vector3.new(1.8, 0.1, 0.03), X = -0.35, Y = 1.9, Z = -0.275, Color = rgb(245, 245, 240) },
			{ Kind = "Box", Size = Vector3.new(0.4, 0.1, 0.03), X = 1, Y = 2.9, Z = -0.275, Color = rgb(255, 180, 205) },
			{ Kind = "Box", Size = Vector3.new(0.4, 0.1, 0.03), X = 1, Y = 2.4, Z = -0.275, Color = rgb(255, 225, 140) },
			{ Kind = "Box", Size = Vector3.new(0.4, 0.1, 0.03), X = 1, Y = 1.9, Z = -0.275, Color = rgb(255, 180, 205) },
			{ Kind = "Plate", Height = 0.03, Diameter = 0.6, X = -0.8, Y = 1.15, Z = -0.275, Color = rgb(255, 180, 205) },
			{ Kind = "Box", Size = Vector3.new(0.45, 0.4, 0.03), X = -0.8, Y = 0.8, Z = -0.275, Color = rgb(245, 245, 240) },
			{ Kind = "Box", Size = Vector3.new(3.2, 0.15, 0.3), Y = 0.15, Z = -0.35, Color = rgb(150, 100, 70), Material = Enum.Material.Wood },
			{ Kind = "Box", Size = Vector3.new(0.4, 0.1, 0.1), X = 1, Y = 0.27, Z = -0.35, Color = rgb(245, 245, 240) },
		},
	},
}

function Config.GetItem(id)
	for _, item in Config.Items do
		if item.Id == id then
			return item
		end
	end
	return nil
end

function Config.IsAllowed(item, userId)
	return item.OnlyFor == nil or table.find(item.OnlyFor, userId) ~= nil
end

-- Game passes bought once with Robux. GamePassId comes from Creator Hub, and 0 means
-- it isn't on sale yet. Section groups them in the store.
Config.Passes = {
	{
		Id = "DoubleCoins",
		Name = "2x Coins",
		GamePassId = 2072444566,
		Section = "Passes",
		Detail = "Double coins from customers and deliveries, forever",
	},
	{
		Id = "VIP",
		Name = "VIP",
		GamePassId = 2072630512,
		Section = "Passes",
		Detail = "VIP tag, 2 VIP decorations, +1 Star every daily reward",
	},
	{
		Id = "StarterPack",
		Name = "Starter Pack",
		GamePassId = 2068562637,
		Section = "Packs",
		Detail = "1,000 coins, 15 Sugar Stars and Party Bunting",
	},
	{
		Id = "CozyPack",
		Name = "Cozy Pack",
		GamePassId = 2070589101,
		Section = "Packs",
		Detail = "Fireplace, Bookshelf and Armchair",
	},
	{
		Id = "WinterPack",
		Name = "Winter Pack",
		GamePassId = 2072654528,
		Section = "Packs",
		Detail = "Christmas Tree, Snowman and Gingerbread House",
	},
}

function Config.GetPass(id)
	for _, pass in Config.Passes do
		if pass.Id == id then
			return pass
		end
	end
	return nil
end

-- Accounts that own some game passes for free, with the pass Ids each one gets.
Config.FreePasses = {
	[7358315834] = { "VIP", "StarterPack", "CozyPack", "WinterPack" }, -- lullabybbys
}

Config.StarterPack = { Coins = 1000, Stars = 15 }

-- Each box holds one kind of treat, so keep this at or above the number of recipes.
Config.HotbarSize = 5
-- Every bakery gets one free display case, placed here to start with (a Layout grid
-- entry). The last case can't be stored, so customers always have something to visit.
Config.StarterCase = { Key = "starter", Item = "SmallCase", X = 36, Z = 27, R = 0 }

-- A second, gold oven sold in the Decorate menu's Expansion tab as a luxury. Its bake
-- times are multiplied by BakeTimeScale, so 0.85 bakes 15% faster than the normal oven.
Config.LuxuryOven = {
	Name = "Luxury Oven",
	Coins = 25000,
	BakeTimeScale = 0.85,
	Detail = "A gold second oven that bakes 15% faster. Bake two batches at once!",
}

-- Bigger bakeries, bought in order from the Decorate menu's Expansion tab. Each step moves
-- the back wall Back studs further back and each side wall Side studs further out. The
-- front, with the door and sign, stays put.
Config.Expansions = {
	{ Coins = 3000, Back = 8, Side = 2 },
	{ Coins = 8000, Back = 8, Side = 2 },
	{ Coins = 18000, Back = 8, Side = 2 },
}

-- Paint for the walls, the oven and each display case, bought in the Decorate menu's
-- Paint tab. Anything can use any colour, except that the oven can't use colours with
-- Oven = false. The oven gets no yellow or shiny paint, so only the Luxury Oven ever looks
-- gold, and the Luxury Oven can't be painted.
Config.WallPaintCoins = 25
Config.OvenPaintCoins = 75
Config.CasePaintCoins = 15
-- Display cases start in this colour.
Config.CaseOriginalPaint = "Bubblegum"
Config.Paints = {
	{ Id = "Vanilla", Name = "Vanilla", Color = rgb(255, 240, 225) },
	{ Id = "Snow", Name = "Snow", Color = rgb(250, 250, 252) },
	{ Id = "Strawberry", Name = "Strawberry", Color = rgb(255, 190, 205) },
	{ Id = "Bubblegum", Name = "Bubblegum", Color = rgb(240, 150, 175) },
	{ Id = "Peach", Name = "Peach", Color = rgb(255, 210, 180) },
	{ Id = "Lemon", Name = "Lemon", Color = rgb(255, 240, 170), Oven = false },
	{ Id = "Mint", Name = "Mint", Color = rgb(175, 225, 205) },
	{ Id = "Sky", Name = "Sky", Color = rgb(185, 220, 245) },
	{ Id = "Lavender", Name = "Lavender", Color = rgb(215, 200, 240) },
	{ Id = "Cocoa", Name = "Cocoa", Color = rgb(150, 105, 85) },
	{ Id = "Cherry", Name = "Cherry", Color = rgb(215, 70, 90) },
}
-- What can be painted. Walls lists part names in the plot's Walls folder, and Oven lists
-- part names in its Oven model. Original is the paint it starts with.
Config.PaintTargets = {
	{ Id = "Back", Name = "Back Wall", Walls = { "BackWall" }, Original = "Vanilla", Coins = Config.WallPaintCoins },
	{ Id = "Left", Name = "Left Wall", Walls = { "LeftWall" }, Original = "Vanilla", Coins = Config.WallPaintCoins },
	{ Id = "Right", Name = "Right Wall", Walls = { "RightWall" }, Original = "Vanilla", Coins = Config.WallPaintCoins },
	{
		Id = "Front",
		Name = "Front Wall",
		Walls = { "FrontLeft", "FrontRight" },
		Original = "Vanilla",
		Coins = Config.WallPaintCoins,
	},
	{ Id = "Oven", Name = "Oven", Oven = { "Body", "Backsplash", "Hood" }, Original = "Mint", Coins = Config.OvenPaintCoins },
}

function Config.GetPaint(id)
	for _, paint in Config.Paints do
		if paint.Id == id then
			return paint
		end
	end
	return nil
end

function Config.GetPaintTarget(id)
	for _, target in Config.PaintTargets do
		if target.Id == id then
			return target
		end
	end
	return nil
end

-- True when the target can be painted this colour. Display cases use every colour.
function Config.CanPaint(target, paint)
	return not target.Oven or paint.Oven ~= false
end

-- Delivery board: one order per tier at a time. Pay is the treats' sale price times PayScale.
Config.DeliveryTiers = {
	{ Name = "Small Order", Min = 1, Max = 2, PayScale = 1.5, Stars = 0, Cooldown = 15 },
	{ Name = "Party Order", Min = 3, Max = 5, PayScale = 1.8, Stars = 1, Cooldown = 120 },
	{ Name = "Big Catering Order", Min = 6, Max = 10, PayScale = 2.2, Stars = 3, Cooldown = 300 },
}

-- Sugar Stars
Config.StartingStars = 5
Config.FinishBakeStars = 1
Config.NewOrderStars = 1

-- Packs bought with Robux. ProductId comes from Creator Hub, and 0 means it isn't
-- on sale yet. Prices are set in Creator Hub, and the store reads them from Roblox.
Config.Products = {
	{ Name = "Coin Bag", ProductId = 3728575847, Currency = "Coins", Amount = 500 },
	{ Name = "Coin Sack", ProductId = 3728575849, Currency = "Coins", Amount = 2000 },
	{ Name = "Coin Chest", ProductId = 3728575852, Currency = "Coins", Amount = 6000 },
	{ Name = "Star Pouch", ProductId = 3728575854, Currency = "Stars", Amount = 10 },
	{ Name = "Star Jar", ProductId = 3728575857, Currency = "Stars", Amount = 30 },
	{ Name = "Star Chest", ProductId = 3728575858, Currency = "Stars", Amount = 100 },
	-- Amount is minutes of double coins. Buying again adds time.
	{ Name = "2x Boost", ProductId = 3728575863, Currency = "Boost", Amount = 15 },
}

-- Daily reward streak (days count in UTC). Missing a day starts again at day 1.
Config.DailyRewards = {
	{ Coins = 100 },
	{ Coins = 200 },
	{ Coins = 300 },
	{ Coins = 400 },
	{ Coins = 500 },
	{ Coins = 600 },
	{ Stars = 5 },
}
Config.VipDailyStars = 1

-- Daily goals: DailyCount different kinds are picked each day. Each pays coins (the best
-- unlocked recipe's price times CoinsPerPrice) plus Stars.
Config.Goals = {
	DailyCount = 3,
	CoinsPerPrice = 30,
	Stars = 1,
	Kinds = {
		{ Id = "Sell", Min = 15, Max = 30 },
		{ Id = "SellRecipe", Min = 4, Max = 10 },
		{ Id = "Ship", Min = 2, Max = 4 },
		{ Id = "Bake", Min = 4, Max = 8 },
	},
}

function Config.GetGoalKind(id)
	for _, kind in Config.Goals.Kinds do
		if kind.Id == id then
			return kind
		end
	end
	return nil
end

function Config.DescribeGoal(goal)
	if goal.Kind == "Sell" then
		return ("Sell %d treats"):format(goal.Target)
	elseif goal.Kind == "SellRecipe" then
		return ("Sell %d %ss"):format(goal.Target, Config.Recipes[goal.Recipe].Name)
	elseif goal.Kind == "Ship" then
		return ("Ship %d deliveries"):format(goal.Target)
	end
	return ("Bake %d batches"):format(goal.Target)
end

-- Customers keep buying from your cases while you're away, for up to this long.
Config.OfflineMaxSeconds = 8 * 60 * 60

-- Customers. On average one arrives every CustomerInterval seconds, sped up by Charm and
-- boosts, but never more often than every CustomerMinInterval.
Config.CustomerInterval = 18
Config.CustomerMinInterval = 3
-- Charm speeds customers up by at most Max (0.5 is 50% faster). Charm of Half gets half of
-- that, and each piece after that helps a little less.
Config.CharmSpeed = { Max = 0.5, Half = 12 }
-- How many customers can be on their way or inside at once, normally and during a boost.
Config.MaxCustomers = 3
Config.MaxCustomersBoosted = 5
Config.CustomerSpeed = 8
Config.BrowseTime = 1.5
-- Golden customers wear a crown, pay PayScale times the price, and sometimes tip a Star.
Config.GoldenCustomer = { Chance = 1 / 12, PayScale = 3, StarChance = 1 / 3 }
-- Customers arrive at random. Each wait is the usual interval times a factor from one of
-- these kinds, picked by Weight. Sometimes friends come together: Groups gives the chance
-- of a group of each size. Waits are evened out so the average still matches the interval.
Config.CustomerGap = {
	Kinds = {
		-- Right behind the last customer.
		{ Weight = 15, Factor = { 0.15, 0.4 } },
		{ Weight = 65, Factor = { 0.5, 1.5 } },
		-- A quiet spell.
		{ Weight = 20, Factor = { 2, 4 } },
	},
	Groups = { [2] = 0.12, [3] = 0.03 },
}

-- Boosts. Each adds its Rush to how fast customers come: 0.5 is 50% more customers. They
-- add together, and while any is on, up to MaxCustomersBoosted can come at once.
-- A Bake Sale is free once every Cooldown seconds. For Duration seconds, customers pay
-- Discount less (0.25 is 25% off). Deliveries and offline sales aren't discounted.
Config.BakeSale = { Duration = 120, Cooldown = 60 * 60, Discount = 0.25, Rush = 0.5 }
-- Bakery Buzz costs Stars for Minutes of customers. Buying again adds more time.
Config.Buzz = { Stars = 3, Minutes = 5, Rush = 1 }
-- The 2x Boost product also brings this many more customers while it lasts.
Config.BoostRush = 1
-- A stand outside the door gives a stack of Stack flyers, and the next stack is ready
-- Restock seconds after taking one. Townsfolk within Reach studs of the owner take one and
-- head to the bakery, at most one every Gap seconds.
Config.Flyers = { Stack = 5, Restock = 180, Reach = 8, Gap = 1 }
-- A customer who gets the treat they wanted tips a random share of its price, from Min to Max.
Config.WantedTip = { Min = 0, Max = 0.25 }

-- Townsfolk stroll around the plaza, and customers are townsfolk who head into a bakery.
-- People walk in from the edge of town, visit a few spots, then walk out again. The crowd
-- is Base people plus PerBakery for each owned bakery, up to Max. Each walks at
-- CustomerSpeed times a random Speed factor and pauses for StopTime seconds at each stop.
Config.Townsfolk = {
	Base = 6,
	PerBakery = 2,
	Max = 16,
	Stops = { 2, 5 },
	StopsAfterShopping = { 1, 3 },
	StopTime = { 2, 8 },
	Speed = { 0.8, 1.15 },
	ArrivalGap = { 2, 6 },
}

Config.AutosaveInterval = 60

Config.Sounds = {
	Coin = "rbxassetid://135483737426662",
	Ding = "rbxassetid://114005773348535",
}

return Config
