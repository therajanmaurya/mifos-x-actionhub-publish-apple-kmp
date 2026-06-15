#!/usr/bin/env bash
#
# materialize-apple-secrets.sh — Orchestrate Apple Dev Program secret setup
#
# Used by every iOS/Mac sub-action that needs both ASC API + Match. Runs:
#   1. setup-asc-api.sh    (APPSTORE_AUTH_KEY_B64 → secrets/AuthKey.p8)
#   2. setup-match.sh      (MATCH_GIT_PRIVATE_KEY → secrets/match_ci_key + ~/.ssh/config)
#   3. (optional) Firebase creds when --firebase flag passed
#
# Required env:
#   APPSTORE_AUTH_KEY_B64   — base64 .p8
#   MATCH_GIT_PRIVATE_KEY   — base64 OR raw SSH key
# Optional env (with --firebase):
#   FIREBASE_CREDS_B64      — base64 Firebase SA JSON
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/setup-asc-api.sh"
bash "$SCRIPT_DIR/setup-match.sh"

# Process flags
for arg in "$@"; do
  case "$arg" in
    --firebase)
      if [[ -n "${FIREBASE_CREDS_B64:-}" ]]; then
        echo "$FIREBASE_CREDS_B64" | base64 --decode > secrets/firebaseAppDistributionServiceCredentialsFile.json
        chmod 600 secrets/firebaseAppDistributionServiceCredentialsFile.json
        echo "✅ Firebase creds materialized"
      fi
      ;;
  esac
done

echo "✅ Apple secrets materialization complete"
