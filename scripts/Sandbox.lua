local HookUtils = ModRequire "HookUtils.lua"
local Players = ModRequire "Players.lua"
local SandboxState = ModRequire "SandboxState.lua"
local MatchConfig = ModRequire "MatchConfig.lua"
local MatchOrchestration = ModRequire "MatchOrchestration.lua"
local log = ModRequire "Log.lua"

local Sandbox = {}

Sandbox.Arenas = SandboxState.Arenas
Sandbox.DefaultArenaName = SandboxState.DefaultArenaName

local BOOT_MARKER = "AgonVersusBoot"
local BARE_ENTRANCE_FUNCTION = "AgonBareArenaEntrance"

Sandbox._state = SandboxState.New()
Sandbox._hooksInstalled = false

function Sandbox.IsActive()
    return SandboxState.IsActive(Sandbox._state)
end

local function wrapDiskWrite(fnName)
    if _G[fnName] then
        HookUtils.wrap(fnName, function(original, ...)
            if Sandbox.IsActive() then
                log("sandbox: " .. fnName .. " blocked (in-memory match, no disk write)")
                return
            end
            return original(...)
        end)
    else
        log("sandbox: " .. fnName .. " missing at install - in-match save block NOT armed")
    end
end

function Sandbox.MarkPending()
    if SetTempRuntimeData then
        SetTempRuntimeData(BOOT_MARKER, "1")
        log("sandbox: Versus boot marker set (native, survives the gameplay state reload)")
    else
        log("sandbox: SetTempRuntimeData missing - cannot mark Versus boot")
    end
end

local function isBootMarked()
    if not GetTempRuntimeData then
        return false
    end
    local ok, value = GetTempRuntimeData(BOOT_MARKER)
    return ok == true and value == "1"
end

local function clearBootMarker()
    if SetTempRuntimeData then
        SetTempRuntimeData(BOOT_MARKER, false)
    end
end

local function isSandboxArenaRoom(room)
    return Sandbox.IsActive()
        and room ~= nil
        and SandboxState.ResolveArena(Sandbox.Arenas, room.Name) ~= nil
end

local function resolveP1Weapon()
    if MatchConfig and MatchConfig.GetWeapon then
        local ok, weapon = pcall(MatchConfig.GetWeapon, MatchConfig.Current(), 1)
        if ok and MatchConfig.IsValidWeapon(weapon) then
            return weapon
        end
    end
    return nil
end

local function startSyntheticRun(arena)
    local p1Weapon = resolveP1Weapon()
    if GameStateInit and InitializeMetaUpgradeState and StartNewRun then
        GameState = {}
        GameStateInit()
        InitializeMetaUpgradeState()
        StartNewRun(nil, { RoomName = arena.Name, StartingBiome = arena.Biome or "F", WeaponName = p1Weapon })
        log("sandbox: synthetic run built with selected P1 weapon=" .. tostring(p1Weapon)
            .. " (GameState=" .. tostring(GameState) .. ", room="
            .. tostring(CurrentRun and CurrentRun.CurrentRoom and CurrentRun.CurrentRoom.Name) .. ")")
        return
    end

    if StartNewGame then
        StartNewGame(arena.Name)
        log("sandbox: synthetic run built via StartNewGame fallback (selected P1 weapon unavailable)")
    else
        log("sandbox: StartNewRun/StartNewGame missing - falling back to lazy OnPreThingCreation rebuild (nil-window risk)")
    end
end

local function bareArenaEntrance(currentRun, currentRoom)
    local roomData = (RoomData and RoomData[currentRoom.Name]) or currentRoom

    if FadeIn then
        FadeIn({ Duration = 0.0 })
    end

    if FullScreenFadeInAnimation then
        local animation = currentRoom.EnterWipeAnimationOverride or roomData.EnterWipeAnimation
        if animation == nil and GetDirectionalWipeAnimation and currentRoom.HeroEndPoint ~= nil then
            animation = GetDirectionalWipeAnimation({ TowardsId = currentRoom.HeroEndPoint, Enter = true })
        end
        FullScreenFadeInAnimation(animation)
    end

    log("sandbox: bare arena entrance used for '" .. tostring(currentRoom.Name)
        .. "' (boss camera/VO suppressed)")
end

local function restoreRoomField(room, name, value)
    room[name] = value
end

local function wrapStartRoomPresentation(original, ...)
    local callArgs = { ... }
    local currentRoom = callArgs[2] or (CurrentRun and CurrentRun.CurrentRoom)

    if not isSandboxArenaRoom(currentRoom) then
        local result = { original(table.unpack(callArgs)) }
        Sandbox._CheckPendingBoot()
        return table.unpack(result)
    end

    local oldForcedEntranceName = currentRoom.ForcedEntranceFunctionName
    local oldForcedEntranceArgs = currentRoom.ForcedEntranceFunctionArgs
    local oldCameraStartPoint = currentRoom.CameraStartPoint

    currentRoom.ForcedEntranceFunctionName = BARE_ENTRANCE_FUNCTION
    currentRoom.ForcedEntranceFunctionArgs = {}
    currentRoom.CameraStartPoint = nil

    local result = nil
    local ok, err = pcall(function()
        result = { original(table.unpack(callArgs)) }
    end)

    restoreRoomField(currentRoom, "ForcedEntranceFunctionName", oldForcedEntranceName)
    restoreRoomField(currentRoom, "ForcedEntranceFunctionArgs", oldForcedEntranceArgs)
    restoreRoomField(currentRoom, "CameraStartPoint", oldCameraStartPoint)

    if not ok then
        error(err)
    end

    Sandbox._CheckPendingBoot()
    return table.unpack(result)
