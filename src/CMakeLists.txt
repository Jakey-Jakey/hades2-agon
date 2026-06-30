add_library(AgonGame SHARED)

include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/libs/hades2-mod-extension/core/src/include
    ${CMAKE_SOURCE_DIR}/libs/hades2-mod-extension/core/src
    ${CMAKE_SOURCE_DIR}/libs/hades2-mod-extension/core/src/hooks
    ${CMAKE_SOURCE_DIR}/libs/hades2-mod-extension/libs/lua-5.2.2/src
    ${CMAKE_SOURCE_DIR}/libs/hades2-engine-interface/src
)

file(GLOB_RECURSE MOD_FILES ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp ${CMAKE_CURRENT_SOURCE_DIR}/*.h)

target_sources(AgonGame PUBLIC ${MOD_FILES})

target_link_libraries(AgonGame PRIVATE liblua Hades2EngineInterface dbghelp)
target_precompile_headers(AgonGame PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/pch.h)
