local Players = {}

Players.MainHero = nil
Players.Dummies = {}

function Players.SetMain(hero)
    Players.MainHero = hero
end

function Players.AddDummy(hero)
    Players.Dummies[#Players.Dummies + 1] = hero
end

function Players.GetHeroByUnit(unitId)
    if unitId == nil then
        return nil
    end
    if Players.MainHero and Players.MainHero.ObjectId == unitId then
        return Players.MainHero
    end
    for i = 1, #Players.Dummies do
        local hero = Players.Dummies[i]
        if hero and hero.ObjectId == unitId then
            return hero
        end
    end
    return nil
end

function Players.GetHero(playerId)
    if playerId == nil then
        return nil
    end
    if playerId == 1 then
        return Players.MainHero
    end
    for i = 1, #Players.Dummies do
        local hero = Players.Dummies[i]
        if hero and hero.AgonPlayerIndex == playerId then
            return hero
        end
    end
    return nil
end

function Players.GetPlayerId(heroOrUnit)
    if heroOrUnit == nil then
        return nil
    end
    local hero = heroOrUnit
    if not Players.IsHero(hero) and hero.ObjectId ~= nil then
        hero = Players.GetHeroByUnit(hero.ObjectId)
    end
    if hero == nil then
        return nil
    end
    if hero == Players.MainHero then
        return 1
    end
    return hero.AgonPlayerIndex
end

function Players.ClearDummies()
    Players.Dummies = {}
end

function Players.IsDummy(unit)
    if unit == nil then
        return false
    end
    for i = 1, #Players.Dummies do
        if Players.Dummies[i] == unit then
            return true
        end
    end
    return false
end

function Players.RemoveDummy(hero)
    for i = 1, #Players.Dummies do
        if Players.Dummies[i] == hero then
            table.remove(Players.Dummies, i)
            return
        end
    end
end

function Players.HeroCount()
    local n = #Players.Dummies
    if Players.MainHero then
        n = n + 1
    end
    return n
end

function Players.HeroIds()
    local ids = {}
    if Players.MainHero and Players.MainHero.ObjectId then
        ids[#ids + 1] = Players.MainHero.ObjectId
    end
    for i = 1, #Players.Dummies do
        local hero = Players.Dummies[i]
        if hero and hero.ObjectId and not hero.IsDead then
            ids[#ids + 1] = hero.ObjectId
        end
    end
    return ids
end

function Players.FindDownedHero()
    if Players.MainHero and Players.MainHero.Health ~= nil and Players.MainHero.Health <= 0 then
        return Players.MainHero
    end
    for i = 1, #Players.Dummies do
        local hero = Players.Dummies[i]
        if hero and hero.Health ~= nil and hero.Health <= 0 then
            return hero
        end
    end
    return nil
end

function Players.IsHero(unit)
    if unit == nil then
        return false
    end
    if unit == Players.MainHero then
        return true
    end
    for i = 1, #Players.Dummies do
        if Players.Dummies[i] == unit then
            return true
        end
    end
    return false
end

function Players.IsHeroFn(unit)
    return Players.IsHero(unit)
end

function Players.Reset()
    Players.MainHero = nil
    Players.Dummies = {}
end

return Players
