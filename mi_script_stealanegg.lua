--[[
    ========================================================
    REPLICA EXACTA: LENNON HUB - BEST EGG SYSTEM
    Desarrollado para Steal An Egg (Delta Executor Móvil / PC)
    - FIX: Filtra ÚNICAMENTE huevos para robar (ignora mascotas de base con $/s)
    - FIX: Ignora tu propia base para no robarte a ti mismo
    - Detección precisa de nombres (Snowy Owl, Holy Peacock, etc.)
    - Teleguiado Inteligente hacia huevos del mapa / nidos enemigos
    ========================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Eliminar versión anterior si existe
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
    ["Divine"] = Color3.fromRGB(255, 215, 0)     -- Amarillo / Dorado
}

local currentEggs = {}
local bestEgg = nil

-- ========================================================
-- 1. PARSEADOR Y FILTRADO INTELIGENTE DE HUEVOS
-- ========================================================
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

local function scanEggs()
    local found = {}
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos = myHrp and myHrp.Position
    
    for _, obj in pairs(workspace:GetDescendants()) do
        -- 1. Descartar si está dentro de tu propia base / plot
        local inMyBase = false
        local parentCheck = obj.Parent
        while parentCheck and parentCheck ~= workspace do
            local pName = string.lower(parentCheck.Name)
            if string.find(pName, string.lower(LocalPlayer.Name)) then
                inMyBase = true
                break
            end
            parentCheck = parentCheck.Parent
        end
        
        if not inMyBase then
            local billboard = obj:FindFirstChildOfClass("BillboardGui") or obj:FindFirstChildOfClass("SurfaceGui")
            local isProductionPet = false
            local detectedRarity = nil
            local detectedName = nil
            local detectedVal = nil
            
            if billboard then
                for _, label in pairs(billboard:GetDescendants()) do
                    if label:IsA("TextLabel") and label.Visible then
                        local txt = label.Text
                        -- Si tiene "/s" o "/sec" es un animal produciendo dinero en una base, ¡DESCARTAR!
                        if string.find(txt, "/s") or string.find(txt, "/sec") or string.find(txt, "per sec") then
                            isProductionPet = true
                            break
                        end
                        
                        -- Comprobar rarezas
                        for rName, _ in pairs(rarityColors) do
                            if string.find(string.lower(txt), string.lower(rName)) then
                                detectedRarity = rName
                            end
                        end
                        
                        -- Comprobar valor / multiplicador del huevo (ej: 28.02M)
                        if string.find(txt, "[%d%.]+[KMBkmb]") and not string.find(txt, "/s") then
                            detectedVal = txt
                        elseif string.len(txt) > 2 and not string.find(txt, "%d") and not detectedRarity then
                            detectedName = txt
                        end
                    end
                end
            end
            
            -- Si NO es una mascota que produce dinero
            if not isProductionPet then
                -- Comprobar si tiene ProximityPrompt (E para robar) o Touch
                local prompt = obj:FindFirstChildOfClass("ProximityPrompt") or (obj.Parent and obj.Parent:FindFirstChildOfClass("ProximityPrompt"))
                local hasStealAction = false
                if prompt then
                    local pText = string.lower((prompt.ActionText or "") .. " " .. (prompt.ObjectText or ""))
                    if string.find(pText, "steal") or string.find(pText, "take") or string.find(pText, "egg") or string.find(pText, "robar") or string.find(pText, "grab") or prompt.ActionText == "" then
                        hasStealAction = true
                    end
                end
                
                local objName = obj.Name
                local isEggName = string.find(string.lower(objName), "egg") or string.find(string.lower(objName), "huevo")
                
                -- Si se detectó rareza o prompt de robo
                if (detectedRarity or hasStealAction or isEggName) and not isProductionPet then
                    local targetPart = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                    if targetPart then
                        local r = detectedRarity or "Cosmic"
                        if selectedRarities[r] then
                            local numVal = parseValue(detectedVal)
                            table.insert(found, {
                                name = detectedName or (isEggName and objName or (r .. " Egg")),
                                rarity = r,
                                valueStr = detectedVal or "1.0x",
                                numericValue = numVal,
                                instance = targetPart
                            })
                        end
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
-- 2. INTERFAZ GRÁFICA NATIVA
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

-- Botón Flotante a la izquierda (Slow Mode)
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

-- Ventana Principal (Card Negra redondeada)
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
-- 3. MOTOR DEL TELEGUIADO HACIA EL MEJOR HUEVO
-- ========================================================
task.spawn(function()
    while true do
        task.wait(1.0)
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

-- Bucle de Teleguiado Físico
task.spawn(function()
    while true do
        task.wait(0.1)
        if teleguiadoActive and bestEgg and bestEgg.instance then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            
            if hrp then
                local targetPos = bestEgg.instance.Position + Vector3.new(0, 2.5, 0)
                local dist = (targetPos - hrp.Position).Magnitude
                
                if dist > 5 then
                    if slowModeActive then
                        -- Planeo suave
                        local dir = (targetPos - hrp.Position).Unit
                        hrp.Velocity = dir * 70
                        hrp.CFrame = CFrame.new(hrp.Position, targetPos)
                    else
                        -- Teleguiado directo
                        hrp.CFrame = CFrame.new(targetPos)
                    end
                else
                    -- Al llegar al huevo objetivo
                    local prompt = bestEgg.instance:FindFirstChildOfClass("ProximityPrompt") or bestEgg.instance.Parent:FindFirstChildOfClass("ProximityPrompt")
                    if prompt and fireproximityprompt then
                        fireproximityprompt(prompt)
                    end
                    if firetouchinterest then
                        firetouchinterest(hrp, bestEgg.instance, 0)
                        task.wait(0.05)
                        firetouchinterest(hrp, bestEgg.instance, 1)
                    end
                    
                    if not loopActive then
                        teleguiadoActive = false
                        SwitchBg.BackgroundColor3 = Color3.fromRGB(40, 45, 42)
                        SwitchDot.Position = UDim2.new(0, 2, 0, 2)
                        SwitchDot.BackgroundColor3 = Color3.fromRGB(150, 155, 150)
                    end
                    task.wait(0.8)
                end
            end
        end
    end
end)

print("¡Lennon Hub Best Egg System (Filtro Corregido) cargado!")
