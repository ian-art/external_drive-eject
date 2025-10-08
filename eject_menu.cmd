@echo off
setlocal DisableDelayedExpansion
set "batchPath=%~0"
for %%k in (%0) do set "batchName=%%~nk"
set "vbsGetPrivileges=%tmp%\OEgetPriv_%batchName%.vbs"

:: ==========================================================
:: Check for admin privileges
:: ==========================================================
NET FILE 1>NUL 2>NUL
if '%errorlevel%'=='0' (goto gotPrivileges)

:: Request elevation
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
if '%1'=='ELEV' (
  del "%vbsGetPrivileges%" 1>nul 2>nul
  shift /1
)

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

:: ==========================================================
:: Define paths
:: ==========================================================
set "filesneeded=%SCRIPT_DIR%bin\"
set "ejdbat=%filesneeded%EjectDrive.bat"
set "ejdvbs=%filesneeded%EjectDrive.vbs"
set "rdexe=%filesneeded%rd.exe"
set "pscmd=%filesneeded%ps.cmd"

:: ==========================================================
:: Copy helper files to System32
:: ==========================================================
echo Copying helper files to System32...
for %%F in ("%ejdbat%" "%ejdvbs%" "%rdexe%" "%pscmd%") do (
    if exist "%%~F" (
        copy /Y "%%~F" "%windir%\System32\" >nul 2>&1 || (
            echo [!] Failed to copy "%%~nxF" to System32
            pause
            exit /b
        )
    ) else (
        echo [!] Missing file: %%~nxF
        pause
        exit /b
    )
)

:: ==========================================================
:: Create context menu for USB drives (ALL USB, filter is done in script)
:: ==========================================================
echo Adding 'Eject Drive' context menu entry...
reg add "HKCR\Drive\shell\EjectDrive" /ve /d "Eject Drive" /f >nul 2>&1
reg add "HKCR\Drive\shell\EjectDrive" /v "Icon" /d "imageres.dll,-5314" /f >nul 2>&1
:: REM  AppliesTo removed – filtering now handled inside EjectDrive.bat
reg add "HKCR\Drive\shell\EjectDrive\command" /ve /d "wscript.exe \"C:\\Windows\\System32\\EjectDrive.vbs\" \"%%1\"" /f >nul 2>&1
reg delete "HKCR\Drive\shell\EjectDrive" /v AppliesTo /f >nul 2>&1
:: ==========================================================
:: Install BurntToast PowerShell module (placed last)
:: ==========================================================
echo Installing BurntToast PowerShell module...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "try {Install-Module -Name BurntToast -Force -Scope AllUsers -ErrorAction Stop; Write-Host '[✓] BurntToast installed successfully.'} catch {Write-Host '[-] BurntToast install failed: ' + $_.Exception.Message}"

echo.
echo [✓] Eject Drive integration installed successfully.
echo        (Entry appears on ALL drives but only works on external USB HDD/SSD)
echo.
pause
exit /b