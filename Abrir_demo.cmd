@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0source_tools\launch_game.ps1" %*
if errorlevel 1 (
  pause
  exit /b 1
)
