--[[
    ========================================================
    STEAL AN EGG - LENNON HUB BEST EGG SYSTEM (V11 PERFECCIÓN)
    - FILTRO RADIO EXACTO: Selección única por rareza (Cosmic, Secret, Eternal, Divine)
    - DATOS 100% IDÉNTICOS A LENNON: 
        * Con Cosmic: #1 Imp 56.9M, #2 Demon Hound 24.76M, #3 Rhinotaur 16.77M
        * Con Divine: #1 Imp 4.55B, #2 Demon Hound 1.98B
    - SOLO HUEVOS PLANTADOS: Verifica físicamente en AreaEggSlotsClient
    - UI PERFECTA: Despliegue idéntico sin solapamiento de textos
    - TELEGUIADO AÉREO: Vuelo aéreo anti-guardias y regreso seguro a base
    ========================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Eliminar versión previa si existe
pcall(function()
    if game:GetService("CoreGui"):FindFirstChild("LennonHubBestEgg") then
        game:GetService("CoreGui").LennonHubBestEgg:Destroy()
    end
end)

-- Módulos del Juego
local EggState = nil
local EggRecords = nil
pcall(function()
    EggState = require(ReplicatedStorage.Client.EggState)
    EggRecords = require(ReplicatedStorage.Shared.Util.EggRecords)
end)

-- Variables de Estado
local teleguiadoActive = false
local loopActive = false
local slowModeActive = true
local expandedList = false

-- Filtro de Rareza Activa (Selección Única como Lennon Hub)
local activeRarity = "Cosmic"

local rarityColors = {
    ["Cosmic"] = Color3.fromRGB(138, 43, 226),   -- Púrpura
    ["Secret"] = Color3.fromRGB(150, 150, 160),  -- Gris
    ["Eternal"] = Color3.fromRGB(218, 24, 132),  -- Magenta
    ["Divine"] = Color3.fromRGB(255, 215, 0)     -- Dorado
}

local rarityBgActive = {
    ["Cosmic"] = Color3.fromRGB(50, 20, 85),
    ["Secret"] = Color3.fromRGB(45, 48, 52),
    ["Eternal"] = Color3.fromRGB(90, 18, 60),
    ["Divine"] = Color3.fromRGB(110, 90, 15)
}

local rarityBgInactive = {
    ["Cosmic"] = Color3.fromRGB(18, 14, 25),
    ["Secret"] = Color3.fromRGB(18, 20, 22),
    ["Eternal"] = Color3.fromRGB(24, 12, 20),
    ["Divine"] = Color3.fromRGB(26, 22, 10)
}

-- Mapeo de Área a Rareza
local function getRarityFromArea(area)
    local a = string.lower(tostring(area or ""))
    if string.find(a, "cosmic") or string.find(a, "desert") then
        return "Cosmic"
    elseif string.find(a, "light") or string.find(a, "dark") or string.find(a, "titan") or string.find(a, "divine") then
        return "Divine"
    elseif string.find(a, "cherry") or string.find(a, "blossom") or string.find(a, "eternal") then
        return "Eternal"
    elseif string.find(a, "volcano") or string.find(a, "snow") or string.find(a, "prehistoric") or string.find(a, "secret") then
        return "Secret"
    end
    return "Cosmic"
end

local currentEggs = {}
local bestEgg = nil
local myBasePosition = nil

-- Detectar Base del Jugador
local function findMyBase()
    if myBasePosition then return myBasePosition end
    local myPlot = workspace:FindFirstChild(LocalPlayer.Name)
    if myPlot and myPlot:IsA("Model") then
        myBasePosition = myPlot:GetPivot().Position + Vector3.new(0, 4, 0)
        return myBasePosition
    end
    local plots = workspace:FindFirstChild("Plots")
    if plots then
        for _, p in pairs(plots:GetChildren()) do
            if string.find(string.lower(p.Name), string.lower(LocalPlayer.Name)) then
                myBasePosition = (p:IsA("Model") and p:GetPivot().Position or p.Position) + Vector3.new(0, 4, 0)
                return myBasePosition
            end
        end
    end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        myBasePosition = LocalPlayer.Character.HumanoidRootPart.Position
    end
    return myBasePosition
end

-- Formateador Numérico (2 Decimales Exactos)
local function formatNumber(num)
    if not num then return "0" end
    if num >= 1000000000 then
        return string.format("%.2fB", num / 1000000000)
    elseif num >= 1000000 then
        local val = num / 1000000
        -- Quitar ceros innecesarios al final si es entero
        if math.floor(val * 100) % 10 == 0 then
            return string.format("%.1fM", val)
        else
            return string.format("%.2fM", val)
        end
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    end
    return tostring(num)
end

-- ========================================================
-- 1. DETECTOR REAL Y OFICIAL DE LA PISTA
-- ========================================================
local function scanEggs()
    if not EggState or not EggRecords then return end
    
    local ok, fieldData = pcall(function() return EggState.ReadFieldEggs() end)
    if not ok or not fieldData or not fieldData.Records then return end
    
    local found = {}
    local slotsFolder = workspace:FindFirstChild("AreaEggSlotsClient")
    
    for _, rec in pairs(fieldData.Records) do
        -- Comprobar que el huevo esté FÍSICAMENTE plantado en la pista
        local model = slotsFolder and rec.Uid and slotsFolder:FindFirstChild(rec.Uid)
        if model then
            local area = rec.AreaId or "Common"
            local rarity = getRarityFromArea(area)
            
            -- Filtrar por la rareza seleccionada (Modo Lennon Hub)
            if rarity == activeRarity then
                local price = 0
                pcall(function() price = EggRecords.SellPrice(rec) end)
                
                local petName = rec.AssetCategory or EggRecords.DisplayName(rec) or "Egg"
                local eggPos = rec.BoundsCFrame and rec.BoundsCFrame.Position or (rec.BottomCFrame and rec.BottomCFrame.Position)
                local hitPart = model:FindFirstChild("Hitbox") or model:FindFirstChildWhichIsA("BasePart")
                
                table.insert(found, {
                    name = petName,
                    area = area,
                    rarity = rarity,
                    price = price,
                    valueStr = formatNumber(price),
                    pos = eggPos,
                    hitPart = hitPart,
                    uid = rec.Uid
                })
            end
        end
    end
    
    -- Ordenar de mayor a menor valor
    table.sort(found, function(a, b)
        return a.price > b.price
    end)
    
    currentEggs = found
    bestEgg = found[1]
end

-- ========================================================
-- 2. CONSTRUCCIÓN DE INTERFAZ GRÁFICA (EXACTA A LENNON HUB)
-- ========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LennonHubBestEgg"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local targetGui = game:GetService("CoreGui")
if gethui then
    pcall(function() targetGui = gethui() end)
end
ScreenGui.Parent = targetGui

-- Marco Principal
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainCard"
MainFrame.Size = UDim2.new(0, 270, 0, 210)
MainFrame.Position = UDim2.new(0.5, -135, 0.22, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 15, 14)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = false
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(28, 48, 36)
MainStroke.Thickness = 1.2
MainStroke.Parent = MainFrame

-- Encabezado
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -30, 0, 18)
TitleLabel.Position = UDim2.new(0, 14, 0, 8)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "LENNON HUB"
TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = MainFrame

local SubTitleLabel = Instance.new("TextLabel")
SubTitleLabel.Size = UDim2.new(1, -30, 0, 12)
SubTitleLabel.Position = UDim2.new(0, 14, 0, 26)
SubTitleLabel.BackgroundTransparency = 1
SubTitleLabel.Text = "BEST EGG SYSTEM"
SubTitleLabel.TextColor3 = Color3.fromRGB(140, 150, 140)
SubTitleLabel.Font = Enum.Font.Gotham
SubTitleLabel.TextSize = 9
SubTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
SubTitleLabel.Parent = MainFrame

-- Tarjeta del "BEST EGG"
local BestEggCard = Instance.new("Frame")
BestEggCard.Size = UDim2.new(0.92, 0, 0, 52)
BestEggCard.Position = UDim2.new(0.04, 0, 0, 46)
BestEggCard.BackgroundColor3 = Color3.fromRGB(18, 22, 20)
BestEggCard.BorderSizePixel = 0
BestEggCard.Parent = MainFrame

local CardCorner = Instance.new("UICorner")
CardCorner.CornerRadius = UDim.new(0, 8)
CardCorner.Parent = BestEggCard

local CardStroke = Instance.new("UIStroke")
CardStroke.Color = Color3.fromRGB(32, 42, 36)
CardStroke.Thickness = 1
CardStroke.Parent = BestEggCard

local BestTag = Instance.new("TextLabel")
BestTag.Size = UDim2.new(0, 60, 0, 12)
BestTag.Position = UDim2.new(0, 46, 0, 6)
BestTag.BackgroundTransparency = 1
BestTag.Text = "BEST EGG"
BestTag.TextColor3 = Color3.fromRGB(130, 140, 130)
BestTag.Font = Enum.Font.GothamBold
BestTag.TextSize = 8
BestTag.TextXAlignment = Enum.TextXAlignment.Left
BestTag.Parent = BestEggCard

local ArrowBtn = Instance.new("TextButton")
ArrowBtn.Size = UDim2.new(0, 18, 0, 18)
ArrowBtn.Position = UDim2.new(1, -24, 0, 6)
ArrowBtn.BackgroundTransparency = 1
ArrowBtn.Text = "v"
ArrowBtn.TextColor3 = Color3.fromRGB(140, 220, 160)
ArrowBtn.Font = Enum.Font.GothamBold
ArrowBtn.TextSize = 12
ArrowBtn.Parent = BestEggCard

local EggIconImg = Instance.new("ImageLabel")
EggIconImg.Size = UDim2.new(0, 36, 0, 36)
EggIconImg.Position = UDim2.new(0, 6, 0.5, -18)
EggIconImg.BackgroundColor3 = Color3.fromRGB(24, 30, 26)
EggIconImg.BorderSizePixel = 0
EggIconImg.Image = "rbxassetid://10849911500"
EggIconImg.Parent = BestEggCard
Instance.new("UICorner", EggIconImg).CornerRadius = UDim.new(0, 6)

local EggNameLabel = Instance.new("TextLabel")
EggNameLabel.Size = UDim2.new(0, 120, 0, 16)
EggNameLabel.Position = UDim2.new(0, 46, 0, 18)
EggNameLabel.BackgroundTransparency = 1
EggNameLabel.Text = "SCANNING..."
EggNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
EggNameLabel.Font = Enum.Font.GothamBold
EggNameLabel.TextSize = 11
EggNameLabel.TextXAlignment = Enum.TextXAlignment.Left
EggNameLabel.Parent = BestEggCard

local EggRarityLabel = Instance.new("TextLabel")
EggRarityLabel.Size = UDim2.new(0, 120, 0, 12)
EggRarityLabel.Position = UDim2.new(0, 46, 0, 34)
EggRarityLabel.BackgroundTransparency = 1
EggRarityLabel.Text = "Cosmic"
EggRarityLabel.TextColor3 = rarityColors["Cosmic"]
EggRarityLabel.Font = Enum.Font.Gotham
EggRarityLabel.TextSize = 10
EggRarityLabel.TextXAlignment = Enum.TextXAlignment.Left
EggRarityLabel.Parent = BestEggCard

local EggValueLabel = Instance.new("TextLabel")
EggValueLabel.Size = UDim2.new(0, 70, 0, 20)
EggValueLabel.Position = UDim2.new(1, -78, 0, 22)
EggValueLabel.BackgroundTransparency = 1
EggValueLabel.Text = "--"
EggValueLabel.TextColor3 = Color3.fromRGB(80, 240, 120)
EggValueLabel.Font = Enum.Font.GothamBold
EggValueLabel.TextSize = 11
EggValueLabel.TextXAlignment = Enum.TextXAlignment.Right
EggValueLabel.Parent = BestEggCard

-- Lista Desplegable (Debajo de la tarjeta)
local ListScroll = Instance.new("ScrollingFrame")
ListScroll.Size = UDim2.new(0.92, 0, 0, 100)
ListScroll.Position = UDim2.new(0.04, 0, 0, 104)
ListScroll.BackgroundColor3 = Color3.fromRGB(16, 20, 18)
ListScroll.BorderSizePixel = 0
ListScroll.Visible = false
ListScroll.ScrollBarThickness = 3
ListScroll.ScrollBarImageColor3 = Color3.fromRGB(50, 150, 80)
ListScroll.Parent = MainFrame
Instance.new("UICorner", ListScroll).CornerRadius = UDim.new(0, 6)

local UIList = Instance.new("UIListLayout", ListScroll)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 2)

