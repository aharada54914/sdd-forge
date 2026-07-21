# Investigation: epic-190-a2-capability-registry (issue #190 — Capability Registry)

Source of truth for all design content below: `docs/ai-dlc-foundation-decision-v2.md`
(hereafter "decision v2") and `docs/adr/0016`-`0024` (hereafter "ADR-00NN"). This
investigation only records repository facts used to ground design choices; it
introduces no requirement that is not already stated in decision v2 or an ADR.

## INV-001: Epic A2's normative scope (decision v2 §19)

`docs/ai-dlc-foundation-decision-v2.md:527` states Epic A2's implementation
list verbatim: "Registry schema / structured predicate DSL（trigger 含む・
意味論準拠） / Gate stage（implementation のみ実装、artifact/promotion 予約） /
Lite eligibility / minimum enforcement / registry_digest 発行 / duplicate検査 /
Provider名混入検査 / projection 生成（scripts/generated/ 配下・保護対象）".
This spec package scopes exactly to that list; Epic A5 (Resolver) is the
consumer that binds `registry_digest` into a Facet Manifest's
`context_binding` (ADR-0021) and Epic A1 owns Project Context, the
canonicalizer, and `sdd/provider-bindings.yaml`.

## INV-002: Registry vs. Pack division of labor (decision v2 §13, Q12)

`docs/ai-dlc-foundation-decision-v2.md:397-409` (§13) makes the Capability
Registry the sole machine-readable source of truth: "Capability ID / trigger /
conditions / required facets / conditional facets / review check IDs / gate
IDs / gate stage / lite eligibility / minimum enforcement / delivery strategy
kind". Capability Packs retain only human/authoring content: "questions.md /
templates/ / review-checklist.md / guidance.md / examples/ / policy-examples/".
`capability-packs/*/gates.yaml` is explicitly abolished ("廃止").

**Repository fact**: no `capability-packs/` directory exists anywhere in this
repository today (`find . -iname "*capability-pack*"` returns nothing). The
Registry/Pack split is prospective — Epic A2 is the first implementation of
either half — so REQ-003's "Pack に Gate 定義なし" check (below) can only be a
forward-guard (assert the deprecated path shape never reappears), not a
cross-check against existing Pack content.

## INV-003: Gate Stage Model and its schema (ADR-0017)

