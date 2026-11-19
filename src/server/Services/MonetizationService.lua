-- Gamepasses e pacotes de moedas (Robux)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MonetizationService = {}

local DataService
local owned = {}

local function grantPass(player, key)
	owned[player] = owned[player] or {}
	owned[player][key] = true
	player:SetAttribute("Pass_" .. key, true)
end

function MonetizationService.HasPass(player, key)
	return owned[player] ~= nil and owned[player][key] == true
end

function MonetizationService.LoadPlayer(player)
	owned[player] = owned[player] or {}
	for key, pass in pairs(Config.GamePasses) do
		if pass.Id ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and has then
				grantPass(player, key)
			end
		end
	end
end

local function findProduct(productId)
	for _, product in ipairs(Config.DevProducts) do
		if product.Id == productId then
			return product
		end
	end
	return nil
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.Get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Já entregue antes? Não entrega de novo.
	if table.find(profile.Receipts, receiptInfo.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local product = findProduct(receiptInfo.ProductId)
	if not product then
		warn("[Monetization] Produto desconhecido: " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	DataService.Increment(player, "Coins", Config.GetProductCoins(product, profile.Rebirths))
	table.insert(profile.Receipts, receiptInfo.PurchaseId)
	while #profile.Receipts > 50 do
		table.remove(profile.Receipts, 1)
	end

	if DataService.Save(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function MonetizationService.Start(dataService)
	DataService = dataService

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, pass in pairs(Config.GamePasses) do
			if pass.Id == passId then
				grantPass(player, key)
			end
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt

	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
end

return MonetizationService
