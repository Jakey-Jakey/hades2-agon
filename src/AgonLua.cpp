#include "pch.h"

#include <cstdarg>
#include <cstdio>

#include "AgonLog.h"
#include "AgonLua.h"
#include "AnimationSwap.h"
#include "AgonSpawn.h"
#include "ProfileBoot.h"

#include "lua.hpp"

namespace {

int AgonCreatePlayer(lua_State *L) {
    size_t playerIndex = Agon::CreatePlayer();

    if (playerIndex != Agon::INVALID_PLAYER_INDEX)
        lua_pushnumber(L, static_cast<lua_Number>(playerIndex + 1));
    else
        lua_pushboolean(L, false);

    return 1;
}

int AgonCreatePlayerUnit(lua_State *L) {
    if (!lua_isnumber(L, 1))
        return luaL_error(L, "AgonCreatePlayerUnit: argument 1 must be a number");

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;
    size_t unitId = Agon::CreatePlayerUnit(playerIndex);

    if (unitId != Agon::INVALID_UNIT_ID)
        lua_pushnumber(L, static_cast<lua_Number>(unitId));
    else
        lua_pushboolean(L, false);

    return 1;
}

int AgonGetPlayersCount(lua_State *L) {
    lua_pushnumber(L, static_cast<lua_Number>(Agon::GetPlayersCount()));
    return 1;
}

int AgonHasPlayer(lua_State *L) {
    if (!lua_isnumber(L, 1))
        return luaL_error(L, "AgonHasPlayer: argument 1 must be a number");

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;
    lua_pushboolean(L, Agon::HasPlayer(playerIndex));
    return 1;
}

int AgonSetPlayerGamepad(lua_State *L) {
    if (!lua_isnumber(L, 1))
        return luaL_error(L, "AgonSetPlayerGamepad: argument 1 must be a number");
    if (!lua_isnumber(L, 2))
        return luaL_error(L, "AgonSetPlayerGamepad: argument 2 must be a number");

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;
    unsigned char gamepadId = static_cast<unsigned char>(lua_tonumber(L, 2));
    lua_pushboolean(L, Agon::SetPlayerGamepad(playerIndex, gamepadId));
    return 1;
}

int AgonSetPlayerController(lua_State *L) {
    if (!lua_isnumber(L, 1))
        return luaL_error(L, "AgonSetPlayerController: argument 1 must be a number");
    if (!lua_isnumber(L, 2))
        return luaL_error(L, "AgonSetPlayerController: argument 2 must be a number");

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;
    unsigned char controllerIndex = static_cast<unsigned char>(lua_tonumber(L, 2));
    lua_pushboolean(L, Agon::SetPlayerController(playerIndex, controllerIndex));
    return 1;
}

int AgonClearPlayerUnit(lua_State *L) {
    if (!lua_isnumber(L, 1))
        return luaL_error(L, "AgonClearPlayerUnit: argument 1 must be a number");

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;
    lua_pushboolean(L, Agon::ClearPlayerUnit(playerIndex));
    return 1;
}

int AgonGetInputMethodsCount(lua_State *L) {
    lua_pushnumber(L, static_cast<lua_Number>(Agon::GetInputMethodsCount()));
    return 1;
}

int AgonGetPlayerControllerIndex(lua_State *L) {
    if (!lua_isnumber(L, 1))
        return luaL_error(L, "AgonGetPlayerControllerIndex: argument 1 must be a number");

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;
    lua_pushnumber(L, static_cast<lua_Number>(Agon::GetPlayerControllerIndex(playerIndex)));
    return 1;
}

int AgonGetPlayerGamepad(lua_State *L) {
    if (!lua_isnumber(L, 1))
        return luaL_error(L, "AgonGetPlayerGamepad: argument 1 must be a number");

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;
    lua_pushnumber(L, static_cast<lua_Number>(Agon::GetPlayerGamepad(playerIndex)));
    return 1;
}

int AgonGetInputMethodGamepad(lua_State *L) {
    if (!lua_isnumber(L, 1))
        return luaL_error(L, "AgonGetInputMethodGamepad: argument 1 must be a number");

    size_t methodIndex = static_cast<size_t>(lua_tonumber(L, 1));
    lua_pushnumber(L, static_cast<lua_Number>(Agon::GetInputMethodGamepad(methodIndex)));
    return 1;
}

int AgonRemovePlayerUnit(lua_State *L) {
    if (!lua_isnumber(L, 1))
        return luaL_error(L, "AgonRemovePlayerUnit: argument 1 must be a number");

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;
    lua_pushboolean(L, Agon::RemovePlayerUnit(playerIndex));
    return 1;
}

int AgonSetCurrentMainPlayer(lua_State *L) {
    if (!lua_isnumber(L, 1))
        return luaL_error(L, "AgonSetCurrentMainPlayer: argument 1 must be a number");

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;
    Agon::SetCurrentMainPlayer(playerIndex);
    return 0;
}

int AgonResetCurrentMainPlayer(lua_State *L) {
    Agon::ResetCurrentMainPlayer();
    return 0;
}

int AgonSetAnimationSwap(lua_State *L) {
    if (!lua_isnumber(L, 1))
        return luaL_error(L, "AgonSetAnimationSwap: argument 1 must be a number");
    if (!lua_isstring(L, 2))
        return luaL_error(L, "AgonSetAnimationSwap: argument 2 must be a string");
    if (!lua_isstring(L, 3))
        return luaL_error(L, "AgonSetAnimationSwap: argument 3 must be a string");

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;
    const char *fromAnimation = lua_tostring(L, 2);
    const char *toAnimation = lua_tostring(L, 3);
    lua_pushboolean(L, Agon::SetAnimationSwap(playerIndex, fromAnimation, toAnimation));
    return 1;
}

int AgonRemoveAnimationSwap(lua_State *L) {
    if (!lua_isnumber(L, 1))
        return luaL_error(L, "AgonRemoveAnimationSwap: argument 1 must be a number");
    if (!lua_isstring(L, 2))
        return luaL_error(L, "AgonRemoveAnimationSwap: argument 2 must be a string");

    size_t playerIndex = static_cast<size_t>(lua_tonumber(L, 1)) - 1;
    const char *fromAnimation = lua_tostring(L, 2);
    lua_pushboolean(L, Agon::RemoveAnimationSwap(playerIndex, fromAnimation));
    return 1;
}

}

