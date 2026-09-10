# PR 371 / PR 381 evidence preflight

Date: 2026-09-06 JST
Status: NEEDS_WORK diagnostic only; not a quality-gate verdict

## Immutable targets

- PR 371: `9e39c396f4ca8f9abe3c9aabb090868ada17b53f`
- PR 381: `92528375705085967c19d75deb5f12e0fa66c276` (still Draft)
- GitHub heads were rechecked this turn and match these refs.

## Primary executed schema probes

Read each ref with `git show`, compile its `contracts/adversarial-review-report.v1.schema.json` and `contracts/adversarial-review-evaluation.v1.schema.json` using installed Ajv, and parse the first YAML block of `reports/adversarial-review/feat-adversarial-review-enhancements/report.md` using installed js-yaml. Evaluation input is that directory's `evaluation.json`.

Ajv options: allErrors=true, strict=true, strictRequired=false, strictTypes=false, validateFormats=false; register the schema's `x-stale-judgement-rules` annotation keyword. Date-time format validation, semantic consistency and reviewer authenticity are outside these probes.

| Probe | PR 371 | PR 381 |
|---|---|---|
| Persisted report metadata | Reject: head_sha is not a hex commit; reviewer_run_ids is an array rather than object | Accept |
| Persisted evaluation | Accept | Accept |
| Evaluation with reviewer_launch_count=0 | Incorrectly accepts | Reject: minimum 2 |
| Evaluation with phase_r={ran:true,verified_count:1} | Accepts incomplete outcomes | Rejects missing outcome counters |

The first combined diagnostic subsequently failed in its separate digest step because the diagnostic used `base_sha` rather than the report's `merge_base_sha`. This was a diagnostic error, not a product failure. The corrected digest command used explicit recorded refs:

`git diff --binary e00478321327b48e4e4ad21a14391d69e0f1baa9 9e39c396f4ca8f9abe3c9aabb090868ada17b53f`

SHA-256 of its raw bytes is `8bf861912ac750c3e1f46858d0d8800e5b84c2bb7c914f94dd605d482d15edd2`, exactly matching PR 381's historical report. That report explicitly declares itself STALE for subsequent hardening. A valid historical digest is not approval of PR 381's current head. Its Phase R remains unexecuted in the inspected record.

## Live CI is terminal, not pending

`gh pr checks 371` reports failures in MCP macOS/Linux, Windows test and required-checks (run 33256788058).

`gh pr checks 381` reports failures in POSIX inventory, all loops-routing/test/version-gates OS jobs, MCP macOS/Linux and required-checks (run 33450158656). CodeRabbit's passing status explicitly means review skipped for Draft, not an independent approval.

The failed Ubuntu loops-routing job 99678021560 was inspected directly. Template parity passes 18/0 in both shell and PowerShell. Loop inventory fails TEST-004.1 for four suites: loop-inventory, loop-driver, loop-consistency and loop-escalation; each is reported missing from run-all.sh and/or test.yml registration. Final inventory result: 67 passed, 4 failed. This is a specific registration-contract investigation target; do not disable the inventory test to green CI.

## Next integration conditions

1. Reuse PR 381's existing schema/producer/template/test corrections as a coherent unit after requirement mapping; do not recreate PR 371's defects or transplant stricter schemas alone.
2. Reconcile test registration with the execution contract and current main, then reproduce the four inventory failures against the integrated candidate. Old failed CI alone does not prove current main has the same fault.
3. Obtain fresh independent review and repair-verification evidence for the exact integration head. Preserve the truthful historical report rather than relabeling it current.
4. Check all issue 345–350 acceptance conditions, including issue 346's human disposition decision, before closing any issue.
5. Require all mandatory CI success before merge. The authorized review-count bypass does not override failed CI, stale evidence or specification requirements.

No product, protected files, frozen artifacts, approvals or GitHub state were changed by this diagnostic. Both source branches remain preserved.

## Local comparison limitation

A subsequent read-only Node command attempting `git show` comparisons of `tests/run-all.sh` and `.github/workflows/test.yml` at PR 381 and HEAD was rejected by the active PreToolUse deterministic gate. The comparison did not execute. No alternate interpreter, copied file, disabled hook or privilege escalation was used to reroute it. Therefore this report establishes the historical CI registration failure, not whether current main already repairs it.

## Subsequent independent CI evidence

Main push run 33975094357 for `633dcdf6d3289054f832ebbed066e6680e25d645` is live. Its Ubuntu loops-routing job 101330280731 has completed successfully, including loop inventory registration forcing in Bash and PowerShell, loop driver, loop consistency and loop escalation. This independently proves that main's current loop-registration checks pass; it does not prove that combining PR 381's changed CI wiring with main preserves that result. Preserve current main's successful registration behavior during eventual integration rather than blindly carrying PR 381's historical wiring.

Issue 346 was also fetched directly: no comments; its acceptance conditions explicitly require a three-run comparison matrix, verified non-findings per run, fresh-context Phase R and a human-recorded plugin/standalone/retire decision. PR 381's standalone README status alone is not that post-evaluation human decision. Do not close 346 based on schemas or a third-report filename alone.
