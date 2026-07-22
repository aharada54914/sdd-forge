#!/usr/bin/env bash
# TDD suite for the Registry discovery contract + vendoring step
# (T-003, REQ-005, ADR-0025).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
REAL_DISCOVERY="$ROOT/plugins/sdd-quality-loop/scripts/registry_discovery.py"
REAL_VENDOR="$ROOT/plugins/sdd-quality-loop/scripts/vendor-capability-registry.py"
FIXTURES="$ROOT/tests/fixtures/capability-registry"

WORKDIR="$(mktemp -d)"
WORKDIR="$(cd "$WORKDIR" && pwd -P)"
trap 'rm -rf "$WORKDIR"' EXIT

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); printf 'ok: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'not ok: %s\n' "$1" >&2; }

# make_layout <name> <registry-mode> <schema-mode> <catalog-mode> [symlink]
# modes: valid|bad|missing-schema-key (schema only)|missing
# Returns (via echo) the path to the scripts/registry_discovery.py entry
# point to invoke (may be a symlink).
make_layout() {
  local name="$1" reg_mode="$2" schema_mode="$3" catalog_mode="$4" use_symlink="${5:-no}"
  local base="$WORKDIR/layout-$name"
  local scripts_dir="$base/plugins/sdd-quality-loop/scripts"
  local contracts_dir="$base/plugins/sdd-quality-loop/contracts"
  mkdir -p "$scripts_dir"

  local entry
  if [[ "$use_symlink" == "yes" ]]; then
    local real_base="$WORKDIR/real-$name"
    local real_scripts="$real_base/plugins/sdd-quality-loop/scripts"
    mkdir -p "$real_scripts"
    cp "$REAL_DISCOVERY" "$real_scripts/registry_discovery.py"
    ln -s "$real_scripts/registry_discovery.py" "$scripts_dir/registry_discovery.py"
    contracts_dir="$real_base/plugins/sdd-quality-loop/contracts"
    entry="$scripts_dir/registry_discovery.py"
  else
    cp "$REAL_DISCOVERY" "$scripts_dir/registry_discovery.py"
    entry="$scripts_dir/registry_discovery.py"
  fi

  if [[ "$reg_mode" != "missing" || "$schema_mode" != "missing" || "$catalog_mode" != "missing" ]]; then
    mkdir -p "$contracts_dir"
  fi

  case "$reg_mode" in
    valid) cp "$FIXTURES/registry-discovery-registry-valid.json" "$contracts_dir/capability-registry.json" ;;
    bad) cp "$FIXTURES/registry-discovery-registry-bad-schema.json" "$contracts_dir/capability-registry.json" ;;
    missing) : ;;
  esac
  case "$schema_mode" in
    valid) cp "$FIXTURES/registry-discovery-schemafile-valid.json" "$contracts_dir/capability-registry.schema.json" ;;
    bad-id) cp "$FIXTURES/registry-discovery-schemafile-bad-id.json" "$contracts_dir/capability-registry.schema.json" ;;
    missing-schema-key) cp "$FIXTURES/registry-discovery-schemafile-missing-schema-key.json" "$contracts_dir/capability-registry.schema.json" ;;
    missing) : ;;
  esac
  case "$catalog_mode" in
    valid) cp "$FIXTURES/registry-discovery-catalog-valid.json" "$contracts_dir/lite-upgrade-reason-catalog.json" ;;
    bad) cp "$FIXTURES/registry-discovery-catalog-bad-schema.json" "$contracts_dir/lite-upgrade-reason-catalog.json" ;;
    missing) : ;;
  esac
  printf '%s' "$entry"
}

run_discover() {
  # $1 = entry path, $2 = filename to discover. Sets OUT, RC, ERRTEXT.
  OUT="$(python3 "$1" "$2" 2>"$WORKDIR/stderr.log")"
  RC=$?
  ERRTEXT="$(cat "$WORKDIR/stderr.log")"
}

# =====================================================================
# Test Strategy item 8 / AC-027: three installed-layout fixtures (one per
# runtime), packaged copy alone resolves, no git reachable (mktemp dirs
# live outside this repository), no runtime env var consulted (none is
# ever read by registry_discovery.py).
# =====================================================================
for runtime in claude-code codex-cli copilot-cli; do
  use_symlink=no
  [[ "$runtime" == "codex-cli" ]] && use_symlink=yes  # also exercises symlink resolution
  entry="$(make_layout "$runtime" valid valid valid "$use_symlink")"
  for filename in capability-registry.json capability-registry.schema.json lite-upgrade-reason-catalog.json; do
    run_discover "$entry" "$filename"
    if [[ "$RC" -eq 0 && "$OUT" == */plugins/sdd-quality-loop/contracts/"$filename" ]]; then
      ok "AC-027 installed-layout ($runtime): $filename resolves via packaged copy alone"
    else
      fail "AC-027 installed-layout ($runtime): $filename did not resolve via packaged copy (rc=$RC out=$OUT err=$ERRTEXT)"
    fi
  done
