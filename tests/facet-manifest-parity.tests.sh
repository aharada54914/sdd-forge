#!/usr/bin/env bash
# facet-manifest-parity.tests.sh — cross-script, cross-runtime parity suite
# (T-005, REQ-006, design.md Test Strategy item 6):
#
#   TEST-031 (AC-031) golden-fixture parity + determinism lock: for all four
#     scripts (validate-facet-manifest, validate-capability-summary,
#     validate-context-projection, compare-facet-manifest-staleness), the
#     `.py`/`.sh`/`.ps1` invocations of the SAME input produce byte-identical
#     exit codes, stdout, and stderr -- replayed against every fixture from
#     suites 1-5 (tests/facet-manifest-schema.tests.sh, tests/facet-manifest-
#     semantics.tests.sh, tests/capability-summary-schema.tests.sh, tests/
#     context-projection-schema.tests.sh, tests/facet-manifest-staleness.
#     tests.sh), plus a Windows-style (backslash-separated) path argument and
#     compare-facet-manifest-staleness's own exit-3 stderr channel.
#   TEST-032 (AC-032) installed-layout discovery lock: one fixture per script
#     per runtime with only the packaged contracts/*.schema.json copy
#     present (no monorepo contracts/, no reachable .git).
#   TEST-033 (AC-033) six-suite registration proof: all six tests/*.tests.
#     {sh,ps1} pairs registered directly in tests/run-all.{sh,ps1}; the
#     staged .github/workflows/test.yml candidate carries all six suites'
#     CI steps with a correct MANIFEST.sha256 entry; the live workflow is
#     untouched.
#   TEST-043 (AC-043) provider-neutrality scan: none of this feature's three
#     schema files or four scripts' own source contains a term from Epic
#     A2's provider-neutrality allowlist; a clean/dirty fixture pair proves
#     the scan neither false-positives on this feature's own vocabulary nor
#     is vacuously blind to real contamination.
#
# Deliberately NOT `set -e` (T-002/T-003's own RT-20260817-003 convention):
# every assertion below tolerates an absent script/fixture so a RED run
# against this suite's own pre-implementation state records one FAIL line
# per affected assertion instead of aborting at the first one.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SCRIPTS="$REPO_ROOT/plugins/sdd-quality-loop/scripts"
FIXTURES_SCHEMA="$REPO_ROOT/tests/fixtures/facet-manifest/schema"
FIXTURES_SEMANTICS="$REPO_ROOT/tests/fixtures/facet-manifest/semantics"
FIXTURES_SUMMARY="$REPO_ROOT/tests/fixtures/facet-manifest/capability-summary"
FIXTURES_PROJECTION="$REPO_ROOT/tests/fixtures/facet-manifest/context-projection"
FIXTURES_STALENESS="$REPO_ROOT/tests/fixtures/facet-manifest/staleness"
FIXTURES_PARITY="$REPO_ROOT/tests/fixtures/facet-manifest/parity"
PROVIDER_TERMS="$REPO_ROOT/plugins/sdd-quality-loop/references/provider-terms.json"

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); printf 'ok: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

# =============================================================================
# Preconditions -- fail loudly rather than silently skipping a runtime
# (matching tests/capability-registry-parity.tests.sh's own T-007 precedent).
# =============================================================================
missing_tool=""
for tool in python3 pwsh; do
  command -v "$tool" >/dev/null 2>&1 || missing_tool="$missing_tool $tool"
done
if [ -n "$missing_tool" ]; then
  printf 'facet-manifest-parity: required tool(s) not available:%s\n' "$missing_tool" >&2
  printf -- '---- summary: pass=0 fail=1 ----\n'
  exit 1
fi

WORKDIR="$(mktemp -d)"
WORKDIR="$(cd "$WORKDIR" && pwd -P)"
trap 'rm -rf "$WORKDIR"' EXIT
OUT="$WORKDIR/out"
mkdir -p "$OUT"

