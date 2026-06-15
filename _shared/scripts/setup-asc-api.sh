#!/usr/bin/env bash
#
# setup-asc-api.sh — Materialize App Store Connect API key
#
# Decodes APPSTORE_AUTH_KEY_B64 → secrets/AuthKey.p8 (chmod 600)
# Required env: APPSTORE_AUTH_KEY_B64 (base64 of .p8)
#
set -euo pipefail
mkdir -p secrets
if [[ -n "${APPSTORE_AUTH_KEY_B64:-}" ]]; then
  echo "$APPSTORE_AUTH_KEY_B64" | base64 --decode > secrets/AuthKey.p8
  chmod 600 secrets/AuthKey.p8
  echo "✅ ASC API key materialized at secrets/AuthKey.p8"
else
  echo "::warning::APPSTORE_AUTH_KEY_B64 unset — secrets/AuthKey.p8 not created"
fi
