-- YBA-only wrapper that auto-queues main script on teleport when possible
local TARGET_PLACE = 2809202155
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer or Players:WaitForChild("LocalPlayer", 5)
if not LocalPlayer then return end

local function safe_pcall(f, ...)
    local ok, res = pcall(f, ...)
    if not ok then
        -- you can uncomment for debugging in executor consoles:
        -- warn("[YBA-Wrapper] error:", res)
    end
    return ok, res
end

local function queue_for_teleport(code)
    -- Try common exploit/loader queue functions so code runs automatically after teleport.
    -- This tries multiple known names used by executors (syn, KRNL, etc).
    local tried = {}

    -- 1) syn (Synapse)
    if syn and type(syn.queue_on_teleport) == "function" then
        safe_pcall(syn.queue_on_teleport, code)
        return true
    end

    -- 2) global queue_on_teleport
    if type(queue_on_teleport) == "function" then
        safe_pcall(queue_on_teleport, code)
        return true
    end

    -- 3) common alternative global names
    if type(queueonteleport) == "function" then
        safe_pcall(queueonteleport, code)
        return true
    end

    -- 4) some executors expose it under different tables
    local possible_tables = {getgenv and getgenv() or nil, _G}
    for _, tbl in ipairs(possible_tables) do
        if type(tbl) == "table" then
            if type(tbl.queue_on_teleport) == "function" then
                safe_pcall(tbl.queue_on_teleport, code)
                return true
            end
            if type(tbl.queueonteleport) == "function" then
                safe_pcall(tbl.queueonteleport, code)
                return true
            end
        end
    end

    -- 5) syn/other synonyms check inside global environment table names (defensive)
    if type(getfenv) == "function" then
        local ok, env = pcall(function() return getfenv() end)
        if ok and type(env) == "table" then
            if type(env.queue_on_teleport) == "function" then
                safe_pcall(env.queue_on_teleport, code)
                return true
            end
        end
    end

    -- if none found, return false (can't queue automatically)
    return false
end

-- The actual code we want to run after teleport (string)
local main_code = [=[
-- Whats good my dear skidders

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local BACK_DISTANCE = 2
local BACK_HEIGHT = 0.5
local PLAYER_HEIGHT = 20
local ALIGN_RESPONSIVENESS = 250
local ALIGN_MAX_FORCE = 1e7
local CHECK_SCAN_INTERVAL = 1.0
local SMOOTH_FALLBACK_ALPHA = 0.85

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StandStickerGui"
screenGui.Parent = game.CoreGui
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 340, 0, 200)
frame.Position = UDim2.new(0.5, -170, 0.5, -100)
frame.BackgroundColor3 = Color3.fromRGB(36,36,36)
frame.BorderSizePixel = 0
frame.Parent = screenGui
local title = Instance.new("TextButton")
title.Size = UDim2.new(1, 0, 0, 32)
title.Position = UDim2.new(0,0,0,0)
title.BackgroundColor3 = Color3.fromRGB(26,26,26)
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Text = "Diabo Stand Sticker"
title.Font = Enum.Font.SourceSansBold
title.TextSize = 17
title.Parent = frame
local textBox = Instance.new("TextBox")
textBox.Size = UDim2.new(1, -12, 0, 28)
textBox.Position = UDim2.new(0, 6, 0, 40)
textBox.PlaceholderText = "ENTER Player/NPC Name"
textBox.BackgroundColor3 = Color3.fromRGB(58,58,58)
textBox.TextColor3 = Color3.fromRGB(255,255,255)
textBox.Font = Enum.Font.SourceSans
textBox.TextSize = 15
textBox.ClearTextOnFocus = false
textBox.Parent = frame
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0.48, -6, 0, 36)
toggleButton.Position = UDim2.new(0, 6, 0, 76)
toggleButton.Text = "Sticker: Off"
toggleButton.BackgroundColor3 = Color3.fromRGB(95,95,95)
toggleButton.TextColor3 = Color3.fromRGB(255,255,255)
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextSize = 15
toggleButton.Parent = frame
local viewButton = Instance.new("TextButton")
viewButton.Size = UDim2.new(0.48, -6, 0, 36)
viewButton.Position = UDim2.new(0.52, 0, 0, 76)
viewButton.Text = "View Stand: Off"
viewButton.BackgroundColor3 = Color3.fromRGB(95,95,95)
viewButton.TextColor3 = Color3.fromRGB(255,255,255)
viewButton.Font = Enum.Font.SourceSansBold
viewButton.TextSize = 15
viewButton.Parent = frame
local methodButton = Instance.new("TextButton")
methodButton.Size = UDim2.new(0.48, -6, 0, 36)
methodButton.Position = UDim2.new(0, 6, 0, 120)
methodButton.Text = "Method: normal"
methodButton.BackgroundColor3 = Color3.fromRGB(95,95,95)
methodButton.TextColor3 = Color3.fromRGB(255,255,255)
methodButton.Font = Enum.Font.SourceSansBold
methodButton.TextSize = 15
methodButton.Parent = frame
local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -12, 0, 18)
infoLabel.Position = UDim2.new(0,6,0,164)
infoLabel.BackgroundTransparency = 1
infoLabel.TextColor3 = Color3.fromRGB(210,210,210)
infoLabel.Text = string.format("Back: %d Height: %.1f | Align mode (fallback: Retard)", BACK_DISTANCE, BACK_HEIGHT)
infoLabel.Font = Enum.Font.SourceSans
infoLabel.TextSize = 13
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.Parent = frame

