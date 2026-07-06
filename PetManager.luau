local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetTemplates = ReplicatedStorage:WaitForChild("PetTemplates")
local PetToggle = ServerStorage:WaitForChild("Bindables"):WaitForChild("PetToggle")

local activePets = {}

-- ==========================================
-- НАСТРОЙКИ ПИТОМЦА
-- ==========================================
local ROTATION_FIX = 90 

-- ФУНКЦИЯ: Удаление текущего питомца
local function removePet(player)
	if activePets[player.UserId] then
		-- Возвращаем скорость и анимации игроку
		if activePets[player.UserId].IsRiding and player.Character then
			local hum = player.Character:FindFirstChild("Humanoid")
			if hum then 
				hum.WalkSpeed = 16 
				if activePets[player.UserId].OriginalHipHeight then
					hum.HipHeight = activePets[player.UserId].OriginalHipHeight
				end
			end
		end

		-- Останавливаем анимацию сидения
		if activePets[player.UserId].RideAnimTrack then
			activePets[player.UserId].RideAnimTrack:Stop()
		end

		-- Отключаем смарт-луп перед удалением
		if activePets[player.UserId].Connection then
			activePets[player.UserId].Connection:Disconnect()
		end

		if activePets[player.UserId].Model then activePets[player.UserId].Model:Destroy() end
		activePets[player.UserId] = nil
	end
end

