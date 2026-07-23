#!/usr/bin/env bash
# epic-136 Phase 3, Stream D (T-003 / issue #126) -- deterministic-lane
# self-check for the staged workflow candidate.
#
# TEST-016 (AC-016): the candidate preserves the single-job structure, keeps
#   the job count and job names byte-unchanged, and prefixes EVERY step inside
#   the `test` job with `[deterministic] ` -- including steps that were unnamed
#   in the live file (they are given a prefixed name in the candidate). The
#   documented (currently empty) eval-lane comment placeholder is present.
# TEST-017 (AC-017): RED-then-GREEN, IDEMPOTENT. The coverage baseline is the
#   live `test`-job step names with any existing `[deterministic] ` prefix
#   stripped, so the check behaves identically before and after the human
#   applies the candidate to the live file. A throwaway fixture with one
#   baseline name dropped MUST fail the coverage check first; the real
#   candidate then passes it, with `required-checks`' `needs:` membership
#   confirmed byte-unchanged.
# TEST-018 (AC-018): self-improvement.yml and model-freshness-check.yml stay
#   isolated from the test workflow / required-checks graph.
# TEST-020 (AC-020): DESIGNED-RED until human-copy. The LIVE workflow's
#   grep-based self-check for each new suite's basename is expected to FAIL
#   until the human applies the staged candidate as a pre-merge commit -- a red
#   result here, alone, is the correct pre-human-copy fail-closed state
#   (mirrors tests/quality-gate-cycle-limit.tests.sh:434-437), not a defect.
#
# Technique: text markers only (tests/workflow-state-ci-integration.tests.sh
# precedent) -- no YAML-parsing dependency, bash 3.2 compatible.
#
# NOTE ON PATHS: the staged candidate lives at a NON-protected draft path
# because sdd-hook-guard denies every agent write whose path ends with the
# protected workflow suffix, including the human-copy staging path. Placing
# the draft at the human-copy path is a human action; this suite therefore
# verifies the draft, which is byte-identical to what the human places.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
workflows_dir="$repo_root/.github/workflows"
live_workflow="$workflows_dir/test.yml"
candidate="$repo_root/specs/epic-136-phase3/verification/T-003/staged-workflow-candidate.draft.yml"

# The suites this feature's ONE shared human-copy batch registers into the
# LIVE workflow (Stream A, Stream B, and Stream D's own self-check -- REQ-005).
NEW_SUITES="guard-dispatch-fallback guard-negative-corpus deterministic-lane-selfcheck"

