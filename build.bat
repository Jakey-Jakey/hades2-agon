@echo off
setlocal enableextensions
cd /d "%~dp0"

echo ============================================
echo   AGON - build from source
echo ============================================
echo.

where git >nul 2>nul
if errorlevel 1 (
  echo [ERROR] git not found on PATH.
  echo         Install Git for Windows from https://git-scm.com/download/win
  goto fail
)

where cmake >nul 2>nul
if errorlevel 1 (
  echo [ERROR] cmake not found on PATH.
  echo         Install CMake from https://cmake.org/download/ and Visual Studio
  echo         with the "Desktop development with C++" workload.
  goto fail
)

rem First run: create the optional deploy config.
if not exist "env.cmake" (
  > "env.cmake" echo # Optional local deploy config. Uncomment and edit to copy builds into r2modman.
  >> "env.cmake" echo # set(AGON_DEPLOY_DIR "C:/Users/YourName/AppData/Roaming/r2modmanPlus-local/HadesII/profiles/Default/ReturnOfModding/plugins"^)
  echo [info] Created env.cmake. To auto-copy the build into your game install,
  echo        open env.cmake and paste your plugins path. This is optional -
  echo        building still produces the mod folder under bin\. Continuing...
  echo.
)

echo [1/4] Fetching submodules...
rem Avoid --recursive; AGON only needs these submodules plus mod-extension's Lua.
git submodule update --init libs/hades2-engine-interface libs/hades2-mod-extension
if errorlevel 1 goto fail
git -C libs/hades2-mod-extension submodule update --init libs/lua-5.2.2
if errorlevel 1 goto fail

echo.
echo [2/4] Configuring...
cmake -B build
if errorlevel 1 goto fail

echo.
echo [3/4] Building Release...
cmake --build build --config Release
if errorlevel 1 goto fail

echo.
echo [4/4] Assembling mod folder...
cmake --install build --config Release
if errorlevel 1 goto fail

echo.
echo ============================================
echo   DONE
echo   DLL:        build\src\Release\AgonGame.dll
echo   Mod folder: bin\Jakey-Jakey-AGON\
echo   If you set AGON_DEPLOY_DIR in env.cmake, it was copied there too.
echo ============================================
echo.
pause
exit /b 0

:fail
echo.
echo [BUILD FAILED] See the error above.
echo Common causes: missing "Desktop development with C++" in Visual Studio,
echo or a CMake/toolchain version mismatch.
echo.
pause
exit /b 1