local dragging, dragStart, startPos = false, Vector2.new(), UDim2.new()
title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

local function notify(t, m)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = t, Text = m, Duration = 4})
    end)
end

local scanTimer = 0
local modelCache = {}
local function isCharacterModel(m)
    if not m or not m:IsA("Model") then return false end
    return m:FindFirstChild("Humanoid") and m:FindFirstChild("HumanoidRootPart")
end
local function rebuildModelCache()
    modelCache = {}
    -- NPCs / world models in workspace
    for _, child in ipairs(workspace:GetChildren()) do
        if isCharacterModel(child) then
            table.insert(modelCache, child)
        else
            for _, c2 in ipairs(child:GetChildren()) do
                if isCharacterModel(c2) then table.insert(modelCache, c2) end
            end
        end
    end
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= player and pl.Character and isCharacterModel(pl.Character) then
            table.insert(modelCache, pl.Character)
        end
    end
end
rebuildModelCache()
workspace.ChildAdded:Connect(function(c)
    if isCharacterModel(c) then table.insert(modelCache, c) else
        for _, c2 in ipairs(c:GetChildren()) do if isCharacterModel(c2) then table.insert(modelCache, c2) end end
    end
end)
workspace.ChildRemoved:Connect(function(c)
    for i = #modelCache, 1, -1 do if modelCache[i] == c then table.remove(modelCache, i) end end
end)
Players.PlayerAdded:Connect(function(pl)
    pl.CharacterAdded:Connect(function(ch)
        if isCharacterModel(ch) then table.insert(modelCache, ch) end
    end)
end)
Players.PlayerRemoving:Connect(function(pl)
    if pl.Character then
        for i = #modelCache, 1, -1 do if modelCache[i] == pl.Character then table.remove(modelCache, i) end end
    end
end)