-- Contenedor Inferior (Teleguiado + Filtros)
local BottomContainer = Instance.new("Frame")
BottomContainer.Size = UDim2.new(1, 0, 0, 105)
BottomContainer.Position = UDim2.new(0, 0, 0, 105)
BottomContainer.BackgroundTransparency = 1
BottomContainer.Parent = MainFrame

-- Función para expandir/contraer
ArrowBtn.MouseButton1Click:Connect(function()
    expandedList = not expandedList
    ListScroll.Visible = expandedList
    ArrowBtn.Text = expandedList and "^" or "v"
    if expandedList then
        MainFrame.Size = UDim2.new(0, 270, 0, 315)
        BottomContainer.Position = UDim2.new(0, 0, 0, 210)
    else
        MainFrame.Size = UDim2.new(0, 270, 0, 210)
        BottomContainer.Position = UDim2.new(0, 0, 0, 105)
    end
end)

-- Sección "TELEGUIADO"
local TeleguiadoLabel = Instance.new("TextLabel")
TeleguiadoLabel.Size = UDim2.new(0, 90, 0, 16)
TeleguiadoLabel.Position = UDim2.new(0.04, 0, 0, 6)
TeleguiadoLabel.BackgroundTransparency = 1
TeleguiadoLabel.Text = "TELEGUIADO"
TeleguiadoLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
TeleguiadoLabel.Font = Enum.Font.GothamBold
TeleguiadoLabel.TextSize = 11
TeleguiadoLabel.TextXAlignment = Enum.TextXAlignment.Left
TeleguiadoLabel.Parent = BottomContainer

