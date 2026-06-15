#!/usr/bin/env bash
#
# codesign-deep.sh — Hardened-runtime deep codesign helper for macOS .app bundles
#
# Used by mac-dmg-notarized sub-action (and any custom flow that needs to
# codesign a built .app with hardened runtime + entitlements).
#
# Usage:
#   IDENTITY=<sha1 or display name> ENTITLEMENTS=<path> APP_PATH=<.app> \
#     bash codesign-deep.sh
#
# Required env:
#   IDENTITY      — codesign identity (SHA1 preferred to avoid ambiguity)
#   ENTITLEMENTS  — path to Entitlements.plist
#   APP_PATH      — path to .app bundle
# Optional env:
#   KEYCHAIN_PATH — explicit keychain to use (else default search list)
#
set -euo pipefail

: "${IDENTITY:?IDENTITY required (SHA1 or display name)}"
: "${ENTITLEMENTS:?ENTITLEMENTS required (path to plist)}"
: "${APP_PATH:?APP_PATH required (.app bundle)}"

KEYCHAIN_ARG=""
[[ -n "${KEYCHAIN_PATH:-}" ]] && KEYCHAIN_ARG="--keychain $KEYCHAIN_PATH"

echo "🔏 Signing $APP_PATH with $IDENTITY..."
codesign --force --deep --options runtime \
  --entitlements "$ENTITLEMENTS" \
  --sign "$IDENTITY" $KEYCHAIN_ARG \
  "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo "✅ .app signed + verified"
