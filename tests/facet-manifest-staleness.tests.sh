#!/usr/bin/env bash
# facet-manifest-staleness.tests.sh — regression tests for
# compare-facet-manifest-staleness.py's REQ-004 branch table, REQ-005
# version-bump tiers, and the CLI/argument-error contract (design.md Test
# Strategy item 5; `compare-facet-manifest-staleness` contract).
#
# All fixtures under tests/fixtures/facet-manifest/staleness/ are
# already-canonical JSON Facet Manifest instances (never .yaml), matching
# facet-manifest-semantics.tests.sh's own convention -- this suite exercises
# the comparator's branch logic directly via its --old-manifest/
# --new-manifest <path>.json inputs, independent of Epic A1's canonicalizer
# (tasks.md External Checkout Constraints; this comparator's own YAML parse
# contract is exercised indirectly through the imported validate-facet-
# manifest.py module, which is already covered by facet-manifest-schema.
# tests.sh/facet-manifest-semantics.tests.sh).
#
# Deliberately NOT `set -e` (T-002/T-003's own RT-20260817-003 convention):
# every assertion below tolerates the comparator script being absent so a
# RED run against this suite's own pre-implementation tree records one FAIL
# line per affected assertion instead of aborting at the first one.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPARATOR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/compare-facet-manifest-staleness.py"
FIXTURES="${REPO_ROOT}/tests/fixtures/facet-manifest/staleness"

PASS=0
FAIL=0
ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

STDOUT_FILE="$(mktemp)"
STDERR_FILE="$(mktemp)"
cleanup() { rm -f "$STDOUT_FILE" "$STDERR_FILE"; }
trap cleanup EXIT

# run_comparator <args...> -- invokes the comparator, capturing stdout/stderr
# into $STDOUT_FILE/$STDERR_FILE separately (never merged, so the channel-
# separation assertions below are meaningful) and prints the exit code on
# its own stdout for command-substitution capture.
run_comparator() {
  python3 "$COMPARATOR" "$@" >"$STDOUT_FILE" 2>"$STDERR_FILE"
  echo "$?"
}

# expect_verdict <old> <new> <status> <reason> <name> [extra comparator args...]
# Asserts: exit code matches <status>'s fixed mapping, stdout is exactly
# "facet-manifest-staleness: <status>:<reason>", and stderr is EMPTY (the
# verdict channel never shares a line with the diagnostic channel).
expect_verdict() {
  local old="$1" new="$2" status="$3" reason="$4" name="$5"
  shift 5
  local expected_exit
  case "$status" in
    fresh) expected_exit=0 ;;
    stale) expected_exit=1 ;;
    blocked) expected_exit=2 ;;
    *) fail "$name: unknown expected status '$status' in test authoring"; return ;;
  esac
  local rc stdout_text stderr_text expected_line
  rc="$(run_comparator --old-manifest "$FIXTURES/$old" --new-manifest "$FIXTURES/$new" "$@")"
  stdout_text="$(cat "$STDOUT_FILE")"
  stderr_text="$(cat "$STDERR_FILE")"
  expected_line="facet-manifest-staleness: ${status}:${reason}"
  if [ "$rc" = "$expected_exit" ] && [ "$stdout_text" = "$expected_line" ] && [ -z "$stderr_text" ]; then
    ok "$name: $old vs $new -> $status:$reason (exit=$expected_exit, stdout pinned, stderr empty)"
  else
    fail "$name: expected exit=$expected_exit stdout=[$expected_line] stderr=[], got exit=$rc stdout=[$stdout_text] stderr=[$stderr_text]"
  fi
}