ADR-0017 (`docs/adr/0017-gate-stage-model.md:27-32,85-92`) fixes three Gate
stages (`implementation`, `artifact`, `promotion`), with Foundation
implementing only `stage: implementation`; `artifact`/`promotion` are
"reserved enum values ... with implementation explicitly exempted for
Foundation; the completeness tests in decision-document v2 §13 apply only to
`stage: implementation` gates." The schema example
(`docs/adr/0017-gate-stage-model.md:87-92`) is a flat, top-level `gates:` list
of `{id, stage, blocking}` objects — not nested per-Capability — which this
spec's Registry schema (design.md) follows directly: gates are defined once,
globally, and Capabilities reference them by ID (so "Gate ID一意" is a single
array's uniqueness constraint, not a cross-capability de-duplication problem).

## INV-004: Predicate DSL evaluation semantics (ADR-0020)

ADR-0020 (`docs/adr/0020-conditional-predicate-dsl.md:38-79`) is normative for
the evaluator this spec designs:
- Logical: `all` (empty → true) / `any` (empty → false) / `not` (unary); no
  short-circuit — every predicate is evaluated and recorded.
- Comparison: `equals` / `not_equals` / `contains` / `in` / `exists`.
- General rule (equals/not_equals/contains/in): missing path, `null`, or type
  mismatch → predicate is `false` + `WARN`, never an exception.
- `exists` is the sole exception: path present → `true` even if the value is
  `null`; path absent → `false` + `WARN`. Type is irrelevant to `exists`.
- `trigger` reuses this exact DSL/evaluator against the affected component's
  own properties — "no second condition language."
- Forbidden: regex, arbitrary JSONPath, shell/JS/Python, dynamic code,
  Provider API calls, time- or network-dependent conditions.
- Field allowlist source of truth is the Project Context schema (Epic A1):
  `artifact_kinds`, `runtime_classes`, `characteristics.pii`,
  `characteristics.ui`, `characteristics.auto_update`,
  `characteristics.local_persistence`, `distribution_channels`,
  `data_classification`.

## INV-004a: Field allowlist drift-check obligation (adversarial review 2026-07-22)

INV-004 already names the Project Context schema (Epic A1) as the field
allowlist's source of truth. The spec's first draft nonetheless hand-
re-listed the 8 dotted paths inside `contracts/capability-registry.schema.json`
itself with no mechanism tying that copy back to A1's schema. Per orchestrator
ruling 2026-07-22 (adversarial spec review, Major finding "A1 の
schema/canonicalizer を参照せず複製・仮定"), REQ-002's allowlist must instead
be generated from, or drift-checked against, A1's schema once it lands
(design.md API / Contract Plan, REQ-002); until A1's schema exists to check
against, the hand-listed 8 paths remain a placeholder carrying an explicit
drift-check obligation, not a second source of truth.

## INV-005: registry_digest and staleness binding (ADR-0021)

ADR-0021 (`docs/adr/0021-context-projection-staleness.md:30-46,55-76`) widens
Facet Manifest staleness binding to include `registry_digest: sha256:...`
("digest of the Registry fragment used") alongside `projection_sha256` and
`ownership_digest`. It also defines **semantic output** for comparison
purposes — the resolved gate set (gate ID + `stage` + `blocking`), effective
minimum enforcement, capability set, lite eligibility, and required/
conditional facets and their N/A reasons — and states: "A Registry edit that
changes a gate's `stage` or `blocking` value while its gate ID stays the same,
or that tightens the minimum enforcement applying to the Feature, is a
semantic-output change." Epic A2's own scope is limited to producing a
deterministic digest **primitive** over a Registry (or a named subset of it);
binding that digest into a Facet Manifest's `context_binding` and computing
semantic-output diffs is Epic A4/A5 work (decision v2 §19, Epic A4/A5), not
duplicated here.

## INV-006: Cross-platform canonical hash (decision v2 §18.3)

`docs/ai-dlc-foundation-decision-v2.md:505-510` fixes the canonicalization
contract used for `registry_digest`: YAML 1.2 core-schema parse (only when
the source is YAML; anchors/custom tags/duplicate keys rejected), canonical
JSON per RFC 8785 (JCS), NFC string normalization, "Python single
implementation + thin sh/ps1/js wrappers (following the
`sdd-hook-guard.sh` pattern) — no per-runtime reimplementation," and
dual-runtime hash equality locked by fixture tests. This is an **Epic A1
deliverable** (the canonicalizer); this spec depends on it and does not
reimplement it (orchestrator instruction; also decision v2 §19 Epic A1's own
list: "canonicalizer（YAML 1.2 + JCS、Python単一実装+ラッパー）").

## INV-007: `lite_policy` shape and its prose/enum tension (ADR-0022)

ADR-0022 (`docs/adr/0022-lite-capability-upgrade.md:40-46`) gives the
machine-readable shape:
```yaml
lite_policy:
  eligible: false
  upgrade_reasons: [public_distribution, production_cloud_runtime, durable_workflow, external_identity, pii]
```
The same ADR's prose (`docs/adr/0022-lite-capability-upgrade.md:52-55`) lists
a broader set of forced-upgrade triggers: "cloud production, a Durable
Workflow, a public package registry, Store distribution, auto-update, Stable
distribution involving code signing, external authentication, PII, payments,
multiple tenants, or a high-risk migration" — eleven categories against the
YAML example's five literal tokens. Neither decision v2 nor any ADR resolves
this gap with an explicit closed enum. Recorded as OQ-001 below; this spec
treats `upgrade_reasons` as an open string array (not a closed enum) so the
schema does not silently contradict the prose list, and files the mismatch
for a human decision rather than picking a side unilaterally.

## INV-008: Provider-neutrality boundary (ADR-0018)

ADR-0018 (`docs/adr/0018-provider-binding-separation.md:63-70`) states the
boundary directly: "A Capability Pack never carries a provider name," "A
Project Context carries only Provider Binding IDs, never provider details,"
and "The existing review rule that detects provider-specific detail leaking
into a Capability specification is retained." **Repository fact**: no
automated implementation of this rule exists today — `grep -rniI
"azure|aws\b|provider.name|provider_binding"` across `plugins/`, `docs/`,
`contracts/` turns up only unrelated matches (a token/secret-shape detector
in `plugins/sdd-domain/skills/domain-review-loop/SKILL.md:304`, and the
threat model / WFI docs). "維持" ("retained") in ADR-0018 describes a
standing **policy**, not a pre-existing **automated check**; Epic A2 is the
first place this becomes an executable Registry-validation step (REQ-003).

## INV-009: Generated-projection precedent (guard-invariants)

The chosen precedent for "generation → protected projection → CI drift check"
is guard-invariants, confirmed directly:
- Source: `plugins/sdd-quality-loop/references/guard-invariants.json`
- Generator: `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`
- Generated (4 languages, each headed and protected):
  `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py`,
  `guard-invariants.generated.js`, `.ps1`, `.sh`
- Generated-file header format (`guard_invariants.py:1-2`):
  `# Generated from guard-invariants.json; schema_version=1; sha256=<hex>` /
  `# This file is generated. Do not edit.`
- All five paths above, plus `.github/workflows/test.yml`, are registered in
  `PROTECTED_GATE_SUFFIXES` and `PHASE2_HUMAN_COPY_TARGETS` inside the
  generated `guard_invariants.py` itself — i.e. the protection list is
  self-hosting: adding a new protected path is itself a protected-file change
  that must go through `specs/epic-136-phase2-gates/human-copy/` +
  `apply-protected-files.ps1` + `MANIFEST.sha256` (confirmed present:
  `specs/epic-136-phase2-gates/human-copy/{MANIFEST.sha256,apply-protected-files.ps1,plugins/,specs/}`).
- CI wiring precedent: `.github/workflows/test.yml:30,35` runs
  `generate-guard-invariants.py --check` on both `python` and `python3`
  invocations (drift check, no write).

Decision v2 §13 (`docs/ai-dlc-foundation-decision-v2.md:406`) fixes the
Capability Registry projection's output path to this same family:
`plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json`, "same
placement, same 'sha256 header + Do not edit' format" as guard-invariants,
and requires it be registered as a protected file, applied via human-copy.

## INV-010: `contracts/` directory conventions

`ls contracts/` (13 files) shows two co-existing shapes, both JSON, no YAML:
1. Pure JSON Schema validating an external instance file, e.g.
   `workflow-state-registry.schema.json` (draft-07, `$id`, `definitions`,
   validates `specs/workflow-state-registry.json`).
2. A self-describing data file carrying its own `"schema"` string field and
   instance data directly, with a companion `.md` doc, e.g.
   `agent-model-capabilities.v2.json` (`"schema": "agent-model-capabilities/v2"`)
   + `agent-model-capabilities.v2.md`.

No file under `contracts/` is authored in YAML. This is the direct precedent
this spec's design.md uses to resolve the file-placement question the task
brief poses ("contracts/ または sdd/ 配下"): `sdd/` (per ADR-0016/ADR-0018) is
reserved for **per-project, human-authored** instance config
(`sdd/project-context.yaml`, `sdd/provider-bindings.yaml` — one per consuming
project); the Capability Registry is **framework-shipped, shared across every
consuming project** — the same nature as `agent-model-capabilities.v2.json`,
not as `sdd/project-context.yaml`. `contracts/` is therefore the better fit
(see design.md's Design Decisions section for the full rationale, including
why the YAML-styled schema examples in decision v2/ADR-0017/0020 do not
override this — they illustrate concepts, they do not fix an on-disk format).

## INV-011: workflow-state-registry entry shape for new full-profile features

`contracts/workflow-state-registry.schema.json` requires every non-legacy
entry to be exactly `{"feature": "<slug>", "profile": "full"|"lite"}` (no
other keys — `additionalProperties: false`). Confirmed instances for
comparable Foundation-adjacent features already in
`specs/workflow-state-registry.json`: `{"feature": "epic-159-pillar-c",
"profile": "full"}`, `{"feature": "epic-159-pillar-a2", "profile": "full"}`.
Epic A2 registers the same minimal shape:
`{"feature": "epic-190-a2-capability-registry", "profile": "full"}`.

## INV-012: `check-sdd-structure.sh` required-file set

`scripts/check-sdd-structure.sh:36-51`: called with **no** feature argument
(as the orchestrator instructs: `sh scripts/check-sdd-structure.sh .`), it
only requires repo-root structure (`AGENTS.md`, `specs/`,
`reports/implementation/`, `reports/quality-gate/`, `docs/adr/`,
`docs/review-tickets/`) — the per-feature file list (`requirements.md`,
`design.md`, `ux-spec.md`, `frontend-spec.md`, `infra-spec.md`,
`security-spec.md`, `acceptance-tests.md`, `tasks.md`, `traceability.md`) is
only enforced when a feature name is passed as `$2`, which the verification
command in this task does not do. This spec package therefore matches
AGENTS.md's "Source Artifact Locations" list (`AGENTS.md:100-106`:
requirements/design/tasks/acceptance-tests/traceability) plus
`investigation.md` (present on every reference spec this session inspected,
e.g. `specs/epic-159-pillar-c/investigation.md`), and does not add the four
layer-specific specs (`ux-spec.md`/`frontend-spec.md`/`infra-spec.md`/
`security-spec.md`) that `epic-159-pillar-c` happened to need for its
multi-layer scope — Epic A2 has no UX/frontend layer and its infra/security
surface is covered inline in `design.md`.

## INV-013: No prior Epic A1/A3 spec exists to align with

Local branches `feature/epic-189-a1-project-context` and
`feature/epic-191-a3-path-ownership` exist (other parallel worktrees) but, as
of this investigation, both point at the same commit as this branch's base
(`b085ec7`, the epic-188 ADR work) with no additional Epic-A1/A3-specific
commits (`git log feature/epic-189-a1-project-context --oneline` shows no
commit beyond the shared ADR history). There is therefore no established,
already-implemented Project Context file convention this spec can defer to;
INV-010's `contracts/` vs `sdd/` reasoning is this spec's own,
explicitly-flagged judgment call (design.md, Design Decisions), made because
the orchestrator's instructions require Epic A2 to name a location now rather
than block on Epic A1 landing first.

## INV-014: Script-pair and test-registration conventions

Script convention (decision v2 §18.3, restated for general scripts in the
orchestrator brief): "Python master + sh/ps1 wrappers, the `sdd-hook-guard`
approach." Test convention: `tests/<name>.tests.sh` + `tests/<name>.tests.ps1`
pairs, each registered directly in `tests/run-all.sh` / `tests/run-all.ps1`
(confirmed unprotected — `tests/agent-capabilities-v2.tests.ps1` appears at
`tests/run-all.ps1:27` with no human-copy step in that precedent) **and**
wired into `.github/workflows/test.yml` (confirmed protected — `test.yml` is
in `PROTECTED_GATE_SUFFIXES`, INV-009 — so `.github/workflows/test.yml`
edits go through human-copy, matching `epic-159-pillar-c`'s own T-001/T-003/
T-005 procedure of staging `specs/<feature>/human-copy/.github/workflows/test.yml`
+ `MANIFEST.sha256` for a human `cp`).

## INV-015: 3-environment packaging obligation bears on plugin placement (decision v2 §16)

`docs/ai-dlc-foundation-decision-v2.md:245-258` (§16) makes sh+ps1 script
pairs, Claude/Codex/Copilot plugin configuration, and environment-specific
tests a **per-Epic Done condition**, explicitly forbidding deferral to a
later Epic (e.g. A8). A *new* plugin therefore carries its own manifest
(`.claude-plugin/plugin.json`, `.codex-plugin/`, copilot-agents/hooks
equivalents — confirmed structure: `plugins/sdd-quality-loop/.claude-plugin/`,
`.codex-plugin/`, `hooks/{claude-hooks.json,hooks.json,copilot-hooks.json}`,
`copilot-agents/`), its own install/uninstall path, and its own 3-environment
test wiring — none of which this spec's first draft scoped into REQ/AC/TEST
for the proposed `plugins/sdd-capability/` plugin. Placing Epic A2's scripts
inside the existing `plugins/sdd-quality-loop/` plugin instead (which already
carries a complete, working 3-environment manifest set) avoids incurring this
packaging cost a second time for no stated benefit beyond semantic separation.
Per orchestrator ruling 2026-07-22, the new-plugin proposal is rejected on
this basis (design.md Design Decisions records it as a rejected alternative).

## INV-016: `${CLAUDE_PLUGIN_ROOT}`-style plugin-root resolution exists, but is host-specific, not a cross-runtime contract

`plugins/sdd-quality-loop/hooks/claude-hooks.json:2,11` confirms
`${CLAUDE_PLUGIN_ROOT}` is expanded by Claude Code itself before spawning a
hook command, and is already used to locate a script relative to the
installed plugin's own root rather than a repository-root-relative path;
`hooks/hooks.json` (Codex CLI) and `hooks/copilot-hooks.json` (Copilot CLI)
are described as "the two runtime-specific analogs" in the same file's own
description comment, but neither of those two files was inspected to
confirm they expose an *equivalent, identically-named* environment
variable — this spec's second draft cited the comment's own characterization
without verifying it, which the 2026-07-22 verification pass correctly
flagged as unconfirmed (orchestrator ruling P10). Per that ruling, REQ-005's
Registry-discovery contract (design.md) does **not** build on this pattern:
it resolves the packaged copy relative to the invoking script's own
symlink-resolved real file path instead, which requires no per-runtime
environment variable at all and therefore does not depend on whether Codex
CLI/Copilot CLI expose one. This INV entry is retained as a repository fact
about the hooks layer's own design, not as the discovery contract's basis.

## Open Questions

Each entry below records this spec's original disposition and, where the
2026-07-22 adversarial spec review (18 findings) required a change, the
orchestrator's ruling that supersedes it. No entry below authorizes changing
`Spec-Review-Status`/`Impl-Review-Status` — both remain `Pending` for a human
reviewer.

- **OQ-001 — `lite_policy.upgrade_reasons` vocabulary.** Status: **partially
  resolved (orchestrator ruling 2026-07-22)**. Original disposition:
  ADR-0022's YAML example (5 tokens) is narrower than its own prose (11
  categories); this spec's schema treats the field as an open string array so
  neither list is silently picked. The adversarial review (Major finding)
  correctly noted that an unconstrained open string makes Epic A6's upgrade
  decision typo-dependent with no automated safety net. Ruling: the
  vocabulary itself is **not** frozen (OQ-001 remains open on that point —
  freezing it is still Epic A6's decision, ADR-0022 item 4), but REQ-003 now
  adds an eighth validator check, (h): every `upgrade_reasons` token must
  resolve against a versioned reason catalog (`contracts/lite-upgrade-
  reason-catalog.json`, a new implementation-phase contract, additive/
  versioned rather than a closed schema enum); an unrecognized token is a
  fail-closed validation error, not a silent pass. See requirements.md
  REQ-003(h)/AC-022, design.md's validator contract.
- **OQ-002 — "trigger" vs. "conditions."** Status: **RESOLVED (orchestrator
  ruling 2026-07-22)**. Decision v2 §13's field list names "trigger" and
  "conditions" as two separate items, but ADR-0020 defines exactly one
  condition concept (the Predicate DSL), used identically for `trigger` and
  for `conditional_facets[].when`. The orchestrator's ruling confirms this
  spec's original reading as the authoritative interpretation: "conditions"
  in decision v2 §13 describes the DSL body itself, not a third schema field.
  The schema holds the Predicate DSL in exactly two places —
  `capabilities[].trigger` and `capabilities[].conditional_facets[].when` —
  and introduces no top-level `conditions` field. This is recorded as the
  confirmed interpretation of decision v2 §13 pending the source document's
  own next revision, which is expected to state it explicitly; until then,
  this ruling is authoritative for Epic A2's schema and is not re-litigated
  at each subsequent review pass.
- **OQ-003 — `delivery_strategy.kind` vocabulary.** Status: **RESOLVED, and
  reversed from this spec's first draft (orchestrator ruling 2026-07-22,
  correcting a Blocker finding)**. "delivery strategy kind" is mentioned
  exactly once in decision v2 (`docs/ai-dlc-foundation-decision-v2.md:401`)
  as a field that must exist; decision v2 elsewhere (§10, §16, §17 —
  `:118-120`, `:399-402`, `:488-492`) explicitly reserves vocabulary-freezing
  for a later ADR triggered by a real cloud-service delivery case, the same
  pattern ADR-0017 already applies to the Artifact/Promotion Gate vocabulary.
  This spec's first draft inferred a closed four/five-value enum from decision
  v2 §17's Pack rollout order and described it inconsistently as a
  "four-value enum" while listing five literals — both the closed-enum
  inference and the internal miscount contradicted the source. Ruling:
  `delivery_strategy.kind` is a reserved, **open, non-empty string** field
  with no defined vocabulary in Foundation; its semantics are determined by a
  real-case ADR after Epic A2 ships, not inferred here.
