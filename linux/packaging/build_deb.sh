#!/bin/bash
set -euo pipefail

# Debian package builder for Personal Finance
# Usage: ./linux/packaging/build_deb.sh <version> <output_dir> [archive_name]

VERSION="${1:-1.0.0}"
OUTPUT_DIR="${2:-build/dist}"
ARCHIVE_NAME="${3:-26_3_PersonalFinance}"

# Ensure version is Debian-compatible (strip any leading 'v')
DEB_VERSION="${VERSION#v}"

echo "Building Debian package for Personal Finance v${DEB_VERSION}..."

BUNDLE_DIR="build/linux/x64/release/bundle"
if [ ! -d "$BUNDLE_DIR" ]; then
  echo "Error: Release bundle directory not found at $BUNDLE_DIR. Run 'flutter build linux --release' first."
  exit 1
fi

STAGE_DIR="build/deb_staging"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/DEBIAN"
mkdir -p "$STAGE_DIR/usr/lib/personal_finance"
mkdir -p "$STAGE_DIR/usr/bin"
mkdir -p "$STAGE_DIR/usr/share/applications"
mkdir -p "$STAGE_DIR/usr/share/icons/hicolor/128x128/apps"
mkdir -p "$OUTPUT_DIR"

# 1. Copy bundle files to /usr/lib/personal_finance
cp -r "$BUNDLE_DIR"/* "$STAGE_DIR/usr/lib/personal_finance/"
chmod 755 "$STAGE_DIR/usr/lib/personal_finance/personal_finance"

# 2. Create launcher script in /usr/bin
cat << 'EOF' > "$STAGE_DIR/usr/bin/personal_finance"
#!/bin/sh
exec /usr/lib/personal_finance/personal_finance "$@"
EOF
chmod 755 "$STAGE_DIR/usr/bin/personal_finance"

# 3. Create .desktop file
cat << EOF > "$STAGE_DIR/usr/share/applications/personal-finance.desktop"
[Desktop Entry]
Version=1.0
Name=Personal Finance
Comment=Privacy-first personal finance and budget management
Exec=/usr/bin/personal_finance
Icon=personal-finance
Terminal=false
Type=Application
Categories=Office;Finance;
Keywords=finance;budget;accounts;expenses;
EOF
chmod 644 "$STAGE_DIR/usr/share/applications/personal-finance.desktop"

# 4. Copy app icon
if [ -f "assets/images/app_logo.png" ]; then
  cp "assets/images/app_logo.png" "$STAGE_DIR/usr/share/icons/hicolor/128x128/apps/personal-finance.png"
fi

# 5. Create control file
cat << EOF > "$STAGE_DIR/DEBIAN/control"
Package: personal-finance
Version: ${DEB_VERSION}
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Saurabh Bhatia <ssbhatia2957@gmail.com>
Depends: libc6, libgtk-3-0
Description: Personal Finance Application
 Comprehensive, privacy-first personal finance, budget, loan, and investment tracker.
 Built with Flutter for desktop.
EOF

# Calculate installed size in KB
INSTALLED_SIZE=$(du -sk "$STAGE_DIR/usr" | cut -f1)
echo "Installed-Size: ${INSTALLED_SIZE}" >> "$STAGE_DIR/DEBIAN/control"

# Set correct Debian permissions
chmod -R u=rwX,go=rX "$STAGE_DIR"
chmod -R 755 "$STAGE_DIR/DEBIAN"
chmod 755 "$STAGE_DIR/usr/bin/personal_finance"

# 6. Build the .deb package
DEB_FILE="${OUTPUT_DIR}/${ARCHIVE_NAME}-Linux-x64.deb"
dpkg-deb --build --root-owner-group "$STAGE_DIR" "$DEB_FILE"

echo "Successfully created Debian package: $DEB_FILE"
