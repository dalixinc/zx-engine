@echo off
rem ATLANTIS - Windows build script
rem   build.bat           assemble build\atlantis.tap (packed with ZX0 if
rem                       zx0.exe is found, see below; otherwise unpacked)
rem   build.bat run       assemble, then open the tape in Fuse
rem   build.bat run 4x    the same, with Fuse at 4x size (2x, 3x, 4x)
rem   build.bat soak      assemble build\atlantis-soak.sna (the self-test)
rem   build.bat runsoak   assemble the soak, then open it in Fuse
rem   build.bat timing    assemble build\atlantis-timing.sna (timing border)
rem   build.bat runtiming assemble the timing build, then open it in Fuse
rem   build.bat demo      assemble build\diver.tap (Engine Demo 1)
rem   build.bat web       assemble, then copy atlantis.sna and atlantis.tap to
rem                       docs\play\ for the web page (docs\WEB.md); commit, push
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

rem ---- the game tape ----
"%SJASM%" %ASMOPTS% --lst=build\atlantis.lst --sym=build\atlantis.sym --exp=build\atlantis.exp src\atlantis\main.asm
if errorlevel 1 goto failed
if "%ZX0%"=="" goto plaintape
"%ZX0%" -f gfx\loading.scr build\loading.zx0 >nul
if errorlevel 1 goto failed
for %%B in (cold code data) do (
    "%ZX0%" -f build\atlantis-%%B.bin build\atlantis-%%B.zx0 >nul
    if errorlevel 1 goto failed
)
"%SJASM%" %ASMOPTS% src\atlantis\tape.asm
if errorlevel 1 goto failed
echo Built build\atlantis.tap (packed)
goto tapedone
:plaintape
copy /y build\atlantis-plain.tap build\atlantis.tap >nul
if errorlevel 1 goto failed
echo Built build\atlantis.tap (unpacked: no zx0.exe found)
:tapedone
if /i "%1"=="web" (
    copy /y build\atlantis.sna docs\play\atlantis.sna >nul
    if errorlevel 1 goto failed
    copy /y build\atlantis.tap docs\play\atlantis.tap >nul
    if errorlevel 1 goto failed
    echo Copied to docs\play\: commit atlantis.sna and .tap and push to update the site
)
if /i "%1"=="run" start "" "%EMU%" --graphics-filter %SIZE% --machine 48 --auto-load --traps --fastload build\atlantis.tap
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
