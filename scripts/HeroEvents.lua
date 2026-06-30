local Players = ModRequire "Players.lua"
local HeroContext = ModRequire "HeroContext.lua"
local CombatApplication = ModRequire "CombatApplication.lua"
local log = ModRequire "Log.lua"

local HeroEvents = {}

HeroEvents.RoutedEvents = {
    { name = "OnWeaponFired", field = "OwnerTable" },
    { name = "OnWeaponTriggerRelease", field = "OwnerTable" },
    { name = "OnWeaponFailedToFire", field = "TriggeredByTable" },
    { name = "OnWeaponCharging", field = "OwnerTable" },
    { name = "OnWeaponChargeCanceled", field = "OwnerTable" },
    { name = "OnPerfectChargeWindowEntered", field = "OwnerTable" },
    { name = "OnProjectileCreation", field = "TriggeredByTable" },
    { name = "OnProjectileArm", field = "TriggeredByTable" },
    { name = "OnProjectileBlock", field = "Blocker" },
    { name = "OnDodge", field = "TriggeredByTable" },
    { name = "OnProjectileReflect", field = "TriggeredByTable" },
    { name = "OnWeaponClipEmpty", field = "OwnerTable" },
    { name = "OnProjectileDeath", fields = { "AttackerTable", "TriggeredByTable" } },
    { name = "OnBlinkFinished", field = "OwnerTable" },
    { name = "OnEffectApply", field = "Victim" },
    { name = "OnEffectCleared", field = "Victim" },
    { name = "OnEffectStackDecrease", field = "Victim" },
    { name = "OnEffectDelayedKnockbackForce", field = "Victim" },
}

local applicationDeps = { Players = Players, HeroContext = HeroContext }

local function wrapRegistrar(eventName, argFields)
    local original = _G[eventName]
    if type(original) ~= "function" then
        log("hero events: " .. eventName .. " missing at install - not routed")
        return
    end

    _G[eventName] = function(args)
        local names, fun
        if type(args[1]) == "function" then
            fun = args[1]
        else
            names = args[1]
            fun = args[2]
        end

        local routed = function(triggerArgs)
            CombatApplication.ApplyRoutedEvent(applicationDeps, triggerArgs, argFields, fun)
        end

        if names then
            original { names, routed }
        else
            original { routed }
        end
    end
end

HeroEvents._installed = false

function HeroEvents.Install()
    if HeroEvents._installed then
        return
    end
    HeroEvents._installed = true

    local routed = 0
    for _, event in ipairs(HeroEvents.RoutedEvents) do
        if type(_G[event.name]) == "function" then
            wrapRegistrar(event.name, event.fields or event.field)
            routed = routed + 1
        else
            log("hero events: " .. event.name .. " missing at install - not routed")
        end
    end
    log("hero events: per-hero combat routing installed (" .. routed .. " events, P2 only)")
end

return HeroEvents
