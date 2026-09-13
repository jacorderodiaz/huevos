--[[
    ========================================================
    STEAL AN EGG - LENNON HUB BEST EGG SYSTEM (V8 DEFINITIVO)
    Descubierto con inspección directa del juego:
    - RUTA REAL: Workspace.ClientRenderedAssets
    - FILTRO DE BASE: Attr OwnerUserId o Nombre (UserId_UID)
    - DATOS: BillboardGui.Data:
        * DisplayName -> Nombre real (Holy Peacock, RazorFang, Rainbow Imp...)
        * Odds / Rarity -> Rareza real (Cosmic, Secret, Eternal, Divine)
        * PerSecond -> Multiplicador real ($360M/s, $54M/s -> 360M, 54M)
    - ANTI-TRAMPAS & ANTI-GUARDIAS: Vuelo aéreo directo
    ========================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Eliminar versión previa si existe
pcall(function()
    if game:GetService("CoreGui"):FindFirstChild("LennonHubBestEgg") then
        game:GetService("CoreGui").LennonHubBestEgg:Destroy()
    end
end)

-- Variables de Estado
local teleguiadoActive = false
local loopActive = false
local slowModeActive = true
local expandedList = false

local selectedRarities = {
    ["Cosmic"] = true,
    ["Secret"] = true,
    ["Eternal"] = true,
    ["Divine"] = true
}

local rarityColors = {
    ["Cosmic"] = Color3.fromRGB(138, 43, 226),   -- Púrpura
    ["Secret"] = Color3.fromRGB(80, 80, 85),     -- Gris / Plata
    ["Eternal"] = Color3.fromRGB(218, 24, 132),  -- Magenta
    ["Divine"] = Color3.fromRGB(255, 215, 0)     -- Dorado / Amarillo
}

local currentEggs = {}
local bestEgg = nil
local myBasePosition = nil

-- Helpers de conversión
local function parseValue(valStr)
    if not valStr then return 0 end
    local num = tonumber(string.match(valStr, "[%d%.]+"))
    if not num then return 0 end
    local upper = string.upper(valStr)
    if string.find(upper, "B") then
        return num * 1000000000
    elseif string.find(upper, "M") then
        return num * 1000000
    elseif string.find(upper, "K") then
        return num * 1000
    end
    return num
end

local function cleanValueString(str)
    if not str then return "25.0M" end
    local clean = string.match(str, "[%d%.]+[KMBkmb]")
    if clean then
        return string.upper(clean)
    end
    local numOnly = string.match(str, "[%d%.]+")
    return numOnly or str
end

-- ========================================================
-- 1. DETECTOR REAL DE HUEVOS (Vía Workspace.ClientRenderedAssets)
-- ========================================================
local function scanEggs()
    local found = {}
    local myUserId = tostring(LocalPlayer.UserId)
    local assets = workspace:FindFirstChild("ClientRenderedAssets")
    
    if assets then
        for _, child in pairs(assets:GetChildren()) do
            -- 1. Identificar dueño del huevo
            local ownerId = child:GetAttribute("OwnerUserId")
            if not ownerId then
                local parts = string.split(child.Name, "_")
                ownerId = parts[1]
            end
            ownerId = tostring(ownerId or "")
            
            -- Detectar posición de mi propia base si encontramos nuestros huevos
            if ownerId == myUserId then
                local myCenter = child:FindFirstChild("CENTER") or child:FindFirstChild("HumanoidRootPart") or child:FindFirstChildWhichIsA("BasePart")
                if myCenter then
                    myBasePosition = myCenter.Position + Vector3.new(0, 5, 0)
                end
            else
                -- Es un huevo enemigo disponible para robar
                local dataGui = child:FindFirstChild("Data") or child:FindFirstChildWhichIsA("BillboardGui")
                if dataGui then
                    local nameLabel = dataGui:FindFirstChild("DisplayName")
                    local oddsLabel = dataGui:FindFirstChild("Odds")
                    local rarityLabel = dataGui:FindFirstChild("Rarity")
                    local perSecLabel = dataGui:FindFirstChild("PerSecond")
                    
                    local petName = (nameLabel and nameLabel.Text ~= "") and nameLabel.Text or "Egg"
                    
                    -- Obtener rareza real
                    local rawOdds = oddsLabel and oddsLabel.Text or ""
                    local rawRarity = rarityLabel and rarityLabel.Text or ""
                    local petRarity = "Cosmic"
                    
                    if rawOdds ~= "" then
                        petRarity = rawOdds
                    elseif rawRarity ~= "" then
                        petRarity = rawRarity
                    end
                    
                    -- Normalizar rareza (Cosmic, Secret, Eternal, Divine)
                    for rKey, _ in pairs(rarityColors) do
                        if string.find(string.lower(petRarity), string.lower(rKey)) then
                            petRarity = rKey
                            break
                        end
                    end
                    
                    local valText = perSecLabel and perSecLabel.Text or "$25M/s"
                    local cleanVal = cleanValueString(valText)
                    local numVal = parseValue(valText)
                    
                    -- Parte física para posicionarse
                    local hitPart = child:FindFirstChild("CENTER") or child:FindFirstChild("HumanoidRootPart") or child:FindFirstChildWhichIsA("BasePart")
                    
                    -- ProximityPrompt para robar
                    local prompt = child:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if not prompt and hitPart then
                        -- Buscar en el pedestal o alrededores (a menos de 15 studs)
                        for _, p in pairs(workspace:GetDescendants()) do
                            if p:IsA("ProximityPrompt") and p.Parent and p.Parent:IsA("BasePart") then
                                if (p.Parent.Position - hitPart.Position).Magnitude < 15 then
                                    prompt = p
                                    break
                                end
                            end
                        end
                    end
                    
                    -- Buscar textura o imagen si existe
                    local petImage = nil
                    local decal = child:FindFirstChildWhichIsA("Decal", true)
                    if decal and decal.Texture ~= "" then
                        petImage = decal.Texture
                    end
                    
                    -- Filtrar por las rarezas seleccionadas
                    if selectedRarities[petRarity] and hitPart then
                        table.insert(found, {
                            name = petName,
                            rarity = petRarity,
                            valueStr = cleanVal,
                            numericValue = numVal > 0 and numVal or 25000000,
                            instance = hitPart,
                            prompt = prompt,
                            image = petImage
                        })
                    end
                end
            end
        end
    end
    
    -- Ordenar de mayor a menor valor
    table.sort(found, function(a, b)
        return a.numericValue > b.numericValue
    end)
    
    currentEggs = found
    bestEgg = found[1]
end

-- ========================================================
-- 2. CONSTRUCCIÓN DE INTERFAZ GRÁFICA (IDÉNTICA A LENNON HUB)
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

-- Lista Desplegable
local ListScroll = Instance.new("ScrollingFrame")
ListScroll.Size = UDim2.new(0.92, 0, 0, 95)
ListScroll.Position = UDim2.new(0.04, 0, 0, 105)
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

ArrowBtn.MouseButton1Click:Connect(function()
    expandedList = not expandedList
    ListScroll.Visible = expandedList
    ArrowBtn.Text = expandedList and "^" or "v"
    MainFrame.Size = expandedList and UDim2.new(0, 270, 0, 310) or UDim2.new(0, 270, 0, 210)
end)

-- Sección "TELEGUIADO"
local TeleguiadoLabel = Instance.new("TextLabel")
TeleguiadoLabel.Size = UDim2.new(0, 90, 0, 16)
TeleguiadoLabel.Position = UDim2.new(0.04, 0, 0, 110)
TeleguiadoLabel.BackgroundTransparency = 1
TeleguiadoLabel.Text = "TELEGUIADO"
TeleguiadoLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
TeleguiadoLabel.Font = Enum.Font.GothamBold
TeleguiadoLabel.TextSize = 11
TeleguiadoLabel.TextXAlignment = Enum.TextXAlignment.Left
TeleguiadoLabel.Parent = MainFrame

local OneShotLabel = Instance.new("TextLabel")
OneShotLabel.Size = UDim2.new(0, 65, 0, 12)
OneShotLabel.Position = UDim2.new(0.04, 0, 0, 126)
OneShotLabel.BackgroundTransparency = 1
OneShotLabel.Text = "ONE SHOT"
OneShotLabel.TextColor3 = Color3.fromRGB(130, 140, 130)
OneShotLabel.Font = Enum.Font.Gotham
OneShotLabel.TextSize = 9
OneShotLabel.TextXAlignment = Enum.TextXAlignment.Left
OneShotLabel.Parent = MainFrame

-- Checkbox LOOP
local LoopBox = Instance.new("TextButton")
LoopBox.Size = UDim2.new(0, 16, 0, 16)
LoopBox.Position = UDim2.new(0.52, 0, 0, 116)
LoopBox.BackgroundColor3 = Color3.fromRGB(24, 28, 26)
LoopBox.BorderSizePixel = 0
LoopBox.Text = ""
LoopBox.TextColor3 = Color3.fromRGB(50, 205, 50)
LoopBox.Font = Enum.Font.GothamBold
LoopBox.TextSize = 12
LoopBox.Parent = MainFrame
Instance.new("UICorner", LoopBox).CornerRadius = UDim.new(0, 4)
local LoopStroke = Instance.new("UIStroke", LoopBox)
LoopStroke.Color = Color3.fromRGB(45, 55, 48)

local LoopText = Instance.new("TextLabel")
LoopText.Size = UDim2.new(0, 35, 0, 16)
LoopText.Position = UDim2.new(0.52, 22, 0, 116)
LoopText.BackgroundTransparency = 1
LoopText.Text = "LOOP"
LoopText.TextColor3 = Color3.fromRGB(180, 190, 185)
LoopText.Font = Enum.Font.GothamBold
LoopText.TextSize = 10
LoopText.TextXAlignment = Enum.TextXAlignment.Left
LoopText.Parent = MainFrame

LoopBox.MouseButton1Click:Connect(function()
    loopActive = not loopActive
    LoopBox.Text = loopActive and "X" or ""
    LoopBox.BackgroundColor3 = loopActive and Color3.fromRGB(30, 48, 36) or Color3.fromRGB(24, 28, 26)
end)

-- Switch Toggle (ON/OFF Teleguiado)
local SwitchBg = Instance.new("TextButton")
SwitchBg.Size = UDim2.new(0, 36, 0, 18)
SwitchBg.Position = UDim2.new(1, -50, 0, 115)
SwitchBg.BackgroundColor3 = Color3.fromRGB(40, 45, 42)
SwitchBg.BorderSizePixel = 0
SwitchBg.Text = ""
SwitchBg.Parent = MainFrame
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
FilterHeader.Position = UDim2.new(0.04, 0, 0, 148)
FilterHeader.BackgroundTransparency = 1
FilterHeader.Text = "RARITY FILTER • TP + TELEGUIADO"
FilterHeader.TextColor3 = Color3.fromRGB(90, 180, 120)
FilterHeader.Font = Enum.Font.GothamBold
FilterHeader.TextSize = 8
FilterHeader.TextXAlignment = Enum.TextXAlignment.Left
FilterHeader.Parent = MainFrame

-- Pills de Rarezas
local function createRarityPill(name, color, xPos, yPos)
    local pill = Instance.new("TextButton")
    pill.Size = UDim2.new(0.44, 0, 0, 20)
    pill.Position = UDim2.new(xPos, 0, 0, yPos)
    pill.BackgroundColor3 = selectedRarities[name] and Color3.fromRGB(22, 28, 25) or Color3.fromRGB(16, 18, 17)
    pill.BorderSizePixel = 0
    pill.Text = (selectedRarities[name] and "✔ " or "") .. name
    pill.TextColor3 = selectedRarities[name] and color or Color3.fromRGB(110, 120, 115)
    pill.Font = Enum.Font.GothamBold
    pill.TextSize = 9
    pill.Parent = MainFrame
    Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 6)
    
    local stroke = Instance.new("UIStroke", pill)
    stroke.Color = selectedRarities[name] and Color3.fromRGB(40, 60, 48) or Color3.fromRGB(28, 34, 30)
    
    pill.MouseButton1Click:Connect(function()
        selectedRarities[name] = not selectedRarities[name]
        pill.Text = (selectedRarities[name] and "✔ " or "") .. name
        pill.TextColor3 = selectedRarities[name] and color or Color3.fromRGB(110, 120, 115)
        pill.BackgroundColor3 = selectedRarities[name] and Color3.fromRGB(22, 28, 25) or Color3.fromRGB(16, 18, 17)
        stroke.Color = selectedRarities[name] and Color3.fromRGB(40, 60, 48) or Color3.fromRGB(28, 34, 30)
        scanEggs()
    end)
end

createRarityPill("Cosmic", rarityColors["Cosmic"], 0.04, 166)
createRarityPill("Secret", rarityColors["Secret"], 0.52, 166)
createRarityPill("Eternal", rarityColors["Eternal"], 0.04, 188)
createRarityPill("Divine", rarityColors["Divine"], 0.52, 188)

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
-- 3. BUCLE DE ACTUALIZACIÓN EN VIVO DE LA INTERFAZ
-- ========================================================
task.spawn(function()
    while true do
        task.wait(0.8)
        scanEggs()
        
        if bestEgg then
            EggNameLabel.Text = bestEgg.name
            EggRarityLabel.Text = bestEgg.rarity
            EggRarityLabel.TextColor3 = rarityColors[bestEgg.rarity] or Color3.fromRGB(255, 255, 255)
            EggValueLabel.Text = bestEgg.valueStr
            if bestEgg.image then
                EggIconImg.Image = bestEgg.image
            end
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
-- 4. TELEGUIADO AÉREO ANTI-GUARDIAS Y ANTI-TRAMPAS
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
        if teleguiadoActive and bestEgg and bestEgg.instance and bestEgg.instance.Parent then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            
            if hrp and hum and hum.Health > 0 then
                local eggPos = bestEgg.instance.Position
                local safeHoverPos = eggPos + Vector3.new(0, 5.0, 0)
                local horizontalDist = (Vector3.new(eggPos.X, 0, eggPos.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude
                
                if horizontalDist > 4 then
                    -- Vuelo alto (Y + 20 studs) para evitar trampas de oso y guardias
                    local skyTarget = Vector3.new(eggPos.X, eggPos.Y + 18, eggPos.Z)
                    local dir = (skyTarget - hrp.Position).Unit
                    
                    if slowModeActive then
                        hrp.Velocity = dir * 85
                        hrp.CFrame = CFrame.new(hrp.Position, skyTarget)
                    else
                        hrp.CFrame = CFrame.new(skyTarget)
                    end
                else
                    -- Flotación directa encima del huevo
                    hrp.CFrame = CFrame.new(safeHoverPos)
                    hrp.Velocity = Vector3.new(0, 0, 0)
                    
                    -- Activar prompt
                    local prompt = bestEgg.prompt or bestEgg.instance:FindFirstChildOfClass("ProximityPrompt")
                    if prompt and fireproximityprompt then
                        fireproximityprompt(prompt, 0)
                    end
                    
                    if firetouchinterest then
                        firetouchinterest(hrp, bestEgg.instance, 0)
                        task.wait(0.05)
                        firetouchinterest(hrp, bestEgg.instance, 1)
                    end
                    
                    -- ESCAPE AÉREO INMEDIATO: Subir 30 studs para evadir GuardComponent
                    hrp.CFrame = hrp.CFrame + Vector3.new(0, 25, 0)
                    
                    -- Navegar de vuelta a la base del jugador por el aire
                    if myBasePosition then
                        task.wait(0.2)
                        local escapeSky = Vector3.new(myBasePosition.X, hrp.Position.Y, myBasePosition.Z)
                        hrp.CFrame = CFrame.new(escapeSky)
                        task.wait(0.3)
                        hrp.CFrame = CFrame.new(myBasePosition)
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

print("¡Lennon Hub Best Egg System (V8 DEFINITIVO) cargado con éxito!")
