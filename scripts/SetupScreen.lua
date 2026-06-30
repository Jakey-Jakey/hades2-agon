local MatchConfig = ModRequire "MatchConfig.lua"
local Sandbox = ModRequire "Sandbox.lua"
local SandboxState = ModRequire "SandboxState.lua"
local log = ModRequire "Log.lua"

local SetupScreen = {}

local SCREEN_DEF = "AgonVersusSetupScreen"

local KEYBOARD_PLAYER_GAMEPAD = 4
local KEYBOARD_PLAYER_FALLBACK_GAMEPAD = 3

local function cloneDevice(device)
    return { Device = device.Device, GamepadId = device.GamepadId }
end

local function displayDevice(device)
    if device.Device == "Keyboard" then
        return "Keyboard + Mouse"
    end
    return "Gamepad " .. tostring(device.GamepadId)
end

local function currentMenuControl()
    local isMouseVisible = false
    if GetConfigOptionValue then
        local ok, value = pcall(GetConfigOptionValue, { Name = "UseMouse" })
        isMouseVisible = ok and value == true
    end
    if isMouseVisible then
        return { Device = "Keyboard", GamepadId = KEYBOARD_PLAYER_GAMEPAD }
    end

    local gamepadId = 0
    if AgonGetPlayerGamepad then
        local ok, value = pcall(AgonGetPlayerGamepad, 1)
        if ok and type(value) == "number" and value >= 0 then
            gamepadId = value
        end
    end
    return { Device = "Gamepad", GamepadId = gamepadId }
end

local function normalizeKeyboardDevice(device, otherDevice)
    if device.Device ~= "Keyboard" then
        return cloneDevice(device)
    end
    local gamepadId = KEYBOARD_PLAYER_GAMEPAD
    if otherDevice.Device == "Gamepad" and otherDevice.GamepadId == KEYBOARD_PLAYER_GAMEPAD then
        gamepadId = KEYBOARD_PLAYER_FALLBACK_GAMEPAD
    end
    return { Device = "Keyboard", GamepadId = gamepadId }
end

local function indexOf(list, predicate)
    for index, item in ipairs(list) do
        if predicate(item) then
            return index
        end
    end
    return 1
end

local function wrapIndex(index, count, delta)
    if count <= 0 then
        return 1
    end
    return ((index - 1 + delta) % count) + 1
end

local function arenaLabel(index)
    local arena = SandboxState.Arenas[index]
    return arena and (arena.Label or arena.Name) or "?"
end