# expect_error <old> <new> <check_id> <needle> <name> [extra comparator args...]
# Asserts: exit code 3, stderr contains "facet-manifest-staleness: <check_id>:
# <needle>", and stdout is EMPTY (no verdict line for an exit-3 invocation).
expect_error() {
  local old="$1" new="$2" check_id="$3" needle="$4" name="$5"
  shift 5
  local rc stdout_text stderr_text
  rc="$(run_comparator --old-manifest "$FIXTURES/$old" --new-manifest "$FIXTURES/$new" "$@")"
  stdout_text="$(cat "$STDOUT_FILE")"
  stderr_text="$(cat "$STDERR_FILE")"
  if [ "$rc" = "3" ] && [ -z "$stdout_text" ] \
     && printf '%s' "$stderr_text" | grep -qF "facet-manifest-staleness: ${check_id}: ${needle}"; then
    ok "$name: exit=3, stdout empty, stderr contains 'facet-manifest-staleness: ${check_id}: ${needle}'"
  else
    fail "$name: expected exit=3 stdout=[] stderr containing 'facet-manifest-staleness: ${check_id}: ${needle}', got exit=$rc stdout=[$stdout_text] stderr=[$stderr_text]"
  fi
}

DEFAULT_FLAGS=(--projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none)

# =============================================================================
# REQ-004 branch table (TEST-019..024, TEST-039, TEST-040)
# =============================================================================

# --- TEST-019 (AC-019): digest-only change, explicit not-weakened -> fresh -
expect_verdict base-old.json registry-digest-only-new.json fresh metadata-only-refresh \
  "TEST-019 digest-only-change not-stale lock" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

# --- TEST-020 (AC-020): same-gate-ID blocking change -> stale -------------
expect_verdict base-old.json gate-blocking-change-new.json stale semantic-output-changed \
  "TEST-020 same-gate-ID attribute-change stale lock" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

# --- TEST-021 (AC-021): evidence-only change -> stale (reversed "B1") -----
expect_verdict base-old.json evidence-change-new.json stale semantic-output-changed \
  "TEST-021 evidence-inclusion lock (reversed)" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

# --- TEST-022 (AC-022): minimum-enforcement tightening -> stale -----------
expect_verdict minimum-enforcement-old.json minimum-enforcement-new.json stale semantic-output-changed \
  "TEST-022 minimum-enforcement-tightening lock" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

# --- TEST-023 (AC-023): weakened verdict short-circuits, comparison never
# evaluated -- semantic output is byte-identical old-vs-new, only
# projection_sha256 differs; block fires anyway ---------------------------
expect_verdict base-old.json projection-digest-only-new.json blocked policy-weakening-blocked:projection \
  "TEST-023 Policy-Weakening short-circuit lock" \
  --projection-weakening weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

# --- TEST-024 (AC-024): fail-closed lock + forward-compatibility sub-case -
expect_verdict base-old.json registry-digest-only-new.json blocked weakening-verdict-indeterminate:registry \
  "TEST-024(1) fail-closed lock (indeterminate)" \
  --projection-weakening not-weakened --registry-weakening indeterminate --ownership-weakening not-weakened --resolver-version-bump none
expect_verdict base-old.json registry-digest-only-new.json fresh metadata-only-refresh \
  "TEST-024(2) forward-compatibility sub-case (not-weakened)" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

# --- TEST-039 (AC-039): no axis changed, all not-weakened, bump none ------
# -> fresh/unchanged, and the comparator must NOT even attempt the semantic
# comparison: this fixture pair's `capabilities` field genuinely differs, so
# if branch 3's short-circuit were removed/reordered, branch 4 would report
# stale/semantic-output-changed instead -- this assertion fails under that
# mutation.
expect_verdict base-old.json no-axis-change-semantic-differs-new.json fresh unchanged \
  "TEST-039 unchanged-digests WARN-only lock" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

# --- TEST-040 (AC-040): ownership-axis parity with the registry axis ------
expect_verdict base-old.json ownership-digest-only-new.json fresh metadata-only-refresh \
  "TEST-040(1) ownership-axis not-weakened -> not stale" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none
expect_verdict base-old.json ownership-digest-only-new.json blocked weakening-verdict-indeterminate:ownership \
  "TEST-040(2) ownership-axis indeterminate -> Block" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening indeterminate --resolver-version-bump none

