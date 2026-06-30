local HeroContextNative = {}

local heroContext = nil

function HeroContextNative.SetHeroContext(mod)
    heroContext = mod
end

local function runContained(fn, ...)
    if heroContext ~= nil and heroContext.RunContained ~= nil then
        return heroContext.RunContained(fn, ...)
    end
    local co = coroutine.create(fn)
    local res = { coroutine.resume(co, ...) }
    return res[1], coroutine.status(co) == "dead", table.unpack(res, 2)
end

local function playerIndexOf(hero)
    if hero ~= nil and type(hero.AgonPlayerIndex) == "number" then
        return hero.AgonPlayerIndex
    end
    return 1
end

function HeroContextNative.RunWithNativeHeroContext(playerIndex, fn, ...)
    if type(AgonSetCurrentMainPlayer) ~= "function"
        or type(AgonResetCurrentMainPlayer) ~= "function" then
        return fn(...)
    end

    AgonSetCurrentMainPlayer(playerIndex)

    local result = { runContained(fn, ...) }
    local ok = result[1]
    local finished = result[2]

    AgonResetCurrentMainPlayer()

    if not finished then
        error("HeroContextNative: wrapped native call yielded — the main-player "
            .. "swap is synchronous-only; wrap only non-yielding native reads")
    end

    if not ok then
        error(result[3])
    end
    return table.unpack(result, 3)
end

function HeroContextNative.RunWithNativeHeroContextFromHero(fn, ...)
    local hero = CurrentRun and CurrentRun.Hero
    return HeroContextNative.RunWithNativeHeroContext(playerIndexOf(hero), fn, ...)
end

return HeroContextNative
