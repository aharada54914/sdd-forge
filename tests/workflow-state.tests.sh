#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
CHECKER="$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }
rule_id() { sed -n 's/^workflow-state: [^:]*: \([^:]*\):.*/\1/p' | head -1; }

make_full_fixture() {
  local name="$1" target
  target="$TMP/$name"
  mkdir -p "$target"
  target="$(cd "$target" && pwd -P)"
  mkdir -p "$target/specs" "$target/reports/spec-review" "$target/reports/impl-review" "$target/reports/task-review"
  mkdir -p "$target/plugins/sdd-review-loop/references" "$target/plugins/sdd-quality-loop/references"
  cp "$ROOT/plugins/sdd-review-loop/references/spec-review-calibration.md" \
    "$ROOT/plugins/sdd-review-loop/references/reviewer-calibration.md" \
    "$target/plugins/sdd-review-loop/references/"
  cp "$ROOT/plugins/sdd-quality-loop/references/risk-gate-matrix.md" \
    "$ROOT/plugins/sdd-quality-loop/references/risk-classification-policy.md" \
    "$target/plugins/sdd-quality-loop/references/"
  cp -R "$ROOT/specs/workflow-state-integrity" "$target/specs/"
  cp -R "$ROOT/reports/spec-review/workflow-state-integrity" "$target/reports/spec-review/"
  cp -R "$ROOT/reports/impl-review/workflow-state-integrity" "$target/reports/impl-review/"
  cp -R "$ROOT/reports/task-review/workflow-state-integrity" "$target/reports/task-review/"
  while IFS= read -r evidence; do
    sed -i.bak "s#$ROOT#$target#g" "$evidence"
    rm "$evidence.bak"
  done < <(find "$target/reports" -type f \
    \( -name '*-review-contract.json' -o -name 'reviewer-a.json' -o -name 'reviewer-b.json' \))
  jq '{schema_version, migration_baseline_commit,
       entries: [.entries[] | select(.feature == "workflow-state-integrity")]}' \
    "$ROOT/specs/workflow-state-registry.json" > "$target/specs/workflow-state-registry.json"
  printf '%s\n' "$target"
}

expect_rule() {
  local root="$1" rule="$2" output status ps_output ps_status
  set +e
  output="$(bash "$CHECKER" --registry "$root/specs/workflow-state-registry.json" 2>&1)"
  status=$?
  ps_output="$(pwsh -NoProfile -File \
    "$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.ps1" \
    --registry "$root/specs/workflow-state-registry.json" 2>&1)"
  ps_status=$?
  set -e
  [[ $status -ne 0 ]] || fail "$rule fixture unexpectedly passed"
  [[ $ps_status -ne 0 ]] || fail "$rule PowerShell fixture unexpectedly passed"
  [[ "$output" == *": $rule:"* ]] || fail "$rule fixture returned: $output"
  [[ "$(printf '%s\n' "$output" | rule_id)" == "$(printf '%s\n' "$ps_output" | rule_id)" ]] ||
    fail "$rule fixture diverged: Shell=$output PowerShell=$ps_output"
}
expect_failure_parity() {
  local root="$1" output status ps_output ps_status
  set +e
  output="$(SDD_SUDO=1 bash "$CHECKER" --registry "$root/specs/workflow-state-registry.json" 2>&1)"
  status=$?
  ps_output="$(SDD_SUDO=1 pwsh -NoProfile -File \
    "$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.ps1" \
    --registry "$root/specs/workflow-state-registry.json" 2>&1)"
  ps_status=$?
  set -e
  [[ $status -ne 0 && $ps_status -ne 0 ]] || fail "invalid lifecycle matrix state passed"
  [[ "$(printf '%s\n' "$output" | rule_id)" == "$(printf '%s\n' "$ps_output" | rule_id)" ]] ||
    fail "lifecycle matrix rule IDs diverged: Shell=$output PowerShell=$ps_output"
}
expect_valid() {
  local root="$1"
  bash "$CHECKER" --registry "$root/specs/workflow-state-registry.json" >/dev/null ||
    fail "valid Shell fixture failed: $root"
  pwsh -NoProfile -File "$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.ps1" \
    --registry "$root/specs/workflow-state-registry.json" >/dev/null ||
    fail "valid PowerShell fixture failed: $root"
}