# --- Branch-1 regression lock: the axis loop checks ALL changed axes, not
# only the first one it encounters -- registry_digest AND ownership_digest
# both differ; registry's own verdict is not-weakened (no block from it),
# but ownership's is weakened, so the comparator must still Block on
# ownership. A mutation that `return`s after the first changed axis
# regardless of its verdict would incorrectly report fresh/stale here. -----
expect_verdict base-old.json multi-axis-mixed-verdict-new.json blocked policy-weakening-blocked:ownership \
  "branch-1 all-changed-axes lock (registry not-weakened, ownership weakened)" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening weakened --resolver-version-bump none

# --- Branch-1 regression lock: fixed axis order (projection, registry,
# ownership) governs "first-encountered", not verdict severity -- the same
# fixture pair, but registry is indeterminate AND ownership is weakened;
# registry is checked first (fixed order) and already blocks, so the
# reported axis must be registry, never ownership, even though "weakened"
# might look like the more severe verdict. A mutation that reordered AXES
# or picked the "worst" verdict across all changed axes instead of the
# first-in-fixed-order one would report ownership here instead. -----------
expect_verdict base-old.json multi-axis-mixed-verdict-new.json blocked weakening-verdict-indeterminate:registry \
  "branch-1 fixed-axis-order precedence lock (registry indeterminate wins over ownership weakened)" \
  --projection-weakening not-weakened --registry-weakening indeterminate --ownership-weakening weakened --resolver-version-bump none

# =============================================================================
# REQ-005 version-bump tiers (TEST-025..027, TEST-045)
# =============================================================================

# --- TEST-025 (AC-025): patch-tier no-op -----------------------------------
expect_verdict base-old.json patch-bump-new.json fresh unchanged \
  "TEST-025 patch-tier no-op lock" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump patch

# --- TEST-026 (AC-026): minor-tier impact assessment, both sub-cases, each
# with a byte-identical context_binding ------------------------------------
expect_verdict base-old.json minor-bump-changed-new.json stale semantic-output-changed \
  "TEST-026(1) minor-tier impact assessment, semantic output changed" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump minor
expect_verdict base-old.json minor-bump-unchanged-new.json fresh metadata-only-refresh \
  "TEST-026(2) minor-tier impact assessment, semantic output unchanged" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump minor

# --- TEST-027 (AC-027): major-tier forced-regardless + Block precedence ---
expect_verdict base-old.json major-bump-new.json stale major-version-forced \
  "TEST-027(1) major-tier forced-regardless lock" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump major
expect_verdict base-old.json major-bump-block-new.json blocked policy-weakening-blocked:projection \
  "TEST-027(2) Block precedence over major-tier forced-stale" \
  --projection-weakening weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump major

# --- TEST-045 (AC-045): branch-3 digest-unchanged short-circuit is scoped
# to none/patch only -- a minor bump with byte-identical context_binding
# still reaches branch 4 (already proven by TEST-026 above; restated here
# under its own AC/TEST id for direct traceability) and a minor-rule-set
# bump under the identical digest-unchanged condition reaches the same
# branch (the "parity fixture" design.md's own AC-045 row names). ---------
expect_verdict base-old.json minor-bump-changed-new.json stale semantic-output-changed \
  "TEST-045(1) branch-3 fix: minor bump reaches ordinary comparison" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump minor
expect_verdict base-old.json minor-rule-set-bump-changed-new.json stale semantic-output-changed \
  "TEST-045(2) branch-3 fix parity: minor-rule-set bump reaches ordinary comparison" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump minor-rule-set

# =============================================================================
# TEST-044: CLI contract -- mandatory flags, stdout/exit-code mapping, the
# exit-3/stderr argument-error class, stdout/stderr channel separation.
# =============================================================================

