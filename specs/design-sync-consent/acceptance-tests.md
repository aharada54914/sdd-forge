# Acceptance Tests: design-sync-consent

Every criterion in this feature is a **document-conformance** assertion against skill and documentation text, because the loop has no executable code path — `design-sync-loop` is a `SKILL.md`, and no mockup has ever been generated in this repository (INV-010). The tests therefore read files and assert on their content. That bounds what they can prove, and the bound is stated once here rather than implied: these tests prove the repository *says* the right thing consistently in every place it says anything. They cannot prove an agent obeys it. The one control that would prove obedience — a mechanical pre-upload gate — is #139, deliberately out of scope.

Where a criterion's own language enumerates branches or quantifies over conditions, it is expanded below into individual branches, each with its own TEST row and its own concrete assertion, per AGENTS.md `## Rules` → "Author-time sweeps that replace case-by-case vigilance", item 4.

## Test Matrix

| Test ID | AC | REQ | Test Type | Target | Assertion in one line |
|---|---|---|---|---|---|
| TEST-001 | AC-001 | REQ-001 | document conformance | `design-sync-loop/SKILL.md` | the **first** upload in a consent scope is stated to require an explicit human consent decision |
| TEST-002 | AC-001 | REQ-001 | document conformance | same | the **second and subsequent** uploads in the same scope are stated to proceed without re-prompting |
| TEST-003 | AC-001 | REQ-001 | document conformance | same | a **different** scope is stated not to inherit the consent |
| TEST-004 | AC-002 | REQ-001 | document conformance | same | the scope names exactly one unit; no disjunction ("feature or session") remains |
| TEST-005 | AC-003 | REQ-002 | document conformance | same | disclosure element (a): payload is specification-derived and may carry confidential material |
| TEST-006 | AC-003 | REQ-002 | document conformance | same | disclosure element (b): destination is claude.ai/design, external, and the project selected in the pull step |
| TEST-007 | AC-003 | REQ-002 | document conformance | same | disclosure element (c): content sent there may be retained |
| TEST-008 | AC-004 | REQ-002 | document conformance | same | disclosure states the scope **and** that later uploads inside it will not prompt again |
| TEST-009 | AC-005 | REQ-002 | document conformance | same | `finalize_plan`'s payload is either described from a cited source or its opacity is stated as a limitation |
| TEST-010 | AC-006 | REQ-003 | document conformance (ordered structure) | same | the loop's ordered steps are generate → consent → push → claude.ai review → regenerate |
| TEST-011 | AC-007 | REQ-003 | document conformance | same | local review is marked optional |
| TEST-012 | AC-007 | REQ-003 | document conformance | same | local review is explicitly stated **not** to be a precondition for push |
| TEST-013 | AC-008 | REQ-003 | document conformance | same | the demotion's consequence — content may egress without prior local human review — is stated where the demotion is described |
| TEST-014 | AC-009 | REQ-003 | document conformance (ordered structure) | same | the regeneration cycle re-enters generation, not consent |
| TEST-015 | AC-010 | REQ-004 | document conformance | same | the `Design-Source` consent record's fields are enumerated by name |
| TEST-016 | AC-011 | REQ-004 | document conformance | same | full-profile record destination is `specs/<feature>/ux-spec.md` |
| TEST-017 | AC-011 | REQ-004 | document conformance | staged `lite-spec/SKILL.md` candidate | lite-profile record destination is `specs/<feature>/design.md` |
| TEST-018 | AC-012 | REQ-004 | document conformance | `design-sync-loop/SKILL.md` | the record is characterised as an agent-written audit trace, not a gate-enforced authorization |
| TEST-019 | AC-013 | REQ-005 | document conformance | same | capability-detection branch 1 — tool unavailable → fallback, marker recorded |
| TEST-020 | AC-013 | REQ-005 | document conformance | same | capability-detection branch 2 — authentication failure → fallback, marker recorded |
| TEST-021 | AC-014 | REQ-005 | document conformance | `claude-design-workflow.md` | the fallback still states it performs no upload, and gained no consent step |
| TEST-022 | AC-015 | REQ-005 | document conformance | `design-sync-loop/SKILL.md` | non-blocking condition 1 — absence of **mockups** never blocks specification review |
| TEST-023 | AC-015 | REQ-005 | document conformance | same | non-blocking condition 2 — absence of **design tools** never blocks specification review |
| TEST-024 | AC-016 | REQ-005 | document conformance | `sdd-bootstrap-interviewer/SKILL.md` | `ds_profile: none` still yields no artifacts and no further design-system questions; no consent question leaks in |
| TEST-025 | AC-017 | REQ-006 | document conformance | `design-sync-loop/SKILL.md` | a single pre-upload check point over `specs/<feature>/mockups/` is named, distinct from the consent step |
| TEST-026 | AC-017 | REQ-006 | document conformance (structural) | same | **no upload path in the loop bypasses that point** |
| TEST-027 | AC-018 | REQ-006 | document conformance | same | that point's blocking behaviour carries no interactive-human precondition |
| TEST-028 | AC-019 | REQ-006 | document conformance | same | consent-resolution outcome 1 — "must be requested" |
| TEST-029 | AC-019 | REQ-006 | document conformance | same | consent-resolution outcome 2 — "already holds for this scope" |
| TEST-030 | AC-019 | REQ-006 | document conformance | same | consent-resolution outcome 3 — "not permitted" → manual fallback, no upload |
| TEST-031 | AC-020 | REQ-006 | document conformance | same | the `Design-Source` shape is stated as additively extensible |
| TEST-032 | AC-020 | REQ-006 | document conformance | same | this feature's behaviour is identified as the one a later `per-feature` setting selects |
| TEST-033 | AC-021 | REQ-007 | document conformance | `design-sync-loop/SKILL.md` frontmatter `description:` | site 1 states the per-feature model |
| TEST-034 | AC-021 | REQ-007 | document conformance | `design-sync-loop/SKILL.md` Boundaries | site 2 states the per-feature model |
| TEST-035 | AC-021 | REQ-007 | document conformance | `sdd-bootstrap-interviewer/SKILL.md` | site 3 states the per-feature model |
| TEST-036 | AC-021 | REQ-007 | document conformance | `docs/workflow-guide.md` | site 4 (Japanese) states the per-feature model |
| TEST-037 | AC-022 | REQ-007 | regression (negative) | `CHANGELOG.md` | the historical release note is byte-identical to its pre-change content |
| TEST-038 | AC-023 | REQ-007 | staging conformance | `lite-spec/SKILL.md` + `human-copy/MANIFEST.sha256` | the change is staged, the live protected file is unmodified at staging time, and the manifest hash matches the drafted candidate |
| TEST-039 | AC-024 | REQ-008 | CI-registration conformance | CI entry point → suite | this feature's assertions are reachable from a CI entry point in both runtimes where a `.ps1` twin exists |
| TEST-040 | AC-025 | REQ-008 | regression | `tests/design-system-contract.tests.{sh,ps1}` | the seven pre-existing `DS-006` literals still pass unmodified |

