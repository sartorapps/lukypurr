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

REM yt-dlp: o release estavel do PyPI esta QUEBRADO contra o bloqueio 403
REM atual do YouTube (metadados passam, download de audio nao). O conserto so
REM existe no canal NIGHTLY. Por isso NAO instalamos o yt-dlp do requirements
REM (que puxaria o release quebrado) e forcamos o nightly via tarball do GitHub.
echo Installing yt-dlp NIGHTLY (release estavel quebrado pelo 403 do YouTube)...
for /f "tokens=*" %%i in ('curl -sL "https://api.github.com/repos/yt-dlp/yt-dlp-nightly-builds/releases/latest" ^| python -c "import sys,json; print(json.load(sys.stdin)['tag_name'])"') do set NIGHTLY_TAG=%%i
if not "%NIGHTLY_TAG%"=="" (
    set NIGHTLY_URL=https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/download/%NIGHTLY_TAG%/yt-dlp.tar.gz
    curl -sL -o "%TEMP%\lukypurr_yt_dlp_nightly.tar.gz" "%NIGHTLY_URL%"
    pip install -q --force-reinstall --no-deps "%TEMP%\lukypurr_yt_dlp_nightly.tar.gz"
    del "%TEMP%\lukypurr_yt_dlp_nightly.tar.gz"
    echo yt-dlp nightly (%NIGHTLY_TAG%) instalado no venv de build.
) else (
    echo AVISO: nao consegui resolver o nightly do yt-dlp; build usara release estavel (pode dar 403).
)

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
