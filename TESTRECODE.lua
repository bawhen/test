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
    aimbot.target_player = get_target()

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
    SchemeColor = Color3.fromRGB(46, 143, 255),
    Background = Color3.fromRGB(0, 0, 0),
    Header = Color3.fromRGB(20, 20, 20),
    TextColor = Color3.fromRGB(255,255,255),
    ElementColor = Color3.fromRGB(20, 20, 20)
}

local lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
local window = lib.CreateLib("Mongoloid Recode [BETA]", colors)

local aimbot_tab = window:NewTab("Aimbot")
local visuals_tab = window:NewTab("Visuals")
local misc_tab = window:NewTab("Misc")

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

-- DRAWING STUFF --
local strings = {}
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

    local function RunVisuals(ctx)
        local localplayer = players.LocalPlayer
        local hrp = localplayer.Character:FindFirstChild("HumanoidRootPart") or nil
        local mouse = uis:GetMouseLocation()

        for i, v in pairs(players:GetChildren()) do
            local character = v.Character; if not character or v == players.LocalPlayer then continue end
            local humanoid = character.Humanoid; if not humanoid or humanoid and humanoid.Health <= 0 then continue end
            local target_hrp = character.HumanoidRootPart; if not target_hrp then continue end

            local cur_distance = (character.HumanoidRootPart.Position - hrp.Position).Magnitude
            if cur_distance > visuals.max_distance then continue end

            local min, max, onscreen = get_bounding_box(character)
            if not onscreen then continue end

            strings = {}

            local box_top = Vector2.new((min.X + max.X) / 2, min.Y - 15)
            local box_bottom = Vector2.new((min.X + max.X) / 2, max.Y + 5)

            if visuals.player_box then
                ctx.Rectangle(min, max - min, Color3.new(0, 0, 0), 1, 0.3, 3)
                ctx.Rectangle(min, max - min, visuals.box_color or Color3.new(1, 0.243137, 0.243137), 1, 0.3, 1)
            end

            if visuals.player_name then
                ctx.OutlinedText(box_top, Drawing.Fonts.System, 12, visuals.name_color or Color3.new(1,1,1), 1, Color3.new(0, 0, 0), 1, v.Name, true)
            end

            if visuals.tool_name then
                if character:FindFirstChildWhichIsA("Tool") then
                    local tool_name = character:FindFirstChildWhichIsA("Tool").Name
                    table.insert(strings, { Text = tool_name, Color = visuals.tool_color or Color3.new(1,1,1), Position = "Bottom" })
                end
            end

            if visuals.distance and target_hrp and hrp then
                local target_pos = target_hrp.Position
                local local_pos  = hrp.Position
                local distance = (target_pos - local_pos).Magnitude

                table.insert(strings, { Text = "[" .. tostring(math.floor(distance)) .. "]", Color = visuals.distance_color or Color3.new(0.184313, 0.635294, 1), Position = "Bottom" })
            end

            for index, string in pairs(strings) do
                if string.Position == "Top" then
                    local top_pos = Vector2.new(box_top.X, box_top.Y - ((index - 1) * 10))
                    ctx.OutlinedText(top_pos, Drawing.Fonts.System, 12, string.Color, 1, Color3.new(0, 0, 0), 1, string.Text, true)
                else
                    local bottom_pos = Vector2.new(box_bottom.X, box_bottom.Y + ((index - 1) * 10))
                    ctx.OutlinedText(bottom_pos, Drawing.Fonts.System, 12, string.Color, 1, Color3.new(0, 0, 0), 1, string.Text, true)
                end
            end

            if aimbot.fov_circle then
                ctx.Circle(mouse, aimbot.fov_radius, Color3.new(0, 0, 0), 1, aimbot.fov_radius / 2, 3)
                ctx.Circle(mouse, aimbot.fov_radius, visuals.fov_color or Color3.new(0.184313, 0.635294, 1), 1, aimbot.fov_radius / 2, 1)
            end

            if aimbot.show_target and aimbot.target_player then
                local target = aimbot.target_player:FindFirstChild("Head")
                ctx.Line(mouse, get_screen_pos(target), visuals.target_color or Color3.new(1,1,1), 1, 1)
            end
        end
    end


    -- drawing hook
    DrawingImmediate.GetPaint(1):Connect(function(ctx)
        drawing_ctx = ctx
    end)

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

        RunVisuals(drawing_ctx)
    end)

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
end)()