# =============================================================================
# TEST-031: generic .py/.sh/.ps1 triple-invocation parity helper. Runs the
# SAME argv against all three wrappers, from REPO_ROOT (so a deliberately
# relative Windows-style path argument resolves -- or fails to resolve --
# identically for every runtime on whatever OS this suite itself runs on),
# and asserts identical exit codes and byte-identical stdout/stderr.
# =============================================================================
CASE_N=0
check_parity() {
  local label="$1" base="$2"
  shift 2
  CASE_N=$((CASE_N + 1))
  local slot="c${CASE_N}"
  ( cd "$REPO_ROOT" && python3 "$SCRIPTS/$base.py" "$@" >"$OUT/$slot.py.out" 2>"$OUT/$slot.py.err" )
  local py_rc=$?
  ( cd "$REPO_ROOT" && bash "$SCRIPTS/$base.sh" "$@" >"$OUT/$slot.sh.out" 2>"$OUT/$slot.sh.err" )
  local sh_rc=$?
  ( cd "$REPO_ROOT" && pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCRIPTS/$base.ps1" "$@" >"$OUT/$slot.ps1.out" 2>"$OUT/$slot.ps1.err" )
  local ps1_rc=$?
  local problems=""
  [ "$py_rc" = "$sh_rc" ] || problems="$problems sh-exit:${sh_rc}!=py:${py_rc}"
  [ "$py_rc" = "$ps1_rc" ] || problems="$problems ps1-exit:${ps1_rc}!=py:${py_rc}"
  cmp -s "$OUT/$slot.py.out" "$OUT/$slot.sh.out" || problems="$problems sh-stdout-diff"
  cmp -s "$OUT/$slot.py.out" "$OUT/$slot.ps1.out" || problems="$problems ps1-stdout-diff"
  cmp -s "$OUT/$slot.py.err" "$OUT/$slot.sh.err" || problems="$problems sh-stderr-diff"
  cmp -s "$OUT/$slot.py.err" "$OUT/$slot.ps1.err" || problems="$problems ps1-stderr-diff"
  if [ -z "$problems" ]; then
    ok "$label (exit=$py_rc, stdout/stderr byte-identical across .py/.sh/.ps1)"
  else
    fail "$label --$problems (py_rc=$py_rc sh_rc=$sh_rc ps1_rc=$ps1_rc)"
  fi

  # Explicit LF-only assertion (seq0763 Critical remediation on the .ps1
  # twin's own capture mechanism; kept here in the bash twin for label-for-
  # label parity with the .ps1 twin's own new assertion), SEPARATE from the
  # byte-parity assertion above: none of the six captured files may contain
  # a raw CR (0x0D) byte -- design.md's diagnostic-determinism contract and
  # AC-031's own "the .ps1 wrapper's own output stays LF-only on Windows"
  # clause, checked directly rather than only inferred from byte-parity (a
  # CR-for-CR-identical-but-still-CRLF triple would pass the byte-parity
  # check above yet still violate this contract). Bash's own `>`/`2>` file
  # redirection never normalizes bytes, so this check is meaningful as-is
  # here; the .ps1 twin needed a raw-byte process-capture rewrite first for
  # the identical check to be meaningful there (see that file's header).
  local cr_hits=""
  for f in "$OUT/$slot.py.out" "$OUT/$slot.py.err" "$OUT/$slot.sh.out" "$OUT/$slot.sh.err" "$OUT/$slot.ps1.out" "$OUT/$slot.ps1.err"; do
    if LC_ALL=C grep -q "$(printf '\r')" "$f" 2>/dev/null; then
      cr_hits="$cr_hits $(basename "$f")"
    fi
  done
  if [ -z "$cr_hits" ]; then
    ok "$label (LF-only: no CR byte in any of .py/.sh/.ps1 stdout/stderr)"
  else
    fail "$label -- CR byte(s) found in:$cr_hits"
  fi

  # Free the capture files immediately -- with ~130 cases x 6 files each this
  # keeps the mktemp tree small across the whole suite run.
  rm -f "$OUT/$slot".*.out "$OUT/$slot".*.err
}

# --- validate-facet-manifest: every fixture in suites 1-2 (schema +
# semantics) -----------------------------------------------------------------
facet_manifest_fixture_list="$(find "$FIXTURES_SCHEMA" "$FIXTURES_SEMANTICS" -type f \( -name '*.json' -o -name '*.yaml' -o -name '*.bin' \) | sort)"
facet_manifest_fixture_count="$(printf '%s\n' "$facet_manifest_fixture_list" | grep -c .)"
# seq0763 Minor-2: minimum-fixture-count non-vacuity guard -- if this glob
# silently returned zero (a fixture directory renamed/emptied out from under
# this suite), the loop below would run zero times and the suite would stay
# green with fewer assertions, not fail. 50 is comfortably below the 62
# fixtures present as of this task's own authoring, so a routine future
# fixture addition/removal within that margin does not need this suite
# edited, but a directory going empty or nearly empty does trip it.
if [ "$facet_manifest_fixture_count" -ge 50 ]; then
  ok "TEST-031 non-vacuity guard: facet-manifest schema+semantics fixture count is $facet_manifest_fixture_count (>= 50 expected)"
else
  fail "TEST-031 non-vacuity guard: facet-manifest schema+semantics fixture count is $facet_manifest_fixture_count, expected >= 50 -- the suite may have silently shrunk"
fi
while IFS= read -r fixture; do
  check_parity "TEST-031 validate-facet-manifest: $(basename "$fixture")" \
    validate-facet-manifest --manifest "$fixture"
done <<EOF
$facet_manifest_fixture_list
EOF

# --- validate-capability-summary: every fixture in suite 3 -----------------
summary_fixture_list="$(find "$FIXTURES_SUMMARY" -type f \( -name '*.json' -o -name '*.yaml' -o -name '*.bin' \) | sort)"
summary_fixture_count="$(printf '%s\n' "$summary_fixture_list" | grep -c .)"
if [ "$summary_fixture_count" -ge 10 ]; then
  ok "TEST-031 non-vacuity guard: capability-summary fixture count is $summary_fixture_count (>= 10 expected)"
else
  fail "TEST-031 non-vacuity guard: capability-summary fixture count is $summary_fixture_count, expected >= 10 -- the suite may have silently shrunk"
fi
while IFS= read -r fixture; do
  check_parity "TEST-031 validate-capability-summary: $(basename "$fixture")" \
    validate-capability-summary --summary "$fixture"
done <<EOF
$summary_fixture_list
EOF

# --- validate-context-projection: every fixture in suite 4 -----------------
projection_fixture_list="$(find "$FIXTURES_PROJECTION" -type f \( -name '*.json' -o -name '*.yaml' -o -name '*.bin' \) | sort)"
projection_fixture_count="$(printf '%s\n' "$projection_fixture_list" | grep -c .)"
if [ "$projection_fixture_count" -ge 20 ]; then
  ok "TEST-031 non-vacuity guard: context-projection fixture count is $projection_fixture_count (>= 20 expected)"
else
  fail "TEST-031 non-vacuity guard: context-projection fixture count is $projection_fixture_count, expected >= 20 -- the suite may have silently shrunk"
fi
while IFS= read -r fixture; do
  check_parity "TEST-031 validate-context-projection: $(basename "$fixture")" \
    validate-context-projection --projection "$fixture"
done <<EOF
$projection_fixture_list
EOF

# --- compare-facet-manifest-staleness: every distinct (old, new, flags)
# invocation suite 5 (facet-manifest-staleness.tests.sh) exercises, so every
# fixture file under tests/fixtures/facet-manifest/staleness/ appears in at
# least one replayed case. -------------------------------------------------
# old|new|projection-weakening|registry-weakening|ownership-weakening|resolver-version-bump
STALENESS_CASES=(
  "base-old.json|registry-digest-only-new.json|not-weakened|not-weakened|not-weakened|none"
  "base-old.json|gate-blocking-change-new.json|not-weakened|not-weakened|not-weakened|none"
  "base-old.json|evidence-change-new.json|not-weakened|not-weakened|not-weakened|none"
  "minimum-enforcement-old.json|minimum-enforcement-new.json|not-weakened|not-weakened|not-weakened|none"
  "base-old.json|projection-digest-only-new.json|weakened|not-weakened|not-weakened|none"
  "base-old.json|registry-digest-only-new.json|not-weakened|indeterminate|not-weakened|none"
  "base-old.json|no-axis-change-semantic-differs-new.json|not-weakened|not-weakened|not-weakened|none"
  "base-old.json|ownership-digest-only-new.json|not-weakened|not-weakened|not-weakened|none"
  "base-old.json|ownership-digest-only-new.json|not-weakened|not-weakened|indeterminate|none"
  "base-old.json|multi-axis-mixed-verdict-new.json|not-weakened|not-weakened|weakened|none"
  "base-old.json|multi-axis-mixed-verdict-new.json|not-weakened|indeterminate|weakened|none"
  "base-old.json|patch-bump-new.json|not-weakened|not-weakened|not-weakened|patch"
  "base-old.json|minor-bump-changed-new.json|not-weakened|not-weakened|not-weakened|minor"
  "base-old.json|minor-bump-unchanged-new.json|not-weakened|not-weakened|not-weakened|minor"
  "base-old.json|major-bump-new.json|not-weakened|not-weakened|not-weakened|major"
  "base-old.json|major-bump-block-new.json|weakened|not-weakened|not-weakened|major"
  "base-old.json|minor-rule-set-bump-changed-new.json|not-weakened|not-weakened|not-weakened|minor-rule-set"
  "base-old.json|major-bump-semantic-changed-new.json|not-weakened|not-weakened|not-weakened|major"
  "base-old.json|feature-change-new.json|not-weakened|not-weakened|not-weakened|none"
  "base-old.json|affected-components-change-new.json|not-weakened|not-weakened|not-weakened|none"
  "base-old.json|required-facets-change-new.json|not-weakened|not-weakened|not-weakened|none"
  "base-old.json|lite-eligibility-change-new.json|not-weakened|not-weakened|not-weakened|none"
  "base-old.json|multi-component-bump-new.json|not-weakened|not-weakened|not-weakened|minor"
  "schema-invalid-manifest.json|registry-digest-only-new.json|not-weakened|not-weakened|not-weakened|none"
  "base-old.json|schema-invalid-manifest.json|not-weakened|not-weakened|not-weakened|none"
  "base-old.json|minor-bump-changed-new.json|not-weakened|not-weakened|not-weakened|patch"
  "base-old.json|major-bump-new.json|not-weakened|not-weakened|not-weakened|patch"
  "manifest-non-utf8-bytes.bin|base-old.json|not-weakened|not-weakened|not-weakened|none"
)
if [ "${#STALENESS_CASES[@]}" -ge 20 ]; then
  ok "TEST-031 non-vacuity guard: compare-facet-manifest-staleness case-table length is ${#STALENESS_CASES[@]} (>= 20 expected)"
else
  fail "TEST-031 non-vacuity guard: compare-facet-manifest-staleness case-table length is ${#STALENESS_CASES[@]}, expected >= 20 -- the case table may have silently shrunk"
fi
for case_row in "${STALENESS_CASES[@]}"; do
  IFS='|' read -r old new proj reg own bump <<<"$case_row"
  check_parity "TEST-031 compare-facet-manifest-staleness: $old vs $new ($proj/$reg/$own/$bump)" \
    compare-facet-manifest-staleness \
    --old-manifest "$FIXTURES_STALENESS/$old" --new-manifest "$FIXTURES_STALENESS/$new" \
    --projection-weakening "$proj" --registry-weakening "$reg" --ownership-weakening "$own" \
    --resolver-version-bump "$bump"
done

# --- nonexistent --old-manifest path (fail-closed manifest-unreadable) -----
check_parity "TEST-031 compare-facet-manifest-staleness: nonexistent --old-manifest path" \
  compare-facet-manifest-staleness \
  --old-manifest "$FIXTURES_STALENESS/does-not-exist.json" --new-manifest "$FIXTURES_STALENESS/base-old.json" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened \
  --resolver-version-bump none

# --- malformed-argument fixture: exit-3 stderr channel (AC-031's trailing
# clause) -- one flag omitted entirely, one out-of-enum value ---------------
check_parity "TEST-031 compare-facet-manifest-staleness: missing --resolver-version-bump (exit-3 diagnostic channel)" \
  compare-facet-manifest-staleness \
  --old-manifest "$FIXTURES_STALENESS/base-old.json" --new-manifest "$FIXTURES_STALENESS/registry-digest-only-new.json" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened

check_parity "TEST-031 compare-facet-manifest-staleness: out-of-enum --registry-weakening (exit-3 diagnostic channel)" \
  compare-facet-manifest-staleness \
  --old-manifest "$FIXTURES_STALENESS/base-old.json" --new-manifest "$FIXTURES_STALENESS/registry-digest-only-new.json" \
  --projection-weakening not-weakened --registry-weakening bogus --ownership-weakening not-weakened \
  --resolver-version-bump none

# --- Windows-style path argument (AC-031: "at least one Windows-style path
# argument... confirms the .ps1 wrapper's own output remains LF-only and
# byte-identical to the .py/.sh outputs for that same fixture, including
# compare-facet-manifest-staleness's own exit-3 stderr diagnostics"). The
# fixture is a relative, backslash-separated path -- on this suite's own
# runtime OS the three wrappers must still agree byte-for-byte on whatever
# outcome that path produces (resolves on real Windows; fails closed with an
# identical diagnostic on POSIX), which is exactly what check_parity proves
# regardless of which outcome actually occurs. --------------------------
WIN_PATH_RAW="$(cat "$FIXTURES_PARITY/windows-style-path.txt")"
WIN_PATH="${WIN_PATH_RAW%$'\n'}"
check_parity "TEST-031 validate-facet-manifest: Windows-style backslash path argument" \
  validate-facet-manifest --manifest "$WIN_PATH"

check_parity "TEST-031 compare-facet-manifest-staleness: Windows-style backslash --old-manifest path (exit-3 channel)" \
  compare-facet-manifest-staleness \
  --old-manifest "$WIN_PATH" --new-manifest "$FIXTURES_STALENESS/base-old.json" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened \
  --resolver-version-bump none

# =============================================================================
# TEST-032: installed-layout discovery lock. A scratch tree living OUTSIDE
# this repository (mktemp, so no ancestor directory carries a reachable
# .git) with only the packaged copy of each schema present at the
# script-relative offset ../contracts/<filename> -- no monorepo contracts/,
# no .git fallback available at all. One fixture per script per runtime
# (4 scripts x 3 runtimes = 12), matching Epic A2's own three-fixture,
# per-runtime discovery proof (INV-018).
# =============================================================================
INSTALLED="$WORKDIR/installed"
mkdir -p "$INSTALLED/scripts" "$INSTALLED/contracts"
for f in \
  validate-facet-manifest.py validate-facet-manifest.sh validate-facet-manifest.ps1 \
  validate-capability-summary.py validate-capability-summary.sh validate-capability-summary.ps1 \
  validate-context-projection.py validate-context-projection.sh validate-context-projection.ps1 \
  compare-facet-manifest-staleness.py compare-facet-manifest-staleness.sh compare-facet-manifest-staleness.ps1 \
  lib/py-dispatch.sh lib/py-dispatch.ps1
do
  if [ -f "$SCRIPTS/$f" ]; then
    mkdir -p "$INSTALLED/scripts/$(dirname "$f")"
    cp "$SCRIPTS/$f" "$INSTALLED/scripts/$f"
    chmod +x "$INSTALLED/scripts/$f" 2>/dev/null || true
  fi
done
for schema in facet-manifest.schema.json capability-summary.schema.json context-projection.schema.json; do
  if [ -f "$REPO_ROOT/contracts/$schema" ]; then
    cp "$REPO_ROOT/contracts/$schema" "$INSTALLED/contracts/$schema"
  fi
done

run_installed() {
  # $1=kind(py|sh|ps1) $2=base $3=outfile-prefix, remaining=args
  local kind="$1" base="$2" outp="$3"
  shift 3
  case "$kind" in
    py) python3 "$INSTALLED/scripts/$base.py" "$@" >"$outp.out" 2>"$outp.err" ;;
    sh) bash "$INSTALLED/scripts/$base.sh" "$@" >"$outp.out" 2>"$outp.err" ;;
    ps1) pwsh -NoProfile -ExecutionPolicy Bypass -File "$INSTALLED/scripts/$base.ps1" "$@" >"$outp.out" 2>"$outp.err" ;;
  esac
  echo $? >"$outp.rc"
}

