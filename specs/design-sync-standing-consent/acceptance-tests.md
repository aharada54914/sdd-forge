# Acceptance Tests: design-sync-standing-consent

Every criterion in this feature is a **document-conformance** assertion, for the same reason DS-29's are (`specs/design-sync-consent/acceptance-tests.md`): `AGENTS.md`, `design-sync-loop/SKILL.md`, and `claude-design-workflow.md` are all prose an agent reads, not code that runs. These tests prove the repository *says* the right thing, consistently, in every place it says anything about `ds_upload_consent`. They cannot prove an agent obeys it, and — sharper than DS-29's own version of this caveat — they cannot prove a human, rather than an agent, chose the setting's value in the first place (`security-spec.md`, principal residual risk).

Where a criterion's own language enumerates branches or quantifies over conditions, it is expanded below into individual branches, each with its own TEST row, per `AGENTS.md` "Author-time sweeps" item 4.

## Test Matrix

| Test ID | AC | REQ | Test Type | Target | Assertion in one line |
|---|---|---|---|---|---|
| TEST-001 | AC-001 | REQ-001 | document conformance | `AGENTS.md` | `ds_upload_consent`'s value domain is named as exactly `standing \| per-feature \| off`, no fourth value |
| TEST-002 | AC-002 | REQ-001 | document conformance | `AGENTS.md` | a `## Project Settings` heading exists **and** the `ds_upload_consent` key is named under it — not a heading-only check |
| TEST-003 | AC-003 | REQ-001 | document conformance | `AGENTS.md` | absence of the section, or of the key within it, is stated to resolve to `per-feature` |
| TEST-004 | AC-004 | REQ-001 | document conformance | `AGENTS.md` | the key's own definition contains no host-name conditional (no "Claude Code... Codex..." fork inside the definition text) |
| TEST-005 | AC-005 | REQ-002 | document conformance | `AGENTS.md` | `off`'s definition states the forbiddance applies on every host, unconditionally |
| TEST-006 | AC-006 | REQ-002 | document conformance | `design-sync-loop/SKILL.md` | step 3's outer selector carries no tool-presence conditional as part of what `off`/`standing`/`per-feature` mean |
| TEST-007 | AC-007 | REQ-003 | document conformance | `design-sync-loop/SKILL.md` | under `standing`, step 3 is stated never to produce the "must be requested" outcome |
| TEST-008 | AC-008 | REQ-003 | document conformance | same | despite no prompt, an audit record is stated to be written |
| TEST-009 | AC-009 | REQ-003 | document conformance | same | the record is stated to be written on the first occurrence only, tested against the presence of `Ds-Upload-Consent-Setting: standing`, not against any prior record's mere existence |
| TEST-010 | AC-010 | REQ-003 | document conformance | same | the one-time record's `Egress-Consent` value is stated as `granted` |
| TEST-011 | AC-011 | REQ-004 | document conformance | same | under `off`, step 3 is stated always to resolve to outcome (c) |
| TEST-012 | AC-012 | REQ-004 | document conformance | same | outcome (c) is stated to route to the manual fallback with no upload attempted, and its record is stated to carry `Ds-Upload-Consent-Setting: off` |
| TEST-013 | AC-013 | REQ-004 | document conformance | same | `off`'s forbiddance is stated as persistent, and explicitly distinguished from a transient per-attempt decline |
| TEST-014 | AC-014 | REQ-004 | document conformance | `AGENTS.md` + `design-sync-loop/SKILL.md` | the forbiddance is stated to hold on every host, cross-referencing TEST-005 |
| TEST-015 | AC-015 | REQ-005 | regression | `design-sync-loop/SKILL.md` | DS-29's own step 3(a)/(b)/(c), step 4, step 5, step 6, and step 7 text is present and unmodified inside the `per-feature` regime |
| TEST-016 | AC-016 | REQ-006 | document conformance | `design-sync-loop/SKILL.md` | the three new field names — `Egress-Consent-Party`, `Egress-Consent-At`, `Ds-Upload-Consent-Setting` — are enumerated in the record table |
| TEST-017 | AC-017 | REQ-006 | document conformance | same | the extensibility paragraph states a DS-29-era record (missing the three new fields) remains conforming |
| TEST-018 | AC-018 | REQ-006 | regression | same | DS-29's five existing field names and `Egress-Consent`'s three-valued domain are present and unmodified |
| TEST-019 | AC-019 | REQ-006 | document conformance | same | the `standing` regime's text states `Egress-Consent-Party` must not name a fabricated per-occurrence identity |
| TEST-020 | AC-020 | REQ-007 | document conformance | same | step 3's opening sentence states the setting is read at its current value, not a value captured once and reused |
| TEST-021 | AC-021 | REQ-007 | document conformance | same | the record-table text states a record's own `Ds-Upload-Consent-Setting` value never overrides the currently configured setting |
| TEST-022 | AC-022 | REQ-008 | document conformance | `claude-design-workflow.md` | the new Boundaries bullet states the setting's value and its audit outcome remain in force when this fallback is the path taken |
| TEST-023 | AC-023 | REQ-008 | regression | same | the existing "does not automatically inspect, upload, or retain" statement is present and unmodified |
| TEST-024 | AC-024 | REQ-008 | regression (negative) | same | no case-insensitive occurrence of the substring "consent" exists anywhere in the file |
| TEST-025 | AC-025 | REQ-009 | external-suite regression | `tests/design-system-contract.tests.{sh,ps1}` | the suite exits 0 unmodified against the edited tree; `TEST-010`/`TEST-015`/`TEST-018`/`TEST-026`/`TEST-040` checked explicitly as the rows this feature's edit shape most directly exposes |
| TEST-026 | AC-026 | REQ-009 | external-suite regression | same, `TEST-021` specifically | DS-29's `TEST-021` (no "consent" substring in `claude-design-workflow.md`) passes unmodified, re-verified from this feature's own suite |
| TEST-027 | AC-027 | REQ-010 | registration conformance | `tests/run-all.sh`, `tests/run-all.ps1` | the new suite's two files are both registered |
| TEST-028 | AC-028 | REQ-010 | CI-registration conformance | `.github/workflows/test.yml` | this feature's suite is reachable from a CI entry point — **stays red on the live tree until a human applies the staged patch**, by design |

