#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
CAPTURE="${GOLDEN_CAPTURE_UNDER_TEST:-${ROOT}/tests/capture-golden-baseline.sh}"
PROMOTE="${GOLDEN_PROMOTE_UNDER_TEST:-${ROOT}/tests/promote-golden-baseline.sh}"
BASELINE_ROOT="${ROOT}/specs/epic-195-a7-compatibility/verification/golden-baseline"
CANONICAL="${BASELINE_ROOT}/canonical"
CANDIDATE="${BASELINE_ROOT}/candidate/current"
PASS=0
FAIL=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ok() { printf 'ok: %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$*"; FAIL=$((FAIL + 1)); }

tree_hash() {
  python3 - "$1" <<'PY'
import hashlib
import os
import sys
from pathlib import Path

root = Path(sys.argv[1])
digest = hashlib.sha256()
if root.is_dir():
    for path in sorted(p for p in root.rglob("*") if p.is_file()):
        relative = path.relative_to(root).as_posix()
        digest.update(relative.encode("utf-8") + b"\0" + path.read_bytes() + b"\0")
print(digest.hexdigest())
PY
}

run_guard_case() {
  local name="$1"
  shift
  local touched="${WORK}/${name}.touched"
  local rc=0
  GOLDEN_TEST_TOUCH_PATH="$touched" "$@" >"${WORK}/${name}.out" 2>"${WORK}/${name}.err" || rc=$?
  if [[ $rc -ne 0 && ! -e "$touched" ]]; then
    ok "$name refuses with no file touched"
  else
    fail "$name must refuse with non-zero status and no file touched (status=$rc touched=$([[ -e "$touched" ]] && printf yes || printf no))"
  fi
}

if [[ "${1:-}" == "--red" ]]; then
  permissive="${WORK}/permissive-promote.sh"
  cat >"$permissive" <<'SH'
#!/usr/bin/env bash
: >"${GOLDEN_TEST_TOUCH_PATH}"
exit 0
SH
  chmod +x "$permissive"
  run_guard_case "CI-set" env CI=false "$permissive" "${WORK}/candidate" --approved-by human
  run_guard_case "approved-by-omitted" env -u CI "$permissive" "${WORK}/candidate"
  printf '%d passed, %d failed\n' "$PASS" "$FAIL"
  [[ $FAIL -eq 0 ]]
  exit
fi

if [[ -x "$CAPTURE" && -x "$PROMOTE" ]]; then
  ok "capture and promote commands are executable"
else
  fail "capture and promote commands must be executable"
fi

before="$(tree_hash "$CANONICAL")"
if env TZ=Pacific/Honolulu LC_ALL=C SDD_BASELINE_SENTINEL=must-not-leak "$CAPTURE" >"${WORK}/default.out" 2>"${WORK}/default.err" \
    && [[ "$(tree_hash "$CANONICAL")" == "$before" ]]; then
  ok "default capture matches canonical and is read-only"
else
  fail "default capture must match canonical without changing it"
fi

if env TZ=Pacific/Honolulu LC_ALL=C SDD_BASELINE_SENTINEL=must-not-leak "$CAPTURE" --write-candidate >"${WORK}/candidate.out" 2>"${WORK}/candidate.err" \
    && [[ "$(tree_hash "$CANONICAL")" == "$before" ]] \
    && diff -qr "$CANONICAL" "$CANDIDATE" >/dev/null; then
  ok "write-candidate writes an exact candidate without changing canonical"
else
  fail "write-candidate must write only an exact candidate"
fi

if python3 - "$ROOT" "$CANDIDATE" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
candidate = Path(sys.argv[2])
manifest = json.loads((candidate / "manifest.json").read_text(encoding="utf-8"))
expected_targets = [
    ("deterministic-script-output", "raw stdout/stderr byte-tuple"),
    ("exit-code", "status integer"),
    ("stdout-stderr", "raw stdout/stderr byte-tuple"),
    ("template-copy-result", "filesystem manifest (path -> sha256)"),
    ("schema-validator-result", "status integer"),
    ("install-result", "filesystem manifest"),
    ("uninstall-result", "filesystem manifest"),
    ("generated-directory-listing", "filesystem listing"),
    ("plugin-manifest", "filesystem manifest (path -> sha256)"),
]
assert manifest["schema_version"] == "golden-baseline-manifest/v1"
assert manifest["pre_capability_commit_sha"] == "50b20364e996432cb06061df03ffb4d173c27fa6"
assert manifest["fixed_environment"] == {"LC_ALL": "C", "TZ": "UTC", "ambient_sdd_variables": []}
assert [(item["name"], item["capture_format"]) for item in manifest["targets"]] == expected_targets
for group in (manifest["capture_scripts"], manifest["targets"]):
    for item in group:
        path = (root if group is manifest["capture_scripts"] else candidate) / item["path"]
        assert path.is_file()
        assert hashlib.sha256(path.read_bytes()).hexdigest() == item["sha256"]
PY
then
  ok "manifest records the pinned SHA, fixed environment, and every target/script hash"
else
  fail "manifest shape or a recorded hash is invalid"
fi

run_guard_case "CI-set" env CI=false "$PROMOTE" "$CANDIDATE" --approved-by human
run_guard_case "approved-by-omitted" env -u CI "$PROMOTE" "$CANDIDATE"

CLONE="${WORK}/repo"
if git clone -q --shared "$ROOT" "$CLONE" \
    && mkdir -p "${CLONE}/tests" "${CLONE}/specs/epic-195-a7-compatibility/verification/golden-baseline" \
    && cp "$ROOT/tests/capture-golden-baseline.sh" "$ROOT/tests/capture-golden-baseline.ps1" \
          "$ROOT/tests/promote-golden-baseline.sh" "$ROOT/tests/promote-golden-baseline.ps1" "${CLONE}/tests/" \
    && cp -R "$CANONICAL" "${CLONE}/specs/epic-195-a7-compatibility/verification/golden-baseline/canonical"; then
  clone_capture="${CLONE}/tests/capture-golden-baseline.sh"
  clone_promote="${CLONE}/tests/promote-golden-baseline.sh"
  clone_baseline="${CLONE}/specs/epic-195-a7-compatibility/verification/golden-baseline"
  printf 'drift\n' >>"${clone_baseline}/canonical/targets/exit-code.txt"
  rc=0
  "$clone_capture" >"${WORK}/drift.out" 2>"${WORK}/drift.err" || rc=$?
  if [[ $rc -ne 0 ]]; then ok "default capture exits non-zero on drift"; else fail "default capture must reject drift"; fi

  if "$clone_capture" --write-candidate >/dev/null 2>"${WORK}/clone-candidate.err" \
      && env -u CI "$clone_promote" "${clone_baseline}/candidate/current" --approved-by test-human >/dev/null 2>"${WORK}/promote.err" \
      && "$clone_capture" >/dev/null 2>"${WORK}/post-promote.err"; then
    ok "guarded promotion copies candidate to canonical"
  else
    fail "guarded promotion must restore a matching canonical baseline"
  fi

  cp "${clone_baseline}/canonical/manifest.json" "${WORK}/manifest.clean.json"
  python3 - "${clone_baseline}/canonical/manifest.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["pre_capability_commit_sha"] = "0" * 40
data["fixed_environment"]["TZ"] = "Etc/GMT+1"
data["fixed_environment"]["LC_ALL"] = "POSIX"
data["fixed_environment"]["ambient_sdd_variables"] = ["SDD_BASELINE_SENTINEL"]
data["capture_scripts"][0]["sha256"] = "0" * 64
for target in data["targets"]:
    target["sha256"] = "0" * 64
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
  rc=0
  "$clone_capture" >/dev/null 2>"${WORK}/manifest-mismatch.err" || rc=$?
  if [[ $rc -ne 0 ]]; then
    ok "manifest/counterpart mismatches fail closed"
  else
    fail "manifest/counterpart mismatches must fail"
  fi
else
  fail "disposable repository setup must succeed"
fi

if grep -Fxq 'candidate/' "${BASELINE_ROOT}/.gitignore"; then
  ok "candidate output is gitignored"
else
  fail "candidate/ must be gitignored"
fi

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