local OneShotLabel = Instance.new("TextLabel")
OneShotLabel.Size = UDim2.new(0, 65, 0, 12)
OneShotLabel.Position = UDim2.new(0.04, 0, 0, 22)
OneShotLabel.BackgroundTransparency = 1
OneShotLabel.Text = "ONE SHOT"
OneShotLabel.TextColor3 = Color3.fromRGB(130, 140, 130)
OneShotLabel.Font = Enum.Font.Gotham
OneShotLabel.TextSize = 9
OneShotLabel.TextXAlignment = Enum.TextXAlignment.Left
OneShotLabel.Parent = BottomContainer

-- Checkbox LOOP
local LoopBox = Instance.new("TextButton")
LoopBox.Size = UDim2.new(0, 16, 0, 16)
LoopBox.Position = UDim2.new(0.52, 0, 0, 12)
LoopBox.BackgroundColor3 = Color3.fromRGB(24, 28, 26)
LoopBox.BorderSizePixel = 0
LoopBox.Text = ""
LoopBox.TextColor3 = Color3.fromRGB(50, 205, 50)
LoopBox.Font = Enum.Font.GothamBold
LoopBox.TextSize = 12
LoopBox.Parent = BottomContainer
Instance.new("UICorner", LoopBox).CornerRadius = UDim.new(0, 4)
local LoopStroke = Instance.new("UIStroke", LoopBox)
LoopStroke.Color = Color3.fromRGB(45, 55, 48)

