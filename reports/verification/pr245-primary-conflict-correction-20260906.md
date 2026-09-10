# PR #245 primary correction to delegated integration advice

Read-only investigation; no protected implementation, frozen evidence, task state or remote branch changed.

Compared exact main `4366438f3b243210a4ece5a17f873ca2d920600a` with PR head `54b1ff247081971e0560cf20d45f4369e01b5c0d`. Primary confirmed both the PR's remote head and local commit object (tool results 193106, 71d4a6).

The delegated merge-base diff is not sufficient to identify changes still missing from main. Its recommendation to import investigation growth tolerance and contract-derived pins as new functionality is not accepted without comparison to current main.

Primary two-endpoint diffs (6e0567, 87c4ec) show that adopting the older PR versions wholesale would remove current SHA-256 tool fail-closed checks, the `--opening` interface and associated current state handling, and the shared review-precheck library extraction. This is not an approved safe resolution.

Main already contains the investigation amendment-growth functions. Main's `plugins/sdd-review-loop/scripts/lib/review-precheck-common.sh:232` also contains the contract-derived investigation pin, ambiguous-pin sentinel at line 240, digest validation at line 242 and per-reviewer binding at line 265 (primary git grep result 1f4bd8). Reintroducing duplicated older code is unnecessary for these behaviors.

Next integration rule: retain current main's implementations of these already-present behaviors and assess only genuinely missing PR deltas against the merge base and both endpoints. The other conflict groups, including panelist inputs and identity/registry evidence, remain unresolved. This note is not a completed merge plan, quality-gate PASS or issue-closure evidence.

## Resumed primary comparison: collector and registration boundaries

Primary compared the same exact endpoints directly, not just merge-base-to-PR:

- `prepare-panelist-input.sh` (1a63a0): the older PR removes the explicit named-key-file fail-closed branch and can fall back to the home key when the named file is missing. It also replaces the Outputs-section history anchor with the last report-file commit and removes the concrete sanitized missing-evidence location. Preserve main's key selection, section anchor/private temporary-file cleanup, and diagnostic behavior.
- `prepare-panelist-input.ps1` (926c59): the older PR similarly reverts explicit key-file handling, literal-path/UTF-8 handling and the exact whitespace trimming set, and removes the shared output-row parser and section fingerprint anchor. Preserve main's corresponding behavior; do not reinstate the older duplicated parser solely to resolve text conflicts.
- PowerShell implementation/task prechecks (bd5420): the older versions remove reviewer-contract agreement checks, case-sensitive digest validation, AC coverage, task lifecycle normalization and frozen-artifact diagnostics. These current checks must survive integration.
- `AGENTS.md` / `specs/workflow-state-registry.json` (e7784e): retain existing A6/A7/A8 and domain-concept registrations and the current report identity-field contract. Add A5 registration alongside them rather than replacing them. Retain the current allowed `Done` lifecycle status; the older PR's removal is not required to add A5.

Runner comparison (21efbe, partially displayed) also exposed reversions of current CLI invocation/isolation, shared helpers and JSON extraction. That output was truncated; it is a warning requiring full per-file inspection, not a completed runner review.

No protected file was edited, no implementation was executed from another location, and no merge resolution has yet been applied. Identity-ledger reconciliation and the complete test-union review remain required before an integration candidate can be accepted.