latest_task_round_dir() {
  local root="$1" path attempt round best="" best_attempt=-1 best_round=-1
  for path in "$root"/reports/task-review/workflow-state-integrity/attempt-*/round-*; do
    [[ -d "$path" ]] || continue
    attempt="${path%/round-*}"
    attempt="${attempt##*/attempt-}"
    round="${path##*/round-}"
    [[ "$attempt" =~ ^[0-9]+$ && "$round" =~ ^[0-9]+$ ]] || continue
    if ((attempt > best_attempt || attempt == best_attempt && round > best_round)); then
      best="$path"
      best_attempt="$attempt"
      best_round="$round"
    fi
  done
  [[ -n "$best" ]] || fail "latest task-review round was not found"
  printf '%s\n' "$best"
}

[[ -f "$CHECKER" ]] || fail "workflow-state Shell adapter is missing"

valid="$(make_full_fixture valid)"
expect_valid "$valid"

relocated="$(make_full_fixture sdd-forge)"
while IFS= read -r evidence; do
  sed -i.bak "s#$relocated#/opt/ci-agent/sdd-forge#g" "$evidence"
  rm "$evidence.bak"
done < <(find "$relocated/reports" -type f \
  \( -name '*-review-contract.json' -o -name 'reviewer-a.json' -o -name 'reviewer-b.json' \))
expect_valid "$relocated"

windows_relocated="$(make_full_fixture windows-sdd-forge)"
while IFS= read -r evidence; do
  jq --arg root "$windows_relocated" '
    walk(if type == "object" and has("path") and (.path | type == "string")
         then .path |= (gsub($root; "C:\\ci-agent\\windows-sdd-forge"))
         else . end)
  ' "$evidence" > "$windows_relocated/evidence.tmp"
  mv "$windows_relocated/evidence.tmp" "$evidence"
done < <(find "$windows_relocated/reports" -type f \
  \( -name '*-review-contract.json' -o -name 'reviewer-a.json' -o -name 'reviewer-b.json' \))
expect_valid "$windows_relocated"

mixed_relocated="$(make_full_fixture mixed-relocated)"
contract="$mixed_relocated/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json"
while IFS= read -r evidence; do
  sed -i.bak "s#$mixed_relocated#/opt/ci-agent/mixed-relocated#g" "$evidence"
  rm "$evidence.bak"
done < <(find "$mixed_relocated/reports" -type f \
  \( -name '*-review-contract.json' -o -name 'reviewer-a.json' -o -name 'reviewer-b.json' \))
jq '
  (.reviewers[0].allowed_input_manifest[] |
   select(.path | endswith("specs/workflow-state-integrity/design.md")) |
   .path) = "/other/ci-agent/mixed-relocated/specs/other-feature/design.md"
' "$contract" > "$mixed_relocated/contract.tmp"
mv "$mixed_relocated/contract.tmp" "$contract"
jq '
  (.allowed_input_manifest[] |
   select(.path | endswith("specs/workflow-state-integrity/design.md")) |
   .path) = "/other/ci-agent/mixed-relocated/specs/other-feature/design.md"
' "$mixed_relocated/reports/impl-review/workflow-state-integrity/attempt-1/round-2/reviewer-a.json" \
  > "$mixed_relocated/reviewer.tmp"
mv "$mixed_relocated/reviewer.tmp" \
  "$mixed_relocated/reports/impl-review/workflow-state-integrity/attempt-1/round-2/reviewer-a.json"
expect_rule "$mixed_relocated" stage-provenance

pending_all="$(make_full_fixture pending-all)"
sed -i.bak 's/^Spec-Review-Status: Passed$/Spec-Review-Status: Pending/' \
  "$pending_all/specs/workflow-state-integrity/requirements.md"
sed -i.bak 's/^Impl-Review-Status: Passed$/Impl-Review-Status: Pending/' \
  "$pending_all/specs/workflow-state-integrity/design.md"
