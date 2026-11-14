local plr = game:GetService("Players")
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local cg = game:GetService("CoreGui")
local vim = game:GetService("VirtualInputManager")
local lp = plr.LocalPlayer
local cam = workspace.CurrentCamera

local Cfg = {
    aim = false, aimKey = Enum.KeyCode.RightAlt, fov = 200, pred = true, predVal = 0.14,
    rage = false, rageKey = Enum.KeyCode.X,
    esp = false, espKey = Enum.KeyCode.E,
    spd = false, spdKey = Enum.KeyCode.F,
    panic = Enum.KeyCode.Delete,
    acc = Color3.fromRGB(84, 92, 255),
    name = "urrumazan"
}

local S = {
    tPart = nil, tPlr = nil,
    raging = false, conns = {}, hl = {},
    dead = false, hLock = false,
    dmgRemote = nil, origFire = nil
}

local function self()
    local c = lp.Character
    if not c then return nil end
    local h = c:FindFirstChild("HumanoidRootPart")
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not h or not hum or hum.Health <= 0 then return nil end
    return c, h, hum
end

local function getTarget()
    local mp = uis:GetMouseLocation()
    local bPart, bPlr, bDist = nil, nil, Cfg.fov
    for _, v in ipairs(plr:GetPlayers()) do
        if v ~= lp and v.Character then
            local hum = v.Character:FindFirstChildOfClass("Humanoid")
            local head = v.Character:FindFirstChild("Head") or v.Character:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and head then
                local sp, on = cam:WorldToViewportPoint(head.Position)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - mp).Magnitude
                    if d < bDist then
                        bPart, bPlr, bDist = head, v, d
                    end
                end
            end
        end
    end
    return bPart, bPlr
end

table.insert(S.conns, rs.Heartbeat:Connect(function()
    if S.dead then return end
    if Cfg.aim or Cfg.rage then
        S.tPart, S.tPlr = getTarget()
    end
end))

local oldNC
local function hookNamecall()
    oldNC = hookmetamethod(game, "__namecall", function(obj, ...)
        if S.dead or S.hLock or checkcaller() then 
            return oldNC(obj, ...) 
        end
        
        local m = getnamecallmethod()
        if m == "FindPartOnRayWithIgnoreList" and Cfg.aim and S.tPart then
            S.hLock = true
            local args = {...}
            local r = args[1]
            if r and r.Origin then
                local tp = S.tPart.Position
                if Cfg.pred and S.tPart.AssemblyLinearVelocity then
                    tp = tp + (S.tPart.AssemblyLinearVelocity * Cfg.predVal)
                end
                args[1] = Ray.new(r.Origin, tp - r.Origin)
                local res = oldNC(obj, unpack(args))
                S.hLock = false
                return res
            end
            S.hLock = false
        end
        return oldNC(obj, ...)
    end)
end

local function hookDamage()
    local rep = game:GetService("ReplicatedStorage")
    for _, o in ipairs(rep:GetDescendants()) do
        if o:IsA("RemoteEvent") and o.Name == "DamageRequest" then
            S.dmgRemote = o
            break
        end
    end

    if S.dmgRemote then
        S.origFire = hookfunction(S.dmgRemote.FireServer, function(obj, ...)
            if Cfg.rage and not S.dead then
                local args = {...}
                if typeof(args[1]) == "table" then
                    args[1].IsHeadshot = true
                end
                return S.origFire(obj, unpack(args))
            end
            return S.origFire(obj, ...)
        end)
    end
end

