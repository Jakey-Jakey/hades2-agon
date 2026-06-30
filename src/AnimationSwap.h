#pragma once

#include <HadesModApi.h>

namespace Agon {

void InstallAnimationSwapHooks(IModApi::GetSymbolAddress_t getSymbolAddress);
bool SetAnimationSwap(size_t playerIndex, const char *fromAnimation, const char *toAnimation);
bool RemoveAnimationSwap(size_t playerIndex, const char *fromAnimation);

}
