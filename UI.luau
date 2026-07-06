local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Создание интерфейса
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SaveScreenGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local saveButton = Instance.new("TextButton")
saveButton.Name = "SaveButton"
saveButton.Size = UDim2.new(0, 150, 0, 50)
saveButton.Position = UDim2.new(1, -170, 1, -70) -- В правом нижнем углу
saveButton.AnchorPoint = Vector2.new(0, 0)
saveButton.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
saveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
saveButton.Font = Enum.Font.SourceSansBold
saveButton.TextSize = 20
saveButton.Text = "Сохранить прогресс"
saveButton.Parent = screenGui

-- Закругление углов для красоты
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = saveButton

local requestSaveRemote = ReplicatedStorage:WaitForChild("RequestSave")

-- Переменные для кулдауна (чтобы кнопка визуально блокировалась)
local cooldown = 60
local onCooldown = false

saveButton.MouseButton1Click:Connect(function()
	if onCooldown then return end

	onCooldown = true
	saveButton.Text = "Сохранение..."
	saveButton.BackgroundColor3 = Color3.fromRGB(150, 150, 40) -- Желтоватый цвет при сохранении

	-- Отправляем запрос на сервер
	requestSaveRemote:FireServer()

	-- Визуальный таймер кулдауна
	for i = cooldown, 1, -1 do
		saveButton.Text = "Подождите (" .. i .. "с)"
		task.wait(1)
	end

	-- Возвращаем кнопку в исходное состояние
	onCooldown = false
	saveButton.Text = "Сохранить прогресс"
	saveButton.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
end)