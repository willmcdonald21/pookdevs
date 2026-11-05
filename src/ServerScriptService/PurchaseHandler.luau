-- Grants coins, Stars, and boosts bought with Robux, and tracks who owns each game pass.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local PurchaseHandler = {}
local inProgress = {}
local ownedPasses = {}
local onPassGranted = nil

local function findProduct(productId)
	for _, product in Config.Products do
		if product.ProductId == productId then
			return product
		end
	end
	return nil
end

local function findPass(gamePassId)
	for _, pass in Config.Passes do
		if pass.GamePassId == gamePassId then
			return pass
		end
	end
	return nil
end

-- Roblox retries a receipt until it gets PurchaseGranted, so this only confirms a
-- purchase once it is saved. The receipt id is saved with the currency, so a retry
-- can never pay out twice, and a failed save loses neither.
function PurchaseHandler.Process(receipt, onGranted)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local product = findProduct(receipt.ProductId)
	if not product then
		warn("PurchaseHandler: unknown product " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not player or not PlayerData.CanSave(player) or inProgress[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	inProgress[receipt.PurchaseId] = true
	local data = PlayerData.Get(player)
	local isNew = table.find(data.Receipts, receipt.PurchaseId) == nil
	if isNew then
		if product.Currency == "Boost" then
			data.BoostUntil = math.max(data.BoostUntil, os.time()) + product.Amount * 60
		else
			data[product.Currency] += product.Amount
		end
		PlayerData.AddReceipt(player, receipt.PurchaseId)
		onGranted(player, product)
	end
	local saved = PlayerData.Save(player)
	inProgress[receipt.PurchaseId] = nil

	if saved then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function PurchaseHandler.OwnsPass(player, passId)
	local owned = ownedPasses[player]
	return owned ~= nil and owned[passId] == true
end

function PurchaseHandler.OwnedPasses(player)
	return ownedPasses[player] or {}
end

-- Asks Roblox which passes the player owns. A pass that can't be checked counts as
-- not owned until the next visit.
function PurchaseHandler.LoadPasses(player)
	local owned = {}
	for _, pass in Config.Passes do
		if pass.GamePassId ~= 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.GamePassId)
			end)
			owned[pass.Id] = ok and result == true
		end
	end
	ownedPasses[player] = owned
end

function PurchaseHandler.GrantPass(player, passId)
	local owned = ownedPasses[player]
	if not owned or owned[passId] then
		return
	end
	owned[passId] = true
	if onPassGranted then
		onPassGranted(player, Config.GetPass(passId))
	end
end

function PurchaseHandler.Start(onGranted, onPass)
	onPassGranted = onPass
	MarketplaceService.ProcessReceipt = function(receipt)
		return PurchaseHandler.Process(receipt, onGranted)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		local pass = findPass(gamePassId)
		if purchased and pass then
			PurchaseHandler.GrantPass(player, pass.Id)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		ownedPasses[player] = nil
	end)
end

return PurchaseHandler
