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

# ── WFI-030: traceability delivery-status normalization ──────────────────────
# The task-stage binding hashes traceability.md whole-file. Its per-requirement
# delivery-status cell is the one field the workflow is designed to advance as
# tasks complete, so a change confined to that cell -- and only over the closed
# lifecycle vocabulary the state registry pins -- must be absorbed the way
# tasks.md's Status: header already is. Every other byte stays bound.
#
# The fixture source carries no layer_sha256, so the task-stage traceability
# block at check-workflow-state.sh:675 would be skipped entirely. These cases
# build the full-profile task state the block requires, which is why they do
# more setup than the fixtures above.
wfi030_sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }

# Rewrite every REQ row's delivery-status cell to $2, over the closed vocabulary
# only. Mirrors the normalization under test, so the fixture can be put into the
# authoring-time state the precheck really records.
wfi030_set_status() {
  LC_ALL=C sed -E -i.bak \
    "s/^(\| REQ-.*\|)([[:space:]]*)(Planned|In Progress|Implementation Complete|Done|Blocked)([[:space:]]*\|[[:space:]]*)\$/\\1\\2$2\\4/" "$1"
  rm -f "$1.bak"
}

wfi030_fixture() {
  local root round specs trace layer extra layers pairs
  root="$(make_full_fixture "$1")"
  round="$(latest_task_round_dir "$root")"
  specs="$root/specs/workflow-state-integrity"
  trace="$specs/traceability.md"
  # Authoring-time state: every delivery-status cell at the default. This is the
  # state a real precheck captures, and the property the tolerance relies on --
  # a matrix recorded with live statuses does not gain it.
  wfi030_set_status "$trace" Planned
  for layer in ux-spec.md frontend-spec.md infra-spec.md security-spec.md; do
    printf '# %s\n\nWFI-030 fixture layer spec.\n' "${layer%.md}" > "$specs/$layer"
  done
  layers="$({ for layer in ux-spec.md frontend-spec.md infra-spec.md security-spec.md; do
      printf '%s\t%s\n' "$layer" "$(wfi030_sha "$specs/$layer")"
    done; } | jq -R -s -c 'split("\n")|map(select(length>0)|split("\t")|{(.[0]):.[1]})|add')"
  # The precheck must be rewritten before the manifest is, because the manifest
  # also binds the precheck file's own hash.
  jq --arg t "$(wfi030_sha "$trace")" --arg d "$(wfi030_sha "$specs/design.md")" --argjson l "$layers" \
    '.traceability_sha256=$t | .design_sha256=$d | .layer_sha256=$l' \
    "$round/precheck-result.json" > "$round/precheck-result.json.new"
  mv "$round/precheck-result.json.new" "$round/precheck-result.json"
  pairs="$({
    printf 'specs/workflow-state-integrity/traceability.md\t%s\n' "$(wfi030_sha "$trace")"
    printf 'specs/workflow-state-integrity/design.md\t%s\n' "$(wfi030_sha "$specs/design.md")"
    for layer in ux-spec.md frontend-spec.md infra-spec.md security-spec.md; do
      printf 'specs/workflow-state-integrity/%s\t%s\n' "$layer" "$(wfi030_sha "$specs/$layer")"
    done
    printf '%s/precheck-result.json\t%s\n' "${round#"$root"/}" "$(wfi030_sha "$round/precheck-result.json")"
  })"
  extra="$(printf '%s' "$pairs" | jq -R -s -c 'split("\n")|map(select(length>0)|split("\t")|{path:.[0],sha256:.[1]})')"
  # Upsert, not append: check-workflow-state.sh:473 rejects a manifest with any
  # duplicate path, and the source contract already lists traceability.md.
  jq --arg t "$(wfi030_sha "$trace")" --arg d "$(wfi030_sha "$specs/design.md")" \
    --argjson l "$layers" --argjson extra "$extra" \
    '.traceability_sha256=$t | .design_sha256=$d | .layer_sha256=$l
     | ($extra | map({key: .path, value: .sha256}) | from_entries) as $ov
     | .reviewers |= map(
         (.allowed_input_manifest // []) as $m
         | .allowed_input_manifest = (
             ($m | map(if $ov[.path] then .sha256 = $ov[.path] else . end))
             + ($extra | map(. as $e | select(([$m[].path] | index($e.path)) == null)))))' \
    "$round/task-review-contract.json" > "$round/task-review-contract.json.new"
  mv "$round/task-review-contract.json.new" "$round/task-review-contract.json"
  # Each reviewer's own recorded manifest must cover everything the contract
  # claims it reviewed, so the same entries are upserted there.
  local reviewer
  for reviewer in reviewer-a reviewer-b; do
    [[ -f "$round/$reviewer.json" ]] || continue
    # reviewer-a records .manifest as a bare array; reviewer-b records
    # .manifest.allowed_inputs inside an object. Handle both shapes.
    jq --argjson extra "$extra" \
      'def upsert($ov; $m):
         (($m // []) | map(if $ov[.path] then .sha256 = $ov[.path] else . end))
         + ($extra | map(. as $e | select(([($m // [])[].path] | index($e.path)) == null)));
       ($extra | map({key: .path, value: .sha256}) | from_entries) as $ov
       | if (.manifest | type) == "object"
         then .manifest.allowed_inputs = upsert($ov; .manifest.allowed_inputs)
         else .manifest = upsert($ov; .manifest) end' \
      "$round/$reviewer.json" > "$round/$reviewer.json.new"
    mv "$round/$reviewer.json.new" "$round/$reviewer.json"
  done
  printf '%s\n' "$root"
}

# Baseline: the task-stage traceability block is now reached (layer_sha256 is
# populated) and the untouched matrix validates on both twins. Without this the
# three cases below could pass vacuously by never entering the block.
wfi030_base="$(wfi030_fixture wfi030-base)"
expect_valid "$wfi030_base"

# A delivery-status transition inside the closed vocabulary is absorbed. This is
# the case the WFI exists to create; before the change it failed with
# stage-provenance on both twins.
wfi030_flip="$(wfi030_fixture wfi030-flip)"
wfi030_set_status "$wfi030_flip/specs/workflow-state-integrity/traceability.md" Done
expect_valid "$wfi030_flip"

# A value outside the closed vocabulary is a body edit, not a lifecycle
# transition, and stays bound. Without this case the tolerance would read as
# "the last cell is unbound", which is not what was implemented.
wfi030_outside="$(wfi030_fixture wfi030-outside)"
LC_ALL=C sed -E -i.bak 's/^(\| REQ-.*\|)([[:space:]]*)Planned([[:space:]]*\|[[:space:]]*)$/\1\2Delivered\3/' \
  "$wfi030_outside/specs/workflow-state-integrity/traceability.md"
rm -f "$wfi030_outside/specs/workflow-state-integrity/traceability.md.bak"
expect_rule "$wfi030_outside" stage-provenance

# Every non-status byte stays bound: an edit to any other cell still fails. This
# is the anti-Goodhart control -- coverage of the status column must not have
# been bought by unbinding the row.
wfi030_body="$(wfi030_fixture wfi030-body)"
printf '\n<!-- WFI-030 body edit outside every delivery-status cell -->\n' \
  >> "$wfi030_body/specs/workflow-state-integrity/traceability.md"
expect_rule "$wfi030_body" stage-provenance

printf 'ok: Shell workflow-state validation fixtures passed\n'
