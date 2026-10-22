@echo off
rem DIVER ENGINE - Windows build script
rem Needs sjasmplus.exe on PATH (or set SJASM below). Optional: Fuse on PATH.
rem   build.bat        assemble build\diver.tap
rem   build.bat run    assemble, then open the .tap in the emulator

setlocal
if "%SJASM%"=="" set SJASM=sjasmplus.exe
if "%EMU%"==""   set EMU=fuse.exe

cd /d "%~dp0"
if not exist build mkdir build

"%SJASM%" --nologo --fullpath=off --lst=build\diver.lst --sym=build\diver.sym src\main.asm
if errorlevel 1 (
    echo.
    echo *** Build FAILED ***
    exit /b 1
)
echo Built build\diver.tap

if /i "%1"=="run" start "" "%EMU%" --machine 48 --auto-load build\diver.tap
endlocal
