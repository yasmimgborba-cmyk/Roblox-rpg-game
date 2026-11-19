-- Configurações do jogo. Edite aqui preços, armas, monstros e IDs de Robux.
local Config = {}

Config.DataStoreName = "PlayerData_v1"

-- Armas: compre a próxima para causar mais dano
Config.Weapons = {
	{ Name = "Graveto", Price = 0, Damage = 1 },
	{ Name = "Espada de Madeira", Price = 50, Damage = 3 },
	{ Name = "Espada de Pedra", Price = 250, Damage = 8 },
	{ Name = "Espada de Ferro", Price = 1000, Damage = 20 },
	{ Name = "Espada de Ouro", Price = 5000, Damage = 50 },
	{ Name = "Espada de Diamante", Price = 25000, Damage = 130 },
	{ Name = "Lâmina Lendária", Price = 150000, Damage = 400 },
	{ Name = "Foice Cósmica", Price = 1000000, Damage = 1200 },
}

-- Monstros: os mais fortes ficam mais longe do centro (Distance = {min, max})
-- Style = visual do monstro | Zone = nome da área onde ele vive
Config.Enemies = {
	{ Name = "Slime", Style = "slime", Zone = "Campo dos Slimes", MaxHealth = 5, Reward = 2, Size = 3, Count = 10, Distance = { 20, 60 }, Color = Color3.fromRGB(90, 210, 90) },
	{ Name = "Goblin", Style = "goblin", Zone = "Floresta Goblin", MaxHealth = 40, Reward = 12, Size = 4, Count = 8, Distance = { 70, 120 }, Color = Color3.fromRGB(110, 160, 60) },
	{ Name = "Esqueleto", Style = "skeleton", Zone = "Cemitério Sombrio", MaxHealth = 250, Reward = 60, Size = 5, Count = 6, Distance = { 130, 180 }, Color = Color3.fromRGB(235, 232, 220) },
	{ Name = "Ogro", Style = "ogre", Zone = "Cânion dos Ogros", MaxHealth = 1500, Reward = 300, Size = 7, Count = 5, Distance = { 190, 240 }, Color = Color3.fromRGB(150, 120, 80) },
	{ Name = "Dragão", Style = "dragon", Zone = "Vulcão do Dragão", MaxHealth = 12000, Reward = 2000, Size = 10, Count = 3, Distance = { 250, 300 }, Color = Color3.fromRGB(200, 40, 40) },
}

Config.PlazaRadius = 16
Config.PlazaName = "Vila Inicial"

-- Onde começa a zona de cada monstro (raio a partir do centro)
function Config.GetZoneStart(index)
	if index == 1 then
		return Config.PlazaRadius
	end
	return Config.Enemies[index].Distance[1] - 5
end

-- Onde termina a zona de cada monstro
function Config.GetZoneEnd(index)
	local nextEnemy = Config.Enemies[index + 1]
	if nextEnemy then
		return nextEnemy.Distance[1] - 5
	end
	return Config.Enemies[index].Distance[2] + 20
end

-- Em qual zona está quem está a essa distância do centro (0 = vila)
function Config.GetZoneAt(distance)
	local zone = 0
	for index in ipairs(Config.Enemies) do
		if distance >= Config.GetZoneStart(index) then
			zone = index
		end
	end
	return zone
end

Config.RespawnTime = 5 -- segundos
Config.AttackRange = 30 -- distância máxima para clicar no monstro
Config.AttackCooldown = 0.12 -- evita auto-clicker de terceiros
Config.AutoAttackInterval = 0.5
Config.AutoAttackRange = 25

-- Renascimento: zera moedas e arma, mas dá bônus permanente de moedas
Config.Rebirth = {
	BasePrice = 10000,
	PriceMultiplier = 3,
	CoinBonus = 0.5, -- +50% de moedas por renascimento
}

-- ===== MONETIZAÇÃO (Robux) =====
-- Crie os itens no Creator Dashboard e cole os IDs aqui (0 = desativado)
Config.GamePasses = {
	DoubleCoins = { Id = 0, Name = "2x Moedas", Description = "Ganhe o dobro de moedas para sempre", Price = 99 },
	DoubleDamage = { Id = 0, Name = "2x Dano", Description = "Cause o dobro de dano para sempre", Price = 99 },
	AutoAttack = { Id = 0, Name = "Ataque Automático", Description = "Ataca monstros próximos sozinho", Price = 199 },
}

-- Pacotes de moedas (Developer Products). Podem ser comprados várias vezes.
-- A quantidade cresce com os renascimentos, então nunca perdem valor.
Config.DevProducts = {
	{ Id = 0, Name = "Saco de Moedas", Coins = 1000, Price = 25 },
	{ Id = 0, Name = "Baú de Moedas", Coins = 6000, Price = 99 },
	{ Id = 0, Name = "Tesouro do Rei", Coins = 40000, Price = 399 },
}

Config.PremiumCoinBonus = 1.1 -- +10% para jogadores Premium (aumenta o Premium Payouts)

function Config.GetRebirthPrice(rebirths)
	return math.floor(Config.Rebirth.BasePrice * (Config.Rebirth.PriceMultiplier ^ rebirths))
end

function Config.GetCoinMultiplier(rebirths, hasDoubleCoins, isPremium)
	local mult = 1 + rebirths * Config.Rebirth.CoinBonus
	if hasDoubleCoins then
		mult = mult * 2
	end
	if isPremium then
		mult = mult * Config.PremiumCoinBonus
	end
	return mult
end

function Config.GetProductCoins(product, rebirths)
	return math.floor(product.Coins * (1 + rebirths))
end

function Config.FormatNumber(n)
	n = math.floor(n)
	local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local i = 1
	local value = n
	while math.abs(value) >= 1000 and i < #suffixes do
		value = value / 1000
		i = i + 1
	end
	if i == 1 then
		return tostring(n)
	end
	return string.format("%.1f%s", value, suffixes[i])
end

return Config
