#include "pch.h"

#include "AgonSpawn.h"
#include "PlayerManagerExtension.h"

#include <hades2/MapThing.h>
#include <hades2/PlayerUnit.h>
#include <hades2/World.h>

namespace Agon {

namespace {
PlayerManagerExtension &Players() {
    static PlayerManagerExtension instance;
    return instance;
}
}

size_t CreatePlayer() {
    auto &players = Players();

    size_t playerIndex = INVALID_PLAYER_INDEX;
    for (size_t i = 0; i < AGON_MAX_PLAYERS; i++) {
        if (!players.HasPlayer(i))
            playerIndex = i;
    }

    if (playerIndex == INVALID_PLAYER_INDEX)
        return INVALID_PLAYER_INDEX;

    if (!players.CreatePlayer(playerIndex))
        return INVALID_PLAYER_INDEX;

    return playerIndex;
}

size_t CreatePlayerUnit(size_t playerIndex) {
    auto &players = Players();

    auto *basePlayer = players.GetPlayer(0);
    auto *newPlayer = players.GetPlayer(playerIndex);

    if (!basePlayer || !newPlayer)
        return INVALID_UNIT_ID;

    auto *baseUnit = basePlayer->GetUnit();
    auto *currentUnit = newPlayer->GetUnit();

    if (!baseUnit || currentUnit)
        return INVALID_UNIT_ID;

    sgg::MapThing *mapThingBase = baseUnit->GetMapThing();

    auto *mapThing =
        static_cast<sgg::MapThing *>(_aligned_malloc(sizeof(sgg::MapThing), std::alignment_of<sgg::MapThing>::value));
    std::memcpy(mapThing, mapThingBase, sizeof(sgg::MapThing));

    mapThing->GetDef()->SetId(static_cast<uint32_t>(40000 - playerIndex));

    auto *playerUnit =
        reinterpret_cast<sgg::PlayerUnit *>(sgg::World::Instance()->CreateThing(mapThing, true, true));

    if (!playerUnit)
        return INVALID_UNIT_ID;

    playerUnit->SetPlayer(newPlayer);
    newPlayer->SetUnit(playerUnit);

    return playerUnit->GetId();
}

bool RemovePlayerUnit(size_t playerIndex) {
    auto *player = Players().GetPlayer(playerIndex);
    if (!player)
        return false;

    auto *unit = player->GetUnit();
    if (!unit)
        return false;

    unit->Delete();
    player->SetUnit(nullptr);
    return true;
}

bool ClearPlayerUnit(size_t playerIndex) {
    if (!Players().HasPlayer(playerIndex))
        return false;

    auto *player = Players().GetPlayer(playerIndex);
    if (!player)
        return false;

    if (!player->GetUnit())
        return false;

    player->SetUnit(nullptr);
    return true;
}

bool SetPlayerGamepad(size_t playerIndex, unsigned char gamepadId) {
    return Players().AssignGamepad(playerIndex, static_cast<uint8_t>(gamepadId));
}

bool SetPlayerController(size_t playerIndex, unsigned char controllerIndex) {
    return Players().AssignControllerIndex(playerIndex, static_cast<uint8_t>(controllerIndex));
}

size_t GetInputMethodsCount() { return Players().GetInputMethodsCount(); }

int GetPlayerControllerIndex(size_t playerIndex) { return Players().GetControllerIndexOf(playerIndex); }

int GetPlayerGamepad(size_t playerIndex) { return Players().GetGamepadIdOf(playerIndex); }

int GetInputMethodGamepad(size_t methodIndex) { return Players().GetInputMethodGamepad(methodIndex); }

bool HasPlayer(size_t playerIndex) { return Players().HasPlayer(playerIndex); }

size_t GetPlayersCount() { return Players().GetPlayersCount(); }

void SetCurrentMainPlayer(size_t playerIndex) { Players().SetCurrentMainPlayer(playerIndex); }

void ResetCurrentMainPlayer() { Players().ResetCurrentMainPlayer(); }

}
