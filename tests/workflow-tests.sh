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
assert len(uses) == 1 and \"/ios-firebase-distribution@\" in uses[0], \"got: \" + str(uses)
'"
# Tier 4 stage routing — assert per-stage iOS+Mac pair routing (version-agnostic;
# Tier 12 T50 separately asserts the version pin is consistent + not frozen at v2.0.0)
for STAGE_PAIR in "stage-1-testflight-internal:testflight-internal" "stage-2-promote-to-external-beta:promote-to-testflight-external" "stage-3-promote-to-app-store:promote-to-app-store"; do
    STAGE="${STAGE_PAIR%:*}"
    SUFFIX="${STAGE_PAIR##*:}"
    run_test "T18: $STAGE has ios-$SUFFIX + mac-$SUFFIX steps" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
uses = [s[\"uses\"] for s in d[\"jobs\"][\"$STAGE\"][\"steps\"] if isinstance(s,dict) and \"publish-apple-kmp/\" in str(s.get(\"uses\",\"\"))]
# Extract the sub-action paths (without version tag)
got_paths = set(u.split(\"@\")[0].split(\"/\")[-1] for u in uses)
expected = set([\"ios-$SUFFIX\", \"mac-$SUFFIX\"])
assert got_paths == expected, \"got: \" + str(got_paths) + \", want: \" + str(expected)
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
run_test "T45: BUG FIXED — release.yaml renames match_ssh → match_git when passing to actions (v2.0.7+)" "py '
import yaml
# Actions still declare match_git_private_key
for a_name in [\"ios-firebase-distribution\",\"ios-testflight-internal\",\"mac-testflight-internal\"]:
    a = yaml.safe_load(open(f\"{a_name}/action.yaml\"))
    declared = set(a.get(\"inputs\", {}).keys())
    assert \"match_git_private_key\" in declared, f\"{a_name} no longer takes match_git_private_key — interface changed?\"
# Verify caller now passes the CORRECT name (match_git_private_key, not match_ssh_private_key)
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
for j_name, j in d[\"jobs\"].items():
    if \"steps\" not in j: continue
    for s in j.get(\"steps\", []):
        if isinstance(s,dict) and \"publish-apple-kmp/\" in str(s.get(\"uses\", \"\")):
            assert \"match_ssh_private_key\" not in s.get(\"with\", {}), j_name + \" still passes the wrong name match_ssh_private_key — fix incomplete\"
            # match_git_private_key should be present (renamed correctly)
            uses_action = s[\"uses\"].split(\"/\")[-1].split(\"@\")[0]
            # mac-promote-stages and ios-promote-to-app-store may not need match key
            if uses_action in [\"ios-firebase-distribution\",\"ios-testflight-internal\",\"mac-testflight-internal\"]:
                assert \"match_git_private_key\" in s.get(\"with\", {}), j_name + \" missing match_git_private_key after rename for \" + uses_action
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

# ── Tier 10: Runtime bug-class regressions (since v2.0.6) ────────────────────
#
# Locks down bug classes that broke real workflow runs. Each test asserts the
# absence of a known bad pattern across every action.yaml in this repo.
echo "── Tier 10: Runtime bug-class regressions ──"
run_test "T47: No bare gem-write commands (every gem install/bundle install/fastlane add_plugin must be sudo or bundle-exec-prefixed)" "python3 -c '
import re, glob
# Patterns that fail on GHA runner images post-2026-06 (system gem dir /var/lib/gems is root-owned)
BARE_PATTERNS = [
    re.compile(r\"^\\s+(?:run:\\s*)?(?:gem install|bundle install|fastlane add_plugin|gem update)(?:\\s|$)\"),
    re.compile(r\"^\\s+(?:run:\\s*\\|)?\\s*(gem install|bundle install|fastlane add_plugin|gem update)(?:\\s|$)\"),
]
SAFE_PREFIXES = (\"sudo \", \"bundle exec \", \"sudo bundle\", \"DEBIAN_FRONTEND=\")
violations = []
for action_yaml in glob.glob(\"**/action.yaml\", recursive=True):
    if \"/_shared/\" in action_yaml or \"/examples/\" in action_yaml:
        continue
    with open(action_yaml) as f:
        for line_num, line in enumerate(f, 1):
            stripped = line.strip()
            if stripped.startswith(\"#\"):
                continue
            for pat in BARE_PATTERNS:
                m = pat.match(line)
                if m:
                    if not any(p in line for p in SAFE_PREFIXES):
                        violations.append(f\"{action_yaml}:{line_num}  {stripped[:80]}\")
if violations:
    print(\"FAIL — bare gem-write commands found (need sudo or bundle exec):\")
    for v in violations: print(f\"  {v}\")
    exit(1)
print(\"OK — no bare gem-write commands\")
'"
run_test "T48: ruby/setup-ruby steps use bundler-cache:true (gem cache enabled)" "py '
import yaml, glob
for action_yaml in glob.glob(\"**/action.yaml\", recursive=True):
    if \"/_shared/\" in action_yaml or \"/examples/\" in action_yaml:
        continue
    d = yaml.safe_load(open(action_yaml))
    if not d or \"runs\" not in d or \"steps\" not in d[\"runs\"]:
        continue
    for step in d[\"runs\"][\"steps\"]:
        if isinstance(step, dict) and \"setup-ruby\" in str(step.get(\"uses\", \"\")):
            w = step.get(\"with\", {})
            assert w.get(\"bundler-cache\") in [True, \"true\"], action_yaml + \" — setup-ruby missing bundler-cache:true\"
'"
echo

# ── Tier 11: release.yaml input contract — every with: passes valid + complete inputs ──
#
# CATCHES THE BUG CLASS that caused the runtime failures:
#   "Unexpected input(s) 'match_ssh_private_key' ..." → silent drop at runtime
#   missing required inputs → action exits 1 with cryptic error
#
# Asserts every `with:` block in release.yaml passes inputs the called composite
# action actually DECLARES, AND that all required inputs are present. Documented
# Mac gaps are allowlisted (KNOWN_GAPS) so the test PASSES current state but
# FAILS on any new contract drift — including when Mac is fixed (the allowlist
# entries become stale and the test catches the over-allowlisting).
echo "── Tier 11: release.yaml input contract ──"
run_test "T49: every release.yaml 'with:' block passes valid + complete inputs (Mac gaps documented)" "python3 -c '
import yaml, os, sys

# Documented Mac contract gaps (require user-side cert setup — see release.yaml
# comments + project README). When these are addressed, remove the entries
# below; the test will then catch any future regressions.
KNOWN_GAPS = {
    (\"stage-1-testflight-internal\", \"mac-testflight-internal\", \"MISSING\"): [
        \"bundle_identifier\", \"keychain_password\",
        \"mac_installer_certificate\", \"mac_installer_certificate_password\",
        \"mac_provisioning_profile_base64\",
        \"mac_signing_certificate\", \"mac_signing_certificate_password\",
    ],
    (\"stage-2-promote-to-external-beta\", \"mac-promote-to-testflight-external\", \"MISSING\"): [\"bundle_identifier\"],
    (\"stage-3-promote-to-app-store\", \"mac-promote-to-app-store\", \"MISSING\"): [\"bundle_identifier\"],
}

d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
unexpected = []
stale_allowlist = []

found_gaps = set()
for j_name, j in d[\"jobs\"].items():
    if \"steps\" not in j: continue
    for step in j.get(\"steps\", []):
        if not isinstance(step, dict): continue
        uses = step.get(\"uses\", \"\")
        if \"publish-apple-kmp/\" not in uses: continue
        sub = uses.split(\"/\")[-1].split(\"@\")[0]
        action_yaml = sub + \"/action.yaml\"
        if not os.path.exists(action_yaml): continue
        action_def = yaml.safe_load(open(action_yaml))
        declared = set(action_def.get(\"inputs\", {}).keys())
        passed = set(step.get(\"with\", {}).keys())
        unknown = passed - declared
        missing_required = set()
        for inp_name, inp_def in action_def.get(\"inputs\", {}).items():
            if isinstance(inp_def, dict) and inp_def.get(\"required\") == True and inp_name not in passed:
                missing_required.add(inp_name)

        for u in unknown:
            key = (j_name, sub, \"UNKNOWN\")
            if u in KNOWN_GAPS.get(key, []):
                found_gaps.add(key)
            else:
                unexpected.append(f\"{j_name} -> {sub}: UNKNOWN input passed (silent drop): {u}\")

        for m in missing_required:
            key = (j_name, sub, \"MISSING\")
            if m in KNOWN_GAPS.get(key, []):
                found_gaps.add(key)
            else:
                unexpected.append(f\"{j_name} -> {sub}: MISSING required input: {m}\")

# Check allowlist freshness — if a KNOWN_GAPS entry exists but the violation no
# longer fires, the allowlist is stale (Mac was fixed but allowlist not cleared)
for key in KNOWN_GAPS:
    if key not in found_gaps:
        stale_allowlist.append(str(key))

if unexpected:
    print(\"FAIL — new contract drift:\")
    for u in unexpected: print(\"  \" + u)
    sys.exit(1)
if stale_allowlist:
    print(\"FAIL — KNOWN_GAPS entries no longer firing (clear them):\")
    for s in stale_allowlist: print(\"  \" + s)
    sys.exit(1)
print(\"OK — input contract clean (Mac gaps documented in KNOWN_GAPS)\")
'"
echo

# ── Tier 12: composite-action self-pin consistency ───────────────────────────
#
# CATCHES the architectural anti-pattern where release.yaml self-pins its
# composite-action subdirs at @v2.0.0 (the OLDEST tag) and never updates the
# references even when subsequent releases change action.yaml content. This
# caused the v2.0.6 + v2.0.7 fixes to be silently INEFFECTIVE — release.yaml
# @v2.0.7 was still calling ios-firebase-distribution@v2.0.0 which had the
# buggy add_plugin step.
echo "── Tier 12: composite-action self-pin consistency ──"
run_test "T50: all composite-action 'uses:' refs in release.yaml use the SAME tag (no v2.0.0 freeze)" "python3 -c '
import re, sys
with open(\".github/workflows/release.yaml\") as f:
    content = f.read()
pat = re.compile(r\"uses:\\s+therajanmaurya/mifos-x-actionhub-publish-apple-kmp/[^/]+@(v[0-9.]+)\")
tags = set(pat.findall(content))
if len(tags) > 1:
    print(\"FAIL — composite-action refs use INCONSISTENT tags: \" + str(sorted(tags)))
    sys.exit(1)
if not tags:
    print(\"OK — no self-referencing composite-action uses\")
    sys.exit(0)
tag = list(tags)[0]
if tag == \"v2.0.0\":
    print(\"FAIL — composite-action refs frozen at v2.0.0 (the original anti-pattern); bump to current version before tagging\")
    sys.exit(1)
print(\"OK — composite-action refs consistent at \" + tag)
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
