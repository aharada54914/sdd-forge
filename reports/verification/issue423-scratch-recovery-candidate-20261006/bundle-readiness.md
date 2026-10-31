# Issue 423 bounded recovery bundle readiness

Status: RELEASED for the bounded three-target human application; source application remains pending.

Owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`
Observed HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`.
Scope: protected/high-risk, two review-context validators and their existing boundary contract only. Existing unrelated dirty changes are retained. No historical report, ledger, reservation, task state, approval, verdict or Git history is changed.

## Prepared application

`human-apply.candidate.py` pins the owner, HEAD, three current target hashes and candidate bytes. It checks every target and parses both runtime candidates before any application. It refuses modified, already-applied and mixed states rather than assuming they are safe to resume. The human-only write branch preserves original bytes in a backup, rechecks all targets before the first write, checks each immediate preimage and verifies every readback. A partial write failure requires inspection of the retained backup; no automatic rollback or blind retry is performed.

`RELEASED = True` releases only the approved human-application scope. Only dry-run preparation has executed. The write path has NOT been executed or behaviorally proven; no rollback has been executed.

| Target | Original SHA-256 | Prepared SHA-256 |
|---|---|---|
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh` | `134fd5fad980cdbfc08cb18126aea8b4f9f81c8a92e8036338d36609a9a18f6d` | `e59da652db0accb86b93ef00ce763efc83dbc5d0443685d2e1473181d5365ab0` |
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1` | `3f0d4a9d7f3d40c0ab2543d0b8b7a2397b0399429c46b38450a9183cb4ad65f1` | `9f7a259070605c0520eb48186fcb466d586cdc3f36d63617f17f794f86ecac03` |
| `plugins/sdd-review-loop/references/review-context-boundary.md` | `94cf8bf3ed973cc7240d3fa264b150f3f654642831095eb3d433cb4dc62baab4` | `e72cc24c5fbfffd3668076cf2e374c733ff888dc06224ff2a1c9ce1c6dadfb50` |

## Executed preparation checks (before release)

- `rtk proxy python3 -B reports/verification/issue423-scratch-recovery-candidate-20261006/human-apply.candidate.py --dry-run`: exit 0; three before/after hashes matched, Bash and PowerShell candidate syntax accepted. No application or product execution.
- `rtk proxy python3 -B reports/verification/issue423-scratch-recovery-candidate-20261006/human-apply.tests.py`: exit 0; 13 read-only preparation assertions passed, including target drift/already-applied bytes and candidate drift rejection.
- Application script SHA-256: `72d7bb399bbda72ac2b08fc615f26d9e7fbcffc1c73ccc034f02a4f1003620f8`.
- Preparation tests SHA-256: `a88c99f9b5434ed5c8bcae3a15b3410fbafa695ce7d1ccdf4e7f5fbbd4de772b`.

The earlier 62 candidate-validator checks are recorded separately in `integration-verification.md`; they were not rerun as part of these preparation checks and do not prove receipt provenance or formal admission.

## Management release, 2026-10-06

The existing explicit limited-recovery approval and the primary agent's management adoption authorize this three-target application bundle. The unused ticket identifier was checked before creating `docs/review-tickets/RT-20261006-001.yml`; it remains open with zero review cycles. Ticket SHA-256: `44d162eb892c08206b14e6068fd37fb51e7799777e7f784470583c826d4e6100`.

The independent agent's `independent-source-inspection-20261006.md` was read and its SHA-256 verified as `8fd0a2a3b5f438174362813ca00babb60fe9d67dd8f969b9f8fe694a8a28a6bd`. Its limited native observations establish the declaration location only. They do not prove historical scratch existence/isolation, original report bytes, or native/logical identity equivalence. This management inspection is not a formal quality-gate verdict or signature.

After release, the same dry-run command again exited 0 with all three old/new hashes and Bash/PowerShell syntax accepted. The preparation tests again exited 0 with 13 assertions passed. No product candidate bytes changed during release.

- Released application script SHA-256: `120101b4b7ca543e6d0adcd308ea1001ec9d038bba7996947c661bf0fbd12083`.
- Released preparation tests SHA-256: `b3d187dda1ca3c72b5ddc87ec9b822fcdf8bbaa7f35ebb2ab0213d0d1e4e0a0f`.

Human application command:

```sh
cd /Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge && rtk proxy python3 -B reports/verification/issue423-scratch-recovery-candidate-20261006/human-apply.candidate.py --apply-human
```

## Remaining receipt-admission and evaluation prerequisites

The proposed boundary contract requires a genuine completed independent recovery review of the observed owner evidence and exact recovery bytes. A hash or self-authored observation is not a signature or independent provenance proof. The current-cycle declaration must bind that completed review's exact bytes in its Post-Fix Artifacts table alongside the three recovery artifacts. `current-cycle-declaration.candidate.md` still lacks the fourth exact review row and authorized adoption and remains invalid for formal use; the management inspection is not automatically promoted to a role-input-limited quality verdict.

This bundle does not copy the declaration, install a receipt, admit recovery input or reserve an evaluator. It must not do so automatically. The sanctioned human application is still required to change the three protected originals. Receipt admission separately requires the authorized declaration and exact independent-review binding. Original-path behavioral regressions, independent evaluation, CI and merge remain pending.
