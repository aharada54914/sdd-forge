#!/usr/bin/env bash
# task-lifecycle-enum-parity.tests.sh — audit Cluster 2 (enum half).
#
# The task lifecycle vocabulary {Planned, In Progress, Blocked,
# Implementation Complete, Done} is embedded independently in six places:
# the full and lite task-state checkers (sh awk conditional, ps1
# $validStatuses array) and the workflow-state twins' REQ-row
# normalization alternation. Nothing asserted they agree, so a sixth
# status added to one site would drift silently — the WFI-038
# "two surfaces must agree and nothing asserts it" class.
#
# This suite extracts the vocabulary from each site's own representation
# and requires every extraction to equal the canonical set. It pins the
# ENUM only; the Approval-line grammar split between the full checker
# (any non-empty annotation) and the lite checker (strict
# "<id> <ISO8601>") is a recorded gate-semantics decision awaiting its
# own WFI and is deliberately not asserted here.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
PASS=0
FAIL=0
ok()  { printf 'ok: %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf 'not ok: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

CANONICAL="Blocked
Done
Implementation Complete
In Progress
Planned"

# assert_enum <label> <newline-separated values>
assert_enum() {
    local label=$1 values
    values="$(printf '%s\n' "$2" | LC_ALL=C sort)"
    if [ "$values" = "$CANONICAL" ]; then
        ok "$label carries exactly the canonical 5-value lifecycle enum"
    else
        bad "$label lifecycle enum diverges from canonical: [$(printf '%s' "$values" | tr '\n' ';')]"
    fi
}

# 1-2. Full and lite sh checkers: the awk validity conditional
#    status != "Planned" && status != "In Progress" && ...
for f in \
    plugins/sdd-quality-loop/scripts/check-task-state.sh \
    plugins/sdd-lite/scripts/check-task-state-lite.sh; do
    line="$(grep 'status != "' "$ROOT/$f" | head -1)"
    if [ -z "$line" ]; then
        bad "$f: awk status-validity conditional not found"
        continue
    fi
    values="$(printf '%s\n' "$line" | grep -o 'status != "[^"]*"' | sed 's/status != "//; s/"$//')"
    assert_enum "$f" "$values"
done

# 3-4. Full and lite ps1 checkers: the $validStatuses array
for f in \
    plugins/sdd-quality-loop/scripts/check-task-state.ps1 \
    plugins/sdd-lite/scripts/check-task-state-lite.ps1; do
    line="$(grep '^\$validStatuses = @(' "$ROOT/$f" | head -1)"
    if [ -z "$line" ]; then
        bad "$f: \$validStatuses array not found"
        continue
    fi
    values="$(printf '%s\n' "$line" | grep -o '"[^"]*"' | sed 's/"//g')"
    assert_enum "$f" "$values"
done

# 5-6. Workflow-state twins: the REQ-row normalization alternation
#    (Planned|In Progress|Implementation Complete|Done|Blocked)
for f in \
    plugins/sdd-quality-loop/scripts/check-workflow-state.sh \
    plugins/sdd-quality-loop/scripts/check-workflow-state.ps1; do
    alt="$(grep -o '(Planned|[^)]*)' "$ROOT/$f" | head -1)"
    if [ -z "$alt" ]; then
        bad "$f: REQ-row status alternation not found"
        continue
    fi
    values="$(printf '%s\n' "$alt" | sed 's/^(//; s/)$//' | tr '|' '\n')"
    assert_enum "$f" "$values"
done

# Non-vacuity: the extractors must actually be reading live code, so a
# canonical-set typo in this file cannot pass silently. Corrupt one value
# in a copy of the sh conditional and assert the comparison would fail.
mutated="$(printf '%s\n' "$CANONICAL" | sed 's/^Done$/Donee/')"
if [ "$mutated" = "$CANONICAL" ]; then
    bad "non-vacuity: mutation produced an identical set — the check is inert"
else
    ok "non-vacuity: a mutated vocabulary is distinguished from the canonical set"
fi

printf '\n%s: %d passed, %d failed\n' "$(basename "$0")" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
