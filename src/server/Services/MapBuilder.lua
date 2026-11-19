-- Gera o mapa inteiro por código: terreno, zonas temáticas, decoração e iluminação.
-- Usa uma semente fixa, então o mapa sai igual toda vez.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapBuilder = {}

local M = Enum.Material
local rng = Random.new(2026)
local terrain = workspace.Terrain
local mapFolder

local PATH_HALF_WIDTH = 6
local LAST_ZONE = #Config.Enemies
local EDGE = Config.GetZoneEnd(LAST_ZONE)

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { terrain }

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local BAD_GROUND = { [M.Water] = true, [M.CrackedLava] = true }

-- ===================== Utilidades =====================

local FIRST_PROPS = { "Shape", "Size", "CFrame", "Position", "CanCollide" }

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = M.SmoothPlastic
	for _, key in ipairs(FIRST_PROPS) do
		if props[key] ~= nil then
			p[key] = props[key]
		end
	end
	for key, value in pairs(props) do
		if not table.find(FIRST_PROPS, key) then
			p[key] = value
		end
	end
	p.Parent = parent or mapFolder
	return p
end

-- Enfeites que não bloqueiam o clique nos monstros
local function decorProps(props)
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return props
end

local function ball(center, diameter, props, parent)
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.one * diameter
	props.Position = center
	return part(props, parent)
end

local function vcyl(center, height, diameter, props, parent)
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2)
	return part(props, parent)
end

local function group(name)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = mapFolder
	return model
end

local function shade(color, amount)
	return color:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, amount or 0.18))
end

local function addLight(parentPart, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1.5
	light.Shadows = false
	light.Parent = parentPart
end

local function addFire(parentPart, size, heat)
	local fire = Instance.new("Fire")
	fire.Size = size
	fire.Heat = heat
	fire.Color = Color3.fromRGB(255, 140, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
	fire.Parent = parentPart
end

local function randomPointInRing(inner, outer)
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = math.sqrt(rng:NextNumber(inner * inner, outer * outer))
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function nearPath(point, margin)
	return point.Z < 0 and math.abs(point.X) < PATH_HALF_WIDTH + margin
end

local function groundAt(x, z)
	local result = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), terrainParams)
	if result then
		return result.Position, result.Material
	end
	return Vector3.new(x, 0, z), nil
end

-- Acha um lugar livre na zona (sem caminho, água, lava ou outro enfeite)
local function findSpot(zone, footprint)
	local inner, outer = Config.GetZoneStart(zone), Config.GetZoneEnd(zone)
	for _ = 1, 25 do
		local point = randomPointInRing(inner + footprint, outer - footprint)
		if not nearPath(point, footprint + 4) then
			local position, material = groundAt(point.X, point.Z)
			if not BAD_GROUND[material] and #workspace:GetPartBoundsInRadius(position, footprint, overlapParams) == 0 then
				return position
			end
		end
	end
	return nil
end

local function scatter(zone, count, footprint, builder)
	for _ = 1, count do
		local position = findSpot(zone, footprint)
		if position then
			builder(position)
		end
	end
end

-- Ponto aleatório para recursos de terreno (antes dos enfeites existirem)
local function terrainSpot(zone, margin)
	local inner, outer = Config.GetZoneStart(zone), Config.GetZoneEnd(zone)
	for _ = 1, 25 do
		local point = randomPointInRing(inner + margin, outer - margin)
		if not nearPath(point, margin + 4) then
			return point
		end
	end
	return randomPointInRing(inner + margin, outer - margin)
end

-- ===================== Enfeites =====================

local WOOD = Color3.fromRGB(105, 72, 45)

