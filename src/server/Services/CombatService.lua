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

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { workspace.Terrain }

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local BAD_GROUND = { [Enum.Material.Water] = true, [Enum.Material.CrackedLava] = true }

-- Acha um lugar no chão da zona, longe de água, lava, árvores e outros monstros
local function findSpawnPosition(data)
	local fallback
	for _ = 1, 20 do
		local angle = math.random() * math.pi * 2
		local radius = data.Distance[1] + math.random() * (data.Distance[2] - data.Distance[1])
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		local result = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), terrainParams)
		local ground = result and result.Position or Vector3.new(x, 0, z)
		fallback = fallback or ground
		if result and not BAD_GROUND[result.Material] then
			local center = ground + Vector3.new(0, data.Size / 2, 0)
			if #workspace:GetPartBoundsInRadius(center, data.Size * 0.7, overlapParams) == 0 then
				return ground
			end
		end
	end
	return fallback
end

-- ===== Visual dos monstros =====
local function addPart(model, cf, size, color, material, shape)
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local BALL = Enum.PartType.Ball
local NEON = Enum.Material.Neon
local BLACK = Color3.new(0, 0, 0)
local BONE = Color3.fromRGB(240, 230, 200)

local function pair(fn)
	fn(-1)
	fn(1)
end

local STYLES = {}

STYLES.slime = function(model, cf, s, body, data)
	body.Material = Enum.Material.Glass
	body.Transparency = 0.2
	body.Reflectance = 0.1
	addPart(model, cf * CFrame.new(0, -0.05 * s, 0), Vector3.one * 0.55 * s, data.Color:Lerp(BLACK, 0.35), nil, BALL)
	pair(function(side)
		local eye = cf * CFrame.new(side * 0.18 * s, 0.12 * s, -0.42 * s)
		addPart(model, eye, Vector3.one * 0.2 * s, BLACK, nil, BALL)
		addPart(model, eye * CFrame.new(0.03 * s, 0.04 * s, -0.08 * s), Vector3.one * 0.07 * s, Color3.new(1, 1, 1), NEON, BALL)
	end)
end

STYLES.goblin = function(model, cf, s, body, data)
	pair(function(side)
		addPart(model, cf * CFrame.new(side * 0.2 * s, 0.12 * s, -0.42 * s), Vector3.one * 0.16 * s, Color3.fromRGB(255, 220, 40), NEON, BALL)
		addPart(model, cf * CFrame.new(side * 0.55 * s, 0.15 * s, 0) * CFrame.Angles(0, 0, side * 0.5), Vector3.new(0.45, 0.1, 0.22) * s, data.Color)
	end)
	addPart(model, cf * CFrame.new(0, 0, -0.5 * s), Vector3.one * 0.16 * s, data.Color:Lerp(BLACK, 0.25), nil, BALL)
	addPart(model, cf * CFrame.new(0, -0.2 * s, -0.46 * s), Vector3.new(0.25, 0.04, 0.05) * s, BLACK)
	addPart(model, cf * CFrame.new(0.55 * s, -0.2 * s, -0.25 * s), Vector3.new(0.1, 0.1, 0.7) * s, Color3.fromRGB(170, 170, 180), Enum.Material.Metal)
end

STYLES.skeleton = function(model, cf, s, body, data)
	body.Material = Enum.Material.Marble
	pair(function(side)
		addPart(model, cf * CFrame.new(side * 0.18 * s, 0.08 * s, -0.4 * s), Vector3.one * 0.22 * s, BLACK, nil, BALL)
		addPart(model, cf * CFrame.new(side * 0.18 * s, 0.08 * s, -0.49 * s), Vector3.one * 0.08 * s, Color3.fromRGB(255, 40, 40), NEON, BALL)
	end)
	addPart(model, cf * CFrame.new(0, -0.1 * s, -0.48 * s), Vector3.new(0.08, 0.1, 0.05) * s, BLACK)
	addPart(model, cf * CFrame.new(0, -0.38 * s, -0.25 * s), Vector3.new(0.45, 0.14, 0.3) * s, data.Color:Lerp(BLACK, 0.1))
	for i = -2, 2 do
		addPart(model, cf * CFrame.new(i * 0.07 * s, -0.29 * s, -0.4 * s), Vector3.new(0.05, 0.06, 0.04) * s, Color3.new(1, 1, 1))
	end
	addPart(model, cf * CFrame.new(0.6 * s, 0, -0.1 * s), Vector3.new(0.1, 0.9, 0.18) * s, Color3.fromRGB(140, 90, 60), Enum.Material.CorrodedMetal)
