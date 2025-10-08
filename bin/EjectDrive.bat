@echo off
setlocal EnableExtensions
:: ----------  CONFIG  (your originals) ----------
set "PowerShellExe=powershell"
set "nap=timeout /t"
set "removedrive=rd.exe"
:: -----------------------------------------------

:: ----------  get drive letter and call elevated  ----------
set "drivepath=%~d1"
set "drivepath=%drivepath::=%"
if "%drivepath%"=="" (
    echo No drive letter specified. Aborting.
    exit /b 1
)

:init
setlocal DisableDelayedExpansion
set "batchPath=%~0"
for %%k in (%0) do set batchName=%%~nk
set "vbsGetPrivileges=%tmp%\OEgetPriv_%batchName%.vbs"

:checkPrivileges
NET FILE 1>NUL 2>NUL
if '%errorlevel%'=='0' (goto gotPrivileges) else (goto getPrivileges)

:getPrivileges
if '%1'=='ELEV' (shift /1 & goto gotPrivileges)
(
  echo Set UAC = CreateObject^("Shell.Application"^)
  echo args = "ELEV "
  echo For Each strArg in WScript.Arguments
  echo   args = args ^& strArg ^& " "
  echo Next
  echo UAC.ShellExecute "%batchPath%", args, "", "runas", 1
) > "%vbsGetPrivileges%"
"%SystemRoot%\System32\WScript.exe" "%vbsGetPrivileges%" %*
exit /b

:gotPrivileges
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"
if '%1'=='ELEV' (del "%vbsGetPrivileges%" 1>nul 2>nul & shift /1)

goto usbhddssd

:continue
set "disksis=OTHER"
setlocal EnableDelayedExpansion

:: --- Normalize values ---
set "BusType=%BusType:"=%"
set "MediaType=%MediaType:"=%"

:: --- Detect based on bus type ---
if /i "%BusType%"=="USB" (
    if /i "%MediaType%"=="HDD" (
        endlocal & set "disksis=HDD"
    ) else if /i "%MediaType%"=="SSD" (
        endlocal & set "disksis=SSD"
    ) else if /i "%MediaType%"=="SCM" (
        endlocal & set "disksis=SSD"
    ) else if /i "%MediaType%"=="External" (
        endlocal & set "disksis=HDD_OR_SSD"
    ) else if /i "%MediaType%"=="Virtual" (
        echo NOTE: Virtual drive detected. Skipping eject.
        endlocal & set "disksis=OTHER"
    ) else if /i "%MediaType%"=="Unspecified" (
        set /a "SizeGB=%DiskSize% / 1000000000"
        if !SizeGB! GTR 128 (
            echo WARNING: MediaType is unknown. Assuming external HDD/SSD based on size.
            endlocal & set "disksis=HDD_OR_SSD"
        ) else if !SizeGB! GTR 32 (
            echo WARNING: MediaType is unknown. Possibly a large flash drive.
            endlocal & set "disksis=OTHER"
        ) else (
            echo WARNING: MediaType is unknown. Assuming Flash Drive based on size.
            endlocal & set "disksis=OTHER"
        )
    ) else (
        echo WARNING: Unrecognized MediaType "%MediaType%". Defaulting to OTHER.
        endlocal & set "disksis=OTHER"
    )
) else if /i "%BusType%"=="Thunderbolt" (
    echo NOTE: Thunderbolt detected – treating as external storage.
    endlocal & set "disksis=HDD_OR_SSD"
) else (
    endlocal & set "disksis=OTHER"
)

:: ----------  now we ARE admin – do the eject ----------
echo.
echo ============================================
echo   Safe Eject External HDD/SSD Utility
echo ============================================
echo Drive selected: %drivepath%
echo.
call :ejectdisk
exit /b

:ejectdisk
set tempfile="%tmp%\tmp_disk.dsk"
cd /d "%SystemRoot%\system32"
echo select volume %drivepath% >"%tempfile%"
echo offline disk >>"%tempfile%"
echo online disk >>"%tempfile%"
echo exit >> "%diskpart%"
diskpart /s "%tempfile%" | findstr /C:"not valid"
tasklist /fi "imagename eq dism.exe" | find /i "dism.exe" >nul 2>&1 && (
    taskkill /f /im diskpart.exe
)
del "%tempfile%" /F /Q >nul

"%removedrive%" %drivepath% -e -f -i -L 1>NUL 2>NUL
if errorlevel 1 (
goto ejectdisk
)
goto :eof

:usbhddssd
set "diskinfo_path=%tmp%\diskinfo"
set "driveletter=%drivepath%"

call "%SystemRoot%\system32\ps.cmd" "%drivepath%" "%diskinfo_path%"

if not exist "%diskinfo_path%" (
    goto :usbhddssd_end
)

for /f "tokens=1,2,3 delims=," %%A in ('type "%diskinfo_path%"') do (
    set "MediaType=%%A"
    set "BusType=%%B"
    set "DiskSize=%%C"
)
del "%diskinfo_path%" /f /q >nul

:usbhddssd_end
goto :continue
