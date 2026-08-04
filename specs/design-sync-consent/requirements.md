# Requirements: design-sync-consent

Spec-Review-Status: Pending

Source issue: [#138](https://github.com/aharada54914/sdd-forge/issues/138) (`enhancement`, `security`, `workflow-improvement`; key `DS-29`, epic #136). Dependants not specified here: [#139](https://github.com/aharada54914/sdd-forge/issues/139) (`DS-30`) and [#140](https://github.com/aharada54914/sdd-forge/issues/140) (`DS-31`), both declaring "Depends on: DS-29".

## Overview

`design-sync-loop` uploads generated HTML mockups from the operator's machine to a claude.ai/design project. That upload is an **egress of repository-derived content to an external service**, and the repository gates it today by requiring explicit human approval on **every** upload (`design-sync-loop/SKILL.md:83-87`, restated as a hard boundary at `:97-98`). This issue keeps the gate but changes its unit to **one informed consent per feature**, inverts the loop so review happens on claude.ai after the push, and demotes local human review from a positional precondition (`:81-82`) to optional.

Three things about that change need saying plainly, because the issue's framing understates two of them.

**The consent-frequency change is the smaller half.** claude.ai-side review is *already* the terminal review in the current loop (`:83-87`), so "順序反転" does not introduce external review — it removes the local review that currently sits in front of the push. Under today's flow, no byte can reach claude.ai without a human having first looked at the generated mockups (INV-003). After this change, the first upload of a feature can carry content **no human has read**, and every subsequent upload can too. That is the substantive privacy delta, and it is why #139 exists as a compensating control.

**The unit change moves consent from a payload to a category.** Per-upload consent is consent to *these bytes*. Per-feature consent is consent to *a class of future bytes whose content is not yet determined* — the loop's own shape guarantees regeneration between uploads (`:87`). An informed consent to an undetermined payload can only be informed about the category, which is exactly why the issue requires the disclosure to state what kind of thing leaves and where it goes.

**The durable record becomes load-bearing, and it is the weakest artifact in the chain.** `Design-Source` is free-form prose with no schema, no template, and no gate (INV-011), written by an agent — and `docs/THREAT-MODEL.md:12` lists agent self-reports under **NOT Trusted**. Under per-upload consent this mattered little, because each upload had its own live human. After this change, whatever `Design-Source` says becomes the standing carrier of an authorization covering every later upload in scope. The specification must therefore either define what makes that record trustworthy, or state plainly that it is an audit trace and not an enforcement point. It must not leave a reader to assume the former.

Consumer-visible consequence, stated once: after this feature the operator answers **one** egress question per feature instead of one per upload, and in exchange gives up per-payload review, per-payload refusal, and the guarantee that a human saw the content before it left. The controls that buy some of that back are `DS-30` and `DS-31`, which are separate issues.

## Requirements

### REQ-001 — the egress consent unit is one per feature, not one per upload

`design-sync-loop` must obtain the human's egress consent **once** within a defined scope and must not re-prompt for further uploads inside that scope. Outside the scope, consent must not be assumed.

The scope unit **is decided**: the consent scope is the **conjunction of feature and session** — a consent applies only where *both* the feature and the session match the ones it was granted under (OQ-1, resolved by the human 2026-08-04). The issue writes "per-feature/セッション 1 回", naming two units that are not the same thing; the narrower conjunction is chosen. The recorded rationale: the issue's actual pain is being asked on every upload *within one working session*, which session scoping solves; feature-only scoping would let a consent outlive the context it was given in, by days and across operators.

The conjunction is **one** scope, not two alternatives. AC-002's prohibition is on a *disjunction* ("per feature or session"), which leaves the unit to the agent's judgement; naming both coordinates of a single scope does not. A skill that says "per feature or session" still fails AC-002.

"Session" here carries the meaning already established for this feature: an **agent session**, in the sense used at `investigation.md:295`, which contrasts it with a `specs/<feature>/` directory and notes the two are orthogonal — one session can specify two features, and one feature routinely spans many sessions and days. This document does not further operationalise where a session boundary falls; it does not need to, because every criterion here is a document-conformance assertion over skill prose (see `acceptance-tests.md` opening) and the skill's obligation is to name the scope, not to detect its edges.

Four consequences follow, stated here rather than left to inference:

- **Expiry** (OQ-2, resolved 2026-08-04). Expiry follows from the scope: a consent dies when its session ends. No separate wall-clock expiry is defined — the session boundary *is* the expiry. Checked by AC-001 branch 3, since a later session is a different scope.
- **Withdrawal** (OQ-2, resolved 2026-08-04). Withdrawal must additionally be possible **mid-session**, so that one answer does not bind the operator for the remainder of a session. Checked by AC-028.
- **Destination** (OQ-3, resolved 2026-08-04). Consent attaches to the feature and **the destination**, not to a specific byte sequence. The loop regenerates mockups between uploads (`SKILL.md:87`), so byte-scoped consent is stale by construction, and re-consenting on every change collapses back to the per-upload behaviour this feature exists to remove. The destination half is load-bearing and is checked by AC-027; the price of not re-consenting on content change is paid in the disclosure (REQ-002, AC-029).
- **A decline is transient** (decided 2026-08-04, closing a round-1 AMBIGUITY finding). Answering "no" to the first-upload consent prompt blocks *that* upload and nothing more; the next attempt asks again. It is **not** the persistent forbiddance that #140's `off` setting provides. Conflating a one-time "no" with a configuration-level change would be surprising, and REQ-006/AC-019's three-outcome model already has a distinct slot for the persistent case. Checked by AC-026.

#### AC-001

The loop's consent behaviour is stated for all three branches its own scoping language implies, each stated explicitly rather than left to inference:

1. the **first** upload within a consent scope is gated on an explicit human consent decision;
2. the **second and every subsequent** upload within the same scope proceeds with no further consent prompt;
3. a **different** scope does not inherit the consent and is gated again.

Each branch has its own TEST row. Branch 3 is included because it is the one an implementation is most likely to leave unstated, and an unstated inheritance rule defaults, in practice, to "whatever the agent decides".

#### AC-002

The consent scope is named by exactly one unit. The text does not offer alternatives ("per feature or session") and does not leave the unit to the agent's judgement. Verified by asserting that the scope statement names one unit and that no disjunction appears in it.

This criterion is deliberately a check on *decidedness*, not on which unit was chosen. OQ-1 was answered by the human on 2026-08-04 (feature ∧ session); this criterion still asserts only that the shipped text names one scope and contains no disjunction, so it neither encodes that choice nor re-opens it. The conjunction satisfies it: the assertion is on the absence of "or" between candidate units, not on the scope having a single coordinate.

#### AC-026

A declined consent is **transient**, and the skill says so. Three TEST rows, because the three statements fail independently and a combined check would pass on any one:

1. a decline blocks **that** upload — no upload occurs;
2. the **next** upload attempt within the same scope prompts again;
3. the decline is explicitly distinguished from the persistent "not permitted" outcome of AC-019 — declining once writes no standing forbiddance and is not #140's `off`.

Row 3 is the substantive one. Without it, an implementation that persists a decline for the rest of the scope satisfies rows 1 and 2 while silently manufacturing the configuration-level control that #140 owns.

#### AC-027

A consent is bound to the **destination** claude.ai/design project selected in the pull step (`SKILL.md:68-69`), and a consent granted for one destination does not apply to another. Two TEST rows:

1. the consent statement names the destination project as part of what the consent covers;
2. a **different** destination project does not inherit the consent and is gated again.

Both are required because either alone is satisfiable by a text that fails the criterion: a record that stores a destination but never says a change re-gates, or a re-gating claim with nothing that binds a consent to a destination in the first place. This is the criterion that gives Edge Case 2 coverage; before OQ-3 was answered that edge case mapped to no OQ, REQ, AC or TEST in this specification.

#### AC-028

A consent can be **withdrawn mid-session**, and the skill states both the path and its effect. Two TEST rows:

1. a withdrawal path is stated — the operator can revoke a consent inside its scope without waiting for the session to end;
2. after withdrawal, the next upload within that same scope is gated again.

Split because "withdrawal is mentioned" is satisfiable by text that names the affordance and never says what it does, which is the vacuous-assertion failure mode this document rejects elsewhere (TEST-015).

### REQ-002 — the consent is informed, and its disclosure is accurate about what it cannot enumerate

The first-time consent prompt must state, in terms an operator can act on:

- **what leaves** — the mockup HTML, and that its content is derived from the feature's requirements, acceptance criteria and design tokens, so it can carry pre-release product decisions, interface copy and brand identity;
- **where it goes** — claude.ai/design, an external service, into the project selected at `SKILL.md:68-69`;
- **what happens to it there** — that content sent to an external service may be retained there, and that the repository does not control its retention;
- **what the consent covers** — the scope from REQ-001, and explicitly that later uploads inside that scope will proceed without asking again;
- **that the coverage survives regeneration** — that the consent covers this feature's mockups **including future regenerations of them**, to the named destination, for this session (OQ-3, resolved 2026-08-04). This is the honest price of not re-consenting on content change: a disclosure that omitted it would let an operator believe only what they saw gets sent;
- **that the pull direction also transmits** — that `list_projects` / `create_project` (`SKILL.md:68-72`) send a human-supplied project name to the same external service (OQ-4, resolved 2026-08-04). Gating the pull direction is out of scope for this feature and stays a Non-goal; saying nothing about it would make the disclosure misleading by omission;
- **what the operator is asserting** — that by consenting, the operator asserts they have the authority to send this content externally (OQ-5, resolved 2026-08-04). This is **not** enforced technically and no such check is possible here; the disclosure converts an invisible assumption into an explicit claim. Organisation-level enforcement belongs to #140's setting.

The disclosure must not overstate its own completeness. `finalize_plan` is called immediately before `write_files` (`SKILL.md:85`) and its payload is not knowable from this repository (OQ-6); a disclosure that enumerates outbound content as if the list were exhaustive would be a false statement in a consent prompt, which is worse than an honest partial one.

#### AC-003

The consent disclosure states all three of the following, each verified separately: (a) the payload is specification-derived and may contain confidential material; (b) the destination is claude.ai/design, an external service, and the specific project selected in the pull step; (c) content sent there may be retained.

Three TEST rows, one per element. A single "the disclosure mentions confidentiality" assertion would pass against a prompt that names the risk but not the destination, which is the text-marker failure mode recorded as FP-02 in the `epic-136-phase3` retrospective.

#### AC-004

The disclosure states the consent's scope and, explicitly, that subsequent uploads within that scope will not prompt again. A consent that does not tell the operator it is the last one they will be asked is not informed about the thing that actually changed.

#### AC-005

Where the outbound payload is not fully enumerable from this repository, the text says so rather than implying a complete list. Verified by asserting that either `finalize_plan`'s payload is described from a source cited at implementation time, or its opacity is stated as a limitation.

#### AC-029

The disclosure states the three elements added by the 2026-08-04 decisions, each verified separately in the manner of AC-003: (d) the consent covers this feature's mockups **including future regenerations**, to the named destination, for this session; (e) the pull direction also transmits a human-supplied project name to the same external service; (f) the operator is asserting they have the authority to send this content externally.

Three TEST rows, not one. Each element answers a different question the operator would otherwise answer wrongly on their own — (d) *how long does what I just agreed to keep applying?*, (e) *is this the only thing that leaves?*, (f) *am I the one who gets to decide this?* — and a combined "the disclosure mentions these topics" assertion passes on any one of the three, which is the FP-02 text-marker failure mode AC-003 already guards against.

### REQ-003 — the flow order inverts, and the demotion of local review is stated as a demotion

The loop's ordered steps become: generate mockups → (first time in scope) obtain egress consent → push → review in the claude.ai/design browser UI → regenerate. Local review moves out of the mandatory path.

"Optional" must be written as a property of the step, not implied by moving it. And the demotion's consequence must be recorded in the skill itself: a reader of the loop must be able to see that the first payload may egress without a human having read it. A change that removes a control silently is indistinguishable, to the next reader, from one that never had it.

#### AC-006

The loop's step sequence is the inverted one above, and the step ordering places consent before the first push and claude.ai review after it.

#### AC-007

Local review is marked optional **and** is explicitly stated not to be a precondition for push. Two TEST rows: the optionality marker alone would be satisfied by a step still positioned as a gate, and a positional change alone would be satisfied by a step still described as required.

#### AC-008

The skill states the consequence of the demotion — that content may be uploaded without prior local human review — at the point where the demotion is described. This is the honest-documentation criterion; it is what makes the change auditable by someone reading only the skill.

#### AC-009

The regeneration cycle returns to the generation step without re-entering the consent step, consistent with AC-001 branch 2. Stated so the two requirements cannot be satisfied by texts that contradict each other.

### REQ-004 — the consent fact and the upload subject are recorded in `Design-Source`, in a stated shape

The issue requires that "同意事実と送信対象" be recorded in the layer file's existing `Design-Source` section. `Design-Source` has no schema, no template and no gate (INV-011), so "recorded in Design-Source" is not verifiable until this feature states what the record contains.

This requirement therefore mandates a **named, minimal, additively-extensible** record shape. It does **not** decide the granularity of "送信対象" — file list, content hashes, or prose description each have different staleness properties under regeneration (OQ-7), and that is a product decision.

#### AC-010

The skill defines the `Design-Source` consent record by naming its fields, so a reader can tell a conforming record from a non-conforming one. Verified by asserting the field names are enumerated in the skill, not by asserting the section heading exists — a heading assertion passes against an empty section.

#### AC-011

The record's destination is stated for both profiles: `specs/<feature>/ux-spec.md` for the full profile and `specs/<feature>/design.md` for the lite profile, per `SKILL.md:18-20`. Two TEST rows, because the lite path runs through a **protected** file (BL-004) and is the branch most likely to be dropped.

#### AC-012

The record is explicitly characterised as an **agent-written audit trace**, not as an authorization that any gate enforces. `docs/THREAT-MODEL.md:12` places agent self-reports under NOT Trusted, and unlike `tasks.md`'s `Approval: Approved` (guarded by a hook-guard counter, `docs/THREAT-MODEL.md:53`) nothing checks this line. A specification that lets a reader believe the record is enforced would be asserting a control that does not exist.

### REQ-005 — the manual fallback and the non-blocking invariant survive unchanged

Neither the DesignSync-absent path nor the "absence never blocks" invariant may be weakened. Both are checkable rather than aspirational because the fallback performs no upload at all: `claude-design-workflow.md:12` — "It does not automatically inspect, upload, or retain images" — and `:70-71`. **A path that egresses nothing needs no egress consent**, which is what makes "the fallback is unaffected" a statement with content.

#### AC-013

The capability-detection behaviour at `SKILL.md:22-30` is preserved for both of its branches — tool unavailable, and authentication failure — each reaching the manual fallback and recording `design tools unavailable — manual workflow used`. Two TEST rows, one per branch, because `:26` states them as a disjunction and a change could preserve one while breaking the other.

#### AC-014

The fallback path introduces no consent step and no upload. Verified positively (the fallback text still states it uploads nothing) rather than only by absence, so a fallback that silently grew an upload step would fail.

#### AC-015

The non-blocking invariant holds for both of its stated conditions (`SKILL.md:29-30`, `:94-95`): absence of mockups, and absence of design tools. Two TEST rows.

#### AC-016

`ds_profile: none` performs no egress and asks no consent question, per `sdd-bootstrap-interviewer/SKILL.md:86-87` ("skip design-system integration entirely — no artifacts and no further design-system questions"). Stated because the new consent prompt is the most plausible thing to leak into the `none` path.

### REQ-006 — the model must leave DS-30 and DS-31 implementable

Neither #139 nor #140 is specified here. This requirement exists because both declare a dependency on this issue and both would be blocked by structural choices this feature could make casually.

For **#139** (pre-upload secret/PII/placeholder scan): the flow must expose exactly **one** named point between "mockups exist on disk" and "the first byte reaches claude.ai" at which a blocking check can be inserted, and that point must not be specified in a way that presumes an interactive human is standing at it — because #140's `standing` mode removes the human from precisely that spot (OQ-9).

For **#140** (`ds_upload_consent: standing | per-feature | off`): the consent decision must be resolved at **one** named step whose outcome space already admits **denied**, not merely {ask, granted} — `off` means "upload is forbidden, use the fallback", which a two-valued model cannot express without re-cutting the flow. And the `Design-Source` record must accept additional fields (consenting party, timestamp, setting value) without a conforming record from this feature becoming non-conforming.

#### AC-017

The skill names a single pre-upload point, distinct from the consent step, at which a blocking check operates on `specs/<feature>/mockups/` before any upload call. Two TEST rows: the point is named, **and** no upload path in the loop bypasses it. The second row is the substantive one — a named point that one branch of the flow can route around is not a choke point.

#### AC-018

That point is specified without requiring an interactive human at it — its blocking behaviour is stated as a property of the check, not as "the human is shown the hit and decides". One TEST row. This is the hedge against OQ-9: #140's `standing` mode removes the human from exactly this spot, so a specification that assumes one there would foreclose it.

#### AC-019

Consent resolution is a single named step whose outcome is one of exactly three: consent must be requested; consent already holds for this scope; upload is not permitted. The third outcome routes to the manual fallback with no upload. Three TEST rows, one per outcome, because an implementation that ships only the first two satisfies every other criterion in this document.

#### AC-020

The `Design-Source` record shape from REQ-004 is stated as extensible: additional fields may be added without invalidating a record written by this feature, and this feature's behaviour is identified as the one a later `per-feature` setting selects. Two TEST rows.

### REQ-007 — every live statement of the per-upload model is reconciled; historical records are not

The repository states the per-upload rule in four live places and one historical one. Leaving any live one stale ships a repository that asserts two contradictory egress policies, and the stalest of them (`SKILL.md:3`) is the text a runtime displays when choosing the skill.

| # | Site | Disposition |
|---|---|---|
| 1 | `design-sync-loop/SKILL.md:3` — frontmatter `description:` ends "…with per-upload human approval" | reconcile |
| 2 | `design-sync-loop/SKILL.md:97-98` — Boundaries, "Uploads require explicit human approval every time" | reconcile |
| 3 | `sdd-bootstrap-interviewer/SKILL.md:84` — "manages per-upload human approval" | reconcile |
| 4 | `docs/workflow-guide.md:224` — "都度人間承認" | reconcile |
| 5 | `CHANGELOG.md:1301` — "都度人間承認のうえ Push して" | **do not modify** — a release note for the version that shipped the per-upload model |

`README.md:186` and `docs/skill-reference.md:16` describe the loop but state no approval unit; both were read and neither needs a change.

#### AC-021

Sites 1 through 4 each state the per-feature model and none asserts per-upload approval. Four TEST rows, one per site — a single "no occurrence of the old phrase anywhere" assertion would pass while site 4's Japanese phrasing survived, since it shares no substring with the English ones.

#### AC-022

`CHANGELOG.md:1301` is byte-identical to its pre-change content. A negative TEST row, because "reconcile every statement" is exactly the instruction under which a historical record gets rewritten.

#### AC-023

Whatever change `plugins/sdd-lite/skills/lite-spec/SKILL.md` requires is **staged**, never written live, and the live file is confirmed unmodified by the agent at staging time. See BL-004; this is a protected enforcement-chain file and the staging destination is itself unwritable by the agent.

### REQ-008 — the document assertions that verify this feature are executed by CI

Every acceptance criterion above is a document-conformance assertion, so the guard is only as real as its execution. Today the suite that already asserts against `design-sync-loop/SKILL.md` — `tests/design-system-contract.tests.{sh,ps1}`, block `DS-006` — is **registered nowhere**: not in `tests/run-all.sh`, not in `tests/run-all.ps1`, and not in any workflow, and `tests/run-all.sh` is itself not invoked by CI (INV-016, INV-017).

Where this feature's assertions live **is decided** (OQ-8, resolved 2026-08-04), in three parts:

**(a) The assertions live in the existing `tests/design-system-contract.tests.sh` / `.ps1`.** That suite already asserts against `design-sync-loop/SKILL.md` and is therefore the correct home: the `DS-006` block reads `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md` at `tests/design-system-contract.tests.sh:61` and asserts over it at `:62-68`, and the `.ps1` twin reads the same file at `tests/design-system-contract.tests.ps1:58` and asserts at `:59-62`. Neither file is protected — `PROTECTED_GATE_SUFFIXES` (`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`) contains only `tests/gates.tests.sh`, `tests/eval.tests.sh`, `tests/guard-parity.tests.sh` and `tests/constant-parity.tests.sh` under `tests/` — so extending both is agent-applicable.

**(b) That suite is registered in `tests/run-all.sh` / `tests/run-all.ps1`.** Both are unprotected by the same read of `guard_invariants.py:4`, so this too is agent-applicable. Today the suite appears in neither list (`tests/run-all.sh:8-65`, `tests/run-all.ps1:7-14`).

**(c) CI registration of the suite is a separate staged patch.** `.github/workflows/test.yml` is a member of `PROTECTED_GATE_SUFFIXES` (`guard_invariants.py:4`) and of `PHASE2_HUMAN_COPY_TARGETS` (`:18`), so an agent cannot write it. It is tracked as a staged candidate and human-applied, and it **explicitly does not block this feature's task decomposition**.

Part (c) has a consequence that must be stated rather than discovered: `test.yml` enumerates its suites individually (`:75`, `:85`, `:95`, …) and invokes neither `tests/run-all.sh` nor `tests/run-all.ps1` — `grep -rn 'run-all' .github/` returns nothing. So part (b) alone does not make the suite CI-executed, and AC-024 is satisfied only once the staged workflow patch in part (c) is applied by a human. Until then AC-024's trace is red against the live tree, by the same designed fail-closed behaviour as AC-023/TEST-017 rather than as a defect. What part (c) unblocks is the *decomposition*: the task plan no longer branches on an unanswered question.

#### AC-024

This feature's document-conformance assertions are executed by a suite that CI runs, in both runtimes where the suite has a `.ps1` twin. Verified by tracing the suite from a CI entry point, not by asserting the suite file exists.

#### AC-025

The seven existing `DS-006` literal assertions (`tests/design-system-contract.tests.sh:62-68`) still pass after the `SKILL.md` edit. A regression row: this feature restructures the file those assertions read.

## Non-goals

- **Implementing the pre-upload secret/PII/placeholder scan.** That is #139. This feature specifies only the *point* at which such a check attaches (REQ-006) and writes none of the scanning logic.
- **Implementing `ds_upload_consent`, or touching `AGENTS.md`.** That is #140. This feature specifies only that the consent decision's outcome space can express `off` (REQ-006), and adds no setting.
- **Changing the pull direction.** `list_projects` / `create_project` / `list_files` / `get_file` (`SKILL.md:68-72`) are outbound-adjacent and currently ungated (INV-007). Leaving them as they are is the status quo, recorded as a Non-goal so its absence from the change set is a decision. OQ-4 was resolved 2026-08-04: gating the pull direction stays out of scope — that would be scope creep — **but** the consent disclosure must mention that the pull direction also transmits a human-supplied project name (REQ-002, AC-029 element (e)). The Non-goal is the gate, not the disclosure; omitting the mention would make the disclosure misleading by omission.
- **Adding redaction, an `input_digest`, or a machine-checkable consent object** on the model of `prepare-panelist-input` (`cross-model-verification-policy.md:270-318`). The asymmetry between the two external-send paths is documented in `security-spec.md` as a residual risk; closing it is a larger change than this issue asks for and would overlap #139.
- **Removing the egress gate.** The issue's own Rationale forbids it: the control stays, only its unit changes.
- **Rewriting the already-correct half of the loop.** The `Ensure design-system/` section, the token-derivation rules at `SKILL.md:76-80`, the `get_file`-content-is-data boundary at `:99-101`, and the design-system contract remain untouched.

## Edge Cases

1. **The mockup set changes between consent and upload — and it always does.** `SKILL.md:87` routes the human back to step 2 after every review, so consent is necessarily granted against revision *n* and spent against revisions *n+1…k*. **Resolved by OQ-3 (2026-08-04):** no "material change" rule is defined, because content change deliberately does not re-trigger consent — consent attaches to the feature and the destination, not to a byte sequence. The specification must not imply the payload is fixed at consent time; instead the disclosure states that coverage includes future regenerations (REQ-002, AC-029 element (d)).
2. **Consent granted, then the human selects a different claude.ai project.** Step 1 (`SKILL.md:68-69`) lets the human choose the destination project; nothing binds a consent to the project it was granted against. Consent to send to project A is not consent to send to project B, and the current text cannot tell them apart. **Resolved by OQ-3 (2026-08-04):** consent is scoped to feature **and destination**, so a different destination re-gates. Covered by **AC-027** and its two TEST rows. Until that decision, this was the only Edge Case here mapping to no OQ, REQ, AC or TEST — recorded so the gap and its closure are both visible.
3. **A later session, a different operator, a `Design-Source` line already present.** Because `Design-Source` lives in a git-tracked layer file, a consent recorded on day 1 is readable by any later session. **Resolved by OQ-1 and OQ-2 (2026-08-04):** it does **not** constitute standing authorization. The scope is feature ∧ session, so a later session is a different scope and is gated again (AC-001 branch 3); the session boundary is the expiry. The failure mode this closes — silent, indefinite, transferable consent — was a consequence of leaving the question open, not of the record's existence, and the record remains an audit trace either way (AC-012).
4. **A fabricated or copy-pasted consent record.** Nothing prevents the line from being written without a human having been asked (INV-011, INV-021). Under per-upload this bought an attacker one upload; after this change it buys the whole feature.
5. **`ds_profile: none` and the non-UI case.** The consent prompt must not appear where the loop does not run (AC-016). The most likely regression is a consent question leaking into the interviewer's generic flow.
6. **A host without DesignSync.** On Codex the tool is absent and the loop falls to the manual path (INV-022). The consent change must not introduce a step that blocks there — the fallback has nothing to consent to.
7. **`.ps1` twin divergence.** `tests/design-system-contract.tests.ps1:57-62` asserts a **subset** of the `.sh` block's literals, deliberately (the em-dash line is ASCII-excluded). Any new assertion added to both suites must not silently repeat that asymmetry; if a literal cannot be asserted in PowerShell, the reason must be stated where the asymmetry is created, as the existing comment does.
8. **A negative assertion that is its own false positive.** AC-021's checks assert that a file no longer contains a per-upload phrase. If the test source spells that phrase contiguously in its own body, the suite becomes a false-positive target of any vocabulary scan this repository runs over `tests/`. Per AGENTS.md "Author-time sweeps" item 2, such a marker must be assembled at runtime from non-contiguous literals rather than embedded. This is an authoring constraint on the tests, recorded here so it is designed in rather than discovered.
9. **Restructuring shifts line numbers other files cite.** `tests/workflow-scenarios/workflow-scenarios.tests.sh:364` and `:410` cite `design-sync-loop/SKILL.md:99` in comments (INV-018). The assertions match a phrase, not a line, so nothing breaks — but the comments go stale. A cheap fix; recorded so it is a choice.

## Assumptions

- **Re-verify every `file:line` in this document at implementation start.** Citations accurate when written and stale when used are a recorded, recurring defect class here (WFI-011). One instance was already found in the issue text itself: it cites the Boundaries sentence as `:96-98` where the live text is `:97-98` and `:96` is an unrelated Figma boundary (INV-002).
- **Protected-file membership is shared, git-tracked state this branch does not own.** BL-004's claim must be re-derived — not re-read from this document — at spec-review time, because it gates a reviewer's conclusion about the task plan's shape, and again at implementation start, by reading `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4` and testing each target with `endswith()` on its repository-relative path. (AGENTS.md "Author-time sweeps", item 3.)
- **The CI registration surface is likewise shared state.** AC-024's claim that a given suite is or is not CI-executed must be re-derived at implementation start from `.github/workflows/` and `tests/run-all.{sh,ps1}`, not taken from INV-017.
- **If an ADR is written, its number must be re-derived at drafting time.** `docs/adr/` is a shared sequential namespace; `0025` merely appeared free when this was written, and the sequence already contains duplicate numbers at `0002`, `0003` and `0004` (INV-025).
- **No mockup has ever been generated in this repository** (INV-010). Every behavioural claim about the loop rests on `SKILL.md` prose, with no observed run to check it against. This is why the acceptance criteria are document-conformance assertions rather than execution assertions, and it bounds what they can prove.
- **`DesignSync` tool semantics are outside this repository.** The six tool names appear only in `SKILL.md` (INV-007). `finalize_plan`'s payload in particular is unknown here (OQ-6).

## Baseline Constraints

- **BL-001 — the egress gate is not removed.** After this feature, an upload to claude.ai still requires a recorded human consent decision within its scope. Only the unit changes.
- **BL-002 — the manual fallback is behaviour-preserving.** `claude-design-workflow.md` keeps its current meaning, including `:12` and `:70-71`; the file is edited only if reconciliation requires it, and never in a way that adds an upload.
- **BL-003 — the non-blocking invariant is preserved.** `SKILL.md:29-30` and `:94-95` keep their current meaning.
- **BL-004 — `plugins/sdd-lite/skills/lite-spec/SKILL.md` is a protected enforcement-chain file and is never written by an agent.** Verified by direct read of `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`, where it is a member of the 42-entry `PROTECTED_GATE_SUFFIXES`; the matcher is a case-insensitive `endswith()` on the normalized repository-relative path (`sdd-hook-guard.py:1001-1015`) with **no `human-copy/` carve-out**, so the staging destination `specs/design-sync-consent/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md` is equally unwritable by an agent and must be placed by a human. The path is additionally a member of `PHASE2_HUMAN_COPY_TARGETS` (`guard_invariants.py:18`). **Re-verify per the Assumptions section before relying on this.**
- **BL-005 — `.github/workflows/test.yml` is also protected** (same list, same read: it is a member of `PROTECTED_GATE_SUFFIXES` at `guard_invariants.py:4` and of `PHASE2_HUMAN_COPY_TARGETS` at `:18`). **OQ-8 was answered 2026-08-04**, and the answer registers the suite in CI, so this feature does acquire a **second** protected target and a second staged candidate. Two things follow. First, `tests/design-system-contract.tests.{sh,ps1}` and `tests/run-all.{sh,ps1}` are **not** protected by that same read, so parts (a) and (b) of the OQ-8 answer are agent-applicable and carry no human-copy round. Second, the CI registration in part (c) is a **separate** staged patch that is tracked but **does not block this feature's task decomposition** — the earlier statement that the decomposition could not be written until OQ-8 was answered is discharged by the answer, not by removing the protected target.
- **BL-006 — `CHANGELOG.md:1301` is not modified** (REQ-007 site 5).
- **BL-007 — the seven `DS-006` literals are preserved.** `tests/design-system-contract.tests.sh:62-68` asserts `^## Ensure design-system/$`, `ui-ux-pro-max`, `design-system --persist`, `ui-ux-pro-max unavailable — D6 template interview used`, `figma-dtcg-import`, `design-system/design-tokens\.json`, `MASTER\.md` against `design-sync-loop/SKILL.md`. Any restructuring keeps all seven.

  All seven have an occurrence inside `## Ensure design-system/` (`:32-64`), which this feature does not touch, so BL-007 holds by construction. Recorded because three of them *also* appear in sections this feature **does** edit — `ui-ux-pro-max` at `:3` (frontmatter) and `:106` (Boundaries), `MASTER.md` at `:107` (Boundaries), `design-system/design-tokens.json` at `:77` (Loop) — and a reader who greps only the edited region could conclude a rewrite there breaks the lock. It does not, provided the Ensure section stays intact. The reverse is the real hazard: a restructuring that *moves* content out of the Ensure section could break all seven at once, and the suite that would catch it does not run in CI today (BL-005, OQ-8).
- **BL-008 — dual-runtime parity.** Any assertion added to a `.sh` suite is added to its `.ps1` twin, or the asymmetry is stated where it is created, following the existing precedent at `tests/design-system-contract.tests.ps1:57`.
- **BL-009 — `specs/workflow-state-registry.json` needs an entry for this feature** (`check-workflow-state.sh:130-134`). Not performed during Phase 1 authoring; see INV-023.

## Open Questions

Carried from `investigation.md`. **Six of the ten were answered by the human on 2026-08-04** — OQ-1, OQ-2, OQ-3, OQ-4, OQ-5 and OQ-8. Every row is retained, resolved or not, so the audit trail shows what was open, what closed it, and when. The `Blocks` column keeps its original value, which is a statement about the state before the decision; the `Status` column records the closure.

| OQ | Question | Owner | Blocks | Blocked criteria | Status |
|---|---|---|---|---|---|
| OQ-1 | What is a "feature" for consent scoping? The issue names two different units in one phrase ("per-feature/セッション") | product / security | **yes** | REQ-001, AC-002, REQ-004 | **Resolved 2026-08-04** — scope is feature **and** session together; both must match. See R-OQ-1 |
| OQ-2 | Does consent expire, and can it be withdrawn? A git-tracked record with no expiry is permanent by default | product / security | **yes** | REQ-001, REQ-004 | **Resolved 2026-08-04** — expires with the session; withdrawable mid-session. See R-OQ-2 |
| OQ-3 | What happens when the mockup content changes after consent? Regeneration is guaranteed by the loop; no "material change" rule exists | product / security | **yes** | REQ-001, REQ-003, Edge Case 1 | **Resolved 2026-08-04** — consent attaches to feature + destination, not to bytes; disclosure carries the cost. See R-OQ-3 |
| OQ-4 | Is the ungated pull direction inside or outside the consent statement's scope? | security | no | REQ-002 wording | **Resolved 2026-08-04** — gating it is out of scope; the disclosure must mention it. See R-OQ-4 |
| OQ-5 | Who consents when the operator is not the data owner? | security / legal | no | REQ-002 | **Resolved 2026-08-04** — not enforced technically; the operator asserts authority in the disclosure. See R-OQ-5 |
| OQ-6 | What does `finalize_plan` send? Unknowable from this repository | implementer | no | AC-005, `security-spec.md` | Open — hedged by AC-005, which accepts a stated limitation |
| OQ-7 | Is "送信対象" a file list, hashes, or a description? Each has different staleness under regeneration | product | no | REQ-004, AC-010 | Open |
| OQ-8 | Where do this feature's assertions run, given the orphaned suite and the protected workflow file? | maintainers | **yes** | REQ-008, and the whole task decomposition (BL-005) | **Resolved 2026-08-04** — existing contract suite, registered in `run-all`, CI registration staged separately. See R-OQ-8 |
| OQ-9 | Under #140's `standing`, is #139's scan blocking, advisory, or skipped? | product / security | no | AC-018 (hedged by not assuming interactivity) | Open |
| OQ-10 | Does `docs/THREAT-MODEL.md` gain a design-sync egress boundary in this feature? | maintainers | no | `security-spec.md` | Open |

### Resolutions (human decisions, 2026-08-04)

- **R-OQ-1 — the consent scope is feature ∧ session.** Both must match for a consent to apply. The issue's phrase named two different units; the narrower conjunction is chosen. Rationale: the issue's actual pain is being asked on every upload within one working session, which session scoping solves; feature-only scoping would let a consent outlive the context it was given in, by days and across operators. Recorded in REQ-001; AC-002 continues to check decidedness only.
- **R-OQ-2 — expiry and withdrawal.** Expiry follows from R-OQ-1: a consent dies when its session ends. Withdrawal must additionally be possible **mid-session**. Recorded in REQ-001; the withdrawal half is checked by **AC-028**, the expiry half by AC-001 branch 3.
- **R-OQ-3 — consent attaches to the feature and the destination, not to a specific byte sequence.** The loop regenerates mockups between uploads, so byte-scoped consent is stale by construction, and re-consenting on every change collapses back to the per-upload behaviour this feature exists to remove. The price is paid honestly in the disclosure: it must state that the consent covers this feature's mockups **including future regenerations**, to the named destination, for this session (AC-029 element (d)). A disclosure that omitted this would let an operator believe only what they saw gets sent. The destination half is checked by **AC-027**, which is also what gives Edge Case 2 coverage.
- **R-OQ-4 — the ungated pull direction stays out of scope, and is disclosed anyway.** Gating it is scope creep; omitting it from the disclosure makes the disclosure misleading by omission. The disclosure must mention that the pull direction also transmits a human-supplied project name (AC-029 element (e)). The Non-goal is unchanged.
- **R-OQ-5 — the operator's authority is asserted, not enforced.** No technical check is possible here. The disclosure must state that the operator is asserting they have authority to send this content externally (AC-029 element (f)), converting an invisible assumption into an explicit claim. Organisation-level enforcement belongs to #140's setting.
- **R-OQ-8 — where this feature's assertions run.** Three parts, spelled out with their verification in REQ-008: (a) the assertions live in the existing `tests/design-system-contract.tests.sh` / `.ps1`, which already assert against `design-sync-loop/SKILL.md`; (b) that suite is registered in `tests/run-all.sh` / `.ps1`, which are not protected and so are agent-applicable; (c) CI registration is a separate staged patch because `.github/workflows/test.yml` is protected — tracked, and explicitly **not** a blocker on this feature's task decomposition.

### Still open

Four remain: OQ-6, OQ-7, OQ-9, OQ-10. **None of them blocks implementation** — the `Blocks` column reads `no` for all four. Three are hedged by an acceptance criterion that accepts the gap rather than guessing: AC-005 accepts a stated opacity for OQ-6, AC-010 enumerates the record's field *names* without fixing OQ-7's value domain, and AC-018 states the check point's blocking behaviour without presuming an interactive human, which is the OQ-9 hedge. OQ-10 is a documentation question owned by `security-spec.md` and touches no criterion here.

The four that did block — OQ-1, OQ-2, OQ-3, OQ-8 — are closed above. `sdd-bootstrap-interviewer/SKILL.md:213-214` ("Do not approve tasks while requirements, design, contracts, acceptance criteria, scope, or important risks remain ambiguous") therefore no longer stands in the way of task approval on their account. It still applies to any ambiguity found elsewhere, and approval remains a human action (`:210-211`).
