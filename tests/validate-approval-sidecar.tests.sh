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
  if [ "${CT_CANONICAL_FIXTURES:-0}" = 1 ]; then
    local fixture_root fixture_dir content_path sidecar_path i
    local args=("$@")
    fixture_root="$(mktemp -d "$WORK/concept-case.XXXXXX")" || return 1
    fixture_dir="$fixture_root/specs/$CT_FEATURE"
    mkdir -p "$fixture_dir" || return 1
    for ((i=0; i<${#args[@]}; i++)); do
      case "${args[i]}" in
        --content)
          content_path="${args[i+1]}"
          if [ -f "$content_path" ]; then cp "$content_path" "$fixture_dir/concept-test.json"; fi
          if [ -f "$(dirname "$content_path")/concept-test.md" ]; then
            cp "$(dirname "$content_path")/concept-test.md" "$fixture_dir/concept-test.md"
          fi
          args[i+1]="$fixture_dir/concept-test.json"
          ;;
        --sidecar)
          sidecar_path="${args[i+1]}"
          if [ -f "$sidecar_path" ]; then cp "$sidecar_path" "$fixture_dir/concept-test.approval.json"; fi
          args[i+1]="$fixture_dir/concept-test.approval.json"
          ;;
      esac
    done
    (cd "$fixture_root" && "$VAL_SH" "${args[@]}") >"$WORK/out" 2>"$WORK/err"
    return $?
  fi
  "$VAL_SH" "$@" >"$WORK/out" 2>"$WORK/err"
  return $?
}

# Staged-artifact layout resolver (mirrors tests/generate-approval-sidecar.tests.sh's
# staged_rel_sidecar/staged_sidecar_path -- see that file's comment for full
# rationale). The generator's staged bundle mirrors the sidecar's LIVE
# repo-relative path (sdd/project-context.approval.json) rather than a bare
# basename; this resolver locates it under either layout so these
# path-agnostic tests keep passing before AND after that layout changes.
staged_rel_sidecar() {
  # staged_rel_sidecar <stagedir> -> sidecar path RELATIVE to <stagedir>
  if [ -f "$1/sdd/project-context.approval.json" ]; then
    printf 'sdd/project-context.approval.json'
  else
    printf 'project-context.approval.json'
  fi
}
staged_sidecar_path() { printf '%s/%s' "$1" "$(staged_rel_sidecar "$1")"; }

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

# A syntactically-valid (schema pattern ^[0-9a-f]{64}$) but obviously-fake
# 64-hex-digit placeholder, generated rather than hand-counted so the digit
# count can never silently drift (as a hand-typed literal previously did:
# see OBLIGATION 2's predecessor_context_sha256 fixture below).
HEX64_PLACEHOLDER="$(printf 'c%.0s' $(seq 1 64))"

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
T020_FUTURE="$(staged_sidecar_path "$WORK/stage-t020-future")"

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
T020_PAST="$(staged_sidecar_path "$WORK/stage-t020-past")"

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
cat > "$WORK/t019/live-sidecar.json" <<EOF
{"schema": "sdd-project-context-approval/v1", "context_sha256": "sha256:$HEX64_PLACEHOLDER", "approval_epoch": 1}
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
T019_SOLO="$(staged_sidecar_path "$WORK/t019/stage-solo")"
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

(cd "$WORK/t019" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content candidate.yaml --sidecar "stage-solo/$(staged_rel_sidecar "$WORK/t019/stage-solo")" --approver-registry sdd/approver-registry.yaml)
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
(cd "$WORK/t019" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content candidate.yaml --sidecar "stage-two/$(staged_rel_sidecar "$WORK/t019/stage-two")" --approver-registry sdd/approver-registry.yaml)
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
# predecessor_context_sha256 must independently conform to the schema's
# ^sha256:[0-9a-f]{64}$ pattern (contracts/approval-sidecar.schema.json) --
# generated the same way write_template's own context_sha256 placeholder is,
# rather than a hand-counted literal, so the digit count can never drift.
write_template "$T_OBL2_TPL" alice 'null' 'null' "\"sha256:$(printf 'd%.0s' $(seq 1 64))\"" '"weakening_verdict": null' 2
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
cat > "$WORK/t043/live-sidecar.json" <<EOF
{"schema": "sdd-project-context-approval/v1", "context_sha256": "sha256:$HEX64_PLACEHOLDER", "approval_epoch": 1}
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
T043_APPROVED="$(staged_sidecar_path "$WORK/t043/stage-approved")"

# Solo (underapproved) weakening sidecar -- signed by the REAL generator
# (documented T-003 gap, same as TEST-019 (a)).
(cd "$WORK/t043" && SDD_CONTEXT_KEY="$TESTKEY" "$GEN_SH" \
  --schema sdd-project-context-approval/v1 \
  --content candidate.yaml \
  --approver alice \
  --status Approved \
  --live-sidecar live-sidecar.json \
  --stage-dir stage-solo >"$WORK/out" 2>"$WORK/err")
T043_SOLO="$(staged_sidecar_path "$WORK/t043/stage-solo")"

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
# SEQ0355 REMEDY (quality-gate seq0355 Major finding): gate (5)'s
# `second_id == primary_id` clause (validate-approval-sidecar.py:678) was
# UNREACHABLE-in-coverage on the standard path (gate (3)'s
# DUPLICATE_APPROVER_IDENTITY always intercepts a same-identity sidecar
# first) and had NO assertion at all under --verify-provenance -- a
# refactor deleting that clause would leave every prior assertion green.
# This fixture (two_person_required: true, second_approval.approver ==
# primary_approval.approver, both individually registered) pins BOTH
# halves of the 2x2 (null-vs-duplicate) x (standard-vs-verify-provenance)
# matrix's remaining untested cell: (a) --verify-provenance reaches gate
# (5) directly and rejects on the duplicate-identity clause specifically
# (WEAKENING_PROVENANCE_UNDERAPPROVED); (b) the standard path is pinned to
# STILL exit via gate (3) first (DUPLICATE_APPROVER_IDENTITY), never
# reaching gate (5) for this same fixture -- the two-path split itself is
# now a regression-locked behavior, not merely an implementer's claim.
# ---------------------------------------------------------------------------

