# T-001 — design-sync-standing-consent assertion suite: acceptance-first mapping and RED baseline

Written per `Required Workflow: acceptance-first` (tasks.md T-001). This
document is the TEST-ID mapping table, the pre-edit RED baseline evidence
for both runtimes (REQ-009/AC-025's "documented baseline" leg), the
positive-control (non-vacuousness) evidence, the case-sensitivity sweep
evidence, and the banned-literal grep demonstration tasks.md T-001's
Done-When requires.

## Files created

- `tests/design-sync-standing-consent.tests.sh` (new, 595 lines) and
  `tests/design-sync-standing-consent.tests.ps1` (new, 615 lines) — one
  assertion block per `TEST-001`..`TEST-053`, `TEST-055`, `TEST-056` (55
  blocking rows) plus `TEST-054` (Deferred, presented after the PASS/FAIL
  summary line in both files, mirroring `acceptance-tests.md`'s own
  structural separation).
- `tests/run-all.sh` / `tests/run-all.ps1` — one line appended to each
  array, following the exact convention established at commit `55bc207c`
  (DS-29's own T-005: "placed last"). Diffs are single-line insertions; no
  pre-existing line in either file was touched (`git diff` confirmed).

## Acceptance-first mapping: TEST-001..TEST-056 → assertion → target

| Test ID | AC | Target | Assertion logic |
|---|---|---|---|
| TEST-001 | AC-001 | `AGENTS.md`, key row | row contains `standing`+`per-feature`+`off`, no hedge phrase (decidedness) |
| TEST-002 | AC-002 | `AGENTS.md` | `## Project Settings` heading exists **and** the key is named under it |
| TEST-003 | AC-003 branch 1 | same, section intro | "absent...section entirely" + `per-feature` |
| TEST-004 | AC-003 branch 2 | same | "absent key" + `per-feature` |
| TEST-005 | AC-004 | same, section present | key text present **and** no `Codex`/`Claude Code` (host-conditional negative) |
| TEST-006 | AC-005 | same | `off` + "forbid...every host" neighbourhood |
| TEST-007 | AC-006 | `design-sync-loop/SKILL.md`, step 3 outer text | key text present **and** no `Codex`/`Claude Code` |
| TEST-008 | AC-007 | same, standing bullet | "never produces...(b)" |
| TEST-009 | AC-008 | same | "Design-Source" named |
| TEST-010 | AC-009 | same, **structural** | `Ds-Upload-Consent-Setting: standing` immediately followed (≤30 chars, no `)`/`.`) by "this/that/the current destination" |
| TEST-011 | AC-030 | same | "different destination...fresh" + "own one-time write" |
| TEST-012 | AC-010 | same | literal `Egress-Consent: granted` |
| TEST-013 | AC-011 | same, off bullet | "always resolves to outcome (c)" |
| TEST-014 | AC-012 | same | "manual fallback"/"no upload attempt" combined (≤80 chars) |
| TEST-015 | AC-012 | same | "write(s) a record" (existence) |
| TEST-016 | AC-012 | same | literal `Ds-Upload-Consent-Setting: off` |
| TEST-017 | AC-013 | same | "persistently...as long as" + "not the transient...decline"/"does not lapse" |
| TEST-018 | AC-014 | `AGENTS.md` + `SKILL.md` | TEST-006's own AGENTS.md check **and** "every host" in the off bullet |
| TEST-019 | AC-015 | `SKILL.md` `## Loop`, flattened | exact 3(a) scope-clause substrings |
| TEST-020 | AC-015 | same | "Consent has not been obtained for this scope" (case-insensitive) + "go to 4" |
| TEST-021 | AC-015 | same | exact 3(c) persistence/decline-distinction substrings |
| TEST-022 | AC-015 | same | 3 exact step-4 disclosure substrings (beginning/middle/end of the block) |
| TEST-023 | AC-015 | same | "with no bypass" + "does not presume...interactive human" |
| TEST-024 | AC-015 | same | 3 exact step-6 push-failure substrings |
| TEST-025 | AC-015 | same | 4 exact step-7 review/regeneration substrings |
| TEST-026 | AC-016 | `SKILL.md`, whole file | literal `Egress-Consent-Party` |
| TEST-027 | AC-016 | same | literal `Egress-Consent-At` |
| TEST-028 | AC-016 | same | literal `Ds-Upload-Consent-Setting` |
| TEST-029 | AC-017 | same | "remain(s) conforming" + a DS-29-era/missing-three marker |
| TEST-030..037 | AC-018 | same | 5 existing field names + 3 existing domain values, each its own literal `grep -Fq` |
| TEST-038 | AC-019 | same, standing bullet | "never a fabricated" + "per-occurrence identity" |
| TEST-039 | AC-019 | same, off bullet | same two phrases, off-scoped |
| TEST-040 | AC-029 | same, standing bullet | all 3 new field names present |
| TEST-041 | AC-029 | same, "Whichever regime" paragraph | "per-feature grant" + all 3 new field names, incl. `Ds-Upload-Consent-Setting: per-feature` |
| TEST-042 | AC-029 | same, step-3 block | "mid-session" + "withdraw" + all 3 new field names |
| TEST-043 | AC-029 | same, off bullet | all 3 new field names, incl. `Ds-Upload-Consent-Setting: off` |
| TEST-044 | AC-020 | same, step-3 opening | "every time this step is resolved" + "never...cached...earlier/previous resolution" |
| TEST-045 | AC-021 | same, whole file | "never override...current(ly configured) setting" neighbourhood |
| TEST-046 | AC-022 | `claude-design-workflow.md`, whole file, **negative** | absence of the runtime-assembled banned key literal |
| TEST-047 | AC-022 | same | "upload-policy setting" + "Design-Source" + "AGENTS.md"/"Project Settings" |
| TEST-048 | AC-023 | same | existing no-upload statement present + no new upload-enabling phrase |
| TEST-049 | AC-023 | same, **minimal diff** | SHA-256 of the anchor-located prefix block and suffix block, both byte-identical to their pre-edit hashes |
| TEST-050 | AC-024 | same, **negative** | absence of the runtime-assembled banned "consent" substring, case-insensitive |
| TEST-051 | AC-025 | `tests/design-system-contract.tests.{sh,ps1}`, **baseline-relative** | every `PASS: DS-`/`PASS: TEST-` line in the T-001 baseline log is still a `PASS:` line in a fresh run; TEST-010/015/018/026/040 also checked by explicit prefix |
| TEST-052 | AC-026 | same, `TEST-021` specifically | DS-29's `TEST-021` is `PASS:` in both the baseline log and the fresh run |
| TEST-053 | AC-027 | `tests/run-all.{sh,ps1}` | both suite paths registered |
| TEST-055 | AC-031 branch 3 | `AGENTS.md` | "not exactly one of...lowercase literals" + "never...standing" + "never...off" |
| TEST-056 | AC-031 | same | "exact...case-sensitive" + literal (case-sensitive) `Standing` |
| TEST-054 (Deferred) | AC-028 | `.github/workflows/*.yml` | both suite filenames referenced by some workflow file — **designed RED** |

No gaps: every `TEST-001` through `TEST-053`, `TEST-055`, `TEST-056` has
exactly one row above and one assertion block in each suite file, in the
same order; `TEST-054` is the one Deferred row, present in both files after
the PASS/FAIL summary line.

## RED baseline: current tree (pre-T-002/T-003/T-004), both runtimes

### `.sh`

```
$ bash tests/design-sync-standing-consent.tests.sh
...
PASS: 22
FAIL: 33
$ echo $?
1
FAIL: TEST-054 ... -- DESIGNED RED: staged workflow patch not yet applied (REQ-010/AC-028)
```

Full transcript: `red-baseline-sh.log`.

- **22 of the 55 blocking `TEST-NNN` already PASS**, because the text they
  check is preserved unchanged by this feature (regression rows over
  DS-29's own text) or is trivially true against the unedited tree
  (baseline-relative and negative rows with nothing yet to violate them):
  `TEST-019`–`TEST-025` (DS-29's step 3(a)/(b)/(c)/4/5/6/7, all unmodified),
  `TEST-030`–`TEST-037` (DS-29's five field names and three domain values,
  unmodified), `TEST-046`, `TEST-048`, `TEST-049`, `TEST-050` (the fallback
  file has not been touched yet, so its negative/regression claims already
  hold), `TEST-051`, `TEST-052` (baseline == current run, since nothing has
  changed yet), and `TEST-053` (registration, satisfied by this task's own
  `run-all` edit).
- **33 of the 55 blocking `TEST-NNN` FAIL** — the expected RED baseline
  T-002 (`AGENTS.md`), T-003 (`design-sync-loop/SKILL.md`'s step 3 and
  record table), and T-004 (`claude-design-workflow.md`) must each turn
  GREEN for their own disjoint subset.
- **`TEST-054` is expected to stay FAIL/RED** even after T-002/T-003/T-004
  land — CI registration is a separately staged, human-applied workflow
  patch (REQ-010/AC-028), by design, mirroring DS-29's own `TEST-039`.
- **No pre-existing, unrelated failure was discovered** while establishing
  this baseline: DS-29's own suite re-run at this task's implementation time
  is byte-identical to the earlier-captured `ds29-baseline-sh.log`/
  `ds29-baseline-ps1.log` (`diff` empty, both runtimes) — the previously
  reported `DS-010 impl count updated` defect
  ([[project-design-sync-consent-t001-complete]]) is confirmed already
  resolved on this tree (`PASS: DS-010 impl count updated` present in both
  logs).

### `.ps1`

```
$ pwsh -NoProfile -File tests/design-sync-standing-consent.tests.ps1
...
PASS: 22
FAIL: 33
$ echo $?
1
FAIL: TEST-054 ... -- DESIGNED RED: staged workflow patch not yet applied (REQ-010/AC-028)
```

Full transcript: `red-baseline-ps1.log`.

**Runtime parity of the RED baseline is exact**: diffing the sorted
`PASS: TEST-NNN` / `FAIL: TEST-NNN` id set from both logs shows an
identical pattern — the same 22 Test IDs PASS and the same 33 FAIL, in both
runtimes, on the same tree (`diff` of the two sorted id lists is empty).

## Positive control: a well-formed fixture tree, both runtimes

To demonstrate the 33 currently-red rows are satisfiable by conforming
content — not accidentally over-strict — a hand-authored fixture tree was
built mirroring `design.md`'s target shape (API & Contract Plan,
`:74-203`) for all three edited files, run against a **copy** of both suite
files rooted at the fixture tree (never against the live repo). Fixture
sources: `fixtures/fixture-well-formed-AGENTS.md`,
`fixtures/fixture-well-formed-design-sync-loop-SKILL.md`,
`fixtures/fixture-well-formed-claude-design-workflow.md`.

Result (full transcripts: `fixtures/positive-control-sh.log`,
`fixtures/positive-control-ps1.log`):

| Runtime | PASS | FAIL | Gap |
|---|---|---|---|
| `.sh` | 54 / 55 | 1 (`TEST-051`) | fixture-environment artifact, not a suite defect (below) |
| `.ps1` | 53 / 55 | 2 (`TEST-051`, `TEST-052`) | same |

The sole gap (`TEST-051`/`TEST-052`) is **not** a suite defect: these two
rows invoke DS-29's own full `tests/design-system-contract.tests.{sh,ps1}`
against `$ROOT`, and the fixture tree deliberately contains only the three
files this feature edits — none of DS-29's own dependency files
(`contracts/`, `PLUGIN-CONTRACTS.md`, templates, `README.md`, etc.) exist
there, so DS-29's own `DS-001`..`DS-017` block fails en masse against the
fixture (confirmed: 71 of DS-29's own checks fail against the fixture,
purely from missing files unrelated to this feature) — and in `.ps1`,
whose `DS-NNN` block is `throw`-on-first-failure, that first `DS-001`
mismatch aborts the whole subprocess before it ever reaches the `TEST-NNN`
block, so `TEST-052`'s explicit re-check of DS-29's `TEST-021` also finds
no `PASS:` line to match. Both are artifacts of testing a 3-file fixture
against a suite that (by design, per AC-025/AC-026) depends on the *real*,
full DS-29 suite and its full dependency set. Against the real, unedited
repository tree (the RED baseline above), `TEST-051` and `TEST-052` both
PASS in both runtimes, and will continue to as long as T-002/T-003/T-004
do not regress DS-29's own suite — the actual claim these two rows exist to
verify.

**All 54 (`.sh`) / 53 (`.ps1`) other rows PASS against the fixture**,
including every row this document's "per-Test-ID structural correctness"
section below discusses — strong evidence the 33 currently-red rows are
satisfiable by conforming content, not accidentally over-strict wording.

## Non-vacuousness: structural and negative rows, demonstrated against a deliberately broken fixture first

Full transcript: `fixtures/vacuous-fixture-evidence.log`.

| Row | Vacuous fixture | Result | Well-formed fixture | Result |
|---|---|---|---|---|
| `TEST-010` (AC-009, structural) | destination-naming clause removed from the standing bullet's first-occurrence test (feature-only wording) | FAIL (correct) | destination-scoped wording restored | PASS (correct) |
| `TEST-046` (AC-022, negative) | the literal setting key injected into the fallback file's own bullet | FAIL (correct) | indirect reference restored | PASS (correct) |
| `TEST-050` (AC-024, negative) | same injection (the literal key also trips the general substring sweep) | FAIL (correct) | same restore | PASS (correct) |
| `TEST-055`/`TEST-056` (AC-031, two independently-failable claims) | the out-of-domain resolution rule and the exact-case-sensitivity statement both replaced with a vague "falls back to a sensible default" sentence | both FAIL (correct) | round-3 wording restored | both PASS (correct) |

An earlier draft of `TEST-010`'s regex accepted the vacuous fixture above
(a looser "destination mentioned somewhere nearby" pattern was satisfied by
the surrounding "(feature, destination)" scoping prose, not by the
first-occurrence test's own destination-naming clause) — caught by this
exact demonstration before the suite was finalized, and tightened to
require "this/that/the current destination" within 30 characters,
immediately after the `Ds-Upload-Consent-Setting: standing` literal.

## Case-sensitivity sweep (`AGENTS.md` "Author-time sweeps" item 1)

Full transcript: `case-sensitivity-sweep-evidence.log`.

Every `-match`/`-cmatch`/`.Contains()`/`.StartsWith()` site in the `.ps1`
suite was audited against its `.sh` twin's case-sensitivity: `grep -F` and
`grep -E` without `-i` map to `.Contains()`/`-cmatch`; `grep -Ei`/`grep -Fi`
map to plain `-match`. Mis-cased negative fixtures, one per representative
site class (operator-level layer, item 1(a)):

- `-cmatch` against `TEST-010`'s destination-scoping pattern:
  `"...Standing naming that Destination"` → `False` (correctly rejected);
  the correctly-cased original → `True`.
- `-cmatch 'Codex|Claude Code'` (`TEST-005`/`TEST-007`'s host-conditional
  negative check): lowercase `"codex...claude code"` → `False`; the
  correctly-cased literal → `True`.
- `.Contains($bannedKey)`: a string lacking the exact-case identifier →
  `False`; the same string with it present → `True`.
- `.StartsWith("PASS: TEST-010 ")` (the `TEST-051`/`TEST-052` baseline
  comparison): a lower-cased id → `False`; the correctly-cased prefix →
  `True`.

Cmdlet-level layer (item 1(b)): **not applicable** — no `Select-String`,
`-split`, `[regex]` static method, `switch -wildcard`/`-regex`, or
`Sort-Object` is used anywhere in this suite's `.ps1` source (confirmed:
these four strings appear only inside the file's own header comment
describing the constraint, never in executable code).

## Banned-literal sweep (`AGENTS.md` "Author-time sweeps" item 2; Edge Case 8)

Per tasks.md T-001 Done-When: neither the identifier `ds_upload_consent`
nor the contiguous substring `consent` appears inside `TEST-046`'s or
`TEST-050`'s own assertion logic or pass/fail labels (the two rows that
check `claude-design-workflow.md` for their absence) in either runtime's
source. Both are assembled at runtime from two non-contiguous parts
(`BANNED_KEY`/`$bannedKey`, `BANNED_WORD`/`$bannedWord`), exactly as DS-29's
own `TEST-033`–`TEST-036` already do, and the same variables are
interpolated into the `pass`/`fail` labels rather than the labels
containing the literal — following the precedent DS-29's own T-001 QG
fix-cycle addendum established after finding its labels had leaked a
banned phrase.

Demonstrated:

```
$ grep -noE 'ds_upload_consent' tests/design-sync-standing-consent.tests.sh tests/design-sync-standing-consent.tests.ps1
(no output, exit 1 -- zero matches, both files)
```

`grep -n TEST-046 / TEST-050` in both suite files (transcript above,
"Files created" section context) confirms the two check bodies and their
labels reference only `$BANNED_KEY`/`$bannedKey` and
`$BANNED_WORD`/`$bannedWord`, never a spelled-out literal. Every *other*
`consent`-containing string in either file (labels, comments, presence
checks against `AGENTS.md`/`SKILL.md`, the feature's own directory/file
names) is outside the scope of this constraint, which applies only to the
two negative checks against `claude-design-workflow.md` — matching
`acceptance-tests.md` Notes' own scoping of the rule.

## Per-Test-ID structural correctness (tasks.md T-001 Done-When)

- **`TEST-003`/`TEST-004`** are two independent checks (absent-section vs.
  present-section-missing-key), keyed to two distinct sub-phrases
  ("absent...section entirely" vs. "absent key") drawn from the same
  defining sentence — either can regress independently if that sentence is
  edited to drop one clause.
- **`TEST-055`/`TEST-056`** are two independent checks (the resolution rule
  vs. the exactness/case-sensitivity rule); demonstrated independently
  failable above (both fail together when the whole branch-3 sentence is
  removed, and the design does not further split "resolution" from
  "exactness" failing independently, since `acceptance-tests.md`'s own Test
  Details frames them as the two claims of one round-3 ruling, not four).
- **`TEST-010`/`TEST-014`** parse structural relationships (destination
  co-location with the field literal; a combined fallback+no-upload clause
  within an 80-character neighbourhood), not bare word presence — see the
  vacuous-fixture demonstration above for `TEST-010`.
- **`TEST-019`–`TEST-025`** check DS-29's seven spans as seven separate
  assertions, each keyed to distinct verbatim substrings drawn directly
  from the live, unedited `SKILL.md` text (not paraphrased), so a
  regression in one span cannot be masked by another span's substring still
  matching.
- **`TEST-026`/`TEST-027`/`TEST-028`** and **`TEST-030`–`TEST-037`** are
  each their own `grep -Fq`/`.Contains()` literal, not chained.
- **`TEST-040`–`TEST-043`** each scope to a distinct block of the step-3
  text (the standing bullet, the "Whichever regime" trailing paragraph, the
  step-3 block generally for the withdrawal occasion, the off bullet) and
  each requires all three new field names present in that scope
  independently.
- **`TEST-038`/`TEST-039`** check the same two-phrase non-fabrication claim
  in the standing bullet and the off bullet respectively — independently
  scoped, so either can regress alone.
- **`TEST-044`** is an executable-oracle check: it requires both "every
  time this step is resolved" *and* an explicit "not cached...earlier or
  previous resolution" clause, not merely the word "current".

## `.ps1` parity asymmetries (BL-008)

None. Every literal and every neighbourhood-regex this suite's `.sh` twin
asserts has a direct `.ps1` counterpart; no non-ASCII code point is
required anywhere (this feature's own vocabulary is entirely ASCII), so no
carve-out of the kind `tests/design-system-contract.tests.ps1:57`
documents was needed here.

## Concerns for the reviewer

1. **Predictive risk on content-based assertions**, exactly as DS-29's own
   T-001 report flagged: `TEST-001` through `TEST-050`, `TEST-055`, and
   `TEST-056` (excluding the structural/positional/regression/negative
   ones) match phrase fragments drawn as closely as possible from
   `design.md`'s literal target text (`:74-203`) and `requirements.md`'s AC
   language, since T-002/T-003/T-004 have not landed at this task's
   authoring time. The well-formed-fixture positive control (54/55 `.sh`,
   53/55 `.ps1`, both gaps explained above as a fixture-environment
   artifact, not a suite defect) is the strongest evidence available that
   the assertions are satisfiable by conforming content — but it is
   evidence against a hand-authored fixture, not against T-002/T-003/T-004's
   actual landed prose. A small wording nudge on either side may be needed
   once those land; that is normal TDD RED→GREEN iteration.
2. **`TEST-041`/`TEST-042`'s scoping is prose-anchored, not bold-marker
   scoped**, unlike `TEST-040`/`TEST-043` (which scope to the `**standing**`
   / `**off**` bulleted blocks). `design.md`'s own shown draft text for the
   ordinary per-feature grant and the mid-session withdrawal occasions is
   itself abbreviated (the withdrawal paragraph says only "all three new
   fields," without re-naming them) — T-002's implementation will need to
   spell the three field names out explicitly for these two occasions to
   satisfy `TEST-041`/`TEST-042` as written, which is the stricter,
   "checkable, not merely asserted in prose" reading `acceptance-tests.md`'s
   own Test Details calls for (see the note under TEST-040/TEST-041/
   TEST-042/TEST-043 there), not a suite defect.
3. **`TEST-029`'s extensibility-paragraph check is loosely worded**
   (`remains? conforming` near a DS-29-era/missing-three marker), since
   `design.md` does not give a literal target sentence for this paragraph's
   edit, only a description of the intended change. Some wording latitude
   is expected here specifically.
