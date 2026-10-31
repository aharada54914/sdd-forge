# A8 two-input oracle: consolidated adoption package

Preparation only. No protected/frozen source applied, candidate driver executed,
identity reserved, review verdict issued, lifecycle changed, commit or push made.
This is an author-checked package, not an independent or formal review PASS.

Owner checkout: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`

Inspected HEAD: `495c88d67af44530687ecea3ce9fb0a90a336539`.
Preserve the dirty checkout: the hashes below include its existing task changes.

## Adoption boundary and sequence

1. Design owner legitimately adopts the three-target design patch and the new
   ADR as one design amendment. Explicit frozen-content authority and the
   existing human-only application boundary remain prerequisites. This package
   does not establish either authority or a new application route.
2. Rebind the amended design through the existing independent implementation
   policy review, including the declared ADR and all normal canonical inputs.
   Rebind tasks with the complete amended design predecessor and layer inputs.
   Old Passed fields do not certify changed bytes; do not launch implementation
   using those historical fields alone.
3. Only after those reviews, adopt the two-target driver patch for approved
   T-001, then run its real fixture entry points and sensitivity checks below.
   Native CLI evidence remains a subsequent, separately gated check.

`tasks.md:43` says **No task drafts a new ADR**. ADR creation belongs to the
preceding design amendment, outside T-001 implementation; T-001 consumes the
already adopted design. If the design owner intends ADR creation inside T-001,
the existing task constraint must first be explicitly amended and re-reviewed.
There is no need to alter T-004 or create a generic admission framework.

## Immutable candidate inputs

Paths are relative to the owner checkout.

| Input under reports/verification/ | SHA-256 |
|---|---|
| a8-nonce-design-revision-20261005.patch | 51283f7c22548b55a55b3e930e4670b6d03faf9d0e835f73c067cb48aeb35a45 |
| a8-nonce-adr0035-candidate-20261005.md | 50cf6c313940ccfa182cc8632d59215430183957e6e0ea02d6d064c934109923 |
| a8-nonce-driver-minimal-candidate-20261005.patch | 446b149577681c3f69f3561796f6d0b69eee67871725ff1192bff273c881ca61 |

## Target pins and readback

| Stage / target | Exact before SHA-256 | Expected after SHA-256 |
|---|---|---|
| Design: specs/epic-196-a8-integration/design.md | 14862a80a6f44b49dbf7e1393af66c82c0434bf1109b248e7ff9b4b695fcd18c | 6485d5585fd37fe9ce298b295168ad2304d6dec6a1c7dc768bf76bbebf8c1aa3 |
| Design: specs/epic-196-a8-integration/tasks.md | 8c17b0f6b2fa299d23ce6e892a8e80a841ac4ab68d613c84d6c36fe09bbcde66 | 44b3658c28a1e216239b46a5bd80e58776099e1a4efd7e9e77b0728118634f6b |
| Design: docs/adr/README.md | 56d9d0197f1978f27724f506631b7a3f16d334bd2bee09adda594ad9264dd07f | 0d99d8f8215cbca6e7d92d218fec1e3a62364d5b581c90f891fec5d322018786 |
| Design: docs/adr/0035-a8-two-contribution-handoff-oracle.md | ABSENT | 50cf6c313940ccfa182cc8632d59215430183957e6e0ea02d6d064c934109923 |
| Driver: tests/cross-runtime-handoff.tests.sh | 479ab524fae57a47c117129f16fcf045b7010af9544f181bb369389d957027ae | fe2dfc070e6290f2afc399d5a21176d19876c647de0edec98a0c17603ae26d25 |
| Driver: tests/cross-runtime-handoff.tests.ps1 | 8a01086d9612cf4f21a243ac407fef5cb26af9f94082209927e12e118daf29f9 | 4d87f40fb97f33c4f80d6eb0bdbedc615b94844f33b775f59f7f6fb9a154eab6 |

Before adoption recheck ADR 0035 in current shared refs and active candidates;
the local canonical path is absent at inspection, not reserved. A collision or
any changed base byte requires revising/re-pinning the package, not overriding
its expected hashes. Input patches use zero context. The README hunk declares
line 319, but its unique exact old row is at line 265 in the pinned base. This
offset is known, not permission to accept other mismatches.

## Executable design-stage helper

`reports/verification/a8-nonce-design-human-apply.mjs` is the bounded human
helper for stage 1 only. Existing T-004 and PR513 helpers target other changes
and must not be reused for this amendment. From the owner checkout:

```sh
rtk proxy node reports/verification/a8-nonce-design-human-apply.mjs --check
```

Executed exit 0: four design targets checked, all pinned hashes and reconstructed
after hashes match, `git apply --check --unidiff-zero` succeeds, ADR target and
0035 namespace in local files/refs are absent. No write or backup occurred.
It does not fetch remote refs or discover other worktree proposals.

After the authorized human confirms the design-adoption authority and current
shared ADR namespace, that human's application command is:

```sh
rtk proxy node reports/verification/a8-nonce-design-human-apply.mjs --apply
```

Agents must not execute that operation after a refusal or as a bypass. The
helper admits only these design-stage targets, pins owner path/HEAD, rejects
noncanonical files and changed hashes, backs up all three existing design
targets plus candidate inputs and itself, records the new ADR's ABSENT state,
rechecks bases, applies the existing patch, creates the ADR exclusively, and
verifies all four readback hashes. It never applies driver changes or modifies
approval/status fields beyond the existing candidate. Backup path and receipt
are printed/persisted. A failure after writing is explicitly partial; it retains
the backup and never auto-retries or silently restores intervening changes.

## Backup and recovery contract (not executed)

Before the first design write, the helper creates and reports a unique
`a8-nonce-design-backup-*` directory and verifies the three design originals
against their before hashes. These are raw working tree bytes, not HEAD
versions; restoring from Git would lose prior task edits. Driver originals
must separately be backed up and pinned when stage 3 becomes authorized.

Backup status now: **NOT CREATED**. No source write was attempted, so no new
restore point is claimed. The pre-write backup is a mandatory operator step.
Record the actual backup path in the adoption receipt. Recheck driver hashes
again immediately before stage 3.

Apply only the declared design patch and exact ADR body through the authorized
route, then read back all four hashes. After reviews, separately apply only the
driver patch and read back both hashes. Do not use this package to retry a
refused source write through another tool or copied executable.

Recovery is limited to the six targets. Restore an existing target from its
verified backup only when its current hash is this package's expected-after
hash; otherwise stop to preserve intervening work. Move the newly created ADR
into the backup directory only if it matches its expected-after hash and no
new review depends on it. Restore each stage atomically at the workflow level;
do not leave a new design with an old task scope or a new oracle with old prompt.

## Verification to execute after adoption

From the owner checkout:

```sh
rtk proxy bash tests/cross-runtime-handoff.tests.sh
rtk proxy pwsh -NoLogo -NoProfile -NonInteractive -File tests/cross-runtime-handoff.tests.ps1
```

Record full exit/output, hashes, and evidence paths. Confirm both newly added
independent one-input mutation loops actually execute; activation prerequisite
failure must be distinguished from fixture failure. Preserve pre/post originals
and use the legitimate test workflow to demonstrate that either a nonce2-only
consumer or nonce2-only expected oracle causes the strengthened fixture to fail.
Do not claim acceptance sensitivity solely from an unchanged positive run.

Native entry points are `--live-e2e` / `-LiveE2E` on those same drivers, but
require the separately verified explicit supported model, current permissions,
and native launch contract. This package does not supply or relax those inputs.

## Checks performed for this package

The bounded read-only dry run reconstructed five target results in memory from
the exact candidate hunks, verified each old span occurred exactly once, and
computed the before/after hashes above. All eleven hunks were located; only the
documented README line offset differed. Exit 0. A preceding exact-line-only
probe stopped on that README offset before any write; its partial results were
not reported as a complete check. Local ADR absence was verified.

No driver or candidate oracle execution occurred in this package preparation.
Prior feasibility evidence remains in
`a8-nonce-runtime-feasibility-result-20261005.md`: it demonstrated the old
nonce1-insensitive oracle and the proposed two-input expression in both
runtimes, but does not verify this full driver patch or real Copilot file reads.
New behavioral verification, native-host proof, independent review, quality
gate, current-head CI, merge, and post-merge delivery are outstanding.