## Test Details

### TEST-001 (AC-001) — the domain is decided, not deferred

Assert the `Values` cell for `ds_upload_consent` names exactly three alternatives, separated by `|`, and no additional value appears anywhere in the key's own row. This is a decidedness check, in the manner of DS-29's own `TEST-004` for consent scope: it fails a table cell that hedges ("e.g. `standing`, `per-feature`, or similar") and passes one that commits to exactly three, in either order.

### TEST-002 (AC-002) — not a heading-only check

Deliberately structured like DS-29's own `TEST-015` for `Design-Source`: `## Project Settings` could exist as an empty heading and satisfy a heading-presence check today, before this feature adds anything under it. The assertion requires both the heading **and** the literal key name `ds_upload_consent` to be present, and — for the strongest version of this check — that the key appears inside a table row under that heading, not merely somewhere later in the file.

### TEST-003 (AC-003) — backward compatibility is a statement, not an inference

Assert the definition states, in terms an implementer cannot miss, that an absent section or an absent key resolves to `per-feature`. The failure this guards against is a definition that states the three values and their meanings but never says what happens when none is configured — which would leave every `AGENTS.md` written before this feature in an undefined state rather than an explicitly backward-compatible one.

### TEST-004 (AC-004) / TEST-006 (AC-006) — host-neutrality has two independent places it can leak a fork

Two rows because the two files can diverge independently: `AGENTS.md`'s own definition of what the values mean (TEST-004), and `design-sync-loop/SKILL.md`'s step 3 text that actually reads the value (TEST-006). A definition that is host-neutral in `AGENTS.md` but implemented with a hidden "except on Codex" clause in `SKILL.md` would satisfy TEST-004 while failing the requirement's actual purpose; asserting only one file would miss that.

