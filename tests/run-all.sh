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
  tests/spec-review-loop.tests.sh
  tests/downstream-review-precheck.tests.sh
  tests/impl-layer-review-inputs.tests.sh
  tests/task-layer-review-inputs.tests.sh
  tests/task-layer-full-profile.tests.sh
  tests/downstream-review-precheck-parity.tests.sh
  tests/task-review-precheck.tests.sh
  tests/impl-review-round2-contract.tests.sh
  tests/review-agent-isolation.tests.sh
  tests/agent-model-routing.tests.sh
  tests/agent-capabilities-v2.tests.sh
  tests/render-agent-frontmatter.tests.sh
  tests/task-context-isolation.tests.sh
  tests/turn-first-workflow.tests.sh
  tests/retrospective-loop.tests.sh
  tests/emit-run-record-feature-scope.tests.sh
  tests/rollback-1.5.0.tests.sh
  tests/release-config-lock.tests.sh
  tests/cross-model.tests.sh
  tests/eval.tests.sh
  tests/crlf-parity.tests.sh
  tests/constant-parity.tests.sh
  tests/scenario.tests.sh
  tests/workflow-scenarios/workflow-scenarios.tests.sh
  tests/apply-branch-protection.tests.sh
  tests/workflow-state-registry.tests.sh
  tests/workflow-state-registry-parity.tests.sh
  tests/workflow-state.tests.sh
  tests/workflow-state-parity.tests.sh
  tests/second-approval-mask.tests.sh
  tests/workflow-state-ci-integration.tests.sh
  tests/structure-check-feature-mode.tests.sh
  tests/quality-gate-cycle-limit.tests.sh
  tests/quality-loop-calibration.tests.sh
  tests/guard-dispatch-fallback.tests.sh
  tests/guard-negative-corpus.tests.sh
  tests/guard-cwd-bypass.tests.sh
  tests/guard-parity.tests.sh
  tests/claude-bash-matcher.tests.sh
  tests/phase2-guard-invariants.tests.sh
  tests/human-copy-mirror-freshness.tests.sh
  tests/phase2-guard-tokenizer.tests.sh
  tests/phase2-risk-upgrade.tests.sh
  tests/phase2-sudo-signature-static.tests.sh
  tests/self-improvement-guard.tests.sh
  tests/p0-hardening.tests.sh
  tests/deterministic-lane-selfcheck.tests.sh
  tests/guard-ps1-ascii.tests.sh
  tests/repository-release-validation.tests.sh
  tests/installer-idempotency.tests.sh
  tests/template-validator-parity.tests.sh
  tests/task-lifecycle-enum-parity.tests.sh
  tests/task-state-grammar-parity.tests.sh
  tests/task-plan-binding-durability.tests.sh
  tests/schema-engine-identity.tests.sh
  tests/loop-inventory.tests.sh
  tests/loop-driver.tests.sh
  tests/loop-consistency.tests.sh
  tests/review-prompt-calibration.tests.sh
  tests/review-context-boundary.tests.sh
  tests/boundary-reference-authorization-parity.tests.sh
  tests/design-system-contract.tests.sh
  tests/design-system-compliance.tests.sh
  tests/loop-escalation.tests.sh
  tests/hitl-wfi-terminal.tests.sh
  tests/check-placeholders-brownfield.tests.sh
  tests/bootstrap-layer-templates.tests.sh
  tests/bootstrap-interview-guidance.tests.sh
  tests/bootstrap-cross-layer-index.tests.sh
  tests/collection-layer.tests.sh
  tests/workflow-documentation.tests.sh
  tests/bump-version-gate.tests.sh
  tests/release-loop-gate.tests.sh
  tests/run-panelist-effort.tests.sh
  tests/model-freshness-check.tests.sh
  tests/facet-manifest-schema.tests.sh
  tests/facet-manifest-semantics.tests.sh
  tests/capability-summary-schema.tests.sh
  tests/context-projection-schema.tests.sh
  tests/facet-manifest-staleness.tests.sh
  tests/facet-manifest-parity.tests.sh
  tests/project-context-schema.tests.sh
  tests/canonicalize-sdd-yaml.tests.sh
  tests/generate-approval-sidecar.tests.sh
  tests/approver-registry-schema.tests.sh
  tests/detect-policy-weakening.tests.sh
  tests/validate-approval-sidecar.tests.sh
  tests/apply-human-copy.tests.sh
  tests/check-hook-activation-handshake.tests.sh
  tests/guard-invariants-epic-a1.tests.sh
  tests/hook-guard-epic-a1-boundary.tests.sh
  tests/plugin-contracts-track-selection.tests.sh
  tests/ship-track-selection-migration.tests.sh
  tests/guard-staging-exemption.tests.sh
  tests/design-sync-standing-consent.tests.sh
  tests/design-sync-scan.tests.sh
  tests/capability-registry-schema.tests.sh
  tests/evaluate-predicate.tests.sh
  tests/registry-discovery.tests.sh
  tests/validate-capability-registry.tests.sh
  tests/generate-registry-digest.tests.sh
  tests/generate-gate-capabilities.tests.sh
  tests/capability-registry-parity.tests.sh
  tests/component-path-resolver.tests.sh
  tests/component-path-diff-basis.tests.sh
  tests/ownership-digest.tests.sh
  tests/check-component-coverage.tests.sh
  tests/component-path-ownership-parity.tests.sh
)

# Every suite runs even after one fails: the suites are mutually independent,
# so aborting at the first failure hides the status of every later suite and
# turns an unbounded set of unrelated defects into a serial discovery queue.
failed=()

for test_file in "${tests[@]}"; do
  printf '==> %s\n' "$test_file"
  if ! bash "$test_file"; then
    printf 'FAILED: %s\n' "$test_file"
    failed+=("$test_file")
  fi
done

# Cross-runtime guard parity (PowerShell host suite; itself self-skips when
# python3 or node is absent). Skip only when pwsh is not installed.
printf '==> %s\n' "tests/guard-r10-port.tests.ps1"
if command -v pwsh >/dev/null 2>&1; then
  if ! pwsh -NoProfile -ExecutionPolicy Bypass -File tests/guard-r10-port.tests.ps1; then
    printf 'FAILED: %s\n' "tests/guard-r10-port.tests.ps1"
    failed+=("tests/guard-r10-port.tests.ps1")
  fi
else
  printf 'SKIP: pwsh not found; guard-r10-port.tests.ps1 not run\n'
fi

if [[ ${#failed[@]} -gt 0 ]]; then
  printf '\n%d failing suite(s):\n' "${#failed[@]}"
  printf '  %s\n' "${failed[@]}"
  exit 1
fi

printf 'All POSIX regression tests passed.\n'
