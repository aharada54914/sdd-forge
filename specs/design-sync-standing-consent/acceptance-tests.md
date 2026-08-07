# Acceptance Tests: design-sync-standing-consent

Every criterion in this feature is a **document-conformance** assertion, for the same reason DS-29's are (`specs/design-sync-consent/acceptance-tests.md`): `AGENTS.md`, `design-sync-loop/SKILL.md`, and `claude-design-workflow.md` are all prose an agent reads, not code that runs. These tests prove the repository *says* the right thing, consistently, in every place it says anything about the project's upload-policy setting. They cannot prove an agent obeys it, and — sharper than DS-29's own version of this caveat — they cannot prove a human, rather than an agent, chose the setting's value in the first place (`security-spec.md`, principal residual risk).

Where a criterion's own language enumerates branches or quantifies over conditions, it is expanded below into individual branches, each with its own TEST row, per `AGENTS.md` "Author-time sweeps" item 4.

**Revision note (round 2).** A Codex adversarial review found one Critical finding and fourteen other findings against round 1 of this matrix (28 rows, `TEST-001`–`TEST-028`) and its sibling `requirements.md` / `design.md`. This revision expands the matrix to 54 rows, splitting several round-1 rows that combined independently-failable claims, sharpens several assertions into executable oracles, corrects the Critical finding (round 1's own `TEST-022` row required a fallback bullet that named the literal setting key — a file whose own regression test forbids the substring that key contains), and moves the one CI-dependent row into a dedicated "Deferred (non-blocking verification)" section. Round-1 Test IDs are **not** preserved positionally — the whole matrix is renumbered once, here, rather than leaving two generations of IDs to cross-reference, because round 1 was never referenced from outside this spec directory (no task, no implementation, no evidence bundle exists yet that cites a round-1 Test ID).

## Test Matrix

| Test ID | AC | REQ | Test Type | Target | Assertion in one line |
|---|---|---|---|---|---|
| TEST-001 | AC-001 | REQ-001 | document conformance | `AGENTS.md` | `ds_upload_consent`'s value domain is named as exactly `standing \| per-feature \| off`, no fourth value |
| TEST-002 | AC-002 | REQ-001 | document conformance | `AGENTS.md` | a `## Project Settings` heading exists **and** the `ds_upload_consent` key is named in a table row under it |
| TEST-003 | AC-003 | REQ-001 | document conformance | `AGENTS.md` | branch 1: a wholly absent `## Project Settings` section is stated to resolve to `per-feature` |
| TEST-004 | AC-003 | REQ-001 | document conformance | `AGENTS.md` | branch 2: a present section that omits the `ds_upload_consent` key is stated to resolve to `per-feature` |
| TEST-005 | AC-004 | REQ-001 | document conformance | `AGENTS.md` | the key's own definition contains no host-name conditional (no "Claude Code... Codex..." fork inside the definition text) |
| TEST-006 | AC-005 | REQ-002 | document conformance | `AGENTS.md` | `off`'s definition states the forbiddance applies on every host, unconditionally |
| TEST-007 | AC-006 | REQ-002 | document conformance | `design-sync-loop/SKILL.md` | step 3's outer selector carries no tool-presence conditional as part of what `off`/`standing`/`per-feature` mean |
| TEST-008 | AC-007 | REQ-003 | document conformance | `design-sync-loop/SKILL.md` | under `standing`, step 3 is stated never to produce the "must be requested" outcome |
| TEST-009 | AC-008 | REQ-003 | document conformance | same | the `standing` write is stated to go to the layer file's own `Design-Source` section specifically, not "a record" left unlocated |
| TEST-010 | AC-009 | REQ-003 | document conformance | same | the first-occurrence test is scoped to (feature, destination): checked against `Ds-Upload-Consent-Setting: standing` naming the current destination, not against the feature's records generally |
| TEST-011 | AC-030 | REQ-003 | document conformance | same | a different destination for an already-`standing`-recorded feature is stated to trigger a fresh one-time write, not inherit the existing record |
| TEST-012 | AC-010 | REQ-003 | document conformance | same | the one-time record's `Egress-Consent` value is stated as `granted` |
| TEST-013 | AC-011 | REQ-004 | document conformance | same | under `off`, step 3 is stated always to resolve to outcome (c) |
| TEST-014 | AC-012 | REQ-004 | document conformance | same | outcome (c) is stated to route to the manual fallback **and** that no upload is attempted (combined, one clause) |
| TEST-015 | AC-012 | REQ-004 | document conformance | same | an outcome record is stated to be written for the `off` resolution (existence, independent of its field completeness) |
| TEST-016 | AC-012 | REQ-004 | document conformance | same | that record is stated to carry `Ds-Upload-Consent-Setting: off` specifically, distinguishing it from a `per-feature` decline |
| TEST-017 | AC-013 | REQ-004 | document conformance | same | `off`'s forbiddance is stated as persistent, and explicitly distinguished from a transient per-attempt decline |
| TEST-018 | AC-014 | REQ-004 | document conformance | `AGENTS.md` + `design-sync-loop/SKILL.md` | the forbiddance is stated to hold on every host, cross-referencing TEST-006 |
| TEST-019 | AC-015 | REQ-005 | regression | `design-sync-loop/SKILL.md` | step 3(a)'s scope clause is present, unmodified |
| TEST-020 | AC-015 | REQ-005 | regression | same | step 3(b)'s routing clause is present, unmodified |
| TEST-021 | AC-015 | REQ-005 | regression | same | step 3(c)'s not-permitted/persistence/decline-distinction clauses are present, unmodified |
| TEST-022 | AC-015 | REQ-005 | regression | same | step 4's informed-consent disclosure content is present, unmodified |
| TEST-023 | AC-015 | REQ-005 | regression | same | step 5's pre-upload check point text is present, unmodified |
| TEST-024 | AC-015 | REQ-005 | regression | same | step 6's push-failure rule is present, unmodified |
| TEST-025 | AC-015 | REQ-005 | regression | same | step 7's review/regeneration cycle text is present, unmodified |
| TEST-026 | AC-016 | REQ-006 | document conformance | `design-sync-loop/SKILL.md` | `Egress-Consent-Party` is enumerated by name in the record table |
| TEST-027 | AC-016 | REQ-006 | document conformance | same | `Egress-Consent-At` is enumerated by name in the record table |
| TEST-028 | AC-016 | REQ-006 | document conformance | same | `Ds-Upload-Consent-Setting` is enumerated by name in the record table |
| TEST-029 | AC-017 | REQ-006 | document conformance | same | the extensibility paragraph states a DS-29-era record (missing the three new fields) remains conforming |
| TEST-030 | AC-018 | REQ-006 | regression | same | `Egress-Consent` field name present, unmodified |
| TEST-031 | AC-018 | REQ-006 | regression | same | `Egress-Consent-Scope` field name present, unmodified |
| TEST-032 | AC-018 | REQ-006 | regression | same | `Egress-Consent-Subject` field name present, unmodified |
| TEST-033 | AC-018 | REQ-006 | regression | same | `Egress-Destination` field name present, unmodified |
| TEST-034 | AC-018 | REQ-006 | regression | same | `Egress-Consent-Expiry` field name present, unmodified |
| TEST-035 | AC-018 | REQ-006 | regression | same | `Egress-Consent` domain value `granted` present, unmodified |
| TEST-036 | AC-018 | REQ-006 | regression | same | `Egress-Consent` domain value `not-permitted` present, unmodified |
| TEST-037 | AC-018 | REQ-006 | regression | same | `Egress-Consent` domain value `withdrawn` present, unmodified |
| TEST-038 | AC-019 | REQ-006 | document conformance | same | `standing`'s text states `Egress-Consent-Party` must not name a fabricated per-occurrence identity |
| TEST-039 | AC-019 | REQ-006 | document conformance | same | `off`'s text states `Egress-Consent-Party` must not name a fabricated per-occurrence identity |
| TEST-040 | AC-029 | REQ-006 | document conformance | same | a `standing` grant's target text carries all three new fields, not a subset |
| TEST-041 | AC-029 | REQ-006 | document conformance | same | an ordinary `per-feature` grant's target text carries all three new fields |
| TEST-042 | AC-029 | REQ-006 | document conformance | same | a `per-feature` mid-session withdrawal's target text carries all three new fields |
| TEST-043 | AC-029 | REQ-006 | document conformance | same | an `off`-driven not-permitted outcome's target text carries all three new fields |
| TEST-044 | AC-020 | REQ-007 | document conformance (executable oracle) | same | step 3's opening sentence states the setting is read at **every** resolution of the step, not cached across resolutions within a session |
| TEST-045 | AC-021 | REQ-007 | document conformance | same | the record-table text states a record's own `Ds-Upload-Consent-Setting` value never overrides the currently configured setting |
| TEST-046 | AC-022 | REQ-008 | regression (negative) | `claude-design-workflow.md` | the file contains no occurrence of the literal identifier `ds_upload_consent` anywhere (the Critical-finding fix, checked directly) |
| TEST-047 | AC-022 | REQ-008 | document conformance | same | the new bullet states the setting's value and audit outcome remain in force via this fallback, via an indirect reference, naming `Design-Source` as the write destination alongside the existing markers |
| TEST-048 | AC-023 | REQ-008 | regression | same | the existing "does not automatically inspect, upload, or retain" statement is present, unmodified, and no new upload-enabling language appears anywhere in the file |
| TEST-049 | AC-023 | REQ-008 | regression (minimal diff) | same | the file's content is unchanged outside the one appended bullet |
| TEST-050 | AC-024 | REQ-008 | regression (negative) | same | no case-insensitive occurrence of the substring "consent" exists anywhere in the file |
| TEST-051 | AC-025 | REQ-009 | external-suite regression (baseline-relative) | `tests/design-system-contract.tests.{sh,ps1}` | zero rows flip from green (pre-change baseline) to red (post-change); `TEST-010`/`TEST-015`/`TEST-018`/`TEST-026`/`TEST-040` checked explicitly as the rows this feature's edit shape most directly exposes |
| TEST-052 | AC-026 | REQ-009 | external-suite regression (baseline-relative) | same, `TEST-021` specifically | DS-29's `TEST-021` is green in both the pre- and post-change runs, re-verified from this feature's own suite, covering both the general "consent" sweep and the literal-key ban |
| TEST-053 | AC-027 | REQ-010 | registration conformance | `tests/run-all.sh`, `tests/run-all.ps1` | the new suite's two files are both registered |

## Deferred (non-blocking verification)

**Round 2, ruling E.** The one row below is presented separately from the Test Matrix above, rather than inside it, because it is expected to be **red on the live tree at authoring time and to remain red until a human applies a staged patch that is out of this feature's own control** — the same designed fail-closed state as DS-29's own `TEST-039`. Placing it in the main matrix, next to fifty-three rows that are all expected to go green once this feature is implemented, would read as an authoring defect the first time someone runs the suite; this section exists so it reads instead as the deliberate, documented gap it is.

| Test ID | AC | REQ | Test Type | Target | Assertion in one line |
|---|---|---|---|---|---|
| TEST-054 | AC-028 | REQ-010 | CI-registration conformance (deferred, non-blocking) | `.github/workflows/test.yml` | this feature's suite is reachable from a CI entry point — **stays red on the live tree until a human applies the staged patch**, by design; not a blocker for any task in this feature's decomposition |

Assert this feature's suite is reachable from a CI entry point, tracing from `.github/workflows/` to the suite file, in both runtimes. `.github/workflows/test.yml` is protected (`guard_invariants.py:4`, `:18`), and `tests/run-all.sh` is itself invoked by no workflow today (re-verified: zero matches for `run-all` across `.github/workflows/` at drafting time), so registering the suite in `run-all` (TEST-053) does not by itself make it CI-executed. This is the identical structural gap DS-29's own `TEST-039` documents, applied to a second, newer suite.

## Test Details

### TEST-001 (AC-001) — the domain is decided, not deferred

Assert the `Values` cell for `ds_upload_consent` names exactly three alternatives, separated by `|`, and no additional value appears anywhere in the key's own row. This is a decidedness check, in the manner of DS-29's own `TEST-004` for consent scope: it fails a table cell that hedges ("e.g. `standing`, `per-feature`, or similar") and passes one that commits to exactly three, in either order.

### TEST-002 (AC-002) — not a heading-only check

Deliberately structured like DS-29's own `TEST-015` for `Design-Source`: `## Project Settings` could exist as an empty heading and satisfy a heading-presence check today, before this feature adds anything under it. The assertion requires the heading, the literal key name `ds_upload_consent`, and the key's presence inside a table row under that heading — not merely somewhere later in the file.

### TEST-003 / TEST-004 (AC-003) — two absences, two rows (round 2, finding 6)

Round 1 combined "no section" and "section but no key" into one assertion. Split because an implementation can satisfy one and miss the other: a whole-file default (if `## Project Settings` is missing entirely, assume `per-feature`) does not automatically also handle a present-but-incomplete section, and a table-driven default lookup (read the `ds_upload_consent` row's `Default` cell) does not automatically also handle the section being absent in the first place, since there is no row to look up. **TEST-003** asserts the wholly-absent case; **TEST-004** asserts the present-section-missing-key case. Both must pass independently for AC-003 to hold.

### TEST-005 (AC-004) / TEST-007 (AC-006) — host-neutrality has two independent places it can leak a fork

Two rows because the two files can diverge independently: `AGENTS.md`'s own definition of what the values mean (TEST-005), and `design-sync-loop/SKILL.md`'s step 3 text that actually reads the value (TEST-007). A definition that is host-neutral in `AGENTS.md` but implemented with a hidden "except on Codex" clause in `SKILL.md` would satisfy TEST-005 while failing the requirement's actual purpose; asserting only one file would miss that.

### TEST-006 (AC-005) / TEST-018 (AC-014) — `off`'s "every host" claim, stated and cross-referenced

TEST-006 asserts the phrase exists in `AGENTS.md`'s own definition. TEST-018 asserts the same property is reachable from `design-sync-loop/SKILL.md`'s own `off` branch, not only from the setting's definition — a specification that states host-neutrality once, in a file the loop's own text never points back to, is one edit away from a `SKILL.md` restructuring silently losing the cross-reference. Both rows exist because REQ-002's own text explicitly declines to claim a present-tense behavioural difference on a tool-absent host — the assertion must find the *unconditional forbiddance* claim, not a claim that could be satisfied by a host-specific behavioural test that would trivially pass on every host today regardless of what `off` means.

### TEST-008 / TEST-009 / TEST-010 / TEST-011 / TEST-012 (AC-007, AC-008, AC-009, AC-030, AC-010) — `standing`, one branch per independently-failable clause

Issue AC #1 ("standing 設定でフィーチャ毎確認が省略されるが監査記録は残る") packs several claims into one sentence, further sharpened by round 2's destination-scoping ruling; each gets its own row because each fails independently:

- **TEST-008** — the confirmation is skipped. The failure this catches: an implementation that reads `standing` but still routes through outcome (b) "must be requested" for the first upload of a session, which would satisfy the issue's word "standing" while failing its substance.
- **TEST-009** — a record exists anyway, **and is written specifically to the layer file's own `Design-Source` section (round 2, finding 7)**, not to some unstated location. The failure this catches: an implementation that writes an audit fact somewhere ad hoc — a comment, a separate log file — rather than the one location every other record in this system uses.
- **TEST-010** — the record is written **once per (feature, destination) pair**, not once per feature regardless of destination, and not once per session **(round 2, ruling B, sharpening round 1's feature-only scoping)**. The assertion is written against the specific mechanism (a check for `Ds-Upload-Consent-Setting: standing` naming the current destination already present), not against the word "once" appearing somewhere.
- **TEST-011** — a **different** destination for an already-recorded feature triggers a **fresh** write, rather than being silently covered by the earlier record (round 2, new — resolves OQ-3). Mirrors DS-29's own `AC-027` second branch. Without this row, an implementation satisfying TEST-010 alone could still under-report every destination beyond the first a feature's content was sent to.
- **TEST-012** — the value is `granted`, the existing domain member, not an invented fourth value. The failure this catches: an implementation that adds `Egress-Consent: standing-granted` or similar, which would break DS-29's own field-value assumptions and this feature's own `AC-018` regression simultaneously.

### TEST-013 / TEST-014 / TEST-015 / TEST-016 / TEST-017 / TEST-018 (AC-011, AC-012, AC-013, AC-014) — `off`, one branch per independently-failable clause

Symmetric to the `standing` set, for issue AC #2 ("off 設定で claude.ai upload が禁止され fallback へ流れる"), and further split per round 2, finding 8:

- **TEST-013** — outcome is always (c). The failure this catches: an implementation that treats `off` as "ask, but default the answer to no," which still reaches step 4's prompt.
- **TEST-014** — routing to the manual fallback **and** no upload attempted, kept as one combined clause (round 2, finding 8) because the two are meaningless apart: naming the fallback without also stating that no upload follows it would leave "route to the fallback, then upload anyway" unexcluded.
- **TEST-015** — an outcome/audit record is written for the `off` resolution at all — existence, independent of the record's field completeness (which AC-029/TEST-043 owns).
- **TEST-016** — that record carries the `off`-specific marker (`Ds-Upload-Consent-Setting: off`), which is what makes AC-013's distinguishability claim checkable — a record indistinguishable from a `per-feature` decline would defeat the entire point of naming the outcome persistent.
- **TEST-017** — the persistence, and its distinction from a transient decline. The substantive row: an implementation that treats `off` as a fresh per-attempt "would you like to decline" satisfies "the outcome is not permitted" in isolation while manufacturing exactly the per-attempt friction `off` is supposed to remove entirely.
- **TEST-018** — every host, cross-referencing TEST-006 (see above).

### TEST-019 through TEST-025 (AC-015) — DS-29's own text, unmodified, checked per span (round 2, finding 9)

Round 1 checked all of step 3(a)/(b)/(c) through step 7 as one combined regression claim. Split into seven rows because DS-29's own `tests/design-system-contract.tests.sh` (`TEST-001` through `TEST-051`) verifies each span through a *different* mechanism — a literal scope-clause match for 3(a), a routing-phrase match for 3(b), a persistence/decline-distinction match for 3(c), a disclosure-content match for step 4, a check-point-location match for step 5, a push-failure-rule match for step 6, a cycle-edge structural match for step 7 — and this feature's edit is an outer branch inserted immediately *before* step 3(a), which is exactly the shape of change most likely to shift one span's relative position without touching a single word of its text. A combined "everything from step 3 through step 7 is unmodified" claim would localize a regression to "somewhere in five hundred lines"; seven separate rows localize it to one span.

### TEST-026 / TEST-027 / TEST-028 (AC-016) — one field, one row (round 2, finding 10)

Round 1 combined all three new field names into one chained assertion, following DS-29's own `TEST-015` pattern for its five *existing* fields. Round 2 splits this feature's *three new* fields into individual rows instead, because a chained assertion across three brand-new literals reports "some subset of the new content is missing" without telling a reviewer which one — a materially worse failure message for a brand-new table than for DS-29's already-stable five-field one, where the chained form has years of stability behind it. `Egress-Consent-Party` (TEST-026), `Egress-Consent-At` (TEST-027), and `Ds-Upload-Consent-Setting` (TEST-028) are each checked as their own literal.

### TEST-029 (AC-017) — the extensibility statement, checked as prose

Assert a DS-29-era record lacking the three fields is still described as conforming — a table alone cannot carry "and a record written before these fields existed is still valid," which is the actual content this criterion requires.

### TEST-030 through TEST-037 (AC-018) — eight branches, eight rows (round 2, finding 11)

Round 1 combined DS-29's five existing field names and the three `Egress-Consent` domain values into one regression row, on the reasoning that a table-restructuring accident is equally likely to hit any of them. Round 2 corrects this: the *reasoning* survives (the failure mode is the same class regardless of which cell was hit) but the *reporting* does not need to collapse with it — eight independent literal checks (`Egress-Consent`, `Egress-Consent-Scope`, `Egress-Consent-Subject`, `Egress-Destination`, `Egress-Consent-Expiry`, `granted`, `not-permitted`, `withdrawn`) let a reviewer see exactly which of the eight moved, at the cost of eight lines of test source instead of one. Given that this feature's own edit inserts three new rows immediately adjacent to these eight literals, the marginal cost of granularity here is low and the diagnostic value is high.

### TEST-038 / TEST-039 (AC-019) — non-fabrication, for both no-live-human regimes (round 2, broadened)

Round 1 asserted this only for `standing`. Round 2 recognizes that `off`'s not-permitted outcome has the identical property — nobody is ever asked, so nobody's identity belongs in the record — and adds a symmetric row. **TEST-038** checks `standing`'s own text for the non-fabrication statement; **TEST-039** checks `off`'s. Kept as two rows rather than one combined "neither regime fabricates an identity" claim because the two branches live in different parts of `SKILL.md`'s step-3 text and can regress independently if either is edited in isolation later.

### TEST-040 / TEST-041 / TEST-042 / TEST-043 (AC-029) — the four record-producing occasions, round 2's principal new check

This is the row set that directly repairs the round-2 Critical-adjacent finding (ruling C): round 1's `off` target text specified only `Egress-Consent: not-permitted, Ds-Upload-Consent-Setting: off`, silently omitting `Egress-Consent-Party` and `Egress-Consent-At`. Four rows, one per occasion this skill's behaviour can produce a `Design-Source` write:

- **TEST-040** — a `standing` grant carries all three new fields (already implied by TEST-009/012's own text, restated here as its own completeness check rather than left to be inferred from two narrower rows).
- **TEST-041** — an ordinary `per-feature` grant, recorded by DS-29's own unedited step-4 logic, also carries all three — this is the row that makes REQ-006's "every record, not only `standing`'s" claim checkable, not merely asserted in prose.
- **TEST-042** — a `per-feature` mid-session withdrawal (DS-29's own unedited `AC-028` path) also carries all three. Named because it is the one occasion neither the issue text nor round 1 of this document mentioned at all — an implementer who copies DS-29's withdrawal text verbatim (as REQ-005/AC-015 requires) has no textual cue, without this row's corresponding target-text update, to also thread the three new fields through it.
- **TEST-043** — an `off`-driven not-permitted outcome carries all three. This is the row round 1 would have failed had it existed: round 1's own target text for `off` supplied only one of the three fields.

### TEST-044 (AC-020) — live-read, as an executable oracle (round 2, ruling A)

Round 1 asserted only that step 3 reads the setting's "current value," a phrase ambiguous between "current per resolution" and "current as of session start." Round 2 replaces this with an executable oracle: assert the text states the setting is read **at every resolution of step 3**, and explicitly that a value is **not** cached or reused across resolutions within one session. The assertion must find a comparison between *this* resolution and a *previous* resolution — not merely the word "current" — because "current" alone is satisfiable by either reading and was exactly round 1's own hedge.

### TEST-045 (AC-021) — non-override, the sharper companion to TEST-044

Assert the record-table text explicitly states a record's own historical setting value never overrides the currently configured setting. This is the row that actually forecloses the dangerous reading (a stale `standing`-era `granted` record silently continuing to authorize uploads after the project switches to `off`) — TEST-044 alone establishes only that the *setting* is read live, not what happens when a *record* disagrees with a live reading.

### TEST-046 / TEST-047 (AC-022) — the Critical-finding fix, checked two ways

- **TEST-046** — the negative, direct check: `claude-design-workflow.md` contains **no occurrence of the literal identifier `ds_upload_consent`** anywhere. This is the row that directly verifies the Critical finding's fix — round 1's own draft would have failed this row outright, on line 1 of its own proposed bullet.
- **TEST-047** — the positive check: the bullet states the setting's value and its audit outcome remain in force via this fallback, using an indirect reference (checked for substance — a reference to "the upload-policy setting" or equivalent — not for the presence of any one exact sentence), and names `Design-Source` as the write destination, alongside the existing markers.

Both are required because either alone is satisfiable by a text that fails the criterion: a bullet that avoids the literal identifier but never actually states anything about the setting's value surviving (passes TEST-046, fails TEST-047), or a bullet that says the right things but reintroduces the identifier while doing so (passes TEST-047 in spirit, fails TEST-046 on the literal check that matters most).

### TEST-048 / TEST-049 (AC-023) — no upload introduced, checked two ways (round 2, finding 14)

- **TEST-048** — DS-29's own no-upload statement (`:12`, restated in Boundaries) is present, unmodified, **and** no new upload-enabling language is introduced anywhere in the file, including inside the new bullet itself. Positive-plus-negative, mirroring DS-29's own `TEST-021` shape.
- **TEST-049** — the file's content is otherwise unchanged outside the one appended bullet — a minimal-diff check, distinct from TEST-048's keyword-absence check, because a file can gain unrelated content in the same edit (a stray reformatting pass, an accidental duplicate section) without any of it containing the word "upload." This is the row that catches scope creep in the edit itself, not only in its vocabulary.

### TEST-050 (AC-024) — the general sweep, still the widest net

Assert no case-insensitive "consent" substring anywhere in the file, checked over the whole file (not only the new bullet), because an edit elsewhere in the same commit could just as easily introduce the word. This row and TEST-046 are two views of the same underlying fact: TEST-046 bans one specific, known-guaranteed trigger (the literal key); TEST-050 is the general sweep that would also catch any other, unanticipated way the substring could re-enter the file.

### TEST-051 / TEST-052 (AC-025, AC-026) — DS-29's suite, run against a documented baseline, not claimed unconditionally green (round 2, ruling E)

**TEST-051** runs `tests/design-system-contract.tests.sh` (and `.ps1`) against the tree **before** this feature's edit, records which rows pass and which are already red (DS-29's own `TEST-039` is expected to be among the latter, for reasons unrelated to this feature), then runs the same suite **after** the edit and asserts no row that was green before is red after. Five rows are named explicitly — `TEST-010`, `TEST-015`, `TEST-018`, `TEST-026`, `TEST-040` — as the ones this feature's own edit shape most plausibly threatens, each through a distinct mechanism spelled out in `requirements.md` AC-025. Naming them does not exempt the rest of the suite from the baseline comparison; the whole suite's before/after diff is the actual assertion, and the five are named because a failure there is the one most directly attributable to this feature's specific edit.

**TEST-052** is deliberately redundant with part of TEST-051's own scope (DS-29's `TEST-021` is one of the rows TEST-051's baseline comparison already covers) and is kept as its own row anyway, for the reason `requirements.md` gives it its own AC (AC-026): `claude-design-workflow.md` is the one file this feature's Critical finding shows a second editor can break in a way that is easy to miss without a dedicated check, and TEST-052 re-verifies it from this feature's own suite as well, covering both the general sweep and the literal-key ban.

### TEST-053 (AC-027) — local registration, no protected file involved

Assert `tests/design-sync-standing-consent.tests.sh` and `.ps1` both appear in `tests/run-all.sh` and `tests/run-all.ps1` respectively. Unlike the deferred row, this one has no designed-red state — both files are unprotected, so there is no reason for this assertion to be anything but green once the suite is authored.

## UI Integration Checklist

**N/A — no user-facing entry point.** This feature adds no view, dialog, menu item, or context action; if anything, it removes the one user-facing surface DS-29 introduced (the consent prompt no longer appears at all under `standing` or `off`). Recorded as N/A rather than omitted, matching DS-29's own convention (`specs/design-sync-consent/acceptance-tests.md`) and this repository's convention for non-UI features generally.

## Notes

- **Test type vocabulary.** `document conformance` is the default; `document conformance (executable oracle)` marks a row whose assertion is a specific structural comparison rather than a keyword search (TEST-044); `regression` marks a row whose assertion is that specific pre-existing text is unmodified; `regression (negative)` marks a row asserting the specific absence of a substring or identifier; `regression (minimal diff)` marks a row asserting a file's content is unchanged outside one named addition; `external-suite regression (baseline-relative)` marks a row that invokes a different feature's own test suite and compares before/after rather than asserting an unconditional clean exit (round 2, ruling E); `registration conformance` and `CI-registration conformance (deferred, non-blocking)` follow DS-29's own vocabulary for its equivalent rows (`TEST-038`, `TEST-039`).
- **Dual-runtime parity.** Every assertion above exists in both the `.sh` and `.ps1` suites, with carve-outs documented at the point they are created, following the precedent at `tests/design-system-contract.tests.ps1:57`.
- **Case-sensitivity sweep (`AGENTS.md` "Author-time sweeps" item 1) — applicability.** This feature ports no `.sh` script to `.ps1`; both runtimes are authored directly. The sweep applies narrowly to any `-match` / `-notmatch` / `Select-String` site added here whose `.sh` counterpart compares case-sensitively, and must be performed, with a mis-cased negative fixture per layer, before the change is reported Implementation Complete.
- **The two banned-literal rows (TEST-046, TEST-050) must not embed their own banned string** (`AGENTS.md` "Author-time sweeps" item 2), in both the `.sh` and `.ps1` sources: the suite's own source must not spell out `ds_upload_consent` or the contiguous substring `consent` inside the assertion logic that checks `claude-design-workflow.md` for their absence — both must be assembled at runtime from non-contiguous parts, exactly as DS-29's own `TEST-033`–`TEST-036` already do for their banned phrases.
- **Re-verify every `file:line` in this document at implementation start** (WFI-011).
- **Three Open Questions in `requirements.md` remain non-blocking; two more were resolved in round 2.** OQ-1 (re-read granularity) and OQ-3 (destination scope for `standing`) are resolved and no longer hedge any TEST row here. OQ-2 (broadened to cover both `standing` and `off`), OQ-4, and OQ-5 remain open and are each hedged by a criterion that accepts the gap rather than guessing (AC-019 for OQ-2; REQ-010's staged-patch framing for OQ-5), exactly as DS-29's own `TEST-009`/`AC-005` accepts either a citation or a stated limitation rather than guessing which of its own Open Questions would resolve to.
