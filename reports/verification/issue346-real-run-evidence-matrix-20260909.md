# Issue #346: historical real-run evidence matrix

Primary evidence inventory, not a fresh adversarial review or quality gate.
No historical report, verdict, or finding disposition was changed.

## Source identities and search scope

- PR381 tree inspected: `3971c93a5705dc15f86ba56cc62118613e4b19db`.
- Run-003 report and evaluation: that tree's
  `reports/adversarial-review/feat-adversarial-review-enhancements/`.
  A scoped `git ls-tree` lists only report.md and evaluation.json there.
- Run-001 provenance: current `skills/adversarial-review/README.md:31-37`
  and introducing commit `32d59b52971b59f4c6c34fdc8d209fba08863908`.
- Run-002 provenance: GitHub issue #136 body, retrieved during this turn,
  describes the two-reviewer mutual critique and names FINAL-refactor-plan.md
  as a scratchpad, but supplies no exact archive path or target SHA.
- Issue #346 acceptance conditions were read from GitHub, not inferred from
  report labels. It remains open.

| Required evidence | Run-001: torque, 2026-07-07 | Run-002: epic-136 plan | Run-003: enhancements |
|---|---|---|---|
| Original report | README names docs/review-tickets/2026-07-07-dual-review-refactoring-plan.md in torque-system-manager and PR #7; original not obtained | Issue #136 names FINAL-refactor-plan.md; original not obtained | report.md obtained from pinned PR381 tree |
| Immutable reviewed identity | Not established from original | Not established from original | Report declares head 9e39c396f4ca8f9abe3c9aabb090868ada17b53f and base e00478321327b48e4e4ad21a14391d69e0f1baa9; hash recomputation not performed in this inventory |
| Finding dispositions | Secondary narrative only; no comparable per-finding original | Issue decomposition is not per-review disposition evidence | Five named dispositions in evaluation.json; summary says five adopted, but A+B-1 is scope_deferred |
| Severity changes / rejected false positives | README says most severities recalibrated; exact count unverified | Not established | Rejected=0 declared; severity-change count not explicitly supplied |
| Scope-stopped proposals | Not established | Not established | out_of_scope=0 and unclear=0 declared; deferment is not automatically an out-of-scope stop |
| Verified non-findings | Not obtained | Not obtained | Eight bullets recorded; this inventory does not independently reverify all eight |
| Fresh-context fix verification | README describes fresh verification; original evidence missing | Not established | phase_r.ran=false, explicitly not performed |
| Launch count / elapsed time | Not established | Not established | Two launches declared; no elapsed-time measurement supplied |
| Valid for current PR381 head | No | No | Explicitly STALE; historical reviewed head differs from current PR381 |

## Reconciliation needed, without retroactive editing

1. The report's adoption summary and metadata describe five adopted findings,
   while evaluation.json gives A+B-1 disposition scope_deferred. Preserve both
   originals and record a sourced reconciliation in a new addendum; do not
   silently equate deferred with adopted or rejected.
2. The report leaves A-2 unchecked, while evaluation.json says the section
   citation was added. The pinned ADR0026 correspondence table does contain
   the section label. This confirms the repository text only, not the accuracy
   of that label against the external paper.
3. Report prose says Phase R will run after merging. That statement does not
   authorize merging while current mandatory CI or formal gates fail. A fresh
   verification can target a fixed immutable candidate before integration.
4. Do not use the reported non-findings or schema success to fill unmeasured
   timing, severity-change counts, or fresh-review results.

## Remaining collection sequence

1. Locate the original torque repository/report and epic-136 scratchpad. An
   authenticated listing of up to 100 repositories under aharada54914 yielded
   no name containing torque; this bounded search is not proof of deletion or
   absence under another owner/location.
2. Bind obtained originals to immutable commits or content hashes, extract
   actual comparable fields, and explicitly label any permanently unavailable
   measurements with reasons. Do not substitute reconstructed reviews for
   historical runs.
3. Complete the in-scope current fixes and required gates, then use a new
   independent Phase R execution on the fixed target with its own raw evidence.
4. Present the evidence matrix to the human for the required plugin / standalone
   / retirement judgment. The earlier approved risk-adaptive direction in issue
   #136 is not silently treated as this later three-run-informed decision.

No issue was closed. The three-run acceptance condition is not yet proven.

## Follow-up: bounded original-source retrieval

Completed the following additional read-only searches in the next continuation:

- Authenticated `gh api user/repos --paginate`, selecting repository names
  containing torque case-insensitively: no matching repository returned. This
  goes beyond the earlier first-100 owner listing, but is still bounded by the
  authenticated account's API visibility.
- GitHub code search for the exact first report filename: no indexed result.
- GitHub code search for FINAL-refactor-plan.md in aharada54914/sdd-forge: no
  indexed result. Search index absence is not proof of repository absence.
- Filename discovery under /Users/jrmag/Projects and /Users/jrmag/.local/share
  for both original filenames: no matches. No contents from unrelated projects
  were read. The Projects active/archive inventory also has no torque-named
  top-level checkout.
- The introducing commit mentions docs/handoff-adversarial-review-skill.md,
  but that file is absent in the current tree and an all-local-ref path history
  search returned no commits. A mention in a commit message is not the missing
  handoff document itself.

The next source-dependent action is now specific: obtain the original torque
report (or its repository owner/URL) and the epic-136 FINAL-refactor-plan.md
scratchpad from the human. Do not keep repeating these completed searches or
turn secondary descriptions into primary historical execution evidence. This
blocks completion of this historical comparison, not all other repository work.
