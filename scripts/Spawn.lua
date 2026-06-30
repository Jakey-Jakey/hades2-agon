local HookUtils = ModRequire "HookUtils.lua"
local Players = ModRequire "Players.lua"
local HeroContext = ModRequire "HeroContext.lua"
local Sandbox = ModRequire "Sandbox.lua"
local MatchConfig = ModRequire "MatchConfig.lua"
local PlayersReady = ModRequire "PlayersReady.lua"
local log = ModRequire "Log.lua"

local Spawn = {}

Spawn._spawnRoom = nil

local DUMMY_WEAPON = "WeaponDagger"

local function resolveP2Weapon()
    if MatchConfig and MatchConfig.GetWeapon then
        local ok, weapon = pcall(MatchConfig.GetWeapon, MatchConfig.Current(), 2)
        if ok and MatchConfig.IsValidWeapon(weapon) then
            return weapon
        end
    end
    return DUMMY_WEAPON
end

local function reapplyMainHeroWeaponAnimations()
    if type(HandleWeaponAnimSwaps) ~= "function" or Players.MainHero == nil then
        return
    end
    local ok, err = pcall(HeroContext.As, Players.MainHero, HandleWeaponAnimSwaps)
    if ok then
        log("SpawnDummy: restored global weapon animation swaps to P1 after P2 setup")
    else
        log("SpawnDummy: failed to restore P1 weapon animation swaps: " .. tostring(err))
    end
end

local DUMMY_OFFSET_X = 200

function Spawn.SpawnDummy()
    log("SpawnDummy: invoked")

    if CurrentRun == nil or CurrentRun.Hero == nil or CurrentRun.CurrentRoom == nil then
        log("SpawnDummy: no active run/room - enter a combat room first (CurrentRun="
            .. tostring(CurrentRun) .. ", Hero=" .. tostring(CurrentRun and CurrentRun.Hero)
            .. ", Room=" .. tostring(CurrentRun and CurrentRun.CurrentRoom) .. ")")
        return
    end

    Players.SetMain(CurrentRun.Hero)

    Players.ClearDummies()

    local playerIndex = 2
    if not AgonHasPlayer(2) then
        playerIndex = AgonCreatePlayer()
        if not playerIndex then
            log("SpawnDummy: AgonCreatePlayer failed (no free slot?)")
            return
        end
        log("SpawnDummy: created player slot " .. tostring(playerIndex))
    else
        log("SpawnDummy: reusing existing player slot 2")
    end

    if AgonClearPlayerUnit(playerIndex) then
        log("SpawnDummy: cleared a stale unit pointer on slot " .. tostring(playerIndex))
    end

    local unitId = AgonCreatePlayerUnit(playerIndex)
    if not unitId then
        log("SpawnDummy: AgonCreatePlayerUnit failed")
        return
    end
    log("SpawnDummy: created unit " .. tostring(unitId))

    local p2Weapon = resolveP2Weapon()
    local dummy = CreateNewHero(nil, { WeaponName = p2Weapon })
    dummy.AgonPlayerIndex = playerIndex

    HookUtils.wrapOnce("GetIdsByType", function()
        return { unitId }
    end)
    dummy.ObjectId = nil

    local ok, err = pcall(HeroContext.As, dummy, SetupHeroObject, CurrentRun.CurrentRoom, false)

    if not ok then
        log("SpawnDummy: SetupHeroObject error: " .. tostring(err))
        return
    end
    reapplyMainHeroWeaponAnimations()

    dummy.HideHealthBar = true
    Players.AddDummy(dummy)
    Teleport { Id = dummy.ObjectId, DestinationId = Players.MainHero.ObjectId, OffsetX = DUMMY_OFFSET_X, OffsetY = 0 }

    PlayersReady.Emit()

    log("SpawnDummy: P2 spawned + PlayersReady emitted (unit=" .. tostring(unitId)
        .. ", ObjectId=" .. tostring(dummy.ObjectId) .. ", weapon=" .. tostring(p2Weapon) .. ")")
end

function Spawn.InstallDebugTrigger()
    log("probe (install-time): rom=" .. type(rom)
        .. " rom.gui=" .. type(rom and rom.gui)
        .. " add_imgui=" .. type(rom and rom.gui and rom.gui.add_imgui)
        .. " ImGui=" .. type(ImGui))

    if StartRoomPresentation and LeaveRoom then
        HookUtils.wrap("LeaveRoom", function(original, ...)
            if AgonHasPlayer and AgonHasPlayer(2) and AgonClearPlayerUnit then
                if AgonClearPlayerUnit(2) then
                    log("LeaveRoom: cleared P2's unit pointer before room teardown")
                end
            end
            Spawn._spawnRoom = nil
            return original(...)
        end)

        HookUtils.wrap("StartRoomPresentation", function(original, ...)
            local result = { original(...) }
            local room = select(2, ...) or (CurrentRun and CurrentRun.CurrentRoom)
            if Sandbox.IsActive() and CurrentRun and CurrentRun.Hero and room and room.Encounter
                and room ~= Spawn._spawnRoom then
                Spawn._spawnRoom = room
                log("auto-spawn: Versus arena presentation finished (name="
                    .. tostring(room.Name) .. ") - spawning P2")
                Spawn.SpawnDummy()
            end
            return table.unpack(result)
        end)
        log("auto-spawn registered (StartRoomPresentation post + LeaveRoom clear, active Versus match, once per room)")
    else
        log("StartRoomPresentation/LeaveRoom unavailable - auto-spawn not installed")
    end

    if rom and rom.gui and rom.gui.add_imgui then
        local guiProbed = false
        local ok = pcall(function()
            rom.gui.add_imgui(function()
                if not guiProbed then
                    guiProbed = true
                    print("[AGON] gui render probe: ImGui=" .. type(ImGui))
                end
                if ImGui then
                    if ImGui.Begin("AGON Debug") then
                        ImGui.Text("Friendly-fire spike")
                        if ImGui.Button("Spawn P2 Dummy") then
                            Spawn.SpawnDummy()
                        end
                    end
                    ImGui.End()
                end
            end)
        end)
        log("rom.gui.add_imgui registered ok=" .. tostring(ok))
    end

    if rom and rom.inputs and rom.inputs.on_key_pressed then
        local ok = pcall(function()
            rom.inputs.on_key_pressed { "ControlAlt J", Name = "AGON Spawn Dummy", function()
                log("ControlAlt J pressed (rom.inputs) - invoking SpawnDummy")
                Spawn.SpawnDummy()
            end }
        end)
        log("rom.inputs ControlAlt J registered ok=" .. tostring(ok))
    end

    AgonSpawnDummy = Spawn.SpawnDummy
end

return Spawn
