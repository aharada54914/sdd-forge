# Issue 423: single human apply batch

Prepared only; agent executed dry-run, never apply. No behavioral GREEN claim.
The sdd-verification-apply skill governed the pinned scope, original-byte backups,
readback and separation of application from verification.

Owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`
HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`.
Script: `reports/verification/issue423-manifest-binding-human-apply.py`
Script SHA-256: `7a0732632570770c853f915a85f51a698c053375bf06eed96d63dd90420e098c`.

## Exact application scope and pins

| Target | Before SHA-256 | Expected after SHA-256 |
| --- | --- | --- |
| plugins/sdd-quality-loop/scripts/validate-review-context-set.sh | 011f1d9c068e7b2f033f02bbae0fd15cf3a9c9c2c7f409c963fc1d9e941fc09b | 2d004b63ba7ec99fa109120c86f91bb7aed7f41b5a461e3b8538b890c7a6aaba |
| plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1 | e8424eb27598222fe527ffaaa296cd287a4c52f850ed05b91e98023c8c4e7925 | 84264f9eb02a25be788c3fe7660950f9a971d926ae5930089b0ea53746bb6bc7 |
| plugins/sdd-review-loop/references/review-context-boundary.md | 07f7834c17561b3b69093f91b32c7c5d4d655e9bc21bf2ff8bec6322fb02152a | 94cf8bf3ed973cc7240d3fa264b150f3f654642831095eb3d433cb4dc62baab4 |

The first two changes replace the exact basename regex
`^handoffs/[A-Za-z0-9._-]+/manifest[.]json$` with
`^handoffs/[A-Za-z0-9._-]+/manifest(-[A-Za-z0-9][A-Za-z0-9_-]*)?[.]json$`.
The third appends seven contract-documentation lines defining that bounded
version suffix and retaining exact evidence binding. The script prints the full
unified diff before any possible write. All other existing dirty bytes are retained.

## Conflict with earlier repair batches

Do NOT chain or rerun `issue423-quality-launch-human-apply.sh`,
`issue423-quality-auth-boundary-human-apply.sh`, or
`issue423-launch-repair-human.py` as part of this batch. They overlap these targets
and pin older source states (launch: Bash `8e5e885c...`, PS `179fdb17...`, docs
`b537052a...`; auth: Bash `4dffb010...`, PS `13541b8d...`, docs `bf7ead45...`).
The current batch pins the already-dirty, later owner bytes. Any change from
another repair makes this batch stop; do not refresh pins automatically.

## Human commands

Execute from an ordinary human-controlled terminal, not an agent executor.
Verify the script hash above before application. Do not apply while another
process edits the three targets.

```sh
cd /Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge
rtk proxy shasum -a 256 reports/verification/issue423-manifest-binding-human-apply.py
rtk proxy python3 reports/verification/issue423-manifest-binding-human-apply.py --dry-run
rtk proxy python3 reports/verification/issue423-manifest-binding-human-apply.py --apply-human
```

The apply mode checks HEAD, regular/non-symlink paths, all three original hashes
and unique anchors before writing. It first creates a unique
`reports/verification/issue423-manifest-binding-backup-*` directory, copies and
verifies every original dirty file, rechecks sources, then writes only the three
targets with immediate exact-byte readback. Backup metadata is preserved.
On any interruption, retain the printed backup and inspect current hashes; do
not rerun blindly. No automatic rollback overwrites potential concurrent work.
Recovery must compare current content and restore only this batch's changes
from the saved original bytes under human control.

## Observed dry-run

`rtk proxy python3 reports/verification/issue423-manifest-binding-human-apply.py --dry-run`
exited 0 and emitted the three before/after hashes above, full diff and:

```text
DRY_RUN_OK: exactly 3 targets; no files written; no product execution
```

No product candidate was executed, no backup or protected write was performed,
and no identity was reserved. After human application, run the focused and full
`tests/issue311-scratch-isolation.tests.py` suites and `git diff --check` as listed
in the earlier filename-binding candidate note. Formal evaluator identity,
protected input-read boundary and quality-gate status remain separate unresolved work.