assert_installed_ok() {
  # $1=label $2=kind $3=base, remaining=args
  local label="$1" kind="$2" base="$3"
  shift 3
  local outp="$OUT/disc-${base}-${kind}"
  run_installed "$kind" "$base" "$outp" "$@"
  local rc out err
  rc="$(cat "$outp.rc")"
  out="$(cat "$outp.out")"
  err="$(cat "$outp.err")"
  if [ "$rc" = "0" ] && [ -z "$out" ] && [ -z "$err" ]; then
    ok "$label"
  else
    fail "$label -- expected exit=0 no output, got exit=$rc stdout=[$out] stderr=[$err]"
  fi
}

assert_installed_verdict() {
  # Like assert_installed_ok, but for compare-facet-manifest-staleness: a
  # SUCCESSFUL discovery+comparison still writes the one-line verdict to
  # stdout (design.md's own contract) -- "no output" would be the WRONG
  # success condition here, unlike the three schema/semantic validators.
  local label="$1" kind="$2" base="$3" expected_stdout="$4"
  shift 4
  local outp="$OUT/disc-${base}-${kind}"
  run_installed "$kind" "$base" "$outp" "$@"
  local rc out err
  rc="$(cat "$outp.rc")"
  out="$(cat "$outp.out")"
  err="$(cat "$outp.err")"
  if [ "$rc" = "0" ] && [ "$out" = "$expected_stdout" ] && [ -z "$err" ]; then
    ok "$label"
  else
    fail "$label -- expected exit=0 stdout=[$expected_stdout] stderr=[], got exit=$rc stdout=[$out] stderr=[$err]"
  fi
}

