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
  # Force a "full" profile for the isolated fixture regardless of the real
  # registry's current classification of workflow-state-integrity. These
  # fixtures deliberately corrupt stage-provenance evidence to assert the
  # checker still rejects it; workflow-state-integrity may be grandfathered
  # to "legacy" in the live registry (e.g. after provenance-hash drift),
  # which would otherwise silently mask the corruption these tests inject.
  jq '{schema_version, migration_baseline_commit,
       entries: [.entries[] | select(.feature == "workflow-state-integrity") | .profile="full" | del(.legacy)]}' \
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

# Issue #71: an impl-review reviewer's allowed_input_manifest may legitimately
# be a superset of the round contract's recorded manifest when the round
# reviewed the four layer specs (ux/frontend/infra/security) but the contract
# predates recording them. That superset must be accepted as long as every
# extra entry is exactly one of the four layer-spec paths for this feature.
layer_superset="$(make_full_fixture layer-superset)"
for layer in ux-spec frontend-spec infra-spec security-spec; do
  printf '# %s\n' "$layer" > "$layer_superset/specs/workflow-state-integrity/$layer.md"
done
for reviewer in a b; do
  reviewer_file="$layer_superset/reports/impl-review/workflow-state-integrity/attempt-1/round-2/reviewer-$reviewer.json"
  jq '
    .allowed_input_manifest += [
      {"path": "specs/workflow-state-integrity/ux-spec.md"},
      {"path": "specs/workflow-state-integrity/frontend-spec.md"},
      {"path": "specs/workflow-state-integrity/infra-spec.md"},
      {"path": "specs/workflow-state-integrity/security-spec.md"}
    ]' "$reviewer_file" > "$layer_superset/reviewer.tmp"
  mv "$layer_superset/reviewer.tmp" "$reviewer_file"
done
for layer in ux-spec frontend-spec infra-spec security-spec; do
  layer_path="$layer_superset/specs/workflow-state-integrity/$layer.md"
  layer_hash="$(shasum -a 256 "$layer_path" | awk '{print $1}')"
  layer_relative="specs/workflow-state-integrity/$layer.md"
  for reviewer in a b; do
    reviewer_file="$layer_superset/reports/impl-review/workflow-state-integrity/attempt-1/round-2/reviewer-$reviewer.json"
    jq --arg path "$layer_relative" --arg hash "$layer_hash" '
      (.allowed_input_manifest[] | select(.path == $path) | .sha256) = $hash
    ' "$reviewer_file" > "$layer_superset/reviewer.tmp"
    mv "$layer_superset/reviewer.tmp" "$reviewer_file"
  done
done
expect_valid "$layer_superset"

# A reviewer manifest superset entry that is NOT one of the four layer specs
# must still be rejected -- unrestricted supersets would weaken provenance.
disallowed_superset="$(make_full_fixture disallowed-superset)"
printf '# unrelated extra input\n' > "$disallowed_superset/specs/workflow-state-integrity/extra-notes.md"
extra_path="$disallowed_superset/specs/workflow-state-integrity/extra-notes.md"
extra_hash="$(shasum -a 256 "$extra_path" | awk '{print $1}')"
reviewer_a_file="$disallowed_superset/reports/impl-review/workflow-state-integrity/attempt-1/round-2/reviewer-a.json"
jq --arg path "specs/workflow-state-integrity/extra-notes.md" --arg hash "$extra_hash" '
  .allowed_input_manifest += [{"path": $path, "sha256": $hash}]' \
  "$reviewer_a_file" > "$disallowed_superset/reviewer.tmp"
mv "$disallowed_superset/reviewer.tmp" "$reviewer_a_file"
expect_rule "$disallowed_superset" stage-provenance

# A contract entry missing from the reviewer's own recorded manifest must
# still fail -- the reviewer manifest must always be a superset of (i.e.
# cover) everything the contract claims it reviewed.
reviewer_manifest_shortfall="$(make_full_fixture reviewer-manifest-shortfall)"
reviewer_a_file="$reviewer_manifest_shortfall/reports/impl-review/workflow-state-integrity/attempt-1/round-2/reviewer-a.json"
jq '(.allowed_input_manifest) |=
      map(select((.path | endswith("specs/workflow-state-integrity/design.md")) | not))' \
  "$reviewer_a_file" > "$reviewer_manifest_shortfall/reviewer.tmp"
mv "$reviewer_manifest_shortfall/reviewer.tmp" "$reviewer_a_file"
expect_rule "$reviewer_manifest_shortfall" stage-provenance