# --- Mandatory-flag presence: each of the 6 required flags, omitted one at
# a time -- an earlier revision made the three --*-weakening flags optional
# with omission standing for indeterminate; this locks the reversal.
# expect_error/run_comparator always supply --old-manifest/--new-manifest
# themselves, so a "missing --old-manifest"/"missing --new-manifest" case
# cannot be expressed through that helper -- this suite invokes python3
# directly for all 6 missing-flag cases instead, via check_missing_flag. --
check_missing_flag() {
  local name="$1" needle="$2"
  shift 2
  python3 "$COMPARATOR" "$@" >"$STDOUT_FILE" 2>"$STDERR_FILE"
  local rc=$?
  local stdout_text stderr_text
  stdout_text="$(cat "$STDOUT_FILE")"
  stderr_text="$(cat "$STDERR_FILE")"
  if [ "$rc" = "3" ] && [ -z "$stdout_text" ] && printf '%s' "$stderr_text" | grep -qF "$needle"; then
    ok "$name: exit=3, stdout empty, stderr contains '$needle'"
  else
    fail "$name: expected exit=3 stdout=[] stderr containing '$needle', got exit=$rc stdout=[$stdout_text] stderr=[$stderr_text]"
  fi
}

check_missing_flag "TEST-044 missing --old-manifest" "the following arguments are required: --old-manifest" \
  --new-manifest "$FIXTURES/registry-digest-only-new.json" --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

check_missing_flag "TEST-044 missing --new-manifest" "the following arguments are required: --new-manifest" \
  --old-manifest "$FIXTURES/base-old.json" --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

check_missing_flag "TEST-044 missing --projection-weakening" "the following arguments are required: --projection-weakening" \
  --old-manifest "$FIXTURES/base-old.json" --new-manifest "$FIXTURES/registry-digest-only-new.json" --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

check_missing_flag "TEST-044 missing --registry-weakening" "the following arguments are required: --registry-weakening" \
  --old-manifest "$FIXTURES/base-old.json" --new-manifest "$FIXTURES/registry-digest-only-new.json" --projection-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

check_missing_flag "TEST-044 missing --ownership-weakening" "the following arguments are required: --ownership-weakening" \
  --old-manifest "$FIXTURES/base-old.json" --new-manifest "$FIXTURES/registry-digest-only-new.json" --projection-weakening not-weakened --registry-weakening not-weakened --resolver-version-bump none

check_missing_flag "TEST-044 missing --resolver-version-bump" "the following arguments are required: --resolver-version-bump" \
  --old-manifest "$FIXTURES/base-old.json" --new-manifest "$FIXTURES/registry-digest-only-new.json" --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened

# --- Out-of-enum values, one per enum-valued flag --------------------------
check_missing_flag "TEST-044 invalid --projection-weakening enum" "argument --projection-weakening: invalid choice: 'bogus'" \
  --old-manifest "$FIXTURES/base-old.json" --new-manifest "$FIXTURES/registry-digest-only-new.json" --projection-weakening bogus --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

check_missing_flag "TEST-044 invalid --registry-weakening enum" "argument --registry-weakening: invalid choice: 'bogus'" \
  --old-manifest "$FIXTURES/base-old.json" --new-manifest "$FIXTURES/registry-digest-only-new.json" --projection-weakening not-weakened --registry-weakening bogus --ownership-weakening not-weakened --resolver-version-bump none

check_missing_flag "TEST-044 invalid --ownership-weakening enum" "argument --ownership-weakening: invalid choice: 'bogus'" \
  --old-manifest "$FIXTURES/base-old.json" --new-manifest "$FIXTURES/registry-digest-only-new.json" --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening bogus --resolver-version-bump none

check_missing_flag "TEST-044 invalid --resolver-version-bump enum" "argument --resolver-version-bump: invalid choice: 'bogus'" \
  --old-manifest "$FIXTURES/base-old.json" --new-manifest "$FIXTURES/registry-digest-only-new.json" --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump bogus

# --- Schema-invalid --old-manifest/--new-manifest --------------------------
expect_error schema-invalid-manifest.json registry-digest-only-new.json schema-invalid "/old-manifest/schema: missing required property 'schema'" \
  "TEST-044 schema-invalid --old-manifest" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none
