local VersusTuning = {}

VersusTuning.Defaults = {
    heroMaxHealth = 1000,
    heroMaxMana = 100,
    damageScale = 1.0,
    hazardDamage = 50,
    spawnOffsetX = 500,
    spawnOffsetY = 100,
    postHitInvulnerability = false,
    pacing = {
        players = 2,
        roundsToWin = 3,
        maxRounds = 5,
        suddenDeathHpFloor = 10,
        roundTimerSeconds = 90,
    },
    beats = {
        introSeconds = 2.0,
        roundEndSeconds = 2.5,
    },
    hitStun = {
        enabled = true,
        heavyThreshold = 0.10,
        lightFreezeDuration = 0.3,
        heavyFreezeDuration = 0.5,
        lightHitAnimation = true,
    },
}

local function copyPacing(p)
    return {
        players = p.players,
        roundsToWin = p.roundsToWin,
        maxRounds = p.maxRounds,
        suddenDeathHpFloor = p.suddenDeathHpFloor,
        roundTimerSeconds = p.roundTimerSeconds,
    }
end

local function copyBeats(b)
    return {
        introSeconds = b.introSeconds,
        roundEndSeconds = b.roundEndSeconds,
    }
end

local function copyHitStun(h)
    return {
        enabled = h.enabled,
        heavyThreshold = h.heavyThreshold,
        lightFreezeDuration = h.lightFreezeDuration,
        heavyFreezeDuration = h.heavyFreezeDuration,
        lightHitAnimation = h.lightHitAnimation,
    }
end

function VersusTuning.New(overrides)
    local d = VersusTuning.Defaults
    local tuning = {
        heroMaxHealth = d.heroMaxHealth,
        heroMaxMana = d.heroMaxMana,
        damageScale = d.damageScale,
        hazardDamage = d.hazardDamage,
        spawnOffsetX = d.spawnOffsetX,
        spawnOffsetY = d.spawnOffsetY,
        postHitInvulnerability = d.postHitInvulnerability,
        pacing = copyPacing(d.pacing),
        beats = copyBeats(d.beats),
        hitStun = copyHitStun(d.hitStun),
    }
    if type(overrides) == "table" then
        for _, key in ipairs({ "heroMaxHealth", "heroMaxMana", "damageScale", "hazardDamage", "spawnOffsetX", "spawnOffsetY", "postHitInvulnerability" }) do
            if overrides[key] ~= nil then
                tuning[key] = overrides[key]
            end
        end
        if type(overrides.pacing) == "table" then
            for k, v in pairs(overrides.pacing) do
                tuning.pacing[k] = v
            end
        end
        if type(overrides.beats) == "table" then
            for k, v in pairs(overrides.beats) do
                tuning.beats[k] = v
            end
        end
        if type(overrides.hitStun) == "table" then
            for k, v in pairs(overrides.hitStun) do
                tuning.hitStun[k] = v
            end
        end
    end
    return tuning
end

function VersusTuning.HeroMaxHealth(tuning)
    return (tuning or VersusTuning.Defaults).heroMaxHealth
end

function VersusTuning.HeroMaxMana(tuning)
    return (tuning or VersusTuning.Defaults).heroMaxMana
end

function VersusTuning.DamageScale(tuning)
    return (tuning or VersusTuning.Defaults).damageScale
end

function VersusTuning.ScaleDamage(base, tuning)
    if type(base) ~= "number" then
        return base
    end
    return base * VersusTuning.DamageScale(tuning)
end

function VersusTuning.Pacing(tuning)
    return copyPacing((tuning or VersusTuning.Defaults).pacing)
end

function VersusTuning.HazardDamage(tuning)
    return (tuning or VersusTuning.Defaults).hazardDamage
end

function VersusTuning.SpawnOffset(tuning)
    tuning = tuning or VersusTuning.Defaults
    return tuning.spawnOffsetX, tuning.spawnOffsetY
end

function VersusTuning.Beats(tuning)
    return copyBeats((tuning or VersusTuning.Defaults).beats)
end

function VersusTuning.PostHitInvulnerability(tuning)
    return (tuning or VersusTuning.Defaults).postHitInvulnerability == true
end

function VersusTuning.HitStun(tuning)
    return copyHitStun((tuning or VersusTuning.Defaults).hitStun)
end

return VersusTuning
