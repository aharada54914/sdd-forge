# WFI Why-Why (5 Whys) Retroactive Review — 2026-08-21

## Purpose

The WFI flow now requires a `## Why-Why Analysis` causal chain in every new
Draft (template + workflow-retrospective step 1.75, audited by wfi-auditor-a's
`WHY-CHAIN-VALID` check). This review re-examines every WFI drafted before
that requirement existed and asks one question per WFI: does its
`## Root Cause Hypothesis` reach a controllable process/mechanism cause, or
does it stop at a symptom, an intermediate cause, or blame?

Historical WFI bodies are intentionally NOT edited by this review:

- `Audit-Content-Hash:` fields bind audit state to the exact body text.
- `Status:` transitions are governed (hook guard; human-only Approved).

This document is a sidecar. Where a chain was found deficient, the
recommendation column says what to do the next time that WFI (or its friction
pattern) is touched — typically: rebuild the why-chain and, if the terminal
cause differs from what was fixed, draft a follow-up WFI against the deeper
cause.

## Method

- Scope: every `docs/workflow-improvements/WFI-*.md` present on 2026-08-21
  (WFI-001–025, 029, 034–038; 31 documents). Auditor JSONs and audit-cycle
  reports were not consulted — the review grades the WFI document itself.
- Each WFI was read in full and its Root Cause Hypothesis classified:
  - **ROOT-CAUSE-REACHED** — names a specific controllable process/mechanism
    cause, and the Proposed Change acts on that cause.
  - **INTERMEDIATE-CAUSE** — a real mechanism, but a deeper "why" exists that
    the Proposed Change does not address (mitigation, not removal).
  - **SYMPTOM-LEVEL** — restates the friction or is circular.
  - **BLAME-STOP** — terminates at human/agent error or an uncontrollable
    cause.
- For every verdict below ROOT-CAUSE-REACHED, a reconstructed why-chain is
  recorded; speculative links are marked `(hypothesis)`.
- Cross-check: `Status: Regressed` / `Status: Rejected` outcomes were compared
  against the verdict — a fix that later regressed is prima facie evidence the
  chain stopped above the root cause.

## Summary

| Verdict | Count | WFIs |
|---|---|---|
| ROOT-CAUSE-REACHED | 17 | 007, 009, 011, 013, 014, 016, 017, 018, 020, 021, 022, 024, 034, 035, 036, 037, 038 |
| INTERMEDIATE-CAUSE | 14 | 001, 002, 003, 004, 005, 006, 008, 010, 012, 015, 019, 023, 025, 029 |
| SYMPTOM-LEVEL | 0 | — |
| BLAME-STOP | 0 | — |

Three findings stand out:

1. **Every Regressed WFI stopped above the root cause.** All six WFIs whose
   failure mode recurred after Verified/Applied (001, 003, 004, 005, 006, 010)
   are INTERMEDIATE-CAUSE. The recurrence evidence in each case names exactly
   the deeper "why" the original hypothesis did not reach. Conversely, none of
   the 17 ROOT-CAUSE-REACHED WFIs has regressed to date. This is direct
   empirical support for requiring a why-why chain before drafting.

2. **The dominant missing "why" is "prose rule without deterministic
   enforcement".** Eight of the 14 intermediate verdicts (003, 005, 006, 010,
   012, 023, plus partially 001, 015) stopped at "no rule/checklist existed",
   added a prose rule, and left unchanged the fact that compliance depended on
   per-session recall. WFI-020's own census quantifies the gap: enforced
   mechanisms ≈99% compliance vs AGENTS.md prose ≈50%.

3. **The second recurring pattern is "two-surface contract drift with no
   parity control"** (002, 019, 025, 029; correctly generalized only in
   WFI-038: "when two surfaces must agree on a contract, something has to
   assert that they do"). Later WFIs (034–038) mostly reach root cause —
   evidence the audit lane's forced revisions (e.g. WFI-020's two rejected
   symptom-level drafts) were already pushing analysis deeper before this
   review formalized the requirement.

## Per-WFI Findings