local function roundTree(position, scale, leafColor)
	local model = group("Arvore")
	local height = 7 * scale
	vcyl(position + Vector3.new(0, height / 2, 0), height, 1.4 * scale, { Color = WOOD, Material = M.Wood }, model)
	local top = position + Vector3.new(0, height + scale, 0)
	ball(top, 7 * scale, decorProps({ Color = shade(leafColor), Material = M.Grass }), model)
	for i = 1, 3 do
		local angle = i * 2.1 + rng:NextNumber(0, 0.8)
		local offset = Vector3.new(math.cos(angle) * 2.4 * scale, rng:NextNumber(-1, 1) * scale, math.sin(angle) * 2.4 * scale)
		ball(top + offset, rng:NextNumber(4, 5.5) * scale, decorProps({ Color = shade(leafColor), Material = M.Grass }), model)
	end
end

local function pineTree(position, scale, leafColor)
	local model = group("Pinheiro")
	local trunk = 4 * scale
	vcyl(position + Vector3.new(0, trunk / 2, 0), trunk, 1.2 * scale, { Color = WOOD, Material = M.Wood }, model)
	for i = 0, 3 do
		local diameter = (8 - 1.8 * i) * scale
		local y = trunk + i * 2.1 * scale
		vcyl(position + Vector3.new(0, y, 0), 1.7 * scale, diameter, decorProps({ Color = shade(leafColor, 0.1), Material = M.Grass }), model)
	end
end

local function deadTree(position, scale, color)
	local model = group("ArvoreSeca")
	local height = 9 * scale
	vcyl(position + Vector3.new(0, height / 2, 0), height, 1.2 * scale, { Color = color, Material = M.Wood }, model)
	for _ = 1, 3 do
		local start = rng:NextNumber(0.45, 0.9) * height
		local length = rng:NextNumber(3, 5) * scale
		local cf = CFrame.new(position + Vector3.new(0, start, 0))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			* CFrame.Angles(0, 0, math.rad(rng:NextNumber(35, 65)))
			* CFrame.new(length / 2, 0, 0)
		part(decorProps({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, 0.5 * scale, 0.5 * scale), CFrame = cf, Color = color, Material = M.Wood }), model)
	end
end

local FLOWER_COLORS = {
	Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 70), Color3.fromRGB(170, 120, 255),
	Color3.fromRGB(255, 255, 255), Color3.fromRGB(90, 170, 255),
}

local function flower(position)
	local model = group("Flor")
	part(decorProps({ Size = Vector3.new(0.15, 1, 0.15), Position = position + Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(60, 140, 50) }), model)
	ball(position + Vector3.new(0, 1.1, 0), 0.7, decorProps({ Color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)] }), model)
end

local function bush(position, scale, color)
	local model = group("Arbusto")
	for _ = 1, 3 do
		local offset = Vector3.new(rng:NextNumber(-1, 1) * scale, 0.8 * scale, rng:NextNumber(-1, 1) * scale)
		ball(position + offset, rng:NextNumber(2.5, 4) * scale, decorProps({ Color = shade(color), Material = M.Grass }), model)
	end
end

local function mushroom(position, scale)
	local model = group("Cogumelo")
	local red = Color3.fromRGB(210, 50, 50)
	vcyl(position + Vector3.new(0, 0.8 * scale, 0), 1.6 * scale, 0.6 * scale, { Color = Color3.fromRGB(240, 230, 210) }, model)
	ball(position + Vector3.new(0, 1.8 * scale, 0), 2.2 * scale, decorProps({ Color = red }), model)
	vcyl(position + Vector3.new(0, 1.7 * scale, 0), 0.4 * scale, 2.4 * scale, decorProps({ Color = red }), model)
	for i = 1, 4 do
		local angle = i * math.pi / 2 + 0.4
		local spot = position + Vector3.new(math.cos(angle) * 0.6 * scale, 2.65 * scale, math.sin(angle) * 0.6 * scale)
		ball(spot, 0.35 * scale, decorProps({ Color = Color3.new(1, 1, 1) }), model)
	end
end

local function campfire(position)
	local model = group("Fogueira")
	for _, yaw in ipairs({ 0.6, -0.6 }) do
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 0.6, 0.6), CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, yaw, 0), Color = Color3.fromRGB(80, 50, 30), Material = M.Wood }, model)
	end
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2
		ball(position + Vector3.new(math.cos(angle) * 1.8, 0.2, math.sin(angle) * 1.8), 0.8, { Color = Color3.fromRGB(110, 110, 115), Material = M.Slate }, model)
	end
	local flame = part(decorProps({ Size = Vector3.one, Position = position + Vector3.new(0, 0.8, 0), Transparency = 1 }), model)
	addFire(flame, 5, 9)
	addLight(flame, Color3.fromRGB(255, 150, 60), 24, 2)
