local TreeBlast = {}

TreeBlast.ProjectileName = "DestructibleTreeSplinter"

TreeBlast.HeroTeam = "HeroTeam"

TreeBlast.CollideGroups = { "EnemyTeam", "HeroTeam" }

local function loadTuning()
    if type(ModRequire) == "function" then
        local ok, m = pcall(function()
            return ModRequire("VersusTuning.lua")
        end)
        if ok and type(m) == "table" then
            return m
        end
    end
    if type(AGON_TEST_ROOT) == "string" then
        local chunk = loadfile(AGON_TEST_ROOT .. "/scripts/VersusTuning.lua")
        if chunk then
            return chunk()
        end
    end
    return nil
end

local VersusTuning = loadTuning()
TreeBlast.Damage = VersusTuning and VersusTuning.HazardDamage() or 50

TreeBlast._installed = false

function TreeBlast.IsSplinterHit(triggerArgs)
    return triggerArgs ~= nil and triggerArgs.SourceProjectile == TreeBlast.ProjectileName
end

function TreeBlast.ResolveHeroVictim(players, triggerArgs)
    local victim = triggerArgs and triggerArgs.Victim
    if victim == nil then
        return nil
    end
    if players.IsHero(victim) then
        return victim
    end
    if victim.ObjectId ~= nil and players.GetHeroByUnit ~= nil then
        return players.GetHeroByUnit(victim.ObjectId)
    end
    return nil
end

TreeBlast.DestroyerField = "AgonTreeDestroyerId"

function TreeBlast.IsSelfHit(hero, triggerArgs)
    local tree = triggerArgs and triggerArgs.AttackerTable
    local destroyerId = tree and tree[TreeBlast.DestroyerField]
    return destroyerId ~= nil and hero ~= nil and hero.ObjectId == destroyerId
end

function TreeBlast.WrapDestructibleTreeHit(players, env)
    return function(original, enemy, attacker, triggerArgs)
        if enemy ~= nil and players.HeroCount() >= 2 then
            for _, id in ipairs(players.HeroIds()) do
                env.AddToGroup(id, TreeBlast.HeroTeam)
            end
            enemy.ProjectilesCollideWithGroups = TreeBlast.CollideGroups
            enemy[TreeBlast.DestroyerField] = attacker and attacker.ObjectId or nil
        end
        return original(enemy, attacker, triggerArgs)
    end
end

function TreeBlast.WrapDamage(players)
    return function(original, victim, triggerArgs)
        if players.HeroCount() >= 2 and TreeBlast.IsSplinterHit(triggerArgs) then
            local hero = TreeBlast.ResolveHeroVictim(players, triggerArgs)
            if hero ~= nil then
                if TreeBlast.IsSelfHit(hero, triggerArgs) then
                    triggerArgs.DamageAmount = 0
                elseif TreeBlast.Damage ~= nil then
                    triggerArgs.DamageAmount = TreeBlast.Damage
                end
            end
        end
        return original(victim, triggerArgs)
    end
end

function TreeBlast.Install(players, hookUtils, log)
    if TreeBlast._installed then
        return
    end
    TreeBlast._installed = true

    local env = {
        log = log,
        AddToGroup = function(id, group)
            if type(AddToGroup) == "function" then
                AddToGroup({ Id = id, Name = group })
            end
        end,
    }

    local function ready()
        return type(DestructibleTreeHit) == "function" and type(Damage) == "function"
    end

    local function doWrap()
        hookUtils.wrap("DestructibleTreeHit", TreeBlast.WrapDestructibleTreeHit(players, env))
        hookUtils.wrap("Damage", TreeBlast.WrapDamage(players))
        log("tree blast: real-splinter routing installed (a splintering tree's projectile hits the other hero)")
    end

    if ready() then
        doWrap()
        return
    end

    thread(function()
        local elapsed = 0
        while not ready() do
            waitUnmodified(0.25)
            elapsed = elapsed + 0.25
            if elapsed > 30 then
                log("tree blast: DestructibleTreeHit/Damage never appeared - splinter routing NOT installed")
                return
            end
        end
        doWrap()
    end)
end

return TreeBlast
