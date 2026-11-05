-- Grants coins and Stars bought with Robux.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local PurchaseHandler = {}
local inProgress = {}

local function findProduct(productId)
	for _, product in Config.Products do
		if product.ProductId == productId then
			return product
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
		data[product.Currency] += product.Amount
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

function PurchaseHandler.Start(onGranted)
	MarketplaceService.ProcessReceipt = function(receipt)
		return PurchaseHandler.Process(receipt, onGranted)
	end
end

return PurchaseHandler
