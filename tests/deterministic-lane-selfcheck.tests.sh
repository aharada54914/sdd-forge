#!/usr/bin/env bash
# epic-136 Phase 3, Stream D (T-003 / issue #126) -- deterministic-lane
# self-check for the current workflow (or an explicitly supplied candidate).
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
#   candidate then passes it, with `required-checks`' complete `needs:` list
#   (membership AND order) confirmed unchanged.
# TEST-018 (AC-018): self-improvement.yml and model-freshness-check.yml stay
#   isolated from the test workflow / required-checks graph.
# TEST-020 (AC-020): DESIGNED-RED until human-copy. The LIVE workflow's
#   grep-based self-check for each new suite's basename is expected to FAIL
#   until the human applies the staged candidate as a pre-merge commit -- a red
#   result here, alone, is the correct pre-human-copy fail-closed state
#   (mirrors tests/quality-gate-cycle-limit.tests.sh:434-437), not a defect.
#
# Technique: job names, step names/count and `needs:` come from the repo's
# structural loader (tests/verification-workflow.py load_workflow), parsed once
# per workflow into JSON, so quoting and line-wrapping style cannot change what
# is observed. Text markers remain only for things YAML parsing discards
# (comments) or that are plain substrings (suite commands, checkout pins).
# bash 3.2 compatible.
#
# The historical phase3 draft is superseded and must never be applied over
# newer jobs. With no arguments validate the live workflow. An optional first
# argument validates a proposed workflow before human application; a second
# argument enables a separate baseline/candidate preservation comparison.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
workflows_dir="$repo_root/.github/workflows"
live_workflow="${1:-$workflows_dir/test.yml}"
candidate="${2:-$live_workflow}"

# The suites this feature's ONE shared human-copy batch registers into the
# LIVE workflow (Stream A, Stream B, Stream C, and Stream D's own self-check
# -- REQ-005 / AC-019 / AC-020). Stream C joined this batch once ADR-0010's
# `Status: Accepted` promotion unblocked it and its suite landed here.
# Repo-relative PATHS, not bare basenames: Stream C's suite lives one
# directory down (tests/workflow-scenarios/), so a basename-only list cannot
# address it.
NEW_SUITES="tests/guard-dispatch-fallback.tests.sh tests/guard-negative-corpus.tests.sh tests/deterministic-lane-selfcheck.tests.sh tests/workflow-scenarios/workflow-scenarios.tests.sh"

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
# Structural parse (once) + helpers; bash 3.2 safe
# ---------------------------------------------------------------------------
live_json="$work/live.json"
cand_json="$work/cand.json"
python3 -I - "$repo_root" "$live_workflow" "$live_json" "$candidate" "$cand_json" <<'PY' \
    || { echo "FAIL: structural workflow parse failed (invalid YAML or parser unavailable)"; exit 1; }