expect_error base-old.json schema-invalid-manifest.json schema-invalid "/new-manifest/schema: missing required property 'schema'" \
  "TEST-044 schema-invalid --new-manifest" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

# --- Exit-code-to-status mapping: one fixture per exit code (0/1/2). NOT
# re-asserted here as its own `ok` line (seq0761 Minor-4: an unconditional
# `ok "...proven by..."` call is a vacuous assertion that inflates the
# passing tally without checking anything itself) -- the mapping is already
# checked by expect_verdict's own exit-code comparison inside TEST-019
# (fresh -> exit 0), TEST-020 (stale -> exit 1), and TEST-023 (blocked ->
# exit 2) above; this is a cross-reference comment, not a duplicate check.

# --- manifest-unreadable: nonexistent --old-manifest path (fail-closed,
# never a Python traceback) -------------------------------------------------
missing_out="$(python3 "$COMPARATOR" --old-manifest "$FIXTURES/does-not-exist.json" --new-manifest "$FIXTURES/base-old.json" "${DEFAULT_FLAGS[@]}" 2>&1 1>/dev/null)"
missing_rc=$?
if [ "$missing_rc" = "3" ] && printf '%s' "$missing_out" | grep -qF "facet-manifest-staleness: manifest-unreadable: old-manifest:"; then
  ok "manifest-unreadable: nonexistent --old-manifest path fails closed (exit=3, diagnostic on stderr)"
else
  fail "manifest-unreadable: expected exit=3 with diagnostic, got exit=$missing_rc output=[$missing_out]"
fi

# --- manifest-unreadable: non-UTF-8 bytes (T-001..T-003 quality-gate
# lesson: except (OSError, ValueError), never a bare
# except (OSError, json.JSONDecodeError), which misses UnicodeDecodeError
# on non-UTF-8 input and leaks an unhandled traceback) ---------------------
nonutf8_out="$(python3 "$COMPARATOR" --old-manifest "$FIXTURES/manifest-non-utf8-bytes.bin" --new-manifest "$FIXTURES/base-old.json" "${DEFAULT_FLAGS[@]}" 2>&1 1>/dev/null)"
nonutf8_rc=$?
if [ "$nonutf8_rc" = "3" ] \
   && printf '%s' "$nonutf8_out" | grep -qF "facet-manifest-staleness: manifest-unreadable: old-manifest:" \
   && ! printf '%s' "$nonutf8_out" | grep -qF "Traceback"; then
  ok "manifest-unreadable: non-UTF-8 byte input fails closed (exit=3, diagnostic present, no traceback)"
else
  fail "manifest-unreadable: non-UTF-8 byte input expected exit=3, diagnostic, no traceback, got exit=$nonutf8_rc output=[$nonutf8_out]"
fi

# =============================================================================
# TEST-046: --resolver-version-bump / actual-manifest-diff consistency
# argument-error class, one fixture per tier mismatch, plus one consistent
# positive fixture per tier.
# =============================================================================

expect_error base-old.json minor-bump-changed-new.json resolver-version-bump-inconsistent \
  "declared 'patch' but the two manifests' own resolver block actually differs at tier 'minor'" \
  "TEST-046 patch declared against an actual minor diff" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump patch

expect_error base-old.json minor-rule-set-bump-changed-new.json resolver-version-bump-inconsistent \
  "declared 'minor' but the two manifests' own resolver block actually differs at tier 'minor-rule-set'" \
  "TEST-046 minor declared against an actual minor-rule-set diff (version unchanged)" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump minor

expect_error base-old.json minor-bump-changed-new.json resolver-version-bump-inconsistent \
  "declared 'minor-rule-set' but the two manifests' own resolver block actually differs at tier 'minor'" \
  "TEST-046 minor-rule-set declared against an actual resolver.version change" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump minor-rule-set

expect_error base-old.json registry-digest-only-new.json resolver-version-bump-inconsistent \
  "declared 'minor-rule-set' but the two manifests' own resolver block actually differs at tier 'none'" \
  "TEST-046 minor-rule-set declared against an unchanged rule_set_revision" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump minor-rule-set