local function findClosestByName(name)
    if not name or name == "" then return nil end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local rootPos = root.Position
    local lower = name:lower()
    local closest, minD = nil, math.huge
    -- check players first (so exact player names are preferred)
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= player and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
            local match = false
            if pl.Name:lower():find(lower) then match = true end
            if pl.DisplayName and pl.DisplayName:lower():find(lower) then match = true end
            if match then
                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                local hum = pl.Character:FindFirstChild("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    local d = (hrp.Position - rootPos).Magnitude
                    if d < minD then minD, closest = d, pl.Character end
                end
            end
        end
    end
    for _, model in ipairs(modelCache) do
        if model and model.Parent and model ~= player.Character then
            if model.Name:lower():find(lower) then
                local hrp = model:FindFirstChild("HumanoidRootPart")
                local hum = model:FindFirstChild("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    local d = (hrp.Position - rootPos).Magnitude
                    if d < minD then minD, closest = d, model end
                end
            end
        end
    end
    return closest
end

local function getStand()
    local ch = player.Character
    if not ch then return nil end
    for _, child in ipairs(ch:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") and child ~= ch then
            return child
        end
    end
    return nil
end

local activeAligns = {}
local currentTargetForEntity = {}
local function cleanupAlignFor(entity)
    if not entity then return end
    local hrp = entity:FindFirstChild("HumanoidRootPart")
    if hrp then
        for _, c in ipairs(hrp:GetChildren()) do
            if tostring(c.Name):match("^Stick_") then
                c:Destroy()
            end
        end
    end
    activeAligns[entity] = nil
    currentTargetForEntity[entity] = nil
end
local function createAlignsFor(entity, targetHRP, stickMode)
    if not entity or not targetHRP then return nil end
    cleanupAlignFor(entity)
    local hrp = entity:FindFirstChild("HumanoidRootPart")
    if not hrp then
        hrp = entity:FindFirstChild("Torso") or entity:FindFirstChild("UpperTorso")
    end
    if not hrp then
        local ok
        ok, hrp = pcall(function() return entity:WaitForChild("HumanoidRootPart", 0.5) end)
        if not ok then hrp = nil end
    end
    if not hrp then return nil end
    local offset = Vector3.new(0,0,0)
    if stickMode == "back" then
        offset = Vector3.new(0, BACK_HEIGHT, -BACK_DISTANCE)
    end
    local attA = Instance.new("Attachment")
    attA.Name = "Stick_AttA"
    attA.Parent = hrp
    attA.Position = Vector3.new(0,0,0)
    local attB = Instance.new("Attachment")
    attB.Name = "Stick_AttB"
    attB.Parent = targetHRP
    attB.Position = offset -- initial
    local alignPos = Instance.new("AlignPosition")
    alignPos.Name = "Stick_AlignPos"
    alignPos.Attachment0 = attA
    alignPos.Attachment1 = attB
    alignPos.MaxForce = ALIGN_MAX_FORCE
    alignPos.Responsiveness = ALIGN_RESPONSIVENESS
    alignPos.RigidityEnabled = false
    alignPos.Parent = hrp
    local alignOri = Instance.new("AlignOrientation")
    alignOri.Name = "Stick_AlignOri"
    alignOri.Attachment0 = attA
    alignOri.Attachment1 = attB
    alignOri.MaxTorque = ALIGN_MAX_FORCE
    alignOri.Responsiveness = ALIGN_RESPONSIVENESS
    alignOri.Parent = hrp
    activeAligns[entity] = {attA = attA, attB = attB, alignPos = alignPos, alignOri = alignOri, stickMode = stickMode}
    currentTargetForEntity[entity] = targetHRP
    if entity == player.Character then
        pcall(function() notify("Sticker", "Player align applied (mode="..tostring(stickMode)..")") end)
    end
    return activeAligns[entity]
end

local function smoothFallback(entity, targetHRP, stickMode, isAlive)
    local hrp = entity and entity:FindFirstChild("HumanoidRootPart")
    if not hrp or not targetHRP then return end
    local desiredPos
    if stickMode == "back" then
        desiredPos = targetHRP.Position - targetHRP.CFrame.LookVector * BACK_DISTANCE + Vector3.new(0, BACK_HEIGHT, 0)
    elseif stickMode == "up" then
        local height = isAlive and -PLAYER_HEIGHT or PLAYER_HEIGHT
        desiredPos = targetHRP.Position + Vector3.new(0, height, 0)
    else
        return
    end
    local look = -Vector3.new(targetHRP.CFrame.LookVector.X, 0, targetHRP.CFrame.LookVector.Z).Unit
    local yaw = math.atan2(look.X, look.Z)
    local desiredCFrame = CFrame.new(desiredPos) * CFrame.Angles(0, yaw, 0)
    hrp.CFrame = hrp.CFrame:Lerp(desiredCFrame, SMOOTH_FALLBACK_ALPHA)
end

local noclipEnabled = false
local originalCollides = {}
local noclipConn = nil

local function enforceNoclipForCharacter(char)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            originalCollides[part] = part.CanCollide
            part.CanCollide = false
        end
    end
end

local function enableNoclip()
    if noclipEnabled then return end
    local char = player.Character
    if not char or not char.Parent then
        -- set flag and wait for character added to apply
        noclipEnabled = true
        return
    end
    originalCollides = {}
    enforceNoclipForCharacter(char)
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    noclipConn = RunService.Stepped:Connect(function()
        local c = player.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then
                if p.CanCollide then p.CanCollide = false end
            end
        end
    end)
    noclipEnabled = true
end

local function disableNoclip()
    if not noclipEnabled then return end
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    for part, val in pairs(originalCollides) do
        if part and part.Parent and part:IsA("BasePart") then
            pcall(function() part.CanCollide = val end)
        end
    end
    originalCollides = {}
    noclipEnabled = false
end

local viewing = false
local prevCameraSubject = nil
local prevCameraType = nil
local viewingStand = nil

local orbit = {
    yaw = 0,
    pitch = 0,
    radius = 8,
    minRadius = 2,
    maxRadius = 60,
    sensitivity = 0.0035,
    pitchMin = -math.pi/2 + 0.1,
    pitchMax = math.pi/2 - 0.1,
    dragging = false,
    inputChangedConn = nil,
    inputBeganConn = nil,
    inputEndedConn = nil,
    renderConn = nil
}

local function enableOrbitCamera(stand)
    if not stand or not stand:FindFirstChild("HumanoidRootPart") then
        notify("View Stand", "Can't view: stand missing HRP.")
        return
    end
    viewingStand = stand
    prevCameraSubject = camera.CameraSubject
    prevCameraType = camera.CameraType
    local standPos = stand.HumanoidRootPart.Position
    local camCF = camera.CFrame
    local toStand = (camCF.Position - standPos)
    orbit.radius = math.clamp(toStand.Magnitude, orbit.minRadius, orbit.maxRadius)
    local dir = toStand.Unit
    local pitch = math.asin(math.clamp(dir.Y, -1, 1)) * -1 -- invert so positive pitch raises camera
    local yaw = math.atan2(dir.X, dir.Z)
    orbit.yaw = yaw
    orbit.pitch = pitch
    camera.CameraType = Enum.CameraType.Scriptable
    orbit.inputBeganConn = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            orbit.dragging = true
            UserInputService.MouseIconEnabled = false
        end
    end)
    orbit.inputEndedConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            orbit.dragging = false
            UserInputService.MouseIconEnabled = true
        end
    end)
    orbit.inputChangedConn = UserInputService.InputChanged:Connect(function(input, processed)
        if input.UserInputType == Enum.UserInputType.MouseMovement and orbit.dragging then
            orbit.yaw = orbit.yaw - input.Delta.X * orbit.sensitivity
            orbit.pitch = math.clamp(orbit.pitch - input.Delta.Y * orbit.sensitivity, orbit.pitchMin, orbit.pitchMax)
        elseif input.UserInputType == Enum.UserInputType.MouseWheel then
            orbit.radius = math.clamp(orbit.radius - input.Position.Z, orbit.minRadius, orbit.maxRadius)
        end
    end)
    orbit.renderConn = RunService.RenderStepped:Connect(function()
        if not viewing or not viewingStand or not viewingStand.Parent then return end
        local hrp = viewingStand:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local standPos = hrp.Position
        local rot = CFrame.Angles(orbit.pitch, orbit.yaw, 0)
        local offset = rot:VectorToWorldSpace(Vector3.new(0, 0, orbit.radius))
        local camPos = standPos + offset
        camera.CFrame = CFrame.new(camPos, standPos)
    end)
    notify("View Stand", "NOW VIEWING YOU SUCKASS STAND YOU TALENTLESS BITCH")
    viewing = true
end

local function disableOrbitCamera()
    viewing = false
    viewingStand = nil
    if orbit.inputChangedConn then orbit.inputChangedConn:Disconnect() orbit.inputChangedConn = nil end
    if orbit.inputBeganConn then orbit.inputBeganConn:Disconnect() orbit.inputBeganConn = nil end
    if orbit.inputEndedConn then orbit.inputEndedConn:Disconnect() orbit.inputEndedConn = nil end
    if orbit.renderConn then orbit.renderConn:Disconnect() orbit.renderConn = nil end
    -- restore camera subject/type
    pcall(function()
        if prevCameraSubject then camera.CameraSubject = prevCameraSubject end
        if prevCameraType then camera.CameraType = prevCameraType end
    end)
    UserInputService.MouseIconEnabled = true
    notify("View Stand", "Camera restored.")
end

local function enableView(stand)
    if not stand or not stand:FindFirstChild("Humanoid") and not stand:FindFirstChild("HumanoidRootPart") then
        notify("View Stand", "ARE WE DEADASS? EQUIPT YOUR FUCKING STAND YOU FUCKING CUNT")
        return
    end
    if viewing then return end
    enableOrbitCamera(stand)
end
local function disableView()
    if not viewing then return end
    disableOrbitCamera()
    viewButton.Text = "View Stand: Off"
end

local stickerEnabled = false
local method = "normal"

toggleButton.MouseButton1Click:Connect(function()
    stickerEnabled = not stickerEnabled
    toggleButton.Text = "Sticker: " .. (stickerEnabled and "On" or "Off")
    if stickerEnabled then
        notify("YBA Script", "Sticker enabled for: ".. (textBox.Text ~= "" and textBox.Text or "<empty>"))
        -- If method is up and target exists, ensure noclip is applied
        if method == "up" then
            enableNoclip()
        end
    else
        notify("YBA Script", "Sticker disabled")
        for entity, _ in pairs(activeAligns) do cleanupAlignFor(entity) end
        disableNoclip()
    end
end)

viewButton.MouseButton1Click:Connect(function()
    if viewing then
        disableView()
        viewButton.Text = "View Stand: Off"
        return
    end
    local stand = getStand()
    if not stand then
        notify("View Stand", "ARE WE DEADASS? EQUIPT YOUR FUCKING STAND YOU FUCKING CUNT")
        return
    end
    enableView(stand)
    viewButton.Text = "View Stand: On"
end)

methodButton.MouseButton1Click:Connect(function()
    method = (method == "normal") and "up" or "normal"
    methodButton.Text = "Method: " .. method
    notify("YBA Script", "Method changed to: " .. method)
    if stickerEnabled then
        for entity, _ in pairs(activeAligns) do cleanupAlignFor(entity) end
    end
    if method ~= "up" then
        disableNoclip()
    end
    if method == "up" and stickerEnabled and not viewing then
        local stand = getStand()
        if stand then
            enableView(stand)
            viewButton.Text = "View Stand: On"
        end
    end
end)

RunService.Heartbeat:Connect(function(dt)
    scanTimer = scanTimer + dt
    if scanTimer >= CHECK_SCAN_INTERVAL then
        rebuildModelCache()
        scanTimer = 0
    end
    if viewing then
        if not viewingStand or not viewingStand.Parent or not viewingStand:FindFirstChild("HumanoidRootPart") then
            disableView()
            viewButton.Text = "View Stand: Off"
        end
    end
    if not stickerEnabled then return end
    local name = textBox.Text
    if not name or name == "" then return end
    local stand = getStand()
    if not stand then
        return
    end
    local target = findClosestByName(name)
    if not target then
        return
    end
    local targetHRP = target:FindFirstChild("HumanoidRootPart")
    local targetHum = target:FindFirstChild("Humanoid")
    local isAlive = targetHum and targetHum.Health > 0
    if not targetHRP or not targetHum then
        for entity,_ in pairs(activeAligns) do cleanupAlignFor(entity) end
        if method == "up" then enableNoclip() else disableNoclip() end
        return
    end
    local myChar = player.Character
    if stand and currentTargetForEntity[stand] ~= targetHRP then
        local ok, res = pcall(createAlignsFor, stand, targetHRP, "back")
        if not ok or not res then
            cleanupAlignFor(stand)
        end
    end
    if method == "up" then
        if currentTargetForEntity[myChar] ~= targetHRP then
            local ok, res = pcall(createAlignsFor, myChar, targetHRP, "up")
            if not ok or not res then
                cleanupAlignFor(myChar)
            end
        end
    else
        cleanupAlignFor(myChar)
        disableNoclip()
    end
    for entity, alignData in pairs(activeAligns) do
        if alignData and alignData.attB and alignData.attB.Parent == targetHRP then
            local desiredWorldPos
            if alignData.stickMode == "back" then
                desiredWorldPos = targetHRP.Position - targetHRP.CFrame.LookVector * BACK_DISTANCE + Vector3.new(0, BACK_HEIGHT, 0)
            elseif alignData.stickMode == "up" then
                local height = isAlive and -PLAYER_HEIGHT or PLAYER_HEIGHT
                desiredWorldPos = targetHRP.Position + Vector3.new(0, height, 0)
            end
            if desiredWorldPos then
                local localPos = targetHRP.CFrame:PointToObjectSpace(desiredWorldPos)
                alignData.attB.Position = localPos
            end
        else
            pcall(smoothFallback, entity, targetHRP, alignData.stickMode, isAlive)
        end
    end
    if method == "up" and isAlive then
        enableNoclip()
    else
        if method ~= "up" then
            disableNoclip()
        end
    end
end)

player.CharacterRemoving:Connect(function()
    for entity,_ in pairs(activeAligns) do cleanupAlignFor(entity) end
    if viewing then disableView() end
end)

player.CharacterAdded:Connect(function(ch)
    if noclipEnabled then
        spawn(function()
            local hrp = ch:WaitForChild("HumanoidRootPart", 5)
            if hrp then
                pcall(enableNoclip)
            end
        end)
    end
end)

title.MouseButton2Click:Connect(function()
    screenGui.Enabled = not screenGui.Enabled
end)

]=]

