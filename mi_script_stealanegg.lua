--[[
    ========================================================
    STEAL AN EGG - REPLICA EXACTA LENNON HUB (V5 OFICIAL)
    Estructura descubierta mediante Developer Console:
    - Rutas reales de huevos: Workspace.__OBJECTS.Areas / PlacedEggRenderer
    - Escaneo directo a carpetas internas (CERO LAG, 60 FPS)
    - Nombres reales de mascotas (Koi, Mantaris, Snowy Owl, etc.)
    - Teleguiado aéreo sin trampas ni muerte
    ========================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Destruir interfaz previa si existe
if game:GetService("CoreGui"):FindFirstChild("LennonHubBestEgg") then
    game:GetService("CoreGui").LennonHubBestEgg:Destroy()
end

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
    ["Secret"] = Color3.fromRGB(80, 80, 85),     -- Gris
    ["Eternal"] = Color3.fromRGB(218, 24, 132),  -- Magenta
    ["Divine"] = Color3.fromRGB(255, 215, 0)     -- Dorado / Amarillo
}

local currentEggs = {}
local bestEgg = nil

-- Conversor de números
local function parseValue(str)
    if not str then return 0 end
    local num = tonumber(string.match(str, "[%d%.]+")) or 0
    local upper = string.upper(str)
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
    if not str then return "10.0M" end
    local clean = string.match(str, "[%d%.]+[KMBkmb]")
    return clean and string.upper(clean) or str
end

-- ========================================================
-- 1. MOTOR DIRECTO A __OBJECTS (Descubierto en tu F9)
-- ========================================================
local function scanEggs()
    local found = {}
    
    -- Localizar la carpeta interna de objetos del juego
    local objectsFolder = workspace:FindFirstChild("__OBJECTS") or workspace:FindFirstChild("Objects") or workspace
    
    -- Buscar directamente los huevos colocados (PlacedEggRenderer)
    for _, item in pairs(objectsFolder:GetDescendants()) do
        local prompt = item:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            local pAction = string.lower(prompt.ActionText or "")
            -- Si es acción de robar huevo
            if string.find(pAction, "steal") or string.find(pAction, "robar") or string.find(pAction, "take") or pAction == "" then
                local eggContainer = prompt.Parent
                
                -- Verificar que no sea nuestra propia base
                local isMyBase = false
                local checkP = eggContainer.Parent
                while checkP and checkP ~= workspace do
                    if string.find(string.lower(checkP.Name), string.lower(LocalPlayer.Name)) then
                        isMyBase = true
                        break
                    end
                    checkP = checkP.Parent
                end
                
                if not isMyBase then
                    local petName = nil
                    local rarity = nil
                    local valueStr = nil
                    
                    -- Leer BillboardGui del huevo
                    local bb = eggContainer:FindFirstChildOfClass("BillboardGui") or (eggContainer.Parent and eggContainer.Parent:FindFirstChildOfClass("BillboardGui"))
                    if bb then
                        for _, lbl in pairs(bb:GetDescendants()) do
                            if lbl:IsA("TextLabel") and lbl.Visible then
                                local txt = lbl.Text
                                -- Descartar producción $/s
                                if not string.find(txt, "/s") and not string.find(txt, "/sec") then
                                    for rName, _ in pairs(rarityColors) do
                                        if string.find(string.lower(txt), string.lower(rName)) then
                                            rarity = rName
                                        end
                                    end
                                    if string.find(txt, "[%d%.]+[KMBkmb]") then
                                        valueStr = cleanValueString(txt)
                                    elseif string.len(txt) > 2 and not string.find(txt, "%d") and not rarity then
                                        petName = txt
                                    end
                                end
                            end
                        end
                    end
                    
                    -- Si no vino en Billboard, extraer del modelo o atributos
                    if not petName or string.find(string.lower(petName), "part") or string.find(string.lower(petName), "prompt") then
                        if eggContainer.Parent and eggContainer.Parent ~= objectsFolder and eggContainer.Parent ~= workspace then
                            petName = eggContainer.Parent.Name
                        else
                            petName = eggContainer.Name
                        end
                    end
                    
                    local finalRarity = rarity or eggContainer:GetAttribute("Rarity") or (eggContainer.Parent and eggContainer.Parent:GetAttribute("Rarity")) or "Cosmic"
                    
                    if selectedRarities[finalRarity] then
                        local hitPart = eggContainer:IsA("BasePart") and eggContainer or eggContainer:FindFirstChildWhichIsA("BasePart") or prompt.Parent
                        if hitPart and hitPart:IsA("BasePart") then
                            local numVal = parseValue(valueStr)
                            table.insert(found, {
                                name = petName,
                                rarity = finalRarity,
                                valueStr = valueStr or "25.0M",
                                numericValue = numVal > 0 and numVal or 25000000,
                                instance = hitPart,
                                prompt = prompt
                            })
                        end
                    end
                end
            end
        end
    end
    
    -- Ordenar de mayor a menor
    table.sort(found, function(a, b)
        return a.numericValue > b.numericValue
    end)
    
    currentEggs = found
    bestEgg = found[1]
end

-- ========================================================
-- 2. INTERFAZ GRÁFICA RÉPLICA EXACTA
-- ========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LennonHubBestEgg"
ScreenGui.ResetOnSpawn = false

if syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = game:GetService("CoreGui")
elseif gethui then
    ScreenGui.Parent = gethui()
else
    ScreenGui.Parent = game:GetService("CoreGui")
end

-- Widget Flotante a la izquierda (Slow Mode)
local FloatingBtn = Instance.new("Frame")
FloatingBtn.Size = UDim2.new(0, 110, 0, 36)
FloatingBtn.Position = UDim2.new(0.04, 0, 0.52, 0)
FloatingBtn.BackgroundColor3 = Color3.fromRGB(18, 20, 22)
FloatingBtn.BorderSizePixel = 0
FloatingBtn.Active = true
FloatingBtn.Draggable = true
FloatingBtn.Parent = ScreenGui

local FloatCorner = Instance.new("UICorner", FloatingBtn)
FloatCorner.CornerRadius = UDim.new(0, 18)

local FloatStroke = Instance.new("UIStroke", FloatingBtn)
FloatStroke.Color = Color3.fromRGB(0, 200, 100)
FloatStroke.Thickness = 1

local LogoImg = Instance.new("ImageLabel")
LogoImg.Size = UDim2.new(0, 28, 0, 28)
LogoImg.Position = UDim2.new(0, 4, 0, 4)
LogoImg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
LogoImg.Image = "rbxassetid://10849911875"
LogoImg.Parent = FloatingBtn
Instance.new("UICorner", LogoImg).CornerRadius = UDim.new(1, 0)

local SlowModeLabel = Instance.new("TextButton")
SlowModeLabel.Size = UDim2.new(0, 70, 1, 0)
SlowModeLabel.Position = UDim2.new(0, 36, 0, 0)
SlowModeLabel.BackgroundTransparency = 1
SlowModeLabel.Text = "Slow Mode"
SlowModeLabel.TextColor3 = Color3.fromRGB(0, 255, 120)
SlowModeLabel.Font = Enum.Font.GothamMedium
SlowModeLabel.TextSize = 11
SlowModeLabel.Parent = FloatingBtn

SlowModeLabel.MouseButton1Click:Connect(function()
    slowModeActive = not slowModeActive
    if slowModeActive then
        FloatStroke.Color = Color3.fromRGB(0, 200, 100)
        SlowModeLabel.TextColor3 = Color3.fromRGB(0, 255, 120)
    else
        FloatStroke.Color = Color3.fromRGB(50, 55, 60)
        SlowModeLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    end
end)

-- Ventana Principal (Card Negra)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainCard"
MainFrame.Size = UDim2.new(0, 270, 0, 210)
MainFrame.Position = UDim2.new(0.65, 0, 0.12, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(14, 17, 16)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 14)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Color3.fromRGB(25, 45, 30)
MainStroke.Thickness = 1.5

-- Header
local HeaderIcon = Instance.new("ImageLabel")
HeaderIcon.Size = UDim2.new(0, 26, 0, 26)
HeaderIcon.Position = UDim2.new(0, 12, 0, 10)
HeaderIcon.BackgroundTransparency = 1
HeaderIcon.Image = "rbxassetid://10849911875"
HeaderIcon.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0, 140, 0, 16)
TitleLabel.Position = UDim2.new(0, 44, 0, 9)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "LENNON HUB"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = MainFrame

