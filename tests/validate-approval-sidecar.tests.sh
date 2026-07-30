#!/bin/sh
# T-006 (epic-189-a1-project-context, REQ-005): acceptance checks for
# plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py and its
# .sh/.ps1 dispatcher wrappers.
#
# TEST-014 six independent rejection fixtures (content-schema incl.
#   duplicate-id / hash mismatch / HMAC mismatch / unregistered approver /
#   duplicate approver identity / future effective_at) -- AC-014.
# TEST-015 positive proof -- AC-015.
# TEST-019 two-person enforcement incl. same-identity refusal, exercised
#   from THIS suite's side against the REAL generate-approval-sidecar.py
#   (T-003) AND this validator -- AC-019. See the "TEST-019 discharge
#   note" comment below: T-003's generator does NOT itself refuse to sign
#   a solo-approved sidecar whose verdict requires two-person review (a
#   gap recorded at T-005's quality-gate, seq0353,
#   `reports/notes/epic-189-a1-carryover-items.md`) -- this validator is
#   the canonical enforcement point instead (obligation 4b, below).
# TEST-020 cooldown enforcement (generation + validation) -- AC-020.
# TEST-043 post-publish provenance re-provability + underapproval
#   rejection via --verify-provenance, incl. the bootstrap case and the
#   HUMAN_COPY_PUBLISH_IN_PROGRESS reader-side fail-closed fixture --
#   AC-043.
# TEST-046 zero-identity structural fail-closed-validating consequence
#   (structural half; the verdict half is T-005's) -- AC-046.
# AC-045 PRODUCTION discharge: T-004's suite proved only the test-side
#   concept (an inline, non-production harness) that a duplicate
#   approvers[].id passes plain JSON Schema but fails a semantic check;
#   THIS suite proves the REAL validate-approval-sidecar.py rejects it
#   (DUPLICATE_APPROVER_REGISTRY_ID).
# OBLIGATION 1 (T-003 QG carryover, recorded twice): executable key-parity
#   proof -- this validator's OWN resolve_context_key(), independently
#   reimplemented (never imported), matches sdd-hook-guard.py's
#   _resolve_sudo_key AND generate-approval-sidecar.py's
#   resolve_context_key byte-for-byte across the AC-013-style 4-case
#   matrix.
# OBLIGATION 2 (T-003 QG round-2 Minor (3)): a non-bootstrap sidecar
#   (predecessor_context_sha256 present) carrying weakening_verdict: null
#   violates requirements.md:310-312's invariant -- this validator
#   rejects it (WEAKENING_VERDICT_MISSING), backstopping T-005's own
#   generator-side refusal.
# OBLIGATION 4b (T-005 QG seq0353 observation): a verdict requiring
#   two-person review implies a PRESENT, DISTINCT second_approval -- this
#   validator rejects otherwise (WEAKENING_PROVENANCE_UNDERAPPROVED) under
#   BOTH the standard validation path and --verify-provenance (design.md
#   only names --verify-provenance explicitly; the standard-path gate is
#   this task's own carry-forward discharge, since no upstream layer
#   enforces the consistency at signing time).
#
# This suite invokes the tool through validate-approval-sidecar.sh (the
# real dispatcher surface), mirroring generate-approval-sidecar.tests.sh's
# own convention. Every positive/negative sidecar fixture is signed with a
# GENUINELY VALID HMAC -- either via a REAL generate-approval-sidecar.py
# (T-003) invocation, or (for shapes T-003's own guard rails refuse to
# produce, e.g. a duplicate-identity sidecar) via this suite's own
# sign_fixture.py, which dispatches to canonicalize-sdd-yaml.py (T-002)
# directly -- never via generate-approval-sidecar.py's internals -- so
# this validator's HMAC gate is exercised against fixtures it did not
# help construct.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/validate-approval-sidecar-test.XXXXXX")
# Physical-path normalization (design.md Test Strategy item 12).
WORK=$(cd "$WORK" && pwd -P)
trap 'rm -rf "$WORK"' EXIT INT TERM

VAL_SH="$ROOT/plugins/sdd-quality-loop/scripts/validate-approval-sidecar.sh"
VAL_PY="$ROOT/plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py"
GEN_SH="$ROOT/plugins/sdd-quality-loop/scripts/generate-approval-sidecar.sh"
CANON_PY="$ROOT/plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py"
HOOK_GUARD_PY="$ROOT/plugins/sdd-quality-loop/scripts/sdd-hook-guard.py"
GEN_PY="$ROOT/plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  printf 'FAIL: no python3/python interpreter available\n'
  exit 1
fi

TESTKEY="test-context-key-epic189-t006"

# run_val [env_prefix...] -- args... -- invokes the .sh dispatcher, capturing
# stdout to $WORK/out, stderr to $WORK/err, and returning its exit code.
run_val() {
  "$VAL_SH" "$@" >"$WORK/out" 2>"$WORK/err"
  return $?
}

# ---------------------------------------------------------------------------
# sign_fixture.py: builds a fully-signed approval-sidecar JSON object from a
# template, computing context_sha256 (via canonicalize-sdd-yaml.py
# --hash-only against a content file, or a literal override) and hmac (via
# canonicalize-sdd-yaml.py JSON-mode + hmac.new) independently of
# generate-approval-sidecar.py's own internals.
# ---------------------------------------------------------------------------

SIGN_FIXTURE="$WORK/sign_fixture.py"
cat > "$SIGN_FIXTURE" <<'PYEOF'
import hashlib
import hmac
import json
import os
import subprocess
import sys
import tempfile

canon_py, content_path, key_file, template_path, output_path = sys.argv[1:6]
override_hash = sys.argv[6] if len(sys.argv) > 6 else None

with open(template_path, "r", encoding="utf-8") as f:
    obj = json.load(f)

if override_hash:
    obj["context_sha256"] = override_hash
elif content_path != "NONE":
    proc = subprocess.run(
        [sys.executable, canon_py, content_path, "--input-format", "yaml", "--hash-only"],
        capture_output=True, check=True,
    )
    obj["context_sha256"] = proc.stdout.decode("ascii").strip()

obj.pop("hmac", None)
tmp_fd, tmp_path = tempfile.mkstemp()
with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
    json.dump(obj, f)
