# Investigation: epic-195-a7-compatibility

Source: repository audit performed in worktree
`sdd-forge-wt-epic-195` (branch `feature/epic-195-a7-compatibility`) at
`main`-derived HEAD `b085ec7` (2026-07-19), cross-referenced against the
sibling worktrees for Epic A1 (`sdd-forge-wt-epic-189`,
`feature/epic-189-a1-project-context`), Epic A3 (`sdd-forge-wt-epic-191`,
`feature/epic-191-a3-path-ownership`), and Epic A5
(`sdd-forge-wt-epic-193`, `feature/epic-193-a5-capability-resolver`),
read-only, per the task's cross-epic consistency requirement.

## Context

`docs/ai-dlc-foundation-decision-v2.md` §4 (Q3) requires three compatibility
test kinds (byte-identical / structural / orchestration-event) and §19
Epic A7 requires the orchestration-event kind to be implemented as an
**extension of already-established loop infrastructure** — the
`loop-inventory/v1` registry, the shared loop driver, the
`loop-consistency` / `loop-escalation` suites, and `emit-run-record.sh` —
rather than a new test suite. None of Epic A1 (Project Context), Epic A2
(Capability Registry), Epic A3 (Component Path Ownership), or Epic A5
(Capability Resolver) is merged to `main` yet; each lives on its own
unmerged feature branch/worktree at spec- or task-review stage (Findings,
below). Epic A7's compatibility tests must therefore be specified so that
they are meaningful **today** (legacy behavior only exists) and become
progressively assertable as A1/A2/A3/A5 land, without requiring a second
spec pass.

## Findings