## Test Details

### TEST-001 / TEST-002 / TEST-003 (AC-001) — the three branches of "one consent per feature"

The criterion's own language implies three branches. Each is asserted separately because each fails differently.

- **TEST-001 (first upload).** Assert the loop states an explicit human consent decision gates the first upload within a scope. Not satisfied by the word "consent" appearing — the assertion must find the gating relationship (consent precedes the first upload), not the vocabulary.
- **TEST-002 (iteration).** Assert the text states that subsequent uploads in the same scope proceed without a further prompt. This is the criterion the whole issue exists for, and it is the one that a conservative edit — adding consent language while leaving "every time" intact — would silently fail.
- **TEST-003 (a different scope).** Assert the text states that a different scope is gated again. Included because an unstated inheritance rule is not neutral: in practice it defaults to whatever the agent decides at runtime, which is the opposite of a control.

### TEST-004 (AC-002) — the scope is decided, not deferred

Assert the scope statement names exactly one unit and contains no disjunction between units. The issue writes "per-feature/セッション 1 回"; shipping that phrasing verbatim would move the ambiguity from the issue into the artifact, where every later reader inherits it.

**This test checks decidedness, not correctness.** Which unit is right is OQ-1, a human decision. This test fails a text that declines to choose, and passes either choice.

### TEST-005 / TEST-006 / TEST-007 (AC-003) — the disclosure, element by element

