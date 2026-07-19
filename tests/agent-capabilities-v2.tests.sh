#!/usr/bin/env bash
# Suite: agent-capabilities-v2 (T-001, #149) — REQ-001 / AC-001..AC-005.
#
# Locks the shape of contracts/agent-model-capabilities.v2.json (schema
# `agent-model-capabilities/v2`) and the two-directional v1<->v2 parity
# invariant against the FROZEN v1 file
# (contracts/agent-model-capabilities.json), which this suite never opens
# for write. TEST-004's negative self-check mutates a scratch COPY of the
# real v2 file (never the tracked file itself) to prove the parity
# assertion is live, not vacuously true.
#
# CI-resilience (specs/epic-159-pillar-c/requirements.md Edge Cases;
# design.md Constraint Compliance): no possibly-empty bash array is
# expanded under `set -u`; the mktemp scratch root is normalized with
# `pwd -P` immediately after creation; this suite performs no `jq`
# consumption at all (JSON parsing goes through python3, already a
# repository dependency per select-agent-model.sh's own heredoc usage),
# so the Windows `jq.exe` CRLF hazard does not apply; no real validator
# gate is driven directly.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

V1="$ROOT/contracts/agent-model-capabilities.json"
V2="$ROOT/contracts/agent-model-capabilities.v2.json"
PLUGIN_CONTRACTS="$ROOT/PLUGIN-CONTRACTS.md"
RUN_ALL_SH="$ROOT/tests/run-all.sh"
RUN_ALL_PS1="$ROOT/tests/run-all.ps1"

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf 'ok: %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'not ok: %s\n' "$1" >&2; }

# Portable SHA-256 (mirrors tests/lib/loop-driver.sh's `_loop_sha256`):
# sha256sum first (Linux/Windows git-bash), shasum -a 256 fallback (macOS).
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

# --- Required artifacts present at all ------------------------------------
if [[ ! -f "$V1" ]]; then
  printf 'not ok: v1 registry missing at %s\n' "$V1" >&2
  exit 1
fi
V1_SHA_BEFORE="$(sha256_of "$V1")"

if [[ ! -f "$V2" ]]; then
  bad "TEST-001: contracts/agent-model-capabilities.v2.json does not exist"
  printf -- '---- summary: pass=%d fail=%d ----\n' "$pass" "$fail"
  printf 'not ok: agent-capabilities-v2 suite FAILED (%d failures)\n' "$fail" >&2
  exit 1
fi

# --- python3 validators (no jq; see header) --------------------------------
# Each validator prints one violation per line to stderr and exits non-zero
# on any violation, exits 0 when the target file satisfies the invariant.

validate_schema_shape() {
  # $1 = path to a v2-shaped registry file. AC-001.
  python3 - "$1" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)

errors = []
if data.get("schema") != "agent-model-capabilities/v2":
    errors.append(f"schema must be 'agent-model-capabilities/v2', got {data.get('schema')!r}")

models = data.get("models")
if not isinstance(models, list) or not models:
    errors.append("models must be a non-empty array")
    models = []

valid_control = {"flag", "frontmatter", "none"}
for entry in models:
    name = entry.get("name", "<unnamed>") if isinstance(entry, dict) else "<non-object model entry>"
    if not isinstance(entry, dict):
        errors.append(f"{name}: model entry must be an object")
        continue
    supported = entry.get("supported_efforts")
    if not isinstance(supported, list) or len(supported) == 0:
        errors.append(f"{name}: supported_efforts must be a non-empty array")
        supported = []
    default_effort = entry.get("default_effort")
    if default_effort not in supported:
        errors.append(f"{name}: default_effort {default_effort!r} must be a member of supported_efforts {supported!r}")
    control = entry.get("effort_control")
    if not isinstance(control, dict):
        errors.append(f"{name}: effort_control must be an object")
        control = {}
    for host in ("claude-code", "codex-cli"):
        value = control.get(host)
        if value not in valid_control:
            errors.append(f"{name}: effort_control.{host} = {value!r} must be one of {sorted(valid_control)}")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
sys.exit(0)
PY
}

validate_risk_matrix() {
  # $1 = path to a v2-shaped registry file. AC-002.
  python3 - "$1" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)

errors = []
matrix = data.get("risk_effort_matrix")
if not isinstance(matrix, dict):
    print("risk_effort_matrix must be an object", file=sys.stderr)
    sys.exit(1)

expected = {"low": "low", "medium": "medium", "high": "high", "critical": "high"}
for risk, effort in expected.items():
    if matrix.get(risk) != effort:
        errors.append(f"risk_effort_matrix.{risk} must be {effort!r}, got {matrix.get(risk)!r}")

