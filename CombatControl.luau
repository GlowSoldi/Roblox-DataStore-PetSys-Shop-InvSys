local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local CombatEvent = ReplicatedStorage:WaitForChild("CombatEvent")

local isSwinging = false
local comboStep = 1
local MAX_COMBO = 5 -- Теперь 5 ударов (4 обычных + 1 крит)
local COOLDOWN = 0.4
local STAMINA_COST = 10
local lastSwingTime = tick() -- Время последнего удара
local currentStamina = 100

-- Ловим обновления стамины от сервера напрямую в контроллере
CombatEvent.OnClientEvent:Connect(function(action, val1, val2)
	if action == "UpdateStamina" then
		currentStamina = val1
	end
end)

-- ТАБЛИЦА АНИМАЦИЙ (1-4 обычные, 5-я крит)
local animIds = {
	"rbxassetid://100198489738925", 

	"rbxassetid://105588048065129", 

	"rbxassetid://99260559693339", 

	"rbxassetid://127218282737014",

	"rbxassetid://78437862498380" 
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end 
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local character = player.Character
		if not character or character:FindFirstChildOfClass("Tool") then return end
		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then return end

		-- ПРОВЕРКА НА СБРОС КОМБО: Если прошло более 1.5 сек, сбрасываем на 1
		if tick() - lastSwingTime > 1.5 then
			comboStep = 1
		end

		if not isSwinging then
			-- Сначала считаем, сколько будет стоить этот удар (обычный или крит)
			local cost = (comboStep == 5) and (STAMINA_COST * 2) or STAMINA_COST

			-- ГЛАВНАЯ ПРОВЕРКА: Если стамины меньше, чем нужно — просто обрываем функцию
			if currentStamina < cost then
				return
			end

			isSwinging = true
			lastSwingTime = tick()

			CombatEvent:FireServer("Swing", cost, comboStep)

			-- Анимация
			local punchAnim = Instance.new("Animation")
			punchAnim.AnimationId = animIds[comboStep]

			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				local track = animator:LoadAnimation(punchAnim)
				track.Priority = Enum.AnimationPriority.Action
				track:Play()
			end

			-- Инкремент комбо
			comboStep = comboStep + 1
			if comboStep > MAX_COMBO then
				comboStep = 1
			end

			task.wait(COOLDOWN)
			isSwinging = false
		end
	end
end)