### WFI-001 — Regressed / app-dev-efficiency / (predates Mechanism field)
- **Problem:** Two high-risk tasks (T-002, T-006) required late evidence-consistency corrections during review — extra QG cycles and a major ticket for verdict/traceability mismatches.
- **Root Cause Hypothesis (paraphrase):** Task contracts did not require a pre-implementation checklist linking each persisted verdict/traceability field to a negative mismatch test.
- **Depth verdict:** INTERMEDIATE-CAUSE — countermeasure-shaped (absence of the proposed checklist), not an explanation of why cross-artifact evidence drifts.
- **Missing why:** Evidence identity is duplicated across artifacts, maintained by manual multi-step procedures that are not idempotent, and no deterministic cross-artifact consistency check runs before the gate `(hypothesis; the regression's "reservation-step non-idempotency" confirms this layer exists)`.
- **Outcome consistency:** Regressed corroborates — the recurrence was a manifest rewritten by a second, redundant run of the reservation step; a preflight checklist cannot reach a tooling non-idempotency.
- **Recommendation:** Re-analyze; follow-up WFI making evidence-reservation steps idempotent plus a deterministic pre-gate consistency check.

### WFI-002 — Verified / plugin-improvement / instructions
- **Problem:** Review-gate prechecks carry mutually incompatible invocation contracts, forcing undocumented ad-hoc manual fallbacks in 4 workflow phases.
- **Root Cause Hypothesis (paraphrase):** Each gate ships mutually inconsistent contract expectations, and with no sanctioned fallback documented, every affected run re-derives an ad-hoc procedure from scratch.
- **Depth verdict:** INTERMEDIATE-CAUSE — the true cause (inconsistent precheck contracts) is named but the change only documents a fallback, explicitly deferring the defect to issue #61.
- **Missing why:** Prechecks were authored per-gate with no shared invocation-contract spec or parity check between them `(hypothesis)`.
- **Outcome consistency:** Verified on its own metric (undocumented fallbacks 4 → 0), but the metric never measured whether fallbacks are still needed — consistent with an intermediate verdict.
- **Recommendation:** Verify issue #61 was actually fixed; if the fallback is still exercised, draft a follow-up defining one shared precheck contract across gates.

