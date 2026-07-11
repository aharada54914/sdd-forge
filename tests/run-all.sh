#!/usr/bin/env bash
# Run the local, deterministic POSIX regression suite in CI order.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"

tests=(
  tests/install.tests.sh
  tests/uninstall.tests.sh
  tests/guards.tests.sh
  tests/approval-boundary.tests.sh
  tests/gates.tests.sh
  tests/check-placeholders.tests.sh
  tests/prepare-panelist.tests.sh
  tests/review-contract-foundation.tests.sh
  tests/review-contract-foundation-parity.tests.sh
  tests/downstream-review-precheck.tests.sh
  tests/impl-layer-review-inputs.tests.sh
  tests/task-layer-review-inputs.tests.sh
  tests/task-layer-full-profile.tests.sh
  tests/downstream-review-precheck-parity.tests.sh
  tests/task-review-precheck.tests.sh
  tests/review-agent-isolation.tests.sh
  tests/agent-model-routing.tests.sh
  tests/task-context-isolation.tests.sh
  tests/turn-first-workflow.tests.sh
  tests/retrospective-loop.tests.sh
  tests/emit-run-record-feature-scope.tests.sh
  tests/rollback-1.5.0.tests.sh
  tests/cross-model.tests.sh
  tests/eval.tests.sh
  tests/crlf-parity.tests.sh
  tests/scenario.tests.sh
  tests/apply-branch-protection.tests.sh
  tests/workflow-state-registry.tests.sh
  tests/workflow-state-registry-parity.tests.sh
  tests/workflow-state.tests.sh
  tests/workflow-state-parity.tests.sh
  tests/workflow-state-ci-integration.tests.sh
  tests/structure-check-feature-mode.tests.sh
)

for test_file in "${tests[@]}"; do
  printf '==> %s\n' "$test_file"
  bash "$test_file"
done

printf 'All POSIX regression tests passed.\n'