- **OQ-004 — unregistered-script detection mechanism.** Status: **closed
  (orchestrator ruling P8, 2026-07-22)**. The line below records the
  intermediate "materially expanded" state this bullet was first drafted
  against; the Adversarial Spec Review Response section (below) records the
  same-day P8 ruling that fully closed it by fixing all four dimensions
  (canonical `.py` reference, the single concrete scan root, the `check-`
  prefix gate-shaped-script rule, and same-basename wrapper grouping)
  concretely rather than by example — this line is updated to match rather
  than left at its pre-P8 wording. "未登録 script なし"
  (no unregistered script) needs a discovery convention to check both
  directions (every `stage: implementation` Gate has exactly one implementing
  script; every gate-shaped script is registered). No such enumeration
  convention exists in decision v2 or any ADR; this remains this spec's own
  design proposal, not a quoted requirement. The adversarial review correctly
  identified that the first draft's bare `implementation_ref` + "configured
  directories" left scan roots, recognized extensions, symlinks, and
  sh/ps1-wrapper grouping (one Python master implementing one Gate via two or
  three wrapper files, not two or three separate "unregistered" scripts)
  undefined. design.md now specifies a **Gate implementation identity**
  schema covering all of these (REQ-003(c)/AC-016/AC-017), still flagged as
  this spec's own proposal, not found verbatim in decision v2 or an ADR.

