@echo off
setlocal

set APP_NAME=LukyPurr
set SCRIPT_DIR=%~dp0
set VENV_DIR=%SCRIPT_DIR%.venv
set DIST_DIR=%SCRIPT_DIR%dist
set BUILD_DIR=%SCRIPT_DIR%build

echo === LukyPurr Build Script (Windows) ===
echo.

if not exist "%VENV_DIR%" (
    echo Creating virtual environment...
    python -m venv "%VENV_DIR%"
)

echo Activating virtual environment...
call "%VENV_DIR%\Scripts\activate.bat"

echo Installing dependencies...
pip install -q --upgrade pip
pip install -q -r "%SCRIPT_DIR%requirements.txt"
pip install -q pyinstaller

echo Cleaning previous builds...
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
if exist "%DIST_DIR%" rmdir /s /q "%DIST_DIR%"

echo Building %APP_NAME%...
pyinstaller ^
    --name "%APP_NAME%" ^
    --onefile ^
    --windowed ^
    --icon "%SCRIPT_DIR%assets\lukypurr_icon.png" ^
    --add-data "%SCRIPT_DIR%ui;ui" ^
    --add-data "%SCRIPT_DIR%services;services" ^
    --add-data "%SCRIPT_DIR%assets;assets" ^
    --add-data "%SCRIPT_DIR%donation;donation" ^
    --add-data "%SCRIPT_DIR%themes;themes" ^
    --collect-data "ytmusicapi" ^
    --hidden-import "PySide6.QtCore" ^
    --hidden-import "PySide6.QtGui" ^
    --hidden-import "PySide6.QtWidgets" ^
    --hidden-import "PySide6.QtQml" ^
    --hidden-import "PySide6.QtQuick" ^
    --hidden-import "PySide6.QtMultimedia" ^
    --hidden-import "ytmusicapi" ^
    --hidden-import "yt_dlp" ^
    --hidden-import "numpy" ^
    "%SCRIPT_DIR%main.py"

echo.
echo === Build Complete ===
echo Executable: %DIST_DIR%\%APP_NAME%.exe
echo.

pause