proc = subprocess.run(
    [sys.executable, canon_py, tmp_path, "--input-format", "json"],
    capture_output=True, check=True,
)
os.unlink(tmp_path)
preimage = proc.stdout

if key_file != "NONE":
    with open(key_file, "rb") as f:
        key = f.read()
    obj["hmac"] = hmac.new(key, preimage, hashlib.sha256).hexdigest()
else:
    obj["hmac"] = "0" * 64

with open(output_path, "w", encoding="utf-8") as f:
    json.dump(obj, f, indent=2, sort_keys=True)
    f.write("\n")
PYEOF

sign_fixture() {
  # sign_fixture <content_path|NONE> <key_file|NONE> <template.json> <output.json> [context_sha256_override]
  "$PY" "$SIGN_FIXTURE" "$CANON_PY" "$1" "$2" "$3" "$4" "${5:-}"
}

KEYFILE="$WORK/context-key"
printf '%s' "$TESTKEY" > "$KEYFILE"

# ---------------------------------------------------------------------------
# Content, registry, and weakening-verdict fixtures.
# ---------------------------------------------------------------------------

CONTENT_VALID="$WORK/project-context.yaml"
cat > "$CONTENT_VALID" <<'EOF'
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
EOF

CONTENT_OTHER="$WORK/project-context-other.yaml"
cat > "$CONTENT_OTHER" <<'EOF'
schema: sdd-project-context/v1
workflow:
  spec_profile: lite
  artifact_layout: lite-three-file
  capability_enforcement: advisory
EOF

CONTENT_DUP_COMPONENT="$WORK/project-context-dup.yaml"
cat > "$CONTENT_DUP_COMPONENT" <<'EOF'
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
components:
  - id: dup-id
  - id: dup-id
EOF

REGISTRY_VALID="$WORK/sdd/approver-registry.yaml"
mkdir -p "$WORK/sdd"
cat > "$REGISTRY_VALID" <<'EOF'
schema: sdd-approver-registry/v1
approvers:
  - id: alice
    name: Alice Example
  - id: bob
    name: Bob Example
EOF

REGISTRY_EMPTY="$WORK/registry-empty.yaml"
cat > "$REGISTRY_EMPTY" <<'EOF'
schema: sdd-approver-registry/v1
approvers: []
EOF

REGISTRY_DUP="$WORK/registry-dup.yaml"
cat > "$REGISTRY_DUP" <<'EOF'
schema: sdd-approver-registry/v1
approvers:
  - id: dup-approver
    name: First
  - id: dup-approver
    name: Second
EOF

# A full 9-category weakening_verdict object, two_person_required: true.
VERDICT_TWO_PERSON_REQUIRED='"weakening_verdict": {
    "policy_weakening": true,
    "categories": {
      "capability_enforcement_weakened": "weakened",
      "capability_removed": "n/a",
      "component_path_narrowed": "not_weakened",
      "public_distribution_descoped": "n/a",
      "criticality_lowered": "n/a",
      "provider_allowlist_widened": "n/a",
      "production_write_path_changed": "n/a",
      "required_gate_removed": "n/a",
      "spec_profile_full_to_lite": "not_weakened"
    },
    "two_person_required": true,
    "cooldown_hours": null
  }'

VERDICT_NOT_WEAKENING='"weakening_verdict": {
    "policy_weakening": false,
    "categories": {
      "capability_enforcement_weakened": "not_weakened",
      "capability_removed": "n/a",
      "component_path_narrowed": "not_weakened",
      "public_distribution_descoped": "n/a",
      "criticality_lowered": "n/a",
      "provider_allowlist_widened": "n/a",
      "production_write_path_changed": "n/a",
      "required_gate_removed": "n/a",
      "spec_profile_full_to_lite": "not_weakened"
    },
    "two_person_required": false,
    "cooldown_hours": 24
  }'

# template_bootstrap <approver> <second_approver_json> <effective_at_json> -> path
write_template() {
  out=$1; approver=$2; second_json=$3; effective_json=$4; predecessor_json=$5; verdict_json=$6; epoch=$7
  cat > "$out" <<EOF
{
  "schema": "sdd-project-context-approval/v1",
  "context_sha256": "sha256:$(printf '0%.0s' $(seq 1 64) | head -c 64)",
  "primary_approval": {"status": "Approved", "approver": "$approver", "approved_at": "2026-01-01T00:00:00Z"},
  "second_approval": $second_json,
  "effective_at": $effective_json,
  "predecessor_context_sha256": $predecessor_json,
  $verdict_json,
  "approval_epoch": $epoch
}
EOF
}

# ---------------------------------------------------------------------------
# TEST-015: positive proof -- AC-015. Correct hash, HMAC, registered+
# distinct approvers, null effective_at, bootstrap verdict.
# ---------------------------------------------------------------------------

T015_TPL="$WORK/t015_tpl.json"
write_template "$T015_TPL" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
T015_SIDECAR="$WORK/t015_sidecar.json"
sign_fixture "$CONTENT_VALID" "$KEYFILE" "$T015_TPL" "$T015_SIDECAR"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$CONTENT_VALID" --sidecar "$T015_SIDECAR" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 0 ] && grep -q VALID "$WORK/out"; then
  pass "TEST-015 positive fixture (correct hash/HMAC/registered approver/null effective_at) validates PASS"
else
  fail "TEST-015 positive fixture (correct hash/HMAC/registered approver/null effective_at) validates PASS (exit $rc; stdout: $(cat "$WORK/out"); stderr: $(cat "$WORK/err"))"
fi

# Two-distinct-approvers positive fixture, non-null effective_at (elapsed).
T015B_TPL="$WORK/t015b_tpl.json"
write_template "$T015B_TPL" alice '{"status": "Approved", "approver": "bob", "approved_at": "2026-01-01T00:05:00Z"}' '"2020-01-01T00:00:00Z"' 'null' '"weakening_verdict": null' 1
T015B_SIDECAR="$WORK/t015b_sidecar.json"
sign_fixture "$CONTENT_VALID" "$KEYFILE" "$T015B_TPL" "$T015B_SIDECAR"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$CONTENT_VALID" --sidecar "$T015B_SIDECAR" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 0 ]; then
  pass "TEST-015 positive fixture (two distinct registered approvers, elapsed effective_at) validates PASS"
