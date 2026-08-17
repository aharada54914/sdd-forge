#!/usr/bin/env bash
# context-projection-schema.tests.sh — regression tests for
# contracts/context-projection.schema.json + validate-context-projection.py's
# schema conformance layer (REQ-003/REQ-006, design.md Test Strategy item 4).
#
# Mirrors facet-manifest-schema.tests.sh/capability-summary-schema.tests.sh's
# ok/fail counter style. Every fixture under tests/fixtures/facet-manifest/
# context-projection/ is pre-canonical JSON representing an already-re-keyed
# Context Projection instance (never a raw project-context.yaml array-shaped
# source) -- design.md's Generation procedure (the re-keying transform
# itself) is Epic A5's future implementation, Non-goals for this task; this
# suite instead proves the schema/validator accept/reject the exact shapes
# that transform is required to produce (an object keyed by component id,
# with no `id` sub-field, including a non-slug-shaped id) and the exact
# shapes it must reject (a still-array-shaped `components`).
#
# design.md's `validate-context-projection` contract: "Checks: schema
# conformance only" -- unlike facet-manifest-semantics.tests.sh, there is no
# sibling semantics suite for this artifact and no YAML parse contract at
# all (this validator's target, project-context.resolved.json, is already
# JSON, INV-007).
#
# Deliberately NOT `set -e`: RT-20260817-003's expected_fix item 3 asks a
# later task's genuine-RED capture to record per-fixture failures rather
# than abort at the first fixture-dependent assertion (T-002's own red-sh.log
# aborted at the very first schema-introspection command once
# contracts/context-projection.schema.json was absent, `set -euo pipefail`
# propagating that command's non-zero exit straight out of the script). Every
# assertion below tolerates the validator/schema being absent -- each helper
# checks the file exists before shelling out, and a missing file is recorded
# as an ordinary `fail()` line rather than a script abort -- so a RED run
# against this suite's own pre-implementation tree reaches every assertion
# and produces one FAIL line per affected fixture, not a single truncated
# run.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/validate-context-projection.py"
SCHEMA="${REPO_ROOT}/contracts/context-projection.schema.json"
FIXTURES="${REPO_ROOT}/tests/fixtures/facet-manifest/context-projection"

PASS=0
FAIL=0
ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

run_validator() {
  python3 "$VALIDATOR" --projection "$1" 2>&1
}

expect_valid() {
  local fixture="$1" name="$2"
  local out rc
  out="$(run_validator "$FIXTURES/$fixture")"
  rc=$?
  if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
    ok "$name: $fixture valid (exit 0, no diagnostics)"
  else
    fail "$name: $fixture expected valid, got exit=$rc output=[$out]"
  fi
}

expect_invalid() {
  local fixture="$1" name="$2" needle="$3"
  local out rc
  out="$(run_validator "$FIXTURES/$fixture")"
  rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF -- "$needle"; then
    ok "$name: $fixture invalid as expected (contains '$needle')"
  else
    fail "$name: $fixture expected invalid containing '$needle', got exit=$rc output=[$out]"
  fi
}

# --- schema existence -------------------------------------------------------
if [ -f "$SCHEMA" ]; then
  ok "contracts/context-projection.schema.json exists"
else
  fail "contracts/context-projection.schema.json is missing"
fi

if [ -f "$SCHEMA" ]; then
  schema_dollar_schema="$(python3 -c "import json;print(json.load(open('$SCHEMA')).get('\$schema',''))" 2>/dev/null)"
else
  schema_dollar_schema=""
fi
if [ "$schema_dollar_schema" = "http://json-schema.org/draft-07/schema#" ]; then
  ok "\$schema is draft-07"
else
  fail "\$schema expected draft-07, got '$schema_dollar_schema'"
fi

if [ -f "$SCHEMA" ]; then
  schema_id="$(python3 -c "import json;print(json.load(open('$SCHEMA')).get('\$id',''))" 2>/dev/null)"
else
  schema_id=""
fi
expected_schema_id="https://github.com/aharada54914/sdd-forge/contracts/context-projection.schema.json"
if [ "$schema_id" = "$expected_schema_id" ]; then
  ok "\$id exact match ($schema_id)"
else
  fail "\$id expected '$expected_schema_id', got '$schema_id'"
fi

