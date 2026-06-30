#include "pch.h"

#include <array>
#include <cstdint>
#include <dbghelp.h>
#include <string>

#include "ProfileBoot.h"
#include "AgonLog.h"

#include "hooks/FunctionHook.h"

void Mem::MemSetUnsafe(void *dest, int val, size_t size) {
    DWORD oldProtect = 0;
    VirtualProtect(dest, size, PAGE_EXECUTE_READWRITE, &oldProtect);
    std::memset(dest, val, size);
    DWORD restoredFrom = 0;
    VirtualProtect(dest, size, oldProtect, &restoredFrom);
}

void Mem::MemCpyUnsafe(void *dest, void *src, size_t size) {
    DWORD oldProtect = 0;
    VirtualProtect(dest, size, PAGE_EXECUTE_READWRITE, &oldProtect);
    std::memcpy(dest, src, size);
    DWORD restoredFrom = 0;
    VirtualProtect(dest, size, oldProtect, &restoredFrom);
}

namespace {

constexpr size_t HOOK_PATCH_SIZE = 12;
constexpr uint8_t SAVE_RESULT_SUCCESS = 3;

constexpr ptrdiff_t CONTINUE_GAME_FLAG_OFFSET = 0x2A8;
constexpr ptrdiff_t NEW_GAME_FLAG_OFFSET = 0x2A9;

uintptr_t g_startOrContinueAddr = 0;
uintptr_t g_saveValidCheckpointAddr = 0;

bool g_pending = false;

void *g_profileScreen = nullptr;

bool g_blockValidCheckpointSaves = false;
bool g_saveValidCheckpointHookInstalled = false;
int g_suppressedValidCheckpointSaves = 0;
std::array<uint8_t, HOOK_PATCH_SIZE> g_saveValidCheckpointOriginal{};

FunctionHook<"AgonRPSSetupProfiles", void, void *> g_setupProfilesHook;

void WriteAbsoluteJump(void *dest, void *target) {
    std::array<uint8_t, HOOK_PATCH_SIZE> patch{};
    patch.fill(0x90);
    patch[0] = 0x48;
    patch[1] = 0xB8;
    *reinterpret_cast<uintptr_t *>(&patch[2]) = reinterpret_cast<uintptr_t>(target);
    patch[10] = 0xFF;
    patch[11] = 0xE0;
    Mem::MemCpyUnsafe(dest, patch.data(), patch.size());
}

uintptr_t ResolveSymbol(const char *name) {
    static HMODULE dbgHelp = LoadLibraryA("dbghelp.dll");
    if (dbgHelp == nullptr) {
        return 0;
    }
    using SymFromName_t = BOOL(WINAPI *)(HANDLE, PCSTR, PSYMBOL_INFO);
    static auto pSymFromName =
        reinterpret_cast<SymFromName_t>(GetProcAddress(dbgHelp, "SymFromName"));
    if (pSymFromName == nullptr) {
        return 0;
    }

    SYMBOL_INFO_PACKAGE pkg = {};
    pkg.si.SizeOfStruct = sizeof(SYMBOL_INFO);
    pkg.si.MaxNameLen = MAX_SYM_NAME;
    if (!pSymFromName(GetCurrentProcess(), name, &pkg.si)) {
        return 0;
    }
    return static_cast<uintptr_t>(pkg.si.Address);
}

uintptr_t ResolveSymbol(const char *undecorated, const char *decorated) {
    uintptr_t addr = ResolveSymbol(undecorated);
    if (addr != 0 || decorated == nullptr) {
        return addr;
    }
    return ResolveSymbol(decorated);
}

uint8_t ReadScreenByte(void *screen, ptrdiff_t offset) {
    return *reinterpret_cast<uint8_t *>(static_cast<char *>(screen) + offset);
}

void WriteScreenByte(void *screen, ptrdiff_t offset, uint8_t value) {
    *reinterpret_cast<uint8_t *>(static_cast<char *>(screen) + offset) = value;
}

void RestoreSaveValidCheckpoint() {
    if (g_saveValidCheckpointAddr == 0 || !g_saveValidCheckpointHookInstalled) {
        return;
    }
    Mem::MemCpyUnsafe(reinterpret_cast<void *>(g_saveValidCheckpointAddr),
                     g_saveValidCheckpointOriginal.data(), g_saveValidCheckpointOriginal.size());
    g_saveValidCheckpointHookInstalled = false;
}

uint8_t __fastcall SaveValidCheckpointDetour(void *progressManager, bool flag) {
    if (g_blockValidCheckpointSaves) {
        ++g_suppressedValidCheckpointSaves;
        if (g_suppressedValidCheckpointSaves == 1 ||
            g_suppressedValidCheckpointSaves % 20 == 0) {
            AgonLog("profile-boot: suppressed native SaveValidCheckpoint "
                    "(blocking Profile*.v.sav during Versus)");
        }
        return SAVE_RESULT_SUCCESS;
    }

    RestoreSaveValidCheckpoint();
    const auto original =
        reinterpret_cast<uint8_t(__fastcall *)(void *, bool)>(g_saveValidCheckpointAddr);
    const uint8_t result = original(progressManager, flag);
    WriteAbsoluteJump(reinterpret_cast<void *>(g_saveValidCheckpointAddr),
                      reinterpret_cast<void *>(&SaveValidCheckpointDetour));
    g_saveValidCheckpointHookInstalled = true;
    return result;
}

void InstallSaveValidCheckpointHook() {
    if (g_saveValidCheckpointAddr == 0 || g_saveValidCheckpointHookInstalled) {
        return;
    }
    std::memcpy(g_saveValidCheckpointOriginal.data(),
                reinterpret_cast<void *>(g_saveValidCheckpointAddr),
                g_saveValidCheckpointOriginal.size());
    WriteAbsoluteJump(reinterpret_cast<void *>(g_saveValidCheckpointAddr),
                      reinterpret_cast<void *>(&SaveValidCheckpointDetour));
    g_saveValidCheckpointHookInstalled = true;
}

void LogProfilePumpFlags(const char *prefix) {
    if (g_profileScreen == nullptr) {
        return;
    }
    const uint8_t continueFlag = ReadScreenByte(g_profileScreen, CONTINUE_GAME_FLAG_OFFSET);
    const uint8_t newGameFlag = ReadScreenByte(g_profileScreen, NEW_GAME_FLAG_OFFSET);
    std::string message = std::string("profile-boot: ") + prefix +
                          " flags continue(0x2A8)=" + std::to_string(continueFlag) +
                          " new-game(0x2A9)=" + std::to_string(newGameFlag);
    AgonLog(message.c_str());
}

void FireSaveFreeStart() {
    if (g_profileScreen == nullptr) {
        return;
    }

    if (g_startOrContinueAddr == 0 || g_profileScreen == nullptr) {
        return;
    }
    LogProfilePumpFlags("before force");
    WriteScreenByte(g_profileScreen, CONTINUE_GAME_FLAG_OFFSET, 0);
    WriteScreenByte(g_profileScreen, NEW_GAME_FLAG_OFFSET, 1);
    LogProfilePumpFlags("after force");

    AgonLog("profile-boot: issuing late StartOrContinueGame after profile setup "
            "(forcing native new-game gameplay pump)");
    g_blockValidCheckpointSaves = true;
    reinterpret_cast<void(__fastcall *)(void *)>(g_startOrContinueAddr)(g_profileScreen);
}

}

