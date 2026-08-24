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

# Issue #120: prechecks must fail fast with a clear runtime error when jq is
# absent, before touching any specification, report, or registry state. Run each
# precheck under an isolated PATH that provides the coreutils the guard path
# needs but deliberately omits jq, so we exercise the absent-jq branch rather
# than a confusing mid-pipeline "jq: command not found" failure downstream.
JQ_ABSENT_BIN="$(mktemp -d)"
ln -sf "$(command -v dirname)" "$JQ_ABSENT_BIN/dirname"
JQ_GUARD_BASH="$(command -v bash)"
assert_jq_guard() {
  local precheck="$1" out rc
  set +e
  out="$(env -i PATH="$JQ_ABSENT_BIN" "$JQ_GUARD_BASH" \
    "$ROOT/plugins/sdd-review-loop/scripts/$precheck" jq-guard-fixture 1 1 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] ||
    fail "$precheck must exit non-zero when jq is absent"
  grep -q 'jq is required' <<<"$out" ||
    fail "$precheck must report 'jq is required' when jq is absent (got: $out)"
}
assert_jq_guard impl-review-precheck.sh
assert_jq_guard task-review-precheck.sh
rm -rf "$JQ_ABSENT_BIN"

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

# Issue #61 regression: spec-review-precheck.sh validate_contract persists
# absolute manifest paths of the generating checkout plus precheck-result and
# integrated-summary entries, hashed at review time (Spec-Review-Status:
# Pending). The impl gate must accept that canonical format after the Passed
# flip, including when validated from a different checkout (worktree/CI).
write_issue61_spec_pass() {
  local contract_root="$1" req acc calibration precheck summary
  local dir="$SPEC_REPORT/attempt-1/round-1"
  cat > "$SPEC_DIR/requirements.md" <<'EOF'
Spec-Review-Status: Pending
EOF
  rm -rf "$SPEC_REPORT"
  mkdir -p "$dir"
  req="$(shasum -a 256 "$SPEC_DIR/requirements.md" | awk '{print $1}')"
  acc="$(shasum -a 256 "$SPEC_DIR/acceptance-tests.md" | awk '{print $1}')"
  calibration="$(shasum -a 256 "$ROOT/plugins/sdd-review-loop/references/spec-review-calibration.md" | awk '{print $1}')"
  printf '{}\n' > "$dir/precheck-result.json"
  printf '{}\n' > "$dir/integrated-summary.json"
  precheck="$(shasum -a 256 "$dir/precheck-result.json" | awk '{print $1}')"
  summary="$(shasum -a 256 "$dir/integrated-summary.json" | awk '{print $1}')"
  jq -n --arg feature "$FEATURE" --arg root "$contract_root" --arg req "$req" --arg acc "$acc" \
    --arg calibration "$calibration" --arg precheck "$precheck" --arg summary "$summary" '
    def entries: [
      {path:($root+"/specs/"+$feature+"/requirements.md"),sha256:$req},
      {path:($root+"/specs/"+$feature+"/acceptance-tests.md"),sha256:$acc},
      {path:($root+"/plugins/sdd-review-loop/references/spec-review-calibration.md"),sha256:$calibration},
      {path:($root+"/reports/spec-review/"+$feature+"/attempt-1/round-1/precheck-result.json"),sha256:$precheck}];
    {schema:"spec-review-contract/v1",stage:"spec",feature:$feature,attempt:1,round:1,
     requirements_sha256:$req,acceptance_sha256:$acc,
     reviewers:[
       {role:"spec-reviewer-a",run_id:"run-a",host_session_id:"session-a",
        allowed_input_manifest:(entries | sort_by(.path))},
       {role:"spec-reviewer-b",run_id:"run-b",host_session_id:"session-b",
        allowed_input_manifest:((entries + [{path:($root+"/reports/spec-review/"+$feature+"/attempt-1/round-1/integrated-summary.json"),sha256:$summary}]) | sort_by(.path))}],
     run_id:"spec-orchestrator",verdict:"PASS",warningCount:0}' > "$dir/spec-review-contract.json"
  jq -n --arg feature "$FEATURE" \
    '{schema:"spec-review-integrated-verdict/v1",stage:"spec",feature:$feature,attempt:1,round:1,reviewer_a_run_id:"run-a",reviewer_b_run_id:"run-b",reviewer_a_host_session_id:"session-a",reviewer_b_host_session_id:"session-b",finding_counts:{critical:0,major:0,minor:0},verdict:"PASS",warningCount:0}' \
    > "$dir/integrated-verdict.json"
  # the orchestrating skill flips the status only after the review passes
  sed -i.bak 's/Spec-Review-Status: Pending/Spec-Review-Status: Passed/' "$SPEC_DIR/requirements.md"
  rm -f "$SPEC_DIR/requirements.md.bak"
}

