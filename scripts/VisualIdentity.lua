local HookUtils = nil
local Players = nil
local HeroContext = nil
local PlayersReady = nil
local log = function() end
local logLoaded = false

local function gameRequire(path)
    if type(ModRequire) ~= "function" then
        return nil
    end
    local ok, module = pcall(function()
        return ModRequire(path)
    end)
    if ok then
        return module
    end
    return nil
end

local function deps()
    if HookUtils == nil then
        HookUtils = gameRequire "HookUtils.lua"
    end
    if Players == nil then
        Players = gameRequire "Players.lua"
    end
    if HeroContext == nil then
        HeroContext = gameRequire "HeroContext.lua"
    end
    if PlayersReady == nil then
        PlayersReady = gameRequire "PlayersReady.lua"
    end
    if not logLoaded then
        log = gameRequire "Log.lua" or function() end
        logLoaded = true
    end
    return HookUtils, Players, HeroContext
end

local VisualIdentity = {}

VisualIdentity.HealthComponentNames = {
    "HealthBack",
    "HealthFalloff",
    "HealthFill",
    "HealthReserve",
    "HealthBuffer",
    "HealthHighIndicator",
    "HealthLowIndicator",
}

VisualIdentity.ManaComponentNames = {
    "ManaMeterBack",
    "ManaMeterFill",
    "ManaMeterReserve",
    "ManaLowIndicator",
}

local FLIP_COMPONENTS = {
    HealthBack = true, HealthFalloff = true, HealthFill = true,
    HealthReserve = true, HealthBuffer = true,
    ManaMeterBack = true, ManaMeterFill = true, ManaMeterReserve = true,
}
local INWARD_NUDGE_COMPONENTS = {
    HealthFalloff = true, HealthFill = true, HealthReserve = true, HealthBuffer = true,
    ManaMeterFill = true, ManaMeterReserve = true,
}

VisualIdentity.Styles = {
    [1] = {
        Name = "P1",
        Tint = { 190, 220, 255, 255 },
        LightBarColor = { 30, 90, 255, 255 },
        Outline = { R = 40, G = 120, B = 255, Opacity = 0.6, Thickness = 2, Threshold = 0.6 },
    },
    [2] = {
        Name = "P2",
        Tint = { 255, 205, 170, 255 },
        LightBarColor = { 255, 70, 10, 255 },
        Outline = { R = 255, G = 90, B = 20, Opacity = 0.6, Thickness = 2, Threshold = 0.6 },
    },
}

VisualIdentity._installed = false

local componentStore = nil

local function p2Name(componentName)
    return componentName .. "Player2"
end

function VisualIdentity.GetStyle(playerId)
    return VisualIdentity.Styles[playerId]
end

function VisualIdentity.HealthFraction(hero)
    if hero == nil or hero.Health == nil or hero.MaxHealth == nil or hero.MaxHealth <= 0 then
        return 0
    end
    local fraction = hero.Health / hero.MaxHealth
    if fraction < 0 then
        return 0
    end
    if fraction > 1 then
        return 1
    end
    return fraction
end

local function shallowCopy(src)
    local copy = {}
    if src == nil then
        return copy
    end
    for k, v in pairs(src) do
        copy[k] = v
    end
    return copy
end

local function deepCopy(src)
    if type(src) ~= "table" then
        return src
    end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = deepCopy(v)
    end
    return copy
end

function VisualIdentity.ApplyHero(playerId, hero)
    local style = VisualIdentity.GetStyle(playerId)
    if style == nil or hero == nil or hero.ObjectId == nil then
        return
    end

    if type(SetThingProperty) == "function" then
        pcall(SetThingProperty, { Property = "AddColor", Value = false, DestinationId = hero.ObjectId, DataValue = false })
    end
    if type(SetColor) == "function" then
        pcall(SetColor, { Id = hero.ObjectId, Color = style.Tint, Duration = 0.0 })
    end
    if type(AddOutline) == "function" then
        local outline = shallowCopy(style.Outline)
        outline.Id = hero.ObjectId
        pcall(AddOutline, outline)
    end
    if type(SetLightBarColor) == "function" then
        pcall(SetLightBarColor, { PlayerIndex = playerId, Color = style.LightBarColor })
    end
end