for kind in py sh ps1; do
  assert_installed_ok "TEST-032 installed-layout discovery: validate-facet-manifest ($kind)" \
    "$kind" validate-facet-manifest --manifest "$FIXTURES_SCHEMA/valid-base.json"
  assert_installed_ok "TEST-032 installed-layout discovery: validate-capability-summary ($kind)" \
    "$kind" validate-capability-summary --summary "$FIXTURES_SUMMARY/decision-doc-v2-section6-worked-example.json"
  assert_installed_ok "TEST-032 installed-layout discovery: validate-context-projection ($kind)" \
    "$kind" validate-context-projection --projection "$FIXTURES_PROJECTION/rekeyed-two-component-non-slug-id.json"
  assert_installed_verdict "TEST-032 installed-layout discovery: compare-facet-manifest-staleness ($kind)" \
    "$kind" compare-facet-manifest-staleness "facet-manifest-staleness: fresh:metadata-only-refresh" \
    --old-manifest "$FIXTURES_STALENESS/base-old.json" --new-manifest "$FIXTURES_STALENESS/registry-digest-only-new.json" \
    --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened \
    --resolver-version-bump none
done

# --- Non-vacuity canary: with the packaged contracts/ directory moved aside
# (still no monorepo contracts/ reachable at any other offset, still no
# .git), discovery MUST fail closed -- proving the 12 "resolves and
# validates" assertions above are not vacuously true regardless of whether
# the packaged copy is actually there. ---------------------------------------
mv "$INSTALLED/contracts" "$INSTALLED/contracts.hidden"
canary_out="$(python3 "$INSTALLED/scripts/validate-facet-manifest.py" --manifest "$FIXTURES_SCHEMA/valid-base.json" 2>&1)"
canary_rc=$?
mv "$INSTALLED/contracts.hidden" "$INSTALLED/contracts"
if [ "$canary_rc" -ne 0 ] && printf '%s' "$canary_out" | grep -qF "schema-discovery-failed"; then
  ok "TEST-032 non-vacuity canary: removing the packaged contracts/ copy makes discovery fail closed (schema-discovery-failed)"
