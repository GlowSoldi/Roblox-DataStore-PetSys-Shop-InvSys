local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- ==========================================
-- БАЗА ДАННЫХ МАГАЗИНА (Добавляй товары сюда)
-- ==========================================
local SHOP_ITEMS = {
	{
		Name = "Horse", 
		DisplayName = "Ездовой Конь", 
		Price = 1000, 
		ProductId = 3607885334 
	},
	
}

-- ==========================================
-- СОЗДАНИЕ ИНТЕРФЕЙСА 
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PetShopGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- 1. Кнопка ОТКРЫТИЯ магазина (Аккуратная, справа по центру)
local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.new(0, 160, 0, 45)
openBtn.Position = UDim2.new(1, -170, 0.5, -22)
openBtn.BackgroundColor3 = Color3.fromRGB(40, 150, 255)
openBtn.Text = "Магазин Питомцев"
openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
openBtn.Font = Enum.Font.BuilderSansBold
openBtn.TextSize = 16
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 8)
openBtn.Parent = screenGui

-- 2. ГЛАВНОЕ ОКНО магазина (Скрыто по умолчанию)
local shopFrame = Instance.new("Frame")
shopFrame.Size = UDim2.new(0, 500, 0, 350)
shopFrame.Position = UDim2.new(0.5, -250, 0.5, -175)
shopFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
shopFrame.Visible = false
Instance.new("UICorner", shopFrame).CornerRadius = UDim.new(0, 12)
shopFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundTransparency = 1
title.Text = "МАГАЗИН ПИТОМЦЕВ"
title.TextColor3 = Color3.fromRGB(255, 200, 50)
title.Font = Enum.Font.BuilderSansBold
title.TextSize = 24
title.Parent = shopFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.BuilderSansBold
closeBtn.TextSize = 20
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.Parent = shopFrame

-- 3. КОНТЕЙНЕР ДЛЯ ТОВАРОВ (Сетка)
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -20, 1, -60)
scrollFrame.Position = UDim2.new(0, 10, 0, 50)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 6
scrollFrame.Parent = shopFrame

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0, 145, 0, 160) -- Размер одной карточки товара
grid.CellPadding = UDim2.new(0, 15, 0, 15)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = scrollFrame

-- ==========================================
-- ЛОГИКА: АВТО-ГЕНЕРАЦИЯ КАРТОЧЕК
-- ==========================================
for i, item in ipairs(SHOP_ITEMS) do
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	card.LayoutOrder = i
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 40)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = item.DisplayName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Font = Enum.Font.BuilderSansMedium
	nameLabel.TextSize = 16
	nameLabel.Parent = card

	-- Здесь можно добавить картинку

	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(0.8, 0, 0, 40)
	buyBtn.Position = UDim2.new(0.1, 0, 1, -50)
	buyBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
	buyBtn.Text = item.Price .. " R$"
	buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyBtn.Font = Enum.Font.BuilderSansBold
	buyBtn.TextSize = 18
	Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 8)
	buyBtn.Parent = card

	-- Логика покупки для каждой карточки
	buyBtn.MouseButton1Click:Connect(function()
		MarketplaceService:PromptProductPurchase(player, item.ProductId)
	end)

	card.Parent = scrollFrame
end

-- ==========================================
-- ЛОГИКА: ОТКРЫТИЕ И ЗАКРЫТИЕ
-- ==========================================
openBtn.MouseButton1Click:Connect(function()
	shopFrame.Visible = not shopFrame.Visible
end)

closeBtn.MouseButton1Click:Connect(function()
	shopFrame.Visible = false
end)