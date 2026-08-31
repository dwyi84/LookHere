#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

APP_NAME="LookHere"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

# Stable local signing identity — a self-signed certificate trusted in the
# USER domain. Because the signature is tied to the certificate (not to the
# binary contents), the Accessibility permission survives rebuilds.
SIGN_ID="LookHere Development Signing"
SIGN_DIR="$HOME/.lookhere"
KEYCHAIN="$SIGN_DIR/lookhere.keychain-db"
KEYCHAIN_PASS="lookhere"

find_openssl() {
    if [ -x "/opt/homebrew/bin/openssl" ]; then
        echo "/opt/homebrew/bin/openssl"
    elif command -v openssl >/dev/null 2>&1; then
        echo "openssl"
    else
        echo ""
    fi
}

set_user_trust() {
    swift "$ROOT/Scripts/trust_signing_cert.swift" "$SIGN_DIR/signing.der"
}

ensure_signing_identity() {
    # Already usable? (cert present in keychain AND trusted in user domain)
    if security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$SIGN_ID"; then
        return 0
    fi

    # Cert exists but lost trust? Re-apply the user-domain trust.
    if security find-certificate -c "$SIGN_ID" "$KEYCHAIN" >/dev/null 2>&1; then
        echo "==> Re-applying trust for $SIGN_ID..."
        security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN"
        set_user_trust
        return 0
    fi

    local openssl_cmd
    openssl_cmd="$(find_openssl)"
    if [ -z "$openssl_cmd" ]; then
        echo "    openssl not found; cannot create a stable signing identity."
        return 1
    fi

    echo "==> Creating stable self-signed signing identity (one-time)..."
    mkdir -p "$SIGN_DIR"
    local key="$SIGN_DIR/signing.key"
    local crt="$SIGN_DIR/signing.crt"
    local der="$SIGN_DIR/signing.der"
    local p12="$SIGN_DIR/signing.p12"

    rm -f "$key" "$crt" "$der" "$p12"
    "$openssl_cmd" req -x509 -newkey rsa:2048 -sha256 -nodes \
        -keyout "$key" -out "$crt" -days 3650 \
        -subj "/CN=$SIGN_ID" \
        -addext "extendedKeyUsage=codeSigning" \
        -addext "keyUsage=critical,digitalSignature" 2>/dev/null
    "$openssl_cmd" pkcs12 -export -legacy -inkey "$key" -in "$crt" \
        -out "$p12" -passout "pass:$KEYCHAIN_PASS" 2>/dev/null
    "$openssl_cmd" x509 -in "$crt" -outform der -out "$der"

    security create-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN" >/dev/null 2>&1 || true
    security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN"
    security import "$p12" -k "$KEYCHAIN" -P "$KEYCHAIN_PASS" \
        -T /usr/bin/codesign -T /usr/bin/security >/dev/null 2>&1
    security set-key-partition-list -S apple-tool:,apple:,codesign: \
        -s -k "$KEYCHAIN_PASS" "$KEYCHAIN" >/dev/null 2>&1 || true
    security list-keychains -d user -s "$KEYCHAIN" "$HOME/Library/Keychains/login.keychain-db"

    rm -f "$p12"
    set_user_trust
    echo "    signing identity ready."
}

sign_app() {
    if ensure_signing_identity; then
        security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN"
        codesign --force --sign "$SIGN_ID" --keychain "$KEYCHAIN" "$APP"
    else
        echo "==> Falling back to ad-hoc signature (permission will need re-granting on each rebuild)."
        codesign --force --deep --sign - "$APP"
    fi
}

echo "==> Building ($APP_NAME, release)..."
swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"

echo "==> Assembling $APP_NAME.app..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

echo "==> Generating app icon..."
rm -rf "$DIST/AppIcon.iconset"
swift "$ROOT/Scripts/make_icon.swift" "$DIST/AppIcon.iconset"
iconutil -c icns "$DIST/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> Code signing..."
sign_app

echo "==> Verifying signature..."
codesign --verify --deep --strict "$APP" && echo "    signature OK"
codesign -d --requirements :- "$APP" 2>/dev/null | grep -oE 'designated = .*' || true

echo "==> Launching $APP_NAME..."
open "$APP"

echo ""
echo "LookHere is running."
echo "If this is the first build with the stable signing identity, grant"
echo "Accessibility permission once:"
echo "  System Settings → Privacy & Security → Accessibility → LookHere"
echo "It will then survive future rebuilds."
echo "Menu bar icon: click to open settings."
echo "Default hotkey: ⇧⌘L to toggle the highlight on/off."