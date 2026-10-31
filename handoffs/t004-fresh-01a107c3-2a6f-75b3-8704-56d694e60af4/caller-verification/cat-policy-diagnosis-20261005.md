# A8 caller proxy-cat refusal: bounded diagnosis

Status: diagnostic RED confirmed; no production repair, no repair GREEN, no native restart.

## Observed boundary

The exact caller refusal is retained in `role-read-refusal-20261005.md`.
The command was `rtk proxy cat .codex/agents/sdd-investigator.toml .codex/agents/sdd-evaluator.toml`.
PreToolUse rejected it before shell execution. Those role contents have not
been read by an alternative tool or executor. This is a separate event from
the older worker rg refusal, whose exact argv remains unavailable; this finding
does not establish the cause of that older refusal.

## Reproduction without executing the refused operation

`cat-policy-diagnostic.py` feeds JSON command strings as inert data to the
existing Python guard. It never invokes the payload command or opens a role
file. Existing saved D01 input comes from
`/private/tmp/sdd-guard-main.3JEj4I/repo/reports/verification/read-policy-regression-inputs-20261004.json`.
Full command, exit code, per-case stdout/stderr and source hashes are retained
in `cat-policy-diagnostic.log`. No source or installed bytes changed.

| Payload, tested against both guards | Expected policy exit | Actual exit |
|---|---:|---:|
| Exact two-role proxy cat | 0 | 2 |
| Saved direct cat | 0 | 0 |
| Saved proxy cat | 0 | 2 |
| Proxy cat followed by redirect | 2 | 2 |
| Proxy cat followed by second write command | 2 | 2 |

Ten decisions: four policy mismatches (RED), six matching controls. Diagnostic
process exit 1 means the expected mismatches, not a hook rejection. No fixed
candidate was introduced, so there is no repair GREEN. JavaScript/PowerShell
or installed activation were not exercised by this bounded diagnostic.

Installed Python SHA-256:
`248b78aa0419e6693d3d1e29d20390af1a1de422a411c4fdd7e30b5066126227`.
Current #536 working-tree Python SHA-256:
`7392cccf47ece13bd6af919bcd319926f92911b11a41a6e7dd243eb41f68c77a`.

## Classification and source evidence

Installed source is
`/Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-quality-loop/1.18.0/scripts/sdd-hook-guard.py`.
Its direct-reader regex (75–77) starts with the reader verb. The separate
proxy helper (1719–1754) recognizes rg only. The role-write decision
(1757–1766), reached from 2029–2042, denies a role-path command unless one
of those exceptions matches. Therefore this exact proxy-cat invocation is
misclassified as a role write. Both installed and current #536 guards reproduce
the same result: this is not demonstrated to be a completed repair awaiting
installation. Installed hash difference from owner/source alone is not an
installation defect.

The #536 Unicode candidate changes the rg pattern grammar only
(`reports/verification/proxy-rg-unicode-20261004.candidate.patch`); its historical
114-case GREEN is not proxy-cat or expanded-read-policy proof. The governing
read-policy design explicitly names this gap and disallows simply stacking
another prefix exception: `reports/verification/read-policy-implementation-boundary-20261004.md:12–32,41,53–61,82–89`
under `/private/tmp/sdd-guard-main.3JEj4I/repo`.

## Smallest normal repair route, not implemented here

1. Keep the exact two-literal-role proxy-cat case and saved direct/proxy controls
   as the initial regression. Reader recognition must consume the whole invocation;
   redirects, substitutions, second commands and unsupported options remain denied.
   Do not blanket-allow Node, unwrap arbitrary executables or build a generic shell parser.
2. Scope the implementation through the existing read-policy contract and its
   three-runtime parity requirements. A one-off proxy-cat exception would conflict
   with the currently proposed replacement-classifier boundary, so a narrower
   staged delivery must be explicitly reflected in the formally reviewed task;
   this A8 diagnosis does not amend that contract or create such a task.
3. Resolve formal launch prerequisites before implementation. Current live files
   still show `specs/guard-role-read-regression/requirements.md:3` Spec-Review-Status
   Pending and `design.md:3` Impl-Review-Status Pending. A filename inventory found
   no tasks.md in that spec; the boundary note at 59 likewise states no Approved task.
4. Historical launch blocker: `read-policy-review-launch-recheck-20261004.md:7–11,19–26`
   records TEST-RCB-011 rejecting the required boundary input and a prepared,
   hash-pinned three-file human application. Reverify current bytes/state before
   consuming this dated repair; it is not asserted still unapplied on every host.
5. Historical interrupted-round blocker:
   `guard-role-read-prelaunch-recovery-gap-20261004.md:53–104` describes attempt-1/
   round-1 with no verdict/contract and normal advance/reset rejection. Its proposed
   recover-prelaunch transition is not an implemented authorization. Resolve the
   applicable recovery contract and protected-apply gate; do not invent FAIL/BLOCKED
   findings, mutate old receipts, or bypass the round transition.
6. Once launch boundaries are valid: fresh specification review, implementation-policy
   review, task review and human-approved implementation task; then scoped guard
   implementation, shared positive/negative regressions and normal protected application.
   Installed read/deny evidence must identify the installed hash and use an authorized
   caller, never demand a write canary from a read-only evaluator. Only thereafter
   resume A8 fresh allocation/manifest/tool-contract checking and seek the permitted
   first turn. Existing logger/controller 14 PASS remains transport evidence only.

Only this diagnostic script, log and note were added in the A8 non-frozen handoff.
No other worktree writes, protected guard/config edits, native allocation, formal
turn, reservation, approval/status changes or verdict reuse occurred.
