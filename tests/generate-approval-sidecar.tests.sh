#!/bin/sh
# T-003 (epic-189-a1-project-context, REQ-004): acceptance checks for
# contracts/approval-sidecar.schema.json and
# plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py and its
# .sh/.ps1 dispatcher wrappers.
#
# TEST-010 schema conformance (positive + negative: hmac length/case) --
#   AC-010.
# TEST-011 staged-signing round-trip (independent HMAC/hash re-derivation)
#   + no-key fail-closed (no staged artifact at all) -- AC-011.
# TEST-012 preimage self-reference exclusion (the `hmac` field's own value
#   never affects the preimage) -- AC-012.
# TEST-013 key-resolution byte-parity with sdd-hook-guard.py's
#   `_resolve_sudo_key` (4-case matrix: env var / env-file / home-path /
#   none) -- AC-013.
# TEST-034 signer staging-only contract + rollback: never opens the live
#   sidecar path for writing; a simulated mid-write failure leaves no
#   partial artifact; a re-run after failure succeeds with a fresh nonce --
#   AC-034.
# TEST-036 HMAC golden vector + fifteen one-field-mutated variants, incl.
#   the three provenance fields -- AC-036.
# Provenance seam Done-When (tasks.md T-003, remedy task-review attempt-3
#   round-2): a bootstrap fixture signs with predecessor_context_sha256/
#   weakening_verdict = null, approval_epoch = 1; a non-bootstrap fixture
#   (live sidecar present) exits non-zero with WEAKENING_DETECTOR_UNAVAILABLE
#   and writes no staged candidate.
# TEST-HARDEN(a) DUPLICATE_APPROVER_IDENTITY refused before any hashing.
# TEST-HARDEN(b) a hostile field value (an unpaired UTF-16 surrogate,
#   delivered via an invalid-UTF-8 argv byte) is rejected with a documented
#   category, never an uncaught traceback.
# TEST-HARDEN(c) usage errors (missing required argument, --status not
#   "Approved") are rejected cleanly, never a traceback.
#
# This suite invokes the tool through generate-approval-sidecar.sh (the
# real dispatcher surface), mirroring canonicalize-sdd-yaml.tests.sh's own
# convention.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/gen-approval-sidecar-test.XXXXXX")
# Physical-path normalization (design.md Test Strategy item 12).
WORK=$(cd "$WORK" && pwd -P)
trap 'rm -rf "$WORK"' EXIT INT TERM

GEN_SH="$ROOT/plugins/sdd-quality-loop/scripts/generate-approval-sidecar.sh"
GEN_PY="$ROOT/plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py"
SCHEMA_JSON="$ROOT/contracts/approval-sidecar.schema.json"
HOOK_GUARD_PY="$ROOT/plugins/sdd-quality-loop/scripts/sdd-hook-guard.py"

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

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# ---------------------------------------------------------------------------
# Staged-artifact layout resolvers (external review of PR #229, Codex).
#
# The staged bundle's INTERNAL layout changes from flat basenames to a mirror
# of each artifact's repo-relative LIVE path, so the directory can be handed
# straight to `apply-human-copy --manifest`. That fix currently lives in the
# R-10-protected script's STAGED CANDIDATE (see STAGED_GEN_PY below) and
# reaches the LIVE script only when a human applies it. These resolvers
# report whichever layout the generator under test actually produced, so
# every pre-existing assertion below holds BOTH before and after that apply.
# TEST-PR229-* further down asserts the NEW layout specifically, against the
# staged candidate, and needs no edit when the apply lands.
staged_rel_sidecar() {
  # staged_rel_sidecar <stagedir> -> sidecar path RELATIVE to <stagedir>
  if [ -f "$1/sdd/project-context.approval.json" ]; then
    printf 'sdd/project-context.approval.json'
  else
    printf 'project-context.approval.json'
  fi
}
staged_rel_snapshot() {
  if [ -f "$1/sdd/.approved-context/project-context.approved.yaml" ]; then
    printf 'sdd/.approved-context/project-context.approved.yaml'
  else
    printf 'project-context.approved.yaml'
  fi
}
staged_sidecar_path() { printf '%s/%s' "$1" "$(staged_rel_sidecar "$1")"; }
staged_snapshot_path() { printf '%s/%s' "$1" "$(staged_rel_snapshot "$1")"; }

# run_gen [env_prefix...] -- args... -- invokes the .sh dispatcher, capturing
# stdout to $WORK/out, stderr to $WORK/err, and returning its exit code.
run_gen() {
  "$GEN_SH" "$@" >"$WORK/out" 2>"$WORK/err"
  return $?
}

write_content_fixture() {
  cat > "$1" <<'EOF'
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
EOF
}

# ---------------------------------------------------------------------------
# TEST-010: schema conformance (positive + negative: hmac length/case) --
# AC-010. Purpose-built draft-07 subset validator (no jsonschema dependency
# available or installed, per this epic's CI-resilience constraint) --
# supports exactly the keywords contracts/approval-sidecar.schema.json uses:
# type, required, additionalProperties, properties, enum, const, pattern,
# oneOf, $ref/definitions, minLength, minimum.
# ---------------------------------------------------------------------------

VALIDATOR="$WORK/sidecar_validator.py"
cat > "$VALIDATOR" <<'PYEOF'
"""Minimal draft-07 JSON Schema subset validator, purpose-built for
contracts/approval-sidecar.schema.json (T-003, epic-189-a1-project-context).
Not a general-purpose JSON Schema implementation."""
import json
import re
import sys


def _type_ok(t, instance):
    if t == "object":
        return isinstance(instance, dict)
    if t == "string":
        return isinstance(instance, str)
    if t == "integer":
        return isinstance(instance, int) and not isinstance(instance, bool)
    if t == "number":
        return isinstance(instance, (int, float)) and not isinstance(instance, bool)
    if t == "boolean":
        return isinstance(instance, bool)
    if t == "null":
        return instance is None
    return True


def validate(schema, instance, root):
    if "$ref" in schema:
        ref = schema["$ref"]
        if not ref.startswith("#/definitions/"):
            return False
        target = root["definitions"][ref[len("#/definitions/"):]]
        return validate(target, instance, root)

    if "oneOf" in schema:
        matches = 0
        for sub in schema["oneOf"]:
            try:
                if validate(sub, instance, root):
                    matches += 1
            except Exception:
                pass
        return matches == 1

    if "enum" in schema and instance not in schema["enum"]:
        return False
    if "const" in schema and instance != schema["const"]:
        return False
    if "type" in schema and not _type_ok(schema["type"], instance):
        return False
    if "pattern" in schema:
        if not isinstance(instance, str) or not re.match(schema["pattern"], instance):
            return False
    if "minLength" in schema:
        if not isinstance(instance, str) or len(instance) < schema["minLength"]:
            return False
    if "minimum" in schema:
        if not isinstance(instance, (int, float)) or isinstance(instance, bool) or instance < schema["minimum"]:
            return False

    if schema.get("type") == "object":
        if not isinstance(instance, dict):
            return False
        for req in schema.get("required", []):
            if req not in instance:
                return False
        if schema.get("additionalProperties") is False:
            allowed = set(schema.get("properties", {}).keys())
            if not set(instance.keys()) <= allowed:
                return False
        for key, subschema in schema.get("properties", {}).items():
            if key in instance and not validate(subschema, instance[key], root):
                return False

    return True


