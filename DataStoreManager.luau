local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local PlayerDataStore = DataStoreService:GetDataStore("PlayerData")
local ItemTemplates = ReplicatedStorage:WaitForChild("ItemTemplates")

-- Создаем каналы связи для инвентаря
local InventoryEvent = Instance.new("RemoteEvent")
InventoryEvent.Name = "InventoryEvent"
InventoryEvent.Parent = ReplicatedStorage

local InventoryFunction = Instance.new("RemoteFunction")
InventoryFunction.Name = "InventoryFunction"
InventoryFunction.Parent = ReplicatedStorage

local DEFAULT_DATA = {
	IsPremium = false,
	Money = 100,
	Wins = 0,
	Losses = 0,

	CombatLevel = 1,
	CombatXP = 0,
	MaxStamina = 100,
	-- =======================
	Inventory = {} -- Чистый стартовый инвентарь
}

local sessionData = {}
local lastSaveTimes = {}
local SAVE_COOLDOWN = 60 
local AUTO_SAVE_INTERVAL = 600 

-- Глубокое копирование
local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			copy[k] = deepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

-- СЕРВЕРНАЯ ФУНКЦИЯ ВЫДАЧИ ПРЕДМЕТОВ
local function giveItem(player, itemName)
	local data = sessionData[player.UserId]
	if not data then return false end

	-- Ищем предмет в обеих папках
	local isWeapon = ItemTemplates:FindFirstChild(itemName) ~= nil
	local isPet = ReplicatedStorage:FindFirstChild("PetTemplates") and ReplicatedStorage.PetTemplates:FindFirstChild(itemName) ~= nil

	if not isWeapon and not isPet then
		warn("Предмет " .. itemName .. " не найден ни в ItemTemplates, ни в PetTemplates!")
		return false
	end

	local uniqueId = HttpService:GenerateGUID(false)
	data.Inventory[uniqueId] = {
		Name = itemName,
		Equipped = false
	}

	InventoryEvent:FireClient(player, "Update", data.Inventory)
	return true
end

_G.giveItem = giveItem

local function setupLeaderstats(player, data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local isPremium = Instance.new("BoolValue")
	isPremium.Name = "IsPremium"
	isPremium.Value = data.IsPremium
	isPremium.Parent = leaderstats

	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Value = data.Money
	money.Parent = leaderstats

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = data.Wins
	wins.Parent = leaderstats

	local losses = Instance.new("IntValue")
	losses.Name = "Losses"
	losses.Value = data.Losses
	losses.Parent = leaderstats

	local wlRatio = Instance.new("NumberValue")
	wlRatio.Name = "WLRatio"
	if data.Losses == 0 then
		wlRatio.Value = data.Wins
	else
		wlRatio.Value = math.floor((data.Wins / data.Losses) * 100) / 100
	end
	wlRatio.Parent = leaderstats

	isPremium.Changed:Connect(function(newValue)
		if sessionData[player.UserId] then sessionData[player.UserId].IsPremium = newValue end
	end)
	money.Changed:Connect(function(newValue)
		if sessionData[player.UserId] then sessionData[player.UserId].Money = newValue end
	end)

	local function updateRatio()
		if losses.Value == 0 then
			wlRatio.Value = wins.Value
		else
			wlRatio.Value = math.floor((wins.Value / losses.Value) * 100) / 100
		end
	end

	wins.Changed:Connect(function(newValue)
		if sessionData[player.UserId] then sessionData[player.UserId].Wins = newValue end
		updateRatio()
	end)
	losses.Changed:Connect(function(newValue)
		if sessionData[player.UserId] then sessionData[player.UserId].Losses = newValue end
		updateRatio()
	end)
end

-- ГЛАВНАЯ ФУНКЦИЯ ЗАХОДА ИГРОКА
local function onPlayerAdded(player)
	local userIdStr = tostring(player.UserId)
	local success, data = pcall(function()
		return PlayerDataStore:GetAsync(userIdStr)
	end)

	if success then
		if not data then
			data = deepCopy(DEFAULT_DATA)
		else
			for k, v in pairs(DEFAULT_DATA) do
				if data[k] == nil then
					if type(v) == "table" then
						data[k] = deepCopy(v)
					else
						data[k] = v
					end
				end
			end
		end

		sessionData[player.UserId] = data
		lastSaveTimes[player.UserId] = 0
		setupLeaderstats(player, data)
		
		-- ВРЕМЕННАЯ АВТОВЫДАЧА ДЛЯ ТЕСТОВ
		---task.spawn(function()
			---task.wait(2) -- Даем инвентарю прогрузиться
			---giveItem(player, "Sword")
		---end)

		-- ВОССТАНОВЛЕНИЕ ОРУЖИЯ ПРИ СПАВНЕ
		
		player.CharacterAdded:Connect(function(character)
			local function onCharacterSpawned(character)
				local currentData = sessionData[player.UserId]
				if not currentData or not currentData.Inventory then return end

				-- Ждем, пока персонаж окончательно заспавнится в Workspace карты
				if not character.Parent then
					character:GetPropertyChangedSignal("Parent"):Wait()
				end

				local humanoid = character:WaitForChild("Humanoid", 5)
				local backpack = player:WaitForChild("Backpack", 5)
				if not humanoid or not backpack then return end

				-- Маленькая пауза, чтобы Роблокс завершил внутреннюю сборку суставов
				task.wait(0.3) 

				-- ТУШИМ ДЮПЫ: Ищем и уничтожаем абсолютно все старые копии этого оружия в рюкзаке и теле
				for uid, item in pairs(currentData.Inventory) do
					if item.Equipped then
						local oldInChar = character:FindFirstChild(item.Name)
						if oldInChar then oldInChar:Destroy() end

						local oldInBackp = backpack:FindFirstChild(item.Name)
						if oldInBackp then oldInBackp:Destroy() end
					end
				end

				-- ВЫДАЕМ ПРЯМО В РУКИ
				for uid, item in pairs(currentData.Inventory) do
					if item.Equipped then
						local template = ItemTemplates:FindFirstChild(item.Name)
						if template then
							local newTool = template:Clone()
							-- Магия: Parent = character принудительно вкладывает вещь в руку, обходя баги EquipTool!
							newTool.Parent = character 
						end
					end
				end
			end

			-- Подключаем к будущим респавнам (после смерти)
			player.CharacterAdded:Connect(onCharacterSpawned)

			-- Если персонаж УЖЕ загрузился до этого кода (фикс первого захода)
			if player.Character then
				task.spawn(onCharacterSpawned, player.Character)
			end
		end)

	else
		warn("Не удалось загрузить данные для " .. player.Name .. ": " .. tostring(data))
		player:Kick("Ошибка загрузки данных DataStore. Пожалуйста, перезайдите.")
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

local function savePlayerData(userId, isRemoving)
	local dataToSave = sessionData[userId]
	if dataToSave then
		local userIdStr = tostring(userId)

		local success, errorMessage = pcall(function()
			PlayerDataStore:UpdateAsync(userIdStr, function(oldData)
				return dataToSave
			end)
		end)

		if not success then
			warn("Критическая ошибка UpdateAsync для " .. userIdStr .. ": " .. tostring(errorMessage))
		end

		if lastSaveTimes[userId] then
			lastSaveTimes[userId] = os.time()
		end

		if isRemoving then
			sessionData[userId] = nil
			lastSaveTimes[userId] = nil
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player.UserId, true)
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player.UserId, true)
	end
