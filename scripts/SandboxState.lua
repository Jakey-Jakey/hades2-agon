local SandboxState = {}

SandboxState.Arenas = {
    { Name = "F_Boss01", Biome = "F", Label = "Hecate's Hall" },
}

SandboxState.DefaultArenaName = "F_Boss01"

function SandboxState.ResolveArena(arenas, name)
    arenas = arenas or SandboxState.Arenas
    name = name or SandboxState.DefaultArenaName
    for _, arena in ipairs(arenas) do
        if arena.Name == name then
            return arena
        end
    end
    return nil
end

function SandboxState.New()
    return { active = false, stash = nil }
end

function SandboxState.IsActive(s)
    return s.active == true
end

function SandboxState.Enter(s, liveGameState, liveCurrentRun)
    if s.active then
        return false
    end
    s.stash = { GameState = liveGameState, CurrentRun = liveCurrentRun }
    s.active = true
    return true
end

function SandboxState.Exit(s)
    if not s.active then
        return nil
    end
    local stash = s.stash
    s.active = false
    s.stash = nil
    return stash
end

return SandboxState
