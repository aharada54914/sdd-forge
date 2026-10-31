# QG cycle-2 fix verification -- mutation application log

Generated 2026-08-08, `sdd-forge-wt-phase4` worktree, branch `feature/wave9-design-sync`.

Every mutant tree was built from `git archive HEAD | tar -x` (the last
**committed** state, i.e. the attempt-1 suite as shipped by T-001, plus
T-002/T-003/T-004's already-landed, correct `AGENTS.md`/
`design-sync-loop/SKILL.md`/`claude-design-workflow.md`), with this fix
pass's working-tree (uncommitted) `tests/design-sync-standing-consent.tests.{sh,ps1}`
overlaid on top, in a private namespace (`/tmp/qg-c2-standing-<pid>`,
distinct from the shared session scratchpad) to avoid collision with any
concurrent agent session's own `mutate.py`/fixture tree in this shared
worktree. Each mutation below was applied via a small Python helper
(`mutate.py`) that requires the search string to occur **exactly once**
in the target file (aborting otherwise) and prints the file's SHA-256
before and after the substitution, so the hash pair itself is the
apply-verification evidence — a silently-unapplied "mutation" (e.g. a
typo'd search string) would show `PRE_HASH == POST_HASH` and is
distinguishable from a real one below by that equality; every row here
shows a changed hash.

| Mutant dir | Target file | Item | PRE_HASH (sha256) | POST_HASH (sha256) | Changed |
|---|---|---|---|---|---|
| `m1a-4th-prepend` | `AGENTS.md` | 1 (TEST-001), 4th value `auto` prepended to Values cell | `05859bd1...9a6b4f3` | `3629ad9e...e71b` | yes |
| `m1b-4th-append` | `AGENTS.md` | 1 (TEST-001), 4th value `ask-always` appended to Values cell | `05859bd1...9a6b4f3` | `d48db515...9b` | yes |
| `m1c-2value` | `AGENTS.md` | 1 (TEST-001), Values cell reduced to 2 alternatives (`standing`\|`off`) | `05859bd1...9a6b4f3` | `1929ce8f...8b8` | yes |
| `m1d-freetext` | `AGENTS.md` | 1 (TEST-001), Values cell replaced with free prose | `05859bd1...9a6b4f3` | `2a56cda9...16a` | yes |
| `m2a-default-standing` | `AGENTS.md` | 2 (TEST-003/004), Default cell `per-feature` -> `standing` | `05859bd1...9a6b4f3` | `b1a272ce...5a5` | yes |
| `m2b-default-off` | `AGENTS.md` | 2 (TEST-003/004), Default cell `per-feature` -> `off` | `05859bd1...9a6b4f3` | `7a7b7577...71f` | yes |
| `m2c-default-empty` | `AGENTS.md` | 2 (TEST-003/004), Default cell `per-feature` -> empty | `05859bd1...9a6b4f3` | `82801b7b...78c` | yes |
| `m2d-prose-default-standing` | `AGENTS.md` | 2 (TEST-003/004), shared absence sentence changed from "uses the stated default" to "uses a default of `standing`" (Default cell left untouched at `per-feature`, a doc self-contradiction) | `05859bd1...9a6b4f3` | `644ffdc0...cc8` | yes |
| `m3a-off-delete-party-at` | `design-sync-loop/SKILL.md` | 3 (TEST-043), `Egress-Consent-Party`/`Egress-Consent-At` lines deleted from the **off** bullet block | `b41980f5...d13b47` | `acfd2645...4c72` | yes |
| `m3b-withdrawal-claim-reduce` | `design-sync-loop/SKILL.md` | 3 (TEST-042), withdrawal paragraph's "writes all three new fields" weakened to "writes two of the three new fields" | `b41980f5...d13b47` | `e91ee39a...0d6` | yes |
| `m5a-uploaded-automatic-bullet` | `claude-design-workflow.md` | 5 (TEST-048), new bullet "Mockups are uploaded to the design service automatically on attach." | `08990f38...9ce6` | `5cf7f48a...a15` | yes |
| `m5b-upload-automatic-retain-bullet` | `claude-design-workflow.md` | 5 (TEST-048), new bullet "This workflow may upload the mockup automatically and retain it once that value is recorded." | `08990f38...9ce6` | `842931f0...ce8` | yes |
| `m5c-uploaded-automatic-nobullet` | `claude-design-workflow.md` | 5 (TEST-048), same sentence as m5a, as a plain (non-bullet) paragraph | `08990f38...9ce6` | `7274ec7f...435` | yes |
| `m6-anchor-zone-insert` | `claude-design-workflow.md` | 6 (TEST-049), unrelated bullet inserted strictly between the `a normal specification edit.` and `When no visual input is supplied, record:` anchors (line 30, confirmed between line 17 and line 40) | `08990f38...9ce6` | `900a6c37...038` | yes |

Full pass/fail results for both the fixed suite (both runtimes) and,
where captured, the pre-fix (`git show HEAD`) suite against the same
mutant tree are in `kill-mutant-matrix.log` in this same directory. Every
kill target listed in the fix request is confirmed killed by the fixed
suite in both `.sh` and `.ps1`, and confirmed **not** killed (false
PASS) by the original, pre-fix `.sh` suite for every mutant where that
before/after comparison was run (items 1, 2, 3, 5, 6) -- direct evidence
that each QG cycle-1 Major finding was real and that the fix closes it.

## Item 4 (TEST-030..TEST-034 ID rebinding)

No mutation-based kill demonstration applies to this item -- it is a
pure ID<->target relabeling/reordering bug fix (each of the five
underlying `grep -Fq`/`.Contains()` checks was already correct; only
which Test ID reported which check was wrong), not a detection-strength
gap. Verified instead by direct inspection: both `.sh` and `.ps1`, after
the fix, report `TEST-030 Egress-Consent field name present`,
`TEST-031 Egress-Consent-Scope field name present`,
`TEST-032 Egress-Consent-Subject field name present`,
`TEST-033 Egress-Destination field name present`,
`TEST-034 Egress-Consent-Expiry field name present` -- matching
`acceptance-tests.md`'s Test Matrix (`specs/design-sync-standing-consent/acceptance-tests.md:44-48`)
exactly, where before the fix the same five checks were bound to IDs one
position out of step (`TEST-030` checked `Egress-Consent-Scope`, ...,
`TEST-034` checked bare `Egress-Consent`).

## Non-regression

- Full 55/0 suite run (both runtimes) against the live tree after all
  seven fixes: `post-fix-live-tree-sh.log` / `post-fix-live-tree-ps1.log`
  in this same directory -- byte-identical to each other (`diff` empty,
  confirmed separately), matching the pre-fix live-tree baseline's own
  55/0 count and exact runtime parity.
- Full 55/0 suite run against the isolated `git archive HEAD` + fixed-
  suite-overlay base copy (no mutation), both runtimes -- tail of
  `kill-mutant-matrix.log`'s final section -- confirms the private-
  namespace harness itself is faithful to the live tree before any
  mutation is layered on top.
- `tests/design-sync-scan.tests.{sh,ps1}` (sibling feature, issue #139)
  and `tests/design-system-contract.tests.{sh,ps1}` (DS-29) re-run
  unmodified against the live tree after this fix pass -- neither
  suite's own file was touched by this fix pass, and this suite's
  `TEST-051`/`TEST-052` (which invoke DS-29's suite at runtime) both
  still PASS in the live-tree 55/0 runs above, confirming no regression
  crossed feature boundaries.
