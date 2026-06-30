local function log(msg)
    print("[AGON] " .. msg)
    if DebugPrint then
        DebugPrint { Text = "[AGON] " .. msg }
    end
end

return log
