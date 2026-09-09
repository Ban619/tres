@echo off
setlocal

if not exist "%~dp0tres.exe" (
    echo tres.exe was not found.
    echo Run himo.bat first.
    pause
    exit /b 1
)

rem Keep this launcher CMD open if the program exits, so errors are visible.
rem The actual game is still launched in a separate Command Prompt window.
start "TRES - Tetris" cmd /k ""%~dp0tres.exe""
exit /b 0
