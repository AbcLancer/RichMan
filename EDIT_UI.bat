@echo off
setlocal
set "GODOT=D:\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" set "GODOT=%~dp0Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" set "GODOT=%~dp0.tools\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot 4.7.2 was not found. Place it in D:\Godot or the project Godot folder.
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0game" --resolution 1440x810 -- --ui-editor
endlocal