Three separate assertions, because a disclosure can be partially right in three distinct ways and a combined check would pass on any one of them.

- **TEST-005** — the payload is described as derived from the feature's requirements, acceptance criteria and design tokens, and as capable of carrying confidential material. Grounded in `SKILL.md:76-80`, which makes the payload a pure function of those inputs.
- **TEST-006** — the destination is named: claude.ai/design, external, and the specific project selected at `SKILL.md:68-69`. A disclosure that says "an external service" without naming it tells the operator nothing they can check.
- **TEST-007** — retention is stated as possible and outside this repository's control. Note the phrasing bound: the assertion must accept an honest "may be retained; this repository does not control retention" and must **not** require a specific retention claim, because no artifact in this repository establishes one.

### TEST-008 (AC-004) — the operator is told this is the last time they will be asked

Assert the disclosure states both the scope and the consequence: further uploads inside that scope proceed without a prompt. The single most likely defect in an informed-consent prompt written from this issue is one that describes the *risk* accurately and never mentions the *frequency change*, which is the only thing the operator is actually being asked to accept.

### TEST-009 (AC-005) — the disclosure does not overclaim

Assert that either `finalize_plan`'s outbound payload is described with a citation resolved at implementation time, or its opacity is recorded as a stated limitation. The failing shape is a confident enumeration of "what leaves" that silently omits one of the two outbound calls (`SKILL.md:85` calls `finalize_plan` then `write_files`; only the latter's payload is inferable from this repository — OQ-6).

An unverifiable claim in a consent prompt is worse than an acknowledged gap, which is why this test accepts the gap and rejects the overclaim.

### TEST-010 / TEST-014 (AC-006, AC-009) — order is a structural property, so assert it structurally

`SKILL.md`'s Loop is a numbered list. Assert the **relative order** of the steps — consent before the first push, claude.ai review after it, regeneration returning to generation — by parsing the ordered list and comparing positions, not by asserting that each step's text exists somewhere in the file.

A presence-only check passes against a file that contains all the right steps in the old order, which is precisely the change under test. TEST-014 exists separately because the cycle edge is the one that couples REQ-003 to AC-001 branch 2: a loop that returned to the consent step would contradict TEST-002 while satisfying TEST-010.

### TEST-011 / TEST-012 (AC-007) — optionality has two independent halves

- **TEST-011** — the step carries an optionality marker.
- **TEST-012** — the text explicitly states local review is not a precondition for push.

Both are required because either alone is satisfiable by a text that fails the criterion: a step labelled "optional" but still positioned as the gate before push, or a step moved out of the path while still described as required. Today's file supplies neither (`SKILL.md:81-82` is an unqualified step 3 preceding step 4).

### TEST-013 (AC-008) — the removed control is named as removed

Assert the skill states, at the point where local review is demoted, that content may consequently be uploaded without prior local human review.

This is the test that keeps the change auditable from the artifact alone. Without it, a reader six months from now sees a loop with optional local review and cannot tell whether the control was considered and dropped, or never existed. That distinction is the whole content of `docs/THREAT-MODEL.md`'s "a threat model that omits a live surface invites the reader to conclude it was assessed" failure mode, applied to a skill file.

### TEST-015 / TEST-016 / TEST-017 / TEST-018 (AC-010 – AC-012) — the record, and what it is not