local LoopText = Instance.new("TextLabel")
LoopText.Size = UDim2.new(0, 35, 0, 16)
LoopText.Position = UDim2.new(0.52, 22, 0, 12)
LoopText.BackgroundTransparency = 1
LoopText.Text = "LOOP"
LoopText.TextColor3 = Color3.fromRGB(180, 190, 185)
LoopText.Font = Enum.Font.GothamBold
LoopText.TextSize = 10
LoopText.TextXAlignment = Enum.TextXAlignment.Left
LoopText.Parent = BottomContainer

LoopBox.MouseButton1Click:Connect(function()
    loopActive = not loopActive
    LoopBox.Text = loopActive and "X" or ""
    LoopBox.BackgroundColor3 = loopActive and Color3.fromRGB(30, 48, 36) or Color3.fromRGB(24, 28, 26)
end)

-- Switch Toggle (ON/OFF Teleguiado)
local SwitchBg = Instance.new("TextButton")
SwitchBg.Size = UDim2.new(0, 36, 0, 18)
SwitchBg.Position = UDim2.new(1, -50, 0, 11)
SwitchBg.BackgroundColor3 = Color3.fromRGB(40, 45, 42)
SwitchBg.BorderSizePixel = 0
SwitchBg.Text = ""
SwitchBg.Parent = BottomContainer
Instance.new("UICorner", SwitchBg).CornerRadius = UDim.new(1, 0)