end

local function tombstone(position)
	local model = group("Lapide")
	local stone = Color3.fromRGB(125, 125, 135)
	local cf = CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
		* CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, math.rad(rng:NextNumber(-8, 8)))
	if rng:NextNumber() < 0.3 then
		part({ Size = Vector3.new(0.5, 3.4, 0.5), CFrame = cf * CFrame.new(0, 1.7, 0), Color = stone, Material = M.Slate }, model)
		part({ Size = Vector3.new(2, 0.5, 0.5), CFrame = cf * CFrame.new(0, 2.4, 0), Color = stone, Material = M.Slate }, model)
	else
		part({ Size = Vector3.new(2, 2.4, 0.6), CFrame = cf * CFrame.new(0, 1.2, 0), Color = shade(stone, 0.2), Material = M.Slate }, model)
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 2, 2), CFrame = cf * CFrame.new(0, 2.4, 0) * CFrame.Angles(0, math.pi / 2, 0), Color = stone, Material = M.Slate }, model)
	end
	part(decorProps({ Size = Vector3.new(2.2, 0.4, 3.5), CFrame = cf * CFrame.new(0, 0.1, -2), Color = Color3.fromRGB(70, 55, 45), Material = M.Ground }), model)
end

local function lantern(position, color, height)
	local model = group("Lanterna")
	local metal = Color3.fromRGB(40, 40, 45)
	part({ Size = Vector3.new(0.4, height, 0.4), Position = position + Vector3.new(0, height / 2, 0), Color = metal, Material = M.Metal }, model)
	part({ Size = Vector3.new(1.3, 0.3, 1.3), Position = position + Vector3.new(0, height + 1.4, 0), Color = metal, Material = M.Metal }, model)
	local glow = part({ Size = Vector3.new(0.8, 1.1, 0.8), Position = position + Vector3.new(0, height + 0.7, 0), Color = color, Material = M.Neon }, model)
	addLight(glow, color, 20, 1.6)
end

local function boulder(position, radius, material)
	terrain:FillBall(position - Vector3.new(0, radius * 0.3, 0), radius, material)
end

local function rockPillar(position, scale, material)
	local radius = 6 * scale
	local y = 0
	for _ = 1, 4 do
		terrain:FillBall(position + Vector3.new(rng:NextNumber(-1, 1), y, rng:NextNumber(-1, 1)), radius, material)
		y = y + radius * 0.9
		radius = radius * 0.82
	end
end

local function basaltSpike(position, scale)
	local steps = { { 4, 0 }, { 3, 3 }, { 2, 5.5 }, { 1.2, 7.5 } }
	for _, step in ipairs(steps) do
		terrain:FillBall(position + Vector3.new(0, step[2] * scale, 0), step[1] * scale, M.Basalt)
	end
end

-- Abre espaço acima (caso caia num morro)
local function clearAbove(position, radius)
	terrain:FillCylinder(CFrame.new(position.X, 6, position.Z), 12, radius, M.Air)
end

local function lavaPool(position, radius)
	clearAbove(position, radius + 2)
	terrain:FillCylinder(CFrame.new(position.X, -0.8, position.Z), 1.8, radius + 1.5, M.Basalt)
	terrain:FillCylinder(CFrame.new(position.X, -0.7, position.Z), 1.8, radius, M.CrackedLava)
	local flame = part(decorProps({ Size = Vector3.one, Position = Vector3.new(position.X, 0.6, position.Z), Transparency = 1 }))
	flame.Name = "Lava"
	addFire(flame, math.min(radius, 10), 12)
	addLight(flame, Color3.fromRGB(255, 100, 30), radius * 3, 2)
end