import importlib.util, json, sys
from pathlib import Path
root, *pairs = sys.argv[1:]
spec = importlib.util.spec_from_file_location(
    "verification_workflow", Path(root) / "tests" / "verification-workflow.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
for src, dst in zip(pairs[0::2], pairs[1::2]):
    Path(dst).write_text(json.dumps(module.load_workflow(Path(src), Path(root))), encoding="utf-8")
PY

# wf_query <json> jobs | steps <job> | needs [<job>]
#   jobs : job keys, in order
#   steps: one line per step of <job> (its name; empty line if unnamed)
#   needs: with <job>, its full `needs` as JSON (order preserved); without,
#          one `job:need` line per dependency of every job
wf_query() {
    python3 -I - "$@" <<'PY'
import json, sys
wf = json.load(open(sys.argv[1], encoding="utf-8"))
kind, jobs = sys.argv[2], wf["jobs"]
if kind == "jobs":
    print("\n".join(jobs))
elif kind == "steps":
    for step in jobs[sys.argv[3]].get("steps", []):
        print(step.get("name", ""))
elif len(sys.argv) > 3:
    print(json.dumps(jobs[sys.argv[3]].get("needs")))
else:
    for key, job in jobs.items():
        needs = job.get("needs") or []
        for need in [needs] if isinstance(needs, str) else needs:
            print("%s:%s" % (key, need))
PY
}

echo "=== TEST-016 (AC-016): candidate structure, every step prefixed ==="

live_jobs="$(wf_query "$live_json" jobs)"
cand_jobs="$(wf_query "$cand_json" jobs)"
if [ "$live_jobs" = "$cand_jobs" ]; then
    ok "TEST-016: job count and job names are byte-unchanged ($(echo "$live_jobs" | tr '\n' ' '))"
else
    fail "TEST-016: job list diverged -- live=[$live_jobs] candidate=[$cand_jobs]"
fi

# EVERY step must be prefixed: the number of prefixed names must equal the
# total number of step entries, so an unnamed step (which cannot carry a
# prefix) makes the counts diverge and fails this assertion.
wf_query "$cand_json" steps test > "$work/cand-steps.txt"
cand_entries="$(wc -l < "$work/cand-steps.txt" | tr -d ' ')"
cand_named="$(grep -c . "$work/cand-steps.txt" || true)"
cand_prefixed="$(grep -c '^\[deterministic\] ' "$work/cand-steps.txt" || true)"
if [ "$cand_prefixed" -eq "$cand_entries" ] && [ "$cand_named" -eq "$cand_entries" ]; then
    ok "TEST-016: all $cand_entries 'test'-job step entries are named AND carry the [deterministic] prefix (no unnamed step)"
else
    fail "TEST-016: step-entry/name/prefix counts diverge -- entries=$cand_entries named=$cand_named prefixed=$cand_prefixed (an unnamed or unprefixed step exists)"
fi

# Comments are discarded by the YAML parser, so this stays a text marker.
if grep -q '^      # eval-lane: (none yet)$' "$candidate"; then
    ok "TEST-016: the documented, currently-empty eval-lane comment placeholder is present"
else
    fail "TEST-016: the eval-lane comment placeholder is missing from the candidate"
fi

# AC-016 is scoped as document/YAML conformance, so the candidate must be a
# LOADABLE YAML document -- not merely the right lines. The structural parse
# above already fails closed on invalid YAML; this raw check additionally
# flags the hazard directly: an UNQUOTED scalar beginning with `[` opens a YAML
# flow sequence and makes the whole file unparseable.
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
    echo "note: ruby not available; YAML parseability rests on the structural parse above"
fi

echo "=== TEST-017 (AC-017): idempotent RED-then-GREEN step-coverage self-check ==="

# Baseline = live step names with any existing [deterministic] prefix stripped.
# Stripping makes the check idempotent: pre-apply the live names are bare, post-
# apply they already carry the prefix, and both reduce to the same base set.
wf_query "$live_json" steps test | sed -e 's/^\[deterministic\] //' > "$work/base-steps.txt"
base_count="$(wc -l < "$work/base-steps.txt" | tr -d ' ')"

# coverage_check <workflow.json>: every baseline name must appear PREFIXED among
# the parsed `test`-job step names of <workflow.json>.
coverage_check() {
    local target="$1" missing=0 name
    wf_query "$target" steps test > "$work/coverage-names.txt"
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        if ! grep -Fqx "[deterministic] ${name}" "$work/coverage-names.txt"; then
            echo "    missing: ${name}"
            missing=$((missing + 1))
        fi
    done < "$work/base-steps.txt"
    [ "$missing" -eq 0 ]
}

# RED: delete the actual third `test`-job step from the parsed candidate.
dropped_step="$(sed -n '3p' "$work/base-steps.txt")"
python3 -I - "$cand_json" "$work/red-fixture.json" <<'PY'
import json, sys
wf = json.load(open(sys.argv[1], encoding="utf-8"))
del wf["jobs"]["test"]["steps"][2]
json.dump(wf, open(sys.argv[2], "w", encoding="utf-8"))
PY
if coverage_check "$work/red-fixture.json" > "$work/red-output.txt" 2>&1; then
    fail "TEST-017-RED: the dropped-step fixture PASSED the coverage check -- the check is vacuous"
else
    ok "TEST-017-RED: dropped step '${dropped_step}' correctly failed the coverage check (check is non-vacuous)"
fi

# GREEN: the real candidate passes.
if coverage_check "$cand_json" > "$work/green-output.txt" 2>&1; then
    ok "TEST-017-GREEN: all $base_count baseline step names appear in the candidate with the [deterministic] prefix (idempotent pre/post apply)"
else
    fail "TEST-017-GREEN: the candidate omits baseline step name(s): $(cat "$work/green-output.txt")"
fi

# Full membership AND order of required-checks' needs, however it is wrapped.
live_needs="$(wf_query "$live_json" needs required-checks)"
cand_needs="$(wf_query "$cand_json" needs required-checks)"
if [ "$live_needs" != "null" ] && [ "$live_needs" = "$cand_needs" ]; then
    ok "TEST-017: required-checks' complete needs list is unchanged (${live_needs})"
else
    fail "TEST-017: required-checks' needs diverged -- live=[$live_needs] candidate=[$cand_needs]"
fi

echo "=== TEST-018 (AC-018): sibling workflow graph isolation unchanged ==="

wf_query "$cand_json" needs > "$work/cand-needs.txt"
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
    if printf '%s\n' "$cand_jobs" | grep -Fqx "$sibling"; then
        fail "TEST-018: ${sibling} appears as a job in the candidate -- isolation broken"
    else
        ok "TEST-018: ${sibling} is not a job in the candidate (isolation preserved)"
    fi
    if grep -Fq ":${sibling}" "$work/cand-needs.txt"; then
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
    if grep -Fq "bash ./${suite}" "$candidate"; then
        ok "TEST-020: the candidate runs ${suite}"
    else
        fail "TEST-020: the candidate has no CI step running ${suite}"
    fi
    if [ -f "$repo_root/${suite}" ]; then
        ok "TEST-020: the referenced suite ${suite} exists"
    else
        fail "TEST-020: the candidate references a non-existent suite ${suite}"
    fi
    # Designed fail-closed window: the LIVE file must run the suite. Until the
    # human applies the candidate, it does not -- that red result is intended.
    if grep -Fq "bash ./${suite}" "$live_workflow"; then
        ok "TEST-020: the selected workflow runs ${suite} ($live_workflow)"
    else
        designed_red "TEST-020: selected workflow does not run ${suite}: $live_workflow (no staged fallback)"
    fi
done

# AC-020, no-regression-on-apply: the staged candidate is applied to the live
# file by a human, wholesale. If a dependabot bump lands live while the
# candidate still pins the older SHA, applying the candidate silently REVERTS
# that bump (this exact drift broke main once -- actions/checkout 7.0.0 -> 7.0.1,
# PR #222). Compare the pin sets rather than trusting authoring-time snapshots.
live_checkout_pins="$(grep -o 'actions/checkout@[0-9a-f]\{40\}' "$live_workflow" | sort -u)"
cand_checkout_pins="$(grep -o 'actions/checkout@[0-9a-f]\{40\}' "$candidate" | sort -u)"
if [ "$live_checkout_pins" = "$cand_checkout_pins" ]; then
    ok "TEST-020: the candidate's actions/checkout pins match the live workflow (applying it regresses no landed bump)"
else
    fail "TEST-020: the candidate's actions/checkout pins differ from live -- applying it would regress a landed dependency bump (live: $(echo "$live_checkout_pins" | tr '\n' ' '); candidate: $(echo "$cand_checkout_pins" | tr '\n' ' '))"
fi

echo
echo "deterministic-lane-selfcheck.tests.sh: $PASS passed, $FAIL failed, $DESIGNED_RED designed-red (pre-human-copy)"
# A designed-red result counts as a non-zero exit, matching the fail-closed
# precedent (quality-gate-cycle-limit.tests.sh): the suite is intentionally red
# until the human-copy candidate is applied to the live workflow, then green.
if [ "$FAIL" -ne 0 ] || [ "$DESIGNED_RED" -ne 0 ]; then
    exit 1
fi
exit 0
