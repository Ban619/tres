@echo off
setlocal

title TRES - Tetris ASM Build

if not exist "%~dp0build" mkdir "%~dp0build"

if not exist "%~dp0tres.asm" (
    echo ERROR: tres.asm was not found.
    pause
    exit /b 1
)

echo.
echo ================================
echo        TRES ASM BUILD
echo ================================
echo.

echo [1/2] Assembling...
nasm -f win64 "%~dp0tres.asm" -o "%~dp0build\tres.obj"
if errorlevel 1 (
    echo.
    echo NASM compilation failed.
    pause
    exit /b 1
)

echo [2/2] Linking with MinGW CRT...
rem Use the normal MinGW CRT startup instead of jumping directly to main.
rem This gives main the standard Windows x64 stack alignment.
gcc -mconsole "%~dp0build\tres.obj" -o "%~dp0tres.exe" -lkernel32 -luser32
if errorlevel 1 (
    echo.
    echo Linking failed.
    pause
    exit /b 1
)

echo.
echo ================================
echo       BUILD SUCCESSFUL
echo ================================
echo.
echo tres.exe is ready.
echo.
pause
exit /b 0
