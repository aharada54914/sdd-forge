# #423 follow-up original-path verification (2026-10-06)

Owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`. HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`. Checkout was already dirty; `git status --short` listed the three targets below as modified among other pre-existing work. No protected source, registry, ledger, task status, verdict, or Git state was changed in this verification.

The three original-path SHA-256 values now equal the postimage pins in `reports/verification/issue423-scratch-recovery-candidate-20261006/postapply-followup-human-apply.py`:

| Original | Applied SHA-256 |
|---|---|
| `plugins/sdd-review-loop/references/review-context-boundary.md` | `47dde31388cd0ec008608397eb7ab0406329e8bd13cd2cf45c38cefed3e07f03` |
| `tests/review-context-boundary.tests.sh` | `f33b5df68333efbfe8e18e929a0e2d8a829967b9499808f01782eb26e73849af` |
| `tests/review-agent-isolation.tests.sh` | `c7277d756929bab28869a7b6caa88a8965714b5a47437a5397f48690601d226b` |

Executed on those originals, not on a candidate copy:

- `rtk proxy bash tests/review-context-boundary.tests.sh`: exit 0; final output `PASS: 84; FAIL: 0`. The suite reported `32 anchors verified`, Bash/PowerShell reservation/verification cases, and expected path/hash refusals.
- `rtk proxy env T005_SOURCE_GIT_ROOT=/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge bash tests/review-agent-isolation.tests.sh`: exit 0; reported distinct, authorized, hash-chained reviewer/evaluator contexts and final `PASS: 26; FAIL: 0` for nested Bash/PowerShell scratch-history cases. `T005_SOURCE_GIT_ROOT` provided the read-only tracked source to the suite's isolated fixture.

This is affected regression evidence, not a formal recovery-review outcome or quality-gate verdict. The canonical adjacent receipt `reports/implementation/sdd-domain-multitarget/T-003-attempt2.scratch-owner.json` was still absent in an `rg --files` check. The current-cycle four-row declaration has not been adopted; `reports/verification/issue423-scratch-recovery-candidate-20261006/current-cycle-declaration.candidate.md` remains a candidate outside the quality-gate directory. Next, continue open `docs/review-tickets/RT-20261006-001.yml` through the existing authorized recovery-review and receipt/declaration admission path described in `reports/verification/issue423-scratch-recovery-candidate-20261006/receipt-declaration-readiness-20261006.md`, then ordinary T-002 preflight and quality gate. Recheck current input hashes at that point. No reservation or formal admission was attempted here.

Current four-input readback matches that readiness note: historical report `a204e954986c2207f9719174f11c5fca2cf9fcbb877828d78f06f5fea7a6d462`; receipt candidate `1a2a624f1b6ef291384172914f851cc90a150a60bfdde045bd8403b939ae34d0`; owner observation `4114ddada34bdf7d76d158f5321c4f8b3772517372980a86be726e0b8a04d679`; independent source-inspection record `8fd0a2a3b5f438174362813ca00babb60fe9d67dd8f969b9f8fe694a8a28a6bd`. The applied boundary contract requires a completed independent recovery review with an outcome and a current-cycle declaration that pins it alongside the three recovery artifacts. The existing source-inspection record expressly labels itself a bounded management inspection, not formal approval, admission, or verdict; its qualification as the completed current-cycle recovery review is not established by this regression run.
