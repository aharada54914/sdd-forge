# PR #404: activate recorded F4 coverage and audit emitted skips

Scope: Issue #195, existing T-004 / T-010 structural compatibility coverage.
Base: 8d7ee4d1b7aa9a3850577db63f3128bf20756483.
Integration reference: origin/main 4366438f3b243210a4ece5a17f873ca2d920600a.

## Root cause and reproduced failure

Both structural suites validated skip formatting but never ran the allowlist
auditor. F4 / AC-007 remained unconditionally skipped after A4 was merged by
PR #301 (02166dbabb0979081337b1d408b26019be3668d6).

The Bash suite returned 0 while auditing its same captured output returned 1:
`ERROR: AC-007 emitted after activation condition became true`.
Connecting the auditor reproduced a real suite failure in both runtimes:
Bash 44 passed / 1 failed; PowerShell 49 passed / 1 failed.
The active-AC-007 output assertion also failed before activation was implemented.

## Change

- Both suites collect and audit their emitted dependency-skip lines. An audit
  failure contributes to the suite failure count; invalid activation evidence
  is a failure, not permission to skip.
- Once the existing manifest condition activates AC-007, execute the existing
  full-track artifact validator against F4. This checks exact paths/count,
  headings/frontmatter, status fields, identifier grammar, and absence of
  reserved references in both artifact contents and paths.
- Preserve the recorded corpus bytes and historical review records. Remaining
  F3/F5/F6 skips are audited, not declared successful acceptance coverage.
- Register an isolated real-suite mutation regression in the POSIX aggregate.
  A local temporary clone contains corpus mutations; the source worktree is
  never mutated by that regression. PowerShell cases execute when available.

## Verification

- `bash tests/structural-compatibility.tests.sh`: 61 passed, 0 failed;
  three remaining allowlisted lines audited.
- `pwsh -NoProfile -File tests/structural-compatibility.tests.ps1`:
  66 passed, 0 failed; three remaining allowlisted lines audited.
- `bash tests/structural-activation.tests.sh`: six actual-suite cases passed:
  clean, forbidden content, forbidden path, separately in Bash and PowerShell.
  Negative cases require the specific forbidden-reference failure, not any exit.
- Logs: `/tmp/pr404-structural-audit-before-20260911.log`,
  `/tmp/pr404-structural-audit-after-{bash,pwsh}-20260911.log`,
  `/tmp/pr404-structural-activated-{bash,pwsh}-20260911.log`,
  `/tmp/pr404-structural-activation-regression-20260911.log`.

Self-review: no production behavior or existing assertion removed; no threshold
relaxed. Newly reachable F4 branch exercised in both runtimes. This is not an
independent reviewer approval or a quality-gate verdict.

T-004 explicitly requires an offline recorded-corpus suite (tasks.md, Done When).
These results are not a new live-model capture or proof of complete A7 delivery.
Other loop suites still contain ad hoc dependency skips and require follow-up.
Latest-head CI, required independent approval, main integration and Issue closure
remain pending. No task/review status was changed.