rm "$pending_all/specs/workflow-state-integrity/"*.bak
rm "$pending_all/specs/workflow-state-integrity/tasks.md"
expect_valid "$pending_all"

impl_pending="$(make_full_fixture impl-pending)"
sed -i.bak 's/^Impl-Review-Status: Passed$/Impl-Review-Status: Pending/' \
  "$impl_pending/specs/workflow-state-integrity/design.md"
rm "$impl_pending/specs/workflow-state-integrity/design.md.bak"
rm "$impl_pending/specs/workflow-state-integrity/tasks.md"
expect_valid "$impl_pending"

task_pending_valid="$(make_full_fixture task-pending-valid)"
sed -i.bak \
  -e 's/^Task-Review-Status: Passed$/Task-Review-Status: Pending/' \
  -e 's/^Approval:.*/Approval: Draft/' \
  -e 's/^Status:.*/Status: Planned/' \
  "$task_pending_valid/specs/workflow-state-integrity/tasks.md"
rm "$task_pending_valid/specs/workflow-state-integrity/tasks.md.bak"
expect_valid "$task_pending_valid"

linked_pending_tasks="$(make_full_fixture linked-pending-tasks)"
sed -e 's/^Task-Review-Status: Passed$/Task-Review-Status: Pending/' \
    -e 's/^Approval:.*/Approval: Draft/' \
    -e 's/^Status:.*/Status: Planned/' \
  "$linked_pending_tasks/specs/workflow-state-integrity/tasks.md" \
  > "$linked_pending_tasks/external-tasks.md"
rm "$linked_pending_tasks/specs/workflow-state-integrity/tasks.md"
ln -s "$linked_pending_tasks/external-tasks.md" \
  "$linked_pending_tasks/specs/workflow-state-integrity/tasks.md"
expect_rule "$linked_pending_tasks" stage-input

stale="$(make_full_fixture stale)"
printf '\nStale mutation.\n' >> "$stale/specs/workflow-state-integrity/design.md"
expect_rule "$stale" stage-provenance

order="$(make_full_fixture order)"
sed -i.bak 's/^Spec-Review-Status: Passed$/Spec-Review-Status: Pending/' \
  "$order/specs/workflow-state-integrity/requirements.md"
rm "$order/specs/workflow-state-integrity/requirements.md.bak"
expect_rule "$order" stage-order

forged="$(make_full_fixture forged)"
forged_task_round="$(latest_task_round_dir "$forged")"
jq '.feature = "other-feature"' \
  "$forged_task_round/task-review-contract.json" \
  > "$forged/contract.tmp"
mv "$forged/contract.tmp" \
  "$forged_task_round/task-review-contract.json"
expect_rule "$forged" stage-provenance

manifest_gap="$(make_full_fixture manifest-gap)"
jq '(.reviewers[0].allowed_input_manifest) |=
      map(select((.path | endswith("specs/workflow-state-integrity/design.md")) | not))' \
  "$manifest_gap/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json" \
  > "$manifest_gap/contract.tmp"
mv "$manifest_gap/contract.tmp" \
  "$manifest_gap/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json"
expect_rule "$manifest_gap" stage-provenance

evil_manifest="$(make_full_fixture evil-manifest)"
jq '(.reviewers[0].allowed_input_manifest[] |
      select(.path | endswith("specs/workflow-state-integrity/design.md")) |
      .path) = "/evil-prefix/specs/workflow-state-integrity/design.md"' \
  "$evil_manifest/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json" \
  > "$evil_manifest/contract.tmp"
mv "$evil_manifest/contract.tmp" \
  "$evil_manifest/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json"
expect_rule "$evil_manifest" stage-provenance

malformed_contract="$(make_full_fixture malformed-contract)"
printf '{bad json\n' \
  > "$malformed_contract/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json"
expect_rule "$malformed_contract" stage-provenance

wrong_stage="$(make_full_fixture wrong-stage)"
jq '.stage = "task"' \
  "$wrong_stage/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json" \
  > "$wrong_stage/verdict.tmp"
mv "$wrong_stage/verdict.tmp" \
  "$wrong_stage/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json"