local function pond(position, radius)
	clearAbove(position, radius + 3)
	terrain:FillCylinder(CFrame.new(position.X, -1.5, position.Z), 3, radius + 2.5, M.Sand)
	terrain:FillCylinder(CFrame.new(position.X, -1.6, position.Z), 3, radius, M.Water)
end

-- ===================== Temas das zonas =====================
-- Um tema por monstro, na mesma ordem do Config.Enemies

local THEMES = {
	{ -- Campo dos Slimes
		Ground = M.Grass, Color = Color3.fromRGB(110, 185, 75),
		Terrain = function(zone)
			for _ = 1, 2 do
				pond(terrainSpot(zone, 12), rng:NextNumber(6, 9))
			end
		end,
		Decorate = function(zone)
			scatter(zone, 16, 5, function(p) roundTree(p, rng:NextNumber(0.9, 1.3), Color3.fromRGB(95, 175, 60)) end)
			scatter(zone, 25, 2.5, function(p) bush(p, rng:NextNumber(0.8, 1.2), Color3.fromRGB(80, 160, 55)) end)
			scatter(zone, 80, 0.6, flower)
		end,
	},
	{ -- Floresta Goblin
		Ground = M.LeafyGrass, Color = Color3.fromRGB(70, 125, 50),
		Terrain = function(zone)
			for _ = 1, 10 do
				boulder(terrainSpot(zone, 6), rng:NextNumber(2, 4), M.Rock)
			end
		end,
		Decorate = function(zone)
			for _ = 1, 3 do
				local p = findSpot(zone, 6)
				if p then
					campfire(p)
				end
			end
			scatter(zone, 45, 5, function(p) roundTree(p, rng:NextNumber(1, 1.5), Color3.fromRGB(55, 120, 45)) end)
			scatter(zone, 30, 4, function(p) pineTree(p, rng:NextNumber(1, 1.6), Color3.fromRGB(40, 95, 50)) end)
			scatter(zone, 18, 1.5, function(p) mushroom(p, rng:NextNumber(0.8, 1.4)) end)
			scatter(zone, 15, 2.5, function(p) bush(p, 1, Color3.fromRGB(50, 110, 45)) end)
		end,
	},
	{ -- Cemitério Sombrio
		Ground = M.Ground, Color = Color3.fromRGB(80, 70, 75),
		Terrain = function(zone)
			for _ = 1, 8 do
				boulder(terrainSpot(zone, 6), rng:NextNumber(2, 3.5), M.Slate)
			end
		end,
		Decorate = function(zone)
			scatter(zone, 12, 3, function(p) lantern(p, Color3.fromRGB(170, 110, 255), 6) end)
			scatter(zone, 18, 4, function(p) deadTree(p, rng:NextNumber(0.9, 1.3), Color3.fromRGB(60, 50, 50)) end)
			scatter(zone, 55, 2.2, tombstone)
		end,
	},
	{ -- Cânion dos Ogros
		Ground = M.Sandstone, Color = Color3.fromRGB(195, 140, 90),
		Terrain = function(zone)
			for _ = 1, 8 do
				rockPillar(terrainSpot(zone, 10), rng:NextNumber(0.8, 1.3), M.Sandstone)
			end
			for _ = 1, 25 do
				boulder(terrainSpot(zone, 8), rng:NextNumber(3, 7), M.Rock)
			end
		end,
		Decorate = function(zone)
			scatter(zone, 5, 6, campfire)
			scatter(zone, 20, 2, function(p) deadTree(p, rng:NextNumber(0.35, 0.5), Color3.fromRGB(120, 90, 60)) end)
		end,
	},
	{ -- Vulcão do Dragão
		Ground = M.Basalt, Color = Color3.fromRGB(55, 48, 48),
		Terrain = function(zone)
			for _ = 1, 12 do
				lavaPool(terrainSpot(zone, 12), rng:NextNumber(5, 10))
			end
			for _ = 1, 16 do
				basaltSpike(terrainSpot(zone, 6), rng:NextNumber(0.8, 1.6))
			end
		end,
		Decorate = function(zone)
			scatter(zone, 10, 3, function(p) deadTree(p, rng:NextNumber(0.8, 1.1), Color3.fromRGB(30, 25, 25)) end)
		end,
	},
}

