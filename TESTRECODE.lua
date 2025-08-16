loadstring(game:HttpGet("https://raw.githubusercontent.com/Pixeluted/adoniscries/refs/heads/main/Source.lua"))()
if not LPH_OBFUSCATED then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Luraph/macrosdk/main/luraphsdk.lua"))()
end

-- features before release --
-- save position / tp to saved position
-- teleport section
-- color section for esp

local rs = game:GetService("RunService")
local rep_storage = game:GetService("ReplicatedStorage")
local uis = game:GetService("UserInputService")
local players = game:GetService("Players")
local lighting = game:GetService("Lighting")
local camera = workspace.CurrentCamera

local aimbot = { enabled = false }
local visuals = {}
local misc = {}
local esp = {}

local is_on_mobile = false
if uis.TouchEnabled and not uis.KeyboardEnabled and not uis.MouseEnabled then
	is_on_mobile = true
elseif not uis.TouchEnabled and uis.KeyboardEnabled and uis.MouseEnabled then
	is_on_mobile = false
end

-- godmode shit
local gm_part = Instance.new("Part")
gm_part.Parent = workspace.SafeZones
gm_part.CanCollide = false
gm_part.Anchored = true
gm_part.Transparency = 1

-- things that need to be defined for fly
misc.control = {
    forward = 0,
    backward = 0,
    left = 0,
    right = 0,
    up = 0,
    down = 0
}
misc.velocity = Vector3.zero

-- aimbot functions (dont need to be obfuscated its already public information)
local get_screen_pos = LPH_NO_VIRTUALIZE(function(object)
    local vector, on_screen = camera:WorldToViewportPoint(object.CFrame * CFrame.new(0, -object.Size.Y, 0).Position)
    local screen_point = Vector2.new(vector.X, vector.Y)
    return screen_point
end)

local get_target = LPH_NO_VIRTUALIZE(function()
    local closest = {aimbot.fov_radius, nil}
    local mouse_pos = uis:GetMouseLocation()
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player == players.LocalPlayer then continue end

        if not player.Character then continue end

        local target = player.Character:FindFirstChild(aimbot.aim_part)
        if not target then continue end

        local screen_pos = get_screen_pos(target)
        local Distance = (mouse_pos - Vector2.new(screen_pos.X, screen_pos.Y)).Magnitude
        if closest[1] == nil then closest = {Distance, player} continue end

        if Distance < closest[1] and Distance <= aimbot.fov_radius then
            closest = {Distance, player}
            --print(closest[2].Name .. ": " .. closest[1])
        end
    end

    if closest[2] then
        return closest[2].Character or nil
    else
        return nil
    end
end)

local aimbot_callback = function(args, namecall, p_self)
    if not aimbot.target_player then
        return namecall(p_self, unpack(args))
    end

    local target_part = aimbot.target_player[aimbot.aim_part]

    args[2] = target_part -- object that was hit
    args[3] = target_part.Position -- object position
    args[4] = target_part.CFrame.LookVector -- object normal?
    return namecall(p_self, unpack(args))
end

local teleport = function(cframe)
    local args = {
        [1] = cframe,
        [2] = true,
    }

    game:GetService('ReplicatedStorage').movementFunction:FireServer(unpack(args))
end

local purchase_item = LPH_NO_VIRTUALIZE(function(item_name)
    local guapo_frame = players.LocalPlayer.PlayerGui.MainGUI.guapoFrame
    local item_button = guapo_frame.stockFrame.Content:WaitForChild(item_name)
    local purchase_button = guapo_frame.productFrame.contentFrame:WaitForChild("purchaseButton")

    replicatesignal(item_button.MouseButton1Down, 1, 1)
    replicatesignal(purchase_button.MouseButton1Down, 1, 1)
end)

local autofarm_finished = function(printer_table)
    local num_printers = #printer_table

    -- check if any printers don't have the ready light
    for i, v in pairs(printer_table) do
        if v.ReadyLight.Color ~= Color3.fromRGB(0, 255, 0) then
            -- if a printer doesn't then we're not finished
            return false
        end
    end

    return true
end

-- this is a whole bunch of bullshit i will not mention
local current_money = 0
local starting_pos = CFrame.new()
local printers = {}

