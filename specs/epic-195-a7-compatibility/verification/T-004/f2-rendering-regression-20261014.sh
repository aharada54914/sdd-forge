#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd -P)"
work="$(mktemp -d "${TMPDIR:-/tmp}/a7-f2-render.XXXXXX")"
trap 'rm -rf "$work"' EXIT
runtime="${1:?sh or ps1}"
case "$runtime" in sh|ps1) ;; *) exit 2;; esac
source_corpus="$ROOT/tests/fixtures/structural-fixture-corpus/f2-lite.json"
before="$(shasum -a 256 "$source_corpus" | awk '{print $1}')"
jq -n --rawfile req "$ROOT/plugins/sdd-lite/templates/requirements-lite.md" \
  --rawfile design "$ROOT/plugins/sdd-lite/templates/design-lite.md" \
  --rawfile tasks "$ROOT/plugins/sdd-lite/templates/tasks-lite.md" \
  '{schema:"structural-fixture-corpus/v1",fixture_state:"F2",recorded_at_model:"synthetic-regression-control",recorded_at_commit:"0000000000000000000000000000000000000000",refresh_procedure:"tests/structural-compatibility-live-refresh.tests.sh",artifacts:[{path:"requirements.md",content:$req},{path:"design.md",content:$design},{path:"tasks.md",content:$tasks}]} | .artifacts[].content |= (split("<feature>")|join("team-coffee-orders")|split("<タスク名>")|join("注文登録を実装する"))' > "$work/valid.json"
passed=0
failed=0
check() {
  local name="$1" expected="$2" code=0
  if [[ "$runtime" == sh ]]; then
    SDD_LIVE_REFRESH_SELF_CHECK=1 bash "$ROOT/tests/structural-compatibility-live-refresh.tests.sh" --state F2 --fixture "$work/$name.json" --dry-run > "$work/$name.log" 2>&1 || code=$?
  else
    SDD_LIVE_REFRESH_SELF_CHECK=1 pwsh -NoProfile -File "$ROOT/tests/structural-compatibility-live-refresh.tests.ps1" -State F2 -Fixture "$work/$name.json" -DryRun > "$work/$name.log" 2>&1 || code=$?
  fi
  if { [[ "$expected" == accept && "$code" == 0 ]]; } || { [[ "$expected" == reject && "$code" != 0 ]] && grep -Eq 'structural mismatch:|status field mismatch:' "$work/$name.log"; }; then
    printf 'PASS [%s]: %s %s\n' "$runtime" "$name" "$expected"; passed=$((passed+1))
  else
    printf 'FAIL [%s]: %s expected=%s exit=%s\n' "$runtime" "$name" "$expected" "$code"; cat "$work/$name.log"; failed=$((failed+1))
  fi
}
check valid accept
for name in feature feature-case placeholder task text level order status approval status-case; do
  case "$name" in
    feature) filter='.artifacts[0].content |= sub("team-coffee-orders";"wrong-feature")';;
    feature-case) filter='.artifacts[0].content |= sub("team-coffee-orders";"Team-coffee-orders")';;
    placeholder) filter='.artifacts[0].content |= sub("team-coffee-orders";"<feature>")';;
    task) filter='.artifacts[2].content |= sub("注文登録を実装する";"異なるタスク")';;
    text) filter='.artifacts[2].content |= sub("### Scope";"### scope")';;
    level) filter='.artifacts[2].content |= sub("### Scope";"## Scope")';;
    order) filter='.artifacts[2].content |= (sub("### Scope";"### TEMP")|sub("### Done When";"### Scope")|sub("### TEMP";"### Done When"))';;
    status) filter='.artifacts[2].content |= sub("Status: Planned\n";"")';;
    approval) filter='.artifacts[2].content |= sub("Approval: Draft\n";"")';;
    status-case) filter='.artifacts[2].content |= sub("Status: Planned";"status: Planned")';;
  esac
  jq "$filter" "$work/valid.json" > "$work/$name.json"
  check "$name" reject
done
after="$(shasum -a 256 "$source_corpus" | awk '{print $1}')"
[[ "$before" == "$after" ]] || { echo 'FAIL: corpus changed'; exit 1; }
printf 'F2 RENDERING SUMMARY [%s]: %d passed, %d failed; corpus unchanged\n' "$runtime" "$passed" "$failed"
[[ "$failed" == 0 ]]