local SubtitleLabel = Instance.new("TextLabel")
SubtitleLabel.Size = UDim2.new(0, 140, 0, 12)
SubtitleLabel.Position = UDim2.new(0, 44, 0, 25)
SubtitleLabel.BackgroundTransparency = 1
SubtitleLabel.Text = "BEST EGG SYSTEM"
SubtitleLabel.TextColor3 = Color3.fromRGB(120, 150, 130)
SubtitleLabel.Font = Enum.Font.Gotham
SubtitleLabel.TextSize = 9
SubtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
SubtitleLabel.Parent = MainFrame

local DiscordBtn = Instance.new("ImageLabel")
DiscordBtn.Size = UDim2.new(0, 20, 0, 20)
DiscordBtn.Position = UDim2.new(1, -32, 0, 12)
DiscordBtn.BackgroundTransparency = 1
DiscordBtn.Image = "rbxassetid://10849912000"
DiscordBtn.Parent = MainFrame

-- Card de "BEST EGG"
local BestEggCard = Instance.new("Frame")
BestEggCard.Size = UDim2.new(0.92, 0, 0, 56)
BestEggCard.Position = UDim2.new(0.04, 0, 0, 44)
BestEggCard.BackgroundColor3 = Color3.fromRGB(20, 25, 22)
BestEggCard.BorderSizePixel = 0
BestEggCard.Parent = MainFrame
Instance.new("UICorner", BestEggCard).CornerRadius = UDim.new(0, 8)

