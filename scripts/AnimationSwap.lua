local HookUtils = ModRequire "HookUtils.lua"
local HeroContext = ModRequire "HeroContext.lua"
local Players = ModRequire "Players.lua"
local log = ModRequire "Log.lua"

local AnimationSwap = {}

local installed = false

local ANIMATIONS_TO_SWAP = {
    MelinoeIdle = true,
    MelinoeDashStart = true,
    MelinoeDash = true,
    MelinoeSprint = true,
    MelinoeStart = true,
    MelinoeRun = true,
    MelinoeStop = true,
    MelinoeGetHit = true,
    Melinoe_GetHit_LastStand = true,

    Melinoe_Cast_Start = true,
    Melinoe_Cast_StartLoop = true,
    Melinoe_Cast_Fire = true,
    Melinoe_Cast_End = true,
    Melinoe_Cast_Fire_Quick = true,

    Melinoe_CrossCast_Start = true,
    Melinoe_ForwardCast_Unequip = true,

    MelinoeEquip = true,
    MelinoeActionIdle = true,
    MelinoeInteract = true,
    MelinoeBoonPreInteract = true,
}

local function currentPlayerId()
    local hero = nil
    if HeroContext and HeroContext.GetCurrentHeroContext then
        hero = HeroContext.GetCurrentHeroContext()
    end
    if hero ~= nil then
        if hero.AgonPlayerIndex ~= nil then
            return hero.AgonPlayerIndex
        end
        local id = Players.GetPlayerId(hero)
        if id ~= nil then
            return id
        end
    end
    return 1
end

function AnimationSwap.Install()
    if installed then
        return
    end
    installed = true

    if type(SwapAnimation) ~= "function" then
        log("animation swaps: SwapAnimation missing - per-player Lua capture not installed")
        return
    end
    if type(AgonSetAnimationSwap) ~= "function" or type(AgonRemoveAnimationSwap) ~= "function" then
        log("animation swaps: native functions missing - per-player Lua capture not installed")
        return
    end

    HookUtils.wrap("SwapAnimation", function(base, args)
        if type(args) ~= "table" or not ANIMATIONS_TO_SWAP[args.Name] then
            return base(args)
        end

        local playerId = currentPlayerId()
        if args.Reverse then
            AgonRemoveAnimationSwap(playerId, args.Name)
            return base(args)
        end
        if type(args.DestinationName) ~= "string" then
            return base(args)
        end
        AgonSetAnimationSwap(playerId, args.Name, args.DestinationName)
        return base(args)
    end)
    log("animation swaps: per-player Lua capture installed")
end

return AnimationSwap
