@echo off
rem ATLANTIS - Windows build script
rem Needs sjasmplus.exe on PATH (or set SJASM below). Optional: Fuse on PATH.
rem   build.bat        assemble build\atlantis.tap
rem   build.bat run    assemble, then open the .tap in the emulator
rem   build.bat demo   assemble build\diver.tap (Engine Demo 1, unchanged)

setlocal
if "%SJASM%"=="" set SJASM=sjasmplus.exe
if "%EMU%"==""   set EMU=fuse.exe

cd /d "%~dp0"
if not exist build mkdir build

if /i "%1"=="demo" goto demo

"%SJASM%" --nologo --fullpath=off --lst=build\atlantis.lst --sym=build\atlantis.sym src\atlantis\main.asm
if errorlevel 1 (
    echo.
    echo *** Build FAILED ***
    exit /b 1
)
echo Built build\atlantis.tap

if /i "%1"=="run" start "" "%EMU%" --machine 48 --auto-load build\atlantis.tap
goto done

:demo
"%SJASM%" --nologo --fullpath=off --lst=build\diver.lst --sym=build\diver.sym src\main.asm
if errorlevel 1 (
    echo.
    echo *** Demo build FAILED ***
    exit /b 1
)
echo Built build\diver.tap

:done
endlocal