function VisualIdentity.ApplyAllHeroes()
    deps()
    if Players == nil then
        return
    end
    VisualIdentity.ApplyHero(1, Players.MainHero)
    if Players.Dummies then
        for i = 1, #Players.Dummies do
            VisualIdentity.ApplyHero(i + 1, Players.Dummies[i])
        end
    end
end

function VisualIdentity.RegisterHudComponents(componentData)
    if componentData == nil or componentData.AgonP2HealthApplied then
        return
    end
    componentData.AgonP2HealthApplied = true

    local function insertAfter(originalName, cloneName)
        if componentData.Order == nil then
            return
        end
        for i, name in ipairs(componentData.Order) do
            if name == originalName then
                table.insert(componentData.Order, i + 1, cloneName)
                return
            end
        end
    end

    local function cloneSet(names)
        for _, componentName in ipairs(names) do
            local original = componentData[componentName]
            if original ~= nil then
                local clone = deepCopy(original)
                if clone.X then
                    clone.X = nil
                    clone.RightOffset = 340 + (315 - original.X)
                end
                if FLIP_COMPONENTS[componentName] then
                    clone.FlipHorizontal = true
                end
                componentData[p2Name(componentName)] = clone
                insertAfter(componentName, p2Name(componentName))
            end
        end
    end

    cloneSet(VisualIdentity.HealthComponentNames)
    cloneSet(VisualIdentity.ManaComponentNames)

    for componentName in pairs(INWARD_NUDGE_COMPONENTS) do
        local clone = componentData[p2Name(componentName)]
        if clone and clone.RightOffset then
            clone.RightOffset = clone.RightOffset + 20
        end
    end
end

local function actingAsSecondHero()
    if Players == nil or HeroContext == nil then
        return false
    end
    local p2 = Players.Dummies and Players.Dummies[1]
    return p2 ~= nil and HeroContext.GetCurrentHeroContext() == p2
end

local function installComponentsProxy(screen)
    local store = {}
    if screen.Components then
        for key, value in pairs(screen.Components) do
            store[key] = value
        end
    end
    componentStore = store

    screen.Components = setmetatable({}, {
        __index = function(_, key)
            if actingAsSecondHero() then
                return store[p2Name(key)] or store[key]
            end
            return store[key]
        end,
        __newindex = function(_, key, value)
            store[key] = value
        end,
    })
end

function VisualIdentity.WrapCreateScreenFromData(original, screen, componentData, args)
    if HUDScreen and screen == HUDScreen then
        VisualIdentity.RegisterHudComponents(componentData)
        installComponentsProxy(screen)
    end
    return original(screen, componentData, args)
end

local function callForEveryHero(original, ...)
    deps()
    if Players == nil or HeroContext == nil or Players.HeroCount() < 2 then
        return original(...)
    end

    if Players.MainHero then
        HeroContext.RunWithHeroContext(Players.MainHero, original, ...)
    end
    local p2 = Players.Dummies and Players.Dummies[1]
    if p2 then
        HeroContext.RunWithHeroContext(p2, original, ...)
    end
end

VisualIdentity.WrapShowHealthUI = callForEveryHero
VisualIdentity.WrapUpdateHealthUI = callForEveryHero
VisualIdentity.WrapHideHealthUI = callForEveryHero

VisualIdentity.WrapShowManaMeter = callForEveryHero
VisualIdentity.WrapUpdateManaMeterUIReal = callForEveryHero

function VisualIdentity.RefreshVitals(hero)
    deps()
    if hero == nil or HeroContext == nil then
        return
    end
    if VisualIdentity._origUpdateHealthUI then
        HeroContext.RunWithHeroContext(hero, VisualIdentity._origUpdateHealthUI,
            { Force = true, FalloffDelay = 0.0 })
    end
    if VisualIdentity._origUpdateManaMeterUIReal
        and type(hero.MaxMana) == "number" and hero.MaxMana > 0 then
        HeroContext.RunWithHeroContext(hero, VisualIdentity._origUpdateManaMeterUIReal)
    end
end

local function isPlayerHeroUnit(unit)
    if Players == nil or unit == nil then
        return false
    end
    if Players.IsHero(unit) then
        return true
    end
    if unit.ObjectId ~= nil and Players.GetHeroByUnit ~= nil then
        return Players.GetHeroByUnit(unit.ObjectId) ~= nil
    end
    return false
