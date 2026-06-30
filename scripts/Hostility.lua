local Hostility = {}

function Hostility.IsHostile(attacker, victim, isHero)
    if attacker == nil or victim == nil then
        return false
    end
    if attacker == victim then
        return false
    end
    return isHero(attacker) and isHero(victim)
end

function Hostility.IsHeroSelfHit(attacker, victim, isHero)
    if attacker == nil or victim == nil then
        return false
    end
    return attacker == victim and isHero(victim)
end

return Hostility
