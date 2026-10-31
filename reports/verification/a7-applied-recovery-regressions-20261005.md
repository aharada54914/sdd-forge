# A7 applied recovery regression verification

Status: regression evidence only; formal review, live recovery, CI and merge remain unverified.

Owner checkout: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`
HEAD: `d64cffcb22b114779202847be33e41700c4ba11f`
The checkout is dirty. This result is for the applied working-tree files, not HEAD alone.

## Applied inputs

- spec-review-precheck.sh: `7c540cb425de6ee430689d0d4bb02ba6068c0c9dee7401c8d6e5dd8b1a1f24d6`
- spec-review-precheck.ps1: `294956150a5bcfafc2d500e35aa9d6d247e5470162431dd5eb45a965ebb52528`
- spec-review-loop/SKILL.md: `8828e5103b669e39385f60720d2cc6a02e40f14d6e1e7758d3c07a94dfbfa7d4`
- fresh-review-recovery.py: `b45adc1a7cb445819ce98f58aeb42db630cc4f32b36e0b950279404c3a8528f0`
- spec-review-fresh-recovery.fixture.py: `b42bef4065a3c40f95eb5d96e3b1c76201086fad1e568cf0f76c408bdcd6dd11`

## Commands and observed results

Executed from the owner checkout:

```sh
rtk proxy env TMPDIR=/private/tmp python3 specs/epic-195-a7-compatibility/verification/spec-review-fresh-recovery.fixture.py
rtk proxy env TMPDIR=/private/tmp python3 specs/epic-195-a7-compatibility/verification/spec-review-interrupted-recovery.fixture.py
rtk proxy git diff --check
```

Fresh recovery: exit 0; 18 PASS groups, nine each for Bash and PowerShell.
Covered valid recovery, changed current input, wrong attempt, changed evidence hash,
missing reservation, reviewer-B invocation, transcript session mismatch, terminal
contract change, and post-lock ledger mutation. The fixture also asserts preservation
of historical evidence and rejection of replay.

Interrupted recovery: exit 0; 30 PASS groups, fifteen each for Bash and PowerShell.
Covered valid recovery and immutability/replay, missing/altered invocation,
missing reservation, reviewer-B invocation, existing reviewer output, changed
allocation, nonterminal predecessor, occupied destination, mixed historical roots,
external paths, manifest mismatch, valid foreign historical root, unrelated later
ledger record, and invalid arguments.

Whitespace check: exit 0, no output.

The first fresh-fixture run using the normal macOS temporary-directory alias failed:
`contract must be a regular, non-symlink file`. `/var` resolves through `/private/var`.
Using canonical `/private/tmp` allowed the fixture to satisfy the unchanged regular-path
contract. This is not proof that the default fixture invocation works; canonicalizing
the fixture's own temporary root is a separate proposed test portability correction.

## Remaining boundary

These isolated tests do not resolve the independent static audit's four findings:
approval-record binding, an unproven historical transition, persistent recovery-contract
location, and overclaiming transcript evidence. The next candidate must explicitly
quarantine unsupported historical conclusions and require a fresh current-input review.
No historical PASS, reservation, task status, or Git history was changed by these tests.
Do not treat this report as permission to launch with the audited gaps unresolved.
