#!/usr/bin/env bash
# T-006: downstream review gates must fail closed before creating evidence.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FEATURE="downstream-precheck-fixture"
SPEC_DIR="$ROOT/specs/$FEATURE"
SPEC_REPORT="$ROOT/reports/spec-review/$FEATURE"
IMPL_REPORT="$ROOT/reports/impl-review/$FEATURE"
TASK_REPORT="$ROOT/reports/task-review/$FEATURE"
REGISTRY="$ROOT/specs/workflow-state-registry.json"
REGISTRY_BACKUP="$(mktemp)"
cp "$REGISTRY" "$REGISTRY_BACKUP"

cleanup() {
  cp "$REGISTRY_BACKUP" "$REGISTRY"
  rm -f "$REGISTRY_BACKUP"
  rm -rf "$SPEC_DIR" "$SPEC_REPORT" "$IMPL_REPORT" "$TASK_REPORT"
}
trap cleanup EXIT

fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }
for precheck in impl-review-precheck.sh task-review-precheck.sh; do
  grep -q 'check-workflow-state.sh.*--feature' \
    "$ROOT/plugins/sdd-review-loop/scripts/$precheck" ||
    fail "$precheck must invoke scoped workflow-state validation"
done
jq --arg feature "$FEATURE" \
  '.entries += [{feature:$feature,profile:"lite"}]' "$REGISTRY" > "$REGISTRY.tmp"
