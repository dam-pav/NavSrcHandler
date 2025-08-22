@echo off
setlocal

REM Determine script directory (with trailing backslash)
set "SCRIPT_DIR=%~dp0"

REM Prefer PowerShell 7+ (pwsh) if available, else fall back to Windows PowerShell
where pwsh.exe >nul 2>&1
if %ERRORLEVEL%==0 (
  set "PS=pwsh.exe"
) else (
  set "PS=powershell.exe"
)

REM Run the PowerShell script with ExecutionPolicy bypass and forward all args
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%NavSrcHandler.ps1" %*

endlocal
