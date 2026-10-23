@echo off
rem Double-click to install or repair the Arrakis desktop (with autostart and the guard).
echo Installing the Arrakis desktop...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Autostart -Guard
echo.
echo A log of this run was saved to "%~dp0install-log.txt".
pause
