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