# --- TEST-046 (seq0761 Minor-6 remediation): patch declared against an
# actual MAJOR diff (the pre-existing suite only covered a patch-vs-minor
# mismatch; this closes the patch-vs-major direction) ----------------------
expect_error base-old.json major-bump-new.json resolver-version-bump-inconsistent \
  "declared 'patch' but the two manifests' own resolver block actually differs at tier 'major'" \
  "TEST-046 patch declared against an actual major diff" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump patch

# --- Positive fixture per tier: a consistent declaration is accepted and
# proceeds to the ordinary branch table (each already exercised above under
# its own REQ-004/REQ-005 AC/TEST id). NOT re-asserted here as its own `ok`
# line (seq0761 Minor-4: see the TEST-044 exit-code-mapping comment above
# for the same reasoning) -- proven by TEST-019 ('none'), TEST-025
# ('patch'), TEST-026(1) ('minor'), TEST-045(2) ('minor-rule-set'), and
# TEST-027(1) ('major').

# =============================================================================
# seq0761 Major-1: branch 2 (major-forced) must precede branch 4 (ordinary
# comparison) -- a fixture with a major bump, a changed digest (not-
# weakened, so it does not Block), AND a genuinely differing semantic
# output. If branch 2 were moved after branch 4 (or removed), this fixture
# would report stale:semantic-output-changed instead of the pinned
# stale:major-version-forced -- the reason string itself is the mutation-
# resistant part of this assertion, not just the stale/exit=1 status.
# =============================================================================
expect_verdict base-old.json major-bump-semantic-changed-new.json stale major-version-forced \
  "Major-1 lock: major-forced precedes ordinary comparison even when both a digest and semantic output differ" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump major

# =============================================================================
# seq0761 Major-2: every one of REQ-004's 9 semantic-output fields must be
# individually mutation-locked. conditional_facets/resolved_gates/
# capability_minimum_enforcement/capabilities are already locked above
# (TEST-021/020/022/TEST-039's own capabilities diff); this closes the
# remaining 5: affected_components, required_facets, lite_eligibility
# (fixture-level, end to end through the CLI) and feature (fixture-level;
# schema-valid to vary, unlike `schema` itself) and schema (a `classify()`
# unit-level check below, since the schema's own `const` keyword makes it
# IMPOSSIBLE to construct two independently schema-valid documents that
# differ in `schema` -- any such fixture would be rejected at branch 0
# before ever reaching branch 4, so this field can only be locked by
# calling the comparison function directly, bypassing schema validation).
# =============================================================================
expect_verdict base-old.json feature-change-new.json stale semantic-output-changed \
  "Major-2 lock: 'feature' is a compared semantic-output field" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

expect_verdict base-old.json affected-components-change-new.json stale semantic-output-changed \
  "Major-2 lock: 'affected_components' is a compared semantic-output field" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

expect_verdict base-old.json required-facets-change-new.json stale semantic-output-changed \
  "Major-2 lock: 'required_facets' is a compared semantic-output field" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

expect_verdict base-old.json lite-eligibility-change-new.json stale semantic-output-changed \
  "Major-2 lock: 'lite_eligibility' is a compared semantic-output field" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump none

# 'schema' field lock: classify() called directly (bypassing the CLI's own
# branch-0 schema-conformance gate, which a real `schema` const-value
# mismatch could never pass on both sides simultaneously). This exercises
# the exact same SEMANTIC_FIELDS tuple / _semantic_output()/classify()
# machinery the CLI path uses -- only the schema-validation front door is
# skipped, not the comparison logic itself.
schema_field_check="$(python3 -c "
import importlib.util, json, copy, sys
spec = importlib.util.spec_from_file_location('cfms', '$COMPARATOR')
cfms = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cfms)
base = json.load(open('$FIXTURES/base-old.json'))
new = copy.deepcopy(base)
new['schema'] = 'sdd-facet-manifest/v2'
weakening = {'projection': 'not-weakened', 'registry': 'not-weakened', 'ownership': 'not-weakened'}
status, reason = cfms.classify(base, new, weakening, 'minor')
print('OK' if (status, reason) == ('stale', 'semantic-output-changed') else 'FAIL status=%r reason=%r' % (status, reason))
")"
if [ "$schema_field_check" = "OK" ]; then
  ok "Major-2 lock: 'schema' is a compared semantic-output field (classify() unit check, schema's own const keyword forbids a real fixture pair)"
