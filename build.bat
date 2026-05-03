@echo off
setlocal enabledelayedexpansion
set "REPO_DIR=%~dp0"

echo.
echo  ========================================
echo   KenshiMP / Kenshi-Online Build Script
echo  ========================================
echo.

:: Check Kenshi install directory. Order:
::   1. First argument: build.bat "D:\SteamLibrary\steamapps\common\Kenshi"
::   2. KENSHI_DIR environment variable
::   3. Common Steam install locations on local drives
if /I "%~1"=="/?" goto :usage
if /I "%~1"=="-h" goto :usage
if /I "%~1"=="--help" goto :usage

set "ENV_KENSHI_DIR=%KENSHI_DIR%"
set "KENSHI_DIR="
if not "%~1"=="" (
    call :use_kenshi_dir "%~1"
) else if defined ENV_KENSHI_DIR (
    call :use_kenshi_dir "%ENV_KENSHI_DIR%"
) else (
    call :detect_kenshi_dir
)

if not defined KENSHI_DIR goto :kenshi_missing
if exist "%KENSHI_DIR%\kenshi_x64.exe" goto :kenshi_ok
goto :kenshi_missing

:kenshi_ok
echo [OK] Kenshi directory: %KENSHI_DIR%

:: Check prerequisites
where cmake >nul 2>&1
if errorlevel 1 (
    echo [ERROR] CMake not found in PATH.
    echo         Install CMake 3.20+ from https://cmake.org/download/
    echo         Or install via: winget install Kitware.CMake
    goto :fail
)

:: Detect Visual Studio
set "VS_GEN="
if exist "%ProgramFiles%\Microsoft Visual Studio\2022" (
    set "VS_GEN=Visual Studio 17 2022"
    echo [OK] Found Visual Studio 2022
) else if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2019" (
    set "VS_GEN=Visual Studio 16 2019"
    echo [OK] Found Visual Studio 2019
) else (
    echo [ERROR] Visual Studio 2019 or 2022 not found.
    echo         Install Visual Studio with "Desktop development with C++" workload.
    goto :fail
)

:: Check submodules
if not exist "lib\enet\CMakeLists.txt" (
    echo [WARN] Submodules not initialized. Running git submodule update...
    git submodule update --init --recursive
    if errorlevel 1 (
        echo [ERROR] Failed to initialize submodules.
        echo         Make sure git is installed and you cloned with: git clone --recursive
        goto :fail
    )
)

:: Configure
echo.
echo [1/3] Configuring CMake (x64 Release)...
if not exist "build" mkdir build

if exist "build\CMakeCache.txt" (
    set "SOURCE_DIR=%CD:\=/%"
    findstr /C:"CMAKE_HOME_DIRECTORY:INTERNAL=!SOURCE_DIR!" "build\CMakeCache.txt" >nul 2>&1
    if errorlevel 1 (
        echo [WARN] Existing CMake cache is for another source directory. Regenerating it...
        del /F /Q "build\CMakeCache.txt" >nul 2>&1
        if exist "build\CMakeFiles" rmdir /S /Q "build\CMakeFiles"
    )
)

cmake -G "%VS_GEN%" -A x64 -S . -B build -DKENSHI_DIR:PATH="%KENSHI_DIR%"
if errorlevel 1 (
    echo [ERROR] CMake configure failed.
    goto :fail
)

:: Build
echo.
echo [2/3] Building all targets (Release)...
cmake --build build --config Release -- /m:1
if errorlevel 1 (
    echo [ERROR] Build failed.
    goto :fail
)

:: Install the gameplay mod used by shared-save character templates.
echo.
echo [DEPLOY] Installing kenshi-online.mod...
call :install_mod_assets
if errorlevel 1 (
    echo [WARN] kenshi-online.mod was not installed. Shared-save character sync may stall.
)

