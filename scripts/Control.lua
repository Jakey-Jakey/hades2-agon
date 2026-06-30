local HookUtils = ModRequire "HookUtils.lua"
local Players = ModRequire "Players.lua"
local HeroContext = ModRequire "HeroContext.lua"
local CombatApplication = ModRequire "CombatApplication.lua"
local MatchConfig = ModRequire "MatchConfig.lua"
local PlayersReady = ModRequire "PlayersReady.lua"
local log = ModRequire "Log.lua"

local Control = {}

local KEYBOARD_PLAYER_GAMEPAD = 4
local KEYBOARD_CONTROLLER_INDEX = 0
local GAMEPAD_CONTROLLER_INDEX = 1

Control.Schema = {
    [1] = { Device = "Keyboard", GamepadId = KEYBOARD_PLAYER_GAMEPAD },
    [2] = { Device = "Gamepad", GamepadId = 0 },
}

local applicationDeps = { Players = Players, HeroContext = HeroContext }

local function resolveDeviceSchema()
    local schema = {}
    local cfg = MatchConfig.Current()
    for playerId = 1, 2 do
        local fallback = Control.Schema[playerId]
        local selected = MatchConfig.GetDevice(cfg, playerId) or fallback
        schema[playerId] = {
            Device = selected.Device or fallback.Device,
            GamepadId = selected.GamepadId or fallback.GamepadId,
        }
    end
    return schema
end

function Control.LogInputState(tag)
    if not (AgonGetInputMethodsCount and AgonGetPlayerControllerIndex and AgonGetPlayerGamepad) then
        log("input-state[" .. tag .. "]: native diagnostics unavailable")
        return
    end

    local function cfg(name)
        if not GetConfigOptionValue then
            return "?"
        end
        local ok, val = pcall(GetConfigOptionValue, { Name = name })
        return ok and tostring(val) or "<err>"
    end

    local methods = AgonGetInputMethodsCount()

    local dump = ""
    if AgonGetInputMethodGamepad then
        for i = 0, math.max(0, methods - 1) do
            dump = dump .. (i > 0 and "," or "") .. "[" .. i .. "]=" .. tostring(AgonGetInputMethodGamepad(i))
        end
    end

    log("input-state[" .. tag .. "]: inputMethods=" .. tostring(methods)
        .. " | P1 ctrlIdx=" .. tostring(AgonGetPlayerControllerIndex(1))
        .. " gamepad=" .. tostring(AgonGetPlayerGamepad(1))
        .. " | P2 ctrlIdx=" .. tostring(AgonGetPlayerControllerIndex(2))
        .. " gamepad=" .. tostring(AgonGetPlayerGamepad(2))
        .. " | methods{" .. dump .. "}"
        .. " | AllowControlHotSwap=" .. cfg("AllowControlHotSwap")
        .. " UseMouse=" .. cfg("UseMouse"))
end

function Control.DisableHotSwap()
    if not SetConfigOption then
        log("DisableHotSwap: SetConfigOption unavailable")
        return
    end

    local ok = pcall(SetConfigOption, { Name = "AllowControlHotSwap", Value = false })
    local readback = "<no GetConfigOptionValue>"
    if GetConfigOptionValue then
        local gotOk, val = pcall(GetConfigOptionValue, { Name = "AllowControlHotSwap" })
        readback = gotOk and tostring(val) or "<read failed>"
    end
    log("DisableHotSwap: set ok=" .. tostring(ok) .. " AllowControlHotSwap now=" .. readback)
end

function Control.Apply()
    Control.DisableHotSwap()

    local schema = resolveDeviceSchema()

    local controllerIndexByPlayer = {
        [1] = KEYBOARD_CONTROLLER_INDEX,
        [2] = GAMEPAD_CONTROLLER_INDEX,
    }
    if schema[2].Device == "Keyboard" then
        controllerIndexByPlayer[1] = GAMEPAD_CONTROLLER_INDEX
        controllerIndexByPlayer[2] = KEYBOARD_CONTROLLER_INDEX
    end

    if AgonSetPlayerController then
        for playerId = 1, 2 do
            local ok = AgonSetPlayerController(playerId, controllerIndexByPlayer[playerId])
            log("Control.Apply: player " .. playerId .. " controller index -> "
                .. tostring(controllerIndexByPlayer[playerId]) .. ", ok=" .. tostring(ok))
        end
    elseif schema[2].Device == "Keyboard" then
        log("Control.Apply: AgonSetPlayerController missing - P2 keyboard mapping cannot be applied")
    end

    if SetConfigOption then
        pcall(SetConfigOption, {
            Name = "UseMouse",
            Value = schema[1].Device == "Keyboard" or schema[2].Device == "Keyboard",
        })
    end

    for playerId = 1, 2 do
        local device = schema[playerId]
        local ok = AgonSetPlayerGamepad(playerId, device.GamepadId)
        log("Control.Apply: player " .. playerId .. " -> " .. device.Device
            .. " (gamepad " .. device.GamepadId .. "), ok=" .. tostring(ok))
    end

    Control.LogInputState("after Apply")
    Control.WarnIfShared()

    if thread and wait then
        thread(function()
            wait(0.5)
            if AgonSetPlayerController then
                for playerId = 1, 2 do
                    AgonSetPlayerController(playerId, controllerIndexByPlayer[playerId])
                end
            end
            for playerId = 1, 2 do
                local device = schema[playerId]
                AgonSetPlayerGamepad(playerId, device.GamepadId)
            end
            Control.LogInputState("after re-apply")
            Control.WarnIfShared()
        end)
    end
end

function Control.WarnIfShared()
    if not (AgonGetPlayerControllerIndex and AgonGetPlayerGamepad) then
        return
    end
    local p1c, p2c = AgonGetPlayerControllerIndex(1), AgonGetPlayerControllerIndex(2)
    local p1g, p2g = AgonGetPlayerGamepad(1), AgonGetPlayerGamepad(2)
    if p1c == p2c then
        log("WARNING: P1 and P2 share controller index " .. tostring(p1c)
            .. " (one InputHandler) - a single pad will drive both heroes")
    elseif p1g == p2g then
        log("WARNING: P1 and P2 read the same gamepad " .. tostring(p1g)
            .. " - P1 was not detached from the pad")
    end
end

function Control.WrapOnControlPressed(baseFun, args)
    local handler = args[2]

    if type(handler) ~= "function" then
        return baseFun(args)
    end

    local routed = {}
    for k, v in pairs(args) do
        routed[k] = v
    end

    routed[2] = function(triggerArgs)
        CombatApplication.ApplyControlIntent(applicationDeps, { TriggerArgs = triggerArgs }, handler)
    end

    return baseFun(routed)
end

Control._wrapInstalled = false

function Control.InstallRoutingWrap()
    if Control._wrapInstalled then
        return
    end

    if not OnControlPressed then
        log("OnControlPressed missing - control routing wrap not installed")
        return
    end

    Control._wrapInstalled = true
    HookUtils.wrap("OnControlPressed", Control.WrapOnControlPressed)
    PlayersReady.Subscribe(Control.Apply)
    log("control routing wrap installed (OnControlPressed)")

    AgonApplyControl = Control.Apply
end

return Control