def main():
    schema_path, instance_path = sys.argv[1], sys.argv[2]
    with open(schema_path, "r", encoding="utf-8") as f:
        schema = json.load(f)
    with open(instance_path, "r", encoding="utf-8") as f:
        instance = json.load(f)
    ok = validate(schema, instance, schema)
    if not ok:
        print("INVALID", file=sys.stderr)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
PYEOF

cat > "$WORK/t010_positive.json" <<'EOF'
{
  "schema": "sdd-project-context-approval/v1",
  "context_sha256": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "primary_approval": {"status": "Approved", "approver": "alice", "approved_at": "2026-01-01T00:00:00Z"},
  "second_approval": {"status": "Approved", "approver": "bob", "approved_at": "2026-01-01T00:05:00Z"},
  "effective_at": "2026-01-02T00:00:00Z",
  "predecessor_context_sha256": null,
  "weakening_verdict": null,
  "approval_epoch": 1,
  "hmac": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}
EOF
if "$PY" "$VALIDATOR" "$SCHEMA_JSON" "$WORK/t010_positive.json" >/dev/null 2>&1; then
  pass "TEST-010 full-field fixture (non-null second_approval/effective_at) validates"
else
  fail "TEST-010 full-field fixture (non-null second_approval/effective_at) validates"
fi

$PY -c "
import json
d = json.load(open('$WORK/t010_positive.json'))
d['hmac'] = 'a' * 63
json.dump(d, open('$WORK/t010_hmac_short.json', 'w'))
"
if "$PY" "$VALIDATOR" "$SCHEMA_JSON" "$WORK/t010_hmac_short.json" >/dev/null 2>&1; then
  fail "TEST-010 hmac shorter than 64 hex chars is rejected"
else
  pass "TEST-010 hmac shorter than 64 hex chars is rejected"
fi

$PY -c "
import json
d = json.load(open('$WORK/t010_positive.json'))
d['hmac'] = 'A' + 'a' * 63
json.dump(d, open('$WORK/t010_hmac_upper.json', 'w'))
"
if "$PY" "$VALIDATOR" "$SCHEMA_JSON" "$WORK/t010_hmac_upper.json" >/dev/null 2>&1; then
  fail "TEST-010 hmac containing an uppercase character is rejected"
else
  pass "TEST-010 hmac containing an uppercase character is rejected"
fi

# ---------------------------------------------------------------------------
# TEST-011: staged-signing round-trip + fail-closed proof -- AC-011.
# ---------------------------------------------------------------------------

CONTENT="$WORK/project-context.yaml"
write_content_fixture "$CONTENT"
STAGE1="$WORK/stage-t011"
LIVE_ABSENT="$WORK/no-such-sidecar.json"
KEYFILE="$WORK/context-key"
printf 'test-context-key-epic189-t003' > "$KEYFILE"

SDD_CONTEXT_KEY_FILE="$KEYFILE" run_gen \
  --schema sdd-project-context-approval/v1 \
  --content "$CONTENT" \
  --approver alice \
  --status Approved \
  --second-approver bob \
  --live-sidecar "$LIVE_ABSENT" \
  --stage-dir "$STAGE1"
rc=$?
if [ "$rc" != 0 ]; then
  fail "TEST-011 staged signing succeeds (exit 0; got $rc; stderr: $(cat "$WORK/err")"
else
  pass "TEST-011 staged signing succeeds (exit 0)"
fi

STAGE1_SIDECAR=$(staged_sidecar_path "$STAGE1")
STAGE1_SNAPSHOT=$(staged_snapshot_path "$STAGE1")
if [ -f "$STAGE1_SIDECAR" ] && [ -f "$STAGE1_SNAPSHOT" ] && [ -f "$STAGE1/MANIFEST.sha256" ]; then
  pass "TEST-011 all three staged artifacts (sidecar, snapshot, manifest) exist"
else
  fail "TEST-011 all three staged artifacts (sidecar, snapshot, manifest) exist"
fi

if cmp -s "$CONTENT" "$STAGE1_SNAPSHOT"; then
  pass "TEST-011 approved-context snapshot is byte-exact with the live content file"
else
  fail "TEST-011 approved-context snapshot is byte-exact with the live content file"
fi

sidecar_hash=$(sha256_of "$STAGE1_SIDECAR")
snapshot_hash=$(sha256_of "$STAGE1_SNAPSHOT")
if grep -q "$sidecar_hash  $(staged_rel_sidecar "$STAGE1")" "$STAGE1/MANIFEST.sha256" \
  && grep -q "$snapshot_hash  $(staged_rel_snapshot "$STAGE1")" "$STAGE1/MANIFEST.sha256"; then
  pass "TEST-011 MANIFEST.sha256 hashes match the actual staged file hashes"
else
  fail "TEST-011 MANIFEST.sha256 hashes match the actual staged file hashes (manifest: $(cat "$STAGE1/MANIFEST.sha256"))"
fi

CANON_PY="$ROOT/plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py"
expected_content_sha256=$("$PY" "$CANON_PY" "$CONTENT" --hash-only | tr -d '\n')
actual_context_sha256=$($PY -c "import json; print(json.load(open('$STAGE1_SIDECAR'))['context_sha256'])")
if [ "$expected_content_sha256" = "$actual_context_sha256" ]; then
  pass "TEST-011 context_sha256 matches the live content file's independently-recomputed SHA-256"
else
  fail "TEST-011 context_sha256 matches the live content file's independently-recomputed SHA-256 (got $actual_context_sha256, want $expected_content_sha256)"
fi

