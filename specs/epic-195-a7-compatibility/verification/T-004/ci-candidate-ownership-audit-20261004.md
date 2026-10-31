# T-004 CI candidate ownership audit

This is an implementation-side disposition, not an independent gate verdict.
No candidate or live workflow bytes were changed.

## Current versus historical

- `git log -- <candidate> <manifest>` returns only `a4829db1`, whose stat
  adds the 865-line candidate and one-line manifest under T-004. No later
  ownership remediation commit exists on this path's current history.
- Current candidate lines 613–622 still carry the T-004-labelled structural
  suite block. Its manifest still binds
  `fa2acab9e8ecb40cd612ba6aab7f5ca2f9a891fd5e4f0e0081dcb291e9db192e`.
- Current tasks.md T-011 remains Planned (line 1517), claims sole workflow
  editing (1526–1527), and explicitly lists this same human-copy candidate and
  manifest (1570–1574). No T-011 implementation report or verification
  directory exists. Current traceability.md ownership row assigns CI to T-011.
- Current live workflow is not byte-identical to that historical 865-line
  candidate and already mentions the structural PS suite at line 243. A
  checked manifest is not proof that overwriting today's workflow is safe.
- There is no working-tree diff in either workflow or the candidate manifest.
  Thus this activation repair introduces no new CI ownership violation; the
  existing candidate ownership finding remains unresolved, not erased by age.

## Disposition

T-004 makes no claim that candidate application is its deliverable. Do not
apply the old whole-file candidate. Preserve it as historical evidence pending
T-011's authorized cumulative registration work, which must regenerate/rebase
its proposed workflow against the then-current live file and validate all
registrations and baseline-write restrictions. Neither a report-only ownership
transfer nor this local audit constitutes acceptance or remediation of the
historical scope finding. The independent gate must classify it explicitly.

The authorized T-004 wording-only amendment is separately prepared in
`donewhen-amendment-candidate-20261004.patch`; the coordinator owns task-plan
edits and must execute the normal guarded apply, then provenance re-review.
No protection denial was encountered during this read-only audit. If normal
application is denied, retain this candidate for the authorized human batch;
do not substitute a write tool or alter gate/protection configuration.
