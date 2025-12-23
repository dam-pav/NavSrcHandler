@echo off
setlocal

REM Determine script directory (with trailing backslash)
set "SCRIPT_DIR=%~dp0"

REM Prefer Windows PowerShell (powershell.exe) for NAV compatibility
set "PS=powershell.exe"

REM Only use pwsh if explicitly needed, as NAV DLLs are often .NET Framework only
REM where pwsh.exe >nul 2>&1
REM if %ERRORLEVEL%==0 (
REM   set "PS=pwsh.exe"
REM ) else (
REM   set "PS=powershell.exe"
REM )

REM Run the PowerShell script with ExecutionPolicy bypass and forward all args
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%NavSrcHandler.ps1" %*

endlocal