if matrix.get("escalation_bump") is not True:
    errors.append(f"risk_effort_matrix.escalation_bump must be true, got {matrix.get('escalation_bump')!r}")

for risk in ("low", "medium", "high", "critical"):
    if matrix.get(risk) == "xhigh":
        errors.append(f"risk_effort_matrix.{risk} must never map directly to xhigh")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
sys.exit(0)
PY
}

validate_role_defaults() {
  # $1 = path to a v2-shaped registry file. AC-003.
  python3 - "$1" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)

errors = []
role_defaults = data.get("role_defaults")
if not isinstance(role_defaults, dict):
    print("role_defaults must be an object", file=sys.stderr)
    sys.exit(1)

required_roles = [
    "spec-reviewer",
    "impl-reviewer",
    "task-reviewer",
    "sdd-evaluator",
    "sdd-investigator",
]
for role in required_roles:
    entry = role_defaults.get(role)
    if not isinstance(entry, dict):
        errors.append(f"role_defaults.{role} must be an object")
        continue
    if not entry.get("minimum_tier"):
        errors.append(f"role_defaults.{role}.minimum_tier must be present")
    if not entry.get("default_effort"):
        errors.append(f"role_defaults.{role}.default_effort must be present")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
sys.exit(0)
PY
}

validate_parity() {
  # $1 = v1 path, $2 = v2 path. Two-directional parity: every v1 model name
  # exists in v2 with the identical canonical_tier, and every v1 model's
  # `efforts` array is a subset of that model's v2 `supported_efforts`. AC-004.
  python3 - "$1" "$2" <<'PY'
import json
import sys

v1_path, v2_path = sys.argv[1], sys.argv[2]
with open(v1_path, encoding="utf-8") as fh:
    v1 = json.load(fh)
with open(v2_path, encoding="utf-8") as fh:
    v2 = json.load(fh)

errors = []
v2_by_name = {
    m.get("name"): m for m in v2.get("models", []) if isinstance(m, dict)
}

for model in v1.get("models", []):
    name = model.get("name")
    tier = model.get("canonical_tier")
    v1_efforts = model.get("efforts", [])
    v2_model = v2_by_name.get(name)
    if v2_model is None:
        errors.append(f"v1 model {name!r} is missing from v2")
        continue
    if v2_model.get("canonical_tier") != tier:
        errors.append(
            f"{name}: canonical_tier mismatch v1={tier!r} v2={v2_model.get('canonical_tier')!r}"
        )
    v2_supported = set(v2_model.get("supported_efforts") or [])
    missing = [e for e in v1_efforts if e not in v2_supported]
    if missing:
        errors.append(
            f"{name}: v1 efforts {missing} not present in v2 supported_efforts {sorted(v2_supported)}"
        )

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
sys.exit(0)
PY
}

# --- TEST-001 (AC-001): schema + per-model shape ---------------------------
if validate_schema_shape "$V2" >"$TMP/test-001.log" 2>&1; then
  ok "TEST-001: v2 schema field + per-model supported_efforts/default_effort/effort_control shape"
else
  bad "TEST-001: v2 schema shape violated -- $(cat "$TMP/test-001.log")"
fi

# --- TEST-002 (AC-002): risk_effort_matrix exact mapping -------------------
if validate_risk_matrix "$V2" >"$TMP/test-002.log" 2>&1; then
  ok "TEST-002: risk_effort_matrix exact mapping, escalation_bump true, no direct xhigh"
else
  bad "TEST-002: risk_effort_matrix violated -- $(cat "$TMP/test-002.log")"
fi

# --- TEST-003 (AC-003): role_defaults for all five roles -------------------
if validate_role_defaults "$V2" >"$TMP/test-003.log" 2>&1; then
  ok "TEST-003: role_defaults present for all five roles with minimum_tier + default_effort"
else
  bad "TEST-003: role_defaults violated -- $(cat "$TMP/test-003.log")"
fi

# --- TEST-004 (AC-004): parity lock + SHA-256 + negative self-check --------
if validate_parity "$V1" "$V2" >"$TMP/test-004.log" 2>&1; then
  ok "TEST-004: two-directional v1<->v2 parity (model names, canonical_tier, efforts subset)"
else
  bad "TEST-004: parity violated -- $(cat "$TMP/test-004.log")"
fi

