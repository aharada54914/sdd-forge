#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/wfi-034-metric.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/reports/review-context" "$tmp/reports/implementation/feature-a"

write_invocation() {
  local name=$1 task=$2 scratch=$3
  jq -n --arg task "$task" --arg scratch "$scratch" '{
    schema:"review-context-invocation/v2", stage:"quality", feature:"feature-a",
    task_id:$task, scratch_root:$scratch
  }' > "$tmp/reports/review-context/$name.json"
}
write_report() {
  local task=$1 scratch=$2
  printf '# Implementation Report: %s\n\n## Isolation Evidence\n\n- **Scratch Root**: %s\n' \
    "$task" "$scratch" > "$tmp/reports/implementation/feature-a/$task.md"
}

write_invocation distinct T-001 /tmp/feature-a/evaluator-1
write_report T-001 /tmp/feature-a/implementation-1
write_invocation shared T-002 /tmp/feature-a/shared/evaluator
write_report T-002 /tmp/feature-a/shared
write_invocation unauditable T-003 /tmp/feature-a/evaluator-3
write_invocation cross-task T-004 /tmp/feature-a/implementation-1/child
write_report T-004 /tmp/feature-a/implementation-4

result="$(python3 "$ROOT/scripts/measure-evaluator-scratch-isolation.py" "$tmp" --feature feature-a)"
[[ "$(jq -r '.metrics.evaluator_scratch_shared_with_implementation' <<<"$result")" == 2 ]] || {
  printf 'FAIL: expected direct and cross-task shared scratch roots: %s\n' "$result" >&2
  exit 1
}
[[ "$(jq -r '.metrics.evaluator_scratch_declared' <<<"$result")" == 4 ]] || {
  printf 'FAIL: expected four declared evaluator roots: %s\n' "$result" >&2
  exit 1
}
[[ "$(jq -r '.metrics.evaluator_scratch_auditable' <<<"$result")" == 3 ]] || {
  printf 'FAIL: expected three auditable evaluator roots: %s\n' "$result" >&2
  exit 1
}

printf 'WFI-034 scratch metric tests passed\n'
