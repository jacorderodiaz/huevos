--[[
    ========================================================
    STEAL AN EGG - LENNON HUB BEST EGG SYSTEM (V14.0 DEFINITIVA)
    - SISTEMA DE MINIMIZAR:
        * Botón "X" en la esquina superior derecha para minimizar
        * Botón circular flotante draggable con logo para reabrir en cualquier momento
    - FILTRO INTELIGENTE Y FLEXIBLE:
        * Puedes prender todos, solo uno, o los que tú quieras
        * Si apagas todos, automáticamente muestra TODOS los mejores de la pista
    - DETECCIÓN OFICIAL DEL SERVIDOR:
        * Lee directamente EggState.ReadFieldEggs() de la memoria del juego
        * Nombres y precios oficiales con EggRecords.SellPrice()
        * Posición física directa con BoundsCFrame (cero fallos de streaming)
    - UI PERFECTA:
        * Cero traslapes: la lista empuja Teleguiado limpiamente hacia abajo
        * Muestra #Rank, Nombre, Rareza coloreada y Precio
    - TELEGUIADO AÉREO ANTI-GUARDIAS CON REGRESO A BASE
    ========================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Eliminar versión previa
pcall(function()
    if game:GetService("CoreGui"):FindFirstChild("LennonHubBestEgg") then
        game:GetService("CoreGui").LennonHubBestEgg:Destroy()
    end
end)

-- Módulos del Juego (100% Nativos)
local EggState = nil
local EggRecords = nil
local AssetEarnings = nil
local petRarityMap = {}

pcall(function()
    EggState = require(ReplicatedStorage.Client.EggState)
    EggRecords = require(ReplicatedStorage.Shared.Util.EggRecords)
    AssetEarnings = require(ReplicatedStorage.Shared.Util.AssetEarnings)
    
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
local loopActive = false
local slowModeActive = false
local expandedList = false
local isFlying = false
local currentTween = nil
local noclipConn = nil
local stopTeleguiado = nil

-- Filtros de Rarezas (Por defecto solo Cosmic activo, idéntico a Lennon Hub)
local selectedRarities = {
    ["Cosmic"] = true,
    ["Secret"] = false,
    ["Eternal"] = false,
    ["Divine"] = false
}

local rarityColors = {
    ["Cosmic"] = Color3.fromRGB(145, 60, 240),   -- Púrpura brillante
    ["Secret"] = Color3.fromRGB(160, 160, 170),  -- Gris plata
    ["Eternal"] = Color3.fromRGB(230, 30, 140),  -- Magenta brillante
    ["Divine"] = Color3.fromRGB(255, 215, 0),    -- Dorado oro
    ["Mythic"] = Color3.fromRGB(240, 50, 70)     -- Rojo mítico
}

local rarityBgActive = {
    ["Cosmic"] = Color3.fromRGB(55, 20, 95),
    ["Secret"] = Color3.fromRGB(50, 52, 58),
    ["Eternal"] = Color3.fromRGB(95, 20, 65),
    ["Divine"] = Color3.fromRGB(115, 95, 15)
}

local rarityBgInactive = {
    ["Cosmic"] = Color3.fromRGB(20, 15, 28),
    ["Secret"] = Color3.fromRGB(20, 22, 24),
    ["Eternal"] = Color3.fromRGB(26, 14, 22),
    ["Divine"] = Color3.fromRGB(28, 24, 12)
}

-- Mapeo de Área oficial a Rareza
local function getRarityFromRecord(rec)
    local area = string.lower(tostring(rec.AreaId or ""))
    if string.find(area, "cosmic") then
        return "Cosmic"
    elseif string.find(area, "light") or string.find(area, "dark") or string.find(area, "titan") or string.find(area, "divine") then
        return "Divine"
    elseif string.find(area, "cherry") or string.find(area, "blossom") or string.find(area, "eternal") then
        return "Eternal"
    elseif string.find(area, "volcano") or string.find(area, "snow") or string.find(area, "prehistoric") or string.find(area, "desert") then
        return "Secret"
    end
    return "Cosmic"
end

local currentEggs = {}
local bestEgg = nil
local myBasePosition = nil

-- Base del Jugador
local function findMyBase()
    local myPlot = workspace:FindFirstChild(LocalPlayer.Name) or workspace:FindFirstChild(LocalPlayer.DisplayName)
    if myPlot and myPlot:IsA("Model") then
        return myPlot:GetPivot().Position + Vector3.new(0, 4, 0)
    end
    local plots = workspace:FindFirstChild("Plots") or workspace:FindFirstChild("Bases") or workspace:FindFirstChild("PlotModels")
    if plots then
        for _, p in pairs(plots:GetChildren()) do
            local ownerVal = p:FindFirstChild("Owner") or p:FindFirstChild("Player") or p:GetAttribute("Owner")
            if (ownerVal and (ownerVal == LocalPlayer.Name or (typeof(ownerVal) == "Instance" and ownerVal.Value == LocalPlayer.Name)))
                or string.find(string.lower(p.Name), string.lower(LocalPlayer.Name)) then
                return (p:IsA("Model") and p:GetPivot().Position or p.Position) + Vector3.new(0, 4, 0)
            end
        end
    end
    if myBasePosition then return myBasePosition end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        myBasePosition = LocalPlayer.Character.HumanoidRootPart.Position
    end
    return myBasePosition
end

-- Formateador Numérico (Lennon Hub: 56.9M, 24.76M, etc.)
local function formatNumber(num)
    if not num or num == 0 then return "0" end
    if num >= 1000000000 then
        return string.format("%.2fB", num / 1000000000)
    elseif num >= 1000000 then
        local val = num / 1000000
        if math.floor(val * 10) == val * 10 then
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
-- 1. DETECTOR VIVO DIRECTO AL MOTOR DEL JUEGO / LENNON
-- ========================================================
local function getLennonEngineState()
    local lp = game:GetService("Players").LocalPlayer
    local pg = lp:FindFirstChild("PlayerGui")
    if pg then
        for _, gui in pairs(pg:GetChildren()) do
            if string.find(gui.Name, "LH_") or string.find(string.lower(gui.Name), "lennon") then
                local row1 = gui:FindFirstChild("Row1", true)
                if row1 then
                    local conns = getconnections(row1.MouseButton1Click)
                    if conns and conns[1] and conns[1].Function then
                        local ups = debug.getupvalues(conns[1].Function)
                        if ups and ups[32] then
                            return ups[32][2], ups[32][3] -- state, funcs
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end

local function scanEggs()
    local found = {}
    
    -- Comprobar qué rarezas están seleccionadas
    local anySelected = false
    for _, active in pairs(selectedRarities) do
        if active then anySelected = true; break end
    end
    
    -- 1. MOTOR NATIVO PRINCIPAL (100% Autónomo del juego, sin depender de nadie)
    if EggState then
        local ok, fieldData = pcall(function() return EggState.ReadFieldEggs() end)
        if ok and fieldData and fieldData.Records then
            local slotsFolder = workspace:FindFirstChild("AreaEggSlotsClient")
            for _, rec in pairs(fieldData.Records) do
                -- 1. Validar que el huevo esté realmente en el nido y no haya sido robado
                if rec.State and rec.State ~= "Slot" then
                    continue
                end
                
                local slotModel = slotsFolder and rec.Uid and slotsFolder:FindFirstChild(rec.Uid)
                if slotsFolder and not slotModel then
                    continue -- Si el modelo ya no existe en el nido, ya fue robado!
                end
                
                local prompt = slotModel and slotModel:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt and not prompt.Enabled then
                    continue -- Si el prompt está apagado, el huevo no está disponible
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
                    if cat == "Moth" and (rarity == "Cosmic" or string.find(string.lower(tostring(rec.AreaId or "")), "cosmic")) then
                        finalName = "Sacred Moth"
                    elseif cat == "Peacock" and (rarity == "Cosmic" or string.find(string.lower(tostring(rec.AreaId or "")), "cosmic")) then
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
                        prompt = prompt,
                        uid = rec.Uid
                    })
                end
            end
        end
    end
    
    -- 2. Fallback secundario si la pista estuviera vacía en ese milisegundo
    if #found == 0 then
        local state = getLennonEngineState()
        if state and state.filteredEggs then
            for _, egg in ipairs(state.filteredEggs) do
                local gen = egg.Generation or 0
                local str = formatNumber(gen)
                local pos = egg.Position or (egg.BottomCFrame and egg.BottomCFrame.Position) or Vector3.new(0,0,0)
                table.insert(found, {
                    name = egg.Name or "Egg",
                    rarity = egg.RarityName or "Cosmic",
                    price = gen,
                    valueStr = str,
                    pos = pos,
                    hitPart = nil,
                    uid = egg.Uid
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
-- 2. CONSTRUCCIÓN DE INTERFAZ GRÁFICA CON MINIMIZAR
-- ========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LennonHubBestEgg"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local targetGui = game:GetService("CoreGui")
if gethui then pcall(function() targetGui = gethui() end) end
ScreenGui.Parent = targetGui

-- Botón Flotante Circular para Abrir / Minimizar
local ToggleButton = Instance.new("ImageButton")
ToggleButton.Name = "LennonHubToggle"
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

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(28, 48, 36)
MainStroke.Thickness = 1.2
MainStroke.Parent = MainFrame

-- Abrir / Cerrar al tocar botón flotante
ToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Encabezado
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0, 95, 0, 18)
TitleLabel.Position = UDim2.new(0, 14, 0, 8)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "LENNON HUB"
TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = MainFrame

-- Insignia Verde V14.0
local VersionBadge = Instance.new("TextLabel")
VersionBadge.Size = UDim2.new(0, 42, 0, 14)
VersionBadge.Position = UDim2.new(0, 110, 0, 10)
VersionBadge.BackgroundColor3 = Color3.fromRGB(28, 55, 38)
VersionBadge.BorderSizePixel = 0
VersionBadge.Text = "V14.0"
VersionBadge.TextColor3 = Color3.fromRGB(80, 240, 120)
VersionBadge.Font = Enum.Font.GothamBold
VersionBadge.TextSize = 8
VersionBadge.Parent = MainFrame
Instance.new("UICorner", VersionBadge).CornerRadius = UDim.new(0, 4)

local SubTitleLabel = Instance.new("TextLabel")
SubTitleLabel.Size = UDim2.new(1, -60, 0, 12)
SubTitleLabel.Position = UDim2.new(0, 14, 0, 26)
SubTitleLabel.BackgroundTransparency = 1
SubTitleLabel.Text = "BEST EGG SYSTEM • V14.0"
SubTitleLabel.TextColor3 = Color3.fromRGB(140, 150, 140)
SubTitleLabel.Font = Enum.Font.Gotham
SubTitleLabel.TextSize = 9
SubTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
SubTitleLabel.Parent = MainFrame

-- Botón "X" para Minimizar
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 22, 0, 22)
CloseBtn.Position = UDim2.new(1, -30, 0, 10)
CloseBtn.BackgroundColor3 = Color3.fromRGB(25, 30, 28)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(180, 190, 185)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11
CloseBtn.Parent = MainFrame
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

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
ArrowBtn.Size = UDim2.new(0, 20, 0, 20)
ArrowBtn.Position = UDim2.new(1, -26, 0, 6)
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
EggValueLabel.Size = UDim2.new(0, 75, 0, 20)
EggValueLabel.Position = UDim2.new(1, -82, 0, 22)
EggValueLabel.BackgroundTransparency = 1
EggValueLabel.Text = "--"
EggValueLabel.TextColor3 = Color3.fromRGB(80, 240, 120)
EggValueLabel.Font = Enum.Font.GothamBold
EggValueLabel.TextSize = 11
EggValueLabel.TextXAlignment = Enum.TextXAlignment.Right
EggValueLabel.Parent = BestEggCard

-- Lista Desplegable (Debajo de BestEggCard)
local ListScroll = Instance.new("ScrollingFrame")
ListScroll.Size = UDim2.new(0.92, 0, 0, 110)
ListScroll.Position = UDim2.new(0.04, 0, 0, 102)
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
BottomContainer.Size = UDim2.new(1, 0, 0, 110)
BottomContainer.Position = UDim2.new(0, 0, 0, 105)
BottomContainer.BackgroundTransparency = 1
BottomContainer.Parent = MainFrame

-- Función expandir/contraer limpia (CERO TRASLAPE)
ArrowBtn.MouseButton1Click:Connect(function()
    expandedList = not expandedList
    ListScroll.Visible = expandedList
    ArrowBtn.Text = expandedList and "^" or "v"
    if expandedList then
        MainFrame.Size = UDim2.new(0, 270, 0, 335)
        BottomContainer.Position = UDim2.new(0, 0, 0, 220)
    else
        MainFrame.Size = UDim2.new(0, 270, 0, 215)
        BottomContainer.Position = UDim2.new(0, 0, 0, 105)
    end
end)

-- Sección "TELEGUIADO"
local TeleguiadoLabel = Instance.new("TextLabel")
TeleguiadoLabel.Size = UDim2.new(0, 90, 0, 16)
TeleguiadoLabel.Position = UDim2.new(0.04, 0, 0, 4)
TeleguiadoLabel.BackgroundTransparency = 1
TeleguiadoLabel.Text = "TELEGUIADO"
TeleguiadoLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
TeleguiadoLabel.Font = Enum.Font.GothamBold
TeleguiadoLabel.TextSize = 11
TeleguiadoLabel.TextXAlignment = Enum.TextXAlignment.Left
TeleguiadoLabel.Parent = BottomContainer

local OneShotLabel = Instance.new("TextLabel")
OneShotLabel.Size = UDim2.new(0, 65, 0, 12)
OneShotLabel.Position = UDim2.new(0.04, 0, 0, 20)
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
LoopBox.Position = UDim2.new(0.52, 0, 0, 10)
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
LoopText.Position = UDim2.new(0.52, 22, 0, 10)
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
SwitchBg.Position = UDim2.new(1, -50, 0, 9)
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
        if stopTeleguiado then stopTeleguiado() end
    end
end)