done

# =====================================================================
# AC-027: three per-artifact version-mismatch fixtures -- fail-closed,
# non-zero exit, diagnostic naming the attempted path.
# =====================================================================
entry="$(make_layout mismatch-registry bad valid valid)"
run_discover "$entry" capability-registry.json
if [[ "$RC" -ne 0 && "$ERRTEXT" == *"registry-discovery"* && "$ERRTEXT" == *"capability-registry.json"* ]]; then
  ok "AC-027 version-mismatch: wrong schema value on the Registry fails closed"
else
  fail "AC-027 version-mismatch: Registry bad-schema did not fail closed as expected (rc=$RC err=$ERRTEXT)"
fi

entry="$(make_layout mismatch-schema-id valid bad-id valid)"
run_discover "$entry" capability-registry.schema.json
if [[ "$RC" -ne 0 && "$ERRTEXT" == *"registry-discovery"* ]]; then
  ok "AC-027 version-mismatch: mismatched \$id on the schema file fails closed"
else
  fail "AC-027 version-mismatch: schema-file bad-\$id did not fail closed as expected (rc=$RC err=$ERRTEXT)"
fi

entry="$(make_layout mismatch-schema-missing-key valid missing-schema-key valid)"
run_discover "$entry" capability-registry.schema.json
if [[ "$RC" -ne 0 && "$ERRTEXT" == *"registry-discovery"* ]]; then
  ok "AC-027 version-mismatch: missing \$schema key on the schema file fails closed"
else
  fail "AC-027 version-mismatch: schema-file missing-\$schema did not fail closed as expected (rc=$RC err=$ERRTEXT)"
fi

entry="$(make_layout mismatch-catalog valid valid bad)"
run_discover "$entry" lite-upgrade-reason-catalog.json
if [[ "$RC" -ne 0 && "$ERRTEXT" == *"registry-discovery"* && "$ERRTEXT" == *"lite-upgrade-reason-catalog.json"* ]]; then
  ok "AC-027 version-mismatch: wrong schema value on the catalog fails closed"
else
  fail "AC-027 version-mismatch: catalog bad-schema did not fail closed as expected (rc=$RC err=$ERRTEXT)"
fi

# =====================================================================
# AC-027: one neither-location-resolves fixture -- fail-closed diagnostic
# naming both attempted paths, no reachable git root either.
# =====================================================================
entry="$(make_layout neither-resolves missing missing missing)"
run_discover "$entry" capability-registry.json
if [[ "$RC" -ne 0 && "$ERRTEXT" == *"registry-discovery"* && "$ERRTEXT" == *"plugins/sdd-quality-loop/contracts/capability-registry.json"* ]]; then
  ok "AC-027 neither-location-resolves: fail-closed diagnostic names the attempted path(s)"
else
  fail "AC-027 neither-location-resolves: expected fail-closed diagnostic naming attempted paths (rc=$RC err=$ERRTEXT)"
fi

# =====================================================================
# AC-027: vendored-copy-drift fixture -- vendor-capability-registry.py
# --check exits non-zero on a stale vendored copy, exits zero with no
# write against a freshly-vendored tree.
# =====================================================================
DRIFT_ROOT="$WORKDIR/drift-repo"
mkdir -p "$DRIFT_ROOT/contracts" "$DRIFT_ROOT/plugins/sdd-quality-loop/scripts" "$DRIFT_ROOT/plugins/sdd-quality-loop/contracts"
git init -q "$DRIFT_ROOT"
cp "$FIXTURES/registry-discovery-registry-valid.json" "$DRIFT_ROOT/contracts/capability-registry.json"
cp "$FIXTURES/registry-discovery-schemafile-valid.json" "$DRIFT_ROOT/contracts/capability-registry.schema.json"
cp "$FIXTURES/registry-discovery-catalog-valid.json" "$DRIFT_ROOT/contracts/lite-upgrade-reason-catalog.json"
cp "$REAL_DISCOVERY" "$DRIFT_ROOT/plugins/sdd-quality-loop/scripts/registry_discovery.py"
cp "$REAL_VENDOR" "$DRIFT_ROOT/plugins/sdd-quality-loop/scripts/vendor-capability-registry.py"
# Deliberately stale vendored copy (differs from the canonical source).
cp "$FIXTURES/registry-discovery-registry-bad-schema.json" "$DRIFT_ROOT/plugins/sdd-quality-loop/contracts/capability-registry.json"
cp "$FIXTURES/registry-discovery-schemafile-valid.json" "$DRIFT_ROOT/plugins/sdd-quality-loop/contracts/capability-registry.schema.json"
cp "$FIXTURES/registry-discovery-catalog-valid.json" "$DRIFT_ROOT/plugins/sdd-quality-loop/contracts/lite-upgrade-reason-catalog.json"

