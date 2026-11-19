-- Interface: moedas, loja de armas, renascer e loja de Robux
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local fmt = Config.FormatNumber

local COLORS = {
	Panel = Color3.fromRGB(30, 30, 40),
	Row = Color3.fromRGB(45, 45, 60),
	Green = Color3.fromRGB(60, 180, 90),
	Blue = Color3.fromRGB(60, 120, 220),
	Gold = Color3.fromRGB(230, 170, 40),
	Purple = Color3.fromRGB(150, 80, 220),
	Gray = Color3.fromRGB(90, 90, 100),
	Red = Color3.fromRGB(200, 60, 60),
}

local function make(className, props, parent)
	local object = Instance.new(className)
	for key, value in pairs(props) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function round(object, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, object)
end

local function label(text, props, parent)
	local base = {
		Text = text,
		BackgroundTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
	}
	for key, value in pairs(props) do
		base[key] = value
	end
	return make("TextLabel", base, parent)
end

local function button(text, color, props, parent)
	local base = {
		Text = text,
		BackgroundColor3 = color,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		AutoButtonColor = true,
	}
	for key, value in pairs(props) do
		base[key] = value
	end
	local btn = make("TextButton", base, parent)
	round(btn)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
	}, btn)
	return btn
end

local gui = make("ScreenGui", { Name = "MainUI", ResetOnSpawn = false, IgnoreGuiInset = false }, player:WaitForChild("PlayerGui"))

-- ===== Status (canto superior esquerdo) =====
local stats = make("Frame", {
	Position = UDim2.fromOffset(12, 12),
	Size = UDim2.fromOffset(230, 100),
	BackgroundColor3 = COLORS.Panel,
	BackgroundTransparency = 0.2,
}, gui)
round(stats, 10)
make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingRight = UDim.new(0, 10) }, stats)
make("UIListLayout", { Padding = UDim.new(0, 2) }, stats)
local coinsLabel = label("Moedas: 0", { Size = UDim2.new(1, 0, 0, 34), TextColor3 = COLORS.Gold, TextXAlignment = Enum.TextXAlignment.Left }, stats)
local weaponLabel = label("Arma: -", { Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left }, stats)
local rebirthLabel = label("Renascimentos: 0", { Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left }, stats)

-- ===== Aviso rápido =====
local toast = label("", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 20),
	Size = UDim2.fromOffset(420, 40),
	TextStrokeTransparency = 0.2,
	TextTransparency = 1,
	TextStrokeColor3 = Color3.new(0, 0, 0),
}, gui)
local toastToken = 0
local function showToast(text, color)
	toastToken = toastToken + 1
	local myToken = toastToken
	toast.Text = text
	toast.TextColor3 = color or Color3.new(1, 1, 1)
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.2
	task.delay(2.2, function()
		if myToken == toastToken then
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

-- ===== Painéis =====
local panels = {}
local function createPanel(title, color)
	local panel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 400),
		BackgroundColor3 = COLORS.Panel,
		Visible = false,
	}, gui)
	round(panel, 12)
	make("UISizeConstraint", { MaxSize = Vector2.new(460, 400) }, panel)
	make("UIStroke", { Color = color, Thickness = 3 }, panel)
	label(title, { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -70, 0, 36), TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left }, panel)
	local close = button("X", COLORS.Red, { Position = UDim2.new(1, -46, 0, 8), Size = UDim2.fromOffset(36, 36) }, panel)
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)
	local list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.new(1, -24, 1, -64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, panel)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	table.insert(panels, panel)
	return panel, list
end

local function togglePanel(panel)
	local show = not panel.Visible
	for _, other in ipairs(panels) do
		other.Visible = false
	end
	panel.Visible = show
end

local function createRow(list, order, title, subtitle, buttonColor)
	local row = make("Frame", { Size = UDim2.new(1, -8, 0, 56), BackgroundColor3 = COLORS.Row, LayoutOrder = order }, list)
	round(row)
	label(title, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -140, 0, 26), TextXAlignment = Enum.TextXAlignment.Left }, row)
	local sub = label(subtitle, {
		Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -140, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(200, 200, 210),
	}, row)
	local btn = button("", buttonColor, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(120, 40) }, row)
	return btn, sub
end

-- Loja de armas
local weaponPanel, weaponList = createPanel("Loja de Armas", COLORS.Blue)
local weaponButtons = {}
for index, weapon in ipairs(Config.Weapons) do
	local btn = createRow(weaponList, index, weapon.Name, "Dano: " .. fmt(weapon.Damage), COLORS.Green)
	weaponButtons[index] = btn
	btn.MouseButton1Click:Connect(function()
		local ok, message = Remotes.BuyWeapon:InvokeServer(index)
		showToast(message, ok and COLORS.Green or COLORS.Red)
	end)
