local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local defaultMinZoom = player.CameraMinZoomDistance
local defaultMaxZoom = player.CameraMaxZoomDistance

game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

local InventoryEvent = ReplicatedStorage:WaitForChild("InventoryEvent")
local InventoryFunction = ReplicatedStorage:WaitForChild("InventoryFunction")

-- ========================================================================
-- СОЗДАНИЕ ОБОЛОЧКИ UI
-- ========================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InventoryGui"
screenGui.ResetOnSpawn = false
-- ВАЖНО: Отключаем отступ верхней панели (Inset), чтобы мышка и UI совпадали 1к1
screenGui.IgnoreGuiInset = true 
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Active = true 
mainFrame.Size = UDim2.new(0, 480, 0, 400)
mainFrame.Position = UDim2.new(0.5, -240, 0.5, -200)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundTransparency = 1
title.Text = "ИНВЕНТАРЬ (B или Tab)"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.BuilderSansBold
title.TextSize = 22
title.Parent = mainFrame

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Active = true 
scrollFrame.Size = UDim2.new(1, -30, 1, -70)
scrollFrame.Position = UDim2.new(0, 15, 0, 55)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 6
scrollFrame.Parent = mainFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 80, 0, 80)
gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = scrollFrame

-- ========================================================================
-- ГЕНЕРАЦИЯ ПУСТЫХ СЛОТОВ
-- ========================================================================
local TOTAL_SLOTS = 24
local slotFrames = {}
local localItemPositions = {} 

for i = 1, TOTAL_SLOTS do
	local slot = Instance.new("Frame")
	slot.Name = "InvSlot"
	slot.LayoutOrder = i
	slot.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	slot.BorderSizePixel = 0
	slot.Parent = scrollFrame

	local slotCorner = Instance.new("UICorner")
	slotCorner.CornerRadius = UDim.new(0, 8)
	slotCorner.Parent = slot

	slotFrames[i] = slot
end

-- ========================================================================
-- ЛОГИКА ОБНОВЛЕНИЯ И DRAG-AND-DROP 
-- ========================================================================
local currentDragClone = nil 
local activeRadialMenu = nil -- Глобальная переменная для кругового меню
local RunService = game:GetService("RunService")

