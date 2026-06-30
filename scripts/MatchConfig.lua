local MatchConfig = {}

MatchConfig.Weapons = {
    "WeaponStaffSwing",
    "WeaponDagger",
    "WeaponTorch",
    "WeaponAxe",
    "WeaponLob",
    "WeaponSuit",
}

MatchConfig.WeaponLabels = {
    WeaponStaffSwing = "Witch's Staff",
    WeaponDagger = "Sister Blades",
    WeaponTorch = "Umbral Flames",
    WeaponAxe = "Moonstone Axe",
    WeaponLob = "Argent Skull",
    WeaponSuit = "The Black Coat",
}

MatchConfig.DefaultWeapon = "WeaponDagger"

MatchConfig.DefaultDevices = {
    [1] = { Device = "Keyboard", GamepadId = 4 },
    [2] = { Device = "Gamepad", GamepadId = 0 },
}

function MatchConfig.IsValidWeapon(name)
    if type(name) ~= "string" then
        return false
    end
    for _, w in ipairs(MatchConfig.Weapons) do
        if w == name then
            return true
        end
    end
    return false
end

function MatchConfig.WeaponLabel(name)
    return MatchConfig.WeaponLabels[name] or tostring(name)
end

local function copyDevice(d)
    if type(d) ~= "table" then
        return nil
    end
    return { Device = d.Device, GamepadId = d.GamepadId }
end

function MatchConfig.New()
    return {
        arena = nil,
        weapons = {
            [1] = MatchConfig.DefaultWeapon,
            [2] = MatchConfig.DefaultWeapon,
        },
        devices = {
            [1] = copyDevice(MatchConfig.DefaultDevices[1]),
            [2] = copyDevice(MatchConfig.DefaultDevices[2]),
        },
    }
end

function MatchConfig.SetWeapon(cfg, playerId, weaponName)
    if cfg == nil or not MatchConfig.IsValidWeapon(weaponName) then
        return false
    end
    cfg.weapons[playerId] = weaponName
    return true
end

function MatchConfig.GetWeapon(cfg, playerId)
    if cfg and cfg.weapons and cfg.weapons[playerId] then
        return cfg.weapons[playerId]
    end
    return MatchConfig.DefaultWeapon
end

function MatchConfig.SetDevice(cfg, playerId, device)
    local copy = copyDevice(device)
    if cfg == nil or copy == nil or (copy.Device ~= "Keyboard" and copy.Device ~= "Gamepad") then
        return false
    end
    cfg.devices[playerId] = copy
    return true
end

function MatchConfig.GetDevice(cfg, playerId)
    if cfg and cfg.devices and cfg.devices[playerId] then
        return cfg.devices[playerId]
    end
    return copyDevice(MatchConfig.DefaultDevices[playerId]) or { Device = "Gamepad", GamepadId = 0 }
end

function MatchConfig.SetArena(cfg, arenaName)
    if cfg ~= nil then
        cfg.arena = arenaName
    end
end

function MatchConfig.GetArena(cfg)
    return cfg and cfg.arena or nil
end

function MatchConfig.DeviceConflict(d1, d2)
    if d1 == nil or d2 == nil then
        return nil
    end
    if d1.Device == "Keyboard" and d2.Device == "Keyboard" then
        return "second-keyboard"
    end
    if d1.Device == "Gamepad" and d2.Device == "Gamepad" and d1.GamepadId == d2.GamepadId then
        return "same-gamepad"
    end
    return nil
end

MatchConfig._current = nil

local RUNTIME_KEY = "AgonVersusConfig"
local SERIALIZED_PREFIX = "v1"

local function isValidDevice(device)
    return type(device) == "table"
        and (device.Device == "Keyboard" or device.Device == "Gamepad")
        and type(device.GamepadId) == "number"
end

function MatchConfig.Export(cfg)
    cfg = cfg or MatchConfig.New()
    return {
        arena = cfg.arena,
        weapons = {
            [1] = MatchConfig.GetWeapon(cfg, 1),
            [2] = MatchConfig.GetWeapon(cfg, 2),
        },
        devices = {
            [1] = MatchConfig.GetDevice(cfg, 1),
            [2] = MatchConfig.GetDevice(cfg, 2),
        },
    }
end

function MatchConfig.Import(data)
    local cfg = MatchConfig.New()
    if type(data) ~= "table" then
        return cfg
    end

    if data.arena == nil or type(data.arena) == "string" then
        cfg.arena = data.arena
    end

    if type(data.weapons) == "table" then
        for playerId = 1, 2 do
            if MatchConfig.IsValidWeapon(data.weapons[playerId]) then
                cfg.weapons[playerId] = data.weapons[playerId]
            end
        end
    end

    if type(data.devices) == "table" then
        for playerId = 1, 2 do
            if isValidDevice(data.devices[playerId]) then
                cfg.devices[playerId] = copyDevice(data.devices[playerId])
            end
        end
    end

    return cfg
end

local function splitPayload(payload)
    local parts = {}
    for part in tostring(payload):gmatch("([^\t]*)\t?") do
        parts[#parts + 1] = part
        if #parts >= 8 then
            break
        end
    end
    return parts
end

local function serialField(value)
    if value == nil then
        return ""
    end
    return tostring(value)
end

function MatchConfig.Serialize(cfg)
    cfg = MatchConfig.Export(cfg or MatchConfig.New())
    local d1 = MatchConfig.GetDevice(cfg, 1)
    local d2 = MatchConfig.GetDevice(cfg, 2)
    return table.concat({
        SERIALIZED_PREFIX,
        serialField(cfg.arena),
        serialField(MatchConfig.GetWeapon(cfg, 1)),
        serialField(MatchConfig.GetWeapon(cfg, 2)),
        serialField(d1.Device),
        serialField(d1.GamepadId),
        serialField(d2.Device),
        serialField(d2.GamepadId),
    }, "\t")
end

function MatchConfig.Deserialize(payload)
    if type(payload) ~= "string" then
        return MatchConfig.New()
    end
    local parts = splitPayload(payload)
    if parts[1] ~= SERIALIZED_PREFIX then
        return MatchConfig.New()
    end
    return MatchConfig.Import({
        arena = parts[2] ~= "" and parts[2] or nil,
        weapons = {
            [1] = parts[3],
            [2] = parts[4],
        },
        devices = {
            [1] = { Device = parts[5], GamepadId = tonumber(parts[6]) },
            [2] = { Device = parts[7], GamepadId = tonumber(parts[8]) },
        },
    })
end

function MatchConfig.Persist(cfg)
    if type(SetTempRuntimeData) == "function" then
        SetTempRuntimeData(RUNTIME_KEY, MatchConfig.Serialize(cfg or MatchConfig.Current()))
    end
end

local function loadPersisted()
    if type(GetTempRuntimeData) ~= "function" then
        return nil
    end
    local ok, value = GetTempRuntimeData(RUNTIME_KEY)
    if ok == true and type(value) == "string" then
        return MatchConfig.Deserialize(value)
    end
    if ok == true and type(value) == "table" then
        return MatchConfig.Import(value)
    end
    return nil
end

MatchConfig._hydrated = false

function MatchConfig.Current()
    if MatchConfig._current == nil then
        MatchConfig._current = loadPersisted() or MatchConfig.New()
        MatchConfig._hydrated = true
    end
    return MatchConfig._current
end

function MatchConfig.Reset()
    MatchConfig._current = MatchConfig.New()
    MatchConfig._hydrated = true
end

return MatchConfig
