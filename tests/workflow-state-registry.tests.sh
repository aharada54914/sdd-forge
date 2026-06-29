#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY="${1:-$ROOT/specs/workflow-state-registry.json}"
SCHEMA="$ROOT/contracts/workflow-state-registry.schema.json"
RETROSPECTIVE="$ROOT/specs/uninstall-workflow/retrospective.md"
BASELINE="0369c8c96de2eb3179868d1949d66644488f65aa"

fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }

validate_registered_path() {
  feature="$1"
  specs_root="$2"
  candidate="$specs_root/$feature"
  if [[ ! -e "$candidate" && ! -L "$candidate" ]]; then
    printf 'workflow-state: %s: registry-dangling-entry: registered directory is missing\n' "$feature" >&2
    return 1
  fi
  resolved="$(cd "$candidate" 2>/dev/null && pwd -P)" || {
    printf 'workflow-state: %s: registry-unreadable-path: registered directory cannot be resolved\n' "$feature" >&2
    return 1
  }
  root_resolved="$(cd "$specs_root" && pwd -P)"
  case "$resolved/" in
    "$root_resolved/"*) return 0 ;;
    *)
      printf 'workflow-state: %s: registry-path-escape: registered directory escapes specs root\n' "$feature" >&2
      return 1
      ;;
  esac
}

