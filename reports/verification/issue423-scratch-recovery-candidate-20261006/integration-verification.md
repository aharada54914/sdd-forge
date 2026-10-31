# Issue 423: candidate scratch-history integration

Date: 2026-10-06. Candidate verification only; no formal gate verdict.

Owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`.
HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`.
Risk: high (protected validation and evidence interpretation).
Task: unblock T-002 independent evaluation without altering historical T-003 records.
Authority: existing user-approved limited recovery-contract repair; adoption and
formal management remain required. This record does not approve its own candidate.

The owning checkout had 124 short-status lines and 20 modified tracked files,
including both validators, boundary contract, task/report records and ledger.
Those changes belong to the existing work and were neither discarded nor edited
by this candidate task. New files are confined to this candidate directory.
No owner reservation, task status, review verdict or Git history was changed.

## Scope and affected contracts

Two embedded scratch-history helpers receive one relative historical-root path.
The existing canonical/containment/overlap functions and manifest admission are
reused. No arbitrary historical-owner map, role allowlist or ledger extension
is introduced. The proposed boundary addendum is in
`contract-addendum.candidate.md`; proposed source diffs are
`validator-sh.candidate.patch` and `validator-ps1.candidate.patch`.

Before hashes:
- Bash: `134fd5fad980cdbfc08cb18126aea8b4f9f81c8a92e8036338d36609a9a18f6d`
- PowerShell: `3f0d4a9d7f3d40c0ab2543d0b8b7a2397b0399429c46b38450a9183cb4ad65f1`

Candidate hashes:
- validator-bash.candidate.txt: `e59da652db0accb86b93ef00ce763efc83dbc5d0443685d2e1473181d5365ab0`
- validator-pwsh.candidate.txt: `9f7a259070605c0520eb48186fcb466d586cdc3f36d63617f17f794f86ecac03`
- recovery-validator.tests.py: `3b2e1055a9160e54291f6726a4e63fee61f3cff5272eca67e4926253883bd751`
- validator.tests.py: `19c88d083df0f348c3c6d2e9d4644781d630ca0a752ad2f00eef5e1a09bdface`

## Executed verification

From owner, using rtk proxy, Python -B:

1. `recovery-validator.tests.py`: session 23897, exit 0, PASS 56 / FAIL 0.
   Both real validator candidates run in disposable fixtures. Valid and sibling
   prefix cases succeed; equality/ancestry, path escape, wrong identity/type,
   different owner, duplicate keys, missing admission and changed artifacts
   reject. Negative cases check ledger unchanged and exclude premature
   role-unlisted/contract rejection. These are fixture reservations only.
2. `validator.tests.py`: session 98081, exit 0, PASS 26 / FAIL 0.
   Existing `tests/review-scratch-history.tests.py` runs unchanged against both
   candidates, including snapshot tamper/deletion, missing history, root
   omission/change and equal/parent/child/prefix checks.

Earlier prototype 54 checks remain prototype evidence only. Earlier integration
fixtures that failed before reaching scratch validation are not counted here.
This final run includes same-checkout rejection absent from those earlier runs.

## Limits and next required validation

Hash matching proves admitted bytes, not owner-observation authenticity. The
source inspection requirement in the contract candidate needs independent review.
Synthetic Outputs admissions in the fixture do not authorize editing frozen
real implementation reports. Real adoption uses the existing recovery declaration
and exact admitted Post-Fix Artifacts channel.

Required next: independent candidate/contract diff review; formal contract
adoption and protected application; original-path affected regressions;
current invocation input revalidation; independent evaluator admission and
quality gate; exact-head CI and safe delivery. Native activation remains separate.
No human application command is provided before independent review.

## Patch packaging check

`git apply --check` for both candidate patches exited 0; no patch was applied.
The first packaging check detected a missing final blank context line. Hunk
counts were corrected in the patch artifacts only; tested candidate bytes were
unchanged. Final patch SHA-256:

- Bash: `842ddf960d3ae90da5f12ed93c9a4583be1fadb024d45e58a7d85b9c2f999dbb`
- PowerShell: `8518812a6b7b2f1b20fa44630b2ce633d8d1dcffe2b1df42537fb1ab2001616a`

## Declaration-channel regression follow-up

The revised fixture leaves implementation-report Outputs unchanged and admits
the three recovery inputs through a hash-pinned gate declaration's Post-Fix
Artifacts. Earlier 56-case results above describe the previous fixture only.

Current test SHA-256: `c16a955a47c485c7a24fa3e0675f425702f8fa47e7b10c5d4768fcc2543f3a4e`.
Command from the same owner: `rtk proxy python3 -B reports/verification/issue423-scratch-recovery-candidate-20261006/recovery-validator.tests.py`.
Parent rerun session 51726 completed with exit 0: PASS 62 / FAIL 0.
Both Bash and PowerShell cover missing declaration, each unlisted recovery input,
incorrect declared hashes and declaration mutation; rejected fixtures preserve
their ledger. Candidate validators and real historical reports were unchanged.
This verifies the declaration admission channel, not native observation
authenticity, protected application, formal evaluation, CI or delivery.
