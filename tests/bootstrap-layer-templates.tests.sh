#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
  printf 'PASS: %s\n' "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf 'FAIL: %s\n' "$1"
}

assert_file() {
  path=$1
  label=$2
  if [ -f "$path" ]; then
    pass "$label"
  else
    fail "$label (missing: $path)"
  fi
}

assert_contains() {
  path=$1
  pattern=$2
  label=$3
  if [ -f "$path" ] && grep -Eq "$pattern" "$path"; then
    pass "$label"
  else
    fail "$label"
  fi
}

# Q16 (owner decision 2026-11-28, ADR-0051 decision 2): the checks on the
# retired interviewer's four layer templates (TEST-001..TEST-005) and on its
# tasks/ai-task templates (RT001 legacy fields) retired with those templates.
# The v2 guarantees stay: the Core task template carries the risk field, the
# risk-classification policy keeps its legacy-mode rules, and the Core layers
# contract holds.
assert_contains "$ROOT/plugins/sdd-bootstrap/skills/sdd-core-spec/templates/tasks.md" '^Risk: standard$' "RT001: Core task template carries the risk field"
POLICY="$ROOT/plugins/sdd-quality-loop/references/risk-classification-policy.md"
if grep -q 'legacy mode' "$POLICY" && grep -q 'Do \*\*NOT\*\* map absent to' "$POLICY"; then
  pass "RT001: classification policy states legacy-mode + do-not-map-absent"
else
  fail "RT001: classification policy lost the legacy-mode / do-not-map rule"
fi
# RT-20260821-001 cycle-2 (seq 834): the load-bearing clause itself must be
# pinned - deleting "NO tier minimum" previously left the whole suite green.
if grep -q 'NO tier minimum' "$POLICY"; then
  pass "RT001: policy states the NO-tier-minimum rule clause"
else
  fail "RT001: policy lost the 'NO tier minimum' rule clause"
fi
# Broadened mapping detector. A textual negative can never be complete
# (natural language admits unbounded phrasings); the AUTHORITATIVE guard is
# behavioral - gates.tests.sh T-004.1 pins check-contract's legacy skip. This
# heuristic catches the common mapping phrasings the cycle-2 evaluator
# demonstrated slipping past the old exact-phrase pattern.
if grep -qiE '(absent|missing)[^.]{0,60}(->|→|⇒|maps? to|mapped to|defaults? to|treated as|apply(ing)? the)[^.]{0,30}medium' "$POLICY"    && ! grep -qiE 'Do \*\*NOT\*\* map absent' "$POLICY"; then
  fail "RT001: an absent/missing->medium mapping statement is back in the policy doc"
else
  # the negation sentence itself legitimately contains absent+medium tokens;
  # require it to remain present so the mapping detector cannot be silenced
  # by deleting the negation
  if grep -qiE '(absent|missing)[^.]{0,60}(->|→|⇒|maps? to|mapped to|defaults? to|treated as|apply(ing)? the)[^.]{0,30}medium' "$POLICY"; then
    fail "RT001: mapping-like sentence present without the do-not-map negation"
  else
    pass "RT001: no absent->medium mapping statement in the policy doc (heuristic; behavioral pin is gates T-004.1)"
  fi
fi

if node "$ROOT/tests/lib/bootstrap-core-contracts.mjs" layers; then
  pass "Core layers contract"
else
  fail "Core layers contract"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
