# Current integration lanes — 2026-09-06

Diagnostic handoff only; no merge, issue closure or formal gate verdict.

The user corrected the scope clarification: Issue #288/#289 investigation
remains required alongside PR #371/#381/#245. The issue investigation is
delegated; commit non-ancestry alone must not be reported as proof that an
equivalent fix is absent from main.

## Exact PR evidence

- PR371: `9e39c396f4ca8f9abe3c9aabb090868ada17b53f`.
- PR381: `3971c93a5705dc15f86ba56cc62118613e4b19db`; live checks remain
  failed (GitHub read 13b941), not pending retry.
- PR245: `54b1ff247081971e0560cf20d45f4369e01b5c0d`; GitHub identifies
  this as **epic-193-a5-capability-resolver**, not epic-191 (7f085d).

Primary endpoint schema diff (487ec5) confirms PR381 tightens
reviewer_launch_count from minimum 0 to 2, requires the complete Phase R
outcome set when ran=true, prohibits outcome counters when ran=false, and
requires full 40-character report commit hashes. These are concrete reasons
not to integrate the older PR371 artifacts wholesale. This comparison does
not establish that all PR371 functionality is subsumed or that PR381 passes.

Primary repeated merge-tree against exact main
`4366438f3b243210a4ece5a17f873ca2d920600a` and PR245 (427079): exit 1,
23 conflicted paths, tree `715c587fa161e4583377f3e5717971bb97301517`.
The tree is unresolved; no checkout or merge application occurred. The prior
primary conflict-selection and ledger reports remain the detailed guidance;
the delegated report's older base and epic-191 attribution are not accepted
as current evidence. A fresh uninstrumented isolation-suite execution on the
PR245 worktree has been assigned; its historical exit 141 remains unresolved.

## PR381 formal-review boundary

Read the current RT-20260821-018 approval and attempt-3 round-1 precheck.
The specification precheck already succeeded; do not overwrite that round.
The installed spec-review-loop requires authentic host-issued run/session
identities reserved before reviewer launch. A current tool discovery found
no dedicated pre-launch reviewer-identity reservation interface. The
collaboration interface starts an agent and returns its identity afterward.
No synthetic reservation, reused reviewer, new launch or verdict was made.
This remains a host-integration prerequisite, not a new request to approve
the already-approved criterion amendment.

T006's candidate repair and regression additions are already implemented.
The current README handoff still limits human application to the mirror
workflow and mirror manifest, with exact hashes and backups. No application
result has been received; the remaining designed-red is not waived.

## Specific live CI wait

PR400 run `34033392134`, exact head
`8fa3eb8561d6f59b692ec574900f87e181145928`, is still live. Primary reads
3a861c and d4c8a1 show 23 successful jobs, zero failed jobs, and only Windows
version-gates running, currently at the apply-human-copy publisher suite.
The aggregate required-checks result is not yet established. No rerun was
requested. Even a green CI result will not satisfy the outstanding T002
formal cross-model prerequisite by itself.

## Additional primary checks

Primary confirmed PR381's Python validator actually implements
`in_traceability_table` and dynamically finds the `Layer Spec` column
(1a5b77). Reuse this existing #289 implementation rather than writing a
second fix.

The delegated #288 conclusion is too broad. Main already derives historical
investigation pins from contracts in spec-review-precheck.sh and the shared
review-precheck-common.sh (b226aa). Commit 18a58810 additionally requires
existing investigation evidence in new spec/impl reservations (1829aa).
These two obligations must be checked separately: absence of the old commit
or its exact test block does not establish absence of the historical audit
repair. Do not replace main's shared prechecks with older branch files.

The PR245 tester returned exit 0 with an empty log. The suite's source ends
with a mandatory success message (3c623f); that empty log is not accepted as
successful execution evidence. Primary started the exact original suite
without xtrace in the explicit PR245 worktree (f83b3f), session 9936. At the
last poll (32c363) it was still running without output; no exit was returned.
Continue polling that handle; do not start another test on an observation
timeout.

That same session subsequently terminated: 112698 reports exit 141 and no
output. The primary reproduction supersedes the pending execution state,
not the unresolved root-cause assessment. PR400 remains live (01d7f3), still
23 successful jobs and Windows version-gates running with no failed jobs.

## Latest diagnostic and scope correction

The user explicitly restored Issue #288 and Issue #289 investigation; these
are issue numbers, not substitute PR numbers. A bounded read-only follow-up
now checks the #288 reservation validator and its regression separately from
the historical precheck fix already on main.

PR245 diagnostic execution used the unchanged original suite and a separate
FD 9 ERR-trap log, without stderr xtrace. It terminated with exit 141
(718a60). `/tmp/pr245-error-fd.LMg8Mk/errors.log` identifies line 813:
`pipeline=(141 0) command=tar -x -C "$rollback_baseline"` (d6cc04).
The failing pipeline is `git archive | tar`, not the earlier grep hypothesis.
This instrumented diagnostic is not acceptance evidence. PR381 already has
the separately approved temporary-archive/export-success/extraction repair
at lines 713–718; its reuse on PR245 needs reconciliation with the approved
task scope, not a wholesale copy of an older suite.

