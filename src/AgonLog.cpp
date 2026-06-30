#include "pch.h"

#include "AgonLog.h"

#include <fstream>
#include <iostream>

namespace {

std::string AgonModuleDir() {
    HMODULE self = nullptr;
    GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                           GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                       reinterpret_cast<LPCSTR>(&AgonModuleDir), &self);
    char path[MAX_PATH]{};
    GetModuleFileNameA(self, path, MAX_PATH);
    std::string p{path};
    const auto slash = p.find_last_of("\\/");
    return slash == std::string::npos ? std::string{"."} : p.substr(0, slash);
}

}

void AgonLog(const char *message) {
    std::cout << "[AGON] " << message << std::endl;
    OutputDebugStringA((std::string{"[AGON] "} + message + "\n").c_str());

    static const std::string logPath = AgonModuleDir() + "\\agon_native.log";
    std::ofstream out(logPath, std::ios::app);
    if (out)
        out << "[AGON] " << message << "\n";
}