local DEFAULT_THEME = { Ground = M.Grass, Color = Color3.fromRGB(110, 185, 75) }

-- ===================== Partes do mapa =====================

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 135, 145)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1

	local function getOrCreate(className, name)
		local object = Lighting:FindFirstChild(name) or Instance.new(className)
		object.Name = name
		object.Parent = Lighting
		return object
	end

	local atmosphere = getOrCreate("Atmosphere", "Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(199, 199, 199)
	atmosphere.Decay = Color3.fromRGB(106, 112, 125)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.5

	local bloom = getOrCreate("BloomEffect", "Bloom")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.2

	local sunRays = getOrCreate("SunRaysEffect", "SunRays")
	sunRays.Intensity = 0.06
	sunRays.Spread = 0.8

	local color = getOrCreate("ColorCorrectionEffect", "ZoneColor")
	color.Saturation = 0.15
	color.Contrast = 0.08
	color.Brightness = 0.02

	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.7
	clouds.Parent = terrain

	terrain.WaterColor = Color3.fromRGB(40, 140, 170)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.1
	terrain.WaterReflectance = 0.6
end

local function buildTerrain()
	terrain:SetMaterialColor(M.Rock, Color3.fromRGB(125, 115, 105))
	terrain:SetMaterialColor(M.Snow, Color3.fromRGB(240, 245, 255))
	terrain:SetMaterialColor(M.Cobblestone, Color3.fromRGB(150, 140, 125))
	terrain:SetMaterialColor(M.Pavement, Color3.fromRGB(185, 178, 165))
	terrain:SetMaterialColor(M.Sand, Color3.fromRGB(220, 200, 150))
	terrain:SetMaterialColor(M.Slate, Color3.fromRGB(95, 95, 105))
	terrain:SetMaterialColor(M.CrackedLava, Color3.fromRGB(255, 90, 20))

	-- Base de pedra embaixo de tudo
	terrain:FillCylinder(CFrame.new(0, -6, 0), 12, EDGE + 90, M.Rock)

	-- Anéis das zonas, de fora para dentro
	for zone = LAST_ZONE, 1, -1 do
		local theme = THEMES[zone] or DEFAULT_THEME
		terrain:SetMaterialColor(theme.Ground, theme.Color)
		terrain:FillCylinder(CFrame.new(0, -4, 0), 8, Config.GetZoneEnd(zone), theme.Ground)
	end

	-- Morros suaves
	for zone = 1, LAST_ZONE do
		local theme = THEMES[zone] or DEFAULT_THEME
		for _ = 1, 14 do
			local radius = rng:NextNumber(8, 16)
			local point = terrainSpot(zone, radius)
			terrain:FillBall(Vector3.new(point.X, -radius * 0.78, point.Z), radius, theme.Ground)
		end
	end

	-- Recursos especiais de cada zona (lagos, lava, rochas)
	for zone = 1, LAST_ZONE do
		local theme = THEMES[zone]
		if theme and theme.Terrain then
			theme.Terrain(zone)
		end
	end

	-- Montanhas em volta do mapa
	local count = 70
	for i = 1, count do
		local angle = i / count * math.pi * 2 + rng:NextNumber(-0.03, 0.03)
		local radius = rng:NextNumber(25, 45)
		local distance = EDGE + 25 + rng:NextNumber(0, 25)
		local center = Vector3.new(math.cos(angle) * distance, -5, math.sin(angle) * distance)
		terrain:FillBall(center, radius, M.Rock)
		if radius > 33 then
			terrain:FillBall(center + Vector3.new(0, radius * 0.6, 0), radius * 0.45, M.Snow)
		end
	end

	-- Caminho de pedra da vila até o vulcão
	local length = EDGE
	terrain:FillBlock(CFrame.new(0, 12, -length / 2), Vector3.new(PATH_HALF_WIDTH * 2 + 2, 24, length), M.Air)
	terrain:FillBlock(CFrame.new(0, -1.5, -length / 2), Vector3.new(PATH_HALF_WIDTH * 2, 3, length), M.Cobblestone)

	-- Praça da vila
	terrain:FillBlock(CFrame.new(0, 12, 0), Vector3.new(Config.PlazaRadius * 2 + 4, 24, Config.PlazaRadius * 2 + 4), M.Air)
	terrain:FillCylinder(CFrame.new(0, -1.5, 0), 3, Config.PlazaRadius + 2, M.Grass)
	terrain:FillCylinder(CFrame.new(0, -1.5, 0), 3, Config.PlazaRadius, M.Pavement)
end

local function buildVillage()
	-- Fonte no centro
	local fountain = group("Fonte")
	local stone = Color3.fromRGB(200, 195, 185)
	vcyl(Vector3.new(0, 0.75, 0), 1.5, 11, { Color = stone, Material = M.Marble }, fountain)
	vcyl(Vector3.new(0, 1.45, 0), 0.2, 9.6, decorProps({ Color = Color3.fromRGB(70, 170, 230), Material = M.Glass, Transparency = 0.25, Reflectance = 0.2 }), fountain)
	vcyl(Vector3.new(0, 3, 0), 3.5, 1.4, { Color = stone, Material = M.Marble }, fountain)
	vcyl(Vector3.new(0, 4.9, 0), 0.6, 4.5, { Color = stone, Material = M.Marble }, fountain)
	local top = vcyl(Vector3.new(0, 5.25, 0), 0.15, 3.8, decorProps({ Color = Color3.fromRGB(70, 170, 230), Material = M.Glass, Transparency = 0.25 }), fountain)
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(150, 220, 255)
	sparkle.Parent = top

	-- Postes de luz
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2 + math.pi / 8
		local r = Config.PlazaRadius - 2
		lantern(Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r), Color3.fromRGB(255, 210, 140), 7)
	end

	-- Ponto de nascimento ao sul da fonte
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation") or Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(0, 0.2, 10)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Material = M.Marble
	spawn.Color = Color3.fromRGB(230, 225, 215)
	spawn.Parent = workspace
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
end

