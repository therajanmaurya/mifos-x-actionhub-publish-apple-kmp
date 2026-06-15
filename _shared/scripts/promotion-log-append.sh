#!/usr/bin/env bash
#
# promotion-log-append.sh — Append a row to consumer's deployment/PROMOTION_LOG.yaml
#
# Optional helper for consumers that maintain a per-deploy audit log per
# RULE-DEPLOYMENT-MANIFEST-001 DM6 (12-field schema).
#
# Usage:
#   bash promotion-log-append.sh \
#     --platform <apple|ios|mac> --lane <name> \
#     [--stage <stage>] [--tag <tag>] \
#     --actor <github-actor> --run-id <gh-run-id>
#
# No-op if consumer doesn't have deployment/PROMOTION_LOG.yaml.
#
set -euo pipefail

PLATFORM=""; LANE=""; STAGE=""; TAG=""; ACTOR=""; RUN_ID=""

while [ $# -gt 0 ]; do
  case "$1" in
    --platform) shift; PLATFORM="${1:-}" ;;
    --lane)     shift; LANE="${1:-}"     ;;
    --stage)    shift; STAGE="${1:-}"    ;;
    --tag)      shift; TAG="${1:-}"      ;;
    --actor)    shift; ACTOR="${1:-}"    ;;
    --run-id)   shift; RUN_ID="${1:-}"   ;;
    *)          echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
  shift || true
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG="$REPO_ROOT/deployment/PROMOTION_LOG.yaml"
[[ -f "$LOG" ]] || { echo "📒 deployment/PROMOTION_LOG.yaml not present in consumer — skip"; exit 0; }

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SHA="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
TARGET="${PLATFORM}-${LANE}"
[[ -n "$STAGE" ]] && TARGET="${TARGET}-${STAGE}"
CI_URL="local"
[[ -n "${GITHUB_REPOSITORY:-}" && "$RUN_ID" != "local" ]] && \
  CI_URL="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${RUN_ID}"

cat >> "$LOG" <<EOF

  - timestamp:    "$TS"
    actor:        "${ACTOR:-ci-system}"
    target:       "$TARGET"
    tier:         1
    version_to:   "${TAG:-auto}"
    commit_sha:   "$SHA"
    ci_run_url:   "$CI_URL"
    outcome:      "success"
EOF

echo "📒 Appended PROMOTION_LOG row: $TARGET @ $TS"