expect_rule "$wrong_stage" stage-provenance

non_pass="$(make_full_fixture non-pass)"
jq '.verdict = "NEEDS_WORK"' \
  "$non_pass/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json" \
  > "$non_pass/verdict.tmp"
mv "$non_pass/verdict.tmp" \
  "$non_pass/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json"
expect_rule "$non_pass" stage-provenance

forged_verdict="$(make_full_fixture forged-verdict)"
jq '.run_id = "forged-run"' \
  "$forged_verdict/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json" \
  > "$forged_verdict/verdict.tmp"
mv "$forged_verdict/verdict.tmp" \
  "$forged_verdict/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json"
expect_rule "$forged_verdict" stage-provenance

missing_run_id="$(make_full_fixture missing-run-id)"
jq 'del(.run_id)' \
  "$missing_run_id/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json" \
  > "$missing_run_id/verdict.tmp"
mv "$missing_run_id/verdict.tmp" \
  "$missing_run_id/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json"
jq 'del(.run_id)' \
  "$missing_run_id/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json" \
  > "$missing_run_id/contract.tmp"
mv "$missing_run_id/contract.tmp" \
  "$missing_run_id/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json"
expect_rule "$missing_run_id" stage-provenance

missing_spec_contract_run_id="$(make_full_fixture missing-spec-contract-run-id)"
jq 'del(.run_id)' \
  "$missing_spec_contract_run_id/reports/spec-review/workflow-state-integrity/attempt-1/round-2/spec-review-contract.json" \
  > "$missing_spec_contract_run_id/contract.tmp"
mv "$missing_spec_contract_run_id/contract.tmp" \
  "$missing_spec_contract_run_id/reports/spec-review/workflow-state-integrity/attempt-1/round-2/spec-review-contract.json"
expect_rule "$missing_spec_contract_run_id" stage-provenance

contradictory_reviewer="$(make_full_fixture contradictory-reviewer)"
jq '.verdict = "NEEDS_WORK" |
    .checks[0].result = "FAIL" |
    .checks[0].severity = "Critical"' \
  "$contradictory_reviewer/reports/spec-review/workflow-state-integrity/attempt-1/round-2/reviewer-a.json" \
  > "$contradictory_reviewer/reviewer.tmp"
mv "$contradictory_reviewer/reviewer.tmp" \
  "$contradictory_reviewer/reports/spec-review/workflow-state-integrity/attempt-1/round-2/reviewer-a.json"
expect_rule "$contradictory_reviewer" stage-provenance

contradictory_task_reviewer_b="$(make_full_fixture contradictory-task-reviewer-b)"
contradictory_task_round="$(latest_task_round_dir "$contradictory_task_reviewer_b")"
jq '.checks[0].result = "FAIL"' \
  "$contradictory_task_round/reviewer-b.json" \
  > "$contradictory_task_reviewer_b/reviewer.tmp"
mv "$contradictory_task_reviewer_b/reviewer.tmp" \
  "$contradictory_task_round/reviewer-b.json"
expect_rule "$contradictory_task_reviewer_b" stage-provenance

contradictory_summary="$(make_full_fixture contradictory-summary)"
jq '.reviewer_a_fail_count = 1 | .reviewer_a_pass_count -= 1' \
  "$contradictory_summary/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-summary.json" \
  > "$contradictory_summary/summary.tmp"
mv "$contradictory_summary/summary.tmp" \
  "$contradictory_summary/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-summary.json"
expect_rule "$contradictory_summary" stage-provenance

