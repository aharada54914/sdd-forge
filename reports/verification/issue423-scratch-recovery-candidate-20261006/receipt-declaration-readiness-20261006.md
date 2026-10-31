# #423 receipt and current-cycle declaration readiness (2026-10-06)

Preparation only. Owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`; HEAD `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`. No receipt was placed, no declaration was adopted, and no reservation, admission, quality verdict, task-state or Git operation was performed for this note. The checkout has pre-existing dirty work.

## Current state, not the earlier preapply snapshot

The initial recovery repair's SH/PS/boundary originals are already applied and read back at `e59da652db0accb86b93ef00ce763efc83dbc5d0443685d2e1473181d5365ab0`, `9f7a259070605c0520eb48186fcb466d586cdc3f36d63617f17f794f86ecac03`, and `e72cc24c5fbfffd3668076cf2e374c733ff888dc06224ff2a1c9ce1c6dadfb50`. Applied-original diagnostics passed 26/26 and 62/62, but the two full original-path suites failed on shifted citations and stale synthetic identity. The independently reviewed three-target follow-up candidate is dry-run checked; its human application and original-path reruns are still pending. The older `review-launch-readiness.md` and `bundle-readiness.md` describe a *preapplication* state and their `RELEASED=False` or “no source application” statements must not be reused as current status.

The exact canonical receipt target `reports/implementation/sdd-domain-multitarget/T-003-attempt2.scratch-owner.json` does not exist. The candidate source is `reports/verification/issue423-scratch-recovery-candidate-20261006/T-003-attempt2.scratch-owner.candidate.json`, SHA-256 `1a2a624f1b6ef291384172914f851cc90a150a60bfdde045bd8403b939ae34d0`; its embedded report and observation paths already name the intended owner/current observation. The historical report remains `a204e954986c2207f9719174f11c5fca2cf9fcbb877828d78f06f5fea7a6d462`. The observation candidate remains `4114ddada34bdf7d76d158f5321c4f8b3772517372980a86be726e0b8a04d679`. The retained independent source-inspection record is `8fd0a2a3b5f438174362813ca00babb60fe9d67dd8f969b9f8fe694a8a28a6bd`; it expressly describes a bounded management inspection, not a formal quality verdict, signature, or input admission. All four hashes were recomputed for this preparation.

## Four-row declaration input candidate, not an adopted declaration

The existing boundary contract requires a current-cycle `gate_report_declaration` under `reports/quality-gate/`, itself pinned by hash, whose `## Post-Fix Artifacts` table binds the following exact inputs. These rows are prepared here only; the fourth row is usable only if the authorized recovery reviewer/caller confirms this retained inspection record qualifies as the completed independent recovery review for the actual current cycle. Do not silently promote the management candidate to that status.

| Path | SHA-256 |
|---|---|
| `reports/implementation/sdd-domain-multitarget/T-003-attempt2.md` | `a204e954986c2207f9719174f11c5fca2cf9fcbb877828d78f06f5fea7a6d462` |
| `reports/implementation/sdd-domain-multitarget/T-003-attempt2.scratch-owner.json` | `1a2a624f1b6ef291384172914f851cc90a150a60bfdde045bd8403b939ae34d0` (not yet placed) |
| `reports/verification/issue423-scratch-recovery-candidate-20261006/T-003-attempt2.owner-observation.candidate.json` | `4114ddada34bdf7d76d158f5321c4f8b3772517372980a86be726e0b8a04d679` |
| `reports/verification/issue423-scratch-recovery-candidate-20261006/independent-source-inspection-20261006.md` | `8fd0a2a3b5f438174362813ca00babb60fe9d67dd8f969b9f8fe694a8a28a6bd` (conditional review binding) |

Do not mutate `current-cycle-declaration.candidate.md` into a live gate document: it has three rows, sits outside `reports/quality-gate/`, and neither identifies nor authorizes a cycle. Do not modify historical reports, prior declarations, or ledger records. The private native session JSONL is not a manifest input.

## Shortest existing sequence after follow-up application

1. Human operator applies only the independently reviewed follow-up through the pinned `postapply-followup-human-apply.py --apply-human`, retains backup/readback, then original-path boundary and agent-isolation suites run. A dry-run or isolated fixture pass does not substitute for this.
2. Continue the existing open `docs/review-tickets/RT-20261006-001.yml` through `fix-by-review-ticket`: confirm the native-source inspection's cycle association and independent outcome. If its limited record is insufficient for the contract's completed-review condition, finish that bounded review under the existing ticket/approval; do not invent a new receipt framework, reviewer identity, or verdict. Recheck current hashes.
3. Place the exact receipt bytes at the canonical adjacent path only through the existing authorized recovery step, verify regular/symlink-free path and SHA-256 readback, and keep the unchanged historical report. The observation can remain at its existing candidate path only if explicitly admitted by exact path/hash.
4. The normal T-002 caller creates/authorizes its actual current-cycle quality-gate declaration with the four rows above (or recomputed current hashes), pins that declaration as `gate_report_declaration`, and binds the four inputs explicitly in `allowed_input_manifest`. Recheck every byte, lifecycle, native owner, independence, scratch and ledger prerequisite immediately before ordinary preflight/reservation. This note does not construct an invocation or reserve identities.

Neither the initial three-file application nor follow-up application alone supplies a formal T-002 evaluation. Original-path regression, independent recovery-review qualification, canonical receipt placement, current-cycle declaration adoption, manifest admission and quality gate are separate states.