# --- top-level required set --------------------------------------------------
if [ -f "$SCHEMA" ]; then
  required_json="$(python3 -c "import json;print(json.dumps(json.load(open('$SCHEMA')).get('required',[])))" 2>/dev/null)"
else
  required_json=""
fi
expected_required_json='["schema", "source_sha256", "workflow", "components", "shared_paths"]'
expected_required_json="$(python3 -c "import json;print(json.dumps(json.loads('$expected_required_json')))")"
if [ "$required_json" = "$expected_required_json" ]; then
  ok "top-level 'required' is exactly the five-field set (AC-015)"
else
  fail "top-level 'required' expected $expected_required_json, got $required_json"
fi

# --- workflow sub-object required set ---------------------------------------
if [ -f "$SCHEMA" ]; then
  workflow_required_json="$(python3 -c "import json;print(json.dumps(json.load(open('$SCHEMA'))['properties']['workflow'].get('required',[])))" 2>/dev/null)"
else
  workflow_required_json=""
fi
expected_workflow_required='["spec_profile", "artifact_layout", "capability_enforcement"]'
expected_workflow_required_json="$(python3 -c "import json;print(json.dumps(json.loads('$expected_workflow_required')))")"
if [ "$workflow_required_json" = "$expected_workflow_required_json" ]; then
  ok "workflow.required is exactly the three-field set"
else
  fail "workflow.required expected $expected_workflow_required_json, got $workflow_required_json"
fi

# --- Field Requirement Matrix: top-level required fields (one fixture per
# field, each omitting exactly ONE top-level required field, matching
# facet-manifest-schema.tests.sh's own convention) --------------------------
declare -a top_field_json=(schema source_sha256 workflow components shared_paths)
declare -a top_field_slug=(schema source-sha256 workflow components shared-paths)
for i in "${!top_field_json[@]}"; do
  field_json="${top_field_json[$i]}"
  field_slug="${top_field_slug[$i]}"
  expect_invalid "required-missing-${field_slug}.json" "top-level required" "missing required property '${field_json}'"
done

# --- Field Requirement Matrix: workflow sub-object required fields ---------
declare -a wf_field_json=(spec_profile artifact_layout capability_enforcement)
declare -a wf_field_slug=(spec-profile artifact-layout capability-enforcement)
for i in "${!wf_field_json[@]}"; do
  field_json="${wf_field_json[$i]}"
  field_slug="${wf_field_slug[$i]}"
  expect_invalid "workflow-missing-${field_slug}.json" "workflow required" "/workflow/${field_json}: missing required property '${field_json}'"
done

# --- enum branches: workflow.spec_profile / artifact_layout /
# capability_enforcement (every enum value is exercised POSITIVELY somewhere
# across this suite's own valid fixtures -- rekeyed-two-component-non-
# slug-id.json (full/facet-native/required), shared-path-bounded-valid.json
# (full/lite-three-file/required), shared-path-unbounded-valid.json
# (lite/legacy-seven-layer/advisory), source-omission-empty-valid.json
# (lite/facet-hybrid/advisory) -- these three fixtures assert the NEGATIVE,
# out-of-enum branch for each field with a pointer-pinned needle) ----------
expect_invalid "workflow-spec-profile-invalid.json" "spec_profile enum" "/workflow/spec_profile: expected one of ['full', 'lite']"
expect_invalid "workflow-artifact-layout-invalid.json" "artifact_layout enum" "/workflow/artifact_layout: expected one of ['lite-three-file', 'legacy-seven-layer', 'facet-hybrid', 'facet-native']"
expect_invalid "workflow-capability-enforcement-invalid.json" "capability_enforcement enum" "/workflow/capability_enforcement: expected one of ['advisory', 'required']"

# --- schema const branch -----------------------------------------------------
expect_invalid "schema-invalid-const.json" "schema const" "/schema: expected const 'sdd-context-projection/v1'"

