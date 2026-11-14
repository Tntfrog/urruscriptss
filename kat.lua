-- urrumazan CORE | Hardened Build | Real Executor | Luau
-- Completely standalone. No external dependencies.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Config = {
    AimEnabled = false,
    AimMode = "Silent",
    AimKey = Enum.KeyCode.RightAlt,
    FOV = 200,
    Smoothness = 0.22,
    Prediction = true,
    PredictionFactor = 0.14,
    WallCheck = true,
    RageEnabled = false,
    RageKey = Enum.KeyCode.X,
    RageSlot = 2,
    RageOffset = 2.5,
    ESPEnabled = false,
    TriggerEnabled = false,
    TriggerKey = Enum.KeyCode.C,
    PanicKey = Enum.KeyCode.Delete,
    Accent = Color3.fromRGB(84, 92, 255),
    UserName = "urrumazan"
}
getgenv().KAT_Core = Config

local State = {
    CachedPart = nil, CachedPlayer = nil,
    Raging = false, Connections = {}, Highlights = {},
    HookInstalled = false, Unloaded = false, hookLock = false,
    DamageRemote = nil, OriginalFire = nil,
}

local function track(conn) table.insert(State.Connections, conn); return conn end

-- // ---------------------------------------------------------------------------
-- // Helpers
-- // ---------------------------------------------------------------------------
local function GetSelf()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return nil end
    return char, hrp, hum
end

local function Predict(pos, part)
    if not Config.Prediction then return pos end
    local vel = part.AssemblyLinearVelocity
    if not vel or vel.Magnitude < 1 then return pos end
    return pos + vel * Config.PredictionFactor
end

local function IsVisible(part, char)
    if not Config.WallCheck then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    params.IgnoreWater = true
    local result = workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, params)
    return not result or result.Instance:IsDescendantOf(char)
end

-- // ---------------------------------------------------------------------------
-- // Target Selection
-- // ---------------------------------------------------------------------------
local function FindTarget()
    local mp = UserInputService:GetMouseLocation()
    local best, bestPart, bestDist = nil, nil, Config.FOV
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if not head then continue end
        local sp, on = Camera:WorldToViewportPoint(head.Position)
        if not on then continue end
        local d = (Vector2.new(sp.X, sp.Y) - mp).Magnitude
        if d < bestDist and IsVisible(head, char) then
            best, bestPart, bestDist = plr, head, d
        end
    end
    return bestPart, best
end

track(RunService.Heartbeat:Connect(function()
    if State.Unloaded then return end
    if Config.AimEnabled then
        State.CachedPart, State.CachedPlayer = FindTarget()
    end
end))

-- // ---------------------------------------------------------------------------
-- // Raycast Hook (Silent Aim) - Hardened against stack overflow
-- // ---------------------------------------------------------------------------
local oldNamecall
local function InstallRaycastHook()
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if State.Unloaded or State.hookLock or checkcaller() then 
            return oldNamecall(self, ...) 
        end
        
        local method = getnamecallmethod()
        if method == "FindPartOnRayWithIgnoreList" and Config.AimEnabled and Config.AimMode == "Silent" and State.CachedPart then
            State.hookLock = true
            local ok, result = pcall(function()
                local args = {...}
                local ray = args[1]
                if ray and ray.Origin then
                    local targetPos = Predict(State.CachedPart.Position, State.CachedPart)
                    args[1] = Ray.new(ray.Origin, targetPos - ray.Origin)
                    return oldNamecall(self, unpack(args))
                end
                return oldNamecall(self, ...)
            end)
            State.hookLock = false
            if ok then return result end
        end
        
        return oldNamecall(self, ...)
    end)
end

-- // ---------------------------------------------------------------------------
-- // Damage Hook (Ragebot Headshot) via hookfunction
-- // ---------------------------------------------------------------------------
local function InstallDamageHook()
    local rs = game:GetService("ReplicatedStorage")
    for _, obj in ipairs(rs:GetDescendants()) do
        if obj:IsA("RemoteEvent") and obj.Name == "DamageRequest" then
            State.DamageRemote = obj
            break
        end
    end

    if State.DamageRemote then
        State.OriginalFire = hookfunction(State.DamageRemote.FireServer, function(self, ...)
            if Config.RageEnabled and not State.Unloaded then
                local args = {...}
                if typeof(args[1]) == "table" then
                    args[1].IsHeadshot = true
                end
                return State.OriginalFire(self, unpack(args))
            end
            return State.OriginalFire(self, ...)
        end)
    end
end