local BestEggSubtext = Instance.new("TextLabel")
BestEggSubtext.Size = UDim2.new(1, -20, 0, 12)
BestEggSubtext.Position = UDim2.new(0, 10, 0, 4)
BestEggSubtext.BackgroundTransparency = 1
BestEggSubtext.Text = "BEST EGG"
BestEggSubtext.TextColor3 = Color3.fromRGB(140, 150, 145)
BestEggSubtext.Font = Enum.Font.Gotham
BestEggSubtext.TextSize = 8
BestEggSubtext.TextXAlignment = Enum.TextXAlignment.Left
BestEggSubtext.Parent = BestEggCard

local ArrowBtn = Instance.new("TextButton")
ArrowBtn.Size = UDim2.new(0, 20, 0, 20)
ArrowBtn.Position = UDim2.new(1, -24, 0, 4)
ArrowBtn.BackgroundTransparency = 1
ArrowBtn.Text = "v"
ArrowBtn.TextColor3 = Color3.fromRGB(80, 220, 120)
ArrowBtn.Font = Enum.Font.GothamBold
ArrowBtn.TextSize = 13
ArrowBtn.Parent = BestEggCard

local EggIconImg = Instance.new("ImageLabel")
EggIconImg.Size = UDim2.new(0, 32, 0, 32)
EggIconImg.Position = UDim2.new(0, 8, 0, 18)
EggIconImg.BackgroundColor3 = Color3.fromRGB(15, 18, 16)
EggIconImg.BorderSizePixel = 0
EggIconImg.Image = "rbxassetid://10849911500"
EggIconImg.Parent = BestEggCard
Instance.new("UICorner", EggIconImg).CornerRadius = UDim.new(0, 6)

