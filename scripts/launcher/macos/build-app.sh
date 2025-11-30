#!/bin/bash
# Build LM Light.app from AppleScript
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="LM Light"
OUTPUT_DIR="$SCRIPT_DIR/dist"

mkdir -p "$OUTPUT_DIR"

# Compile AppleScript to app
osacompile -o "$OUTPUT_DIR/$APP_NAME.app" "$SCRIPT_DIR/LMLight.applescript"

# Set icon (optional - use default for now)
# cp "$SCRIPT_DIR/icon.icns" "$OUTPUT_DIR/$APP_NAME.app/Contents/Resources/applet.icns"

echo "Done: $OUTPUT_DIR/$APP_NAME.app"
echo "Drag to Applications or Dock"