# Reference-doc hash drift: plugins/ reference docs (risk-gate-matrix.md,
# reviewer-calibration.md, etc.) are living documents that evolve as the
# quality loop matures. The workflow-state-integrity task-review evidence
# recorded plugins/sdd-quality-loop/references/risk-gate-matrix.md's sha256
# from before commit cfe1d8d (unified-design-system) added a new row to that
# matrix. The live file's current hash therefore no longer matches the
# historical manifest. The checker must still PASS by resolving the file's
# content as of the commit that produced this evidence (git show <pin>:path)
# and confirming that historical content matches the recorded hash -- a
# reference doc's later, legitimate evolution must not retroactively fail a
# past feature's provenance. This exercises the same drift as the "valid"
# fixture above, but makes the regression explicit and self-documenting.
reference_doc_evolved="$(make_full_fixture reference-doc-evolved)"
evolved_matrix="$reference_doc_evolved/plugins/sdd-quality-loop/references/risk-gate-matrix.md"
recorded_matrix_hash="$(jq -r '
  .reviewers[]?.allowed_input_manifest[]? |
  select(.path | endswith("risk-gate-matrix.md")) | .sha256
' "$reference_doc_evolved/reports/task-review/workflow-state-integrity/attempt-4/round-2/task-review-contract.json" | head -1)"
current_matrix_hash="$(shasum -a 256 "$evolved_matrix" | awk '{print $1}')"
[[ -n "$recorded_matrix_hash" && "$recorded_matrix_hash" != "$current_matrix_hash" ]] ||
  fail "reference-doc-evolved fixture precondition not met: risk-gate-matrix.md is not actually drifted"
expect_valid "$reference_doc_evolved"

# A plugins/ manifest hash that matches neither the live file nor any
# legitimate point-in-time content (i.e. a forged/tampered hash) must still
# fail -- the pinned-commit fallback must not become a blanket bypass.
reference_doc_forged="$(make_full_fixture reference-doc-forged)"
forged_task_contract="$reference_doc_forged/reports/task-review/workflow-state-integrity/attempt-4/round-2/task-review-contract.json"
jq '(.reviewers[].allowed_input_manifest[] |
      select(.path | endswith("risk-gate-matrix.md")) | .sha256) = ("f" * 64)' \
  "$forged_task_contract" > "$reference_doc_forged/contract.tmp"
mv "$reference_doc_forged/contract.tmp" "$forged_task_contract"
forged_reviewer_b="$reference_doc_forged/reports/task-review/workflow-state-integrity/attempt-4/round-2/reviewer-b.json"
jq '(.manifest.allowed_inputs[]? |
      select(.path | endswith("risk-gate-matrix.md")) | .sha256) = ("f" * 64)' \
  "$forged_reviewer_b" > "$reference_doc_forged/reviewer.tmp"
mv "$reference_doc_forged/reviewer.tmp" "$forged_reviewer_b"
expect_rule "$reference_doc_forged" stage-provenance

# WFI-024: a release artifact (e.g. the tarball repository-release-validation
# .tests.sh builds by excluding .git) has no history at all, so the pinned-
# commit fallback above has nothing to reconcile a manifest-recorded plugins/
# hash against. The SAME forged input that reference-doc-forged (immediately
# above) proves is REJECTED when git history is available must instead be
# ACCEPTED when it is not: the comparison is not evaluable there, not failed.
# This embeds a standalone copy of the checker (plus the schema it needs) at
# the canonical relative depth inside a fixture with no git ancestor above
# it, so plugins_git_history_available/Test-PluginsGitHistoryAvailable
# genuinely observes "no history" rather than relying on $TMP happening to
# sit outside a repository.
reference_doc_forged_no_git="$(make_full_fixture reference-doc-forged-no-git)"
no_git_task_contract="$reference_doc_forged_no_git/reports/task-review/workflow-state-integrity/attempt-4/round-2/task-review-contract.json"
jq '(.reviewers[].allowed_input_manifest[] |
      select(.path | endswith("risk-gate-matrix.md")) | .sha256) = ("f" * 64)' \
  "$no_git_task_contract" > "$reference_doc_forged_no_git/contract.tmp"