### WFI-003 — Regressed / plugin-improvement / instructions
- **Problem:** Missing identity fields on 22 report artifacts made retrospective/run-record measurement blind — 33 N/A metric cells; run record counted 0 of 11 gate reports.
- **Root Cause Hypothesis (paraphrase):** Nothing in the project's workflow files states the required fields — a missing-specification cause rather than individual authoring mistakes.
- **Depth verdict:** INTERMEDIATE-CAUSE — missing specification is a real mechanism, but the fix is prose documentation only; nothing enforces the fields when reports are written.
- **Missing why:** Fields exist only as prose rules; no deterministic check validates authored reports against the parser schema before gate/retrospective `(the regression itself names reports "written to satisfy a human reader rather than the script that must parse them")`.
- **Outcome consistency:** Regressed strongly corroborates — fields vanished again as soon as instruction adherence decayed (3/5 reports missing `Task Attempt Count`, 4/5 gate reports missing `Task:`).
- **Recommendation:** Follow-up WFI adding a deterministic schema check on authored reports (extend WFI-005's parity approach from templates to the artifacts themselves).

### WFI-004 — Regressed / plugin-improvement / instructions
- **Problem:** Full-profile persisted-state validation was unsatisfiable after implementation — five contradictions blocked all 10 tasks.
- **Root Cause Hypothesis (paraphrase):** The validator was authored against invariants never exercised end-to-end; role files cover only pre-implementation states; the freeze design assumes review-bound artifacts never change.
- **Depth verdict:** INTERMEDIATE-CAUSE — real structural mechanisms, acted on, but the deeper why (the freeze admits mutable lines by enumeration, so each new sanctioned field re-triggers the class) is untouched.
- **Missing why:** No single source of truth for freeze-exempt fields shared by hasher and workflow; no full-profile end-to-end CI fixture `(hypothesis)`.
- **Outcome consistency:** Regressed corroborates — RT-20260712-003 was a NEW instance of the same class, remediated by yet another enumerated mask.
- **Recommendation:** Re-analyze at class level: registry-driven definition of mutable status fields plus an end-to-end full-profile CI fixture.

### WFI-005 — Regressed / plugin-improvement / tools
- **Problem:** 23 gate artifacts needed manual format retrofits plus one unusable documented waiver, from four template-vs-validator contract gaps.
- **Root Cause Hypothesis (paraphrase):** Validators were hardened in separate changes without updating the artifact templates, and no deterministic check binds template output to validator expectations.
- **Depth verdict:** INTERMEDIATE-CAUSE — genuine mechanism, acted on (template fixes + parity twins), but the parity test binds templates to validators, not authored artifacts to validators.
- **Missing why:** Report production is free-form authoring rather than generated/lint-checked output, so format correctness depends on each author re-reading the template `(hypothesis)`.
- **Outcome consistency:** Regressed corroborates precisely — both regression commits retrofit authored reports while the parity twins stayed green; the guard was installed one level too shallow.
- **Recommendation:** Follow-up WFI running the real consumer parsers over authored reports at authoring/commit time (pre-gate lint), not only over rendered templates.

### WFI-006 — Regressed / plugin-improvement / instructions
- **Problem:** Implementation-report prose (counts, statuses, paths) goes stale before the gate reads it — 4th consecutive feature showing the class.
- **Root Cause Hypothesis (paraphrase):** Reports are honest commit-scoped snapshots, but neither template nor gate instructions say so, and nothing reconciles the frozen report against gate-time reality.
- **Depth verdict:** INTERMEDIATE-CAUSE — a real reconciliation-gap mechanism, but the change (advisory Snapshot Notice) codifies tolerance of staleness rather than removing what makes reports stale.
- **Missing why:** Reports embed volatile shared-surface values that concurrent tasks invalidate by construction; the evidence format binds those claims to no revision — no commit-SHA scoping or derive-at-gate-time design `(hypothesis)`.
- **Outcome consistency:** Regressed sharply corroborates — 7 findings against a Verified target of ≤1; the regression note concedes the instruction cannot prevent authorship of claims a concurrent sibling invalidates.
- **Recommendation:** Re-analyze targeting commit-scoped or machine-derived volatile claims (follow-up already flagged in the 2026-07-29 retrospective).

### WFI-007 — Verified / plugin-improvement / instructions
- **Problem:** Eight plugin doc/template locations taught the flat report path the evaluator launch boundary rejects, forcing a 9-file gate-phase `git mv` per feature.
- **Root Cause Hypothesis (paraphrase):** The launch boundary was hardened to the canonical per-feature path but the plugin's own skill and reference files were never updated to match — structural, reproducing on every task until corrected.
- **Depth verdict:** ROOT-CAUSE-REACHED
- **Outcome consistency:** Verified corroborates — 0 path moves in the next feature, sustained.
- **Recommendation:** No action on this WFI; optionally extend WFI-005's parity-check idea to doc path prose (the doc-vs-validator drift class regressed siblings later).

### WFI-008 — Verified / app-dev-efficiency / tools
- **Problem:** Raw quality-gate logs for two features were permanently lost (116 unique paths; all 21 evidence bundles fail validation) — never git-tracked, then the worktrees holding them were deleted.
- **Root Cause Hypothesis (paraphrase):** The `.gitignore` re-include covered only flat `verification/*.log` while the gate writes nested paths, and nothing verifies referenced artifacts are actually git-tracked.
- **Depth verdict:** INTERMEDIATE-CAUSE — the analysis itself reaches the deeper mechanism (no tracked-artifact check at bundle generation) but explicitly defers it out of scope; the applied change covers only the instance fix.
- **Missing why:** Bundle generation checks on-disk existence, not git-trackedness, so any future artifact path outside the re-includes repeats the loss silently (stated in the WFI, not addressed by it).
- **Outcome consistency:** Verified (0 missing paths across three features) corroborates the instance fix; it never exercises the deferred class-level guard, so Verified does not contradict the intermediate verdict.
- **Recommendation:** Confirm the flagged follow-up WFI (deterministic "referenced artifacts must be git-tracked" check at bundle-generation time) was drafted; create it if not.

### WFI-009 — Applied / plugin-improvement / tools (Meta-Change: true)
- **Problem:** Expensive 3-panelist blind cross-model rounds failed (2 of 3 first runs) on evidence-completeness gaps that were deterministically checkable before any panelist ran.
- **Root Cause Hypothesis (paraphrase):** The panel is the first step checking two pre-computable properties because no deterministic pre-panel check exists for either, so gaps ride through to the costliest stage.
- **Depth verdict:** ROOT-CAUSE-REACHED
- **Outcome consistency:** Applied, structurally fail-closed, RED→GREEN TDD evidence; metric honestly open.
- **Recommendation:** No action on analysis; close the open Verification Plan count at the next cross-model feature.

### WFI-010 — Regressed / plugin-improvement / tools (Meta-Change: true)
- **Problem:** The deterministic run-record emitter reported `gate_reports.total: 0` (true 4) and a false `blocked: 1` across two consecutive retrospectives.
- **Root Cause Hypothesis (paraphrase):** Emitter authored against an assumed header convention that silently returns 0 instead of failing loudly, plus an unanchored whole-file BLOCKED grep; report authoring had regressed from WFI-003's compliance state.
- **Depth verdict:** INTERMEDIATE-CAUSE
- **Missing why:** The WFI-003 rule is prose-only with no deterministic emission/gate-time check of identity fields, so compliance depends on per-session recall `(hypothesis)`.
- **Outcome consistency:** Strongly corroborates — after manual re-compliance and Verified on pillar-c, the 2026-07-30 retention check regressed on `total` again; only the deterministic blocked-count sub-fix held.
- **Recommendation:** Re-analyze; draft the outstanding FP-01 follow-up targeting deterministic enforcement of gate-report identity fields, not another round of manual re-compliance.

### WFI-011 — Verified / app-dev-efficiency / instructions
- **Problem:** Two spec-phase factual premises about existing repo behavior were false and caught only incidentally by implementation-time grep.
- **Root Cause Hypothesis (paraphrase):** Spec-phase claims carry no evidentiary bar — investigation/requirements claims asserted without the file:line grep evidence the implementation phase already requires.
- **Depth verdict:** ROOT-CAUSE-REACHED
- **Outcome consistency:** Corroborates — 2-feature horizon closed at 0/2 recurrences; the fix includes a review-side enforcement seam, not author memory alone.
- **Recommendation:** No action — verified; recurrence condition registered in retention-checklist.md.

### WFI-012 — Applied / app-dev-efficiency / instructions
- **Problem:** `.sh`→`.ps1` ports shipped silently case-insensitive at two independent layers; a detection suite self-matched its own marker strings.
- **Root Cause Hypothesis (paraphrase):** Both gaps rely on the author's manual vigilance for properties easy to state but easy to miss; neither has a checklist step.
- **Depth verdict:** INTERMEDIATE-CAUSE
- **Missing why:** The properties are finite and grep-able (the rule itself enumerates the operator/cmdlet inventory) yet no deterministic scripted sweep or precheck enforces them `(hypothesis)`.
- **Outcome consistency:** Neutral so far (horizon open), but the WFI's own Result cites WFI-003/005/010 regressing "precisely because authors did not follow rules that already existed" — internal evidence a prose checklist mitigates rather than removes a vigilance dependency.
- **Recommendation:** When the horizon scores, draft a follow-up converting both sweeps into deterministic scripted checks (tools mechanism).

### WFI-013 — Applied / app-dev-efficiency / instructions
- **Problem:** Spec/design asserted facts about shared repo state that a concurrently-merging sibling branch invalidated (one Critical, one Major finding).
- **Root Cause Hypothesis (paraphrase):** Claims about repository-wide shared mutable state the feature's branch does not own can be silently changed by any other branch merging to main; the re-verify-at-consumption pattern exists in two isolated places but is not a stated, generalizable rule.
- **Depth verdict:** ROOT-CAUSE-REACHED (genuine TOCTOU mechanism)
- **Outcome consistency:** Consistent but unproven — Applied, wired into a reviewer-checkable seam; concurrent-branch horizon open.
- **Recommendation:** Score the open horizon at the next concurrently-developed features.

### WFI-014 — Applied / app-dev-efficiency / instructions
- **Problem:** ACs whose own language enumerates branches mapped to TEST-IDs covering a strict subset, caught only reactively across two spec-review rounds.
- **Root Cause Hypothesis (paraphrase):** acceptance-tests.md is drafted by paraphrasing each AC; nothing cross-checks that every branch/condition the AC's language names has a corresponding TEST-ID assertion.
- **Depth verdict:** ROOT-CAUSE-REACHED
- **Outcome consistency:** Consistent but unproven; the Result's own note that the same seam failed one step further downstream (round-time AC amendment not propagated) shows the class extends beyond this rule's trigger.
- **Recommendation:** Score the horizon; extend the rule (or sibling WFI) to round-time AC amendments propagating to downstream task/RED clauses.

### WFI-015 — Approved (Result records Applied; Status not advanced) / app-dev-efficiency / instructions
- **Problem:** Changes that flipped an environment/platform SKIP-gate open for the first time exposed never-exercised assumptions at the most expensive point (Windows CI leg; real release), twice.
- **Root Cause Hypothesis (paraphrase):** Nothing treats "a change is about to flip that gate from closed to open for the first time" as its own re-verification trigger.
- **Depth verdict:** INTERMEDIATE-CAUSE
- **Missing why:** The rule presumes the author notices the flip, yet Instance 1's flip was an indirect side effect of an unrelated CRLF fix; nothing mechanically surfaces "previously-SKIPped test now runs" `(hypothesis)`.
- **Outcome consistency:** Neutral — horizon open; Instance 1's history (a silent probe made the suite green regardless) suggests detection of flips, not willingness to re-verify, is the binding constraint.
- **Recommendation:** Follow-up WFI adding mechanical gate-flip detection (skip-count/newly-run-test delta in CI); advance the Status field to match the Result.

### WFI-016 — Applied / plugin-improvement / tools (Meta-Change: true)
- **Problem:** The Impl-Review-Status guard falsely denied a legitimate `Passed` write whenever the session CWD was outside the repository.
- **Root Cause Hypothesis (paraphrase):** The verdict check was CWD-relative and never migrated to the multi-candidate root-resolution pattern the same scripts already use; the parity suite reinforced the blind spot because its scenarios pin CWD to the repository.
- **Depth verdict:** ROOT-CAUSE-REACHED (includes the why-tests-missed-it layer)
- **Outcome consistency:** Consistent — fix acts on mechanism and test blind spot with pre/post exit-code evidence; a separate staging-staleness cause honestly deferred to a follow-up.
- **Recommendation:** Complete the pending 2-feature verification; file the flagged staged-vs-live drift follow-up.

### WFI-017 — Verified / plugin-improvement / tools
- **Problem:** The plugin's authoring-time implementation-report validator rejected 100% of reports authored from the canonical template because WFI-005 replaced the template's outputs section without updating this validator.
- **Root Cause Hypothesis (paraphrase):** WFI-005's consumer inventory omitted the same-plugin validator; its parity suite was scoped to two named consumers; "additive" wording concealed a replacement; the only tests exercising the validator were unregistered in CI, so the break produced no signal.
- **Depth verdict:** ROOT-CAUSE-REACHED
- **Outcome consistency:** Verified at the 2026-08-05 checkpoint with target hit; honestly records the parity twins are still CI-only.
- **Recommendation:** No action — keep the recurrence condition; let #211 close the CI-registration co-cause.

### WFI-018 — Draft / measurement / instructions
- **Problem:** A post-implementation provenance re-review produced a fresh Major each round from TYPE-H checks against byte-identical, previously-passed frozen content — round 3 terminal.
- **Root Cause Hypothesis (paraphrase):** The task-review state machine assumes findings are resolvable by editing tasks.md, but the re-review forbids content changes and waivers; TYPE-H judgments are re-drawn per fresh instance, making the procedure "non-convergent by construction".
- **Depth verdict:** ROOT-CAUSE-REACHED
- **Outcome consistency:** Result pending (Draft); the hypothesis avoids blaming reviewer variance (uncontrollable) and targets the controllable procedure rule; a later clean PASS re-review is consistent with convergence being achievable.
- **Recommendation:** Reconcile the dangling Draft status against what actually landed; note the shared deeper pattern with WFI-019 (re-review mode shipped without reconciliation against existing machinery) as a candidate follow-up WFI.

### WFI-019 — Draft / measurement / hooks-scripts
- **Problem:** After a clean provenance re-review PASS, `check-workflow-state` still exits 1 ("task plan hash is stale") — an honestly-built contract can never satisfy both hash validators.
- **Root Cause Hypothesis (paraphrase):** The state validator compares status-normalized hashes while the ledger validator pins raw bytes; post-implementation raw ≠ normalized, and the two validators were never reconciled for this case.
- **Depth verdict:** INTERMEDIATE-CAUSE
- **Missing why:** Why were they never reconciled? → The re-review procedure shipped with its primary path never exercised end-to-end, and no parity fixture binds the two validators' hash rules `(hypothesis)` — the patch widens acceptance but adds no such fixture/guard.
- **Outcome consistency:** Never advanced past Draft; the substance landed as orchestrator-applied commit `6e584411`, which worked — but the missing-regression-fixture gap remains.
- **Recommendation:** Re-analyze; draft a follow-up adding a post-implementation (raw≠normalized) regression fixture plus a cross-validator hash-semantics parity check; reconcile this WFI's status against `6e584411`.

### WFI-020 — Approved / plugin-improvement / instructions
- **Problem:** Three deterministic consumers could not associate quality-gate reports with their tasks (run record counted 1 of 5 gate runs), tripping retention conditions that set WFI-003/005/010 to Regressed.
- **Root Cause Hypothesis (paraphrase):** Not "no specification exists" (twice corrected by audit): a working, parity-tested template "was written, proven, and then disconnected", plus a false statement telling future authors it was never there; census: template+parity ≈99% compliance vs AGENTS.md prose ≈50%.
- **Depth verdict:** ROOT-CAUSE-REACHED
- **Outcome consistency:** Result pending, but the three Regressed predecessors corroborate its diagnosis that prose-only rules were symptom-level fixes. The audit-forced corrections are why-why analysis in action — two symptom-level drafts rejected before reaching the mechanism.
- **Recommendation:** No re-analysis — proceed to application; resolve the documented NO-PLUGIN-SCOPE-CREEP contradiction (a human decision).

### WFI-021 — Applied / plugin-improvement / architecture
- **Problem:** Independent workflow-state defects across features surfaced strictly one per ~21-minute CI round trip.
- **Root Cause Hypothesis (paraphrase):** Two compounding fail-fast decisions — first-diagnostic exit (correct within a feature, not across independent features) and a monolithic 65-step CI job — convert independent defects into a serial discovery queue.
- **Depth verdict:** ROOT-CAUSE-REACHED
- **Outcome consistency:** Applied and deterministically verified; the unaddressed CI job-structure cause is explicitly scoped out and recorded, not glossed.
- **Recommendation:** Ensure the deferred CI job-split cause gets its own tracked change.

### WFI-022 — Draft / plugin-improvement / tools
- **Problem:** The approval hook guard falsely refuses read-only greps, approval-removing seds, prose-quoting edits, and even the creation of the WFI document itself.
- **Root Cause Hypothesis (paraphrase):** The guard was written to answer "does this operation grant an approval?" but on two of its three paths actually answers "does this operation's text mention the approval field near a WFI path?" — Edit path omits the old_string operand; Bash path has no notion of direction or read-vs-write.
- **Depth verdict:** ROOT-CAUSE-REACHED
- **Outcome consistency:** Draft, Result pending — no outcome to contradict; the fix targets the semantic defect, not the symptoms.
- **Recommendation:** No re-analysis — advance to approval/application and execute the replay-based Verification Plan.

### WFI-023 — Applied / app-dev-efficiency / instructions
- **Problem:** Seven of eleven NEEDS_WORK rounds across two features were caused by sibling artifacts still asserting superseded facts after a decision was recorded in one place.
- **Root Cause Hypothesis (paraphrase):** Edits land only at the site the decision text names because nothing demands enumeration of the other sites; every restatement is a copy that goes stale.
- **Depth verdict:** INTERMEDIATE-CAUSE
- **Missing why:** Why do stale copies survive to review? → No deterministic check binds restatements to the governing artifact `(hypothesis)`; the WFI stops at an unenforced prose rule, though its own evidence base (WFI-020 census) shows prose ≈50% vs enforced mechanism ≈99% compliance.
- **Outcome consistency:** Applied, verification pending; the Regressed history of prose-rule WFIs (003/005/010) on adjacent classes makes a Regressed outcome plausible — a memory-dependent instruction mitigates rather than removes the identified cause.
- **Recommendation:** Re-analyze; draft a follow-up making the identifier sweep deterministic (pre-review sweep script or precheck gate), keeping the prose rule as interim mitigation.

### WFI-024 — Approved / plugin-improvement / tools
- **Problem:** Release-artifact validation (git-less checkout) fails with 21 false "reviewer manifest input hash is stale" diagnostics — the pin fallback is structurally unreachable without `.git`.
- **Root Cause Hypothesis (paraphrase):** `plugins_hash_matches` treats "the pin-fallback lookup could not be performed" and "lookup found no justification" as the same outcome (reject), silently redefining "not evaluable" as "failed".
- **Depth verdict:** ROOT-CAUSE-REACHED
- **Outcome consistency:** Approved with Verification Plan steps 1–4 executed including a mutation-proof; consistent, no detection power lost.
- **Recommendation:** No re-analysis — commit/push, confirm CI parity on both OS legs, record the SHA in the Rollback-Plan.

### WFI-025 — Draft / plugin-improvement / tools
- **Problem:** Task-stage provenance bindings over a status-mixed `tasks.md` break on every lifecycle flip, forcing costly rebinds (3 features hit attempts 5/3/5); the producer can only emit the one non-invariant digest form.
- **Root Cause Hypothesis (paraphrase):** The accepting side admits three transition-invariant digest forms, but the producing side emits only raw bytes; the extra forms were added to the acceptor without a corresponding producer change.
- **Depth verdict:** INTERMEDIATE-CAUSE
- **Missing why:** Why did the two surfaces drift invisibly? → No control asserts producer/consumer agreement on accepted binding forms (the two-surface drift pattern WFI-038 later names) `(hypothesis)`. The Proposed Change fixes the emission gap but not the missing parity control.
- **Outcome consistency:** Neutral — still Draft; the two BLOCKED audit attempts were orthogonal to causal depth.
- **Recommendation:** Keep the mechanism fix; re-analyze with a why-why chain terminating at the missing producer/acceptor parity control and add such a check for the digest-form contract.

### WFI-029 — Applied / plugin-improvement / instructions
- **Problem:** Three impl-review-loop instruction defects (SKILL omits `investigation.md` the downstream precheck requires; documented `--reset` path is a dead end post-Phase-2; legacy-design relief exists in reviewer A's role file only).
- **Root Cause Hypothesis (paraphrase):** Input contract written from reviewer's POV, validator from provenance POV, "nobody reconciled the two lists"; sibling-skill lessons never back-propagated.
- **Depth verdict:** INTERMEDIATE-CAUSE
- **Missing why:** Why is drift invisible until a live run? → No parity test compares skill instructions against the scripts they drive `(hypothesis)`. "Nobody reconciled" also edges toward a who-based stop rather than asking why no mechanism reconciles.
- **Outcome consistency:** Corroborates the verdict — the WFI's own Result records the drift class recurring against this very fix (stale `review-context-boundary.md` misled it into re-reporting a fixed defect; defect 4 authored 40 commits behind main).
- **Recommendation:** Re-analyze with a why-why chain; draft a follow-up WFI targeting a deterministic skill-vs-script contract parity control (WFI-038 pattern applied to SKILL manifest enumerations).

### WFI-034 — Applied (2 of 3 items) / plugin-improvement / architecture
- **Problem:** Evaluator and implementation agents shared one scratch directory; grader isolation held only by evaluator good behaviour.
- **Root Cause Hypothesis (paraphrase):** Isolation is enforced only at the declared-input layer; the launch contract never says where scratch space lives, so the guarantee is convention, not construction.
- **Depth verdict:** ROOT-CAUSE-REACHED
- **Outcome consistency:** Partially consistent — the auditability leg was deliberately dropped (#311), leaving isolation structural at launch time but unverifiable afterwards.
- **Recommendation:** Complete the #311 follow-up (recorded scratch root + deterministic overlap check) so the by-construction property the hypothesis demands actually exists.

### WFI-035 — Applied / plugin-improvement / tools
- **Problem:** The quality-gate cycle-limit counter escalated three never-gated tasks because it counts any report that merely mentions a task id.
- **Root Cause Hypothesis (paraphrase):** The counter substitutes full-text search for the report's own `Task ID:` identity header — it measures "reports that mention this task", and the failure is self-inflicting because the template mandates sibling cross-references.
- **Depth verdict:** ROOT-CAUSE-REACHED
- **Outcome consistency:** Strongly corroborates — Applied with both controls mutation-proven; prior point-patches (BL-001, #167) had treated symptoms, this fix replaced the wrong predicate itself.
- **Recommendation:** No action on the cause — complete the stated 10-run verification window to move to Verified.

### WFI-036 — Applied / plugin-improvement / architecture
- **Problem:** A gate cycle that fixes a defect cannot authorize its own fix for review — declaration rule and report-immutability rule are jointly unsatisfiable.
- **Root Cause Hypothesis (paraphrase):** Two individually correct rules leave no channel for post-fix bytes; the more effective the gate, the more artifacts become unreviewable.
- **Depth verdict:** ROOT-CAUSE-REACHED
- **Outcome consistency:** Corroborates — the append-only gate-authored channel dissolves the unsatisfiability rather than exempting a path; controls mutation-proven on the real blocked T-004 case.
- **Recommendation:** No re-analysis — finish the 10-cycle metric and re-gate T-002/T-003.

### WFI-037 — Draft / plugin-improvement / architecture
- **Problem:** The boundary reference prescribes a four-step ledger verification no role can perform, yielding identity-based BLOCKs and orphan reservations (seq 402, seq 795).
- **Root Cause Hypothesis (paraphrase):** Corrective guidance and the allowlist are two surfaces and only one was updated; the fix "was written where the diagnosis was written", and no test compares the two.
- **Depth verdict:** ROOT-CAUSE-REACHED
- **Outcome consistency:** Neutral (Draft, Result Pending) — but the Proposed Change already targets both the instance and the missing parity control.
- **Recommendation:** No re-analysis — proceed to audit/apply; implement the fabricated-`REVIEW_CONTEXT_OK` falsifiability control before claiming verification.

### WFI-038 — Applied / plugin-improvement / tools
- **Problem:** WFI-017's ratified legacy declaration grammar was taught to the report validator but not the review-context validator, making formally valid reports ungateable.
- **Root Cause Hypothesis (paraphrase):** "A contract change was applied to the producer's validator and not to the consumer's, and nothing compares the two" — when two surfaces must agree on a contract, something has to assert that they do.
- **Depth verdict:** ROOT-CAUSE-REACHED
- **Outcome consistency:** Corroborates — the shipped parity test is self-updating and mutation-proven; the Result honestly scopes what stays broken (separate identity-line gap).
- **Recommendation:** Draft a follow-up WFI generalizing the two-surface parity control to the other drifted pairs in this series (WFI-025's digest forms, WFI-029's skill-vs-script contracts).

## Follow-Up Recommendations

These are candidates, not Drafts: per the retrospective flow, a WFI is drafted
only from recurring evidence in a retrospective period, so the next
`workflow-retrospective` run should consume this list alongside its own
metrics. Ordered by expected value:

1. **Deterministic authored-report schema check (from 003 + 005 + 010, all
   Regressed).** Run the real consumer parsers (run-record emitter,
   retrospective rules, evidence-bundle checks) over authored reports at
   authoring/pre-gate time. This closes the shared root cause behind three
   regressions: prose identity-field rules enforced by nothing.
2. **Generalize WFI-038's two-surface parity control** to the other drifted
   contract pairs this review found: WFI-025's digest forms
   (producer/acceptor), WFI-029's skill-vs-script contracts, WFI-019's
   cross-validator hash semantics, WFI-002's precheck invocation contracts.
3. **Deterministic identifier-propagation sweep (from 023).** Convert the
   prose "sweep sibling artifacts" rule into a pre-review script/gate before
   it regresses like its prose-rule predecessors.
4. **Commit-scoped or machine-derived volatile claims in reports (from 006,
   Regressed).** Stop authoring claims a concurrent sibling task can
   invalidate; already flagged in the 2026-07-29 retrospective.
5. **Evidence-step idempotency + pre-gate cross-artifact consistency check
   (from 001, Regressed).**
6. **Mechanical SKIP-gate-flip detection in CI (from 015)** — skip-count /
   newly-run-test delta reporting.
7. **Git-trackedness check at evidence-bundle generation (from 008)** — the
   WFI itself flagged this follow-up; confirm it was drafted, create if not.
8. **Cross-platform case-sensitivity / self-match lint (from 012)** — when its
   horizon scores, convert the checklist into a scripted sweep.

Status hygiene (no new WFI needed):
- WFI-015: advance `Status:` to Applied to match its own Result (human action).
- WFI-018 / WFI-019: reconcile dangling Drafts against what actually landed
  (WFI-019's substance shipped as commit `6e584411`).
- Open Drafts (018, 019, 022, 025, 037) predate the `## Why-Why Analysis`
  section: on their next revision the wfi-audit-cycle's WHY-CHAIN-VALID check
  will require the chain — add it then; do not edit audited bodies outside the
  orchestrator.