else
  fail "TEST-015 positive fixture (two distinct registered approvers, elapsed effective_at) validates PASS (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# TEST-014: six independent rejection fixtures -- AC-014.
# ---------------------------------------------------------------------------

# (1) content-schema violation (incl. duplicate-id): content file has two
# components[] entries sharing the same id -- passes canonicalization and
# would hash/sign fine, but validate-approval-sidecar must reject it BEFORE
# even comparing the hash.
T014A_TPL="$WORK/t014a_tpl.json"
write_template "$T014A_TPL" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
T014A_SIDECAR="$WORK/t014a_sidecar.json"
sign_fixture "$CONTENT_DUP_COMPONENT" "$KEYFILE" "$T014A_TPL" "$T014A_SIDECAR"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$CONTENT_DUP_COMPONENT" --sidecar "$T014A_SIDECAR" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 33 ] && grep -q DUPLICATE_COMPONENT_ID "$WORK/err"; then
  pass "TEST-014 (1) content-schema violation (duplicate components[].id) rejected (DUPLICATE_COMPONENT_ID)"
else
  fail "TEST-014 (1) content-schema violation (duplicate components[].id) rejected (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# (2) hash mismatch: sidecar's context_sha256 was computed for a DIFFERENT
# content file than the one presented for validation; HMAC is otherwise
# perfectly valid over the (wrong) context_sha256 it does carry.
T014B_TPL="$WORK/t014b_tpl.json"
write_template "$T014B_TPL" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
T014B_SIDECAR="$WORK/t014b_sidecar.json"
sign_fixture "$CONTENT_OTHER" "$KEYFILE" "$T014B_TPL" "$T014B_SIDECAR"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$CONTENT_VALID" --sidecar "$T014B_SIDECAR" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 39 ] && grep -q HASH_MISMATCH "$WORK/err"; then
  pass "TEST-014 (2) hash mismatch rejected (HASH_MISMATCH)"
else
  fail "TEST-014 (2) hash mismatch rejected (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# (3) HMAC mismatch: hash matches, but the sidecar was signed under a
# DIFFERENT key -- proving hash match alone is never sufficient.
T014C_TPL="$WORK/t014c_tpl.json"
write_template "$T014C_TPL" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
T014C_SIDECAR="$WORK/t014c_sidecar.json"
WRONGKEYFILE="$WORK/wrong-key"
printf 'a-different-key-entirely' > "$WRONGKEYFILE"
sign_fixture "$CONTENT_VALID" "$WRONGKEYFILE" "$T014C_TPL" "$T014C_SIDECAR"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$CONTENT_VALID" --sidecar "$T014C_SIDECAR" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 40 ] && grep -q HMAC_MISMATCH "$WORK/err"; then
  pass "TEST-014 (3) HMAC mismatch (context_sha256 matches; hmac signed under a different key) rejected (HMAC_MISMATCH)"
else
  fail "TEST-014 (3) HMAC mismatch rejected (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# (4) unregistered approver: primary_approval.approver is not present in
# the approver registry, hash/HMAC otherwise perfectly valid.
T014D_TPL="$WORK/t014d_tpl.json"
write_template "$T014D_TPL" mallory 'null' 'null' 'null' '"weakening_verdict": null' 1
T014D_SIDECAR="$WORK/t014d_sidecar.json"
sign_fixture "$CONTENT_VALID" "$KEYFILE" "$T014D_TPL" "$T014D_SIDECAR"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$CONTENT_VALID" --sidecar "$T014D_SIDECAR" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 41 ] && grep -q UNREGISTERED_APPROVER "$WORK/err"; then
  pass "TEST-014 (4) unregistered approver id rejected (UNREGISTERED_APPROVER)"
else
  fail "TEST-014 (4) unregistered approver id rejected (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# (5) duplicate approver identity: primary_approval.approver ==
# second_approval.approver (the SAME registered id twice) -- a shape
# generate-approval-sidecar.py itself refuses to PRODUCE, so this fixture
# is hand-signed to prove the validator ALSO independently rejects it if
# it is ever presented (a hand-edited-after-signing or alternate-tool
# scenario, requirements.md's own stated rationale).
T014E_TPL="$WORK/t014e_tpl.json"
write_template "$T014E_TPL" alice '{"status": "Approved", "approver": "alice", "approved_at": "2026-01-01T00:05:00Z"}' 'null' 'null' '"weakening_verdict": null' 1
T014E_SIDECAR="$WORK/t014e_sidecar.json"
sign_fixture "$CONTENT_VALID" "$KEYFILE" "$T014E_TPL" "$T014E_SIDECAR"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$CONTENT_VALID" --sidecar "$T014E_SIDECAR" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 10 ] && grep -q DUPLICATE_APPROVER_IDENTITY "$WORK/err"; then
  pass "TEST-014 (5) duplicate approver identity (primary == second) rejected (DUPLICATE_APPROVER_IDENTITY)"
else
  fail "TEST-014 (5) duplicate approver identity rejected (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# (6) future effective_at: hash/HMAC/approver all valid, but effective_at
# is in the future relative to validation time.
T014F_TPL="$WORK/t014f_tpl.json"
write_template "$T014F_TPL" alice 'null' '"2099-01-01T00:00:00Z"' 'null' '"weakening_verdict": null' 1
T014F_SIDECAR="$WORK/t014f_sidecar.json"
sign_fixture "$CONTENT_VALID" "$KEYFILE" "$T014F_TPL" "$T014F_SIDECAR"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$CONTENT_VALID" --sidecar "$T014F_SIDECAR" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 42 ] && grep -q EFFECTIVE_AT_NOT_YET_REACHED "$WORK/err"; then
  pass "TEST-014 (6) future effective_at rejected (EFFECTIVE_AT_NOT_YET_REACHED)"
else
  fail "TEST-014 (6) future effective_at rejected (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# TEST-020: cooldown enforcement (generation + validation) -- AC-020. Uses
