#!/usr/bin/env bash
# task-plan-binding-durability.tests.sh — WFI-025: a task-stage provenance
# binding made over a MIXED-status task plan survives lifecycle transitions.
#
# Three parts:
#  P1. The producing side: task-review-precheck.sh records the raw digest for
#      a uniform plan (byte-for-byte today's behaviour) and the
#      STATUS-NORMALIZED digest for a mixed plan, declaring which under
#      tasks_sha256_form. Non-vacuity: the same feature flips form when its
#      plan's mixture flips.
#  P2. The reservation validator: the tasks.md manifest entry may carry the
#      normalized digest ONLY when the round's precheck declares it — the
#      scoped exception binds (precheck pin + live-file re-derivation), the
#      old-way fresh-raw manifest is rejected at reservation, and the
#      exception is unusable for any other entry or a raw-form precheck.
#  P3. The accepting side, unchanged code: with the normalized digest
#      recorded, check-workflow-state.sh still exits 0 after a status flip —
#      and with the raw digest recorded (the only form the pre-WFI-025
#      precheck could emit), the same flip fails. That pair is the measured
#      before/after of the property this WFI exists to create.
set -euo pipefail

# This suite drives the sh review stack end to end (real precheck →
# validator → check-workflow-state.sh). On Windows the ps1 twins are CI's
# leg for that stack — check-workflow-state.sh's registry scan misreads
# spec-directory paths under Git Bash (every registered feature reports
# registry-dangling-entry), so the sh legs are skipped there exactly as the
# workflow-state suites gate them.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    echo "SKIP: task-plan-binding-durability.tests.sh exercises the sh review stack; the ps1 twins are CI's Windows leg"
    exit 0 ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FEATURE="binding-durability-fixture"
SPEC_DIR="$ROOT/specs/$FEATURE"
SPEC_REPORT="$ROOT/reports/spec-review/$FEATURE"
IMPL_REPORT="$ROOT/reports/impl-review/$FEATURE"
TASK_REPORT="$ROOT/reports/task-review/$FEATURE"
REGISTRY="$ROOT/specs/workflow-state-registry.json"
REGISTRY_BACKUP="$(mktemp)"
cp "$REGISTRY" "$REGISTRY_BACKUP"
TMP="$(mktemp -d)"

PASS=0
FAIL=0
ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }
die()  { echo "not ok: $*" >&2; exit 1; }

cleanup() {
  cp "$REGISTRY_BACKUP" "$REGISTRY"
  rm -f "$REGISTRY_BACKUP"
  rm -rf "$SPEC_DIR" "$SPEC_REPORT" "$IMPL_REPORT" "$TASK_REPORT" "$TMP"
}
trap cleanup EXIT

