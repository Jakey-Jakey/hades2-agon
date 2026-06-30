local HookUtils = ModRequire "HookUtils.lua"
local HeroContext = ModRequire "HeroContext.lua"
local CombatApplication = ModRequire "CombatApplication.lua"
local Players = ModRequire "Players.lua"
local Hostility = ModRequire "Hostility.lua"
local VersusTuning = ModRequire "VersusTuning.lua"
local HitStun = ModRequire "HitStun.lua"
local HeroEvents = ModRequire "HeroEvents.lua"
local log = ModRequire "Log.lua"

local FriendlyFire = {}

local combatApplicationDeps = { Players = Players, HeroContext = HeroContext }
local damageScaleDeps = { Players = Players, Hostility = Hostility, Tuning = VersusTuning }
local hitStunDeps = { Players = Players, Hostility = Hostility, Tuning = VersusTuning, CombatApplication = CombatApplication }
local trapDamagePatched = false

function FriendlyFire.PatchTrapDamage()
    if trapDamagePatched then
        return
    end

    local hasProjectileData = type(ProjectileData) == "table" and type(ProjectileData.DestructibleTreeSplinter) == "table"
    local hasEnemyData = type(EnemyData) == "table" and type(EnemyData.DestructibleTree) == "table"
    if not hasProjectileData and not hasEnemyData then
        log("arena hazard damage patch skipped - destructible tree data missing")
        return
    end

    trapDamagePatched = true

    local function allowPlayerDamage(data)
        if type(data) ~= "table" then
            return false
        end
        data.OutgoingDamageModifiers = data.OutgoingDamageModifiers or {}

        local foundPlayerMultiplier = false
        for i = 1, #data.OutgoingDamageModifiers do
            local modifier = data.OutgoingDamageModifiers[i]
            if type(modifier) == "table" and modifier.PlayerMultiplier ~= nil then
                modifier.PlayerMultiplier = 1.0
                foundPlayerMultiplier = true
            end
        end
        if not foundPlayerMultiplier then
            data.OutgoingDamageModifiers[#data.OutgoingDamageModifiers + 1] = { PlayerMultiplier = 1.0 }
        end
        return true
    end

    local function allowPlayerDamageForDataOverrides(data)
        if type(data) ~= "table" or type(data.DreamBiomeData) ~= "table" then
            return
        end
        for _, biomeData in pairs(data.DreamBiomeData) do
            if type(biomeData) == "table" then
                allowPlayerDamage(biomeData.DataOverrides)
            end
        end
    end

    if hasProjectileData then
        allowPlayerDamage(ProjectileData.DestructibleTreeSplinter)
    end
    if hasEnemyData then
        allowPlayerDamage(EnemyData.DestructibleTree)
        allowPlayerDamageForDataOverrides(EnemyData.DestructibleTree)
    end
    if type(ActiveEnemies) == "table" then
        for _, enemy in pairs(ActiveEnemies) do
            if type(enemy) == "table" and enemy.Name == "DestructibleTree" then
                allowPlayerDamage(enemy)
            end
        end
    end

    log("arena hazard damage patch installed (DestructibleTreeSplinter can damage player heroes)")
end

function FriendlyFire.WrapOnHit(baseFun, args)
    local fun = args[1]

    baseFun { function(triggerArgs)
        CombatApplication.ScaleHostileDamage(damageScaleDeps, triggerArgs)
        HitStun.Apply(hitStunDeps, triggerArgs)
        CombatApplication.ApplyHitEvent(combatApplicationDeps, triggerArgs, fun)
    end }
end

FriendlyFire._combatRoutingInstalled = false

function FriendlyFire.InstallCombatRouting(phase)
    if FriendlyFire._combatRoutingInstalled then
        return
    end
    local hasOnHit = type(OnHit) == "function"
    log("combat routing [" .. phase .. "]: OnHit present=" .. tostring(hasOnHit))
    if not hasOnHit then
        return
    end
    FriendlyFire._combatRoutingInstalled = true
    HookUtils.wrap("OnHit", FriendlyFire.WrapOnHit)
    HeroEvents.Install()
    log("combat routing installed [" .. phase .. "]")
end

return FriendlyFire
