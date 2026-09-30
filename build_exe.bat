@echo off
rem Build standalone build\windows\Glue.exe.
rem Needs Godot 4.7 export templates in %APPDATA%\Godot\export_templates\4.7.stable
cd /d "%~dp0"
set GODOT=tools\godot\Godot_v4.7-stable_win64_console.exe
if not exist "%GODOT%" (
    echo Godot not found: %GODOT%
    echo Put Godot 4.7 stable win64 into tools\godot\
    pause
    exit /b 1
)
if not exist "build\windows" mkdir "build\windows"
"%GODOT%" --headless --path "%~dp0." --export-release "Windows Desktop" build/windows/Glue.exe
if errorlevel 1 (
    echo Build failed.
    pause
    exit /b 1
)
echo Done: build\windows\Glue.exe
pause
