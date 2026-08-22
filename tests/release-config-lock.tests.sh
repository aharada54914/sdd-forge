#!/usr/bin/env bash
# release-config-lock.tests.sh — standing lock on the release-gating config
# surfaces (RT-20260821-004, risk-adaptive-layer T-008).
#
# The T-008 quality gate measured that deleting merge_group from test.yml or
# breaking the ruleset JSON passed every gate in CI: the clauses held only by
# direct measurement, with no standing gate locking them. This suite is that
# lock. It asserts structure only — it does not (and cannot) verify what the
# GitHub server actually enforces; that half stays with the T-008 apply
# script's own tests.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

# 1. Ruleset JSON parses and keeps its load-bearing shape.
RULESET="$ROOT/.github/rulesets/main.json"
if [ -f "$RULESET" ] && python3 - "$RULESET" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert isinstance(data, dict), "ruleset root is not an object"
assert data.get("enforcement"), "ruleset has no enforcement field"
rules = data.get("rules")
assert isinstance(rules, list) and rules, "ruleset has no rules array"
PY
then
    ok "ruleset main.json parses and carries enforcement + rules"
else
    fail "ruleset main.json missing, unparseable, or structurally empty"
fi

# 2. CODEOWNERS parses: at least one non-comment rule line of the form
#    <pattern> <owner...> with every owner @-prefixed.
CODEOWNERS="$ROOT/CODEOWNERS"
if [ -f "$CODEOWNERS" ] && python3 - "$CODEOWNERS" <<'PY'
import sys
rules = 0
for line in open(sys.argv[1]):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    parts = line.split()
    assert len(parts) >= 2, f"CODEOWNERS rule has no owner: {line!r}"
    assert all(p.startswith("@") for p in parts[1:]), f"non-@ owner: {line!r}"
    rules += 1
assert rules >= 1, "CODEOWNERS has zero rule lines"
PY
then
    ok "CODEOWNERS parses with at least one valid rule"
else
    fail "CODEOWNERS missing or malformed"
fi

# 3. merge_group trigger is present in the CI workflow.
TEST_YML="$ROOT/.github/workflows/test.yml"
if grep -Eq '^[[:space:]]*merge_group:' "$TEST_YML"; then
    ok "test.yml keeps the merge_group trigger"
else
    fail "test.yml lost the merge_group trigger (release gating hole)"
fi

# 4. The T-008 apply script the ruleset depends on still exists and parses.
APPLY="$ROOT/scripts/apply-branch-protection.sh"
if [ -f "$APPLY" ] && bash -n "$APPLY" 2>/dev/null; then
    ok "apply-branch-protection.sh exists and parses"
else
    fail "apply-branch-protection.sh missing or unparseable"
fi

printf '\nResults: %s passed, %s failed.\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