path_alias="$(make_full_fixture path-alias)"
if [[ "$path_alias" == /private/var/* ]]; then
  while IFS= read -r evidence; do
    sed -i.bak 's#"/private/var/#"/var/#g' "$evidence"
    rm "$evidence.bak"
  done < <(find "$path_alias/reports" -type f \
    \( -name '*-review-contract.json' -o -name 'reviewer-a.json' -o -name 'reviewer-b.json' \))
  expect_valid "$path_alias"
fi

contract_reviewer_fail="$(make_full_fixture contract-reviewer-fail)"
jq '.reviewer_a_verdict = "FAIL"' \
  "$contract_reviewer_fail/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json" \
  > "$contract_reviewer_fail/contract.tmp"
mv "$contract_reviewer_fail/contract.tmp" \
  "$contract_reviewer_fail/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json"
expect_rule "$contract_reviewer_fail" stage-provenance

top_level_hash="$(make_full_fixture top-level-hash)"
jq '.design_sha256 = ("0" * 64)' \
  "$top_level_hash/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json" \
  > "$top_level_hash/contract.tmp"
mv "$top_level_hash/contract.tmp" \
  "$top_level_hash/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json"
expect_rule "$top_level_hash" stage-provenance

missing_calibration="$(make_full_fixture missing-calibration)"
jq '(.reviewers[].allowed_input_manifest) |=
      map(select((.path | endswith("plugins/sdd-review-loop/references/reviewer-calibration.md")) | not))' \
  "$missing_calibration/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json" \
  > "$missing_calibration/contract.tmp"
mv "$missing_calibration/contract.tmp" \
  "$missing_calibration/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json"
expect_rule "$missing_calibration" stage-provenance

linked_verdict="$(make_full_fixture linked-verdict)"
mkdir -p \
  "$linked_verdict/reports/impl-review/workflow-state-integrity/attempt-999/round-1"
ln -s \
  "$linked_verdict/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json" \
  "$linked_verdict/reports/impl-review/workflow-state-integrity/attempt-999/round-1/integrated-verdict.json"
expect_rule "$linked_verdict" stage-provenance

missing_task_header="$(make_full_fixture missing-task-header)"
sed -i.bak '/^Task-Review-Status:/d' \
  "$missing_task_header/specs/workflow-state-integrity/tasks.md"
rm "$missing_task_header/specs/workflow-state-integrity/tasks.md.bak"
expect_rule "$missing_task_header" stage-status

unknown_passed_lifecycle="$(make_full_fixture unknown-passed-lifecycle)"
sed -i.bak -e 's/^Approval:.*/Approval: Banana/' -e 's/^Status:.*/Status: Weird/' \
  "$unknown_passed_lifecycle/specs/workflow-state-integrity/tasks.md"
rm "$unknown_passed_lifecycle/specs/workflow-state-integrity/tasks.md.bak"
expect_rule "$unknown_passed_lifecycle" task-lifecycle

pending="$(make_full_fixture pending)"
sed -i.bak 's/^Task-Review-Status: Passed$/Task-Review-Status: Pending/' \
  "$pending/specs/workflow-state-integrity/tasks.md"
rm "$pending/specs/workflow-state-integrity/tasks.md.bak"
expect_rule "$pending" task-lifecycle

invalid_pending="$(make_full_fixture invalid-pending)"
sed -i.bak \
  -e 's/^Task-Review-Status: Passed$/Task-Review-Status: Pending/' \
  -e 's/^Approval:.*/Approval: Banana/' \
  -e 's/^Status:.*/Status: Weird/' \
  "$invalid_pending/specs/workflow-state-integrity/tasks.md"
rm "$invalid_pending/specs/workflow-state-integrity/tasks.md.bak"
expect_rule "$invalid_pending" task-lifecycle

matrix_index=0
for predecessor in spec impl task; do
  for lifecycle in Approved "In Progress" "Implementation Complete" Done; do
    matrix_index=$((matrix_index + 1))
    matrix="$(make_full_fixture "matrix-$matrix_index")"
    case "$predecessor" in
      spec)
        sed -i.bak 's/^Spec-Review-Status: Passed$/Spec-Review-Status: Pending/' \
          "$matrix/specs/workflow-state-integrity/requirements.md"
        rm "$matrix/specs/workflow-state-integrity/requirements.md.bak"
        ;;
      impl)
        sed -i.bak 's/^Impl-Review-Status: Passed$/Impl-Review-Status: Pending/' \
          "$matrix/specs/workflow-state-integrity/design.md"
        rm "$matrix/specs/workflow-state-integrity/design.md.bak"
        ;;
      task)
        sed -i.bak 's/^Task-Review-Status: Passed$/Task-Review-Status: Pending/' \
          "$matrix/specs/workflow-state-integrity/tasks.md"
        rm "$matrix/specs/workflow-state-integrity/tasks.md.bak"
        ;;
    esac
    if [[ "$lifecycle" == Approved ]]; then
      sed -i.bak -e '0,/^Approval:.*/s//Approval: Approved/' \
        -e '0,/^Status:.*/s//Status: Planned/' \
        "$matrix/specs/workflow-state-integrity/tasks.md"
    else
      sed -i.bak -e '0,/^Approval:.*/s//Approval: Draft/' \
        -e "0,/^Status:.*/s//Status: $lifecycle/" \
        "$matrix/specs/workflow-state-integrity/tasks.md"
    fi
    rm "$matrix/specs/workflow-state-integrity/tasks.md.bak"
    expect_failure_parity "$matrix"
  done