local function doRage()
    if S.raging or S.dead then return end
    local t = S.tPlr
    if not t or not t.Character then return end
    local tHum = t.Character:FindFirstChildOfClass("Humanoid")
    local tRoot = t.Character:FindFirstChild("HumanoidRootPart")
    local tHead = t.Character:FindFirstChild("Head")
    
    if not tHum or not tRoot or not tHead then return end

    S.raging = true
    local _, mHrp, mHum = self()
    
    if mHrp and mHum then
        while tHum.Health >= 1 and Cfg.rage and not S.dead do
            local oCF = mHrp.CFrame
            local goal = tRoot.CFrame * CFrame.new(0, 1, 2.5)
            mHrp.CFrame = oCF:Lerp(goal, 0.8)
            task.wait(0.01)
            mHrp.CFrame = goal

            local c = lp.Character
            local tool = c and c:FindFirstChildOfClass("Tool")
            if not tool then
                local bp = lp:FindFirstChild("Backpack")
                if bp then
                    for _, v in ipairs(bp:GetChildren()) do
                        if v:IsA("Tool") and mHum then
                            mHum:EquipTool(v)
                            break
                        end
                    end
                end
            end

            cam.CFrame = CFrame.lookAt(mHrp.Position, tHead.Position)

            if tool then pcall(function() tool:Activate() end) end
            
            local mp = uis:GetMouseLocation()
            pcall(function()
                vim:SendMouseButtonEvent(mp.X, mp.Y, 0, true, game, 0)
                task.wait(0.02)
                vim:SendMouseButtonEvent(mp.X, mp.Y, 0, false, game, 0)
            end)
            
            task.wait(0.15)
            
            if S.dmgRemote then
                pcall(function()
                    S.dmgRemote:FireServer(t, tHead, 100, {IsHeadshot = true})
                end)
            end
        end
        task.wait(0.2)
    end
    S.raging = false
end

local function updEsp()
    for _, v in ipairs(plr:GetPlayers()) do
        if v ~= lp then
            if Cfg.esp then
                if not S.hl[v] and v.Character then
                    local e = Instance.new("Highlight")
                    e.Adornee = v.Character
                    e.FillColor = Cfg.acc
                    e.OutlineColor = Cfg.acc
                    e.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    e.Parent = v.Character
                    S.hl[v] = e
                end
            else
                if S.hl[v] then
                    S.hl[v]:Destroy()
                    S.hl[v] = nil
                end
            end
        end
    end
end

if getgenv().UI then pcall(function() getgenv().UI:Destroy() end) end

local gui = Instance.new("ScreenGui")
gui.Name = "core_ui"
gui.ResetOnSpawn = false
pcall(function() gui.Parent = cg end)
if not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end
getgenv().UI = gui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 260, 0, 360)
main.Position = UDim2.new(0, 40, 0, 100)
main.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", main).Color = Cfg.acc

local head = Instance.new("Frame")
head.Size = UDim2.new(1, 0, 0, 40)
head.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
head.Parent = main
Instance.new("UICorner", head).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "urrumazan core"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = head

