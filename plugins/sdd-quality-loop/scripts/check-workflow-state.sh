#!/usr/bin/env bash
# Validate the repository-wide SDD workflow state. Diagnostics are API-stable.
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd -P)"
REGISTRY="$SCRIPT_ROOT/specs/workflow-state-registry.json"
FEATURE_FILTER=""

diagnostic() {
  printf 'workflow-state: %s: %s: %s\n' "$1" "$2" "$3" >&2
  exit 1
}
sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}
sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else shasum -a 256 | awk '{print $1}'; fi
}

while (($#)); do
  case "$1" in
    --feature)
      (($# >= 2)) || diagnostic repository cli-usage "--feature requires a value"
      FEATURE_FILTER="$2"; shift 2 ;;
    --registry)
      (($# >= 2)) || diagnostic repository cli-usage "--registry requires a value"
      REGISTRY="$2"; shift 2 ;;
    *) diagnostic repository cli-usage "unknown argument: $1" ;;
  esac
done
[[ -z "$FEATURE_FILTER" || "$FEATURE_FILTER" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
  diagnostic "$FEATURE_FILTER" cli-usage "invalid feature slug"
[[ -f "$REGISTRY" && ! -L "$REGISTRY" && -r "$REGISTRY" ]] ||
  diagnostic repository registry-unreadable "registry is missing, linked, or unreadable"
jq -e . "$REGISTRY" >/dev/null 2>&1 ||
  diagnostic repository registry-malformed "registry is not valid JSON"
jq -e '
  .schema_version == 1 and
  (.entries | type == "array" and length > 0) and
  all(.entries[];
    (.feature | type == "string" and test("^[a-z0-9][a-z0-9-]*$")) and
    (.profile == "full" or .profile == "lite" or .profile == "legacy"))
' "$REGISTRY" >/dev/null 2>&1 ||
  diagnostic repository registry-malformed "registry shape or version is invalid"
SCHEMA="$SCRIPT_ROOT/contracts/workflow-state-registry.schema.json"
[[ -f "$SCHEMA" ]] || diagnostic repository registry-schema "registry schema is unavailable"
jq -e --slurpfile schema "$SCHEMA" '
  (keys | sort) == ["entries","migration_baseline_commit","schema_version"] and
  .schema_version == $schema[0].properties.schema_version.const and
  .migration_baseline_commit == $schema[0].properties.migration_baseline_commit.const and
  (.entries | type == "array" and length > 0) and
  all(.entries[];
    if .profile == "full" or .profile == "lite" then
      (keys | sort) == ["feature","profile"]
    else
      . as $entry |
      any($schema[0].definitions.legacyEntry.oneOf[]; .const == $entry)
    end)
' "$REGISTRY" >/dev/null 2>&1 ||
  diagnostic repository registry-schema "registry entry violates the bounded schema"

SPECS_ROOT="$(cd "$(dirname "$REGISTRY")" && pwd -P)"
REPO_ROOT="$(cd "$SPECS_ROOT/.." && pwd -P)"
REPO_ROOT_ALIAS="$REPO_ROOT"
case "$REPO_ROOT" in
  /private/var/*) REPO_ROOT_ALIAS="/var/${REPO_ROOT#/private/var/}" ;;
  /var/*) REPO_ROOT_ALIAS="/private/var/${REPO_ROOT#/var/}" ;;
esac

duplicate="$(jq -r '[.entries[].feature] | group_by(.)[] | select(length > 1) | .[0]' "$REGISTRY" | head -1)"
[[ -z "$duplicate" ]] || diagnostic "$duplicate" registry-duplicate "feature is registered more than once"
while IFS= read -r feature; do
  candidate="$SPECS_ROOT/$feature"
  [[ -e "$candidate" || -L "$candidate" ]] ||
    diagnostic "$feature" registry-dangling-entry "registered specification directory is missing"
  resolved="$(cd "$candidate" 2>/dev/null && pwd -P)" ||
    diagnostic "$feature" registry-unreadable-path "registered directory cannot be resolved"
  case "$resolved/" in "$SPECS_ROOT/"*) ;; *)
    diagnostic "$feature" registry-path-escape "registered directory escapes specs root" ;;
  esac
  [[ ! -L "$candidate" ]] ||
    diagnostic "$feature" registry-linked-entry "registered specification directory must not be linked"
done < <(jq -r '.entries[].feature' "$REGISTRY")
for candidate in "$SPECS_ROOT"/*; do
  [[ -d "$candidate" || -L "$candidate" ]] || continue
  feature="$(basename "$candidate")"
  jq -e --arg feature "$feature" 'any(.entries[]; .feature == $feature)' "$REGISTRY" >/dev/null ||
    diagnostic "$feature" registry-unregistered-directory "specification directory is not registered"
done
if [[ -n "$FEATURE_FILTER" ]]; then
  jq -e --arg feature "$FEATURE_FILTER" 'any(.entries[]; .feature == $feature)' "$REGISTRY" >/dev/null ||
    diagnostic "$FEATURE_FILTER" registry-unknown-feature "feature is not registered"
fi

header_value() {
  local file="$1" header="$2"
  sed -n "s/^${header}:[[:space:]]*\\([^[:space:]\r]*\\).*/\\1/p" "$file" | head -1
}
normalized_hash() {
  local file="$1" stage="$2"
  local cr=""
  case "$stage" in
    spec)
      LC_ALL=C grep -q $'^Spec-Review-Status:.*\r$' "$file" && cr=$'\r'
      sed "s/^Spec-Review-Status:[[:space:]]*.*/Spec-Review-Status: Pending${cr}/" "$file" | sha256_stream ;;
    impl)
      LC_ALL=C grep -q $'^Impl-Review-Status:.*\r$' "$file" && cr=$'\r'
      sed "s/^Impl-Review-Status:[[:space:]]*.*/Impl-Review-Status: Pending${cr}/" "$file" | sha256_stream ;;
    task)
      LC_ALL=C grep -q $'^Task-Review-Status:.*\r$' "$file" && cr=$'\r'
      sed \
        -e "s/^Task-Review-Status:[[:space:]]*.*/Task-Review-Status: Pending${cr}/" \
        -e "s/^Approval:[[:space:]]*.*/Approval: Draft${cr}/" \
        -e "s/^Status:[[:space:]]*.*/Status: Planned${cr}/" "$file" | sha256_stream ;;
  esac
}
manifest_has_hash() {
  local contract="$1" suffix="$2" expected="$3" recorded_root="$4"
  jq -e --arg suffix "$suffix" --arg expected "$expected" \
    --arg repo "$REPO_ROOT/" --arg alias "$REPO_ROOT_ALIAS/" \
    --arg recorded "${recorded_root:+$recorded_root/}" '
    def relative_path:
      gsub("\\\\"; "/") |
      if startswith($repo) then .[($repo|length):]
      elif startswith($alias) then .[($alias|length):]
      elif ($recorded != "" and startswith($recorded)) then .[($recorded|length):]
      elif test("^(/|[A-Za-z]:/)") then null
      else . end;
    ($suffix | ltrimstr("/")) as $target |
    all(.reviewers[]?;
      any(.allowed_input_manifest[]?;
        (.path | type == "string" and relative_path == $target) and .sha256 == $expected))
  ' "$contract" >/dev/null
}
recorded_repo_root() {
  local contract="$1" repo_name
  repo_name="$(basename "$REPO_ROOT")"
  jq -r --arg repo "$REPO_ROOT/" --arg alias "$REPO_ROOT_ALIAS/" \
    --arg marker "/$repo_name/" '
    def normalized: gsub("\\\\"; "/");
    def rooted: test("^(/|[A-Za-z]:/)");
    [.reviewers[].allowed_input_manifest[].path |
      normalized |
      select(rooted and (startswith($repo) or startswith($alias) | not)) |
      . as $path |
      ($path | rindex($marker)) as $index |
      if $index == null then null
      else $path[0:($index + ($marker | length) - 1)]
      end] as $roots |
    if any($roots[]; . == null) or ($roots | map(select(. != null)) | unique | length) > 1
    then "__INVALID__"
    else ($roots | map(select(. != null)) | unique | .[0] // "")
    end
  ' "$contract"
}
validate_passed_stage() {
  local feature="$1" stage="$2" feature_dir="$3"
  local root="$REPO_ROOT/reports/${stage}-review/$feature"
  [[ -d "$root" && ! -L "$root" ]] ||
    diagnostic "$feature" stage-provenance "$stage PASS has no review report root"
  local best="" best_attempt=0 best_round=0 candidate relative attempt round
  while IFS= read -r candidate; do
    [[ ! -L "$candidate" && -f "$candidate" ]] ||
      diagnostic "$feature" stage-provenance "$stage verdict evidence is linked or unreadable"
    relative="${candidate#"$root/"}"
    [[ "$relative" =~ ^attempt-([1-9][0-9]*)/round-([1-9][0-9]*)/integrated-verdict\.json$ ]] ||
      diagnostic "$feature" stage-provenance "$stage verdict has a noncanonical path"
    attempt="${BASH_REMATCH[1]}"; round="${BASH_REMATCH[2]}"
    if ((attempt > best_attempt || (attempt == best_attempt && round > best_round))); then
      best="$candidate"; best_attempt="$attempt"; best_round="$round"
    fi
  done < <(find "$root" -name integrated-verdict.json -print)
  [[ -n "$best" ]] || diagnostic "$feature" stage-provenance "$stage PASS has no integrated verdict"
  local contract="$(dirname "$best")/${stage}-review-contract.json"
  local round_dir="$(dirname "$best")"
  local reviewer_a="$round_dir/reviewer-a.json"
  local reviewer_b="$round_dir/reviewer-b.json"
  local summary="$round_dir/integrated-summary.json"
  [[ -f "$contract" && ! -L "$contract" && -r "$contract" ]] ||
    diagnostic "$feature" stage-provenance "$stage PASS has no readable review contract"
  for candidate in "$reviewer_a" "$reviewer_b" "$summary"; do
    [[ -f "$candidate" && ! -L "$candidate" && -r "$candidate" ]] ||
      diagnostic "$feature" stage-provenance "$stage reviewer evidence is missing, linked, or unreadable"
    jq -e . "$candidate" >/dev/null 2>&1 ||
      diagnostic "$feature" stage-provenance "$stage reviewer evidence is malformed"
  done
  jq -e --arg feature "$feature" --arg stage "$stage" \
    --argjson attempt "$best_attempt" --argjson round "$best_round" '
    .feature == $feature and .stage == $stage and .attempt == $attempt and
    .round == $round and
    (.verdict == "PASS" or ($stage != "spec" and .verdict == "PASS-with-warnings")) and
    (if $stage == "spec" then
      .schema == "spec-review-integrated-verdict/v1" and
      ([.reviewer_a_run_id,.reviewer_b_run_id,.reviewer_a_host_session_id,.reviewer_b_host_session_id]
       | all(type == "string" and length > 0)) and
      .reviewer_a_run_id != .reviewer_b_run_id and
      .reviewer_a_host_session_id != .reviewer_b_host_session_id
     else
      .schema == "integrated-verdict/v1" and
      (.run_id | type == "string" and length > 0) and
      (.reviewer_a_verdict == "PASS" or .reviewer_a_verdict == "NEEDS_WORK") and
      (.reviewer_b_verdict == "PASS" or .reviewer_b_verdict == "NEEDS_WORK") and
      .findings_critical == 0 and .findings_major == 0 and
      (.findings_minor | type == "number" and . >= 0)
     end)
  ' "$best" >/dev/null 2>&1 ||
    diagnostic "$feature" stage-provenance "$stage integrated verdict is not a valid PASS"
  jq -e --arg feature "$feature" --arg stage "$stage" \
    --argjson attempt "$best_attempt" --argjson round "$best_round" '
    .schema == ($stage + "-review-contract/v1") and .feature == $feature and
    .stage == $stage and .attempt == $attempt and .round == $round and
    (.verdict == "PASS" or ($stage != "spec" and .verdict == "PASS-with-warnings")) and
    (.run_id | type == "string" and length > 0) and
    ($stage == "spec" or
      ((.reviewer_a_verdict == "PASS" or .reviewer_a_verdict == "NEEDS_WORK") and
       (.reviewer_b_verdict == "PASS" or .reviewer_b_verdict == "NEEDS_WORK") and
       .findings_critical == 0 and .findings_major == 0 and
       (.findings_minor | type == "number" and . >= 0))) and
    ([.reviewers[]?.role] | sort) == [($stage+"-reviewer-a"),($stage+"-reviewer-b")] and
    ([.reviewers[]?.run_id] | all(type == "string" and length > 0) and (unique|length)==2) and
    ([.reviewers[]?.host_session_id] | all(type == "string" and length > 0) and (unique|length)==2)
  ' "$contract" >/dev/null 2>&1 ||
    diagnostic "$feature" stage-provenance "$stage review contract identity is invalid"
  local recorded_root
  recorded_root="$(recorded_repo_root "$contract")"
  [[ "$recorded_root" != "__INVALID__" ]] ||
    diagnostic "$feature" stage-provenance "$stage reviewer manifest paths are not canonical"
  jq -e --arg feature "$feature" --arg stage "$stage" \
    --arg repo "$REPO_ROOT/" --arg alias "$REPO_ROOT_ALIAS/" \
    --arg recorded "${recorded_root:+$recorded_root/}" \
    --argjson attempt "$best_attempt" --argjson round "$best_round" '
    def relative_path:
      gsub("\\\\"; "/") |
      if startswith($repo) then .[($repo|length):]
      elif startswith($alias) then .[($alias|length):]
      elif ($recorded != "" and startswith($recorded)) then .[($recorded|length):]
      elif test("^(/|[A-Za-z]:/)") then null
      else . end;
    def allowed($role; $path):
      ("reports/" + $stage + "-review/" + $feature + "/attempt-" + ($attempt|tostring)) as $attempt_root |
      ($attempt_root + "/round-" + ($round|tostring)) as $round_root |
      ($path == ("specs/" + $feature + "/requirements.md")) or
      ($path == ("specs/" + $feature + "/acceptance-tests.md")) or
      ($path == ("specs/" + $feature + "/investigation.md")) or
      ($stage == "impl" and $path == ("specs/" + $feature + "/design.md")) or
      ($stage == "task" and
        ($path == ("specs/" + $feature + "/tasks.md") or
         $path == ("specs/" + $feature + "/traceability.md"))) or
      ($path == (if $stage == "spec" then
                   "plugins/sdd-review-loop/references/spec-review-calibration.md"
                 else "plugins/sdd-review-loop/references/reviewer-calibration.md" end)) or
      ($path == ($round_root + "/precheck-result.json")) or
      ($role == ($stage + "-reviewer-b") and $path == ($round_root + "/integrated-summary.json")) or
      ($stage == "impl" and $role == "impl-reviewer-a" and $round > 1 and
       $path == ($attempt_root + "/round-" + (($round-1)|tostring) + "/integrated-summary.json")) or
      ($stage == "task" and $role == "task-reviewer-a" and
       $path == ($round_root + "/dependency-graph.json")) or
      ($stage == "task" and $role == "task-reviewer-b" and
       ($path == "plugins/sdd-quality-loop/references/risk-gate-matrix.md" or
        $path == "plugins/sdd-quality-loop/references/risk-classification-policy.md"));
    all(.reviewers[];
      .role as $role |
      ([.allowed_input_manifest[].path | relative_path] as $paths |
       ($paths | all(. != null and (test("(^|/)\\.\\.?(/|$)")|not))) and
       ($paths | length) == ($paths | unique | length) and
       all($paths[]; allowed($role; .))))
  ' "$contract" >/dev/null 2>&1 ||
    diagnostic "$feature" stage-provenance "$stage reviewer manifest paths are not canonical"
  while IFS=$'\t' read -r manifest_path manifest_hash; do
    manifest_path="${manifest_path//\\//}"
    if [[ -n "$recorded_root" && "$manifest_path" == "$recorded_root/"* ]]; then
      manifest_relative="${manifest_path#"$recorded_root/"}"
      manifest_file="$REPO_ROOT/$manifest_relative"
    else
      case "$manifest_path" in
        "$REPO_ROOT"/*) manifest_file="$manifest_path"; manifest_relative="${manifest_path#"$REPO_ROOT/"}" ;;
        "$REPO_ROOT_ALIAS"/*)
          manifest_relative="${manifest_path#"$REPO_ROOT_ALIAS/"}"
          manifest_file="$REPO_ROOT/$manifest_relative" ;;
        /*|[A-Za-z]:/*) diagnostic "$feature" stage-provenance "$stage reviewer manifest path escapes repository" ;;
        *) manifest_file="$REPO_ROOT/$manifest_path"; manifest_relative="$manifest_path" ;;
      esac
    fi
    case "$manifest_relative" in
      "specs/$feature/requirements.md"|"specs/$feature/design.md"|"specs/$feature/tasks.md"|"specs/$feature/traceability.md"|"specs/$feature/acceptance-tests.md") continue ;;
    esac
    [[ -f "$manifest_file" && ! -L "$manifest_file" && -r "$manifest_file" ]] ||
      diagnostic "$feature" stage-provenance "$stage reviewer manifest input is missing or unreadable"
    [[ "$(sha256_file "$manifest_file")" == "$manifest_hash" ]] ||
      diagnostic "$feature" stage-provenance "$stage reviewer manifest input hash is stale"
  done < <(jq -r '.reviewers[].allowed_input_manifest[] | .path + "\t" + .sha256' "$contract")
  jq -e --slurpfile verdict "$best" --arg stage "$stage" '
    .attempt == $verdict[0].attempt and .round == $verdict[0].round and
    .verdict == $verdict[0].verdict and
    (if $stage == "spec" then
      (.reviewers|map({key:.role,value:{run_id:.run_id,host:.host_session_id}})|from_entries) as $r |
      $r["spec-reviewer-a"].run_id == $verdict[0].reviewer_a_run_id and
      $r["spec-reviewer-b"].run_id == $verdict[0].reviewer_b_run_id and
      $r["spec-reviewer-a"].host == $verdict[0].reviewer_a_host_session_id and
      $r["spec-reviewer-b"].host == $verdict[0].reviewer_b_host_session_id
     else .run_id == $verdict[0].run_id end)
  ' "$contract" >/dev/null 2>&1 ||
    diagnostic "$feature" stage-provenance "$stage contract and verdict contradict each other"

  jq -e --slurpfile contract "$contract" --slurpfile verdict "$best" \
    --slurpfile reviewer_b "$reviewer_b" --slurpfile summary "$summary" --arg stage "$stage" \
    --argjson attempt "$best_attempt" --argjson round "$best_round" '
    def normalized_manifest:
      map({path: .path, sha256: .sha256}) | sort_by(.path, .sha256);
    def reviewer_contract($role):
      $contract[0].reviewers[] | select(.role == $role);
    def check_result:
      if $stage == "task" then .status else .result end;
    def failures($reviewer):
      if $stage == "task" then [$reviewer.findings[]?]
      else [$reviewer.checks[]? | select(.result == "FAIL")] end;
    def expected_reviewer_verdict($reviewer):
      failures($reviewer) as $f |
      if any($f[]?; .severity == "Critical") then "BLOCKED"
      elif ($f | length) > 0 then "NEEDS_WORK"
      else "PASS" end;
    . as $a |
    $reviewer_b[0] as $b |
    (if $stage == "task" then
       ($a.schema == "task-reviewer-a/v1" and $a.stage == "task-review" and
        $a.role == "reviewer-a" and $b.schema == "task-reviewer-b/v1" and
        $b.stage == "task" and $b.role == "task-reviewer-b" and
        $a.feature == $contract[0].feature and $b.feature == $contract[0].feature and
        $a.attempt == $attempt and $b.attempt == $attempt and
        $a.round == $round and $b.round == $round)
     else
       ($a.schema == ($stage + "-reviewer-a/v1") and $a.stage == $stage and
        $a.role == ($stage + "-reviewer-a") and
        $b.schema == ($stage + "-reviewer-b/v1") and $b.stage == $stage and
        $b.role == ($stage + "-reviewer-b"))
     end) and
    ([$a.run_id,$a.host_session_id,$b.run_id,$b.host_session_id]
      | all(type == "string" and length > 0)) and
    $a.run_id == reviewer_contract($stage + "-reviewer-a").run_id and
    $a.host_session_id == reviewer_contract($stage + "-reviewer-a").host_session_id and
    $b.run_id == reviewer_contract($stage + "-reviewer-b").run_id and
    $b.host_session_id == reviewer_contract($stage + "-reviewer-b").host_session_id and
    ((if $stage == "task" then $a.manifest else $a.allowed_input_manifest end)
      | normalized_manifest) ==
      (reviewer_contract($stage + "-reviewer-a").allowed_input_manifest | normalized_manifest) and
    ((if $stage == "task" then $b.manifest.allowed_inputs else $b.allowed_input_manifest end)
      | normalized_manifest) ==
      (reviewer_contract($stage + "-reviewer-b").allowed_input_manifest | normalized_manifest) and
    $a.verdict == expected_reviewer_verdict($a) and
    $b.verdict == expected_reviewer_verdict($b) and
    (failures($a) + failures($b) |
      all(.severity == "Critical" or .severity == "Major" or .severity == "Minor")) and
    (if $stage == "task" then
       ([$a.checks[] | select(.status == "FAIL")] | length) == ($a.findings | length) and
       ([$b.checks[] | select(.result == "FAIL")] | length) == ($b.findings | length)
     else true end) and
    ($summary[0].schema == "integrated-summary/v1" and
     $summary[0].attempt == $attempt and $summary[0].round == $round) and
    ([$a.checks[] | .id] | sort) ==
      ((if $stage == "spec" then [$summary[0].reviewer_a_checks[] | .id]
        else $summary[0].reviewer_a_check_ids end) | sort) and
    ([$a.checks[] | select(check_result == "FAIL")] | length) ==
      $summary[0].reviewer_a_fail_count and
    ([$a.checks[] | select(check_result == "PASS")] | length) ==
      $summary[0].reviewer_a_pass_count and
    ([$a.checks[] | select(check_result == "SKIP")] | length) ==
      $summary[0].reviewer_a_skip_count and
    (failures($a) + failures($b)) as $findings |
    {critical: ([$findings[] | select(.severity == "Critical")] | length),
     major: ([$findings[] | select(.severity == "Major")] | length),
     minor: ([$findings[] | select(.severity == "Minor")] | length)} as $counts |
    ($counts.critical == 0 and $counts.major == 0 and
     ($counts.minor == 0 or $round == 3)) and
    (if $stage == "spec" then
       $contract[0].verdict == "PASS" and
       $contract[0].warningCount == $counts.minor and
       $verdict[0].verdict == "PASS" and
       $verdict[0].warningCount == $counts.minor and
       $verdict[0].finding_counts == $counts
     else
       ($counts.minor == 0 and $contract[0].verdict == "PASS" and
        $verdict[0].verdict == "PASS" or
        $counts.minor > 0 and $contract[0].verdict == "PASS-with-warnings" and
        $verdict[0].verdict == "PASS-with-warnings") and
       $contract[0].findings_critical == $counts.critical and
       $contract[0].findings_major == $counts.major and
       $contract[0].findings_minor == $counts.minor and
       $verdict[0].findings_critical == $counts.critical and
       $verdict[0].findings_major == $counts.major and
       $verdict[0].findings_minor == $counts.minor and
       $contract[0].reviewer_a_verdict == $a.verdict and
       $contract[0].reviewer_b_verdict == $b.verdict and
       $verdict[0].reviewer_a_verdict == $a.verdict and
       $verdict[0].reviewer_b_verdict == $b.verdict
     end)
  ' "$reviewer_a" >/dev/null 2>&1 ||
    diagnostic "$feature" stage-provenance "$stage reviewer outputs or integrated summary contradict the final PASS"

  local req="$feature_dir/requirements.md" accept="$feature_dir/acceptance-tests.md"
  local req_hash accept_hash
  [[ -f "$req" && -f "$accept" && ! -L "$req" && ! -L "$accept" ]] ||
    diagnostic "$feature" stage-provenance "$stage canonical inputs are missing"
  accept_hash="$(sha256_file "$accept")"
  if [[ "$stage" == spec ]]; then req_hash="$(normalized_hash "$req" spec)"
  else req_hash="$(sha256_file "$req")"; fi
  jq -e --arg stage "$stage" --arg req "$req_hash" --arg accept "$accept_hash" '
    .requirements_sha256 == $req and .acceptance_sha256 == $accept
  ' "$contract" >/dev/null 2>&1 ||
    diagnostic "$feature" stage-provenance "$stage top-level contract hashes are stale"
  manifest_has_hash "$contract" "/specs/$feature/requirements.md" "$req_hash" "$recorded_root" &&
    manifest_has_hash "$contract" "/specs/$feature/acceptance-tests.md" "$accept_hash" "$recorded_root" ||
    diagnostic "$feature" stage-provenance "$stage contract hashes are stale"
  local calibration precheck
  if [[ "$stage" == spec ]]; then
    calibration="$REPO_ROOT/plugins/sdd-review-loop/references/spec-review-calibration.md"
  else
    calibration="$REPO_ROOT/plugins/sdd-review-loop/references/reviewer-calibration.md"
  fi
  precheck="$root/attempt-$best_attempt/round-$best_round/precheck-result.json"
  [[ -f "$calibration" && ! -L "$calibration" && -f "$precheck" && ! -L "$precheck" ]] ||
    diagnostic "$feature" stage-provenance "$stage required review inputs are missing"
  manifest_has_hash "$contract" "/${calibration#"$REPO_ROOT/"}" "$(sha256_file "$calibration")" "$recorded_root" &&
    manifest_has_hash "$contract" "/${precheck#"$REPO_ROOT/"}" "$(sha256_file "$precheck")" "$recorded_root" ||
    diagnostic "$feature" stage-provenance "$stage reviewer manifests omit required inputs"
  if [[ "$stage" == impl ]]; then
    local design="$feature_dir/design.md"
    [[ -f "$design" && ! -L "$design" ]] ||
      diagnostic "$feature" stage-provenance "implementation design is missing"
    manifest_has_hash "$contract" "/specs/$feature/design.md" "$(normalized_hash "$design" impl)" "$recorded_root" ||
      diagnostic "$feature" stage-provenance "implementation design hash is stale"
    [[ "$(jq -r '.design_sha256 // empty' "$contract")" == "$(normalized_hash "$design" impl)" ]] ||
      diagnostic "$feature" stage-provenance "implementation top-level design hash is stale"
  elif [[ "$stage" == task ]]; then
    local tasks="$feature_dir/tasks.md"
    [[ -f "$tasks" && ! -L "$tasks" ]] ||
      diagnostic "$feature" stage-provenance "task plan is missing"
    manifest_has_hash "$contract" "/specs/$feature/tasks.md" "$(normalized_hash "$tasks" task)" "$recorded_root" ||
      diagnostic "$feature" stage-provenance "task plan hash is stale"
    [[ "$(jq -r '.tasks_sha256 // empty' "$contract")" == "$(normalized_hash "$tasks" task)" ]] ||
      diagnostic "$feature" stage-provenance "task top-level plan hash is stale"
  fi
}

validate_legacy() {
  local feature="$1" dir="$2" entry="$3" stage file header key value
  for stage in spec impl task; do
    case "$stage" in
      spec) file="$dir/requirements.md"; header="Spec-Review-Status"; key="spec_status" ;;
      impl) file="$dir/design.md"; header="Impl-Review-Status"; key="impl_status" ;;
      task) file="$dir/tasks.md"; header="Task-Review-Status"; key="task_status" ;;
    esac
    value=""; [[ -f "$file" ]] && value="$(header_value "$file" "$header")"
    if [[ -z "$value" ]]; then
      jq -e --arg stage "$stage" '.legacy.allowed_missing_stages | index($stage) != null' <<<"$entry" >/dev/null ||
        diagnostic "$feature" legacy-state "missing $stage status is not declared"
    else
      jq -e --arg key "$key" --arg value "$value" \
        '.legacy.allowed_noncanonical_statuses[$key] | index($value) != null' <<<"$entry" >/dev/null ||
        diagnostic "$feature" legacy-state "$stage status is broader than the migration record"
    fi
  done
  if [[ -f "$dir/tasks.md" ]]; then
    while IFS= read -r value; do
      value="${value#Approval: }"; value="${value%% (*}"
      jq -e --arg value "$value" '.legacy.allowed_task_approvals | index($value) != null' <<<"$entry" >/dev/null ||
        diagnostic "$feature" legacy-state "task approval is broader than the migration record"
    done < <(sed -n 's/^\(Approval:[[:space:]]*.*\r\{0,1\}\)$/\1/p' "$dir/tasks.md" | tr -d '\r')
    while IFS= read -r value; do
      value="${value#Status: }"
      jq -e --arg value "$value" '.legacy.allowed_task_statuses | index($value) != null' <<<"$entry" >/dev/null ||
        diagnostic "$feature" legacy-state "task lifecycle is broader than the migration record"
    done < <(sed -n 's/^\(Status:[[:space:]]*.*\r\{0,1\}\)$/\1/p' "$dir/tasks.md" | tr -d '\r')
  fi
}

while IFS= read -r entry; do
  feature="$(jq -r '.feature' <<<"$entry")"
  [[ -z "$FEATURE_FILTER" || "$feature" == "$FEATURE_FILTER" ]] || continue
  profile="$(jq -r '.profile' <<<"$entry")"
  dir="$SPECS_ROOT/$feature"
  [[ "$profile" == lite ]] && continue
  if [[ "$profile" == legacy ]]; then validate_legacy "$feature" "$dir" "$entry"; continue; fi
  for required in requirements.md design.md acceptance-tests.md; do
    [[ -f "$dir/$required" && ! -L "$dir/$required" && -r "$dir/$required" ]] ||
      diagnostic "$feature" stage-input "$required is missing, linked, or unreadable"
  done
  spec="$(header_value "$dir/requirements.md" Spec-Review-Status)"
  impl="$(header_value "$dir/design.md" Impl-Review-Status)"
  tasks="$dir/tasks.md"; task=""
  if [[ -e "$tasks" || -L "$tasks" ]]; then
    [[ -f "$tasks" && ! -L "$tasks" && -r "$tasks" ]] ||
      diagnostic "$feature" stage-input "tasks.md is linked or unreadable"
  fi
  [[ -f "$tasks" ]] && task="$(header_value "$tasks" Task-Review-Status)"
  [[ ! -f "$tasks" || -n "$task" ]] ||
    diagnostic "$feature" stage-status "tasks.md has no Task-Review-Status"
  [[ "$spec" == Pending || "$spec" == Passed ]] ||
    diagnostic "$feature" stage-status "Spec status is missing or invalid"
  [[ "$impl" == Pending || "$impl" == Passed ]] ||
    diagnostic "$feature" stage-status "Impl status is missing or invalid"
  [[ -z "$task" || "$task" == Pending || "$task" == Passed ]] ||
    diagnostic "$feature" stage-status "Task status is invalid"
  [[ "$impl" != Passed || "$spec" == Passed ]] ||
    diagnostic "$feature" stage-order "Impl Passed requires Spec Passed"
  [[ "$task" != Passed || ( "$spec" == Passed && "$impl" == Passed ) ]] ||
    diagnostic "$feature" stage-order "Task Passed requires Spec and Impl Passed"
  [[ ! -f "$tasks" || ( "$spec" == Passed && "$impl" == Passed ) ]] ||
    diagnostic "$feature" task-lifecycle "tasks.md requires Spec and Impl Passed"
  if [[ -f "$tasks" ]]; then
    approval_count=0; status_count=0
    while IFS= read -r value; do
      approval_count=$((approval_count + 1))
      case "$value" in
        Draft|Approved|"Approved ("*")") ;;
        *) diagnostic "$feature" task-lifecycle "task approval is invalid" ;;
      esac
    done < <(sed -n 's/^Approval:[[:space:]]*//p' "$tasks" | tr -d '\r')
    while IFS= read -r value; do
      status_count=$((status_count + 1))
      [[ "$value" == Planned || "$value" == "In Progress" ||
         "$value" == "Implementation Complete" || "$value" == Done ]] ||
        diagnostic "$feature" task-lifecycle "task status is invalid"
    done < <(sed -n 's/^Status:[[:space:]]*//p' "$tasks" | tr -d '\r')
    [[ "$approval_count" -gt 0 && "$approval_count" -eq "$status_count" ]] ||
      diagnostic "$feature" task-lifecycle "task lifecycle fields are incomplete"
  fi
  if [[ "$task" == Pending ]]; then
    while IFS= read -r value; do
      [[ "$value" == Draft ]] ||
        diagnostic "$feature" task-lifecycle "pending task review permits only Draft approvals"
    done < <(sed -n 's/^Approval:[[:space:]]*//p' "$tasks" | tr -d '\r')
    while IFS= read -r value; do
      [[ "$value" == Planned ]] ||
        diagnostic "$feature" task-lifecycle "pending task review permits only Planned statuses"
    done < <(sed -n 's/^Status:[[:space:]]*//p' "$tasks" | tr -d '\r')
  fi
  if [[ -f "$tasks" ]] && grep -Eq '^Status:[[:space:]]*(In Progress|Implementation Complete|Done)|^Approval:[[:space:]]*Approved' "$tasks"; then
    [[ "$spec" == Passed && "$impl" == Passed && "$task" == Passed ]] ||
      diagnostic "$feature" task-lifecycle "executable task state requires all reviews Passed"
  fi
  [[ "$spec" != Passed ]] || validate_passed_stage "$feature" spec "$dir"
  [[ "$impl" != Passed ]] || validate_passed_stage "$feature" impl "$dir"
  [[ "$task" != Passed ]] || validate_passed_stage "$feature" task "$dir"
done < <(jq -c '.entries[]' "$REGISTRY")

printf 'workflow-state: ok\n'
