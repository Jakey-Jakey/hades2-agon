#pragma once

class lua_State;

namespace AgonLua {
void Load(lua_State *L);
}

namespace Agon {
void SanitizeLoadCorruption(void *L, const char *scriptName);
}
