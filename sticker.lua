-- YBA Pilot + Sticker Unified
local TARGET_PLACE = 2809202155
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

    local LocalPlayer = Players.LocalPlayer or Players:WaitForChild("LocalPlayer", 5)
if not LocalPlayer then return end
local Camera = Workspace.CurrentCamera

-- ══════════════════════════════════════════
--             AUTO-QUEUE SYSTEM
-- ══════════════════════════════════════════
local function safe_pcall(f, ...)
    local ok, res = pcall(f, ...)
    return ok, res
end

local function queue_for_teleport(code)
    if syn and type(syn.queue_on_teleport) == "function" then
        safe_pcall(syn.queue_on_teleport, code) return true
    end
    if type(queue_on_teleport) == "function" then
        safe_pcall(queue_on_teleport, code) return true
    end
    if type(queueonteleport) == "function" then
        safe_pcall(queueonteleport, code) return true
    end
    local possible_tables = {getgenv and getgenv() or nil, _G}
    for _, tbl in ipairs(possible_tables) do
        if type(tbl) == "table" then
            if type(tbl.queue_on_teleport) == "function" then
                safe_pcall(tbl.queue_on_teleport, code) return true
            end
            if type(tbl.queueonteleport) == "function" then
                safe_pcall(tbl.queueonteleport, code) return true
            end
        end
    end
    if type(getfenv) == "function" then
        local ok, env = pcall(function() return getfenv() end)
        if ok and type(env) == "table" and type(env.queue_on_teleport) == "function" then
            safe_pcall(env.queue_on_teleport, code) return true
        end
    end
    return false
end

-- // GITHUB RAW SCRIPT URL
local SCRIPT_URL = "https://raw.githubusercontent.com/arsenshahverdyanlavtxa228/yba-pilot/refs/heads/main/sticker.lua"
local main_code = ("loadstring(game:HttpGet('%s'))()"):format(SCRIPT_URL)

