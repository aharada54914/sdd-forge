#!/usr/bin/env bash
# Regression coverage for the SDD Core (v2) review-chain documentation.
#
# The v1 three-loop chain (spec/impl/task review loops, the bootstrap
# interviewer and the Lite track) was retired by ADR-0051 decision 2; its
# assertions were retired on 2026-11-28 (T-010 suite disposition plan). The
# same guarantee now holds for the v2 flow: the user-facing guides name the
# risk-scaled pre-implementation check and the independent completion gate,
# in order, around the human approval.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
README="${ROOT}/README.md"
GUIDE="${ROOT}/docs/workflow-guide.md"
RUN_SKILL="${ROOT}/plugins/sdd-bootstrap/skills/bootstrap/SKILL.md"
AGENTS="${ROOT}/AGENTS.md"

fail() {
  printf 'not ok: %s\n' "$1" >&2
  exit 1
}

line_of() {
  # First line number of a fixed string in a file; empty when absent.
  grep -n -m1 -F -- "$2" "$1" | cut -d: -f1 || true
}

for document in "$README" "$GUIDE"; do
  name="${document#"$ROOT"/}"
  grep -Fq 'spec-check' "$document" || fail "$name must name the spec-check pre-implementation review"
  grep -Fq 'sdd-gate' "$document" || fail "$name must name the sdd-gate completion gate"
  grep -Fq '独立レビュー1回' "$document" || fail "$name must state that sdd-gate includes one independent review"
done

# The standard flow diagram orders: specification -> spec-check -> human
# approval -> baseline -> implementation -> sdd-gate -> Done.
spec_check="$(line_of "$GUIDE" 'C{"spec-check')"
approval="$(line_of "$GUIDE" '人間: Approval: Approved')"
baseline="$(line_of "$GUIDE" 'record-spec-baseline.mjs')"
gate="$(line_of "$GUIDE" 'GATE{"sdd-gate')"
done_node="$(line_of "$GUIDE" 'GATE -->|PASS| DONE')"
[[ -n "$spec_check" && -n "$approval" && -n "$baseline" && -n "$gate" && -n "$done_node" &&
   "$spec_check" -lt "$approval" && "$approval" -lt "$baseline" &&
   "$baseline" -lt "$gate" && "$gate" -lt "$done_node" ]] ||
  fail "workflow guide must order spec-check, human approval, baseline, sdd-gate and Done"
grep -Fq 'C -->|NEEDS_FIX| B' "$GUIDE" || fail "spec-check NEEDS_FIX must return to the specification"
grep -Fq 'GATE -->|FAIL / UNDECLARED_DRIFT| IMP' "$GUIDE" ||
  fail "sdd-gate FAIL or undeclared drift must return to implementation"
grep -Fq '(low:省略 / standard:1体 / high:2視点並列)' "$GUIDE" ||
  fail "spec-check must scale by risk: low skipped, standard one reviewer, high two perspectives"
grep -Fq 'P --> W[workflow-retrospective' "$GUIDE" ||
  fail "workflow diagram must keep the retrospective node distinct from the review chain"

# Every bootstrap mode that writes a specification reaches spec-check.
for mode in feature bugfix refactor project; do
  grep -Eq "^\\| \`${mode}\` \\|[^|]*sdd-core-spec\` → \`spec-check\` \\|" "$RUN_SKILL" ||
    fail "bootstrap ${mode} mode must run sdd-core-spec and then spec-check"
done
grep -Fq -- '--skip-check' "$RUN_SKILL" || fail "bootstrap must document how spec-check is skipped explicitly"

# This repository's own contributor workflow (AGENTS.md) is unchanged.
for stage in spec-review-loop impl-review-loop task-review-loop; do
  grep -Fq "$stage" "$AGENTS" || fail "AGENTS.md must require $stage"
done
grep -Eq 'cross-epic.*merge state.*task plan|task plan.*cross-epic.*merge state' "$AGENTS" ||
  fail "AGENTS.md must tell review lanes to compare cross-epic merge state against the task plan"

printf 'ok: SDD Core documentation orders spec-check, human approval and the independent sdd-gate\n'