## Summary of Evidence References

- `docs/ai-dlc-foundation-decision-v2.md` §3 (Q2, Gate stages), §6 (Q5, lite
  matrix and `lite_policy`), §10 (Q9, effective enforcement), §11 (Q10,
  Predicate DSL), §13 (Q12, Registry/Pack split, projection), §16 (Q15,
  per-Epic 3-environment Done condition), §17 (Q16, Pack rollout order),
  §18.3 (canonical hash), §19 (Epic A2 scope)
- ADR-0017 (Gate Stage Model), ADR-0018 (Provider Binding Separation),
  ADR-0020 (Conditional Predicate DSL), ADR-0021 (Context Projection
  Staleness), ADR-0022 (Lite Capability Upgrade)
- `plugins/sdd-quality-loop/references/guard-invariants.json`,
  `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`,
  `plugins/sdd-quality-loop/scripts/generated/*`
- `plugins/sdd-quality-loop/hooks/claude-hooks.json`,
  `plugins/sdd-quality-loop/.claude-plugin/plugin.json`
- `contracts/agent-model-capabilities.v2.json`,
  `contracts/workflow-state-registry.schema.json`
- `specs/epic-136-phase2-gates/human-copy/` (MANIFEST.sha256,
  apply-protected-files.ps1)
- `AGENTS.md:79-119`, `scripts/check-sdd-structure.sh`,
  `plugins/sdd-quality-loop/scripts/check-workflow-state.sh`,
  `specs/workflow-state-registry.json`,
  `contracts/workflow-state-registry.schema.json`

