@echo off
setlocal

set "ROOT=%~dp0"
set "BUILD_BIN=%ROOT%build\bin\Release"
set "DIST=%ROOT%dist"
set "OUT=%ROOT%packages"

if /I "%~1"=="/?" goto :usage
if /I "%~1"=="-h" goto :usage
if /I "%~1"=="--help" goto :usage

echo.
echo  ========================================
echo   KenshiMP Release Packager
echo  ========================================
echo.

call :require_file "%BUILD_BIN%\KenshiMP.Core.dll" "KenshiMP.Core.dll"
if errorlevel 1 goto :missing_build
call :require_file "%BUILD_BIN%\KenshiMP.Injector.exe" "KenshiMP.Injector.exe"
if errorlevel 1 goto :missing_build
call :require_file "%BUILD_BIN%\KenshiMP.Server.exe" "KenshiMP.Server.exe"
if errorlevel 1 goto :missing_build

call :require_file "%DIST%\install.bat" "dist\install.bat"
if errorlevel 1 goto :missing_dist
call :require_file "%DIST%\uninstall.bat" "dist\uninstall.bat"
if errorlevel 1 goto :missing_dist
call :require_file "%DIST%\JOINING.md" "dist\JOINING.md"
if errorlevel 1 goto :missing_dist
call :require_file "%DIST%\PLAYER_README.md" "dist\PLAYER_README.md"
if errorlevel 1 goto :missing_dist
call :require_file "%DIST%\SERVER_README.md" "dist\SERVER_README.md"
if errorlevel 1 goto :missing_dist
call :require_file "%DIST%\HOST_README.md" "dist\HOST_README.md"
if errorlevel 1 goto :missing_dist
call :require_file "%DIST%\Kenshi_MainMenu.layout" "dist\Kenshi_MainMenu.layout"
if errorlevel 1 goto :missing_dist
call :require_file "%DIST%\Kenshi_MultiplayerPanel.layout" "dist\Kenshi_MultiplayerPanel.layout"
if errorlevel 1 goto :missing_dist
call :require_file "%DIST%\Kenshi_MultiplayerHUD.layout" "dist\Kenshi_MultiplayerHUD.layout"
if errorlevel 1 goto :missing_dist
call :require_file "%DIST%\kenshi-online.mod" "dist\kenshi-online.mod"
if errorlevel 1 goto :missing_dist
call :require_file "%DIST%\server.json" "dist\server.json"
if errorlevel 1 goto :missing_dist

if exist "%OUT%" rmdir /S /Q "%OUT%"
mkdir "%OUT%" || goto :fail

set "PLAYER=%OUT%\KenshiMP-Player"
set "SERVER=%OUT%\KenshiMP-Server"
set "HOST=%OUT%\KenshiMP-Host"

mkdir "%PLAYER%" "%SERVER%" "%HOST%" || goto :fail

echo [1/4] Creating player package...
call :copy_client_files "%PLAYER%" || goto :fail
copy /Y "%DIST%\PLAYER_README.md" "%PLAYER%\README.md" >nul || goto :fail

echo [2/4] Creating server package...
copy /Y "%BUILD_BIN%\KenshiMP.Server.exe" "%SERVER%\KenshiMP.Server.exe" >nul || goto :fail
copy /Y "%DIST%\server.json" "%SERVER%\server.json" >nul || goto :fail
copy /Y "%DIST%\SERVER_README.md" "%SERVER%\README.md" >nul || goto :fail

echo [3/4] Creating host package...
call :copy_client_files "%HOST%" || goto :fail
copy /Y "%BUILD_BIN%\KenshiMP.Server.exe" "%HOST%\KenshiMP.Server.exe" >nul || goto :fail
copy /Y "%DIST%\server.json" "%HOST%\server.json" >nul || goto :fail
copy /Y "%DIST%\HOST_README.md" "%HOST%\README.md" >nul || goto :fail

echo [4/4] Creating zip files...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Compress-Archive -Path '%PLAYER%\*' -DestinationPath '%OUT%\KenshiMP-Player.zip' -Force; " ^
  "Compress-Archive -Path '%SERVER%\*' -DestinationPath '%OUT%\KenshiMP-Server.zip' -Force; " ^
  "Compress-Archive -Path '%HOST%\*' -DestinationPath '%OUT%\KenshiMP-Host.zip' -Force"
if errorlevel 1 goto :fail

echo.
echo  ========================================
echo   PACKAGES READY
echo  ========================================
echo.
echo   %OUT%\KenshiMP-Player.zip
echo   %OUT%\KenshiMP-Server.zip
echo   %OUT%\KenshiMP-Host.zip
echo.
echo   Player = join games only
echo   Server = dedicated server only
echo   Host   = player files plus server exe for HOST GAME
echo.
goto :end

:copy_client_files
set "DEST=%~1"
copy /Y "%BUILD_BIN%\KenshiMP.Core.dll" "%DEST%\KenshiMP.Core.dll" >nul || exit /b 1
copy /Y "%BUILD_BIN%\KenshiMP.Injector.exe" "%DEST%\KenshiMP.Injector.exe" >nul || exit /b 1
copy /Y "%DIST%\install.bat" "%DEST%\install.bat" >nul || exit /b 1
copy /Y "%DIST%\uninstall.bat" "%DEST%\uninstall.bat" >nul || exit /b 1
copy /Y "%DIST%\JOINING.md" "%DEST%\JOINING.md" >nul || exit /b 1
copy /Y "%DIST%\Kenshi_MainMenu.layout" "%DEST%\Kenshi_MainMenu.layout" >nul || exit /b 1
copy /Y "%DIST%\Kenshi_MultiplayerPanel.layout" "%DEST%\Kenshi_MultiplayerPanel.layout" >nul || exit /b 1
copy /Y "%DIST%\Kenshi_MultiplayerHUD.layout" "%DEST%\Kenshi_MultiplayerHUD.layout" >nul || exit /b 1
copy /Y "%DIST%\kenshi-online.mod" "%DEST%\kenshi-online.mod" >nul || exit /b 1
exit /b 0

:require_file
if not exist "%~1" (
    echo [ERROR] Missing %~2
    exit /b 1
)
exit /b 0

:missing_build
echo.
echo  Build the Release binaries first:
echo    build.bat
echo.
goto :fail

:missing_dist
echo.
echo  A tracked dist asset is missing. Restore it from Git before packaging.
echo.
goto :fail

:usage
echo Usage:
echo   package-release.bat
echo.
echo Creates:
echo   packages\KenshiMP-Player.zip
echo   packages\KenshiMP-Server.zip
echo   packages\KenshiMP-Host.zip
echo.
echo Run build.bat first so build\bin\Release contains the compiled files.
exit /b 0

:fail
echo.
echo  PACKAGING FAILED
echo.
exit /b 1

:end
endlocal
exit /b 0
