#!/usr/bin/env bash
# T-006: supported host entry points produce the same semantic precheck fields.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FEATURE="downstream-precheck-parity"
SPEC="$ROOT/specs/$FEATURE"
SPEC_REPORT="$ROOT/reports/spec-review/$FEATURE"
IMPL_REPORT="$ROOT/reports/impl-review/$FEATURE"
TASK_REPORT="$ROOT/reports/task-review/$FEATURE"
WORK="$(mktemp -d)"
cleanup() { rm -rf "$SPEC" "$SPEC_REPORT" "$IMPL_REPORT" "$TASK_REPORT" "$WORK"; }
trap cleanup EXIT
fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }
semantic() { jq -S "$1" "$2"; }
write_pass_artifacts() {
  local stage="$1" dir="$2" req acc design calibration
  req="$(shasum -a 256 "$SPEC/requirements.md" | awk '{print $1}')"; acc="$(shasum -a 256 "$SPEC/acceptance-tests.md" | awk '{print $1}')"; design="$(shasum -a 256 "$SPEC/design.md" | awk '{print $1}')"
  calibration="$(shasum -a 256 "$ROOT/plugins/sdd-review-loop/references/reviewer-calibration.md" | awk '{print $1}')"
  jq -n --arg stage "$stage" --arg feature "$FEATURE" --arg req "$req" --arg acc "$acc" --arg design "$design" 'if $stage == "spec" then {schema:"spec-review-integrated-verdict/v1",stage:"spec",feature:$feature,attempt:1,round:1,reviewer_a_run_id:"run-a",reviewer_b_run_id:"run-b",reviewer_a_host_session_id:"session-a",reviewer_b_host_session_id:"session-b",finding_counts:{critical:0,major:0,minor:0},verdict:"PASS",warningCount:0} else {schema:"integrated-verdict/v1",stage:$stage,feature:$feature,attempt:1,round:1,run_id:($stage+"-orchestrator"),verdict:"PASS"} end' > "$dir/integrated-verdict.json"
  jq -n --arg stage "$stage" --arg feature "$FEATURE" --arg req "$req" --arg acc "$acc" --arg design "$design" --arg calibration "$calibration" '{schema:($stage+"-review-contract/v1"),stage:$stage,feature:$feature,attempt:1,round:1,run_id:($stage+"-orchestrator"),verdict:"PASS",reviewers:[{role:($stage+"-reviewer-a"),run_id:"run-a",host_session_id:"session-a",allowed_input_manifest:[{path:("specs/"+$feature+"/requirements.md"),sha256:$req},{path:("specs/"+$feature+"/acceptance-tests.md"),sha256:$acc},{path:("specs/"+$feature+"/design.md"),sha256:$design}]},{role:($stage+"-reviewer-b"),run_id:"run-b",host_session_id:"session-b",allowed_input_manifest:[{path:("specs/"+$feature+"/requirements.md"),sha256:$req},{path:("specs/"+$feature+"/acceptance-tests.md"),sha256:$acc},{path:("specs/"+$feature+"/design.md"),sha256:$design}]}]} | if $stage == "impl" then .reviewers |= map(.allowed_input_manifest += [{path:"plugins/sdd-review-loop/references/reviewer-calibration.md",sha256:$calibration}]) else . end' > "$dir/$stage-review-contract.json"
}

rm -rf "$SPEC" "$SPEC_REPORT" "$IMPL_REPORT" "$TASK_REPORT"
mkdir -p "$SPEC" "$SPEC_REPORT/attempt-1/round-1"
printf 'Spec-Review-Status: Passed\n# UTF-8: 仕様\n' > "$SPEC/requirements.md"
printf 'Impl-Review-Status: Pending\n# UTF-8: 実装\n' > "$SPEC/design.md"
printf '# Acceptance\n' > "$SPEC/acceptance-tests.md"
printf '## T-001 First\nRisk: low\nRisk Rationale: fixture\nRequired Workflow: test-after\n### Blockers\nNone\n\n## T-002 Second\nRisk: low\nRisk Rationale: fixture\nRequired Workflow: test-after\n### Blockers\nT-001\n' > "$SPEC/tasks.md"
write_pass_artifacts spec "$SPEC_REPORT/attempt-1/round-1"

