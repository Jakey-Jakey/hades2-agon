cmake_minimum_required(VERSION 3.20)

project(AGON VERSION 0.0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(MSVC)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

add_definitions(-DNOMINMAX)
add_definitions(-DEASTL_DEBUG=0)
add_definitions(-DEASTL_CUSTOM_FLOAT_CONSTANTS_REQUIRED)

add_subdirectory(libs/hades2-mod-extension/libs/lua-5.2.2)
add_subdirectory(libs/hades2-engine-interface)

add_subdirectory(src)

set(AGON_MOD_FOLDER "Jakey-Jakey-AGON")
set(AGON_STAGE_PATH ${CMAKE_SOURCE_DIR}/bin/${AGON_MOD_FOLDER})

if(EXISTS ${CMAKE_SOURCE_DIR}/env.cmake)
    include(${CMAKE_SOURCE_DIR}/env.cmake)
endif()

install(TARGETS AgonGame
        RUNTIME DESTINATION ${AGON_STAGE_PATH})

install(DIRECTORY ${CMAKE_SOURCE_DIR}/scripts/
        DESTINATION ${AGON_STAGE_PATH})

if(DEFINED AGON_DEPLOY_DIR)
    install(CODE "file(MAKE_DIRECTORY \"${AGON_DEPLOY_DIR}/${AGON_MOD_FOLDER}\")")
    install(TARGETS AgonGame RUNTIME DESTINATION ${AGON_DEPLOY_DIR}/${AGON_MOD_FOLDER})
    install(DIRECTORY ${CMAKE_SOURCE_DIR}/scripts/
            DESTINATION ${AGON_DEPLOY_DIR}/${AGON_MOD_FOLDER})
endif()

set(AGON_NORMALIZE_SCRIPT ${CMAKE_SOURCE_DIR}/tools/normalize-line-endings.ps1)
if(EXISTS ${AGON_NORMALIZE_SCRIPT})
    install(CODE "execute_process(COMMAND pwsh -NoProfile -ExecutionPolicy Bypass -File \"${AGON_NORMALIZE_SCRIPT}\" -Path \"${AGON_STAGE_PATH}\" COMMAND_ERROR_IS_FATAL ANY)")
    if(DEFINED AGON_DEPLOY_DIR)
        install(CODE "execute_process(COMMAND pwsh -NoProfile -ExecutionPolicy Bypass -File \"${AGON_NORMALIZE_SCRIPT}\" -Path \"${AGON_DEPLOY_DIR}/${AGON_MOD_FOLDER}\" COMMAND_ERROR_IS_FATAL ANY)")
    endif()
endif()
