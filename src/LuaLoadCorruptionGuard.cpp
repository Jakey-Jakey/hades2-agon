#include "pch.h"

#include "LuaLoadCorruptionGuard.h"

#include <cstring>

#include "AgonLog.h"
#include "AgonLua.h"
#include "hooks/FunctionHook.h"

namespace {

constexpr size_t HOOK_PATCH_SIZE = 12;

bool g_isSanitizeTarget(const char *name) {
    if (name == nullptr) {
        return false;
    }
    static const char *const targets[] = {
        "NarrativeData", "AudioData", "TradePresentation", "EnemyAILogic",
        "NPCData",       "UIData",    "HUDData",           "EnemyData",
    };
    for (const char *t : targets) {
        if (std::strstr(name, t) != nullptr) {
            return true;
        }
    }
    return false;
}

FunctionHook<"AgonLuaLLoadBufferx", int, void *, const char *, size_t, const char *, const char *>
    g_loadBufferx;

bool g_installed = false;

}

namespace Agon {

void InstallLuaLoadCorruptionGuard(IModApi::GetSymbolAddress_t getSymbolAddress) {
    if (g_installed) {
        return;
    }
    g_installed = true;

    if (getSymbolAddress == nullptr) {
        AgonLog("lua load guard: no symbol resolver; issue #29 guard not installed");
        return;
    }

    const auto address = static_cast<uintptr_t>(getSymbolAddress("luaL_loadbufferx"));
    if (address == 0) {
        AgonLog("lua load guard: luaL_loadbufferx symbol missing; issue #29 guard not installed");
        return;
    }

    g_loadBufferx.Install(reinterpret_cast<void *>(address), HOOK_PATCH_SIZE);
    g_loadBufferx.onPreFunction = [](void *&luaState, const char *&buff, size_t &size,
                                     const char *&name, const char *&) {
        (void)buff;
        (void)size;

        if (g_isSanitizeTarget(name)) {
            Agon::SanitizeLoadCorruption(luaState, name);
        }
    };

    AgonLog("lua load guard: luaL_loadbufferx issue #29 guard installed");
}

}