-- Sección "RARITY FILTER"
local FilterHeader = Instance.new("TextLabel")
FilterHeader.Size = UDim2.new(1, -20, 0, 12)
FilterHeader.Position = UDim2.new(0.04, 0, 0, 42)
FilterHeader.BackgroundTransparency = 1
FilterHeader.Text = "RARITY FILTER • TP + TELEGUIADO"
FilterHeader.TextColor3 = Color3.fromRGB(90, 180, 120)
FilterHeader.Font = Enum.Font.GothamBold
FilterHeader.TextSize = 8
FilterHeader.TextXAlignment = Enum.TextXAlignment.Left
FilterHeader.Parent = BottomContainer

-- Pills de Rarezas con Selección Libre y Flexible
local pillButtons = {}

local function updatePillStyles()
    for rName, pData in pairs(pillButtons) do
        local isActive = selectedRarities[rName]
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
        -- Conmutar estado de esta rareza
        selectedRarities[name] = not selectedRarities[name]
        updatePillStyles()
        scanEggs()
    end)
end

createRarityPill("Cosmic", 0.04, 58)
createRarityPill("Secret", 0.52, 58)
createRarityPill("Eternal", 0.04, 80)
createRarityPill("Divine", 0.52, 80)
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
        task.wait(0.2)
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
                    row.Size = UDim2.new(1, -4, 0, 28)
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
                    nameL.Size = UDim2.new(0, 110, 0, 14)
                    nameL.Position = UDim2.new(0, 24, 0, 2)
                    nameL.BackgroundTransparency = 1
                    nameL.Text = item.name
                    nameL.TextColor3 = Color3.fromRGB(240, 240, 240)
                    nameL.Font = Enum.Font.GothamBold
                    nameL.TextSize = 10
                    nameL.TextXAlignment = Enum.TextXAlignment.Left
                    nameL.Parent = row
                    
                    local rarL = Instance.new("TextLabel")
                    rarL.Size = UDim2.new(0, 110, 0, 11)
                    rarL.Position = UDim2.new(0, 24, 0, 15)
                    rarL.BackgroundTransparency = 1
                    rarL.Text = item.rarity
                    rarL.TextColor3 = rarityColors[item.rarity] or Color3.fromRGB(140, 140, 140)
                    rarL.Font = Enum.Font.Gotham
                    rarL.TextSize = 8
                    rarL.TextXAlignment = Enum.TextXAlignment.Left
                    rarL.Parent = row
                    
                    local valL = Instance.new("TextLabel")
                    valL.Size = UDim2.new(0, 75, 1, 0)
                    valL.Position = UDim2.new(1, -80, 0, 0)
                    valL.BackgroundTransparency = 1
                    valL.Text = item.valueStr
                    valL.TextColor3 = Color3.fromRGB(80, 240, 120)
                    valL.Font = Enum.Font.GothamBold
                    valL.TextSize = 10
                    valL.TextXAlignment = Enum.TextXAlignment.Right
                    valL.Parent = row
                end
            end
        end
    end
