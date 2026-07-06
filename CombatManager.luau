local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local CombatEvent = ReplicatedStorage:FindFirstChild("CombatEvent") or Instance.new("RemoteEvent")
CombatEvent.Name = "CombatEvent"
CombatEvent.Parent = ReplicatedStorage
local Bindables = ServerStorage:WaitForChild("Bindables")

local GetPlayerCombatData = Bindables:WaitForChild("GetPlayerCombatData")
local UpdatePlayerCombatData = Bindables:WaitForChild("UpdatePlayerCombatData")

local playerStamina = {}

-- ФУНКЦИЯ: Расчет необходимого опыта для следующего уровня 
local function getRequiredXP(level)
	return math.floor(100 * (1.5 ^ (level - 1)))
end

-- ФУНКЦИЯ: Расчет урона в зависимости от уровня 
local function calculateDamage(level)
	local BASE_DAMAGE = 15
	local DAMAGE_PER_LEVEL = 5
	return BASE_DAMAGE + (level * DAMAGE_PER_LEVEL)
end

Players.PlayerAdded:Connect(function(player)
	-- Ждем секунду, чтобы DataStoreManager успел загрузить данные игрока из облака
	task.wait(1)

	local combatData = GetPlayerCombatData:Invoke(player)
	if combatData then
		playerStamina[player.UserId] = {
			Current = combatData.MaxStamina,
			Max = combatData.MaxStamina,
			LastUsed = tick(),
			Level = combatData.Level,
			XP = combatData.XP,
			regenDelay = 1.5
		}
	else
		-- Фолбэк на случай непредвиденной задержки
		playerStamina[player.UserId] = { Current = 100, Max = 100, LastUsed = tick(), Level = 1, XP = 0, RegenDelay = 1.5 }
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerStamina[player.UserId] = nil
end)

-- РЕГЕНЕРАЦИЯ ВЫНОСЛИВОСТИ
RunService.Heartbeat:Connect(function(deltaTime)
	for userId, data in pairs(playerStamina) do
		-- Теперь сервер проверяет индивидуальную задержку игрока
		if tick() - data.LastUsed > (data.RegenDelay or 1.5) then
			if data.Current < data.Max then
				data.Current = math.min(data.Max, data.Current + (25 * deltaTime)) 
				local player = Players:GetPlayerByUserId(userId)
				if player then
					CombatEvent:FireClient(player, "UpdateStamina", data.Current, data.Max)
				end
			end
		end
	end
end)

-- ОБРАБОТКА СИГНАЛОВ ОТ КЛИЕНТА
CombatEvent.OnServerEvent:Connect(function(player, action, cost, comboStep)
	local data = playerStamina[player.UserId]
	if not data then return end

	-- Клиент запрашивает свои статы при заходе в игру
	if action == "GetStats" then
		CombatEvent:FireClient(player, "UpdateStamina", data.Current, data.Max)
		CombatEvent:FireClient(player, "UpdateStats", data.Level, data.XP, getRequiredXP(data.Level))
		return
	end

	if action == "Swing" then
		if data.Current >= cost then
			data.Current = data.Current - cost
			data.LastUsed = tick()

			-- ЛОГИКА ИСТОЩЕНИЯ: Если стамины почти нет, даем штраф
			if data.Current < 10 then
				data.RegenDelay = 3.5 -- Игрок выдохся! Ждем 3.5 секунды
			else
				data.RegenDelay = 1.5 -- Иначе обычная пауза 1.5 секунды
			end

			CombatEvent:FireClient(player, "UpdateStamina", data.Current, data.Max)
			
			-- ХИТБОКС
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local hitboxSize = Vector3.new(3, 5, 3)
				local hitboxCFrame = hrp.CFrame * CFrame.new(0, 0, -2)

				local overlapParams = OverlapParams.new()
				overlapParams.FilterType = Enum.RaycastFilterType.Exclude
				overlapParams.FilterDescendantsInstances = {player.Character} 

				local hitParts = workspace:GetPartBoundsInBox(hitboxCFrame, hitboxSize, overlapParams)
				local alreadyHit = {} 

				for _, part in ipairs(hitParts) do
					local enemyModel = part.Parent
					local enemyHum = enemyModel:FindFirstChild("Humanoid")

					if enemyHum and enemyHum.Health > 0 and not alreadyHit[enemyHum] then
						alreadyHit[enemyHum] = true

						local dynamicDamage = calculateDamage(data.Level)

						-- Если комбо-шаг был 5-м (крит), умножаем урон на 2
						if comboStep == 5 then 
							dynamicDamage = dynamicDamage * 2 
						end

						enemyHum:TakeDamage(dynamicDamage)

						data.XP = data.XP + 15

						while data.XP >= getRequiredXP(data.Level) do
							data.XP = data.XP - getRequiredXP(data.Level)
							data.Level = data.Level + 1
							data.Max = data.Max + 10
							data.Current = data.Max 
						end

						UpdatePlayerCombatData:Fire(player, data.Level, data.XP, data.Max)

						-- Отправляем обновленный опыт и уровень на экран
						CombatEvent:FireClient(player, "UpdateStats", data.Level, data.XP, getRequiredXP(data.Level))
					end
				end
			end
		end
	end
end)