else
  fail "TEST-032 non-vacuity canary: expected exit!=0 with schema-discovery-failed once the packaged copy was hidden, got exit=$canary_rc output=[$canary_out]"
fi

# =============================================================================
# TEST-033: six-suite registration proof.
# =============================================================================
SIX_SUITES="facet-manifest-schema facet-manifest-semantics capability-summary-schema context-projection-schema facet-manifest-staleness facet-manifest-parity"
for suite in $SIX_SUITES; do
  if grep -qF "tests/${suite}.tests.sh" "$REPO_ROOT/tests/run-all.sh"; then
    ok "TEST-033: tests/run-all.sh registers tests/${suite}.tests.sh"
  else
    fail "TEST-033: tests/run-all.sh does NOT register tests/${suite}.tests.sh"
  fi
  if grep -qF "tests/${suite}.tests.ps1" "$REPO_ROOT/tests/run-all.ps1"; then
    ok "TEST-033: tests/run-all.ps1 registers tests/${suite}.tests.ps1"
  else
    fail "TEST-033: tests/run-all.ps1 does NOT register tests/${suite}.tests.ps1"
  fi
done

STAGED_WORKFLOW="$REPO_ROOT/specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml"
STAGED_MANIFEST="$REPO_ROOT/specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256"
LIVE_WORKFLOW="$REPO_ROOT/.github/workflows/test.yml"