# Mutation-based negative self-check (proves the parity assertion is live):
# copy the real v2 file to a scratch path and strip a v1-required effort
# from one model's supported_efforts, then confirm validate_parity now
# reports a violation. The tracked v2 file is never touched.
MUTATED_V2="$TMP/mutated-v2.json"
python3 - "$V2" "$MUTATED_V2" <<'PY'
import json
import sys

src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8") as fh:
    data = json.load(fh)

# anthropic/sonnet's v1 efforts is ["medium"]; remove "medium" from v2's
# supported_efforts so the subset check must fail.
for model in data.get("models", []):
    if model.get("name") == "anthropic/sonnet":
        model["supported_efforts"] = [e for e in model["supported_efforts"] if e != "medium"]
        if not model["supported_efforts"]:
            model["supported_efforts"] = ["low"]
        if model.get("default_effort") == "medium":
            model["default_effort"] = model["supported_efforts"][0]

with open(dst, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PY

if validate_parity "$V1" "$MUTATED_V2" >/dev/null 2>&1; then
  bad "TEST-004 (negative self-check): removing anthropic/sonnet's v1-required 'medium' effort from a mutated v2 copy did NOT turn the parity assertion red"
else
  ok "TEST-004 (negative self-check): a mutated v2 copy missing a v1-required effort correctly turns the parity assertion red"
fi

# --- TEST-005 (AC-005): PLUGIN-CONTRACTS.md documents the v2 schema -------
if [[ -f "$PLUGIN_CONTRACTS" ]] && grep -Fq "agent-model-capabilities/v2" "$PLUGIN_CONTRACTS"; then
  ok "TEST-005: PLUGIN-CONTRACTS.md documents the agent-model-capabilities/v2 schema"
else
  bad "TEST-005: PLUGIN-CONTRACTS.md does not document the agent-model-capabilities/v2 schema"
fi

# --- Self-registration (design.md Test Strategy #7; mirrors
# tests/second-approval-mask.tests.sh:285-289's established pattern) -------
if grep -q 'agent-capabilities-v2\.tests\.sh' "$RUN_ALL_SH"; then
  ok "self-registration: agent-capabilities-v2.tests.sh registered in tests/run-all.sh"
else
  bad "self-registration: agent-capabilities-v2.tests.sh NOT registered in tests/run-all.sh"
fi
if [[ -f "$RUN_ALL_PS1" ]] && grep -q 'agent-capabilities-v2\.tests\.ps1' "$RUN_ALL_PS1"; then
  ok "self-registration: agent-capabilities-v2.tests.ps1 registered in tests/run-all.ps1"
else
  bad "self-registration: agent-capabilities-v2.tests.ps1 NOT registered in tests/run-all.ps1"
fi

# --- Protected-file human-copy staging: .github/workflows/test.yml --------
# .github/workflows/test.yml is R-10 protected (guard_invariants.py:4); this
# suite never opens the real path for write, only the staged candidate.
STAGED_TEST_YML="$ROOT/specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml"
MANIFEST="$ROOT/specs/epic-159-pillar-c/human-copy/MANIFEST.sha256"
if [[ -f "$STAGED_TEST_YML" ]] && [[ -f "$MANIFEST" ]]; then
  staged_sha="$(sha256_of "$STAGED_TEST_YML")"
  if grep -Fq "$staged_sha  .github/workflows/test.yml" "$MANIFEST"; then
    ok "human-copy: staged .github/workflows/test.yml candidate matches its MANIFEST.sha256 entry"
  else
    bad "human-copy: staged .github/workflows/test.yml candidate SHA-256 does not match MANIFEST.sha256"
  fi
else
  bad "human-copy: staged .github/workflows/test.yml candidate or MANIFEST.sha256 is missing"
fi

# --- v1 frozen: SHA-256 unchanged before/after this suite's own run -------
V1_SHA_AFTER="$(sha256_of "$V1")"
if [[ "$V1_SHA_BEFORE" == "$V1_SHA_AFTER" ]]; then
  ok "AC-004: v1 registry SHA-256 unchanged before/after this suite's run ($V1_SHA_AFTER)"
else
  bad "AC-004: v1 registry SHA-256 CHANGED during this suite's run (before=$V1_SHA_BEFORE after=$V1_SHA_AFTER)"
fi

printf -- '---- summary: pass=%d fail=%d ----\n' "$pass" "$fail"
if [[ "$fail" -gt 0 ]]; then
  printf 'not ok: agent-capabilities-v2 suite FAILED (%d failures)\n' "$fail" >&2
  exit 1
fi
printf 'ok: agent-capabilities-v2 suite passed (%d checks)\n' "$pass"