## Adversarial Spec Review Response (orchestrator ruling 2026-07-22)

An 18-finding adversarial review (4 Blocker, 11 Major, 1 Minor, 2 OK) was
conducted against this spec package. All 18 findings were accepted; the
orchestrator's rulings are recorded at the point of each affected REQ/AC/
design decision rather than duplicated here. This section is a pointer index
only — it does not itself change `Spec-Review-Status`/`Impl-Review-Status`,
both of which remain `Pending`:

- Blocker 1 (`trigger`/`conditions`) → OQ-002 above (RESOLVED).
- Blocker 2 (`delivery_strategy.kind` closed enum) → OQ-003 above (RESOLVED,
  reversed); requirements.md AC-004; design.md API / Contract Plan.
- Blocker 3 (JSON projection header contradiction) → requirements.md REQ-005/
  AC-025; design.md API / Contract Plan (`_generated` object is now the only
  header contract named anywhere in this package).
- Blocker 4 (AC↔TEST 1:1 false) + Major "REQ-003 bidirectional completeness
  gaps" → acceptance-tests.md was fully renumbered and cross-checked against
  requirements.md's Acceptance Criteria; REQ-003(c)/(e) now have their own
  AC-017/AC-018 and TEST-017/TEST-018.
- Major "AC-003 unvalidatable schema-level dynamic reference" → folded into
  AC-021 (validator-only referential integrity); no AC claims schema-level
  dynamic cross-reference checking.
