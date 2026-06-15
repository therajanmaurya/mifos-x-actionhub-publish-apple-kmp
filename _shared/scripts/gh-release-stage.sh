#!/usr/bin/env bash
#
# gh-release-stage.sh — Apply GH Release prerelease + latest flags per direct-distro ladder
#
# Used by mac-dmg-notarized to flip stage flags. Lifted from
# kmp-project-template/deployment/_shared/scripts/gh-release-stage.sh.
#
# Usage:
#   bash gh-release-stage.sh <tag> <stage>
# Where <stage> ∈ {prerelease, beta, stable}.
#
set -euo pipefail

TAG="${1:?tag required}"
STAGE="${2:-stable}"

case "$STAGE" in
  prerelease) PRERELEASE=true;  LATEST=false ;;
  beta)       PRERELEASE=false; LATEST=false ;;
  stable)     PRERELEASE=false; LATEST=true  ;;
  *)          echo "Invalid STAGE: $STAGE" >&2; exit 2 ;;
esac

REPO_ARG=()
[[ -n "${GITHUB_REPOSITORY:-}" ]] && REPO_ARG=(--repo "$GITHUB_REPOSITORY")

gh release edit "$TAG" --prerelease="$PRERELEASE" --latest="$LATEST" "${REPO_ARG[@]}" >/dev/null
echo "🏷  Release $TAG → prerelease=$PRERELEASE, latest=$LATEST"
