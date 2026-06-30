local CastSlow = {}

CastSlow.Effects = { "ImpactSlow", "ImpactGrip" }

CastSlow._installed = false

function CastSlow.OpponentHeroIds(players, caster)
    local casterId = caster and caster.ObjectId or nil
    local opponents = {}
    for _, id in ipairs(players.HeroIds()) do
        if id ~= casterId then
            opponents[#opponents + 1] = id
        end
    end
    return opponents
end

local function playerEffectProps(effectName)
    local props = ShallowCopyTable(EffectData[effectName].DataProperties)
    props.IgnoreName = nil
    return props
end

function CastSlow.RunOpponentSlowLoop(projectileId, caster, players)
    local casterId = caster and caster.ObjectId or nil
    if casterId == nil then
        return
    end

    local scaleX = GetProjectileDataValue({ Id = projectileId, Property = "DamageRadiusScaleX" })
    local scaleY = GetProjectileDataValue({ Id = projectileId, Property = "DamageRadiusScaleY" })
    local effectProps = {}
    for _, name in ipairs(CastSlow.Effects) do
        effectProps[name] = playerEffectProps(name)
    end

    while ProjectileExists({ Id = projectileId }) do
        local opponentIds = CastSlow.OpponentHeroIds(players, caster)
        if #opponentIds > 0 then
            local radius = GetProjectileProperty({ ProjectileId = projectileId, Property = "ModifiedDamageRadius" })
            local inRange = GetClosestIds({
                ProjectileId = projectileId,
                Distance = radius,
                DestinationIds = opponentIds,
                ScaleX = scaleX,
                ScaleY = scaleY,
                PreciseCollision = true,
            })
            for _, id in pairs(inRange) do
                for _, name in ipairs(CastSlow.Effects) do
                    ApplyEffect({ DestinationId = id, Id = casterId, EffectName = name, DataProperties = effectProps[name] })
                end
            end
        end
        waitUnmodified(0.15)
    end
end

function CastSlow.WrapStartCastSlow(players, heroContext)
    return function(original, projectileId, duration)
        if players.HeroCount() >= 2 then
            local caster = heroContext.GetCurrentHeroContext()
            if caster ~= nil and caster.ObjectId ~= nil then
                thread(CastSlow.RunOpponentSlowLoop, projectileId, caster, players)
            end
        end
        return original(projectileId, duration)
    end
end

function CastSlow.Install(players, heroContext, hookUtils, log)
    if CastSlow._installed then
        return
    end
    CastSlow._installed = true

    local function doWrap()
        hookUtils.wrap("StartCastSlow", CastSlow.WrapStartCastSlow(players, heroContext))
        log("cast-slow: opponent routing installed (base cast slows the other hero)")
    end

    if type(StartCastSlow) == "function" then
        doWrap()
        return
    end

    thread(function()
        local elapsed = 0
        while type(StartCastSlow) ~= "function" do
            waitUnmodified(0.25)
            elapsed = elapsed + 0.25
            if elapsed > 30 then
                log("cast-slow: StartCastSlow never appeared - opponent slow NOT routed")
                return
            end
        end
        doWrap()
    end)
end

return CastSlow