done

missing="$(make_full_fixture missing)"
rm "$missing/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json"
expect_rule "$missing" stage-provenance

malformed="$(make_full_fixture malformed)"
printf '{bad json\n' > "$malformed/specs/workflow-state-registry.json"
expect_rule "$malformed" registry-malformed

unreadable="$(make_full_fixture unreadable)"
chmod 000 "$unreadable/specs/workflow-state-registry.json"
expect_rule "$unreadable" registry-unreadable
chmod 600 "$unreadable/specs/workflow-state-registry.json"

wrong_baseline="$(make_full_fixture wrong-baseline)"
jq '.migration_baseline_commit = "bad"' \
  "$wrong_baseline/specs/workflow-state-registry.json" > "$wrong_baseline/registry.tmp"
mv "$wrong_baseline/registry.tmp" "$wrong_baseline/specs/workflow-state-registry.json"
expect_rule "$wrong_baseline" registry-schema

root_property="$(make_full_fixture root-property)"
jq '.unexpected = true' \
  "$root_property/specs/workflow-state-registry.json" > "$root_property/registry.tmp"
mv "$root_property/registry.tmp" "$root_property/specs/workflow-state-registry.json"
expect_rule "$root_property" registry-schema

missing_input="$(make_full_fixture missing-input)"
rm "$missing_input/specs/workflow-state-integrity/acceptance-tests.md"
expect_rule "$missing_input" stage-input

overbroad="$(make_full_fixture overbroad)"
jq '.entries = [{
      "feature":"workflow-state-integrity",
      "profile":"legacy",
      "legacy":{
        "introduced_before_commit":.migration_baseline_commit,
        "reason":"unbounded exception",
        "owner":"test",
        "allowed_missing_stages":["spec","impl","task"],
        "allowed_noncanonical_statuses":{},
        "allowed_task_approvals":["Draft","Approved"],
        "allowed_task_statuses":["Planned","In Progress","Implementation Complete","Done"]
      }}]' "$overbroad/specs/workflow-state-registry.json" > "$overbroad/registry.tmp"
mv "$overbroad/registry.tmp" "$overbroad/specs/workflow-state-registry.json"
expect_rule "$overbroad" registry-schema

escape="$TMP/escape"
mkdir -p "$escape/specs" "$escape/outside"
ln -s "$escape/outside" "$escape/specs/escape"
jq '.entries = [{"feature":"escape","profile":"full"}]' \
  "$ROOT/specs/workflow-state-registry.json" > "$escape/specs/workflow-state-registry.json"
expect_rule "$escape" registry-path-escape

lite="$TMP/lite"
mkdir -p "$lite/specs/sdd-lite"
printf '# Lite\n' > "$lite/specs/sdd-lite/requirements.md"
jq '{schema_version, migration_baseline_commit,
     entries: [.entries[] | select(.feature == "sdd-lite")]}' \
  "$ROOT/specs/workflow-state-registry.json" > "$lite/specs/workflow-state-registry.json"
bash "$CHECKER" --registry "$lite/specs/workflow-state-registry.json" >/dev/null ||
  fail "lite fixture was subjected to full rules"

printf 'ok: Shell workflow-state validation fixtures passed\n'
