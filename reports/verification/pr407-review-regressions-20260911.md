# PR407 review regressions

Base: 136c6cc4f2f2df976240cc6eb6e40722cf555505.
Review comments: 3985432072 and 3985432075.

The exact Requirement-only header rejected the existing ci-mcp traceability
table (specs/ci-mcp/traceability.md:8). Both validators now also recognize the
case-sensitive REQ-ID alias in column zero. Layer Spec validation, coverage,
and rejection of unrelated tables are unchanged. The template again includes
Investigation as required by investigate-codebase/references/spec-id-rules.md
under Cross-Referencing; it asks for real evidence IDs, not invented examples.

Verification on macOS:

- New bootstrap checks before production changes: 21 passed, 3 failed
  (missing provenance column and existing REQ-ID rejected by Python/PowerShell).
- bootstrap-cross-layer-index.tests.sh after changes: 30 passed, 0 failed.
  Includes actual ci-mcp inputs, both runtimes, noncanonical-case and displaced
  header rejection, and retained side-table/anchor checks.
- task-layer-review-inputs.tests.sh: exit 0; all nine checks passed.
- task-layer-review-inputs.tests.ps1: exit 0; all seven checks passed.
- loop-driver.tests.sh first run: 25 passed, 1 failed because its negative
  fixture incorrectly designated the established REQ-ID header as obsolete.
  Changed that fixture to lowercase req-id, retaining the expected diagnostic.
  Rerun: 26 passed, 0 failed.
- git diff --check: exit 0.

Local diff review found no further blocking finding in this bounded change.
This is not independent approval or a Windows OS run. Latest-head CI, required
approval, merge, and post-merge verification remain pending. Issue289 stays open.