T_DUPID_VERDICT_TPL="$WORK/t_dupid_verdict_tpl.json"
write_template "$T_DUPID_VERDICT_TPL" alice '{"status": "Approved", "approver": "alice", "approved_at": "2026-01-01T00:05:00Z"}' 'null' 'null' "$VERDICT_TWO_PERSON_REQUIRED" 1
T_DUPID_VERDICT_SIDECAR="$WORK/t_dupid_verdict_sidecar.json"
sign_fixture "$CONTENT_VALID" "$KEYFILE" "$T_DUPID_VERDICT_TPL" "$T_DUPID_VERDICT_SIDECAR"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --verify-provenance --sidecar "$T_DUPID_VERDICT_SIDECAR")
rc=$?
if [ "$rc" = 43 ] && grep -q WEAKENING_PROVENANCE_UNDERAPPROVED "$WORK/err"; then
  pass "SEQ0355 REMEDY (a) --verify-provenance rejects a two-person-required sidecar whose second_approval.approver duplicates primary_approval.approver (WEAKENING_PROVENANCE_UNDERAPPROVED, gate 5's duplicate clause)"
else
  fail "SEQ0355 REMEDY (a) --verify-provenance rejects duplicate-identity two-person-required sidecar (exit $rc; stderr: $(cat "$WORK/err"))"
fi

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$CONTENT_VALID" --sidecar "$T_DUPID_VERDICT_SIDECAR" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 10 ] && grep -q DUPLICATE_APPROVER_IDENTITY "$WORK/err"; then
  pass "SEQ0355 REMEDY (b) the SAME fixture on the standard path is intercepted by gate 3 (DUPLICATE_APPROVER_IDENTITY), never reaching gate 5 -- the two-path split is pinned"
else
  fail "SEQ0355 REMEDY (b) standard path intercepted by gate 3 for the same fixture (exit $rc; stderr: $(cat "$WORK/err"))"
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
# TEST-PR229-VAL: the standard path enforces SIDECAR schema conformance.
#
# External review of PR #229 (Codex), finding 3. _load_sidecar checked only
# that the nine top-level keys were PRESENT -- nothing about their values --
# and contracts/approval-sidecar.schema.json was never loaded on the
# standard path at all. Every fixture below carries a GENUINELY VALID HMAC
# (re-signed after mutation via this suite's own sign_fixture, exactly as
# every other fixture in this file is built), so the HMAC gate cannot be
# what rejects it: what is proven is schema conformance and nothing else.
# All of these reported `VALID`, exit 0, before the fix.
#
# WHICH SCRIPT THIS EXERCISES: plugins/sdd-quality-loop/scripts/
# validate-approval-sidecar.py is R-10 protected, so the fix lives in its
# STAGED CANDIDATE under specs/epic-189-a1-project-context/human-copy/ until
# a human applies it. These assertions therefore run the STAGED candidate.
# They keep passing unchanged after the apply (staged and live are then
# byte-identical); to re-point them at the live script, replace
# STAGED_VAL_PY with $VAL_PY.
#
# The staged Python script cannot be executed where it sits: it resolves
# canonicalize-sdd-yaml.py via Path(__file__).parent and the repo root via
# Path(__file__).parents[3] (for contracts/). It is therefore copied into a
# SHADOW tree reproducing the real repo layout -- which is also what a human
# gets after applying.
# ===========================================================================

STAGED_VAL_PY="$ROOT/specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py"

if [ -f "$STAGED_VAL_PY" ]; then
  pass "TEST-PR229-VAL staged validate-approval-sidecar.py candidate exists"
else
  fail "TEST-PR229-VAL staged validate-approval-sidecar.py candidate exists"
fi

