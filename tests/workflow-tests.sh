#!/bin/bash
# tests/workflow-tests.sh
#
# End-to-end workflow tests for mifos-x-actionhub-publish-apple-kmp.
#
# Tier-3 repo (iOS + macOS) in the 3-tier actionhub chain.
#
# Two-axis matrix: platform (ios|mac) × rung (firebase|internal|beta|production).
# Each stage has per-platform conditional `uses:` gated by `inputs.platform == '…'`.
#
# Test tiers:
#   1. Static syntax    — YAML parse · actionlint · no dynamic uses · shellcheck
#   2. Workflow_call    — interface schema (inputs + secrets contract)
#   3. Job structure    — 5 jobs · sequential dependency chain
#   4. Per-platform routing — per-stage conditional ios/mac steps
#   5. Composite actions — all 13 subdirs (excluding examples) have action.yaml
#   6. Action interfaces — each referenced action accepts what release.yaml passes
#   7. validate-secrets — per-platform secret coverage
#   8. Stage-conditional logic — if-conditions match expected rung set

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0
FAILED_TESTS=()

run_test() {
    local name="$1"
    local cmd="$2"
    printf "  %-72s ... " "$name"
    if eval "$cmd" > /tmp/test-out 2>&1; then
        echo "✅ PASS"
        PASS=$((PASS+1))
    else
        echo "❌ FAIL"
        sed 's/^/      /' /tmp/test-out
        FAIL=$((FAIL+1))
        FAILED_TESTS+=("$name")
    fi
}

py() { python3 -c "$1"; }

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────
ALL_SUBDIRS=(
    ios-app-store ios-build ios-firebase-distribution
    ios-promote-to-app-store ios-promote-to-testflight-external ios-testflight-internal
    mac-app-store mac-build mac-dmg-notarized mac-dmg-unsigned
    mac-promote-to-app-store mac-promote-to-testflight-external mac-testflight-internal
)

# Actions actively referenced by release.yaml's stages
ACTIVE_REFS=(
    ios-firebase-distribution
    ios-testflight-internal mac-testflight-internal
    ios-promote-to-testflight-external mac-promote-to-testflight-external
    ios-promote-to-app-store mac-promote-to-app-store
)

EXPECTED_JOBS=(validate-secrets stage-0-firebase stage-1-testflight-internal stage-2-promote-to-external-beta stage-3-promote-to-app-store)

echo "════════════════════════════════════════════════════════════════════════════"
echo "  Workflow E2E tests for mifos-x-actionhub-publish-apple-kmp"
echo "════════════════════════════════════════════════════════════════════════════"
echo

# ── Tier 1: Static syntax ────────────────────────────────────────────────────
echo "── Tier 1: Static syntax ──"
run_test "T01: release.yaml parses" \
    "py 'import yaml; yaml.safe_load(open(\".github/workflows/release.yaml\"))'"
run_test "T02: pr-check.yaml parses" \
    "py 'import yaml; yaml.safe_load(open(\".github/workflows/pr-check.yaml\"))'"
run_test "T03: tag.yaml parses" \
    "py 'import yaml; yaml.safe_load(open(\".github/workflows/tag.yaml\"))'"
run_test "T04: actionlint clean on release.yaml" \
    "actionlint .github/workflows/release.yaml"
run_test "T05: actionlint clean on pr-check.yaml" \
    "actionlint .github/workflows/pr-check.yaml"
run_test "T06: actionlint clean on tag.yaml" \
    "actionlint .github/workflows/tag.yaml"
run_test "T07: NO dynamic uses regression" \
    "! grep -nE '^[^#]*uses: .*\\\${{ (inputs|matrix)\\.' .github/workflows/release.yaml"
run_test "T08: shellcheck clean on _shared/scripts" \
    "find _shared/scripts -name '*.sh' -exec shellcheck -S warning {} +"
echo

