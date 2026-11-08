@echo off
rem ATLANTIS and TRIGON - Windows build script
rem   build.bat           assemble both games: build\atlantis.tap and .sna,
rem                       build\trigon.tap and .sna (packed with ZX0 if
rem                       zx0.exe is found, see below; otherwise unpacked)
rem   build.bat run       build both, then open Atlantis's tape in Fuse
rem   build.bat run 4x    the same, with Fuse at 4x size (2x, 3x, 4x)
rem   build.bat runtrigon build both, then open Trigon's tape in Fuse
rem   build.bat soak      assemble build\atlantis-soak.sna (the self-test)
rem   build.bat runsoak   assemble the soak, then open it in Fuse
rem   build.bat trigonsoak    build\trigon-soak.sna; runtrigonsoak opens it
rem   build.bat trigonseas    build\trigon-sea-black.sna and -dark.sna
rem   build.bat timing    assemble build\atlantis-timing.sna (timing border)
rem   build.bat runtiming assemble the timing build, then open it in Fuse
rem   build.bat demo      assemble build\diver.tap (Engine Demo 1)
rem   build.bat web       build both, then copy each game's .sna and .tap to
rem                       docs\play\ and docs\play\trigon\ for the web pages
rem                       (docs\WEB.md); commit, push
rem
rem Tools: uses windows-tools\fuse\fuse.exe and
rem windows-tools\sjasmplus\sjasmplus.exe if they are there, otherwise
rem whatever is on PATH. Set SJASM or EMU first to override either.
rem The tape is packed with windows-tools\zx0\zx0.exe (or zx0.exe on the
rem PATH, or ZX0), compiled from tools\zx0\. Without it, build\atlantis.tap
rem is the unpacked tape, which loads the same game, only more slowly.

setlocal
cd /d "%~dp0"

if "%SJASM%"=="" if exist "windows-tools\sjasmplus\sjasmplus.exe" set "SJASM=%~dp0windows-tools\sjasmplus\sjasmplus.exe"
if "%SJASM%"=="" for /r "windows-tools" %%F in (sjasmplus.exe) do if exist "%%F" set "SJASM=%%F"
if "%SJASM%"=="" set "SJASM=sjasmplus.exe"
if "%EMU%"==""   if exist "windows-tools\fuse\fuse.exe" set "EMU=%~dp0windows-tools\fuse\fuse.exe"
if "%EMU%"==""   set "EMU=fuse.exe"
if "%ZX0%"==""   if exist "windows-tools\zx0\zx0.exe" set "ZX0=%~dp0windows-tools\zx0\zx0.exe"
if "%ZX0%"==""   for %%Z in (zx0.exe) do if not "%%~$PATH:Z"=="" set "ZX0=%%~$PATH:Z"

if not exist build mkdir build

set "ASMOPTS=--nologo --fullpath=off"

rem Fuse window size: 2x, 3x or 4x, e.g. build.bat run 4x. Default 3x.
if not "%2"=="" set "SIZE=%2"
if "%SIZE%"=="" set "SIZE=3x"

if /i "%1"=="demo"      goto demo
if /i "%1"=="soak"      goto soak
if /i "%1"=="runsoak"   goto soak
if /i "%1"=="timing"    goto timing
if /i "%1"=="runtiming" goto timing
if /i "%1"=="trigonsoak"    goto trigonsoak
if /i "%1"=="runtrigonsoak" goto trigonsoak
if /i "%1"=="trigonseas"    goto trigonseas

