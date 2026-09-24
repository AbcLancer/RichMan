@echo off
setlocal

rem ==== 按优先级自动探测 Godot 4.7.2 ====
set "GODOT="

if exist "D:\Godot\Godot_v4.7.2-stable_win64.exe" set "GODOT=D:\Godot\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT if exist "%~dp0Godot\Godot_v4.7.2-stable_win64.exe" set "GODOT=%~dp0Godot\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT if exist "%~dp0.tools\Godot_v4.7.2-stable_win64.exe" set "GODOT=%~dp0.tools\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT if exist "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"

if not defined GODOT (
  echo.
  echo   [错误] 没找到 Godot 4.7.2
  echo.
  echo   已尝试以下位置：
  echo     D:\Godot\
  echo     %~dp0Godot\
  echo     %~dp0.tools\
  echo     %%LOCALAPPDATA%%\Microsoft\WinGet\Packages\...
  echo.
  echo   请把 Godot_v4.7.2-stable_win64.exe 放进 D:\Godot\
  echo   或用 Godot 编辑器打开 %~dp0game 后按 F5 运行。
  echo.
  pause
  exit /b 1
)

echo.
echo   正在启动 大富翁6 即时制复刻 ...
echo   Godot: %GODOT%
echo.
start "" "%GODOT%" --path "%~dp0game" --resolution 1440x810

endlocal