### TEST-005 (AC-005) / TEST-014 (AC-014) — `off`'s "every host" claim, stated and cross-referenced

TEST-005 asserts the phrase exists in `AGENTS.md`'s own definition. TEST-014 asserts the same property is reachable from `design-sync-loop/SKILL.md`'s own `off` branch, not only from the setting's definition — a specification that states host-neutrality once, in a file the loop's own text never points back to, is one edit away from a `SKILL.md` restructuring silently losing the cross-reference. Both rows exist because REQ-002's own text explicitly declines to claim a present-tense behavioural difference on a tool-absent host (Capability Detection already forecloses the upload there for an unrelated reason) — the assertion must find the *unconditional forbiddance* claim, not a claim that could be satisfied by a host-specific behavioural test that would trivially pass on every host today regardless of what `off` means.

### TEST-007 / TEST-008 / TEST-009 / TEST-010 (AC-007–AC-010) — `standing`, one branch per independently-failable clause

Issue AC #1 ("standing 設定でフィーチャ毎確認が省略されるが監査記録は残る") packs four claims into one sentence; each gets its own row because each fails independently:

- **TEST-007** — the confirmation is skipped. The failure this catches: an implementation that reads `standing` but still routes through outcome (b) "must be requested" for the first upload of a session, which would satisfy the issue's word "standing" while failing its substance.
- **TEST-008** — a record exists anyway. The failure this catches: an implementation that optimizes only for "ask nothing" and drops the record along with the prompt, satisfying TEST-007 while failing the issue's own second clause.
- **TEST-009** — the record is written **once**, not once per session. The assertion is written against the specific mechanism (a check for `Ds-Upload-Consent-Setting: standing` already present), not against the word "once" appearing somewhere — a text that says "record once" without stating *what* "once" is tested against would leave an implementer free to interpret it as "once per session," which defeats the entire point of `standing` relative to `per-feature`.
- **TEST-010** — the value is `granted`, the existing domain member, not an invented fourth value. The failure this catches: an implementation that adds `Egress-Consent: standing-granted` or similar, which would break DS-29's own `TEST-015`-style field-value assumptions and this feature's own `AC-018` regression simultaneously.

### TEST-011 / TEST-012 / TEST-013 / TEST-014 (AC-011–AC-014) — `off`, one branch per independently-failable clause

Symmetric to the `standing` set, for issue AC #2 ("off 設定で claude.ai upload が禁止され fallback へ流れる"):

- **TEST-011** — outcome is always (c). The failure this catches: an implementation that treats `off` as "ask, but default the answer to no," which still reaches step 4's prompt and is a materially weaker control than the issue asks for.
- **TEST-012** — the routing and its record. Two things in one row deliberately, mirroring DS-29's own `TEST-030` shape (an outcome that is merely *named* but has no stated consequence would satisfy a weaker check while leaving `off` unimplementable) — the assertion requires both "no upload attempted" **and** the `Ds-Upload-Consent-Setting: off` marker on the record it produces.
- **TEST-013** — the persistence, and its distinction from a transient decline. The substantive row: an implementation that treats `off` as a fresh per-attempt "would you like to decline" satisfies "the outcome is not permitted" in isolation while manufacturing exactly the per-attempt friction `off` is supposed to remove entirely, in the opposite direction from `standing`'s own removal.
- **TEST-014** — every host, cross-referencing TEST-005 (see above).

### TEST-015 (AC-015) — DS-29's own text, unmodified, checked as a regression

