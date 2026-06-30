#include "pch.h"

#include "AnimationSwap.h"

#include <array>
#include <unordered_map>

#include <hades2/AnimationData.h>
#include <hades2/GameDataManager.h>
#include <hades2/HashGuid.h>
#include <hades2/Player.h>
#include <hades2/PlayerUnit.h>
#include <hades2/Thing.h>
#include <hades2/Unit.h>

#include "AgonLog.h"
#include "hooks/FunctionHook.h"

namespace {

constexpr size_t HOOK_PATCH_SIZE = 12;
constexpr size_t MAX_LOCAL_PLAYERS = 5;

class PlayerAnimationSwaps {
  public:
    void Set(sgg::HashGuid fromAnimation, sgg::HashGuid toAnimation) {
        swaps_[fromAnimation.GetId()] = toAnimation.GetId();
    }

    void Remove(sgg::HashGuid fromAnimation) { swaps_.erase(fromAnimation.GetId()); }

    bool Get(sgg::HashGuid fromAnimation, sgg::HashGuid &outToAnimation) const {
        const auto found = swaps_.find(fromAnimation.GetId());
        if (found == swaps_.end()) {
            return false;
        }
        outToAnimation = sgg::HashGuid(found->second);
        return true;
    }

    void Reset() { swaps_.clear(); }

  private:
    std::unordered_map<uint32_t, uint32_t> swaps_{};
};

std::array<PlayerAnimationSwaps, MAX_LOCAL_PLAYERS> g_playerSwaps{};
size_t g_lastKnownPlayerIndex = 0;
sgg::HashGuid g_lastLookupName{0};
sgg::HashGuid *g_lastLookupResult = nullptr;

FunctionHook<"AgonThingSetAnimation", void *, sgg::Thing *, sgg::HashGuid, bool, bool, bool,
             sgg::HashGuid>
    g_thingSetAnimation;
FunctionHook<"AgonUnitPlayMoveAnimation", void, sgg::Unit *, bool> g_unitPlayMoveAnimation;
FunctionHook<"AgonUnitIsPlayingMoveAnimation", int64_t, sgg::Unit *> g_unitIsPlayingMoveAnimation;
FunctionHook<"AgonAnimationGetNameSwapHash", sgg::HashGuid *, sgg::HashGuid *, sgg::HashGuid>
    g_getNameSwapByHash;
FunctionHook<"AgonAnimationGetNameSwapAnim", sgg::AnimationData *, sgg::AnimationData *>
    g_getNameSwapByAnim;
FunctionHook<"AgonAnimationManagerReset", void, void *> g_animationManagerReset;

bool g_installed = false;

void ApplyPlayerContextFromThing(sgg::Thing *thing) {
    if (thing == nullptr || !thing->IsPlayerUnit()) {
        return;
    }
    auto *player = static_cast<sgg::PlayerUnit *>(thing)->GetPlayer();
    if (player == nullptr) {
        return;
    }
    const uint64_t index = player->GetIndex();
    if (index < MAX_LOCAL_PLAYERS) {
        g_lastKnownPlayerIndex = static_cast<size_t>(index);
    }
}

bool GetPlayerSwap(sgg::HashGuid fromAnimation, sgg::HashGuid &outToAnimation) {
    if (g_lastKnownPlayerIndex >= g_playerSwaps.size()) {
        return false;
    }
    return g_playerSwaps[g_lastKnownPlayerIndex].Get(fromAnimation, outToAnimation);
}

uintptr_t Symbol(IModApi::GetSymbolAddress_t getSymbolAddress, const char *name) {
    if (getSymbolAddress == nullptr) {
        return 0;
    }
    return static_cast<uintptr_t>(getSymbolAddress(name));
}

template <typename InstallFn>
void InstallOrLog(bool &ok, uintptr_t address, const char *label, InstallFn install) {
    if (address == 0) {
        ok = false;
        std::string msg = std::string("animation swaps: missing symbol ") + label;
        AgonLog(msg.c_str());
        return;
    }
    install(reinterpret_cast<void *>(address));
}

}

