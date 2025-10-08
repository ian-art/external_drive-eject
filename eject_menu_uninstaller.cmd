@echo off
setlocal

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

:: ==========================================================
:: Define paths
:: ==========================================================
set "ejdbat=%windir%\System32\EjectDrive.bat"
set "ejdvbs=%windir%\System32\EjectDrive.vbs"
set "pscmd=%windir%\System32\ps.cmd"

:: --- safer: don’t delete rd.exe unless you *really* want to ---
set "targets=%ejdbat% %ejdvbs% %pscmd%"

echo === Target files ===
for %%T in (%targets%) do echo %%~fT
echo ====================
pause

:: ==========================================================
:: Delete loop
:: ==========================================================
for %%F in (%targets%) do (
    if exist "%%~F" (
        echo Deleting "%%~F" ...
        del /f /q "%%~F"
        if exist "%%~F" (
            echo [!] FAILED to delete %%~nxF - trying to take ownership...
            takeown /f "%%~F" >nul 2>&1
            icacls "%%~F" /grant "%username%:F" >nul 2>&1
            del /f /q "%%~F"
            if exist "%%~F" (
                echo [X] Still failed: %%~nxF
            ) else (
                echo [✓] Deleted after ownership fix: %%~nxF
            )
        ) else (
            echo [✓] Deleted: %%~nxF
        )
    ) else (
        echo [i] Not found: %%~nxF
    )
)

:: Delete the command subkey first (if present)
reg delete "HKCR\Drive\shell\EjectDrive\command" /f
:: Then delete the parent key
reg delete "HKCR\Drive\shell\EjectDrive" /f

echo Done.
echo To refresh Explorer shell context menus, log off/on or restart Explorer.
endlocal
pause
exit /b 0
