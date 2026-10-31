# Evaluator launch precheck — 2026-10-03

Status: BLOCKED before reservation; independent evaluation NOT RUN.

- Human supplied the shipped evaluator role definition. Its reference comments name `openai/gpt-5.2-codex/high`.
- Live registry selector returned `gpt-6-astra/medium`, strong tier, risk-matrix effort, flag control. DRIFT recorded; live selection governs. The reused single-candidate cost estimate is historical #137 metadata, not this review's price or measured cost.
- Fresh evaluator initialized without substantive inputs: session `01a0ff20-25ba-7292-b6ce-29743e086b8c`, observed via its own `printenv CODEX_THREAD_ID`.
- All 28 candidate input SHA-256 values matched immediately before the attempted reservation.
- Invocation: `reports/review-context/issue423-t001-quality-20261003-invocation.json`.
- Original `validate-review-context-set.sh <invocation> . --reserve` exited 1: `REVIEW_CONTEXT_PATH: scratch history contains a non-canonical root`; `feature scratch-history check failed`.
- Root cause: `reports/implementation/sdd-domain-multitarget/T-002.md:60` records the relative root `specs/sdd-domain-multitarget/verification/T-002`. The feature-wide history scan calls the absolute-root validator on that old declaration, before ledger reservation. T-001's current implementation and evaluator scratch roots are absolute and distinct.

Do not rewrite the historical T-002 declaration, drop history checks, or launch the evaluator without reservation. A narrowly reviewed historical-root compatibility/recovery path is needed; it must retain old bytes and still reject traversal, ambiguous roots, overlap, and substituted evidence. No review verdict, task status, commit, push, or merge was produced by this attempt.