if [ -f "$STAGED_WORKFLOW" ]; then
  staged_missing=""
  for suite in $SIX_SUITES; do
    grep -qF "tests/${suite}.tests.sh" "$STAGED_WORKFLOW" || staged_missing="$staged_missing ${suite}.tests.sh"
    grep -qF "tests/${suite}.tests.ps1" "$STAGED_WORKFLOW" || staged_missing="$staged_missing ${suite}.tests.ps1"
  done
  if [ -z "$staged_missing" ]; then
    ok "TEST-033: the staged .github/workflows/test.yml candidate carries all six suites' CI steps"
  else
    fail "TEST-033: staged candidate is missing CI steps for:$staged_missing"
  fi
else
  fail "TEST-033: staged .github/workflows/test.yml candidate is missing at $STAGED_WORKFLOW"
fi

if [ -f "$STAGED_WORKFLOW" ] && [ -f "$STAGED_MANIFEST" ]; then
  staged_hash="$(shasum -a 256 "$STAGED_WORKFLOW" | awk '{print $1}')"
  manifest_hash="$(grep -F 'workflows/test.yml' "$STAGED_MANIFEST" | awk '{print $1}')"
  if [ -n "$manifest_hash" ] && [ "$staged_hash" = "$manifest_hash" ]; then
    ok "TEST-033: staged candidate sha256 matches its own MANIFEST.sha256 entry"
  else
    fail "TEST-033: staged candidate sha256 ($staged_hash) does not match MANIFEST.sha256 ($manifest_hash)"
  fi
