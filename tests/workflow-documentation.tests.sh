#!/usr/bin/env bash
# Regression coverage for the full SDD review-chain documentation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS=(
  "README.md"
  "docs/workflow-guide.md"
  "docs/contributor/workflow-detail.md"
  "docs/skill-reference.md"
  "docs/contributor/skill-reference-detail.md"
  "docs/troubleshooting.md"
)

fail() {
  printf 'not ok: %s\n' "$1" >&2
  exit 1
}

for document in "${DOCS[@]}"; do
  content="${ROOT}/${document}"
  for stage in spec-review-loop impl-review-loop task-review-loop; do
    grep -Fq "$stage" "$content" || fail "$document must name $stage"
  done
  grep -Eqi 'independent|独立' "$content" || fail "$document must describe independent review"
done

grep -Fq 'P --> W[workflow-retrospective' "${ROOT}/docs/workflow-guide.md" || \
  fail "workflow diagram must keep the retrospective node distinct from spec review"

workflow_guide="${ROOT}/docs/workflow-guide.md"
assert_section_review_order() {
  local name="$1" start="$2" end="$3" section spec_line impl_line task_line
  section="$(sed -n "/^### ${start} /,/^### ${end} /p" "$workflow_guide")"
  spec_line="$(grep -n -m1 -F 'spec-review-loop' <<<"$section" | cut -d: -f1 || true)"
  impl_line="$(grep -n -m1 -F 'impl-review-loop' <<<"$section" | cut -d: -f1 || true)"
  task_line="$(grep -n -m1 -F 'task-review-loop' <<<"$section" | cut -d: -f1 || true)"
  [[ -n "$spec_line" && -n "$impl_line" && -n "$task_line" &&
     "$spec_line" -lt "$impl_line" && "$impl_line" -lt "$task_line" ]] || \
    fail "$name flow must run spec-review-loop, impl-review-loop, and task-review-loop in order"
}

assert_section_review_order "feature" "3.1" "3.2"
assert_section_review_order "bugfix" "3.2" "3.3"
assert_section_review_order "refactor" "3.3" "3.4"

grep -Fq 'ステップ 3b/3c/3e のレビューゲート' "$workflow_guide" || \
  fail "lite profile must identify all three review gates"

agents="${ROOT}/AGENTS.md"
for stage in spec-review-loop impl-review-loop task-review-loop; do
  grep -Fq "$stage" "$agents" || fail "AGENTS.md must require $stage"
done

interviewer="${ROOT}/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md"
grep -Fq '/sdd-review-loop:spec-review-loop --feature <feature>' "$interviewer" || \
  fail "bootstrap interviewer must invoke the namespaced specification review command"

spec_line="$(grep -n -m1 -F '/sdd-review-loop:spec-review-loop --feature <feature>' "$interviewer" | cut -d: -f1)"
impl_line="$(grep -n -m1 -F '/sdd-review-loop:impl-review-loop --feature <feature>' "$interviewer" | cut -d: -f1)"
task_line="$(grep -n -m1 -F '/sdd-review-loop:task-review-loop --feature <feature>' "$interviewer" | cut -d: -f1)"
[[ "$spec_line" -lt "$impl_line" && "$impl_line" -lt "$task_line" ]] || \
  fail "bootstrap interviewer review commands must be ordered spec, implementation-policy, task"

run_skill="${ROOT}/plugins/sdd-bootstrap/skills/run/SKILL.md"
run_full="$(sed -n '/^### `feature` .*full track)/,/^### Lite track/p' "$run_skill")"
for stage in spec-review-loop impl-review-loop task-review-loop; do
  grep -Fq "$stage" <<<"$run_full" || fail "bootstrap run full track must name $stage"
done
run_spec_line="$(grep -n -m1 -F 'spec-review-loop' <<<"$run_full" | cut -d: -f1)"
run_impl_line="$(grep -n -m1 -F 'impl-review-loop' <<<"$run_full" | cut -d: -f1)"
run_task_line="$(grep -n -m1 -F 'task-review-loop' <<<"$run_full" | cut -d: -f1)"
[[ "$run_spec_line" -lt "$run_impl_line" && "$run_impl_line" -lt "$run_task_line" ]] || \
  fail "bootstrap run full track review commands must be ordered spec, implementation-policy, task"
grep -Fq 'skip all three review loops' "$run_skill" || \
  fail "bootstrap run lite track must explicitly skip all three review loops"

printf 'ok: full SDD documentation names the three independent review stages in order\n'
