# mifos-x-actionhub-publish-apple-kmp

[![Release](https://img.shields.io/github/v/release/therajanmaurya/mifos-x-actionhub-publish-apple-kmp?label=release&logo=github)](https://github.com/therajanmaurya/mifos-x-actionhub-publish-apple-kmp/releases/latest)
[![PR Check](https://github.com/therajanmaurya/mifos-x-actionhub-publish-apple-kmp/actions/workflows/pr-check.yaml/badge.svg)](https://github.com/therajanmaurya/mifos-x-actionhub-publish-apple-kmp/actions/workflows/pr-check.yaml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)

> Composite GitHub Actions for KMP **Apple platforms** (iOS + macOS): build + Firebase Distribution + TestFlight + App Store + Mac App Store + Developer ID notarized DMG. All work that requires an Apple Developer Program account lives here.

## Why "apple", not "ios"

This repo covers iOS **and** macOS — all Apple Dev Program work. Both platforms share:
- Same App Store Connect API key (`.p8`)
- Same Fastlane Match repo for cert management
- Same Apple-shared Fastlane helpers (`appstore_helpers.rb`, `version_helpers.rb`)
- Same notarytool authentication
- Same `pilot`/`deliver` Fastlane actions

Co-locating them is the only way to share this infrastructure without cross-repo coupling.

## What this provides

13 composite sub-actions across two ladders (iOS App Store + Mac App Store) plus the direct-distribution macOS DMG path:

### iOS section

| Sub-action | Stage | Purpose |
|---|---|---|
| [`ios-build/`](./ios-build/) | — | Build iOS IPA (signed or unsigned) |
| [`ios-firebase-distribution/`](./ios-firebase-distribution/) | **Stage 0** — dev/QA | Upload IPA to Firebase App Distribution |
| [`ios-testflight-internal/`](./ios-testflight-internal/) | **Stage 1** — internal | Build + upload IPA to TestFlight (internal testers see it immediately) |
| [`ios-promote-to-testflight-external/`](./ios-promote-to-testflight-external/) | **Stage 2** — external beta | Distribute existing TF build to external testers (Apple beta review, ~24h). No rebuild. 🆕 |
| [`ios-app-store/`](./ios-app-store/) | **Stage 3** — production (rebuild) | Full rebuild + App Store submit. Used for hotfixes. |
| [`ios-promote-to-app-store/`](./ios-promote-to-app-store/) | **Stage 3** — production (promote) | Submit existing TF build to App Review. No rebuild. (preferred path) |

### macOS section

| Sub-action | Stage | Purpose |
|---|---|---|
| [`mac-build/`](./mac-build/) | — | Build Compose Desktop macOS app bundle |
| [`mac-testflight-internal/`](./mac-testflight-internal/) | **MAS Stage 1** — internal | Build PKG + upload to Mac TestFlight |
| [`mac-promote-to-testflight-external/`](./mac-promote-to-testflight-external/) | **MAS Stage 2** — external beta | Distribute existing Mac TF build to external testers. 🆕 |
| [`mac-app-store/`](./mac-app-store/) | **MAS Stage 3** — production (rebuild) | Full rebuild + Mac App Store submit |
| [`mac-promote-to-app-store/`](./mac-promote-to-app-store/) | **MAS Stage 3** — production (promote) | Submit existing Mac TF build to App Review. No rebuild. |
| [`mac-dmg-notarized/`](./mac-dmg-notarized/) | Direct (alt ladder) | Apple Developer ID + notarytool + stapler → GitHub Release 🆕 |
| [`mac-dmg-unsigned/`](./mac-dmg-unsigned/) | Direct (dev only) | Ad-hoc signed DMG for trusted-device dev builds |

## Repository structure

```
.
├── README.md
├── LICENSE
├── CHANGELOG.md
├── action.yaml                                 ← root composite (defaults)
├── .github/workflows/{pr-check,release}.yaml
│
├── ios-build/, ios-firebase-distribution/,
├── ios-testflight-internal/, ios-promote-to-testflight-external/,
├── ios-app-store/, ios-promote-to-app-store/   ← 6 iOS sub-actions
│
├── mac-build/, mac-testflight-internal/,
├── mac-promote-to-testflight-external/,
├── mac-app-store/, mac-promote-to-app-store/,
├── mac-dmg-notarized/, mac-dmg-unsigned/       ← 7 macOS sub-actions
│
├── _shared/
│   ├── scripts/
│   │   ├── setup-match.sh                      ← Match git repo SSH setup (used by 9 subdirs)
│   │   ├── setup-asc-api.sh                    ← ASC API key materialization (used by 10)
│   │   ├── materialize-apple-secrets.sh        ← orchestrates both
│   │   ├── codesign-deep.sh                    ← shared codesign helper (used by Mac actions)
│   │   ├── notarize-wait.sh                    ← notarytool submit + wait
│   │   ├── gh-release-stage.sh                 ← GH Release flag flip (mac-dmg-notarized only)
│   │   └── promotion-log-append.sh
│   ├── lib/                                    ← Ruby Fastlane helpers
│   │   ├── appstore_helpers.rb
│   │   ├── version_helpers.rb
│   │   └── deploy_helpers.rb
│   └── fastlane/
│       └── Fastfile.shared
│
└── examples/
    ├── consumer-release-ios.yml
    └── consumer-release-mac.yml
```

## Quick start — iOS Stage 1 (TestFlight Internal)

```yaml
- uses: openMF/mifos-x-actionhub-publish-apple-kmp/ios-testflight-internal@v2.0.0
  with:
    ios_package_name:       cmp-ios
    shared_module:          cmp-shared
    appstore_key_id:        ${{ secrets.APPSTORE_KEY_ID }}
    appstore_issuer_id:     ${{ secrets.APPSTORE_ISSUER_ID }}
    appstore_auth_key:      ${{ secrets.APPSTORE_AUTH_KEY }}
    match_password:         ${{ secrets.MATCH_PASSWORD }}
    match_ssh_private_key:  ${{ secrets.MATCH_SSH_PRIVATE_KEY }}
```

## Quick start — macOS DMG notarized

```yaml
- uses: openMF/mifos-x-actionhub-publish-apple-kmp/mac-dmg-notarized@v2.0.0
  with:
    mac_bundle_id:          org.example.app
    appstore_key_id:        ${{ secrets.APPSTORE_KEY_ID }}
    appstore_issuer_id:     ${{ secrets.APPSTORE_ISSUER_ID }}
    appstore_auth_key:      ${{ secrets.APPSTORE_AUTH_KEY }}
    match_password:         ${{ secrets.MATCH_PASSWORD }}
    match_ssh_private_key:  ${{ secrets.MATCH_SSH_PRIVATE_KEY }}
    github_tag:             v2026.06.15
    stage:                  prerelease    # prerelease | beta | stable
```

For the **full ladder run with approval gates + supersede semantics**, see the orchestrator at [`openMF/mifos-x-actionhub/.github/workflows/release-apple.yaml`](https://github.com/openMF/mifos-x-actionhub/blob/main/.github/workflows/release-apple.yaml).

## Supersedes (legacy repos)

| Old repo | New path |
|---|---|
| `openMF/mifos-x-actionhub-build-ios-app@v1.0.14` | `./ios-build/@v2.0.0` |
| `openMF/mifos-x-actionhub-publish-ios-on-firebase@v1.0.14` | `./ios-firebase-distribution/@v2.0.0` |
| `openMF/mifos-x-actionhub-publish-ios-on-appstore-testflight@v1.0.14` | `./ios-testflight-internal/@v2.0.0` |
| `openMF/mifos-x-actionhub-publish-ios-on-appstore@v1.0.14` | `./ios-app-store/@v2.0.0` |
| `openMF/mifos-x-actionhub-publish-macos-on-appstore-testflight-kmp@v1.0.14` | `./mac-testflight-internal/@v2.0.0` |
| `openMF/mifos-x-actionhub-publish-macos-on-appstore-kmp@v1.0.14` | `./mac-app-store/@v2.0.0` |

NEW sub-actions (no equivalent in legacy constellation):
- `ios-promote-to-testflight-external/`
- `ios-promote-to-app-store/`
- `mac-promote-to-testflight-external/`
- `mac-promote-to-app-store/`
- `mac-dmg-notarized/`
- `mac-dmg-unsigned/`

## License

[Apache 2.0](./LICENSE)
