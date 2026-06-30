local MatchOrchestration = {}

local deps = nil
local state = nil
local installed = false

local FALLBACK_INTRO_BEAT = 2.0
local FALLBACK_ROUND_END_BEAT = 2.5

local function introBeat()
    local vt = deps and deps.VersusTuning
    return (vt and vt.Beats().introSeconds) or FALLBACK_INTRO_BEAT
end

local function roundEndBeat()
    local vt = deps and deps.VersusTuning
    return (vt and vt.Beats().roundEndSeconds) or FALLBACK_ROUND_END_BEAT
end

local function log(msg)
    if deps and deps.log then
        deps.log(msg)
    end
end

local function fx(name, ...)
    local effects = deps and deps.Effects
    if effects and effects[name] then
        return effects[name](...)
    end
end

local function hud(name, ...)
    local h = deps and deps.Hud
    if h and h[name] then
        return h[name](...)
    end
end

local function schedule(seconds, fn)
    if deps and deps.Schedule then
        deps.Schedule(seconds, fn)
    end
end

local function heroOf(playerId)
    return deps.Players.GetHero(playerId)
end

function MatchOrchestration.Configure(d)
    deps = d
end

function MatchOrchestration.GetState()
    return state
end

local function armTimer(round)
    local secs = (state and state.config and state.config.roundTimerSeconds) or 90
    schedule(secs, function()
        if state ~= nil and state.round == round and state.phase == deps.Match.Phase.InRound then
            MatchOrchestration.ExpireTimer(round)
        end
    end)
end

local function beginRound()
    local Match = deps.Match
    state = Match.reduce(state, { type = Match.Event.RoundStarted })
    local round = state.round
    log("round " .. tostring(round) .. " starting (input-locked intro)")
    fx("LockInput")
    fx("ApplyTunedVitals", heroOf(1))
    fx("ApplyTunedVitals", heroOf(2))
    fx("ResetPositions", heroOf(1), heroOf(2))
    fx("Announce", "Round " .. tostring(round), 1.5)
    schedule(introBeat(), function()
        if not (state ~= nil and state.round == round and state.phase == Match.Phase.InRound) then
            return
        end
        fx("Announce", "Fight!", 1.0)
        fx("UnlockInput")
        armTimer(round)
        local secs = (state and state.config and state.config.roundTimerSeconds) or 90
        hud("StartRoundClock", secs)
    end)
    return state
end

function MatchOrchestration.Start(config)
    assert(deps and deps.Match, "MatchOrchestration.Start before Configure")
    state = deps.Match.initial(config)
    log("match started")
    return beginRound()
end

function MatchOrchestration.StartIfReady()
    if deps == nil or deps.Sandbox == nil then
        return state
    end
    if deps.Sandbox.IsActive() and not MatchOrchestration.IsLive() then
        return MatchOrchestration.Start()
    end
    return state
end

local function resetForNextRound()
    local p1, p2 = heroOf(1), heroOf(2)
    fx("Heal", p1)
    fx("Heal", p2)
    fx("ClearTransient", p1)
    fx("ClearTransient", p2)
    log("round reset: both heroes healed out of the downed pose and cleared")
end

function MatchOrchestration.BeginNextRound()
    if state == nil or deps.Match.isOver(state) then
        return state
    end
    resetForNextRound()
    return beginRound()
end

function MatchOrchestration.ExpireTimer(round)
    if state == nil then
        return state
    end
    if round ~= nil and state.round ~= round then
        return state
    end
    if state.phase ~= deps.Match.Phase.InRound then
        return state
    end
    state = deps.Match.reduce(state, { type = deps.Match.Event.TimerExpired })
    local floor = state.config.suddenDeathHpFloor
    fx("Clamp", heroOf(1), floor)
    fx("Clamp", heroOf(2), floor)
    fx("Announce", "Sudden Death!", 2.0)
    log("round " .. tostring(state.round) .. " timer expired -> Sudden Death (both clamped to "
        .. tostring(floor) .. " HP)")
    return state
end

function MatchOrchestration.IsLive()
    return state ~= nil and not deps.Match.isOver(state)
end

function MatchOrchestration.IsRoundLive()
    if state == nil then
        return false
    end
    local Phase = deps.Match.Phase
    return state.phase == Phase.InRound or state.phase == Phase.SuddenDeath