end)

local saveMatchDataBindable = Instance.new("BindableEvent")
saveMatchDataBindable.Name = "SaveMatchData"
saveMatchDataBindable.Parent = ServerStorage

saveMatchDataBindable.Event:Connect(function(player)
	if player and player:IsA("Player") then
		savePlayerData(player.UserId, false)
	end
end)

local requestSaveRemote = Instance.new("RemoteEvent")
requestSaveRemote.Name = "RequestSave"
requestSaveRemote.Parent = ReplicatedStorage

requestSaveRemote.OnServerEvent:Connect(function(player)
	local lastSave = lastSaveTimes[player.UserId] or 0
	local currentTime = os.time()

	if currentTime - lastSave >= SAVE_COOLDOWN then
		savePlayerData(player.UserId, false)
	end
end)

-- ОБРАБОТКА ЭКИПИРОВКИ ОТ КЛИЕНТА
InventoryFunction.OnServerInvoke = function(player, action, uniqueId)
	local data = sessionData[player.UserId]
	if not data then return false end

	if action == "Get" then
		return data.Inventory

	elseif action == "Equip" then
		local itemData = data.Inventory[uniqueId]
		if itemData then

			-- Проверяем, к какому типу относится предмет
			local isWeapon = ItemTemplates:FindFirstChild(itemData.Name) ~= nil
			local isPet = ReplicatedStorage:FindFirstChild("PetTemplates") and ReplicatedStorage.PetTemplates:FindFirstChild(itemData.Name) ~= nil

			-- 1. СНЯТИЕ ПРЕДМЕТА
			if itemData.Equipped then
				itemData.Equipped = false

				if isWeapon then
					if player.Character then
						local tool = player.Character:FindFirstChild(itemData.Name)
						if tool then tool:Destroy() end
					end
					local bpTool = player.Backpack:FindFirstChild(itemData.Name)
					if bpTool then bpTool:Destroy() end
				elseif isPet then
					-- Отправляем сигнал в PetManager убрать питомца
					ServerStorage.Bindables.PetToggle:Fire(player, itemData.Name, false)
				end

				InventoryEvent:FireClient(player, "Update", data.Inventory)
				return true
			end

			-- 2. ЭКИПИРОВКА (Снимаем предметы такого же типа)
			for uid, item in pairs(data.Inventory) do
				if item.Equipped then
					local itemIsWeapon = ItemTemplates:FindFirstChild(item.Name) ~= nil
					local itemIsPet = ReplicatedStorage.PetTemplates:FindFirstChild(item.Name) ~= nil

					-- Если мы надеваем оружие, снимаем старое оружие. Если пета - старого пета.
					if (isWeapon and itemIsWeapon) or (isPet and itemIsPet) then
						item.Equipped = false
						if itemIsWeapon then
							if player.Character then
								local equippedTool = player.Character:FindFirstChild(item.Name)
								if equippedTool then equippedTool:Destroy() end
							end
							local backpackTool = player.Backpack:FindFirstChild(item.Name)
							if backpackTool then backpackTool:Destroy() end
						elseif itemIsPet then
							ServerStorage.Bindables.PetToggle:Fire(player, item.Name, false)
						end
					end
				end
			end

			-- 3. НАДЕВАЕМ ВЫБРАННЫЙ ПРЕДМЕТ
			itemData.Equipped = true

			if isWeapon then
				local template = ItemTemplates:FindFirstChild(itemData.Name)
				if template then
					local newTool = template:Clone()
					newTool.Parent = player.Character
				end
			elseif isPet then
				-- Отправляем сигнал в PetManager заспавнить питомца
				ServerStorage.Bindables.PetToggle:Fire(player, itemData.Name, true)
			end

			InventoryEvent:FireClient(player, "Update", data.Inventory)
			return true
		end

	elseif action == "Drop" then
		local itemData = data.Inventory[uniqueId]
		if itemData then
			-- 1. Снимаем предмет, если он в руках
			if itemData.Equipped then
				if player.Character then
					local tool = player.Character:FindFirstChild(itemData.Name)
					if tool then tool:Destroy() end
				end
				local bpTool = player.Backpack:FindFirstChild(itemData.Name)
				if bpTool then bpTool:Destroy() end
			end

			-- 2. Спавним физическую копию в мире (без логики Tool)
			local template = ItemTemplates:FindFirstChild(itemData.Name)
			if template and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local dropModel = Instance.new("Model")
				dropModel.Name = itemData.Name

				-- Ищем деталь Handle, чтобы выкинуть именно её
				local handle = template:FindFirstChild("Handle")
				if handle then
					local dropPart = handle:Clone()
					-- Выкидываем на 4 стада перед лицом игрока
					dropPart.CFrame = player.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -4)
					dropPart.CanCollide = true
					dropPart.Anchored = false
					dropPart.Parent = dropModel

					-- Добавляем UI-кнопку для подбора
					local prompt = Instance.new("ProximityPrompt")
					prompt.ActionText = "Подобрать"
					prompt.ObjectText = itemData.Name
					prompt.RequiresLineOfSight = false
					prompt.Parent = dropPart

					-- Логика подбора (возвращаем в базу данных)
					prompt.Triggered:Connect(function(triggerPlayer)
						if giveItem(triggerPlayer, itemData.Name) then
							dropModel:Destroy()
						end
					end)

					dropModel.Parent = workspace
				end
			end

			-- 3. Удаляем предмет из базы данных
			data.Inventory[uniqueId] = nil
			InventoryEvent:FireClient(player, "Update", data.Inventory)
			return true
		end
	end
	return false