mv "$reference_doc_forged_no_git/contract.tmp" "$no_git_task_contract"
no_git_reviewer_b="$reference_doc_forged_no_git/reports/task-review/workflow-state-integrity/attempt-4/round-2/reviewer-b.json"
jq '(.manifest.allowed_inputs[]? |
      select(.path | endswith("risk-gate-matrix.md")) | .sha256) = ("f" * 64)' \
  "$no_git_reviewer_b" > "$reference_doc_forged_no_git/reviewer.tmp"
mv "$reference_doc_forged_no_git/reviewer.tmp" "$no_git_reviewer_b"
no_git_scripts="$reference_doc_forged_no_git/plugins/sdd-quality-loop/scripts"
mkdir -p "$no_git_scripts" "$reference_doc_forged_no_git/contracts"
cp "$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.sh" \
  "$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.ps1" \
  "$no_git_scripts/"
cp "$ROOT/contracts/workflow-state-registry.schema.json" \
  "$reference_doc_forged_no_git/contracts/"
# Non-vacuity precondition: without a genuinely git-less fixture root, this
# case would silently fall through to the same pinned-commit path that
# reference-doc-forged already covers and prove nothing about "no history".
if git -C "$reference_doc_forged_no_git" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "reference-doc-forged-no-git fixture precondition not met: fixture root is inside a git work tree"
fi
no_git_sh_output="$(bash "$no_git_scripts/check-workflow-state.sh" \
  --registry "$reference_doc_forged_no_git/specs/workflow-state-registry.json" 2>&1)" ||
  fail "reference-doc-forged-no-git Shell fixture unexpectedly rejected: $no_git_sh_output"
no_git_ps_output="$(pwsh -NoProfile -File "$no_git_scripts/check-workflow-state.ps1" \
  --registry "$reference_doc_forged_no_git/specs/workflow-state-registry.json" 2>&1)" ||
  fail "reference-doc-forged-no-git PowerShell fixture unexpectedly rejected: $no_git_ps_output"

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

# A re-review (impl-review-precheck --provenance-rereview) necessarily runs
# while design.md already reads `Impl-Review-Status: Passed`, so its reviewers
# record the RAW hash of that state rather than the Pending-normalized one.
# The gate must accept it, or a re-reviewed feature can never pass again no
# matter how many times its review passes.
rereview_ok="$(make_full_fixture rereview-raw-hash)"
rereview_design="$rereview_ok/specs/workflow-state-integrity/design.md"
rereview_contract="$rereview_ok/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json"
rereview_raw="$(shasum -a 256 "$rereview_design" | awk '{print $1}')"
rereview_norm="$(sed 's/^Impl-Review-Status:[[:space:]]*.*/Impl-Review-Status: Pending/' \
  "$rereview_design" | shasum -a 256 | awk '{print $1}')"
# Guard against a vacuous fixture: if the two forms coincided, this case would
# prove nothing about accepting the raw one.
[[ "$rereview_raw" != "$rereview_norm" ]] ||
  fail "rereview fixture is vacuous: raw and normalized design hashes are equal"
jq --arg raw "$rereview_raw" '
  .design_sha256 = $raw |
  (.reviewers[].allowed_input_manifest) |=
    map(if (.path | endswith("/specs/workflow-state-integrity/design.md"))
        then .sha256 = $raw else . end)' \
  "$rereview_contract" > "$rereview_ok/contract.tmp"
mv "$rereview_ok/contract.tmp" "$rereview_contract"
expect_valid "$rereview_ok"

# Non-vacuity of the above: accepting the raw form must NOT mean accepting any
# hash. An edit to design.md's BODY after the contract was recorded matches
# neither form, so the gate must still reject it.
rereview_body="$(make_full_fixture rereview-body-edit)"
rereview_body_design="$rereview_body/specs/workflow-state-integrity/design.md"
rereview_body_contract="$rereview_body/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json"
rereview_body_raw="$(shasum -a 256 "$rereview_body_design" | awk '{print $1}')"
jq --arg raw "$rereview_body_raw" '
  .design_sha256 = $raw |
  (.reviewers[].allowed_input_manifest) |=
    map(if (.path | endswith("/specs/workflow-state-integrity/design.md"))
        then .sha256 = $raw else . end)' \
  "$rereview_body_contract" > "$rereview_body/contract.tmp"
mv "$rereview_body/contract.tmp" "$rereview_body_contract"
printf '\nAn edit made after the reviewers read this document.\n' >> "$rereview_body_design"
expect_rule "$rereview_body" stage-provenance

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

