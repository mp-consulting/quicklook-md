#!/usr/bin/env bash
# Builds QuickLook MD in Release, signs it, and packages it as a .zip and .dmg in dist/.
#
# Usage: scripts/build-release.sh [version]
#
# Environment:
#   BUILD_NUMBER        CFBundleVersion (default: 1)
#   SIGN_IDENTITY       codesign identity, e.g. "Developer ID Application: Name (TEAMID)" (default: "-", ad-hoc)
#   TEAM_ID             Apple developer team ID, required with a real identity
#   NOTARY_KEY_PATH     App Store Connect API key (.p8); with NOTARY_KEY_ID and NOTARY_ISSUER_ID enables notarization
#   NOTARY_KEY_ID
#   NOTARY_ISSUER_ID
#   DERIVED_DATA        Xcode derived data path
#   OUT_DIR             Output directory (default: dist)
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null || echo 0.0.0)}"
VERSION="${VERSION#v}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
TEAM_ID="${TEAM_ID:-}"
DERIVED_DATA="${DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/QuickLookMD-release}"
OUT_DIR="${OUT_DIR:-dist}"

APP_NAME="QuickLook MD"
ARTIFACT="QuickLook-MD-$VERSION"
APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"

notarize=false
if [[ -n "${NOTARY_KEY_PATH:-}" && -n "${NOTARY_KEY_ID:-}" && -n "${NOTARY_ISSUER_ID:-}" ]]; then
    [[ "$SIGN_IDENTITY" == "-" ]] && { echo "error: notarization requires a Developer ID SIGN_IDENTITY" >&2; exit 1; }
    notarize=true
fi

sign_flags=()
if [[ "$SIGN_IDENTITY" != "-" ]]; then
    # Secure timestamps are required for notarization.
    sign_flags+=(OTHER_CODE_SIGN_FLAGS="--timestamp")
fi

submit_for_notarization() {
    xcrun notarytool submit "$1" --wait \
        --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID"
}

echo "==> Building $APP_NAME $VERSION ($BUILD_NUMBER), identity: $SIGN_IDENTITY"
xcodegen generate --quiet
rm -rf "$DERIVED_DATA/Build/Products/Release"
xcodebuild \
    -project QuickLookMD.xcodeproj \
    -scheme QuickLookMD \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    -quiet \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    ${sign_flags[@]+"${sign_flags[@]}"} \
    build

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"

if $notarize; then
    echo "==> Notarizing app"
    tmp_zip="$(mktemp -d)/app.zip"
    ditto -c -k --keepParent "$APP" "$tmp_zip"
    submit_for_notarization "$tmp_zip"
    xcrun stapler staple "$APP"
fi

echo "==> Packaging"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT_DIR/$ARTIFACT.zip"

staging="$(mktemp -d)"
ditto "$APP" "$staging/$APP_NAME.app"
ln -s /Applications "$staging/Applications"
hdiutil create -quiet -volname "$APP_NAME" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$OUT_DIR/$ARTIFACT.dmg"
rm -rf "$staging"

if [[ "$SIGN_IDENTITY" != "-" ]]; then
    codesign --sign "$SIGN_IDENTITY" --timestamp "$OUT_DIR/$ARTIFACT.dmg"
fi
if $notarize; then
    echo "==> Notarizing dmg"
    submit_for_notarization "$OUT_DIR/$ARTIFACT.dmg"
    xcrun stapler staple "$OUT_DIR/$ARTIFACT.dmg"
fi

(cd "$OUT_DIR" && shasum -a 256 "$ARTIFACT.zip" "$ARTIFACT.dmg" > SHA256SUMS.txt)

echo "==> Done"
ls -lh "$OUT_DIR"
