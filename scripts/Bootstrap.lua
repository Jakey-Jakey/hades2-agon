local HookUtils = ModRequire "HookUtils.lua"
local HeroContext = ModRequire "HeroContext.lua"
local HeroContextNative = ModRequire "HeroContextNative.lua"
local HeroContextDiagnostics = ModRequire "HeroContextDiagnostics.lua"
local FriendlyFire = ModRequire "FriendlyFire.lua"
local Players = ModRequire "Players.lua"
local Spawn = ModRequire "Spawn.lua"
local Control = ModRequire "Control.lua"
local Camera = ModRequire "Camera.lua"
local Sandbox = ModRequire "Sandbox.lua"
local CastSlow = ModRequire "CastSlow.lua"
local TreeBlast = ModRequire "TreeBlast.lua"
local HitInvulnerability = ModRequire "HitInvulnerability.lua"
local Match = ModRequire "Match.lua"
local VersusTuning = ModRequire "VersusTuning.lua"
local MatchOrchestration = ModRequire "MatchOrchestration.lua"
local MatchEffects = ModRequire "MatchEffects.lua"
local MatchHud = ModRequire "MatchHud.lua"
local PlayersReady = ModRequire "PlayersReady.lua"
local AnimationSwap = ModRequire "AnimationSwap.lua"
local VisualIdentity = ModRequire "VisualIdentity.lua"
local log = ModRequire "Log.lua"

local Bootstrap = {}

Bootstrap._installed = false

local function installVisualIdentity()
    if VisualIdentity == nil then
        log("visual identity: module not loaded - skipping install")
        return
    end
    local ok, err = pcall(VisualIdentity.Install)
    if not ok then
        log("visual identity: install failed - " .. tostring(err))
    end
end

function Bootstrap.Install()
    if Bootstrap._installed then
        return
    end
    Bootstrap._installed = true

    if type(AgonResumeGC) == "function" then
        AgonResumeGC()
    end

    HeroContext.InitHooks()
    AnimationSwap.Install()
    HeroContextNative.SetHeroContext(HeroContext)
    HeroContextDiagnostics.Install()

    PlayersReady.SetLogger(log)

    Spawn.InstallDebugTrigger()

    Camera.InstallHook()

    installVisualIdentity()

    MatchHud.Configure {
        MatchOrchestration = MatchOrchestration,
        Match = Match,
        HookUtils = HookUtils,
        log = log,
    }
    MatchHud.InstallTick()

    MatchOrchestration.Configure {
        Match = Match,
        Players = Players,
        HookUtils = HookUtils,
        Sandbox = Sandbox,
        Effects = MatchEffects,
        Schedule = MatchEffects.Schedule,
        Hud = MatchHud,
        PlayersReady = PlayersReady,
        VersusTuning = VersusTuning,
        log = log,
    }
    MatchOrchestration.Install()

    FriendlyFire.InstallCombatRouting("gameplay")
    FriendlyFire.PatchTrapDamage()

    CastSlow.Install(Players, HeroContext, HookUtils, log)

    TreeBlast.Install(Players, HookUtils, log)

    HitInvulnerability.Install(Players, HookUtils, VersusTuning, log)

    if type(GetWeaponChargeFraction) == "function" then
        HookUtils.wrap("GetWeaponChargeFraction", function(base, ...)
            return HeroContextNative.RunWithNativeHeroContextFromHero(base, ...)
        end)
        log("native charge context installed (GetWeaponChargeFraction -> acting player)")
    else
        log("GetWeaponChargeFraction missing at install - P2 omega charge not routed")
    end

    if type(ShowMoneyUI) == "function" then
        HookUtils.wrap("ShowMoneyUI", function(base, ...)
            if Sandbox.IsActive() then
                if type(HideMoneyUI) == "function" then
                    HideMoneyUI()
                end
                return
            end
            return base(...)
        end)
        log("money UI hidden during Versus matches (ShowMoneyUI gated on active sandbox)")
    else
        log("ShowMoneyUI missing at install - money UI not hidden in Versus")
    end

    Sandbox.InstallHooks()

    Control.InstallRoutingWrap()

    Control.DisableHotSwap()

    log("AGON bootstrap complete (combat routing + auto-spawn + match loop armed)")
end

function Bootstrap.Arm()
    Control.InstallRoutingWrap()
    FriendlyFire.InstallCombatRouting("init")
    OnPreThingCreation { Bootstrap.Install }
end

return Bootstrap
