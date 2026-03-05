#!/bin/bash
# =============================================================================
#  CCMac — Build Script: .app bundle + DMG
#  Usage: cd /path/to/CCMac && bash build_dmg.sh
# =============================================================================
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
APP_NAME="CCMac"
VERSION="1.0.0"
BUNDLE_ID="com.ccmac.app"
MIN_MACOS="13.0"
RELEASE_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_STAGING="dist_staging"
ICON_SRC="Sources/CCMac/Resources/AppIcon.png"
ICNS_PATH="Sources/CCMac/Resources/AppIcon.icns"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   Building ${APP_NAME} ${VERSION} for macOS ${MIN_MACOS}+  ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── 1. Release build ──────────────────────────────────────────────────────────
echo "▶ Step 1/6 — swift build -c release"
swift build -c release
echo "  ✓ Build succeeded"

# ── 2. Generate .icns from AppIcon.png ───────────────────────────────────────
echo ""
echo "▶ Step 2/6 — Generating AppIcon.icns"

if [ ! -f "${ICON_SRC}" ]; then
    echo "  ⚠ ${ICON_SRC} not found — skipping icon (app will use default)"
else
    ICONSET="AppIcon.iconset"
    rm -rf "${ICONSET}"
    mkdir "${ICONSET}"

    # Generate all required macOS icon sizes using sips
    sips -z 16   16   "${ICON_SRC}" --out "${ICONSET}/icon_16x16.png"       > /dev/null
    sips -z 32   32   "${ICON_SRC}" --out "${ICONSET}/icon_16x16@2x.png"    > /dev/null
    sips -z 32   32   "${ICON_SRC}" --out "${ICONSET}/icon_32x32.png"       > /dev/null
    sips -z 64   64   "${ICON_SRC}" --out "${ICONSET}/icon_32x32@2x.png"    > /dev/null
    sips -z 128  128  "${ICON_SRC}" --out "${ICONSET}/icon_128x128.png"     > /dev/null
    sips -z 256  256  "${ICON_SRC}" --out "${ICONSET}/icon_128x128@2x.png"  > /dev/null
    sips -z 256  256  "${ICON_SRC}" --out "${ICONSET}/icon_256x256.png"     > /dev/null
    sips -z 512  512  "${ICON_SRC}" --out "${ICONSET}/icon_256x256@2x.png"  > /dev/null
    sips -z 512  512  "${ICON_SRC}" --out "${ICONSET}/icon_512x512.png"     > /dev/null
    sips -z 1024 1024 "${ICON_SRC}" --out "${ICONSET}/icon_512x512@2x.png"  > /dev/null

    # Convert iconset → .icns
    iconutil --convert icns "${ICONSET}" --output "${ICNS_PATH}"
    rm -rf "${ICONSET}"
    echo "  ✓ AppIcon.icns generated ($(du -sh ${ICNS_PATH} | cut -f1))"
fi

# ── 3. Assemble .app bundle ───────────────────────────────────────────────────
echo ""
echo "▶ Step 3/6 — Assembling ${APP_BUNDLE}"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Binary
cp "${RELEASE_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Info.plist (read by Finder, Spotlight, Gatekeeper)
# Inject CFBundleIconFile so Finder picks up the icon
INFO_PLIST="${APP_BUNDLE}/Contents/Info.plist"
cp "Sources/CCMac/Resources/Info.plist" "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${INFO_PLIST}" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "${INFO_PLIST}"

# App icon
if [ -f "${ICNS_PATH}" ]; then
    cp "${ICNS_PATH}" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    echo "  ✓ AppIcon.icns embedded"
fi

# SPM resource bundle (may or may not exist depending on assets)
RESOURCE_BUNDLE="${RELEASE_DIR}/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "${RESOURCE_BUNDLE}" ]; then
    cp -R "${RESOURCE_BUNDLE}" "${APP_BUNDLE}/Contents/Resources/"
    echo "  ✓ Copied SPM resource bundle"
fi

echo "  ✓ .app bundle assembled"

# ── 4. Ad-hoc code sign ───────────────────────────────────────────────────────
echo ""
echo "▶ Step 4/6 — Code signing (ad-hoc)"
codesign \
    --force \
    --deep \
    --sign - \
    --identifier "${BUNDLE_ID}" \
    --options runtime \
    "${APP_BUNDLE}"
echo "  ✓ Signed ${APP_BUNDLE}"

# ── 5. Verify signature ───────────────────────────────────────────────────────
echo ""
echo "▶ Step 5/6 — Verifying signature"
codesign --verify --verbose "${APP_BUNDLE}" 2>&1 | sed 's/^/  /'
echo "  ✓ Signature valid"

# ── 6. Create DMG ─────────────────────────────────────────────────────────────
echo ""
echo "▶ Step 6/6 — Creating ${DMG_NAME}"
rm -rf "${DMG_STAGING}"
mkdir "${DMG_STAGING}"
cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

rm -f "${DMG_NAME}"
hdiutil create \
    -volname "${APP_NAME} ${VERSION}" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "${DMG_NAME}"

rm -rf "${DMG_STAGING}"
echo "  ✓ ${DMG_NAME} created"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✅  Done!                                               ║"
echo "╠══════════════════════════════════════════════════════════╣"
printf  "║  📦  %-52s║\n" "${DMG_NAME}"
printf  "║  📁  %-52s║\n" "$(du -sh ${DMG_NAME} | cut -f1)  on disk"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Install:                                                ║"
echo "║    1. Open the DMG                                       ║"
echo "║    2. Drag CCMac.app → Applications                      ║"
echo "║    3. Right-click → Open  (first launch, ad-hoc signed)  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