PASS=0
FAIL=0
DESIGNED_RED=0
ok() { PASS=$((PASS + 1)); echo "ok: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }
designed_red() { DESIGNED_RED=$((DESIGNED_RED + 1)); echo "DESIGNED-RED (pre-human-copy): $*"; }

[ -f "$live_workflow" ] || { echo "FAIL: live workflow not found"; exit 1; }
[ -f "$candidate" ] || { echo "FAIL: staged candidate draft not found: $candidate"; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# ---------------------------------------------------------------------------
# Helpers (text markers only; bash 3.2 safe)
# ---------------------------------------------------------------------------
# Emit every `- name:` value inside <job> of <file>.
job_step_names() {
    python3 - "$1" "$2" <<'PY'
import sys
path, job = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().split("\n")
start = end = None
for i, ln in enumerate(lines):
    if ln == "  %s:" % job:
        start = i
        continue
    if start is not None and i > start and ln.startswith("  ") \
            and not ln.startswith("   ") and ln.rstrip().endswith(":"):
        end = i
        break
if start is None:
    raise SystemExit("job not found: %s" % job)
if end is None:
    end = len(lines)
for ln in lines[start:end]:
    if ln.startswith("      - name: "):
        print(ln[len("      - name: "):])
PY
}

# Count total step entries (lines beginning "      - ") inside <job> of <file>.
job_step_entry_count() {
    python3 - "$1" "$2" <<'PY'
import sys
path, job = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().split("\n")
start = end = None
for i, ln in enumerate(lines):
    if ln == "  %s:" % job:
        start = i
        continue
    if start is not None and i > start and ln.startswith("  ") \
            and not ln.startswith("   ") and ln.rstrip().endswith(":"):
        end = i
        break
if end is None:
    end = len(lines)
print(sum(1 for ln in lines[start:end] if ln.startswith("      - ")))
PY
}

job_keys() {
    python3 - "$1" <<'PY'
import sys
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
injobs = False
for ln in lines:
    if ln.rstrip() == "jobs:":
        injobs = True
        continue
    if injobs:
        if ln and not ln.startswith(" "):
            break
        if ln.startswith("  ") and not ln.startswith("   ") and ln.rstrip().endswith(":"):
            print(ln.strip().rstrip(":"))
PY
}

echo "=== TEST-016 (AC-016): candidate structure, every step prefixed ==="

live_jobs="$(job_keys "$live_workflow")"
cand_jobs="$(job_keys "$candidate")"
if [ "$live_jobs" = "$cand_jobs" ]; then
    ok "TEST-016: job count and job names are byte-unchanged ($(echo "$live_jobs" | tr '\n' ' '))"
else
    fail "TEST-016: job list diverged -- live=[$live_jobs] candidate=[$cand_jobs]"
fi

# EVERY step must be prefixed: the number of prefixed `- name:` lines must equal
# the total number of step entries, so an unnamed step (which cannot carry a
# prefix) makes the counts diverge and fails this assertion.
cand_named="$(job_step_names "$candidate" test | wc -l | tr -d ' ')"
cand_prefixed="$(job_step_names "$candidate" test | grep -c '^"\[deterministic\] ' || true)"
cand_entries="$(job_step_entry_count "$candidate" test | tr -d ' ')"
if [ "$cand_prefixed" -eq "$cand_entries" ] && [ "$cand_named" -eq "$cand_entries" ]; then
    ok "TEST-016: all $cand_entries 'test'-job step entries are named AND carry the [deterministic] prefix (no unnamed step)"
else
    fail "TEST-016: step-entry/name/prefix counts diverge -- entries=$cand_entries named=$cand_named prefixed=$cand_prefixed (an unnamed or unprefixed step exists)"
fi

if grep -q '^      # eval-lane: (none yet)$' "$candidate"; then
    ok "TEST-016: the documented, currently-empty eval-lane comment placeholder is present"
else
    fail "TEST-016: the eval-lane comment placeholder is missing from the candidate"
fi

# AC-016 is scoped as document/YAML conformance, so the candidate must be a
# LOADABLE YAML document -- not merely the right lines. The `[deterministic] `
# prefix is exactly the hazard here: an UNQUOTED scalar beginning with `[`
# opens a YAML flow sequence and makes the whole file unparseable, which no
# text-marker assertion can see. This check is dependency-free and fails
# closed; a real parser run is added on top when one is available.
bad_scalar="$(python3 - "$candidate" <<'PY'
import sys
bad = []
for n, ln in enumerate(open(sys.argv[1], encoding="utf-8").read().split("\n"), 1):
    if not ln.startswith("      - name: "):
        continue
    value = ln[len("      - name: "):].strip()
    if value[:1] in ('[', '{', '*', '&', '!', '%', '@', '`', ','):
        bad.append("%d:%s" % (n, value[:40]))
print("\n".join(bad))
PY
)"
if [ -z "$bad_scalar" ]; then
    ok "TEST-016: every 'test'-job step name is a YAML-safe scalar (no unquoted flow-sequence opener)"
else
    fail "TEST-016: unquoted step name(s) open a YAML flow sequence -- the document would not load: $(echo "$bad_scalar" | tr '\n' ' ')"
fi

if command -v ruby >/dev/null 2>&1; then
    if ruby -ryaml -e 'YAML.load_file(ARGV[0])' "$candidate" >/dev/null 2>&1; then
        ok "TEST-016: the candidate parses as YAML (ruby/Psych)"
    else
        fail "TEST-016: the candidate does NOT parse as YAML (ruby/Psych) -- applying it would make the workflow unloadable"
    fi
else
    echo "note: ruby not available; YAML parseability rests on the scalar-shape check above"
fi

echo "=== TEST-017 (AC-017): idempotent RED-then-GREEN step-coverage self-check ==="

# Baseline = live step names with any existing [deterministic] prefix stripped.
# Stripping makes the check idempotent: pre-apply the live names are bare, post-
# apply they already carry the prefix, and both reduce to the same base set.
job_step_names "$live_workflow" test | sed -e 's/^"\[deterministic\] //' -e 's/"$//' > "$work/base-steps.txt"
base_count="$(wc -l < "$work/base-steps.txt" | tr -d ' ')"

# coverage_check <file>: every baseline name must appear PREFIXED in <file>.
coverage_check() {
    local target="$1" missing=0 name
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        if ! grep -Fqx "      - name: \"[deterministic] ${name}\"" "$target"; then
            echo "    missing: ${name}"
            missing=$((missing + 1))
        fi
    done < "$work/base-steps.txt"
    [ "$missing" -eq 0 ]
}

# RED: drop one baseline name's prefixed line from a candidate copy.
dropped_step="$(sed -n '3p' "$work/base-steps.txt")"
grep -vFx "      - name: \"[deterministic] ${dropped_step}\"" "$candidate" > "$work/red-fixture.draft.yml"
if coverage_check "$work/red-fixture.draft.yml" > "$work/red-output.txt" 2>&1; then
    fail "TEST-017-RED: the dropped-step fixture PASSED the coverage check -- the check is vacuous"
else
    ok "TEST-017-RED: dropped step '${dropped_step}' correctly failed the coverage check (check is non-vacuous)"
fi

# GREEN: the real candidate passes.
if coverage_check "$candidate" > "$work/green-output.txt" 2>&1; then
    ok "TEST-017-GREEN: all $base_count baseline step names appear in the candidate with the [deterministic] prefix (idempotent pre/post apply)"
else
    fail "TEST-017-GREEN: the candidate omits baseline step name(s): $(cat "$work/green-output.txt")"
fi

live_needs="$(grep -A6 '^  required-checks:' "$live_workflow" | grep '^    needs:' | head -1 || true)"
cand_needs="$(grep -A6 '^  required-checks:' "$candidate" | grep '^    needs:' | head -1 || true)"
if [ -n "$live_needs" ] && [ "$live_needs" = "$cand_needs" ]; then
    ok "TEST-017: required-checks' needs: line is byte-unchanged (${live_needs# })"
else
    fail "TEST-017: required-checks' needs: diverged -- live=[$live_needs] candidate=[$cand_needs]"
fi

echo "=== TEST-018 (AC-018): sibling workflow graph isolation unchanged ==="

for sibling in self-improvement model-freshness-check; do
    sfile="$workflows_dir/${sibling}.yml"
    if [ ! -f "$sfile" ]; then
        fail "TEST-018: expected sibling workflow not found: ${sibling}.yml"
        continue
    fi
    if grep -Fq "workflows/${sibling}.yml" "$candidate"; then
        fail "TEST-018: the candidate reuses (uses:) ${sibling}.yml -- isolation broken"
    else
        ok "TEST-018: the candidate does not reuse ${sibling}.yml as a workflow (isolation preserved)"
    fi
    if job_keys "$candidate" | grep -Fqx "$sibling"; then
        fail "TEST-018: ${sibling} appears as a job in the candidate -- isolation broken"
    else
        ok "TEST-018: ${sibling} is not a job in the candidate (isolation preserved)"
    fi
    if grep '^    needs:' "$candidate" | grep -Fq "$sibling"; then
        fail "TEST-018: ${sibling} appears in a needs: list in the candidate -- isolation broken"
    else
        ok "TEST-018: ${sibling} appears in no needs: list in the candidate (isolation preserved)"
    fi
    if grep -q '^  workflow_run:' "$sfile"; then
        fail "TEST-018: ${sibling}.yml is triggered by another workflow's run -- isolation broken"
    else
        ok "TEST-018: ${sibling}.yml keeps its own independent trigger (no workflow_run coupling)"
    fi
done

echo "=== TEST-020 (AC-020): CI step per new suite, DESIGNED-RED until human-copy ==="

for suite in $NEW_SUITES; do
    if grep -Fq "bash ./tests/${suite}.tests.sh" "$candidate"; then
        ok "TEST-020: the candidate runs tests/${suite}.tests.sh"
    else
        fail "TEST-020: the candidate has no CI step running tests/${suite}.tests.sh"
    fi
    if [ -f "$repo_root/tests/${suite}.tests.sh" ]; then
        ok "TEST-020: the referenced suite tests/${suite}.tests.sh exists"
    else
        fail "TEST-020: the candidate references a non-existent suite tests/${suite}.tests.sh"
    fi
    # Designed fail-closed window: the LIVE file must run the suite. Until the
    # human applies the candidate, it does not -- that red result is intended.
    if grep -Fq "bash ./tests/${suite}.tests.sh" "$live_workflow"; then
        ok "TEST-020: the LIVE workflow runs tests/${suite}.tests.sh (human-copy already applied)"
    else
        designed_red "TEST-020 (AC-020, DESIGNED-RED): the LIVE .github/workflows/test.yml does NOT yet run tests/${suite}.tests.sh -- expected until the human-copy pre-merge commit lands (no staged fallback)"
    fi
done

echo
echo "deterministic-lane-selfcheck.tests.sh: $PASS passed, $FAIL failed, $DESIGNED_RED designed-red (pre-human-copy)"
# A designed-red result counts as a non-zero exit, matching the fail-closed
# precedent (quality-gate-cycle-limit.tests.sh): the suite is intentionally red
# until the human-copy candidate is applied to the live workflow, then green.
if [ "$FAIL" -ne 0 ] || [ "$DESIGNED_RED" -ne 0 ]; then
    exit 1
fi
exit 0
