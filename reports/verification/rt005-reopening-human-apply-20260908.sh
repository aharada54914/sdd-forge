#!/usr/bin/env bash
# HUMAN-ONLY application: do not execute this through an agent to evade a hook.
set -euo pipefail
repo=/Users/jrmag/sdd-forge
cd "$repo"
patch=reports/verification/rt005-reopening-human-20260908.patch
check_hash() {
  local expected=$1 path=$2 actual
  [[ -f "$path" && ! -L "$path" ]] || { printf 'STOP: missing/linked: %s\n' "$path" >&2; exit 1; }
  actual=$(rtk proxy shasum -a 256 "$path")
  [[ "${actual%% *}" == "$expected" ]] || { printf 'STOP: hash changed: %s\n' "$path" >&2; exit 1; }
}
for required in rtk bash python3 pwsh git shasum jq; do
  command -v "$required" >/dev/null || { printf 'STOP: missing %s\n' "$required" >&2; exit 1; }
done
check_hash 6c9b085d7991c17ca095765742b8c2f7ab0637e7bd035d964fa58769e0bc8ea3 "$patch"
check_hash 2c13a604a8c007d2fb7a906d34c4830556829362fa1969f8542323d54ba972fc tests/workflow-state-t002-reopening.tests.py
check_hash 0c3da01fe7cd56ed1e78e3a06c0e5674111c6d8424554c3871726ac591a8aa92 specs/workflow-state-registry.json
check_hash bee4972d7d4d4ae8116ac0115d16295d1f167333edffd5a08d9dc8ceea3c31d7 contracts/workflow-state-registry.schema.json
check_hash d48910919b283acb0cdf6721059012b60d1ad8c53b16dedd974c7d19f82f4e63 plugins/sdd-quality-loop/scripts/check-workflow-state.sh
check_hash a253c220fe6c57bf90f9b782876628869b84d4a45e0de45675fba14a344e8aff plugins/sdd-quality-loop/scripts/check-workflow-state.ps1
check_hash 529f45341b7a9dbe99dec8df35825511350deb32a9015069c1dd1cf6b3bd94af tests/workflow-state-registry.tests.sh
rtk proxy git apply --check --recount "$patch"
backup=$(rtk proxy mktemp -d /tmp/sdd-t002-reopening.XXXXXXXX)
printf 'Backup and logs: %s\n' "$backup"
targets=(
  specs/workflow-state-registry.json
  contracts/workflow-state-registry.schema.json
  plugins/sdd-quality-loop/scripts/check-workflow-state.sh
  plugins/sdd-quality-loop/scripts/check-workflow-state.ps1
  tests/workflow-state-registry.tests.sh
)
for path in "${targets[@]}"; do
  rtk proxy mkdir -p "$backup/${path%/*}"
  rtk proxy cp -p "$path" "$backup/$path"
done
rtk proxy git apply --recount "$patch"
failed=0
run_check() {
  local label=$1 code
  shift
  printf '\nCheck: %s\n' "$label"
  if "$@" 2>&1 | rtk proxy tee "$backup/$label.log"; then code=0; else code=$?; failed=1; fi
  printf 'Exit: %s\n' "$code"
}
run_check syntax rtk proxy bash -n plugins/sdd-quality-loop/scripts/check-workflow-state.sh
run_check reopening rtk proxy python3 tests/workflow-state-t002-reopening.tests.py
run_check registry-bash rtk proxy bash tests/workflow-state-registry.tests.sh
run_check registry-pwsh rtk proxy pwsh -NoProfile -File tests/workflow-state-registry.tests.ps1
run_check target-bash rtk proxy bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature sdd-forge-mcp
run_check target-pwsh rtk proxy pwsh -NoProfile -File plugins/sdd-quality-loop/scripts/check-workflow-state.ps1 --feature sdd-forge-mcp
run_check workflow-bash rtk proxy bash tests/workflow-state.tests.sh
run_check workflow-pwsh rtk proxy pwsh -NoProfile -File tests/workflow-state.tests.ps1
run_check whitespace rtk proxy git diff --check
rtk proxy git diff --stat -- "${targets[@]}"
rtk proxy shasum -a 256 "${targets[@]}"
printf '\nChecks failed flag: %s; backup and logs: %s\n' "$failed" "$backup"
printf 'Stop here. Send complete output to Codex. Do not commit/push/merge or change review verdicts.\n'
exit "$failed"
