# Run the local, deterministic PowerShell regression suite in CI order.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$powerShell = (Get-Process -Id $PID).Path
$tests = @(
    'tests/validate-repository.ps1',
    'tests/scripts.tests.ps1',
    'tests/review-contract-foundation.tests.ps1',
    'tests/task-context-isolation.tests.ps1',
    'tests/rollback-1.5.0.tests.ps1',
    'tests/downstream-review-precheck.tests.ps1',
    'tests/impl-layer-review-inputs.tests.ps1',
    'tests/task-layer-review-inputs.tests.ps1',
    'tests/cross-model.tests.ps1',
    'tests/hooks.tests.ps1',
    'tests/phase2-guard-tokenizer.tests.ps1',
    'tests/phase2-risk-upgrade.tests.ps1',
    'tests/phase2-sudo-signature.tests.ps1',
    'tests/scenario.tests.ps1',
    'tests/install.tests.ps1',
    'tests/uninstall.tests.ps1',
    'tests/claude-registration.tests.ps1',
    'tests/workflow-state-registry.tests.ps1',
    'tests/workflow-state.tests.ps1',
    'tests/workflow-state-repository-integration.tests.ps1',
    'tests/structure-check-feature-mode.tests.ps1',
    'tests/emit-run-record-feature-scope.tests.ps1',
    'tests/agent-capabilities-v2.tests.ps1',
    'tests/render-agent-frontmatter.tests.ps1',
    'tests/agent-model-routing.tests.ps1',
    'tests/template-validator-parity.tests.ps1',
    'tests/loop-inventory.tests.ps1',
    'tests/loop-driver.tests.ps1',
    'tests/loop-consistency.tests.ps1',
    'tests/loop-escalation.tests.ps1',
    'tests/hitl-wfi-terminal.tests.ps1',
    'tests/check-placeholders-brownfield.tests.ps1',
    'tests/bump-version-gate.tests.ps1',
    'tests/release-loop-gate.tests.ps1',
    'tests/run-panelist-effort.tests.ps1',
    'tests/model-freshness-check.tests.ps1',
    'tests/facet-manifest-schema.tests.ps1',
    'tests/facet-manifest-semantics.tests.ps1',
    'tests/capability-summary-schema.tests.ps1',
    'tests/context-projection-schema.tests.ps1',
    'tests/design-system-contract.tests.ps1',
    'tests/project-context-schema.tests.ps1',
    'tests/canonicalize-sdd-yaml.tests.ps1',
    'tests/generate-approval-sidecar.tests.ps1',
    'tests/approver-registry-schema.tests.ps1',
    'tests/detect-policy-weakening.tests.ps1',
    'tests/validate-approval-sidecar.tests.ps1',
    'tests/apply-human-copy.tests.ps1',
    'tests/check-hook-activation-handshake.tests.ps1',
    'tests/guard-invariants-epic-a1.tests.ps1',
    'tests/hook-guard-epic-a1-boundary.tests.ps1',
    'tests/plugin-contracts-track-selection.tests.ps1',
    'tests/ship-track-selection-migration.tests.ps1',
    'tests/design-sync-standing-consent.tests.ps1',
    'tests/design-sync-scan.tests.ps1',
    'tests/capability-registry-schema.tests.ps1',
    'tests/evaluate-predicate.tests.ps1',
    'tests/registry-discovery.tests.ps1',
    'tests/validate-capability-registry.tests.ps1',
    'tests/generate-registry-digest.tests.ps1',
    'tests/generate-gate-capabilities.tests.ps1',
    'tests/capability-registry-parity.tests.ps1',
    'tests/component-path-resolver.tests.ps1',
    'tests/component-path-diff-basis.tests.ps1',
    'tests/ownership-digest.tests.ps1',
    'tests/check-component-coverage.tests.ps1',
    'tests/component-path-ownership-parity.tests.ps1'
)

# Every suite runs even after one fails: the suites are mutually independent,
# so aborting at the first failure hides the status of every later suite and
# turns an unbounded set of unrelated defects into a serial discovery queue.
$failed = @()

Push-Location $root
try {
    foreach ($testFile in $tests) {
        Write-Host "==> $testFile"
        & $powerShell -NoProfile -File (Join-Path $root $testFile)
        if ($LASTEXITCODE -ne 0) {
            Write-Host "FAILED: $testFile (exit code $LASTEXITCODE)"
            $failed += $testFile
        }
    }
} finally {
    Pop-Location
}

if ($failed.Count -gt 0) {
    Write-Host ''
    Write-Host "$($failed.Count) failing suite(s):"
    foreach ($failedTest in $failed) {
        Write-Host "  $failedTest"
    }
    exit 1
}

Write-Host 'All PowerShell regression tests passed.'
exit 0
