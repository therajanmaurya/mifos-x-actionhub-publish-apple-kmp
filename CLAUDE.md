# CLAUDE.md — mifos-x-actionhub-publish-apple-kmp (Tier 3 — iOS + macOS)

> **You are in a TIER-3 PUBLISH repo.** Before editing anything, check whether
> the change actually belongs in the **orchestrator** (`openMF/mifos-x-actionhub`).
> Full decision guide: [`mifos-x-actionhub/CONTRIBUTING.md`](https://github.com/openMF/mifos-x-actionhub/blob/main/CONTRIBUTING.md)

## The 3-tier chain

```
Consumer (kmp-project-template + forks)        Tier 1 — thin wrapper
    └─ uses @v1.0.X →
openMF/mifos-x-actionhub                       Tier 2 — orchestrator
    └─ uses @v2.0.X →
publish-android-kmp                            Tier 3 — Android ladder
publish-apple-kmp (THIS REPO)                  Tier 3 — iOS + macOS
publish-desktop-kmp                            Tier 3 — Windows + Linux
publish-web-kmp                                Tier 3 — Web hosts
```

This repo serves **both iOS and macOS** via a single `platform` input
(`platform: ios | mac`) — they share Apple Dev Program / Match infra.

## What lives here (Apple-specific)

| Concern | File | Owns |
|---|---|---|
| Ladder workflow | `.github/workflows/release.yaml` | rungs: firebase (iOS only) → internal → beta → production |
| Composite actions | `ios-*/action.yaml`, `mac-*/action.yaml` | per-rung Xcode build, Match codesign, TestFlight upload |
| Validate-secrets preflight | `release.yaml#validate-secrets` | fail-fast on missing appstore_* / match_* / firebase_creds |

## "Should this change go HERE or in the orchestrator?"

### ✅ Edit HERE when…
- Adding/removing a rung
- Changing Xcode build flags, scheme, target
- Updating Fastlane Match flow (signing identity, provisioning profile pull)
- Changing TestFlight/App Store upload logic
- Adding Apple-specific secrets (e.g. new ASC API key, notarization cert)
- Changing GitHub Environment names (`ios-testflight-internal` → `ios-tf-internal`)
- Bumping macOS runner image, Xcode version, CocoaPods version
- Adjusting `validate-secrets` env list

### ❌ DON'T edit here — go to orchestrator when…
- Changing the consumer-facing `workflow_dispatch` form
- Adding cross-platform validation
- Changing `version_tag` auto-compute logic (App Store-specific sanitization happens in lanes — that IS here)
- Renaming a shared secret → update `V2_GUIDE.md` first

## Versioning

| Bump | When |
|---|---|
| Patch (`v2.0.4` → `v2.0.5`) | any change inside the ladder |
| Minor (`v2.0.X` → `v2.1.0`) | new rung added |
| Major (`v2.X.X` → `v3.0.0`) | breaking — secret renamed, rung removed, platform input schema change |

After merging:
1. Tag `v2.0.{X+1}` on `main`
2. Bump orchestrator's `publish-apple-kmp/.github/workflows/release.yaml@v2.0.{X}` → `@v2.0.{X+1}`
3. Tag orchestrator patch, bump consumer wrappers

## Apple secret schema (canonical names — match orchestrator's V2_GUIDE.md)

| Name | Used at | Content |
|---|---|---|
| `appstore_key_id` | always | App Store Connect API Key ID |
| `appstore_issuer_id` | always | App Store Connect Issuer ID |
| `appstore_auth_key` | always | Base64 of `.p8` API key file |
| `match_password` | always | Fastlane Match passphrase |
| `match_ssh_private_key` | always | Base64 of SSH key with read access to Match cert repo |
| `firebase_creds` | iOS firebase rung only | Firebase service-account JSON (macOS skips firebase rung) |

## Don't

- ❌ Don't reference floating tags
- ❌ Don't add `appstore_*` secrets without an alphabetic suffix matching V2_GUIDE.md
- ❌ Don't fork the iOS and macOS workflows — they share `release.yaml` by design

## Always

- ✅ Tag immediately after merge
- ✅ Bump orchestrator's ref pin in the same coordinated release
- ✅ When adding a rung for one Apple platform, decide if the other needs it too (often yes)
- ✅ Match canonical lowercase snake_case secret names