else
  fail "TEST-033: MANIFEST.sha256 or the staged candidate is missing"
fi

if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  if git -C "$REPO_ROOT" diff --quiet HEAD -- .github/workflows/test.yml 2>/dev/null; then
    ok "TEST-033: the live .github/workflows/test.yml is byte-unchanged relative to its committed state (this task never writes to it)"
  else
    fail "TEST-033: live .github/workflows/test.yml has an uncommitted modification -- this task must never write to it"
  fi
else
  fail "TEST-033: cannot verify the live workflow is unmodified (no git repository resolved at $REPO_ROOT)"
fi

# =============================================================================
# TEST-043: provider-neutrality scan.
#
# seq0763 Major remediation: the earlier revision excluded the WHOLE term
# "lambda" from the four scripts' own source scan, which let a genuine
# contamination string like `LAMBDA_DEPLOY_TARGET = "lambda"` slip through
# undetected -- an unconditional word exclusion drops the allowlist's
# detection power by 1/16 (one of Epic A2's 16 terms), and the exclusion
# itself drifted from what requirements.md/acceptance-tests.md actually
# authorize as the false-positive defense (a CLEAN FIXTURE, not a term
# exclusion). Fixed to IDIOM-level masking: only the exact `key=lambda`
# keyword-argument idiom (the one, sole legitimate occurrence in all four
# scripts -- `sorted(diags, key=lambda d: (d.check_id, d.pointer))`, T-001's
# diagnostic-determinism-contract implementation, reused verbatim by
# T-002/T-003/T-004) is masked out of the text BEFORE scanning; every other
# occurrence of the word "lambda" anywhere in the source -- including a
# quoted string literal like `"lambda"` -- is scanned normally against the
# full, unexcluded 16-term allowlist.
# =============================================================================
scan_terms() {
  # $1 = file to scan against Epic A2's own provider-neutrality allowlist.
  # Whole-word match (regex \b...\b, case-insensitive) after idiom-level
  # masking, not a bare substring search: a bare substring match would flag,
  # e.g., any English word merely containing "s3" as a run of characters.
  # Prints a comma-joined list of matched terms, empty if none.
  python3 - "$1" "$PROVIDER_TERMS" <<'PY'
import json
import re
import sys

target_path, terms_path = sys.argv[1], sys.argv[2]
doc = json.load(open(terms_path, encoding="utf-8"))
terms = []
for category_terms in doc.get("categories", {}).values():
    terms.extend(category_terms)
text = open(target_path, encoding="utf-8", errors="replace").read()
# Idiom-level mask: ONLY the `key=lambda` keyword-argument idiom (Python's
# own reserved keyword used as a sort key, never a provider-name reference)
# is removed from the scanned text -- a standalone "lambda" anywhere else
# (e.g. a quoted string literal) is left untouched and fully scannable.
masked = re.sub(r"key\s*=\s*lambda\b", "key=__PY_LAMBDA_KEYWORD_IDIOM__", text)
masked_lower = masked.lower()
hits = []
for term in terms:
    lowered = term.lower()
    if re.search(r"\b" + re.escape(lowered) + r"\b", masked_lower):
        hits.append(term)
print(",".join(hits))
PY
}

