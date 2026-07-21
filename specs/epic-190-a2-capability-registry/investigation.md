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

## Open Questions

- **OQ-001**: `lite_policy.upgrade_reasons` — ADR-0022's YAML example (5
  tokens) is narrower than its own prose (11 categories). This spec's schema
  (design.md) treats the field as an open string array precisely to avoid
  silently picking one list over the other; a human should decide whether to
  freeze a closed enum in a later ADR amendment. Not blocking for Epic A2
  (the field only needs to exist and be structurally valid; its vocabulary is
  Epic A6's concern per ADR-0022 item 4).
- **OQ-002**: decision v2 §13's field list names "trigger" and "conditions" as
  two separate items, but ADR-0020 defines exactly one condition concept (the
  Predicate DSL), used identically for `trigger` and for
  `conditional_facets[].when`. This spec's schema (design.md) resolves this by
  treating "conditions" as describing the DSL body itself, not a third field:
  a Capability entry has exactly one predicate field (`trigger`); required
  facets are unconditional; conditional facets each carry their own nested
  `when`. Flagged for human confirmation at spec review, not silently
  resolved without a trace.
- **OQ-003**: "delivery strategy kind" is mentioned exactly once in decision
  v2 (`docs/ai-dlc-foundation-decision-v2.md:401`) with no defined vocabulary
  anywhere else. This spec infers the vocabulary from decision v2 §17's own
  Pack rollout order (`docs/ai-dlc-foundation-decision-v2.md:488-492`:
  developer-tooling/cli-library → desktop → cloud-service → durable-workflow)
  as the closest documented enumeration of "kinds" of delivery shape, and
  documents this inference explicitly in design.md rather than treating it as
  settled fact.
- **OQ-004**: "未登録 script なし" (no unregistered script) needs a discovery
  convention to check both directions (every `stage: implementation` Gate has
  exactly one implementing script; every gate-shaped script is registered).
  No such enumeration convention exists in the repository today. design.md
  proposes a `implementation_ref` field per Gate plus a configured list of
  scanned script directories; this is this spec's own design proposal (not
  found verbatim in decision v2 or an ADR) and is flagged as such.

## Summary of Evidence References

- `docs/ai-dlc-foundation-decision-v2.md` §3 (Q2, Gate stages), §6 (Q5, lite
  matrix and `lite_policy`), §10 (Q9, effective enforcement), §11 (Q10,
  Predicate DSL), §13 (Q12, Registry/Pack split, projection), §17 (Q16, Pack
  rollout order), §18.3 (canonical hash), §19 (Epic A2 scope)
- ADR-0017 (Gate Stage Model), ADR-0018 (Provider Binding Separation),
  ADR-0020 (Conditional Predicate DSL), ADR-0021 (Context Projection
  Staleness), ADR-0022 (Lite Capability Upgrade)
- `plugins/sdd-quality-loop/references/guard-invariants.json`,
  `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`,
  `plugins/sdd-quality-loop/scripts/generated/*`
- `contracts/agent-model-capabilities.v2.json`,
  `contracts/workflow-state-registry.schema.json`
- `specs/epic-136-phase2-gates/human-copy/` (MANIFEST.sha256,
  apply-protected-files.ps1)
- `AGENTS.md:79-119`, `scripts/check-sdd-structure.sh`,
  `plugins/sdd-quality-loop/scripts/check-workflow-state.sh`,
  `specs/workflow-state-registry.json`,
  `contracts/workflow-state-registry.schema.json`
