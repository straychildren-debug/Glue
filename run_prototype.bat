@echo off
chcp 65001 >nul
rem Запуск прототипа «Держись!» через локальный Godot 4.7 (tools\godot).
cd /d "%~dp0"
set GODOT=tools\godot\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo Не найден %GODOT%. Положите туда Godot 4.7 stable win64.
    pause
    exit /b 1
)
if not exist ".godot" "%GODOT%" --headless --path "%~dp0." --import
start "" "%GODOT%" --path "%~dp0."
