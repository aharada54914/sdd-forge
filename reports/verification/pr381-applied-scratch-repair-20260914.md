# PR 381 applied scratch-history repair

Date: 2026-09-14 JST
Base: 14ac111a95375189b1704686f9dae3ff4c9489e0
Review scope: discussion 3991438202; feature-wide scratch declarations.

The human applied the pinned repair batch and retained backup/logs at
`/private/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/sdd-review-boundary-repair-udhwnwf2`.
The agent independently read the six applied PR 381 files, verified their hashes,
reviewed the diff, and ran the tests against this actual worktree.

## Verification

- `tests/review-agent-isolation.tests.sh`: exit 0, including mandatory scratch
  history regression, PASS 20 / FAIL 0 across Bash and PowerShell.
  Log: `/tmp/sdd-pr381-applied-isolation-20260914.log`.
- `tests/review-context-boundary.tests.sh`: exit 0; 31 citation anchors and
  TEST-RCB-001 through TEST-RCB-010 (including 005b) passed in both runtimes.
  Log: `/tmp/sdd-pr381-applied-boundary-20260914.log`.
- `git diff --check`: exit 0.
- Full POSIX regression inventory launched; no success claimed before its
  terminal result. Log: `/tmp/sdd-pr381-applied-posix-20260914.log`.

## Scoped review

The original finding compares only the current task. The applied validators now
inspect every declared implementation root in the feature and prior evaluator
invocation history. Tests reject equal, parent and child roots while accepting
prefix-only sibling names, reject missing history without changing the ledger,
and verify snapshot preservation and changed-root refusal.

Reservation rechecks under the existing ledger lock, writes a new exclusive
snapshot before appending, and never rewrites historical reservations. Failure
to append can leave an orphan snapshot; recovery must preserve and investigate
it. Both validators contain the same Python implementation and now require
Python 3 for this declared-root check. No new dependency download is performed.

No Critical finding in this scoped code review. This is a local implementation
review, not an independent SDD gate, a GitHub approval, or an assertion of live
host isolation. The validators check declared locations, not OS enforcement.
Latest-commit CI, remaining review resolution and merge remain pending.

## Applied SHA-256

```text
c81991151998985c8edb4959b448263e3d360743e71819b63eb2e51ddca4ad05  plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
1b3f625426dafdd5d421b8f608b8fff8e6a61fc9653d23eabc5000817f5109ea  plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1
4694830f79840b7fbee535f916d1b741b40534d9f764819be735e9eb24b36d47  plugins/sdd-review-loop/references/review-context-boundary.md
b5ad348e78429b98bc639f9c49256dbc81dea7ef0a978fa08d933394f5cf19e6  tests/review-context-boundary.tests.sh
f2ae4dc164934e963ffa0025238a6535c3a68a3195686ca049d54359219f3ee5  tests/review-scratch-history.tests.py
5687aeb0fe49468da6607d4ff3124b508e5cb1f1a9c2b12d2d58eb2d77f60244  tests/review-agent-isolation.tests.sh
```
