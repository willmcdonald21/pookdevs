-- Paints Treat Designer drawings on the client. A designed treat carries its drawing as the
-- Art attribute of a TreatArt decal (see ItemBuilder and TreatDesign), and this turns that
-- text into a small EditableImage, shared by every treat with the same drawing. Treats the
-- server builds, like those in display cases, are painted as they arrive.
-- It also reads the designs each plot publishes (TreatDesign.Publish).
-- EditableImage needs "Allow Mesh / Image APIs" on in the experience's Security settings.
-- Without it, or when the device has no room for more images, the drawing just isn't shown.
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local TreatDesign = require(ReplicatedStorage:WaitForChild("TreatDesign"))

local GRID = TreatDesign.Grid
local SIZE = Vector2.new(GRID, GRID)
-- When there are more images than this, ones no treat shows any more are let go.
local MAX_IMAGES = 120

local TreatArt = {}

-- Drawing text to its image, or false when one couldn't be made.
local images = {}
local imageCount = 0
-- A plot model's last TreatDesigns text and what it decoded to.
local decoded = setmetatable({}, { __mode = "k" })

-- Fills an EditableImage with a drawing. Empty cells are see-through.
function TreatArt.Write(image, art)
	local pixels = buffer.create(GRID * GRID * 4)
	for index = 1, GRID * GRID do
		local byte = string.byte(art, index)
		local color = byte and byte >= 97 and Config.TreatColors[byte - 96]
		if color then
			local offset = (index - 1) * 4
			buffer.writeu8(pixels, offset, math.floor(color.Color.R * 255 + 0.5))
			buffer.writeu8(pixels, offset + 1, math.floor(color.Color.G * 255 + 0.5))
			buffer.writeu8(pixels, offset + 2, math.floor(color.Color.B * 255 + 0.5))
			buffer.writeu8(pixels, offset + 3, 255)
		end
	end
	image:WritePixelsBuffer(Vector2.zero, SIZE, pixels)
end

-- A new blank canvas, or nil when EditableImage isn't available.
function TreatArt.NewImage()
	local ok, image = pcall(AssetService.CreateEditableImage, AssetService, { Size = SIZE })
	return ok and image or nil
end

-- Lets go of images no treat in the world or the menus shows any more.
local function tidy()
	local used = {}
	for _, root in { Workspace, Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") } do
		for _, decal in root:GetDescendants() do
			if decal.Name == "TreatArt" and decal:IsA("Decal") then
				used[decal:GetAttribute("Art") or ""] = true
			end
		end
	end
	for art, image in images do
		if not used[art] then
			if image then
				image:Destroy()
			end
			images[art] = nil
			imageCount -= 1
		end
	end
end

function TreatArt.Image(art)
	local image = images[art]
	if image == nil then
		if imageCount >= MAX_IMAGES then
			tidy()
		end
		image = TreatArt.NewImage()
		if image then
			TreatArt.Write(image, art)
		end
		images[art] = image or false
		imageCount += 1
	end
	return image or nil
end

function TreatArt.Paint(decal)
	local art = decal:GetAttribute("Art")
	local image = type(art) == "string" and TreatArt.Image(art)
	if image then
		decal.TextureContent = Content.fromObject(image)
	end
end

-- Paints every drawing in a model the client built, like a menu picture.
function TreatArt.Apply(model)
	for _, decal in model:GetDescendants() do
		if decal.Name == "TreatArt" and decal:IsA("Decal") then
			TreatArt.Paint(decal)
		end
	end
end

-- A plot's designs, keyed like a save's (see TreatDesign.For).
function TreatArt.Designs(plotModel)
	if not plotModel then
		return nil
	end
	local text = plotModel:GetAttribute("TreatDesigns")
	local cached = decoded[plotModel]
	if not cached or cached.text ~= text then
		cached = { text = text, designs = text and TreatDesign.Decode(text) or {} }
		decoded[plotModel] = cached
	end
	return cached.designs
end

function TreatArt.DesignFor(plotModel, recipeIndex)
	return TreatDesign.For(TreatArt.Designs(plotModel), recipeIndex)
end

-- Builds a treat in a plot's design with its drawing painted, for menus and bubbles.
function TreatArt.Build(recipeIndex, plotModel, scale, cframe)
	local model = TreatDesign.Build(recipeIndex, TreatArt.DesignFor(plotModel, recipeIndex), scale, cframe)
	TreatArt.Apply(model)
	return model
end

local function painted(object)
	if object.Name == "TreatArt" and object:IsA("Decal") then
		TreatArt.Paint(object)
	end
end
Workspace.DescendantAdded:Connect(painted)
for _, object in Workspace:GetDescendants() do
	painted(object)
end

return TreatArt
