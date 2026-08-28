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
python -m pip install -q --upgrade pip
python -m pip install -q -r "%SCRIPT_DIR%requirements.txt"
python -m pip install -q pyinstaller

REM yt-dlp: o release estavel do PyPI esta QUEBRADO contra o bloqueio 403
REM atual do YouTube (metadados passam, download de audio nao). O conserto so
REM existe no canal NIGHTLY/DEV. Por isso NAO instalamos o yt-dlp do requirements
REM (que puxaria o release quebrado) e forcamos o dev-release via --pre do PyPI.
echo Instalando yt-dlp NIGHTLY via PyPI dev-release --pre...
python -m pip install --pre --force-reinstall --no-deps yt-dlp
python -c "import yt_dlp" 2>nul
if errorlevel 1 (
    echo ERRO: yt-dlp nao foi instalado com sucesso no venv de build.
    goto :build_fail
) else (
    python -c "import yt_dlp; print('yt-dlp', yt_dlp.version.__version__, 'instalado e importavel.')"
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
    --collect-submodules "yt_dlp" ^
    --hidden-import "PySide6.QtCore" ^
    --hidden-import "PySide6.QtGui" ^
    --hidden-import "PySide6.QtWidgets" ^
    --hidden-import "PySide6.QtQml" ^
    --hidden-import "PySide6.QtQuick" ^
    --hidden-import "PySide6.QtMultimedia" ^
    --hidden-import "ytmusicapi" ^
    --hidden-import "yt_dlp" ^
    --hidden-import "yt_dlp.extractor" ^
    --hidden-import "numpy" ^
    "%SCRIPT_DIR%main.py"

echo.
echo === Build Complete ===
echo Executable: %DIST_DIR%\%APP_NAME%.exe
echo.
goto :eof

:build_fail
echo.
echo === BUILD ABORTADO: yt-dlp nao instalado ===
echo O executavel NAO foi gerado por causa da falha acima.
echo.

pause
