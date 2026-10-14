@echo off
setlocal
cd /d "%~dp0"
set "BUILD_PYTHON=python"
if exist ".workbuddy\venv\Scripts\python.exe" set "BUILD_PYTHON=.workbuddy\venv\Scripts\python.exe"
if not "%~1"=="" goto cli
echo 1. Windows PC
echo 2. Check PC requirements
echo 3. Resource PCK
choice /c 123 /n /m "Select: "
if errorlevel 3 goto pack
if errorlevel 2 goto check
"%BUILD_PYTHON%" tools\package_game.py build pc --release
goto done
:check
"%BUILD_PYTHON%" tools\package_game.py check pc --release
goto done
:pack
"%BUILD_PYTHON%" tools\package_game.py build pack
goto done
:cli
"%BUILD_PYTHON%" tools\package_game.py %*
exit /b %errorlevel%
:done
set "BUILD_RESULT=%errorlevel%"
echo See docs\packaging.md for setup and iOS instructions.
pause
exit /b %BUILD_RESULT%
