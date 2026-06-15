# Required Fastlane Lanes

Each composite sub-action in this repo runs `bundle exec fastlane <platform> <lane>` against your consumer project's Fastfile. Your `Fastfile` must define the lanes listed below.

Reference implementations are maintained in [`openMF/kmp-project-template/deployment/`](https://github.com/openMF/kmp-project-template/tree/dev/deployment) — fork that as a starting point if you're scaffolding a new consumer.

## iOS lanes (used by `ios-*` sub-actions)

| Lane | Sub-action | What the lane must do |
|---|---|---|
| `ios beta` | `ios-testflight-internal/` | Build signed IPA via Match (appstore profile) → upload to TestFlight |
| `ios deploy_on_firebase` | `ios-firebase-distribution/` | Build signed IPA → upload to Firebase App Distribution |
| `ios release` | `ios-app-store/` | Full rebuild → submit to App Store review |
| `ios build_ios` | `ios-build/` (Debug) | Build unsigned IPA (no codesign) |
| `ios build_signed_ios` | `ios-build/` (Release) | Build signed IPA via Match |
| `ios promoteToExternalBeta` 🆕 | `ios-promote-to-testflight-external/` | `pilot(distribute_only: true, distribute_external: true, submit_beta_review: true)` against existing TF build |
| `ios promoteToAppStore` | `ios-promote-to-app-store/` | `deliver(skip_binary_upload: true, build_number: <latest TF>)` |

## macOS lanes (used by `mac-*` sub-actions)

| Lane | Sub-action | What the lane must do |
|---|---|---|
| `mac desktop_testflight` | `mac-testflight-internal/` | Build signed PKG → upload to Mac TestFlight |
| `mac desktop_release` | `mac-app-store/` | Full rebuild → submit to Mac App Store review |
| `mac promoteMacToExternalBeta` 🆕 | `mac-promote-to-testflight-external/` | `pilot(distribute_only: true, app_platform: "osx", ...)` |
| `mac promoteMacToAppStore` | `mac-promote-to-app-store/` | `deliver(platform: "osx", skip_binary_upload: true, ...)` |
| `mac buildNotarizedMacDmg` 🆕 | `mac-dmg-notarized/` | Match Developer ID install → `createReleaseDistributable` → codesign hardened runtime → hdiutil DMG wrap → Fastlane `notarize` action → `gh release upload` + `gh release edit --prerelease=... --latest=...` |

## Reference implementation

Working lanes — including the 5 NEW ones marked 🆕 — live in `kmp-project-template`:

- iOS: [`deployment/ios/testflight/lane.rb`](https://github.com/openMF/kmp-project-template/blob/dev/deployment/ios/testflight/lane.rb), [`deployment/ios/appstore/lane.rb`](https://github.com/openMF/kmp-project-template/blob/dev/deployment/ios/appstore/lane.rb), [`deployment/ios/firebase/lane.rb`](https://github.com/openMF/kmp-project-template/blob/dev/deployment/ios/firebase/lane.rb)
- macOS: [`deployment/desktop/mac-app-store/lane.rb`](https://github.com/openMF/kmp-project-template/blob/dev/deployment/desktop/mac-app-store/lane.rb), [`deployment/desktop/dmg-notarized/lane.rb`](https://github.com/openMF/kmp-project-template/blob/dev/deployment/desktop/dmg-notarized/lane.rb)
- Shared helpers: [`deployment/_shared/config.rb`](https://github.com/openMF/kmp-project-template/blob/dev/deployment/_shared/config.rb), [`deployment/_shared/lib/`](https://github.com/openMF/kmp-project-template/tree/dev/deployment/_shared/lib)

## Env vars passed by composite actions to your Fastlane process

Every iOS/Mac composite action sets these before invoking `bundle exec fastlane`:

```
APPSTORE_KEY_ID         — ASC API key ID
APPSTORE_ISSUER_ID      — ASC issuer ID
MATCH_PASSWORD          — Match repo passphrase
MATCH_GIT_PRIVATE_KEY   — Match SSH key (or path, after setup-match.sh runs)
```

Plus per-lane:
- Firebase: `FIREBASE_GROUPS` (tester groups list)
- mac-dmg-notarized: `MAC_APP_IDENTIFIER`, `FLAVOR`, `GIT_TAG`, `STAGE`, `AD_HOC_SIGNING`, `GH_TOKEN`, `GITHUB_REPOSITORY`
- promote-external: `BUILD_NUMBER`, `EXTERNAL_GROUPS`

Plus secrets materialized to canonical paths:
- `secrets/AuthKey.p8` — ASC API key (.p8)
- `secrets/match_ci_key` — Match SSH private key
- `~/.ssh/config` — github.com IdentityFile entry
- `secrets/firebaseAppDistributionServiceCredentialsFile.json` — Firebase SA (firebase lane only)

Your Fastfile lanes should read from these paths.

## Fastfile shape

The shared `Fastfile` your project uses should import per-target lane.rb files:

```ruby
# Gemfile
source "https://rubygems.org"
gem "fastlane"
gem "firebase_app_distribution", "1.0.0"

# Fastfile
fastlane_require 'spaceship'
import_from_git(
  url: 'https://github.com/openMF/kmp-project-template',
  branch: 'dev',
  path: 'deployment/fastlane/Fastfile',
)
# OR maintain per-target lane.rb files in your own repo's deployment/ dir
```
