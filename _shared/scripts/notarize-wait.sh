#!/usr/bin/env bash
#
# notarize-wait.sh — Submit DMG/PKG to notarytool + wait + staple
#
# Wraps xcrun notarytool with App Store Connect API key auth. Prefer Fastlane's
# `notarize(...)` action when called from a Fastfile; this script exists for
# bash-only callers.
#
# Required env:
#   PACKAGE       — path to .dmg or .pkg
#   KEY_PATH      — path to ASC API key (.p8)
#   KEY_ID        — ASC API key ID
#   ISSUER_ID     — ASC issuer ID
#
set -euo pipefail

: "${PACKAGE:?PACKAGE required (.dmg or .pkg)}"
: "${KEY_PATH:?KEY_PATH required (.p8)}"
: "${KEY_ID:?KEY_ID required}"
: "${ISSUER_ID:?ISSUER_ID required}"

echo "📤 Submitting $PACKAGE to notarytool..."
xcrun notarytool submit "$PACKAGE" \
  --key "$KEY_PATH" --key-id "$KEY_ID" --issuer "$ISSUER_ID" \
  --wait --output-format json | tee /tmp/notarize.log

# Check status from log
STATUS=$(grep -o '"status":"[^"]*"' /tmp/notarize.log | tail -1 | cut -d'"' -f4)
if [[ "$STATUS" != "Accepted" ]]; then
  echo "::error::Notarization failed with status: $STATUS"
  exit 1
fi

echo "🏷  Stapling..."
xcrun stapler staple "$PACKAGE"
xcrun stapler validate "$PACKAGE"
echo "✅ Notarized + stapled"
