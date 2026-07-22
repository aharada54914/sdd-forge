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
| INV-002 | The registration-forcing suite hardcodes the entry count: `jq -e '(.loops \| type) == "array" and (.loops \| length) == 8'`. Adding a **new** loop entry (a new `id`) to the registry would fail this assertion until the suite itself is edited; adding a new **field** to an existing entry does not. This is the concrete fork in the road between "new loop kind" and "capability event added to an existing loop" (design.md Design Decisions). | Critical | `tests/loop-inventory.tests.sh:129-133` |
| INV-003 | `tests/lib/loop-driver.sh` is the shared, source-style driver (never executed directly). Its public contract is fixed in its own header comment: `loop_fixture_init`, `drive_review_round`, `assert_prior_round_complete`, `assert_artifacts_schema`, `assert_terminal`, `assert_runtime_budget`, plus the environment variables `SDD_LOOP_REPO_ROOT` / `LOOP_INVENTORY_PATH` / `LOOP_FIXTURE_SEED`. `drive_review_round` dispatches by `stage` (`spec\|impl\|task\|domain`) to private `_loop_drive_*_round` functions; there is no `capability`/`resolver` stage today. | High | `tests/lib/loop-driver.sh:1-27` (public contract), `:1409-1429` (`drive_review_round` dispatch) |
| INV-004 | `assert_terminal <loop-id> <observed-state>` and `assert_artifacts_schema <dir>` both read directly from `LOOP_INVENTORY_PATH` (the same registry as INV-001), so any capability-event vocabulary added to the registry (INV-002) is automatically visible to both assertion helpers without touching their own code — the intended low-cost extension seam. | Medium | `tests/lib/loop-driver.sh:1434-1459` |
| INV-005 | `tests/loop-consistency.tests.sh` drives spec/impl/task/domain rounds end-to-end via the shared driver (TEST-008), locks a historical regression (TEST-009), and re-validates the bidirectional review-context-set invariant (TEST-010). `tests/loop-escalation.tests.sh` drives the quality-gate escalation chain and terminal-tier resume (TEST-011), a task-ID prefix-collision fixture (TEST-018), and a template↔validator parity extension (TEST-012). Both suites already accept `LOOP_INVENTORY_PATH`/`SDD_LOOP_REPO_ROOT` overrides and both already carry a `TEST-017` runtime-budget check, so a capability-event assertion added as a new numbered `TEST-0NN` case fits their existing pattern without a new file. | Medium | `tests/loop-consistency.tests.sh:1-39`; `tests/loop-escalation.tests.sh:1-60` |
| INV-006 | `plugins/sdd-quality-loop/scripts/emit-run-record.sh` already implements the exact "byte-identical unless a new flag is supplied" pattern Epic A7 needs: `emit_v2` starts at `0` (line 37), is set to `1` only when one of the `--effort-*` flags is parsed (lines 62-77), and the final `if [ "$emit_v2" = "1" ]` branch (line 185) either emits an additive `sdd-run-record/v2` object or falls through to an `else` branch whose heredoc is "intentionally an exact, unmodified copy of the pre-T-004 emission" (line 279-282), guaranteeing the no-flag path stays byte-identical to `sdd-run-record/v1`. | High | `plugins/sdd-quality-loop/scripts/emit-run-record.sh:30-43,62-77,185,245-304` |
| INV-007 | `tests/install.tests.sh` (1776 lines) and `tests/uninstall.tests.sh` (666 lines) already exercise install/uninstall determinism (fixture cloned via `git archive`, no network) but carry no concept of `project-context.yaml` or capability mode — they are the existing byte-identical-style baseline for the "install・uninstall結果" target named in decision doc §4.1, not yet parameterized by Project-Context presence/absence. | Medium | `tests/install.tests.sh:1-30`; `tests/uninstall.tests.sh` |
| INV-008 | ADR-0010 fixes the fixture-profile vocabulary as the closed set `greenfield \| brownfield` and the `cap_source` axis as `script \| skill-instruction`, and states extending the vocabulary requires an ADR revision, not an ad hoc addition. Any new fixture axis this epic introduces (the 4-state capability-enforcement matrix, Findings INV-013) is additive to, and independent of, this existing vocabulary — it must not be folded into `fixture_profiles` itself. | High | `docs/adr/0010-loop-inventory-and-fixture-vocabulary.md:34-84` |
| INV-009 | ADR-0016 redefines `disabled-legacy` as a **derived internal state** (not an enum value): when `project-context.yaml` is absent, "the Resolver, the Registry, the Gate stage machinery, and the effective enforcement `max()` computation do not run at all". This is the literal legacy code path the byte-identical test (decision doc §4.1) must exercise: zero capability-machinery invocation, not a low-severity capability evaluation. | Critical | `docs/adr/0016-workflow-axes-separation.md` Decision items 3-4 |
| INV-010 | ADR-0023 fixes the track-selection compatibility contract this epic must verify unchanged: when `project-context.yaml` is **absent**, the current priority order (CLI flag → `AGENTS.md` marker → default) is preserved unchanged. The current, pre-Epic-A1 priority order is documented today at `PLUGIN-CONTRACTS.md:63-65` (`--full` → FULL, `--lite` → LITE, `spec_profile: lite` marker → LITE) — this is the literal byte-identical/behavioral baseline for the Context-absent fixture. | High | `docs/adr/0023-track-selection-contract-migration.md` Decision items 1-2; `PLUGIN-CONTRACTS.md:63-65` |
| INV-011 | `docs/ai-dlc-foundation-decision-v2.md` §6's combination matrix names exactly the four fixture states this epic's test matrix must cover: `lite/lite-three-file/(non-active)` and `full/legacy-seven-layer/(non-active)` are both labeled "互換フォールバック（Context不在）" (compatibility fallback, Context absent); `full/legacy-seven-layer/advisory\|required` is labeled "移行互換モード" (migration-compatible mode, Context present). | High | `docs/ai-dlc-foundation-decision-v2.md:207-219` |
| INV-012 | §19 Epic A1 confirms track-selection migration and the compatible-caller contract are **Epic A1 deliverables**, not this epic's own implementation; §19 Epic A7 confirms this epic's own scope is the three test kinds themselves, built on top of that (eventual) migration. | Medium | `docs/ai-dlc-foundation-decision-v2.md:522-524,544-545` |
| INV-013 | Cross-epic (Epic A1, unmerged, `sdd-forge-wt-epic-189`): REQ-009 is the track-selection contract migration; a Project Context that fails validation stops with the named `PROJECT_CONTEXT_INVALID` error rather than falling back to "no Project Context" — this is a **third** distinguishable orchestration outcome (beyond byte-identical-fallback and event-identical-capability-mode) that the orchestration-event test's fixture matrix must be able to represent even though the mechanism that raises it does not exist on `main` yet. | High | `specs/epic-189-a1-project-context/requirements.md:882` (REQ-009), `:2156` (B5 risk row naming `PROJECT_CONTEXT_INVALID`), `:1972-1985` (five A1-time consumer call sites, all sharing the identical absent→fallback / present→validate-then-trust rule) — read from sibling worktree `sdd-forge-wt-epic-189` |
| INV-014 | Cross-epic (Epic A3, unmerged, `sdd-forge-wt-epic-191`): `check-component-coverage.py`'s design already establishes the exact 3-state pattern (`disabled-legacy` → zero evaluation + a real, truthful `state: "not-applicable (disabled-legacy)"` evidence record, exit 0; `advisory` → full evaluation, non-blocking; `required` → full evaluation, blocking) that this epic's structural/orchestration tests must treat as the canonical shape for every future capability-derived Gate. This confirms disabled-legacy must always be a **truthful non-evaluation record**, never "gate not invoked at all" and never a silent skip. | High | `specs/epic-191-a3-path-ownership/design.md:88-95,377-380,447-453,682-707` — read from sibling worktree `sdd-forge-wt-epic-191` |
| INV-015 | Cross-epic (Epic A5, unmerged, `sdd-forge-wt-epic-193`): REQ-002 defines a closed Block-diagnostic taxonomy for the (future) Resolver; one named diagnostic, `disabled-legacy-invocation`, is explicitly framed as "a CLI-misuse guard, not a designed pipeline state" — A5's own text states "a compatible caller (REQ-007) never invokes this Resolver's own process while a Project Context is absent or derives `disabled-legacy`". The compatibility-relevant assertion is therefore an **absence** assertion (no Resolver subprocess call observed in the event trace when Context is absent), not a Resolver-output assertion. | Critical | `specs/epic-193-a5-capability-resolver/requirements.md:334-348` (REQ-002 table, `disabled-legacy-invocation` row) — read from sibling worktree `sdd-forge-wt-epic-193` |
| INV-016 | Cross-epic (Epic A5, unmerged): A5's own design explicitly defers the live caller-integration contract test (`resolve-project-context-caller-contract`) to "a future task, Non-goals" — i.e. A5 fixes the fixture-level contract at design time but does not itself author the suite. That future suite's own techniques are directly reusable by this epic: (a) an anchor-fingerprint drift check (sha256 of a fixed line window in the live `SKILL.md`, plus that heading's ordinal position among all headings) rather than a bare "heading text still exists" check, and (b) a spy-harness fixture proving a Context-absent invocation never calls the capability subprocess at all (event-identical to today's flow). This epic's orchestration-event test package is one plausible home for that deferred suite once the capability interview phase exists, or it can stay a distinct future task — recorded as an Open Question (requirements.md). | High | `specs/epic-193-a5-capability-resolver/design.md:1809-1866` (item 10, `resolve-project-context-caller-contract`) — read from sibling worktree `sdd-forge-wt-epic-193` |
| INV-017 | Grep confirms none of `capability_enforcement`, `disabled-legacy`, or `project-context.yaml` appears anywhere under `plugins/`, `scripts/`, `contracts/`, or `tests/` in this worktree (`main` baseline): `grep -rln "capability_enforcement\|disabled-legacy\|project-context.yaml" plugins/ scripts/ contracts/ tests/` returns no matches. Likewise `resolve-project-context*` and `check-component-coverage*` do not exist anywhere in this worktree (`find . -iname "resolve-project-context*" -o -iname "check-component-coverage*"` returns no matches). The capability machinery this epic's compatibility tests describe is entirely forward-looking relative to `main`. | Critical | grep/find evidence, this worktree, 2026-07-22 |
| INV-018 | `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`'s own "Required Outputs" section lists the full-profile Phase 1 output set as **seven** mandatory Markdown files (`requirements.md`, `acceptance-tests.md`, `design.md`, `ux-spec.md`, `frontend-spec.md`, `infra-spec.md`, `security-spec.md`) plus Phase-2 `tasks.md`/`traceability.md`; `plugins/sdd-bootstrap/scripts/check-sdd-structure.sh`'s feature-mode check enforces the same nine-file set. This epic's own package (four files: `investigation.md`/`requirements.md`/`design.md`/`acceptance-tests.md`, no layer specs, no Phase 2) is a deliberate, explicitly-scoped deviation from that default per this task's own Phase-1-only mandate, not an oversight — recorded as a Risk (requirements.md) because a literal `check-sdd-structure.sh <root> epic-195-a7-compatibility` run would report the four layer files and two Phase-2 files as `missing:`. | Medium | `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:116-141`; `plugins/sdd-bootstrap/scripts/check-sdd-structure.sh:71-78` |
| INV-019 | `AGENTS.md`'s "Spec factual-claim evidence citations" rule (WFI-011) requires every checkable factual claim in `investigation.md`/`requirements.md`/`design.md` to cite the specific grep/file:line evidence it rests on, in the document itself — the citation convention this investigation follows throughout. | Medium | `AGENTS.md:137-145` |
| INV-020 | `specs/workflow-state-registry.json`'s schema (`contracts/workflow-state-registry.schema.json:459-497`) accepts a minimal full-profile entry of exactly `{"feature": "<slug>", "profile": "full"}` (`additionalProperties: false`); no `legacy` block is required for a fresh, non-migrated feature. `specs/local-env-mcp` is an existing example of this minimal shape. | Low | `contracts/workflow-state-registry.schema.json:459-476`; `specs/workflow-state-registry.json` (`local-env-mcp` entry) |

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
- Do not treat any cross-epic (A1/A3/A5) file cited above as merged or
  stable; they are unmerged specs on sibling feature branches and may
  change before this epic's own Phase 2/3 begins. Re-verify before
  authoring tests against them.
- Do not fabricate current capability-machinery behavior: per INV-017, no
  such machinery exists on `main` today, so every orchestration-event
  assertion this epic specifies for the "Context present" fixture states
  is necessarily a forward-looking contract, not an assertion against
  code that exists yet.
- Preserve the existing 8-entry `loop-inventory/v1` registry and its
  registration-forcing suite (INV-001, INV-002) exactly as-is in this
  spec-only phase.