local function updateUI(inventoryData)
	if currentDragClone then
		currentDragClone:Destroy()
		currentDragClone = nil
		scrollFrame.ScrollingEnabled = true
	end

	-- ФИКС 1: Не убиваем меню при любом чихе сервера! 
	-- Закрываем его ТОЛЬКО если предмет физически исчез из инвентаря (например, мы его выбросили).
	if activeRadialMenu then
		local targetId = activeRadialMenu:GetAttribute("TargetItem")
		if targetId and not inventoryData[targetId] then
			activeRadialMenu:Destroy()
			activeRadialMenu = nil
		end
	end

	for _, slot in ipairs(slotFrames) do
		for _, child in ipairs(slot:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
	end

	for uniqueId, itemData in pairs(inventoryData) do
		local targetSlotIndex = localItemPositions[uniqueId]
		if not targetSlotIndex or slotFrames[targetSlotIndex]:FindFirstChildOfClass("TextButton") then
			for i, slot in ipairs(slotFrames) do
				if not slot:FindFirstChildOfClass("TextButton") then
					targetSlotIndex = i
					localItemPositions[uniqueId] = i
					break
				end
			end
		end

		if targetSlotIndex then
			local itemBtn = Instance.new("TextButton")
			itemBtn.Name = uniqueId
			itemBtn.Size = UDim2.new(1, 0, 1, 0)
			itemBtn.BackgroundColor3 = itemData.Equipped and Color3.fromRGB(46, 138, 87) or Color3.fromRGB(70, 70, 80)
			itemBtn.Text = itemData.Name .. (itemData.Equipped and "\n[В руке]" or "")
			itemBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			itemBtn.Font = Enum.Font.BuilderSansMedium
			itemBtn.TextSize = 14
			itemBtn.ZIndex = 2
			itemBtn.Parent = slotFrames[targetSlotIndex]

			local btnCorner = Instance.new("UICorner")
			btnCorner.CornerRadius = UDim.new(0, 8)
			btnCorner.Parent = itemBtn

			local isDragging = false
			local dragStartPos = nil
			local moveConn, endConn

			-- =========================================================
			-- ФУНКЦИЯ: ОТКРЫТИЕ КРУГОВОГО МЕНЮ
			-- =========================================================
			local function openRadialMenu(startPos)
				if activeRadialMenu then activeRadialMenu:Destroy() end

				local radialBg = Instance.new("Frame")
				radialBg.Size = UDim2.new(1, 0, 1, 0)
				radialBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				radialBg.BackgroundTransparency = 0.4
				radialBg.ZIndex = 200
				radialBg:SetAttribute("TargetItem", uniqueId) -- Сохраняем ID, чтобы защитить от автозакрытия
				radialBg.Parent = screenGui
				activeRadialMenu = radialBg

				local centerPos = Vector2.new(startPos.X, startPos.Y)
				local options = {
					{Text = itemData.Equipped and "Снять" or "Надеть", Action = "Equip", Color = Color3.fromRGB(46, 138, 87)},
					{Text = "Выбросить", Action = "Drop", Color = Color3.fromRGB(200, 50, 50)},
					{Text = "Отмена", Action = "Cancel", Color = Color3.fromRGB(100, 100, 110)}
				}

				local radius = 85
				local buttons = {}
				local hoveredIndex = nil

				-- Центральная точка
				local centerDot = Instance.new("Frame")
				centerDot.Size = UDim2.new(0, 12, 0, 12)
				centerDot.Position = UDim2.new(0, centerPos.X - 6, 0, centerPos.Y - 6)
				centerDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				centerDot.ZIndex = 201
				Instance.new("UICorner", centerDot).CornerRadius = UDim.new(1, 0)
				centerDot.Parent = radialBg

				-- Создаем кнопки по кругу
				for i, opt in ipairs(options) do
					local angle = (i - 1) * (math.pi * 2 / #options) - (math.pi / 2)

					local btn = Instance.new("Frame")
					btn.Size = UDim2.new(0, 80, 0, 80)
					btn.Position = UDim2.new(0, centerPos.X + math.cos(angle) * radius - 40, 0, centerPos.Y + math.sin(angle) * radius - 40)
					btn.BackgroundColor3 = opt.Color
					btn.BackgroundTransparency = 0.5
					btn.ZIndex = 201
					btn.Parent = radialBg

					local corner = Instance.new("UICorner")
					corner.CornerRadius = UDim.new(1, 0)
					corner.Parent = btn

					local label = Instance.new("TextLabel")
					label.Size = UDim2.new(1, 0, 1, 0)
					label.BackgroundTransparency = 1
					label.Text = opt.Text
					label.TextColor3 = Color3.fromRGB(255, 255, 255)
					label.Font = Enum.Font.BuilderSansBold
					label.TextSize = 14
					label.Parent = btn

					buttons[i] = {Frame = btn, Action = opt.Action, Angle = angle}
				end

				-- Вычисляем угол и подсвечиваем нужную кнопку
				local rsConn
				rsConn = RunService.RenderStepped:Connect(function()
					if not activeRadialMenu then rsConn:Disconnect() return end

					local mouseLocation = UserInputService:GetMouseLocation()
					local dy = mouseLocation.Y - centerPos.Y
					local dx = mouseLocation.X - centerPos.X
					local dist = math.sqrt(dx*dx + dy*dy)

					if dist < 25 then
						hoveredIndex = nil
					else
						local deg = math.deg(math.atan2(dy, dx)) + 90
						if deg < 0 then deg = deg + 360 end
						local sectorDeg = deg + (360 / #options / 2)
						if sectorDeg >= 360 then sectorDeg = sectorDeg - 360 end
						hoveredIndex = math.floor(sectorDeg / (360 / #options)) + 1
					end

					for i, btnData in ipairs(buttons) do
						local targetSize = (i == hoveredIndex) and 100 or 80
						local targetTrans = (i == hoveredIndex) and 0 or 0.5
						local offset = targetSize / 2

						btnData.Frame.Size = btnData.Frame.Size:Lerp(UDim2.new(0, targetSize, 0, targetSize), 0.2)
						btnData.Frame.Position = btnData.Frame.Position:Lerp(UDim2.new(0, centerPos.X + math.cos(btnData.Angle) * radius - offset, 0, centerPos.Y + math.sin(btnData.Angle) * radius - offset), 0.2)
						btnData.Frame.BackgroundTransparency = btnData.Frame.BackgroundTransparency + (targetTrans - btnData.Frame.BackgroundTransparency) * 0.2
					end
				end)

				local menuOpenTime = tick()

				radialBg.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
						if tick() - menuOpenTime < 0.15 then return end

						if hoveredIndex then
							local action = buttons[hoveredIndex].Action
							if action ~= "Cancel" then
								InventoryFunction:InvokeServer(action, uniqueId)
							end
						end
						if rsConn then rsConn:Disconnect() end
						radialBg:Destroy()
						activeRadialMenu = nil
					end
				end)
			end
			-- =========================================================

			itemBtn.InputBegan:Connect(function(input)
				-- 1. ОТКРЫТИЕ МЕНЮ НА ПК (ПРАВАЯ КНОПКА МЫШИ)
				if input.UserInputType == Enum.UserInputType.MouseButton2 then
					if not activeRadialMenu and not currentDragClone then
						-- ФИКС 2: Идеальный центр - глобальная позиция курсора в данный момент
						openRadialMenu(UserInputService:GetMouseLocation())
					end
					return
				end

				-- 2. ОБРАБОТКА ЛЕВОЙ КНОПКИ И ТАЧА
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then

					-- Блокируем взаимодействие с инвентарем, если меню уже открыто
					if activeRadialMenu or (currentDragClone and not isDragging) then return end

					-- ПРОСЛУШКА ДВОЙНОГО ТАПА (ДЛЯ МОБИЛОК)
					if input.UserInputType == Enum.UserInputType.Touch then
						local currentTime = tick()
						local lastTap = itemBtn:GetAttribute("LastTap") or 0
						if currentTime - lastTap < 0.3 then
							itemBtn:SetAttribute("LastTap", 0)
							openRadialMenu(UserInputService:GetMouseLocation())
							return
						end
						itemBtn:SetAttribute("LastTap", currentTime)
					end

					-- СТАНДАРТНАЯ ЛОГИКА DRAG-AND-DROP
					if isDragging then
						isDragging = false
						itemBtn.Transparency = 0
						scrollFrame.ScrollingEnabled = true
						if currentDragClone then currentDragClone:Destroy() currentDragClone = nil end
					end

					dragStartPos = input.Position
					isDragging = false

					if moveConn then moveConn:Disconnect() moveConn = nil end
					if endConn then endConn:Disconnect() endConn = nil end

					moveConn = UserInputService.InputChanged:Connect(function(moveInput)
						if not itemBtn.Parent then
							if moveConn then moveConn:Disconnect() moveConn = nil end
							if endConn then endConn:Disconnect() endConn = nil end
							return
						end

						if moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch then
							local dist = (moveInput.Position - dragStartPos).Magnitude
							if dist > 10 and not isDragging then
								isDragging = true

								if moveInput.UserInputType == Enum.UserInputType.Touch then scrollFrame.ScrollingEnabled = false end

								itemBtn.Transparency = 0.6
								currentDragClone = itemBtn:Clone()
								currentDragClone.Size = UDim2.new(0, 80, 0, 80) 
								currentDragClone.Transparency = 0.2
								currentDragClone.ZIndex = 100
								currentDragClone.Active = false
								currentDragClone.Interactable = false
								currentDragClone.Parent = screenGui
							end

							if isDragging and currentDragClone then
								currentDragClone.Position = UDim2.new(0, moveInput.Position.X - 40, 0, moveInput.Position.Y - 40)
							end
						end
					end)

					endConn = UserInputService.InputEnded:Connect(function(endInput)
						if endInput.UserInputType == input.UserInputType then
							if moveConn then moveConn:Disconnect() moveConn = nil end
							if endConn then endConn:Disconnect() endConn = nil end

							if isDragging then
								isDragging = false
								scrollFrame.ScrollingEnabled = true 
								itemBtn.Transparency = 0
								if currentDragClone then currentDragClone:Destroy() currentDragClone = nil end

								local guisAtPosition = playerGui:GetGuiObjectsAtPosition(endInput.Position.X, endInput.Position.Y)
								local targetSlot = nil

								for _, gui in ipairs(guisAtPosition) do
									if gui.Name == "InvSlot" then targetSlot = gui break end
								end

								local mfPos = mainFrame.AbsolutePosition
								local mfSize = mainFrame.AbsoluteSize
								local mouseX, mouseY = endInput.Position.X, endInput.Position.Y
								local isOverMainFrame = (mouseX >= mfPos.X and mouseX <= mfPos.X + mfSize.X) and (mouseY >= mfPos.Y and mouseY <= mfPos.Y + mfSize.Y)

								if targetSlot and targetSlot ~= itemBtn.Parent then
									local existingItem = targetSlot:FindFirstChildOfClass("TextButton")
									if existingItem then
										existingItem.Parent = itemBtn.Parent
										localItemPositions[existingItem.Name] = itemBtn.Parent.LayoutOrder
									end
									itemBtn.Parent = targetSlot
									localItemPositions[uniqueId] = targetSlot.LayoutOrder
								elseif not isOverMainFrame then
									InventoryFunction:InvokeServer("Drop", uniqueId)
								end
							else
								if dragStartPos and (endInput.Position - dragStartPos).Magnitude <= 10 then
									-- ФИКС 3: Если открыто круговое меню, блокируем авто-экипировку от второго тапа!
									if not activeRadialMenu then
										InventoryFunction:InvokeServer("Equip", uniqueId)
									end
								end
							end
							dragStartPos = nil
						end
					end)
				end
			end)
		end
	end
end

-- ========================================================================
-- ЗАПУСК И УПРАВЛЕНИЕ ОКНОМ
-- ========================================================================
local function toggleInventory(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin then
		mainFrame.Visible = not mainFrame.Visible
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("ToggleInventory", toggleInventory, true, Enum.KeyCode.B, Enum.KeyCode.Tab)
ContextActionService:SetTitle("ToggleInventory", "Bag")

-- Защита от призраков: если меню закрыли во время перетаскивания
mainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if mainFrame.Visible then
		-- ИНВЕНТАРЬ ОТКРЫТ: Замораживаем зум на текущей дистанции
		local camera = workspace.CurrentCamera
		local currentZoom = (camera.CFrame.Position - camera.Focus.Position).Magnitude
		currentZoom = math.clamp(currentZoom, 0.5, 400) -- Защита от ошибок математики

		player.CameraMinZoomDistance = currentZoom
		player.CameraMaxZoomDistance = currentZoom
	else
		-- ИНВЕНТАРЬ ЗАКРЫТ: Разблокируем зум
		player.CameraMinZoomDistance = defaultMinZoom
		player.CameraMaxZoomDistance = defaultMaxZoom

		scrollFrame.ScrollingEnabled = true 
		if currentDragClone then
			currentDragClone:Destroy()
			currentDragClone = nil
			task.spawn(function()
				local data = InventoryFunction:InvokeServer("Get")
				if data then updateUI(data) end
			end)
		end

		-- УБИВАЕМ КРУГОВОЕ МЕНЮ ПРИ ЗАКРЫТИИ ИНВЕНТАРЯ
		if activeRadialMenu then
			activeRadialMenu:Destroy()
			activeRadialMenu = nil
		end
	end
end)

InventoryEvent.OnClientEvent:Connect(function(action, data)
	if action == "Update" then
		updateUI(data)
	end
end)

task.spawn(function()
	local initialData = false
	while not initialData do
		initialData = InventoryFunction:InvokeServer("Get")
		if not initialData then task.wait(1) end
	end
	updateUI(initialData)
end)