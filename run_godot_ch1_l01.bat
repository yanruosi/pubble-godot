@echo off
setlocal
cd /d "%~dp0"

set "GODOT_EXE="
if exist "%~dp0godot.local.bat" call "%~dp0godot.local.bat"
if not defined GODOT_EXE if defined GODOT set "GODOT_EXE=%GODOT%"
if not defined GODOT_EXE set "GODOT_EXE=D:\steamku\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"

if not exist "%GODOT_EXE%" (
  echo [错误] 找不到 Godot：%GODOT_EXE%
  echo 请编辑 godot.local.bat 中的 GODOT_EXE，或设置环境变量 GODOT。
  pause
  exit /b 1
)

echo [提示] Godot: %GODOT_EXE%
echo [提示] 启动 ch1_l01 场景（390x844 见 project.godot）
echo.

"%GODOT_EXE%" --path "%~dp0" "res://scenes/idol/ch1_l01.tscn"
set "ERR=%ERRORLEVEL%"
echo.
echo [退出码] %ERR%
pause
endlocal & exit /b %ERR%
