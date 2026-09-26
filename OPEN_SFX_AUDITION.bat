@echo off
chcp 936 >nul
cd /d "%~dp0"
set "PY=%~dp0.workbuddy\venv\Scripts\python.exe"
if not exist "%PY%" set "PY=python"
echo.
echo   大富翁6 音效试听页 —— 正在启动本地服务...
echo.
"%PY%" "%~dp0tools\serve_docs.py"
echo.
echo   服务已结束，按任意键关闭窗口。
pause >nul
