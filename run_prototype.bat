@echo off
rem Run the "Hold on!" prototype with the local Godot 4.7 (tools\godot).
cd /d "%~dp0"
set GODOT=tools\godot\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo Godot not found: %GODOT%
    echo Put Godot 4.7 stable win64 into tools\godot\
    pause
    exit /b 1
)
if not exist ".godot" "%GODOT%" --headless --path "%~dp0." --import
start "" "%GODOT%" --path "%~dp0."