end

-- Loja de Robux
local storePanel, storeList = createPanel("Loja VIP", COLORS.Gold)
local passButtons = {}
local order = 0
for key, pass in pairs(Config.GamePasses) do
	order = order + 1
	local btn = createRow(storeList, order, pass.Name, pass.Description, COLORS.Purple)
	btn.Text = "R$ " .. pass.Price
	passButtons[key] = btn
	btn.MouseButton1Click:Connect(function()
		if player:GetAttribute("Pass_" .. key) then
			return
		end
		if pass.Id == 0 then
			showToast("Configure o ID deste gamepass no Config.", COLORS.Red)
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	end)
end
local productSubtitles = {}
for index, product in ipairs(Config.DevProducts) do
	local btn, sub = createRow(storeList, 100 + index, product.Name, "", COLORS.Gold)
	btn.Text = "R$ " .. product.Price
	productSubtitles[index] = sub
	btn.MouseButton1Click:Connect(function()
		if product.Id == 0 then
			showToast("Configure o ID deste produto no Config.", COLORS.Red)
			return
		end
		MarketplaceService:PromptProductPurchase(player, product.Id)
	end)
end

-- ===== Botões de baixo =====
local bar = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.fromOffset(480, 54),
	BackgroundTransparency = 1,
}, gui)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 10),
}, bar)
local weaponsBtn = button("Armas", COLORS.Blue, { Size = UDim2.fromOffset(140, 54) }, bar)
local rebirthBtn = button("Renascer", COLORS.Purple, { Size = UDim2.fromOffset(170, 54) }, bar)
local storeBtn = button("Loja VIP", COLORS.Gold, { Size = UDim2.fromOffset(140, 54) }, bar)

weaponsBtn.MouseButton1Click:Connect(function()
	togglePanel(weaponPanel)
end)
storeBtn.MouseButton1Click:Connect(function()
	togglePanel(storePanel)
end)
rebirthBtn.MouseButton1Click:Connect(function()
	local ok, message = Remotes.Rebirth:InvokeServer()
	showToast(message, ok and COLORS.Green or COLORS.Red)
end)

-- ===== Atualização =====
local function refresh()
	local coins = player:GetAttribute("Coins") or 0
	local weaponIndex = player:GetAttribute("Weapon") or 1
	local rebirths = player:GetAttribute("Rebirths") or 0

	coinsLabel.Text = "Moedas: " .. fmt(coins)
	weaponLabel.Text = "Arma: " .. Config.Weapons[weaponIndex].Name
	rebirthLabel.Text = "Renascimentos: " .. rebirths .. "  (x" .. string.format("%.1f", 1 + rebirths * Config.Rebirth.CoinBonus) .. ")"
	rebirthBtn.Text = "Renascer (" .. fmt(Config.GetRebirthPrice(rebirths)) .. ")"

	for index, btn in ipairs(weaponButtons) do
		local weapon = Config.Weapons[index]
		if index <= weaponIndex then
			btn.Text = index == weaponIndex and "Equipada" or "Comprada"
			btn.BackgroundColor3 = COLORS.Gray
		else
			btn.Text = fmt(weapon.Price)
			btn.BackgroundColor3 = coins >= weapon.Price and COLORS.Green or COLORS.Red
		end
	end

	for key, btn in pairs(passButtons) do
		if player:GetAttribute("Pass_" .. key) then
			btn.Text = "Possui"
			btn.BackgroundColor3 = COLORS.Gray
		end
	end

	for index, sub in ipairs(productSubtitles) do
		sub.Text = "+" .. fmt(Config.GetProductCoins(Config.DevProducts[index], rebirths)) .. " moedas"
	end
end

-- Número flutuante "+X" quando ganha moedas
local lastCoins = player:GetAttribute("Coins") or 0
local function coinPopup(amount)
	local popup = label("+" .. fmt(amount), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.2, 0.45),
		Size = UDim2.fromOffset(160, 40),
		TextColor3 = COLORS.Gold,
		TextStrokeTransparency = 0.2,
	}, gui)
	local tween = TweenService:Create(popup, TweenInfo.new(0.9), {
		Position = popup.Position - UDim2.fromOffset(0, 80),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
end

player:GetAttributeChangedSignal("Coins"):Connect(function()
	local coins = player:GetAttribute("Coins") or 0
	if coins > lastCoins and player:GetAttribute("Loaded") then
		coinPopup(coins - lastCoins)
	end
	lastCoins = coins
end)

player.AttributeChanged:Connect(refresh)
refresh()
