#pragma once

#include <cstddef>

namespace Agon {

constexpr size_t INVALID_PLAYER_INDEX = static_cast<size_t>(-1);
constexpr size_t INVALID_UNIT_ID = static_cast<size_t>(-1);

size_t CreatePlayer();

size_t CreatePlayerUnit(size_t playerIndex);

bool RemovePlayerUnit(size_t playerIndex);

bool ClearPlayerUnit(size_t playerIndex);

bool SetPlayerGamepad(size_t playerIndex, unsigned char gamepadId);

bool SetPlayerController(size_t playerIndex, unsigned char controllerIndex);

bool HasPlayer(size_t playerIndex);

size_t GetPlayersCount();

void SetCurrentMainPlayer(size_t playerIndex);
void ResetCurrentMainPlayer();

size_t GetInputMethodsCount();
int GetPlayerControllerIndex(size_t playerIndex);
int GetPlayerGamepad(size_t playerIndex);
int GetInputMethodGamepad(size_t methodIndex);

}