namespace Agon {

void InstallProfileBootHook() {
    uintptr_t setupProfilesAddr =
        ResolveSymbol("sgg::RemoteProfileScreen::SetupProfiles",
                      "?SetupProfiles@RemoteProfileScreen@sgg@@AEAAXXZ");
    g_startOrContinueAddr =
        ResolveSymbol("sgg::RemoteProfileScreen::StartOrContinueGame",
                      "?StartOrContinueGame@RemoteProfileScreen@sgg@@AEAAXXZ");
    g_saveValidCheckpointAddr =
        ResolveSymbol("sgg::ProgressManager::SaveValidCheckpoint",
                      "?SaveValidCheckpoint@ProgressManager@sgg@@QEAA?AW4LoadResult@2@_N@Z");

    if (setupProfilesAddr == 0 || g_startOrContinueAddr == 0) {
        AgonLog("profile-boot: could not resolve RemoteProfileScreen symbols "
                "(SetupProfiles or StartOrContinueGame) - save-free boot "
                "DISABLED, Versus will fall back to the profile picker");
        return;
    }
    if (g_saveValidCheckpointAddr != 0) {
        InstallSaveValidCheckpointHook();
    } else {
        AgonLog("profile-boot: could not resolve ProgressManager::SaveValidCheckpoint "
                "- native Profile*.v.sav writes will not be blocked");
    }

    g_setupProfilesHook.onPreFunction = [](void *&self) {
        if (g_pending) {
            g_profileScreen = self;
        }
    };
    g_setupProfilesHook.onPostFunction = []() {
        if (!g_pending) {
            return;
        }
        g_pending = false;
        AgonLog("profile-boot: profiles set up with a pending Versus boot - "
                "forcing the native new-game pump branch");
        FireSaveFreeStart();
    };
    g_setupProfilesHook.Install(reinterpret_cast<void *>(setupProfilesAddr), HOOK_PATCH_SIZE);

    AgonLog("profile-boot: armed - RemoteProfileScreen::SetupProfiles hooked, "
            "late StartOrContinueGame resolved (save-free Versus boot enabled)");
}

void RequestSaveFreeBoot() {
    if (g_startOrContinueAddr == 0) {
        AgonLog("profile-boot: save-free boot requested but symbols are unresolved "
                "- the picker will be used");
        return;
    }
    g_pending = true;
    AgonLog("profile-boot: save-free boot requested - will start the active profile "
            "when the profile screen builds");
}

bool HasProfileScreen() { return g_profileScreen != nullptr; }

}