local autofarm_callback = LPH_JIT(function()
    if not misc.autofarm_filament or not misc.autofarm_limit then warn("[mongoloid] one of your autofarm settings has not been set") return end
    local lp = players.LocalPlayer
    local char = lp.Character
    local hrp = char.HumanoidRootPart

    local stop = false

    current_money = lp.Settings.Currency:GetAttribute("Cash")
    starting_pos = hrp.CFrame -- store the starting position
    
    repeat
        hrp.Anchored = true

        for i, v in pairs(printers) do
            local interact_prompt = v.MachineBody.Interact:WaitForChild("Interaction")
            local status = ""

            interact_prompt.HoldDuration = 0
            interact_prompt.MaxActivationDistance = 100

            current_money = lp.Settings.Currency:GetAttribute("Cash")

            if current_money < misc.autofarm_limit then
                stop = true
            end

            if v.PrintingLight.Color == Color3.fromRGB(218, 133, 65) then
                status = "printing"
            end
            if v.CompleteLight.Color == Color3.fromRGB(152, 194, 219) then
                status = "complete"
            end
            if v.ReadyLight.Color == Color3.fromRGB(0, 255, 0) then
                status = "ready"
            end

            if status == "printing" then teleport(starting_pos) continue end

            local printer_cframe = v.MachineBody.CFrame

            if status == "ready" then
                if stop then continue end
                
                if not lp.Backpack:FindFirstChild(misc.autofarm_filament) then
                    purchase_item(misc.autofarm_filament)
                end
                local filament = lp.Backpack:WaitForChild(misc.autofarm_filament, 10)
                char.Humanoid:EquipTool(filament)

                task.wait(0.5)
            elseif status == "complete" then
                purchase_item("Empty Shoe Box")
                local shoebox = lp.Backpack:WaitForChild("Empty Shoe Box", 10)
                char.Humanoid:EquipTool(shoebox)

                task.wait(0.5)
            end

            teleport(printer_cframe)
            task.wait(0.3)
            fireproximityprompt(interact_prompt)

            task.wait(0.5)
            teleport(starting_pos)
        end
        task.wait(0.3)
    until stop and autofarm_finished(printers)
end)

-- the callbacks we dont want public
local inf_stam_callback = function(args, namecall, p_self)
    args[1] = false
    return namecall(p_self, unpack(args))
end

local tweet_callback = function()
    if not misc.tweet_text then return end
    local args = {
        [1] = misc.tweet_text,
        [2] = "\226\128\142 Pr\226\128\142 1V\226\128\142 4t3\226\128\142 "
    }

    game:GetService("ReplicatedStorage").birdiePostFunction:FireServer(unpack(args))
end

local playing = false
local fly_callback = LPH_NO_VIRTUALIZE(function()
    if misc.fly then
        local moveVector = (
            camera.CFrame.LookVector * (misc.control.forward - misc.control.backward) +
            camera.CFrame.RightVector * (misc.control.right - misc.control.left) +
            camera.CFrame.UpVector * (misc.control.up - misc.control.down)
        ).Unit

        if moveVector.Magnitude > 0 then
            misc.velocity = moveVector * 50
        else
            misc.velocity = Vector3.zero
        end

        misc.fly_velocity.Velocity = misc.velocity
        misc.fly_gyro.CFrame = camera.CFrame
    end
end)

local bypass1_callback = function()
    return 10
end

local bypass2_callback = function()
    return nil
end

local bypass_event = game:GetService('ReplicatedStorage').movementFunction
local bypass_humanoid = game:GetService('Players').LocalPlayer.Character.Humanoid
local aim_event = nil

-- bypass walkspeed check
local index_hook = nil
index_hook = hookmetamethod(game, '__index', LPH_NO_VIRTUALIZE(function(Self, Key)
    if not checkcaller() and Self == bypass_humanoid then
        if Key == "WalkSpeed" or Key == "JumpPower" then
            return bypass1_callback()
        end
    end

    return index_hook(Self, Key)
end))

local energy_event = players.LocalPlayer.Events.Energy
local namecall = nil

