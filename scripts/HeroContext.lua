local HeroContext = {}

local coroutineToHero = setmetatable({}, { __mode = "k" })

local fallbackDiagnostic = nil
local fallbackWarnedCoroutines = setmetatable({}, { __mode = "k" })

local defaultHero = nil

local hooksInstalled = false

local RunMT = {
    __index = function(self, key)
        if key == "Hero" then
            return HeroContext.GetCurrentHeroContext()
        end
        return rawget(self, key)
    end,
}

local function fallbackDiagnosticCallsite()
    if type(debug) ~= "table" or type(debug.getinfo) ~= "function" then
        return "unknown"
    end

    local info = debug.getinfo(3, "Sl")
    if info and info.source and info.source:find("HeroContext.lua", 1, true) then
        info = debug.getinfo(4, "Sl")
    end
    if info == nil then
        return "unknown"
    end
    return tostring(info.short_src or info.source or "unknown") .. ":" .. tostring(info.currentline or "?")
end

local function maybeEmitFallbackDiagnostic(co, isMain)
    local diagnostic = fallbackDiagnostic
    if diagnostic == nil or isMain or fallbackWarnedCoroutines[co] then
        return
    end
    if type(diagnostic.isActive) == "function" and not diagnostic.isActive() then
        return
    end

    fallbackWarnedCoroutines[co] = true

    local heroLabel = "default hero"
    if type(diagnostic.describeHero) == "function" then
        heroLabel = diagnostic.describeHero(defaultHero)
    end
    local msg = "hero context: unkeyed coroutine fell back to " .. tostring(heroLabel)
        .. " during a multi-hero match; add a HeroEvents/HeroContextNative route "
        .. "or mark the callsite N/A (source " .. fallbackDiagnosticCallsite() .. ")"

    if type(diagnostic.emit) == "function" then
        diagnostic.emit(msg)
    else
        print("[AGON] " .. msg)
    end
end

function HeroContext.GetCurrentHeroContext()
    local co, isMain = coroutine.running()
    local hero = coroutineToHero[co]
    if hero ~= nil then
        return hero
    end
    if fallbackDiagnostic ~= nil then
        maybeEmitFallbackDiagnostic(co, isMain)
    end
    return defaultHero
end

function HeroContext.IsHeroContextExplicit()
    return coroutineToHero[coroutine.running()] ~= nil
end

function HeroContext.SetFallbackDiagnostic(diagnostic)
    fallbackDiagnostic = diagnostic
    fallbackWarnedCoroutines = setmetatable({}, { __mode = "k" })
end

function HeroContext.SetDefaultHero(hero)
    defaultHero = hero
end

function HeroContext.GetDefaultHero()
    return defaultHero
end

function HeroContext.EnsureRunProxy()
    if CurrentRun == nil then
        return
    end
    local raw = rawget(CurrentRun, "Hero")
    if raw ~= nil then
        defaultHero = raw
        rawset(CurrentRun, "Hero", nil)
    end
    if getmetatable(CurrentRun) ~= RunMT then
        setmetatable(CurrentRun, RunMT)
    end
end

function HeroContext.As(hero, fn, ...)
    HeroContext.EnsureRunProxy()

    local co = coroutine.running()
    local prev = coroutineToHero[co]
    coroutineToHero[co] = hero

    local results = { pcall(fn, ...) }

    coroutineToHero[co] = prev

    if not results[1] then
        error(results[2])
    end
    return table.unpack(results, 2)
end

function HeroContext.RunWithHeroContext(hero, fn, ...)
    HeroContext.EnsureRunProxy()

    if type(thread) ~= "function" then
        return HeroContext.As(hero, fn, ...)
    end

    thread(function(...)
        local co = coroutine.running()
        coroutineToHero[co] = hero
        fn(...)
        coroutineToHero[co] = nil
    end, ...)
end

function HeroContext.RunContained(fn, ...)
    local co = coroutine.create(fn)
    coroutineToHero[co] = coroutineToHero[coroutine.running()]
    local res = { coroutine.resume(co, ...) }
    local finished = coroutine.status(co) == "dead"
    return res[1], finished, table.unpack(res, 2)
end

function HeroContext.InitHooks()
    if hooksInstalled then
        return
    end
    if type(thread) ~= "function" or type(coroutine) ~= "table" then
        return
    end
    hooksInstalled = true

    local _thread = thread
    thread = function(fun, ...)
        local heroContext = coroutineToHero[coroutine.running()]
        if heroContext then
            return _thread(function(...)
                local co = coroutine.running()
                coroutineToHero[co] = heroContext
                fun(...)
                coroutineToHero[co] = nil
            end, ...)
        end
        return _thread(fun, ...)
    end

    local _yield = coroutine.yield
    coroutine.yield = function(params)
        if params == "task done" then
            coroutineToHero[coroutine.running()] = nil
        end
        return _yield(params)
    end
end

return HeroContext