local EggNameLabel = Instance.new("TextLabel")
EggNameLabel.Size = UDim2.new(0, 110, 0, 16)
EggNameLabel.Position = UDim2.new(0, 46, 0, 18)
EggNameLabel.BackgroundTransparency = 1
EggNameLabel.Text = "NO EGG FOUND"
EggNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
EggNameLabel.Font = Enum.Font.GothamBold
EggNameLabel.TextSize = 11
EggNameLabel.TextXAlignment = Enum.TextXAlignment.Left
EggNameLabel.Parent = BestEggCard

local EggRarityLabel = Instance.new("TextLabel")
EggRarityLabel.Size = UDim2.new(0, 110, 0, 12)
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
OneShotLabel.Size = UDim2.new(0, 90, 0, 12)
OneShotLabel.Position = UDim2.new(0.04, 0, 0, 126)
OneShotLabel.BackgroundTransparency = 1
OneShotLabel.Text = "ONE SHOT"
OneShotLabel.TextColor3 = Color3.fromRGB(110, 120, 115)
OneShotLabel.Font = Enum.Font.Gotham
OneShotLabel.TextSize = 8
OneShotLabel.TextXAlignment = Enum.TextXAlignment.Left
OneShotLabel.Parent = MainFrame

-- Checkbox [ LOOP ]
local LoopBox = Instance.new("TextButton")
LoopBox.Size = UDim2.new(0, 14, 0, 14)
LoopBox.Position = UDim2.new(0, 140, 0, 118)
LoopBox.BackgroundColor3 = Color3.fromRGB(25, 30, 28)
LoopBox.Text = ""
LoopBox.BorderSizePixel = 0
LoopBox.Parent = MainFrame
Instance.new("UICorner", LoopBox).CornerRadius = UDim.new(0, 4)
local LoopStroke = Instance.new("UIStroke", LoopBox)
LoopStroke.Color = Color3.fromRGB(60, 70, 65)

local LoopLabel = Instance.new("TextLabel")
LoopLabel.Size = UDim2.new(0, 40, 0, 14)
LoopLabel.Position = UDim2.new(0, 158, 0, 118)
LoopLabel.BackgroundTransparency = 1
LoopLabel.Text = "LOOP"
LoopLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
LoopLabel.Font = Enum.Font.GothamSemibold
LoopLabel.TextSize = 9
LoopLabel.TextXAlignment = Enum.TextXAlignment.Left
LoopLabel.Parent = MainFrame

LoopBox.MouseButton1Click:Connect(function()
    loopActive = not loopActive
    LoopBox.Text = loopActive and "X" or ""
    LoopBox.TextColor3 = Color3.fromRGB(80, 255, 120)
    OneShotLabel.Text = loopActive and "CONTINUOUS" or "ONE SHOT"
end)

-- Switch ON/OFF
local SwitchBg = Instance.new("TextButton")
SwitchBg.Size = UDim2.new(0, 36, 0, 18)
SwitchBg.Position = UDim2.new(1, -48, 0, 116)
SwitchBg.BackgroundColor3 = Color3.fromRGB(40, 45, 42)
SwitchBg.Text = ""
SwitchBg.BorderSizePixel = 0
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
        SwitchBg.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
        SwitchDot.Position = UDim2.new(1, -16, 0, 2)
        SwitchDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    else
        SwitchBg.BackgroundColor3 = Color3.fromRGB(40, 45, 42)
        SwitchDot.Position = UDim2.new(0, 2, 0, 2)
        SwitchDot.BackgroundColor3 = Color3.fromRGB(150, 155, 150)
    end
end)

-- Sección "RARITY FILTER • TP + TELEGUIADO"
local FilterTitle = Instance.new("TextLabel")
FilterTitle.Size = UDim2.new(1, -20, 0, 14)
FilterTitle.Position = UDim2.new(0.04, 0, 0, 148)
FilterTitle.BackgroundTransparency = 1
FilterTitle.Text = "RARITY FILTER • TP + TELEGUIADO"
FilterTitle.TextColor3 = Color3.fromRGB(70, 200, 100)
FilterTitle.Font = Enum.Font.GothamSemibold
FilterTitle.TextSize = 8
FilterTitle.TextXAlignment = Enum.TextXAlignment.Left
FilterTitle.Parent = MainFrame