int AgonRequestSaveFreeBoot(lua_State *L) {
    (void)L;
    Agon::RequestSaveFreeBoot();
    return 0;
}

int AgonHasProfileScreen(lua_State *L) {
    lua_pushboolean(L, Agon::HasProfileScreen());
    return 1;
}

int AgonResumeGC(lua_State *L) {
    lua_gc(L, LUA_GCRESTART, 0);
    AgonLog("gc-guard: incremental GC restarted after the bulk script load (issue #29)");
    return 0;
}

static void agonLogf(const char *fmt, ...) {
    char buf[256];
    va_list ap;
    va_start(ap, fmt);
    _vsnprintf_s(buf, sizeof(buf), _TRUNCATE, fmt, ap);
    va_end(ap);
    AgonLog(buf);
}

static int SanitizeInvalidCollectables(lua_State *L) {
    if (L == nullptr) {
        return 0;
    }
    int fixed = 0;
    __try {
        const char *g = *reinterpret_cast<char *const *>(reinterpret_cast<const char *>(L) + 0x18);
        if (g == nullptr) {
            return 0;
        }
        unsigned long long obj = *reinterpret_cast<const unsigned long long *>(g + 0x60);
        unsigned long long guard = 0;
        while (obj != 0 && guard++ < 4000000ull) {
            const unsigned char tt = *reinterpret_cast<const unsigned char *>(obj + 8);
            if ((tt & 0x0f) == 5) {
                const unsigned long long array = *reinterpret_cast<const unsigned long long *>(obj + 0x18);
                const int sizearray = *reinterpret_cast<const int *>(obj + 0x38);
                if (array != 0 && sizearray > 0 && sizearray < 1000000) {
                    for (int i = 0; i < sizearray; i++) {
                        const unsigned long long tv = array + static_cast<unsigned long long>(i) * 16;
                        const unsigned char vtt = *reinterpret_cast<const unsigned char *>(tv + 8);
                        if (vtt & 0x40) {
                            const unsigned long long val = *reinterpret_cast<const unsigned long long *>(tv);
                            if (val < 0x10000ull) {
                                *reinterpret_cast<int *>(tv + 8) = 0;
                                fixed++;
                            }
                        }
                    }
                }
            }
            obj = *reinterpret_cast<const unsigned long long *>(obj);
        }
    } __except (EXCEPTION_EXECUTE_HANDLER) {
    }
    return fixed;
}

namespace Agon {
void SanitizeLoadCorruption(void *L, const char *scriptName) {
    const int fixed = SanitizeInvalidCollectables(reinterpret_cast<lua_State *>(L));
    if (fixed > 0) {
        agonLogf("gc-fix: neutralized %d corrupt collectable value(s) before '%s' (issue #29)",
                 fixed, scriptName ? scriptName : "?");
    }
}
}

void AgonLua::Load(lua_State *L) {
#define AGON_REGISTER(fun) lua_register(L, #fun, fun)
    AGON_REGISTER(AgonCreatePlayer);
    AGON_REGISTER(AgonCreatePlayerUnit);
    AGON_REGISTER(AgonClearPlayerUnit);
    AGON_REGISTER(AgonSetPlayerGamepad);
    AGON_REGISTER(AgonSetPlayerController);
    AGON_REGISTER(AgonRemovePlayerUnit);
    AGON_REGISTER(AgonGetPlayersCount);
    AGON_REGISTER(AgonHasPlayer);
    AGON_REGISTER(AgonGetInputMethodsCount);
    AGON_REGISTER(AgonGetPlayerControllerIndex);
    AGON_REGISTER(AgonGetPlayerGamepad);
    AGON_REGISTER(AgonGetInputMethodGamepad);
    AGON_REGISTER(AgonSetCurrentMainPlayer);
    AGON_REGISTER(AgonResetCurrentMainPlayer);
    AGON_REGISTER(AgonSetAnimationSwap);
    AGON_REGISTER(AgonRemoveAnimationSwap);
    AGON_REGISTER(AgonRequestSaveFreeBoot);
    AGON_REGISTER(AgonHasProfileScreen);
    AGON_REGISTER(AgonResumeGC);
#undef AGON_REGISTER

    lua_gc(L, LUA_GCSTOP, 0);
    AgonLog("gc-guard: incremental GC stopped for the bulk script load (issue #29)");
}
