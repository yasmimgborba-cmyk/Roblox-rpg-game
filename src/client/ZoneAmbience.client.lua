-- Muda o clima (névoa e cor) ao trocar de zona e mostra o nome da zona na tela
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local atmosphere = Lighting:WaitForChild("Atmosphere", 15)
local colorFx = Lighting:WaitForChild("ZoneColor", 15)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Índice = zona (0 = vila). Zonas sem preset usam o da vila.
local PRESETS = {
	[0] = { Density = 0.3, Color = rgb(199, 199, 199), Decay = rgb(106, 112, 125), Tint = rgb(255, 255, 255) },
	[1] = { Density = 0.3, Color = rgb(205, 225, 235), Decay = rgb(110, 130, 150), Tint = rgb(255, 255, 250) },
	[2] = { Density = 0.4, Color = rgb(170, 200, 170), Decay = rgb(70, 100, 70), Tint = rgb(235, 255, 235) },
	[3] = { Density = 0.52, Color = rgb(125, 115, 155), Decay = rgb(55, 45, 80), Tint = rgb(200, 190, 235) },
	[4] = { Density = 0.36, Color = rgb(235, 205, 165), Decay = rgb(160, 110, 80), Tint = rgb(255, 240, 220) },
	[5] = { Density = 0.48, Color = rgb(200, 110, 80), Decay = rgb(110, 35, 20), Tint = rgb(255, 210, 195) },
}

local gui = Instance.new("ScreenGui")
gui.Name = "ZoneBanner"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0.14, 0)
banner.Size = UDim2.fromOffset(520, 56)
banner.BackgroundTransparency = 1
banner.Font = Enum.Font.GothamBlack
banner.TextScaled = true
banner.TextColor3 = Color3.new(1, 1, 1)
banner.TextStrokeTransparency = 1
banner.TextTransparency = 1
banner.Parent = gui

local function showBanner(text, color)
	banner.Text = text
	banner.TextColor3 = color
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.2
	task.delay(2.5, function()
		if banner.Text == text then
			TweenService:Create(banner, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function applyZone(zone)
	local preset = PRESETS[zone] or PRESETS[0]
	local info = TweenInfo.new(2, Enum.EasingStyle.Sine)
	if atmosphere then
		TweenService:Create(atmosphere, info, { Density = preset.Density, Color = preset.Color, Decay = preset.Decay }):Play()
	end
	if colorFx then
		TweenService:Create(colorFx, info, { TintColor = preset.Tint }):Play()
	end
	if zone == 0 then
		showBanner(Config.PlazaName, Color3.fromRGB(255, 230, 160))
	else
		local enemy = Config.Enemies[zone]
		showBanner(enemy.Zone or enemy.Name, enemy.Color)
	end
end

local currentZone = nil
while true do
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
		local zone = Config.GetZoneAt(flat.Magnitude)
		if zone ~= currentZone then
			currentZone = zone
			applyZone(zone)
		end
	end
	task.wait(0.5)
end
