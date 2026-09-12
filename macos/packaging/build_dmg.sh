#!/bin/bash
set -euo pipefail

# macOS DMG packager for Personal Finance
# Usage: ./macos/packaging/build_dmg.sh <version> <output_dir> [archive_name]

VERSION="${1:-1.0.0}"
OUTPUT_DIR="${2:-build/dist}"
ARCHIVE_NAME="${3:-26_3_PersonalFinance}"

echo "Packaging macOS DMG and ZIP for Personal Finance v${VERSION}..."

BUILD_PRODUCTS="build/macos/Build/Products/Release"
APP_PATH="$(find "$BUILD_PRODUCTS" -maxdepth 1 -name "*.app" | head -n 1)"

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo "Error: .app bundle not found in $BUILD_PRODUCTS. Run 'flutter build macos --release' first."
  exit 1
fi

APP_NAME="$(basename "$APP_PATH")"
mkdir -p "$OUTPUT_DIR"

# 1. Create portable ZIP archive
echo "Creating macOS application ZIP..."
ditto -c -k --keepParent "$APP_PATH" "${OUTPUT_DIR}/${ARCHIVE_NAME}-macOS.zip"

# 2. Create DMG Disk Image
DMG_STAGE="build/dmg_staging"
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"

echo "Staging application for DMG..."
cp -R "$APP_PATH" "$DMG_STAGE/"
# Create symlink to /Applications for standard drag-and-drop installer experience
ln -s /Applications "$DMG_STAGE/Applications"

DMG_FILE="${OUTPUT_DIR}/${ARCHIVE_NAME}-macOS.dmg"
rm -f "$DMG_FILE"

echo "Creating DMG disk image with hdiutil..."
hdiutil create \
  -volname "Personal Finance" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -format UDZO \
  "$DMG_FILE"

echo "Successfully generated macOS artifacts:"
echo "  - ${OUTPUT_DIR}/${ARCHIVE_NAME}-macOS.dmg"
echo "  - ${OUTPUT_DIR}/${ARCHIVE_NAME}-macOS.zip"
