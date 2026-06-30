local Match = {}

Match.Phase = {
    PreMatch = "PreMatch",
    InRound = "InRound",
    RoundOver = "RoundOver",
    SuddenDeath = "SuddenDeath",
    MatchOver = "MatchOver",
}

Match.Event = {
    RoundStarted = "RoundStarted",
    HeroDied = "HeroDied",
    TimerExpired = "TimerExpired",
    SuddenDeathStarted = "SuddenDeathStarted",
}

local function loadTuning()
    if type(ModRequire) == "function" then
        local ok, m = pcall(function()
            return ModRequire("VersusTuning.lua")
        end)
        if ok and type(m) == "table" then
            return m
        end
    end
    if type(AGON_TEST_ROOT) == "string" then
        local chunk = loadfile(AGON_TEST_ROOT .. "/scripts/VersusTuning.lua")
        if chunk then
            return chunk()
        end
    end
    return nil
end

local VersusTuning = loadTuning()

Match.DefaultConfig = VersusTuning and VersusTuning.Pacing() or {
    players = 2,
    roundsToWin = 3,
    maxRounds = 5,
    suddenDeathHpFloor = 10,
    roundTimerSeconds = 90,
}

local function opponentOf(p)
    return p == 1 and 2 or 1
end

local function cloneState(state)
    local roundWins = {}
    for i, v in pairs(state.roundWins) do
        roundWins[i] = v
    end
    return {
        config = state.config,
        phase = state.phase,
        round = state.round,
        roundWins = roundWins,
        suddenDeath = state.suddenDeath,
        victor = state.victor,
    }
end

function Match.initial(config)
    local cfg = {}
    for k, v in pairs(Match.DefaultConfig) do
        cfg[k] = v
    end
    if config then
        for k, v in pairs(config) do
            cfg[k] = v
        end
    end

    local roundWins = {}
    for p = 1, cfg.players do
        roundWins[p] = 0
    end

    return {
        config = cfg,
        phase = Match.Phase.PreMatch,
        round = 0,
        roundWins = roundWins,
        suddenDeath = false,
        victor = nil,
    }
end

function Match.isOver(state)
    return state.phase == Match.Phase.MatchOver
end

function Match.victor(state)
    return state.victor
end

local function isRoundLive(phase)
    return phase == Match.Phase.InRound or phase == Match.Phase.SuddenDeath
end

local function applyRoundStarted(next)
    if next.phase == Match.Phase.MatchOver then
        return next
    end
    next.round = next.round + 1
    next.phase = Match.Phase.InRound
    next.suddenDeath = false
    return next
end

local function applyHeroDied(next, event)
    if not isRoundLive(next.phase) then
        return next
    end

    local deceased = event.player
    if deceased == nil or next.roundWins[deceased] == nil then
        return next
    end

    local winner = opponentOf(deceased)
    next.roundWins[winner] = next.roundWins[winner] + 1

    if next.roundWins[winner] >= next.config.roundsToWin then
        next.phase = Match.Phase.MatchOver
        next.victor = winner
    else
        next.phase = Match.Phase.RoundOver
    end
    return next
end

local function applyTimerExpired(next)
    if next.phase ~= Match.Phase.InRound then
        return next
    end
    next.phase = Match.Phase.SuddenDeath
    next.suddenDeath = true
    return next
end

local function applySuddenDeathStarted(next)
    if not isRoundLive(next.phase) then
        return next
    end
    next.phase = Match.Phase.SuddenDeath
    next.suddenDeath = true
    return next
end

local HANDLERS = {
    [Match.Event.RoundStarted] = applyRoundStarted,
    [Match.Event.HeroDied] = applyHeroDied,
    [Match.Event.TimerExpired] = applyTimerExpired,
    [Match.Event.SuddenDeathStarted] = applySuddenDeathStarted,
}

function Match.reduce(state, event)
    if event == nil or event.type == nil then
        return state
    end
    local handler = HANDLERS[event.type]
    if handler == nil then
        return state
    end
    return handler(cloneState(state), event)
end

return Match