| ID | Finding | Severity | Evidence |
|----|---------|----------|----------|
| INV-001 | `tests/loops/loop-inventory.json` (`schema: "loop-inventory/v1"`) is the single machine-readable registry of all 8 review/gate loops (`spec-review`, `impl-review`, `task-review`, `domain-review`, `quality-gate`, `terminal-tier`, `wfi-audit`, `hitl-diagnosis`). Each entry carries `id / kind / cap / cap_source / cap_kind / driver_scripts / cross_gates / artifact_schemas / terminal / fixture_profiles`. There is no `capability`-related field on any entry today. | High | `tests/loops/loop-inventory.json:1-168` |
| INV-002 | The registration-forcing suite hardcodes the entry count: `jq -e '(.loops \| type) == "array" and (.loops \| length) == 8'`. Adding a **new** loop entry (a new `id`) to the registry would fail this assertion until the suite itself is edited; adding a new **field** to an existing entry does not. This is the concrete fork in the road between "new loop kind" and "capability event added to an existing loop" (design.md Design Decisions). This is a description of the suite's *current* assertion value, not itself a normative claim that `length == 8` must remain the registry's permanent invariant; `design.md`'s own Global Constraints ground the "no ninth loop for capability events" decision in the independent-lifecycle argument (Root cause / rationale, below), never in this assertion's present numeric value alone. | Critical | `tests/loop-inventory.tests.sh:129-133` |
| INV-003 | `tests/lib/loop-driver.sh` is the shared, source-style driver (never executed directly). Its public contract is fixed in its own header comment: `loop_fixture_init`, `drive_review_round`, `assert_prior_round_complete`, `assert_artifacts_schema`, `assert_terminal`, `assert_runtime_budget`, plus the environment variables `SDD_LOOP_REPO_ROOT` / `LOOP_INVENTORY_PATH` / `LOOP_FIXTURE_SEED`. `drive_review_round` dispatches by `stage` (`spec\|impl\|task\|domain`) to private `_loop_drive_*_round` functions; there is no `capability`/`resolver` stage today. | High | `tests/lib/loop-driver.sh:1-27` (public contract), `:1468-1488` (`drive_review_round` dispatch) |
| INV-004 | `assert_terminal <loop-id> <observed-state>` and `assert_artifacts_schema <dir>` both read directly from `LOOP_INVENTORY_PATH` (the same registry as INV-001), so any capability-event vocabulary added to the registry (INV-002) is automatically visible to both assertion helpers without touching their own code — the intended low-cost extension seam. Neither function returns or accumulates an event trace, however (INV-021): each is a single boolean comparison against one scalar/one artifact, not a producer of the ordered, multi-kind event sequence REQ-003 requires. | Medium | `tests/lib/loop-driver.sh:1493-1507` (`assert_artifacts_schema`), `:1512-1518` (`assert_terminal`) |
| INV-005 | `tests/loop-consistency.tests.sh` drives spec/impl/task/domain rounds end-to-end via the shared driver (TEST-008), locks a historical regression (TEST-009), and re-validates the bidirectional review-context-set invariant (TEST-010). `tests/loop-escalation.tests.sh` drives the quality-gate escalation chain and terminal-tier resume (TEST-011), a task-ID prefix-collision fixture (TEST-018), and a template↔validator parity extension (TEST-012). Both suites already accept `LOOP_INVENTORY_PATH`/`SDD_LOOP_REPO_ROOT` overrides and both already carry a `TEST-017` runtime-budget check, so a capability-event assertion added as a new numbered `TEST-0NN` case fits their existing pattern without a new file. | Medium | `tests/loop-consistency.tests.sh:1-39`; `tests/loop-escalation.tests.sh:1-60` |
| INV-006 | `plugins/sdd-quality-loop/scripts/emit-run-record.sh` already implements the exact "byte-identical unless a new flag is supplied" pattern Epic A7 needs: `emit_v2` starts at `0` (line 37), is set to `1` only when one of the `--effort-*` flags is parsed (lines 62-77), and the final `if [ "$emit_v2" = "1" ]` branch (line 185) either emits an additive `sdd-run-record/v2` object or falls through to an `else` branch whose heredoc is "intentionally an exact, unmodified copy of the pre-T-004 emission" (line 279-282), guaranteeing the no-flag path stays byte-identical to `sdd-run-record/v1`. | High | `plugins/sdd-quality-loop/scripts/emit-run-record.sh:30-43,62-77,185,245-304` |
| INV-007 | `tests/install.tests.sh` (1776 lines) and `tests/uninstall.tests.sh` (666 lines) already exercise install/uninstall determinism (fixture cloned via `git archive`, no network) but carry no concept of `project-context.yaml` or capability mode — they are the existing byte-identical-style baseline for the "install・uninstall結果" target named in decision doc §4.1, not yet parameterized by Project-Context presence/absence. | Medium | `tests/install.tests.sh:1-30`; `tests/uninstall.tests.sh` |
| INV-008 | ADR-0010 fixes the fixture-profile vocabulary as the closed set `greenfield \| brownfield` and the `cap_source` axis as `script \| skill-instruction`, and states extending the vocabulary requires an ADR revision, not an ad hoc addition. Any new fixture axis this epic introduces (the `capability_enforcement`-valued fixture matrix, now eight named rows plus a `PROJECT_CONTEXT_INVALID` variant per Context-present row, requirements.md REQ-005) is additive to, and independent of, this existing vocabulary — it must not be folded into `fixture_profiles` itself. | High | `docs/adr/0010-loop-inventory-and-fixture-vocabulary.md:34-84` |
| INV-009 | ADR-0016 redefines `disabled-legacy` as a **derived internal state** (not an enum value): when `project-context.yaml` is absent, "the Resolver, the Registry, the Gate stage machinery, and the effective enforcement `max()` computation do not run at all". This is the literal legacy code path the byte-identical test (decision doc §4.1) must exercise: zero capability-machinery invocation, not a low-severity capability evaluation. | Critical | `docs/adr/0016-workflow-axes-separation.md` Decision items 3-4 |
| INV-010 | ADR-0023 fixes the track-selection compatibility contract this epic must verify unchanged: when `project-context.yaml` is **absent**, the current priority order (CLI flag → `AGENTS.md` marker → default) is preserved unchanged. The current, pre-Epic-A1 priority order is documented today at `PLUGIN-CONTRACTS.md:63-65` (`--full` → FULL, `--lite` → LITE, `spec_profile: lite` marker → LITE) — this is the literal byte-identical/behavioral baseline for the Context-absent fixture. | High | `docs/adr/0023-track-selection-contract-migration.md` Decision items 1-2; `PLUGIN-CONTRACTS.md:63-65` |
| INV-011 | `docs/ai-dlc-foundation-decision-v2.md` §6's combination matrix names **eight** valid rows this epic's compatibility matrix must cover (two additional rows are explicitly marked `無効な組合せ`, invalid combinations, and are out of scope by construction) — not four, correcting a prior draft's under-count: `lite/lite-three-file/(non-active)` and `full/legacy-seven-layer/(non-active)` are both labeled "互換フォールバック（Context不在）" (compatibility fallback, Context absent, F1/F2); `lite/lite-three-file/advisory\|required` (F5/F6, "Lite許可/Lite専用GateのCapability" rows); `full/legacy-seven-layer/advisory\|required` is labeled "移行互換モード" (migration-compatible mode, Context present, F3/F4); `full/facet-hybrid/required` is "推奨モード" (F7); `full/facet-native/required` is "将来の標準モード" (F8). requirements.md REQ-005/design.md's Compatibility Matrix (AC-028) enumerate all eight (F1–F8), building F1–F4 in this epic's own Phase 2/3 increment and recording F5–F8 as `SKIP`/`N/A` with a stated rationale rather than omitting them. | High | `docs/ai-dlc-foundation-decision-v2.md:207-219` |
| INV-012 | §19 Epic A1 confirms track-selection migration and the compatible-caller contract are **Epic A1 deliverables**, not this epic's own implementation; §19 Epic A7 confirms this epic's own scope is the three test kinds themselves, built on top of that (eventual) migration. | Medium | `docs/ai-dlc-foundation-decision-v2.md:522-524,544-545` |
| INV-013 | Cross-epic (Epic A1, unmerged, `sdd-forge-wt-epic-189`): REQ-009 is the track-selection contract migration; a Project Context that fails validation stops with the named `PROJECT_CONTEXT_INVALID` error rather than falling back to "no Project Context" — this is a **third** distinguishable orchestration outcome (beyond byte-identical-fallback and event-identical-capability-mode) that the orchestration-event test's fixture matrix must be able to represent even though the mechanism that raises it does not exist on `main` yet. | High | `specs/epic-189-a1-project-context/requirements.md:882` (REQ-009), `:2156` (B5 risk row naming `PROJECT_CONTEXT_INVALID`), `:1972-1985` (five A1-time consumer call sites, all sharing the identical absent→fallback / present→validate-then-trust rule) — read from sibling worktree `sdd-forge-wt-epic-189` |
| INV-014 | Cross-epic (Epic A3, unmerged, `sdd-forge-wt-epic-191`): `check-component-coverage.py`'s design fixes an exact 3-state pattern (`disabled-legacy` → zero evaluation + a real, truthful `state: "not-applicable (disabled-legacy)"` evidence record, exit 0; `advisory` → full evaluation, non-blocking; `required` → full evaluation, blocking). **This pattern is scoped to `check-component-coverage` itself** — an always-running, evidence-emitting Implementation Gate check item — not a claim that every future capability-derived Gate, nor the Capability Resolver, must share the identical shape. The Resolver (Epic A5, INV-015) is architecturally *outside* `disabled-legacy`'s computational domain (ADR-0016 item 4) and is never invoked at all in that state; it has no analogous "always run, always emit an N/A evidence record" step. This epic's orchestration-event trace therefore fixes two independent, component-scoped expectations rather than one generalized shape: the component-coverage Gate emits a present `state: "not-applicable (disabled-legacy)"` evidence event in `disabled-legacy`, while the Resolver emits no invocation event at all in that same state — both are simultaneously true and do not conflict once scoped per-component. | High | `specs/epic-191-a3-path-ownership/design.md:87-99,373-380,447-453,682-707` — read from sibling worktree `sdd-forge-wt-epic-191`; `disabled-legacy-invocation` row, Epic A5's own Block taxonomy — see `FP-A5-DISABLED-LEGACY-ROW` (design.md Design Decisions "Cross-epic fingerprint citations": `specs/epic-193-a5-capability-resolver/requirements.md:355`, `sha256:4b776b1142cfd4a973a88706b43531f720bc0d9235fb4cc58abe21571d6c7129`, at sibling worktree `sdd-forge-wt-epic-193` HEAD `748f40ccb713`; NEW-001 found the earlier `requirements.md:334-349` locator had already drifted from the row's actual current location, `requirements.md:355`, with the table's own opening at `requirements.md:341`) |
| INV-015 | Cross-epic (Epic A5, unmerged, `sdd-forge-wt-epic-193`): REQ-002 defines a closed Block-diagnostic taxonomy for the (future) Resolver; one named diagnostic, `disabled-legacy-invocation`, is explicitly framed as "a CLI-misuse guard, not a designed pipeline state" — A5's own text states "a compatible caller (REQ-007) never invokes this Resolver's own process while a Project Context is absent or derives `disabled-legacy`". The compatibility-relevant assertion is therefore an **absence** assertion (no Resolver subprocess call observed in the event trace when Context is absent), not a Resolver-output assertion. | Critical | `FP-A5-DISABLED-LEGACY-ROW` (design.md Design Decisions "Cross-epic fingerprint citations": `specs/epic-193-a5-capability-resolver/requirements.md:355`, `sha256:4b776b1142cfd4a973a88706b43531f720bc0d9235fb4cc58abe21571d6c7129`) — read from sibling worktree `sdd-forge-wt-epic-193` |
| INV-016 | Cross-epic (Epic A5, unmerged): A5's own design explicitly defers the live caller-integration contract test (`resolve-project-context-caller-contract`) to "a future task, Non-goals" — i.e. A5 fixes the fixture-level contract at design time but does not itself author the suite. That future suite's own techniques are directly reusable by this epic: (a) an anchor-fingerprint drift check (sha256 of a fixed line window in the live `SKILL.md`, plus that heading's ordinal position among all headings) rather than a bare "heading text still exists" check, and (b) a spy-harness fixture proving a Context-absent invocation never calls the capability subprocess at all (event-identical to today's flow). This package's own `design.md` now fixes this epic's existing orchestration-event suite (not a new suite file) as the home for exactly these three fixture-level assertions ((a)/(b)/(c) above), authored as `TEST-0NN` cases once the capability interview phase is implemented (requirements.md OQ-001, resolved) — never a distinct future task guessed at implementation time. | High | `FP-A5-CALLER-CONTRACT-10` (design.md Design Decisions "Cross-epic fingerprint citations": `specs/epic-193-a5-capability-resolver/design.md:1886-1915`, item 10, `resolve-project-context-caller-contract`, sub-items a/b/c, `sha256:9b549be9c9d8897c9efd1badbab8a5d4184086649e98a3c31325ef3210561bff`, at sibling worktree `sdd-forge-wt-epic-193` HEAD `748f40ccb713`) — read from sibling worktree `sdd-forge-wt-epic-193`. **NEW-001 (adversarial review finding)**: an earlier draft cited this same item as `design.md:1861-1890`, which had already drifted to the wrong content (item 10 begins at `:1886`, not `:1861`) by the time of that review — the concrete failure that motivated replacing every such normative cross-epic citation with a recomputable fingerprint rather than a bare line-number locator (design.md Design Decisions). |
| INV-017 | Grep confirms none of `capability_enforcement`, `disabled-legacy`, or `project-context.yaml` appears anywhere under `plugins/`, `scripts/`, `contracts/`, or `tests/` in this worktree (`main` baseline): `grep -rln "capability_enforcement\|disabled-legacy\|project-context.yaml" plugins/ scripts/ contracts/ tests/` returns no matches. Likewise `resolve-project-context*` and `check-component-coverage*` do not exist anywhere in this worktree (`find . -iname "resolve-project-context*" -o -iname "check-component-coverage*"` returns no matches). The capability machinery this epic's compatibility tests describe is entirely forward-looking relative to `main`. | Critical | grep/find evidence, this worktree, 2026-07-22 |
| INV-018 | `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`'s own "Required Outputs" section lists the full-profile Phase 1 output set as **seven** mandatory Markdown files (`requirements.md`, `acceptance-tests.md`, `design.md`, `ux-spec.md`, `frontend-spec.md`, `infra-spec.md`, `security-spec.md`) plus Phase-2 `tasks.md`/`traceability.md`; `plugins/sdd-bootstrap/scripts/check-sdd-structure.sh`'s feature-mode check enforces the same nine-file set. This epic's own package (four files: `investigation.md`/`requirements.md`/`design.md`/`acceptance-tests.md`, no layer specs, no Phase 2) is a deliberate, explicitly-scoped deviation from that default per this task's own Phase-1-only mandate, not an oversight — recorded as a Risk (requirements.md) because a literal `check-sdd-structure.sh <root> epic-195-a7-compatibility` run would report the four layer files and two Phase-2 files as `missing:`. | Medium | `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:116-141`; `plugins/sdd-bootstrap/scripts/check-sdd-structure.sh:71-78` |
| INV-019 | `AGENTS.md`'s "Spec factual-claim evidence citations" rule (WFI-011) requires every checkable factual claim in `investigation.md`/`requirements.md`/`design.md` to cite the specific grep/file:line evidence it rests on, in the document itself — the citation convention this investigation follows throughout. | Medium | `AGENTS.md:137-145` |
| INV-020 | `specs/workflow-state-registry.json`'s schema (`contracts/workflow-state-registry.schema.json:459-497`) accepts a minimal full-profile entry of exactly `{"feature": "<slug>", "profile": "full"}` (`additionalProperties: false`); no `legacy` block is required for a fresh, non-migrated feature. `specs/local-env-mcp` is an existing example of this minimal shape. | Low | `contracts/workflow-state-registry.schema.json:459-476`; `specs/workflow-state-registry.json` (`local-env-mcp` entry) |
| INV-021 | Neither `tests/lib/loop-driver.sh` nor `tests/loop-consistency.tests.sh`/`tests/loop-escalation.tests.sh` collects an ordered, multi-kind orchestration event trace today: `drive_review_round` dispatches by `stage` and returns a single pass/fail exit code per round (no event list returned or accumulated), `assert_terminal` compares one scalar `.terminal.state` string per loop-id, and `assert_artifacts_schema` checks one artifact's `.schema` field against a known-set — none of the three represents skill-invocation order, approval-checkpoint identity, a Done-transition's own timing, or a skip/stop message's own text as a comparable, orderable event. Decision doc §4.3's six named observables (呼び出されるskillの順序 / review loopの有無 / approval checkpoint / quality gate / Done遷移 / skip・stop message) therefore have no existing producer or comparison oracle to extend today; a versioned event-trace schema (this package's own addition, not an existing artifact) is a precondition for REQ-003, not merely a naming decision about which existing suite gets a new assertion. | Critical | `tests/lib/loop-driver.sh:1468-1488` (`drive_review_round` dispatch), `:1493-1507` (`assert_artifacts_schema`), `:1512-1518` (`assert_terminal`); `docs/ai-dlc-foundation-decision-v2.md:147-149` (§4.3 six-observable list) |
| INV-022 | A golden-baseline capture contract that names no fixed script path/filename, no manifest format, and no separation between a locally-regenerable *candidate* baseline and the committed *canonical* one is unable to prevent baseline pollution: a single `--write`-flagged script that both diffs and (when passed) overwrites the same committed file lets any agent or CI job with repository write access silently update the file the byte-identical test trusts. Anchoring the first capture to "the `main` commit current when Phase 2 starts" is a second pollution vector distinct from the update-flow one: per decision doc §20's stated build order, Epic A1 merges before this epic's Phase 2 begins, so "current at capture time" can already include A1's own changes — silently blessing any Context-absent regression A1 introduces as the new legacy baseline, rather than pinning the baseline to a fixed, named, pre-capability commit. | Critical | `docs/ai-dlc-foundation-decision-v2.md:140-142` (§4.1, the exact byte-identical target list the baseline must pin), `:544-545` (§19, Epic A0's stated build order preceding A1) |
| INV-023 | A `SKIP` governance rule that only degrades an upstream-dependent assertion to `SKIP` while its dependency is unmerged, with no reverse check, is fail-open by construction: nothing forces a suite failure if a `SKIP` line still fires after its cited epic has actually merged (a stale/forgotten SKIP), if an unrecognized `SKIP` message appears anywhere in suite output (a typo or an un-audited later addition), or if the cited upstream contract has drifted from what this package's own citation records (fingerprint drift). Enumerating only Epic A1/A2/A3/A5 as upstream dependencies is also incomplete: Epic A4 (Facet Manifest, issue #192) is the dependency AC-007's Facet-reference assertion names directly, and Epic A6 (Lite integration, issue #194) is the dependency the `lite`/`capability_enforcement`-present fixture-matrix rows (decision doc §6) require before they can be asserted rather than SKIPped. | High | `specs/epic-192-a4-facet-manifest/requirements.md:1-6` — read from sibling worktree `sdd-forge-wt-epic-192`; `specs/epic-194-a6-lite-integration/requirements.md:1-7` — read from sibling worktree `sdd-forge-wt-epic-194`; `docs/ai-dlc-foundation-decision-v2.md:207-219` (§6 combination matrix) |
| INV-024 | `plugins/sdd-lite/skills/lite-spec/SKILL.md`'s own `## Process` section fixes the LITE track's exact three-file generation set: `requirements.md` (`templates/requirements-lite.md`), `design.md` (`templates/design-lite.md`), `tasks.md` (`templates/tasks-lite.md`) — distinct from `sdd-bootstrap-interviewer`'s own seven-file `full`-track set (INV-018). `PLUGIN-CONTRACTS.md`'s own track-selection contract confirms LITE routes generation to `lite-spec`, not `sdd-bootstrap-interviewer`, once track selection resolves LITE (CLI flag / `AGENTS.md` marker / default priority order, ADR-0023). This is the concrete, citable "lite-three-file" file set an earlier draft's F2 Compatibility Matrix row needed but did not cite, mistakenly reusing AC-005's `full`-track legacy-seven-layer expectation for the `lite` track instead (design.md Compatibility Matrix). It also means F2's own REQ-002 structural assertion is assertable **now** (existing, unmerged-epic-independent legacy behavior), never an Epic-A6-gated `SKIP`. | High | `plugins/sdd-lite/skills/lite-spec/SKILL.md:54-61`; `PLUGIN-CONTRACTS.md:64-65,72` |

## Root cause / rationale for an extension-only design

Decision doc §4.3 and §19 both state the orchestration-event test must be
built as capability-event additions to already-existing infrastructure
rather than a parallel suite, to avoid the exact risk ADR-0010 names for
fixture vocabularies: "a separate harness inventing its own incompatible
vocabulary" (ADR-0010 Context, item 3). INV-002 shows precisely which
existing assertion (`loops | length == 8`) would need to change if this
epic added a new loop *kind*, versus which additions (new optional fields
read generically by `assert_terminal`/`assert_artifacts_schema`, INV-004)
require no such change. This is the basis for design.md's decision to
extend existing loop entries and `emit-run-record.sh`'s already-proven
additive-flag pattern (INV-006) rather than register a ninth loop.

## Safety constraints

- Do not modify `plugins/**`, `scripts/**`, `.github/**`, `tests/**`,
  `contracts/**`, or `docs/**` in this task (Phase 1, spec-only). Every
  file:line citation above is read-only evidence, not a change made by
  this task.
- Do not treat any cross-epic (A1/A3/A4/A5/A6) file cited above, or any
  fingerprint digest design.md's own allowlist manifest records against
  one of them, as merged or stable; they are unmerged specs on sibling
  feature branches and may change before this epic's own Phase 2/3
  begins. Re-verify before authoring tests against them — recomputing a
  recorded fingerprint's own digest against the cited epic's then-current
  HEAD (design.md Design Decisions "Cross-epic fingerprint citations") is
  the mechanical form this re-verification takes, closing the drift
  NEW-001 found in an earlier draft's bare line-number citations.
- Do not fabricate current capability-machinery behavior: per INV-017, no
  such machinery exists on `main` today, so every orchestration-event
  assertion this epic specifies for the "Context present" fixture states
  is necessarily a forward-looking contract, not an assertion against
  code that exists yet.
- Preserve the existing 8-entry `loop-inventory/v1` registry and its
  registration-forcing suite (INV-001, INV-002) exactly as-is in this
  spec-only phase.

## Amendment Re-Review Context

This package is in a declared amendment re-review context: its Phase 1
documents were amended after this epic's implementation phase ran, the
amendments are human-approved, and this entry — committed into the
hash-pinned, review-pinned package — is the durable, citable approval
record.

### Human approval (verbatim, dated)

- 2026-08-23: 「194/195/196の凍結文書について人間は承認する」 — the
  human's approval of the frozen-document amendments for epics 194, 195,
  and 196, given as the authorization for re-running the affected review
  stage against the amended documents at a new attempt.
- 2026-08-23: 「限定デプロイ + WFI 起票でやれ」 — the human's follow-on
  instruction authorizing the limited deployment of the amendment
  re-review lane for epic-195 and epic-194, plus a WFI filing for the
  durable mechanism.

Because these approvals were given in conversation, this committed entry
is itself the durable record of them; no other citable artifact carries
them.

### Amendment commits (full hashes) and amended-document SHA-256 values

- `7652d01b3a152863afefd38bd11e1bac5767e3de` — reworded the
  acceptance-tests.md AC-009/TEST-009 row (folding AC-009's byte-identity
  lock around the sanctioned `_loop_trace_emit
  done-transition:assert-terminal` call) and applied the matching
  `tests/lib/loop-driver.{sh,ps1}` /
  `tests/loop-inventory.tests.{sh,ps1}` re-baseline. As of this commit,
  `specs/epic-195-a7-compatibility/acceptance-tests.md` =
  `54f6ace65a05570cb8b81a418a5c597bd10ba47c10ebc9c20f97ae5de4c60992`.
- `a5681c67d9453d4c92e6f6446d8b3959094c215d` — completed that amendment
  across both documents (spec-review attempt 3 rounds 1-3 remediations:
  requirements.md AC-009 aligned with TEST-009; TEST-009's dangling
  cross-references replaced by explicit hash values and in-repo
  locations; first, narrative form of the Overview/Non-goals note). As
  of this commit, `specs/epic-195-a7-compatibility/requirements.md` =
  `fc5f9ffe66edb9c94c865193e8bca9565eb24e91e7fcf55dba354e883106a505` and
  `specs/epic-195-a7-compatibility/acceptance-tests.md` =
  `d982efe1eef57b5efdb42c1e40398ee3cd27ec4790da1c9914f0a78b17a09d04`.
- `27843332c6f07f6286111ebb90b6a900a0385089` — repointed the
  Overview/Non-goals amendment note at this entry (pointer form). As of
  this commit, `specs/epic-195-a7-compatibility/requirements.md` =
  `b302af8dabdee7c59a797d3cf3b25d25937da41313f865a67738ae7c40902811`.
- This entry is itself an amendment to
  `specs/epic-195-a7-compatibility/investigation.md`. Its own
  post-amendment SHA-256 cannot be cited from inside itself; per the
  calibration's "as applicable" scope it is pinned externally by the
  attempt-4 reviewer invocation manifests
  (`reports/review-context/pending-epic-195-a7-compatibility-spec-reviewer-{a,b}-seq*-manifest.json`)
  and by the identity ledger records those reservations append. The
  pre-amendment investigation.md (as of both amendment commits above) =
  `8b1ac3aba8b41e9bb1d053755f9e735b97af293c6be513ddb14d99dd7d5a353b`.

### Later-phase artifacts this package references (commit / SHA-256)

The amended requirements.md (Overview/Non-goals note) and
acceptance-tests.md (TEST-009 row) reference the following later-phase
artifacts; every reference is carried here with a commit hash or SHA-256
fingerprint, never as a bare path:

- `specs/epic-195-a7-compatibility/tasks.md` — SHA-256
  `80dba0cd7dea38fa6047a238acb6500048074a9cf5141fccff09cf0da444e3fd`,
  last amended in commit `6b4e87ba095a565cce1833fcacecc03571665229`.
  Defines T-005 and T-006, the implementation cycle TEST-009's
  provenance note names.
- `specs/epic-195-a7-compatibility/traceability.md` — SHA-256
  `d40e35c3a9c67c3b6a9ad604aebb89ecd172ca50d0141d4d9d0535c341708f5f`;
  `specs/epic-195-a7-compatibility/traceability.json` — SHA-256
  `53293b9f82198dad9bba4c433e7d82af9f06d7fe8920526d1267063c8c21f9da`.
- `specs/epic-195-a7-compatibility/design.md` — SHA-256
  `2e7c0c46d97371565ad93b1e097dcccb9dcdbbb3d15faf6b949584433fd18f78`
  (the per-kind producer table AC-009 and AC-026 cite).
- `tests/loop-inventory.tests.sh` — SHA-256
  `ba8fca9efbb1854d30cac5766e0d0a1e2c981d40f70587aee5339a05347433b4`;
  records `EXPECTED_TERMINAL_SHA` =
  `f325a4df4a276cf4a4bc7a4051032693cceb6bff6db99fce27eb4b13b18473df`,
  the `assert_terminal` function-body hash TEST-009 declares as its
  binding truth condition (re-baselined in commit
  `7652d01b3a152863afefd38bd11e1bac5767e3de`).
- `tests/loop-inventory.tests.ps1` — SHA-256
  `2b971e92e512c8c97dbb00e9c62a4a55093de42fc704274a22d26b2216e09a54`;
  records the `Test-LoopTerminal` function-body hash
  `460467af4a0b89af0b1cc0cb1ec94aa022dec00a81abbcd00924288727367757`
  (same commit).
- `tests/lib/loop-driver.sh` — SHA-256
  `8ae3cc282785a7f352c1d1a99ee2e98d67e0fdfb1577661a2a6de80007dc9789`;
  `tests/lib/loop-driver.ps1` — SHA-256
  `b90c84bfffda9f31eae3cdb6ee146c1f9fd69782fe1a0c041de3bdddfee15fb9`
  (hosts of `assert_artifacts_schema` / `assert_terminal` /
  `Test-LoopTerminal`; the one sanctioned `assert_terminal` change
  landed in commit `7652d01b3a152863afefd38bd11e1bac5767e3de`).

### Scope

This entry documents amendment lineage and authorization; it waives no
review finding. Every check other than the phase-sequencing basis the
calibration's Amendment Re-Review Context section describes is judged
exactly as it would be without this entry.

### Round-2 extension (2026-08-24): AC-010 named-SKIP disposition

- Human ruling (verbatim, dated): 2026-08-24 「①でやれ」 — "do option 1",
  where ① in the decision presented to the human referred to the
  named-SKIP disposition for AC-010/TEST-019: TEST-019 gains the same
  "named SKIP entry in REQ-007's allowlist ... until Epic A1 merges"
  clause every sibling Context-present AC (AC-007, AC-019-AC-021,
  AC-042, AC-043) carries, the omission being an authoring gap rather
  than a deliberate exception.
- Amendment commit (full hash):
  `47cb338ae8e748761ae793c38a02e1f77fb38df4` — adds the named-SKIP
  clause to requirements.md AC-010 (the AC-042-form sentence) and to the
  acceptance-tests.md AC-010 row (Test Type "integration (named SKIP,
  allowlist-governed, until Epic A1 merges)"; REQ-007 added to the
  Requirement column), mirroring the sibling rows exactly. As of this
  commit, `specs/epic-195-a7-compatibility/requirements.md` =
  `f2343a1c0977aecc6970c2cb42d8fa9c9cb677cf11ff5ef35fb6fa38df9364d2`
  and `specs/epic-195-a7-compatibility/acceptance-tests.md` =
  `7f17001714aac9fcd78ca2093a340a7f1e6e557c7d80338b8db216a7aa4966e8`.
