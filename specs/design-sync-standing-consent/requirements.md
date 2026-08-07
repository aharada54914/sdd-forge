# Requirements: design-sync-standing-consent

Spec-Review-Status: Pending

Source issue: [#140](https://github.com/aharada54914/sdd-forge/issues/140) (`enhancement`, `workflow-improvement`; key `DS-31`, epic #136). Depends on: [#138](https://github.com/aharada54914/sdd-forge/issues/138) (`DS-29`, "design-sync-consent"). Sibling: [#139](https://github.com/aharada54914/sdd-forge/issues/139) (`DS-30`, "design-sync-scan") — independent of this feature (see Non-goals).

## Overview

`design-sync-loop`'s egress gate, as shipped by DS-29 (`specs/design-sync-consent/`, `Impl-Review-Status: Passed`, live in `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md`), asks for exactly one human consent per feature-and-session before any upload to claude.ai/design, and it applies identically to every project — there is no project-level dial. This issue (DS-31) adds one: `ds_upload_consent`, with three positions — `standing` (skip the per-feature confirmation, but still write one audit record), `per-feature` (DS-29's shipped behaviour, unchanged, and the default when the setting is absent), and `off` (forbid the upload outright, on every host, forcing the manual fallback).

Two things about this change need saying plainly, because the issue's own framing (`他Rationale`) presents `standing` and `off` as symmetric conveniences for opposite kinds of organisation, and they are not symmetric in what they cost this repository's own enforcement chain.

