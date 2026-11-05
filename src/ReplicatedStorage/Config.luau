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
		Price = 5,
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
		Price = 12,
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
		Price = 25,
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
		Price = 50,
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
		Price = 100,
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

local function seconds(count)
	return count == 1 and "1 second" or ("%d seconds"):format(count)
end

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
	{
		Id = "Shoes",
		Name = "Comfy Shoes",
		Levels = {
			{ WalkSpeed = 16 },
			{ WalkSpeed = 20, Cost = 40 },
			{ WalkSpeed = 24, Cost = 300 },
			{ WalkSpeed = 28, Cost = 1500 },
		},
		Describe = function(level)
			return ("Walk at speed %d"):format(level.WalkSpeed)
		end,
	},
	-- Helpers: level 1 means not hired. Delay is how long they wait before working.
	{
		Id = "Baker",
		Name = "Baker Helper",
		Levels = {
			{},
			{ Delay = 4, Cost = 2000 },
			{ Delay = 1, Cost = 6000 },
		},
		Describe = function(level)
			if not level.Delay then
				return "Not hired yet"
			end
			return ("Bakes your last treat again %s after the oven empties"):format(seconds(level.Delay))
		end,
	},
	{
		Id = "Stocker",
		Name = "Stocker Helper",
		Levels = {
			{},
			{ Delay = 6, Cost = 3500 },
			{ Delay = 2, Cost = 9000 },
		},
		Describe = function(level)
			if not level.Delay then
				return "Not hired yet"
			end
			return ("Moves finished batches into your cases after %s"):format(seconds(level.Delay))
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
-- floor at the item's spot. Display cases hold treats at their Slots.
-- An item with OnlyFor = { userId, ... } is a free gift for those accounts, and
-- nobody else can see or get it. An item with Pass = "<pass Id>" comes with that
-- game pass, and everyone can see it in the Decorate menu.
local CASE_PINK = rgb(240, 150, 175)
local GLASS = rgb(210, 235, 245)

local function slots(shelves)
	local list = {}
	for _, y in shelves do
		for _, z in { -0.6, 0.6 } do
			for _, x in { -1.4, 0, 1.4 } do
				table.insert(list, Vector3.new(x, y, z))
			end
		end
	end
	return list
end

Config.Items = {
	{
		Id = "SmallCase",
		Name = "Display Case",
		Coins = 100,
		Charm = 0,
		Slots = slots({ 3.3 }),
		Parts = {
			{ Kind = "Box", Size = Vector3.new(4.6, 3, 2.8), Y = 1.5, Color = CASE_PINK },
			{ Kind = "Box", Size = Vector3.new(4.6, 2, 2.8), Y = 4, Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.7 },
			{ Kind = "Box", Size = Vector3.new(4.8, 0.25, 3), Y = 5.1, Color = CASE_PINK, Transparency = 0.5 },
		},
	},
	{
		Id = "BigCase",
		Name = "Tall Display Case",
		Coins = 800,
		Charm = 1,
		Slots = slots({ 1.9, 4.1 }),
		Parts = {
			{ Kind = "Box", Size = Vector3.new(4.6, 1.6, 2.8), Y = 0.8, Color = CASE_PINK },
			{ Kind = "Box", Size = Vector3.new(4.6, 0.2, 2.8), Y = 3.9, Color = CASE_PINK, Transparency = 0.5 },
			{ Kind = "Box", Size = Vector3.new(4.6, 4.8, 2.8), Y = 4, Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.75 },
			{ Kind = "Box", Size = Vector3.new(4.8, 0.25, 3), Y = 6.5, Color = CASE_PINK, Transparency = 0.5 },
		},
	},
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

Config.StarterPack = { Coins = 1000, Stars = 15 }

Config.SpotCount = 16
-- Each box holds one kind of treat, so keep this at or above the number of recipes.
Config.HotbarSize = 5
Config.StarterCaseKey = "starter"
Config.StarterCaseSlots = {
	Vector3.new(-3.5, 0.35, 0),
	Vector3.new(-2.1, 0.35, 0),
	Vector3.new(-0.7, 0.35, 0),
	Vector3.new(0.7, 0.35, 0),
	Vector3.new(2.1, 0.35, 0),
	Vector3.new(3.5, 0.35, 0),
}

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

-- Customers
Config.CustomerInterval = 9
Config.CustomerMinInterval = 2.5
Config.CharmSpeedBonus = 0.06
Config.MaxCustomers = 5
Config.CustomerSpeed = 8
Config.BrowseTime = 1.5
-- Golden customers wear a crown, pay PayScale times the price, and sometimes tip a Star.
Config.GoldenCustomer = { Chance = 1 / 12, PayScale = 3, StarChance = 1 / 3 }

Config.AutosaveInterval = 60

Config.Sounds = {
	Coin = "rbxassetid://135483737426662",
	Ding = "rbxassetid://114005773348535",
}

return Config