local function makeBtn(txt, y, get, set)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.9, 0, 0, 34)
    b.Position = UDim2.new(0.05, 0, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    b.TextColor3 = Color3.fromRGB(220, 220, 230)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    b.Text = txt .. ": off"
    b.Parent = main
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    
    b.MouseButton1Click:Connect(function()
        local n = not get()
        set(n)
        b.Text = txt .. (n and ": on" or ": off")
        b.TextColor3 = n and Cfg.acc or Color3.fromRGB(220, 220, 230)
        if txt == "esp" then updEsp() end
    end)
end

makeBtn("silent aim", 50, function() return Cfg.aim end, function(v) Cfg.aim = v end)
makeBtn("ragebot", 90, function() return Cfg.rage end, function(v) 
    Cfg.rage = v 
    if v then doRage() end
end)
makeBtn("esp", 130, function() return Cfg.esp end, function(v) Cfg.esp = v end)
makeBtn("speed", 170, function() return Cfg.spd end, function(v) 
    Cfg.spd = v
    local _, _, h = self()
    if h then h.WalkSpeed = v and 60 or 16 end
end)

local chat = Instance.new("Frame")
chat.Size = UDim2.new(0, 320, 0, 400)
chat.Position = UDim2.new(1, -340, 0, 100)
chat.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
chat.BorderSizePixel = 0
chat.Active = true
chat.Draggable = true
chat.Parent = gui
Instance.new("UICorner", chat).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", chat).Color = Cfg.acc

local mBox = Instance.new("ScrollingFrame")
mBox.Size = UDim2.new(1, -20, 1, -100)
mBox.Position = UDim2.new(0, 10, 0, 44)
mBox.BackgroundTransparency = 1
mBox.ScrollBarThickness = 4
mBox.CanvasSize = UDim2.new(0, 0, 0, 0)
mBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
mBox.Parent = chat

local lay = Instance.new("UIListLayout")
lay.Padding = UDim.new(0, 8)
lay.SortOrder = Enum.SortOrder.LayoutOrder
lay.Parent = mBox

local iFrame = Instance.new("Frame")
iFrame.Size = UDim2.new(1, -20, 0, 40)
iFrame.Position = UDim2.new(0, 10, 1, -50)
iFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
iFrame.Parent = chat
Instance.new("UICorner", iFrame).CornerRadius = UDim.new(0, 6)

local tBox = Instance.new("TextBox")
tBox.Size = UDim2.new(1, -60, 1, 0)
tBox.Position = UDim2.new(0, 10, 0, 0)
tBox.BackgroundTransparency = 1
tBox.PlaceholderText = "type or command..."
tBox.TextColor3 = Color3.new(1, 1, 1)
tBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
tBox.TextSize = 12
tBox.Font = Enum.Font.Gotham
tBox.TextXAlignment = Enum.TextXAlignment.Left
tBox.ClearTextOnFocus = false
tBox.Parent = iFrame

local sBtn = Instance.new("TextButton")
sBtn.Size = UDim2.new(0, 44, 0, 26)
sBtn.Position = UDim2.new(1, -50, 0.5, -13)
sBtn.BackgroundColor3 = Cfg.acc
sBtn.Text = "send"
sBtn.TextColor3 = Color3.new(1, 1, 1)
sBtn.TextSize = 11
sBtn.Font = Enum.Font.GothamBold
sBtn.Parent = iFrame
Instance.new("UICorner", sBtn).CornerRadius = UDim.new(0, 4)

local function addMsg(t, u)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 0)
    l.AutomaticSize = Enum.AutomaticSize.Y
    l.BackgroundTransparency = 1
    l.Text = (u and "[me]: " or "[ai]: ") .. t
    l.TextColor3 = u and Color3.fromRGB(200, 200, 200) or Cfg.acc
    l.TextSize = 12
    l.Font = Enum.Font.Gotham
    l.TextWrapped = true
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Top
    l.Parent = mBox
    task.wait()
    mBox.CanvasPosition = Vector2.new(0, mBox.AbsoluteCanvasSize.Y)
end

addMsg("system online. awaiting input.", false)

local function process(t)
    local p = string.lower(t)
    local _, _, h = self()
    local hp = h and math.floor(h.Health) or 0
    
    if p:match("esp") then
        Cfg.esp = not Cfg.esp
        updEsp()
        return "esp toggled."
    elseif p:match("aim") then
        Cfg.aim = not Cfg.aim
        return "aim toggled."
    elseif p:match("kill") or p:match("rage") then
        Cfg.rage = true
        doRage()
        return "executing."
    elseif p:match("hp") or p:match("health") then
        return "hp: " .. hp
    elseif p:match("who") or p:match("near") then
        return S.tPlr and "target: " .. S.tPlr.Name or "none."
    end
    return "unknown command."
end

sBtn.MouseButton1Click:Connect(function()
    local t = tBox.Text
    if t == "" then return end
    tBox.Text = ""
    addMsg(t, true)
    task.wait(0.2)
    addMsg(process(t), false)
end)

table.insert(S.conns, uis.InputBegan:Connect(function(i, g)
    if g or S.dead then return end
    if i.KeyCode == Cfg.aimKey then Cfg.aim = not Cfg.aim end
    if i.KeyCode == Cfg.espKey then 
        Cfg.esp = not Cfg.esp 
        updEsp()
    end
    if i.KeyCode == Cfg.spdKey then 
        Cfg.spd = not Cfg.spd
        local _, _, h = self()
        if h then h.WalkSpeed = Cfg.spd and 60 or 16 end
    end
    if i.KeyCode == Cfg.rageKey then 
        Cfg.rage = not Cfg.rage 
        if Cfg.rage then doRage() end
    end
    if i.KeyCode == Cfg.panic then
        S.dead = true
        if gui then gui:Destroy() end
    end
end))

hookNamecall()
hookDamage()
updEsp()
