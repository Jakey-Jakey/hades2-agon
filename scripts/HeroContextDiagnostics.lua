local HeroContext = ModRequire "HeroContext.lua"
local Players = ModRequire "Players.lua"
local log = ModRequire "Log.lua"

local HeroContextDiagnostics = {}

local enabled = false

local function describeHero(hero)
    if hero == nil then
        return "nil"
    end
    local id = hero.ObjectId and (" ObjectId=" .. tostring(hero.ObjectId)) or ""
    local player = hero.AgonPlayerIndex and (" player=" .. tostring(hero.AgonPlayerIndex)) or " player=1"
    return tostring(hero.Name or hero.name or "hero") .. player .. id
end

function HeroContextDiagnostics.Configure(on, shouldLog)
    enabled = on == true

    if not enabled then
        HeroContext.SetFallbackDiagnostic(nil)
        if shouldLog then
            log("hero context diagnostics disabled")
        end
        return
    end

    HeroContext.SetFallbackDiagnostic {
        isActive = function()
            return Players.HeroCount() >= 2
        end,
        describeHero = describeHero,
        emit = function(msg)
            log(msg)
            if DebugAssert then
                DebugAssert { Condition = false, Text = "[AGON] " .. msg, Owner = "AGON" }
            end
        end,
    }
    if shouldLog then
        log("hero context diagnostics enabled")
    end
end

function HeroContextDiagnostics.IsEnabled()
    return enabled
end

function HeroContextDiagnostics.Install()
    AgonSetHeroContextDiagnostics = function(on)
        HeroContextDiagnostics.Configure(on ~= false, true)
    end
    AgonHeroContextDiagnosticsEnabled = function()
        return enabled
    end
end

return HeroContextDiagnostics
