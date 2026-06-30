local log = ModRequire "Log.lua"

local Versus = {
    Name = "Versus",
    Flavour = "Sparring",
}

local function directBootFallback(reason)
    log("Versus setup fallback: " .. tostring(reason))

    local MatchConfig = ModRequire "MatchConfig.lua"
    MatchConfig.Reset()
    MatchConfig.Persist(MatchConfig.Current())

    local Sandbox = ModRequire "Sandbox.lua"
    Sandbox.MarkPending()
    SetTempRuntimeData("Gamemode", nil)

    if type(AgonRequestSaveFreeBoot) == "function" then
        AgonRequestSaveFreeBoot()
    end
    MainMenuOpenProfiles()
end

function Versus.OnSelected(name)
    log("Versus selected (Sparring); gamemode='" .. tostring(name) .. "'")
    DebugPrint { Text = "[AGON] Versus selected (Sparring); gamemode='" .. tostring(name) .. "'" }

    local opened, err = false, nil
    local ok, perr = pcall(function()
        local SetupScreen = ModRequire "SetupScreen.lua"
        opened, err = SetupScreen.Open(name)
    end)
    if not ok then
        directBootFallback("setup screen threw: " .. tostring(perr))
    elseif not opened then
        directBootFallback("setup screen failed: " .. tostring(err))
    end
end

return Versus
