@echo off
chcp 65001 >nul
setlocal

set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"

if not exist "%GODOT%" (
  echo.
  echo  [错误] 没找到 Godot 4.7.2：
  echo    %GODOT%
  echo.
  echo  请先安装，或用编辑器打开 %~dp0game 后按 F5 运行。
  echo.
  pause
  exit /b 1
)

echo 正在启动 大富翁6 即时制复刻 ...
start "" "%GODOT%" --path "%~dp0game" --resolution 1440x810

endlocal
