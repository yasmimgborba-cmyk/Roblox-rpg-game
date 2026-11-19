-- Salva e carrega o progresso dos jogadores (DataStore)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataService = {}

local DEFAULTS = { Coins = 0, Weapon = 1, Rebirths = 0 }
local LEADERSTATS = { Coins = "Moedas", Rebirths = "Renascimentos" }
local AUTOSAVE_INTERVAL = 120

local store = DataStoreService:GetDataStore(Config.DataStoreName)
local profiles = {}
local canSave = {}

local function storeKey(player)
	return "u_" .. player.UserId
end

local function withRetry(fn)
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("[DataService] tentativa %d falhou: %s"):format(attempt, tostring(result)))
		task.wait(attempt)
	end
	return false, nil
end

local function sync(player, key)
	local profile = profiles[player]
	if not profile then
		return
	end
	player:SetAttribute(key, profile[key])
	local leaderstats = player:FindFirstChild("leaderstats")
	local label = LEADERSTATS[key]
	if leaderstats and label and leaderstats:FindFirstChild(label) then
		leaderstats[label].Value = profile[key]
	end
end

function DataService.Load(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, label in pairs(LEADERSTATS) do
		local value = Instance.new("IntValue")
		value.Name = label
		value.Parent = leaderstats
	end
	leaderstats.Parent = player

	local ok, data = withRetry(function()
		return store:GetAsync(storeKey(player))
	end)
	if not player.Parent then
		return nil
	end
	if not ok then
		player:Kick("Não conseguimos carregar seu progresso. Entre de novo em alguns segundos.")
		return nil
	end

	data = type(data) == "table" and data or {}
	local profile = { Receipts = type(data.Receipts) == "table" and data.Receipts or {} }
	for key, default in pairs(DEFAULTS) do
		profile[key] = type(data[key]) == "number" and data[key] or default
	end
	profile.Weapon = math.clamp(profile.Weapon, 1, #Config.Weapons)

	profiles[player] = profile
	canSave[player] = true
	for key in pairs(DEFAULTS) do
		sync(player, key)
	end
	return profile
end

function DataService.Get(player)
	return profiles[player]
end

function DataService.Set(player, key, value)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile[key] = value
	sync(player, key)
end

function DataService.Increment(player, key, delta)
	local profile = profiles[player]
	if not profile then
		return
	end
	DataService.Set(player, key, profile[key] + delta)
end

function DataService.Save(player)
	local profile = profiles[player]
	if not profile or not canSave[player] then
		return false
	end
	local payload = {
		Coins = profile.Coins,
		Weapon = profile.Weapon,
		Rebirths = profile.Rebirths,
		Receipts = profile.Receipts,
	}
	local ok = withRetry(function()
		store:SetAsync(storeKey(player), payload, { player.UserId })
	end)
	return ok
end

function DataService.Start()
	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player)
		profiles[player] = nil
		canSave[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in pairs(profiles) do
				task.spawn(DataService.Save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in pairs(profiles) do
			pending = pending + 1
			task.spawn(function()
				DataService.Save(player)
				pending = pending - 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