# the REAL generate-approval-sidecar.py CLI (--effective-at), matching
# AC-020's own "solo-approver policy-weakening sidecar gets effective_at =
# signing time + 24h" description.
# ---------------------------------------------------------------------------

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" "$GEN_SH" \
  --schema sdd-project-context-approval/v1 \
  --content "$CONTENT_VALID" \
  --approver alice \
  --status Approved \
  --effective-at "2099-06-01T00:00:00Z" \
  --live-sidecar "$WORK/no-such-live-sidecar.json" \
  --stage-dir "$WORK/stage-t020-future" >"$WORK/out" 2>"$WORK/err")
T020_FUTURE="$WORK/stage-t020-future/project-context.approval.json"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$CONTENT_VALID" --sidecar "$T020_FUTURE" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 42 ] && grep -q EFFECTIVE_AT_NOT_YET_REACHED "$WORK/err"; then
  pass "TEST-020 validator rejects applying a cooldown sidecar before its effective_at"
else
  fail "TEST-020 validator rejects applying a cooldown sidecar before its effective_at (exit $rc; stderr: $(cat "$WORK/err"))"
fi

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" "$GEN_SH" \
  --schema sdd-project-context-approval/v1 \
  --content "$CONTENT_VALID" \
  --approver alice \
  --status Approved \
  --effective-at "2020-01-01T00:00:00Z" \
  --live-sidecar "$WORK/no-such-live-sidecar.json" \
  --stage-dir "$WORK/stage-t020-past" >"$WORK/out" 2>"$WORK/err")
T020_PAST="$WORK/stage-t020-past/project-context.approval.json"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$CONTENT_VALID" --sidecar "$T020_PAST" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 0 ]; then
  pass "TEST-020 validator accepts applying a cooldown sidecar after its effective_at has elapsed"
else
  fail "TEST-020 validator accepts applying a cooldown sidecar after its effective_at has elapsed (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# TEST-019: two-person enforcement, incl. same-identity refusal -- AC-019.
#
# TEST-019 discharge note (T-006 carry-forward obligation 4, tasks.md T-006
# Scope): AC-019's frozen text describes THREE cases as
# generate-approval-sidecar.py's OWN behavior ("refuses to sign" /
# "signs successfully" / "refuses to sign with DUPLICATE_APPROVER_IDENTITY").
# Case (c) IS implemented at generation time (T-003 checks
# primary_approval.approver != second_approval.approver before any
# hashing). Case (a) is NOT implemented at generation time -- T-003's
# generator has no mechanism to consult a weakening_verdict's
# two_person_required field at all (T-005 QG seq0353 observation,
# `reports/notes/epic-189-a1-carryover-items.md`) -- so this case is
# discharged end-to-end instead: the REAL generator signs it (documenting
# the actual, current generator behavior), and THIS validator -- the
# design's actual canonical enforcement point (obligation 4b) -- rejects
# the result. Case (b) is a genuine positive case at BOTH layers.
# ---------------------------------------------------------------------------