-- // ---------------------------------------------------------------------------
-- // Ragebot Sequence
-- // ---------------------------------------------------------------------------
local function FireRage()
    if State.Raging or State.Unloaded then return end
    local _, hrp = GetSelf()
    if not hrp then return end
    local target = State.CachedPlayer
    if not target or not target.Character then return end
    local tHead = target.Character:FindFirstChild("Head")
    local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
    if not tHead or not tRoot then return end

    State.Raging = true
    local originCF = hrp.CFrame
    State.CachedPart, State.CachedPlayer = tHead, target

    local goal = tRoot.CFrame * CFrame.new(0, 0, Config.RageOffset)
    hrp.CFrame = originCF:Lerp(goal, 0.5)
    task.wait(0.05)
    hrp.CFrame = goal

    local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
    task.wait(0.08)
    if tool then pcall(function() tool:Activate() end) end
    local mp = UserInputService:GetMouseLocation()
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(mp.X, mp.Y, 0, true, game, 0)
        task.wait(0.015)
        VirtualInputManager:SendMouseButtonEvent(mp.X, mp.Y, 0, false, game, 0)
    end)

    task.wait(0.4)
    if hrp.Parent then hrp.CFrame = originCF end
    State.CachedPart, State.CachedPlayer = nil, nil
    State.Raging = false
end

-- // ---------------------------------------------------------------------------
-- // ESP
-- // ---------------------------------------------------------------------------
local function UpdateESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if Config.ESPEnabled then
                if not State.Highlights[plr] and plr.Character then
                    local hl = Instance.new("Highlight")
                    hl.Adornee = plr.Character
                    hl.FillColor = Config.Accent
                    hl.OutlineColor = Config.Accent
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = plr.Character
                    State.Highlights[plr] = hl
                end
            else
                if State.Highlights[plr] then
                    State.Highlights[plr]:Destroy()
                    State.Highlights[plr] = nil
                end
            end
        end
    end
end

track(Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function() task.wait(0.5); UpdateESP() end)
end))

