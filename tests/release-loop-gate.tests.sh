#!/usr/bin/env bash
# tests/release-loop-gate.tests.sh — text-marker lock for the
# .github/workflows/release.yml required loop-gate job (T-002 / Issue #148 /
# epic-159-pillar-b REQ-002).
#
#   TEST-007 (AC-007) — the new `loop-gate:` job's slice of the workflow
#     text contains both the `tests/loop-consistency.tests.sh` and
#     `tests/loop-inventory.tests.sh` invocation strings.
#   TEST-008 (AC-008) — the build job's (`release:`) slice contains a
#     `needs: loop-gate` (or equivalent list form) entry, and neither that
#     slice nor the `loop-gate:` job's slice contains `continue-on-error:
#     true` or `if: always()`/`if: success() || failure()` (weakened-gate
#     negative scan).
#   TEST-009 (AC-009) — negative-branch canary: a mktemp fixture copy of
#     release.yml with the `needs:` line textually stripped is re-checked by
#     the SAME marker-check function used for TEST-007/TEST-008/TEST-010;
#     asserts the function now reports non-compliance, proving TEST-008's
#     assertion is not vacuously true.
#   TEST-010 (AC-010) — the `loop-gate:` job's slice contains `runs-on:
#     ubuntu-latest` and no `strategy:`/`matrix:` key (single-OS, matching
#     release.yml's existing scope); this suite self-registers in
#     tests/run-all.sh/.ps1 and .github/workflows/test.yml.
#
# Technique: text-marker structural checks over the real release.yml,
# following tests/workflow-state-ci-integration.tests.sh's established
# python3-heredoc precedent (design.md API/Contract Plan) rather than adding
# a YAML-parsing library dependency. The marker-check logic is written once
# to a scratch python3 script and invoked against BOTH the real file
# (TEST-007/TEST-008/TEST-010) and, separately, a mutated mktemp copy
# (TEST-009) — the same function, two inputs, proving the check is not
# vacuous. This suite never writes a real repository path; release.yml is
# read only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
RELEASE_YML="${ROOT}/.github/workflows/release.yml"
RUN_ALL_SH="${ROOT}/tests/run-all.sh"
TEST_YML="${ROOT}/.github/workflows/test.yml"

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); printf 'ok: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

