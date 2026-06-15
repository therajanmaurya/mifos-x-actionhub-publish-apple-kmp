#!/usr/bin/env bash
#
# setup-match.sh — Materialize Fastlane Match SSH key + configure SSH
#
# Decodes MATCH_GIT_PRIVATE_KEY → secrets/match_ci_key (chmod 600) and writes
# ~/.ssh/config with a github.com IdentityFile entry so Match can clone its
# git-stored cert repo over SSH.
#
# Required env: MATCH_GIT_PRIVATE_KEY (base64 OR raw SSH private key)
#
set -euo pipefail
mkdir -p secrets ~/.ssh
chmod 700 ~/.ssh

if [[ -n "${MATCH_GIT_PRIVATE_KEY:-}" ]]; then
  # Detect if already-decoded (raw PEM) or base64-encoded
  if printf '%s' "$MATCH_GIT_PRIVATE_KEY" | head -1 | grep -q 'BEGIN.*PRIVATE KEY'; then
    printf '%s' "$MATCH_GIT_PRIVATE_KEY" > secrets/match_ci_key
  else
    printf '%s' "$MATCH_GIT_PRIVATE_KEY" | base64 --decode > secrets/match_ci_key
  fi
  chmod 600 secrets/match_ci_key

  KEY_ABS="$(cd "$(dirname secrets/match_ci_key)" && pwd)/match_ci_key"
  cat > ~/.ssh/config <<EOF
Host github.com
  IdentityFile $KEY_ABS
  StrictHostKeyChecking no
EOF
  chmod 600 ~/.ssh/config
  echo "✅ Match SSH key materialized + ~/.ssh/config wired"
else
  echo "::warning::MATCH_GIT_PRIVATE_KEY unset — Match cert clone will fail"
fi