- **TEST-015** — the `Design-Source` consent record's fields are enumerated by name. **Deliberately not a section-heading check**: `Design-Source` already exists as a heading name in the current skill (`SKILL.md:28`, `:72`), so a heading assertion would pass today, before this feature does anything. That is a vacuous test, and the same defect class as asserting a section exists rather than that it has content.
- **TEST-016 / TEST-017** — the two profile destinations, per `SKILL.md:18-20`. Split because TEST-017's target is the **protected** `lite-spec/SKILL.md`, so it is asserted against the *staged candidate*, not the live file, until the human-copy application lands (BL-004, TEST-038). Until then TEST-017 is red against the live tree by design, exactly as `epic-136-phase3`'s TEST-019/020 were.
- **TEST-018** — the record is characterised as an agent-written audit trace, not an authorization anything enforces. This is a security assertion in a documentation test: `docs/THREAT-MODEL.md:12` places agent self-reports under NOT Trusted, and nothing guards this line (INV-011, INV-021). A text that presents it as the authorization would be asserting a control the repository does not have.

### TEST-019 / TEST-020 (AC-013) — the fallback's two entry conditions

`SKILL.md:26` states the condition as a disjunction: "If the tool is unavailable **or** authentication fails". Two branches, two rows. A change can preserve one and break the other — most plausibly by making consent resolution happen before capability detection, which would leave the auth-failure path prompting for consent to an upload that can never occur.

### TEST-021 (AC-014) — the fallback is asserted positively

Assert that `claude-design-workflow.md` still states it performs no upload (`:12`, `:70-71`) **and** that it contains no consent step. Positive plus negative: an absence-only check would pass against a fallback that grew an upload step but no consent step, which is strictly worse than the state this feature started from.

### TEST-022 / TEST-023 (AC-015) — the non-blocking invariant's two conditions

`SKILL.md:94-95` names both: "absence of mockups **or** design tools never blocks specification review". Two rows, because the flow inversion touches the mockup-absence path (mockups now exist before consent) without touching the tool-absence path, so they can regress independently.

### TEST-024 (AC-016) — the consent question must not leak into `ds_profile: none`

Assert `sdd-bootstrap-interviewer/SKILL.md:86-87`'s guarantee survives: on `none`, no artifacts and no further design-system questions. The reconciliation at site 3 (TEST-035) edits text two lines above this guarantee, which is exactly the adjacency that produces this class of regression.

### TEST-025 / TEST-026 / TEST-027 (AC-017, AC-018) — the choke point #139 will attach to

- **TEST-025** — a single pre-upload point over `specs/<feature>/mockups/` is named, distinct from the consent step. Distinctness matters: if the check is folded into the consent step, then under #140's `standing` mode (consent skipped) the check disappears with it.
- **TEST-026** — **no upload path bypasses it.** The substantive row. Verified structurally by enumerating every path in the loop that reaches an upload call and asserting each passes the named point first. A named point that one branch routes around is decoration.
- **TEST-027** — the point's blocking behaviour is stated as a property of the check, not as "the human is shown the hit and decides". This is the OQ-9 hedge: #140's `standing` removes the human from this spot, and a specification that presumes one there quietly forecloses `standing` + #139 in combination.

None of these tests asserts anything about *scanning*. #139 writes the scan; this feature only guarantees there is a well-defined place to put it.

### TEST-028 / TEST-029 / TEST-030 (AC-019) — the three-valued outcome, one row each

The outcome space is `{must be requested, already holds for this scope, not permitted}`. Each gets its own row because the third is the one an implementation naturally omits — a straightforward reading of #138 alone needs only the first two, and #140's `off` is what needs the third.

**TEST-030 additionally asserts the routing**: "not permitted" leads to the manual fallback with no upload attempted. An outcome that is merely *named* but has no stated consequence would satisfy a weaker check while leaving `off` unimplementable.

### TEST-031 / TEST-032 (AC-020) — forward compatibility, stated in the artifact