blocked_valid="$(make_full_fixture blocked-valid)"
# Only the first task's Status line is retargeted to Blocked (its Approval
# stays "Approved (sudo ...)" and all review stages stay Passed), so this
# represents a legitimately blocked task in an otherwise fully-reviewed
# feature. The task-stage provenance hash normalizes Status/Approval/
# Task-Review-Status values but hashes the rest of tasks.md verbatim, so the
# substitution below is restricted to that one line (via its line number,
# portable across BSD and GNU sed) rather than appending new prose that
# would otherwise make the recorded task plan hash go stale.
blocked_status_line="$(grep -n '^Status:' \
  "$blocked_valid/specs/workflow-state-integrity/tasks.md" | head -1 | cut -d: -f1)"
sed -i.bak "${blocked_status_line}s/^Status:.*/Status: Blocked/" \
  "$blocked_valid/specs/workflow-state-integrity/tasks.md"
rm "$blocked_valid/specs/workflow-state-integrity/tasks.md.bak"
expect_valid "$blocked_valid"

matrix_index=0
for predecessor in spec impl task; do
  for lifecycle in Approved "In Progress" Blocked "Implementation Complete" Done; do
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

# WFI-021: two independently broken features are BOTH reported in one run
# (cross-feature accumulation), while a feature's own chain still stops at
# its first diagnostic (within-feature short-circuit). Under the pre-change
# exit-at-first behavior the second feature's line was absent, so asserting
# its presence is the non-vacuous regression guard.
accumulate="$TMP/accumulate"
mkdir -p "$accumulate/specs/feat-a" "$accumulate/specs/feat-b"
printf 'x\n' > "$accumulate/specs/feat-a/acceptance-tests.md"
printf 'Spec-Review-Status: Bogus\n' > "$accumulate/specs/feat-b/requirements.md"
printf 'Impl-Review-Status: Pending\n' > "$accumulate/specs/feat-b/design.md"
printf 'x\n' > "$accumulate/specs/feat-b/acceptance-tests.md"
jq '{schema_version, migration_baseline_commit,
     entries: [{"feature":"feat-a","profile":"full"},{"feature":"feat-b","profile":"full"}]}' \
  "$ROOT/specs/workflow-state-registry.json" > "$accumulate/specs/workflow-state-registry.json"
diag_seq() { sed -n 's/^workflow-state: \([^:]*\): \([^:]*\):.*/\1:\2/p'; }
set +e
acc_output="$(bash "$CHECKER" --registry "$accumulate/specs/workflow-state-registry.json" 2>&1)"
acc_status=$?
acc_ps_output="$(pwsh -NoProfile -File \
  "$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.ps1" \
  --registry "$accumulate/specs/workflow-state-registry.json" 2>&1)"
acc_ps_status=$?
set -e
[[ $acc_status -ne 0 && $acc_ps_status -ne 0 ]] || fail "WFI-021 accumulate fixture unexpectedly passed"
for acc_out in "$acc_output" "$acc_ps_output"; do
  [[ "$acc_out" == *"workflow-state: feat-a: stage-input:"* ]] ||
    fail "WFI-021 first feature diagnostic missing: $acc_out"
  [[ "$acc_out" == *"workflow-state: feat-b: stage-status:"* ]] ||
    fail "WFI-021 second feature diagnostic missing (exit-at-first regression): $acc_out"
  [[ "$(printf '%s\n' "$acc_out" | grep -c '^workflow-state: feat-a:')" -eq 1 ]] ||
    fail "WFI-021 within-feature short-circuit lost: $acc_out"
done
[[ "$(printf '%s\n' "$acc_output" | diag_seq)" == "$(printf '%s\n' "$acc_ps_output" | diag_seq)" ]] ||
  fail "WFI-021 twins diverged: Shell=$acc_output PowerShell=$acc_ps_output"

# check-workflow-state's own gate runs BEFORE a review-loop precheck creates
# the round it is trying to open (impl-review-precheck.sh calls this gate at
# its STEP "canonical validation", and only writes precheck-result.json at
# its later STEP 6) -- so nothing on disk can ever prove a round is "open"
# at the one moment this check needs to know it. A tree-only signal (an
# artifact in a later round directory) therefore cannot express the
# distinction that matters. What distinguishes a review-loop precheck
# opening round (attempt, round) from a standalone auditor is not tree
# state but who is asking: the precheck already knows attempt/round as its
# own CLI arguments and says so explicitly via --opening stage:attempt:round.
# A standalone invocation (no --opening) always sees the latest verdict
# govern, exactly as before.

