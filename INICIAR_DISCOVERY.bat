@echo off
setlocal
set "ROOT=%~dp0"
where powershell.exe >nul 2>&1
if errorlevel 1 (
  mshta "javascript:alert('O Windows PowerShell não foi encontrado neste computador.');close()"
  exit /b 1
)
start "Hexxon Bridge Discovery" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%ROOT%src\Start-Discovery.ps1"
endlocal