-- ══════════════════════════════════════════
--              MAIN LOGIC (YBA)
-- ══════════════════════════════════════════
if game.PlaceId == TARGET_PLACE then

    -- // CONSTANTS //
    local ALIGN_FORCE      = 1e7
    local ALIGN_RESP       = 250
    local UNDER_OFFSET     = -20
    local ANCHOR_HEIGHT    = 5.3

    local BACK_DISTANCE = 2
    local BACK_HEIGHT = 0.5
    local PLAYER_HEIGHT = 20
    local SMOOTH_FALLBACK_ALPHA = 0.85
    local CHECK_SCAN_INTERVAL = 1.0

    -- // STATE //
    local pilotActive = false
    local pilotConn = nil
    local pilotAnchor = nil
    local pilotFloor = nil

    local stickerEnabled = false
    local stickerMethod = "normal"
    local activeAligns = {}
    local currentTargetForEntity = {}

    local superSpeedEnabled = false
    local superJumpEnabled  = false

    local noclipConn = nil
    local noclipEnabled = false
    local originalCollides = {}

    local viewing = false
    local viewingStand = nil
    local prevCamSubject = nil
    local prevCamType = nil

    local scanTimer = 0
    local modelCache = {}

    local orbit = {
        yaw = 0, pitch = math.rad(20),
        radius = 12, minR = 3, maxR = 60,
        sens = 0.004,
        pitchMin = -math.pi/2 + 0.05,
        pitchMax =  math.pi/2 - 0.05,
        dragging = false,
        locked = false,
        c1 = nil, c2 = nil, c3 = nil,
        renderConn = nil
    }

    local function notify(t, m)
        pcall(function() StarterGui:SetCore("SendNotification", {Title = t, Text = m, Duration = 3}) end)
    end

    local function getHRP()
        local char = LocalPlayer.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end

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

    local function getGroundY(x, z, excludes)
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = excludes or {}
        params.FilterType = Enum.RaycastFilterType.Exclude
        
        local startY = 800
        local hrp = getHRP()
        if hrp then
            local currentY = hrp.Position.Y
            if currentY > -50 then startY = currentY + 100 else startY = 200 end
        end

        local res = Workspace:Raycast(Vector3.new(x, startY, z), Vector3.new(0, -1000, 0), params)
        if res then
            if res.Instance and res.Instance.Transparency >= 1 then
                local res2 = Workspace:Raycast(Vector3.new(x, res.Position.Y - 5, z), Vector3.new(0, -1000, 0), params)
                return res2 and res2.Position.Y or res.Position.Y
            end
            return res.Position.Y
        end
        return hrp and hrp.Position.Y or 0
    end

    -- // CACHE SYSTEM (Sticker) //
    local function isCharacterModel(m)
        if not m or not m:IsA("Model") then return false end
        return m:FindFirstChild("Humanoid") and m:FindFirstChild("HumanoidRootPart")
    end
    local function rebuildModelCache()
        modelCache = {}
        for _, child in ipairs(Workspace:GetChildren()) do
            if isCharacterModel(child) then
                table.insert(modelCache, child)
            else
                for _, c2 in ipairs(child:GetChildren()) do
                    if isCharacterModel(c2) then table.insert(modelCache, c2) end
                end
            end
        end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and pl.Character and isCharacterModel(pl.Character) then
                table.insert(modelCache, pl.Character)
            end
        end
    end
    rebuildModelCache()
    Workspace.ChildAdded:Connect(function(c)
        if isCharacterModel(c) then table.insert(modelCache, c) else
            for _, c2 in ipairs(c:GetChildren()) do if isCharacterModel(c2) then table.insert(modelCache, c2) end end
        end
    end)
    Workspace.ChildRemoved:Connect(function(c)
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
        local root = getHRP()
        if not root then return nil end
        local rootPos = root.Position
        local lower = name:lower()
        local closest, minD = nil, math.huge
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                local match = (pl.Name:lower():find(lower) or (pl.DisplayName and pl.DisplayName:lower():find(lower)))
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
            if model and model.Parent and model ~= LocalPlayer.Character then
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

    -- // ALIGN SYSTEM //
    local function cleanupAlignFor(entity)
        if not entity then return end
        local hrp = entity:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, c in ipairs(hrp:GetChildren()) do
                if c.Name:match("^Pilot_") or c.Name:match("^Stick_") then c:Destroy() end
            end
        end
        activeAligns[entity] = nil
        currentTargetForEntity[entity] = nil
    end

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

        return attA, attB, ap
    end

    local function createAlignsFor(entity, targetHRP, stickMode)
        if not entity or not targetHRP then return nil end
        cleanupAlignFor(entity)
        local hrp = entity:FindFirstChild("HumanoidRootPart") or entity:FindFirstChild("Torso") or entity:FindFirstChild("UpperTorso")
        if not hrp then return nil end

        local offset = Vector3.new(0,0,0)
        if stickMode == "back" then offset = Vector3.new(0, BACK_HEIGHT, -BACK_DISTANCE) end

        local attA, attB, ap = attachAlign(hrp, targetHRP, 0)
        attB.Position = offset
        
        local alignOri = Instance.new("AlignOrientation")
        alignOri.Name = "Stick_AlignOri"
        alignOri.Attachment0 = attA
        alignOri.Attachment1 = attB
        alignOri.MaxTorque = ALIGN_FORCE
        alignOri.Responsiveness = ALIGN_RESP
        alignOri.Parent = hrp

        activeAligns[entity] = {attA = attA, attB = attB, alignPos = ap, alignOri = alignOri, stickMode = stickMode}
        currentTargetForEntity[entity] = targetHRP
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

    -- // NOCLIP SYSTEM //
    local function enforceNoclipForCharacter(char)
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                originalCollides[part] = part.CanCollide
                part.CanCollide = false
            end
        end
    end

    local function enableNoclipMode(isPilot)
        if noclipConn then return end
        local char = LocalPlayer.Character
        if not char then return end
        if not isPilot then
            originalCollides = {}
            enforceNoclipForCharacter(char)
        end
        
        noclipConn = RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then
                        p.CanCollide = false
                    end
                end
            end
            if isPilot then
                local s = getStand()
                if s then
                    for _, p in ipairs(s:GetDescendants()) do
                        if p:IsA("BasePart") and p.CanCollide then
                            p.CanCollide = false
                        end
                    end
                end
            end
        end)
        noclipEnabled = true
    end

    local function disableNoclipMode(isPilot)
        if noclipConn then noclipConn:Disconnect() noclipConn = nil end
        if not isPilot then
            for part, val in pairs(originalCollides) do
                if part and part.Parent and part:IsA("BasePart") then
                    pcall(function() part.CanCollide = val end)
                end
            end
            originalCollides = {}
        end
        noclipEnabled = false
    end

    -- // CAMERA SYSTEM //
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
                orbit.pitch = math.clamp(orbit.pitch - inp.Delta.Y * orbit.sens, orbit.pitchMin, orbit.pitchMax)
            elseif inp.UserInputType == Enum.UserInputType.MouseWheel then
                orbit.radius = math.clamp(orbit.radius - inp.Position.Z * 2, orbit.minR, orbit.maxR)
            end
        end)

        orbit.renderConn = RunService.RenderStepped:Connect(function()
            if not viewing and not pilotActive then return end
            
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
        
        viewing = true
    end

    local function stopOrbitCamera()
        if orbit.c1 then orbit.c1:Disconnect() orbit.c1 = nil end
        if orbit.c2 then orbit.c2:Disconnect() orbit.c2 = nil end
        if orbit.c3 then orbit.c3:Disconnect() orbit.c3 = nil end
        if orbit.renderConn then orbit.renderConn:Disconnect() orbit.renderConn = nil end
        orbit.dragging = false
        UserInputService.MouseIconEnabled = true
        viewing = false
        pcall(function()
            if prevCamSubject then Camera.CameraSubject = prevCamSubject end
            if prevCamType    then Camera.CameraType    = prevCamType    end
        end)
    end

    -- // PILOT MODE //
    local function startPilot()
        if pilotActive then return true end

        local stand = getStand()
        if not stand then return false end

        local hrp = getHRP()
        local standHRP = stand:FindFirstChild("HumanoidRootPart")
        if not hrp or not standHRP then return false end

        local px, pz = hrp.Position.X, hrp.Position.Z
        local gY     = getGroundY(px, pz, {LocalPlayer.Character, stand})
        local groundPos = Vector3.new(px, gY + ANCHOR_HEIGHT, pz)

        pilotFloor = Instance.new("Part")
        pilotFloor.Name = "PilotFloor"
        pilotFloor.Anchored = true
        pilotFloor.CanCollide = true
        pilotFloor.Transparency = 1
        pilotFloor.Size = Vector3.new(10000, 5, 10000)
        pilotFloor.CFrame = CFrame.new(px, gY - 25, pz)
        pilotFloor.Parent = Workspace

        pilotAnchor = Instance.new("Part")
        pilotAnchor.Name = "PilotAnchor"
        pilotAnchor.Anchored = true
        pilotAnchor.CanCollide = false
        pilotAnchor.Transparency = 1
        pilotAnchor.Size = Vector3.new(1, 1, 1)
        pilotAnchor.CFrame = CFrame.new(groundPos)
        pilotAnchor.Parent = Workspace

        pcall(function() standHRP.CFrame = CFrame.new(groundPos) end)
        pcall(function() hrp.CFrame = CFrame.new(px, gY - 20, pz) end)

        attachAlign(standHRP, pilotAnchor, 0)

        enableNoclipMode(true)
        pilotActive = true
        startOrbitCamera(standHRP)

        pilotConn = RunService.Heartbeat:Connect(function()
            if not pilotActive or not pilotAnchor then return end

            local myHRP = getHRP()
            if not myHRP then return end

            local mx, mz  = myHRP.Position.X, myHRP.Position.Z
            local newGY   = getGroundY(mx, mz, {LocalPlayer.Character, stand, pilotFloor})

            local jumpOffset = 0
            if pilotFloor then
                jumpOffset = myHRP.Position.Y - (pilotFloor.Position.Y + 5)
                if jumpOffset < 0.5 then jumpOffset = 0 end
            end

            pilotAnchor.CFrame = CFrame.new(mx, newGY + ANCHOR_HEIGHT + jumpOffset, mz)
            
            if pilotFloor then
                local targetFloorY = newGY - 25
                if math.abs(pilotFloor.Position.Y - targetFloorY) > 10 then
                    pilotFloor.CFrame = CFrame.new(mx, targetFloorY, mz)
                end
                
                if math.abs(myHRP.Position.Y - pilotFloor.Position.Y) > 22 then
                    myHRP.CFrame = CFrame.new(mx, pilotFloor.Position.Y + 5, mz)
                end
            end
        end)
        return true
    end

    local function stopPilot()
        pilotActive = false
        disableNoclipMode(true)
        if pilotConn then pilotConn:Disconnect() pilotConn = nil end
        cleanupAlignFor(getStand())
        if pilotAnchor then pilotAnchor:Destroy() pilotAnchor = nil end
        if pilotFloor then pilotFloor:Destroy() pilotFloor = nil end
        if not viewing then stopOrbitCamera() end
        
        local myHRP = getHRP()
        if myHRP then
            local mx, mz = myHRP.Position.X, myHRP.Position.Z
            local gY = getGroundY(mx, mz, {LocalPlayer.Character})
            myHRP.CFrame = CFrame.new(mx, gY + 5, mz)
        end
    end

    -- // STICKER MODE //
    RunService.Heartbeat:Connect(function(dt)
        scanTimer = scanTimer + dt
        if scanTimer >= CHECK_SCAN_INTERVAL then
            rebuildModelCache()
            scanTimer = 0
        end
        if viewing and not pilotActive then
            if not viewingStand or not viewingStand.Parent or not viewingStand:FindFirstChild("HumanoidRootPart") then
                stopOrbitCamera()
            end
        end
        if not stickerEnabled or pilotActive then return end
        
        -- // Gui references //
        local name = _G.StickerTargetName or ""
        if name == "" then return end
        
        local stand = getStand()
        if not stand then return end
        
        local target = findClosestByName(name)
        if not target then return end
        
        local targetHRP = target:FindFirstChild("HumanoidRootPart")
        local targetHum = target:FindFirstChild("Humanoid")
        local isAlive = targetHum and targetHum.Health > 0
        if not targetHRP or not targetHum then
            for entity,_ in pairs(activeAligns) do cleanupAlignFor(entity) end
            if stickerMethod == "up" then enableNoclipMode(false) else disableNoclipMode(false) end
            return
        end
        
        local myChar = LocalPlayer.Character
        if stand and currentTargetForEntity[stand] ~= targetHRP then
            pcall(createAlignsFor, stand, targetHRP, "back")
        end
        if stickerMethod == "up" then
            if currentTargetForEntity[myChar] ~= targetHRP then
                pcall(createAlignsFor, myChar, targetHRP, "up")
            end
        else
            cleanupAlignFor(myChar)
            disableNoclipMode(false)
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
        
        if stickerMethod == "up" and isAlive then
            enableNoclipMode(false)
        else
            if stickerMethod ~= "up" then disableNoclipMode(false) end
        end
    end)

    LocalPlayer.CharacterRemoving:Connect(function()
        for entity,_ in pairs(activeAligns) do cleanupAlignFor(entity) end
        if viewing then stopOrbitCamera() end
    end)
    LocalPlayer.CharacterAdded:Connect(function(ch)
        if noclipEnabled and not pilotActive then
            spawn(function()
                local hrp = ch:WaitForChild("HumanoidRootPart", 5)
                if hrp then pcall(enableNoclipMode, false) end
            end)
        end
        if pilotActive then
            stopPilot()
            local hum = ch:WaitForChild("Humanoid", 5)
            if hum then Camera.CameraSubject = hum; Camera.CameraType = Enum.CameraType.Custom end
        end
    end)

    -- ══════════════════════════════════════════
    --         UNIFIED BEAUTIFUL GUI
    -- ══════════════════════════════════════════
    local function createTween(object, info, properties)
        local t = TweenService:Create(object, TweenInfo.new(unpack(info)), properties)
        t:Play() return t
    end

    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    for _, gui in ipairs(game.CoreGui:GetChildren()) do if gui.Name == "YBA_UnifiedGUI" or gui.Name == "StandStickerGui" then gui:Destroy() end end
    for _, gui in ipairs(playerGui:GetChildren()) do if gui.Name == "YBA_PilotGUI" or gui.Name == "YBA_UnifiedGUI" then gui:Destroy() end end

    local sg = Instance.new("ScreenGui")
    sg.Name = "YBA_UnifiedGUI"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = game.CoreGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 460, 0, 250)
    mainFrame.Position = UDim2.new(0.5, -230, 0.5, -125)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = sg
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(50, 50, 80)
    stroke.Thickness = 2
    stroke.Parent = mainFrame
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)
    local tFix = Instance.new("Frame")
    tFix.Size = UDim2.new(1, 0, 0, 10)
    tFix.Position = UDim2.new(0, 0, 1, -10)
    tFix.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    tFix.BorderSizePixel = 0
    tFix.Parent = titleBar

    local titleTxt = Instance.new("TextLabel")
    titleTxt.Size = UDim2.new(1, -20, 1, 0)
    titleTxt.Position = UDim2.new(0, 10, 0, 0)
    titleTxt.BackgroundTransparency = 1
    titleTxt.Text = "🔮 YBA Unified Pilot & Sticker"
    titleTxt.Font = Enum.Font.GothamBold
    titleTxt.TextSize = 14
    titleTxt.TextColor3 = Color3.fromRGB(220, 220, 255)
    titleTxt.TextXAlignment = Enum.TextXAlignment.Left
    titleTxt.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 35, 0, 35)
    closeBtn.Position = UDim2.new(1, -35, 0, 0)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "X"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = Color3.fromRGB(200, 100, 100)
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function() sg.Enabled = not sg.Enabled end)

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = mainFrame
    Instance.new("UIPadding", mainFrame).PaddingTop = UDim.new(0, 45)

    local function CreateRow()
        local r = Instance.new("Frame")
        r.Size = UDim2.new(1, -20, 0, 35)
        r.BackgroundTransparency = 1
        r.Parent = mainFrame
        local l = Instance.new("UIListLayout")
        l.FillDirection = Enum.FillDirection.Horizontal
        l.SortOrder = Enum.SortOrder.LayoutOrder
        l.Padding = UDim.new(0, 10)
        l.Parent = r
        return r
    end

    local function CreateButton(parent, text, color, widthScale)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(widthScale, widthScale == 1 and 0 or -5, 1, 0)
        b.BackgroundColor3 = color
        b.Text = text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 14
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Parent = parent
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        
        b.MouseEnter:Connect(function() createTween(b, {0.2, Enum.EasingStyle.Quad}, {BackgroundColor3 = Color3.new(color.R*1.2, color.G*1.2, color.B*1.2)}) end)
        b.MouseLeave:Connect(function() createTween(b, {0.2, Enum.EasingStyle.Quad}, {BackgroundColor3 = color}) end)
        -- Анимация нажатия
        b.MouseButton1Down:Connect(function() createTween(b, {0.1, Enum.EasingStyle.Quad}, {TextSize = 12}) end)
        b.MouseButton1Up:Connect(function() createTween(b, {0.1, Enum.EasingStyle.Quad}, {TextSize = 14}) end)
        return b
    end

    local function CreateSlider(parent, text, min, max, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -20, 0, 45)
        frame.BackgroundTransparency = 1
        frame.Parent = parent

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 20)
        label.BackgroundTransparency = 1
        label.Text = text .. ": " .. tostring(default)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(220, 220, 255)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 0, 10)
        bg.Position = UDim2.new(0, 0, 0, 25)
        bg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        bg.Parent = frame
        Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
        fill.Parent = bg
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = bg

        local dragging = false
        local function update(input)
            local pos = math.clamp((input.Position.X - bg.AbsolutePosition.X) / bg.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(pos, 0, 1, 0)
            local val = math.floor(min + (max - min) * pos)
            label.Text = text .. ": " .. tostring(val)
            callback(val)
        end

        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                update(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                update(input)
            end
        end)
        return frame
    end

    local function CreateSlider(parent, text, min, max, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -20, 0, 45)
        frame.BackgroundTransparency = 1
        frame.Parent = parent

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 20)
        label.BackgroundTransparency = 1
        label.Text = text .. ": " .. tostring(default)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(220, 220, 255)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 0, 10)
        bg.Position = UDim2.new(0, 0, 0, 25)
        bg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        bg.Parent = frame
        Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
        fill.Parent = bg
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = bg

        local dragging = false
        local function update(input)
            local pos = math.clamp((input.Position.X - bg.AbsolutePosition.X) / bg.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(pos, 0, 1, 0)
            local val = math.floor(min + (max - min) * pos)
            label.Text = text .. ": " .. tostring(val)
            callback(val)
        end

        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                update(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                update(input)
            end
        end)
        return frame
    end

    -- Row 1: Pilot & View
    local row1 = CreateRow()
    local btnPilot = CreateButton(row1, "✈ Pilot Mode [OFF]", Color3.fromRGB(40, 40, 60), 0.5)
    local btnView  = CreateButton(row1, "📷 View Stand [OFF]", Color3.fromRGB(40, 60, 40), 0.5)

    -- Row 2: Textbox
    local row2 = CreateRow()
    local boxTarget = Instance.new("TextBox")
    boxTarget.Size = UDim2.new(1, 0, 1, 0)
    boxTarget.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    boxTarget.PlaceholderText = "Введите ник игрока..."
    boxTarget.Text = ""
    boxTarget.Font = Enum.Font.Gotham
    boxTarget.TextSize = 14
    boxTarget.TextColor3 = Color3.fromRGB(255, 255, 255)
    boxTarget.Parent = row2
    Instance.new("UICorner", boxTarget).CornerRadius = UDim.new(0, 8)
    local bs = Instance.new("UIStroke")
    bs.Color = Color3.fromRGB(60, 60, 80)
    bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    bs.Parent = boxTarget
    _G.StickerTargetName = ""
    boxTarget.Changed:Connect(function(prop) if prop == "Text" then _G.StickerTargetName = boxTarget.Text end end)

    -- Row 3: Sticker & Method
    local row3 = CreateRow()
    local btnSticker = CreateButton(row3, "📌 Sticker [OFF]", Color3.fromRGB(40, 40, 60), 0.5)
    local btnMethod  = CreateButton(row3, "⚙ Method: NORMAL", Color3.fromRGB(60, 40, 60), 0.5)

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -20, 0, 20)
    info.BackgroundTransparency = 1
    info.Text = "Caps/Shift: Mouse Lock | F8: Toggle Pilot"
    info.Font = Enum.Font.Gotham
    info.TextSize = 11
    info.TextColor3 = Color3.fromRGB(150, 150, 170)
    info.Parent = mainFrame

    -- // Button Logics //
    btnPilot.MouseButton1Click:Connect(function()
        if pilotActive then
            stopPilot()
            btnPilot.Text = "✈ Pilot Mode [OFF]"
            btnPilot.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        else
            if stickerEnabled then
                stickerEnabled = false
                btnSticker.Text = "📌 Sticker [OFF]"
                btnSticker.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
                for entity, _ in pairs(activeAligns) do cleanupAlignFor(entity) end
                disableNoclipMode(false)
            end
            local ok = startPilot()
            if ok then
                btnPilot.Text = "✈ Pilot Mode [ON]"
                btnPilot.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
            else
                notify("Ошибка", "Стенд не экипирован!")
            end
        end
    end)

    btnSticker.MouseButton1Click:Connect(function()
        if pilotActive then
            notify("Ошибка", "Выключи Pilot Mode сначала!")
            return
        end
        stickerEnabled = not stickerEnabled
        if stickerEnabled then
            btnSticker.Text = "📌 Sticker [ON]"
            btnSticker.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
            if stickerMethod == "up" then enableNoclipMode(false) end
        else
            btnSticker.Text = "📌 Sticker [OFF]"
            btnSticker.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            for entity, _ in pairs(activeAligns) do cleanupAlignFor(entity) end
            disableNoclipMode(false)
        end
    end)

    btnMethod.MouseButton1Click:Connect(function()
        stickerMethod = (stickerMethod == "normal") and "up" or "normal"
        btnMethod.Text = "⚙ Method: " .. stickerMethod:upper()
        if stickerEnabled then for entity, _ in pairs(activeAligns) do cleanupAlignFor(entity) end end
        if stickerMethod ~= "up" then disableNoclipMode(false) end
    end)

    btnView.MouseButton1Click:Connect(function()
        if pilotActive then notify("YBA", "Камера уже управляется Пилотом!") return end
        if viewing then
            stopOrbitCamera()
            btnView.Text = "📷 View Stand [OFF]"
            btnView.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
        else
            local stand = getStand()
            if not stand then notify("Ошибка", "Стенд не найден!") return end
            startOrbitCamera(stand:FindFirstChild("HumanoidRootPart"))
            btnView.Text = "📷 View Stand [ON]"
            btnView.BackgroundColor3 = Color3.fromRGB(80, 140, 80)
        end
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.F8 then btnPilot.MouseButton1Click:Fire() end
    end)