# Standalone (no --opening): BLOCKED latest verdict, nothing beyond it in
# the tree -> must still fail, with the identical diagnostic a non-BLOCKED
# non-PASS verdict gets. This is the check earning its keep: a feature whose
# review genuinely ended BLOCKED must not read as healthy just because
# --opening now exists for a different caller to use.
blocked_no_successor="$(make_full_fixture blocked-no-successor)"
jq '.verdict = "BLOCKED"' \
  "$blocked_no_successor/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json" \
  > "$blocked_no_successor/verdict.tmp"
mv "$blocked_no_successor/verdict.tmp" \
  "$blocked_no_successor/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json"
expect_rule "$blocked_no_successor" stage-provenance

run_opening() {
  # $1=root $2=feature $3=opening-value $4=expect-exit(0|nonzero) $5=label
  local root="$1" feature="$2" opening="$3" expect_ok="$4" label="$5"
  local output status ps_output ps_status
  set +e
  output="$(bash "$CHECKER" --registry "$root/specs/workflow-state-registry.json" \
    --feature "$feature" --opening "$opening" 2>&1)"
  status=$?
  ps_output="$(pwsh -NoProfile -File \
    "$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.ps1" \
    --registry "$root/specs/workflow-state-registry.json" \
    --feature "$feature" --opening "$opening" 2>&1)"
  ps_status=$?
  set -e
  if [[ "$expect_ok" == "0" ]]; then
    [[ $status -eq 0 ]] || fail "$label: Shell unexpectedly failed: $output"
    [[ $ps_status -eq 0 ]] || fail "$label: PowerShell unexpectedly failed: $ps_output"
  else
    [[ $status -ne 0 ]] || fail "$label: Shell unexpectedly passed"
    [[ $ps_status -ne 0 ]] || fail "$label: PowerShell unexpectedly passed"
    [[ "$output" == *": stage-provenance:"* ]] || fail "$label: Shell wrong rule: $output"
    [[ "$(printf '%s\n' "$output" | rule_id)" == "$(printf '%s\n' "$ps_output" | rule_id)" ]] ||
      fail "$label: twins diverged: Shell=$output PowerShell=$ps_output"
  fi
}

# THE case that matters: the gate invoked exactly the way
# impl-review-precheck.sh invokes it when opening a new attempt over a
# BLOCKED predecessor -- with NOTHING yet written under the new attempt (no
# directory, no precheck-result.json, nothing). Only the tree's own history
# (attempt-1/round-2 BLOCKED) plus the caller's --opening claim exist. This
# is the case the file-artifact-based version of this fix could never
# satisfy, because the artifact it looked for cannot exist until after this
# same gate has already passed.
blocked_opening_next_attempt="$(make_full_fixture blocked-opening-next-attempt)"
jq '.verdict = "BLOCKED"' \
  "$blocked_opening_next_attempt/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json" \
  > "$blocked_opening_next_attempt/verdict.tmp"
mv "$blocked_opening_next_attempt/verdict.tmp" \
  "$blocked_opening_next_attempt/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json"
[[ ! -e "$blocked_opening_next_attempt/reports/impl-review/workflow-state-integrity/attempt-2" ]] ||
  fail "blocked-opening-next-attempt fixture precondition not met: attempt-2 already exists"
run_opening "$blocked_opening_next_attempt" workflow-state-integrity impl:2:1 0 \
  "blocked-opening-next-attempt"

# Same shape, but opening the next ROUND of the SAME attempt rather than a
# new attempt -- the adjacency rule covers both continuation shapes.
blocked_opening_next_round="$(make_full_fixture blocked-opening-next-round)"
jq '.verdict = "NEEDS_WORK"' \
  "$blocked_opening_next_round/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json" \
  > "$blocked_opening_next_round/verdict.tmp"
mv "$blocked_opening_next_round/verdict.tmp" \
  "$blocked_opening_next_round/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json"
[[ ! -e "$blocked_opening_next_round/reports/impl-review/workflow-state-integrity/attempt-1/round-3" ]] ||
  fail "blocked-opening-next-round fixture precondition not met: round-3 already exists"
run_opening "$blocked_opening_next_round" workflow-state-integrity impl:1:3 0 \
  "blocked-opening-next-round"