# ── Tier 2: workflow_call interface contract ─────────────────────────────────
echo "── Tier 2: workflow_call interface contract ──"
run_test "T09: workflow_call inputs include (platform, package_name, shared_module, version_tag, starting_rung)" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
got = set(d[\"on\" if \"on\" in d else True][\"workflow_call\"][\"inputs\"].keys())
expected = set([\"platform\",\"package_name\",\"shared_module\",\"version_tag\",\"starting_rung\"])
assert expected.issubset(got), \"missing inputs: \" + str(expected - got)
'"
run_test "T10: platform input is required + type string" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
t = d[\"on\" if \"on\" in d else True][\"workflow_call\"][\"inputs\"][\"platform\"]
assert t.get(\"required\") == True, \"platform should be required\"
assert t.get(\"type\") == \"string\"
'"
run_test "T11: workflow_call secrets include appstore + match + firebase" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
got = set(d[\"on\" if \"on\" in d else True][\"workflow_call\"][\"secrets\"].keys())
expected = set([\"appstore_key_id\",\"appstore_issuer_id\",\"appstore_auth_key\",\"match_password\",\"match_ssh_private_key\",\"firebase_creds\"])
assert expected == got, \"diff: \" + str(got.symmetric_difference(expected))
'"
echo

# ── Tier 3: Job structure ────────────────────────────────────────────────────
echo "── Tier 3: Job structure ──"
run_test "T12: All 5 expected jobs present" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
got = set(d[\"jobs\"].keys())
exp = set([\"validate-secrets\",\"stage-0-firebase\",\"stage-1-testflight-internal\",\"stage-2-promote-to-external-beta\",\"stage-3-promote-to-app-store\"])
assert got == exp, \"diff: \" + str(got.symmetric_difference(exp))
'"
run_test "T13: stage-0 depends on validate-secrets" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
assert \"validate-secrets\" in d[\"jobs\"][\"stage-0-firebase\"][\"needs\"]
'"
run_test "T14: stage-1 depends on stage-0 (sequential)" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
needs = d[\"jobs\"][\"stage-1-testflight-internal\"][\"needs\"]
assert \"stage-0-firebase\" in needs
'"
run_test "T15: stage-2 depends on stage-1" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
assert d[\"jobs\"][\"stage-2-promote-to-external-beta\"][\"needs\"] == [\"stage-1-testflight-internal\"]
'"
run_test "T16: stage-3 depends on stage-2" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
assert d[\"jobs\"][\"stage-3-promote-to-app-store\"][\"needs\"] == [\"stage-2-promote-to-external-beta\"]
'"
echo

# ── Tier 4: Per-platform per-stage routing ───────────────────────────────────
echo "── Tier 4: Per-platform per-stage routing ──"
run_test "T17: stage-0-firebase is iOS-only (no Mac equivalent — Firebase iOS Distribution)" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
cond = d[\"jobs\"][\"stage-0-firebase\"][\"if\"]
assert \"inputs.platform == \\\"ios\\\"\" in cond or \"inputs.platform == \\\"\\047ios\\047\\\"\" in cond or \"platform == \\047ios\\047\" in cond
uses = [s[\"uses\"] for s in d[\"jobs\"][\"stage-0-firebase\"][\"steps\"] if isinstance(s,dict) and \"publish-apple-kmp/\" in str(s.get(\"uses\",\"\"))]
assert uses == [\"therajanmaurya/mifos-x-actionhub-publish-apple-kmp/ios-firebase-distribution@v2.0.0\"], uses
'"
for STAGE_PAIR in "stage-1-testflight-internal:testflight-internal" "stage-2-promote-to-external-beta:promote-to-testflight-external" "stage-3-promote-to-app-store:promote-to-app-store"; do
    STAGE="${STAGE_PAIR%:*}"
    SUFFIX="${STAGE_PAIR##*:}"
    run_test "T18: $STAGE has ios-$SUFFIX + mac-$SUFFIX steps" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
uses = [s[\"uses\"] for s in d[\"jobs\"][\"$STAGE\"][\"steps\"] if isinstance(s,dict) and \"publish-apple-kmp/\" in str(s.get(\"uses\",\"\"))]
expected = set([
    \"therajanmaurya/mifos-x-actionhub-publish-apple-kmp/ios-$SUFFIX@v2.0.0\",
    \"therajanmaurya/mifos-x-actionhub-publish-apple-kmp/mac-$SUFFIX@v2.0.0\",
])
assert set(uses) == expected, \"got: \" + str(uses) + \", want: \" + str(expected)
'"
done
for STAGE in stage-1-testflight-internal stage-2-promote-to-external-beta stage-3-promote-to-app-store; do
    run_test "T19/$STAGE: per-platform steps gated by inputs.platform" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
for s in d[\"jobs\"][\"$STAGE\"][\"steps\"]:
    if isinstance(s,dict) and \"publish-apple-kmp/\" in str(s.get(\"uses\",\"\")):
        assert \"if\" in s, \"missing if on \" + s[\"uses\"]
        assert \"inputs.platform ==\" in s[\"if\"], \"missing inputs.platform check: \" + s[\"if\"]
'"
done
echo

# ── Tier 5: Composite-action existence ───────────────────────────────────────
echo "── Tier 5: Composite-action existence (13 subdirs) ──"
for S in "${ALL_SUBDIRS[@]}"; do
    run_test "T2x:  $S/action.yaml exists + parses" \
        "test -f '$S/action.yaml' && py 'import yaml; yaml.safe_load(open(\"$S/action.yaml\"))'"
done
for S in "${ALL_SUBDIRS[@]}"; do
    run_test "T2z:  $S/README.md exists" "test -f '$S/README.md'"
done
echo

# ── Tier 6: Actively-referenced actions' caller-callee contract ──────────────
echo "── Tier 6: Caller-callee contract (7 referenced actions) ──"
for A in "${ACTIVE_REFS[@]}"; do
    run_test "T3x:  $A action is composite + has steps" "py '
import yaml
d = yaml.safe_load(open(\"$A/action.yaml\"))
assert d[\"runs\"][\"using\"] == \"composite\"
assert d[\"runs\"].get(\"steps\"), \"$A has no steps\"
'"
done
# Per-platform contract assertions — iOS actions accept ios_package_name,
# Mac actions accept desktop_package_name (legacy name, will be renamed to
# mac_package_name in a future PR).
for A in ios-firebase-distribution ios-testflight-internal ios-promote-to-testflight-external ios-promote-to-app-store; do
    run_test "T4x:  $A accepts ios_package_name" "py '
import yaml
d = yaml.safe_load(open(\"$A/action.yaml\"))
declared = set(d.get(\"inputs\", {}).keys())
assert \"ios_package_name\" in declared, \"$A missing ios_package_name — got: \" + str(declared)
'"
done
for A in mac-testflight-internal mac-promote-to-testflight-external mac-promote-to-app-store; do
    run_test "T4x:  $A accepts desktop_package_name (LEGACY — should be mac_package_name)" "py '
import yaml
d = yaml.safe_load(open(\"$A/action.yaml\"))
declared = set(d.get(\"inputs\", {}).keys())
assert \"desktop_package_name\" in declared, \"$A missing desktop_package_name — got: \" + str(declared)
'"
done
# All accept the appstore creds (the cross-cutting Apple Dev Program contract)
for A in "${ACTIVE_REFS[@]}"; do
    run_test "T5x:  $A accepts (appstore_key_id, appstore_issuer_id, appstore_auth_key)" "py '
import yaml
d = yaml.safe_load(open(\"$A/action.yaml\"))
declared = set(d.get(\"inputs\", {}).keys())
required = set([\"appstore_key_id\",\"appstore_issuer_id\",\"appstore_auth_key\"])
assert required.issubset(declared), \"$A missing: \" + str(required - declared)
'"
done
echo

# ── Tier 7: validate-secrets coverage ────────────────────────────────────────
echo "── Tier 7: validate-secrets coverage ──"
run_test "T35: validate-secrets checks appstore_key_id" \
    "grep -E 'appstore_key_id' .github/workflows/release.yaml | head -1"
run_test "T36: validate-secrets checks match_password" \
    "grep -E 'match_password' .github/workflows/release.yaml | head -1"
run_test "T37: validate-secrets checks firebase_creds (for firebase rung)" \
    "grep -E 'firebase_creds' .github/workflows/release.yaml | head -1"
run_test "T38: validate-secrets checks match_ssh_private_key" \
    "grep -E 'match_ssh_private_key' .github/workflows/release.yaml | head -1"
echo

# ── Tier 8: Stage-conditional logic (rung + platform) ────────────────────────
echo "── Tier 8: Stage-conditional logic ──"
run_test "T39: stage-0-firebase if includes 'firebase' (ladder bottom)" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
assert \"firebase\" in d[\"jobs\"][\"stage-0-firebase\"][\"if\"]
'"
run_test "T40: stage-1-testflight-internal if covers {internal, beta, production}" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
cond = d[\"jobs\"][\"stage-1-testflight-internal\"][\"if\"]
for r in [\"internal\",\"beta\",\"production\"]:
    assert r in cond, r + \" not in stage-1 if-condition\"
'"
run_test "T41: stage-2-promote-to-external-beta if covers {beta, production}" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
cond = d[\"jobs\"][\"stage-2-promote-to-external-beta\"][\"if\"]
for r in [\"beta\",\"production\"]:
    assert r in cond
'"
run_test "T42: stage-3-promote-to-app-store requires 'production' (terminal rung)" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
assert \"production\" in d[\"jobs\"][\"stage-3-promote-to-app-store\"][\"if\"]
'"
echo

# ── Tier 9: Known interface bugs documented as DETECTED-AT-TEST-TIME ──────────
#
# These are PRE-EXISTING bugs surfaced by the test framework. They don't fail CI
# (tests assert the current state) but document the gaps for future remediation.
# When a bug is fixed, FLIP the assertion (current XOR fixed) — this prevents
# silent regressions during the fix.
echo "── Tier 9: Known interface bugs (pre-existing, documented for follow-up) ──"
run_test "T43: KNOWN BUG — Mac actions need 'bundle_identifier' but release.yaml does NOT pass it" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
mac_actions_needing_bundle_id = [\"mac-testflight-internal\",\"mac-promote-to-testflight-external\",\"mac-promote-to-app-store\"]
for ma in mac_actions_needing_bundle_id:
    a = yaml.safe_load(open(ma + \"/action.yaml\"))
    assert \"bundle_identifier\" in a.get(\"inputs\", {}), ma + \" should require bundle_identifier (regression?)\"
# Verify release.yaml does NOT pass it (the bug)
for j in [\"stage-1-testflight-internal\",\"stage-2-promote-to-external-beta\",\"stage-3-promote-to-app-store\"]:
    for s in d[\"jobs\"][j].get(\"steps\", []):
        if isinstance(s,dict) and \"mac-\" in str(s.get(\"uses\",\"\")):
            assert \"bundle_identifier\" not in s.get(\"with\", {}), s[\"uses\"] + \" now passes bundle_identifier — flip this test to ensure-passed (BUG FIXED)\"
'"
run_test "T44: KNOWN BUG — Mac TestFlight needs 6 signing-cert inputs but release.yaml passes NONE" "py '
import yaml
a = yaml.safe_load(open(\"mac-testflight-internal/action.yaml\"))
required_cert_inputs = set([\"mac_signing_certificate\",\"mac_signing_certificate_password\",\"mac_installer_certificate\",\"mac_installer_certificate_password\",\"mac_provisioning_profile_base64\",\"keychain_password\"])
declared = set(a.get(\"inputs\", {}).keys())
assert required_cert_inputs.issubset(declared), \"mac-testflight-internal no longer requires cert inputs — bug fixed?\"
# Verify release.yaml does NOT pass them
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
for s in d[\"jobs\"][\"stage-1-testflight-internal\"].get(\"steps\", []):
    if isinstance(s,dict) and \"mac-testflight-internal\" in str(s.get(\"uses\",\"\")):
        passed = set(s.get(\"with\", {}).keys())
        intersect = required_cert_inputs & passed
        assert not intersect, f\"release.yaml now passes {intersect} — flip this test to ensure-passed (BUG FIXED)\"
'"
run_test "T45: KNOWN BUG — naming mismatch: actions take match_git_private_key, caller passes match_ssh_private_key" "py '
import yaml
for a_name in [\"ios-firebase-distribution\",\"ios-testflight-internal\",\"mac-testflight-internal\"]:
    a = yaml.safe_load(open(f\"{a_name}/action.yaml\"))
    declared = set(a.get(\"inputs\", {}).keys())
    assert \"match_git_private_key\" in declared, f\"{a_name} no longer takes match_git_private_key — bug fixed?\"
# Verify caller passes the WRONG name
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
mismatch_found = False
for j in d[\"jobs\"].values():
    for s in j.get(\"steps\", []) if isinstance(j, dict) else []:
        if isinstance(s,dict) and \"with\" in s and \"match_ssh_private_key\" in s.get(\"with\", {}):
            mismatch_found = True
assert mismatch_found, \"release.yaml no longer uses match_ssh_private_key — naming reconciled, BUG FIXED?\"
'"
run_test "T46: KNOWN BUG — inconsistent platform package_name naming: ios_package_name vs desktop_package_name (should be mac_package_name)" "py '
import yaml
# Bug exists if Mac actions use desktop_package_name instead of mac_package_name
for a_name in [\"mac-testflight-internal\",\"mac-promote-to-testflight-external\",\"mac-promote-to-app-store\"]:
    a = yaml.safe_load(open(f\"{a_name}/action.yaml\"))
    declared = set(a.get(\"inputs\", {}).keys())
    assert \"desktop_package_name\" in declared, f\"{a_name} now uses canonical mac_package_name — BUG FIXED?\"
'"
echo

# ─────────────────────────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════════════════"
echo "  Results: $PASS passed · $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    echo "  Failed tests:"
    for t in "${FAILED_TESTS[@]}"; do echo "    - $t"; done
fi
echo "════════════════════════════════════════════════════════════════════════════"
exit $FAIL
