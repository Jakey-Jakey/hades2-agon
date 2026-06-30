#include "pch.h"

#include "PlayerManagerExtension.h"

#include "AgonLog.h"

#include <hades2/InputHandler.h>
#include <hades2/PlayerManager.h>

bool PlayerManagerExtension::HasPlayer(size_t index) {
    auto *instance = sgg::PlayerManager::Instance();
    if (instance->m_palyers.size() <= index)
        return false;

    return instance->m_palyers[index];
}

sgg::Player *PlayerManagerExtension::CreatePlayer(size_t index) {
    auto *instance = sgg::PlayerManager::Instance();

    if (index >= AGON_MAX_PLAYERS)
        return nullptr;

    if (instance->m_palyers.size() <= index)
        return nullptr;

    if (instance->m_palyers[index] != nullptr)
        return nullptr;

    auto *player = AddPlayer(index);
    AssignController(player, 1);

    return player;
}

sgg::Player *PlayerManagerExtension::AddPlayer(size_t index) {
    auto *player =
        static_cast<sgg::Player *>(_aligned_malloc(sizeof(sgg::Player), std::alignment_of<sgg::Player>::value));

    uint8_t controllerIndex = 1;
    sgg::Player::internal_constructor(player, index, &controllerIndex);

    auto *instance = sgg::PlayerManager::Instance();
    instance->m_palyers[index] = player;
    return player;
}

void PlayerManagerExtension::AssignController(sgg::Player *player, uint8_t controller) {
    sgg::PlayerManager::Instance()->AssignController(player, controller);
}

sgg::Player *PlayerManagerExtension::GetPlayer(size_t index) const noexcept {
    return sgg::PlayerManager::Instance()->m_palyers[index];
}

void PlayerManagerExtension::SetCurrentMainPlayer(size_t index) {
    if (swapDepth++ > 0) {
        AgonLog("SetCurrentMainPlayer: nested main-player swap refused — a wrapped "
                "id-less native call ran inside another swap's extent (synchronous "
                "no-yield contract violated); keeping the outer swap");
        return;
    }

    mainPlayer = nullptr;

    auto *instance = sgg::PlayerManager::Instance();
    if (instance->m_palyers.size() <= index)
        return;

    auto *newMainPlayer = GetPlayer(index);
    if (!newMainPlayer)
        return;

    mainPlayer = GetPlayer(0);
    newMainPlayer->SetIndex(0);
    instance->m_palyers[0] = newMainPlayer;
}

void PlayerManagerExtension::ResetCurrentMainPlayer() {
    if (swapDepth == 0)
        return;

    if (--swapDepth > 0)
        return;

    if (!mainPlayer)
        return;

    auto *instance = sgg::PlayerManager::Instance();
    instance->m_palyers[0] = mainPlayer;

    for (size_t index = 0; index < instance->m_palyers.size(); index++) {
        auto *player = GetPlayer(index);
        if (player)
            player->SetIndex(index);
    }

    mainPlayer = nullptr;
}

sgg::InputHandler *PlayerManagerExtension::GetInput(size_t controllerIndex) {
    auto *instance = sgg::PlayerManager::Instance();
    if (instance->m_inputMethods.size() <= controllerIndex)
        return nullptr;

    return instance->m_inputMethods[controllerIndex];
}

bool PlayerManagerExtension::AssignGamepad(size_t playerIndex, uint8_t gamepadId) {
    auto *instance = sgg::PlayerManager::Instance();
    if (instance->m_palyers.size() <= playerIndex)
        return false;

    auto *player = instance->m_palyers[playerIndex];
    if (!player)
        return false;

    auto *input = GetInput(player->GetControllerIndex());
    if (!input)
        return false;

    input->SetGamepadId(gamepadId);
    return true;
}

bool PlayerManagerExtension::AssignControllerIndex(size_t playerIndex, uint8_t controllerIndex) {
    auto *instance = sgg::PlayerManager::Instance();
    if (instance->m_palyers.size() <= playerIndex)
        return false;

    auto *player = instance->m_palyers[playerIndex];
    if (!player)
        return false;

    if (!GetInput(controllerIndex))
        return false;

    AssignController(player, controllerIndex);
    return player->GetControllerIndex() == controllerIndex;
}

size_t PlayerManagerExtension::GetInputMethodsCount() const noexcept {
    return sgg::PlayerManager::Instance()->m_inputMethods.size();
}

int PlayerManagerExtension::GetControllerIndexOf(size_t playerIndex) {
    auto *instance = sgg::PlayerManager::Instance();
    if (instance->m_palyers.size() <= playerIndex)
        return -1;

    auto *player = instance->m_palyers[playerIndex];
    if (!player)
        return -1;

    return static_cast<int>(player->GetControllerIndex());
}

int PlayerManagerExtension::GetInputMethodGamepad(size_t methodIndex) {
    auto *input = GetInput(methodIndex);
    if (!input)
        return -1;

    return static_cast<int>(input->GetGamepadId());
}

int PlayerManagerExtension::GetGamepadIdOf(size_t playerIndex) {
    auto *instance = sgg::PlayerManager::Instance();
    if (instance->m_palyers.size() <= playerIndex)
        return -1;

    auto *player = instance->m_palyers[playerIndex];
    if (!player)
        return -1;

    auto *input = GetInput(player->GetControllerIndex());
    if (!input)
        return -1;

    return static_cast<int>(input->GetGamepadId());
}

size_t PlayerManagerExtension::GetPlayersCount() const noexcept {
    size_t size = 0;
    for (auto *player : sgg::PlayerManager::Instance()->m_palyers)
        if (player)
            size++;

    return size;
}
