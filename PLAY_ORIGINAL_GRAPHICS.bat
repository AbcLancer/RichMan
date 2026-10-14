@echo off
setlocal
set "GODOT=D:\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" set "GODOT=%~dp0.tools\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot executable not found. See PLAY.bat for supported installation paths.
  pause
  exit /b 1
)
start "" /wait "%GODOT%" --headless --editor --import --path "%~dp0game" >nul 2>&1
start "" "%GODOT%" --path "%~dp0game" --resolution 1440x810 -- --original-graphics
endlocal
