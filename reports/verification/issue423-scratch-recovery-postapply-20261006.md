# Issue 423 scratch recovery: post-application checks (2026-10-06)

Owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`. HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`. Scope is the approved high-risk/protected three-target recovery. The checkout was already dirty; no protected original, ledger, reservation, task status, approval, verdict, or Git state was changed in this verification. The nonfrozen `recovery-validator.tests.py` gained `--applied-originals` so the existing 62 cases invoke the two actual installed owner scripts rather than candidate copies.

Applied-original SHA-256 readback, before and after tests:

| Original | SHA-256 |
|---|---|
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh` | `e59da652db0accb86b93ef00ce763efc83dbc5d0443685d2e1473181d5365ab0` |
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1` | `9f7a259070605c0520eb48186fcb466d586cdc3f36d63617f17f794f86ecac03` |
| `plugins/sdd-review-loop/references/review-context-boundary.md` | `e72cc24c5fbfffd3668076cf2e374c733ff888dc06224ff2a1c9ce1c6dadfb50` |

All commands used `rtk proxy` in the owner checkout with non-login shell. These are diagnostics, not formal gate results:

- `rtk proxy python3 -B tests/review-scratch-history.tests.py --repo .`: exit 0, PASS 26 / FAIL 0; Bash and PowerShell invoked the two applied original validators in disposable repositories.
- `rtk proxy python3 -B reports/verification/issue423-scratch-recovery-candidate-20261006/recovery-validator.tests.py --applied-originals`: exit 0, PASS 62 / FAIL 0; Bash and PowerShell commands point to applied original paths. Covers valid/prefix admission, scratch overlap, malformed/forged receipt and owner evidence, undeclared or mutated artifacts, and declaration hash failures. Fixture reservations occur only in temporary directories.
- `rtk proxy bash tests/review-context-boundary.tests.sh`: exit 1 at citation check before its later behavioral cases. The applied boundary document still cites `validate-review-context-set.sh:1221` for the ledger digest comparison, but the construct is now at line 1282. Do not count this suite as passed.
- `rtk proxy bash tests/review-agent-isolation.tests.sh`: exit 1 at ANNOT-01. The synthetic implementation report fixture has no Run ID/session match to its manifest; the validator rejects it with `REVIEW_CONTEXT_IDENTITY: implementation report run/session does not match its manifest`. Do not count this suite as passed or classify the underlying annotation behavior from this run.

Remaining regular path: resolve the two test failures through the approved protected/high-risk workflow (or establish that a fixture-only correction is within its existing approved scope), rerun the affected original-path suites, then obtain independent review and applicable CI at the exact final HEAD. The current-cycle gate declaration still requires the genuine independent recovery review's exact hash as its fourth Post-Fix Artifacts row and authorized adoption before receipt admission and a fresh quality-gate run. No declaration, receipt or formal evaluation was created here; no task is Done on these diagnostics alone.