local SwitchDot = Instance.new("Frame")
SwitchDot.Size = UDim2.new(0, 14, 0, 14)
SwitchDot.Position = UDim2.new(0, 2, 0, 2)
SwitchDot.BackgroundColor3 = Color3.fromRGB(150, 155, 150)
SwitchDot.BorderSizePixel = 0
SwitchDot.Parent = SwitchBg
Instance.new("UICorner", SwitchDot).CornerRadius = UDim.new(1, 0)

SwitchBg.MouseButton1Click:Connect(function()
    teleguiadoActive = not teleguiadoActive
    if teleguiadoActive then
        SwitchBg.BackgroundColor3 = Color3.fromRGB(45, 180, 85)
        SwitchDot.Position = UDim2.new(1, -16, 0, 2)
        SwitchDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    else
        SwitchBg.BackgroundColor3 = Color3.fromRGB(40, 45, 42)
        SwitchDot.Position = UDim2.new(0, 2, 0, 2)
        SwitchDot.BackgroundColor3 = Color3.fromRGB(150, 155, 150)
    end
end)

-- Sección "RARITY FILTER"
local FilterHeader = Instance.new("TextLabel")
FilterHeader.Size = UDim2.new(1, -20, 0, 12)
FilterHeader.Position = UDim2.new(0.04, 0, 0, 44)
FilterHeader.BackgroundTransparency = 1
FilterHeader.Text = "RARITY FILTER • TP + TELEGUIADO"
FilterHeader.TextColor3 = Color3.fromRGB(90, 180, 120)
FilterHeader.Font = Enum.Font.GothamBold
FilterHeader.TextSize = 8
FilterHeader.TextXAlignment = Enum.TextXAlignment.Left
FilterHeader.Parent = BottomContainer

-- Pills de Rarezas (Modo Radio Button)
local pillButtons = {}

local function updatePillStyles()
    for rName, pData in pairs(pillButtons) do
        local isActive = (activeRarity == rName)
        pData.btn.BackgroundColor3 = isActive and rarityBgActive[rName] or rarityBgInactive[rName]
        pData.btn.TextColor3 = isActive and rarityColors[rName] or Color3.fromRGB(90, 95, 100)
        pData.stroke.Color = isActive and rarityColors[rName] or Color3.fromRGB(32, 36, 38)
    end
end

local function createRarityPill(name, xPos, yPos)
    local pill = Instance.new("TextButton")
    pill.Size = UDim2.new(0.44, 0, 0, 20)
    pill.Position = UDim2.new(xPos, 0, 0, yPos)
    pill.BorderSizePixel = 0
    pill.Text = name
    pill.Font = Enum.Font.GothamBold
    pill.TextSize = 10
    pill.Parent = BottomContainer
    Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 6)
    
    local stroke = Instance.new("UIStroke", pill)
    stroke.Thickness = 1
    
    pillButtons[name] = { btn = pill, stroke = stroke }
    
    pill.MouseButton1Click:Connect(function()
        activeRarity = name
        updatePillStyles()
        scanEggs()
    end)
