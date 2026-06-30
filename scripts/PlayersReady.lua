local PlayersReady = {}

local subscribers = {}

local log = function() end

function PlayersReady.SetLogger(fn)
    if type(fn) == "function" then
        log = fn
    end
end

function PlayersReady.Subscribe(fn)
    if type(fn) == "function" then
        subscribers[#subscribers + 1] = fn
    end
end

function PlayersReady.Emit()
    for i = 1, #subscribers do
        local ok, err = pcall(subscribers[i])
        if not ok then
            log("PlayersReady subscriber " .. i .. " failed (soft): " .. tostring(err))
        end
    end
end

function PlayersReady.Reset()
    subscribers = {}
end

return PlayersReady