write_issue61_spec_pass "/original-checkout/sdd-forge"
(cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1) >/dev/null ||
  fail "impl must accept the canonical spec contract from another checkout after the Passed flip"
rm -rf "$IMPL_REPORT"

write_issue61_spec_pass "$ROOT"
(cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1) >/dev/null ||
  fail "impl must accept the canonical spec contract from the same checkout after the Passed flip"
rm -rf "$IMPL_REPORT"

write_issue61_spec_pass "/original-checkout/sdd-forge"
jq '(.reviewers[].allowed_input_manifest[] | select(.path | endswith("/requirements.md")) | .sha256) = ("1"*64) | .requirements_sha256 = ("1"*64)' \
  "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json" > "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" &&
  mv "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json"
expect_denied_without_evidence "impl tampered requirements hash in foreign-checkout contract" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1

write_issue61_spec_pass "/original-checkout/sdd-forge"
jq '(.reviewers[0].allowed_input_manifest) += [{path:"/original-checkout/outside/escape.md",sha256:("0"*64)}]' \
  "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json" > "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" &&
  mv "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.tmp" "$SPEC_REPORT/attempt-1/round-1/spec-review-contract.json"
expect_denied_without_evidence "impl anchor-less absolute path in foreign-checkout contract" "$IMPL_REPORT" \
  bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1