# --- TEST-015: re-keying proof + source-omission normalization (AC-015) ----
# Positive fixture: two components, one with a non-slug-shaped id
# (`Desktop/App`), re-keyed to exactly two id-valued keys, no `id`
# sub-field anywhere.
expect_valid "rekeyed-two-component-non-slug-id.json" "TEST-015"
rekey_check="$(python3 -c "
import json
d = json.load(open('$FIXTURES/rekeyed-two-component-non-slug-id.json'))
comps = d['components']
keys = sorted(comps.keys())
ok = (
    len(comps) == 2
    and keys == ['Desktop/App', 'desktop-client']
    and 'id' not in comps['desktop-client']
    and 'id' not in comps['Desktop/App']
)
print('OK' if ok else 'FAIL keys=%r' % (keys,))
")"
if [ "$rekey_check" = "OK" ]; then
  ok "TEST-015: components re-keys to exactly two id-valued keys (incl. non-slug 'Desktop/App'), no 'id' sub-field"
else
  fail "TEST-015: re-keying shape check failed: $rekey_check"
fi

# Second fixture: a source that omits components/shared_paths entirely
# re-keys to components: {} / shared_paths: [] ("B8").
expect_valid "source-omission-empty-valid.json" "TEST-015 (B8 source-omission)"
omission_check="$(python3 -c "
import json
d = json.load(open('$FIXTURES/source-omission-empty-valid.json'))
ok = d['components'] == {} and d['shared_paths'] == []
print('OK' if ok else 'FAIL components=%r shared_paths=%r' % (d.get('components'), d.get('shared_paths')))
")"
if [ "$omission_check" = "OK" ]; then
  ok "TEST-015 (B8): source-omission fixture materializes components: {} / shared_paths: []"
else
  fail "TEST-015 (B8): $omission_check"
fi

# --- TEST-016: end-to-end RFC 6901 pointer resolution (AC-016) -------------
# /components/desktop-client/artifact_kinds (decision document v2 section 16's
# own example, requirements.md:722/769) resolves against the AC-015-shaped
# fixture to a real value.
pointer_resolution="$(python3 -c "
import json
def resolve(doc, pointer):
    if pointer == '':
        return doc
    node = doc
    for token in pointer.lstrip('/').split('/'):
        token = token.replace('~1', '/').replace('~0', '~')
        if isinstance(node, list):
            node = node[int(token)]
        else:
            node = node[token]
    return node
d = json.load(open('$FIXTURES/rekeyed-two-component-non-slug-id.json'))
value = resolve(d, '/components/desktop-client/artifact_kinds')
print(json.dumps(value))
")"
if [ "$pointer_resolution" = '["executable", "installer"]' ]; then
  ok "TEST-016: /components/desktop-client/artifact_kinds resolves to a real value ($pointer_resolution)"
else
  fail "TEST-016: expected /components/desktop-client/artifact_kinds to resolve to [\"executable\", \"installer\"], got [$pointer_resolution]"
fi

# --- TEST-030: validate-context-projection.py exit-0/non-zero contract
# (AC-030) --------------------------------------------------------------
# Positive: exits 0 on the non-slug-key fixture (proves B3's relaxation is
# enforced by the validator, not merely the schema file in isolation --
# already asserted above via "TEST-015", re-stated here under its own AC).
expect_valid "rekeyed-two-component-non-slug-id.json" "TEST-030"
# Negative: exits non-zero on a still-array-shaped 'components' fixture --
# proving the validator enforces the re-keying transform, not merely a
# generic 'type: object' check that happens to be satisfied.
expect_invalid "components-still-array-shaped.json" "TEST-030" "/components: expected type 'object', got list"

# --- TEST-042: shared_paths[] oneOf branch (AC-042) -------------------------
expect_valid "shared-path-bounded-valid.json" "TEST-042 (bounded)"
expect_valid "shared-path-unbounded-valid.json" "TEST-042 (unbounded)"
expect_invalid "shared-path-both-rejected.json" "TEST-042 (both)" "/shared_paths/0: expected exactly one 'oneOf' branch to match, 2 matched"
expect_invalid "shared-path-neither-rejected.json" "TEST-042 (neither)" "/shared_paths/0: expected exactly one 'oneOf' branch to match, 0 matched"

# --- Regression lock: shared_paths[] items' own top-level 'pattern' is
# still required regardless of which oneOf branch is chosen -----------------
expect_invalid "shared-path-missing-pattern.json" "shared_paths[] required 'pattern'" "/shared_paths/0/pattern: missing required property 'pattern'"