end)

-- ========================================================
-- 4. TELEGUIADO AÉREO ANTI-GUARDIAS (ESTILO LENNON V14)
-- ========================================================
local function applyAntiRagdoll(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        if hum:GetState() == Enum.HumanoidStateType.Ragdoll or hum:GetState() == Enum.HumanoidStateType.FallingDown then
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end
    for _, sc in pairs(char:GetDescendants()) do
        if sc:IsA("Script") or sc:IsA("LocalScript") then
            local n = string.lower(sc.Name)
            if string.find(n, "ragdoll") or string.find(n, "fall") then
                sc.Disabled = true
            end
        end
    end
end

local function setBodyVelocity(hrp, active)
    if not hrp or not hrp.Parent then return end
    local bv = hrp:FindFirstChild("TeleguiadoBV")
    if active then
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "TeleguiadoBV"
            bv.Parent = hrp
        end
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    else
        if bv then
            bv:Destroy()
        end
    end
end

local function setNoclip(active)
    if noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
    end
    if active then
        noclipConn = RunService.Stepped:Connect(function()
            if LocalPlayer.Character then
                for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

stopTeleguiado = function()
    teleguiadoActive = false
    isFlying = false
    if currentTween then
        pcall(function() currentTween:Cancel() end)
        currentTween = nil
    end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        setBodyVelocity(hrp, false)
        hrp.Velocity = Vector3.new(0, 0, 0)
        hrp.RotVelocity = Vector3.new(0, 0, 0)
    end
    setNoclip(false)
end

local function tweenToTarget(hrp, targetPos, speed)
    if not hrp or not hrp.Parent or not teleguiadoActive then return false end
    speed = speed or (slowModeActive and 65 or 100)
    local dist = (hrp.Position - targetPos).Magnitude
    local duration = math.max(dist / speed, 0.05)
    
    local targetCFrame = CFrame.new(targetPos)
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tw = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
    currentTween = tw
    tw:Play()
    
    local completed = false
    local conn
    conn = tw.Completed:Connect(function()
        completed = true
    end)
    
    while not completed and teleguiadoActive do
        task.wait(0.03)
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hrp.Parent or not hum or hum.Health <= 0 then
            tw:Cancel()
            if conn then conn:Disconnect() end
            return false
        end
    end
    if conn then conn:Disconnect() end
    
    if not teleguiadoActive then
        tw:Cancel()
        return false
    end
    return true
end

local function liftCharacterOutOfGround(hrp, flyAltitude)
    flyAltitude = flyAltitude or 225
    local skyStart = Vector3.new(hrp.Position.X, flyAltitude, hrp.Position.Z)
    return tweenToTarget(hrp, skyStart, 85)
end

local function startNewTeleguiado()
    if isFlying or not teleguiadoActive then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end
    if not bestEgg or not bestEgg.pos then return end
    
    isFlying = true
    
    -- Desequipar herramientas/bate para no trabarse en la Safe Zone
    if hum then
        hum:UnequipTools()
    end
    
    applyAntiRagdoll(char)
    setBodyVelocity(hrp, true)
    setNoclip(true)
    
    local eggPos = bestEgg.pos
    local home = findMyBase()
    local groundY = hrp.Position.Y
    local flyAltitude = math.max(eggPos.Y + 22.3, 92.9)
    
    -- PASO 1: Salir de la base hacia la pista central ("en medio") a ras de suelo
    if math.abs(hrp.Position.Z - (-358)) > 15 then
        local middlePos = Vector3.new(hrp.Position.X, groundY, -358)
        local ok = tweenToTarget(hrp, middlePos, slowModeActive and 120 or 250)
        if not ok then stopTeleguiado(); return end
        task.wait(0.03)
    end
    
    -- PASO 2: Elevarse a la altura segura de vuelo Y = 92.9 (fuera del alcance de guardias y bates)
    local skyStart = Vector3.new(hrp.Position.X, flyAltitude, hrp.Position.Z)
    local ok = tweenToTarget(hrp, skyStart, 120)
    if not ok then stopTeleguiado(); return end
    
    -- PASO 3: Vuelo seguro por el aire hasta quedar justo encima del huevo (sin chocar con nada)
    local skyOverEgg = Vector3.new(eggPos.X, flyAltitude, eggPos.Z)
    ok = tweenToTarget(hrp, skyOverEgg, slowModeActive and 220 or 450)
    if not ok then stopTeleguiado(); return end
    
    -- PASO 4: Descenso vertical tipo ascensor directo sobre el nido
    local hoverEgg = Vector3.new(eggPos.X, eggPos.Y + 1.2, eggPos.Z)
    ok = tweenToTarget(hrp, hoverEgg, 85)
    if not ok then stopTeleguiado(); return end
    
    -- PASO 5: Robo en el nido (activación directa de proximity prompt y touch)
    local robStart = tick()
    while (tick() - robStart) < 2.5 and teleguiadoActive do
        if hum then hum:UnequipTools() end
        
        hrp.CFrame = CFrame.new(eggPos.X, eggPos.Y + 1.2, eggPos.Z)
        hrp.Velocity = Vector3.new(0, 0, 0)
        
        local prompt = bestEgg.prompt or (bestEgg.slotModel and bestEgg.slotModel:FindFirstChildWhichIsA("ProximityPrompt", true))
        if prompt and fireproximityprompt then
            fireproximityprompt(prompt, prompt.HoldDuration or 0)
            task.wait(0.04)
            fireproximityprompt(prompt, 0)
        end
        
        if bestEgg.hitPart and firetouchinterest then
            firetouchinterest(hrp, bestEgg.hitPart, 0)
            task.wait(0.03)
            firetouchinterest(hrp, bestEgg.hitPart, 1)
        end
        
        -- Si el huevo ya no está en el nido (ya lo tenemos en brazos!), escapar de inmediato!
        local slotsFolder = workspace:FindFirstChild("AreaEggSlotsClient")
        if slotsFolder and bestEgg.uid and not slotsFolder:FindFirstChild(bestEgg.uid) then
            break
        end
        task.wait(0.08)
    end
    
    -- PASO 6: Ascenso vertical instantáneo a 92.9 studs (escape aéreo anti-guardias)
    ok = tweenToTarget(hrp, skyOverEgg, 120)
    if not ok then stopTeleguiado(); return end
    
    -- PASO 7: Regreso seguro a la base por el aire a Y = 92.9
    if home then
        local skyOverHome = Vector3.new(home.X, flyAltitude, home.Z)
        ok = tweenToTarget(hrp, skyOverHome, slowModeActive and 220 or 450)
        if ok then
            -- Descenso suave a la base
            local landHome = home + Vector3.new(0, 3.0, 0)
            tweenToTarget(hrp, landHome, 80)
        end
    end
    
    -- 7. Limpieza al aterrizar
    setBodyVelocity(hrp, false)
    setNoclip(false)
    isFlying = false
    
    if not loopActive then
        teleguiadoActive = false
        SwitchBg.BackgroundColor3 = Color3.fromRGB(40, 45, 42)
        SwitchDot.Position = UDim2.new(0, 2, 0, 2)
        SwitchDot.BackgroundColor3 = Color3.fromRGB(150, 155, 150)
    end
end

task.spawn(function()
    while true do
        task.wait(0.2)
        if teleguiadoActive and not isFlying and bestEgg and bestEgg.pos then
            pcall(startNewTeleguiado)
            if loopActive and teleguiadoActive then
                task.wait(1.2)
            end
        end
    end
end)

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "LENNON HUB",
        Text = "Versión V14.0 Oficial cargada con éxito!",
        Duration = 4
    })
end)
print("¡Lennon Hub Best Egg System (V14.0 OFICIAL) cargado con éxito!")
