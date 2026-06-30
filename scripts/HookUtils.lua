local HookUtils = {}

function HookUtils.wrap(funcName, handler)
    local original = _G[funcName]

    if not original then
        error("AGON HookUtils.wrap: cannot wrap missing function '" .. tostring(funcName) .. "'")
    end

    _G[funcName] = function(...)
        return handler(original, ...)
    end
end

function HookUtils.wrapOnce(funcName, handler)
    local original = _G[funcName]

    if not original then
        error("AGON HookUtils.wrapOnce: cannot wrap missing function '" .. tostring(funcName) .. "'")
    end

    _G[funcName] = function(...)
        local result = { handler(original, ...) }
        _G[funcName] = original
        return table.unpack(result)
    end
end

return HookUtils