- Major "`upgrade_reasons` typo-dependent" → OQ-001 above; REQ-003(h)/AC-022.
- Major "`implementation_ref`+scan incomplete" → OQ-004 above; REQ-003(c)/
  AC-016/AC-017. **Marked PARTIAL by the 2026-07-22 verification pass**
  (scan roots/canonical-reference extension/gate-shaped-script rule were
  still stated by example, not concretely); **fully closed same day per
  orchestrator ruling P8**: `implementation_ref` is now always the `.py`
  master; the sole scan root is the concrete literal
  `plugins/sdd-quality-loop/scripts/`; gate-shaped = `check-`-prefixed
  basename; wrapper group = same-directory, same-basename `.sh`/`.ps1`/
  `.js` siblings.
- Major "new `sdd-capability` plugin ignores 3-env packaging cost" → INV-015
  above; design.md Architecture/Design Decisions (rejected-alternative
  paragraph); all script paths moved under `plugins/sdd-quality-loop/`.
- Major "Registry discovery for installed plugin" → INV-016 above; design.md
  API / Contract Plan (Registry discovery contract); requirements.md AC-027.
  **Marked PARTIAL by the 2026-07-22 verification pass** (the runtime
  plugin-root environment-variable dependency was unverified for two of the
  three runtimes, and the version check/vendored-copy-drift-check gaps
  remained); **fully closed same day per orchestrator ruling P10**:
  discovery is now script-relative (no environment variable of any kind),
  falls back to a `git`-resolved repository root, defines a distinct
  version check per artifact, and adds a release-gating vendored-copy
  digest-equality check.
- Major "A1 schema/canonicalizer dependency undefined" → INV-004a above;
  requirements.md Dependencies (REQ-004 blocked statement); AC-011.
- Major "`registry_digest` fragment identity undefined" → requirements.md
  AC-024; design.md `registry_digest` generator contract.
- Major "dual-runtime/3-env parity claims outrun tests" → requirements.md
  AC-031/AC-032/AC-033.
- Major "evaluator Evidence/operator coverage ambiguous" → requirements.md
  AC-012/AC-013.
- Major "TEST-021 time-dependent" → acceptance-tests.md's Spec-Authoring-Time
  Manual Review Record (moved out of the Planned implementation-phase table).
- Minor "six files vs. four Phase-1 files" → requirements.md Roles and
  Permissions (corrected to "four"); acceptance-tests.md AC-035/AC-036 split
  (Phase 1 OQ audit vs. Phase 2 traceability audit).
- OK "`contracts/`/JSON placement" → design.md Design Decisions (wording
  clarified: repo-local judgment, not a source-document necessity).
- OK "Gate stage/`minimum_enforcement` interpretation" → kept as-is;
  requirements.md AC-005 adds the positive/negative schema test and the
  reserved-stage inertness test the finding requested.