CLEANUP_ROOTS=()
cleanup() {
  local d
  for d in "${CLEANUP_ROOTS[@]:-}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup EXIT

# The marker-check python3 script is written once to a scratch file (never a
# real repository path) and reused by every case below via
# check_release_yml(). Scoping the job-key search to lines AFTER the
# top-level `jobs:` key (rather than the whole file) is deliberate: this
# workflow's `on:` trigger section itself contains a 2-space-indented
# `release:` key (`release.yml:10-13`'s `on: release: types: [published]`)
# that would otherwise be misidentified as a job boundary.
#
# NOTE: the mktemp template below ends in a bare XXXXXX (no literal suffix
# after it) deliberately -- BSD/macOS mktemp (unlike GNU mktemp) only
# substitutes a trailing run of X's when it is the LAST thing in the
# template; a template like "name.XXXXXX.py" is returned byte-for-byte
# un-randomized on BSD mktemp, so every run after the first collides with
# "File exists". A mktemp -d directory (bare XXXXXX suffix) holding a
# fixed-name file inside it is the portable pattern.
CHECKER_DIR="$(mktemp -d "${TMPDIR:-/tmp}/release-loop-gate-checker.XXXXXX")"
CHECKER_DIR="$(cd "$CHECKER_DIR" && pwd -P)"
CLEANUP_ROOTS+=("$CHECKER_DIR")
CHECKER_PY="${CHECKER_DIR}/checker.py"
cat > "$CHECKER_PY" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
lines = text.split("\n")

JOBS_KEY_RE = re.compile(r"^jobs:\s*$")
JOB_KEY_RE = re.compile(r"^  [A-Za-z0-9_-]+:\s*$")

jobs_start = None
for i, line in enumerate(lines):
    if JOBS_KEY_RE.match(line):
        jobs_start = i
        break

if jobs_start is None:
    job_starts = []
else:
    job_starts = [
        i for i in range(jobs_start + 1, len(lines)) if JOB_KEY_RE.match(lines[i])
    ]


def job_slice(name):
    marker = f"  {name}:"
    start = None
    for i in job_starts:
        if lines[i].rstrip() == marker:
            start = i
            break
    if start is None:
        return ""
    end = len(lines)
    for i in job_starts:
        if i > start:
            end = i
            break
    return "\n".join(lines[start:end])


loop_gate_slice = job_slice("loop-gate")
release_slice = job_slice("release")

ESCAPE_HATCH_MARKERS = (
    "continue-on-error: true",
    "if: always()",
    "if: success() || failure()",
)


def has_escape_hatch(slice_text):
    return any(marker in slice_text for marker in ESCAPE_HATCH_MARKERS)


needs_scalar = re.search(r"needs:\s*loop-gate\s*$", release_slice, re.MULTILINE)
needs_inline_list = re.search(r"needs:\s*\[\s*loop-gate\s*\]", release_slice)
needs_block_list = re.search(r"needs:\s*\n\s*-\s*loop-gate\b", release_slice)
release_has_needs = bool(needs_scalar or needs_inline_list or needs_block_list)

results = {
    "loop_gate_slice_found": bool(loop_gate_slice),
    "release_slice_found": bool(release_slice),
    "loop_gate_has_consistency": "tests/loop-consistency.tests.sh" in loop_gate_slice,
    "loop_gate_has_inventory": "tests/loop-inventory.tests.sh" in loop_gate_slice,
    "release_has_needs": release_has_needs,
    "loop_gate_has_escape_hatch": has_escape_hatch(loop_gate_slice),
    "release_has_escape_hatch": has_escape_hatch(release_slice),
    "loop_gate_runs_on_ubuntu": "runs-on: ubuntu-latest" in loop_gate_slice,
    "loop_gate_has_strategy": ("strategy:" in loop_gate_slice)
    or ("matrix:" in loop_gate_slice),
}

for key in sorted(results):
    print(f"{key}={results[key]}")
PY

# check_release_yml <path> — prints "key=True"/"key=False" marker lines for
# the given workflow-file path; callers grep the captured output.
check_release_yml() {
  python3 "$CHECKER_PY" "$1"
}

# ---------------------------------------------------------------------------
# TEST-007 (AC-007): loop-gate job slice contains both suite invocations
# ---------------------------------------------------------------------------
run_test_007() {
  echo "=== TEST-007 (AC-007): loop-gate job slice contains both suite invocations ==="
  local output
  output="$(check_release_yml "$RELEASE_YML")"

  if grep -qF 'loop_gate_slice_found=True' <<<"$output"; then
    ok "TEST-007 (AC-007): a loop-gate: job slice was found in release.yml"
  else
    fail "TEST-007 (AC-007): no loop-gate: job slice found in release.yml"
    return
  fi

  if grep -qF 'loop_gate_has_consistency=True' <<<"$output"; then
    ok "TEST-007 (AC-007): loop-gate job slice invokes tests/loop-consistency.tests.sh"
  else
    fail "TEST-007 (AC-007): loop-gate job slice does not invoke tests/loop-consistency.tests.sh"
  fi

  if grep -qF 'loop_gate_has_inventory=True' <<<"$output"; then
    ok "TEST-007 (AC-007): loop-gate job slice invokes tests/loop-inventory.tests.sh"
  else
    fail "TEST-007 (AC-007): loop-gate job slice does not invoke tests/loop-inventory.tests.sh"
  fi
}

# ---------------------------------------------------------------------------
# TEST-008 (AC-008): release job needs: loop-gate + weakened-gate negative
# scan
# ---------------------------------------------------------------------------
run_test_008() {
  echo "=== TEST-008 (AC-008): release job needs: loop-gate + no escape hatch ==="
  local output
  output="$(check_release_yml "$RELEASE_YML")"

  if grep -qF 'release_has_needs=True' <<<"$output"; then
    ok "TEST-008 (AC-008): release job slice carries a needs: loop-gate entry"
  else
    fail "TEST-008 (AC-008): release job slice does not carry a needs: loop-gate entry"
  fi

  if grep -qF 'loop_gate_has_escape_hatch=False' <<<"$output"; then
    ok "TEST-008 (AC-008): loop-gate job slice carries no continue-on-error:true / if:always() / if:success()||failure() escape hatch"
  else
    fail "TEST-008 (AC-008): loop-gate job slice carries an escape hatch (weakened-gate threat)"
  fi

  if grep -qF 'release_has_escape_hatch=False' <<<"$output"; then
    ok "TEST-008 (AC-008): release job slice carries no continue-on-error:true / if:always() / if:success()||failure() escape hatch"
  else
    fail "TEST-008 (AC-008): release job slice carries an escape hatch (weakened-gate threat)"
  fi
}

# ---------------------------------------------------------------------------
# TEST-009 (AC-009): negative-branch canary — needs: textually stripped
# ---------------------------------------------------------------------------
run_test_009() {
  echo "=== TEST-009 (AC-009): negative-branch canary (needs: stripped) ==="
  local fixture_dir fixture_copy output

  fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/release-loop-gate-canary.XXXXXX")"
  fixture_dir="$(cd "$fixture_dir" && pwd -P)"
  CLEANUP_ROOTS+=("$fixture_dir")
  fixture_copy="${fixture_dir}/release.yml"

  grep -vE '^[[:space:]]*needs:[[:space:]]*loop-gate[[:space:]]*$' "$RELEASE_YML" > "$fixture_copy"

  output="$(check_release_yml "$fixture_copy")"
  if grep -qF 'release_has_needs=False' <<<"$output"; then
    ok "TEST-009 (AC-009): the needs:-stripped fixture copy is reported non-compliant (release_has_needs=False), proving TEST-008's assertion is not vacuously true"
  else
    fail "TEST-009 (AC-009): the needs:-stripped fixture copy was still reported compliant -- the marker-check function is vacuous"
  fi
}

# ---------------------------------------------------------------------------
# TEST-010 (AC-010): ubuntu-latest only + self-registration
# ---------------------------------------------------------------------------
run_test_010() {
  echo "=== TEST-010 (AC-010): ubuntu-latest only + self-registration ==="
  local output
  output="$(check_release_yml "$RELEASE_YML")"

  if grep -qF 'loop_gate_runs_on_ubuntu=True' <<<"$output"; then
    ok "TEST-010 (AC-010): loop-gate job slice declares runs-on: ubuntu-latest"
  else
    fail "TEST-010 (AC-010): loop-gate job slice does not declare runs-on: ubuntu-latest"
  fi

  if grep -qF 'loop_gate_has_strategy=False' <<<"$output"; then
    ok "TEST-010 (AC-010): loop-gate job slice carries no strategy:/matrix: key (single-OS, matching release.yml's existing scope)"
  else
    fail "TEST-010 (AC-010): loop-gate job slice unexpectedly carries a strategy:/matrix: key"
  fi

  if grep -qF 'release-loop-gate.tests.sh' "$RUN_ALL_SH" 2>/dev/null \
      && grep -qF 'release-loop-gate.tests.sh' "$TEST_YML" 2>/dev/null; then
    ok "TEST-010 (AC-010): release-loop-gate.tests.sh is registered in tests/run-all.sh and .github/workflows/test.yml"
  else
    fail "TEST-010 (AC-010): release-loop-gate.tests.sh is NOT registered in tests/run-all.sh and/or .github/workflows/test.yml"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
run_test_007
run_test_008
run_test_009
run_test_010

printf -- '---- summary: pass=%d fail=%d ----\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'not ok: release-loop-gate suite FAILED (%d failures)\n' "$FAIL" >&2
  exit 1
fi
printf 'ok: release-loop-gate suite passed (%d checks)\n' "$PASS"