sha_file() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}' || sha256sum "$1" | awk '{print $1}'; }
sha_stream() { if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'; else shasum -a 256 | awk '{print $1}'; fi; }
# The accepting side's task normalization (check-workflow-state.sh
# normalized_hash, task stage), restated here as the test's independent
# expectation of what the precheck and validator must both compute.
norm_hash() {
  sed \
    -e "s/^Task-Review-Status:[[:space:]]*.*/Task-Review-Status: Pending/" \
    -e "s/^Approval:[[:space:]]*.*/Approval: Draft/" \
    -e "s/^Status:[[:space:]]*.*/Status: Planned/" \
    -e "/^Second Approval:/d" "$1" | sha_stream
}

# ---------------------------------------------------------------------------
# P1 — the producing side, on the REAL precheck with its real predecessors.
# ---------------------------------------------------------------------------
jq --arg feature "$FEATURE" '.entries += [{feature:$feature,profile:"lite"}]' \
  "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"

write_tasks_uniform() {
  cat > "$SPEC_DIR/tasks.md" <<'EOF'
Task-Review-Status: Pending

## T-001 First
Risk: low
Risk Rationale: fixture
Required Workflow: test-after
Approval: Draft
Status: Planned
### Blockers
None

## T-002 Second
Risk: low
Risk Rationale: fixture
Required Workflow: test-after
Approval: Draft
Status: Planned
### Blockers
T-001
EOF
}
write_tasks_mixed() {
  cat > "$SPEC_DIR/tasks.md" <<'EOF'
Task-Review-Status: Pending

## T-001 First
Risk: low
Risk Rationale: fixture
Required Workflow: test-after
Approval: Approved (alice 2026-08-22T01:02:03Z)
Status: Done
### Blockers
None

## T-002 Second
Risk: low
Risk Rationale: fixture
Required Workflow: test-after
Approval: Draft
Status: Planned
### Blockers
T-001
EOF
}
write_inputs() {
  mkdir -p "$SPEC_DIR"
  printf 'Spec-Review-Status: Pending\n' > "$SPEC_DIR/requirements.md"
  printf 'Impl-Review-Status: Pending\n' > "$SPEC_DIR/design.md"
  printf '# Acceptance\n' > "$SPEC_DIR/acceptance-tests.md"
  write_tasks_uniform
}
write_pass_artifacts() {
  local stage="$1" directory="$2" req acc design calibration precheck summary
  req="$(sha_file "$SPEC_DIR/requirements.md")"
  acc="$(sha_file "$SPEC_DIR/acceptance-tests.md")"
  design="$(sha_file "$SPEC_DIR/design.md")"
  if [[ "$stage" == spec ]]; then
    calibration="$(sha_file "$ROOT/plugins/sdd-review-loop/references/spec-review-calibration.md")"
  else
    calibration="$(sha_file "$ROOT/plugins/sdd-review-loop/references/reviewer-calibration.md")"
  fi
  printf '{}\n' > "$directory/precheck-result.json"
  printf '{}\n' > "$directory/integrated-summary.json"
  precheck="$(sha_file "$directory/precheck-result.json")"
  summary="$(sha_file "$directory/integrated-summary.json")"
  jq -n --arg stage "$stage" --arg feature "$FEATURE" \
    'if $stage == "spec" then {schema:"spec-review-integrated-verdict/v1",stage:"spec",feature:$feature,attempt:1,round:1,reviewer_a_run_id:"run-a",reviewer_b_run_id:"run-b",reviewer_a_host_session_id:"session-a",reviewer_b_host_session_id:"session-b",finding_counts:{critical:0,major:0,minor:0},verdict:"PASS",warningCount:0} else {schema:"integrated-verdict/v1",stage:$stage,feature:$feature,attempt:1,round:1,run_id:($stage+"-orchestrator"),verdict:"PASS"} end' > "$directory/integrated-verdict.json"
  jq -n --arg stage "$stage" --arg feature "$FEATURE" --arg req "$req" --arg acc "$acc" --arg design "$design" --arg calibration "$calibration" --arg precheck "$precheck" --arg summary "$summary" \
    '{schema:($stage+"-review-contract/v1"),stage:$stage,feature:$feature,attempt:1,round:1,run_id:($stage+"-orchestrator"),verdict:"PASS",requirements_sha256:$req,acceptance_sha256:$acc,design_sha256:$design,reviewers:[{role:($stage+"-reviewer-a"),run_id:"run-a",host_session_id:"session-a",allowed_input_manifest:[{path:("specs/"+$feature+"/requirements.md"),sha256:$req},{path:("specs/"+$feature+"/acceptance-tests.md"),sha256:$acc}]},{role:($stage+"-reviewer-b"),run_id:"run-b",host_session_id:"session-b",allowed_input_manifest:[{path:("specs/"+$feature+"/requirements.md"),sha256:$req},{path:("specs/"+$feature+"/acceptance-tests.md"),sha256:$acc}]}]}
    | if $stage == "impl" then .reviewers |= map(.allowed_input_manifest += [{path:("specs/"+$feature+"/design.md"),sha256:$design}]) else . end
    | .reviewers |= map(.allowed_input_manifest += [{path:(if $stage == "spec" then "plugins/sdd-review-loop/references/spec-review-calibration.md" else "plugins/sdd-review-loop/references/reviewer-calibration.md" end),sha256:$calibration},{path:("reports/"+$stage+"-review/"+$feature+"/attempt-1/round-1/precheck-result.json"),sha256:$precheck}])
    | .reviewers[1].allowed_input_manifest += [{path:("reports/"+$stage+"-review/"+$feature+"/attempt-1/round-1/integrated-summary.json"),sha256:$summary}]' > "$directory/$stage-review-contract.json"
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

write_inputs
write_spec_pass
write_impl_pass

if ! (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 1 1) >/dev/null; then
  die "P1 setup: precheck on the uniform plan should succeed"
fi
P1_UNIFORM="$TASK_REPORT/attempt-1/round-1/precheck-result.json"
[[ "$(jq -r '.tasks_sha256_form' "$P1_UNIFORM")" == "raw" ]] \
  && ok "P1: uniform plan records tasks_sha256_form=raw" \
  || fail "P1: uniform plan form is $(jq -r '.tasks_sha256_form' "$P1_UNIFORM"), expected raw"
[[ "$(jq -r '.tasks_sha256' "$P1_UNIFORM")" == "$(sha_file "$SPEC_DIR/tasks.md")" ]] \
  && ok "P1: uniform plan records the raw digest byte-for-byte" \
  || fail "P1: uniform plan digest is not the raw digest"

write_tasks_mixed
if ! (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 2 1) >/dev/null; then
  die "P1 setup: precheck on the mixed plan should succeed"
fi
P1_MIXED="$TASK_REPORT/attempt-2/round-1/precheck-result.json"
MIXED_NORM="$(norm_hash "$SPEC_DIR/tasks.md")"
MIXED_RAW="$(sha_file "$SPEC_DIR/tasks.md")"
[[ "$(jq -r '.tasks_sha256_form' "$P1_MIXED")" == "normalized" ]] \
  && ok "P1: mixed plan records tasks_sha256_form=normalized (non-vacuity: same feature, flipped mixture, flipped form)" \
  || fail "P1: mixed plan form is $(jq -r '.tasks_sha256_form' "$P1_MIXED"), expected normalized"
[[ "$(jq -r '.tasks_sha256' "$P1_MIXED")" == "$MIXED_NORM" ]] \
  && ok "P1: mixed plan records the accepting side's normalized recipe exactly" \
  || fail "P1: mixed plan digest does not match the normalization recipe"
[[ "$MIXED_NORM" != "$MIXED_RAW" ]] \
  && ok "P1: normalized and raw digests differ on the mixed plan (the recipe is not vacuous)" \
  || fail "P1: normalized digest equals raw on a mixed plan"

# verify-inputs honors the declared form: flip a status, then re-verify.
sed -i.bak 's/^Status: Done$/Status: Implementation Complete/' "$SPEC_DIR/tasks.md"; rm -f "$SPEC_DIR"/*.bak
if (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 2 1 --verify-inputs) >/dev/null 2>&1; then
  ok "P1: --verify-inputs absorbs a status flip under a normalized record"
else
  fail "P1: --verify-inputs rejected a pure status flip under a normalized record"
fi
printf 'body edit\n' >> "$SPEC_DIR/tasks.md"
if (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 2 1 --verify-inputs) >/dev/null 2>&1; then
  fail "P1: --verify-inputs accepted a BODY edit under a normalized record"
else
  ok "P1: --verify-inputs still rejects a body edit under a normalized record"
fi
sed -i.bak '$d' "$SPEC_DIR/tasks.md"; rm -f "$SPEC_DIR"/*.bak

# Mis-cased mixture (PR #336 review; AGENTS.md case-sensitivity sweep): a
# Done/done plan is MIXED — status values compare case-sensitively, exactly
# as LC_ALL=C sort -u does. This is the fixture the ps1 twin's ordinal
# HashSet must mirror.
write_tasks_mixed
sed -i.bak 's/^Status: Planned$/Status: done/' "$SPEC_DIR/tasks.md"
sed -i.bak2 's/^Approval: Draft$/Approval: Approved (bob 2026-08-22T01:02:03Z)/' "$SPEC_DIR/tasks.md"
rm -f "$SPEC_DIR"/*.bak "$SPEC_DIR"/*.bak2
if ! (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "$FEATURE" 3 1) >/dev/null; then
  fail "P1 setup: precheck on the mis-cased mixed plan should succeed"
else
  [[ "$(jq -r '.tasks_sha256_form' "$TASK_REPORT/attempt-3/round-1/precheck-result.json")" == "normalized" ]] \
    && ok "P1: a Done/done plan is classified mixed (case-sensitive uniqueness)" \
    || fail "P1: a Done/done plan was classified uniform — case-insensitive comparison crept in"
fi
write_tasks_mixed

# ---------------------------------------------------------------------------
# P2 — the reservation validator's scoped exception, on isolated fixtures.
# ---------------------------------------------------------------------------
VALIDATOR="$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
sha_text() { printf '%s' "$1" | sha_stream; }
# P1's verify-inputs cases mutated the live fixture plan (a status flip the
# normalized digest absorbs), so re-derive the RAW digest from the plan as it
# stands now; the normalized digest is unchanged by construction.
MIXED_RAW="$(sha_file "$SPEC_DIR/tasks.md")"

build_reservation_fixture() {
  local dir="$1" tasks_hash="$2" precheck_form="$3" precheck_hash="$4"
  rm -rf "$dir"
  mkdir -p "$dir/specs/$FEATURE" "$dir/reports/review-context" "$dir/reports/task-review/$FEATURE/attempt-2/round-1"
  cp "$SPEC_DIR/tasks.md" "$dir/specs/$FEATURE/tasks.md"
  jq -n --arg form "$precheck_form" --arg hash "$precheck_hash" --arg feature "$FEATURE" \
    '{schema:"task-review-precheck/v1",feature:$feature,attempt:2,round:1,tasks_sha256:$hash,tasks_sha256_form:$form}' \
    > "$dir/reports/task-review/$FEATURE/attempt-2/round-1/precheck-result.json"
  local record1_hash ledger_hash precheck_file_hash
  # Genesis record hash: the chain walk recomputes with an EMPTY previous
  # field (the '-' in its tsv is mapped back to '' first).
  record1_hash="$(sha_text '1|spec|spec-reviewer-a|RUN-genesis|SESS-genesis|')"
  jq -n --arg hash "$record1_hash" \
    '{schema:"review-identity-ledger/v1",records:[{sequence:1,stage:"spec",role:"spec-reviewer-a",run_id:"RUN-genesis",host_session_id:"SESS-genesis",previous_record_sha256:"",record_sha256:$hash}]}' \
    > "$dir/reports/review-context/identity-ledger.json"
  ledger_hash="$(sha_file "$dir/reports/review-context/identity-ledger.json")"
  precheck_file_hash="$(sha_file "$dir/reports/task-review/$FEATURE/attempt-2/round-1/precheck-result.json")"
  jq -n --arg feature "$FEATURE" --arg ledger "$ledger_hash" --arg previous "$record1_hash" \
    --arg tasks "$tasks_hash" --arg precheck "$precheck_file_hash" \
    '{schema:"review-context-invocation/v2",input_mode:"file-manifest",fallback_mode:"none",read_only:true,
      stage:"task",role:"task-reviewer-a",feature:$feature,run_id:"RUN-wfi025",host_session_id:"SESS-wfi025",
      sequence:2,identity_ledger_path:"reports/review-context/identity-ledger.json",
      identity_ledger_sha256:$ledger,previous_record_sha256:$previous,
      allowed_input_manifest:[
        {path:("specs/"+$feature+"/tasks.md"),sha256:$tasks},
        {path:("reports/task-review/"+$feature+"/attempt-2/round-1/precheck-result.json"),sha256:$precheck}]}' \
    > "$dir/manifest.json"
}

run_validator() { bash "$VALIDATOR" "$1/manifest.json" "$1" 2>&1; }

# (a) normalized digest, declared by the precheck: accepted.
F_A="$TMP/resv-a"; build_reservation_fixture "$F_A" "$MIXED_NORM" normalized "$MIXED_NORM"
if out="$(run_validator "$F_A")" && grep -q '^REVIEW_CONTEXT_OK ' <<<"$out"; then
  ok "P2a: normalized tasks.md entry accepted when the precheck declares it"
else
  fail "P2a: normalized entry rejected: $out"
fi

# (f) the WFI property at reservation time: a status flip after the precheck
# does not break the declared binding.
sed -i.bak 's/^Status: Planned$/Status: In Progress/' "$F_A/specs/$FEATURE/tasks.md"; rm -f "$F_A/specs/$FEATURE"/*.bak
if out="$(run_validator "$F_A")" && grep -q '^REVIEW_CONTEXT_OK ' <<<"$out"; then
  ok "P2f: the normalized binding survives a post-precheck status flip"
else
  fail "P2f: status flip broke the normalized binding: $out"
fi

# (e) ...but a body edit still fails: the entry binds every other byte.
printf 'body edit\n' >> "$F_A/specs/$FEATURE/tasks.md"
if out="$(run_validator "$F_A")"; then
  fail "P2e: body edit accepted under a normalized binding"
else
  grep -q 'does not normalize to the declared digest' <<<"$out" \
    && ok "P2e: body edit rejected — the normalized entry still binds bytes" \
    || fail "P2e: body edit rejected for the wrong reason: $out"
fi

# (b) the old-way manifest (fresh raw digest) against a normalized precheck is
# rejected at reservation by round consistency — the two halves cannot drift.
F_B="$TMP/resv-b"; build_reservation_fixture "$F_B" "$MIXED_RAW" normalized "$MIXED_NORM"
if out="$(run_validator "$F_B")"; then
  fail "P2b: fresh-raw manifest accepted against a normalized precheck"
else
  grep -q 'did not pin' <<<"$out" \
    && ok "P2b: fresh-raw manifest rejected at reservation (round consistency)" \
    || fail "P2b: fresh-raw manifest rejected for the wrong reason: $out"
fi

# (d) a normalized digest claimed while the precheck recorded raw: rejected.
F_D="$TMP/resv-d"; build_reservation_fixture "$F_D" "$MIXED_NORM" raw "$MIXED_RAW"
if out="$(run_validator "$F_D")"; then
  fail "P2d: normalized entry accepted although the precheck declared raw"
else
  grep -q 'hash mismatch' <<<"$out" \
    && ok "P2d: normalized entry rejected when the precheck declared raw" \
    || fail "P2d: rejected for the wrong reason: $out"
fi

# (c) the exception is scoped to tasks.md: any other entry keeps raw-only.
F_C="$TMP/resv-c"; build_reservation_fixture "$F_C" "$MIXED_NORM" normalized "$MIXED_NORM"
printf 'requirements body\n' > "$F_C/specs/$FEATURE/requirements.md"
jq --arg feature "$FEATURE" --arg bogus "$MIXED_NORM" \
  '.allowed_input_manifest += [{path:("specs/"+$feature+"/requirements.md"),sha256:$bogus}]' \
  "$F_C/manifest.json" > "$F_C/manifest.tmp" && mv "$F_C/manifest.tmp" "$F_C/manifest.json"
if out="$(run_validator "$F_C")"; then
  fail "P2c: a non-tasks.md entry with a non-raw digest was accepted"
else
  grep -q 'hash mismatch: specs/'"$FEATURE"'/requirements.md' <<<"$out" \
    && ok "P2c: the exception is unusable for any entry but the task plan" \
    || fail "P2c: rejected for the wrong reason: $out"
fi

# ---------------------------------------------------------------------------
# P3 — the accepting side (check-workflow-state.sh, code untouched by this
# WFI): normalized-recorded evidence survives a status flip; raw-recorded
# evidence (the only form the pre-WFI-025 precheck could emit) does not.
# ---------------------------------------------------------------------------
CHECKER="$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.sh"
make_ws_fixture() {
  local target="$TMP/ws-$1"
  rm -rf "$target"
  mkdir -p "$target/specs" "$target/reports/spec-review" "$target/reports/impl-review" "$target/reports/task-review"
  mkdir -p "$target/plugins/sdd-review-loop/references" "$target/plugins/sdd-quality-loop/references"
  cp "$ROOT/plugins/sdd-review-loop/references/spec-review-calibration.md" \
    "$ROOT/plugins/sdd-review-loop/references/reviewer-calibration.md" \
    "$target/plugins/sdd-review-loop/references/"
  cp "$ROOT/plugins/sdd-quality-loop/references/risk-gate-matrix.md" \
    "$ROOT/plugins/sdd-quality-loop/references/risk-classification-policy.md" \
    "$target/plugins/sdd-quality-loop/references/" 2>/dev/null || true
  cp -R "$ROOT/specs/workflow-state-integrity" "$target/specs/"
  cp -R "$ROOT/reports/spec-review/workflow-state-integrity" "$target/reports/spec-review/"
  cp -R "$ROOT/reports/impl-review/workflow-state-integrity" "$target/reports/impl-review/"
  cp -R "$ROOT/reports/task-review/workflow-state-integrity" "$target/reports/task-review/"
  while IFS= read -r evidence; do
    sed -i.bak "s#$ROOT#$target#g" "$evidence"; rm -f "$evidence.bak"
  done < <(find "$target/reports" -type f \
    \( -name '*-review-contract.json' -o -name 'reviewer-a.json' -o -name 'reviewer-b.json' \))
  # Force the full profile and drop any legacy grandfathering, as
  # tests/workflow-state.tests.sh does — a legacy entry skips exactly the
  # provenance checks this suite exists to exercise.
  jq '{schema_version, migration_baseline_commit,
       entries: [.entries[] | select(.feature == "workflow-state-integrity") | .profile="full" | del(.legacy)]}' \
    "$ROOT/specs/workflow-state-registry.json" > "$target/specs/workflow-state-registry.json"
  printf '%s\n' "$target"
}
# Rebind the task contract (top-level hash + every reviewer manifest entry)
# to the given digest of the fixture's tasks.md.
# Rewrite every task-review artifact's pin of one manifest path — the
# contract's reviewers' manifests and the reviewer outputs' own echoed
# manifests (the stage-provenance check cross-compares them all); when the
# path is the task plan, also the contract's top-level tasks_sha256.
rebind_manifest_entry() {
  local target="$1" suffix="$2" digest="$3" artifact
  while IFS= read -r artifact; do
    jq --arg suffix "$suffix" --arg digest "$digest" '
      (if (has("tasks_sha256") and ($suffix | endswith("tasks.md"))) then .tasks_sha256 = $digest else . end)
      | (if has("allowed_input_manifest") then
           .allowed_input_manifest |= map(
             if (.path | endswith($suffix)) then .sha256 = $digest else . end)
         else . end)
      | (if has("reviewers") then
           .reviewers |= map(
             (.allowed_input_manifest // []) |= map(
               if (.path | endswith($suffix)) then .sha256 = $digest else . end))
         else . end)
      | (if (has("manifest") and (.manifest | type == "array")) then
           .manifest |= map(
             if (.path | endswith($suffix)) then .sha256 = $digest else . end)
         else . end)
      | (if (has("manifest") and (.manifest | type == "object") and (.manifest | has("allowed_inputs"))) then
           .manifest.allowed_inputs |= map(
             if (.path | endswith($suffix)) then .sha256 = $digest else . end)
         else . end)
    ' "$artifact" > "$artifact.tmp" && mv "$artifact.tmp" "$artifact"
  done < <(find "$target/reports/task-review" -type f \
    \( -name 'task-review-contract.json' -o -name 'reviewer-a.json' -o -name 'reviewer-b.json' \))
}
rebind_task_contract() {
  local target="$1" digest="$2"
  rebind_manifest_entry "$target" "specs/workflow-state-integrity/tasks.md" "$digest"
  # Hermetic fixture: the committed contracts pin two
  # plugins/sdd-quality-loop/references/ files at hashes older than the live
  # tree, which the checker reconciles via its git pin-commit fallback.
  # That fallback needs FULL history — it passes locally and in full-depth
  # checkouts but fails in a shallow CI clone (git show HEAD: yields current
  # content, not the recorded generation's). This suite is about the task
  # plan's binding, not those pins, so rebind them to the live copies the
  # fixture ships and drop the history dependence entirely.
  local ref
  for ref in plugins/sdd-quality-loop/references/risk-gate-matrix.md \
             plugins/sdd-quality-loop/references/risk-classification-policy.md; do
    rebind_manifest_entry "$target" "$ref" "$(sha_file "$ROOT/$ref")"
  done
}
# Flip the first REMAINING 'Status: Done' line (awk, not GNU-sed 0,/re/ —
# the suite also runs on BSD sed hosts). Calling twice flips two tasks.
flip_one_done() {
  local file="$1/specs/workflow-state-integrity/tasks.md"
  awk 'f==0 && /^Status: Done$/ { print "Status: Implementation Complete"; f=1; next } { print }' \
    "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# The committed fixture is a COMPLETED epic: uniformly Done, so its raw bytes
# coincide with the accepting side's re-review form and a raw binding would
# accidentally survive — exactly the accidental invariance the WFI's Root
# Cause names. Flip one task FIRST so both bindings are made over the
# ordinary MID-FLIGHT (mixed) state the WFI is about, then flip a second
# task as the post-binding lifecycle transition.
WS_NORM="$(make_ws_fixture norm)"
flip_one_done "$WS_NORM"
NORM_DIGEST="$(norm_hash "$WS_NORM/specs/workflow-state-integrity/tasks.md")"
rebind_task_contract "$WS_NORM" "$NORM_DIGEST"
if bash "$CHECKER" --registry "$WS_NORM/specs/workflow-state-registry.json" >/dev/null 2>&1; then
  ok "P3: normalized-recorded mid-flight evidence passes the unchanged checker"
else
  fail "P3: normalized-recorded mid-flight evidence rejected before any flip"
fi
flip_one_done "$WS_NORM"
if bash "$CHECKER" --registry "$WS_NORM/specs/workflow-state-registry.json" >/dev/null 2>&1; then
  ok "P3: the normalized binding SURVIVES a lifecycle flip (the WFI-025 property)"
else
  fail "P3: the normalized binding broke on a lifecycle flip"
fi

WS_RAW="$(make_ws_fixture raw)"
flip_one_done "$WS_RAW"
RAW_DIGEST="$(sha_file "$WS_RAW/specs/workflow-state-integrity/tasks.md")"
rebind_task_contract "$WS_RAW" "$RAW_DIGEST"
bash "$CHECKER" --registry "$WS_RAW/specs/workflow-state-registry.json" >/dev/null 2>&1 ||
  die "P3 control setup: raw-recorded mid-flight evidence should pass before the flip"
flip_one_done "$WS_RAW"
if bash "$CHECKER" --registry "$WS_RAW/specs/workflow-state-registry.json" >/dev/null 2>&1; then
  fail "P3 control: raw binding unexpectedly survived the flip (test cannot discriminate)"
else
  ok "P3 control: the raw mid-flight binding (all a pre-WFI-025 precheck could emit) breaks on the same flip"
fi

echo ""
echo "task-plan-binding-durability.tests.sh: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