namecall = hookmetamethod(game, "__namecall", LPH_NO_VIRTUALIZE(function(self, ...)
    local args = {...}
    local method = getnamecallmethod():lower()

    if checkcaller() then return namecall(self, ...) end

    if method == "fireserver" then
        if self == bypass_event then
            return bypass2_callback()
        end
        if self == energy_event and misc.infinite_stamina then
            return inf_stam_callback(args, namecall, self)
        end
        if aim_event and self == aim_event and aimbot.enabled then
            return aimbot_callback(args, namecall, self)
        end
    end

    return namecall(self, ...)
end))

-- menu initialization
local colors = {
    SchemeColor = Color3.fromRGB(33, 129, 255),
    Background = Color3.fromRGB(0, 0, 0),
    Header = Color3.fromRGB(0, 0, 0),
    TextColor = Color3.fromRGB(255,255,255),
    ElementColor = Color3.fromRGB(20, 20, 20)
}

local lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/bawhen/kavo_lib_modified/refs/heads/main/kavo_lib_modified.lua"))()
local window = lib.CreateLib("Mongoloid Recode [BETA]", colors)

local aimbot_tab = window:NewTab("Aimbot")
local visuals_tab = window:NewTab("Visuals")
local misc_tab = window:NewTab("Misc")
local autofarm_tab = window:NewTab("Autofarm")

-- aimbot tab --
local aimbot_main = aimbot_tab:NewSection("Main")
local aimbot_visuals = aimbot_tab:NewSection("Visualizations")
aimbot_main:NewToggle("Toggle [MOBILE]", "", function(state)
    aimbot.enabled = state
    if aimbot.enabled then
        aim_event = players.LocalPlayer.Character:FindFirstChildOfClass("Tool").Event
    else
        aim_event = nil
    end
end)
aimbot_main:NewKeybind("Keybind [PC]", "Activate while you have your gun out, \nReactivate when equipping a new gun.", Enum.KeyCode.CapsLock, function()
	aimbot.enabled = not aimbot.enabled
    if aimbot.enabled then
        aim_event = players.LocalPlayer.Character:FindFirstChildOfClass("Tool").Event
    else
        aim_event = nil
    end
end)
aimbot_main:NewSlider("FOV", "Field of view of the aimbot.", 500, 5, function(s) -- 500 (MaxValue) | 0 (MinValue)
    aimbot.fov_radius = s
end)
aimbot_main:NewDropdown("Part", "The part the aimbot should target.", {"Head", "HumanoidRootPart", "UpperTorso"}, function(s)
    aimbot.aim_part = s
end)

aimbot_visuals:NewToggle("Show FOV", "Draws a circle representing the aimbot FOV.", function(s)
    aimbot.fov_circle = s
end)
aimbot_visuals:NewToggle("Show Target", "Draws a line to the target.", function(s)
    aimbot.show_target = s
end)

-- visuals tab --
local visuals_main = visuals_tab:NewSection("Main")
local visuals_colors = visuals_tab:NewSection("Colors")

visuals_main:NewToggle("Box", "Draws a box around players.", function(s)
    visuals.player_box = s
end)
visuals_main:NewToggle("Name", "Shows the player's name from anywhere.", function(s)
    visuals.player_name = s
end)
visuals_main:NewToggle("Health", "Draws a healthbar for players.", function(s)
    visuals.healthbar = s
end)
visuals_main:NewToggle("Tool Name", "Shows the player's equipped tool.", function(s)
    visuals.tool_name = s
end)
visuals_main:NewToggle("Distance", "Shows the player's distance from you.", function(s)
    visuals.distance = s
end)
visuals.max_distance = 1000
visuals_main:NewSlider("Max Distance", "Maximum distance at which the script will render players.", 3000, 100, function(s)
    visuals.max_distance = s
end)

visuals_colors:NewColorPicker("Box Color", "", Color3.fromRGB(255, 71, 71), function(s)
    visuals.box_color = s
end)
visuals_colors:NewColorPicker("Name Color", "", Color3.fromRGB(255, 255, 255), function(s)
    visuals.name_color = s
end)
visuals_colors:NewColorPicker("Health Color", "", Color3.fromRGB(33, 255, 44), function(s)
    visuals.health_color = s
end)
visuals_colors:NewColorPicker("Tool Color", "", Color3.fromRGB(255, 255, 255), function(s)
    visuals.box_color = s
end)
visuals_colors:NewColorPicker("Distance Color", "", Color3.fromRGB(58, 160, 255), function(s)
    visuals.box_color = s
end)