end

function MatchOrchestration.Reset()
    state = nil
    hud("Reset")
end

function MatchOrchestration.HandleDamageResolved(victimHero, triggerArgs)
    if state == nil or victimHero == nil then
        return state
    end
    local Match = deps.Match
    local playerId = deps.Players.GetPlayerId(victimHero)
    if playerId == nil then
        return state
    end
    local hp = victimHero.Health
    if hp ~= nil and hp > 0 then
        return state
    end
    if not MatchOrchestration.IsRoundLive() then
        return state
    end

    state = Match.reduce(state, { type = Match.Event.HeroDied, player = playerId })
    log("round loss: player " .. tostring(playerId) .. " down -> phase " .. tostring(state.phase)
        .. " (wins " .. tostring(state.roundWins[1]) .. "-" .. tostring(state.roundWins[2]) .. ")")

    fx("LockInput")
    fx("PresentDowned", victimHero, playerId)

    if state.phase == Match.Phase.MatchOver then
        fx("PresentVictory", state.victor)
        log("match over - player " .. tostring(state.victor) .. " wins the match")
    elseif state.phase == Match.Phase.RoundOver then
        schedule(roundEndBeat(), function()
            if state ~= nil and state.phase == Match.Phase.RoundOver then
                MatchOrchestration.BeginNextRound()
            end
        end)
    end
    return state
end

function MatchOrchestration.Rematch(config)
    log("rematch requested - restarting match in place")
    resetForNextRound()
    return MatchOrchestration.Start(config)
end

function MatchOrchestration.Install()
    if installed then
        return
    end
    if not (deps and deps.HookUtils and deps.Sandbox) then
        log("match orchestration: Install skipped - HookUtils/Sandbox not injected")
        return
    end
    if type(Kill) ~= "function" then
        log("match orchestration: Kill global missing - round-loss intercept NOT armed")
        return
    end
    installed = true

    if deps.PlayersReady then
        deps.PlayersReady.Subscribe(MatchOrchestration.StartIfReady)
        log("match orchestration: subscribed StartIfReady to PlayersReady")
    end

    local HookUtils = deps.HookUtils
    local Players = deps.Players
    local Sandbox = deps.Sandbox

    HookUtils.wrap("Kill", function(originalKill, victim, triggerArgs)
        if not (Sandbox.IsActive() and state ~= nil) then
            return originalKill(victim, triggerArgs)
        end

        local engineVictimIsHero = victim ~= nil and Players.IsHero(victim)
        local loser = nil
        if engineVictimIsHero and (victim.Health == nil or victim.Health <= 0) then
            loser = victim
        else
            loser = Players.FindDownedHero()
        end

        if loser == nil then
            return originalKill(victim, triggerArgs)
        end

        if not MatchOrchestration.IsRoundLive() then
            return
        end

        local loserId = Players.GetPlayerId(loser)
        local engineId = engineVictimIsHero and Players.GetPlayerId(victim) or nil
        if engineId ~= nil and engineId ~= loserId then
            log("Kill: engine victim was player " .. tostring(engineId)
                .. " (CurrentRun.Hero restored to P1), but player " .. tostring(loserId)
                .. " is the one at 0 HP - crediting the real loser")
        end
        log("Kill intercepted - round loss for player " .. tostring(loserId)
            .. " (scoring instead of the run-death loop)")
        loser.Health = 0
        MatchOrchestration.HandleDamageResolved(loser, triggerArgs)
        return
    end)

    AgonForceSuddenDeath = function()
        return MatchOrchestration.ExpireTimer(state and state.round)
    end
    AgonRematch = function()
        return MatchOrchestration.Rematch()
    end
    AgonMatchState = function()
        if state == nil then
            log("match state: no match")
            return
        end
        log("match state: phase=" .. tostring(state.phase) .. " round=" .. tostring(state.round)
            .. " wins=" .. tostring(state.roundWins[1]) .. "-" .. tostring(state.roundWins[2])
            .. " victor=" .. tostring(state.victor))
        return state
    end

    log("match orchestration: round loop armed (Kill intercept + timer/SD/victory/rematch, gated on a live match)")
end

return MatchOrchestration