rem ---- the game tapes: Atlantis, then Trigon ----
call :tape atlantis src\atlantis\main.asm gfx\loading.scr build\loading.zx0 ""
if errorlevel 1 goto failed
call :tape trigon src\trigon\main.asm gfx\trigon\loading.scr build\trigon-loading.zx0 "-DTRIGON"
if errorlevel 1 goto failed
if /i "%1"=="web" (
    copy /y build\atlantis.sna docs\play\atlantis.sna >nul
    if errorlevel 1 goto failed
    copy /y build\atlantis.tap docs\play\atlantis.tap >nul
    if errorlevel 1 goto failed
    copy /y build\trigon.sna docs\play\trigon\trigon.sna >nul
    if errorlevel 1 goto failed
    copy /y build\trigon.tap docs\play\trigon\trigon.tap >nul
    if errorlevel 1 goto failed
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\webstamp.ps1
    if errorlevel 1 goto failed
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\webstamp.ps1 -Name trigon -Dir docs\play\trigon
    if errorlevel 1 goto failed
    echo Copied to docs\play\ and docs\play\trigon\: commit the .sna, .tap and index.html files and push to update the site
)
if /i "%1"=="run" start "" "%EMU%" --graphics-filter %SIZE% --machine 48 --auto-load --traps --fastload build\atlantis.tap
if /i "%1"=="runtrigon" start "" "%EMU%" --graphics-filter %SIZE% --machine 48 --auto-load --traps --fastload build\trigon.tap
goto done

rem ---- one game's tape: call :tape NAME MAIN.ASM SCREEN.SCR SCREEN.ZX0 "TAPE.ASM FLAGS"
rem main.asm writes build\NAME.sna, the plain tape and the four blocks;
rem ZX0 packs the screen and the blocks (cold, code, data, UDG), and
rem tape.asm puts them on build\NAME.tap behind the unpacker.
:tape
"%SJASM%" %ASMOPTS% --lst=build\%1.lst --sym=build\%1.sym --exp=build\%1.exp %2
if errorlevel 1 exit /b 1
if "%ZX0%"=="" goto tapeplain
"%ZX0%" -f %3 %4 >nul
if errorlevel 1 exit /b 1
for %%B in (cold code data udg) do (
    "%ZX0%" -f build\%1-%%B.bin build\%1-%%B.zx0 >nul
    if errorlevel 1 exit /b 1
)
"%SJASM%" %ASMOPTS% %~5 src\atlantis\tape.asm
if errorlevel 1 exit /b 1
echo Built build\%1.tap (packed) and build\%1.sna
exit /b 0
:tapeplain
copy /y build\%1-plain.tap build\%1.tap >nul
if errorlevel 1 exit /b 1
echo Built build\%1.tap (unpacked: no zx0.exe found) and build\%1.sna
exit /b 0

:trigonsoak
"%SJASM%" %ASMOPTS% -DSOAK --lst=build\trigon-soak.lst src\trigon\main.asm
if errorlevel 1 goto failed
echo Built build\trigon-soak.sna  (green border and OK after about two minutes)
if /i "%1"=="runtrigonsoak" start "" "%EMU%" --graphics-filter %SIZE% --machine 48 build\trigon-soak.sna
goto done

:trigonseas
"%SJASM%" %ASMOPTS% -DSEA_SNA -DCFG_SEA=0 src\trigon\main.asm
if errorlevel 1 goto failed
"%SJASM%" %ASMOPTS% -DSEA_SNA -DCFG_SEA=1 src\trigon\main.asm
if errorlevel 1 goto failed
echo Built build\trigon-sea-black.sna and build\trigon-sea-dark.sna
goto done

:soak
"%SJASM%" %ASMOPTS% -DSOAK --lst=build\atlantis-soak.lst src\atlantis\main.asm
if errorlevel 1 goto failed
echo Built build\atlantis-soak.sna  (green border and OK after about two minutes)
if /i "%1"=="runsoak" start "" "%EMU%" --graphics-filter %SIZE% --machine 48 build\atlantis-soak.sna
goto done

:timing
"%SJASM%" %ASMOPTS% -DTIMING_BARS --lst=build\atlantis-timing.lst src\atlantis\main.asm
if errorlevel 1 goto failed
echo Built build\atlantis-timing.sna
if /i "%1"=="runtiming" start "" "%EMU%" --graphics-filter %SIZE% --machine 48 build\atlantis-timing.sna
goto done

:demo
"%SJASM%" %ASMOPTS% --lst=build\diver.lst --sym=build\diver.sym src\main.asm
if errorlevel 1 goto failed
echo Built build\diver.tap
goto done

:failed
echo.
echo *** Build FAILED ***
endlocal
exit /b 1

:done
endlocal
