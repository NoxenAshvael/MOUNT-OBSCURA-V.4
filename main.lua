-- ESP MOUNT OBSCURA - ULTRA PREMIUM GUI v3
-- By: NoxenAshvael
-- NEW: Radius Slider + ESP Color Picker

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- ========== KONFIGURASI ==========
local Config = {
    ShowESP    = true,
    ScanRadius = 300,
    UpdateSpeed = 0.5,
    HighlightColor = Color3.fromRGB(255, 50, 50),
}

-- ========== DAFTAR OBSTACLE ==========
local AllowedObstacles  = { "Part", "Union", "Truss" }
local AllowedClassNames = { "UnionOperation" }

local cacheValidParts   = {}
local cacheInvalidParts = {}
local lastCacheClear    = 0

local function IsAllowedObstacle(part)
    if not part or not part:IsA("BasePart") then return false end
    if part:IsDescendantOf(LocalPlayer.Character) then return false end
    if cacheValidParts[part]   then return true  end
    if cacheInvalidParts[part] then return false end
    for _, v in ipairs(AllowedObstacles)  do if part.Name      == v then cacheValidParts[part]   = true return true  end end
    for _, v in ipairs(AllowedClassNames) do if part.ClassName == v then cacheValidParts[part]   = true return true  end end
    cacheInvalidParts[part] = true
    return false
end

local function CleanCache()
    local now = tick()
    if now - lastCacheClear >= 60 then
        lastCacheClear = now
        for p in pairs(cacheValidParts)   do if not p or not p.Parent then cacheValidParts[p]   = nil end end
        for p in pairs(cacheInvalidParts) do if not p or not p.Parent then cacheInvalidParts[p] = nil end end
    end
end

-- ========== ESP ==========
local activeESP = {}
local espTimestamps = {}  -- FIX: grace period tracker

local function UpdateAllESPColor()
    for part, group in pairs(activeESP) do
        if group then
            local box = group:FindFirstChild("Box")
            if box then box.Color3 = Config.HighlightColor end
        end
    end
end

local function CreateESP(part)
    if activeESP[part] then return end
    local espGroup = Instance.new("Folder")
    espGroup.Name = "ESP_Obstacle"
    espGroup.Parent = part
    local box = Instance.new("BoxHandleAdornment")
    box.Name = "Box"
    box.Adornee = part
    box.Size = part.Size
    box.Color3 = Config.HighlightColor
    box.Transparency = 0.35
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Parent = espGroup
    local bill = Instance.new("BillboardGui")
    bill.Adornee = part
    bill.Size = UDim2.new(0, 140, 0, 30)
    bill.AlwaysOnTop = true
    bill.Parent = espGroup
    local label = Instance.new("TextLabel")
    label.Text = "! " .. part.Name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Parent = bill
    activeESP[part] = espGroup
end

local function ClearESP()
    for _, g in pairs(activeESP) do if g then g:Destroy() end end
    activeESP = {}
    espTimestamps = {}  -- FIX: bersihkan timestamps juga
end

local updateDisplay = nil
local lastFoundCount = -1

local function RefreshESP()
    if not Config.ShowESP then return end
    local character = LocalPlayer.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
    if not root then return end
    local rootPos = root.Position
    local newList, foundCount = {}, 0

    -- FIX: Ganti FindPartsInRegion3 (deprecated) dengan GetPartBoundsInRadius (lebih akurat)
    local overlapParams = OverlapParams.new()
    overlapParams.FilterDescendantsInstances = {character}
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.MaxParts = 1000
    local parts = Workspace:GetPartBoundsInRadius(rootPos, Config.ScanRadius, overlapParams)

    for _, obj in ipairs(parts) do
        if IsAllowedObstacle(obj) then
            CreateESP(obj)
            newList[obj] = true
            espTimestamps[obj] = tick()  -- FIX: update timestamp tiap terdeteksi
            foundCount = foundCount + 1
        end
    end

    -- FIX: Grace period 1.5 detik sebelum ESP dihapus (anti-flicker)
    local now = tick()
    local GRACE = 1.5
    for part, group in pairs(activeESP) do
        if not part or not part.Parent then
            if group then group:Destroy() end
            activeESP[part] = nil
            espTimestamps[part] = nil
        elseif not newList[part] then
            if not espTimestamps[part] or (now - espTimestamps[part]) > GRACE then
                if group then group:Destroy() end
                activeESP[part] = nil
                espTimestamps[part] = nil
            end
        end
    end

    if updateDisplay and foundCount ~= lastFoundCount then
        updateDisplay(foundCount)
        lastFoundCount = foundCount
    end
end

-- ========== HELPERS ==========
local function MakeCorner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 10); c.Parent = p; return c
end
local function MakeStroke(p, col, th, tr)
    local s = Instance.new("UIStroke"); s.Color = col or Color3.fromRGB(255,40,40)
    s.Thickness = th or 1; s.Transparency = tr or 0.5; s.Parent = p; return s
end
local function MakeTxt(p, txt, sz, fnt, col, xa, zi)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1; l.Text = txt
    l.TextSize = sz or 12; l.Font = fnt or Enum.Font.Gotham
    l.TextColor3 = col or Color3.fromRGB(220,220,220)
    l.TextXAlignment = xa or Enum.TextXAlignment.Center
    l.ZIndex = zi or 5; l.Parent = p; return l