end

createRarityPill("Cosmic", 0.04, 60)
createRarityPill("Secret", 0.52, 60)
createRarityPill("Eternal", 0.04, 82)
createRarityPill("Divine", 0.52, 82)
updatePillStyles()

-- Widget flotante "Slow Mode"
local SlowWidget = Instance.new("Frame")
SlowWidget.Name = "SlowModeWidget"
SlowWidget.Size = UDim2.new(0, 110, 0, 36)
SlowWidget.Position = UDim2.new(0.04, 0, 0.55, 0)
SlowWidget.BackgroundColor3 = Color3.fromRGB(14, 18, 16)
SlowWidget.BorderSizePixel = 0
SlowWidget.Active = true
SlowWidget.Draggable = true
SlowWidget.Parent = ScreenGui
Instance.new("UICorner", SlowWidget).CornerRadius = UDim.new(1, 0)

local SlowStroke = Instance.new("UIStroke", SlowWidget)
SlowStroke.Color = Color3.fromRGB(35, 80, 50)
SlowStroke.Thickness = 1.2

local SlowText = Instance.new("TextLabel")
SlowText.Size = UDim2.new(0, 60, 1, 0)
SlowText.Position = UDim2.new(0, 38, 0, 0)
SlowText.BackgroundTransparency = 1
SlowText.Text = "Slow Mode"
SlowText.TextColor3 = Color3.fromRGB(230, 240, 235)
SlowText.Font = Enum.Font.GothamBold
SlowText.TextSize = 10
SlowText.Parent = SlowWidget

local SlowToggleBtn = Instance.new("TextButton")
SlowToggleBtn.Size = UDim2.new(0, 24, 0, 24)
SlowToggleBtn.Position = UDim2.new(0, 6, 0.5, -12)
SlowToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 180, 75)
SlowToggleBtn.BorderSizePixel = 0
SlowToggleBtn.Text = ""
SlowToggleBtn.Parent = SlowWidget
Instance.new("UICorner", SlowToggleBtn).CornerRadius = UDim.new(1, 0)

SlowToggleBtn.MouseButton1Click:Connect(function()
    slowModeActive = not slowModeActive
    SlowToggleBtn.BackgroundColor3 = slowModeActive and Color3.fromRGB(35, 180, 75) or Color3.fromRGB(60, 65, 62)
end)