-- ФУНКЦИЯ: Спавн нового питомца
local function spawnPet(player, petName)
	removePet(player)

	local template = PetTemplates:FindFirstChild(petName)
	local char = player.Character
	if not template or not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local pet = template:Clone()
	local primaryPart = pet.PrimaryPart
	if not primaryPart then return end

	pet:PivotTo(hrp.CFrame * CFrame.new(2, 0, 3))

	for _, part in ipairs(pet:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true
			part.Anchored = false

			if part ~= primaryPart then
				local weld = part:FindFirstChild("AutoPetWeld") or Instance.new("WeldConstraint")
				weld.Name = "AutoPetWeld"
				weld.Part0 = part
				weld.Part1 = primaryPart
				weld.Parent = part
			end
		end
	end

	local petAttachment = Instance.new("Attachment")
	petAttachment.Parent = primaryPart

	-- ИСПОЛЬЗУЕМ OneAttachment (Смарт-управление из скрипта)
	local alignPos = Instance.new("AlignPosition")
	alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPos.Attachment0 = petAttachment
	alignPos.MaxForce = 100000 
	alignPos.MaxVelocity = 22 -- Эффект догонялок
	alignPos.Responsiveness = 8
	alignPos.Parent = primaryPart

	local alignOri = Instance.new("AlignOrientation")
	alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOri.Attachment0 = petAttachment
	alignOri.MaxTorque = math.huge
	alignOri.Responsiveness = 10
	alignOri.Parent = primaryPart

	-- ==========================================
	-- ЛОГИКА ЕЗДЫ ВЕРХОМ 
	-- ==========================================
	local ridePrompt = Instance.new("ProximityPrompt")
	ridePrompt.ActionText = "Ехать верхом"
	ridePrompt.ObjectText = petName
	ridePrompt.RequiresLineOfSight = false
	ridePrompt.KeyboardKeyCode = Enum.KeyCode.E
	ridePrompt.Parent = primaryPart

	-- Предварительно сохраняем данные, чтобы событие Triggered могло их менять
	activePets[player.UserId] = {
		Model = pet, 
		IsRiding = false
	}

	ridePrompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= player then return end 

		local petData = activePets[player.UserId]
		local humanoid = char:FindFirstChild("Humanoid")
		if not petData or not humanoid then return end

		if not petData.IsRiding then
			-- === САДИМСЯ НА ПИТОМЦА ===
			petData.IsRiding = true
			ridePrompt.ActionText = "Слезть"

			alignPos.Enabled = false
			alignOri.Enabled = false

			-- ==========================================
			-- НАСТРОЙКА ВЫСОТЫ ПОСАДКИ 
			-- ==========================================
			local HIP_BOOST = 1    -- Насколько поднять капсулу игрока 
			local HORSE_OFFSET = -2.5 -- Насколько опустить коня вниз от центра игрока

			petData.OriginalHipHeight = humanoid.HipHeight
			humanoid.HipHeight = humanoid.HipHeight + HIP_BOOST

			-- Жесткая сварка
			local rideWeld = Instance.new("Weld")
			rideWeld.Name = "RideWeld"
			rideWeld.Part0 = hrp
			rideWeld.Part1 = primaryPart
			rideWeld.C0 = CFrame.new(0, HORSE_OFFSET, 0) * CFrame.Angles(0, math.rad(ROTATION_FIX), 0)
			rideWeld.Parent = primaryPart

			-- Запускаем анимацию сидения с ВЫСШИМ ПРИОРИТЕТОМ
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				local sitAnim = Instance.new("Animation")
				sitAnim.AnimationId = (humanoid.RigType == Enum.HumanoidRigType.R15) and "rbxassetid://2506281703" or "rbxassetid://178130996"
				local track = animator:LoadAnimation(sitAnim)

				-- ФИКС: Запрещаем Роблоксу перебивать эту анимацию бегом!
				track.Priority = Enum.AnimationPriority.Action 

				track:Play()
				petData.RideAnimTrack = track
			end

			humanoid.WalkSpeed = 35
		else
			-- === СЛЕЗАЕМ С ПИТОМЦА ===
			petData.IsRiding = false
			ridePrompt.ActionText = "Ехать верхом"

			-- 1. Удаляем сварку
			local rideWeld = primaryPart:FindFirstChild("RideWeld")
			if rideWeld then rideWeld:Destroy() end

			-- 2. Возвращаем оригинальную высоту
			if petData.OriginalHipHeight then
				humanoid.HipHeight = petData.OriginalHipHeight
			end

			-- 3. Останавливаем анимацию сидения
			if petData.RideAnimTrack then
				petData.RideAnimTrack:Stop()
				petData.RideAnimTrack = nil
			end

			-- 4. Возвращаем стандартную скорость
			humanoid.WalkSpeed = 16

			-- 5. Включаем следование обратно
			pet:PivotTo(hrp.CFrame * CFrame.new(2.5, 0, 4))
			alignPos.Enabled = true
			alignOri.Enabled = true
		end
	end)

	pet.Parent = workspace

	-- ==========================================
	-- СМАРТ-ЛУП: ЖИВОЕ ПОВЕДЕНИЕ 
	-- ==========================================
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {char, pet} 

	local runConnection = RunService.Heartbeat:Connect(function()
		if activePets[player.UserId] and activePets[player.UserId].IsRiding then return end
		if not hrp.Parent then return end

		local idealOffset = hrp.CFrame * CFrame.new(2.5, 0, 4.5)
		local targetX = idealOffset.Position.X
		local targetZ = idealOffset.Position.Z

		local rayOrigin = Vector3.new(targetX, hrp.Position.Y + 5, targetZ)
		local rayResult = workspace:Raycast(rayOrigin, Vector3.new(0, -20, 0), rayParams)

		local floorY = hrp.Position.Y
		if rayResult then
			floorY = rayResult.Position.Y + 1.5 
		end

		local isMoving = hrp.Velocity.Magnitude > 2
		local bobbing = 0
		if isMoving then
			bobbing = math.sin(tick() * 12) * 0.4
		else
			bobbing = math.sin(tick() * 2) * 0.1
		end

		alignPos.Position = Vector3.new(targetX, floorY + bobbing, targetZ)

		local lookTarget
		if isMoving then
			lookTarget = pet.PrimaryPart.Position + hrp.CFrame.LookVector
		else
			lookTarget = Vector3.new(hrp.Position.X, pet.PrimaryPart.Position.Y, hrp.Position.Z)
		end

		local targetCFrame = CFrame.lookAt(pet.PrimaryPart.Position, lookTarget)

		if ROTATION_FIX ~= 0 then
			targetCFrame = targetCFrame * CFrame.Angles(0, math.rad(ROTATION_FIX), 0)
		end

		alignOri.CFrame = targetCFrame
	end)

	-- Обновляем данные 
	activePets[player.UserId].Connection = runConnection
end

PetToggle.Event:Connect(function(player, petName, isEquipping)
	if isEquipping then
		spawnPet(player, petName)
	else
		removePet(player)
	end
end)

game.Players.PlayerRemoving:Connect(removePet)