SHADOW229V="$WORK/shadow229v"
mkdir -p "$SHADOW229V/plugins/sdd-quality-loop/scripts"
cp "$ROOT"/plugins/sdd-quality-loop/scripts/*.py "$SHADOW229V/plugins/sdd-quality-loop/scripts/"
cp "$STAGED_VAL_PY" "$SHADOW229V/plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py"
cp -R "$ROOT/contracts" "$SHADOW229V/contracts"
SHADOW_VAL="$SHADOW229V/plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py"

run_val_pr229() {
  ( cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" "$PY" "$SHADOW_VAL" "$@" ) >"$WORK/out" 2>"$WORK/err"
  return $?
}

# Base template + its faithfully-signed sidecar (the positive control).
PR229_TPL="$WORK/pr229_tpl.json"
write_template "$PR229_TPL" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
PR229_OK="$WORK/pr229_ok.json"
sign_fixture "$CONTENT_VALID" "$KEYFILE" "$PR229_TPL" "$PR229_OK"

run_val_pr229 --content "$CONTENT_VALID" --sidecar "$PR229_OK" --approver-registry "$REGISTRY_VALID"
rc=$?
if [ "$rc" = 0 ] && grep -q VALID "$WORK/out"; then
  pass "TEST-PR229-VAL positive control: a conformant, correctly-signed sidecar still validates (no false positive introduced)"
else
  fail "TEST-PR229-VAL positive control: a conformant, correctly-signed sidecar still validates (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# pr229_mutate <name> <python-statement> -- derives a mutated TEMPLATE from
# PR229_TPL, then signs it, so the resulting sidecar's HMAC is genuinely
# valid over the mutated content.
pr229_mutate() {
  pm_name=$1
  pm_code=$2
  "$PY" -c "
import json
obj = json.load(open('$PR229_TPL'))
$pm_code
json.dump(obj, open('$WORK/pr229_${pm_name}_tpl.json', 'w'))
"
  sign_fixture "$CONTENT_VALID" "$KEYFILE" "$WORK/pr229_${pm_name}_tpl.json" "$WORK/pr229_${pm_name}.json"
}

pr229_expect_violation() {
  pv_label=$1
  pv_sidecar=$2
  run_val_pr229 --content "$CONTENT_VALID" --sidecar "$pv_sidecar" --approver-registry "$REGISTRY_VALID"
  pv_rc=$?
  if [ "$pv_rc" = 47 ] && grep -q SIDECAR_SCHEMA_VIOLATION "$WORK/err"; then
    pass "TEST-PR229-VAL $pv_label is rejected (SIDECAR_SCHEMA_VIOLATION, exit 47)"
  else
    fail "TEST-PR229-VAL $pv_label is rejected (SIDECAR_SCHEMA_VIOLATION, exit 47); got exit $pv_rc, stdout '$(cat "$WORK/out")', stderr '$(cat "$WORK/err")'"
  fi
}

# (a) const violation: the schema pins primary_approval.status to "Approved".
pr229_mutate status "obj['primary_approval']['status'] = 'Rejected'"
pr229_expect_violation "primary_approval.status = 'Rejected'" "$WORK/pr229_status.json"

# (b) additionalProperties: false, at the top level.
pr229_mutate extratop "obj['smuggled_field'] = 'x'"
pr229_expect_violation "a smuggled extra top-level property" "$WORK/pr229_extratop.json"

# (c) additionalProperties: false inside the \$ref'd 'approval' definition
#     (this also proves \$ref resolution actually happens).
pr229_mutate extranested "obj['primary_approval']['nickname'] = 'al'"
pr229_expect_violation "an extra property inside primary_approval (\$ref'd definition)" "$WORK/pr229_extranested.json"

# (d) minimum: 1.
pr229_mutate epochzero "obj['approval_epoch'] = 0"
pr229_expect_violation "approval_epoch = 0 (schema minimum 1)" "$WORK/pr229_epochzero.json"

# (e) type: integer.
pr229_mutate epochstr "obj['approval_epoch'] = '1'"
pr229_expect_violation "approval_epoch = '1' (schema type integer)" "$WORK/pr229_epochstr.json"

# (f) pattern ^[0-9a-f]{64}$ on hmac. NOT re-signed -- the signature BYTES
#     are unchanged and only their letter case is flipped, which is exactly
#     why _check_hmac (comparing stored_hmac.lower()) never caught it. This
#     is the previously-registered uppercase-hmac carryover; it is now
#     rejected structurally by the schema rather than by tightening the
#     constant-time comparison, which must keep normalizing so that a case
#     difference can never become a timing signal.
"$PY" -c "
import json
obj = json.load(open('$PR229_OK'))
obj['hmac'] = obj['hmac'].upper()
json.dump(obj, open('$WORK/pr229_hmacupper.json', 'w'))
"
pr229_expect_violation "an all-uppercase hmac (the registered carryover)" "$WORK/pr229_hmacupper.json"

# (g) DOCUMENTED LIMIT, asserted rather than implied. The review also listed
#     a malformed `approved_at`. That is NOT a schema-conformance failure:
#     the schema types the field {"type": "string", "format": "date-time"},
#     draft-07 defines `format` as an ANNOTATION rather than an assertion,
#     and this epic's own purpose-built subset validators (the T-003 harness
#     in tests/generate-approval-sidecar.tests.sh and the production
#     _schema_validate promoted from it) both deliberately omit `format`.
#     Enforcing it would require a NEW date-time gate -- a new requirement,
#     not a conformance fix -- so the current, correct-per-schema behaviour
#     is pinned here to keep the boundary visible instead of assumed.
pr229_mutate approvedat "obj['primary_approval']['approved_at'] = 'not-a-date'"
run_val_pr229 --content "$CONTENT_VALID" --sidecar "$WORK/pr229_approvedat.json" --approver-registry "$REGISTRY_VALID"
rc=$?
if [ "$rc" = 0 ]; then
  pass "TEST-PR229-VAL DOCUMENTED LIMIT: a malformed approved_at is schema-CONFORMANT (draft-07 'format' is an annotation) and is still accepted -- no date-time gate exists for approved_at"
else
  fail "TEST-PR229-VAL DOCUMENTED LIMIT: a malformed approved_at is schema-conformant and still accepted (got exit $rc: $(cat "$WORK/err"))"
fi

# (h) --verify-provenance is deliberately NOT bound to the current schema
#     revision, so a historical sidecar stays re-provable indefinitely.
run_val_pr229 --verify-provenance --sidecar "$WORK/pr229_extratop.json"
rc=$?
if [ "$rc" = 0 ]; then
  pass "TEST-PR229-VAL --verify-provenance is NOT schema-gated (historical re-provability must not expire when the schema is extended)"
else
  fail "TEST-PR229-VAL --verify-provenance is NOT schema-gated (got exit $rc: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# T-001 (sdd-domain-concept-test, REQ-001/REQ-003): concept-test sidecar
# type (schema `sdd-concept-test-approval/v1`) additive registration --
# reuses this validator's standard content/hash/HMAC/registry pipeline
# (contracts/concept-test.v1.schema.json) against the SAME genuine
# temporary key + registered test approver pattern as every fixture above.
# Every concept-test content file below is feature-local JSON (not a
# sdd/*.yaml global singleton), hashed in `--input-format json` mode.
#
# Includes the owner-approved fixed sibling Markdown projection and
# table-driven all-field agreement checks in this candidate revision.
# ---------------------------------------------------------------------------

MAKE_CONCEPT="$WORK/make_concept_content.py"
cat > "$MAKE_CONCEPT" <<'PYEOF'
import hashlib
import json
import os
import sys
sys.path.insert(0, os.path.join(sys.argv[-1], "plugins/sdd-quality-loop/scripts"))
from concept_test_render import render_concept_test_md

if sys.argv[1] in ("--json-unknown-key", "--empty-inputs"):
    content_path = sys.argv[2]
    with open(content_path, encoding="utf-8") as f: obj = json.load(f)
    if sys.argv[1] == "--empty-inputs": obj["inputs"] = []
    else: obj["unexpected"] = True
    with open(content_path, "w", encoding="utf-8") as f: json.dump(obj, f)
    with open(os.path.join(os.path.dirname(content_path), "concept-test.md"), "wb") as f:
        f.write(render_concept_test_md(obj))
    sys.exit(0)

if sys.argv[1] == "--md-variant":
    content_path, variant = sys.argv[2:4]
    with open(content_path, encoding="utf-8") as f:
        obj = json.load(f)
    md_path = os.path.join(os.path.dirname(content_path), "concept-test.md")
    if variant == "missing":
        os.unlink(md_path)
        sys.exit(0)
    if variant == "crlf":
        data = render_concept_test_md(obj).replace(b"\n", b"\r\n")
    elif variant == "prose":
        data = render_concept_test_md(obj) + b"extra prose\n"
    else:
        if variant == "feature": obj["feature"] += "-other"
        elif variant == "schema": obj["schema"] = "other-schema"
        elif variant == "proposal": obj["proposal"] = "RESPONSIBILITY_CONFLICT" if obj["proposal"] == "FITS_EXISTING_CONCEPTS" else "FITS_EXISTING_CONCEPTS"
        elif variant == "rationale": obj["rationale"] += " other"
        elif variant == "relation": obj["relation"] = "same" if obj["relation"] != "same" else "different"
        elif variant == "input_path": obj["inputs"][0]["path"] += "-other"
        elif variant == "input_hash": obj["inputs"][0]["sha256"] = "0" * 64
        elif variant == "decision": obj["decision"] = "proceed" if obj["decision"] is None else "rejected" if obj["decision"] != "rejected" else "proceed"
        elif variant == "second_path": obj["inputs"][1]["path"] += "-other"
        elif variant == "second_hash": obj["inputs"][1]["sha256"] = "0" * 64
        elif variant == "second_omit": obj["inputs"].pop()
        elif variant == "second_reorder": obj["inputs"].reverse()
        elif variant == "unknown_key": obj["unexpected"] = True
        else: raise ValueError(variant)
        data = render_concept_test_md(obj)
    with open(md_path, "wb") as f: f.write(data)
    sys.exit(0)

output, feature, proposal, decision, relation, rationale, input_path = sys.argv[1:8]
with open(input_path, "rb") as f:
    digest = hashlib.sha256(f.read()).hexdigest()
obj = {
    "schema": "sdd-concept-test/v1",
    "feature": feature,
    "proposal": proposal,
    "rationale": rationale,
    "relation": relation,
    "decision": None if decision == "NONE" else decision,
    "inputs": [{"path": input_path, "sha256": digest}],
}
if len(sys.argv) == 10:
    with open(sys.argv[8], "rb") as f:
        second_digest = hashlib.sha256(f.read()).hexdigest()
    obj["inputs"].append({"path": sys.argv[8], "sha256": second_digest})
with open(output, "w", encoding="utf-8") as f:
    json.dump(obj, f)
with open(os.path.join(os.path.dirname(output), "concept-test.md"), "wb") as f:
    f.write(render_concept_test_md(obj))
PYEOF

make_concept_content() {
  # make_concept_content <output.json> <feature> <proposal> <decision|NONE> <relation> <rationale> <input_path>
  "$PY" "$MAKE_CONCEPT" "$@" "$ROOT"
}

concept_hash() {
  # concept_hash <content.json> -> sha256:<hex>, via canonicalize-sdd-yaml.py
  # --input-format json --hash-only (the feature-local JSON content path,
  # never the --input-format yaml path the two pre-existing schema ids use).
  "$PY" "$CANON_PY" "$1" --input-format json --hash-only
}

# write_concept_template <out> <approver> <second_json> <effective_json> <predecessor_json> <verdict_json> <epoch>
write_concept_template() {
  wct_out=$1; wct_approver=$2; wct_second=$3; wct_effective=$4; wct_predecessor=$5; wct_verdict=$6; wct_epoch=$7
  cat > "$wct_out" <<EOF
{
  "schema": "sdd-concept-test-approval/v1",
  "context_sha256": "sha256:$(printf '0%.0s' $(seq 1 64) | head -c 64)",
  "primary_approval": {"status": "Approved", "approver": "$wct_approver", "approved_at": "2026-01-01T00:00:00Z"},
  "second_approval": $wct_second,
  "effective_at": $wct_effective,
  "predecessor_context_sha256": $wct_predecessor,
  $wct_verdict,
  "approval_epoch": $wct_epoch
}
EOF
}

CT_FEATURE="sdd-domain-concept-test"
CT_CANONICAL_FIXTURES=1
CT_INPUT="$WORK/ct-input.txt"
printf 'concept test read input fixture\n' > "$CT_INPUT"

# ---------------------------------------------------------------------------
# TEST-006 (AC-006): FITS_EXISTING_CONCEPTS, decision null, valid signed
# evidence -- gate passes (VALID).
# ---------------------------------------------------------------------------

make_concept_content "$WORK/ct_test006.json" "$CT_FEATURE" FITS_EXISTING_CONCEPTS NONE same \
  "Existing Fulfillment concept already covers this responsibility." "$CT_INPUT"
CT006_HASH="$(concept_hash "$WORK/ct_test006.json")"
write_concept_template "$WORK/ct_test006_tpl.json" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
sign_fixture NONE "$KEYFILE" "$WORK/ct_test006_tpl.json" "$WORK/ct_test006_sidecar.json" "$CT006_HASH"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$WORK/ct_test006.json" --sidecar "$WORK/ct_test006_sidecar.json" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 0 ] && grep -q VALID "$WORK/out"; then
  pass "TEST-001/006 concept-test FITS_EXISTING_CONCEPTS valid evidence and sibling Markdown validate PASS"
else
  fail "TEST-001/006 concept-test FITS_EXISTING_CONCEPTS valid evidence and sibling Markdown validate PASS (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# TEST-007/015-022 (AC-007): the 3 non-FITS proposals x the 3 decision
# values, each a valid signed-evidence positive fixture -- the validator's
# own scope is evidence VALIDITY, never continue/defer/stop ROUTING (that
# is T-003's job per Governing Amendments), so every one of these 9 cases
# must validate PASS regardless of which decision string it carries.
# ---------------------------------------------------------------------------

concept_positive_case() {
  cpc_testid=$1; cpc_proposal=$2; cpc_decision=$3
  cpc_content="$WORK/ct_${cpc_testid}.json"
  cpc_tpl="$WORK/ct_${cpc_testid}_tpl.json"
  cpc_sidecar="$WORK/ct_${cpc_testid}_sidecar.json"
  make_concept_content "$cpc_content" "$CT_FEATURE" "$cpc_proposal" "$cpc_decision" different \
    "Rationale for $cpc_proposal with decision=$cpc_decision." "$CT_INPUT"
  cpc_hash="$(concept_hash "$cpc_content")"
  write_concept_template "$cpc_tpl" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
  sign_fixture NONE "$KEYFILE" "$cpc_tpl" "$cpc_sidecar" "$cpc_hash"
  (cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$cpc_content" --sidecar "$cpc_sidecar" --approver-registry "$REGISTRY_VALID")
  cpc_rc=$?
  if [ "$cpc_rc" = 0 ]; then
    pass "$cpc_testid concept-test $cpc_proposal + decision=$cpc_decision valid signed evidence validates PASS"
  else
    fail "$cpc_testid concept-test $cpc_proposal + decision=$cpc_decision valid signed evidence validates PASS (exit $cpc_rc; stderr: $(cat "$WORK/err"))"
  fi
}

concept_positive_case TEST-007 NEW_CONCEPT_CANDIDATE proceed
concept_positive_case TEST-015 NEW_CONCEPT_CANDIDATE defer-to-domain-update
concept_positive_case TEST-016 NEW_CONCEPT_CANDIDATE rejected
concept_positive_case TEST-017 RESPONSIBILITY_CONFLICT proceed
concept_positive_case TEST-018 RESPONSIBILITY_CONFLICT defer-to-domain-update
concept_positive_case TEST-019 RESPONSIBILITY_CONFLICT rejected
concept_positive_case TEST-020 REQUIRES_HUMAN_DECISION proceed
concept_positive_case TEST-021 REQUIRES_HUMAN_DECISION defer-to-domain-update
concept_positive_case TEST-022 REQUIRES_HUMAN_DECISION rejected

# ---------------------------------------------------------------------------
# TEST-002/003/004 (AC-002/003/004): each non-FITS proposal with decision
# omitted (null) is BLOCKed (CONCEPT_TEST_DECISION_MISSING) -- an LLM
# proposal classification alone never satisfies REQ-003's machine gate.
# ---------------------------------------------------------------------------

concept_decision_missing_case() {
  cdm_testid=$1; cdm_proposal=$2
  cdm_content="$WORK/ct_${cdm_testid}.json"
  cdm_tpl="$WORK/ct_${cdm_testid}_tpl.json"
  cdm_sidecar="$WORK/ct_${cdm_testid}_sidecar.json"
  make_concept_content "$cdm_content" "$CT_FEATURE" "$cdm_proposal" NONE undecided \
    "Rationale for $cdm_proposal with no decision recorded." "$CT_INPUT"
  cdm_hash="$(concept_hash "$cdm_content")"
  write_concept_template "$cdm_tpl" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
  sign_fixture NONE "$KEYFILE" "$cdm_tpl" "$cdm_sidecar" "$cdm_hash"
  (cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$cdm_content" --sidecar "$cdm_sidecar" --approver-registry "$REGISTRY_VALID")
  cdm_rc=$?
  if [ "$cdm_rc" = 48 ] && grep -q CONCEPT_TEST_DECISION_MISSING "$WORK/err"; then
    pass "$cdm_testid concept-test $cdm_proposal with decision=null is BLOCKed (CONCEPT_TEST_DECISION_MISSING)"
  else
    fail "$cdm_testid concept-test $cdm_proposal decision-missing BLOCK (exit $cdm_rc; stderr: $(cat "$WORK/err"))"
  fi
}

concept_decision_missing_case TEST-002 NEW_CONCEPT_CANDIDATE
concept_decision_missing_case TEST-003 RESPONSIBILITY_CONFLICT
concept_decision_missing_case TEST-004 REQUIRES_HUMAN_DECISION

# ---------------------------------------------------------------------------
# TEST-005 (AC-005): v2-target evidence JSON file absent is BLOCKed.
# ---------------------------------------------------------------------------

write_concept_template "$WORK/ct_test005_tpl.json" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
sign_fixture NONE "$KEYFILE" "$WORK/ct_test005_tpl.json" "$WORK/ct_test005_sidecar.json" "sha256:$(printf '0%.0s' $(seq 1 64))"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$WORK/ct_test005_nonexistent.json" --sidecar "$WORK/ct_test005_sidecar.json" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 31 ] && grep -q CONTENT_CANONICALIZATION_FAILED "$WORK/err"; then
  pass "TEST-005 concept-test evidence JSON file absent is BLOCKed (CONTENT_CANONICALIZATION_FAILED)"
else
  fail "TEST-005 concept-test evidence JSON file absent is BLOCKed (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# TEST-014 (AC-014): corrupt/malformed JSON evidence is rejected.
# ---------------------------------------------------------------------------

CT_MALFORMED="$WORK/ct_malformed.json"
printf '{not valid json' > "$CT_MALFORMED"
write_concept_template "$WORK/ct_malformed_tpl.json" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
sign_fixture NONE "$KEYFILE" "$WORK/ct_malformed_tpl.json" "$WORK/ct_malformed_sidecar.json" "sha256:$(printf '0%.0s' $(seq 1 64))"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$CT_MALFORMED" --sidecar "$WORK/ct_malformed_sidecar.json" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 31 ] && grep -q CONTENT_CANONICALIZATION_FAILED "$WORK/err"; then
  pass "TEST-014 concept-test corrupt JSON evidence is rejected (CONTENT_CANONICALIZATION_FAILED)"
else
  fail "TEST-014 concept-test corrupt JSON evidence rejected (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# TEST-028/029 (AC-014): an unknown proposal / unknown decision enum value
# is rejected by schema conformance (CONTENT_SCHEMA_VIOLATION).
# ---------------------------------------------------------------------------

make_concept_content "$WORK/ct_test028.json" "$CT_FEATURE" UNKNOWN_PROPOSAL_VALUE proceed different \
  "Unknown proposal value." "$CT_INPUT"
CT028_HASH="$(concept_hash "$WORK/ct_test028.json")"
write_concept_template "$WORK/ct_test028_tpl.json" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
sign_fixture NONE "$KEYFILE" "$WORK/ct_test028_tpl.json" "$WORK/ct_test028_sidecar.json" "$CT028_HASH"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$WORK/ct_test028.json" --sidecar "$WORK/ct_test028_sidecar.json" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 32 ] && grep -q CONTENT_SCHEMA_VIOLATION "$WORK/err"; then
  pass "TEST-028 concept-test unknown proposal value is rejected (CONTENT_SCHEMA_VIOLATION)"
else
  fail "TEST-028 concept-test unknown proposal value rejected (exit $rc; stderr: $(cat "$WORK/err"))"
fi

make_concept_content "$WORK/ct_test029.json" "$CT_FEATURE" NEW_CONCEPT_CANDIDATE not-a-real-decision different \
  "Unknown decision value." "$CT_INPUT"
CT029_HASH="$(concept_hash "$WORK/ct_test029.json")"
write_concept_template "$WORK/ct_test029_tpl.json" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
sign_fixture NONE "$KEYFILE" "$WORK/ct_test029_tpl.json" "$WORK/ct_test029_sidecar.json" "$CT029_HASH"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$WORK/ct_test029.json" --sidecar "$WORK/ct_test029_sidecar.json" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 32 ] && grep -q CONTENT_SCHEMA_VIOLATION "$WORK/err"; then
  pass "TEST-029 concept-test unknown decision value is rejected (CONTENT_SCHEMA_VIOLATION)"
else
  fail "TEST-029 concept-test unknown decision value rejected (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# TEST-030 (AC-015): sidecar file absent is BLOCKed.
# ---------------------------------------------------------------------------

make_concept_content "$WORK/ct_test030.json" "$CT_FEATURE" FITS_EXISTING_CONCEPTS NONE same \
  "Valid evidence; sidecar is absent." "$CT_INPUT"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$WORK/ct_test030.json" --sidecar "$WORK/ct_test030_nonexistent_sidecar.json" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 37 ] && grep -q SIDECAR_UNREADABLE "$WORK/err"; then
  pass "TEST-030 concept-test absent sidecar is BLOCKed (SIDECAR_UNREADABLE)"
else
  fail "TEST-030 concept-test absent sidecar is BLOCKed (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# TEST-031 (AC-015): tampered signature is BLOCKed.
# ---------------------------------------------------------------------------

make_concept_content "$WORK/ct_test031.json" "$CT_FEATURE" FITS_EXISTING_CONCEPTS NONE same \
  "Valid evidence; hmac byte is flipped after signing." "$CT_INPUT"
CT031_HASH="$(concept_hash "$WORK/ct_test031.json")"
write_concept_template "$WORK/ct_test031_tpl.json" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
sign_fixture NONE "$KEYFILE" "$WORK/ct_test031_tpl.json" "$WORK/ct_test031_sidecar.json" "$CT031_HASH"
"$PY" -c "
import json
p = '$WORK/ct_test031_sidecar.json'
d = json.load(open(p))
d['hmac'] = ('1' if d['hmac'][0] == '0' else '0') + d['hmac'][1:]
json.dump(d, open(p, 'w'))
"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$WORK/ct_test031.json" --sidecar "$WORK/ct_test031_sidecar.json" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 40 ] && grep -q HMAC_MISMATCH "$WORK/err"; then
  pass "TEST-031 concept-test tampered signature is BLOCKed (HMAC_MISMATCH)"
else
  fail "TEST-031 concept-test tampered signature is BLOCKed (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# TEST-032 (AC-015): no resolvable SDD_CONTEXT_KEY is BLOCKed, never a skip.
# ---------------------------------------------------------------------------

make_concept_content "$WORK/ct_test032.json" "$CT_FEATURE" FITS_EXISTING_CONCEPTS NONE same \
  "Valid evidence; validated with no resolvable key." "$CT_INPUT"
CT032_HASH="$(concept_hash "$WORK/ct_test032.json")"
write_concept_template "$WORK/ct_test032_tpl.json" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
sign_fixture NONE "$KEYFILE" "$WORK/ct_test032_tpl.json" "$WORK/ct_test032_sidecar.json" "$CT032_HASH"

FAKE_HOME_T032="$WORK/fake-home-t032"
mkdir -p "$FAKE_HOME_T032"
mkdir -p "$WORK/specs/$CT_FEATURE"
cp "$WORK/ct_test032.json" "$WORK/specs/$CT_FEATURE/concept-test.json"
cp "$WORK/concept-test.md" "$WORK/specs/$CT_FEATURE/concept-test.md"
cp "$WORK/ct_test032_sidecar.json" "$WORK/specs/$CT_FEATURE/concept-test.approval.json"
(cd "$WORK" && env -u SDD_CONTEXT_KEY -u SDD_CONTEXT_KEY_FILE HOME="$FAKE_HOME_T032" \
  "$VAL_SH" --content "$WORK/specs/$CT_FEATURE/concept-test.json" --sidecar "$WORK/specs/$CT_FEATURE/concept-test.approval.json" --approver-registry "$REGISTRY_VALID" >"$WORK/out" 2>"$WORK/err")
rc=$?
if [ "$rc" = 11 ] && grep -q NO_CONTEXT_KEY "$WORK/err"; then
  pass "TEST-032 concept-test no resolvable key is BLOCKed (NO_CONTEXT_KEY), never a skip"
else
  fail "TEST-032 concept-test no resolvable key is BLOCKed (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# TEST-033 (AC-015): a correctly-signed sidecar for an UNREGISTERED approver
# is BLOCKed.
# ---------------------------------------------------------------------------

make_concept_content "$WORK/ct_test033.json" "$CT_FEATURE" FITS_EXISTING_CONCEPTS NONE same \
  "Valid evidence; approver is not in the registry." "$CT_INPUT"
CT033_HASH="$(concept_hash "$WORK/ct_test033.json")"
write_concept_template "$WORK/ct_test033_tpl.json" mallory 'null' 'null' 'null' '"weakening_verdict": null' 1
sign_fixture NONE "$KEYFILE" "$WORK/ct_test033_tpl.json" "$WORK/ct_test033_sidecar.json" "$CT033_HASH"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$WORK/ct_test033.json" --sidecar "$WORK/ct_test033_sidecar.json" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 41 ] && grep -q UNREGISTERED_APPROVER "$WORK/err"; then
  pass "TEST-033 concept-test unregistered approver (correct signature) is BLOCKed (UNREGISTERED_APPROVER)"
else
  fail "TEST-033 concept-test unregistered approver is BLOCKed (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# TEST-034 (AC-015): a decision VALUE alone, with no signed sidecar at all,
# is BLOCKed -- a decision string is never itself human-approval evidence.
# ---------------------------------------------------------------------------

make_concept_content "$WORK/ct_test034.json" "$CT_FEATURE" NEW_CONCEPT_CANDIDATE proceed different \
  "A decision string is present, but no sidecar accompanies it." "$CT_INPUT"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$WORK/ct_test034.json" --sidecar "$WORK/ct_test034_no_sidecar.json" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 37 ] && grep -q SIDECAR_UNREADABLE "$WORK/err"; then
  pass "TEST-034 concept-test decision-string-only evidence with no signed sidecar is BLOCKed (SIDECAR_UNREADABLE)"
else
  fail "TEST-034 concept-test decision-only evidence is BLOCKed (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# TEST-035 (AC-016): a read input mutated by 1 byte AFTER signing is
# BLOCKed -- the recorded inputs[].sha256 no longer matches the live file,
# even though context_sha256/hmac (computed over the unchanged JSON
# content) still verify.
# ---------------------------------------------------------------------------

CT_INPUT_035="$WORK/ct-input-test035.txt"
printf 'concept test read input for TEST-035\n' > "$CT_INPUT_035"
make_concept_content "$WORK/ct_test035.json" "$CT_FEATURE" FITS_EXISTING_CONCEPTS NONE same \
  "Valid evidence; the referenced input file is mutated after signing." "$CT_INPUT_035"
CT035_HASH="$(concept_hash "$WORK/ct_test035.json")"
write_concept_template "$WORK/ct_test035_tpl.json" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
sign_fixture NONE "$KEYFILE" "$WORK/ct_test035_tpl.json" "$WORK/ct_test035_sidecar.json" "$CT035_HASH"
printf 'X' >> "$CT_INPUT_035"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$WORK/ct_test035.json" --sidecar "$WORK/ct_test035_sidecar.json" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 50 ] && grep -q CONCEPT_TEST_INPUT_HASH_MISMATCH "$WORK/err"; then
  pass "TEST-035 concept-test a 1-byte-changed read input is BLOCKed (CONCEPT_TEST_INPUT_HASH_MISMATCH)"
else
  fail "TEST-035 concept-test a changed read input is BLOCKed (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# ---------------------------------------------------------------------------
# TEST-036 (AC-016): a read input absent at validation time is BLOCKed.
# ---------------------------------------------------------------------------

CT_INPUT_036="$WORK/ct-input-test036.txt"
printf 'concept test read input for TEST-036 (will be removed)\n' > "$CT_INPUT_036"
make_concept_content "$WORK/ct_test036.json" "$CT_FEATURE" FITS_EXISTING_CONCEPTS NONE same \
  "Valid evidence; the referenced input file is removed after signing." "$CT_INPUT_036"
CT036_HASH="$(concept_hash "$WORK/ct_test036.json")"
write_concept_template "$WORK/ct_test036_tpl.json" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
sign_fixture NONE "$KEYFILE" "$WORK/ct_test036_tpl.json" "$WORK/ct_test036_sidecar.json" "$CT036_HASH"
rm -f "$CT_INPUT_036"

(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$WORK/ct_test036.json" --sidecar "$WORK/ct_test036_sidecar.json" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 49 ] && grep -q CONCEPT_TEST_INPUT_UNREADABLE "$WORK/err"; then
  pass "TEST-036 concept-test an absent read input is BLOCKed (CONCEPT_TEST_INPUT_UNREADABLE)"
else
  fail "TEST-036 concept-test an absent read input is BLOCKed (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# Bad HMAC with an absent content-named path must stop at HMAC, before
# attempting to open that path (the valid-HMAC counterpart is TEST-036).
"$PY" -c 'import json,sys; d=json.load(open(sys.argv[1])); d["hmac"]=("1" if d["hmac"][0]=="0" else "0")+d["hmac"][1:]; json.dump(d,open(sys.argv[2],"w"))' \
  "$WORK/ct_test036_sidecar.json" "$WORK/ct_test036_bad_hmac.json"
(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$WORK/ct_test036.json" --sidecar "$WORK/ct_test036_bad_hmac.json" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 40 ] && grep -q HMAC_MISMATCH "$WORK/err"; then
  pass "concept-test bad HMAC stops before absent input read"
else
  fail "concept-test bad HMAC input-read ordering (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# Unknown signed JSON property is rejected even when Markdown agrees.
make_concept_content "$WORK/ct_unknown_json.json" "$CT_FEATURE" FITS_EXISTING_CONCEPTS NONE same "Unknown-key fixture." "$CT_INPUT"
"$PY" "$MAKE_CONCEPT" --json-unknown-key "$WORK/ct_unknown_json.json" "$ROOT"
CT_UNKNOWN_HASH="$(concept_hash "$WORK/ct_unknown_json.json")"
write_concept_template "$WORK/ct_unknown_json_tpl.json" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
sign_fixture NONE "$KEYFILE" "$WORK/ct_unknown_json_tpl.json" "$WORK/ct_unknown_json_sidecar.json" "$CT_UNKNOWN_HASH"
(cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$WORK/ct_unknown_json.json" --sidecar "$WORK/ct_unknown_json_sidecar.json" --approver-registry "$REGISTRY_VALID")
rc=$?
if [ "$rc" = 32 ] && grep -q CONTENT_SCHEMA_VIOLATION "$WORK/err"; then
  pass "concept-test signed JSON unknown key is BLOCKed by schema"
else
  fail "concept-test signed JSON unknown key schema rejection (exit $rc; stderr: $(cat "$WORK/err"))"
fi

# Standard CLI cardinality controls; mutate before hashing and signing.
for ct_count in 1 0; do
  ct_content="$WORK/ct_cardinality_${ct_count}.json"
  ct_tpl="$WORK/ct_cardinality_${ct_count}_tpl.json"
  ct_sidecar="$WORK/ct_cardinality_${ct_count}_sidecar.json"
  make_concept_content "$ct_content" "$CT_FEATURE" NEW_CONCEPT_CANDIDATE proceed different "Cardinality fixture." "$CT_INPUT" || exit 1
  if [ "$ct_count" = 0 ]; then
    "$PY" "$MAKE_CONCEPT" --empty-inputs "$ct_content" "$ROOT" || exit 1
  fi
  ct_hash="$(concept_hash "$ct_content")" || exit 1
  write_concept_template "$ct_tpl" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
  sign_fixture NONE "$KEYFILE" "$ct_tpl" "$ct_sidecar" "$ct_hash" || exit 1
  (cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$ct_content" --sidecar "$ct_sidecar" --approver-registry "$REGISTRY_VALID")
  ct_rc=$?
  if [ "$ct_count" = 1 ] && [ "$ct_rc" = 0 ] && grep -qx VALID "$WORK/out"; then
    pass "concept-test minItems one input accepted by standard CLI"
  elif [ "$ct_count" = 0 ] && [ "$ct_rc" = 32 ] && grep -Fq 'CONTENT_SCHEMA_VIOLATION: /inputs: fewer than minItems 1' "$WORK/err"; then
    pass "concept-test minItems empty inputs rejected by standard CLI"
  else
    fail "concept-test minItems inputs=$ct_count (exit $ct_rc; stderr: $(cat "$WORK/err"))"
  fi
done

# Every schema field is compared for every proposal. The signed JSON and
# live input stay valid; only the sibling Markdown changes.
ct_md_mismatch_case() {
  cmm_id=$1; cmm_proposal=$2; cmm_decision=$3; cmm_field=$4
  cmm_label=$cmm_id
  case "$cmm_id" in
    TEST-075) cmm_label=TEST-037/078 ;;
    TEST-076) cmm_label=TEST-075 ;;
    TEST-077) cmm_label=TEST-076 ;;
    TEST-078) cmm_label=TEST-077 ;;
  esac
  cmm_content="$WORK/ct_${cmm_id}.json"
  cmm_tpl="$WORK/ct_${cmm_id}_tpl.json"
  cmm_sidecar="$WORK/ct_${cmm_id}_sidecar.json"
  make_concept_content "$cmm_content" "$CT_FEATURE" "$cmm_proposal" "$cmm_decision" same "Markdown mismatch fixture." "$CT_INPUT"
  cmm_hash="$(concept_hash "$cmm_content")"
  write_concept_template "$cmm_tpl" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
  sign_fixture NONE "$KEYFILE" "$cmm_tpl" "$cmm_sidecar" "$cmm_hash"
  "$PY" "$MAKE_CONCEPT" --md-variant "$cmm_content" "$cmm_field" "$ROOT"
  (cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$cmm_content" --sidecar "$cmm_sidecar" --approver-registry "$REGISTRY_VALID")
  cmm_rc=$?
  if [ "$cmm_rc" = 51 ] && grep -q CONCEPT_TEST_MD_MISMATCH "$WORK/err"; then
    pass "$cmm_label $cmm_proposal $cmm_field Markdown mismatch BLOCK"
  else
    fail "$cmm_label $cmm_proposal $cmm_field Markdown mismatch (exit $cmm_rc; stderr: $(cat "$WORK/err"))"
  fi
}

cmm_base=51
for cmm_class in FITS_EXISTING_CONCEPTS NEW_CONCEPT_CANDIDATE RESPONSIBILITY_CONFLICT REQUIRES_HUMAN_DECISION; do
  cmm_decision=proceed
  [ "$cmm_class" = FITS_EXISTING_CONCEPTS ] && cmm_decision=NONE
  for cmm_field in feature proposal rationale relation input_path input_hash; do
    cmm_id=$(printf 'TEST-%03d' "$cmm_base")
    ct_md_mismatch_case "$cmm_id" "$cmm_class" "$cmm_decision" "$cmm_field"
    cmm_base=$((cmm_base + 1))
  done
  cmm_id=$(printf 'TEST-%03d' "$((75 + (cmm_base - 57) / 6))")
  ct_md_mismatch_case "$cmm_id" "$cmm_class" "$cmm_decision" decision
done

CT_INPUT_SECOND="$WORK/ct-input-second.txt"
printf 'second read input\n' > "$CT_INPUT_SECOND"
for cmm_field in schema second_path second_hash second_omit second_reorder unknown_key missing crlf prose; do
  cmm_content="$WORK/ct_extra_${cmm_field}.json"
  make_concept_content "$cmm_content" "$CT_FEATURE" FITS_EXISTING_CONCEPTS NONE same "Two-input fixture." "$CT_INPUT" "$CT_INPUT_SECOND"
  cmm_hash="$(concept_hash "$cmm_content")"
  cmm_tpl="$WORK/ct_extra_${cmm_field}_tpl.json"
  cmm_sidecar="$WORK/ct_extra_${cmm_field}_sidecar.json"
  write_concept_template "$cmm_tpl" alice 'null' 'null' 'null' '"weakening_verdict": null' 1
  sign_fixture NONE "$KEYFILE" "$cmm_tpl" "$cmm_sidecar" "$cmm_hash"
  "$PY" "$MAKE_CONCEPT" --md-variant "$cmm_content" "$cmm_field" "$ROOT"
  (cd "$WORK" && SDD_CONTEXT_KEY="$TESTKEY" run_val --content "$cmm_content" --sidecar "$cmm_sidecar" --approver-registry "$REGISTRY_VALID")
  cmm_rc=$?
  if [ "$cmm_rc" = 51 ] && grep -q CONCEPT_TEST_MD_MISMATCH "$WORK/err"; then
    pass "two-input $cmm_field Markdown mismatch BLOCK"
  else
    fail "two-input $cmm_field Markdown mismatch (exit $cmm_rc; stderr: $(cat "$WORK/err"))"
  fi
done

# ---------------------------------------------------------------------------
# Self-registration.
# ---------------------------------------------------------------------------

# Query executable registration; failed listings never count as membership.
if registered_suites="$(bash "$ROOT/tests/run-all.sh" --list)" &&
  grep -Fx "tests/validate-approval-sidecar.tests.sh" <<< "$registered_suites" >/dev/null; then
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
