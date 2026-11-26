#!/usr/bin/env bash
# The retained task/workflow validators and contract share the five lifecycle
# values. The Core gate accepts exactly the two statuses eligible for review.
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
    if same_enum "$values"; then
        ok "$label carries exactly the canonical 5-value lifecycle enum"
    else
        bad "$label lifecycle enum diverges from canonical: [$(printf '%s' "$values" | tr '\n' ';')]"
    fi
}

# Keep the same comparison live in the negative control without touching the contract.
same_enum() {
    [ "$1" = "$CANONICAL" ]
}

# Extract each persisted-state checker's case-sensitive vocabulary.
f=plugins/sdd-quality-loop/scripts/check-task-state.sh
line="$(grep 'status != "' "$ROOT/$f" | head -1)"
values="$(printf '%s\n' "$line" | grep -o 'status != "[^"]*"' | sed 's/status != "//; s/"$//')"
assert_enum "$f" "$values"

f=plugins/sdd-quality-loop/scripts/check-task-state.ps1
line="$(grep '^\$validStatuses = @(' "$ROOT/$f" | head -1)"
values="$(printf '%s\n' "$line" | grep -o '"[^"]*"' | sed 's/"//g')"
assert_enum "$f" "$values"

# Workflow-state twins: the REQ-row normalization alternation
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

contract="$ROOT/contracts/sdd-forge-mcp-tools.v1.schema.json"
values="$(jq -er '.["$defs"].status.enum[]' "$contract")"
assert_enum "task status contract" "$values"
mutated="$(jq -er '.["$defs"].status.enum | map(if . == "Done" then "Donee" else . end) | sort[]' "$contract")"
if same_enum "$mutated"; then
    bad "contract mutation: renamed Done was accepted"
else
    ok "contract mutation: renamed Done was rejected"
fi
if python3 "$ROOT/tests/lib/core-lifecycle-checks.py" lifecycle; then
    ok "Core gate checks all lifecycle statuses"
else
    bad "Core gate eligibility disagrees with lifecycle"
fi

printf '\n%s: %d passed, %d failed\n' "$(basename "$0")" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