end

function VisualIdentity.WrapCreateHealthBar(original, unit)
    if isPlayerHeroUnit(unit) then
        return
    end
    return original(unit)
end

function VisualIdentity.WrapUpdateHealthBar(original, unit, damageAmount, damageEventArgs)
    if isPlayerHeroUnit(unit) then
        return
    end
    return original(unit, damageAmount, damageEventArgs)
end

function VisualIdentity.WrapSetPlayerUnDarkside(original, ...)
    local result = { original(...) }
    VisualIdentity.ApplyAllHeroes()
    return table.unpack(result)
end

function VisualIdentity.HideSecondHealthBar()
    if componentStore == nil or type(SetAlpha) ~= "function" then
        return
    end
    local ids = {}
    local function collect(names)
        for _, componentName in ipairs(names) do
            local clone = componentStore[p2Name(componentName)]
            if clone and clone.Id then
                ids[#ids + 1] = clone.Id
            end
        end
    end
    collect(VisualIdentity.HealthComponentNames)
    collect(VisualIdentity.ManaComponentNames)
    if #ids > 0 then
        pcall(SetAlpha, { Ids = ids, Fraction = 0.0, Duration = 0.0 })
    end
end

local function wrapIfPresent(name, handler, missingNote)
    if type(_G[name]) == "function" then
        HookUtils.wrap(name, handler)
    else
        log("visual identity: " .. name .. " missing - " .. missingNote)
    end
end

function VisualIdentity.Install()
    if VisualIdentity._installed then
        return
    end
    deps()
    if HookUtils == nil then
        log("visual identity: HookUtils unavailable - not installed")
        return
    end

    VisualIdentity._installed = true

    VisualIdentity._origShowHealthUI = _G.ShowHealthUI
    VisualIdentity._origUpdateHealthUI = _G.UpdateHealthUI
    VisualIdentity._origShowManaMeter = _G.ShowManaMeter
    VisualIdentity._origUpdateManaMeterUIReal = _G.UpdateManaMeterUIReal

    wrapIfPresent("CreateScreenFromData", VisualIdentity.WrapCreateScreenFromData, "P2 health bar clone not installed")
    wrapIfPresent("ShowHealthUI", VisualIdentity.WrapShowHealthUI, "health show wrapper not installed")
    wrapIfPresent("UpdateHealthUI", VisualIdentity.WrapUpdateHealthUI, "health update wrapper not installed")
    wrapIfPresent("HideHealthUI", VisualIdentity.WrapHideHealthUI, "health hide wrapper not installed")
    wrapIfPresent("ShowManaMeter", VisualIdentity.WrapShowManaMeter, "P2 mana meter not shown")
    wrapIfPresent("UpdateManaMeterUIReal", VisualIdentity.WrapUpdateManaMeterUIReal, "P2 mana update not installed")
    wrapIfPresent("CreateHealthBar", VisualIdentity.WrapCreateHealthBar, "overhead-bar guard not installed")
    wrapIfPresent("UpdateHealthBar", VisualIdentity.WrapUpdateHealthBar, "overhead-bar update guard not installed")
    wrapIfPresent("SetPlayerUnDarkside", VisualIdentity.WrapSetPlayerUnDarkside, "outline reapply not installed")

    if PlayersReady then
        PlayersReady.Subscribe(VisualIdentity.OnPlayersReady)
    end

    AgonRefreshIdentity = function()
        VisualIdentity.OnPlayersReady()
    end

    log("visual identity installed (subtle tint + outline + light-bar + two health bars)")
end

function VisualIdentity.OnPlayersReady()
    deps()
    VisualIdentity.ApplyAllHeroes()

    local p2 = Players and Players.Dummies and Players.Dummies[1]
    if p2 == nil or HeroContext == nil then
        return
    end
    if VisualIdentity._origShowHealthUI then
        HeroContext.RunWithHeroContext(p2, VisualIdentity._origShowHealthUI, {})
    end
    if VisualIdentity._origShowManaMeter and type(p2.MaxMana) == "number" and p2.MaxMana > 0 then
        HeroContext.RunWithHeroContext(p2, VisualIdentity._origShowManaMeter, {})
    end
end

function VisualIdentity.Reset()
    deps()
    VisualIdentity.HideSecondHealthBar()
end

return VisualIdentity