# Non-vacuity: --opening cannot be used to wave away a BLOCKED verdict "at a
# distance". The ONLY value this function will ever accept is the true next
# slot; skipping ahead to an arbitrary attempt, or an arbitrary round within
# the same attempt, must still fail exactly like the no-successor case.
blocked_opening_arbitrary="$(make_full_fixture blocked-opening-arbitrary)"
jq '.verdict = "BLOCKED"' \
  "$blocked_opening_arbitrary/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json" \
  > "$blocked_opening_arbitrary/verdict.tmp"
mv "$blocked_opening_arbitrary/verdict.tmp" \
  "$blocked_opening_arbitrary/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json"
run_opening "$blocked_opening_arbitrary" workflow-state-integrity impl:9:1 1 \
  "blocked-opening-arbitrary-attempt-rejected"
run_opening "$blocked_opening_arbitrary" workflow-state-integrity impl:1:5 1 \
  "blocked-opening-arbitrary-round-rejected"

# Non-vacuity: --opening is scoped to the single stage named in it. Claiming
# to open the SPEC stage's next round must not exempt the IMPL stage's own
# BLOCKED verdict -- the exemption cannot leak across stages.
blocked_opening_wrong_stage="$(make_full_fixture blocked-opening-wrong-stage)"
jq '.verdict = "BLOCKED"' \
  "$blocked_opening_wrong_stage/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json" \
  > "$blocked_opening_wrong_stage/verdict.tmp"
mv "$blocked_opening_wrong_stage/verdict.tmp" \
  "$blocked_opening_wrong_stage/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json"
run_opening "$blocked_opening_wrong_stage" workflow-state-integrity spec:2:1 1 \
  "blocked-opening-wrong-stage"

# A PASS latest verdict is unaffected by --opening being present: the
# "valid" fixture's own genuinely-PASS impl verdict never even reaches the
# branch that consults it.
run_opening "$valid" workflow-state-integrity impl:2:1 0 "valid-with-opening-flag-present"

# --opening is only meaningful pinned to one feature; without --feature it
# must be rejected as a usage error on both runtimes (not silently ignored,
# which would make it a blanket, registry-wide exemption).
set +e
no_feature_output="$(bash "$CHECKER" --registry "$valid/specs/workflow-state-registry.json" \
  --opening impl:2:1 2>&1)"
no_feature_status=$?
no_feature_ps_output="$(pwsh -NoProfile -File \
  "$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.ps1" \
  --registry "$valid/specs/workflow-state-registry.json" --opening impl:2:1 2>&1)"
no_feature_ps_status=$?
set -e
[[ $no_feature_status -ne 0 && $no_feature_ps_status -ne 0 ]] ||
  fail "--opening without --feature unexpectedly succeeded"
[[ "$no_feature_output" == *": cli-usage:"* ]] || fail "--opening without --feature: wrong rule: $no_feature_output"
[[ "$(printf '%s\n' "$no_feature_output" | rule_id)" == "$(printf '%s\n' "$no_feature_ps_output" | rule_id)" ]] ||
  fail "--opening without --feature twins diverged: Shell=$no_feature_output PowerShell=$no_feature_ps_output"

# A malformed --opening value (unknown stage, non-numeric attempt/round) is
# a usage error, not a silent no-op.
set +e
bad_opening_output="$(bash "$CHECKER" --registry "$valid/specs/workflow-state-registry.json" \
  --feature workflow-state-integrity --opening "bogus" 2>&1)"
bad_opening_status=$?
bad_opening_ps_output="$(pwsh -NoProfile -File \
  "$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.ps1" \
  --registry "$valid/specs/workflow-state-registry.json" \
  --feature workflow-state-integrity --opening "bogus" 2>&1)"
bad_opening_ps_status=$?
set -e
[[ $bad_opening_status -ne 0 && $bad_opening_ps_status -ne 0 ]] ||
  fail "malformed --opening value unexpectedly succeeded"
[[ "$bad_opening_output" == *": cli-usage:"* ]] || fail "malformed --opening: wrong rule: $bad_opening_output"

# --- Downstream input-hash staleness tolerance under --opening ---
#
# epic-196's deadlock: task-review-precheck's --provenance-rereview requires
# the latest IMPL verdict to be PASS (it is BLOCKED), so task re-review
# cannot open; impl-review-precheck's --opening correctly exempts that
# BLOCKED verdict (0732ec97), but the already-Passed TASK stage's OWN
# reviewed-hash pins (e.g. tasks.md, design.md) have since gone stale,
# because the human-approved amendment wave that will let impl re-pass
# moved the very documents task pinned when it last passed. That staleness
# is the recovery's expected intermediate state, not corruption -- impl
# re-passes first, task then re-binds against the amended documents. These
# fixtures cover: the deadlock case itself; that a standalone (no
# --opening) caller is completely unaffected; that the tolerance is
# strictly diagnostic-scoped (a genuinely missing input, or a forbidden
# reviewer-report path, still fails even downstream); and that the
# tolerance is strictly stage-scoped (opening task grants nothing to
# spec, which is upstream of task in walk order).