Endpoint test diff (13aab0) shows PR245 adds ANNOT-01–08 cases but removes
main's legacy grammar checks. Integration must retain both main's legacy
cases and PR245's annotation cases, alongside the safe archive handling.

PR381's existing #289 suite produced 22 PASS and 0 FAIL in
`/tmp/pr381-bootstrap-cross-layer-index-fresh.log` (primary output 7c4848).
Primary hash verification (99b551):

- Script SHA-256: `cec433f86e00071a605e24a8402d336d99e8c34ebf6e0870e885aa95aa20409f`.
- Log SHA-256: `99da4dc4be39a341aceef1e304e7b97b0e4d47d8932f798e903b36bed1f135b6`.

This verifies the branch suite, not main integration or a formal gate pass.
PR400's latest read (102c73) still shows 23 successful jobs and one running
Windows version-gates job, now at check-component-coverage; no failed job.

## Issue 288 primary correction and integration risk

Live Issue 288 (4c6df2) distinguishes historical contract audit from new
reservation completeness. The latest delegated claim that only tests are
missing conflated these obligations and is rejected. Its statement that the
late-file reset should fail also reverses the regression: reset must succeed
for a terminal contract predating investigation.md; only the later one-sided
binding must fail (actual commit test diff 3abcfa).

Primary read main's full Bash reservation validator (d1e04a), and PowerShell
validator plus its middle-section follow-up (260397, cda929), at main
4366438f3b243210a4ece5a17f873ca2d920600a. These authorize and hash-check listed
inputs but lack the existing-investigation omission check added in
18a58810 to `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh`
and `.ps1` (d5a850). The similarly named spec precheck is a separate file.

An integration interaction also needs coverage: old commit 18a58810 only
accepted not-yet-reserved identities (b6a3af). Current main supports both new
admission and verification of persisted identities (d1e04a). Transplanting
the old unconditional omission block would also affect persisted historical
manifests after a new investigation file appears. This is a static integration
risk, not an executed failure or approved behavior change. Preserve historical
verification and test new admission separately; do not blindly transplant old
validator files or declare Issue 288 complete.

PR400 is now terminal green: all 24 workload jobs plus required-checks passed
(6f2903, 51bc2a, f4d5d8). Exact-head formal-gate prerequisites remain open;
the run-specific heartbeat was paused, not the overall integration goal.

## Issue 288 approval-source audit and integration acceptance matrix

Primary inspection of `origin/feature/issue-137-sdd-context` found WFI-027
still explicitly `Status: Draft`, `Audit-Status: Not-Started`, and result
pending (55f8de). Its proposed change correctly separates historical audit
from new reservation, but is not an Approved task or resolved review ticket.
Exact identifier searches for `WFI-027`, `#288`, or `issues/288` in that
branch's task plans/review tickets (35d48e) and PR381's task plans/review
tickets (9235db) returned no matches. This is a scoped absence finding, not
proof that no differently named authority exists anywhere.

The delegated claim that WFI-025 supplies approval is rejected: primary read
of its cited span (ce8ce5) proves it concerns normalized task-plan digests,
and explicitly says it does not touch the identity ledger or reservation
protocol. It cannot authorize the investigation omission change.

Current implementation identifies new versus persisted contexts by the
ledger match, not the `--reserve` flag (Bash lines 359-425, 992448;
PowerShell lines 319-380, a9cb36). The following integration acceptance
matrix is a proposal, not executed evidence or a relaxation of other checks:

| Context | Investigation input | Required result, all other inputs valid |
|---|---|---|
| New spec and impl identity, dry-run and reserve | Existing regular file omitted | Reject in Bash and PowerShell; do not append ledger |
| New spec and impl identity, dry-run and reserve | Included at correct hash | Accept; append only when reserve requested |
| New spec and impl identity | Included at wrong hash | Reject using existing hash enforcement |
| New spec and impl identity | File absent, entry omitted | Preserve existing acceptance |
| Persisted identity verification | File created later, historical entry absent | Preserve valid historical verification without rewriting evidence |
| Persisted identity with reserve requested | Any | Preserve duplicate-reservation rejection |
| Task-stage identity | Existing investigation omitted | Do not introduce an unauthorized required input |
| Historical contract | Only one reviewer binds investigation | Preserve rejection |

Path confinement, symlink rejection for supplied inputs, identity uniqueness,
ledger-chain validation, and existing parity suites remain mandatory. Each
enumerated stage/runtime/mode branch needs its own assertion when the scoped
task is approved; this table does not claim tests have run.

Current remote inventory (7e488b) has six open PRs: 245, 371, 381, 390, 394,
400. PR400 remains green at 8fa3eb8 (9ed636). PR390's Windows test and
required-checks remain failed (70d22f). T006 mirror manifest remains old
233d4581, versus candidate cb7eb680 (a73442); no human application inferred.
