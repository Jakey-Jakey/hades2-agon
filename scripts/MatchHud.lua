local MatchHud = {}

local deps = nil

local LAYOUT = {
    Y = 1006,
    TimerOffsetY = -6,
    PipOffsetY = -2,
    PipSideGap = 90,
    PipSpacing = 52,
    PipTextureFilled = "GUI\\HUD\\Harvest\\ExorcismPipFilled",
    PipTextureEmpty = "GUI\\HUD\\Harvest\\ExorcismPipUnfilled",
    PipScale = 0.72,
    Group = "Combat_Menu",
    Font = "P22UndergroundSCHeavy",
    TimerFontSize = 52,
    ShowBacking = false,
    BackingColor = { 8, 6, 16, 150 },
    BackingScaleX = 4.2,
    BackingScaleY = 0.95,
    BackingOffsetY = 8,
    PipEmptyP1 = { 110, 150, 205, 205 },
    PipEmptyP2 = { 205, 140, 95, 205 },
    PipFillP1 = { 70, 160, 255, 255 },
    PipFillP2 = { 255, 140, 60, 255 },
    PipOutlineP1 = { R = 90, G = 175, B = 255, Opacity = 0.95, Thickness = 2.5, Threshold = 0.5 },
    PipOutlineP2 = { R = 255, G = 135, B = 55, Opacity = 0.95, Thickness = 2.5, Threshold = 0.5 },
    TimerColor = { 255, 255, 255, 255 },
    SuddenDeathColor = { 255, 80, 60, 255 },
}

local built = false
local ids = nil
local clock = { running = false, remaining = 0, endTime = nil }
local lastPips = nil
local lastTimerText = nil

local function log(msg)
    if deps and deps.log then
        deps.log(msg)
    end
end

local function guarded(label, body)
    local ok, err = pcall(body)
    if not ok then
        log("hud " .. label .. " failed (soft): " .. tostring(err))
    end
end

function MatchHud.FormatClock(seconds)
    if type(seconds) ~= "number" or seconds < 0 then
        seconds = 0
    end
    return string.format("%d", math.ceil(seconds))
end

function MatchHud.PipFill(state, playerId)
    if state == nil or state.config == nil then
        return 0, 0
    end
    local total = state.config.roundsToWin or 0
    local wins = (state.roundWins and state.roundWins[playerId]) or 0
    if wins < 0 then wins = 0 end
    if wins > total then wins = total end
    return wins, total
end

function MatchHud.Configure(d)
    deps = d
end

local function screenCenterX()
    if type(ScreenCenterX) == "number" then
        return ScreenCenterX
    end
    if type(ScreenWidth) == "number" then
        return ScreenWidth / 2
    end
    return 960
end

local function baseY()
    if type(ScreenHeight) == "number" then
        return ScreenHeight - (1080 - LAYOUT.Y)
    end
    return LAYOUT.Y
end

local function setPipColor(id, color)
    if id and type(SetColor) == "function" then
        pcall(SetColor, { Id = id, Color = color, Duration = 0.0 })
    end
end

local function addPipOutline(id, outline)
    if id and outline and type(AddOutline) == "function" then
        local o = {
            Id = id, R = outline.R, G = outline.G, B = outline.B,
            Opacity = outline.Opacity, Thickness = outline.Thickness, Threshold = outline.Threshold,
        }
        pcall(AddOutline, o)
    end
end

local function setPipAnimation(id, animName)
    if id and type(SetAnimation) == "function" then
        pcall(SetAnimation, { Name = animName, DestinationId = id })
    end
end

local function applyPip(playerId, pipId, filled)
    if filled then
        setPipAnimation(pipId, LAYOUT.PipTextureFilled)
        setPipColor(pipId, playerId == 1 and LAYOUT.PipFillP1 or LAYOUT.PipFillP2)
    else
        setPipAnimation(pipId, LAYOUT.PipTextureEmpty)
        setPipColor(pipId, playerId == 1 and LAYOUT.PipEmptyP1 or LAYOUT.PipEmptyP2)
    end
end