# seq0763 Minor-1: "the four scripts' source" (security-spec.md) means each
# script's full .py/.sh/.ps1 triple, not the .py master alone -- the .sh/
# .ps1 wrappers are thin forwarders with no `lambda` idiom of their own, so
# they need no masking, but they are still in-scope scan targets.
PROVIDER_NEUTRALITY_TARGETS="$REPO_ROOT/contracts/facet-manifest.schema.json $REPO_ROOT/contracts/capability-summary.schema.json $REPO_ROOT/contracts/context-projection.schema.json \
$SCRIPTS/validate-facet-manifest.py $SCRIPTS/validate-facet-manifest.sh $SCRIPTS/validate-facet-manifest.ps1 \
$SCRIPTS/validate-capability-summary.py $SCRIPTS/validate-capability-summary.sh $SCRIPTS/validate-capability-summary.ps1 \
$SCRIPTS/validate-context-projection.py $SCRIPTS/validate-context-projection.sh $SCRIPTS/validate-context-projection.ps1 \
$SCRIPTS/compare-facet-manifest-staleness.py $SCRIPTS/compare-facet-manifest-staleness.sh $SCRIPTS/compare-facet-manifest-staleness.ps1"
for target in $PROVIDER_NEUTRALITY_TARGETS; do
  if [ -f "$target" ]; then
    hits="$(scan_terms "$target")"
    if [ -z "$hits" ]; then
      ok "TEST-043: $(basename "$target") contains no provider-neutrality-allowlist term"
    else
      fail "TEST-043: $(basename "$target") contains provider-neutrality-allowlist term(s): $hits"
    fi
  else
    fail "TEST-043: scan target missing: $target"
  fi
done

# Dirty fixture: proves the scan mechanism itself actually detects
# contamination (a non-vacuity canary for the "no hit" assertions above).
dirty_hits="$(scan_terms "$FIXTURES_PARITY/provider-neutrality-dirty.txt")"
if [ -n "$dirty_hits" ]; then
  ok "TEST-043 non-vacuity canary: the dirty fixture is correctly flagged ($dirty_hits)"
else
  fail "TEST-043 non-vacuity canary: the dirty fixture (deliberately containing a provider term) was NOT flagged -- the scan is vacuous"
fi

# seq0763 Major regression lock: a `NAME = "lambda"  # Lambda ...`-shaped
# assignment (the evaluator's own dirty-fixture pattern) must still be
# flagged even though it is NOT the masked `key=lambda` idiom -- proves the
# idiom-level mask does not over-mask a genuine standalone occurrence.
lambda_dirty_hits="$(scan_terms "$FIXTURES_PARITY/provider-neutrality-lambda-dirty.txt")"
if printf '%s' "$lambda_dirty_hits" | grep -qE '(^|,)lambda(,|$)'; then
  ok "TEST-043 lambda-idiom-mask regression lock: a standalone quoted 'lambda' string-literal assignment (not the key=lambda idiom) is correctly flagged ($lambda_dirty_hits)"
else
  fail "TEST-043 lambda-idiom-mask regression lock: expected 'lambda' to be flagged in the standalone-assignment fixture, got [$lambda_dirty_hits] -- the idiom mask is over-masking"
fi

# Clean fixture: proves this feature's own vocabulary (e.g.
# distribution_channels, a real field this feature's own context-projection
# schema already carries) does not false-positive.
clean_hits="$(scan_terms "$FIXTURES_PARITY/provider-neutrality-clean.txt")"
if [ -z "$clean_hits" ]; then
  ok "TEST-043: the clean fixture (this feature's own provider-neutral vocabulary) produces no false positive"
else
  fail "TEST-043: the clean fixture unexpectedly matched: $clean_hits"
fi
if grep -qF "distribution_channels" "$FIXTURES_PARITY/provider-neutrality-clean.txt"; then
  ok "TEST-043: the clean fixture genuinely contains 'distribution_channels' (the no-hit result above is not vacuous)"
else
  fail "TEST-043: the clean fixture no longer contains 'distribution_channels' -- rewrite it to keep testing the intended vocabulary"
fi

# =============================================================================
# Vendored-copy drift gate (Done When): --check exits 0 against the three
# schema files' vendored copies on the clean tree.
# =============================================================================
vendor_out="$(python3 "$SCRIPTS/vendor-capability-registry.py" --check 2>&1)"
vendor_rc=$?
if [ "$vendor_rc" -eq 0 ] && printf '%s' "$vendor_out" | grep -qF "no drift"; then
  ok "vendor-capability-registry.py --check exits 0 against the clean tree (extended to cover the three new schema filenames)"
else
  fail "vendor-capability-registry.py --check expected exit=0 with 'no drift', got exit=$vendor_rc output=[$vendor_out]"
fi

# =============================================================================
# Suite/CI self-registration self-check.
# =============================================================================
if grep -qF "tests/facet-manifest-parity.tests.sh" "${REPO_ROOT}/tests/run-all.sh"; then
  ok "self-registration: tests/run-all.sh lists this suite"
else
  fail "self-registration: tests/run-all.sh does not list tests/facet-manifest-parity.tests.sh"
fi

echo
echo "facet-manifest-parity: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