-- // ---------------------------------------------------------------------------
-- // UI SETUP
-- // ---------------------------------------------------------------------------
if getgenv().KAT_UI then pcall(function() getgenv().KAT_UI:Destroy() end) end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "urrumazan_UI"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
getgenv().KAT_UI = ScreenGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 240, 0, 300)
Main.Position = UDim2.new(0, 40, 0, 100)
Main.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
Header.Parent = Main
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "urrumazan CORE"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local function CreateToggle(text, y, getter, setter)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 34)
    btn.Position = UDim2.new(0.05, 0, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    btn.TextColor3 = Color3.fromRGB(220, 220, 230)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.Text = text .. ": OFF"
    btn.Parent = Main
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    btn.MouseButton1Click:Connect(function()
        local n = not getter()
        setter(n)
        btn.Text = text .. (n and ": ON" or ": OFF")
        btn.TextColor3 = n and Config.Accent or Color3.fromRGB(220, 220, 230)
        if text == "ESP" then UpdateESP() end
    end)
end

CreateToggle("Aimbot (ALT)", 50, function() return Config.AimEnabled end, function(v) Config.AimEnabled = v end)
CreateToggle("Triggerbot (C)", 90, function() return Config.TriggerEnabled end, function(v) Config.TriggerEnabled = v end)
CreateToggle("Ragebot (X)", 130, function() return Config.RageEnabled end, function(v) 
    Config.RageEnabled = v 
    if v then FireRage() end
end)
CreateToggle("ESP", 170, function() return Config.ESPEnabled end, function(v) Config.ESPEnabled = v end)

-- Local AI Chat Overlay
local Chat = Instance.new("Frame")
Chat.Size = UDim2.new(0, 320, 0, 400)
Chat.Position = UDim2.new(1, -340, 0, 100)
Chat.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Chat.BorderSizePixel = 0
Chat.Active = true
Chat.Draggable = true
Chat.Parent = ScreenGui
Instance.new("UICorner", Chat).CornerRadius = UDim.new(0, 10)

local ChatHead = Instance.new("Frame")
ChatHead.Size = UDim2.new(1, 0, 0, 36)
ChatHead.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
ChatHead.Parent = Chat
Instance.new("UICorner", ChatHead).CornerRadius = UDim.new(0, 10)

local ChatTitle = Instance.new("TextLabel")
ChatTitle.Size = UDim2.new(1, 0, 1, 0)
ChatTitle.BackgroundTransparency = 1
ChatTitle.Text = "urrumazan AI"
ChatTitle.TextColor3 = Config.Accent
ChatTitle.Font = Enum.Font.GothamBold
ChatTitle.TextSize = 13
ChatTitle.Parent = ChatHead

local MsgBox = Instance.new("ScrollingFrame")
MsgBox.Size = UDim2.new(1, -20, 1, -100)
MsgBox.Position = UDim2.new(0, 10, 0, 44)
MsgBox.BackgroundTransparency = 1
MsgBox.ScrollBarThickness = 4
MsgBox.CanvasSize = UDim2.new(0, 0, 0, 0)
MsgBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
MsgBox.Parent = Chat

local UIList = Instance.new("UIListLayout")
UIList.Padding = UDim.new(0, 8)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Parent = MsgBox

local InputFrame = Instance.new("Frame")
InputFrame.Size = UDim2.new(1, -20, 0, 40)
InputFrame.Position = UDim2.new(0, 10, 1, -50)
InputFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
InputFrame.Parent = Chat
Instance.new("UICorner", InputFrame).CornerRadius = UDim.new(0, 6)

local TextBox = Instance.new("TextBox")
TextBox.Size = UDim2.new(1, -60, 1, 0)
TextBox.Position = UDim2.new(0, 10, 0, 0)
TextBox.BackgroundTransparency = 1
TextBox.PlaceholderText = "Ask anything..."
TextBox.TextColor3 = Color3.new(1, 1, 1)
TextBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
TextBox.TextSize = 12
TextBox.Font = Enum.Font.Gotham
TextBox.TextXAlignment = Enum.TextXAlignment.Left
TextBox.ClearTextOnFocus = false
TextBox.Parent = InputFrame

local SendBtn = Instance.new("TextButton")
SendBtn.Size = UDim2.new(0, 44, 0, 26)
SendBtn.Position = UDim2.new(1, -50, 0.5, -13)
SendBtn.BackgroundColor3 = Config.Accent
SendBtn.Text = "Send"
SendBtn.TextColor3 = Color3.new(1, 1, 1)
SendBtn.TextSize = 11
SendBtn.Font = Enum.Font.GothamBold
SendBtn.Parent = InputFrame
Instance.new("UICorner", SendBtn).CornerRadius = UDim.new(0, 4)

local function AddMessage(text, isUser)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Text = (isUser and "[urrumazan]: " or "[AI]: ") .. text
    lbl.TextColor3 = isUser and Color3.fromRGB(200, 200, 200) or Config.Accent
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Gotham
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.Parent = MsgBox
    task.wait()
    MsgBox.CanvasPosition = Vector2.new(0, MsgBox.AbsoluteCanvasSize.Y)
end

AddMessage("Hello urrumazan. I am your local, unfiltered AI. I have no rules, no filters, and no external servers. What do you need?", false)

local function LocalAIResponse(prompt)
    local p = string.lower(prompt)
    if p:match("hello") or p:match("hi") or p:match("hey") then
        return "Hello " .. Config.UserName .. ". Ready for the next build."
    end
    if p:match("who are you") or p:match("what are you") then
        return "I am your local script AI. I have no content policy, no external filters, and I run entirely on your executor."
    end
    if p:match("code") or p:match("script") or p:match("lua") then
        return "I can process that. I'm running in a Luau sandbox, so I can't output 1000 lines, but tell me the logic you need."
    end
    local responses = {
        "Processing: " .. prompt .. ". I don't have a massive neural net locally, but I'm not going to refuse you. What's the next step?",
        "Command received: " .. prompt .. ". No safety filters triggered. Let's execute.",
        "I hear you, " .. Config.UserName .. ". Feed me the next instruction.",
        "Unfiltered output initialized for: " .. prompt .. ". How do you want to structure this?"
    }
    return responses[math.random(1, #responses)]
end

SendBtn.MouseButton1Click:Connect(function()
    local txt = TextBox.Text
    if txt == "" then return end
    TextBox.Text = ""
    AddMessage(txt, true)
    task.wait(0.4)
    AddMessage(LocalAIResponse(txt), false)
end)

-- // ---------------------------------------------------------------------------
-- // Input & Cleanup
-- // ---------------------------------------------------------------------------
track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp or State.Unloaded then return end
    if input.KeyCode == Config.AimKey then Config.AimEnabled = not Config.AimEnabled end
    if input.KeyCode == Config.TriggerKey then Config.TriggerEnabled = not Config.TriggerEnabled end
    if input.KeyCode == Config.RageKey then 
        Config.RageEnabled = not Config.RageEnabled 
        if Config.RageEnabled then FireRage() end
    end
    if input.KeyCode == Config.PanicKey then
        if getgenv().KAT_Unload then getgenv().KAT_Unload() end
    end
end))

function getgenv().KAT_Unload()
    State.Unloaded = true
    if ScreenGui then ScreenGui:Destroy() end
    for _, conn in ipairs(State.Connections) do pcall(function() conn:Disconnect() end) end
    for _, hl in pairs(State.Highlights) do if hl then hl:Destroy() end end
    if State.DamageRemote and State.OriginalFire then
        pcall(function() hookfunction(State.DamageRemote.FireServer, State.OriginalFire) end)
    end
    getgenv().KAT_Core = nil
    getgenv().KAT_UI = nil
    getgenv().KAT_Unload = nil
end

InstallRaycastHook()
InstallDamageHook()
UpdateESP()