local function build()
    if built then
        return
    end
    if type(CreateScreenObstacle) ~= "function" then
        log("hud: CreateScreenObstacle missing - HUD not built")
        return
    end
    guarded("build", function()
        local cx = screenCenterX()
        local y = baseY()
        local handles = { pips = { [1] = {}, [2] = {} } }

        if LAYOUT.ShowBacking then
            local backId = CreateScreenObstacle({
                Name = "rectangle01", Group = LAYOUT.Group,
                X = cx, Y = y + LAYOUT.BackingOffsetY,
                ScaleX = LAYOUT.BackingScaleX, ScaleY = LAYOUT.BackingScaleY,
            })
            handles.backing = backId
            setPipColor(backId, LAYOUT.BackingColor)
        end

        local timerId = CreateScreenObstacle({
            Name = "BlankObstacle", Group = LAYOUT.Group,
            X = cx, Y = y + LAYOUT.TimerOffsetY,
        })
        handles.timer = timerId
        if type(CreateTextBox) == "function" then
            CreateTextBox({
                Id = timerId,
                Text = "",
                FontSize = LAYOUT.TimerFontSize,
                Font = LAYOUT.Font,
                Color = LAYOUT.TimerColor,
                Justification = "Center",
                ShadowBlur = 0, ShadowColor = { 0, 0, 0, 1 }, ShadowOffset = { 0, 3 },
            })
        end

        local function buildSide(playerId, total, dir)
            local pipY = y + LAYOUT.PipOffsetY
            for i = 1, math.max(total, 0) do
                local x = cx + dir * (LAYOUT.PipSideGap + (i - 1) * LAYOUT.PipSpacing)
                local pipId = CreateScreenObstacle({
                    Name = "BlankObstacle", Group = LAYOUT.Group,
                    X = x, Y = pipY, Scale = LAYOUT.PipScale, Animation = LAYOUT.PipTextureEmpty,
                })
                handles.pips[playerId][i] = pipId
                applyPip(playerId, pipId, false)
            end
        end

        local state = deps and deps.MatchOrchestration and deps.MatchOrchestration.GetState()
        local _, total = MatchHud.PipFill(state, 1)
        if total <= 0 then
            total = 3
        end
        buildSide(1, total, -1)
        buildSide(2, total, 1)

        ids = handles
        built = true
        lastPips = nil
        lastTimerText = nil
        log("hud: built (timer + " .. tostring(total) .. " orb pips/side, bottom-center)")
    end)
end

local function teardown()
    if not built then
        return
    end
    guarded("teardown", function()
        local toDestroy = {}
        if ids then
            if ids.timer then toDestroy[#toDestroy + 1] = ids.timer end
            if ids.backing then toDestroy[#toDestroy + 1] = ids.backing end
            for _, side in pairs(ids.pips or {}) do
                for _, pipId in ipairs(side) do
                    toDestroy[#toDestroy + 1] = pipId
                end
            end
        end
        if #toDestroy > 0 and type(Destroy) == "function" then
            pcall(Destroy, { Ids = toDestroy })
        end
    end)
    built = false
    ids = nil
    lastPips = nil
    lastTimerText = nil
end

local function refreshPips(state)
    if not built or ids == nil then
        return
    end
    local f1 = select(1, MatchHud.PipFill(state, 1))
    local f2 = select(1, MatchHud.PipFill(state, 2))
    local key = tostring(f1) .. "-" .. tostring(f2)
    if key == lastPips then
        return
    end
    lastPips = key
    guarded("refreshPips", function()
        local fills = { [1] = f1, [2] = f2 }
        for playerId, filled in pairs(fills) do
            for i, pipId in ipairs(ids.pips[playerId] or {}) do
                applyPip(playerId, pipId, i <= filled)
            end
        end
    end)
end

local function setTimerText(text, color)
    if not built or ids == nil or ids.timer == nil then
        return
    end
    if text == lastTimerText then
        return
    end
    lastTimerText = text
    guarded("setTimerText", function()
        if type(ModifyTextBox) == "function" then
            ModifyTextBox({ Id = ids.timer, Text = text, Color = color or LAYOUT.TimerColor })
        end
    end)
end

function MatchHud.StartRoundClock(seconds)
    clock.running = true
    clock.remaining = (type(seconds) == "number" and seconds) or 0
    clock.endTime = nil
    lastTimerText = nil
end

function MatchHud.StopRoundClock()
    clock.running = false
end

local function phaseOf(state)
    return state and state.phase
end

function MatchHud.Tick(time)
    local orch = deps and deps.MatchOrchestration
    if orch == nil then
        return
    end
    local state = orch.GetState()

    if state == nil then
        if built then
            teardown()
        end
        return
    end

    if not built then
        build()
    end

    local Match = deps.Match
    local phase = phaseOf(state)
    local inRound = Match ~= nil and phase == Match.Phase.InRound
    local inSuddenDeath = Match ~= nil and phase == Match.Phase.SuddenDeath

    refreshPips(state)

    if inSuddenDeath then
        setTimerText("SUDDEN DEATH", LAYOUT.SuddenDeathColor)
        return
    end

    if clock.running and inRound and type(time) == "number" then
        if clock.endTime == nil then
            clock.endTime = time + clock.remaining
        end
        clock.remaining = clock.endTime - time
        if clock.remaining < 0 then
            clock.remaining = 0
        end
    elseif not inRound then
        clock.running = false
    end

    setTimerText(MatchHud.FormatClock(clock.remaining), LAYOUT.TimerColor)
end

MatchHud._tickInstalled = false

function MatchHud.InstallTick()
    if MatchHud._tickInstalled then
        return
    end
    if type(draw) ~= "function" then
        log("hud: draw global missing - HUD tick not installed")
        return
    end
    if deps == nil or deps.HookUtils == nil then
        log("hud: HookUtils not injected - HUD tick not installed")
        return
    end
    MatchHud._tickInstalled = true
    deps.HookUtils.wrap("draw", function(original, ...)
        original(...)
        local args = { ... }
        local ok, err = pcall(MatchHud.Tick, args[1])
        if not ok then
            log("hud: tick error - tearing HUD down for this run: " .. tostring(err))
            pcall(teardown)
        end
    end)
    log("hud: tick installed (draw post-wrap)")
end

function MatchHud.Reset()
    clock.running = false
    clock.remaining = 0
    clock.endTime = nil
    teardown()
end

return MatchHud
