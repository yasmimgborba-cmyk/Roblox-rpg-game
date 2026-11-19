-- Salva e carrega o progresso dos jogadores (DataStore)
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataService = {}

local DEFAULTS = { Coins = 0, Weapon = 1, Rebirths = 0 }
local LEADERSTATS = { Coins = "Moedas", Rebirths = "Renascimentos" }
local AUTOSAVE_INTERVAL = 120
local LOCK_EXPIRY = 600 -- trava mais velha que isso é de servidor que caiu

-- No Studio usa outro banco, para testes não estragarem o progresso real
local storeName = RunService:IsStudio() and (Config.DataStoreName .. "_Studio") or Config.DataStoreName
local store = DataStoreService:GetDataStore(storeName)
local SERVER_ID = RunService:IsStudio() and ("studio-" .. HttpService:GenerateGUID(false)) or game.JobId
local profiles = {}
local canSave = {}

local function storeKey(player)
	return "u_" .. player.UserId
end

local function withRetry(fn)
	local delay = 1
	for attempt = 1, 4 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("[DataService] tentativa %d falhou: %s"):format(attempt, tostring(result)))
		task.wait(delay + math.random())
		delay = math.min(delay * 2, 8)
	end
	return false, nil
end

-- Formato salvo: { data = {...}, lock = { server, time } }
-- Aceita também o formato antigo (dados soltos), por segurança
local function readRecord(record)
	if type(record) ~= "table" then
		return { data = {}, lock = nil }
	end
	if type(record.data) == "table" then
		return record
	end
	return { data = record, lock = nil }
end

-- Pega a trava da sessão. Retorna (ok, dados) ou (ok, nil) se outro servidor está usando.
local function acquire(player)
	local loaded
	local ok = withRetry(function()
		loaded = nil
		store:UpdateAsync(storeKey(player), function(raw)
			local record = readRecord(raw)
			local lock = record.lock
			local now = os.time()
			if lock and lock.server ~= SERVER_ID and now - lock.time < LOCK_EXPIRY then
				return nil -- outro servidor ainda está com esse jogador
			end
			record.lock = { server = SERVER_ID, time = now }
			loaded = record.data
			return record, { player.UserId }
		end)
	end)
	return ok, loaded
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

	local ok, data
	for _ = 1, 3 do -- o servidor anterior pode ainda estar soltando a trava
		ok, data = acquire(player)
		if (ok and data) or not ok or not player.Parent then
			break
		end
		task.wait(5)
	end
	if not player.Parent then
		if ok and data then
			-- saiu enquanto carregava: solta a trava para não travar o próximo servidor
			withRetry(function()
				store:UpdateAsync(storeKey(player), function(raw)
					local record = readRecord(raw)
					if record.lock and record.lock.server == SERVER_ID then
						record.lock = nil
						return record, { player.UserId }
					end
					return nil
				end)
			end)
		end
		return nil
	end
	if not ok or not data then
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

-- release = true solta a trava (quando o jogador sai)
function DataService.Save(player, release)
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
	local stillOwner = true
	local ok = withRetry(function()
		stillOwner = true
		store:UpdateAsync(storeKey(player), function(raw)
			local record = readRecord(raw)
			if record.lock and record.lock.server ~= SERVER_ID then
				stillOwner = false
				return nil -- perdemos a trava: nunca sobrescreve outro servidor
			end
			return {
				data = payload,
				lock = (not release) and { server = SERVER_ID, time = os.time() } or nil,
			}, { player.UserId }
		end)
	end)
	if ok and not stillOwner then
		warn("[DataService] outro servidor está com os dados de " .. player.Name)
		canSave[player] = false
	end
	return ok and stillOwner
end

function DataService.Start()
	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player, true)
		profiles[player] = nil
		canSave[player] = nil
	end)

	task.spawn(function()
		task.wait(math.random() * AUTOSAVE_INTERVAL) -- espalha os servidores
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
				DataService.Save(player, true)
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
