# T-001 — design-sync-consent assertion suite: acceptance-first mapping and RED baseline

Written before the suite content below was finalized against the live tree,
per `Required Workflow: acceptance-first` (tasks.md T-001). This document
is the required TEST-ID ↔ assertion-function correspondence table, the RED
baseline evidence for both runtimes, and the load-bearing / case-sensitivity
fixture demonstrations tasks.md T-001's Done-When requires.

## Files created

- `tests/design-system-contract.tests.sh` — 528 lines appended (140 → 668
  total). Pure addition: `git diff --stat` reports `528 insertions(+)`, `0
  deletions(-)`, so every pre-existing `DS-NNN` assertion, including the
  seven `DS-006` literals at `:62-68`, is byte-unchanged (BL-007).
- `tests/design-system-contract.tests.ps1` — 597 lines appended (139 → 736
  total). Pure addition: `git diff --stat` reports `597 insertions(+)`, `0
  deletions(-)`.
- No other file was edited. `tests/run-all.sh` and `tests/run-all.ps1` are
  untouched (T-005's scope).

## Acceptance-first mapping: TEST-001..TEST-051 → assertion → target

Every row cites the one-line assertion `acceptance-tests.md`'s Test Matrix
states for that Test ID, and the file:approximate-line the assertion lives
at in each suite (both suites carry the block in the same relative order,
directly under the `design-sync-consent (issue #138, DS-29)` heading that
follows `DS-017` / `"ok: design-system contract tests passed"`).

| Test ID | AC | Target | Assertion logic |
|---|---|---|---|
| TEST-001 | AC-001 | `design-sync-loop/SKILL.md` `## Loop` | "consent has not been obtained for this scope" leads to "Obtain informed consent" |
| TEST-002 | AC-001 | same | "consent already holds" leads to "continue to 5" / proceeds to the pre-upload step |
| TEST-003 | AC-001 | same | "both must match" (scope conjunction) or "session has ended does not hold" |
| TEST-004 | AC-002 | same, whole file | "this feature AND/and this session" present; no "feature or session" disjunction |
| TEST-005 | AC-003(a) | `## Loop` step 4 | REQ-NNN + AC-NNN + confidential/pre-release |
| TEST-006 | AC-003(b) | same | claude.ai/design + external + "selected in step 1" |
| TEST-007 | AC-003(c) | same | "may be retained" + "does not control" |
| TEST-008 | AC-004 | same | "for this session" + "without asking again" |
| TEST-009 | AC-005 | same | "finalize_plan" + opacity/limitation language |
| TEST-010 | AC-006 | `## Loop`, positional | line-index order: Generate mockups < Resolve egress consent < Push < claude.ai/design browser |
| TEST-011 | AC-007 | same | "Local review is OPTIONAL" |
| TEST-012 | AC-007 | same | "no upload waits on it" / "not a precondition for push" |
| TEST-013 | AC-008 | same | "without any human having read it" |
| TEST-014 | AC-009 | `## Loop`, positional | "return to 2" present, "return to 3" absent (case-sensitive) |
| TEST-015 | AC-010 | whole file | five `Egress-*` field names present by literal name |
| TEST-016 | AC-011 (full) | whole file | `specs/<feature>/ux-spec.md` present |
| TEST-017 | AC-011 (lite) | staged draft `specs/design-sync-consent/verification/T-004/staged-lite-spec-candidate.draft.md` | draft exists + contains `specs/<feature>/design.md` |
| TEST-018 | AC-012 | whole file, **load-bearing** | structural: `audit trace[^.]{0,100}not[^.]{0,60}authorization` |
| TEST-019 | AC-013(1) | `## Capability Detection` | "tool is unavailable" + "design tools unavailable" |
| TEST-020 | AC-013(2) | same | "authentication fails" + "design tools unavailable" |
| TEST-021 | AC-014 | `claude-design-workflow.md` | "does not automatically inspect, upload, or retain" present + "consent" absent |
| TEST-022 | AC-015(1) | `## Boundaries` | "absence of mockups...never blocks" / "mockups or design tools" |
| TEST-023 | AC-015(2) | same | "design tools...never blocks" / "mockups or design tools" |
| TEST-024 | AC-016 | `sdd-bootstrap-interviewer/SKILL.md` | "no artifacts and no" + "further design-system questions" (byte-unchanged guarantee) |
| TEST-025 | AC-017(1) | `## Loop`, positional | "Pre-upload check point" line index ≠ consent line index, + "specs/<feature>/mockups/" |
| TEST-026 | AC-017(2) | `## Loop`, **load-bearing, structural** | every `write_files` line index ≥ the check-point line index |
| TEST-027 | AC-018 | `## Loop` | "property of the check" + "does not presume...an interactive human" |
| TEST-028 | AC-019(1) | `## Loop` | "consent has not been obtained for this scope" |
| TEST-029 | AC-019(2) | `## Loop` | "consent already holds for this feature" |
| TEST-030 | AC-019(3) | `## Loop` | "egress is not permitted" + "manual fallback" + "no upload" |
| TEST-031 | AC-020(1) | whole file | "extensible" + "ignored"/"non-conforming" |
| TEST-032 | AC-020(2) | whole file | "per-feature" near "select"/"default" |
| TEST-033 | AC-021 site 1 | frontmatter `description:` line | not-banned "per-upload"; "per-feature" or "feature ... and/AND ... session" |
| TEST-034 | AC-021 site 2 | `## Boundaries` | not-banned "every time"; per-feature/session phrasing |
| TEST-035 | AC-021 site 3 | `sdd-bootstrap-interviewer/SKILL.md` UI bullet | not-banned "per-upload"; per-feature/session phrasing |
| TEST-036 | AC-021 site 4 | `docs/workflow-guide.md` §3.1b | not-banned 都度人間承認; セッション present (Japanese) |
| TEST-037 | AC-022 | `CHANGELOG.md`, regression (negative) | SHA-256 of the 5-line historical block == recorded hash |
| TEST-038 | AC-023 | staged draft + `human-copy/MANIFEST.sha256` + live file | draft exists, manifest records its hash under the destination name, live file's hash == captured baseline |
| TEST-039 | AC-024 | `.github/workflows/*.yml` | both `design-system-contract.tests.sh` and `.ps1` referenced by some workflow file — **designed RED** |
| TEST-040 | AC-025 | `design-sync-loop/SKILL.md`, regression | the seven `DS-006` literals, re-asserted under this feature's own Test ID |
| TEST-041 | AC-026(1) | `## Loop` | "no upload" + "decline" |
| TEST-042 | AC-026(2) | `## Loop` | "next...asks again" / "prompts again" |
| TEST-043 | AC-026(3) | `## Loop` | "not a persisted refusal" / "no standing forbiddance" |
| TEST-044 | AC-027(1) | whole file | "Egress-Destination" + "selected in step 1" |
| TEST-045 | AC-027(2) | whole file | "does not carry to" / "re-enters step 4" / "different destination...gated again" |
| TEST-046 | AC-028(1) | whole file | "withdraw" + "mid-session" |
| TEST-047 | AC-028(2) | whole file | "withdraw" + "gated again"/"does not hold" |
| TEST-048 | AC-029(d) | `## Loop` | "future regenerations" + "for this session" |
| TEST-049 | AC-029(e) | `## Loop` | "pull direction" + "human-supplied project name" |
| TEST-050 | AC-029(f) | `## Loop` | "asserting...authority" + "claim, not a check"/"not enforced" |
| TEST-051 | AC-030 | `## Loop`, all 4 parts | "not change consent state" + "reports the failure" + "no re-prompt"/"without a new consent prompt" + "no standing forbiddance" |

No gaps: every TEST-001 through TEST-051 has exactly one row above, and one
assertion block in each of the two suite files, in the same order.

## RED baseline: current tree, both runtimes

### `.sh`

```
$ bash tests/design-system-contract.tests.sh
...
PASS: 78
FAIL: 43
$ echo $?
1
```

Full transcript: `red-baseline-sh.log`. Of the 121 total assertions (70
pre-existing `DS-NNN` + 51 new `TEST-NNN`):

- **9 of the 51 `TEST-NNN` already PASS** against the live tree, because
  the text they check is preserved unchanged by design: TEST-016 (the
  full-profile destination sentence, `SKILL.md:18`), TEST-019/TEST-020
  (`## Capability Detection`, untouched), TEST-021 (the fallback's
  no-upload sentence), TEST-022/TEST-023 (the non-blocking invariant),
  TEST-024 (the `ds_profile: none` guarantee, untouched),
  TEST-037 (the `CHANGELOG.md` byte-identity check — trivially true today
  since nothing has edited it yet), TEST-040 (the seven `DS-006` literals,
  re-read from the still-unrestructured file).
- **42 of the 51 `TEST-NNN` FAIL** — this is the expected RED baseline
  T-002/T-003/T-004 must turn GREEN for their own subset (tasks.md T-002
  Done-When: "shows every Test ID whose target is `design-sync-loop/
  SKILL.md` passing... This is this task's Green half of the feature-wide
  Red baseline T-001 established").
- **TEST-039 is expected to stay FAIL/RED even after T-002/T-003/T-004/T-005
  land** — CI registration is a separately staged, human-applied workflow
  patch (R-OQ-8 part 3), by design.
- **One pre-existing, unrelated failure was discovered and is reported,
  not fixed**: `FAIL: DS-010 impl count updated` — `phase-review-checklist.md`'s
  `impl-review-loop\`: 20 checks` count has drifted stale relative to the
  live file (later features added reviewer checks beyond 20). This
  predates this task (confirmed by running the unmodified suite before any
  edit — same single failure, `PASS: 69 / FAIL: 1`) and is out of T-001's
  scope (`.sh`/`.ps1` additions only; no existing `DS-NNN` line is edited,
  per BL-007 preservation and the global "no unrelated refactors" rule).
  Flagged here as a DISCOVERED DEFECT for a follow-on fix, not silently
  absorbed.

### `.ps1`

```
$ pwsh -NoProfile -File tests/design-system-contract.tests.ps1
...
PASS: 9
FAIL: 42
$ echo $?
1
```

Full transcript: `red-baseline-ps1.log`. The pre-existing `DS-001`..`DS-017`
blocks (throw-on-first-failure style, unaffected by this task) all report
`ok:` and the script does not throw before reaching the new section — the
existing `.ps1` `DS-010` check does not carry the stale count assertion the
`.sh` twin does (a pre-existing, harmless dual-runtime asymmetry, also not
this task's to fix), so it is unaffected by the `.sh`-side discovered
defect above.

**Runtime parity of the RED baseline is exact**: diffing the 51
`PASS: TEST-NNN` / `FAIL: TEST-NNN` lines from both logs (stripping the
one ASCII-subset comment suffix on TEST-040) shows an identical pattern —
the same 9 Test IDs PASS and the same 42 FAIL, in both runtimes, on the
same tree.

## TEST-018 / TEST-026 — load-bearing, demonstrated against a vacuous fixture first

Per tasks.md T-001 Done-When: "Both are demonstrated in the implementation
report by running each against a deliberately vacuous fixture...and
showing it fails, before the real target is checked."

Two fixtures, committed here for auditability:

- `fixture-vacuous-018.md` — a text that says "This is an audit trace...
  Authorization matters and consent matters too" without the actual
  negation relationship.
- `fixture-vacuous-026.md` — a Loop that names "Pre-upload check point" as
  step 3, but calls `write_files` in step 2, i.e. a real bypass.
- `fixture-well-formed-skill.md` — a hand-authored Loop matching design.md's
  target shape (API & Contract Plan, `design.md:90-158`), used as the
  positive control.

Result (full transcript: `load-bearing-and-case-sensitivity-evidence.log`),
both runtimes:

| Fixture | TEST-018 | TEST-026 |
|---|---|---|
| vacuous | FAIL (correct) | FAIL (correct — `cp_line=5`, `upload_lines=[4]`, `write_files` at line 4 precedes the check point named at line 5) |
| well-formed | PASS (correct) | PASS (correct — `cp_line=32`, `upload_lines=[36]`) |

This also positive-controls the full 51-assertion block: running the whole
new section against `fixture-well-formed-skill.md` (substituted for
`design-sync-loop/SKILL.md`) produces `PASS: 42 / FAIL: 9`, identically in
both runtimes, where the 9 expected failures are exactly the assertions
whose target the minimal fixture does not populate (TEST-016/017 — no
`ux-spec.md`/`design.md` destination sentence in this Loop-focused
fixture; TEST-033..036 — target `sdd-bootstrap-interviewer/SKILL.md` and
`docs/workflow-guide.md`, real files, unrelated to the fixture; TEST-038 —
no staged draft; TEST-039 — no CI registration; TEST-040 — the fixture
omits `## Ensure design-system/` content). None of the 9 is a logic
defect; all are accounted for by the fixture's intentionally narrow scope.

This is how a genuine, non-line-wrap-fragile bug in the first draft of
this suite was caught and fixed before landing: the first cut of every
multi-word phrase assertion matched directly against the raw, multi-line
file text via `grep`/`-match`, which silently fails when Markdown's
ordinary prose wrapping splits a phrase such as "both must match" across
two source lines. Validating against a realistic fixture surfaced this
immediately (several TEST-NNN incorrectly FAILed against otherwise-correct
content); the fix — collapsing the relevant section to one
whitespace-normalized line before phrase matching (`flatten_file`/
`flatten_text` in `.sh`, `Get-Flat`/`Get-FlatText` in `.ps1`) — is now in
both suites. The positional checks (TEST-010, TEST-014, TEST-025,
TEST-026) deliberately do **not** flatten, since they need real line
boundaries.

## Case-sensitivity sweep (AGENTS.md "Author-time sweeps" item 1)

Scope, per `acceptance-tests.md` Notes: narrow — only the `-match`/
`-cmatch`/`.Contains` sites this task adds to the `.ps1` suite whose `.sh`
counterpart compares case-sensitively. Audited every `grep` call added to
`.sh`; every one that is case-sensitive there (`grep -Fq`, or `grep -Eq`
without `-i`) uses `-cmatch` or `[string]::Contains` (ordinal,
case-sensitive) in `.ps1`; every case-insensitive one (`-Ei`/`-Fi`) uses
plain `-match`/`-notmatch` (PowerShell's default). No `Select-String`,
`-split`, `[regex]` static method, `switch -wildcard`/`-regex`, or
`Sort-Object` is used anywhere in the new `.ps1` section, so the
cmdlet-level layer of the sweep (item 1(b)) has no site to cover.

Mis-cased negative fixtures, one per case-sensitive site class
(operator-level layer, item 1(a)), transcript in
`load-bearing-and-case-sensitivity-evidence.log`:

- `-cmatch 'this feature AND this session|this feature and this session'`
  (TEST-004): `"This Feature And This Session"` → `False` (correctly
  rejected); the correctly-cased original → `True`.
- `-cmatch 'return to 2\b'` (TEST-014): `"Return To 2"` → `False`; `"return
  to 2"` → `True`.
- `-cmatch 'write_files'` (TEST-026): `"Write_Files"` → `False`;
  `"write_files"` → `True`.

Cmdlet-level layer (item 1(b)): not applicable — no cmdlet from that list
is used in this task's `.ps1` addition.

## `.ps1` parity asymmetries (BL-008)

One documented asymmetry, following the precedent at
`tests/design-system-contract.tests.ps1:57` (now `:594` after this task's
insertion) and the existing DS-006/DS-017 pattern in this same file:

- **TEST-040**: the `.sh` twin asserts all seven `DS-006` literals,
  including the em-dash-bearing D6 fallback note
  (`ui-ux-pro-max unavailable — D6 template interview used`). The `.ps1`
  side asserts the other six (ASCII-safe) and states in its own PASS/FAIL
  label that the em-dash literal is asserted by the `.sh` twin only —
  matching the *existing*, pre-this-task asymmetry the live `DS-006` block
  already carries between the two files (`tests/design-system-contract.tests.ps1:57`'s
  own comment: "the em-dash fallback note is asserted by the sh twin").
  This is not a new asymmetry introduced by this task; TEST-040 simply
  inherits the same, already-accepted one when re-asserting the same seven
  literals under its own Test ID.

No other asymmetry exists. TEST-036 (the one row that could plausibly have
needed one, since its target is Japanese) does not: both the banned-marker
negative check and the `セッション` positive check are built from Unicode
code points in `.ps1` (`$bannedJaPerUpload`, `$sessionKatakana`), so both
runtimes assert the identical two conditions, not a documented subset.

## Concerns for the reviewer

1. **Predictive risk on content-based assertions.** TEST-001 through
   TEST-051 (excluding the structural/positional ones) match phrase
   fragments drawn as closely as possible from `design.md`'s literal
   target text (API & Contract Plan, `:90-158`) and from `requirements.md`'s
   AC language, since T-002/T-003/T-004 have not landed yet at this task's
   authoring time. The well-formed-fixture positive control (42/51 PASS,
   with all 9 gaps explained by the fixture's intentionally narrow scope)
   is the strongest evidence available that the assertions are
   satisfiable by conforming content and not accidentally over-strict —
   but it is evidence against a hand-authored fixture, not against
   T-002/T-003/T-004's actual prose. Some assertions may need a small
   wording nudge on either side (test or skill) once T-002 lands; that is
   normal TDD RED→GREEN iteration, not a defect in this baseline.
2. **TEST-026's `write_files`-only scan.** Deliberately excludes
   `finalize_plan` from the bypass scan (comment at the assertion site
   explains why: `finalize_plan` is legitimately *discussed*, never
   *called*, in step 4's OQ-6 disclosure hedge, which precedes the check
   point by design — scanning for it would fail a conforming file). This
   is the one place a mechanical, naive read of AC-017/TEST-026 ("every
   upload path... no bypass") could plausibly disagree with the chosen
   implementation; the reasoning is recorded at the assertion site in both
   suites.
