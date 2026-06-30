local HookUtils = ModRequire "HookUtils.lua"
local Players = ModRequire "Players.lua"
local PlayersReady = ModRequire "PlayersReady.lua"
local log = ModRequire "Log.lua"

local Camera = {}

local RELOCK_DURATION = 0.0

Camera._enabled = false
Camera._installed = false
Camera._tickInstalled = false
Camera._forceFocus = true
Camera.LockCameraOrig = nil

function Camera.IsActive()
    return Camera._enabled and Players.HeroCount() >= 2
end

function Camera.Update()
    if not Camera._forceFocus or not Camera.IsActive() then
        return
    end
    if not Camera.LockCameraOrig then
        return
    end
    local ids = Players.HeroIds()
    if #ids == 0 then
        return
    end
    Camera.LockCameraOrig { Ids = ids, Duration = RELOCK_DURATION }
end

function Camera.WrapLockCamera(original, args)
    if not Camera.IsActive() then
        return original(args)
    end

    local mainId = Players.MainHero and Players.MainHero.ObjectId
    if mainId and args and args.Id == mainId then
        Camera._forceFocus = true
        return Camera.Update()
    end

    Camera._forceFocus = false
    return original(args)
end

function Camera.InstallTick()
    if Camera._tickInstalled then
        return
    end
    if not draw then
        log("draw global missing - shared-camera tick not installed")
        return
    end
    Camera._tickInstalled = true
    HookUtils.wrap("draw", function(original, ...)
        original(...)
        local ok, err = pcall(Camera.Update)
        if not ok then
            Camera._enabled = false
            log("shared-camera tick error - framing disabled for this run: " .. tostring(err))
        end
    end)
    log("shared-camera tick installed (draw post-wrap)")
end

function Camera.Enable()
    Camera._enabled = true
    Camera._forceFocus = true
end

function Camera.RefocusMain()
    local mainId = Players.MainHero and Players.MainHero.ObjectId
    if Camera.LockCameraOrig and mainId then
        Camera.LockCameraOrig { Id = mainId }
    end
end

function Camera.InstallHook()
    if not Camera._installed then
        if not LockCamera then
            log("LockCamera global missing - shared camera not installed")
            return
        end
        Camera._installed = true
        Camera.LockCameraOrig = LockCamera
        HookUtils.wrap("LockCamera", Camera.WrapLockCamera)
        PlayersReady.Subscribe(Camera.Enable)
        log("shared-camera wrap installed (LockCamera)")
    end
    Camera.InstallTick()
end

function Camera.Reset()
    Camera._enabled = false
    Camera._forceFocus = true
end

return Camera