# --- Regression lock: source_sha256 / provider_bindings_sha256 digest
# pattern is enforced. design.md's own keyword-audit paragraph (API /
# Contract Plan, "keywords each committed schema instance actually uses")
# omits 'pattern' from context-projection.schema.json's list, but the
# schema's own committed JSON block (same section) declares both digest
# fields' pattern constraint -- this fixture proves the shipped hand-rolled
# engine actually enforces it rather than silently treating it as
# unconstrained (the same failure class T-002's own 'feature' pattern
# regression already caught for a sibling schema). See this task's
# Specification Differences note. --------------------------------------
expect_invalid "source-sha256-malformed-digest.json" "source_sha256 pattern regression" "/source_sha256: does not match pattern"
expect_invalid "provider-bindings-sha256-malformed-digest.json" "provider_bindings_sha256 pattern regression" "/provider_bindings_sha256: does not match pattern"

# --- ECMA pattern semantics: trailing-newline digest value rejected --------
# Draft-07 pattern follows ECMA-262 semantics: a non-multiline $ asserts
# end-of-string only. Python's bare $ also matches immediately before a
# trailing "\n", so "sha256:<64 hex>\n" must not be silently accepted.
# Regression lock for this validator's own _ecma_anchor/_compile_pattern
# pair (T-001 quality-gate lesson, RT-20260817-003 -- not a design.md/
# tasks.md instruction; carried into this validator's independent copy of
# the engine for the same reason T-001/T-002 needed it).
expect_invalid "source-sha256-trailing-newline.json" "ECMA pattern semantics: trailing-newline source_sha256 rejected" "/source_sha256: does not match pattern"

# --- Diagnostic determinism: multi-diagnostic ordering (check-id, pointer) -
# Two simultaneous violations (schema const + workflow.capability_enforcement
# enum) must appear as two exact lines, ordered ascending by JSON Pointer
# (both share the same check-id, 'schema-invalid'; '/schema' sorts before
# '/workflow/capability_enforcement').
expected_line1="context-projection: schema-invalid: /schema: expected const 'sdd-context-projection/v1', got 'sdd-facet-manifest/v1'"
expected_line2="context-projection: schema-invalid: /workflow/capability_enforcement: expected one of ['advisory', 'required'], got 'optional'"
multi_out="$(run_validator "$FIXTURES/multi-diagnostic-ordering.json")"
multi_rc=$?
expected_multi="$(printf '%s\n%s' "$expected_line1" "$expected_line2")"
if [ "$multi_rc" -ne 0 ] && [ "$multi_out" = "$expected_multi" ]; then
  ok "diagnostic determinism: multi-diagnostic-ordering.json emits exactly 2 lines in (check-id, pointer) order"
else
  fail "diagnostic determinism: expected exit!=0 and exact 2-line output [$expected_multi], got exit=$multi_rc output=[$multi_out]"
fi

# --- projection-unreadable regression lock ----------------------------------
# Deterministic: a nonexistent --projection path must surface the
# validator's own projection-unreadable diagnostic (fail-closed JSON load),
# not a Python traceback or a silent pass. No fixture file needed -- the
# path is intentionally absent. (This validator has no YAML/canonicalizer
# subprocess at all, design.md's own `validate-context-projection` contract
# -- unlike validate-facet-manifest.py/validate-capability-summary.py, there
# is no 'canonicalizer-invocation-failed' diagnostic to regression-lock
# here; 'projection-unreadable' is this script's own equivalent fail-closed
# behavior for its stdlib-only json.load path.)
missing_projection="$FIXTURES/does-not-exist.json"
canon_out="$(run_validator "$missing_projection")"
canon_rc=$?
if [ "$canon_rc" -ne 0 ] && printf '%s' "$canon_out" | grep -qF "context-projection: projection-unreadable:"; then
  ok "projection-unreadable: nonexistent .json path fails closed (exit=$canon_rc, contains diagnostic)"
else
  fail "projection-unreadable: expected exit!=0 and diagnostic, got exit=$canon_rc output=[$canon_out]"
fi

# --- Suite/CI registration self-check ---------------------------------------
if [ -f "${REPO_ROOT}/tests/run-all.sh" ] && grep -qF "tests/context-projection-schema.tests.sh" "${REPO_ROOT}/tests/run-all.sh"; then
  ok "self-registration: tests/run-all.sh lists this suite"
else
  fail "self-registration: tests/run-all.sh does not list tests/context-projection-schema.tests.sh"
fi

echo
echo "context-projection-schema: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
