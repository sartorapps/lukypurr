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