else
  fail "Major-2 lock: 'schema' field check failed: $schema_field_check"
fi

# =============================================================================
# seq0761 Major-3: the sibling validate-facet-manifest.py import must fail
# closed (exit 3, stderr-only diagnostic, no traceback), never as an
# unhandled traceback that exits with Python's own default code 1 --
# indistinguishable from a legitimate `stale` verdict to a caller that
# branches on exit code alone. Reproduced by copying ONLY the comparator
# script (not its sibling) into a scratch directory and invoking it there.
# =============================================================================
sibling_scratch="$(mktemp -d)"
cp "$COMPARATOR" "$sibling_scratch/compare-facet-manifest-staleness.py"
python3 "$sibling_scratch/compare-facet-manifest-staleness.py" \
  --old-manifest "$FIXTURES/base-old.json" --new-manifest "$FIXTURES/base-old.json" \
  "${DEFAULT_FLAGS[@]}" >"$STDOUT_FILE" 2>"$STDERR_FILE"
sibling_rc=$?
sibling_stdout="$(cat "$STDOUT_FILE")"
sibling_stderr="$(cat "$STDERR_FILE")"
rm -rf "$sibling_scratch"
if [ "$sibling_rc" = "3" ] && [ -z "$sibling_stdout" ] \
   && printf '%s' "$sibling_stderr" | grep -qF "facet-manifest-staleness: validator-import-failed:" \
   && ! printf '%s' "$sibling_stderr" | grep -qF "Traceback"; then
  ok "Major-3 lock: missing sibling validate-facet-manifest.py fails closed (exit=3, stdout empty, diagnostic present, no traceback)"
else
  fail "Major-3 lock: expected exit=3 stdout=[] diagnostic 'validator-import-failed', no traceback; got exit=$sibling_rc stdout=[$sibling_stdout] stderr=[$sibling_stderr]"
fi

# =============================================================================
# seq0761 Minor-5: Specification Difference #4 confirmation -- design.md's
# own "(and no coarser one)" clause (Invocation section) is logically
# equivalent to "the coarsest changed component determines the tier," so
# this is not an open interpretive question; it is a direct consequence of
# the contract text already resolving it. Locked with a genuine
# multi-component version change (1.1.0 -> 1.2.5, both minor and patch
# differ): declaring `patch` (a coarser-than-actual claim) is rejected;
# declaring `minor` (the coarsest actually-changed component) is accepted.
# =============================================================================
expect_error base-old.json multi-component-bump-new.json resolver-version-bump-inconsistent \
  "declared 'patch' but the two manifests' own resolver block actually differs at tier 'minor'" \
  "multi-component semver lock: patch declared against a minor+patch actual diff is rejected" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump patch

expect_verdict base-old.json multi-component-bump-new.json stale semantic-output-changed \
  "multi-component semver lock: minor (the coarsest actually-changed component) is accepted and proceeds" \
  --projection-weakening not-weakened --registry-weakening not-weakened --ownership-weakening not-weakened --resolver-version-bump minor

# =============================================================================
# Suite/CI registration self-check
# =============================================================================
if grep -qF "tests/facet-manifest-staleness.tests.sh" "${REPO_ROOT}/tests/run-all.sh"; then
  ok "self-registration: tests/run-all.sh lists this suite"
else
  fail "self-registration: tests/run-all.sh does not list tests/facet-manifest-staleness.tests.sh"
fi

echo
echo "facet-manifest-staleness: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