namespace Agon {

bool SetAnimationSwap(size_t playerIndex, const char *fromAnimation, const char *toAnimation) {
    if (playerIndex >= MAX_LOCAL_PLAYERS || fromAnimation == nullptr || toAnimation == nullptr) {
        return false;
    }

    const auto fromHash = sgg::HashGuid::StringIntern(fromAnimation, 0);
    const auto toHash = sgg::HashGuid::StringIntern(toAnimation, 0);
    if (fromHash == 0 || toHash == 0) {
        return false;
    }

    g_playerSwaps[playerIndex].Set(sgg::HashGuid(static_cast<uint32_t>(fromHash)),
                                   sgg::HashGuid(static_cast<uint32_t>(toHash)));
    return true;
}

bool RemoveAnimationSwap(size_t playerIndex, const char *fromAnimation) {
    if (playerIndex >= MAX_LOCAL_PLAYERS || fromAnimation == nullptr) {
        return false;
    }

    const auto fromHash = sgg::HashGuid::StringIntern(fromAnimation, 0);
    if (fromHash == 0) {
        return false;
    }

    g_playerSwaps[playerIndex].Remove(sgg::HashGuid(static_cast<uint32_t>(fromHash)));
    return true;
}

void InstallAnimationSwapHooks(IModApi::GetSymbolAddress_t getSymbolAddress) {
    if (g_installed) {
        return;
    }
    g_installed = true;

    bool ok = true;

    InstallOrLog(ok,
                 Symbol(getSymbolAddress,
                        "?SetAnimation@Thing@sgg@@QEAAPEAVAnimation@2@UHashGuid@2@_N11U42@@Z"),
                 "sgg::Thing::SetAnimation", [](void *address) {
                     g_thingSetAnimation.Install(address, HOOK_PATCH_SIZE);
                     g_thingSetAnimation.onPreFunction =
                         [](sgg::Thing *&self, sgg::HashGuid &, bool &, bool &, bool &,
                            sgg::HashGuid &) { ApplyPlayerContextFromThing(self); };
                 });

    InstallOrLog(ok, Symbol(getSymbolAddress, "sgg::Unit::PlayMoveAnimation"),
                 "sgg::Unit::PlayMoveAnimation", [](void *address) {
                     g_unitPlayMoveAnimation.Install(address, HOOK_PATCH_SIZE);
                     g_unitPlayMoveAnimation.onPreFunction =
                         [](sgg::Unit *&self, bool &) { ApplyPlayerContextFromThing(self); };
                 });

    InstallOrLog(ok, Symbol(getSymbolAddress, "sgg::Unit::IsPlayingMoveAnimation"),
                 "sgg::Unit::IsPlayingMoveAnimation", [](void *address) {
                     g_unitIsPlayingMoveAnimation.Install(address, HOOK_PATCH_SIZE);
                     g_unitIsPlayingMoveAnimation.onPreFunction =
                         [](sgg::Unit *&self) { ApplyPlayerContextFromThing(self); };
                 });

    InstallOrLog(ok,
                 Symbol(getSymbolAddress,
                        "?GetNameSwap@AnimationManager@sgg@@SA?AUHashGuid@2@U32@@Z"),
                 "sgg::AnimationManager::GetNameSwap(HashGuid)", [](void *address) {
                     g_getNameSwapByHash.Install(address, HOOK_PATCH_SIZE);
                     g_getNameSwapByHash.onPreFunction =
                         [](sgg::HashGuid *&result, sgg::HashGuid &name) {
                             g_lastLookupName = name;
                             g_lastLookupResult = result;
                         };
                     g_getNameSwapByHash.onPostFunction = [](sgg::HashGuid *ret) {
                         sgg::HashGuid swapped{0};
                         if (g_lastLookupResult != nullptr &&
                             GetPlayerSwap(g_lastLookupName, swapped)) {
                             *g_lastLookupResult = swapped;
                             return g_lastLookupResult;
                         }
                         return ret;
                     };
                 });

    InstallOrLog(ok,
                 Symbol(getSymbolAddress,
                        "?GetNameSwap@AnimationManager@sgg@@SAPEAVAnimationData@2@PEAV32@@Z"),
                 "sgg::AnimationManager::GetNameSwap(AnimationData)", [](void *address) {
                     g_getNameSwapByAnim.Install(address, HOOK_PATCH_SIZE);
                     g_getNameSwapByAnim.onPreFunction = [](sgg::AnimationData *&from) {
                         if (from != nullptr) {
                             g_lastLookupName = from->GetName();
                         } else {
                             g_lastLookupName = sgg::HashGuid{0};
                         }
                     };
                     g_getNameSwapByAnim.onPostFunction = [](sgg::AnimationData *ret) {
                         sgg::HashGuid swapped{0};
                         if (GetPlayerSwap(g_lastLookupName, swapped)) {
                             auto *data = sgg::GameDataManager::GetAnimationData(swapped);
                             if (data != nullptr) {
                                 return data;
                             }
                         }
                         return ret;
                     };
                 });

    InstallOrLog(ok, Symbol(getSymbolAddress, "sgg::AnimationManager::Reset"),
                 "sgg::AnimationManager::Reset", [](void *address) {
                     g_animationManagerReset.Install(address, HOOK_PATCH_SIZE);
                     g_animationManagerReset.onPreFunction = [](void *&) {
                         for (auto &swaps : g_playerSwaps) {
                             swaps.Reset();
                         }
                     };
                 });

    AgonLog(ok ? "animation swaps: per-player hooks installed"
               : "animation swaps: one or more hooks missing; per-player swaps partial");
}

}
