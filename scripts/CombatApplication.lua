local CombatApplication = {}

local function resolveHero(unit, players)
    if unit == nil then
        return nil
    end
    if players.IsHero and players.IsHero(unit) then
        return unit
    end
    if unit.ObjectId ~= nil and players.GetHeroByUnit ~= nil then
        return players.GetHeroByUnit(unit.ObjectId)
    end
    return nil
end

local function resolveHeroFromIntent(deps, intent)
    local hero = intent and intent.Hero or nil
    local triggerArgs = intent and intent.TriggerArgs or nil

    if hero == nil and triggerArgs ~= nil and deps.Players.GetHeroByUnit ~= nil then
        hero = deps.Players.GetHeroByUnit(triggerArgs.triggeredById or triggerArgs.TriggeredById)
    end

    return hero
end

function CombatApplication.ResolveHeroFromArgs(triggerArgs, argFields, players)
    if triggerArgs == nil then
        return nil
    end
    if type(argFields) == "table" then
        for i = 1, #argFields do
            local hero = resolveHero(triggerArgs[argFields[i]], players)
            if hero ~= nil then
                return hero
            end
        end
        return nil
    end
    return resolveHero(triggerArgs[argFields], players)
end

function CombatApplication.ApplyForHero(deps, hero, handler, triggerArgs, opts)
    local players = deps.Players
    local heroContext = deps.HeroContext

    if hero ~= nil and hero ~= players.MainHero then
        if opts and opts.Yielding then
            return heroContext.RunWithHeroContext(hero, handler, triggerArgs)
        end
        return heroContext.As(hero, handler, triggerArgs)
    end

    return handler(triggerArgs)
end

function CombatApplication.ApplyControlIntent(deps, intent, handler)
    local triggerArgs = intent and intent.TriggerArgs or nil
    local hero = resolveHeroFromIntent(deps, intent)

    return CombatApplication.ApplyForHero(deps, hero, handler, triggerArgs)
end

function CombatApplication.ApplyMovementIntent(deps, intent, handler)
    local triggerArgs = intent and intent.TriggerArgs or nil
    local hero = resolveHeroFromIntent(deps, intent)

    return CombatApplication.ApplyForHero(deps, hero, handler, triggerArgs)
end

function CombatApplication.ApplyRoutedEvent(deps, triggerArgs, argFields, handler)
    local hero = CombatApplication.ResolveHeroFromArgs(triggerArgs, argFields, deps.Players)
    return CombatApplication.ApplyForHero(deps, hero, handler, triggerArgs, { Yielding = true })
end

function CombatApplication.ScaleHostileDamage(deps, triggerArgs)
    if triggerArgs == nil then
        return false
    end
    local players = deps.Players
    local Hostility = deps.Hostility
    local Tuning = deps.Tuning
    if players == nil or Hostility == nil or Tuning == nil then
        return false
    end

    local victim = CombatApplication.ResolveHeroFromArgs(triggerArgs, "Victim", players)
    local attacker = CombatApplication.ResolveHeroFromArgs(triggerArgs,
        { "AttackerTable", "Attacker", "TriggeredByTable", "OwnerTable" }, players)
    if not Hostility.IsHostile(attacker, victim, players.IsHeroFn) then
        return false
    end
    if type(triggerArgs.DamageAmount) ~= "number" then
        return false
    end
    triggerArgs.DamageAmount = Tuning.ScaleDamage(triggerArgs.DamageAmount, deps.TuningConfig)
    return true
end

function CombatApplication.ApplyHitEvent(deps, triggerArgs, handler)
    local hero = CombatApplication.ResolveHeroFromArgs(triggerArgs, "Victim", deps.Players)
    if hero == nil then
        hero = CombatApplication.ResolveHeroFromArgs(triggerArgs,
            { "AttackerTable", "Attacker", "TriggeredByTable", "OwnerTable" }, deps.Players)
    end
    return CombatApplication.ApplyForHero(deps, hero, handler, triggerArgs)
end

return CombatApplication