local function screenDefinitionPath()
    if type(GetCurrentModPath) == "function" and type(GetScriptDir) == "function" then
        local modPath = GetCurrentModPath()
        local scriptDir = GetScriptDir()
        if type(modPath) == "string" and type(scriptDir) == "string" and #scriptDir > #modPath then
            return scriptDir:sub(#modPath + 2) .. SCREEN_DEF .. ".sjson"
        end
    end
    return SCREEN_DEF .. ".sjson"
end

local function beginBoot(selection)
    Sandbox.MarkPending()
    if SetTempRuntimeData then
        SetTempRuntimeData("Gamemode", nil)
    end
    if type(AgonRequestSaveFreeBoot) == "function" then
        log("save-free boot: setup confirmed; requesting native pump")
        AgonRequestSaveFreeBoot()
    else
        log("save-free boot: native request missing - using the profile picker")
    end
    MainMenuOpenProfiles()
end

function SetupScreen.Open(name)
    if type(CreateMenuScreen) ~= "function" then
        return false, "CreateMenuScreen unavailable"
    end

    MatchConfig.Reset()
    local cfg = MatchConfig.Current()

    local sel = {
        p1Device = cloneDevice(MatchConfig.GetDevice(cfg, 1)),
        p2Device = cloneDevice(MatchConfig.GetDevice(cfg, 2)),
        arena = indexOf(SandboxState.Arenas, function(a)
            return a.Name == (MatchConfig.GetArena(cfg) or SandboxState.DefaultArenaName)
        end),
        p1Weapon = indexOf(MatchConfig.Weapons, function(w)
            return w == MatchConfig.GetWeapon(cfg, 1)
        end),
        p2Weapon = indexOf(MatchConfig.Weapons, function(w)
            return w == MatchConfig.GetWeapon(cfg, 2)
        end),
    }

    local menu
    local components = {}
    local booting = false

    local function setText(key, text)
        local c = components[key]
        if c then
            c:SetText(text)
        end
    end

    local function refresh()
        setText("HeaderText", "VERSUS")
        setText("Subtitle", "")
        setText("P1DeviceButton", "P1 Device:  " .. displayDevice(sel.p1Device))
        setText("P2DeviceButton", "P2 Device:  " .. displayDevice(sel.p2Device))
        setText("ArenaButton", "Arena:  " .. arenaLabel(sel.arena))
        setText("P1WeaponButton", "P1 Arm:  " .. MatchConfig.WeaponLabel(MatchConfig.Weapons[sel.p1Weapon]))
        setText("P2WeaponButton", "P2 Arm:  " .. MatchConfig.WeaponLabel(MatchConfig.Weapons[sel.p2Weapon]))
        setText("ConfirmButton", "BEGIN SPARRING")

        local conflict = MatchConfig.DeviceConflict(sel.p1Device, sel.p2Device)
        local status = ""
        if conflict == "second-keyboard" then
            status = "Only one player can claim keyboard and mouse."
        elseif conflict == "same-gamepad" then
            status = "Both players cannot claim the same gamepad."
        end
        setText("StatusText", status)
    end

    local function onClaimP1()
        sel.p1Device = currentMenuControl()
        refresh()
    end
    local function onClaimP2()
        sel.p2Device = currentMenuControl()
        refresh()
    end
    local function onCycleArena()
        sel.arena = wrapIndex(sel.arena, #SandboxState.Arenas, 1)
        refresh()
    end
    local function onCycleP1Weapon()
        sel.p1Weapon = wrapIndex(sel.p1Weapon, #MatchConfig.Weapons, 1)
        refresh()
    end
    local function onCycleP2Weapon()
        sel.p2Weapon = wrapIndex(sel.p2Weapon, #MatchConfig.Weapons, 1)
        refresh()
    end

    local function onConfirm()
        if booting then
            return
        end
        local conflict = MatchConfig.DeviceConflict(sel.p1Device, sel.p2Device)
        if conflict ~= nil then
            refresh()
            if PlaySound then
                pcall(PlaySound, { Name = "/SFX/Menu Sounds/GeneralWhooshMENULoudLow" })
            end
            return
        end

        local p1Device = normalizeKeyboardDevice(sel.p1Device, sel.p2Device)
        local p2Device = normalizeKeyboardDevice(sel.p2Device, sel.p1Device)
        MatchConfig.SetDevice(cfg, 1, p1Device)
        MatchConfig.SetDevice(cfg, 2, p2Device)
        MatchConfig.SetArena(cfg, SandboxState.Arenas[sel.arena].Name)
        MatchConfig.SetWeapon(cfg, 1, MatchConfig.Weapons[sel.p1Weapon])
        MatchConfig.SetWeapon(cfg, 2, MatchConfig.Weapons[sel.p2Weapon])
        MatchConfig.Persist(cfg)

        log("setup: confirmed arena=" .. tostring(SandboxState.Arenas[sel.arena].Name)
            .. " p1Weapon=" .. tostring(MatchConfig.Weapons[sel.p1Weapon])
            .. " p2Weapon=" .. tostring(MatchConfig.Weapons[sel.p2Weapon])
            .. " p1Device=" .. displayDevice(p1Device) .. " (" .. tostring(p1Device.GamepadId) .. ")"
            .. " p2Device=" .. displayDevice(p2Device) .. " (" .. tostring(p2Device.GamepadId) .. ")")

        booting = true
        if menu then
            pcall(function() menu:ExitScreen() end)
        end
        beginBoot(sel)
    end

    local function onCancel()
        log("setup: cancelled")
        if SetTempRuntimeData then
            SetTempRuntimeData("Gamemode", nil)
        end
        if menu then
            pcall(function() menu:ExitScreen() end)
        end
    end

    local ok, err = pcall(function()
        menu = CreateMenuScreen()
        menu:CreateBack(0.8)
        menu:CreateBackground("")
        menu:SetLowerInputBlock(true)
        menu:CreateCancelButton(onCancel)

        local function textBox(refName)
            local box = CreateGUIComponentTextBox(menu)
            menu:AddReflection(refName, box)
            components[refName] = box
            return box
        end
        textBox("HeaderText")
        textBox("Subtitle")
        textBox("StatusText")

        local function button(refName, handler)
            local btn = CreateGUIComponentButton(menu)
            menu:AddReflection(refName, btn)
            btn:AddActivationHandler(handler)
            components[refName] = btn
            return btn
        end
        button("P1DeviceButton", onClaimP1)
        button("P2DeviceButton", onClaimP2)
        button("ArenaButton", onCycleArena)
        button("P1WeaponButton", onCycleP1Weapon)
        button("P2WeaponButton", onCycleP2Weapon)
        button("ConfirmButton", onConfirm)

        refresh()
        menu:LoadDefenitions(screenDefinitionPath())
    end)

    if not ok then
        if menu then
            pcall(function() menu:ExitScreen() end)
        end
        return false, tostring(err)
    end

    log("setup: opened")
    return true
end

return SetupScreen