validate_registry_coverage() {
  registry="$1"
  specs_root="$2"
  duplicate="$(jq -r '[.entries[].feature] | group_by(.)[] | select(length > 1) | .[0]' "$registry" | head -1)"
  if [[ -n "$duplicate" ]]; then
    printf 'workflow-state: %s: registry-duplicate: feature is registered more than once\n' "$duplicate" >&2
    return 1
  fi
  while IFS= read -r feature; do
    validate_registered_path "$feature" "$specs_root" || return 1
  done < <(jq -r '.entries[].feature' "$registry")
  for candidate in "$specs_root"/*; do
    [[ -d "$candidate" || -L "$candidate" ]] || continue
    feature="$(basename "$candidate")"
    if ! jq -e --arg feature "$feature" 'any(.entries[]; .feature == $feature)' "$registry" >/dev/null; then
      printf 'workflow-state: %s: registry-unregistered-directory: specs directory is not registered\n' "$feature" >&2
      return 1
    fi
  done
}

if [[ "${1:-}" == "--coverage-fixture" ]]; then
  fixture="${2:-}"
  fixture_root="$(mktemp -d)"
  trap 'rm -rf "$fixture_root"' EXIT
  registry_fixture="$fixture_root/registry.json"
  case "$fixture" in
    duplicate)
      jq '.entries += [.entries[] | select(.feature == "workflow-state-integrity")]' "$ROOT/specs/workflow-state-registry.json" > "$registry_fixture"
      validate_registry_coverage "$registry_fixture" "$ROOT/specs"
      ;;
    dangling)
      jq '.entries += [{"feature":"ghost-feature","profile":"full"}]' "$ROOT/specs/workflow-state-registry.json" > "$registry_fixture"
      validate_registry_coverage "$registry_fixture" "$ROOT/specs"
      ;;
    unregistered)
      jq 'del(.entries[] | select(.feature == "workflow-state-integrity"))' "$ROOT/specs/workflow-state-registry.json" > "$registry_fixture"
      validate_registry_coverage "$registry_fixture" "$ROOT/specs"
      ;;
    symlink)
      mkdir -p "$fixture_root/specs" "$fixture_root/outside"
      ln -s "$fixture_root/outside" "$fixture_root/specs/escape"
      printf '%s\n' '{"entries":[{"feature":"escape","profile":"full"}]}' > "$registry_fixture"
      validate_registry_coverage "$registry_fixture" "$fixture_root/specs"
      ;;
    *) fail "unknown coverage fixture: $fixture" ;;
  esac
  fail "$fixture coverage fixture unexpectedly accepted"
fi

shell_schema_accepts() {
  jq -e --arg baseline "$BASELINE" --slurpfile schema "$SCHEMA" '
    def exact_keys($allowed): (keys | sort) == ($allowed | sort);
    def string_array($allowed):
      type == "array" and
      (all(.[]; type == "string" and ($allowed | index(.) != null))) and
      length == (unique | length);
    type == "object" and
    exact_keys(["schema_version", "migration_baseline_commit", "entries"]) and
    .schema_version == 1 and
    .migration_baseline_commit == $baseline and
    (.entries | type == "array" and length > 0) and
    all(.entries[];
      type == "object" and
      (.feature | type == "string" and test("^[a-z0-9][a-z0-9-]*$")) and
      if .profile == "full" or .profile == "lite" then
        exact_keys(["feature", "profile"])
      elif .profile == "legacy" then
        exact_keys(["feature", "profile", "legacy"]) and
        (.legacy |
          type == "object" and
          ((keys - ["introduced_before_commit", "reason", "owner",
                    "allowed_missing_stages", "allowed_noncanonical_statuses",
                    "allowed_task_approvals", "allowed_task_statuses",
                    "retrospective_sources"]) | length == 0) and
          has("introduced_before_commit") and has("reason") and has("owner") and
          has("allowed_missing_stages") and has("allowed_noncanonical_statuses") and
          has("allowed_task_approvals") and has("allowed_task_statuses") and
          .introduced_before_commit == $baseline and
          (.reason | type == "string" and length > 0 and contains("*") | not) and
          (.owner | type == "string" and length > 0 and contains("*") | not) and
          (.allowed_missing_stages | string_array(["spec", "impl", "task"])) and
          (.allowed_noncanonical_statuses |
            type == "object" and
            ((keys - ["spec_status", "impl_status", "task_status"]) | length == 0) and
            all(.[]; string_array(["Pending", "Passed"]))) and
          (.allowed_task_approvals | string_array(["Draft", "Approved"])) and
          (.allowed_task_statuses |
            string_array(["Planned", "In Progress", "Implementation Complete", "Done"])) and
          (if has("retrospective_sources") then
            .retrospective_sources | type == "array" and
            length == (unique | length) and
            all(.[]; type == "string" and
              test("^(?!.*(?:^|/)\\.\\.?(?:/|$))[a-zA-Z0-9][a-zA-Z0-9._/-]*$"))
          else true end)
        )
      else false end
    ) and
    ([.entries[] | select(.profile == "legacy")] | sort_by(.feature)) ==
    ([$schema[0].definitions.legacyEntry.oneOf[].const] | sort_by(.feature))
  ' "$1" >/dev/null 2>&1
}

[[ -f "$REGISTRY" ]] || fail "registry missing"
[[ -f "$SCHEMA" ]] || fail "schema missing"
[[ -f "$RETROSPECTIVE" ]] || fail "uninstall retrospective missing"

jq -e --arg baseline "$BASELINE" '
  .schema_version == 1 and
  .migration_baseline_commit == $baseline and
  (.entries | type == "array" and length == 8) and
  ([.entries[].feature] | length == (unique | length)) and
  ([.entries[].feature] | sort) == [
    "bootstrap-interviewer-enhancement",
    "claude-workflow-compatibility",
    "cross-model-verification",
    "risk-adaptive-layer",
    "sdd-forge-refactor",
    "sdd-lite",
    "uninstall-workflow",
    "workflow-state-integrity"
  ] and
  all(.entries[];
    (.feature | test("^[a-z0-9][a-z0-9-]*$")) and
    (.profile == "full" or .profile == "lite" or .profile == "legacy") and
    (if .profile == "legacy" then
      .legacy.introduced_before_commit == $baseline and
      (.legacy.reason | type == "string" and length > 0) and
      (.legacy.owner | type == "string" and length > 0) and
      (.legacy.allowed_missing_stages | type == "array") and
      (.legacy.allowed_noncanonical_statuses | type == "object") and
      (.legacy.allowed_task_approvals | type == "array") and
      (.legacy.allowed_task_statuses | type == "array") and
      ([.legacy | .. | strings] | all(contains("*") | not))
    else has("legacy") | not end)
  ) and
  (.entries[] | select(.feature == "sdd-lite") | .profile) == "lite" and
  (.entries[] | select(.feature == "bootstrap-interviewer-enhancement") | .profile) == "full" and
  (.entries[] | select(.feature == "workflow-state-integrity") | .profile) == "full"
' "$REGISTRY" >/dev/null || fail "canonical registry contract is invalid"
shell_schema_accepts "$REGISTRY" || fail "canonical registry fails independent Shell schema validation"

actual="$(find "$ROOT/specs" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | LC_ALL=C sort | jq -Rsc 'split("\n")[:-1]')"
declared="$(jq -c '[.entries[].feature] | sort' "$REGISTRY")"
[[ "$actual" == "$declared" ]] || fail "registry does not exactly cover first-level specs directories"
validate_registry_coverage "$REGISTRY" "$ROOT/specs" ||
  fail "canonical registry failed coverage/path validation"

for fixture in "$ROOT"/tests/fixtures/workflow-state/invalid-registry-*.json; do
  if shell_schema_accepts "$fixture"; then
    fail "$(basename "$fixture") unexpectedly passes schema"
  fi
done

for fixture in duplicate dangling unregistered; do
  diagnostic="$(bash "$0" --coverage-fixture "$fixture" 2>&1 || true)"
  [[ "$diagnostic" == workflow-state:* ]] ||
    fail "$fixture fixture did not reach coverage validation"
done

symlink_diagnostic="$(bash "$0" --coverage-fixture symlink 2>&1 || true)"
[[ "$symlink_diagnostic" == "workflow-state: escape: registry-path-escape:"* ]] ||
  fail "escaping symlink was not rejected with registry-path-escape"

rg -q '277a79d' "$RETROSPECTIVE" || fail "retrospective omits uninstall commit"
rg -q 'uninstall\.sh|uninstall\.ps1' "$RETROSPECTIVE" || fail "retrospective omits implementation files"
rg -q 'uninstall\.tests\.sh|uninstall\.tests\.ps1' "$RETROSPECTIVE" || fail "retrospective omits tests"
rg -qi 'review provenance.*unavailable|provenance.*unavailable' "$RETROSPECTIVE" ||
  fail "retrospective does not state unavailable review provenance"

printf 'ok: workflow-state registry and bounded migration records are valid\n'
