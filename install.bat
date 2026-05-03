@echo off
setlocal

:: KenshiMP Install - Copies built files and configures Kenshi to load the Ogre plugin.
:: Run this after building (cmake --build build --config Release).

if not "%~1"=="" (
    set "KENSHI_DIR=%~1"
) else if defined KENSHI_DIR (
    set "KENSHI_DIR=%KENSHI_DIR%"
) else (
    set "KENSHI_DIR=%~dp0.."
)
for %%I in ("%KENSHI_DIR%") do set "KENSHI_DIR=%%~fI"

echo ============================================
echo  KenshiMP Install
echo ============================================
echo.

if not exist "%KENSHI_DIR%\kenshi_x64.exe" (
    echo [!] Kenshi not found at: %KENSHI_DIR%
    call :prompt_kenshi_dir
)

if not exist "%KENSHI_DIR%\kenshi_x64.exe" (
    echo [!] Kenshi install not found.
    echo     Run install.bat again and paste the folder when prompted.
    goto :done
)

echo [OK] Kenshi directory: %KENSHI_DIR%

set "BUILD_DLL=%~dp0build\bin\Release\KenshiMP.Core.dll"
set "BUILD_SERVER=%~dp0build\bin\Release\KenshiMP.Server.exe"
set "MOD_SRC=%~dp0dist\kenshi-online.mod"
set PLUGINS_CFG=%KENSHI_DIR%\Plugins_x64.cfg
set MAIN_MENU_LAYOUT=%KENSHI_DIR%\data\gui\layout\Kenshi_MainMenu.layout
set MP_PANEL_LAYOUT=%KENSHI_DIR%\data\gui\layout\Kenshi_MultiplayerPanel.layout
set MOD_LIST=%KENSHI_DIR%\data\__mods.list

:: 1. Copy DLL to Kenshi root
if exist "%BUILD_DLL%" (
    copy /Y "%BUILD_DLL%" "%KENSHI_DIR%\KenshiMP.Core.dll" >nul 2>&1
    if errorlevel 1 (
        echo [!] Failed to copy DLL - is Kenshi running? Close it first.
    ) else (
        echo [OK] Copied KenshiMP.Core.dll
    )
) else (
    echo [!] DLL not found. Build first: cmake --build build --config Release
)

:: 2. Copy Server exe to Kenshi root
if exist "%BUILD_SERVER%" (
    copy /Y "%BUILD_SERVER%" "%KENSHI_DIR%\KenshiMP.Server.exe" >nul 2>&1
    if errorlevel 1 (
        echo [!] Failed to copy Server exe - is it running?
    ) else (
        echo [OK] Copied KenshiMP.Server.exe
    )
) else (
    echo [--] Server exe not built yet (optional)
)

:: 3. Ensure Plugin=KenshiMP.Core is in Plugins_x64.cfg
findstr /C:"Plugin=KenshiMP.Core" "%PLUGINS_CFG%" >nul 2>&1
if errorlevel 1 (
    echo Plugin=KenshiMP.Core>> "%PLUGINS_CFG%"
    echo [OK] Added Plugin=KenshiMP.Core to Plugins_x64.cfg
) else (
    echo [OK] Plugins_x64.cfg already has KenshiMP.Core
)

:: 4. Check MULTIPLAYER button in main menu layout
findstr /C:"MULTIPLAYER" "%MAIN_MENU_LAYOUT%" >nul 2>&1
if errorlevel 1 (
    echo [!] MULTIPLAYER button not in Kenshi_MainMenu.layout - adding it...
    echo     NOTE: Auto-patching the layout is fragile. Check manually if it breaks.
) else (
    echo [OK] MULTIPLAYER button present in main menu
)

:: 5. Check multiplayer panel layout
if exist "%MP_PANEL_LAYOUT%" (
    echo [OK] Kenshi_MultiplayerPanel.layout exists
) else (
    echo [!] Kenshi_MultiplayerPanel.layout is missing!
    echo     It should be at: data\gui\layout\Kenshi_MultiplayerPanel.layout
)

:: 6. Install and enable the gameplay mod used for shared-save multiplayer characters.
if exist "%MOD_SRC%" (
    if not exist "%KENSHI_DIR%\mods\kenshi-online" mkdir "%KENSHI_DIR%\mods\kenshi-online" >nul 2>&1
    copy /Y "%MOD_SRC%" "%KENSHI_DIR%\data\kenshi-online.mod" >nul 2>&1
    copy /Y "%MOD_SRC%" "%KENSHI_DIR%\mods\kenshi-online\kenshi-online.mod" >nul 2>&1

    if not exist "%MOD_LIST%" type nul > "%MOD_LIST%"
    findstr /X /C:"kenshi-online" "%MOD_LIST%" >nul 2>&1
    if errorlevel 1 echo kenshi-online>> "%MOD_LIST%"

    echo [OK] Installed kenshi-online.mod and enabled it in __mods.list
) else (
    echo [!] kenshi-online.mod not found at: %MOD_SRC%
)

echo.
echo ============================================
echo  Done. Launch Kenshi to play!
echo ============================================
:done
pause
exit /b 0

:prompt_kenshi_dir
echo.
echo [INPUT] Paste your Kenshi install folder.
echo         Example: D:\SteamLibrary\steamapps\common\Kenshi
set "USER_KENSHI_DIR="
set /P "USER_KENSHI_DIR=Kenshi folder: "
if not defined USER_KENSHI_DIR (
    set "KENSHI_DIR="
    exit /b 1
)
set "USER_KENSHI_DIR=%USER_KENSHI_DIR:"=%"
for %%I in ("%USER_KENSHI_DIR%") do set "KENSHI_DIR=%%~fI"
if exist "%KENSHI_DIR%\kenshi_x64.exe" exit /b 0
echo [WARN] That folder does not contain kenshi_x64.exe.
set "KENSHI_DIR="
exit /b 1
