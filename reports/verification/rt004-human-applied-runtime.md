# RT004 human-applied integration verification

Date: 2026-09-26
Base commit: 5362378989f046a851b5005637abad6f942b1841
Branch: codex/rt004-adr-main-integration
Scope: verification only; no product/test edits, commits, push, approval, reservation or formal gate verdict changes.
Environment: macOS Bash and PowerShell; synthetic fixtures, not native Windows/live verification.

## Applied artifact identity

All 18 product/contract/test files matched the pinned candidates byte-for-byte before execution. Both patches passed reverse apply check.

- Code patch SHA256: 14cfa98a1c4bb5ca74a72e7829ea62d9f201194aa9ea14cca5c248b0611d722f
- Contract/tests patch SHA256: 099bbf0c1c4b30bb0913ef49b16128a6b170ca3279ef8bad6cc10a05572e2526

## Sequential runtime results

| Entry point | Exit | Observed result |
|---|---:|---|
| tests/impl-review-adr-inputs.tests.sh | 0 | admission 448/0; precheck 10/0; generation 30/0; downstream 32/0, inconclusive 0; workflow history cases all successful |
| tests/review-context-boundary.tests.sh | 1 | stopped at first citation assertion; subsequent runtime boundary checks not reached |
| tests/review-investigation-completeness.tests.py --mode preflight | 0 | PASS 36; FAIL 0 |
| tests/review-investigation-completeness.tests.py --mode reservation --cross-runtime | 0 | PASS 120; FAIL 0 |
| check-workflow-state.sh --feature workflow-state-integrity | 0 | workflow-state: ok |
| check-workflow-state.ps1 --feature workflow-state-integrity | 0 | workflow-state: ok |
| git diff --check | 0 | no diagnostics |

Boundary failure: references/review-context-boundary.md:52 cites validate-review-context-set.sh:796-801 for the path_is_authorized invocation, but the invocation is now at validate-review-context-set.sh:810. Exact diagnostic: citation has slid off the construct it describes. No repair or retry was made by this verifier. Parent owns the citation repair; full boundary runtime coverage remains outstanding.

## Restoration

Hashes below matched before the ADR suite, immediately after it, and after all verification. Initial and final git status were identical (14 modified + 4 new approved targets plus existing inert preparation reports). No leftover fixture or ledger files appeared in git status.

- specs/workflow-state-registry.json: 6ff8722870d251b3d14e9efbcacc019b825be1ddf714ad5faf4ec239b4619042
- reports/review-context/identity-ledger.json: c0518fcc733f0ad34c8f6574c2612ef4d740796d5d35ad70aa8a67f148f97316

## Limitations

This is runtime verification evidence, not a formal SDD PASS. Boundary suite remains failed/incomplete. Captured ADR output and reservation JSON output are available in the verifier session; preflight terminal capture had a display truncation although its final exit and 36/0 summary were observed. No root checkout tests were run.

## Citation repair and complete boundary rerun

The parent corrected only the document and assertion-table citation from
796–801 to 796–811, retaining every assertion and matching the actual
authorization branch. The original failed result above remains historical.
The complete original-path boundary suite subsequently exited 0: all 32
citation anchors, Bash/PowerShell reservation and verification cases, three
runtime unit tests, and regular/hardlink/symlink investigation checks passed.
The last symlink group reported 84 PASS / 0 FAIL. No check was removed or
relaxed; this does not assert Windows execution or a formal review verdict.

## Integration checks and independent review

- Full repository workflow-state validation: Bash exit 0; PowerShell exit 0.
- Workflow-state adapter parity regression: exit 0.
- Round-2 implementation-contract regression: exit 0, including missing previous
  summary, wrong reviewer binding, and missing investigation rejection.
- Independent static integration review found one Major: the new ADR suite was
  not registered for CI. Adding its single entry to `tests/suite-inventory.posix`
  resolves that finding; independent re-review reported no remaining
  Critical/Major findings in the reviewed diff.
- CI wiring checks: exit 0, including all 20 behavioral controls. The existing
  four-shard fallback now schedules the complete ADR suite without a new job.

These results supersede the earlier boundary-incomplete limitation only; past
failed observations remain above. Windows CI, formal SDD review, and main
integration are not claimed by this report.