# Issue #61 regression (task gate): the same canonical-contract format persisted
# by predecessor gates must also be accepted by task-review-precheck.sh when it
# validates the spec AND impl predecessor contracts, including from a checkout
# other than the one running task-review-precheck.sh (worktree/clone/CI).
write_issue61_impl_pass() {
  local contract_root="$1" req acc design calibration precheck summary
  local dir="$IMPL_REPORT/attempt-1/round-1"
  sed -i.bak 's/Impl-Review-Status: Pending/Impl-Review-Status: Passed/' "$SPEC_DIR/design.md"
  rm -f "$SPEC_DIR"/*.bak
  rm -rf "$IMPL_REPORT"
  mkdir -p "$dir"
  req="$(shasum -a 256 "$SPEC_DIR/requirements.md" | awk '{print $1}')"
  acc="$(shasum -a 256 "$SPEC_DIR/acceptance-tests.md" | awk '{print $1}')"
  design="$(shasum -a 256 "$SPEC_DIR/design.md" | awk '{print $1}')"
  calibration="$(shasum -a 256 "$ROOT/plugins/sdd-review-loop/references/reviewer-calibration.md" | awk '{print $1}')"
  printf '{}\n' > "$dir/precheck-result.json"
  printf '{}\n' > "$dir/integrated-summary.json"
  precheck="$(shasum -a 256 "$dir/precheck-result.json" | awk '{print $1}')"
  summary="$(shasum -a 256 "$dir/integrated-summary.json" | awk '{print $1}')"
  jq -n --arg feature "$FEATURE" --arg root "$contract_root" --arg req "$req" --arg acc "$acc" --arg design "$design" \
    --arg calibration "$calibration" --arg precheck "$precheck" --arg summary "$summary" '
    def entries: [
      {path:($root+"/specs/"+$feature+"/requirements.md"),sha256:$req},
      {path:($root+"/specs/"+$feature+"/acceptance-tests.md"),sha256:$acc},
      {path:($root+"/specs/"+$feature+"/design.md"),sha256:$design},
      {path:($root+"/plugins/sdd-review-loop/references/reviewer-calibration.md"),sha256:$calibration},
      {path:($root+"/reports/impl-review/"+$feature+"/attempt-1/round-1/precheck-result.json"),sha256:$precheck}];
    {schema:"impl-review-contract/v1",stage:"impl",feature:$feature,attempt:1,round:1,
     requirements_sha256:$req,acceptance_sha256:$acc,design_sha256:$design,
     reviewers:[
       {role:"impl-reviewer-a",run_id:"run-a",host_session_id:"session-a",
        allowed_input_manifest:(entries | sort_by(.path))},
       {role:"impl-reviewer-b",run_id:"run-b",host_session_id:"session-b",
        allowed_input_manifest:((entries + [{path:($root+"/reports/impl-review/"+$feature+"/attempt-1/round-1/integrated-summary.json"),sha256:$summary}]) | sort_by(.path))}],
     run_id:"impl-orchestrator",verdict:"PASS",warningCount:0}' > "$dir/impl-review-contract.json"
  jq -n --arg feature "$FEATURE" \
    '{schema:"integrated-verdict/v1",stage:"impl",feature:$feature,attempt:1,round:1,run_id:"impl-orchestrator",verdict:"PASS"}' \
    > "$dir/integrated-verdict.json"
}

write_issue61_spec_pass "/original-checkout/sdd-forge"
write_issue61_impl_pass "/original-checkout/sdd-forge"
(cd "$ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 1 1) >/dev/null ||
  fail "task must accept canonical spec and impl contracts from another checkout after the Passed flips"
rm -rf "$TASK_REPORT"

write_issue61_spec_pass "$ROOT"
write_issue61_impl_pass "$ROOT"
(cd "$ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 1 1) >/dev/null ||
  fail "task must accept canonical spec and impl contracts from the same checkout after the Passed flips"
rm -rf "$TASK_REPORT"

write_issue61_spec_pass "/original-checkout/sdd-forge"
write_issue61_impl_pass "/original-checkout/sdd-forge"
jq '(.reviewers[].allowed_input_manifest[] | select(.path | endswith("/design.md")) | .sha256) = ("1"*64) | .design_sha256 = ("1"*64)' \
  "$IMPL_REPORT/attempt-1/round-1/impl-review-contract.json" > "$IMPL_REPORT/attempt-1/round-1/impl-review-contract.tmp" &&
  mv "$IMPL_REPORT/attempt-1/round-1/impl-review-contract.tmp" "$IMPL_REPORT/attempt-1/round-1/impl-review-contract.json"
expect_denied_without_evidence "task tampered design hash in foreign-checkout impl contract" "$TASK_REPORT" \
  bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 1 1

write_issue61_spec_pass "/original-checkout/sdd-forge"
write_issue61_impl_pass "/original-checkout/sdd-forge"
jq '(.reviewers[0].allowed_input_manifest) += [{path:"/original-checkout/outside/escape.md",sha256:("0"*64)}]' \
  "$IMPL_REPORT/attempt-1/round-1/impl-review-contract.json" > "$IMPL_REPORT/attempt-1/round-1/impl-review-contract.tmp" &&
  mv "$IMPL_REPORT/attempt-1/round-1/impl-review-contract.tmp" "$IMPL_REPORT/attempt-1/round-1/impl-review-contract.json"
expect_denied_without_evidence "task anchor-less absolute path in foreign-checkout impl contract" "$TASK_REPORT" \
  bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 1 1

# Restore design.md to Impl-Review-Status: Pending so later impl-review-precheck.sh
# invocations in this suite see the state they expect.
sed -i.bak 's/Impl-Review-Status: Passed/Impl-Review-Status: Pending/' "$SPEC_DIR/design.md"
rm -f "$SPEC_DIR/design.md.bak"
rm -rf "$IMPL_REPORT" "$TASK_REPORT"

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
(cd "$ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 1 1) >/dev/null ||
  fail "medium test-after should remain valid under the canonical risk policy"
rm -rf "$TASK_REPORT"
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

# AC coverage: design.md must name every AC-NNN that requirements.md states.
# On epic-136-phase4-docs, impl review burned rounds 2 and 3 of attempt 1 finding
# AC-013 and then AC-012 absent from the design plan, one per round, and escalated
# to BLOCKED; a later sweep found AC-001 and AC-014 missing too. All were criteria
# spec review had added late as gap-closers. This is deterministic work that was
# being paid for with reviewer rounds.
rm -rf "$SPEC_DIR" "$SPEC_REPORT" "$IMPL_REPORT"
write_inputs
# The spec contract is hash-bound to these documents, so every edit below is made
# before the contract that pins it is written.
printf '\n#### AC-001\n\nfixture criterion\n' >> "$SPEC_DIR/requirements.md"
write_spec_pass

ac_run() {
  (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1) 2>&1
}

# absent -> refused, and refused before any evidence is written
rm -rf "$IMPL_REPORT"
ac_out="$(ac_run || true)"
grep -q 'never names these acceptance criteria: AC-001' <<<"$ac_out" ||
  fail "impl precheck must refuse a design.md that never names AC-001 (got: $ac_out)"
[[ ! -d "$IMPL_REPORT/attempt-1/round-1" ]] ||
  fail 'AC-coverage refusal must fail closed before creating round evidence'

# named -> accepted, proving the refusal above was the AC check and not some
# unrelated fixture failure that would make this case vacuous
printf '\nCovers AC-001 in the plan.\n' >> "$SPEC_DIR/design.md"
write_spec_pass   # re-pin the contract now that design.md changed
rm -rf "$IMPL_REPORT"
ac_out="$(ac_run || true)"
if grep -q 'never names these acceptance criteria' <<<"$ac_out"; then
  fail "impl precheck must accept a design.md that names AC-001 (got: $ac_out)"
fi
[[ -f "$IMPL_REPORT/attempt-1/round-1/precheck-result.json" ]] ||
  fail "impl precheck should have produced round evidence once AC-001 is named (got: $ac_out)"
rm -rf "$IMPL_REPORT"

# The narrow Global-scope exception (human ruling, 2026-08-24), and the half of
# it that matters just as much: the exception must not become a loophole.
#
# Some acceptance criteria are structurally not design content. epic-194's
# AC-023/AC-024 and epic-193's AC-035..AC-037 are criteria about the spec
# package's OWN registration commit -- AC-024 requires both status headers to
# read Pending "at commit time", which no design plans for and which is now
# historically false since both read Passed. The exception keys on the scope the
# requirements table itself declares in the criterion's own defining row, in
# both spellings the repository uses, never on a list of AC ids and never on
# "cited somewhere in the package". A REQ-traced criterion -- which is what
# every epic-136-class gap-closer is -- is still demanded of the design.
#
# Both halves are asserted from ONE run, so neither can pass by accident: a
# one-sided test would let a blanket loosening through.
rm -rf "$SPEC_DIR" "$SPEC_REPORT" "$IMPL_REPORT"
write_inputs
cat >> "$SPEC_DIR/requirements.md" <<'EOF'

| AC-ID | Requirement | Criterion |
|---|---|---|
| AC-002 | REQ-001 | Behaviour this design must plan for. |
| AC-003 | Global | This package's own registration commit creates no file outside its spec directory. |
| AC-004 (Global) | — | `check-sdd-structure.sh` exits 0 after this package's registration commit. |
EOF
write_spec_pass
rm -rf "$IMPL_REPORT"
ac_out="$(ac_run || true)"
ac_error="$(grep 'never names these acceptance criteria' <<<"$ac_out" || true)"
[[ -n "$ac_error" ]] ||
  fail "a REQ-traced AC missing from design.md must still be refused (got: $ac_out)"
[[ "$ac_error" == *AC-002* ]] ||
  fail "the refusal must name the REQ-traced AC-002 (got: $ac_error)"
[[ "$ac_error" != *AC-003* ]] ||
  fail "a criterion the requirements table scopes Global must not be demanded of design.md (got: $ac_error)"
[[ "$ac_error" != *AC-004* ]] ||
  fail "the '(Global)' spelling must be read as Global scope too (got: $ac_error)"
[[ "$ac_out" == *"scopes Global"*AC-003*AC-004* ]] ||
  fail "an exercised exception must be reported, naming the excused criteria (got: $ac_out)"
[[ ! -d "$IMPL_REPORT/attempt-1/round-1" ]] ||
  fail 'AC-coverage refusal must fail closed before creating round evidence'
# The diagnostic must assert only what this script evaluates. It consults no
# testability or traceability attribute anywhere, and never did.
[[ "$ac_out" != *"testable and traceable"* ]] ||
  fail "the AC-coverage diagnostic claims a predicate this script never evaluates (got: $ac_out)"

# Naming only the REQ-traced criterion clears the gate: proof the two Global
# rows were genuinely excused and were not merely riding on some other failure.
printf '\nCovers AC-002 in the plan.\n' >> "$SPEC_DIR/design.md"
write_spec_pass   # re-pin the contract now that design.md changed
rm -rf "$IMPL_REPORT"
ac_out="$(ac_run || true)"
if grep -q 'never names these acceptance criteria' <<<"$ac_out"; then
  fail "Global-scoped criteria must not be demanded of design.md (got: $ac_out)"
fi
[[ -f "$IMPL_REPORT/attempt-1/round-1/precheck-result.json" ]] ||
  fail "impl precheck should have produced round evidence once AC-002 is named (got: $ac_out)"
rm -rf "$IMPL_REPORT"

# Contract/reviewer agreement: a round's recorded hashes must be the hashes its
# two reviewers actually pinned. On epic-136-phase4-docs attempt 2 round 2 the
# contract was written after a remediation edit and recorded a design.md hash
# neither reviewer had read, so the round's verdict was attributed to text nobody
# reviewed. It surfaced only because the next round's precheck happened to refuse.
rm -rf "$SPEC_DIR" "$SPEC_REPORT" "$IMPL_REPORT"
write_inputs
printf '\n#### AC-001\n\nfixture criterion\n' >> "$SPEC_DIR/requirements.md"
printf '\nCovers AC-001 in the plan.\n' >> "$SPEC_DIR/design.md"
write_spec_pass
# Round-1 impl evidence without flipping Impl-Review-Status, which must stay
# Pending for round 2 to run at all.
mkdir -p "$IMPL_REPORT/attempt-1/round-1"
write_pass_artifacts impl "$IMPL_REPORT/attempt-1/round-1"
impl_contract="$IMPL_REPORT/attempt-1/round-1/impl-review-contract.json"
[[ -f "$impl_contract" ]] || fail 'fixture did not produce an impl contract'
cp "$impl_contract" "$impl_contract.orig"
# Round 2 requires design.md to differ from what round 1 recorded.
printf '\nRound-2 remediation line.\n' >> "$SPEC_DIR/design.md"

fake='1111111111111111111111111111111111111111111111111111111111111111'

# (a) contract records a design hash neither reviewer pinned -> refused
jq --arg h "$fake" '.design_sha256=$h' "$impl_contract.orig" > "$impl_contract"
out="$( (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 2) 2>&1 || true)"
grep -q 'neither reviewer read' <<<"$out" ||
  fail "impl precheck must refuse a contract recording a design hash no reviewer pinned (got: $out)"

# (b) the two reviewers pinned different design hashes -> refused
jq --arg h "$fake" '.reviewers[1].allowed_input_manifest |= map(if (.path|test("design\\.md$")) then .sha256=$h else . end)' \
  "$impl_contract.orig" > "$impl_contract"
out="$( (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 2) 2>&1 || true)"
grep -q 'did not review the same text' <<<"$out" ||
  fail "impl precheck must refuse a contract whose reviewers pinned different design.md (got: $out)"

# (c) the untouched contract must still be accepted, so (a) and (b) are not vacuous
cp "$impl_contract.orig" "$impl_contract"
out="$( (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 2) 2>&1 || true)"
if grep -qE 'neither reviewer read|did not review the same text' <<<"$out"; then
  fail "impl precheck must accept a contract whose reviewers agree with it (got: $out)"
fi
rm -f "$impl_contract.orig"
rm -rf "$IMPL_REPORT"

# ─────────────────────────────────────────────────────────────────────────────
# impl-review-precheck --provenance-rereview
#
# Post-implementation evidence re-binding. Before this mode existed the impl
# stage had no way to start a second attempt at all: a shipped feature's
# design.md must read `Impl-Review-Status: Passed` (check-workflow-state.sh's
# task-lifecycle rule requires every stage to read Passed once any task is
# Approved or past Planned), while the precheck demanded `Pending`. The two
# rules could not both hold, and the error text pointed at a `--reset` flag the
# script never implemented.
# ─────────────────────────────────────────────────────────────────────────────
rm -rf "$SPEC_DIR" "$SPEC_REPORT" "$IMPL_REPORT" "$TASK_REPORT"
write_inputs
write_spec_pass

# Without a prior persisted impl PASS there is no provenance to re-bind, so the
# mode must refuse even though design.md is otherwise in the right state. This
# is the guard that stops the mode standing in for a first review.
sed -i.bak 's/Impl-Review-Status: Pending/Impl-Review-Status: Passed/' "$SPEC_DIR/design.md"
rm -f "$SPEC_DIR"/*.bak
provenance_err="$( (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh \
  "$FEATURE" 2 1 --provenance-rereview) 2>&1 1>/dev/null || true )"
grep -q 'prior persisted impl-review PASS verdict' <<<"$provenance_err" ||
  fail "provenance re-review without a prior PASS must name the missing verdict (got: $provenance_err)"
[[ ! -e "$IMPL_REPORT/attempt-2" ]] ||
  fail "provenance re-review must not create evidence when it refuses"

# Now give it a real prior PASS. write_impl_pass leaves design.md at Passed and
# writes attempt-1/round-1's integrated-verdict.
sed -i.bak 's/Impl-Review-Status: Passed/Impl-Review-Status: Pending/' "$SPEC_DIR/design.md"
rm -f "$SPEC_DIR"/*.bak
write_impl_pass

# A Pending header is refused even with a prior PASS present: Pending means the
# ordinary attempt path applies, and silently accepting it here would let the
# mode bypass a first review after all.
sed -i.bak 's/Impl-Review-Status: Passed/Impl-Review-Status: Pending/' "$SPEC_DIR/design.md"
rm -f "$SPEC_DIR"/*.bak
pending_err="$( (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh \
  "$FEATURE" 2 1 --provenance-rereview) 2>&1 1>/dev/null || true )"
grep -q 'requires design.md to declare' <<<"$pending_err" ||
  fail "provenance re-review must refuse a Pending header (got: $pending_err)"
rm -rf "$IMPL_REPORT/attempt-2"
sed -i.bak 's/Impl-Review-Status: Pending/Impl-Review-Status: Passed/' "$SPEC_DIR/design.md"
rm -f "$SPEC_DIR"/*.bak

# The contrast that makes this suite non-vacuous: in one and the same state, the
# ordinary invocation must fail and the provenance invocation must succeed. If
# the ordinary one ever starts passing here, the mode is no longer doing
# anything and these cases would otherwise still go green.
ordinary_err="$( (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh \
  "$FEATURE" 2 1) 2>&1 1>/dev/null || true )"
grep -q "expected 'Pending'" <<<"$ordinary_err" ||
  fail "ordinary impl precheck must still refuse a Passed header (got: $ordinary_err)"
grep -q 'use --provenance-rereview' <<<"$ordinary_err" ||
  fail "ordinary impl precheck must point at a flag that exists (got: $ordinary_err)"
rm -rf "$IMPL_REPORT/attempt-2"
(cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh \
  "$FEATURE" 2 1 --provenance-rereview) >/dev/null ||
  fail "provenance re-review must accept a prior-PASS design.md that the ordinary path refuses"
[[ -f "$IMPL_REPORT/attempt-2/round-1/precheck-result.json" ]] ||
  fail "provenance re-review must write the round's precheck evidence"
rm -rf "$IMPL_REPORT/attempt-2"

# The canonical gate is advisory under this mode, not skipped. Re-register the
# fixture as a full-profile feature so check-workflow-state actually runs and
# fails on it, then assert the ordinary path dies on the gate while the
# provenance path gets past it.
jq --arg feature "$FEATURE" \
  '.entries |= map(if .feature == $feature then .profile = "full" else . end)' \
  "$REGISTRY" > "$REGISTRY.tmp"
mv "$REGISTRY.tmp" "$REGISTRY"
gate_err="$( (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh \
  "$FEATURE" 2 1) 2>&1 1>/dev/null || true )"
# Match the fatal form specifically. The advisory NOTE quotes the same phrase,
# so a bare substring match would be satisfied by the very message that proves
# the mode worked.
grep -q '^ERROR: impl-review-precheck: canonical workflow-state validation failed' <<<"$gate_err" ||
  fail "the full-profile fixture must actually fail the canonical gate, or the next case proves nothing (got: $gate_err)"
rm -rf "$IMPL_REPORT/attempt-2"
tolerant_err="$( (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh \
  "$FEATURE" 2 1 --provenance-rereview) 2>&1 1>/dev/null || true )"
grep -q 'impl-stage evidence re-binding in progress' <<<"$tolerant_err" ||
  fail "provenance re-review must disclose that it proceeded past a failing gate (got: $tolerant_err)"
if grep -q '^ERROR: impl-review-precheck: canonical workflow-state validation failed' <<<"$tolerant_err"; then
  fail "provenance re-review must not abort on the gate it is meant to repair (got: $tolerant_err)"
fi
# Positive proof that execution continued past the gate rather than stopping
# quietly: the run reaches the full-profile layer-input check, which is many
# steps downstream of the gate call.
grep -q 'layer review input is missing' <<<"$tolerant_err" ||
  fail "provenance re-review should have continued to the layer-input check (got: $tolerant_err)"
jq --arg feature "$FEATURE" \
  '.entries |= map(if .feature == $feature then .profile = "lite" else . end)' \
  "$REGISTRY" > "$REGISTRY.tmp"
mv "$REGISTRY.tmp" "$REGISTRY"
rm -rf "$IMPL_REPORT/attempt-2"

printf 'ok: downstream prechecks reject bad predecessors and cycles before evidence, then preserve valid graph edges\n'
printf 'ok: impl --provenance-rereview re-binds a prior PASS, refuses without one, and treats the canonical gate as advisory\n'
