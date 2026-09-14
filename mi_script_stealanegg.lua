--[[
    ========================================================================
    STEAL AN EGG - NATIVE HUB (100% STANDALONE & ZERO KEYS)
    - ARCHIVO: new.lua
    - DESARROLLADO 100% NATIVO PARA ANDROID (DELTA EXECUTOR)
    
    CARACTERISTICAS:
    1. MOTOR DE DETECCION Y VALUACION OFICIAL:
       - Modulo nativo: ReplicatedStorage.Client.EggState.ReadFieldEggs()
       - Valuacion por segundo exacta: ReplicatedStorage.Shared.Util.AssetEarnings
       - Mapeo automatico de rarezas desde el catalogo interno del juego
       - Eliminacion automatica de huevos robados o fantasma en 0.2s
       
    2. SISTEMA DE ROBO NATIVO:
       - Localizacion dinamica del prompt real: Workspace.SmartPromptPart.CarryAreaEgg
       - Activacion nativa de conexiones de evento: getconnections(prompt.Triggered)
       - Invocacion de respaldo nativo: EggState.CarryFieldEgg(uid)
       
    3. TELEGUIADO AEREO SEGURO ANTI-GUARDIAS:
       - Crucero aereo a Y = 92.9 studs (fuera del alcance de los bates de los guardias)
       - Descenso vertical tipo ascensor directo sobre el nido
       - Escape aereo vertical inmediato con el huevo y retorno seguro a base
       
    4. INTERFAZ GRAFICA MODERNA:
       - Boton flotante draggable para minimizar / abrir
       - Filtros individuales de rareza (Cosmic, Secret, Eternal, Divine, Mythic)
       - Lista expandible con ranking de mejores huevos de la pista
    ========================================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Eliminar instancias previas de la interfaz
pcall(function()
    if game:GetService("CoreGui"):FindFirstChild("NativeEggHubGui") then
        game:GetService("CoreGui").NativeEggHubGui:Destroy()
    end
end)

-- ========================================================
-- 1. MODULOS NATIVOS DEL JUEGO Y MAPA DE RAREZAS
-- ========================================================
local EggState = nil
local AssetEarnings = nil
local EggRecords = nil
local petRarityMap = {}

pcall(function()
    EggState = require(ReplicatedStorage.Client.EggState)
    AssetEarnings = require(ReplicatedStorage.Shared.Util.AssetEarnings)
    EggRecords = require(ReplicatedStorage.Shared.Util.EggRecords)
    
    if AssetEarnings and debug and debug.getupvalues then
        local ups = debug.getupvalues(AssetEarnings.CatalogRatePerSecond)
        if ups and ups[2] and ups[2].ByRarity then
            for rName, pList in pairs(ups[2].ByRarity) do
                for pName, _ in pairs(pList) do
                    petRarityMap[tostring(pName)] = tostring(rName)
                end
            end
        end
    end
end)

-- Variables de Estado
local teleguiadoActive = false
local slowModeActive = false
local expandedList = false
local isFlying = false
local currentTween = nil
local noclipConn = nil
local stopTeleguiado = nil

-- Filtros de Rarezas
local selectedRarities = {
    ["Cosmic"] = true,
    ["Secret"] = false,
    ["Eternal"] = false,
    ["Divine"] = false,
    ["Mythic"] = false
}

local rarityColors = {
    ["Cosmic"] = Color3.fromRGB(155, 75, 255),
    ["Secret"] = Color3.fromRGB(175, 180, 195),
    ["Eternal"] = Color3.fromRGB(255, 45, 150),
    ["Divine"] = Color3.fromRGB(255, 215, 0),
    ["Mythic"] = Color3.fromRGB(245, 55, 75)
}

local rarityBgActive = {
    ["Cosmic"] = Color3.fromRGB(55, 20, 95),
    ["Secret"] = Color3.fromRGB(50, 52, 60),
    ["Eternal"] = Color3.fromRGB(95, 20, 65),
    ["Divine"] = Color3.fromRGB(105, 85, 15),
    ["Mythic"] = Color3.fromRGB(95, 20, 25)
}

local rarityBgInactive = {
    ["Cosmic"] = Color3.fromRGB(20, 15, 28),
    ["Secret"] = Color3.fromRGB(22, 24, 28),
    ["Eternal"] = Color3.fromRGB(28, 14, 22),
    ["Divine"] = Color3.fromRGB(28, 24, 12),
    ["Mythic"] = Color3.fromRGB(28, 14, 16)
}

-- Formateador Monetario Oficial
local function formatNumber(n)
    if not n or n == 0 then return "zsh/s" end
    local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
    local idx = 1
    local num = math.abs(n)
    while num >= 1000 and idx < #suffixes do
        num = num / 1000
        idx = idx + 1
    end
    if idx == 1 then
        return string.format("$%d/s", num)
    else
        return string.format("$%.2f %s/s", num, suffixes[idx])
    end
end

-- Determinar Rareza de un Registro
local function getRarityFromRecord(rec)
    if not rec then return "Cosmic" end
    local cat = tostring(rec.AssetCategory or "")
    if petRarityMap[cat] then return petRarityMap[cat] end
    
    local area = tostring(rec.AreaId or "")
    if area == "Cosmic" then return "Cosmic" end
    if area == "Volcano" then return "Divine" end
    if area == "Prehistoric" then return "Eternal" end
    if area == "Angels" or area == "Demons" then return "Secret" end
    return "Cosmic"
end

-- ========================================================
-- 2. ESCANEO Y DETECCION DE HUEVOS DISPONIBLES
-- ========================================================
local currentEggs = {}
local bestEgg = nil

local function scanEggs()
    local found = {}
    local anySelected = false
    for _, v in pairs(selectedRarities) do
        if v then anySelected = true break end
    end
    
    if EggState and EggState.ReadFieldEggs then
        local ok, fieldData = pcall(function() return EggState.ReadFieldEggs() end)
        if ok and fieldData and fieldData.Records then
            local slotsFolder = workspace:FindFirstChild("AreaEggSlotsClient")
            for _, rec in pairs(fieldData.Records) do
                -- 1. Validar que el huevo este realmente en un nido
                if rec.State and rec.State ~= "Slot" then
                    continue
                end
                
                -- 2. Descartar huevos que no esten en el mundo del cliente
                local slotModel = slotsFolder and rec.Uid and slotsFolder:FindFirstChild(rec.Uid)
                if slotsFolder and not slotModel then
                    continue
                end
                
                local cat = tostring(rec.AssetCategory or "")
                local rarity = petRarityMap[cat] or getRarityFromRecord(rec)
                local isAllowed = (not anySelected) or selectedRarities[rarity]
                
                if isAllowed then
                    local rate = 0
                    if AssetEarnings then
                        local itemData = {
                            Category = rec.AssetCategory,
                            Scale = rec.AssetScale or 1,
                            Mutations = rec.Mutations or {}
                        }
                        local sok, srate = pcall(function() return AssetEarnings.RatePerSecond(itemData) end)
                        if sok and srate and srate > 0 then rate = srate end
                    end
                    
                    if not rate or rate == 0 then
                        rate = rec.Generation or ((rec.EarningRate or rec.BaseRate or 10000000) * (rec.AssetScale or rec.Scale or 1))
                    end
                    
                    local eggPos = rec.BoundsCFrame and rec.BoundsCFrame.Position or (rec.BottomCFrame and rec.BottomCFrame.Position)
                    local hitPart = slotModel and (slotModel:FindFirstChild("Hitbox") or slotModel:FindFirstChildWhichIsA("BasePart"))
                    
                    local finalName = cat
                    if cat == "Moth" and rarity == "Cosmic" then
                        finalName = "Sacred Moth"
                    elseif cat == "Peacock" and rarity == "Cosmic" then
                        finalName = "Holy Peacock"
                    end
                    
                    table.insert(found, {
                        name = finalName,
                        rarity = rarity,
                        price = rate,
                        valueStr = formatNumber(rate),
                        pos = eggPos,
                        hitPart = hitPart,
                        slotModel = slotModel,
                        uid = rec.Uid
                    })
                end
            end
        end
    end
    
    -- Ordenar de mayor a menor valor
    table.sort(found, function(a, b) return a.price > b.price end)
    currentEggs = found
    bestEgg = found[1]
end

-- ========================================================
-- 3. CONSTRUCCION DE INTERFAZ GRAFICA
-- ========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NativeEggHubGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local targetGui = game:GetService("CoreGui")
if gethui then pcall(function() targetGui = gethui() end) end
ScreenGui.Parent = targetGui

-- Boton Flotante Circular para Minimizar / Abrir
local ToggleButton = Instance.new("ImageButton")
ToggleButton.Name = "ToggleFloatingBtn"
ToggleButton.Size = UDim2.new(0, 42, 0, 42)
ToggleButton.Position = UDim2.new(0.02, 0, 0.45, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(16, 20, 18)
ToggleButton.BorderSizePixel = 0
ToggleButton.Image = "rbxassetid://10849911500"
ToggleButton.Active = true
ToggleButton.Draggable = true
ToggleButton.Parent = ScreenGui
Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(1, 0)
local ToggleStroke = Instance.new("UIStroke", ToggleButton)
ToggleStroke.Color = Color3.fromRGB(45, 180, 85)
ToggleStroke.Thickness = 1.5

-- Marco Principal
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainCard"
MainFrame.Size = UDim2.new(0, 270, 0, 215)
MainFrame.Position = UDim2.new(0.5, -135, 0.22, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 15, 14)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 10)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Color3.fromRGB(28, 48, 36)
MainStroke.Thickness = 1.2

ToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Barra de Titulo
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(18, 24, 20)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -70, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "BEST EGG SYSTEM (NATIVE)"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 11
TitleLabel.TextColor3 = Color3.fromRGB(235, 240, 235)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Boton X para Minimizar
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -30, 0, 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(28, 35, 30)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.TextColor3 = Color3.fromRGB(180, 190, 185)
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- Tarjeta del Mejor Huevo (BestEggCard)
local BestEggCard = Instance.new("Frame")
BestEggCard.Size = UDim2.new(1, -20, 0, 48)
BestEggCard.Position = UDim2.new(0, 10, 0, 38)
BestEggCard.BackgroundColor3 = Color3.fromRGB(18, 22, 20)
BestEggCard.BorderSizePixel = 0
BestEggCard.Parent = MainFrame
Instance.new("UICorner", BestEggCard).CornerRadius = UDim.new(0, 8)
local BestEggStroke = Instance.new("UIStroke", BestEggCard)
BestEggStroke.Color = Color3.fromRGB(45, 180, 85)
BestEggStroke.Thickness = 1.2

local EggIconImg = Instance.new("ImageLabel")
EggIconImg.Size = UDim2.new(0, 32, 0, 32)
EggIconImg.Position = UDim2.new(0, 8, 0.5, -16)
EggIconImg.BackgroundTransparency = 1
EggIconImg.Image = "rbxassetid://10849911500"
EggIconImg.Parent = BestEggCard

local EggNameLabel = Instance.new("TextLabel")
EggNameLabel.Size = UDim2.new(1, -110, 0, 18)
EggNameLabel.Position = UDim2.new(0, 46, 0, 7)
EggNameLabel.BackgroundTransparency = 1
EggNameLabel.Text = "Buscando huevo..."
EggNameLabel.Font = Enum.Font.GothamBold
EggNameLabel.TextSize = 12
EggNameLabel.TextColor3 = Color3.fromRGB(240, 245, 240)
EggNameLabel.TextXAlignment = Enum.TextXAlignment.Left
EggNameLabel.Parent = BestEggCard

local RarityBadge = Instance.new("TextLabel")
RarityBadge.Size = UDim2.new(0, 52, 0, 14)
RarityBadge.Position = UDim2.new(0, 46, 0, 26)
RarityBadge.BackgroundColor3 = Color3.fromRGB(55, 20, 95)
RarityBadge.Text = "Cosmic"
RarityBadge.Font = Enum.Font.GothamBold
RarityBadge.TextSize = 9
RarityBadge.TextColor3 = Color3.fromRGB(200, 130, 255)
RarityBadge.Parent = BestEggCard
Instance.new("UICorner", RarityBadge).CornerRadius = UDim.new(0, 4)

local ValueLabel = Instance.new("TextLabel")
ValueLabel.Size = UDim2.new(0, 95, 1, 0)
ValueLabel.Position = UDim2.new(1, -100, 0, 0)
ValueLabel.BackgroundTransparency = 1
ValueLabel.Text = "zsh/s"
ValueLabel.Font = Enum.Font.GothamBold
ValueLabel.TextSize = 12
ValueLabel.TextColor3 = Color3.fromRGB(45, 180, 85)
ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
ValueLabel.Parent = BestEggCard

-- Contenedor de Filtros de Rarezas
local FilterContainer = Instance.new("Frame")
FilterContainer.Size = UDim2.new(1, -20, 0, 22)
FilterContainer.Position = UDim2.new(0, 10, 0, 92)
FilterContainer.BackgroundTransparency = 1
FilterContainer.Parent = MainFrame

local filterButtons = {}
local filterOrder = {"Cosmic", "Secret", "Eternal", "Divine", "Mythic"}
local fWidth = 44
local fGap = 5

for i, rName in ipairs(filterOrder) do
    local fBtn = Instance.new("TextButton")
    fBtn.Name = "Filter_" .. rName
    fBtn.Size = UDim2.new(0, fWidth, 1, 0)
    fBtn.Position = UDim2.new(0, (i - 1) * (fWidth + fGap), 0, 0)
    fBtn.Text = string.sub(rName, 1, 3)
    fBtn.Font = Enum.Font.GothamBold
    fBtn.TextSize = 10
    fBtn.BorderSizePixel = 0
    fBtn.Parent = FilterContainer
    Instance.new("UICorner", fBtn).CornerRadius = UDim.new(0, 5)
    
    local fStroke = Instance.new("UIStroke", fBtn)
    fStroke.Thickness = 1
    
    local function updateFilterStyle()
        local active = selectedRarities[rName]
        fBtn.BackgroundColor3 = active and rarityBgActive[rName] or rarityBgInactive[rName]
        fBtn.TextColor3 = active and rarityColors[rName] or Color3.fromRGB(120, 125, 130)
        fStroke.Color = active and rarityColors[rName] or Color3.fromRGB(40, 44, 48)
    end
    
    updateFilterStyle()
    
    fBtn.MouseButton1Click:Connect(function()
        selectedRarities[rName] = not selectedRarities[rName]
        updateFilterStyle()
        scanEggs()
    end)
    
    filterButtons[rName] = fBtn
end

-- Boton de Lista Completa (Expandir / Contraer)
local ListToggleBtn = Instance.new("TextButton")
ListToggleBtn.Name = "ListToggleBtn"
ListToggleBtn.Size = UDim2.new(1, -20, 0, 22)
ListToggleBtn.Position = UDim2.new(0, 10, 0, 120)
ListToggleBtn.BackgroundColor3 = Color3.fromRGB(18, 24, 20)
ListToggleBtn.BorderSizePixel = 0
ListToggleBtn.Text = "LISTA COMPLETA (▼ MOSTRAR)"
ListToggleBtn.Font = Enum.Font.GothamBold
ListToggleBtn.TextSize = 10
ListToggleBtn.TextColor3 = Color3.fromRGB(140, 160, 150)
ListToggleBtn.Parent = MainFrame
Instance.new("UICorner", ListToggleBtn).CornerRadius = UDim.new(0, 5)
local ListToggleStroke = Instance.new("UIStroke", ListToggleBtn)
ListToggleStroke.Color = Color3.fromRGB(30, 50, 38)
ListToggleStroke.Thickness = 1

-- Contenedor de la Lista Expandible
local ListScroll = Instance.new("ScrollingFrame")
ListScroll.Name = "ListScroll"
ListScroll.Size = UDim2.new(1, -20, 0, 130)
ListScroll.Position = UDim2.new(0, 10, 0, 148)
ListScroll.BackgroundColor3 = Color3.fromRGB(14, 18, 16)
ListScroll.BorderSizePixel = 0
ListScroll.ScrollBarThickness = 3
ListScroll.ScrollBarImageColor3 = Color3.fromRGB(45, 180, 85)
ListScroll.Visible = false
ListScroll.Parent = MainFrame
Instance.new("UICorner", ListScroll).CornerRadius = UDim.new(0, 6)

local ListLayout = Instance.new("UIListLayout", ListScroll)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 4)

-- Contenedor Inferior de Botones de Accion
local BottomActions = Instance.new("Frame")
BottomActions.Name = "BottomActions"
BottomActions.Size = UDim2.new(1, -20, 0, 55)
BottomActions.Position = UDim2.new(0, 10, 0, 150)
BottomActions.BackgroundTransparency = 1
BottomActions.Parent = MainFrame

-- Boton Principal: TELEGUIADO
local TeleguiadoBtn = Instance.new("TextButton")
TeleguiadoBtn.Name = "TeleguiadoBtn"
TeleguiadoBtn.Size = UDim2.new(1, 0, 0, 30)
TeleguiadoBtn.Position = UDim2.new(0, 0, 0, 0)
TeleguiadoBtn.BackgroundColor3 = Color3.fromRGB(24, 60, 35)
TeleguiadoBtn.BorderSizePixel = 0
TeleguiadoBtn.Text = "ACTIVAR TELEGUIADO (ROBO)"
TeleguiadoBtn.Font = Enum.Font.GothamBold
TeleguiadoBtn.TextSize = 11
TeleguiadoBtn.TextColor3 = Color3.fromRGB(220, 255, 230)
TeleguiadoBtn.Parent = BottomActions
Instance.new("UICorner", TeleguiadoBtn).CornerRadius = UDim.new(0, 6)
local TeleStroke = Instance.new("UIStroke", TeleguiadoBtn)
TeleStroke.Color = Color3.fromRGB(45, 180, 85)
TeleStroke.Thickness = 1.2

-- Boton Secundario: MODO LENTO / SEGURO
local SlowModeBtn = Instance.new("TextButton")
SlowModeBtn.Name = "SlowModeBtn"
SlowModeBtn.Size = UDim2.new(1, 0, 0, 18)
SlowModeBtn.Position = UDim2.new(0, 0, 0, 34)
SlowModeBtn.BackgroundColor3 = Color3.fromRGB(18, 22, 20)
SlowModeBtn.BorderSizePixel = 0
SlowModeBtn.Text = "VELOCIDAD: RAPIDA (450 studs/s)"
SlowModeBtn.Font = Enum.Font.Gotham
SlowModeBtn.TextSize = 9
SlowModeBtn.TextColor3 = Color3.fromRGB(140, 155, 145)
SlowModeBtn.Parent = BottomActions
Instance.new("UICorner", SlowModeBtn).CornerRadius = UDim.new(0, 4)

SlowModeBtn.MouseButton1Click:Connect(function()
    slowModeActive = not slowModeActive
    if slowModeActive then
        SlowModeBtn.Text = "VELOCIDAD: SEGURA (220 studs/s)"
        SlowModeBtn.TextColor3 = Color3.fromRGB(255, 200, 80)
    else
        SlowModeBtn.Text = "VELOCIDAD: RAPIDA (450 studs/s)"
        SlowModeBtn.TextColor3 = Color3.fromRGB(140, 155, 145)
    end
end)

-- Logica de Expansion / Contraccion de la Lista
ListToggleBtn.MouseButton1Click:Connect(function()
    expandedList = not expandedList
    if expandedList then
        ListToggleBtn.Text = "LISTA COMPLETA (▲ OCULTAR)"
        ListScroll.Visible = true
        MainFrame.Size = UDim2.new(0, 270, 0, 355)
        BottomActions.Position = UDim2.new(0, 10, 0, 288)
    else
        ListToggleBtn.Text = "LISTA COMPLETA (▼ MOSTRAR)"
        ListScroll.Visible = false
        MainFrame.Size = UDim2.new(0, 270, 0, 215)
        BottomActions.Position = UDim2.new(0, 10, 0, 150)
    end
end)

-- Actualizar Interfaz Grafica
local function updateUI()
    if not bestEgg then
        EggNameLabel.Text = "Sin huevos disponibles"
        RarityBadge.Visible = false
        ValueLabel.Text = "zsh/s"
    else
        EggNameLabel.Text = bestEgg.name
        RarityBadge.Text = bestEgg.rarity
        RarityBadge.Visible = true
        RarityBadge.TextColor3 = rarityColors[bestEgg.rarity] or Color3.fromRGB(200, 200, 200)
        RarityBadge.BackgroundColor3 = rarityBgActive[bestEgg.rarity] or Color3.fromRGB(40, 40, 40)
        ValueLabel.Text = bestEgg.valueStr
    end
    
    -- Actualizar filas de la lista expandible
    if expandedList then
        for _, child in pairs(ListScroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        
        for rank, egg in ipairs(currentEggs) do
            if rank > 15 then break end
            
            local row = Instance.new("Frame")
            row.Name = "Row_" .. rank
            row.Size = UDim2.new(1, -6, 0, 24)
            row.BackgroundColor3 = (rank == 1) and Color3.fromRGB(22, 34, 26) or Color3.fromRGB(16, 20, 18)
            row.BorderSizePixel = 0
            row.Parent = ListScroll
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
            
            local rRank = Instance.new("TextLabel", row)
            rRank.Size = UDim2.new(0, 24, 1, 0)
            rRank.BackgroundTransparency = 1
            rRank.Text = "#" .. rank
            rRank.Font = Enum.Font.GothamBold
            rRank.TextSize = 10
            rRank.TextColor3 = (rank == 1) and Color3.fromRGB(45, 180, 85) or Color3.fromRGB(120, 130, 125)
            
            local rName = Instance.new("TextLabel", row)
            rName.Size = UDim2.new(1, -115, 1, 0)
            rName.Position = UDim2.new(0, 26, 0, 0)
            rName.BackgroundTransparency = 1
            rName.Text = egg.name
            rName.Font = Enum.Font.Gotham
            rName.TextSize = 10
            rName.TextColor3 = Color3.fromRGB(220, 225, 220)
            rName.TextXAlignment = Enum.TextXAlignment.Left
            
            local rVal = Instance.new("TextLabel", row)
            rVal.Size = UDim2.new(0, 85, 1, 0)
            rVal.Position = UDim2.new(1, -88, 0, 0)
            rVal.BackgroundTransparency = 1
            rVal.Text = egg.valueStr
            rVal.Font = Enum.Font.GothamBold
            rVal.TextSize = 10
            rVal.TextColor3 = rarityColors[egg.rarity] or Color3.fromRGB(45, 180, 85)
            rVal.TextXAlignment = Enum.TextXAlignment.Right
        end
        ListScroll.CanvasSize = UDim2.new(0, 0, 0, #currentEggs * 28)
    end
end

-- ========================================================
-- 4. MOTOR DE TELEGUIADO AEREO SEGURO (ANTI-GUARDIAS)
-- ========================================================
local function enableNoclip(char)
    if noclipConn then noclipConn:Disconnect() end
    noclipConn = RunService.Stepped:Connect(function()
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function disableNoclip()
    if noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
    end
end

local function tweenToTarget(hrp, targetPos, speed)
    if not hrp or not hrp.Parent then return false end
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    
    local dist = (hrp.Position - targetPos).Magnitude
    local tTime = math.clamp(dist / speed, 0.05, 15)
    
    local tweenInfo = TweenInfo.new(tTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    currentTween = TweenService:Create(hrp, tweenInfo, { CFrame = CFrame.new(targetPos) })
    currentTween:Play()
    
    local completed = false
    local conn
    conn = currentTween.Completed:Connect(function()
        completed = true
        conn:Disconnect()
    end)
    
    while not completed and teleguiadoActive do
        hrp.Velocity = Vector3.new(0, 0, 0)
        task.wait(0.03)
    end
    
    return completed and teleguiadoActive
end

local function startTeleguiado()
    if teleguiadoActive or isFlying then return end
    teleguiadoActive = true
    isFlying = true
    
    TeleguiadoBtn.Text = "DETENER TELEGUIADO"
    TeleguiadoBtn.BackgroundColor3 = Color3.fromRGB(120, 25, 30)
    TeleStroke.Color = Color3.fromRGB(240, 60, 60)
    
    task.spawn(function()
        while teleguiadoActive do
            scanEggs()
            if not bestEgg or not bestEgg.pos then
                task.wait(0.5)
                continue
            end
            
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then
                task.wait(0.5)
                continue
            end
            
            enableNoclip(char)
            hum:UnequipTools()
            
            -- Guardar posicion de la base del jugador para retornar el huevo
            local homeBasePos = hrp.Position
            local eggPos = bestEgg.pos
            
            -- ALTURA DE SEGURIDAD ESTRICTA: Y = 92.9 (Inalcanzable para los guardias)
            local flyAltitude = 92.9
            
            -- PASO 1: Ascenso vertical instantaneo fuera del alcance del suelo
            local skyAboveMe = Vector3.new(hrp.Position.X, flyAltitude, hrp.Position.Z)
            local ok = tweenToTarget(hrp, skyAboveMe, 110)
            if not ok then break end
            
            -- PASO 2: Crucero aereo horizontal a alta velocidad (450 studs/s) directo sobre el nido
            local skyOverEgg = Vector3.new(eggPos.X, flyAltitude, eggPos.Z)
            local hSpeed = slowModeActive and 220 or 450
            ok = tweenToTarget(hrp, skyOverEgg, hSpeed)
            if not ok then break end
            
            -- PASO 3: Descenso vertical tipo ascensor directo sobre el nido
            local hoverEgg = Vector3.new(eggPos.X, eggPos.Y + 0.4, eggPos.Z)
            ok = tweenToTarget(hrp, hoverEgg, 85)
            if not ok then break end
            
            -- PASO 4: ROBO NATIVO EN EL NIDO
            local robStart = tick()
            while (tick() - robStart) < 2.5 and teleguiadoActive do
                if hum then hum:UnequipTools() end
                hrp.CFrame = CFrame.new(eggPos.X, eggPos.Y + 0.3, eggPos.Z)
                hrp.Velocity = Vector3.new(0, 0, 0)
                
                -- 1. Localizar el prompt real CarryAreaEgg en Workspace.SmartPromptPart
                local targetPrompt = nil
                for _, obj in pairs(workspace:GetChildren()) do
                    if obj.Name == "SmartPromptPart" and (obj.Position - eggPos).Magnitude < 9 then
                        local p = obj:FindFirstChild("CarryAreaEgg")
                        if p then targetPrompt = p break end
                    end
                end
                
                -- 2. Disparar prompt nativo del juego
                if targetPrompt then
                    targetPrompt.Enabled = true
                    targetPrompt.RequiresLineOfSight = false
                    targetPrompt.MaxActivationDistance = 40
                    
                    -- Disparar la conexion del cliente nativo
                    local conns = getconnections and getconnections(targetPrompt.Triggered) or {}
                    for _, c in pairs(conns) do
                        pcall(function() c.Function(LocalPlayer) end)
                    end
                    
                    if fireproximityprompt then
                        pcall(function() fireproximityprompt(targetPrompt, 0) end)
                    end
                end
                
                -- 3. Respaldo directo: EggState.CarryFieldEgg(uid)
                if EggState and EggState.CarryFieldEgg and bestEgg.uid then
                    pcall(function() EggState.CarryFieldEgg(bestEgg.uid) end)
                end
                
                -- 4. Respaldo fisico: TouchInterest
                if bestEgg.hitPart and firetouchinterest then
                    pcall(function()
                        firetouchinterest(hrp, bestEgg.hitPart, 0)
                        task.wait(0.04)
                        firetouchinterest(hrp, bestEgg.hitPart, 1)
                    end)
                end
                
                -- Si ya tenemos el huevo en brazos, escapar de inmediato!
                local hasEgg = false
                for _, c in pairs(char:GetChildren()) do
                    if c:IsA("Tool") or string.find(string.lower(c.Name), "egg") or string.find(string.lower(c.Name), "carry") then
                        hasEgg = true
                        break
                    end
                end
                
                local slotsFolder = workspace:FindFirstChild("AreaEggSlotsClient")
                local eggStillThere = slotsFolder and bestEgg.uid and slotsFolder:FindFirstChild(bestEgg.uid) ~= nil
                
                if hasEgg or not eggStillThere then
                    break
                end
                task.wait(0.08)
            end
            
            -- PASO 5: Ascenso vertical instantaneo de escape (Y = 92.9)
            ok = tweenToTarget(hrp, skyOverEgg, 130)
            if not ok then break end
            
            -- PASO 6: Retorno seguro por los cielos hacia tu base
            local skyOverHome = Vector3.new(homeBasePos.X, flyAltitude, homeBasePos.Z)
            ok = tweenToTarget(hrp, skyOverHome, hSpeed)
            if not ok then break end
            
            -- PASO 7: Descenso suave en tu base y plantar huevo
            ok = tweenToTarget(hrp, homeBasePos, 90)
            task.wait(0.3)
            
            -- Plantar huevo nativamente si EggState lo soporta
            if EggState and EggState.PlantEgg then
                pcall(function() EggState.PlantEgg() end)
            end
            
            task.wait(0.5)
        end
        
        disableNoclip()
        isFlying = false
        teleguiadoActive = false
        TeleguiadoBtn.Text = "ACTIVAR TELEGUIADO (ROBO)"
        TeleguiadoBtn.BackgroundColor3 = Color3.fromRGB(24, 60, 35)
        TeleStroke.Color = Color3.fromRGB(45, 180, 85)
    end)
end

stopTeleguiado = function()
    teleguiadoActive = false
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    disableNoclip()
    isFlying = false
    TeleguiadoBtn.Text = "ACTIVAR TELEGUIADO (ROBO)"
    TeleguiadoBtn.BackgroundColor3 = Color3.fromRGB(24, 60, 35)
    TeleStroke.Color = Color3.fromRGB(45, 180, 85)
end

TeleguiadoBtn.MouseButton1Click:Connect(function()
    if teleguiadoActive then
        stopTeleguiado()
    else
        startTeleguiado()
    end
end)

-- ========================================================
-- 5. BUCLE PRINCIPAL Y EVENTOS NATIVOS DEL JUEGO
-- ========================================================
-- Escaneo inicial
scanEggs()
updateUI()

-- Escuchar senales nativas de actualizacion de huevos
if EggState then
    if EggState.FieldShifted and typeof(EggState.FieldShifted) == "table" and EggState.FieldShifted.Connect then
        pcall(function()
            EggState.FieldShifted:Connect(function()
                scanEggs()
                updateUI()
            end)
        end)
    end
    
    if EggState.FieldGone and typeof(EggState.FieldGone) == "table" and EggState.FieldGone.Connect then
        pcall(function()
            EggState.FieldGone:Connect(function()
                scanEggs()
                updateUI()
            end)
        end)
    end
end

-- Bucle de refresco periodico (0.5s)
task.spawn(function()
    while ScreenGui and ScreenGui.Parent do
        scanEggs()
        updateUI()
        task.wait(0.5)
    end
end)

print("[NATIVE HUB] new.lua cargado exitosamente!")