:: Run tests
echo.
echo [3/3] Running unit tests...
build\bin\Release\KenshiMP.UnitTest.exe
if errorlevel 1 (
    echo [WARN] Some unit tests failed.
) else (
    echo [OK] All tests passed.
)

echo.
echo  ========================================
echo   BUILD SUCCESSFUL
echo  ========================================
echo.
echo  Output binaries in: build\bin\Release\
echo.
echo  Key files:
echo    KenshiMP.Core.dll      - Client plugin (auto-deployed to Kenshi dir)
echo    KenshiMP.Server.exe    - Dedicated server (auto-deployed to Kenshi dir)
echo    KenshiMP.Injector.exe  - Launcher / installer
echo.
echo  To open in Visual Studio:
echo    build\KenshiMP.sln
echo.
goto :end

:usage
echo Usage:
echo   build.bat
echo   build.bat "C:\Program Files (x86)\Steam\steamapps\common\Kenshi"
echo.
echo Optional:
echo   set KENSHI_DIR=C:\Games\SteamLibrary\steamapps\common\Kenshi
echo   build.bat
echo.
exit /b 0

:kenshi_missing
echo [ERROR] Kenshi install not found.
echo.
echo         I looked for kenshi_x64.exe in the path you provided, the KENSHI_DIR
echo         environment variable, and common Steam library folders.
echo.
echo         Run this with your Kenshi install folder:
echo           build.bat "C:\Program Files (x86)\Steam\steamapps\common\Kenshi"
echo.
echo         Or set it once for this terminal:
echo           set KENSHI_DIR=C:\Games\SteamLibrary\steamapps\common\Kenshi
echo           build.bat
goto :fail

:use_kenshi_dir
for %%I in ("%~1") do set "KENSHI_DIR=%%~fI"
exit /b 0

:try_kenshi_dir
if exist "%~1\kenshi_x64.exe" (
    call :use_kenshi_dir "%~1"
    exit /b 0
)
exit /b 1

:detect_kenshi_dir
call :try_kenshi_dir "%ProgramFiles(x86)%\Steam\steamapps\common\Kenshi"
if defined KENSHI_DIR exit /b 0
call :try_kenshi_dir "%ProgramFiles%\Steam\steamapps\common\Kenshi"
if defined KENSHI_DIR exit /b 0

for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    call :try_kenshi_dir "%%D:\SteamLibrary\steamapps\common\Kenshi"
    if defined KENSHI_DIR exit /b 0
    call :try_kenshi_dir "%%D:\Steam\steamapps\common\Kenshi"
    if defined KENSHI_DIR exit /b 0
)
exit /b 1

:install_mod_assets
set "MOD_SRC=%REPO_DIR%dist\kenshi-online.mod"
set "DATA_DIR=%KENSHI_DIR%\data"
set "MOD_DIR=%KENSHI_DIR%\mods\kenshi-online"
set "MOD_LIST=%DATA_DIR%\__mods.list"

if not exist "%MOD_SRC%" (
    echo [WARN] Missing %MOD_SRC%
    exit /b 1
)

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" >nul 2>&1
if errorlevel 1 exit /b 1

if not exist "%MOD_DIR%" mkdir "%MOD_DIR%" >nul 2>&1
if errorlevel 1 exit /b 1

copy /Y "%MOD_SRC%" "%DATA_DIR%\kenshi-online.mod" >nul
if errorlevel 1 exit /b 1

copy /Y "%MOD_SRC%" "%MOD_DIR%\kenshi-online.mod" >nul
if errorlevel 1 exit /b 1

if not exist "%MOD_LIST%" type nul > "%MOD_LIST%"
findstr /X /C:"kenshi-online" "%MOD_LIST%" >nul 2>&1
if errorlevel 1 echo kenshi-online>> "%MOD_LIST%"

echo [OK] Installed kenshi-online.mod and enabled it in __mods.list
exit /b 0

:fail
echo.
echo  BUILD FAILED - see errors above.
echo.
exit /b 1

:end
endlocal
exit /b 0
