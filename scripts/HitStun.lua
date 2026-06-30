local HitStun = {}

local ATTACKER_FIELDS = { "AttackerTable", "Attacker", "TriggeredByTable", "OwnerTable" }

local FREEZE_BLOCK = "AgonHitStun"

function HitStun.ClassifyTier(damageAmount, maxHealth, heavyThreshold)
    if type(damageAmount) ~= "number" or damageAmount <= 0 then
        return "none"
    end
    if type(maxHealth) == "number" and maxHealth > 0
        and type(heavyThreshold) == "number" and heavyThreshold > 0
        and damageAmount >= maxHealth * heavyThreshold then
        return "heavy"
    end
    return "light"
end

local function offCooldown(key, seconds)
    if type(CheckCooldown) ~= "function" then
        return true
    end
    return CheckCooldown(key, seconds) == true
end

local function freeze(playerId, seconds)
    if type(AddInputBlock) ~= "function" then
        return
    end
    AddInputBlock { PlayerIndex = playerId, Name = FREEZE_BLOCK }
    if type(thread) == "function" and type(wait) == "function" then
        thread(function()
            wait(seconds > 0 and seconds or 0.01, "AgonHitStun")
            if type(RemoveInputBlock) == "function" then
                RemoveInputBlock { PlayerIndex = playerId, Name = FREEZE_BLOCK }
            end
        end)
    elseif type(RemoveInputBlock) == "function" then
        RemoveInputBlock { PlayerIndex = playerId, Name = FREEZE_BLOCK }
    end
end

function HitStun.Apply(deps, triggerArgs)
    if triggerArgs == nil then
        return "none"
    end
    local players = deps.Players
    local Hostility = deps.Hostility
    local Tuning = deps.Tuning
    local CombatApplication = deps.CombatApplication
    if not (players and Hostility and Tuning and CombatApplication) then
        return "none"
    end
    if players.HeroCount() < 2 then
        return "none"
    end

    local cfg = Tuning.HitStun()
    if not cfg.enabled then
        return "none"
    end

    local victim = CombatApplication.ResolveHeroFromArgs(triggerArgs, "Victim", players)
    if victim == nil then
        return "none"
    end
    local attacker = CombatApplication.ResolveHeroFromArgs(triggerArgs, ATTACKER_FIELDS, players)
    if not Hostility.IsHostile(attacker, victim, players.IsHeroFn) then
        return "none"
    end

    local tier = HitStun.ClassifyTier(triggerArgs.DamageAmount, victim.MaxHealth, cfg.heavyThreshold)
    if tier == "none" then
        return "none"
    end

    local duration = (tier == "heavy") and cfg.heavyFreezeDuration or cfg.lightFreezeDuration
    if tier == "light" and triggerArgs.Victim ~= nil then
        triggerArgs.Victim.SkipDamageAnimation = not cfg.lightHitAnimation
    end
    pcall(function()
        local playerId = players.GetPlayerId(victim)
        if offCooldown(FREEZE_BLOCK .. ":" .. tostring(playerId), duration) then
            freeze(playerId, duration)
        end
    end)
    return tier
end

return HitStun