end

task.spawn(function()
	while true do
		task.wait(AUTO_SAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			if sessionData[player.UserId] then
				savePlayerData(player.UserId, false)
				task.wait(1)
			end
		end
	end
end)
-- ========================================================================
-- МЕЖСКРИПТОВОЕ ВЗАИМОДЕЙСТВИЕ ДЛЯ БОЕВКИ
-- ========================================================================
local Bindables = ServerStorage:WaitForChild("Bindables")
local GetPlayerCombatData = Bindables:WaitForChild("GetPlayerCombatData")
local UpdatePlayerCombatData = Bindables:WaitForChild("UpdatePlayerCombatData")

-- Отдаем данные по запросу из другого скрипта
GetPlayerCombatData.OnInvoke = function(player)
	local data = sessionData[player.UserId]
	if data then
		return {
			Level = data.CombatLevel or 1,
			XP = data.CombatXP or 0,
			MaxStamina = data.MaxStamina or 100
		}
	end
	return nil
end

-- Принимаем обновленные данные от скрипта боевки
UpdatePlayerCombatData.Event:Connect(function(player, newLevel, newXP, newMaxStamina)
	local data = sessionData[player.UserId]
	if data then
		data.CombatLevel = newLevel
		data.CombatXP = newXP
		data.MaxStamina = newMaxStamina
	end
end)