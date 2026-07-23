#!/usr/bin/env bash
# epic-136 Phase 3, Stream D (T-003 / issue #126) -- deterministic-lane
# self-check for the staged workflow candidate.
#
# TEST-016 (AC-016): the candidate preserves the single-job structure, keeps
#   the job count and job names byte-unchanged, prefixes EVERY step inside the
#   `test` job with `[deterministic] `, carries the documented (currently
#   empty) eval-lane comment placeholder, and leaves the LIVE protected
#   workflow file unmodified by the agent.
# TEST-017 (AC-017): RED-then-GREEN. A throwaway fixture with one step name
#   intentionally dropped MUST fail the coverage check first (proving the
#   check catches a real omission); the real candidate then passes it, with
#   `required-checks`' `needs:` membership confirmed byte-unchanged.
# TEST-018 (AC-018): self-improvement.yml and model-freshness-check.yml stay
#   isolated from the test workflow / required-checks graph.
# TEST-020 (AC-020): the candidate carries one CI step per new suite added by
#   T-001 (Stream A) and T-002 (Stream B).
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

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

[ -f "$live_workflow" ] || { echo "FAIL: live workflow not found"; exit 1; }
[ -f "$candidate" ] || { echo "FAIL: staged candidate draft not found: $candidate"; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# ---------------------------------------------------------------------------
# Helper: emit every `- name:` value inside a given job of a workflow file.
# Args: <file> <job-key>
# ---------------------------------------------------------------------------
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

echo "=== TEST-016 (AC-016): candidate structure + live file untouched ==="

live_jobs="$(job_keys "$live_workflow")"
cand_jobs="$(job_keys "$candidate")"
if [ "$live_jobs" = "$cand_jobs" ]; then
    ok "TEST-016: job count and job names are byte-unchanged ($(echo "$live_jobs" | tr '\n' ' '))"
else
    fail "TEST-016: job list diverged -- live=[$live_jobs] candidate=[$cand_jobs]"
fi

unprefixed="$(job_step_names "$candidate" test | grep -cv '^\[deterministic\] ' || true)"
total_steps="$(job_step_names "$candidate" test | wc -l | tr -d ' ')"
if [ "$unprefixed" -eq 0 ]; then
    ok "TEST-016: all $total_steps steps inside the single 'test' job carry the [deterministic] prefix"
else
    fail "TEST-016: $unprefixed of $total_steps 'test'-job steps lack the [deterministic] prefix"
fi

if grep -q '^      # eval-lane: (none yet)$' "$candidate"; then
    ok "TEST-016: the documented, currently-empty eval-lane comment placeholder is present"
else
    fail "TEST-016: the eval-lane comment placeholder is missing from the candidate"
fi

# The agent must never have written the live protected file. Any modification
# would show up as a tracked diff in git.
if git -C "$repo_root" diff --quiet -- .github/workflows/ 2>/dev/null &&
   git -C "$repo_root" diff --cached --quiet -- .github/workflows/ 2>/dev/null; then
    ok "TEST-016: the LIVE protected workflow directory has no agent-authored modification"
else
    fail "TEST-016: the LIVE protected workflow directory is modified -- the agent must never write it"
fi

echo "=== TEST-017 (AC-017): RED-then-GREEN step-coverage self-check ==="

# Capture the pre-change (live) step-name list -- the coverage baseline.
job_step_names "$live_workflow" test > "$work/live-steps.txt"
live_step_count="$(wc -l < "$work/live-steps.txt" | tr -d ' ')"

# coverage_check <candidate-file>: every live step name must survive, carrying
# the [deterministic] prefix. Returns non-zero on the first omission.
coverage_check() {
    local target="$1" missing=0 name
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        if ! grep -Fqx "      - name: [deterministic] ${name}" "$target"; then
            echo "    missing: ${name}"
            missing=$((missing + 1))
        fi
    done < "$work/live-steps.txt"
    [ "$missing" -eq 0 ]
}

# RED: a throwaway pre-candidate fixture with ONE step name dropped.
dropped_step="$(sed -n '3p' "$work/live-steps.txt")"
grep -vFx "      - name: [deterministic] ${dropped_step}" "$candidate" > "$work/red-fixture.draft.yml"
if coverage_check "$work/red-fixture.draft.yml" > "$work/red-output.txt" 2>&1; then
    fail "TEST-017-RED: the dropped-step fixture PASSED the coverage check -- the check is vacuous"
else
    ok "TEST-017-RED: dropped step '${dropped_step}' correctly failed the coverage check (check is non-vacuous)"
fi

# GREEN: the real staged candidate must pass the identical check.
if coverage_check "$candidate" > "$work/green-output.txt" 2>&1; then
    ok "TEST-017-GREEN: all $live_step_count pre-change step names survive in the candidate with the [deterministic] prefix"
else
    fail "TEST-017-GREEN: the real candidate omits step name(s): $(cat "$work/green-output.txt")"
fi

live_needs="$(grep -A6 '^  required-checks:' "$live_workflow" | grep '^    needs:' | head -1 || true)"
cand_needs="$(grep -A6 '^  required-checks:' "$candidate" | grep '^    needs:' | head -1 || true)"
if [ -n "$live_needs" ] && [ "$live_needs" = "$cand_needs" ]; then
    ok "TEST-017: required-checks' needs: line is byte-unchanged (${live_needs# })"
else
    fail "TEST-017: required-checks' needs: diverged -- live=[$live_needs] candidate=[$cand_needs]"
fi

echo "=== TEST-018 (AC-018): sibling workflow isolation unchanged ==="

# AC-018 is about GRAPH isolation, not textual mentions: a sibling workflow
# may legitimately name test.yml in a comment or a PR-body string (
# self-improvement.yml does exactly that). What must stay true is that neither
# sibling is a job of, is reused by, or is depended upon by the test workflow
# -- before or after Stream D's lane marking.
for sibling in self-improvement model-freshness-check; do
    sfile="$workflows_dir/${sibling}.yml"
    if [ ! -f "$sfile" ]; then
        fail "TEST-018: expected sibling workflow not found: ${sibling}.yml"
        continue
    fi
    # A sibling is graph-coupled only if it is reusable-called or its jobs are
    # depended on. Both would appear as a `uses:` pointing at its workflow file.
    if grep -Fq "workflows/${sibling}.yml" "$candidate"; then
        fail "TEST-018: the candidate reuses (uses:) ${sibling}.yml -- isolation broken"
    else
        ok "TEST-018: the candidate does not reuse ${sibling}.yml as a workflow (isolation preserved)"
    fi
    # The sibling must not appear as a job key or a needs: member anywhere.
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
done

# The sibling workflows themselves must keep their own independent triggers --
# neither may be driven by the test workflow's completion.
for sibling in self-improvement model-freshness-check; do
    if grep -q '^  workflow_run:' "$workflows_dir/${sibling}.yml"; then
        fail "TEST-018: ${sibling}.yml is triggered by another workflow's run -- isolation broken"
    else
        ok "TEST-018: ${sibling}.yml keeps its own independent trigger (no workflow_run coupling)"
    fi
done

echo "=== TEST-020 (AC-020): CI step per new suite from T-001 and T-002 ==="

for suite in guard-dispatch-fallback guard-negative-corpus; do
    if grep -Fq "bash ./tests/${suite}.tests.sh" "$candidate"; then
        ok "TEST-020: the candidate runs tests/${suite}.tests.sh"
    else
        fail "TEST-020: the candidate has no CI step running tests/${suite}.tests.sh"
    fi
    # The LIVE file must stay red for these until the human-copy commit lands.
    if grep -Fq "bash ./tests/${suite}.tests.sh" "$live_workflow"; then
        ok "TEST-020: the LIVE workflow already runs tests/${suite}.tests.sh (human-copy applied)"
    else
        ok "TEST-020: the LIVE workflow does not yet run tests/${suite}.tests.sh -- red until the human-copy commit lands (expected, no staged fallback)"
    fi
    if [ -f "$repo_root/tests/${suite}.tests.sh" ]; then
        ok "TEST-020: the referenced suite tests/${suite}.tests.sh exists"
    else
        fail "TEST-020: the candidate references a non-existent suite tests/${suite}.tests.sh"
    fi
done

echo
echo "deterministic-lane-selfcheck.tests.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