mv "$REGISTRY.tmp" "$REGISTRY"
write_inputs() {
  mkdir -p "$SPEC_DIR"
  cat > "$SPEC_DIR/requirements.md" <<'EOF'
Spec-Review-Status: Pending
EOF
  cat > "$SPEC_DIR/design.md" <<'EOF'
Impl-Review-Status: Pending
EOF
  cat > "$SPEC_DIR/acceptance-tests.md" <<'EOF'
# Acceptance
EOF
  cat > "$SPEC_DIR/tasks.md" <<'EOF'
Task-Review-Status: Pending

## T-001 First
Risk: low
Risk Rationale: fixture
Required Workflow: test-after
### Blockers
None

## T-002 Second
Risk: low
Risk Rationale: fixture
Required Workflow: test-after
### Blockers
T-001
EOF
}
write_spec_pass() {
  sed -i.bak 's/Spec-Review-Status: Pending/Spec-Review-Status: Passed/' "$SPEC_DIR/requirements.md"
  rm -f "$SPEC_DIR"/*.bak
  mkdir -p "$SPEC_REPORT/attempt-1/round-1"
  write_pass_artifacts spec "$SPEC_REPORT/attempt-1/round-1"
}
write_impl_pass() {
  sed -i.bak 's/Impl-Review-Status: Pending/Impl-Review-Status: Passed/' "$SPEC_DIR/design.md"
  rm -f "$SPEC_DIR"/*.bak
  mkdir -p "$IMPL_REPORT/attempt-1/round-1"
  write_pass_artifacts impl "$IMPL_REPORT/attempt-1/round-1"
}
write_pass_artifacts() {
  local stage="$1" directory="$2" attempt="${3:-1}" req acc design calibration precheck summary
  req="$(shasum -a 256 "$SPEC_DIR/requirements.md" | awk '{print $1}')"
  acc="$(shasum -a 256 "$SPEC_DIR/acceptance-tests.md" | awk '{print $1}')"
  design="$(shasum -a 256 "$SPEC_DIR/design.md" | awk '{print $1}')"
  if [[ "$stage" == spec ]]; then
    calibration="$(shasum -a 256 "$ROOT/plugins/sdd-review-loop/references/spec-review-calibration.md" | awk '{print $1}')"
  else
    calibration="$(shasum -a 256 "$ROOT/plugins/sdd-review-loop/references/reviewer-calibration.md" | awk '{print $1}')"
  fi
  printf '{}\n' > "$directory/precheck-result.json"
  printf '{}\n' > "$directory/integrated-summary.json"
  precheck="$(shasum -a 256 "$directory/precheck-result.json" | awk '{print $1}')"
  summary="$(shasum -a 256 "$directory/integrated-summary.json" | awk '{print $1}')"
  jq -n --arg stage "$stage" --arg feature "$FEATURE" --argjson attempt "$attempt" --arg req "$req" --arg acc "$acc" --arg design "$design" \
    'if $stage == "spec" then {schema:"spec-review-integrated-verdict/v1",stage:"spec",feature:$feature,attempt:$attempt,round:1,reviewer_a_run_id:"run-a",reviewer_b_run_id:"run-b",reviewer_a_host_session_id:"session-a",reviewer_b_host_session_id:"session-b",finding_counts:{critical:0,major:0,minor:0},verdict:"PASS",warningCount:0} else {schema:"integrated-verdict/v1",stage:$stage,feature:$feature,attempt:$attempt,round:1,run_id:($stage+"-orchestrator"),verdict:"PASS"} end' > "$directory/integrated-verdict.json"
  jq -n --arg stage "$stage" --arg feature "$FEATURE" --argjson attempt "$attempt" --arg req "$req" --arg acc "$acc" --arg design "$design" --arg calibration "$calibration" --arg precheck "$precheck" --arg summary "$summary" \
    '{schema:($stage+"-review-contract/v1"),stage:$stage,feature:$feature,attempt:$attempt,round:1,run_id:($stage+"-orchestrator"),verdict:"PASS",requirements_sha256:$req,acceptance_sha256:$acc,design_sha256:$design,reviewers:[{role:($stage+"-reviewer-a"),run_id:"run-a",host_session_id:"session-a",allowed_input_manifest:[{path:("specs/"+$feature+"/requirements.md"),sha256:$req},{path:("specs/"+$feature+"/acceptance-tests.md"),sha256:$acc}]},{role:($stage+"-reviewer-b"),run_id:"run-b",host_session_id:"session-b",allowed_input_manifest:[{path:("specs/"+$feature+"/requirements.md"),sha256:$req},{path:("specs/"+$feature+"/acceptance-tests.md"),sha256:$acc}]}]}
    | if $stage == "impl" then .reviewers |= map(.allowed_input_manifest += [{path:("specs/"+$feature+"/design.md"),sha256:$design}]) else . end
    | .reviewers |= map(.allowed_input_manifest += [{path:(if $stage == "spec" then "plugins/sdd-review-loop/references/spec-review-calibration.md" else "plugins/sdd-review-loop/references/reviewer-calibration.md" end),sha256:$calibration},{path:("reports/"+$stage+"-review/"+$feature+"/attempt-"+($attempt|tostring)+"/round-1/precheck-result.json"),sha256:$precheck}])
    | .reviewers[1].allowed_input_manifest += [{path:("reports/"+$stage+"-review/"+$feature+"/attempt-"+($attempt|tostring)+"/round-1/integrated-summary.json"),sha256:$summary}]' > "$directory/$stage-review-contract.json"
}
expect_denied_without_evidence() {
  local label="$1" report="$2"; shift 2
  rm -rf "$report"
  if (cd "$ROOT" && "$@") >/dev/null 2>&1; then fail "$label should fail"; fi
  [[ ! -e "$report" ]] || fail "$label must not create report evidence"
}

write_inputs
expect_denied_without_evidence "impl missing spec status" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1
expect_denied_without_evidence "task missing predecessor statuses" "$TASK_REPORT" \
  bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 1 1

write_spec_pass
rm -rf "$SPEC_REPORT"
expect_denied_without_evidence "impl missing persisted spec PASS" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1
write_spec_pass
rm -f "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json"
expect_denied_without_evidence "impl missing complete spec contract" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1
write_spec_pass
printf '# stale predecessor input\n' >> "$SPEC_DIR/requirements.md"
expect_denied_without_evidence "impl stale spec contract hash" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1
sed -i.bak '$d' "$SPEC_DIR/requirements.md"; rm -f "$SPEC_DIR/requirements.md.bak"
write_spec_pass
jq '.attempt=2 | .round=3 | .reviewer_a_run_id="contradictory-a-run" | .reviewer_b_run_id="contradictory-b-run" | .reviewer_a_host_session_id="contradictory-a-session" | .reviewer_b_host_session_id="contradictory-b-session"' "$SPEC_REPORT/attempt-1/round-1/integrated-verdict.json" > "$SPEC_REPORT/attempt-1/round-1/integrated-verdict.tmp" && mv "$SPEC_REPORT/attempt-1/round-1/integrated-verdict.tmp" "$SPEC_REPORT/attempt-1/round-1/integrated-verdict.json"
expect_denied_without_evidence "impl contradictory spec verdict and contract" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1
write_spec_pass
jq '.attempt=99 | .round=77' "$SPEC_REPORT/attempt-1/round-1/integrated-verdict.json" > "$SPEC_REPORT/attempt-1/round-1/integrated-verdict.tmp" &&
  mv "$SPEC_REPORT/attempt-1/round-1/integrated-verdict.tmp" "$SPEC_REPORT/attempt-1/round-1/integrated-verdict.json"
jq '.attempt=99 | .round=77' "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json" > "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" &&
  mv "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json"
expect_denied_without_evidence "impl predecessor attempt round path mismatch" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1
write_spec_pass
printf '{"schema":"integrated-verdict/v1","stage":"spec","feature":"%s","attempt":1,"round":1,"verdict":"NEEDS_WORK"}\n' "$FEATURE" > "$SPEC_REPORT/attempt-1/round-1/integrated-verdict.json"
expect_denied_without_evidence "impl non-PASS spec verdict" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1

write_spec_pass
jq --arg root "$ROOT/" '(.reviewers[].allowed_input_manifest[].path) |= ($root + .)' \
  "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json" > "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" &&
  mv "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json"
(cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1) >/dev/null
rm -rf "$IMPL_REPORT"

write_spec_pass
jq '(.reviewers[0].allowed_input_manifest) |= map(select(.path | endswith("/precheck-result.json") | not))' \
  "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json" > "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" &&
  mv "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json"
expect_denied_without_evidence "impl reviewer missing precheck evidence" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1

write_spec_pass
jq '(.reviewers[1].allowed_input_manifest) |= map(select(.path | endswith("/integrated-summary.json") | not))' \
  "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json" > "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" &&
  mv "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json"
expect_denied_without_evidence "impl reviewer B missing integrated summary" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1

write_spec_pass
jq '(.reviewers[0].allowed_input_manifest[] | select(.path | endswith("/requirements.md")).path) |= ascii_upcase' \
  "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json" > "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" &&
  mv "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json"
expect_denied_without_evidence "impl case changed canonical manifest path" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1

write_spec_pass
jq '(.reviewers[0].allowed_input_manifest) += [(.reviewers[0].allowed_input_manifest[] | select(.path | endswith("/requirements.md")) | .sha256=("0"*64))]' \
  "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json" > "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" &&
  mv "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json"
expect_denied_without_evidence "impl duplicate manifest path with forged hash" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1

rm -rf "$SPEC_REPORT"
mkdir -p "$SPEC_REPORT/attempt-9/round-1" "$SPEC_REPORT/attempt-10/round-1"
write_pass_artifacts spec "$SPEC_REPORT/attempt-9/round-1" 9
write_pass_artifacts spec "$SPEC_REPORT/attempt-10/round-1" 10
jq '.verdict="NEEDS_WORK"' "$SPEC_REPORT/attempt-10/round-1/integrated-verdict.json" > "$SPEC_REPORT/attempt-10/round-1/integrated-verdict.tmp" &&
  mv "$SPEC_REPORT/attempt-10/round-1/integrated-verdict.tmp" "$SPEC_REPORT/attempt-10/round-1/integrated-verdict.json"
expect_denied_without_evidence "impl numeric latest predecessor generation" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1
rm -rf "$SPEC_REPORT"

write_spec_pass
jq --arg path "specs/$FEATURE/../escape.md" \
  '(.reviewers[0].allowed_input_manifest) += [{path:$path,sha256:("0"*64)}]' \
  "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json" > "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" &&
  mv "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json"
expect_denied_without_evidence "impl traversal manifest path" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1

write_spec_pass
jq '(.reviewers[0].allowed_input_manifest) += [{path:"/tmp/sdd-forge-escape.md",sha256:("0"*64)}]' \
  "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json" > "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" &&
  mv "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json"
expect_denied_without_evidence "impl escaping absolute manifest path" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1

write_spec_pass
jq --arg path "reports/spec-review/$FEATURE/attempt-1/round-1/reviewer-a.json" \
  '(.reviewers[0].allowed_input_manifest) += [{path:$path,sha256:("0"*64)}]' \
  "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json" > "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" &&
  mv "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json"
expect_denied_without_evidence "impl arbitrary report artifact" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1

write_spec_pass
jq --arg path "reports/spec-review/$FEATURE/attempt-1/round-1/integrated-summary.json" \
  '(.reviewers[0].allowed_input_manifest) += [{path:$path,sha256:("0"*64)}]' \
  "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json" > "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" &&
  mv "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json"
expect_denied_without_evidence "impl reviewer-role manifest violation" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1

write_spec_pass
expect_denied_without_evidence "invalid feature slug" "$ROOT/reports/impl-review/unsafe" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh ../unsafe 1 1
expect_denied_without_evidence "nonpositive impl round" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 0
expect_denied_without_evidence "nonpositive task attempt" "$TASK_REPORT" \
  bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 0 1

(cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1) >/dev/null
[[ -f "$IMPL_REPORT/attempt-1/round-1/precheck-result.json" ]] || fail "valid impl predecessor must create precheck"
write_impl_pass
rm -f "$IMPL_REPORT/attempt-1/round-1/impl-review-contract.json"
expect_denied_without_evidence "task missing complete impl contract" "$TASK_REPORT" \
  bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 1 1
write_impl_pass
jq '(.reviewers[].allowed_input_manifest) |= map(select(.path != "plugins/sdd-review-loop/references/reviewer-calibration.md"))' "$IMPL_REPORT/attempt-1/round-1/impl-review-contract.json" > "$IMPL_REPORT/attempt-1/round-1/impl-review-contract.tmp" && mv "$IMPL_REPORT/attempt-1/round-1/impl-review-contract.tmp" "$IMPL_REPORT/attempt-1/round-1/impl-review-contract.json"
expect_denied_without_evidence "task missing impl calibration manifest" "$TASK_REPORT" \
  bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 1 1
write_impl_pass
printf '{"schema":"integrated-verdict/v1","stage":"impl","feature":"%s","attempt":1,"round":1,"verdict":"NEEDS_WORK"}\n' "$FEATURE" > "$IMPL_REPORT/attempt-1/round-1/integrated-verdict.json"
expect_denied_without_evidence "task non-PASS impl verdict" "$TASK_REPORT" \
  bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 1 1
write_impl_pass
jq '.run_id="contradictory-impl-run"' "$IMPL_REPORT/attempt-1/round-1/integrated-verdict.json" > "$IMPL_REPORT/attempt-1/round-1/integrated-verdict.tmp" && mv "$IMPL_REPORT/attempt-1/round-1/integrated-verdict.tmp" "$IMPL_REPORT/attempt-1/round-1/integrated-verdict.json"
expect_denied_without_evidence "task contradictory impl verdict and contract" "$TASK_REPORT" \
  bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 1 1
write_impl_pass
(cd "$ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 1 1) >/dev/null
[[ "$(jq -c '.edges' "$TASK_REPORT/attempt-1/round-1/dependency-graph.json")" == '[{"from":"T-002","to":"T-001"}]' ]] || fail "task graph must preserve declared edge"

rm -rf "$TASK_REPORT"
sed -i.bak 's/Risk: low/Risk: medium/g' "$SPEC_DIR/tasks.md"; rm -f "$SPEC_DIR/tasks.md.bak"
expect_denied_without_evidence "medium test-after workflow mismatch" "$TASK_REPORT" \
  bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 1 1
sed -i.bak 's/Risk: medium/Risk: low/g' "$SPEC_DIR/tasks.md"; rm -f "$SPEC_DIR/tasks.md.bak"

rm -rf "$TASK_REPORT"
sed -i.bak 's/^None$/T-002/' "$SPEC_DIR/tasks.md"; rm -f "$SPEC_DIR/tasks.md.bak"
expect_denied_without_evidence "cycle in blocker graph" "$TASK_REPORT" \
  bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 1 1

outside="$(mktemp -d)"
rm -rf "$IMPL_REPORT"
mkdir -p "$IMPL_REPORT/attempt-1"
ln -s "$outside" "$IMPL_REPORT/attempt-1/round-1"
if (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1) >/dev/null 2>&1; then fail "symlinked impl destination should fail"; fi
[[ -z "$(find "$outside" -mindepth 1 -print -quit)" ]] || fail "symlinked destination must not receive evidence"
rm -rf "$IMPL_REPORT" "$outside"

printf 'ok: downstream prechecks reject bad predecessors and cycles before evidence, then preserve valid graph edges\n'
