@echo off
setlocal
cd /d "%~dp0"

echo [提示] 工作目录: %CD%
echo [提示] 请先保存 data_src/xlsx表 里正在编辑的 .xlsx，否则转出来仍是旧数据。
echo [提示] data_src 只放 xlsx 源表；转表会自动清理 CSV/.import/.translation 等（见 data_src/00_表头约定.txt）。
echo.

set "PYTHONCMD=py -3"
py -3 -c "import sys" 2>nul
if errorlevel 1 set "PYTHONCMD=python"

if "%~1"=="" (
  %PYTHONCMD% "%~dp0convert_tables.py"
) else (
  %PYTHONCMD% "%~dp0convert_tables.py" %*
)

echo.
pause
endlocal