if game.PlaceId == TARGET_PLACE then
    -- In correct place: load immediately
    local ok, err = pcall(function()
        -- Запускаем оригинальный скрипт из строки
        local func = loadstring(main_code)
        if func then func() end
    end)
    if not ok then
        warn("[YBA-Wrapper] Failed to load main script: "..tostring(err))
    end

    -- ══════════════════════════════════════════
    --   PILOT v4 — AlignPosition как метод UP
    --   Стенд притягивается к якорю на земле.
    --   Якорь следует за XZ игрока каждый кадр.
    --   Игрок только ~20 юнитов под землёй (как в UP).
    --   Скиллы работают, камера на стенде.
    -- ══════════════════════════════════════════

    local RunService       = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace        = game:GetService("Workspace")
    local Camera           = Workspace.CurrentCamera

    -- Те же константы что в оригинальном StandStickScript
    local ALIGN_FORCE      = 1e7
    local ALIGN_RESP       = 250
    local UNDER_OFFSET     = -20   -- игрок 20 юнитов под якорём (как PLAYER_HEIGHT в UP)
    local ANCHOR_HEIGHT    = 5.3   -- высота стенда над землёй (чуть-чуть повыше)

    local pilotActive    = false
    local pilotConn      = nil
    local pilotRenderConn = nil
    local noclipConn     = nil
    local pilotAnchor    = nil   -- якорь для стенда (поверхность)
    local pilotPlayerAnchor = nil -- якорь для игрока (под землёй)
    local alignObjs      = {}

    local prevCamSubject = nil
    local prevCamType    = nil

    local orbit = {
        yaw = 0, pitch = math.rad(20),
        radius = 12, minR = 3, maxR = 60,
        sens = 0.004,
        pitchMin = -math.pi/2 + 0.05,
        pitchMax  =  math.pi/2 - 0.05,
        dragging = false,
        locked = false,
        c1 = nil, c2 = nil, c3 = nil,
    }

    local function getHRP()
        local char = LocalPlayer.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    -- Стенд = дочерняя Model персонажа с HumanoidRootPart (как getStand() в оригинале)
    local function getStand()
        local char = LocalPlayer.Character
        if not char then return nil end
        for _, c in ipairs(char:GetChildren()) do
            if c:IsA("Model") and c:FindFirstChild("HumanoidRootPart") then
                return c
            end
        end
        return nil
    end

    -- Y поверхности по XZ
    local function getGroundY(x, z, excludes)
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = excludes or {}
        params.FilterType = Enum.RaycastFilterType.Exclude
        
        local startY = 800
        local hrp = getHRP()
        if hrp then
            -- Чтобы не попадать в невидимые потолки YBA,
            -- пускаем луч чуть выше текущей позиции игрока (если он не слишком глубоко под землёй)
            local currentY = hrp.Position.Y
            if currentY > -50 then
                startY = currentY + 100
            else
                startY = 200
            end
        end

        local res = Workspace:Raycast(Vector3.new(x, startY, z), Vector3.new(0, -1000, 0), params)
        if res then
            -- Если мы попали во что-то прозрачное (невидимая стена/потолок), попробуем ещё ниже
            if res.Instance and res.Instance.Transparency >= 1 then
                local res2 = Workspace:Raycast(Vector3.new(x, res.Position.Y - 5, z), Vector3.new(0, -1000, 0), params)
                return res2 and res2.Position.Y or res.Position.Y
            end
            return res.Position.Y
        end
        return hrp and hrp.Position.Y or 0
    end

    -- Создаёт AlignPosition + Attachment как в оригинальном скрипте
    local function attachAlign(entityHRP, anchorPart, yOffset)
        local attA = Instance.new("Attachment")
        attA.Name     = "Pilot_AttA"
        attA.Position = Vector3.new(0, 0, 0)
        attA.Parent   = entityHRP

        local attB = Instance.new("Attachment")
        attB.Name     = "Pilot_AttB"
        attB.Position = Vector3.new(0, yOffset, 0)
        attB.Parent   = anchorPart

        local ap = Instance.new("AlignPosition")
        ap.Name          = "Pilot_AlignPos"
        ap.Attachment0   = attA
        ap.Attachment1   = attB
        ap.MaxForce      = ALIGN_FORCE
        ap.Responsiveness = ALIGN_RESP
        ap.RigidityEnabled = false
        ap.Parent        = entityHRP

        table.insert(alignObjs, attA)
        table.insert(alignObjs, attB)
        table.insert(alignObjs, ap)
    end

    local function cleanAligns()
        for _, obj in ipairs(alignObjs) do
            pcall(function() obj:Destroy() end)
        end
        alignObjs = {}
    end

    local function enableNoclip()
        if noclipConn then return end
        noclipConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then
                        p.CanCollide = false
                    end
                end
            end
            local s = getStand()
            if s then
                for _, p in ipairs(s:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then
                        p.CanCollide = false
                    end
                end
            end
        end)
    end

    local function disableNoclip()
        if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    end
    local function startOrbitCamera(standHRP)
        prevCamSubject = Camera.CameraSubject
        prevCamType    = Camera.CameraType

        local toStand = Camera.CFrame.Position - standHRP.Position
        orbit.radius  = math.clamp(toStand.Magnitude, orbit.minR, orbit.maxR)
        local dir = toStand.Unit
        orbit.pitch = math.asin(math.clamp(dir.Y, -1, 1))
        orbit.yaw   = math.atan2(dir.X, dir.Z)

        Camera.CameraType = Enum.CameraType.Scriptable

        orbit.c1 = UserInputService.InputBegan:Connect(function(inp, proc)
            if proc then return end
            if inp.UserInputType == Enum.UserInputType.MouseButton2 then
                orbit.dragging = true
                UserInputService.MouseIconEnabled = false
            elseif inp.KeyCode == Enum.KeyCode.CapsLock or inp.KeyCode == Enum.KeyCode.LeftShift then
                orbit.locked = not orbit.locked
                if orbit.locked then
                    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                    UserInputService.MouseIconEnabled = false
                else
                    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                    UserInputService.MouseIconEnabled = true
                end
            end
        end)
        orbit.c2 = UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton2 then
                orbit.dragging = false
                UserInputService.MouseIconEnabled = true
            end
        end)
        orbit.c3 = UserInputService.InputChanged:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseMovement and orbit.dragging then
                orbit.yaw   = orbit.yaw   - inp.Delta.X * orbit.sens
                orbit.pitch = math.clamp(
                    orbit.pitch - inp.Delta.Y * orbit.sens,
                    orbit.pitchMin, orbit.pitchMax
                )
            elseif inp.UserInputType == Enum.UserInputType.MouseWheel then
                orbit.radius = math.clamp(orbit.radius - inp.Position.Z * 2, orbit.minR, orbit.maxR)
            end
        end)

        pilotRenderConn = RunService.RenderStepped:Connect(function()
            if not pilotActive then return end
            
            if orbit.locked then
                UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                local delta = UserInputService:GetMouseDelta()
                orbit.yaw = orbit.yaw - delta.X * orbit.sens
                orbit.pitch = math.clamp(orbit.pitch - delta.Y * orbit.sens, orbit.pitchMin, orbit.pitchMax)
            end

            local s = getStand()
            if not s then return end
            local sHRP = s:FindFirstChild("HumanoidRootPart")
            if not sHRP then return end
            local rot    = CFrame.Angles(orbit.pitch, orbit.yaw, 0)
            local offset = rot:VectorToWorldSpace(Vector3.new(0, 0, orbit.radius))
            Camera.CFrame = CFrame.new(sHRP.Position + offset, sHRP.Position)
        end)
    end

    local function stopOrbitCamera()
        if orbit.c1 then orbit.c1:Disconnect() orbit.c1 = nil end
        if orbit.c2 then orbit.c2:Disconnect() orbit.c2 = nil end
        if orbit.c3 then orbit.c3:Disconnect() orbit.c3 = nil end
        if pilotRenderConn then pilotRenderConn:Disconnect() pilotRenderConn = nil end
        orbit.dragging = false
        UserInputService.MouseIconEnabled = true
        pcall(function()
            if prevCamSubject then Camera.CameraSubject = prevCamSubject end
            if prevCamType    then Camera.CameraType    = prevCamType    end
        end)
    end

    local function startPilot()
        if pilotActive then return true end

        local stand   = getStand()
        if not stand then return false end

        local hrp     = getHRP()
        local standHRP = stand:FindFirstChild("HumanoidRootPart")
        if not hrp or not standHRP then return false end

        local px, pz = hrp.Position.X, hrp.Position.Z
        local gY     = getGroundY(px, pz, {LocalPlayer.Character, stand})
        local groundPos = Vector3.new(px, gY + ANCHOR_HEIGHT, pz)

        -- Создаём огромный невидимый пол для игрока под землёй
        pilotFloor = Instance.new("Part")
        pilotFloor.Name = "PilotFloor"
        pilotFloor.Anchored = true
        pilotFloor.CanCollide = true
        pilotFloor.Transparency = 1
        pilotFloor.Size = Vector3.new(10000, 5, 10000)
        pilotFloor.CFrame = CFrame.new(px, gY - 25, pz)
        pilotFloor.Parent = Workspace

        -- Создаём якорь на поверхности
        pilotAnchor               = Instance.new("Part")
        pilotAnchor.Name          = "PilotAnchor"
        pilotAnchor.Anchored      = true
        pilotAnchor.CanCollide    = false
        pilotAnchor.CanTouch      = false
        pilotAnchor.CastShadow    = false
        pilotAnchor.Transparency  = 1
        pilotAnchor.Size          = Vector3.new(1, 1, 1)
        pilotAnchor.CFrame        = CFrame.new(groundPos)
        pilotAnchor.Parent        = Workspace

        -- Стенд → туда где стоял игрок (поверхность)
        pcall(function() standHRP.CFrame = CFrame.new(groundPos) end)

        -- Игрок → на невидимый пол (-20 юнитов от поверхности)
        pcall(function() hrp.CFrame = CFrame.new(px, gY - 20, pz) end)

        -- ВАЖНО: AlignPosition только на стенд!
        attachAlign(standHRP, pilotAnchor, 0)

        enableNoclip() -- Включаем Noclip для стенда и верхней части игрока
        pilotActive = true
        startOrbitCamera(standHRP)

        pilotConn = RunService.Heartbeat:Connect(function()
            if not pilotActive then return end
            if not pilotAnchor then return end

            local myHRP = getHRP()
            if not myHRP then return end

            local mx, mz  = myHRP.Position.X, myHRP.Position.Z
            local newGY   = getGroundY(mx, mz, {LocalPlayer.Character, stand, pilotFloor})

            -- Вычисляем высоту прыжка игрока (относительно невидимого пола)
            local jumpOffset = 0
            if pilotFloor then
                jumpOffset = myHRP.Position.Y - (pilotFloor.Position.Y + 5)
                if jumpOffset < 0.5 then jumpOffset = 0 end -- игнорируем мелкие покачивания при ходьбе
            end

            -- Якорь всегда следует за XZ игрока, и учитывает прыжок
            pilotAnchor.CFrame = CFrame.new(mx, newGY + ANCHOR_HEIGHT + jumpOffset, mz)
            
            -- Если игрок использовал скилл с телепортом (оказался на поверхности или провалился),
            -- либо если рельеф сильно изменился — обновляем пол и возвращаем игрока на него
            if pilotFloor then
                local targetFloorY = newGY - 25
                -- Обновляем высоту пола, если он слишком отстал от поверхности
                if math.abs(pilotFloor.Position.Y - targetFloorY) > 10 then
                    pilotFloor.CFrame = CFrame.new(mx, targetFloorY, mz)
                end
                
                -- Если игрок упал с пола ИЛИ телепортировался высоко (например, скилл вернул на землю)
                -- Лимит увеличен с 15 до 22! Это позволяет делать высокие прыжки (они не будут отменяться),
                -- но всё ещё ловит телепорты на поверхность (поверхность находится на разнице 25+).
                if math.abs(myHRP.Position.Y - pilotFloor.Position.Y) > 22 then
                    myHRP.CFrame = CFrame.new(mx, pilotFloor.Position.Y + 5, mz)
                end
            end
        end)

        return true
    end

    local function stopPilot()
        pilotActive = false
        disableNoclip()
        if pilotConn then pilotConn:Disconnect() pilotConn = nil end
        cleanAligns()
        if pilotAnchor then pilotAnchor:Destroy() pilotAnchor = nil end
        if pilotFloor then pilotFloor:Destroy() pilotFloor = nil end
        stopOrbitCamera()
        
        -- Возвращаем игрока на поверхность
        local myHRP = getHRP()
        if myHRP then
            local mx, mz = myHRP.Position.X, myHRP.Position.Z
            local gY = getGroundY(mx, mz, {LocalPlayer.Character})
            myHRP.CFrame = CFrame.new(mx, gY + 5, mz)
        end
    end

    LocalPlayer.CharacterAdded:Connect(function(newChar)
        if pilotActive then
            stopPilot()
            local hum = newChar:WaitForChild("Humanoid", 5)
            if hum then
                Camera.CameraSubject = hum
                Camera.CameraType    = Enum.CameraType.Custom
            end
        end
    end)

    -- ── GUI ──
    local playerGui  = LocalPlayer:WaitForChild("PlayerGui")
    local pilotGui   = Instance.new("ScreenGui")
    pilotGui.Name    = "YBA_PilotGUI"
    pilotGui.ResetOnSpawn   = false
    pilotGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pilotGui.Parent  = playerGui

    local frame = Instance.new("Frame")
    frame.Size              = UDim2.new(0, 210, 0, 90)
    frame.Position          = UDim2.new(0, 16, 0.5, -45)
    frame.BackgroundColor3  = Color3.fromRGB(15, 15, 25)
    frame.BorderSizePixel   = 0
    frame.Active            = true
    frame.Draggable         = true
    frame.Parent            = pilotGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    -- Полоса заголовка
    local titleBar = Instance.new("Frame")
    titleBar.Size             = UDim2.new(1, 0, 0, 28)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 70)
    titleBar.BorderSizePixel  = 0
    titleBar.Parent           = frame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size               = UDim2.new(1, -10, 1, 0)
    titleLbl.Position           = UDim2.new(0, 10, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text               = "✈ YBA Pilot"
    titleLbl.Font               = Enum.Font.GothamBold
    titleLbl.TextSize           = 13
    titleLbl.TextColor3         = Color3.fromRGB(200, 200, 255)
    titleLbl.TextXAlignment     = Enum.TextXAlignment.Left
    titleLbl.Parent             = titleBar

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size              = UDim2.new(1, -16, 0, 18)
    statusLbl.Position          = UDim2.new(0, 8, 0, 32)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text              = "Статус: выкл"
    statusLbl.Font              = Enum.Font.Gotham
    statusLbl.TextSize          = 11
    statusLbl.TextColor3        = Color3.fromRGB(160, 160, 160)
    statusLbl.TextXAlignment    = Enum.TextXAlignment.Left
    statusLbl.Parent            = frame

    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, -16, 0, 30)
    btn.Position         = UDim2.new(0, 8, 0, 52)
    btn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
    btn.Text             = "Включить Pilot"
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 13
    btn.TextColor3       = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel  = 0
    btn.Parent           = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

    btn.MouseButton1Click:Connect(function()
        if pilotActive then
            stopPilot()
            btn.Text             = "Включить Pilot"
            btn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
            statusLbl.Text       = "Статус: выкл"
        else
            local ok = startPilot()
            if ok then
                btn.Text             = "Выключить Pilot"
                btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                statusLbl.Text       = "Статус: вкл  [ПКМ = камера]"
            else
                statusLbl.Text = "⚠ Экипируй стенд сначала!"
            end
        end
    end)

    -- F8 — хоткей
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.F8 then
            btn.MouseButton1Click:Fire()
        end
    end)