local function buildGate(z, title, color)
	local model = group("Portao")
	local stone = Color3.fromRGB(140, 135, 130)
	for _, x in ipairs({ -PATH_HALF_WIDTH - 1.5, PATH_HALF_WIDTH + 1.5 }) do
		part({ Size = Vector3.new(2.5, 14, 2.5), Position = Vector3.new(x, 7, z), Color = stone, Material = M.Cobblestone }, model)
		local torch = part(decorProps({ Size = Vector3.one, Position = Vector3.new(x, 14.8, z), Transparency = 1 }), model)
		addFire(torch, 2.5, 6)
		addLight(torch, Color3.fromRGB(255, 160, 70), 18, 1.6)
	end
	part({ Size = Vector3.new(PATH_HALF_WIDTH * 2 + 5.5, 2, 2.5), Position = Vector3.new(0, 13, z), Color = stone, Material = M.Cobblestone }, model)

	local sign = part(decorProps({ Size = Vector3.new(12, 2.6, 0.4), Position = Vector3.new(0, 10.6, z), Color = Color3.fromRGB(90, 60, 40), Material = M.Wood }), model)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = sign
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = title
		text.TextScaled = true
		text.Font = Enum.Font.GothamBlack
		text.TextColor3 = color
		text.TextStrokeTransparency = 0
		text.Parent = gui
	end
end

function MapBuilder.Build()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = workspace
	overlapParams.FilterDescendantsInstances = { mapFolder }

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	setupLighting()
	buildTerrain()
	buildVillage()

	for zone, enemy in ipairs(Config.Enemies) do
		buildGate(-Config.GetZoneStart(zone), enemy.Zone or enemy.Name, enemy.Color)
	end

	for zone = 1, LAST_ZONE do
		local theme = THEMES[zone]
		if theme and theme.Decorate then
			theme.Decorate(zone)
		end
	end
end

return MapBuilder