mkdir -p "$WORK/t019/sdd/.approved-context"
cp "$CONTENT_VALID" "$WORK/t019/baseline.yaml"
cp "$CONTENT_OTHER" "$WORK/t019/candidate.yaml"
cp "$WORK/t019/baseline.yaml" "$WORK/t019/sdd/.approved-context/project-context.approved.yaml"
cp "$REGISTRY_VALID" "$WORK/t019/sdd/approver-registry.yaml"
cat > "$WORK/t019/live-sidecar.json" <<'EOF'
{"schema": "sdd-project-context-approval/v1", "context_sha256": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", "approval_epoch": 1}
EOF

# (a) solo primary_approval against a policy-weakening candidate
# (baseline capability_enforcement: required -> candidate: advisory, a
# genuine weakening per design.md's implemented category #1): T-003
# CURRENTLY signs this (documented gap); the validator rejects it.
(cd "$WORK/t019" && SDD_CONTEXT_KEY="$TESTKEY" "$GEN_SH" \
  --schema sdd-project-context-approval/v1 \
  --content candidate.yaml \
  --approver alice \
  --status Approved \
  --live-sidecar live-sidecar.json \
  --stage-dir stage-solo >"$WORK/out" 2>"$WORK/err")
gen_solo_rc=$?
if [ "$gen_solo_rc" = 0 ]; then
  pass "TEST-019 (a) [discharge note] generate-approval-sidecar.py currently SIGNS a solo-approved two-person-required transition (documented T-003 gap, not this task's to fix)"
else
  fail "TEST-019 (a) [discharge note] generate-approval-sidecar.py's documented current behavior (sign, exit 0) changed unexpectedly (exit $gen_solo_rc; stderr: $(cat "$WORK/err"))"
fi
T019_SOLO="$WORK/t019/stage-solo/project-context.approval.json"
if [ -f "$T019_SOLO" ] && "$PY" -c "
import json
d = json.load(open('$T019_SOLO'))
assert d['weakening_verdict']['two_person_required'] is True
assert d['weakening_verdict']['policy_weakening'] is True
assert d['second_approval'] is None
" 2>"$WORK/err"; then
  pass "TEST-019 (a) the signed solo sidecar carries a two_person_required:true verdict with second_approval: null (the exact underapproved shape)"
else
  fail "TEST-019 (a) the signed solo sidecar carries the expected underapproved shape: $(cat "$WORK/err")"
fi

(cd "$WORK/t019" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content candidate.yaml --sidecar stage-solo/project-context.approval.json --approver-registry sdd/approver-registry.yaml)
rc=$?
if [ "$rc" = 43 ] && grep -q WEAKENING_PROVENANCE_UNDERAPPROVED "$WORK/err"; then
  pass "TEST-019 (a) validate-approval-sidecar.py REJECTS the solo-approved two-person-required sidecar (WEAKENING_PROVENANCE_UNDERAPPROVED) -- the canonical enforcement point (obligation 4b)"
else
  fail "TEST-019 (a) validate-approval-sidecar.py rejects the solo-approved two-person-required sidecar (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# (b) two DISTINCT registered approver ids: signs successfully at BOTH
# layers.
(cd "$WORK/t019" && SDD_CONTEXT_KEY="$TESTKEY" "$GEN_SH" \
  --schema sdd-project-context-approval/v1 \
  --content candidate.yaml \
  --approver alice \
  --second-approver bob \
  --status Approved \
  --live-sidecar live-sidecar.json \
  --stage-dir stage-two >"$WORK/out" 2>"$WORK/err")
rc=$?
if [ "$rc" = 0 ]; then
  pass "TEST-019 (b) generate-approval-sidecar.py signs successfully with two DISTINCT registered approver ids"
else
  fail "TEST-019 (b) generate-approval-sidecar.py signs with two distinct approvers (exit $rc; stderr: $(cat "$WORK/err"))"
fi
(cd "$WORK/t019" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content candidate.yaml --sidecar stage-two/project-context.approval.json --approver-registry sdd/approver-registry.yaml)
rc=$?
if [ "$rc" = 0 ]; then
  pass "TEST-019 (b) validate-approval-sidecar.py accepts the two-distinct-approver sidecar"
else
  fail "TEST-019 (b) validate-approval-sidecar.py accepts the two-distinct-approver sidecar (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# (c) second_approval.approver == primary_approval.approver: T-003 ITSELF
# refuses to sign (DUPLICATE_APPROVER_IDENTITY), before any hashing.
(cd "$WORK/t019" && SDD_CONTEXT_KEY="$TESTKEY" "$GEN_SH" \
  --schema sdd-project-context-approval/v1 \
  --content candidate.yaml \
  --approver alice \
  --second-approver alice \
  --status Approved \
  --live-sidecar live-sidecar.json \
  --stage-dir stage-dup >"$WORK/out" 2>"$WORK/err")
rc=$?
if [ "$rc" = 10 ] && grep -q DUPLICATE_APPROVER_IDENTITY "$WORK/err"; then
  pass "TEST-019 (c) generate-approval-sidecar.py refuses to sign when second_approval.approver == primary_approval.approver (DUPLICATE_APPROVER_IDENTITY)"
else
  fail "TEST-019 (c) generate-approval-sidecar.py refuses same-identity signing (exit $rc; stderr: $(cat "$WORK/err"))"
fi
if [ -e "$WORK/t019/stage-dup" ]; then
  fail "TEST-019 (c) same-identity refusal writes NO staged artifact"
else
  pass "TEST-019 (c) same-identity refusal writes NO staged artifact"
fi

# ---------------------------------------------------------------------------
# TEST-046: zero-identity structural fail-closed-validating consequence
# (structural half; the verdict half is T-005's) -- AC-046. T-004's
# schema-valid `approvers: []` fixture is combined with a signed sidecar;
# since no id can EVER resolve against an empty registry, the validator
# refuses (UNREGISTERED_APPROVER, the structural consequence of "no id can
# ever resolve"). generate-approval-sidecar.py does not itself consult the
# registry for approver-identity purposes at signing time (identity
# checking is REQ-005's/this validator's own step, T-004 Out of Scope:
# "T-006 re-derives identity/duplicate-identity checks against this
# schema's data shape") -- so it signs regardless of registry state; this
# is the SAME documented gap-shape as TEST-019 (a), discharged the same
# way: this suite exercises the REAL generator's actual behavior and
# proves THIS validator is the enforcement point.
# ---------------------------------------------------------------------------

T046_TPL="$WORK/t046_tpl.json"
write_template "$T046_TPL" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
T046_SIDECAR="$WORK/t046_sidecar.json"
sign_fixture "$CONTENT_VALID" "$KEYFILE" "$T046_TPL" "$T046_SIDECAR"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$CONTENT_VALID" --sidecar "$T046_SIDECAR" --approver-registry "$REGISTRY_EMPTY")
rc=$?
if [ "$rc" = 41 ] && grep -q UNREGISTERED_APPROVER "$WORK/err"; then
  pass "TEST-046 validate-approval-sidecar.py refuses to validate against a zero-entry approvers:[] registry (no id can ever resolve, UNREGISTERED_APPROVER)"
else
  fail "TEST-046 validate-approval-sidecar.py refuses to validate against a zero-entry registry (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# AC-045 PRODUCTION discharge: sdd/approver-registry.yaml with a duplicate
# approvers[].id -- PASSES plain JSON Schema (M18-equivalent, already
# proven by tests/approver-registry-schema.tests.sh's own inline harness)
# but is rejected by THIS validator (DUPLICATE_APPROVER_REGISTRY_ID),
# discharging the PRODUCTION half T-004's suite could not (T-006 did not
# yet exist at T-004's implementation time). The ordering assertion
# ("run BEFORE REQ-006's distinct-identity count", AC-045) is discharged
# structurally: THIS check (an independent semantic-validator layer) never
# consults or depends on detect-policy-weakening.py's own
# _count_distinct_registry_identities (which still silently dedupes via a
# bare set() -- a T-005 residual gap, out of T-006's scope to fix, noted
# in the implementation report) -- any consumer that respects REQ-005's
# validation contract is blocked here before a duplicate-id registry could
# ever reach a two-person computation trusted downstream.
# ---------------------------------------------------------------------------

T045_TPL="$WORK/t045_tpl.json"
write_template "$T045_TPL" dup-approver 'null' 'null' 'null' '"weakening_verdict": null' 1
T045_SIDECAR="$WORK/t045_sidecar.json"
sign_fixture "$CONTENT_VALID" "$KEYFILE" "$T045_TPL" "$T045_SIDECAR"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$CONTENT_VALID" --sidecar "$T045_SIDECAR" --approver-registry "$REGISTRY_DUP")
rc=$?
if [ "$rc" = 36 ] && grep -q DUPLICATE_APPROVER_REGISTRY_ID "$WORK/err"; then
  pass "AC-045 PRODUCTION discharge: validate-approval-sidecar.py rejects a duplicate-id approver-registry.yaml (DUPLICATE_APPROVER_REGISTRY_ID)"
else
  fail "AC-045 PRODUCTION discharge: validate-approval-sidecar.py rejects a duplicate-id approver-registry.yaml (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# OBLIGATION 2: non-bootstrap sidecar (predecessor_context_sha256 present)
# carrying weakening_verdict: null violates requirements.md:310-312's
# invariant -- rejected (WEAKENING_VERDICT_MISSING).
# ---------------------------------------------------------------------------

T_OBL2_TPL="$WORK/t_obl2_tpl.json"
write_template "$T_OBL2_TPL" alice 'null' 'null' '"sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"' '"weakening_verdict": null' 2
T_OBL2_SIDECAR="$WORK/t_obl2_sidecar.json"
sign_fixture "$CONTENT_VALID" "$KEYFILE" "$T_OBL2_TPL" "$T_OBL2_SIDECAR"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$CONTENT_VALID" --sidecar "$T_OBL2_SIDECAR" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 46 ] && grep -q WEAKENING_VERDICT_MISSING "$WORK/err"; then
  pass "OBLIGATION 2 a non-bootstrap sidecar (predecessor_context_sha256 present) with weakening_verdict: null is rejected (WEAKENING_VERDICT_MISSING)"
else
  fail "OBLIGATION 2 non-bootstrap null-verdict rejected (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# The SAME shape via --verify-provenance mode too (both code paths call
# the identical bootstrap-invariant check).
(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --verify-provenance --sidecar "$T_OBL2_SIDECAR")
rc=$?
if [ "$rc" = 46 ] && grep -q WEAKENING_VERDICT_MISSING "$WORK/err"; then
  pass "OBLIGATION 2 --verify-provenance also rejects a non-bootstrap null-verdict sidecar (WEAKENING_VERDICT_MISSING)"
else
  fail "OBLIGATION 2 --verify-provenance rejects non-bootstrap null-verdict (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# TEST-043: post-publish provenance re-provability + underapproval
# rejection via --verify-provenance -- AC-043.
# ---------------------------------------------------------------------------

mkdir -p "$WORK/t043/sdd/.approved-context"
cp "$CONTENT_VALID" "$WORK/t043/baseline.yaml"
cp "$CONTENT_OTHER" "$WORK/t043/candidate.yaml"
cp "$WORK/t043/baseline.yaml" "$WORK/t043/sdd/.approved-context/project-context.approved.yaml"
cp "$REGISTRY_VALID" "$WORK/t043/sdd/approver-registry.yaml"
cat > "$WORK/t043/live-sidecar.json" <<'EOF'
{"schema": "sdd-project-context-approval/v1", "context_sha256": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", "approval_epoch": 1}
EOF

# Two-distinct-approver (correctly-approved) weakening sidecar.
(cd "$WORK/t043" && SDD_CONTEXT_KEY="$TESTKEY" "$GEN_SH" \
  --schema sdd-project-context-approval/v1 \
  --content candidate.yaml \
  --approver alice \
  --second-approver bob \
  --status Approved \
  --live-sidecar live-sidecar.json \
  --stage-dir stage-approved >"$WORK/out" 2>"$WORK/err")
T043_APPROVED="$WORK/t043/stage-approved/project-context.approval.json"

# Solo (underapproved) weakening sidecar -- signed by the REAL generator
# (documented T-003 gap, same as TEST-019 (a)).
(cd "$WORK/t043" && SDD_CONTEXT_KEY="$TESTKEY" "$GEN_SH" \
  --schema sdd-project-context-approval/v1 \
  --content candidate.yaml \
  --approver alice \
  --status Approved \
  --live-sidecar live-sidecar.json \
  --stage-dir stage-solo >"$WORK/out" 2>"$WORK/err")
T043_SOLO="$WORK/t043/stage-solo/project-context.approval.json"

# Simulate "post-publish, predecessor anchor gone": move BOTH sidecars to a
# fresh directory that never had sdd/.approved-context/* at all, and
# invoke --verify-provenance (which needs only --sidecar, no anchor, no
# --content).
mkdir -p "$WORK/t043-postpublish"
cp "$T043_APPROVED" "$WORK/t043-postpublish/approved.json"
cp "$T043_SOLO" "$WORK/t043-postpublish/solo.json"

(cd "$WORK/t043-postpublish" && SDD_CONTEXT_KEY="$TESTKEY" run_val --verify-provenance --sidecar approved.json)
rc=$?
if [ "$rc" = 0 ]; then
  pass "TEST-043 --verify-provenance PASSES a correctly-two-person-approved weakening sidecar after its predecessor anchor is gone"
else
  fail "TEST-043 --verify-provenance passes a correctly-approved sidecar post-publish (exit $rc; stderr: $(cat "$WORK/err"))"
fi

(cd "$WORK/t043-postpublish" && SDD_CONTEXT_KEY="$TESTKEY" run_val --verify-provenance --sidecar solo.json)
rc=$?
if [ "$rc" = 43 ] && grep -q WEAKENING_PROVENANCE_UNDERAPPROVED "$WORK/err"; then
  pass "TEST-043 --verify-provenance FAILS an underapproved (solo) weakening sidecar after its predecessor anchor is gone (WEAKENING_PROVENANCE_UNDERAPPROVED)"
else
  fail "TEST-043 --verify-provenance fails an underapproved sidecar post-publish (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# Bootstrap-case fixture: approval_epoch: 1, predecessor_context_sha256:
# null, weakening_verdict: null -- independently passes --verify-provenance
# with no second-approval requirement implied.
T043_BOOTSTRAP_TPL="$WORK/t043_bootstrap_tpl.json"
write_template "$T043_BOOTSTRAP_TPL" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
T043_BOOTSTRAP="$WORK/t043_bootstrap_sidecar.json"
sign_fixture "$CONTENT_VALID" "$KEYFILE" "$T043_BOOTSTRAP_TPL" "$T043_BOOTSTRAP"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --verify-provenance --sidecar "$T043_BOOTSTRAP")
rc=$?
if [ "$rc" = 0 ]; then
  pass "TEST-043 --verify-provenance PASSES the bootstrap case (approval_epoch:1, weakening_verdict: null) with no second-approval requirement implied"
else
  fail "TEST-043 --verify-provenance passes the bootstrap case (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# Reader-side fixture: a live TRANSACTION.json journal naming the sidecar
# path being read fails closed (HUMAN_COPY_PUBLISH_IN_PROGRESS).
mkdir -p "$WORK/t043-inprogress/sdd/.staging/some-nonce"
cp "$T043_APPROVED" "$WORK/t043-inprogress/sidecar.json"
cat > "$WORK/t043-inprogress/sdd/.staging/some-nonce/TRANSACTION.json" <<'EOF'
{
  "nonce": "some-nonce",
  "status": "in-progress",
  "targets": [
    {"live_path": "sidecar.json", "pre_hash": "ABSENT", "post_hash": "deadbeef"}
  ]
}
EOF
(cd "$WORK/t043-inprogress" && SDD_CONTEXT_KEY="$TESTKEY" run_val --verify-provenance --sidecar sidecar.json)
rc=$?
if [ "$rc" = 21 ] && grep -q HUMAN_COPY_PUBLISH_IN_PROGRESS "$WORK/err"; then
  pass "TEST-043 a live TRANSACTION.json naming the sidecar path fails closed (HUMAN_COPY_PUBLISH_IN_PROGRESS)"
else
  fail "TEST-043 a live TRANSACTION.json naming the sidecar path fails closed (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# The SAME reader-side check on the STANDARD validation path (--content +
# --sidecar), naming the content path this time.
mkdir -p "$WORK/t043-inprogress2/sdd/.staging/some-nonce"
cp "$CONTENT_VALID" "$WORK/t043-inprogress2/project-context.yaml"
cp "$REGISTRY_VALID" "$WORK/t043-inprogress2/registry.yaml" 2>/dev/null || cp "$REGISTRY_VALID" "$WORK/t043-inprogress2/registry.yaml"
cp "$T015_SIDECAR" "$WORK/t043-inprogress2/sidecar.json"
cat > "$WORK/t043-inprogress2/sdd/.staging/some-nonce/TRANSACTION.json" <<'EOF'
{
  "nonce": "some-nonce",
  "status": "in-progress",
  "targets": [
    {"live_path": "project-context.yaml", "pre_hash": "ABSENT", "post_hash": "deadbeef"}
  ]
}
EOF
(cd "$WORK/t043-inprogress2" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content project-context.yaml --sidecar sidecar.json --approver-registry registry.yaml)
rc=$?
if [ "$rc" = 21 ] && grep -q HUMAN_COPY_PUBLISH_IN_PROGRESS "$WORK/err"; then
  pass "TEST-043 standard validation path: a live TRANSACTION.json naming the content path fails closed (HUMAN_COPY_PUBLISH_IN_PROGRESS)"
else
  fail "TEST-043 standard validation path fails closed on a live journal naming --content (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# APPROVER_REGISTRY_SCHEMA_VIOLATION: a malformed (non-array 'approvers')
# registry is rejected distinctly from a duplicate-id one.
# ---------------------------------------------------------------------------

REGISTRY_MALFORMED="$WORK/registry-malformed.yaml"
cat > "$REGISTRY_MALFORMED" <<'EOF'
schema: sdd-approver-registry/v1
approvers: not-an-array
EOF

T_MALREG_TPL="$WORK/t_malreg_tpl.json"
write_template "$T_MALREG_TPL" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
T_MALREG_SIDECAR="$WORK/t_malreg_sidecar.json"
sign_fixture "$CONTENT_VALID" "$KEYFILE" "$T_MALREG_TPL" "$T_MALREG_SIDECAR"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$CONTENT_VALID" --sidecar "$T_MALREG_SIDECAR" --approver-registry "$REGISTRY_MALFORMED")
rc=$?
if [ "$rc" = 35 ] && grep -q APPROVER_REGISTRY_SCHEMA_VIOLATION "$WORK/err"; then
  pass "TEST-HARDEN a malformed (non-array approvers) registry is rejected (APPROVER_REGISTRY_SCHEMA_VIOLATION)"
else
  fail "TEST-HARDEN malformed registry rejected (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# TEST-HARDEN: no resolvable SDD_CONTEXT_KEY -- NO_CONTEXT_KEY, never a
# skip.
# ---------------------------------------------------------------------------

FAKE_HOME_NOKEY="$WORK/fake-home-nokey"
mkdir -p "$FAKE_HOME_NOKEY"
(cd "$WORK" && env -u SDD_CONTEXT_KEY -u SDD_CONTEXT_KEY_FILE HOME="$FAKE_HOME_NOKEY" \
  "$VAL_SH" --content "$CONTENT_VALID" --sidecar "$T015_SIDECAR" --approver-registry "$REGISTRY_VALID" >"$WORK/out" 2>"$WORK/err")
rc=$?
if [ "$rc" = 11 ] && grep -q NO_CONTEXT_KEY "$WORK/err"; then
  pass "TEST-HARDEN no resolvable SDD_CONTEXT_KEY: exit 11/NO_CONTEXT_KEY, never a skip"
else
  fail "TEST-HARDEN no resolvable SDD_CONTEXT_KEY (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# TEST-HARDEN: usage errors are rejected cleanly, never a traceback.
# ---------------------------------------------------------------------------

(cd "$WORK" && "$VAL_SH" --sidecar "$T015_SIDECAR" >"$WORK/out" 2>"$WORK/err")
rc=$?
if [ "$rc" = 2 ] && ! grep -q Traceback "$WORK/err"; then
  pass "TEST-HARDEN missing --content (without --verify-provenance) is a clean usage error, never a traceback"
else
  fail "TEST-HARDEN missing --content usage error (exit $rc; stderr: $(cat "$WORK/err"))"
fi

(cd "$WORK" && "$VAL_SH" --content "$CONTENT_VALID" --sidecar "$T015_SIDECAR" --verify-provenance >"$WORK/out" 2>"$WORK/err")
rc=$?
if [ "$rc" = 2 ]; then
  pass "TEST-HARDEN --content combined with --verify-provenance is a clean usage error"
else
  fail "TEST-HARDEN --content + --verify-provenance usage error (exit $rc; stderr: $(cat "$WORK/err"))"
fi

(cd "$WORK" && "$VAL_SH" --content "$CONTENT_VALID" --sidecar "$WORK/no-such-file.json" --approver-registry "$REGISTRY_VALID" >"$WORK/out" 2>"$WORK/err")
rc=$?
if [ "$rc" = 37 ] && grep -q SIDECAR_UNREADABLE "$WORK/err" && ! grep -q Traceback "$WORK/err"; then
  pass "TEST-HARDEN a missing --sidecar file is rejected cleanly (SIDECAR_UNREADABLE), never a traceback"
else
  fail "TEST-HARDEN missing --sidecar file (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# OBLIGATION 1: executable key-parity proof (AC-013-style 4-case matrix)
# against sdd-hook-guard.py's _resolve_sudo_key AND
# generate-approval-sidecar.py's resolve_context_key. This validator's OWN
# resolve_context_key() is independently reimplemented (never imported).
# ---------------------------------------------------------------------------

PARITY="$WORK/key_parity.py"
cat > "$PARITY" <<'PYEOF'
import importlib.util
import os
import sys

VAL_PATH, GEN_PATH, GUARD_PATH, CASE = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
ARG = sys.argv[5:]


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


val = _load("_val_approval_sidecar", VAL_PATH)
gen = _load("_gen_approval_sidecar", GEN_PATH)
guard = _load("_sdd_hook_guard", GUARD_PATH)

if CASE == "env":
    os.environ["SDD_CONTEXT_KEY"] = "byte-parity-value"
    os.environ["SDD_SUDO_KEY"] = "byte-parity-value"
elif CASE == "file":
    (path,) = ARG
    os.environ.pop("SDD_CONTEXT_KEY", None)
    os.environ.pop("SDD_SUDO_KEY", None)
    os.environ["SDD_CONTEXT_KEY_FILE"] = path
    os.environ["SDD_SUDO_KEY_FILE"] = path
elif CASE == "home":
    (home,) = ARG
    for var in ("SDD_CONTEXT_KEY", "SDD_SUDO_KEY", "SDD_CONTEXT_KEY_FILE", "SDD_SUDO_KEY_FILE"):
        os.environ.pop(var, None)
    os.environ["HOME"] = home
elif CASE == "none":
    for var in ("SDD_CONTEXT_KEY", "SDD_SUDO_KEY", "SDD_CONTEXT_KEY_FILE", "SDD_SUDO_KEY_FILE"):
        os.environ.pop(var, None)
    os.environ["HOME"] = ARG[0]
else:
    raise SystemExit("unknown case")

a = val.resolve_context_key()
b = gen.resolve_context_key()
c = guard._resolve_sudo_key()

if a == b == c:
    sys.exit(0)
sys.stderr.write("MISMATCH: validator=%r generator=%r guard=%r\n" % (a, b, c))
sys.exit(1)
PYEOF

if "$PY" "$PARITY" "$VAL_PY" "$GEN_PY" "$HOOK_GUARD_PY" env >"$WORK/out" 2>"$WORK/err"; then
  pass "OBLIGATION 1 (TEST-013-style) case 1/4 (env var): validate-approval-sidecar.py's resolve_context_key() matches generate-approval-sidecar.py's AND sdd-hook-guard.py's _resolve_sudo_key byte-for-byte"
else
  fail "OBLIGATION 1 case 1/4 (env var) key-resolution byte-parity: $(cat "$WORK/err")"
fi

printf '\xef\xbb\xbf  byte-parity-file-value  \r\n' > "$WORK/t013_keyfile"
if "$PY" "$PARITY" "$VAL_PY" "$GEN_PY" "$HOOK_GUARD_PY" file "$WORK/t013_keyfile" >"$WORK/out" 2>"$WORK/err"; then
  pass "OBLIGATION 1 (TEST-013-style) case 2/4 (env-file, BOM+whitespace-stripped): identical key bytes across all three resolvers"
else
  fail "OBLIGATION 1 case 2/4 (env-file) key-resolution byte-parity: $(cat "$WORK/err")"
fi

FAKE_HOME_PARITY="$WORK/fake-home-parity"
mkdir -p "$FAKE_HOME_PARITY/.sdd"
printf '\xef\xbb\xbf  byte-parity-home-value  \r\n' > "$FAKE_HOME_PARITY/.sdd/context-key"
printf '\xef\xbb\xbf  byte-parity-home-value  \r\n' > "$FAKE_HOME_PARITY/.sdd/sudo-key"
if "$PY" "$PARITY" "$VAL_PY" "$GEN_PY" "$HOOK_GUARD_PY" home "$FAKE_HOME_PARITY" >"$WORK/out" 2>"$WORK/err"; then
  pass "OBLIGATION 1 (TEST-013-style) case 3/4 (home-path, BOM+whitespace-stripped): identical key bytes across all three resolvers"
else
  fail "OBLIGATION 1 case 3/4 (home-path) key-resolution byte-parity: $(cat "$WORK/err")"
fi

FAKE_HOME_EMPTY="$WORK/fake-home-parity-empty"
mkdir -p "$FAKE_HOME_EMPTY"
if "$PY" "$PARITY" "$VAL_PY" "$GEN_PY" "$HOOK_GUARD_PY" none "$FAKE_HOME_EMPTY" >"$WORK/out" 2>"$WORK/err"; then
  pass "OBLIGATION 1 (TEST-013-style) case 4/4 (none resolvable): all three resolvers return None"
else
  fail "OBLIGATION 1 case 4/4 (none resolvable) key-resolution byte-parity: $(cat "$WORK/err")"
fi

# ---------------------------------------------------------------------------
# Self-registration.
# ---------------------------------------------------------------------------

if grep -q 'validate-approval-sidecar\.tests\.sh' "$ROOT/tests/run-all.sh"; then
  pass "self-registration: tests/validate-approval-sidecar.tests.sh registered in tests/run-all.sh"
else
  fail "self-registration: tests/validate-approval-sidecar.tests.sh registered in tests/run-all.sh"
fi
if grep -q 'validate-approval-sidecar\.tests\.ps1' "$ROOT/tests/run-all.ps1"; then
  pass "self-registration: tests/validate-approval-sidecar.tests.ps1 registered in tests/run-all.ps1"
else
  fail "self-registration: tests/validate-approval-sidecar.tests.ps1 registered in tests/run-all.ps1"
fi
if [ -f "$ROOT/tests/validate-approval-sidecar.tests.ps1" ]; then
  pass "self-registration: tests/validate-approval-sidecar.tests.ps1 twin exists"
else
  fail "self-registration: tests/validate-approval-sidecar.tests.ps1 twin exists"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