**`standing` does not skip a formality — it removes the one bounded moment of live human attention DS-29's entire design exists to defend.** DS-29's central structural decision (`specs/design-sync-consent/design.md` → "The central structural decision") split consent resolution into a three-outcome step specifically so a future `off` value would have somewhere to go, and scoped consent tightly to feature ∧ session (`specs/design-sync-consent/requirements.md` R-OQ-1) specifically so one grant could never quietly become standing authorization across sessions — DS-29's own security review closed that exact risk and retired it as R2 (`specs/design-sync-consent/security-spec.md:176`). `standing` is this feature's deliberate, opt-in reconstruction of the very blast radius DS-29 spent its review closing — this time as an explicit project decision rather than an accidental one. That is a legitimate choice for an organisation whose claude.ai use is already approved (the issue's own Rationale), but the specification must say plainly what is traded, not only what is gained. `security-spec.md` carries the full treatment.

**The setting that authorizes this trade is not itself a protected file.** `AGENTS.md` — where this feature places `ds_upload_consent` — carries no entry in `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`'s `PROTECTED_GATE_SUFFIXES` (42 entries, read in full; re-verify per Assumptions), unlike `tasks.md`'s `Approval: Approved`, which a hook-guard counter defends against any net increase. An agent can write `ds_upload_consent: standing` into `AGENTS.md` in the ordinary course of unrelated work, and from that moment every future feature's first upload proceeds without a human being asked — not because this specification is wrong to allow the setting, but because nothing in this repository's enforcement chain distinguishes "a human deliberately configured this" from "an agent wrote a line in a Markdown file." This is recorded as the feature's principal residual risk (`security-spec.md`), not fixed here: adding a guard for `AGENTS.md` is a larger change than this issue asks for.

Consumer-visible consequence, stated once: after this feature, a project's `ds_upload_consent` setting — not the per-feature dialogue DS-29 shipped — decides whether an operator is ever asked, on every host this repository's skills run on.

## Requirements

### REQ-001 — `ds_upload_consent` is a three-valued project setting, in a place `AGENTS.md` has never had one before

`AGENTS.md` (256 lines, read in full) has five `##` sections today — `Required Workflow` (`:5`), `Sources Of Truth` (`:36`), `Active Spec Directories` (`:79`), `Source Artifact Locations` (`:105`), `Rules` (`:119`) — and no section named `Project Settings`, and no existing convention anywhere in the file for a project-level configuration key with a bounded value domain. This feature introduces both the section and the convention; it is not extending an established pattern, and the specification must say so rather than imply one already existed.

#### AC-001

The setting's value domain is named exactly once, as exactly three alternatives — `standing`, `per-feature`, `off` — and no fourth value is described anywhere in the definition.

#### AC-002

The setting is placed under a new `## Project Settings` section of `AGENTS.md`, and the key is named `ds_upload_consent` there. Verified by asserting the section heading and the key name both exist, not by asserting the heading alone (the same vacuous-heading failure mode DS-29's TEST-015 guards against for `Design-Source`).

#### AC-003

The definition states explicitly that an absent `## Project Settings` section, or a present section that omits `ds_upload_consent`, resolves to `per-feature` — i.e., every `AGENTS.md` written before this feature, including this repository's own until a human adds the section, keeps DS-29's shipped behaviour completely unchanged. This is the criterion that makes the feature backward-compatible by statement, not by accident.

#### AC-004

The setting's own definition text carries no host-name conditional — no "under Claude Code, X; under Codex, Y" branching inside the sentence(s) that define what `standing` / `per-feature` / `off` mean. One definition governs every host; REQ-002 is what makes that claim checkable against the loop's own step-3 text.

### REQ-002 — the setting means the same thing on every host `design-sync-loop` can run on, including one without the `DesignSync` tool today

The 2026-07-10 addendum to issue #140 requires this explicitly: `ds_upload_consent` is host-independent, and `off` in particular must forbid the claude.ai/design upload **on every host**, including Codex, where `DesignSync` is absent today (INV-022, carried from `specs/design-sync-consent/requirements.md`). The forbiddance must not be contingent on the tool's presence, so that a host which gains the tool later inherits the forbiddance automatically, without a further specification change.

This requirement does not claim a present-tense behavioural difference on a tool-absent host: Capability Detection (`design-sync-loop/SKILL.md:22-30`) already routes such a host to the manual fallback before step 3 is ever reached, for the unrelated reason that the tool is absent. What this requirement guarantees is that the forbiddance is stated as a property of the **setting**, not of the tool's current availability, so the two reasons for reaching the fallback — tool absence and `off` — do not collapse into one unstated rule that silently stops applying the day a host gains the tool. REQ-008 is the mechanism that keeps the audit trail honest about which of the two reasons applied on a given run.

#### AC-005

The definition of `off` states, in terms that do not depend on any host's current toolset, that it forbids the upload on every host. Verified by asserting the "every host" (or equivalent unconditional) phrasing appears adjacent to `off`'s definition, not merely somewhere in the document.

#### AC-006

`design-sync-loop/SKILL.md`'s step-3 branching text — the place this feature edits to read the setting — carries no tool-presence conditional as part of what `off` / `standing` / `per-feature` mean. The tool-presence condition remains exclusively Capability Detection's (`:22-30`, untouched by this feature), so the two conditions stay legible as separate reasons a run can end at the manual fallback.

### REQ-003 — `standing`: the per-feature confirmation at step 3 is skipped; exactly one audit record is written, the first time, as `granted`

This is the full decomposition of issue AC #1 ("standing 設定でフィーチャ毎確認が省略されるが監査記録は残る"), expanded per `AGENTS.md` "Author-time sweeps" item 4 into the branches its own language implies, because the sentence packs four independently-failable claims into one: that confirmation is skipped; that a record nonetheless exists; that it exists exactly once, not once per session; and that its value is the same `granted` DS-29 already defines, not a new one.

#### AC-007

Under `standing`, step 3 never produces its "must be requested" outcome — the branch that currently gates the first upload on a human decision (`design-sync-loop/SKILL.md:93`) does not fire. The step resolves as if consent already held, and continues to the pre-upload check point (`:128-134`) with no prompt.

#### AC-008

Despite no prompt, an audit record is written to the layer file's `Design-Source` section (`:160-206`) — `standing` is not silently equivalent to no record at all. This is the branch an implementation optimizing only for "skip the question" is most likely to drop, since dropping it satisfies AC-007 while failing the issue's own second clause.

#### AC-009

The record is written on the **first** occurrence only — defined as the first time step 3 is reached under `standing` for a given feature and finds no existing record whose `Ds-Upload-Consent-Setting` field (REQ-006) reads `standing`. Every later occurrence — a later session, the same feature, still under `standing` — finds that field-and-value already present and writes nothing further. Stated this precisely because "once" is otherwise ambiguous between "once ever, project-wide" (impossible to implement: `Design-Source` is a per-feature file, `specs/<feature>/{ux-spec.md,design.md}`, with no project-wide store) and "once per feature under this regime specifically" (well-defined, and what this criterion requires). A DS-29-era per-feature `granted` record, written before `standing` was ever configured, does not itself satisfy "already written" for this purpose — it carries no `Ds-Upload-Consent-Setting` field at all (Edge Case 2).

#### AC-010

The one-time record's `Egress-Consent` value is `granted` — DS-29's existing three-valued domain (`granted` / `not-permitted` / `withdrawn`, `:169`) is reused, not extended with a fourth value for this case. `standing`'s write is a `granted` record with unusual provenance, not a new kind of record; REQ-006/AC-018 is what keeps the domain itself untouched.

### REQ-004 — `off`: the upload is forbidden; step 3 always resolves to its existing "not permitted" outcome, persistently, on every host

The full decomposition of issue AC #2 ("off 設定で claude.ai upload が禁止され fallback へ流れる"). DS-29 built the third outcome of step 3 specifically for this (`specs/design-sync-consent/requirements.md` REQ-006: "the consent decision must be resolved at one named step whose outcome space already admits denied, not merely {ask, granted}"); this feature is what actually drives that outcome, rather than leaving it permanently unreachable.

#### AC-011

Under `off`, step 3's resolved outcome is always its outcome (c), "egress is not permitted" (`design-sync-loop/SKILL.md:94-100`) — never (a) or (b), regardless of any prior record for the feature.

#### AC-012

Outcome (c)'s existing routing is exercised unchanged: the manual fallback is taken, no upload is attempted, and the outcome is recorded (`:95-96`). The record of an `off`-driven outcome additionally carries `Ds-Upload-Consent-Setting: off` (REQ-006), so a reader of `Design-Source` can tell an `off`-driven forbiddance from a DS-29-era per-attempt decline that happened to occur under `per-feature`.

#### AC-013

The forbiddance is **persistent** for as long as the setting reads `off` — not the transient, single-attempt decline DS-29's own AC-026 defines (`design-sync-loop/SKILL.md:97-100`: "a decline is transient... it is not a persisted refusal"). The two must stay distinguishable in the skill's own text: a decline at step 4 is one operator's one "no"; `off` is a standing project-level "no" that persists across every operator and every session until the setting changes. Mirrors the distinction DS-29's own AC-026 (row 3) and AC-030 (part 4) already draw between a transient decline / a push failure and the persistent outcome (c) — this feature is what finally populates that persistent case for real.

#### AC-014

The forbiddance holds on every host (REQ-002/AC-005), including one where `DesignSync` is absent today — where it is presently unobservable only because Capability Detection already forecloses the upload for the unrelated reason of tool absence (see REQ-002's own caveat).

### REQ-005 — the default, `per-feature`, is exactly DS-29's shipped behaviour — not a reinterpretation of it

Issue AC #3 ("既定は per-feature(DS-29)"). This feature's edit to `design-sync-loop/SKILL.md` is confined to an **outer branch selector** wrapping the existing step 3 — it must not rewrite step 3(a)/(b)/(c)'s own content (the feature ∧ session scope, the destination binding, the decline-transience rule, the mid-session withdrawal path, the push-failure rule) in the course of adding the `standing` and `off` branches.

#### AC-015

Every DS-29-authored sentence inside step 3(a)/(b)/(c) (`:89-100`), the informed-consent disclosure content of step 4 (`:101-127`), the pre-upload check point (`:128-134`), the push-failure rule (`:135-144`), and the review/regeneration cycle (`:145-153`) is unmodified by this feature's edit — the only new material is the branch that decides, before step 3(a)/(b)/(c) is entered, which of `standing` / `per-feature` / `off` is in force. Verified as a regression: every phrase DS-29's own suite already asserts against these spans (TEST-001 through TEST-051, `tests/design-system-contract.tests.sh`) must still be found in the same relative positions after this feature's edit.

### REQ-006 — the setting value and the audit fact are both reflected in `Design-Source`, via three fields DS-29 pre-declared a slot for

DS-29's own field table (`design-sync-loop/SKILL.md:167-173`) is followed by an explicit forward statement: "That is what lets DS-31 / issue #140 add fields such as a consenting party, a timestamp and a project-level setting value later without invalidating a record written here" (`:177-179`). This requirement is that promise, exercised. Issue AC #4 ("設定値と監査記録が Design-Source に反映される").

The three new fields apply to **every** record this skill writes after this feature ships — not only the ones `standing` (REQ-003) or `off` (REQ-004) produce. An ordinary `per-feature` grant, recorded by DS-29's own unedited step-4 logic (REQ-005), also carries `Ds-Upload-Consent-Setting: per-feature` going forward: the "record shape" DS-29 defined (`:160-206`) is a single section shared by every branch, and this feature's edit lands there, not inside step 3/4's own branch-specific text — which is exactly what keeps REQ-005/AC-015 (step 3/4's content is unedited) and this requirement (every record gains the new fields) from contradicting each other.

#### AC-016

Three new fields are enumerated by name in the record's field table: `Egress-Consent-Party` (who or what produced the grant), `Egress-Consent-At` (an ISO-8601 timestamp), and `Ds-Upload-Consent-Setting` (the setting value in force when the record was written). Verified by asserting all three field names are present, in the manner of DS-29's own TEST-015 (field names, not a heading check).

#### AC-017

The shape stays additively extensible in the direction DS-29 already promised: a record written under DS-29's shipped behaviour — before this feature existed, and therefore missing all three new fields — remains a conforming record. The three new fields are required of records this feature's implementation writes, never retroactively required of records that predate it.

#### AC-018

DS-29's five existing field names (`Egress-Consent`, `Egress-Consent-Scope`, `Egress-Consent-Subject`, `Egress-Destination`, `Egress-Consent-Expiry`, `:169-173`) and `Egress-Consent`'s three-valued domain (`granted` / `not-permitted` / `withdrawn`) are unchanged by this feature. `standing`'s one-time write reuses `granted` (AC-010); it does not add a fourth value to that field, and this criterion is the regression check that nothing about the pre-existing table drifted while three rows were added to it.

#### AC-019

`Egress-Consent-Party`'s value, for a `standing` write specifically, must not fabricate an identity. `standing`'s one-time write (REQ-003) has no live, per-occurrence human to name — the human decision was made once, when someone configured `ds_upload_consent: standing`, not now — and the record must say so rather than inventing an operator name it does not have. The field's exact value domain otherwise is not fixed here (OQ-2): what this criterion fixes is only that the record does not claim a specific person consented to an occurrence no person was present for.

### REQ-007 — the setting governs step 3 by its current value; a record's own history never overrides it

Not named in the issue text, but a necessary consequence of REQ-006 giving each record a `Ds-Upload-Consent-Setting` field: once that field exists, a reader — or a careless implementation — could mistake a record's own stored setting value for the thing that governs the *next* run, rather than a note about what was true when the record was written. This requirement forecloses that reading before an implementation can adopt it.

#### AC-020

Step 3's branch (`standing` / `per-feature` / `off`) is decided from the setting's current value at the point of resolution, not a value captured once (e.g., at session start) and reused for the rest of that run without regard for an intervening change. This document does not fix the exact re-read granularity — whether "current" means re-reading `AGENTS.md` on every invocation of step 3 or once per session — that is OQ-1; what it fixes is that the branch is never decided from a **record's** historical value (AC-021 is the sharper, checkable form of that).

#### AC-021

A `Design-Source` record's own `Ds-Upload-Consent-Setting` value never overrides the currently configured setting. Concretely: a `standing`-era `granted` record does not defeat a later `off` — step 3 still resolves to outcome (c) once the setting reads `off`, regardless of what any prior record for that feature says. This is REQ-006's new field kept from becoming exactly the kind of unguarded standing authorization DS-29's own `security-spec.md` (`B3`, "the finding this document exists to surface") warns `Design-Source` already risks being mistaken for — extended to the setting itself rather than only to a single consent record.

### REQ-008 — the manual fallback document states that the setting's value and its audit consequence survive being the actual path taken, without ever using the one word its own regression test forbids

The 2026-07-10 addendum: "監査記録（`Design-Source`）はランタイム中立...standing/off の設定値と監査記録の扱いを fallback 手順（`claude-design-workflow.md`）側にも反映する." The manual fallback (`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md`) is reached whenever the primary loop cannot run — tool absence, auth failure (DS-29, unchanged), or now, an `off`-driven outcome (c) — and in every case it performs no upload of any kind (`:12`, `:70-71`, DS-29 BL-002). This feature does not change that; it requires the fallback to record which setting was nominally in force, so the audit trail names the applicable regime on every host, including one where the primary loop's own step 3 is never reached at all.

**A discovered constraint governs how this must be written.** `tests/design-system-contract.tests.sh` (`DSC` block, `TEST-021`) asserts that `claude-design-workflow.md` contains **no case-insensitive occurrence of the substring "consent" anywhere in the file** — a deliberate DS-29 invariant (`AC-014`: "the fallback introduces no consent step") verified positively **and** negatively (the file must both keep stating it uploads nothing and never grow the word "consent"). This feature is the first to have a reason to edit that file since DS-29 shipped it, and the reason is exactly the kind of edit that would naturally reach for that word. The requirement below is written to be satisfiable without it.

#### AC-022

`claude-design-workflow.md` states, using vocabulary other than "consent" (e.g. "authorization", "the project's upload setting", "permission"), that the project's `ds_upload_consent` setting value and its audit consequence remain in force when this fallback — not the primary loop — is the actual path taken, and names `Design-Source` as where that value is recorded, alongside the existing `design tools unavailable` / `No mockup provided` markers.

#### AC-023

The fallback continues to introduce no upload of any kind. This feature adds no upload path, no upload call, and no new precondition for one — its only edit to this file is the recording statement in AC-022.

#### AC-024

The edited file contains no case-insensitive occurrence of the substring "consent" anywhere. Verified the same way DS-29's own `TEST-021` verifies it, so this feature's own edit is checked against the exact rule it must not violate, not merely assumed compatible with it.

### REQ-009 — every DS-29 invariant this feature's edit surface touches is verified unbroken, not merely assumed so

This feature edits two files DS-29's own suite already asserts against in detail (`design-sync-loop/SKILL.md`, `claude-design-workflow.md`) and reads a third that suite has no coverage of at all (`AGENTS.md`). "Do not break DS-29" is not a criterion an implementer can satisfy by inspection; it is a regression obligation with a named suite to run.

#### AC-025

`tests/design-system-contract.tests.sh` and its `.ps1` twin pass, unmodified, after this feature's edit to `design-sync-loop/SKILL.md`. Five rows are named explicitly because this feature's edit shape — an outer branch wrapped around step 3, three new fields appended to the record table, no reordering — puts each at risk through a different mechanism, and each fails independently:

- **`TEST-010`** (`design-system-contract.tests.sh:308-318`) — asserts the Loop's four anchor phrases ("Generate mockups", "Resolve egress consent", `\bPush\b`, "claude.ai/design browser") occur in that relative order. An outer branch inserted *before* step 3's own text must not change step 3's own line position relative to steps 2 and 6, or this structural check regresses even though nothing about step order was intended to change.
- **`TEST-015`** (`:339-346`) — asserts DS-29's five existing field names are present by literal `grep -F`. Appending three rows to the same table must not touch the five existing cell values these greps match verbatim.
- **`TEST-018`** (`:369-378`) — asserts the neighbourhood regex `audit trace[^.]{0,100}not[^.]{0,60}authorization` matches somewhere in the flattened `SKILL.md` text. This feature must not touch the sentence that satisfies it (`:201-205`), and must not insert 100+ characters of new prose between "audit trace" and "not" if it ever edits near that sentence for an unrelated reason.
- **`TEST-026`** (`:428-455`) — asserts, structurally, that every `write_files` occurrence inside the Loop section sits at or after the pre-upload check point's own line. This feature's `standing`/`off` branching sits *before* step 3, i.e. before the check point at step 5 — it must not introduce a second `write_files` mention (for example, inside an example or a comment) anywhere above that point.
- **`TEST-040`** (design-system-contract.tests.sh, the `DS-006` block) — the seven pre-existing literals inside `## Ensure design-system/` (`:32-64`). This feature does not touch that section, and the check exists here as a regression tripwire against `SKILL.md` restructuring more generally, not because this feature has any specific reason to move that section.

#### AC-026

`tests/design-system-contract.tests.sh`'s `TEST-021` (the no-"consent"-substring check over `claude-design-workflow.md`, `:396-399`) passes, unmodified, after this feature's edit to that file — named separately from AC-025 because `claude-design-workflow.md` is not one of the five files AC-025 enumerates, and REQ-008 is the one requirement in this document whose satisfaction is most directly in tension with this specific regression.

### REQ-010 — this feature's own criteria are executed by a new suite, registered locally; CI registration follows DS-29's own precedent rather than re-litigating it

Unlike DS-29, this feature touches no protected file (Global Constraints) — there is no `plugins/sdd-lite/skills/lite-spec/SKILL.md`-shaped staging round here at all. The only shared-infrastructure question this feature reopens is where its own assertions live and whether CI runs them, and DS-29 already answered the general shape of that question for a sibling suite (R-OQ-8, `specs/design-sync-consent/requirements.md`): adopted directly here rather than re-derived from first principles, because the facts it rests on — `tests/run-all.{sh,ps1}` unprotected, `.github/workflows/test.yml` protected, `tests/run-all.sh` invoked by no workflow — are unchanged (re-verified during this document's own drafting; see Assumptions).

#### AC-027

This feature's assertions live in a new suite, `tests/design-sync-standing-consent.tests.sh` and its `.ps1` twin, document-conformance in nature (this feature has no more of an executable code path than DS-29 did), and that suite is registered in `tests/run-all.sh` and `tests/run-all.ps1`. Both files are unprotected (confirmed against `guard_invariants.py:4`), so this is agent-applicable with no human action.

#### AC-028

CI registration of the new suite — an entry in `.github/workflows/test.yml` — is a **separately staged, human-applied patch**, explicitly not a blocker on this feature's task decomposition, exactly as DS-29's own equivalent patch (for `tests/design-system-contract.tests.{sh,ps1}`) remains staged and unapplied today (re-verified: zero matches for `run-all` or `design-system` across `.github/workflows/` at drafting time). The two staged patches touch the same protected file and may be applied together.

## Non-goals

- **Implementing #139 (design-sync-scan, DS-30).** Independent of this feature — both edit `design-sync-loop/SKILL.md`, but at different, non-overlapping steps (#139: the pre-upload check point at step 5; this feature: the outer branch wrapping step 3, and the record table). The only cross-feature obligation this document records is that the two features' `SKILL.md` edits are serialized at implementation time to avoid a conflicting simultaneous edit to the same file; this specification makes no other assumption about #139's content, timing, or outcome. DS-29's own OQ-9 ("under `standing`, is #139's scan blocking, advisory, or skipped?") is carried forward, still open, still owned by #139 — this feature only guarantees the pre-upload check point continues to sit between consent resolution and push for every branch that produces an upload attempt (`standing`, `per-feature`); `off` produces no upload attempt, so there is nothing for the check point to see, which is an absence of work for it, not a bypass of it.
- **Touching `plugins/sdd-lite/skills/lite-spec/SKILL.md`.** Not needed: this feature's changes live at the `AGENTS.md` / `design-sync-loop/SKILL.md` / `claude-design-workflow.md` layer, consumed identically by both the full and lite profiles without a profile-specific restatement.
- **Touching `contracts/design-system.contract.v1.schema.json`.** That schema governs `design-tokens.json`'s meta envelope (color/typography/spacing token groups); it has no relationship to the consent record or the `ds_upload_consent` setting, and this feature does not add one.
- **Adding a protected-file guard for `AGENTS.md` or for `ds_upload_consent` specifically.** Recorded as the feature's principal residual risk (`security-spec.md`), not fixed here — closing that gap is a larger change than this issue asks for, and would need to establish a general policy for which `AGENTS.md` sections warrant guarding, not only this one.
- **Adding a `docs/THREAT-MODEL.md` entry for design-sync egress.** Carried unresolved from DS-29's own OQ-10 (`specs/design-sync-consent/requirements.md`); still open, still a maintainers' call, restated here as OQ-4 because `standing`/`off` raise the stakes of that gap without this feature being the one that closes it.
- **Re-litigating DS-29's own per-feature+session scope, destination binding, decline-transience, mid-session withdrawal, or push-failure rules.** REQ-005/AC-015 freezes them explicitly; this feature adds an outer selector, not a rewrite.

## Edge Cases

1. **The setting changes while a `Design-Source` record from an earlier regime still exists.** Resolved by REQ-007: step 3 reads the *current* setting, never a record's own historical `Ds-Upload-Consent-Setting` value; a stale `standing`-era `granted` record does not defeat a later `off` (AC-021).
2. **A DS-29-era per-feature record already exists for a feature when `standing` is later turned on.** Resolved by AC-009's precise "first occurrence" test: it checks for a record whose `Ds-Upload-Consent-Setting` field already reads `standing`, not for the mere existence of any prior record. A pre-`standing` grant, which carries no such field, does not suppress `standing`'s own one-time write.
3. **`standing` is configured project-wide; does "once" mean once per feature or once ever?** Resolved structurally, not by choice: `Design-Source` is a per-feature file (`specs/<feature>/{ux-spec.md,design.md}`) with no project-wide store, so "once" can only mean once per feature under the `standing` regime (AC-009). A newly-created feature, under an already-`standing` project, still receives its own first-occurrence write.
4. **A host without `DesignSync` (Codex today) under `off`.** Capability Detection already routes such a host to the manual fallback for an unrelated reason (tool absence) before step 3 — DS-29's ordering, unchanged (REQ-005/AC-015). `off`'s forbiddance is therefore unobservable there today and becomes load-bearing only once such a host gains the tool; REQ-002 states the forbiddance as a property of the setting for exactly this reason, so no further specification change is needed when that day comes.
5. **The same host-absence case under `standing`.** Symmetric to Edge Case 4 in cause (Capability Detection short-circuits before step 3 either way) but different in consequence: nothing about `standing`'s skip-the-prompt behaviour is observable there either, today. This is exactly why REQ-008 requires the fallback document itself — not the primary loop's step 3 — to record which setting is nominally in force: the audit trail must stay complete on the one path where the primary loop's own branching text never executes.
6. **A live human answers the ordinary `per-feature` step-4 prompt after `standing` is later configured for the project.** Not a conflict: `per-feature` and `standing` are mutually exclusive settings, and once the project reads `standing`, step 3 no longer reaches step 4's prompt for that feature at all (AC-007). A grant recorded before the switch remains inert history, exactly as a DS-29-era record does under any later scope mismatch (`specs/design-sync-consent/security-spec.md`, "B3, in detail").
7. **`.ps1` twin divergence for the new suite.** Following DS-29's own precedent (`tests/design-system-contract.tests.ps1:57`), any assertion in this feature's `.sh` suite that cannot be expressed identically in an ASCII-only `.ps1` source must state the reason where the asymmetry is created, not silently assert a subset.
8. **A negative assertion (AC-024, "no 'consent' substring") that is its own false positive.** Per `AGENTS.md` "Author-time sweeps" item 2, the new suite's own source must not embed the literal substring "consent" contiguously while writing the test that checks for its absence elsewhere — it must assemble the marker at runtime from non-contiguous parts, exactly as DS-29's own `TEST-033`–`TEST-036` do for their banned phrases.

## Assumptions

- **Re-verify every `file:line` in this document at implementation start.** Citations accurate when written and stale when used are a recorded, recurring defect class in this repository (WFI-011).
- **Protected-file membership is shared, git-tracked state this branch does not own.** Re-derived at drafting time (`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`): `PROTECTED_GATE_SUFFIXES` has 42 entries, and none of `AGENTS.md`, `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md`, or `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md` is among them — all three are agent-applicable directly, with no human-copy round required by this feature. `.github/workflows/test.yml` (`:4`, `:18`) remains protected, which is why REQ-010's CI registration is staged. Must be re-derived again at spec-review time and at implementation start (AGENTS.md "Author-time sweeps" item 3), not read from this paragraph.
- **DS-29 is shipped and live, not merely specified.** Re-verified by reading `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md` directly (226 lines): the per-feature+session consent model, the three-outcome step 3, the five-field `Design-Source` record table, and the reconciled per-feature language at all four DS-29 REQ-007 sites are all live. `plugins/sdd-lite/skills/lite-spec/SKILL.md`'s DS-29 human-copy round is also applied (`specs/design-sync-consent/human-copy/` contains both the `MANIFEST.sha256` and the placed candidate). DS-29's own CI-registration patch (part (c) of its R-OQ-8) is **not** yet applied — `grep -rn 'run-all\|design-system' .github/workflows/` returns nothing at drafting time — which is why REQ-010 treats its own CI registration the same way rather than expecting DS-29's own gap to have closed first.
- **The CI registration surface is shared state.** Re-derive at implementation start from `.github/workflows/` and `tests/run-all.{sh,ps1}`, not from this document (same instruction DS-29 carries).
- **`DesignSync` tool semantics remain outside this repository.** This feature adds no new claim about `finalize_plan` or any other tool call beyond what DS-29 already states; `finalize_plan`'s payload is still unknown here (DS-29 OQ-6, untouched by this feature).

## Baseline Constraints

- **BL-001 — DS-29's egress gate, and its own internal rules, are not rewritten.** `per-feature`'s content — scope, destination binding, decline transience, mid-session withdrawal, push-failure handling — is unmodified (REQ-005/AC-015). This feature adds an outer selector and two new branches beside it.
- **BL-002 — DS-29's five `Design-Source` field names and `Egress-Consent`'s three-valued domain are unchanged** (REQ-006/AC-018).
- **BL-003 — the manual fallback's zero-upload property, and its "no 'consent' substring" invariant, both survive this feature's own edit to it** (REQ-008/AC-023, AC-024, AC-026).
- **BL-004 — no protected file is touched, live or staged, by this feature.** A contrast with DS-29, stated positively: `plugins/sdd-lite/skills/lite-spec/SKILL.md` is untouched; `.github/workflows/test.yml`'s CI registration is out-of-decomposition, exactly as DS-29's own remains, and the two staged patches may be bundled (REQ-010/AC-028).
- **BL-005 — `specs/workflow-state-registry.json` needs an entry for this feature**, per `check-workflow-state.sh:130-134`'s iteration over every `specs/` subdirectory. Unlike DS-29, which deferred this to a later phase, this document's own authoring process adds the minimal entry — `{"feature": "design-sync-standing-consent", "profile": "full"}` — directly, because the task authorizing this document's creation explicitly scoped that one file as an allowed edit alongside this spec directory.
- **BL-006 — `AGENTS.md`'s `Active Spec Directories` list (`:79-103`) needs `specs/design-sync-standing-consent/` appended.** Non-blocking, gate-invisible, exactly as DS-29's own equivalent item was (`specs/design-sync-consent/infra-spec.md` → Prerequisites) — **not performed during this document's own authoring**, because the authoring instruction for this session permits editing only this spec directory and the registry file, and `AGENTS.md` is neither.

## Open Questions

| OQ | Question | Owner | Blocks | Blocked criteria | Status |
|---|---|---|---|---|---|
| OQ-1 | Does "the setting's current value" (REQ-007/AC-020) mean re-reading `AGENTS.md` on every invocation of step 3, or once per session? Both satisfy AC-021 (a stale *record* never overrides the live setting); they differ only on whether a same-session `AGENTS.md` edit takes effect immediately. | implementer | no | AC-020 (hedged: either reading satisfies the criterion as written) | Open |
| OQ-2 | What exact value does `Egress-Consent-Party` carry for a `standing` write, beyond the requirement that it not fabricate an identity (AC-019)? A named mechanism ("the project's `ds_upload_consent: standing` setting"), a generic placeholder, and other honest phrasings are all consistent with AC-019 as written. | product | no | AC-019 fixes only the non-fabrication rule; the value domain is open, in the manner of DS-29's own OQ-7 for `Egress-Consent-Subject` | Open |
| OQ-3 | Under `standing`, does a **different destination project** selected for an already-recorded feature trigger a fresh one-time audit write (for completeness — the trail should name every destination content was sent to), or does the single per-feature record stand regardless of destination? DS-29's own `AC-027` binds `per-feature`'s scope to (feature, destination); whether `standing`'s "once" (AC-009) is scoped by (feature) alone or by (feature, destination) is not decided here. | product / security | no | none named in this document; an implementer may choose either reading provided it is stated in the implementation report and does not disturb `Egress-Destination`'s existing binding meaning for the `per-feature` / `off` branches (AC-018) | Open |
| OQ-4 | Does `docs/THREAT-MODEL.md` gain a design-sync egress boundary entry, now naming the `ds_upload_consent`-driven risk specifically (see `security-spec.md`)? Carried from DS-29's own still-open OQ-10; unresolved there, and this feature raises the stakes without being the one that closes it. | maintainers | no | none | Open |
| OQ-5 | Are the two staged CI-registration patches (DS-29's, for `tests/design-system-contract.tests.{sh,ps1}`; this feature's, for `tests/design-sync-standing-consent.tests.{sh,ps1}`) applied to `.github/workflows/test.yml` as one combined human edit or two independent ones? | maintainers | no | none — either satisfies AC-028 | Open |

None of the five blocks this feature's task decomposition; each is hedged by an acceptance criterion that accepts the gap rather than guessing at it, in the manner DS-29 itself used for its own non-blocking Open Questions (OQ-6, OQ-7, OQ-9, OQ-10).