else
    -- Show UI
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "YBA_OnlyNotice"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 420, 0, 140)
    frame.Position = UDim2.new(0.5, -210, 0.5, -70)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    frame.ClipsDescendants = true
    frame.Name = "YBANoticeFrame"

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 60)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "Dude Wrong game press join to join the right game - advice = READ THE FUCKING CAPTION!!"
    title.TextWrapped = true
    title.TextScaled = false
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 20
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Parent = frame

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -20, 0, 28)
    info.Position = UDim2.new(0, 10, 0, 70)
    info.BackgroundTransparency = 1
    info.Text = "Wrong Game Dude you need to press join if you want to go the the right game"
    info.TextWrapped = true
    info.TextScaled = false
    info.Font = Enum.Font.SourceSans
    info.TextSize = 14
    info.TextColor3 = Color3.fromRGB(200, 200, 200)
    info.Parent = frame

    local joinBtn = Instance.new("TextButton")
    joinBtn.Size = UDim2.new(0, 120, 0, 40)
    joinBtn.Position = UDim2.new(1, -140, 1, -50)
    joinBtn.AnchorPoint = Vector2.new(0, 0)
    joinBtn.Text = "Join?"
    joinBtn.Font = Enum.Font.SourceSansBold
    joinBtn.TextSize = 20
    joinBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
    joinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    joinBtn.Parent = frame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 80, 0, 30)
    closeBtn.Position = UDim2.new(0, 10, 1, -40)
    closeBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    closeBtn.Text = "Close"
    closeBtn.Font = Enum.Font.SourceSans
    closeBtn.TextSize = 18
    closeBtn.Parent = frame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -20, 0, 18)
    statusLabel.Position = UDim2.new(0, 10, 1, -20)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = ""
    statusLabel.Font = Enum.Font.SourceSansItalic
    statusLabel.TextSize = 14
    statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    statusLabel.TextWrapped = true
    statusLabel.Parent = frame

    local debounce = false
    joinBtn.MouseButton1Click:Connect(function()
        if debounce then return end
        debounce = true
        statusLabel.Text = "Preparing teleport..."
        -- Try to queue the script string for teleport
        local ok = false
        local success, err = pcall(function()
            ok = queue_for_teleport(main_code)
        end)
        if not success then ok = false end

        if ok then
            statusLabel.Text = "Script queued — teleporting now."
        else
            statusLabel.Text = "Auto-queue not available for your executor. Teleporting anyway."
        end

        -- Give a short delay so user sees the message, then teleport
        wait(0.5)
        pcall(function()
            TeleportService:Teleport(TARGET_PLACE, LocalPlayer)
        end)
    end)

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
end