- **TEST-031** — the record shape is stated as extensible: adding fields does not invalidate a record written by this feature. #140 adds consenting party, timestamp and setting value to the same section.
- **TEST-032** — this feature's behaviour is identified as the value a later `per-feature` setting selects, matching #140's "既定は per-feature(DS-29)". This is cheap to write now and expensive to retrofit, because #140 would otherwise have to reinterpret text written without it in mind.

Neither test introduces `ds_upload_consent` — that is #140's, and a test asserting the setting exists would fail by design here.

### TEST-033 / TEST-034 / TEST-035 / TEST-036 (AC-021) — one row per site, and why a global check will not do

Four sites, four rows: `design-sync-loop/SKILL.md:3` (frontmatter `description:`), `design-sync-loop/SKILL.md:97-98` (Boundaries), `sdd-bootstrap-interviewer/SKILL.md:84`, `docs/workflow-guide.md:224`.

**A single repository-wide "the old phrase no longer occurs" assertion is explicitly rejected**, for two independent reasons:

1. Site 4 is Japanese (`都度人間承認`) and shares no substring with the three English sites, so an English-substring sweep passes while site 4 stays stale — the exact failure the sweep was supposed to prevent.
2. A global absence sweep would also match `CHANGELOG.md:1301`, which AC-022 requires be left alone, turning a correct repository into a failing one.

**Authoring constraint on these four tests (AGENTS.md "Author-time sweeps", item 2).** Each asserts that a file no longer contains a per-upload phrase. The test source must **not** embed that phrase as a contiguous literal in its own body, comments or failure messages; it must assemble the marker at runtime from non-contiguous parts. Otherwise the suite becomes a false-positive target of any vocabulary scan this repository runs over `tests/` — a detection suite that is its own false positive. This applies to the `.ps1` twin identically.

### TEST-037 (AC-022) — the historical record is not rewritten

Assert `CHANGELOG.md`'s per-upload release note is byte-identical to its pre-change content. A negative test, and a necessary one: REQ-007's instruction is "reconcile every statement of the old model", and a diligent implementer following that instruction literally rewrites history. The changelog documents what a released version *did*, and that fact did not change.

### TEST-038 (AC-023) — the protected file is staged, never written

`plugins/sdd-lite/skills/lite-spec/SKILL.md` is a protected enforcement-chain file (BL-004). Assert all three:

1. the agent-authored candidate exists at a **non-protected** draft path — following `epic-136-phase3`'s shape, `specs/design-sync-consent/verification/T-NNN/staged-lite-spec-candidate.draft.md`;
2. `specs/design-sync-consent/human-copy/MANIFEST.sha256` records that candidate's SHA-256 under its destination name;
3. the **live** `plugins/sdd-lite/skills/lite-spec/SKILL.md` is unmodified at staging time.

The staging destination `specs/design-sync-consent/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md` **cannot be created by the agent**: the guard's protected-suffix match is a case-insensitive `endswith()` on the normalized path (`sdd-hook-guard.py:1001-1015`) with no `human-copy/` carve-out. Only `MANIFEST.sha256` is agent-writable under that directory, and finding only that one file there is the designed state, not a missing artifact — the same state `find specs/epic-136-phase3/human-copy -type f` returns today.

Until the human applies the candidate, TEST-017 is red against the live tree. That red is the designed fail-closed behaviour, not a defect.

### TEST-039 (AC-024) — the guard is only real if CI runs it

Assert this feature's assertions are reachable from a CI entry point, by tracing from `.github/workflows/` to the suite, in both runtimes where a `.ps1` twin exists.

**This test cannot be written until OQ-8 is answered**, and that is the point of listing it. The suite that already asserts against `design-sync-loop/SKILL.md` — `tests/design-system-contract.tests.{sh,ps1}`, block `DS-006` — is registered in `tests/run-all.sh` (no), `tests/run-all.ps1` (no), and any workflow (no); and `tests/run-all.sh` is itself not invoked by CI (INV-016, INV-017). So the natural home for these assertions is currently unexecuted, and the natural fix touches a protected file.