- This extension is itself a further amendment to investigation.md; as
  stated above for this entry, its own post-amendment SHA-256 cannot be
  cited from inside itself and is pinned externally by the attempt-4
  round-2 reviewer invocation manifests and the identity-ledger records
  their reservations append.

### Impl-round-2 extension (2026-08-24): design.md Global Constraints pointer

- Amendment commit (full hash):
  `41dac120d31a5d7fe6efd5161460e727ff79fc7b` — adds the dated
  amendment-note pointer to design.md's `## Global Constraints` section,
  mirroring the treatment the human-approved amendment already gave
  requirements.md's Overview/Non-goals: the original constraint text
  ("No edits to ... `tests/**` ..."; "No tasks.md/traceability.md in
  this Phase 1 package") is retained unchanged as an authoring-time
  record, and the note points at this entry as the authoritative
  framing. This closes impl-review attempt 3 round 1's
  NO-REQ-CONTRADICTION finding (design.md was the one package document
  the amendment's reconciling pointer never reached). design.md thereby
  joins the amended-document set of this entry. As of this commit,
  `specs/epic-195-a7-compatibility/design.md` =
  `3dacbe7afb64cd3f3420fd763ee6bf24ab5fff6bde8c44fd0e363f934cc40383`.
- Authorization: completion of the same human-approved amendment quoted
  verbatim at the top of this entry (2026-08-23 approvals); no new
  approval statement was issued for this propagation step.
- This extension is itself a further amendment to investigation.md; as
  stated above for this entry, its own post-amendment SHA-256 cannot be
  cited from inside itself and is pinned externally by the impl-review
  attempt-3 round-2 reviewer invocation manifests and the
  identity-ledger records their reservations append.

### Spec/impl/task re-bind extension (2026-08-25): AC-009 propagated to its eleven sibling statements

- Human rulings (verbatim, dated). Both were given in conversation, so this
  committed entry is itself the durable record of them:
  - 2026-08-25: 「① 8 箇所に波及させる（推奨）」 — authorizing propagation of
    the AC-009 amendment to every sibling statement in the package that
    still asserted the pre-amendment fact, and accepting the cost that
    doing so re-stales the stages those documents are pinned by.
  - 2026-08-25: 「② 記録し、コードは触らない（推奨）」 — directing that the
    `done-transition` ordering defect confirmed by both cross-model
    panelist slots be recorded rather than fixed, because the fix would
    change `assert_terminal`'s body and re-baselining its hash to match
    that edit is the retrofit this entry's own history already records.
- Amendment commit (full hash):
  `99c74ff78cc4ec0548028652d429aca66ebb2c32` — propagates the AC-009
  amendment to the eleven statements that still described
  `assert_terminal` as unmodified or byte-identical to its pre-task form:
  four in tasks.md (T-005's Planned Files, Goal, Must Read, Done When),
  five in design.md (the Components table, the Data Plan additive-field
  paragraph, the `assert_capability_applicability` contract, the AC-009
  restatement, the Constraint Compliance table), and two in
  security-spec.md (the B2 boundary's own Validation column, and the Test
  Strategy row for items 5 and 7). Each corrected statement now names
  `assert_artifacts_schema` and `assert_terminal` separately and states
  what is true of each, following the wording requirements.md's own
  amended AC-009 already carried. As of this commit,
  `specs/epic-195-a7-compatibility/design.md` =
  `04a124d6d56298cc1b2ff63f2eacd21c75c615a781e220d0ad37513636fe9dfc`,
  `specs/epic-195-a7-compatibility/security-spec.md` =
  `4b31d724cd326ee89b87de867e0f857cf2b7ca69d794956ebb7ce4edc6ff8d31`, and
  `specs/epic-195-a7-compatibility/tasks.md` =
  `d3b3fdcd51449ad4ebb8a56010b6d8f5b33d718e9fdaa0286656e3051eca4f97`.
- `specs/epic-195-a7-compatibility/security-spec.md` thereby joins the
  amended-document set of this entry. It had not appeared in this entry
  before this extension, which mattered: its two statements asserted the
  falsified fact as a security control, and a document the amendment
  changed being absent from this entry's tracked artifacts would by itself
  have left the declaration incomplete.
- Superseded fingerprints. Each is superseded by appending here and naming
  what it replaces; no earlier block in this entry is rewritten, so this
  extension deletes nothing:
  - `design.md` = `3dacbe7afb64cd3f3420fd763ee6bf24ab5fff6bde8c44fd0e363f934cc40383`,
    recorded above under "Impl-round-2 extension (2026-08-24)", is
    superseded by `04a124d6d562...` as of `99c74ff78cc4ec0548028652d429aca66ebb2c32`.
  - `tasks.md` = `80dba0cd7dea38fa6047a238acb6500048074a9cf5141fccff09cf0da444e3fd`,
    recorded above under "Later-phase artifacts this package references",
    is superseded by `d3b3fdcd5144...` as of the same commit.
  - `traceability.md` = `d40e35c3a9c67c3b6a9ad604aebb89ecd172ca50d0141d4d9d0535c341708f5f`
    is superseded by
    `2bcd0a75250e235eca6fdf95f28a444d41e9e0898b1179b6dab9fdb2fee079e8`, and
    `traceability.json` = `53293b9f82198dad9bba4c433e7d82af9f06d7fe8920526d1267063c8c21f9da`
    is superseded by
    `700abeeb7533e34652a43d3c5bc943292dfa403504d3f7702af2c915e7ad55bd`.
    Both went stale in commit
    `3bc2368ac037c598d760f8f704ac5edee315a62d` (the task-review attempt-5
    round-2 PASS), before and independently of this session's amendment;
    they are corrected here because this entry states them as present-tense
    fingerprints, not because this amendment changed either file.
- Still current, unchanged by this amendment and re-verified at this
  commit: `tests/lib/loop-driver.sh` =
  `8ae3cc282785a7f352c1d1a99ee2e98d67e0fdfb1577661a2a6de80007dc9789`,
  `tests/lib/loop-driver.ps1` =
  `b90c84bfffda9f31eae3cdb6ee146c1f9fd69782fe1a0c041de3bdddfee15fb9`,
  `tests/loop-inventory.tests.sh` =
  `ba8fca9efbb1854d30cac5766e0d0a1e2c981d40f70587aee5339a05347433b4`, and
  `tests/loop-inventory.tests.ps1` =
  `2b971e92e512c8c97dbb00e9c62a4a55093de42fc704274a22d26b2216e09a54`, together with the
  `EXPECTED_TERMINAL_SHA` / `Test-LoopTerminal` function-body hashes those
  two suites record.
- Listed so it is visibly considered rather than silently missing from the
  completion chain: commit
  `6f1e093880ff3225827a55e1f5dc6f80188dcd73`, made in the same session
  immediately before the propagation, amended no frozen Phase 1 document.
  It changed implementation reports, verification contracts and recaptured
  evidence logs, two test suites, and one plugin script. It is therefore
  not an amendment commit of this entry's chain, and no document fingerprint
  in this entry moved because of it.
- This extension is itself a further amendment to investigation.md; as
  stated above for this entry, its own post-amendment SHA-256 cannot be
  cited from inside itself and is pinned externally by the spec, impl and
  task re-review reviewer manifests taken against it and by the
  identity-ledger records their reservations append.

### Round-3 extension (2026-08-25): the propagation's scope named explicitly as eleven sites

- Human ruling (verbatim, dated): 2026-08-25:
  「① 11 箇所を名指して授権する（推奨）」 — authorizing the AC-009
  propagation at its actual scope of eleven named sites: four in
  `tasks.md` (T-005's Planned Files, Goal, Must Read, Done When), five in
  `design.md` (the Components table, the Data Plan additive-field
  paragraph, the `assert_capability_applicability` contract, the AC-009
  restatement, the Constraint Compliance table), and two in
  `security-spec.md` (the B2 boundary's Validation column, and the Test
  Strategy row for items 5 and 7).
- This ruling supersedes **in scope** the earlier approval quoted above in
  the "Spec/impl/task re-bind extension (2026-08-25)" sub-entry,
  「① 8 箇所に波及させる（推奨）」. That quotation said eight and meant
  eight. The eight was a reviewer's estimate of how many sibling
  statements existed; the true set was established afterwards by
  exhaustive enumeration of every line in `tasks.md` and `design.md`
  mentioning `assert_terminal`, `Test-LoopTerminal`,
  `assert_artifacts_schema`, `Test-ArtifactsSchema` or `AC-009`, and by a
  wider sweep across sibling documents. The two sites the estimate missed
  are both in `security-spec.md`, where the falsified fact was stated not
  as prose but as a security control.
- The earlier sub-entry's gloss broadened that eight-site quotation to
  cover eleven. That was not sufficient, and this entry does not repair it
  by rewriting it. Spec-review attempt 6 round 1 reviewer B (ledger
  sequence 786) recorded the discrepancy as a Critical `CONTRADICTION`
  finding, holding that the calibration's evidence bar requires the
  verbatim quotation itself to authorize the amendment's actual scope
  rather than a paraphrase that expands it after the fact. That reading is
  correct and is the reason this ruling exists.
- Amendment commit already on record for the propagation itself:
  `99c74ff78cc4ec0548028652d429aca66ebb2c32`, whose per-document
  post-amendment SHA-256 values are recorded in the preceding sub-entry.
  This ruling adds authorization for that commit's actual scope; it
  changes no document byte of its own.

### Round-3 extension (2026-08-25): AC-026's ordering defect tracked in requirements.md

- Human ruling (verbatim, dated): 2026-08-25:
  「① requirements.md に追跡を追加する（推奨）」 — directing that the
  `done-transition` ordering defect be tracked in `requirements.md`
  itself, rather than existing only in this investigation.md entry.
- Substance recorded there: `AC-026`'s ordering rule ("always the last
  event in the round's own event sub-sequence") is not satisfied by the
  implementation `AC-009` pins, because `assert_terminal` /
  `Test-LoopTerminal` emits the event before verifying the observed
  terminal state and emits nothing on either early return; both
  cross-model panelist slots found this independently; and it is
  deliberately not fixed in code because the fix changes a function body
  whose hash `AC-009` pins, so it resolves only together with a formal
  amendment of that hash.
- Recorded as `OQ-004 (open)` in `requirements.md`'s Open Questions and as
  a `High` entry in its Risks register. Both placements are deliberate:
  spec-review attempt 6 round 1 reviewer A (ledger sequence 785) named the
  Risks register and reviewer B (ledger sequence 786) named
  Assumptions/Open Questions, each independently, so the tracking was
  added where each reviewer looked. The stated purpose in both places is
  reviewer A's: a verifier reading `AC-026` in isolation must be able to
  learn from `requirements.md` alone that a test asserting that ordering
  rule is expected to fail for a known, deliberately unaddressed reason.
- As of this amendment, `specs/epic-195-a7-compatibility/requirements.md` =
  `bc596b776cc08b7a5479be198a18c942ea715f89e3bdd25af35f6d3460f2400f`. This
  supersedes `f2343a1c0977aecc6970c2cb42d8fa9c9cb677cf11ff5ef35fb6fa38df9364d2`,
  recorded above as of commit
  `47cb338ae8e748761ae793c38a02e1f77fb38df4`.
- This extension and the `requirements.md` amendment it describes are made
  in a single commit, so that commit's own hash cannot be cited from
  inside itself; as stated above for this entry, it is pinned externally
  by the spec-review attempt-6 round-2 reviewer manifests and by the
  identity-ledger records their reservations append. The
  `requirements.md` SHA-256 given immediately above is exact and is
  independently checkable without that commit hash.

### Operational note (2026-08-25): the prescribed fixed-point step is not executable through its own tool

`reviewer-calibration.md`'s Amendment Re-Review Context section discloses a
fixed-point procedure — validate the prior round's contract against the bytes
it reviewed, then restore the amended bytes. The restore half works. The
validate half does not: running
`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh` against an
already-reserved manifest fails with `REVIEW_CONTEXT_IDENTITY: canonical
identity ledger hash is stale or mismatched`, because the ledger has grown
since that manifest was reserved, and the check compares against the ledger's
current hash. The substitute used here, and labelled as a substitute rather
than presented as the prescribed step: each input in the prior manifest was
compared individually against the restored bytes. For spec attempt 5
(sequence 779) that gave four of five inputs matching exactly; the fifth,
`requirements.md`, differed only by its `Spec-Review-Status:` header line,
which `check-workflow-state.sh`'s own `normalized_hash()` neutralizes by
design — confirmed by the attempt-6 precheck computing
`f2343a1c0977...` while reading the field as `Pending`.

### Round-4 extension (2026-08-25): AC-026 and TEST-026 carry the disclosure at the point of use

- Human ruling (verbatim, dated): 2026-08-25:
  「承認するので進めてください」 — authorizing the package's own existing
  Test Type annotation convention to be applied to `TEST-026`, and a
  pointer to be added at `AC-026`, so a verifier reading either in
  isolation learns the criterion is known-unsatisfied.
- Closes spec-review attempt 6 round 1's three Majors: reviewer A's
  `AC-OBSERVABLE` (ledger sequence 787) and reviewer B's
  `DOWNSTREAM-READINESS` and `CONTRADICTION` (ledger sequence 788).
- The annotation is copied, not invented. The closest precedent is the
  pair of rows whose Requirement column is `REQ-003` alone — `AC-036`
  and `AC-037` — which carry `integration (named SKIP until <condition>)`
  in the Test Type column and an `(OQ-NNN)` pointer at the end of the
  Notes column. `TEST-026` now carries exactly that two-part shape. The
  longer `allowlist-governed` variant was deliberately not copied: it
  appears on rows whose Requirement column includes `REQ-007`, and
  `tests/fixtures/skip-allowlist-manifest.json` does not yet exist, so
  claiming allowlist governance would assert a manifest entry that cannot
  be checked.
- **A correction to this session's own earlier remedy, appended rather
  than rewritten.** The `OQ-004` and Risks entries committed in
  `c50c8028` state that `AC-026`'s *ordering* rule, "always last in a
  round's own event sub-sequence", is not satisfied. That is stricter
  than the evidence supports, and both reviewers accepted it because both
  were reasoning from the framing this session supplied. Where the emit
  happens it is `assert_terminal`'s final act before returning, so
  "always last" does hold. The clause actually violated is design.md's
  per-kind producer table's firing condition — "firing exactly once per
  round at the instant it evaluates the freshly-read `.terminal.state`" —
  because the emit precedes the evaluation: a failing comparison records a
  transition that did not occur, and each early return records none. The
  defect, its deliberate non-fix, and its resolution path are unchanged.
  The original wording is left in place with the correction appended
  beneath it, the same treatment the eight-site quotation received.
- As of this amendment,
  `specs/epic-195-a7-compatibility/requirements.md` = `2ee8681ec48f95e522187161a5b30467635a40468623f94faa6e5e2b01cbb3e4`,
  superseding `bc596b776cc08b7a5479be198a18c942ea715f89e3bdd25af35f6d3460f2400f`
  recorded in the preceding sub-entry; and
  `specs/epic-195-a7-compatibility/acceptance-tests.md` = `8c2abdee404aa093feae6e0d636909fb5d8855e155d4503c70ed4329a1fb9ad5`,
  superseding `7f17001714aac9fcd78ca2093a340a7f1e6e557c7d80338b8db216a7aa4966e8`.
  This extension and the two document amendments it describes are made in
  a single commit, so that commit's own hash cannot be cited from inside
  itself; it is pinned externally by the spec-review attempt-6 round-2
  reviewer manifests and the identity-ledger records their reservations
  append.
- Dependent statements found by enumeration and deliberately NOT edited,
  because they fall outside the authorization this ruling gives:
  `tasks.md` line 968 (T-006's Done When, "round's own event
  sub-sequence (AC-026)") and `tasks.md` line 1078 (T-007's equivalent,
  "this round's own sub-sequence (AC-026, this suite's own share)") both
  instruct a future implementer to assert the criterion, and neither now
  carries the pointer that `AC-026` and `TEST-026` carry.
  `traceability.md` line 117 binds `AC-026` to `TEST-026` and is
  likewise untouched. Recorded here so the next sweep starts from a list
  rather than a pattern.

### Round-5 extension (2026-08-25): the SKIP framing is withdrawn; the pointer stands

- Authorization as received (2026-08-25): "option 4 — abandon the SKIP
  framing, keep the pointer." **Provenance caveat, recorded rather than
  glossed:** this authorization reached this session relayed in English by
  the orchestrating caller, not as a verbatim source-language ruling
  string like the approvals quoted earlier in this entry. A reviewer
  judging this sub-entry against the calibration's "verbatim dated
  quotation" element should weigh that difference itself rather than take
  this line as equivalent to those. Saying so here is a direct consequence
  of the 8-versus-11 finding recorded above: a paraphrase that reads as an
  authorization is exactly what that finding was about.
- What changed: `TEST-026`'s Test Type column returns to `integration`,
  the value it held before the round-2 remedy. The disclosing half of the
  Notes column stays, as does `AC-026`'s appended pointer. The one
  sentence in that pointer which asserted "`TEST-026` is therefore a
  named `SKIP`" is withdrawn and replaced by a statement of what is
  actually true: the criterion carries no `SKIP` disposition and is not
  governed by `AC-034`'s allowlist.
- **How the defect happened, recorded as a sequence rather than as a
  clean correction.** The instruction this session worked from was to copy
  the package's existing annotation form exactly and not to design a new
  marker. That instruction was sound in general and wrong for this case.
  While applying it, this session observed that `AC-026`'s Requirement
  column contains `REQ-003` alone and not `REQ-007`, and treated that
  absence as a detail to trim from the copied wording — dropping the
  `allowlist-governed` phrase while keeping the `named SKIP` phrase.
  Both spec reviewers then found, independently and blind, that the
  absence was not a detail. Reviewer B (ledger sequence 790) put it
  exactly: that absence was "simultaneously the evidence that AC-026 falls
  outside the very governance machinery the annotation's shared visual
  form implies it participates in." A shared visual form is not a shared
  contract. The absence of the governing `REQ` is the thing to stop on,
  not the thing to trim.
- **Why option 4 is correct rather than merely convenient.** Reviewer B
  found a fact neither the instruction nor this session had: `TEST-026`
  asserts the Done-transition event "within both `TEST-018` and
  `TEST-019`", and `TEST-018` is the Context-absent case, which depends
  on no upstream epic at all. So even a correctly formed
  upstream-dependency annotation — one that named a real epic and passed
  `AC-034`'s grammar — would still have been wrong for part of what
  `TEST-026` asserts. No variant of the SKIP framing fits this criterion.
- The two Criticals this withdraws were raised by reviewer A (sequence
  789, `AC-OBSERVABLE`) and reviewer B (sequence 790, `CONTRADICTION`),
  each reaching `AC-035(b)`'s unknown-SKIP hard-fail independently. The
  disclosure half of the round-2 remedy is untouched: both reviewers
  confirmed `AC-026`'s point-of-use pointer closes round 1's gap, and both
  confirmed the appended `OQ-004`/Risks precision correction is accurate
  and that appending rather than rewriting was the right treatment.
- As of this amendment,
  `specs/epic-195-a7-compatibility/requirements.md` = `fb5be3067b95345f2e4a0dcd190e0800f61421e595479c5975ac050246e2e734`, superseding
  `2ee8681ec48f95e522187161a5b30467635a40468623f94faa6e5e2b01cbb3e4`; and
  `specs/epic-195-a7-compatibility/acceptance-tests.md` = `f77158ea4ad4263910439cd37ca0ed5296fc3f4e29e1d4e8c963d659ed799815`,
  superseding `8c2abdee404aa093feae6e0d636909fb5d8855e155d4503c70ed4329a1fb9ad5`.
  Both values were recorded in the Round-4 sub-entry above. This
  extension's own commit hash cannot be cited from inside itself; it is
  pinned externally by the spec-review attempt-6 round-3 reviewer
  manifests and the identity-ledger records their reservations append.
- `acceptance-tests.md` does not return to its pre-round-2 bytes. The
  Test Type cell does, exactly; the Notes cell retains the disclosing
  clause and its `(OQ-004)` pointer, which is the half both reviewers
  credited with closing round 1's finding.

### Round-6 extension (2026-08-25): the option-4 authorization, verbatim, replacing an insufficient relay

- Human ruling (verbatim, dated, source language), 2026-08-25:
  「④ SKIP 枠組みを捨て、ポインタのみ残す（推奨）」 — the human's own
  selection authorizing the withdrawal of the `SKIP` framing from
  `TEST-026` while keeping the point-of-use pointer, which is the change
  commit `8bf1cda0` made.
- **This supersedes the authorization line recorded in the Round-5
  extension above, and the two are not the same evidence.** Round-5
  recorded "option 4 — abandon the SKIP framing, keep the pointer" and
  disclosed that it had reached this session as an English relay from the
  orchestrating caller rather than as the human's own words. That relayed
  form was **insufficient**: the calibration requires a verbatim, dated
  quotation of the human's approval statement and states that a paraphrase
  means the declaration does not apply, with no benefit of the doubt. The
  verbatim string above was supplied afterwards, and only now does this
  authorization meet the bar. A later verbatim quotation does not
  retroactively make the earlier relay adequate; it replaces it.
- Spec-review attempt 6 round 3 reviewer B (ledger sequence 792) is why
  this entry exists. It raised a Critical `APPROVAL-BOUNDARY` finding on
  exactly this point and closed it with the rule this package's own
  operating context states: an agent-relayed instruction is never itself
  authorization. That rule binds the orchestrating caller relaying to an
  implementing session exactly as it binds any other relay. Attempt 6
  terminated `BLOCKED` on that finding.
- The Round-5 caveat is deliberately left standing, unedited and
  unsoftened, in the sub-entry above. It is what made the defect findable:
  a reviewer could only reject the relayed authorization because the entry
  admitted what it was. Rewriting it now would remove the disclosure that
  did the work.
- No document bytes change with this extension. `requirements.md` and
  `acceptance-tests.md` keep the values recorded in the Round-5 sub-entry;
  this extension corrects the authorization evidence for a change that was
  already made, not the change itself. This extension's own commit hash
  cannot be cited from inside itself and is pinned externally by the
  spec-review attempt-7 round-1 reviewer manifests and the identity-ledger
  records their reservations append.

### Round-7 extension (2026-08-25): two abbreviated commit citations superseded by their full hashes

- Defect corrected: two commits in this entry were cited in abbreviated
  eight-character form, where the calibration's evidence bar element 1
  requires "the amendment commit hashes, given in full (not abbreviated,
  and not described only as 'recent changes')", and lists "abbreviated
  where a full hash is required" among the conditions under which the
  declaration does not apply, with no benefit of the doubt.
- Superseded by appending, never rewritten in place. Each is identified
  here by its full hash rather than by reproducing the abbreviated string,
  because emitting the eight-character form again would recreate the very
  condition being corrected:
  - The commit that withdrew the `SKIP` framing from `TEST-026` is
    `8bf1cda07d295aa44e12cb8d62565f2a3ac4a7c4`. The Round-6 extension
    above cites it by its first eight characters only; that citation is
    superseded by this full value.
  - The commit that added the `OQ-004` and Risks entries is
    `c50c8028cd7978368cc95c5cc495ffb7213b05d6`. The Round-4 extension
    above cites it by its first eight characters only; that citation is
    superseded by this full value.
  Both full values were resolved with `git rev-parse` at the time of
  writing rather than assumed from the abbreviations.
- Authorization: none newly required. The changes these two commits made
  were authorized by the rulings already quoted verbatim in this entry —
  2026-08-25 「④ SKIP 枠組みを捨て、ポインタのみ残す（推奨）」 for the
  first, and 2026-08-25 「① requirements.md に追跡を追加する（推奨）」 for
  the second. This extension corrects the form in which their commits are
  cited; it authorizes nothing further and changes no document bytes.
- Provenance of the defect, recorded because the sequence is the useful
  part. Spec-review attempt 7 round 1 reviewer A (ledger sequence 793) and
  reviewer B (ledger sequence 794) both found the first of the two
  independently and blind, each rating it Critical. Neither found the
  second. That one was found
  by enumerating every seven-to-thirty-nine character hexadecimal token in
  this section and testing each against `git cat-file`, which is a
  deterministic check that does not depend on a reader noticing. Two
  careful blind reviewers found one instance; enumeration found both.
- Standing consequence, adopted this session: before any commit that
  appends to this entry, a mechanical checklist is run over the appended
  text — every hex token that resolves as a commit must be given in full,
  every SHA-256 must match a live measurement or a value already recorded
  here, any authorization must be a verbatim dated source-language
  quotation attributed to the human, no bare paths, zero deletions, and
  this section's own start line unmoved. Three consecutive review rounds
  failed on this record rather than on the specification it documents,
  each correction introducing the next defect of the same class; a
  finite, enumerable check over one's own text is the answer to that, not
  more careful reading.

### Round-8 extension (2026-08-25): three truncated document digests given in full

- Corrected here, appended rather than rewritten in place. Three superseding
  SHA-256 document fingerprints were recorded truncated to twelve characters
  followed by an ellipsis. Their full values are:
  - `design.md`, superseded value:
    `04a124d6d56298cc1b2ff63f2eacd21c75c615a781e220d0ad37513636fe9dfc`
  - `tasks.md`, superseded value:
    `d3b3fdcd51449ad4ebb8a56010b6d8f5b33d718e9fdaa0286656e3051eca4f97`
  - `requirements.md`, superseded value:
    `f2343a1c0977aecc6970c2cb42d8fa9c9cb677cf11ff5ef35fb6fa38df9364d2`
  Each was already present in full elsewhere in this entry; what is corrected
  is the form of the back-reference, not the value.
- **Why this was corrected rather than adjudicated.** The two spec reviewers
  split on whether these truncations are defects at all. Reviewer A (ledger
  sequence 795) held that element 2 requires the digest to be *given*, which it
  was, a few lines above each truncated back-reference, and did not treat them
  as disqualifying. Reviewer B (ledger sequence 796) held that the calibration's
  "abbreviated where a full hash is required" clause applies literally with no
  benefit of the doubt, and noted that the adjacent bullets in the same list
  give their superseding values in full, so the truncation reads as omission
  rather than as the section's format. Both readings are defensible. The remedy
  is citation form only, changes zero document bytes, and is lossless under
  either reading — under A's it changes nothing that matters, under B's it
  closes a Critical. It was taken for that reason, not because one reviewer was
  judged right and the other wrong.
- **Audit method, widened twice over after this class was missed.** The
  pre-commit check adopted in the Round-7 extension had two structural holes.
  It ran only over each commit's newly added lines, so a defect committed
  earlier could never surface however many times it ran; and it tested hex
  tokens against `git cat-file`, which resolves git objects and is therefore
  blind to a content digest. It now runs over the entire
  `## Amendment Re-Review Context` section on whitespace-flattened text, and
  audits all four evidence-bar elements rather than whichever one the last
  reviewer named: every commit cited in full and resolving as a commit; every
  document digest in full; every approval a verbatim, dated, source-language
  quotation attributed to the human; no bare artifact paths; plus append-only,
  section start unmoved, and the pinned section still an exact prefix of the
  live file. An abbreviated or truncated value counts as cured when its full
  form appears somewhere in this section, which is the supersede-by-appending
  convention stated mechanically; an approval counts as cured when a later
  sub-entry supplies the verbatim quotation and names the earlier one as
  superseded.
- **A structural defect in the review workflow, recorded here because it has
  now cost four rounds.** `plugins/sdd-review-loop/scripts/spec-review-precheck.sh`
  advances a round only when `requirements.md` or `acceptance-tests.md` has
  changed since the prior round:

      [[ "$requirements_sha" != "$prior_requirements_sha" || "$acceptance_sha" != "$prior_acceptance_sha" ]] \
        || fail "reviewed inputs are unchanged from the prior round"

  The Amendment Re-Review Context evidence bar lives entirely in this file,
  reviewers are instructed by the calibration to judge it, and it has produced
  a Critical finding in four consecutive rounds — a non-verbatim relayed
  approval, an abbreviated commit hash, and truncated document digests. But a
  remedy for any of those touches only `investigation.md`, leaving both files
  the round-advance test inspects byte-identical, so **the round cannot
  advance**. Opening a fresh attempt is equally blocked whenever the stalled
  round holds `NEEDS_WORK`, which is not terminal. The only remaining
  transition is a reset, which replaces the artifacts documenting how the state
  was reached. A defect whose sole remedy is in this file therefore cannot be
  cleared inside its own attempt, and each correction costs a reset plus two
  fresh reviewer runs.

### Round-9 extension (2026-08-27): the Round-8 extension's missing authorization statement, supplied

- **What was missing.** Spec-review attempt 7 round 1 reviewer B (ledger
  sequence 798) found that the Round-8 extension above carries no
  authorization statement at all — element 3 of the evidence bar — while
  every other sub-entry in this section has one, including Round-7, which
  states explicitly why none was needed. Reviewer A (ledger sequence 797)
  ran its own enumeration looking specifically for a fifth class and found
  none; B found this one. B is right, and the omission is exactly the gap
  whose precedent in this section rates it Critical.
- **The statement, supplied here by supersession.** Authorization for the
  Round-8 extension: none newly required. That extension corrected citation
  form only — three truncated back-references given in full — changed zero
  document bytes, and authorized nothing further. It stands under the same
  rulings already quoted verbatim in this section: 2026-08-25
  「④ SKIP 枠組みを捨て、ポインタのみ残す（推奨）」 and 2026-08-25
  「① requirements.md に追跡を追加する（推奨）」. This is the identical
  posture the Round-7 extension recorded for itself; Round-8 omitted the
  sentence, and this sub-entry supplies it, superseding the omission per
  this section's supersede-by-appending convention.
- **The standing adjudication, quoted verbatim.** On 2026-08-25 the human
  was asked, through the session's structured question mechanism:
  「epic-195 の amendment record が 5 ラウンド連続で失敗し、修正のたびに
  新しいクラスを生んでいます（仕様本体は毎回 PASS）。どうしますか?」 and
  selected the answer: 「① 引用形式の欠陥は spec 段を止めないと裁定」.
  Under that ruling, a finding whose remedy is citation form alone — the
  truncated back-references reviewer B holds unresolved, and this
  authorization omission — is recorded here, cured by supersession, and
  does not block the specification verdict. The specification itself has
  now passed both reviewer slots in five consecutive rounds; every finding
  in those rounds was against this record.
- **Why in-place cure is structurally impossible, recorded so the standing
  disagreement is adjudicated rather than reargued.** Reviewer B's position
  — that leaving a truncated citation in place while supplying the full
  value below is the artifact adjudicating its own compliance — asks for an
  edit this document cannot legally receive: this section is append-only,
  and the provenance tolerance that keeps three sealed review stages valid
  requires the pinned generation to remain an exact byte prefix of the live
  file. Rewriting an earlier line breaks every sealed pin at once.
  Supersession by appending is therefore not a convenience but the only
  lawful remedy, and the 2026-08-25 ruling above settles which way that
  trade-off is decided for the spec verdict.
- Authorization for this Round-9 extension itself: none newly required. It
  changes zero document bytes outside this section, supplies a missing
  statement about an already-authorized correction, and quotes a ruling the
  human already issued in the words the human selected.
