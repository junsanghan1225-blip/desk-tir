@echo off
rem Double-click: get the latest code (git pull), then run the game in Godot.
chcp 65001 >nul
cd /d "%~dp0"
git pull
set "GODOT="
for /f "delims=" %%f in (
'where /r "%USERPROFILE%" Godot_v4*_win64.exe 2^>nul') do if not defined GODOT set "GODOT=%%f"
if not defined GODOT (
  echo Godot_v4..._win64.exe not found under %USERPROFILE%. Put Godot in Desktop or Downloads.
  pause
  exit /b
)
start "" "%GODOT%" --path "%~dp0."