# THE deadlock case: impl's latest verdict is BLOCKED (exempted by the
# pre-existing --opening mechanism, unchanged), and the already-Passed task
# stage's own tasks.md pin has gone stale (its own reviewed-hash pin, the
# same class of diagnostic "task plan hash is stale" -- tasks.md carries no
# later "omit" check the way design.md/layer specs do, so this is a clean,
# unambiguous demonstration of the tolerance without also tripping the
# separately-not-tolerated manifest-existence checks). Opening impl over
# this must now succeed.
deadlock_recovery="$(make_full_fixture deadlock-recovery)"
jq '.verdict = "BLOCKED"' \
  "$deadlock_recovery/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json" \
  > "$deadlock_recovery/verdict.tmp"
mv "$deadlock_recovery/verdict.tmp" \
  "$deadlock_recovery/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json"
printf '\n<!-- amendment wave: tasks.md updated after task review -->\n' \
  >> "$deadlock_recovery/specs/workflow-state-integrity/tasks.md"

run_opening "$deadlock_recovery" workflow-state-integrity impl:2:1 0 \
  "deadlock-recovery-opening-impl-tolerates-stale-task-pin"

# Same fixture, standalone: no --opening means no exemption of any kind --
# the checker must still fail, and specifically on the impl verdict itself
# (the very first stage-provenance check reached, since spec is sound and
# impl is validated before task), exactly as it did before this change.
set +e
deadlock_standalone_output="$(bash "$CHECKER" \
  --registry "$deadlock_recovery/specs/workflow-state-registry.json" 2>&1)"
deadlock_standalone_status=$?
deadlock_standalone_ps_output="$(pwsh -NoProfile -File \
  "$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.ps1" \
  --registry "$deadlock_recovery/specs/workflow-state-registry.json" 2>&1)"
deadlock_standalone_ps_status=$?
set -e
[[ $deadlock_standalone_status -ne 0 ]] || fail "deadlock-recovery standalone Shell unexpectedly passed"
[[ $deadlock_standalone_ps_status -ne 0 ]] || fail "deadlock-recovery standalone PowerShell unexpectedly passed"
[[ "$deadlock_standalone_output" == *"integrated verdict is not a valid PASS"* ]] ||
  fail "deadlock-recovery standalone: expected the impl verdict diagnostic unchanged, got: $deadlock_standalone_output"
[[ "$(printf '%s\n' "$deadlock_standalone_output" | rule_id)" == \
   "$(printf '%s\n' "$deadlock_standalone_ps_output" | rule_id)" ]] ||
  fail "deadlock-recovery standalone twins diverged: Shell=$deadlock_standalone_output PowerShell=$deadlock_standalone_ps_output"

# Opening impl over the same BLOCKED verdict, but the task stage's reviewer
# record is now missing an input file it declared (not stale -- genuinely
# absent). The tolerance is scoped to staleness diagnostics only; a missing
# input must still fail even though it surfaces inside the downstream
# (task) stage's own validation while impl is being opened.
deadlock_missing_input="$(make_full_fixture deadlock-missing-input)"
jq '.verdict = "BLOCKED"' \
  "$deadlock_missing_input/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json" \
  > "$deadlock_missing_input/verdict.tmp"
mv "$deadlock_missing_input/verdict.tmp" \
  "$deadlock_missing_input/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json"
rm "$deadlock_missing_input/reports/task-review/workflow-state-integrity/attempt-4/round-2/dependency-graph.json"

set +e
deadlock_missing_output="$(bash "$CHECKER" \
  --registry "$deadlock_missing_input/specs/workflow-state-registry.json" \
  --feature workflow-state-integrity --opening impl:2:1 2>&1)"
deadlock_missing_status=$?
deadlock_missing_ps_output="$(pwsh -NoProfile -File \
  "$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.ps1" \
  --registry "$deadlock_missing_input/specs/workflow-state-registry.json" \
  --feature workflow-state-integrity --opening impl:2:1 2>&1)"