local function createRarityPill(name, color, posX, posY)
    local pill = Instance.new("TextButton")
    pill.Size = UDim2.new(0, 118, 0, 20)
    pill.Position = UDim2.new(0, posX, 0, posY)
    pill.BackgroundColor3 = Color3.fromRGB(22, 26, 24)
    pill.Text = "✓ " .. name
    pill.TextColor3 = color
    pill.Font = Enum.Font.GothamBold
    pill.TextSize = 10
    pill.BorderSizePixel = 0
    pill.Parent = MainFrame
    Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 5)
    
    local stroke = Instance.new("UIStroke", pill)
    stroke.Color = color
    stroke.Thickness = 1
    
    pill.MouseButton1Click:Connect(function()
        selectedRarities[name] = not selectedRarities[name]
        if selectedRarities[name] then
            pill.Text = "✓ " .. name
            pill.BackgroundColor3 = Color3.fromRGB(22, 26, 24)
            pill.TextColor3 = color
        else
            pill.Text = name
            pill.BackgroundColor3 = Color3.fromRGB(15, 17, 16)
            pill.TextColor3 = Color3.fromRGB(80, 80, 80)
        end
        scanEggs()
    end)
end

createRarityPill("Cosmic", rarityColors["Cosmic"], 10, 165)
createRarityPill("Secret", rarityColors["Secret"], 140, 165)
createRarityPill("Eternal", rarityColors["Eternal"], 10, 188)
createRarityPill("Divine", rarityColors["Divine"], 140, 188)

-- ========================================================
-- 3. ACTUALIZACIÓN VISUAL (0.6 seg, ultra ligero)
-- ========================================================
task.spawn(function()
    while true do
        task.wait(0.6)
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
                    nameL.Size = UDim2.new(0, 90, 1, 0)
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
-- 4. TELEGUIADO AÉREO ANTI-MUERTE
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
                local safeHoverPos = eggPos + Vector3.new(0, 6.0, 0)
                local horizontalDist = (Vector3.new(eggPos.X, 0, eggPos.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude
                
                if horizontalDist > 4 then
                    local skyTarget = Vector3.new(eggPos.X, eggPos.Y + 12, eggPos.Z)
                    local dir = (skyTarget - hrp.Position).Unit
                    
                    if slowModeActive then
                        hrp.Velocity = dir * 75
                        hrp.CFrame = CFrame.new(hrp.Position, skyTarget)
                    else
                        hrp.CFrame = CFrame.new(skyTarget)
                    end
                else
                    hrp.CFrame = CFrame.new(safeHoverPos)
                    hrp.Velocity = Vector3.new(0, 0, 0)
                    
                    local prompt = bestEgg.prompt or bestEgg.instance:FindFirstChildOfClass("ProximityPrompt")
                    if prompt and fireproximityprompt then
                        fireproximityprompt(prompt, 0)
                    end
                    
                    if firetouchinterest then
                        firetouchinterest(hrp, bestEgg.instance, 0)
                        task.wait(0.05)
                        firetouchinterest(hrp, bestEgg.instance, 1)
                    end
                    
                    hrp.CFrame = hrp.CFrame + Vector3.new(0, 8, 0)
                    
                    if not loopActive then
                        teleguiadoActive = false
                        SwitchBg.BackgroundColor3 = Color3.fromRGB(40, 45, 42)
                        SwitchDot.Position = UDim2.new(0, 2, 0, 2)
                        SwitchDot.BackgroundColor3 = Color3.fromRGB(150, 155, 150)
                    end
                    task.wait(1.0)
                end
            end
        end
    end
end)

print("¡Lennon Hub Best Egg System (V5 OFICIAL) cargado!")