The single highest-value row against accidental damage. Assert that the specific sentences DS-29's own `tests/design-system-contract.tests.sh` already checks in detail (its `TEST-001` through `TEST-051`, covering step 3's scope/destination/decline/withdrawal rules, step 4's disclosure, step 5's check point, step 6's push-failure rule, and step 7's cycle) are present, byte-identical, inside the `per-feature` regime's own text after this feature's edit. This is not a substitute for running DS-29's own suite (TEST-025) — it is the same claim, checked from this feature's own document, so a reader of this file alone can see what "unmodified" means without cross-referencing a different acceptance-tests.md.

### TEST-016 / TEST-017 / TEST-018 / TEST-019 (AC-016–AC-019) — the record table, additively extended

- **TEST-016** — field names enumerated, in the manner of DS-29's own `TEST-015` (a single combined assertion across all three new names, not three separate rows, because — unlike a multi-element disclosure where each element is a semantically distinct claim — three field-name literals are the same kind of claim three times, and a chained `grep -F` is the right shape for it, exactly as DS-29's own `TEST-015` combines all five of its field names in one assertion).
- **TEST-017** — the extensibility statement, checked as prose (a DS-29-era record lacking the three fields is still described as conforming), not merely inferred from the fields being described as optional in a table cell — a table alone cannot carry "and a record written before these fields existed is still valid," which is the actual content this criterion requires.
- **TEST-018** — regression on DS-29's own five fields and the `Egress-Consent` domain. Combined into one row for the reason DS-29's own `TEST-040` combines seven literals into one row: the failure mode (table restructuring damaged something it shouldn't have) is the same regardless of which specific cell was hit.
- **TEST-019** — the non-fabrication rule for `standing`'s `Egress-Consent-Party`. Assert the `standing` regime's own text states the value must not name a person or operator who did not act at that occurrence — accepting any phrasing that names the mechanism instead (the setting, the project configuration) and rejecting a phrasing that implies a specific human decided *this* upload.

### TEST-020 / TEST-021 (AC-020, AC-021) — live-read, and non-override, are different claims

- **TEST-020** — step 3's own opening sentence states the setting is read at its current value. A necessary but insufficient claim on its own — "current" could be misread as "current per session" without contradicting this row (OQ-1 is exactly this residue, left open on purpose).
- **TEST-021** — the sharper, checkable claim: a record's own historical setting value is explicitly stated never to override the live setting. This is the row that actually forecloses the dangerous reading (a stale `standing`-era `granted` record silently continuing to authorize uploads after the project switches to `off`), and it is written as its own row because TEST-020 alone would not catch a specification that states "read the current value" while leaving unstated what happens when a *record* disagrees with it.

### TEST-022 / TEST-023 / TEST-024 (AC-022–AC-024) — the fallback, and the constraint discovered while writing it

- **TEST-022** — the new bullet states the setting's value and its audit outcome remain in force via this fallback. Positive assertion, checking for the substance (setting value + audit outcome + "regardless of which path") rather than for any specific sentence, since REQ-008's own design intentionally avoids one word that might otherwise appear in a naive first draft.
- **TEST-023** — DS-29's own no-upload statement (`:12`, restated in Boundaries) is present, unmodified — regression, positive half, mirroring DS-29's own `TEST-021` shape.
- **TEST-024** — the negative half, and the row this feature's own edit is most likely to fail by accident: no case-insensitive "consent" substring anywhere in the file, checked over the whole file (not only the new bullet), because an edit elsewhere in the same commit could just as easily introduce the word.

### TEST-025 / TEST-026 (AC-025, AC-026) — DS-29's suite, run, not merely trusted

**TEST-025** invokes `tests/design-system-contract.tests.sh` (and `.ps1`) against the edited tree and asserts a clean exit, naming five specific rows — `TEST-010`, `TEST-015`, `TEST-018`, `TEST-026`, `TEST-040` — as the ones this feature's own edit shape (an outer branch prepended to step 3; three rows appended to the record table; no reordering, no section moves) most plausibly threatens, each through a distinct mechanism spelled out in `requirements.md` AC-025. Naming them does not mean the other forty-six rows of DS-29's suite (`TEST-001`–`TEST-051` minus the five named, plus the `DS-001`–`DS-017` literal blocks) go unchecked — the whole suite's exit code is the actual assertion; the five are named because a failure there is the one most directly attributable to this feature's specific edit, and a reviewer should not have to guess which of fifty-one rows regressed.

**TEST-026** is deliberately redundant with part of TEST-025's own scope (DS-29's `TEST-021` is one of the fifty-one rows TEST-025's exit-code check already covers) and is kept as its own row anyway, for the same reason `requirements.md` gives it its own AC (AC-026): `claude-design-workflow.md` is the one file DS-29's suite could not have anticipated a second editor for, and REQ-008 — this feature's own edit to that file — is the requirement most directly in tension with the invariant TEST-021 protects. A reviewer scanning this feature's own Test Matrix should be able to see that tension named explicitly, not only inherit it silently through TEST-025's aggregate exit code.

### TEST-027 (AC-027) — local registration, no protected file involved

Assert `tests/design-sync-standing-consent.tests.sh` and `.ps1` both appear in `tests/run-all.sh` and `tests/run-all.ps1` respectively. Unlike every "staged" row in this document, this one has no designed-red state — both files are unprotected, so there is no reason for this assertion to be anything but green once the suite is authored.

### TEST-028 (AC-028) — the guard is only real once CI runs it, and it does not yet

Assert this feature's suite is reachable from a CI entry point, tracing from `.github/workflows/` to the suite file, in both runtimes. **This row is expected to be red on the live tree at authoring time and to remain red until a human applies the staged patch** — the same designed fail-closed state as DS-29's own `TEST-039`, for the identical underlying reason: `.github/workflows/test.yml` is protected (`guard_invariants.py:4`, `:18`), and `tests/run-all.sh` is itself invoked by no workflow today (re-verified: zero matches for `run-all` across `.github/workflows/` at drafting time), so registering the suite in `run-all` (TEST-027) does not by itself make it CI-executed.

## UI Integration Checklist

**N/A — no user-facing entry point.** This feature adds no view, dialog, menu item, or context action; if anything, it removes the one user-facing surface DS-29 introduced (the consent prompt no longer appears at all under `standing` or `off`). Recorded as N/A rather than omitted, matching DS-29's own convention (`specs/design-sync-consent/acceptance-tests.md`) and this repository's convention for non-UI features generally.

## Notes

- **Test type vocabulary.** `document conformance` is the default; `regression` marks a row whose assertion is that specific pre-existing text is unmodified; `regression (negative)` marks a row asserting the specific absence of a substring; `external-suite regression` marks a row that invokes a different feature's own test suite rather than re-implementing its logic; `registration conformance` and `CI-registration conformance` follow DS-29's own vocabulary for its equivalent rows (`TEST-038`, `TEST-039`).
- **Dual-runtime parity.** Every assertion above exists in both the `.sh` and `.ps1` suites, with carve-outs documented at the point they are created, following the precedent at `tests/design-system-contract.tests.ps1:57`.
- **Case-sensitivity sweep (`AGENTS.md` "Author-time sweeps" item 1) — applicability.** This feature ports no `.sh` script to `.ps1`; both runtimes are authored directly. The sweep applies narrowly to any `-match` / `-notmatch` / `Select-String` site added here whose `.sh` counterpart compares case-sensitively, and must be performed, with a mis-cased negative fixture per layer, before the change is reported Implementation Complete.
- **Re-verify every `file:line` in this document at implementation start** (WFI-011).
- **All five Open Questions in `requirements.md` are non-blocking.** None of TEST-001 through TEST-028 is written against an unresolved value — where an OQ leaves a value domain open (OQ-2, `Egress-Consent-Party`'s exact string; OQ-1, re-read granularity), the corresponding TEST row (TEST-019, TEST-020) accepts any phrasing consistent with the decided half of the criterion, exactly as DS-29's own `TEST-009`/`AC-005` accepts either a citation or a stated limitation rather than guessing which OQ-6 would resolve to.