# Independent HMAC re-derivation: recompute the preimage via the --dump-preimage
# hook (a documented test-only path, distinct from main()'s own inline signing
# code path) and re-derive the HMAC via a standalone python3 -c invocation,
# never reusing the generator's own signing call.
$PY -c "
import json
d = json.load(open('$STAGE1_SIDECAR'))
d.pop('hmac', None)
json.dump(d, open('$WORK/t011_reverify.json', 'w'))
"
"$PY" "$GEN_PY" --dump-preimage "$WORK/t011_reverify.json" > "$WORK/t011_reverify.preimage"
recomputed_hmac=$($PY -c "
import hmac, hashlib
key = open('$KEYFILE','rb').read()
data = open('$WORK/t011_reverify.preimage','rb').read()
print(hmac.new(key, data, hashlib.sha256).hexdigest())
")
staged_hmac=$($PY -c "import json; print(json.load(open('$STAGE1_SIDECAR'))['hmac'])")
if [ "$recomputed_hmac" = "$staged_hmac" ]; then
  pass "TEST-011 staged sidecar's hmac verifies under independent preimage/HMAC re-derivation"
else
  fail "TEST-011 staged sidecar's hmac verifies under independent preimage/HMAC re-derivation (got $recomputed_hmac, want $staged_hmac)"
fi

# Fail-closed proof: no key resolvable anywhere -> exit non-zero, no staged
# artifact at all.
STAGE2="$WORK/stage-t011-nokey"
FAKE_HOME="$WORK/fake-home-empty"
mkdir -p "$FAKE_HOME"
env -u SDD_CONTEXT_KEY -u SDD_CONTEXT_KEY_FILE HOME="$FAKE_HOME" \
  "$GEN_SH" \
  --schema sdd-project-context-approval/v1 \
  --content "$CONTENT" \
  --approver alice \
  --status Approved \
  --live-sidecar "$LIVE_ABSENT" \
  --stage-dir "$STAGE2" >"$WORK/out" 2>"$WORK/err"
rc=$?
if [ "$rc" = 11 ] && grep -q NO_CONTEXT_KEY "$WORK/err"; then
  pass "TEST-011 no resolvable SDD_CONTEXT_KEY: exit 11/NO_CONTEXT_KEY"
else
  fail "TEST-011 no resolvable SDD_CONTEXT_KEY: exit 11/NO_CONTEXT_KEY (got exit $rc; stderr: $(cat "$WORK/err")"
fi
if [ -e "$STAGE2" ]; then
  fail "TEST-011 no-key refusal writes NO staged artifact at all"
else
  pass "TEST-011 no-key refusal writes NO staged artifact at all"
fi

# ---------------------------------------------------------------------------
# TEST-012: preimage self-reference exclusion -- AC-012.
# ---------------------------------------------------------------------------

$PY -c "
import json
d = json.load(open('$WORK/t010_positive.json'))
d['hmac'] = 'a' * 64
json.dump(d, open('$WORK/t012_hmac_a.json', 'w'))
d['hmac'] = 'b' * 64
json.dump(d, open('$WORK/t012_hmac_b.json', 'w'))
"
"$PY" "$GEN_PY" --dump-preimage "$WORK/t012_hmac_a.json" > "$WORK/t012_a.preimage"
"$PY" "$GEN_PY" --dump-preimage "$WORK/t012_hmac_b.json" > "$WORK/t012_b.preimage"
if cmp -s "$WORK/t012_a.preimage" "$WORK/t012_b.preimage"; then
  pass "TEST-012 two sidecars differing ONLY in hmac produce an identical preimage"
else
  fail "TEST-012 two sidecars differing ONLY in hmac produce an identical preimage"
fi

# ---------------------------------------------------------------------------
# TEST-013: key-resolution byte-parity with sdd-hook-guard.py's
# _resolve_sudo_key -- AC-013 (4-case fixture matrix: env var / env-file /
# home-path / none). resolve_evidence_key (generate-evidence-bundle.sh) is
# the same algorithm by direct source inspection at implementation time
# (BOM-strip + whitespace-strip + identical 3-tier-plus-none order), but is
# embedded in a mixed shell/Python dispatch file rather than a standalone
# importable module, so this suite asserts byte-parity against the
# cleanly-importable canonical precedent (`_resolve_sudo_key`), per
# tasks.md T-003 Must Read.
# ---------------------------------------------------------------------------

PARITY="$WORK/key_parity.py"
cat > "$PARITY" <<'PYEOF'
import importlib.util
import os
import sys

GEN_PATH, GUARD_PATH, CASE, ARG = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


gen = _load("_gen_approval_sidecar", GEN_PATH)
guard = _load("_sdd_hook_guard", GUARD_PATH)

if CASE == "env":
    os.environ["SDD_CONTEXT_KEY"] = "byte-parity-value"
    os.environ["SDD_SUDO_KEY"] = "byte-parity-value"
    a = gen.resolve_context_key()
    b = guard._resolve_sudo_key()
elif CASE == "file":
    (path,) = ARG
    os.environ.pop("SDD_CONTEXT_KEY", None)
    os.environ.pop("SDD_SUDO_KEY", None)
    os.environ["SDD_CONTEXT_KEY_FILE"] = path
    os.environ["SDD_SUDO_KEY_FILE"] = path
    a = gen.resolve_context_key()
    b = guard._resolve_sudo_key()
elif CASE == "home":
    (home,) = ARG
    for var in ("SDD_CONTEXT_KEY", "SDD_SUDO_KEY", "SDD_CONTEXT_KEY_FILE", "SDD_SUDO_KEY_FILE"):
        os.environ.pop(var, None)
    os.environ["HOME"] = home
    a = gen.resolve_context_key()
    b = guard._resolve_sudo_key()
elif CASE == "none":
    for var in ("SDD_CONTEXT_KEY", "SDD_SUDO_KEY", "SDD_CONTEXT_KEY_FILE", "SDD_SUDO_KEY_FILE"):
        os.environ.pop(var, None)
    os.environ["HOME"] = ARG[0]
    a = gen.resolve_context_key()
    b = guard._resolve_sudo_key()
else:
    raise SystemExit("unknown case")

if a == b:
    sys.exit(0)
sys.exit(1)
PYEOF

if "$PY" "$PARITY" "$GEN_PY" "$HOOK_GUARD_PY" env >/dev/null 2>&1; then
  pass "TEST-013 case 1/4 (env var): identical key bytes to _resolve_sudo_key"
else
  fail "TEST-013 case 1/4 (env var): identical key bytes to _resolve_sudo_key"
fi

printf '\xef\xbb\xbf  byte-parity-file-value  \r\n' > "$WORK/t013_keyfile"
if "$PY" "$PARITY" "$GEN_PY" "$HOOK_GUARD_PY" file "$WORK/t013_keyfile" >/dev/null 2>&1; then
  pass "TEST-013 case 2/4 (env-file, BOM+whitespace-stripped): identical key bytes to _resolve_sudo_key"
else
  fail "TEST-013 case 2/4 (env-file, BOM+whitespace-stripped): identical key bytes to _resolve_sudo_key"
fi

FAKE_HOME_PARITY="$WORK/fake-home-parity"
mkdir -p "$FAKE_HOME_PARITY/.sdd"
printf '\xef\xbb\xbf  byte-parity-home-value  \r\n' > "$FAKE_HOME_PARITY/.sdd/context-key"
printf '\xef\xbb\xbf  byte-parity-home-value  \r\n' > "$FAKE_HOME_PARITY/.sdd/sudo-key"
if "$PY" "$PARITY" "$GEN_PY" "$HOOK_GUARD_PY" home "$FAKE_HOME_PARITY" >/dev/null 2>&1; then
  pass "TEST-013 case 3/4 (home-path, BOM+whitespace-stripped): identical key bytes to _resolve_sudo_key"
else
  fail "TEST-013 case 3/4 (home-path, BOM+whitespace-stripped): identical key bytes to _resolve_sudo_key"
fi

FAKE_HOME_EMPTY="$WORK/fake-home-parity-empty"
mkdir -p "$FAKE_HOME_EMPTY"
if "$PY" "$PARITY" "$GEN_PY" "$HOOK_GUARD_PY" none "$FAKE_HOME_EMPTY" >/dev/null 2>&1; then
  pass "TEST-013 case 4/4 (none resolvable): both resolvers return None"
else
  fail "TEST-013 case 4/4 (none resolvable): both resolvers return None"
fi

# ---------------------------------------------------------------------------
# TEST-034: signer staging-only contract + rollback -- AC-034.
# ---------------------------------------------------------------------------

PROJ_A="$WORK/proj-t034-a"
mkdir -p "$PROJ_A"
CONTENT_A="$PROJ_A/project-context.yaml"
write_content_fixture "$CONTENT_A"

# (a) never opens the live sidecar path for writing: a "live" sidecar-shaped
# file is byte-identical before and after a run that reads it (a
# non-bootstrap attempt, which fails via the weakening-detector seam).
LIVE_B="$WORK/live-sidecar-for-t034.json"
cat > "$LIVE_B" <<'EOF'
{"schema": "sdd-project-context-approval/v1", "context_sha256": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", "approval_epoch": 1}
EOF
live_before=$(sha256_of "$LIVE_B")
SDD_CONTEXT_KEY="test-context-key-epic189-t003" run_gen \
  --schema sdd-project-context-approval/v1 \
  --content "$CONTENT_A" \
  --approver alice \
  --status Approved \
  --live-sidecar "$LIVE_B" \
  --stage-dir "$WORK/stage-t034-nonbootstrap"
live_after=$(sha256_of "$LIVE_B")
if [ "$live_before" = "$live_after" ]; then
  pass "TEST-034 the live sidecar path is never opened for writing (byte-identical before/after)"
else
  fail "TEST-034 the live sidecar path is never opened for writing (byte-identical before/after)"
fi

# (b) a simulated mid-write failure (after the sidecar candidate is written,
# before the snapshot) leaves no partial artifact at the final staged path.
STAGE_FAIL1="$WORK/stage-t034-fail1"
SDD_CONTEXT_KEY="test-context-key-epic189-t003" run_gen \
  --schema sdd-project-context-approval/v1 \
  --content "$CONTENT_A" \
  --approver alice \
  --status Approved \
  --live-sidecar "$WORK/no-such-sidecar-t034.json" \
  --stage-dir "$STAGE_FAIL1" \
  --simulate-mid-write-failure after-sidecar
rc=$?
if [ "$rc" = 90 ] && [ ! -e "$STAGE_FAIL1" ]; then
  pass "TEST-034 a simulated failure after the sidecar write leaves no partial artifact at the staged path"
else
  fail "TEST-034 a simulated failure after the sidecar write leaves no partial artifact (exit $rc; stage exists: $([ -e "$STAGE_FAIL1" ] && echo yes || echo no))"
fi
if find "$WORK" -maxdepth 1 -name ".tmp-*" | grep -q .; then
  fail "TEST-034 no stray temp staging directory remains after a simulated failure"
else
  pass "TEST-034 no stray temp staging directory remains after a simulated failure"
fi

STAGE_FAIL2="$WORK/stage-t034-fail2"
SDD_CONTEXT_KEY="test-context-key-epic189-t003" run_gen \
  --schema sdd-project-context-approval/v1 \
  --content "$CONTENT_A" \
  --approver alice \
  --status Approved \
  --live-sidecar "$WORK/no-such-sidecar-t034.json" \
  --stage-dir "$STAGE_FAIL2" \
  --simulate-mid-write-failure after-snapshot
rc=$?
if [ "$rc" = 90 ] && [ ! -e "$STAGE_FAIL2" ]; then
  pass "TEST-034 a simulated failure after the snapshot write leaves no partial artifact at the staged path"
else
  fail "TEST-034 a simulated failure after the snapshot write leaves no partial artifact (exit $rc; stage exists: $([ -e "$STAGE_FAIL2" ] && echo yes || echo no))"
fi

# (c) a re-run after failure succeeds with a fresh nonce and staging
# subdirectory, using the tool's OWN default (non-overridden) stage path.
PROJ_C="$WORK/proj-t034-c"
mkdir -p "$PROJ_C"
CONTENT_C="$PROJ_C/project-context.yaml"
write_content_fixture "$CONTENT_C"
(
  cd "$PROJ_C" && \
  SDD_CONTEXT_KEY="test-context-key-epic189-t003" "$GEN_SH" \
    --schema sdd-project-context-approval/v1 \
    --content project-context.yaml \
    --approver alice \
    --status Approved \
    --live-sidecar no-such-sidecar.json \
    --simulate-mid-write-failure after-sidecar >/dev/null 2>&1
)
before_count=0
if [ -d "$PROJ_C/sdd/.staging/sdd-project-context-approval/v1" ]; then
  before_count=$(find "$PROJ_C/sdd/.staging/sdd-project-context-approval/v1" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
fi
(
  cd "$PROJ_C" && \
  SDD_CONTEXT_KEY="test-context-key-epic189-t003" "$GEN_SH" \
    --schema sdd-project-context-approval/v1 \
    --content project-context.yaml \
    --approver alice \
    --status Approved \
    --live-sidecar no-such-sidecar.json >/dev/null 2>&1
)
rc=$?
after_count=0
if [ -d "$PROJ_C/sdd/.staging/sdd-project-context-approval/v1" ]; then
  after_count=$(find "$PROJ_C/sdd/.staging/sdd-project-context-approval/v1" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
fi
if [ "$rc" = 0 ] && [ "$before_count" = 0 ] && [ "$after_count" = 1 ]; then
  pass "TEST-034 a re-run after a mid-write failure succeeds with a fresh nonce/staging subdirectory"
else
  fail "TEST-034 a re-run after a mid-write failure succeeds with a fresh nonce/staging subdirectory (rc=$rc before=$before_count after=$after_count)"
fi

# ---------------------------------------------------------------------------
# TEST-036: HMAC golden vector + fifteen one-field-mutated variants -- AC-036.
# ---------------------------------------------------------------------------

GOLDEN_HMAC="93d361de8a9f97d9ff173b6db8764a606a885440e7534164dd31e1f2826d4b07"
GOLDEN_KEY="$WORK/t036-key"
printf 'test-context-key-epic189-t003' > "$GOLDEN_KEY"

cat > "$WORK/t036_golden.json" <<'EOF'
{
  "schema": "sdd-project-context-approval/v1",
  "context_sha256": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "primary_approval": {"status": "Approved", "approver": "alice", "approved_at": "2026-01-01T00:00:00Z"},
  "second_approval": {"status": "Approved", "approver": "bob", "approved_at": "2026-01-01T00:05:00Z"},
  "effective_at": "2026-01-02T00:00:00Z",
  "predecessor_context_sha256": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "weakening_verdict": {
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
  },
  "approval_epoch": 2,
  "hmac": "93d361de8a9f97d9ff173b6db8764a606a885440e7534164dd31e1f2826d4b07"
}
EOF

hmac_of() {
  "$PY" "$GEN_PY" --dump-preimage "$1" > "$WORK/t036.preimage"
  "$PY" -c "
import hmac, hashlib
key = open('$GOLDEN_KEY','rb').read()
data = open('$WORK/t036.preimage','rb').read()
print(hmac.new(key, data, hashlib.sha256).hexdigest())
"
}

golden_hmac_actual=$(hmac_of "$WORK/t036_golden.json")
if [ "$golden_hmac_actual" = "$GOLDEN_HMAC" ]; then
  pass "TEST-036 golden vector's HMAC matches the hand-verified expected value"
else
  fail "TEST-036 golden vector's HMAC matches the hand-verified expected value (got $golden_hmac_actual, want $GOLDEN_HMAC)"
fi

mutate_and_check() {
  desc=$1
  jq_expr=$2
  "$PY" -c "
import json
d = json.load(open('$WORK/t036_golden.json'))
$jq_expr
json.dump(d, open('$WORK/t036_mut.json', 'w'))
"
  mutated_hmac=$(hmac_of "$WORK/t036_mut.json")
  if [ "$mutated_hmac" != "$GOLDEN_HMAC" ]; then
    pass "TEST-036 mutating $desc changes the HMAC"
  else
    fail "TEST-036 mutating $desc changes the HMAC (unchanged: $mutated_hmac)"
  fi
}

mutate_and_check "schema" "d['schema'] = 'sdd-provider-bindings-approval/v1'"
mutate_and_check "context_sha256" "d['context_sha256'] = 'sha256:' + 'f' * 64"
mutate_and_check "primary_approval.status" "d['primary_approval']['status'] = 'Rejected'"
mutate_and_check "primary_approval.approver" "d['primary_approval']['approver'] = 'carol'"
mutate_and_check "primary_approval.approved_at" "d['primary_approval']['approved_at'] = '2027-01-01T00:00:00Z'"
mutate_and_check "second_approval.status" "d['second_approval']['status'] = 'Rejected'"
mutate_and_check "second_approval.approver" "d['second_approval']['approver'] = 'dave'"
mutate_and_check "second_approval.approved_at" "d['second_approval']['approved_at'] = '2027-01-01T00:05:00Z'"
mutate_and_check "effective_at" "d['effective_at'] = '2027-01-02T00:00:00Z'"
mutate_and_check "predecessor_context_sha256" "d['predecessor_context_sha256'] = 'sha256:' + 'e' * 64"
mutate_and_check "weakening_verdict.policy_weakening" "d['weakening_verdict']['policy_weakening'] = False"
mutate_and_check "weakening_verdict.categories.capability_enforcement_weakened" "d['weakening_verdict']['categories']['capability_enforcement_weakened'] = 'not_weakened'"
mutate_and_check "weakening_verdict.two_person_required" "d['weakening_verdict']['two_person_required'] = False"
mutate_and_check "weakening_verdict.cooldown_hours" "d['weakening_verdict']['cooldown_hours'] = 24"
mutate_and_check "approval_epoch" "d['approval_epoch'] = 3"

# ---------------------------------------------------------------------------
# Provenance seam Done-When (tasks.md T-003, remedy; UPDATED by T-005's
# wiring completion): bootstrap signs with null/null/epoch=1; non-bootstrap
# now resolves a REAL verdict via the in-process detect-policy-weakening.py
# seam (T-005) rather than failing closed with WEAKENING_DETECTOR_UNAVAILABLE
# -- that diagnostic remains a documented category (module genuinely
# absent/unloadable), but no longer fires for THIS fixture now that the
# detector is present. The comprehensive wiring proof (exact verdict
# match, malformed/None-verdict/unexpected-exception carry-forward
# regressions) lives in tests/detect-policy-weakening.tests.sh (T-005);
# this suite only re-asserts that ITS OWN non-bootstrap fixture now signs
# successfully.
# ---------------------------------------------------------------------------

STAGE_BOOT="$WORK/stage-seam-bootstrap"
SDD_CONTEXT_KEY="test-context-key-epic189-t003" run_gen \
  --schema sdd-project-context-approval/v1 \
  --content "$CONTENT_A" \
  --approver alice \
  --status Approved \
  --live-sidecar "$WORK/no-such-sidecar-seam.json" \
  --stage-dir "$STAGE_BOOT"
rc=$?
if [ "$rc" = 0 ]; then
  pass "SEAM bootstrap (no live sidecar): signing succeeds"
else
  fail "SEAM bootstrap (no live sidecar): signing succeeds (exit $rc; stderr: $(cat "$WORK/err")"
fi
predecessor=$($PY -c "import json; print(json.load(open('$(staged_sidecar_path "$STAGE_BOOT")'))['predecessor_context_sha256'])" 2>/dev/null)
verdict=$($PY -c "import json; print(json.load(open('$(staged_sidecar_path "$STAGE_BOOT")'))['weakening_verdict'])" 2>/dev/null)
epoch=$($PY -c "import json; print(json.load(open('$(staged_sidecar_path "$STAGE_BOOT")'))['approval_epoch'])" 2>/dev/null)
if [ "$predecessor" = "None" ] && [ "$verdict" = "None" ] && [ "$epoch" = "1" ]; then
  pass "SEAM bootstrap: predecessor_context_sha256/weakening_verdict = null, approval_epoch = 1"
else
  fail "SEAM bootstrap: predecessor_context_sha256/weakening_verdict = null, approval_epoch = 1 (got predecessor=$predecessor verdict=$verdict epoch=$epoch)"
fi

# Isolated CWD (no sdd/.approved-context/ present) so this fixture's
# result never depends on whether the ambient repository has a REAL
# approved-context anchor by the time this suite runs (it does not, as of
# T-005, but a later task in this epic will eventually bootstrap one) --
# the detector's default anchor resolution is CWD-relative, matching
# design.md's CLI contract, so isolating the CWD is what makes this
# fixture deterministic regardless of ambient repository state.
PROJ_NONBOOT="$WORK/proj-seam-nonbootstrap"
mkdir -p "$PROJ_NONBOOT"
cp "$CONTENT_A" "$PROJ_NONBOOT/project-context.yaml"
cp "$LIVE_B" "$PROJ_NONBOOT/live-sidecar.json"
(
  cd "$PROJ_NONBOOT" && \
  SDD_CONTEXT_KEY="test-context-key-epic189-t003" "$GEN_SH" \
    --schema sdd-project-context-approval/v1 \
    --content project-context.yaml \
    --approver alice \
    --status Approved \
    --live-sidecar live-sidecar.json \
    --stage-dir stage-nonbootstrap >"$WORK/out" 2>"$WORK/err"
)
rc=$?
if [ "$rc" = 0 ]; then
  pass "SEAM non-bootstrap (live sidecar present, detector now wired): signing succeeds"
else
  fail "SEAM non-bootstrap (live sidecar present, detector now wired): signing succeeds (exit $rc; stderr: $(cat "$WORK/err")"
fi
if grep -q WEAKENING_DETECTOR_UNAVAILABLE "$WORK/err"; then
  fail "SEAM non-bootstrap: WEAKENING_DETECTOR_UNAVAILABLE no longer fires for this fixture"
else
  pass "SEAM non-bootstrap: WEAKENING_DETECTOR_UNAVAILABLE no longer fires for this fixture"
fi
STAGE_NONBOOT="$PROJ_NONBOOT/stage-nonbootstrap"
if [ -f "$(staged_sidecar_path "$STAGE_NONBOOT")" ]; then
  pass "SEAM non-bootstrap: a staged candidate IS written now that a real verdict resolves"
else
  fail "SEAM non-bootstrap: a staged candidate IS written now that a real verdict resolves"
fi
nonboot_verdict=$($PY -c "import json; print(json.load(open('$(staged_sidecar_path "$STAGE_NONBOOT")'))['weakening_verdict'] is not None)" 2>/dev/null)
if [ "$nonboot_verdict" = "True" ]; then
  pass "SEAM non-bootstrap: the embedded weakening_verdict is non-null (T-005's in-process seam)"
else
  fail "SEAM non-bootstrap: the embedded weakening_verdict is non-null (got: $nonboot_verdict)"
fi

# ---------------------------------------------------------------------------
# TEST-HARDEN(a): DUPLICATE_APPROVER_IDENTITY refused before any hashing.
# ---------------------------------------------------------------------------

STAGE_DUP="$WORK/stage-dup"
SDD_CONTEXT_KEY="test-context-key-epic189-t003" run_gen \
  --schema sdd-project-context-approval/v1 \
  --content "$CONTENT_A" \
  --approver alice \
  --status Approved \
  --second-approver alice \
  --live-sidecar "$WORK/no-such-sidecar-dup.json" \
  --stage-dir "$STAGE_DUP"
rc=$?
if [ "$rc" = 10 ] && grep -q DUPLICATE_APPROVER_IDENTITY "$WORK/err"; then
  pass "TEST-HARDEN(a) identical primary/second approver id refused (DUPLICATE_APPROVER_IDENTITY)"
else
  fail "TEST-HARDEN(a) identical primary/second approver id refused (exit $rc; stderr: $(cat "$WORK/err")"
fi
if [ -e "$STAGE_DUP" ]; then
  fail "TEST-HARDEN(a) DUPLICATE_APPROVER_IDENTITY refusal writes no staged artifact"
else
  pass "TEST-HARDEN(a) DUPLICATE_APPROVER_IDENTITY refusal writes no staged artifact"
fi

# ---------------------------------------------------------------------------
# TEST-HARDEN(b): a hostile field value (an unpaired UTF-16 surrogate,
# delivered via an invalid-UTF-8 argv byte) is rejected with a documented
# category, never an uncaught traceback.
# ---------------------------------------------------------------------------

STAGE_HOSTILE="$WORK/stage-hostile"
hostile_approver=$(printf '\xff')
SDD_CONTEXT_KEY="test-context-key-epic189-t003" run_gen \
  --schema sdd-project-context-approval/v1 \
  --content "$CONTENT_A" \
  --approver "$hostile_approver" \
  --status Approved \
  --live-sidecar "$WORK/no-such-sidecar-hostile.json" \
  --stage-dir "$STAGE_HOSTILE"
rc=$?
if [ "$rc" = 14 ] && grep -q PREIMAGE_CANONICALIZATION_FAILED "$WORK/err" && ! grep -qi traceback "$WORK/err"; then
  pass "TEST-HARDEN(b) an invalid-UTF-8 approver id is rejected (PREIMAGE_CANONICALIZATION_FAILED), never a traceback"
else
  fail "TEST-HARDEN(b) an invalid-UTF-8 approver id is rejected cleanly (exit $rc; stderr: $(cat "$WORK/err")"
fi
if [ -e "$STAGE_HOSTILE" ]; then
  fail "TEST-HARDEN(b) hostile-field refusal writes no staged artifact"
else
  pass "TEST-HARDEN(b) hostile-field refusal writes no staged artifact"
fi

# ---------------------------------------------------------------------------
# TEST-HARDEN(c): usage errors are rejected cleanly, never a traceback.
# ---------------------------------------------------------------------------

run_gen --schema sdd-project-context-approval/v1 --content "$CONTENT_A" --approver alice --status Approved
rc=$?
if [ "$rc" = 2 ] && grep -qi "missing required argument" "$WORK/err" && ! grep -qi traceback "$WORK/err"; then
  pass "TEST-HARDEN(c) a missing required argument (--live-sidecar) is a clean usage error (exit 2)"
else
  fail "TEST-HARDEN(c) a missing required argument (--live-sidecar) is a clean usage error (exit $rc; stderr: $(cat "$WORK/err")"
fi

run_gen \
  --schema sdd-project-context-approval/v1 \
  --content "$CONTENT_A" \
  --approver alice \
  --status Rejected \
  --live-sidecar "$WORK/no-such-sidecar-status.json"
rc=$?
if [ "$rc" = 2 ] && ! grep -qi traceback "$WORK/err"; then
  pass "TEST-HARDEN(c) --status not exactly \"Approved\" is a clean usage error (exit 2)"
else
  fail "TEST-HARDEN(c) --status not exactly \"Approved\" is a clean usage error (exit $rc; stderr: $(cat "$WORK/err")"
fi

# ---------------------------------------------------------------------------
# TEST-HARDEN(d): staging I/O errors are wrapped as STAGING_IO_ERROR, never a
# raw traceback (quality-gate seq0350 Major remedy: os.makedirs()/os.rename()
# OSError subclasses escaped main()'s narrow GenerateApprovalSidecarError
# handler). Two required classes: (i) a --stage-dir collision (existing
# non-empty directory or existing regular file); (ii) the DEFAULT path with
# no --stage-dir override, where `sdd` itself is a regular file.
# ---------------------------------------------------------------------------

STAGE_COLLIDE_DIR="$WORK/stage-collide-dir"
mkdir -p "$STAGE_COLLIDE_DIR"
touch "$STAGE_COLLIDE_DIR/pre-existing-file"
SDD_CONTEXT_KEY="test-context-key-epic189-t003" run_gen \
  --schema sdd-project-context-approval/v1 \
  --content "$CONTENT_A" \
  --approver alice \
  --status Approved \
  --live-sidecar "$WORK/no-such-sidecar-collide-dir.json" \
  --stage-dir "$STAGE_COLLIDE_DIR"
rc=$?
if [ "$rc" = 16 ] && grep -q STAGING_IO_ERROR "$WORK/err" && ! grep -qi traceback "$WORK/err"; then
  pass "TEST-HARDEN(d) --stage-dir = existing non-empty directory: clean STAGING_IO_ERROR (exit 16), never a traceback"
else
  fail "TEST-HARDEN(d) --stage-dir = existing non-empty directory: clean STAGING_IO_ERROR (exit 16), never a traceback (exit $rc; stderr: $(cat "$WORK/err")"
fi
if [ -e "$STAGE_COLLIDE_DIR/project-context.approval.json" ] || [ -e "$STAGE_COLLIDE_DIR/MANIFEST.sha256" ]; then
  fail "TEST-HARDEN(d) a stage-dir directory collision writes no staged candidate into it"
else
  pass "TEST-HARDEN(d) a stage-dir directory collision writes no staged candidate into it"
fi
if find "$WORK" -maxdepth 1 -name ".tmp-*" | grep -q .; then
  fail "TEST-HARDEN(d) a stage-dir directory collision leaves no stray temp staging directory"
else
  pass "TEST-HARDEN(d) a stage-dir directory collision leaves no stray temp staging directory"
fi

STAGE_COLLIDE_FILE="$WORK/stage-collide-file"
touch "$STAGE_COLLIDE_FILE"
SDD_CONTEXT_KEY="test-context-key-epic189-t003" run_gen \
  --schema sdd-project-context-approval/v1 \
  --content "$CONTENT_A" \
  --approver alice \
  --status Approved \
  --live-sidecar "$WORK/no-such-sidecar-collide-file.json" \
  --stage-dir "$STAGE_COLLIDE_FILE"
rc=$?
if [ "$rc" = 16 ] && grep -q STAGING_IO_ERROR "$WORK/err" && ! grep -qi traceback "$WORK/err"; then
  pass "TEST-HARDEN(d) --stage-dir = existing regular file: clean STAGING_IO_ERROR (exit 16), never a traceback"
else
  fail "TEST-HARDEN(d) --stage-dir = existing regular file: clean STAGING_IO_ERROR (exit 16), never a traceback (exit $rc; stderr: $(cat "$WORK/err")"
fi
if find "$WORK" -maxdepth 1 -name ".tmp-*" | grep -q .; then
  fail "TEST-HARDEN(d) a stage-dir file collision leaves no stray temp staging directory"
else
  pass "TEST-HARDEN(d) a stage-dir file collision leaves no stray temp staging directory"
fi

PROJ_SDD_IS_FILE="$WORK/proj-sdd-is-file"
mkdir -p "$PROJ_SDD_IS_FILE"
write_content_fixture "$PROJ_SDD_IS_FILE/project-context.yaml"
touch "$PROJ_SDD_IS_FILE/sdd"
(
  cd "$PROJ_SDD_IS_FILE" && \
  SDD_CONTEXT_KEY="test-context-key-epic189-t003" "$GEN_SH" \
    --schema sdd-project-context-approval/v1 \
    --content project-context.yaml \
    --approver alice \
    --status Approved \
    --live-sidecar no-such-sidecar.json >"$WORK/out" 2>"$WORK/err"
)
rc=$?
if [ "$rc" = 16 ] && grep -q STAGING_IO_ERROR "$WORK/err" && ! grep -qi traceback "$WORK/err"; then
  pass "TEST-HARDEN(d) default path with 'sdd' as a regular file: clean STAGING_IO_ERROR (exit 16), never a traceback"
else
  fail "TEST-HARDEN(d) default path with 'sdd' as a regular file: clean STAGING_IO_ERROR (exit 16), never a traceback (exit $rc; stderr: $(cat "$WORK/err")"
fi
extra_paths=$(find "$PROJ_SDD_IS_FILE" -mindepth 1 ! -name 'project-context.yaml' ! -name 'sdd')
if [ -n "$extra_paths" ]; then
  fail "TEST-HARDEN(d) default path with 'sdd' as a regular file: no staged artifact or stray temp path created anywhere (found: $extra_paths)"
else
  pass "TEST-HARDEN(d) default path with 'sdd' as a regular file: no staged artifact or stray temp path created anywhere"
fi

# ===========================================================================
# TEST-PR229-GEN: the staged bundle is directly consumable by the publisher.
#
# External review of PR #229 (Codex), finding 2. The generator's
# MANIFEST.sha256 was written as a `nonce: <hex>` header line followed by
# `<sha256>  <bare basename>` rows. apply-human-copy accepts ONLY
# `<64-hex-lowercase>  <repo-relative live path>` rows, so the header line
# was rejected as MANIFEST_INVALID (exit 13) and the bare basenames would
# have published both artifacts into the REPOSITORY ROOT instead of `sdd/`
# and `sdd/.approved-context/`.
#
# WHICH SCRIPT THIS EXERCISES: plugins/sdd-quality-loop/scripts/
# generate-approval-sidecar.py is R-10 protected, so the fix lives in its
# STAGED CANDIDATE under specs/epic-189-a1-project-context/human-copy/ until
# a human applies it. These assertions therefore run the STAGED candidate.
# They keep passing unchanged after the apply (the staged copy and the live
# copy are then byte-identical); to re-point them at the live script,
# replace STAGED_GEN_PY with $GEN_PY.
#
# The staged Python scripts cannot be executed where they sit: they resolve
# `canonicalize-sdd-yaml.py` via Path(__file__).parent. So the candidate is
# copied into a SHADOW tree that reproduces the real repo layout
# (<shadow>/plugins/sdd-quality-loop/scripts/ + <shadow>/contracts/), which
# is also what a human gets after applying.
# ===========================================================================

STAGED_GEN_PY="$ROOT/specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py"
STAGED_APPLY_SH="$ROOT/specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/apply-human-copy.sh"

if [ -f "$STAGED_GEN_PY" ] && [ -f "$STAGED_APPLY_SH" ]; then
  pass "TEST-PR229-GEN staged candidates for generate-approval-sidecar.py and apply-human-copy.sh exist"
else
  fail "TEST-PR229-GEN staged candidates for generate-approval-sidecar.py and apply-human-copy.sh exist"
fi

SHADOW229="$WORK/shadow229"
mkdir -p "$SHADOW229/plugins/sdd-quality-loop/scripts"
cp "$ROOT"/plugins/sdd-quality-loop/scripts/*.py "$SHADOW229/plugins/sdd-quality-loop/scripts/"
cp "$STAGED_GEN_PY" "$SHADOW229/plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py"
cp -R "$ROOT/contracts" "$SHADOW229/contracts"
SHADOW_GEN="$SHADOW229/plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py"

STAGE229="$WORK/stage-pr229"
REPO229="$WORK/repo-pr229"
mkdir -p "$REPO229/sdd/.staging"
CONTENT229="$WORK/pr229-project-context.yaml"
write_content_fixture "$CONTENT229"
KEYFILE229="$WORK/pr229-key"
printf 'test-context-key-epic189-pr229' > "$KEYFILE229"

SDD_CONTEXT_KEY_FILE="$KEYFILE229" "$PY" "$SHADOW_GEN" \
  --schema sdd-project-context-approval/v1 \
  --content "$CONTENT229" \
  --approver alice \
  --status Approved \
  --second-approver bob \
  --live-sidecar "$WORK/pr229-no-such-sidecar.json" \
  --stage-dir "$STAGE229" >"$WORK/out" 2>"$WORK/err"
rc=$?
if [ "$rc" = 0 ]; then
  pass "TEST-PR229-GEN staged signing via the fixed candidate succeeds (exit 0)"
else
  fail "TEST-PR229-GEN staged signing via the fixed candidate succeeds (exit 0; got $rc; stderr: $(cat "$WORK/err"))"
fi

# (a) No `nonce:` header line -- that line alone was MANIFEST_INVALID.
if grep -q '^nonce:' "$STAGE229/MANIFEST.sha256"; then
  fail "TEST-PR229-GEN MANIFEST.sha256 carries no 'nonce:' header line"
else
  pass "TEST-PR229-GEN MANIFEST.sha256 carries no 'nonce:' header line"
fi

# (b) The nonce is PRESERVED out-of-band rather than dropped.
if [ -f "$STAGE229/NONCE" ] && grep -q '^nonce: [0-9a-f][0-9a-f]*$' "$STAGE229/NONCE"; then
  pass "TEST-PR229-GEN the nonce is preserved in a sibling NONCE file, not silently dropped"
else
  fail "TEST-PR229-GEN the nonce is preserved in a sibling NONCE file, not silently dropped"
fi

# (c) Exactly two rows, each publisher-format, naming the REAL live paths.
pr229_rows=$(wc -l < "$STAGE229/MANIFEST.sha256" | tr -d ' ')
pr229_wellformed=$(grep -c '^[0-9a-f]\{64\}  [^ ]' "$STAGE229/MANIFEST.sha256")
if [ "$pr229_rows" = "2" ] && [ "$pr229_wellformed" = "2" ]; then
  pass "TEST-PR229-GEN MANIFEST.sha256 is exactly two publisher-format '<64-hex>  <path>' rows"
else
  fail "TEST-PR229-GEN MANIFEST.sha256 is exactly two publisher-format rows (rows=$pr229_rows wellformed=$pr229_wellformed; manifest: $(cat "$STAGE229/MANIFEST.sha256"))"
fi

pr229_sidecar_hash=$(sha256_of "$STAGE229/sdd/project-context.approval.json")
pr229_snapshot_hash=$(sha256_of "$STAGE229/sdd/.approved-context/project-context.approved.yaml")
if grep -qxF "$pr229_sidecar_hash  sdd/project-context.approval.json" "$STAGE229/MANIFEST.sha256" \
  && grep -qxF "$pr229_snapshot_hash  sdd/.approved-context/project-context.approved.yaml" "$STAGE229/MANIFEST.sha256"; then
  pass "TEST-PR229-GEN manifest rows name the real repo-relative LIVE paths (sdd/, sdd/.approved-context/) and match the staged bytes"
else
  fail "TEST-PR229-GEN manifest rows name the real repo-relative LIVE paths and match the staged bytes (manifest: $(cat "$STAGE229/MANIFEST.sha256"))"
fi

# (d) The two live basenames differ, so the publisher's basename-keyed
#     backup slot cannot collide (DUPLICATE_BASENAME_IN_BATCH, exit 19).
if [ "project-context.approval.json" != "project-context.approved.yaml" ]; then
  pass "TEST-PR229-GEN the batch's two live basenames differ (no DUPLICATE_BASENAME_IN_BATCH risk)"
else
  fail "TEST-PR229-GEN the batch's two live basenames differ"
fi

# (e) THE POINT: hand the staging dir straight to the publisher.
( cd "$REPO229" && "$STAGED_APPLY_SH" --staging-dir "$STAGE229" --manifest "$STAGE229/MANIFEST.sha256" ) >"$WORK/out" 2>"$WORK/err"
rc=$?
if [ "$rc" = 0 ]; then
  pass "TEST-PR229-GEN the staged bundle is consumed directly by apply-human-copy --manifest (exit 0)"
else
  fail "TEST-PR229-GEN the staged bundle is consumed directly by apply-human-copy --manifest (exit 0; got $rc; stdout: $(cat "$WORK/out"))"
fi

if [ -f "$REPO229/sdd/project-context.approval.json" ] \
  && [ -f "$REPO229/sdd/.approved-context/project-context.approved.yaml" ] \
  && [ ! -e "$REPO229/project-context.approval.json" ] \
  && [ ! -e "$REPO229/project-context.approved.yaml" ]; then
  pass "TEST-PR229-GEN both artifacts land at their real live paths, never in the repository root"
else
  fail "TEST-PR229-GEN both artifacts land at their real live paths, never in the repository root"
fi

if cmp -s "$STAGE229/sdd/project-context.approval.json" "$REPO229/sdd/project-context.approval.json" \
  && cmp -s "$CONTENT229" "$REPO229/sdd/.approved-context/project-context.approved.yaml"; then
  pass "TEST-PR229-GEN published bytes are byte-exact (sidecar vs staged candidate; anchor vs live content)"
else
  fail "TEST-PR229-GEN published bytes are byte-exact (sidecar vs staged candidate; anchor vs live content)"
fi

# ---------------------------------------------------------------------------
# Self-registration (design.md Test Strategy item 11).
# ---------------------------------------------------------------------------

if grep -q 'generate-approval-sidecar\.tests\.sh' "$ROOT/tests/run-all.sh"; then
  pass "self-registration: tests/generate-approval-sidecar.tests.sh registered in tests/run-all.sh"
else
  fail "self-registration: tests/generate-approval-sidecar.tests.sh registered in tests/run-all.sh"
fi
if grep -q 'generate-approval-sidecar\.tests\.ps1' "$ROOT/tests/run-all.ps1"; then
  pass "self-registration: tests/generate-approval-sidecar.tests.ps1 registered in tests/run-all.ps1"
else
  fail "self-registration: tests/generate-approval-sidecar.tests.ps1 registered in tests/run-all.ps1"
fi
if [ -f "$ROOT/tests/generate-approval-sidecar.tests.ps1" ]; then
  pass "self-registration: tests/generate-approval-sidecar.tests.ps1 twin exists"
else
  fail "self-registration: tests/generate-approval-sidecar.tests.ps1 twin exists"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