-- misc. tab --
local misc_main = misc_tab:NewSection("Main")
local misc_movement = misc_tab:NewSection("Movement")

misc_main:NewToggle("God mode", "Cannot do damage while active.", function(s)
    misc.godmode = s
end)
misc_main:NewToggle("Ghost mode", "Walk around with a fake body. (Hide your real body somewhere)", function(s)
    misc.ghostmode = s
    local character = players.LocalPlayer.Character

    if misc.ghostmode then
        if not misc.cached then
            misc.old_parent = nil
            misc.old_cframe = nil
            misc.new_hrp = nil
            misc.old_hrp = nil

            misc.old_parent = character.Parent
            misc.old_hrp = character.HumanoidRootPart
            misc.old_cframe = character.HumanoidRootPart.CFrame
            misc.new_hrp = character.HumanoidRootPart:Clone()
            misc.cached = true
        end

        character.Parent = game
        misc.old_hrp.Parent = game
        misc.new_hrp.Parent = character
        character.Parent = misc.old_parent
        misc.new_hrp.CFrame = misc.old_cframe
        character.Parent = misc.old_parent
    else
        character.Parent = game
        misc.new_hrp.Parent = game
        misc.old_hrp.Parent = character
        character.Parent = misc.old_parent
        misc.old_hrp.CFrame = misc.old_cframe
        misc.cached = false
    end
end)

misc_main:NewButton("Instant Respawn", "", function()
    rep_storage.loadCharacter:FireServer()
end)

misc_main:NewButton("Open Safe", "Open your safe from anywhere.", function()
    local safe = players.LocalPlayer.PlayerGui.MainGUI.safeFrame
    if safe then
        safe.Position = UDim2.new({0.293, 0}, {0.239, 0})
        safe.Visible = true
    end
end)

misc_main:NewTextBox("Tweet", "The message you want to tweet", function(txt)
	misc.tweet_text = txt
end)
misc_main:NewButton("Send Tweet", "Tweet anything you want. (Yes, anything)", tweet_callback)


misc_movement:NewToggle("Infinite Stamina", "", function(s)
    misc.infinite_stamina = s
end)
misc_movement:NewToggle("No Jump Cooldown", "", function(s)
    local humanoid = players.LocalPlayer.Character.Humanoid
    local connections = getconnections(humanoid.Changed)

    if s then
        connections[1]:Disable()
    else
        connections[1]:Enable()
    end
end)
misc_movement:NewToggle("Change Walk/Jump", "", function(s)
    misc.change_stats = s
end)
misc_movement:NewSlider("WalkSpeed", "", 300, 5, function(s)
    misc.walkspeed = s
end)
misc_movement:NewSlider("JumpPower", "", 300, 5, function(s)
    misc.JumpPower = s
end)

-- autofarm tab --
local autofarm_repz = autofarm_tab:NewSection("Repz")

