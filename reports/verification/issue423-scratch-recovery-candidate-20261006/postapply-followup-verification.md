# #423 scratch recovery postapply follow-up candidate (2026-10-06)

- Owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`; HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`.
- Scope/risk: high-risk protected boundary documentation and its synthetic regression fixtures. This is a candidate, not an application, independent review, or formal verdict. Existing dirty work, frozen records, reservations, ledger, and task status are untouched.
- Applied validator and boundary hashes checked separately: SH `e59da652db0accb86b93ef00ce763efc83dbc5d0443685d2e1473181d5365ab0`; PS `9f7a259070605c0520eb48186fcb466d586cdc3f36d63617f17f794f86ecac03`; boundary `e72cc24c5fbfffd3668076cf2e374c733ff888dc06224ff2a1c9ce1c6dadfb50`.

## Cause and candidate

The applied SH validator inserted the scratch-history guard before the former receipt checks. The boundary document and `review-context-boundary.tests.sh` still cite SH lines 1209/1221/1231-1243, while the same constructs are now at 1270/1282/1292-1304. This is an integration failure caused by the applied change, not an assertion defect. `review-agent-isolation.tests.sh` rewrites synthetic reports after fixture setup in several cases; those rewrites omitted the now-required task-manifest run/session/citation identity fields. Those cases were not current-contract fixtures after the applied validator guard. The candidate changes only citations and synthetic fixture identity, preserving all assertions and validator behavior. Canonical historical evidence is not migrated or edited.

- Candidate: `postapply-followup-v2.patch`, SHA-256 `7e8421bc0f0a19fcfa97b126f094ca4dbec594a16c90b35e2ced60490ed79e8d`.
- Exact targets and preimage → candidate SHA-256:
  - `plugins/sdd-review-loop/references/review-context-boundary.md`: `e72cc24c5fbfffd3668076cf2e374c733ff888dc06224ff2a1c9ce1c6dadfb50` → `47dde31388cd0ec008608397eb7ab0406329e8bd13cd2cf45c38cefed3e07f03` (protected; human application only).
  - `tests/review-context-boundary.tests.sh`: `34eb70012271e5f7f697a0c640fe1a4ce0f547f2ae92569beb5a532cba2e96ca` → `f33b5df68333efbfe8e18e929a0e2d8a829967b9499808f01782eb26e73849af`.
  - `tests/review-agent-isolation.tests.sh`: `7f8d15c2c95aafe4cfa5e812fb2f10c431d775ef0d35aecc72946e932f60c1b9` → `c7277d756929bab28869a7b6caa88a8965714b5a47437a5397f48690601d226b`.

## Executed checks

- Owner preapply check: `rtk proxy git apply --unidiff-zero --check reports/verification/issue423-scratch-recovery-candidate-20261006/postapply-followup-v2.patch` exited 0. The zero-context patch must not be applied without checking all exact preimage hashes first.
- Candidate applied only in disposable copy `/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/sdd423-followup-v2.PinWprLCaj` (copied without `.git`). `rtk proxy bash -n tests/review-context-boundary.tests.sh tests/review-agent-isolation.tests.sh` exited 0.
- In preceding disposable copy `/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/sdd423-followup.QL3SoIsmpK` (same boundary-document and boundary-test candidate bytes), `rtk proxy bash tests/review-context-boundary.tests.sh` exited 0: 32 boundary anchors and Bash/PowerShell TEST-RCB cases passed, including nested investigation checks. In the final v2 disposable copy, `rtk proxy env T005_SOURCE_GIT_ROOT=/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge bash tests/review-agent-isolation.tests.sh` exited 0: isolation checks and nested scratch-history tests (26/26) passed. `T005_SOURCE_GIT_ROOT` only supplies the read-only tracked source to the isolated fixture.
- Owner originals retained their preimage hashes above after these tests. No protected original, validator, ledger, Git state, reservation, or formal task state was written.

Remaining: independent candidate diff review and sanctioned application of the protected documentation change, with exact target/hash readback and original-path regression afterward. Synthetic fixture success does not resolve unrelated canonical production-evidence defects or make a formal quality-gate decision.

## Human-application preparation

The independently reviewed patch has a dedicated human-only helper `postapply-followup-human-apply.py` (SHA-256 `e546660f6464bbd31db52331f137773a80ebc19a5fa7f3790a899fad2cc51403`). It pins owner HEAD, patch bytes, the exact three targets and all pre/post hashes; applies the patch only to a disposable staging directory before any target write; backs up and reads back all originals before writing; checks each immediate and final readback. The operator must not change executors to evade a guard refusal. An agent ran only:

`rtk proxy python3 reports/verification/issue423-scratch-recovery-candidate-20261006/postapply-followup-human-apply.py --dry-run`

Exit 0 with `CHECKED` for all three expected pre/post hashes and `DRY_RUN_OK: three targets; no original files changed`. The three owner originals were rehashed afterward and remain at the preimage hashes above. No application was performed. For the sanctioned human operator, from the pinned owner checkout only, the exact application command is:

`rtk proxy python3 reports/verification/issue423-scratch-recovery-candidate-20261006/postapply-followup-human-apply.py --apply-human`

The helper prints its backup directory and readback hashes; its successful application is not behavioral regression or a formal gate verdict. The original-path boundary and isolation suites must then be rerun.