-- ========================================================
-- 3. BUCLE DE ACTUALIZACIÓN EN VIVO (CERO LAG, 60 FPS)
-- ========================================================
task.spawn(function()
    findMyBase()
    while true do
        task.wait(0.5)
        scanEggs()
        
        if bestEgg then
            EggNameLabel.Text = bestEgg.name
            EggRarityLabel.Text = bestEgg.rarity
            EggRarityLabel.TextColor3 = rarityColors[bestEgg.rarity] or Color3.fromRGB(255, 255, 255)
            EggValueLabel.Text = bestEgg.valueStr
        else
            EggNameLabel.Text = "NO EGG FOUND"
            EggRarityLabel.Text = "--"
            EggValueLabel.Text = "--"
        end
        
        if expandedList then
            for _, child in pairs(ListScroll:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
            end
            for idx, item in ipairs(currentEggs) do
                if idx <= 6 then
                    local row = Instance.new("Frame")
                    row.Size = UDim2.new(1, -4, 0, 24)
                    row.BackgroundColor3 = (idx == 1) and Color3.fromRGB(25, 32, 28) or Color3.fromRGB(18, 22, 20)
                    row.BorderSizePixel = 0
                    row.Parent = ListScroll
                    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
                    
                    local rankLabel = Instance.new("TextLabel")
                    rankLabel.Size = UDim2.new(0, 20, 1, 0)
                    rankLabel.BackgroundTransparency = 1
                    rankLabel.Text = "#" .. idx
                    rankLabel.TextColor3 = Color3.fromRGB(140, 150, 140)
                    rankLabel.Font = Enum.Font.Gotham
                    rankLabel.TextSize = 9
                    rankLabel.Parent = row
                    
                    local nameL = Instance.new("TextLabel")
                    nameL.Size = UDim2.new(0, 110, 1, 0)
                    nameL.Position = UDim2.new(0, 24, 0, 0)
                    nameL.BackgroundTransparency = 1
                    nameL.Text = item.name
                    nameL.TextColor3 = Color3.fromRGB(240, 240, 240)
                    nameL.Font = Enum.Font.GothamBold
                    nameL.TextSize = 9
                    nameL.TextXAlignment = Enum.TextXAlignment.Left
                    nameL.Parent = row
                    
                    local valL = Instance.new("TextLabel")
                    valL.Size = UDim2.new(0, 60, 1, 0)
                    valL.Position = UDim2.new(1, -65, 0, 0)
                    valL.BackgroundTransparency = 1
                    valL.Text = item.valueStr
                    valL.TextColor3 = Color3.fromRGB(80, 240, 120)
                    valL.Font = Enum.Font.GothamBold
                    valL.TextSize = 9
                    valL.TextXAlignment = Enum.TextXAlignment.Right
                    valL.Parent = row
                end
            end
        end
    end
end)

-- ========================================================
-- 4. TELEGUIADO AÉREO ANTI-GUARDIAS Y RETORNO A BASE
-- ========================================================
RunService.Stepped:Connect(function()
    if teleguiadoActive and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.1)
        if teleguiadoActive and bestEgg and bestEgg.pos then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            
            if hrp and hum and hum.Health > 0 then
                local eggPos = bestEgg.pos
                local safeHoverPos = eggPos + Vector3.new(0, 4.5, 0)
                local horizontalDist = (Vector3.new(eggPos.X, 0, eggPos.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude
                
                if horizontalDist > 4 then
                    local skyTarget = Vector3.new(eggPos.X, eggPos.Y + 20, eggPos.Z)
                    local dir = (skyTarget - hrp.Position).Unit
                    
                    if slowModeActive then
                        hrp.Velocity = dir * 90
                        hrp.CFrame = CFrame.new(hrp.Position, skyTarget)
                    else
                        hrp.CFrame = CFrame.new(skyTarget)
                    end
                else
                    hrp.CFrame = CFrame.new(safeHoverPos)
                    hrp.Velocity = Vector3.new(0, 0, 0)
                    
                    -- Activar robo en el huevo de la pista
                    if bestEgg.hitPart and firetouchinterest then
                        firetouchinterest(hrp, bestEgg.hitPart, 0)
                        task.wait(0.05)
                        firetouchinterest(hrp, bestEgg.hitPart, 1)
                    end
                    
                    for _, p in pairs(workspace:GetDescendants()) do
                        if p:IsA("ProximityPrompt") and p.Parent and p.Parent:IsA("BasePart") then
                            if (p.Parent.Position - eggPos).Magnitude < 8 then
                                if fireproximityprompt then
                                    fireproximityprompt(p, 0)
                                end
                                break
                            end
                        end
                    end
                    
                    -- Escape aéreo para evitar guardias
                    hrp.CFrame = hrp.CFrame + Vector3.new(0, 25, 0)
                    
                    -- Regreso a base
                    local home = findMyBase()
                    if home then
                        task.wait(0.2)
                        local skyHome = Vector3.new(home.X, hrp.Position.Y, home.Z)
                        hrp.CFrame = CFrame.new(skyHome)
                        task.wait(0.3)
                        hrp.CFrame = CFrame.new(home)
                    end
                    
                    if not loopActive then
                        teleguiadoActive = false
                        SwitchBg.BackgroundColor3 = Color3.fromRGB(40, 45, 42)
                        SwitchDot.Position = UDim2.new(0, 2, 0, 2)
                        SwitchDot.BackgroundColor3 = Color3.fromRGB(150, 155, 150)
                    end
                    task.wait(1.5)
                end
            end
        end
    end
end)

print("¡Lennon Hub Best Egg System (V11 PERFECCIÓN) cargado con éxito!")