autofarm_repz:NewToggle("Hijack Other Printers", "Steals repz from other printers and uses them to print your own.", function(s)
    misc.hijack_printers = s
end)
autofarm_repz:NewDropdown("Filament", "The filament you want to buy for your printers.", {"Basic Filament","Exclusive Filament","Galaxy Filament", "Supreme Filament", "Rior Filament"}, function(s)
    misc.autofarm_filament = s
end)
autofarm_repz:NewSlider("Minimum Balance", "", 100, 60000, function(s)
    misc.autofarm_limit = s
end)
autofarm_repz:NewButton("Start Autofarm", "You will not be able to move.", function(s)
    if not misc.autofarm_filament or not misc.autofarm_limit then warn("[mongoloid] one of your autofarm settings has not been set") return end

    -- reset and store all printers
    printers = {}
    for i, v in pairs(workspace.RepzMachines:GetChildren()) do
        if v:IsA("Model") and v:FindFirstChild("RepzHandler") then
            if not string.find(v.Name, players.LocalPlayer.Name) and not misc.hijack_printers then continue end
            table.insert(printers, v)
        end
    end

    autofarm_callback()
end)
-- DRAWING STUFF --
local elements = {}
local drawing_ctx = nil
-- this stuff doesn't need to be obfuscated
LPH_NO_VIRTUALIZE(function()
    local function get_bounding_box(instance)
        local min, max = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
        local onscreen = false

        if instance and instance:IsA("Model") then
            for _, p in ipairs(instance:GetChildren()) do
                if p and p:IsA("BasePart") then
                    local size = (p.Size / 2)
                    local cf = p.CFrame
                    for _, offset in ipairs({
                        Vector3.new( size.X,  size.Y,  size.Z),
                        Vector3.new(-size.X,  size.Y,  size.Z),
                        Vector3.new( size.X, -size.Y,  size.Z),
                        Vector3.new(-size.X, -size.Y,  size.Z),
                        Vector3.new( size.X,  size.Y, -size.Z),
                        Vector3.new(-size.X,  size.Y, -size.Z),
                        Vector3.new( size.X, -size.Y, -size.Z),
                        Vector3.new(-size.X, -size.Y, -size.Z),
                    }) do
                        local pos, visible = camera:WorldToViewportPoint(cf:PointToWorldSpace(offset))
                        if visible then
                            local v2 = Vector2.new(pos.X, pos.Y)
                            min = min:Min(v2)
                            max = max:Max(v2)
                            onscreen = true
                        end
                    end
                end
            end
        elseif instance and instance:IsA("BasePart") then
            local size = (instance.Size / 2)
            local cf = instance.CFrame
            for _, offset in ipairs({
                Vector3.new( size.X,  size.Y,  size.Z),
                Vector3.new(-size.X,  size.Y,  size.Z),
                Vector3.new( size.X, -size.Y,  size.Z),
                Vector3.new(-size.X, -size.Y,  size.Z),
                Vector3.new( size.X,  size.Y, -size.Z),
                Vector3.new(-size.X,  size.Y, -size.Z),
                Vector3.new( size.X, -size.Y, -size.Z),
                Vector3.new(-size.X, -size.Y, -size.Z),
            }) do
                local pos, visible = camera:WorldToViewportPoint(cf:PointToWorldSpace(offset))
                if visible then
                    local v2 = Vector2.new(pos.X, pos.Y)
                    min = min:Min(v2)
                    max = max:Max(v2)
                    onscreen = true
                end
            end
        end

        return min, max, onscreen
    end

    -- loop through players and store the drawn shapes as objects themselves if the player is on screen
    --[[
        elements = {
            player = {
                box = drawing,
                name = drawing
            }
        }
    ]]

    local add_drawing = function(drawing_type, args)
        local drawing = Drawing.new(drawing_type)

        for i, v in pairs(args) do
            drawing[i] = v
        end

        return drawing
    end

    local add_esp = function(player)
        local objs = {
            box_outline = add_drawing("Square", { Filled = false, Color = Color3.new(0,0,0), Thickness = 3 }),
            box_line = add_drawing("Square", { Filled = false, Color = Color3.new(0,0,0), Thickness = 1 }),

            name = add_drawing("Text", { Font = 2, Size = 14, Center = true }),
            tool = add_drawing("Text", { Font = 2, Size = 14, Center = true }),
            distance = add_drawing("Text", { Font = 2, Size = 14, Center = false })
        }

        esp[player.Name] = objs
    end

    local remove_esp = function(player_name)
        for i, v in pairs(esp[player_name]) do
            v:Remove()
        end

        esp[player_name] = nil
    end

    local disable_esp = function(player_name)
        for i, v in pairs(esp[player_name]) do
            v.Visible = false
        end
    end

    local update_esp = function()
        local local_hrp = players.LocalPlayer.Character:WaitForChild("HumanoidRootPart")

        for i, v in pairs(esp) do
            local player = players:FindFirstChild(i)
            if not player then continue end
            local character = player.Character or player.CharacterAdded:wait()
            local humanoid = character:WaitForChild("Humanoid")
            local plr_hrp = character:WaitForChild("HumanoidRootPart")

            local distance = (plr_hrp.Position - local_hrp.Position).Magnitude
            if distance > visuals.max_distance or humanoid.Health <= 0 then disable_esp(i) continue end

            local min, max, onscreen = get_bounding_box(character)
            if not onscreen then disable_esp(i) continue end

            local box_top = Vector2.new((min.X + max.X) / 2, min.Y - 15)
            local box_bottom = Vector2.new((min.X + max.X) / 2, max.Y + 5)

            if visuals.player_box then
                v.box_outline.Position = min
                v.box_outline.Visible = visuals.player_box or false
                v.box_outline.Size = max - min

                v.box_line.Position = min
                v.box_line.Visible = visuals.player_box or false
                v.box_line.Color = visuals.box_color or Color3.new(0.988235, 0.274509, 0.274509)
                v.box_line.Size = max - min
            end

            if visuals.player_name then
                v.name.Position = box_top
                v.name.Text = player.Name or false
                v.name.Color = visuals.name_color or Color3.new(1,1,1)
                v.name.Visible = visuals.player_name
            end

            if visuals.distance then
                v.distance.Position = Vector2.new((min.X + max.X) + 5, max.Y)
                v.distance.Visible = visuals.distance or false
                v.distance.Text = "[" .. tostring(distance) .. "]"
                v.distance.Color = visuals.distance_color or Color3.new(0.203921, 0.615686, 1)
            end

            if character:FindFirstChildWhichIsA("Tool") and visuals.tool_name then
                v.tool.Position = box_bottom
                v.tool.Visible = visuals.tool_name or false
                v.tool.text = character:FindFirstChildWhichIsA("Tool").Name or ""
                v.tool.Color = visuals.tool_color or Color3.new(1,1,1)
            end
        end
    end

    -- inputs
    local function update_fly_controls(input, is_pressed)
        local directions = {
            [Enum.KeyCode.W] = "forward",
            [Enum.KeyCode.A] = "left",
            [Enum.KeyCode.S] = "backward",
            [Enum.KeyCode.D] = "right",
            [Enum.KeyCode.E] = "up",
            [Enum.KeyCode.Q] = "down"
        }

        if directions[input.KeyCode] then
            misc.control[directions[input.KeyCode]] = is_pressed and 1 or 0
        end
    end

    uis.InputBegan:Connect(function(input)
        update_fly_controls(input, true)
    end)
    uis.InputEnded:Connect(function(input)
        update_fly_controls(input, false)
    end)

    -- esp initialization --
    for i, v in pairs(players:GetPlayers()) do
        if v == players.LocalPlayer then continue end
        add_esp(v)
    end
    print("added esp to players")

    players.PlayerAdded:Connect(function(plr)
        if plr == players.LocalPlayer then return end
        add_esp(plr)
    end)
    print("connected to playeradded")

    players.PlayerRemoving:Connect(function(plr)
        if plr == players.LocalPlayer then return end
        remove_esp(plr.Name)
    end)
    print("connected to playerremoving")

    rs.RenderStepped:Connect(function()
        update_esp()
    end)
    print("connected to renderstepped")

    rs.Heartbeat:Connect(function()
        local lp = players.LocalPlayer
        if misc.change_stats then
            if misc.walkspeed then
                lp.Character.Humanoid.WalkSpeed = misc.walkspeed
            end
            if misc.jumppower then
                lp.Character.Humanoid.JumpPower = misc.jumppower
            end
        end

        if misc.fly then
            fly_callback()
        end

        if misc.godmode then
            gm_part.CFrame = lp.Character.HumanoidRootPart.CFrame
        else
            gm_part.CFrame = CFrame.new(0,0,0)
        end

        if aimbot.enabled then
            local target = get_target()
            if target and target:FindFirstChild("Head") then
                aimbot.target_player = target
            else
                aimbot.target_player = nil
            end
        end
    end)
end)()

--[[
local teleport = function(cframe)
    local args = {
        [1] = cframe,
        [2] = true,
    }

    game:GetService('ReplicatedStorage').movementFunction:FireServer(unpack(args))
end

workspace.ChildAdded:Connect(function(child)
    if string.find(child.Name, "BodyBag") then
        task.wait(0.5)

    end
end)
]]--
