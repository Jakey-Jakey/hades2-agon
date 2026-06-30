#pragma once

#include <hades2/Player.h>

namespace sgg {
class InputHandler;
}

constexpr size_t AGON_MAX_PLAYERS = 2;

class PlayerManagerExtension {
  public:
    PlayerManagerExtension() = default;
    ~PlayerManagerExtension() = default;

    bool HasPlayer(size_t index);

    sgg::Player *CreatePlayer(size_t index);
    sgg::Player *GetPlayer(size_t index) const noexcept;

    size_t GetPlayersCount() const noexcept;

    void SetCurrentMainPlayer(size_t index);
    void ResetCurrentMainPlayer();

    bool AssignGamepad(size_t playerIndex, uint8_t gamepadId);

    bool AssignControllerIndex(size_t playerIndex, uint8_t controllerIndex);

    size_t GetInputMethodsCount() const noexcept;
    int GetControllerIndexOf(size_t playerIndex);
    int GetGamepadIdOf(size_t playerIndex);
    int GetInputMethodGamepad(size_t methodIndex);

  private:
    sgg::Player *AddPlayer(size_t index);
    void AssignController(sgg::Player *player, uint8_t controller);
    sgg::InputHandler *GetInput(size_t controllerIndex);

    sgg::Player *mainPlayer = nullptr;

    unsigned int swapDepth = 0;
};