deadlock_missing_ps_status=$?
set -e
[[ $deadlock_missing_status -ne 0 ]] || fail "deadlock-missing-input Shell unexpectedly passed under --opening impl:2:1"
[[ $deadlock_missing_ps_status -ne 0 ]] || fail "deadlock-missing-input PowerShell unexpectedly passed under --opening impl:2:1"
[[ "$deadlock_missing_output" == *"missing"* ]] ||
  fail "deadlock-missing-input: expected a missing-input diagnostic, got: $deadlock_missing_output"
[[ "$(printf '%s\n' "$deadlock_missing_output" | rule_id)" == \
   "$(printf '%s\n' "$deadlock_missing_ps_output" | rule_id)" ]] ||
  fail "deadlock-missing-input twins diverged: Shell=$deadlock_missing_output PowerShell=$deadlock_missing_ps_output"

# Opening impl over the same BLOCKED verdict, but the task stage's contract
# now carries a forbidden manifest entry -- a raw reviewer report path,
# which the canonical-path allowlist never permits for any role or stage.
# Forbidden paths are a shape violation, not staleness, and must still fail
# even downstream while impl is being opened.
#
# The identical entry is added to BOTH the contract's manifest AND
# reviewer-a.json's own manifest (kept in sync) so the manifest-superset
# consistency check (contract manifest subset of reviewer's own) still
# passes and does not itself independently fail first -- isolating the
# assertion to the canonical-path allowlist specifically, rather than
# "some stage-provenance diagnostic or other fires."
deadlock_forbidden_path="$(make_full_fixture deadlock-forbidden-path)"
jq '.verdict = "BLOCKED"' \
  "$deadlock_forbidden_path/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json" \
  > "$deadlock_forbidden_path/verdict.tmp"
mv "$deadlock_forbidden_path/verdict.tmp" \
  "$deadlock_forbidden_path/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json"
forbidden_entry='{
  "path": "reports/task-review/workflow-state-integrity/attempt-4/round-2/reviewer-a.json",
  "sha256": "0000000000000000000000000000000000000000000000000000000000000"
}'
forbidden_contract="$deadlock_forbidden_path/reports/task-review/workflow-state-integrity/attempt-4/round-2/task-review-contract.json"
jq --argjson entry "$forbidden_entry" '.reviewers[0].allowed_input_manifest += [$entry]' \
  "$forbidden_contract" > "$deadlock_forbidden_path/contract.tmp"
mv "$deadlock_forbidden_path/contract.tmp" "$forbidden_contract"
forbidden_reviewer_a="$deadlock_forbidden_path/reports/task-review/workflow-state-integrity/attempt-4/round-2/reviewer-a.json"
jq --argjson entry "$forbidden_entry" '.manifest += [$entry]' \
  "$forbidden_reviewer_a" > "$deadlock_forbidden_path/reviewer-a.tmp"
mv "$deadlock_forbidden_path/reviewer-a.tmp" "$forbidden_reviewer_a"

run_opening "$deadlock_forbidden_path" workflow-state-integrity impl:2:1 1 \
  "deadlock-forbidden-reviewer-report-path-still-fails"

# Opening TASK (not impl) with a stale SPEC-stage pin. Spec is upstream of
# task in walk order, so opening task must grant it nothing: the tolerance
# is strictly downstream-of-S, never upstream, regardless of how the
# opened slot itself validates. attempt-5/round-1 is task's own genuine
# structurally-next slot here (best_attempt=4, best_round=2), so this
# proves the upstream refusal is not just "the --opening slot was
# rejected" -- the slot IS valid, and spec still fails anyway.
#
# Mutating investigation.md rather than requirements.md deliberately: it is
# the one spec-manifest entry checked ONLY by the generic per-entry
# staleness loop, with no separate top-level-field or manifest-existence
# check standing behind it (unlike requirements.md/acceptance-tests.md,
# which have a second, NOT-tolerated "contract hashes are stale" check that
# would independently catch a stale pin and mask a broken downstream-scope
# guard as a false-negative-proof "still fails").
deadlock_upstream_stale="$(make_full_fixture deadlock-upstream-stale)"
printf '\n<!-- amendment wave: investigation.md updated after spec review -->\n' \
  >> "$deadlock_upstream_stale/specs/workflow-state-integrity/investigation.md"

run_opening "$deadlock_upstream_stale" workflow-state-integrity task:5:1 1 \
  "deadlock-upstream-stale-spec-pin-not-tolerated-by-opening-task"


printf 'ok: Shell workflow-state validation fixtures passed\n'
