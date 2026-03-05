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

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   Building ${APP_NAME} ${VERSION} for macOS ${MIN_MACOS}+  ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── 1. Release build ──────────────────────────────────────────────────────────
echo "▶ Step 1/5 — swift build -c release"
swift build -c release
echo "  ✓ Build succeeded"

# ── 2. Assemble .app bundle ───────────────────────────────────────────────────
echo ""
echo "▶ Step 2/5 — Assembling ${APP_BUNDLE}"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Binary
cp "${RELEASE_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Info.plist  (read by Finder, Spotlight, Gatekeeper)
cp "Sources/CCMac/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# SPM resource bundle (may or may not exist depending on assets)
RESOURCE_BUNDLE="${RELEASE_DIR}/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "${RESOURCE_BUNDLE}" ]; then
    cp -R "${RESOURCE_BUNDLE}" "${APP_BUNDLE}/Contents/Resources/"
    echo "  ✓ Copied resource bundle"
else
    echo "  ℹ No resource bundle found (expected if no non-plist assets)"
fi

echo "  ✓ .app bundle assembled"

# ── 3. Ad-hoc code sign ───────────────────────────────────────────────────────
echo ""
echo "▶ Step 3/5 — Code signing (ad-hoc)"
# '--deep' signs all nested bundles/frameworks too
codesign \
    --force \
    --deep \
    --sign - \
    --identifier "${BUNDLE_ID}" \
    --options runtime \
    "${APP_BUNDLE}"
echo "  ✓ Signed ${APP_BUNDLE}"

# ── 4. Verify signature ───────────────────────────────────────────────────────
echo ""
echo "▶ Step 4/5 — Verifying signature"
codesign --verify --verbose "${APP_BUNDLE}" 2>&1 | sed 's/^/  /'
echo "  ✓ Signature valid"

# ── 5. Create DMG ─────────────────────────────────────────────────────────────
echo ""
echo "▶ Step 5/5 — Creating ${DMG_NAME}"
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
