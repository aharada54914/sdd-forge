#!/usr/bin/env bash
# Portable foundation for review-loop prechecks. Emits canonical JSON only after
# validating the contract identity and a report root contained by this repository.
set -euo pipefail

feature="" attempt="" round="" stage="" report_root="" contract=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature) feature="${2:?missing feature}"; shift 2 ;;
    --attempt) attempt="${2:?missing attempt}"; shift 2 ;;
    --round) round="${2:?missing round}"; shift 2 ;;
    --stage) stage="${2:?missing stage}"; shift 2 ;;
    --report-root) report_root="${2:?missing report root}"; shift 2 ;;
    --contract) contract="${2:?missing contract}"; shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

fail() { echo "ERROR: review-contract-validate: $1" >&2; exit 1; }
[[ "$feature" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "invalid feature slug"
[[ "$attempt" =~ ^[1-9][0-9]*$ ]] || fail "attempt must be a positive integer"
[[ "$round" =~ ^[1-9][0-9]*$ ]] || fail "round must be a positive integer"
[[ "$stage" =~ ^(spec|impl|task)$ ]] || fail "stage must be spec, impl, or task"
[[ -f "$contract" ]] || fail "contract does not exist"

repo_root="$(cd "$(dirname "$0")/../../.." && pwd -P)"
reports_root="${repo_root}/reports"
root_parent="$(dirname "$report_root")"
[[ -d "$root_parent" ]] || fail "report root parent does not exist"
canonical_parent="$(cd "$root_parent" && pwd -P)"
canonical_root="${canonical_parent}/$(basename "$report_root")"
[[ "$canonical_root" == "${reports_root}"/* ]] || fail "report root escapes reports directory"
[[ ! -e "$report_root" || -d "$report_root" ]] || fail "report root must be a directory when it exists"
[[ ! -L "$report_root" ]] || fail "report root must not be a symlink"

command -v jq >/dev/null 2>&1 || fail "jq is required"
jq -e \
  --arg feature "$feature" --argjson attempt "$attempt" --argjson round "$round" --arg stage "$stage" \
  'type == "object" and (keys == ["attempt", "feature", "input_sha256", "round", "run_id", "schema", "stage", "verdict"]) and .schema == "review-contract/v1" and .feature == $feature and .attempt == $attempt and .round == $round and .stage == $stage and (.input_sha256|type == "string" and test("^[0-9a-fA-F]{64}$")) and (.run_id|type == "string" and test("\\S")) and .verdict == "PASS"' \
  "$contract" >/dev/null || fail "contract identity or PASS verdict is invalid"

jq -cn --arg feature "$feature" --argjson attempt "$attempt" --argjson round "$round" --arg stage "$stage" \
  '{schema:"review-contract-validation/v1",feature:$feature,attempt:$attempt,round:$round,stage:$stage,verdict:"PASS"}'
