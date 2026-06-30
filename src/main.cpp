#include "pch.h"

#include <HadesModApi.h>
#include <HookTable.h>

#include "AgonLog.h"
#include "AgonLua.h"
#include "AnimationSwap.h"
#include "LuaLoadCorruptionGuard.h"
#include "ProfileBoot.h"

HADES_MOD_API void _cdecl HadesModLuaCreated(lua_State *luaState) {
    AgonLog("HadesModLuaCreated - game Lua state ready; init.lua will register the Versus gamemode");

    AgonLua::Load(luaState);
}

HADES_MOD_API bool _cdecl HadesModInit(const IModApi *modApi) {
    if (modApi->version < MOD_API_VERSION) {
        AgonLog("HadesModInit - mod-extension API version too old; aborting load");
        return false;
    }

    HookTable::Instance().Init(*modApi->GetHookTable());

    Agon::InstallLuaLoadCorruptionGuard(modApi->GetSymbolAddress);

    Agon::InstallProfileBootHook();
    Agon::InstallAnimationSwapHooks(modApi->GetSymbolAddress);

    AgonLog("HadesModInit - AGON native plugin loaded under Hell2Modding + mod-extension (coexistence spike)");
    return true;
}

HADES_MOD_API bool _cdecl HadesModStart() {
    AgonLog("HadesModStart");
    return true;
}

HADES_MOD_API bool _cdecl HadesModStop() {
    AgonLog("HadesModStop");
    return true;
}
