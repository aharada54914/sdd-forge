#!/usr/bin/env bash
# Functions only. ROOT names the immutable source fixture repository; TMP is owned by caller.
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


materialize_workflow_state_case() {
  local case_name="$1" destination="$2" target TMP name round
  case "$case_name" in valid|stale|forged|invalid|boundary) ;; *) return 2 ;; esac
  [[ ! -e "$destination" && ! -L "$destination" ]] || return 2
  TMP="$(dirname "$destination")"
  name="$(basename "$destination")"
  target="$(make_full_fixture "$name")" || return
  case "$case_name" in
    stale) printf '\nStale mutation.\n' >> "$target/specs/workflow-state-integrity/design.md" ;;
    forged)
      round="$(latest_task_round_dir "$target")" || return
      jq '.feature = "other-feature"' "$round/task-review-contract.json" > "$target/contract.tmp"
      mv "$target/contract.tmp" "$round/task-review-contract.json" ;;
    invalid) printf '{invalid json\n' > "$target/specs/workflow-state-registry.json" ;;
    boundary)
      jq '.entries = []' "$target/specs/workflow-state-registry.json" > "$target/registry.tmp"
      mv "$target/registry.tmp" "$target/specs/workflow-state-registry.json" ;;
  esac
  printf '%s\n' "$target"
}
