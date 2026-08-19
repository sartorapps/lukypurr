#!/bin/bash
set -e

APP_NAME="LukyPurr"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
DIST_DIR="$SCRIPT_DIR/dist"
BUILD_DIR="$SCRIPT_DIR/build"

echo "=== LukyPurr Build Script ==="
echo ""

# Check venv
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Activate venv
echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Install dependencies
echo "Installing dependencies..."
pip install -q --upgrade pip
pip install -q -r "$SCRIPT_DIR/requirements.txt"
pip install -q pyinstaller

# yt-dlp: o release estavel do PyPI esta QUEBRADO contra o bloqueio 403
# atual do YouTube (metadados passam, download de audio nao). O conserto so
# existe no canal NIGHTLY. Por isso NAO instalamos o yt-dlp do requirements
# (que puxaria o release quebrado) e forcamos o nightly via tarball do GitHub.
echo "Installing yt-dlp NIGHTLY (release estavel quebrado pelo 403 do YouTube)..."
NIGHTLY_TAG=$(curl -sL "https://api.github.com/repos/yt-dlp/yt-dlp-nightly-builds/releases/latest" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])" 2>/dev/null)
if [ -n "$NIGHTLY_TAG" ]; then
    NIGHTLY_URL="https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/download/${NIGHTLY_TAG}/yt-dlp.tar.gz"
    curl -sL -o /tmp/lukypurr_yt_dlp_nightly.tar.gz "$NIGHTLY_URL"
    pip install -q --force-reinstall --no-deps /tmp/lukypurr_yt_dlp_nightly.tar.gz
    rm -f /tmp/lukypurr_yt_dlp_nightly.tar.gz
    echo "yt-dlp nightly ($NIGHTLY_TAG) instalado no venv de build."
else
    echo "AVISO: nao consegui resolver o nightly do yt-dlp; build usara release estavel (pode dar 403)."
fi

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf "$BUILD_DIR" "$DIST_DIR"

# Build
echo "Building $APP_NAME..."
pyinstaller \
    --name "$APP_NAME" \
    --onefile \
    --windowed \
    --add-data "ui:ui" \
    --add-data "services:services" \
    --add-data "assets:assets" \
    --add-data "donation:donation" \
    --add-data "themes:themes" \
    --collect-data "ytmusicapi" \
    --hidden-import "PySide6.QtCore" \
    --hidden-import "PySide6.QtGui" \
    --hidden-import "PySide6.QtWidgets" \
    --hidden-import "PySide6.QtQml" \
    --hidden-import "PySide6.QtQuick" \
    --hidden-import "PySide6.QtMultimedia" \
    --hidden-import "ytmusicapi" \
    --hidden-import "yt_dlp" \
    --hidden-import "numpy" \
    "$SCRIPT_DIR/main.py"

echo ""
echo "=== Build Complete ==="
echo "Executable: $DIST_DIR/$APP_NAME/$APP_NAME"
echo ""