end

function Sandbox._CheckPendingBoot(trigger)
    if Sandbox.IsActive() then
        return false
    end

    if not isBootMarked() then
        return false
    end
    if CurrentRun == nil or CurrentRun.Hero == nil then
        log("sandbox: boot marked, but no live run yet - waiting")
        return false
    end

    clearBootMarker()
    log("sandbox: boot marker seen in a live run (" .. tostring(trigger or "unknown")
        .. ") - arming arena boot")
    if thread and wait then
        thread(function()
            wait(0.05, "AgonVersusBoot")
            Sandbox.Enter()
        end)
    else
        Sandbox.Enter()
    end
    return true
end

function Sandbox.InstallHooks()
    if Sandbox._hooksInstalled then
        return
    end
    Sandbox._hooksInstalled = true

    AgonEnterSandbox = function(name) Sandbox.Enter(name) end
    AgonExitSandbox = Sandbox.Exit
    _G[BARE_ENTRANCE_FUNCTION] = bareArenaEntrance

    if StartEncounter then
        HookUtils.wrap("StartEncounter", function(original, run, room, encounter)
            if Sandbox.IsActive() then
                log("sandbox: encounter suppressed ('"
                    .. tostring(encounter and encounter.Name) .. "') - pure PvP")
                return
            end
            return original(run, room, encounter)
        end)
    else
        log("sandbox: StartEncounter missing at install - encounter suppression NOT armed")
    end

    for _, fnName in ipairs({ "ActivatePrePlaced", "ActivatePrePlacedUnits" }) do
        if _G[fnName] then
            HookUtils.wrap(fnName, function(original, ...)
                if Sandbox.IsActive() then
                    log("sandbox: pre-placed enemy activation suppressed (" .. fnName
                        .. ") - bare arena")
                    return {}
                end
                return original(...)
            end)
        else
            log("sandbox: " .. fnName .. " missing at install - pre-placed suppression NOT armed")
        end
    end

    if MoveHeroToRoomPosition then
        HookUtils.wrap("MoveHeroToRoomPosition", function(original, ...)
            if Sandbox.IsActive() then
                log("sandbox: hero intro walk suppressed (MoveHeroToRoomPosition) - pure PvP")
                return
            end
            return original(...)
        end)
    else
        log("sandbox: MoveHeroToRoomPosition missing at install - intro-walk suppression NOT armed")
    end

    if UnlockRoomExits then
        HookUtils.wrap("UnlockRoomExits", function(original, run, room, delay)
            if Sandbox.IsActive() then
                log("sandbox: room exits kept sealed (UnlockRoomExits suppressed)")
                return
            end
            return original(run, room, delay)
        end)
    else
        log("sandbox: UnlockRoomExits missing at install - exit sealing NOT armed")
    end

    wrapDiskWrite("Save")
    wrapDiskWrite("SaveCheckpoint")

    if StartRoom then
        HookUtils.wrap("StartRoom", function(original, ...)
            if Sandbox._CheckPendingBoot("StartRoom pre") then
                return
            end
            return original(...)
        end)
    else
        log("sandbox: StartRoom missing at install - early boot trigger NOT armed")
    end

    if StartRoomPresentation then
        HookUtils.wrap("StartRoomPresentation", wrapStartRoomPresentation)
    else
        log("sandbox: StartRoomPresentation missing at install - boot trigger NOT armed")
    end

    log("sandbox hooks installed (encounter suppress + bare entrance + exit seal + save blocks + boot trigger)")
end

function Sandbox.Enter(arenaName)
    if arenaName == nil and MatchConfig and MatchConfig.GetArena then
        local ok, chosen = pcall(MatchConfig.GetArena, MatchConfig.Current())
        if ok then
            arenaName = chosen
        end
    end
    local arena = SandboxState.ResolveArena(Sandbox.Arenas, arenaName)
    if arena == nil then
        log("sandbox: refusing to enter - unknown arena '" .. tostring(arenaName)
            .. "' (not in the curated list)")
        return
    end

    Sandbox.InstallHooks()

    if Sandbox.IsActive() then
        log("sandbox: a prior match was still active on re-entry - tearing it down first")
        Sandbox.Exit()
    end

    if AgonHasPlayer and AgonHasPlayer(2) and AgonClearPlayerUnit then
        if AgonClearPlayerUnit(2) then
            log("sandbox: cleared a lingering P2 unit before the boot transition")
        end
    end

    if not SandboxState.Enter(Sandbox._state, GameState, CurrentRun) then
        log("sandbox: Enter ignored - a match is already active")
        return
    end
    log("sandbox: stashed live globals (GameState=" .. tostring(GameState)
        .. ", CurrentRun=" .. tostring(CurrentRun) .. ")")

    GameState = nil
    CurrentRun = nil
    Players.Reset()

    startSyntheticRun(arena)

    log("sandbox: booting arena '" .. arena.Name .. "' (" .. tostring(arena.Label) .. ")")
    thread(function()
        log("sandbox: load thread running - LoadMap '" .. arena.Name .. "'")
        LoadMap { Name = arena.Name, ResetBinks = true }
        log("sandbox: LoadMap returned for '" .. arena.Name .. "' (run should be live)")
    end)
end

function Sandbox.Exit()
    local stash = SandboxState.Exit(Sandbox._state)
    if stash == nil then
        return
    end

    Players.Reset()
    MatchOrchestration.Reset()
    GameState = stash.GameState
    CurrentRun = stash.CurrentRun
    log("sandbox: exited - restored prior GameState=" .. tostring(GameState)
        .. ", CurrentRun=" .. tostring(CurrentRun))
end

return Sandbox
