-- Ponto de entrada do servidor
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Services = script.Parent:WaitForChild("Services")
local DataService = require(Services.DataService)
local MonetizationService = require(Services.MonetizationService)
local CombatService = require(Services.CombatService)
local MapBuilder = require(Services.MapBuilder)

-- Remotes para o cliente
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local buyWeapon = Instance.new("RemoteFunction")
buyWeapon.Name = "BuyWeapon"
buyWeapon.Parent = remotes
local rebirth = Instance.new("RemoteFunction")
rebirth.Name = "Rebirth"
rebirth.Parent = remotes
remotes.Parent = ReplicatedStorage

MapBuilder.Build()
DataService.Start()
MonetizationService.Start(DataService)
CombatService.Start(DataService, MonetizationService)

buyWeapon.OnServerInvoke = function(player, index)
	local profile = DataService.Get(player)
	if not profile then
		return false, "Carregando seus dados..."
	end
	if type(index) ~= "number" or index % 1 ~= 0 or not Config.Weapons[index] then
		return false, "Arma inválida."
	end
	if index <= profile.Weapon then
		return false, "Você já tem essa arma."
	end
	local weapon = Config.Weapons[index]
	if profile.Coins < weapon.Price then
		return false, "Moedas insuficientes."
	end
	DataService.Increment(player, "Coins", -weapon.Price)
	DataService.Set(player, "Weapon", index)
	return true, "Você comprou " .. weapon.Name .. "!"
end

rebirth.OnServerInvoke = function(player)
	local profile = DataService.Get(player)
	if not profile then
		return false, "Carregando seus dados..."
	end
	local price = Config.GetRebirthPrice(profile.Rebirths)
	if profile.Coins < price then
		return false, "Você precisa de " .. Config.FormatNumber(price) .. " moedas."
	end
	DataService.Set(player, "Coins", 0)
	DataService.Set(player, "Weapon", 1)
	DataService.Increment(player, "Rebirths", 1)
	task.spawn(DataService.Save, player)
	return true, "Renasceu! Bônus de moedas aumentou."
end

local function onPlayerAdded(player)
	local profile = DataService.Load(player)
	if profile then
		MonetizationService.LoadPlayer(player)
		player:SetAttribute("Loaded", true)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
