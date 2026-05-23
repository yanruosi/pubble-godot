@echo off
setlocal
cd /d "%~dp0"

set "GODOT_EXE="
if exist "%~dp0godot.local.bat" call "%~dp0godot.local.bat"
if not defined GODOT_EXE if defined GODOT set "GODOT_EXE=%GODOT%"
if not defined GODOT_EXE set "GODOT_EXE=D:\steamku\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"

if not exist "%GODOT_EXE%" (
  echo [错误] 找不到 Godot：%GODOT_EXE%
  pause
  exit /b 1
)

echo [校验] headless 加载 ch1_l01（约 3 秒）...
"%GODOT_EXE%" --headless --path "%~dp0" --quit-after 3 "res://scenes/idol/ch1_l01.tscn" 2>&1
set "ERR=%ERRORLEVEL%"
echo.
if %ERR%==0 (
  echo [完成] 场景可加载，退出码 0
) else (
  echo [失败] 退出码 %ERR%，请查看上方 Godot 报错
)
pause
endlocal & exit /b %ERR%
