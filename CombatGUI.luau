local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local CombatEvent = ReplicatedStorage:WaitForChild("CombatEvent")

local isDataLoaded = false -- Создаем переключатель

-- Создаем интерфейс
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CombatGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ==========================================
-- 1. ПОЛОСКА ВЫНОСЛИВОСТИ (Снизу по центру)
-- ==========================================
local staminaBg = Instance.new("Frame")
staminaBg.Size = UDim2.new(0, 200, 0, 15)
staminaBg.Position = UDim2.new(0.5, -100, 1, -120) 
staminaBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Instance.new("UICorner", staminaBg).CornerRadius = UDim.new(1, 0)
staminaBg.Parent = screenGui

local staminaFill = Instance.new("Frame")
staminaFill.Size = UDim2.new(1, 0, 1, 0)
staminaFill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
Instance.new("UICorner", staminaFill).CornerRadius = UDim.new(1, 0)
staminaFill.Parent = staminaBg

local staminaText = Instance.new("TextLabel")
staminaText.Size = UDim2.new(1, 0, 1, 0)
staminaText.BackgroundTransparency = 1
staminaText.Text = "100 / 100"
staminaText.TextColor3 = Color3.fromRGB(255, 255, 255)
staminaText.Font = Enum.Font.BuilderSansBold
staminaText.TextSize = 12
staminaText.Parent = staminaBg

-- ==========================================
-- 2. ИНТЕРФЕЙС УРОВНЯ И ОПЫТА (Снизу слева)
-- ==========================================
local statsFrame = Instance.new("Frame")
statsFrame.Size = UDim2.new(0, 220, 0, 50)
statsFrame.Position = UDim2.new(0, 20, 1, -70) -- В левом нижнем углу
statsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
Instance.new("UICorner", statsFrame).CornerRadius = UDim.new(0, 8)
statsFrame.Parent = screenGui

local levelText = Instance.new("TextLabel")
levelText.Size = UDim2.new(1, -20, 0, 20)
levelText.Position = UDim2.new(0, 10, 0, 5)
levelText.BackgroundTransparency = 1
levelText.Text = "Боевой уровень: 1"
levelText.TextColor3 = Color3.fromRGB(255, 255, 255)
levelText.Font = Enum.Font.BuilderSansBold
levelText.TextSize = 16
levelText.TextXAlignment = Enum.TextXAlignment.Left
levelText.Parent = statsFrame

local xpBg = Instance.new("Frame")
xpBg.Size = UDim2.new(1, -20, 0, 10)
xpBg.Position = UDim2.new(0, 10, 0, 30)
xpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Instance.new("UICorner", xpBg).CornerRadius = UDim.new(1, 0)
xpBg.Parent = statsFrame

local xpFill = Instance.new("Frame")
xpFill.Size = UDim2.new(0, 0, 1, 0)
xpFill.BackgroundColor3 = Color3.fromRGB(50, 150, 255) -- Синий цвет для XP
Instance.new("UICorner", xpFill).CornerRadius = UDim.new(1, 0)
xpFill.Parent = xpBg

local xpText = Instance.new("TextLabel")
xpText.Size = UDim2.new(1, 0, 1, 0)
xpText.BackgroundTransparency = 1
xpText.Text = "0 / 100 XP"
xpText.TextColor3 = Color3.fromRGB(255, 255, 255)
xpText.Font = Enum.Font.BuilderSansBold
xpText.TextSize = 10
xpText.Parent = xpBg

-- ==========================================
-- 3. ОБНОВЛЕНИЕ ДАННЫХ С СЕРВЕРА
-- ==========================================
CombatEvent.OnClientEvent:Connect(function(action, val1, val2, val3)
	if action == "UpdateStamina" then
		local current, max = val1, val2
		local fillWidth = math.clamp(current / max, 0, 1)
		staminaFill:TweenSize(UDim2.new(fillWidth, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
		staminaText.Text = math.floor(current) .. " / " .. max

	elseif action == "UpdateStats" then
		isDataLoaded = true -- НОВОЕ: Как только сервер ответил, меняем флаг

		local level, currentXP, requiredXP = val1, val2, val3

		levelText.Text = "Боевой уровень: " .. level
		xpText.Text = math.floor(currentXP) .. " / " .. requiredXP .. " XP"

		-- Плавно заполняем синюю полоску
		local fillWidth = math.clamp(currentXP / requiredXP, 0, 1)
		xpFill:TweenSize(UDim2.new(fillWidth, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
	end
end)

-- ==========================================
-- 4. АСИНХРОННЫЙ ЗАПРОС ДАННЫХ
-- ==========================================
task.spawn(function()
	while not isDataLoaded do
		CombatEvent:FireServer("GetStats")
		task.wait(0.5) -- Ждем полсекунды и спрашиваем снова, пока сервер не отдаст данные
	end
end)