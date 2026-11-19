-- Cria o chão, o ponto de nascimento e anéis que marcam cada zona
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapBuilder = {}

function MapBuilder.Build()
	if not workspace:FindFirstChild("Baseplate") and not workspace:FindFirstChild("Arena") then
		local ground = Instance.new("Part")
		ground.Name = "Arena"
		ground.Size = Vector3.new(700, 2, 700)
		ground.Position = Vector3.new(0, -1, 0)
		ground.Anchored = true
		ground.Material = Enum.Material.Grass
		ground.Color = Color3.fromRGB(85, 160, 70)
		ground.Parent = workspace
	end

	if not workspace:FindFirstChildOfClass("SpawnLocation") then
		local spawn = Instance.new("SpawnLocation")
		spawn.Size = Vector3.new(12, 1, 12)
		spawn.Position = Vector3.new(0, 0.5, 0)
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Parent = workspace
	end

	-- Placas de zona: mostram onde começa cada monstro
	for _, data in ipairs(Config.Enemies) do
		local sign = Instance.new("Part")
		sign.Name = "Zona_" .. data.Name
		sign.Size = Vector3.new(1, 6, 1)
		sign.Position = Vector3.new(0, 3, -data.Distance[1] + 4)
		sign.Anchored = true
		sign.Color = data.Color
		sign.Parent = workspace

		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(200, 50)
		gui.StudsOffset = Vector3.new(0, 4.5, 0)
		gui.MaxDistance = 200
		gui.Parent = sign

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "Zona: " .. data.Name
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = data.Color
		label.TextStrokeTransparency = 0
		label.Parent = gui
	end
end

return MapBuilder
