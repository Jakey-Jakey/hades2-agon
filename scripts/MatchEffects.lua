local Players = ModRequire "Players.lua"
local VersusTuning = ModRequire "VersusTuning.lua"
local log = ModRequire "Log.lua"

local MatchEffects = {}

local ARENA_SPAWN_TUNING = {
    F_Boss01 = { CenterOffsetX = 520, CenterOffsetY = -280, Label = "F_Boss01 visual offset" },
}
local INTRO_INPUT_BLOCK = "AgonRoundIntro"
local IDLE_ANIMATION = "MelinoeIdle"

local inputLocked = false
local HeroContext = nil
local VisualIdentity = nil

local function guarded(label, body)
    local ok, err = pcall(body)
    if not ok then
        log("effect " .. label .. " failed (soft): " .. tostring(err))
    end
end

local function gameRequire(path)
    local ok, module = pcall(function()
        return ModRequire(path)
    end)
    if ok then
        return module
    end
    return nil
end

local function heroContext()
    if HeroContext == nil then
        HeroContext = gameRequire "HeroContext.lua"
    end
    return HeroContext
end

local function visualIdentity()
    if VisualIdentity == nil then
        VisualIdentity = gameRequire "VisualIdentity.lua"
    end
    return VisualIdentity
end

local function refreshVitals(hero)
    guarded("RefreshVitals", function()
        local identity = visualIdentity()
        if identity and identity.RefreshVitals then
            identity.RefreshVitals(hero)
        end
    end)
end

local function maxAvailableMana(hero)
    local context = heroContext()
    if type(GetHeroMaxAvailableMana) == "function" and context ~= nil then
        local ok, value = pcall(context.As, hero, GetHeroMaxAvailableMana)
        if ok and type(value) == "number" then
            return value
        end
    end
    return hero and hero.MaxMana
end

local function resolveSpawnAnchor(room, p1)
    local anchor = nil
    local label = nil
    local centerOffsetX = 0
    local centerOffsetY = 0
    if room ~= nil then
        anchor = room.HeroEndPoint
        if room.Name ~= nil then
            local tuning = ARENA_SPAWN_TUNING[room.Name]
            if tuning ~= nil then
                centerOffsetX = tuning.CenterOffsetX or 0
                centerOffsetY = tuning.CenterOffsetY or 0
                label = tuning.Label or (room.Name .. " visual offset")
            end
        end
    end
    if anchor == nil then
        anchor = p1 and p1.ObjectId
    end
    label = label or ((room and room.HeroEndPoint and "HeroEndPoint") or "P1 fallback")
    return anchor, label, centerOffsetX, centerOffsetY
end

function MatchEffects.Schedule(seconds, fn)
    if thread and wait then
        thread(function()
            wait(seconds > 0 and seconds or 0.01, "AgonMatchFlow")
            guarded("scheduled", fn)
        end)
    else
        guarded("scheduled", fn)
    end
end

function MatchEffects.ApplyTunedVitals(hero)
    if hero == nil then
        return
    end
    guarded("ApplyTunedVitals", function()
        local maxHealth = VersusTuning.HeroMaxHealth()
        if type(maxHealth) == "number" then
            hero.MaxHealth = maxHealth
            hero.Health = maxHealth
        end
        local maxMana = VersusTuning.HeroMaxMana()
        if type(maxMana) == "number" then
            hero.MaxMana = maxMana
            hero.Mana = maxMana
        end
        if hero.ObjectId and type(SetUnitProperty) == "function" and VersusTuning.HitStun().enabled then
            SetUnitProperty({ Property = "ImmuneToStun", Value = true, DestinationId = hero.ObjectId })
        end
    end)
    refreshVitals(hero)
end

function MatchEffects.Heal(hero)
    if hero == nil then
        return
    end
    guarded("Heal", function()
        hero.Health = hero.MaxHealth or hero.Health
        if type(hero.MaxMana) == "number" then
            hero.Mana = maxAvailableMana(hero) or hero.MaxMana
        end
        hero.IsDead = nil
        if hero.ObjectId and SetAnimation then
            SetAnimation { Name = IDLE_ANIMATION, DestinationId = hero.ObjectId }
        end
    end)
    refreshVitals(hero)
end

function MatchEffects.ClearTransient(hero)
    if hero == nil then
        return
    end
    guarded("ClearTransient", function()
        if hero.InvulnerableFlags ~= nil then
            hero.InvulnerableFlags = {}
        end
    end)
end

function MatchEffects.ResetPositions(p1, p2)
    guarded("ResetPositions", function()
        if not Teleport then
            return
        end
        local room = CurrentRun and CurrentRun.CurrentRoom
        local anchor, anchorLabel, centerOffsetX, centerOffsetY = resolveSpawnAnchor(room, p1)
        if anchor == nil then
            return
        end
        local spawnOffsetX, spawnOffsetY = VersusTuning.SpawnOffset()
        log("round reset spawn anchor: " .. tostring(anchorLabel)
            .. " (id=" .. tostring(anchor)
            .. ", centerOffsetX=" .. tostring(centerOffsetX)
            .. ", centerOffsetY=" .. tostring(centerOffsetY)
            .. ", spawnOffsetX=" .. tostring(spawnOffsetX) .. ")")
        if p1 and p1.ObjectId then
            Teleport { Id = p1.ObjectId, DestinationId = anchor, OffsetX = centerOffsetX - spawnOffsetX, OffsetY = centerOffsetY + spawnOffsetY }
        end
        if p2 and p2.ObjectId then
            Teleport { Id = p2.ObjectId, DestinationId = anchor, OffsetX = centerOffsetX + spawnOffsetX, OffsetY = centerOffsetY - spawnOffsetY }
        end
    end)
end

function MatchEffects.Clamp(hero, hp)
    if hero == nil then
        return
    end
    guarded("Clamp", function()
        hero.Health = hp
    end)
    refreshVitals(hero)
end

function MatchEffects.Announce(text, seconds)
    guarded("Announce", function()
        local anchor = Players.GetHero(1)
        local anchorId = anchor and anchor.ObjectId
        if InCombatText and anchorId then
            InCombatText(anchorId, text, seconds or 2.0)
        else
            log("announce (no InCombatText/anchor): " .. tostring(text))
        end
    end)
end

function MatchEffects.LockInput()
    if inputLocked then
        return
    end
    guarded("LockInput", function()
        if not AddInputBlock then
            return
        end
        for _, id in ipairs({ 1, 2 }) do
            if Players.GetHero(id) then
                AddInputBlock { PlayerIndex = id, Name = INTRO_INPUT_BLOCK }
            end
        end
    end)
    inputLocked = true
end

function MatchEffects.UnlockInput()
    if not inputLocked then
        return
    end
    guarded("UnlockInput", function()
        if not RemoveInputBlock then
            return
        end
        for _, id in ipairs({ 1, 2 }) do
            if Players.GetHero(id) then
                RemoveInputBlock { PlayerIndex = id, Name = INTRO_INPUT_BLOCK }
            end
        end
    end)
    inputLocked = false
end

function MatchEffects.PresentDowned(hero, playerId)
    guarded("PresentDowned", function()
        if hero and hero.ObjectId and SetAnimation then
            SetAnimation { Name = "Melinoe_DeathHover_Start", DestinationId = hero.ObjectId }
        end
        MatchEffects.Announce("Player " .. tostring(playerId) .. " down!", 1.5)
    end)
end

function MatchEffects.PresentVictory(victorId)
    guarded("PresentVictory", function()
        MatchEffects.Announce("Player " .. tostring(victorId) .. " wins the match!", 5.0)
    end)
end

return MatchEffects
