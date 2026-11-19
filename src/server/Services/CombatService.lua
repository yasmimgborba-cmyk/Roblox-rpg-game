-- Monstros: nascem no mapa, levam dano ao clicar e dão moedas
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CombatService = {}

local DataService
local MonetizationService
local enemiesFolder
local lastAttack = {}

local function getDamage(player)
	local profile = DataService.Get(player)
	if not profile then
		return 0
	end
	local weapon = Config.Weapons[profile.Weapon] or Config.Weapons[1]
	local damage = weapon.Damage
	if MonetizationService.HasPass(player, "DoubleDamage") then
		damage = damage * 2
	end
	return damage
end

local function getCoinMultiplier(player)
	local profile = DataService.Get(player)
	return Config.GetCoinMultiplier(
		profile.Rebirths,
		MonetizationService.HasPass(player, "DoubleCoins"),
		player.MembershipType == Enum.MembershipType.Premium
	)
end

local function updateBillboard(model)
	local body = model:FindFirstChild("Body")
	local gui = body and body:FindFirstChild("Info")
	if not gui then
		return
	end
	local health = model:GetAttribute("Health")
	local maxHealth = model:GetAttribute("MaxHealth")
	gui.Bar.Fill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
	gui.Bar.Label.Text = Config.FormatNumber(health) .. " / " .. Config.FormatNumber(maxHealth)
end

local function randomPosition(range, height)
	local angle = math.random() * math.pi * 2
	local radius = range[1] + math.random() * (range[2] - range[1])
	return Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
end

local spawnEnemy

local function onDefeated(model, player)
	model:SetAttribute("Dead", true)
	local index = model:GetAttribute("EnemyIndex")
	local data = Config.Enemies[index]
	if player and player.Parent and DataService.Get(player) then
		local reward = math.floor(data.Reward * getCoinMultiplier(player))
		DataService.Increment(player, "Coins", reward)
	end
	model:Destroy()
	task.delay(Config.RespawnTime, spawnEnemy, index)
end

function CombatService.Damage(player, model)
	if not model.Parent or model:GetAttribute("Dead") then
		return
	end
	local damage = getDamage(player)
	if damage <= 0 then
		return
	end
	local health = math.max(model:GetAttribute("Health") - damage, 0)
	model:SetAttribute("Health", health)
	updateBillboard(model)

	local body = model:FindFirstChild("Body")
	if body then
		local original = body.Color
		body.Color = Color3.new(1, 1, 1)
		task.delay(0.08, function()
			if body.Parent then
				body.Color = original
			end
		end)
	end

	if health <= 0 then
		onDefeated(model, player)
	end
end

local function createBillboard(body, data)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.fromOffset(160, 46)
	gui.StudsOffset = Vector3.new(0, data.Size / 2 + 1.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120

	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1, 0.5)
	name.BackgroundTransparency = 1
	name.Text = data.Name
	name.TextScaled = true
	name.Font = Enum.Font.GothamBold
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Parent = gui

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromScale(0, 0.55)
	bar.Size = UDim2.fromScale(1, 0.4)
	bar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bar.BorderSizePixel = 0
	bar.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	fill.BorderSizePixel = 0
	fill.Parent = bar

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.ZIndex = 2
	label.Parent = bar

	gui.Parent = body
end

spawnEnemy = function(index)
	local data = Config.Enemies[index]
	local position = randomPosition(data.Distance, data.Size / 2)

	local model = Instance.new("Model")
	model.Name = data.Name

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(data.Size, data.Size, data.Size)
	body.Color = data.Color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.Position = position
	body.Parent = model
	model.PrimaryPart = body

	for _, side in ipairs({ -1, 1 }) do
		local eye = Instance.new("Part")
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(1, 1, 1) * data.Size * 0.2
		eye.Color = Color3.new(0, 0, 0)
		eye.Anchored = true
		eye.CanCollide = false
		eye.Position = position + Vector3.new(side * data.Size * 0.2, data.Size * 0.15, -data.Size * 0.42)
		eye.Parent = model
	end

	model:SetAttribute("EnemyIndex", index)
	model:SetAttribute("MaxHealth", data.MaxHealth)
	model:SetAttribute("Health", data.MaxHealth)
	createBillboard(body, data)
	updateBillboard(model)

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = Config.AttackRange
	click.Parent = model
	click.MouseClick:Connect(function(player)
		local now = os.clock()
		if lastAttack[player] and now - lastAttack[player] < Config.AttackCooldown then
			return
		end
		lastAttack[player] = now
		CombatService.Damage(player, model)
	end)

	model.Parent = enemiesFolder
end

local function autoAttackLoop()
	while true do
		task.wait(Config.AutoAttackInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			if MonetizationService.HasPass(player, "AutoAttack") then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					local nearest, nearestDistance = nil, Config.AutoAttackRange
					for _, model in ipairs(enemiesFolder:GetChildren()) do
						if model.PrimaryPart and not model:GetAttribute("Dead") then
							local distance = (model.PrimaryPart.Position - root.Position).Magnitude
							if distance < nearestDistance then
								nearest, nearestDistance = model, distance
							end
						end
					end
					if nearest then
						CombatService.Damage(player, nearest)
					end
				end
			end
		end
	end
end

function CombatService.Start(dataService, monetizationService)
	DataService = dataService
	MonetizationService = monetizationService

	enemiesFolder = Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = workspace

	for index, data in ipairs(Config.Enemies) do
		for _ = 1, data.Count do
			spawnEnemy(index)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
	end)

	task.spawn(autoAttackLoop)
end

return CombatService