**Newly-reachable branch declaration (AGENTS.md "Author-time sweeps", item 5).** If OQ-8 resolves toward registering `design-system-contract.tests.{sh,ps1}` in CI, then the entire `DS-001`…`DS-017` assertion block — which has **never executed on a CI runner** — becomes reachable for the first time, on every OS leg of the matrix. The implementation report must name that block and that environment explicitly, and must either exercise it in a matching environment before merge or flag it as "pending first real execution at CI time", so a resulting failure is traceable to this class rather than read as an unrelated surprise.

**Re-verification instruction (item 3).** The CI registration surface is shared, git-tracked state this branch does not own. Re-derive the three "no" answers above from `.github/workflows/` and `tests/run-all.{sh,ps1}` at implementation start rather than trusting this paragraph.

### TEST-040 (AC-025) — the existing lock still holds

Assert the seven `DS-006` literals still pass after the `SKILL.md` restructuring: `^## Ensure design-system/$`, `ui-ux-pro-max`, `design-system --persist`, `ui-ux-pro-max unavailable — D6 template interview used`, `figma-dtcg-import`, `design-system/design-tokens\.json`, `MASTER\.md` (`tests/design-system-contract.tests.sh:62-68`). The `.ps1` twin asserts the same set minus the em-dash line, by an existing deliberate ASCII-only exclusion (`tests/design-system-contract.tests.ps1:57-62`).

The pre-existing assertions must pass **unmodified**. Needing to edit one is evidence BL-007 was broken and must be reported, not accommodated.

## UI Integration Checklist

**N/A — no user-facing entry point.** This feature adds no view, dialog, menu item or context action. Its only human-perceivable surface is a consent prompt emitted by an agent inside an existing skill flow, which has no shell location to be reachable from. Recorded as N/A rather than removed, so the omission is visibly a judgement rather than an oversight (`sdd-bootstrap-interviewer/SKILL.md:54-58` requires the question be asked; the answer is that there is no entry point).

## Notes

- **Test type vocabulary.** Every row is `document conformance` except TEST-037 (`regression (negative)`), TEST-038 (`staging conformance`), TEST-039 (`CI-registration conformance`) and TEST-040 (`regression`). The repository's own convention is that the tier describes what the case *drives*, not how many files it touches; `epic-136-phase4-mcp`'s gate recorded a Minor for mislabelling on exactly this axis, so the tiers are stated deliberately.
- **Dual-runtime parity (BL-008).** Every assertion above exists in both the `.sh` and `.ps1` suites, with one carve-out: an assertion whose literal cannot be expressed in an ASCII-only `.ps1` source must state the reason where the asymmetry is created, following the precedent comment at `tests/design-system-contract.tests.ps1:57`. Silently asserting a subset is the failure mode; a documented subset is acceptable.
- **Case-sensitivity sweep (AGENTS.md "Author-time sweeps", item 1) — applicability.** This feature ports no `.sh` script to `.ps1`; it adds parallel assertions to an existing `.ps1` suite. The operator-level and cmdlet-level sweeps therefore apply narrowly — to any `-match` / `-notmatch` / `Select-String` site added here whose `.sh` counterpart compares case-sensitively — and must still be performed before the change is reported Implementation Complete, with a mis-cased negative fixture per layer. The sweep becomes fully load-bearing for **#139**, which ports a real scanner.
- **Re-verify every `file:line` in this document at implementation start.** Citations accurate when written and stale when used are a recorded, recurring defect class here (WFI-011). One instance was already found in issue #138 itself (INV-002).
- **Four Open Questions block implementation** — OQ-1, OQ-2, OQ-3, OQ-8. TEST-004 is satisfiable only after OQ-1 is answered; TEST-039 is not writable until OQ-8 is. That is not a defect in these tests; it is the specification declining to guess on the human's behalf.