end

-- ========== GUI ==========
local screenGui = nil

local function CreateModernGUI()
    if screenGui then screenGui:Destroy() end

    screenGui = Instance.new("ScreenGui")
    screenGui.Name        = "ESP MOUNT OBSCURA V3"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- ===== HINT BADGE =====
    local badge = Instance.new("Frame")
    badge.Size = UDim2.new(0,124,0,26); badge.Position = UDim2.new(0,16,0,8)
    badge.BackgroundColor3 = Color3.fromRGB(10,10,18); badge.BorderSizePixel = 0
    badge.ZIndex = 10; badge.Parent = screenGui
    MakeCorner(badge,7); MakeStroke(badge, Color3.fromRGB(255,40,40),1,0.4)
    local badgeLabel = MakeTxt(badge,"[ V ]  Toggle Panel",10,Enum.Font.GothamMedium,Color3.fromRGB(180,180,200),Enum.TextXAlignment.Center,11)

    -- ===== SIZES =====
    local PW       = 290
    local HEADER_H = 68
    local CONTENT_Y = HEADER_H + 10

    -- Sections heights:
    -- statCard: 68
    -- gap: 8
    -- secLabel TARGETS: 16
    -- 3 rows: 3*(40+6) = 138
    -- gap: 8
    -- secLabel SETTINGS: 16
    -- radiusCard: 62
    -- gap: 8
    -- colorCard: 62
    -- gap: 8
    -- espBtn: 40
    -- bottomPad: 10
    -- total content: 68+8+16+138+8+16+62+8+62+8+40+8+16+62+10 = 530
    local CONTENT_H = 530
    local PH = CONTENT_Y + CONTENT_H + 6

    -- ===== MAIN FRAME =====
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0,PW,0,PH); main.Position = UDim2.new(0,16,0,42)
    main.BackgroundColor3 = Color3.fromRGB(9,9,16); main.BorderSizePixel = 0
    main.ClipsDescendants = true; main.ZIndex = 2; main.Parent = screenGui
    MakeCorner(main,16); MakeStroke(main, Color3.fromRGB(255,40,40),1.5,0.35)

    -- ===== HEADER =====
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1,0,0,HEADER_H); header.BackgroundColor3 = Color3.fromRGB(22,6,6)
    header.BorderSizePixel = 0; header.ZIndex = 3; header.Parent = main
    MakeCorner(header,16)
    -- flat bottom cover
    local hf = Instance.new("Frame"); hf.Size = UDim2.new(1,0,0,16)
    hf.Position = UDim2.new(0,0,1,-16); hf.BackgroundColor3 = Color3.fromRGB(22,6,6)
    hf.BorderSizePixel = 0; hf.ZIndex = 3; hf.Parent = header
    -- accent line
    local al = Instance.new("Frame"); al.Size = UDim2.new(1,0,0,2)
    al.Position = UDim2.new(0,0,1,-1); al.BackgroundColor3 = Color3.fromRGB(255,35,35)
    al.BackgroundTransparency = 0.3; al.BorderSizePixel = 0; al.ZIndex = 5; al.Parent = header
    -- icon
    local ib = Instance.new("Frame"); ib.Size = UDim2.new(0,44,0,44)
    ib.Position = UDim2.new(0,14,0,12); ib.BackgroundColor3 = Color3.fromRGB(220,30,30)
    ib.BorderSizePixel = 0; ib.ZIndex = 4; ib.Parent = header; MakeCorner(ib,11)
    MakeTxt(ib,"ESP",12,Enum.Font.GothamBold,Color3.fromRGB(255,255,255),Enum.TextXAlignment.Center,5)
    -- title
    local t1 = Instance.new("TextLabel"); t1.Size = UDim2.new(0,170,0,22)
    t1.Position = UDim2.new(0,68,0,12); t1.BackgroundTransparency = 1
    t1.Text = "MOUNT OBSCURA"; t1.TextColor3 = Color3.fromRGB(255,255,255)
    t1.TextSize = 16; t1.Font = Enum.Font.GothamBold
    t1.TextXAlignment = Enum.TextXAlignment.Left; t1.ZIndex = 4; t1.Parent = header
    local t2 = Instance.new("TextLabel"); t2.Size = UDim2.new(0,170,0,15)
    t2.Position = UDim2.new(0,68,0,36); t2.BackgroundTransparency = 1
    t2.Text = "OBSTACLE DETECTOR  v3.0"; t2.TextColor3 = Color3.fromRGB(200,60,60)
    t2.TextSize = 8; t2.Font = Enum.Font.GothamMedium
    t2.TextXAlignment = Enum.TextXAlignment.Left; t2.ZIndex = 4; t2.Parent = header
    -- live dot
    local liveDot = Instance.new("Frame"); liveDot.Size = UDim2.new(0,8,0,8)
    liveDot.Position = UDim2.new(1,-46,0,14); liveDot.BackgroundColor3 = Color3.fromRGB(60,240,100)
    liveDot.BorderSizePixel = 0; liveDot.ZIndex = 4; liveDot.Parent = header; MakeCorner(liveDot,4)
    local liveTxt = Instance.new("TextLabel"); liveTxt.Size = UDim2.new(0,32,0,12)
    liveTxt.Position = UDim2.new(1,-38,0,11); liveTxt.BackgroundTransparency = 1
    liveTxt.Text = "LIVE"; liveTxt.TextColor3 = Color3.fromRGB(60,240,100)
    liveTxt.TextSize = 7; liveTxt.Font = Enum.Font.GothamBold
    liveTxt.TextXAlignment = Enum.TextXAlignment.Left; liveTxt.ZIndex = 4; liveTxt.Parent = header
    -- minimize btn
    local minBtn = Instance.new("TextButton"); minBtn.Size = UDim2.new(0,26,0,26)
    minBtn.Position = UDim2.new(1,-40,0,34); minBtn.BackgroundColor3 = Color3.fromRGB(60,14,14)
    minBtn.Text = "–"; minBtn.TextColor3 = Color3.fromRGB(255,255,255)
    minBtn.TextSize = 16; minBtn.Font = Enum.Font.GothamBold
    minBtn.BorderSizePixel = 0; minBtn.ZIndex = 6; minBtn.Parent = header
    MakeCorner(minBtn,7); MakeStroke(minBtn, Color3.fromRGB(255,50,50),1,0.5)

    -- ===== CONTENT =====
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1,-20,0,CONTENT_H); content.Position = UDim2.new(0,10,0,CONTENT_Y)
    content.BackgroundTransparency = 1; content.ZIndex = 3; content.Parent = main

    local cy = 0  -- running Y cursor inside content

    -- ===== STAT CARD =====
    local statCard = Instance.new("Frame"); statCard.Size = UDim2.new(1,0,0,68)
    statCard.Position = UDim2.new(0,0,0,cy); statCard.BackgroundColor3 = Color3.fromRGB(18,5,5)
    statCard.BorderSizePixel = 0; statCard.ZIndex = 4; statCard.Parent = content
    MakeCorner(statCard,13); MakeStroke(statCard, Color3.fromRGB(255,35,35),1,0.6)
    local sg = Instance.new("UIGradient")
    sg.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(28,7,7)),ColorSequenceKeypoint.new(1,Color3.fromRGB(12,3,3))})
    sg.Rotation = 135; sg.Parent = statCard
    local bigNum = Instance.new("TextLabel"); bigNum.Size = UDim2.new(0,72,1,0)
    bigNum.Position = UDim2.new(0,14,0,0); bigNum.BackgroundTransparency = 1
    bigNum.Text = "0"; bigNum.TextColor3 = Color3.fromRGB(255,55,55)
    bigNum.TextSize = 44; bigNum.Font = Enum.Font.GothamBold
    bigNum.TextXAlignment = Enum.TextXAlignment.Left; bigNum.ZIndex = 5; bigNum.Parent = statCard
    local vd = Instance.new("Frame"); vd.Size = UDim2.new(0,1,0,40)
    vd.Position = UDim2.new(0,88,0,14); vd.BackgroundColor3 = Color3.fromRGB(255,35,35)
    vd.BackgroundTransparency = 0.7; vd.BorderSizePixel = 0; vd.ZIndex = 5; vd.Parent = statCard
    local lA = Instance.new("TextLabel"); lA.Size = UDim2.new(0,165,0,20)
    lA.Position = UDim2.new(0,98,0,12); lA.BackgroundTransparency = 1
    lA.Text = "OBSTACLES FOUND"; lA.TextColor3 = Color3.fromRGB(200,200,215)
    lA.TextSize = 10; lA.Font = Enum.Font.GothamBold
    lA.TextXAlignment = Enum.TextXAlignment.Left; lA.ZIndex = 5; lA.Parent = statCard
    local lB = Instance.new("TextLabel"); lB.Size = UDim2.new(0,165,0,16)
    lB.Position = UDim2.new(0,98,0,34); lB.BackgroundTransparency = 1
    lB.Text = "Radius: 300 studs"; lB.TextColor3 = Color3.fromRGB(100,100,120)
    lB.TextSize = 9; lB.Font = Enum.Font.Gotham
    lB.TextXAlignment = Enum.TextXAlignment.Left; lB.ZIndex = 5; lB.Parent = statCard
    cy = cy + 68 + 8

    -- ===== SECTION: SCAN TARGETS =====
    local st1 = Instance.new("TextLabel"); st1.Size = UDim2.new(1,0,0,16)
    st1.Position = UDim2.new(0,2,0,cy); st1.BackgroundTransparency = 1
    st1.Text = "ACTIVE SCAN TARGETS"; st1.TextColor3 = Color3.fromRGB(100,100,120)
    st1.TextSize = 8; st1.Font = Enum.Font.GothamMedium
    st1.TextXAlignment = Enum.TextXAlignment.Left; st1.ZIndex = 4; st1.Parent = content
    cy = cy + 16

    local rowDefs = {
        {tag="PRT",name="Part",  sub="Basic geometry block"},
        {tag="UNI",name="Union", sub="Merged mesh operation"},
        {tag="TRS",name="Truss", sub="Truss structure part"},
    }
    for i, row in ipairs(rowDefs) do
        local rf = Instance.new("Frame"); rf.Size = UDim2.new(1,0,0,40)
        rf.Position = UDim2.new(0,0,0,cy); rf.BackgroundColor3 = Color3.fromRGB(16,5,5)
        rf.BorderSizePixel = 0; rf.ZIndex = 4; rf.Parent = content
        MakeCorner(rf,10); MakeStroke(rf, Color3.fromRGB(255,35,35),1,0.72)
        local pill = Instance.new("Frame"); pill.Size = UDim2.new(0,40,0,24)
        pill.Position = UDim2.new(0,10,0,8); pill.BackgroundColor3 = Color3.fromRGB(210,28,28)
        pill.BorderSizePixel = 0; pill.ZIndex = 5; pill.Parent = rf; MakeCorner(pill,7)
        MakeTxt(pill,row.tag,8,Enum.Font.GothamBold,Color3.fromRGB(255,255,255),Enum.TextXAlignment.Center,6)
        local rn = Instance.new("TextLabel"); rn.Size = UDim2.new(0,150,0,18)
        rn.Position = UDim2.new(0,60,0,4); rn.BackgroundTransparency = 1
        rn.Text = row.name; rn.TextColor3 = Color3.fromRGB(235,235,245)
        rn.TextSize = 13; rn.Font = Enum.Font.GothamBold
        rn.TextXAlignment = Enum.TextXAlignment.Left; rn.ZIndex = 5; rn.Parent = rf
        local rs = Instance.new("TextLabel"); rs.Size = UDim2.new(0,160,0,14)
        rs.Position = UDim2.new(0,60,0,23); rs.BackgroundTransparency = 1
        rs.Text = row.sub; rs.TextColor3 = Color3.fromRGB(90,90,110)
        rs.TextSize = 8; rs.Font = Enum.Font.Gotham
        rs.TextXAlignment = Enum.TextXAlignment.Left; rs.ZIndex = 5; rs.Parent = rf
        local dot = Instance.new("Frame"); dot.Size = UDim2.new(0,7,0,7)
        dot.Position = UDim2.new(1,-14,0,17); dot.BackgroundColor3 = Color3.fromRGB(255,50,50)
        dot.BorderSizePixel = 0; dot.ZIndex = 5; dot.Parent = rf; MakeCorner(dot,4)
        cy = cy + 40 + 6
    end
    cy = cy + 2  -- extra gap before settings

    -- ===== SECTION: SETTINGS =====
    local st2 = Instance.new("TextLabel"); st2.Size = UDim2.new(1,0,0,16)
    st2.Position = UDim2.new(0,2,0,cy); st2.BackgroundTransparency = 1
    st2.Text = "SETTINGS"; st2.TextColor3 = Color3.fromRGB(100,100,120)
    st2.TextSize = 8; st2.Font = Enum.Font.GothamMedium
    st2.TextXAlignment = Enum.TextXAlignment.Left; st2.ZIndex = 4; st2.Parent = content
    cy = cy + 16

    -- ===== RADIUS SLIDER CARD =====
    local MIN_R, MAX_R = 100, 500
    local radCard = Instance.new("Frame"); radCard.Size = UDim2.new(1,0,0,62)
    radCard.Position = UDim2.new(0,0,0,cy); radCard.BackgroundColor3 = Color3.fromRGB(14,4,4)
    radCard.BorderSizePixel = 0; radCard.ZIndex = 4; radCard.Parent = content
    MakeCorner(radCard,13); MakeStroke(radCard, Color3.fromRGB(255,35,35),1,0.65)

    local radTitle = Instance.new("TextLabel"); radTitle.Size = UDim2.new(1,-16,0,18)
    radTitle.Position = UDim2.new(0,12,0,8); radTitle.BackgroundTransparency = 1
    radTitle.Text = "SCAN RADIUS"; radTitle.TextColor3 = Color3.fromRGB(200,200,215)
    radTitle.TextSize = 10; radTitle.Font = Enum.Font.GothamBold
    radTitle.TextXAlignment = Enum.TextXAlignment.Left; radTitle.ZIndex = 5; radTitle.Parent = radCard

    local radValLabel = Instance.new("TextLabel"); radValLabel.Size = UDim2.new(0,70,0,18)
    radValLabel.Position = UDim2.new(1,-80,0,8); radValLabel.BackgroundTransparency = 1
    radValLabel.Text = "300 studs"; radValLabel.TextColor3 = Color3.fromRGB(255,80,80)
    radValLabel.TextSize = 10; radValLabel.Font = Enum.Font.GothamBold
    radValLabel.TextXAlignment = Enum.TextXAlignment.Right; radValLabel.ZIndex = 5; radValLabel.Parent = radCard

    -- slider track
    local TRACK_X_PAD = 12
    local trackBg = Instance.new("Frame"); trackBg.Size = UDim2.new(1,-TRACK_X_PAD*2,0,6)
    trackBg.Position = UDim2.new(0,TRACK_X_PAD,0,38); trackBg.BackgroundColor3 = Color3.fromRGB(40,12,12)
    trackBg.BorderSizePixel = 0; trackBg.ZIndex = 5; trackBg.Parent = radCard; MakeCorner(trackBg,3)

    local trackFill = Instance.new("Frame"); trackFill.Size = UDim2.new(0.5,0,1,0)  -- default 300 = midish
    trackFill.BackgroundColor3 = Color3.fromRGB(220,35,35); trackFill.BorderSizePixel = 0
    trackFill.ZIndex = 6; trackFill.Parent = trackBg; MakeCorner(trackFill,3)

    local sliderThumb = Instance.new("Frame"); sliderThumb.Size = UDim2.new(0,14,0,14)
    sliderThumb.AnchorPoint = Vector2.new(0.5,0.5)
    sliderThumb.Position = UDim2.new(0.5,0,0.5,0)  -- will be set properly
    sliderThumb.BackgroundColor3 = Color3.fromRGB(255,255,255); sliderThumb.BorderSizePixel = 0
    sliderThumb.ZIndex = 7; sliderThumb.Parent = trackBg; MakeCorner(sliderThumb,7)
    MakeStroke(sliderThumb, Color3.fromRGB(220,35,35),2,0)

    -- Set initial thumb + fill from Config.ScanRadius
    local function SetSliderFromRadius(r)
        local t = (r - MIN_R) / (MAX_R - MIN_R)
        trackFill.Size = UDim2.new(t, 0, 1, 0)
        sliderThumb.Position = UDim2.new(t, 0, 0.5, 0)
        radValLabel.Text = r .. " studs"
        Config.ScanRadius = r
        lB.Text = "Radius: " .. r .. " studs"
    end
    SetSliderFromRadius(300)

    -- Drag logic for slider
    local sliderDragging = false
    local trackAbsPos, trackAbsSize

    local function UpdateSliderFromMouse(mouseX)
        if not trackAbsPos then return end
        local rel = math.clamp((mouseX - trackAbsPos.X) / trackAbsSize.X, 0, 1)
        local r = math.floor(MIN_R + rel * (MAX_R - MIN_R))
        r = math.floor(r / 10) * 10  -- snap to 10
        SetSliderFromRadius(r)
    end

    trackBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliderDragging = true
            trackAbsPos  = trackBg.AbsolutePosition
            trackAbsSize = trackBg.AbsoluteSize
            UpdateSliderFromMouse(input.Position.X)
        end
    end)
    sliderThumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliderDragging = true
            trackAbsPos  = trackBg.AbsolutePosition
            trackAbsSize = trackBg.AbsoluteSize
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliderDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateSliderFromMouse(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliderDragging = false
        end
    end)

    cy = cy + 62 + 8

    -- ===== COLOR PICKER CARD =====
    -- 6 preset colors + live preview swatch
    local colorPresets = {
        {name="RED",   c=Color3.fromRGB(255,50,50)},
        {name="ORG",   c=Color3.fromRGB(255,140,0)},
        {name="YLW",   c=Color3.fromRGB(255,230,0)},
        {name="GRN",   c=Color3.fromRGB(50,230,80)},
        {name="CYN",   c=Color3.fromRGB(0,200,255)},
        {name="PRP",   c=Color3.fromRGB(180,50,255)},
    }

    local colCard = Instance.new("Frame"); colCard.Size = UDim2.new(1,0,0,62)
    colCard.Position = UDim2.new(0,0,0,cy); colCard.BackgroundColor3 = Color3.fromRGB(14,4,4)
    colCard.BorderSizePixel = 0; colCard.ZIndex = 4; colCard.Parent = content
    MakeCorner(colCard,13); MakeStroke(colCard, Color3.fromRGB(255,35,35),1,0.65)

    local colTitle = Instance.new("TextLabel"); colTitle.Size = UDim2.new(1,-16,0,18)
    colTitle.Position = UDim2.new(0,12,0,8); colTitle.BackgroundTransparency = 1
    colTitle.Text = "ESP BOX COLOR"; colTitle.TextColor3 = Color3.fromRGB(200,200,215)
    colTitle.TextSize = 10; colTitle.Font = Enum.Font.GothamBold
    colTitle.TextXAlignment = Enum.TextXAlignment.Left; colTitle.ZIndex = 5; colTitle.Parent = colCard

    -- preview swatch (kanan title)
    local previewSwatch = Instance.new("Frame"); previewSwatch.Size = UDim2.new(0,20,0,14)
    previewSwatch.Position = UDim2.new(1,-34,0,11); previewSwatch.BackgroundColor3 = Config.HighlightColor
    previewSwatch.BorderSizePixel = 0; previewSwatch.ZIndex = 6; previewSwatch.Parent = colCard
    MakeCorner(previewSwatch,4); MakeStroke(previewSwatch, Color3.fromRGB(255,255,255),1,0.6)

    -- color buttons
    local BTN_W = 34
    local BTN_H = 22
    local BTN_GAP = 6
    local totalBtnW = #colorPresets * BTN_W + (#colorPresets-1) * BTN_GAP
    local btnStartX = math.floor((colCard.Size.X.Offset - totalBtnW) / 2)
    -- use UDim2 proportional start
    local colBtnY = 32

    for i, preset in ipairs(colorPresets) do
        local bx = 12 + (i-1)*(BTN_W + BTN_GAP)
        local cb = Instance.new("TextButton"); cb.Size = UDim2.new(0,BTN_W,0,BTN_H)
        cb.Position = UDim2.new(0,bx,0,colBtnY); cb.BackgroundColor3 = preset.c
        cb.BorderSizePixel = 0; cb.Text = ""; cb.ZIndex = 6; cb.Parent = colCard
        MakeCorner(cb,6)

        -- selected ring (default hide except first)
        local ring = Instance.new("UIStroke"); ring.Color = Color3.fromRGB(255,255,255)
        ring.Thickness = 2; ring.Transparency = (i == 1) and 0 or 1; ring.Parent = cb

        cb.MouseButton1Click:Connect(function()
            Config.HighlightColor = preset.c
            previewSwatch.BackgroundColor3 = preset.c
            UpdateAllESPColor()
            -- update ring on all buttons
            for j, p2 in ipairs(colorPresets) do
                local otherBtn = colCard:GetChildren()
                -- find by position offset
            end
            -- simpler: store ring refs
            ring.Transparency = 0
        end)

        cb.MouseEnter:Connect(function()
            TweenService:Create(cb, TweenInfo.new(0.1), {BackgroundTransparency = 0.25}):Play()
        end)
        cb.MouseLeave:Connect(function()
            TweenService:Create(cb, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
        end)

        -- Store ring ref for deselect
        preset.ring = ring
        preset.btn  = cb
    end

    -- Rebuild click to handle ring deselect properly
    for i, preset in ipairs(colorPresets) do
        preset.btn.MouseButton1Click:Connect(function()
            Config.HighlightColor = preset.c
            previewSwatch.BackgroundColor3 = preset.c
            UpdateAllESPColor()
            for _, p2 in ipairs(colorPresets) do
                p2.ring.Transparency = (p2 == preset) and 0 or 1
            end
        end)
    end

    cy = cy + 62 + 8

    -- ===== ESP TOGGLE BUTTON =====
    local espBtn = Instance.new("TextButton"); espBtn.Size = UDim2.new(1,0,0,40)
    espBtn.Position = UDim2.new(0,0,0,cy); espBtn.BackgroundColor3 = Color3.fromRGB(195,28,28)
    espBtn.BorderSizePixel = 0; espBtn.Text = "  ESP: ACTIVE"
    espBtn.TextColor3 = Color3.fromRGB(255,255,255); espBtn.TextSize = 13
    espBtn.Font = Enum.Font.GothamBold; espBtn.ZIndex = 5; espBtn.Parent = content
    MakeCorner(espBtn,12)
    local btnGrad = Instance.new("UIGradient")
    btnGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(225,35,35)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(145,18,18)),
    }); btnGrad.Rotation = 90; btnGrad.Parent = espBtn

    cy = cy + 40 + 8

    -- ===== SECTION: SPEED WALK =====
    local swLabel = Instance.new("TextLabel"); swLabel.Size = UDim2.new(1,0,0,16)
    swLabel.Position = UDim2.new(0,2,0,cy); swLabel.BackgroundTransparency = 1
    swLabel.Text = "SPEED WALK"; swLabel.TextColor3 = Color3.fromRGB(100,100,120)
    swLabel.TextSize = 8; swLabel.Font = Enum.Font.GothamMedium
    swLabel.TextXAlignment = Enum.TextXAlignment.Left; swLabel.ZIndex = 4; swLabel.Parent = content
    cy = cy + 16

    local swCard = Instance.new("Frame"); swCard.Size = UDim2.new(1,0,0,62)
    swCard.Position = UDim2.new(0,0,0,cy); swCard.BackgroundColor3 = Color3.fromRGB(14,4,4)
    swCard.BorderSizePixel = 0; swCard.ZIndex = 4; swCard.Parent = content
    MakeCorner(swCard,13); MakeStroke(swCard, Color3.fromRGB(255,35,35),1,0.65)

    -- Title + toggle button
    local swTitle = Instance.new("TextLabel"); swTitle.Size = UDim2.new(0,120,0,18)
    swTitle.Position = UDim2.new(0,12,0,8); swTitle.BackgroundTransparency = 1
    swTitle.Text = "WALK SPEED"; swTitle.TextColor3 = Color3.fromRGB(200,200,215)
    swTitle.TextSize = 10; swTitle.Font = Enum.Font.GothamBold
    swTitle.TextXAlignment = Enum.TextXAlignment.Left; swTitle.ZIndex = 5; swTitle.Parent = swCard

    -- Toggle ON/OFF button
    local swToggle = Instance.new("TextButton"); swToggle.Size = UDim2.new(0,52,0,18)
    swToggle.Position = UDim2.new(1,-64,0,9); swToggle.BackgroundColor3 = Color3.fromRGB(40,40,55)
    swToggle.Text = "OFF"; swToggle.TextColor3 = Color3.fromRGB(150,150,170)
    swToggle.TextSize = 8; swToggle.Font = Enum.Font.GothamBold
    swToggle.BorderSizePixel = 0; swToggle.ZIndex = 6; swToggle.Parent = swCard
    MakeCorner(swToggle,5); MakeStroke(swToggle, Color3.fromRGB(100,100,130),1,0.4)

    -- Multiplier label (x1.0, x1.5, dst)
    local swValLabel = Instance.new("TextLabel"); swValLabel.Size = UDim2.new(0,60,0,14)
    swValLabel.Position = UDim2.new(1,-72,0,38); swValLabel.BackgroundTransparency = 1
    swValLabel.Text = "x1.0"; swValLabel.TextColor3 = Color3.fromRGB(255,80,80)
    swValLabel.TextSize = 9; swValLabel.Font = Enum.Font.GothamBold
    swValLabel.TextXAlignment = Enum.TextXAlignment.Right; swValLabel.ZIndex = 5; swValLabel.Parent = swCard

    local swTrackBg = Instance.new("Frame"); swTrackBg.Size = UDim2.new(1,-24,0,6)
    swTrackBg.Position = UDim2.new(0,12,0,38); swTrackBg.BackgroundColor3 = Color3.fromRGB(40,12,12)
    swTrackBg.BorderSizePixel = 0; swTrackBg.ZIndex = 5; swTrackBg.Parent = swCard; MakeCorner(swTrackBg,3)

    local swTrackFill = Instance.new("Frame"); swTrackFill.BackgroundColor3 = Color3.fromRGB(220,35,35)
    swTrackFill.BorderSizePixel = 0; swTrackFill.ZIndex = 6; swTrackFill.Parent = swTrackBg; MakeCorner(swTrackFill,3)

    local swThumb = Instance.new("Frame"); swThumb.Size = UDim2.new(0,14,0,14)
    swThumb.AnchorPoint = Vector2.new(0.5,0.5); swThumb.BackgroundColor3 = Color3.fromRGB(255,255,255)
    swThumb.BorderSizePixel = 0; swThumb.ZIndex = 7; swThumb.Parent = swTrackBg; MakeCorner(swThumb,7)
    MakeStroke(swThumb, Color3.fromRGB(220,35,35),2,0)

    -- Range multiplier: 1.0x sampai 10.0x
    local MIN_MULT, MAX_MULT = 1.0, 10.0
    local swMultiplier = 1.0
    local swEnabled    = false
    local swBaseSpeed  = nil  -- diisi saat toggle ON pertama kali

    -- Update visual slider saja (tanpa apply speed)
    local function RefreshSliderVisual(mult)
        local t = (mult - MIN_MULT) / (MAX_MULT - MIN_MULT)
        swTrackFill.Size = UDim2.new(t, 0, 1, 0)
        swThumb.Position = UDim2.new(t, 0, 0.5, 0)
        swValLabel.Text  = "x" .. string.format("%.1f", mult)
    end
    RefreshSliderVisual(1.0)

    -- Update visual toggle saja
    local function RefreshToggleVisual()
        for _, c in ipairs(swToggle:GetChildren()) do
            if c:IsA("UIStroke") then c:Destroy() end
        end
        if swEnabled then
            swToggle.Text = "ON"
            swToggle.BackgroundColor3 = Color3.fromRGB(30,100,50)
            swToggle.TextColor3 = Color3.fromRGB(255,255,255)
            MakeStroke(swToggle, Color3.fromRGB(50,220,100),1,0.4)
        else
            swToggle.Text = "OFF"
            swToggle.BackgroundColor3 = Color3.fromRGB(40,40,55)
            swToggle.TextColor3 = Color3.fromRGB(150,150,170)
            MakeStroke(swToggle, Color3.fromRGB(100,100,130),1,0.4)
        end
    end

    -- Terapkan WalkSpeed ke humanoid berdasarkan state saat ini
    local function ApplySpeed()
        local character = LocalPlayer.Character
        if not character then return end
        local hum = character:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if swEnabled and swBaseSpeed then
            hum.WalkSpeed = swBaseSpeed * swMultiplier
        elseif swBaseSpeed then
            hum.WalkSpeed = swBaseSpeed
        end
        -- jika swBaseSpeed nil (belum pernah ON), tidak ubah apapun
    end

    -- Toggle ON/OFF
    swToggle.MouseButton1Click:Connect(function()
        local character = LocalPlayer.Character
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        if not hum then return end  -- karakter belum ada, abaikan

        if not swEnabled then
            -- Aktifkan: simpan speed asli baru sekarang
            swBaseSpeed = hum.WalkSpeed
            swEnabled   = true
            hum.WalkSpeed = swBaseSpeed * swMultiplier
        else
            -- Nonaktifkan: kembalikan ke speed asli
            swEnabled = false
            if swBaseSpeed then hum.WalkSpeed = swBaseSpeed end
        end
        RefreshToggleVisual()
    end)

    -- Slider geser: ubah multiplier dan apply jika ON
    local function SetMultSlider(mult)
        swMultiplier = math.clamp(math.floor(mult * 10 + 0.5) / 10, MIN_MULT, MAX_MULT)
        RefreshSliderVisual(swMultiplier)
        ApplySpeed()
    end

    -- Terapkan speed tiap karakter respawn
    LocalPlayer.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        task.wait(0.5)  -- beri waktu map set speed default-nya
        swBaseSpeed = hum.WalkSpeed
        if swEnabled then
            hum.WalkSpeed = swBaseSpeed * swMultiplier
        end
    end)

    local swDragging = false
    local swAbsPos, swAbsSize

    local function UpdateSwSlider(mouseX)
        if not swAbsPos then return end
        local rel = math.clamp((mouseX - swAbsPos.X) / swAbsSize.X, 0, 1)
        SetMultSlider(MIN_MULT + rel * (MAX_MULT - MIN_MULT))
    end

    swTrackBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            swDragging = true
            swAbsPos  = swTrackBg.AbsolutePosition
            swAbsSize = swTrackBg.AbsoluteSize
            UpdateSwSlider(input.Position.X)
        end
    end)
    swThumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            swDragging = true
            swAbsPos  = swTrackBg.AbsolutePosition
            swAbsSize = swTrackBg.AbsoluteSize
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if swDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateSwSlider(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            swDragging = false
        end
    end)

    cy = cy + 62

    -- ===== STATE =====
    local espOn = true
    local panelVisible = true
    local minimized    = false
    local panicMode    = false
    local FULL_H       = PH
    local MINI_H       = HEADER_H + 2

    -- ===== UPDATE DISPLAY =====
    updateDisplay = function(count)
        bigNum.Text = tostring(count)
        bigNum.TextColor3 = count > 0 and Color3.fromRGB(255,55,55) or Color3.fromRGB(70,70,90)
    end

    -- ===== ESP TOGGLE =====
    local function setESPOn(on)
        espOn = on
        Config.ShowESP = on
        if on then
            espBtn.Text = "  ESP: ACTIVE"
            btnGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0,Color3.fromRGB(225,35,35)),
                ColorSequenceKeypoint.new(1,Color3.fromRGB(145,18,18)),
            })
            liveDot.BackgroundColor3 = Color3.fromRGB(60,240,100)
            liveTxt.TextColor3       = Color3.fromRGB(60,240,100)
            RefreshESP()
        else
            espBtn.Text = "  ESP: INACTIVE"
            btnGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0,Color3.fromRGB(45,45,55)),
                ColorSequenceKeypoint.new(1,Color3.fromRGB(28,28,38)),
            })
            liveDot.BackgroundColor3 = Color3.fromRGB(180,45,45)
            liveTxt.TextColor3       = Color3.fromRGB(180,45,45)
            ClearESP()
        end
    end

    espBtn.MouseButton1Click:Connect(function() setESPOn(not espOn) end)
    espBtn.MouseEnter:Connect(function()
        TweenService:Create(espBtn, TweenInfo.new(0.12), {BackgroundTransparency=0.25}):Play()
    end)
    espBtn.MouseLeave:Connect(function()
        TweenService:Create(espBtn, TweenInfo.new(0.12), {BackgroundTransparency=0}):Play()
    end)

    -- ===== MINIMIZE =====
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        content.Visible = not minimized
        minBtn.Text = minimized and "+" or "–"
        TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, PW, 0, minimized and MINI_H or FULL_H)
        }):Play()
    end)

    -- ===== V KEY: TOGGLE VISIBILITY =====
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.V then
            panelVisible = not panelVisible
            main.Visible = panelVisible
            badgeLabel.Text = panelVisible and "[ V ]  Toggle Panel" or "[ V ]  Show Panel"
        end

        -- ===== P KEY: PANIC MODE =====
        if input.KeyCode == Enum.KeyCode.P then
            panicMode = not panicMode
            if panicMode then
                -- Sembunyikan semua seketika
                ClearESP()
                Config.ShowESP = false
                screenGui.Enabled = false
            else
                -- Pulihkan kembali
                screenGui.Enabled = true
                Config.ShowESP = espOn
                if espOn then RefreshESP() end
            end
        end
    end)

    -- ===== DRAG (header) =====
    local dragging, dragStart, startPos = false, nil, nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if sliderDragging then return end
            dragging  = true
            dragStart = input.Position
            startPos  = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)

    -- ===== PULSE LIVE DOT =====
    spawn(function()
        while screenGui and screenGui.Parent do
            if espOn then
                TweenService:Create(liveDot, TweenInfo.new(0.7,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundTransparency=0.55}):Play()
                wait(0.7)
                TweenService:Create(liveDot, TweenInfo.new(0.7,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundTransparency=0}):Play()
                wait(0.7)
            else
                wait(1)
            end
        end
    end)
end

-- ========== INIT ==========
CreateModernGUI()
CleanCache()

local lastRefresh = 0
local lastCleanup = 0

RunService.RenderStepped:Connect(function()
    if not Config.ShowESP then return end
    local now = tick()
    if now - lastRefresh >= Config.UpdateSpeed then
        lastRefresh = now
        RefreshESP()
    end
    if now - lastCleanup >= 60 then
        lastCleanup = now
        CleanCache()
    end
end)

print("=" .. string.rep("=", 55))
print("ESP MOUNT OBSCURA - ULTRA PREMIUM v3")
print("")
print("  [V]      = Toggle panel show/hide")
print("  [P]      = PANIC MODE - sembunyikan semua seketika")
print("  [-/+]    = Minimize/expand panel")
print("  Slider   = Atur scan radius 100-500 studs")
print("  Speed    = Atur walk speed 8-100")
print("  Color    = 6 preset warna ESP box")
print("  Drag     = Header untuk pindah posisi")
print("=" .. string.rep("=", 55))
