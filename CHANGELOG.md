# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## v2.0.0 — Constellation consolidation (planned)

### Added

**iOS section (6 sub-actions)**:
- `ios-build/` — lifted from `openMF/mifos-x-actionhub-build-ios-app@v1.0.14`
- `ios-firebase-distribution/` — lifted from `openMF/mifos-x-actionhub-publish-ios-on-firebase@v1.0.14`
- `ios-testflight-internal/` — lifted from `openMF/mifos-x-actionhub-publish-ios-on-appstore-testflight@v1.0.14`
- `ios-promote-to-testflight-external/` 🆕 — Fastlane `pilot(distribute_only: true)` wrap; submits existing TF build to Apple beta review
- `ios-app-store/` — lifted from `openMF/mifos-x-actionhub-publish-ios-on-appstore@v1.0.14`
- `ios-promote-to-app-store/` 🆕 — Fastlane `deliver` with existing TF build_number

**macOS section (7 sub-actions)**:
- `mac-build/` — Compose Desktop Mac build
- `mac-testflight-internal/` — lifted from `openMF/mifos-x-actionhub-publish-macos-on-appstore-testflight-kmp@v1.0.14`
- `mac-promote-to-testflight-external/` 🆕 — Mac equivalent of iOS external promote (app_platform: "osx")
- `mac-app-store/` — lifted from `openMF/mifos-x-actionhub-publish-macos-on-appstore-kmp@v1.0.14`
- `mac-promote-to-app-store/` 🆕 — Fastlane `deliver` with existing Mac TF build_number
- `mac-dmg-notarized/` 🆕 — Fastlane Match-managed Developer ID + native `notarize` action. Reference implementation lifted from `workspaces/mifos-x/kmp-project-template/source/kmp-project-template/deployment/desktop/dmg-notarized/lane.rb`.
- `mac-dmg-unsigned/` 🆕 — Ad-hoc codesign for trusted-device dev builds

**Shared infrastructure**:
- `_shared/scripts/{setup-match,setup-asc-api,materialize-apple-secrets,codesign-deep,notarize-wait,gh-release-stage,promotion-log-append}.sh`
- `_shared/lib/{appstore_helpers,version_helpers,deploy_helpers}.rb` — Ruby Fastlane helpers (lifted from `deployment/_shared/lib/`)
- `_shared/fastlane/Fastfile.shared` — common lane includes

**CI**:
- `.github/workflows/pr-check.yaml` — matrix-tests every sub-action on PR
- `.github/workflows/release.yaml` — auto-tags `v2.0.X` + rolling `@v2` on merge

### Supersedes (6-month deprecation window from 2026-09-01)

- `openMF/mifos-x-actionhub-build-ios-app`
- `openMF/mifos-x-actionhub-publish-ios-on-firebase`
- `openMF/mifos-x-actionhub-publish-ios-on-appstore-testflight`
- `openMF/mifos-x-actionhub-publish-ios-on-appstore`
- `openMF/mifos-x-actionhub-publish-macos-on-appstore-testflight-kmp`
- `openMF/mifos-x-actionhub-publish-macos-on-appstore-kmp`

Old refs continue working via 301 redirect during grace period.

### Refs

- Epic: `actionhub-constellation-consolidation`
- Companion repos: `openMF/mifos-x-actionhub-publish-android-kmp@v2.0.0`, `openMF/mifos-x-actionhub-publish-desktop-kmp@v2.0.0`, `openMF/mifos-x-actionhub-publish-web-kmp@v2.0.0`
- Orchestrator: `openMF/mifos-x-actionhub@v1.0.17` — adds `release-apple.yaml` reusable workflow