python3 "$DRIFT_ROOT/plugins/sdd-quality-loop/scripts/vendor-capability-registry.py" --check >/dev/null 2>"$WORKDIR/drift-check.log"
if [[ $? -ne 0 ]]; then
  ok "AC-027 vendored-copy-drift: --check fails non-zero on a stale vendored copy"
else
  fail "AC-027 vendored-copy-drift: --check unexpectedly passed against a stale vendored copy"
fi

# Freshly-vendored tree: re-vendor for real, then confirm --check passes
# and performs no filesystem write (mtime-unchanged after a second --check).
python3 "$DRIFT_ROOT/plugins/sdd-quality-loop/scripts/vendor-capability-registry.py" >/dev/null 2>&1
mtime_before="$(stat -f '%m' "$DRIFT_ROOT/plugins/sdd-quality-loop/contracts/capability-registry.json" 2>/dev/null || stat -c '%Y' "$DRIFT_ROOT/plugins/sdd-quality-loop/contracts/capability-registry.json")"
python3 "$DRIFT_ROOT/plugins/sdd-quality-loop/scripts/vendor-capability-registry.py" --check >/dev/null 2>"$WORKDIR/drift-check2.log"
drift_check_rc=$?
mtime_after="$(stat -f '%m' "$DRIFT_ROOT/plugins/sdd-quality-loop/contracts/capability-registry.json" 2>/dev/null || stat -c '%Y' "$DRIFT_ROOT/plugins/sdd-quality-loop/contracts/capability-registry.json")"
if [[ "$drift_check_rc" -eq 0 ]]; then
  ok "AC-027 vendored-copy-drift: --check exits zero against a freshly-vendored tree"
else
  fail "AC-027 vendored-copy-drift: --check unexpectedly failed against a freshly-vendored tree"
fi
if [[ "$mtime_before" == "$mtime_after" ]]; then
  ok "AC-027 vendored-copy-drift: --check performs no filesystem write (mtime unchanged)"
else
  fail "AC-027 vendored-copy-drift: --check unexpectedly modified the vendored file (mtime changed)"
fi

# =====================================================================
# Suite/CI registration self-checks
# =====================================================================
if grep -q 'tests/registry-discovery.tests.sh' "$ROOT/tests/run-all.sh"; then
  ok "self-registration: registry-discovery.tests.sh registered in tests/run-all.sh"
else
  fail "self-registration: registry-discovery.tests.sh NOT registered in tests/run-all.sh"
fi
if grep -q 'tests/registry-discovery.tests.ps1' "$ROOT/tests/run-all.ps1"; then
  ok "self-registration: registry-discovery.tests.ps1 registered in tests/run-all.ps1"
else
  fail "self-registration: registry-discovery.tests.ps1 NOT registered in tests/run-all.ps1"
fi

HUMAN_COPY_DIR="$ROOT/specs/epic-190-a2-capability-registry/human-copy"
STAGED_WORKFLOW="$HUMAN_COPY_DIR/.github/workflows/test.yml"
STAGED_MANIFEST="$HUMAN_COPY_DIR/MANIFEST.sha256"
if [[ -f "$STAGED_WORKFLOW" ]] && grep -q 'tests/registry-discovery.tests.sh' "$STAGED_WORKFLOW" && grep -q 'tests/registry-discovery.tests.ps1' "$STAGED_WORKFLOW"; then
  ok "human-copy: staged workflow candidate registers this suite's CI steps"
else
  fail "human-copy: staged workflow candidate missing this suite's CI steps"
fi
if [[ -f "$STAGED_MANIFEST" ]]; then
  staged_hash="$(shasum -a 256 "$STAGED_WORKFLOW" | awk '{print $1}')"
  manifest_hash="$(grep -F 'workflows/test.yml' "$STAGED_MANIFEST" | awk '{print $1}')"
  if [[ -n "$manifest_hash" && "$staged_hash" == "$manifest_hash" ]]; then
    ok "human-copy: staged workflow candidate sha256 matches MANIFEST.sha256"
  else
    fail "human-copy: staged workflow candidate sha256 does not match MANIFEST.sha256"
  fi
else
  fail "human-copy: MANIFEST.sha256 missing"
fi

printf -- '---- summary: pass=%d fail=%d ----\n' "$PASS" "$FAIL"
if [[ "$FAIL" -eq 0 ]]; then
  printf 'registry-discovery suite passed (%d checks)\n' "$PASS"
  exit 0
else
  printf 'registry-discovery suite FAILED (%d passed, %d failed)\n' "$PASS" "$FAIL"
  exit 1
fi
