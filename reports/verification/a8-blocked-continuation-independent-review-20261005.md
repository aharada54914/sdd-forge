# BLOCKED continuation candidate: independent technical review

Date: 2026-10-05
Owner checkout: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`
Observed HEAD: `495c88d67af44530687ecea3ce9fb0a90a336539`
Scope: candidate patch and disposable tests; not a formal SDD gate or verdict.
Risk: high (review history admissibility). Existing dirty files were preserved.
No protected sources, historical verdicts, reservations, or task states were changed.

## Finding: P1 / Major — Pending stage bypasses the required history validation

Locations in candidate-applied files: `plugins/sdd-review-loop/scripts/impl-review-precheck.sh:392-397` and `plugins/sdd-review-loop/scripts/impl-review-precheck.ps1:730-734` (the newly added BLOCKED branches).

The added call to check-workflow-state does not unconditionally validate the prior round. Its dispatch invokes impl history validation only when the current design has `Impl-Review-Status: Passed`: Bash `plugins/sdd-quality-loop/scripts/check-workflow-state.sh:1910`, PowerShell `plugins/sdd-quality-loop/scripts/check-workflow-state.ps1:2429`. A normal first design review has Pending and no tasks.md. The canonical command then succeeds without inspecting impl history. The local ADR-binding checks do not recalculate Critical/Major totals, so the new BLOCKED admission accepts an inconsistent historical count.

Confirmed in a separate disposable copy of the patched runner fixture:

1. Change only the copied design status from Passed to Pending, and move copied tasks.md aside to model the valid pre-task lifecycle.
2. Set copied round-1 `impl-review-contract.json` field `findings_critical` to 0; leave the Critical reviewer finding, integrated verdict and summary unchanged.
3. Run each actual precheck normally (no provenance flag), feature `epic-196-a8-integration`, attempt 9, round 2.

Observed: **Bash exit 0, round-2 emitted; PowerShell exit 0, round-2 emitted**. Both print `workflow-state: ok` twice. This violates the candidate's required rejection of forged counts and affects the newly accepted BLOCKED path even without advisory provenance mode.

Reproduction script: `/tmp/a8-pending-review-repro.py`.
Retained reproduction fixture: `/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/a8-pending-independent-n6ogfk2y`.

Smallest repair direction: make the canonical ADR historical binding validator callable for the explicit previous attempt/round independently of the document's Passed/Pending status (a narrow validation-only entry point, or shared extraction of the existing validator), and require that validation before BLOCKED admission on both runtimes. Do not synthesize Passed status or rewrite historical evidence. Add Pending/no-tasks negative coverage for forged Critical/Major totals, integrated verdict disagreement, identity and hash disagreement, alongside the existing Passed/provenance cases.

## Validation and limits

The submitted candidate runner completed successfully: all 16 RED/GREEN assertions, ADR generation 30 passed / 0 failed, `owner_history_unchanged=true; failures=0`. It tests only copied A8 Passed/provenance history, so these successful results do not cover the Pending dispatch defect. Existing explicit round-limit rejection was reproduced by that runner. Hash binding and role matching were inspected, but no claim is made of exhaustive adversarial coverage after the confirmed blocker.

Recommendation: do not apply this candidate until the history-validation dispatch defect is corrected and independently retested. No formal review PASS, quality-gate outcome, Windows-native verification, or exact-final-head CI is claimed.
