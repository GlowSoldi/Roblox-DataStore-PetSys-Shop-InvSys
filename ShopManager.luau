local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local PRODUCT_PETS = {
	[3607885334] = "Horse", 
}

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Игрок вышел во время покупки. Роблокс вернет ему деньги или попробует выдать позже.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local itemName = PRODUCT_PETS[receiptInfo.ProductId]

	if itemName then
		-- Пытаемся выдать предмет через нашу надежную функцию инвентаря
		if _G.giveItem then
			local success = _G.giveItem(player, itemName)

			if success then
				print(player.Name .. " успешно купил " .. itemName .. "!")
				-- Сообщаем Роблоксу: Товар выдан, можно списывать Робуксы!
				return Enum.ProductPurchaseDecision.PurchaseGranted
			else
				warn("Не удалось выдать " .. itemName .. " (Инвентарь вернул ошибку)")
			end
		else
			warn("Критическая ошибка: _G.giveItem не найдена!")
		end
	end

	-- Если что-то пошло не так, мы НЕ подтверждаем покупку, чтобы игрок не потерял Робуксы
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Подключаем нашу кассу к Роблоксу
MarketplaceService.ProcessReceipt = processReceipt