end

STYLES.ogre = function(model, cf, s, body, data)
	pair(function(side)
		addPart(model, cf * CFrame.new(side * 0.17 * s, 0.17 * s, -0.46 * s), Vector3.one * 0.12 * s, Color3.fromRGB(255, 60, 30), NEON, BALL)
		addPart(model, cf * CFrame.new(side * 0.12 * s, -0.2 * s, -0.47 * s) * CFrame.Angles(0, 0, -side * 0.15), Vector3.new(0.08, 0.22, 0.08) * s, BONE)
		addPart(model, cf * CFrame.new(side * 0.25 * s, 0.5 * s, -0.05 * s) * CFrame.Angles(0, 0, -side * 0.35), Vector3.new(0.12, 0.35, 0.12) * s, BONE)
	end)
	addPart(model, cf * CFrame.new(0, 0.28 * s, -0.43 * s), Vector3.new(0.5, 0.08, 0.12) * s, data.Color:Lerp(BLACK, 0.5))
	addPart(model, cf * CFrame.new(0.65 * s, 0, -0.1 * s) * CFrame.Angles(0, 0, math.pi / 2 - 0.3), Vector3.new(1.2, 0.22, 0.22) * s, Color3.fromRGB(100, 65, 40), Enum.Material.Wood, Enum.PartType.Cylinder)
end

STYLES.dragon = function(model, cf, s, body, data)
	local dark = data.Color:Lerp(BLACK, 0.35)
	local snout = addPart(model, cf * CFrame.new(0, -0.05 * s, -0.5 * s), Vector3.one * 0.45 * s, dark, nil, BALL)
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 4
	fire.Parent = snout
	pair(function(side)
		addPart(model, cf * CFrame.new(side * 0.07 * s, 0, -0.72 * s), Vector3.one * 0.06 * s, BLACK, nil, BALL)
		addPart(model, cf * CFrame.new(side * 0.2 * s, 0.18 * s, -0.42 * s), Vector3.one * 0.13 * s, Color3.fromRGB(255, 210, 0), NEON, BALL)
		addPart(model, cf * CFrame.new(side * 0.2 * s, 0.52 * s, 0.05 * s) * CFrame.Angles(0.5, 0, -side * 0.25), Vector3.new(0.1, 0.4, 0.1) * s, BONE)
		addPart(model, cf * CFrame.new(side * 0.75 * s, 0.3 * s, 0.15 * s) * CFrame.Angles(0, 0, side * 0.45), Vector3.new(0.9, 0.05, 0.55) * s, dark)
		addPart(model, cf * CFrame.new(side * 1.15 * s, 0.6 * s, 0.25 * s) * CFrame.Angles(0, 0, side * 0.9), Vector3.new(0.5, 0.05, 0.4) * s, dark)
	end)
	for _, z in ipairs({ -0.1, 0.1, 0.3 }) do
		local y = math.sqrt(0.25 - z * z) + 0.05
		addPart(model, cf * CFrame.new(0, y * s, z * s), Vector3.new(0.06, 0.18, 0.12) * s, BONE)
	end
	local tail = { { -0.3, 0.55, 0.3 }, { -0.33, 0.75, 0.22 }, { -0.3, 0.92, 0.15 } }
	for _, t in ipairs(tail) do
		addPart(model, cf * CFrame.new(0, t[1] * s, t[2] * s), Vector3.one * t[3] * s, data.Color, nil, BALL)
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 40)
	light.Range = 14
	light.Parent = body
end

local function buildVisual(model, data, ground)
	local s = data.Size
	local center = ground + Vector3.new(0, s / 2, 0)
	local cf = CFrame.lookAt(center, Vector3.new(0, center.Y, 0))
	local body = addPart(model, cf, Vector3.one * s, data.Color, nil, BALL)
	body.Name = "Body"
	body.CanCollide = true
	model.PrimaryPart = body
	local style = STYLES[data.Style] or STYLES.slime
	style(model, cf, s, body, data)
	return body
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
		local original = Config.Enemies[model:GetAttribute("EnemyIndex")].Color
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
	gui.StudsOffset = Vector3.new(0, data.Size * 0.75 + 1.5, 0)
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
	local model = Instance.new("Model")
	model.Name = data.Name
	local body = buildVisual(model, data, findSpawnPosition(data))

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
	local mapFolder = workspace:FindFirstChild("Map")
	overlapParams.FilterDescendantsInstances = mapFolder and { mapFolder, enemiesFolder } or { enemiesFolder }

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
