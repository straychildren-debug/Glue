@echo off
chcp 65001 >nul
rem Сборка автономного build\windows\Glue.exe (нужны шаблоны экспорта Godot 4.7 в %APPDATA%\Godot\export_templates\4.7.stable).
cd /d "%~dp0"
set GODOT=tools\godot\Godot_v4.7-stable_win64_console.exe
if not exist "%GODOT%" (
    echo Не найден %GODOT%. Положите туда Godot 4.7 stable win64.
    pause
    exit /b 1
)
if not exist "build\windows" mkdir "build\windows"
"%GODOT%" --headless --path "%~dp0." --export-release "Windows Desktop" build/windows/Glue.exe
if errorlevel 1 (
    echo Сборка не удалась.
    pause
    exit /b 1
)
echo Готово: build\windows\Glue.exe
pause
