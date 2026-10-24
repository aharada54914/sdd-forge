# Independent T-001 review — prior frozen candidate

**NEEDS_WORK: 2 Major findings and 1 Minor coverage finding.** This verdict binds commit `d56313b0e2cbf10fa1154a664780030f8ff2756c` and the prior 716-result source pins. The author's corrected candidate is pending its own final freeze and bounded recheck.

Reviewer: Work context `/root/review_mode_compat`, independent of source author `/root/a9_t001_impl`. This is ordinary independent code/content review. No native reviewer identity, formal model adoption, quality-gate Passed, task Done or real recovery is claimed.

## Findings

**F1 — Major: ambiguous B attribution is accepted.** The Bash `relative()`/correlation logic and PowerShell `Get-RecoveryRelative`/correlation logic strip only the current root and otherwise treat an unfamiliar path as unrelated. In owned fixtures I added a valid-chain later `spec-reviewer-b` record with a matching raw input-binding manifest under a non-source filename. Its source precheck reference used either `./reports/spec-review/.../attempt-3/round-3/precheck-result.json` or `/historical/checkout/reports/spec-review/.../attempt-3/round-3/precheck-result.json`. Both actual runtimes returned **0** for both cases. The clean control also returned 0; every fixture remained byte-identical. This violates the contract's requirement to reject ambiguous source-B attribution (semantic6; TEST-024/025/080). It proves admission of malformed/ambiguous evidence, not a genuine native B launch. Correct path attribution or reject unresolved forms, retaining valid unrelated later-reviewer controls.

Evidence: `/workspace/a9-t001-independent-probes-20261024/probe.py` and `results.json`. The original six source hashes match the committed blobs and preserved author pins.

**F2 — Major acceptance/evidence gap: the frozen all-variants Red→Green condition is unsatisfied.** `tasks.md:50` requires every assigned concrete case/variant to have Red then Green. Each original Red log instead records two already-correct PASS controls, one `ADMISSION_NOT_IMPLEMENTED` failure, and **530 NOT_RUN cases**. The later 716 passing outcomes cannot retrospectively establish those individual Reds. Genuine later defect-specific Reds, unchanged baselines, current Greens and unexecuted cases must remain separate. TEST-041/042's origin procedures also remain explicitly not independently executed; genuine AUTH-001 is unavailable. This is a real acceptance gap, not an instruction to fabricate Reds or human provenance.

The external one-sentence criterion proposal (SHA-256 `6e72240b5298c43925d80a463477b267fb122287ce21d290b23032a48e23c244`) is adequate for consideration: it preserves assigned IDs/variants, both runtimes, genuine changed-defect Reds, baseline provenance, rollback, independent review and origin requirements. It does not turn missing baseline results into success. It is **not approved or applied**; the frozen criterion and this gap remain in force. Any retrospective baseline must identify its real historical source and execution time. Root owns the necessary authorization/provenance reconciliation.

**F3 — Minor coverage gap: all expanded IDs is not all planned variants.** The prior inventory's TEST-057 cases cover fourteen reference SHA slots × six variants. The additional `reviewer_a.record_sha256` uppercase/nonhex/short cases explicitly listed in the saved design are missing; missing/null are covered by F21, and an incorrect digest by TEST-074. The frozen base TEST-057 calls for each hash slot independently. Also, saved TEST-043 canonical Unicode equivalence, wrong ensure_ascii, extra hash-input newline, omitted-field and array-order cases cannot be inferred from one key-order/whitespace positive and one all-zero-digest negative. Add or map these cases individually and distinguish the saved design from executed evidence. The author acknowledged these gaps; prospective corrections are not yet reviewed.

## Verified scope and limits

- Read the fixed requirements, design, task, AC, contract and layer/traceability instructions. Reviewed the six production/test/catalog paths and reuse of real own-stage contract validation and persisted identity verification without reservation. The T-001 predicate remains separate from T-002 publication/locking work.
- Independently matched every named outcome in both stable logs to the inventory: **716 unique outcomes per runtime = 713 concrete variants + 3 controls**, with no missing/extra names. This confirms those recorded Greens, not complete saved-plan coverage or individual historical Reds. No large suite was rerun.
- Six narrow actual PowerShell parser assertions passed: ISO-looking string stays string; Boolean, Int64 and Double remain distinct; decoded duplicate names and `1e999` reject. `System.Text.Json` is framework-provided on the modern .NET floor already required by existing `ToHexString`/`SHA256.HashData`; no unsupported Desktop claim or new external parser package is required. Windows execution remains unverified here.
- Recovery references enforce exact keys/types/hash/path inventory and repeated input pins; authorization binds content/digest only. Hashes and fictional fixtures do not establish human authorship. The actual original human approval/application dependency remains outside synthetic validation.
- The existing report honestly labels its Work authoring identity and incomplete formal identity. The saved 752-case preparation is design, not execution. The external criterion proposal removes no origin case or runtime requirement.

Only external review/probe artifacts and owned temporary synthetic fixtures were written. No production source/Git changes, provider calls, live historical recovery, real reservations or live/root/other-worktree ledger reads occurred. This review cannot supply model adoption, formal quality approval, Windows CI or T-002/T-003 validation.

## Source hashes

- `plugins/sdd-review-loop/scripts/spec-review-precheck.sh`: `3403caa958c01eae9dff21bbd3add09f650ee829b2090b759cedbd420fcb2878`.
- `plugins/sdd-review-loop/scripts/spec-review-precheck.ps1`: `475933d20fb314b8f714bd24df2220e3127a78815afa808432c21bc8754a92c4`.
- `tests/spec-review-interrupted-recovery.tests.sh`: `d98fd63093275af7d328870dda9cced3da493d4fd5fce2939d638f32f1505bbb`.
- `tests/spec-review-interrupted-recovery.tests.ps1`: `9f6807548dbe273d0a89c3e218e15c7dcc9b211c518bb1e050230bdf1ecb8d6d`.
- `tests/spec-review-loop.tests.sh`: `4bbc3cc63f97e8f954dd2731a8a609656fe1fbf66a80bc900a8a9eb8862ff79b`.
- `tests/verification-catalog.json`: `128837b2664db266b0a8234c5f75e32a767c28ad91d20e2f11bd4b9065c25317`.

Exact specification, log, probe and proposal hashes are in the companion JSON report.