else
    -- ══════════════════════════════════════════
    --             WRONG GAME GUI
    -- ══════════════════════════════════════════
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local sg = Instance.new("ScreenGui")
    sg.Name = "YBA_OnlyNotice"
    sg.ResetOnSpawn = false
    sg.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 420, 0, 140)
    frame.Position = UDim2.new(0.5, -210, 0.5, -70)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 60)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "Это не YBA! Нажми Join чтобы телепортироваться."
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Parent = frame

    local joinBtn = Instance.new("TextButton")
    joinBtn.Size = UDim2.new(0, 120, 0, 40)
    joinBtn.Position = UDim2.new(1, -140, 1, -50)
    joinBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
    joinBtn.Text = "Join YBA"
    joinBtn.Font = Enum.Font.GothamBold
    joinBtn.TextSize = 16
    joinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    joinBtn.Parent = frame
    Instance.new("UICorner", joinBtn).CornerRadius = UDim.new(0, 8)

    local debounce = false
    joinBtn.MouseButton1Click:Connect(function()
        if debounce then return end
        debounce = true
        title.Text = "Телепортация..."
        
        local ok = queue_for_teleport(main_code)
        if ok then title.Text = "Скрипт в очереди, прыгаем!" else title.Text = "Авто-очередь не сработала. Прыгаем!" end
        
        wait(0.5)
        pcall(function() TeleportService:Teleport(TARGET_PLACE, LocalPlayer) end)
    end)
end