jq '.attempt=2 | .round=3 | .reviewer_a_run_id="contradictory-a-run" | .reviewer_b_run_id="contradictory-b-run" | .reviewer_a_host_session_id="contradictory-a-session" | .reviewer_b_host_session_id="contradictory-b-session"' "$SPEC_REPORT/attempt-1/round-1/integrated-verdict.json" > "$WORK/contradictory-spec-verdict.json"
mv "$WORK/contradictory-spec-verdict.json" "$SPEC_REPORT/attempt-1/round-1/integrated-verdict.json"
if (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1) >/dev/null 2>&1; then fail 'impl shell accepted contradictory predecessor artifacts'; fi
[[ ! -e "$IMPL_REPORT" ]] || fail 'impl shell wrote evidence for contradictory predecessor artifacts'
if pwsh -NoProfile -File "$ROOT/plugins/sdd-review-loop/scripts/impl-review-precheck.ps1" -Feature "$FEATURE" -Attempt 1 -Round 1 >/dev/null 2>&1; then fail 'impl PowerShell accepted contradictory predecessor artifacts'; fi
[[ ! -e "$IMPL_REPORT" ]] || fail 'impl PowerShell wrote evidence for contradictory predecessor artifacts'
write_pass_artifacts spec "$SPEC_REPORT/attempt-1/round-1"

(cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1) >/dev/null
semantic '{schema,feature,attempt,round,impl_review_status_field,legacy_design,design_req_drift,design_sha256,requirements_sha256,acceptance_sha256}' "$IMPL_REPORT/attempt-1/round-1/precheck-result.json" > "$WORK/impl-sh.json"
rm -rf "$IMPL_REPORT"
pwsh -NoProfile -File "$ROOT/plugins/sdd-review-loop/scripts/impl-review-precheck.ps1" -Feature "$FEATURE" -Attempt 1 -Round 1 >/dev/null
semantic '{schema,feature,attempt,round,impl_review_status_field,legacy_design,design_req_drift,design_sha256,requirements_sha256,acceptance_sha256}' "$IMPL_REPORT/attempt-1/round-1/precheck-result.json" > "$WORK/impl-ps.json"
cmp -s "$WORK/impl-sh.json" "$WORK/impl-ps.json" || fail 'impl shell and PowerShell semantic output differs'

printf 'Impl-Review-Status: Passed\n# UTF-8: 実装\n' > "$SPEC/design.md"
write_pass_artifacts impl "$IMPL_REPORT/attempt-1/round-1"
jq '.run_id="contradictory-impl-run"' "$IMPL_REPORT/attempt-1/round-1/integrated-verdict.json" > "$WORK/contradictory-impl-verdict.json"
mv "$WORK/contradictory-impl-verdict.json" "$IMPL_REPORT/attempt-1/round-1/integrated-verdict.json"
if (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 1 1) >/dev/null 2>&1; then fail 'task shell accepted contradictory predecessor artifacts'; fi
[[ ! -e "$TASK_REPORT" ]] || fail 'task shell wrote evidence for contradictory predecessor artifacts'
if pwsh -NoProfile -File "$ROOT/plugins/sdd-review-loop/scripts/task-review-precheck.ps1" -Feature "$FEATURE" -Attempt 1 -Round 1 >/dev/null 2>&1; then fail 'task PowerShell accepted contradictory predecessor artifacts'; fi
[[ ! -e "$TASK_REPORT" ]] || fail 'task PowerShell wrote evidence for contradictory predecessor artifacts'
write_pass_artifacts impl "$IMPL_REPORT/attempt-1/round-1"
(cd "$ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 1 1) >/dev/null
semantic '{schema,feature,attempt,round,workflow_match_precheck,blockers_format_valid,tasks_sha256,requirements_sha256,acceptance_sha256}' "$TASK_REPORT/attempt-1/round-1/precheck-result.json" > "$WORK/task-sh.json"
semantic '{schema,feature,attempt,round,nodes,edges}' "$TASK_REPORT/attempt-1/round-1/dependency-graph.json" > "$WORK/graph-sh.json"
rm -rf "$TASK_REPORT"
pwsh -NoProfile -File "$ROOT/plugins/sdd-review-loop/scripts/task-review-precheck.ps1" -Feature "$FEATURE" -Attempt 1 -Round 1 >/dev/null
semantic '{schema,feature,attempt,round,workflow_match_precheck,blockers_format_valid,tasks_sha256,requirements_sha256,acceptance_sha256}' "$TASK_REPORT/attempt-1/round-1/precheck-result.json" > "$WORK/task-ps.json"
semantic '{schema,feature,attempt,round,nodes,edges}' "$TASK_REPORT/attempt-1/round-1/dependency-graph.json" > "$WORK/graph-ps.json"
cmp -s "$WORK/task-sh.json" "$WORK/task-ps.json" || fail 'task shell and PowerShell semantic output differs'
cmp -s "$WORK/graph-sh.json" "$WORK/graph-ps.json" || fail 'dependency graph shell and PowerShell semantic output differs'

printf 'ok: downstream review precheck shell and PowerShell outputs have equivalent semantics\n'
