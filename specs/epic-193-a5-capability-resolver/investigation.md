# Investigation: epic-193-a5-capability-resolver

Source: Issue #193 (Epic A5 — Capability Resolver), tracked under epic #187
(AI-DLC Foundation) / `docs/ai-dlc-foundation-decision-v2.md` §19 (Epic A5),
§11 (Q10, DSL), §16 (Q15, staleness binding), §2 (Q1, three-axis model) /
ADR-0016, ADR-0017, ADR-0019, ADR-0020, ADR-0021, ADR-0023, ADR-0025.

## INV-001: Epic A5's normative scope is "produce the artifact A4 already typed, from inputs A1-A3 already fixed" — not a fresh architectural decision

Decision document v2 §19 sequences Epic A5 last among A1-A5 specifically so
"Resolver 本体より先に正本・承認・条件言語・path ownership を固定する" (§20).
Issue #193's own scope line states the input set explicitly: "Project
Context / Affected Components（**Epic A3 の決定論的導出のみ**。v1 にあった
「Change Characteristics」は削除済み — 自己申告入力を新設しない）/ Registry"
and the output set: "Facet Manifest / Capability Summary / Context
Projection / Resolver Evidence（DSL 全述語の評価結果を記録）". Issue #193
also fixes the implementation shape directly: "agent skill ではなく、
Bash／PowerShell から呼び出せる決定論的 script" (decision doc v2 §7,
"実装方針": "`capability-resolver` は agent skill ではなく Bash／
PowerShell から呼び出せる決定論的 script とする"). Every field this
feature's output artifacts carry, every input contract it consumes, and the
Predicate DSL it evaluates are already Accepted (ADR-0020/ADR-0021) or
`Spec-Review-Status: Passed` (Epic A1/A2/A3/A4, verified directly against
each sibling worktree's own `requirements.md` header, INV-002 below) before
this investigation begins. This feature's own design latitude is
correspondingly narrow: it fixes the Resolver's own CLI/orchestration
contract (which no upstream ADR or sibling spec defines, INV-012/INV-018
below) and the shape of `Resolver Evidence` (an A5-owned artifact no
sibling spec defines, INV-019 below); it does not redefine any field, enum,
digest-binding rule, or evaluation semantic Epic A1-A4 or ADR-0016/0017/
0019/0020/0021/0023/0025 already fix.

## INV-002: All four upstream sibling epics (A1-A4) are `Spec-Review-Status: Passed`, confirmed directly against each worktree

`head -6` of each sibling worktree's own requirements.md, run at
investigation time:

- `/Users/jrmag/Projects/active/sdd-forge-wt-epic-189/specs/epic-189-a1-project-context/requirements.md`: `Spec-Review-Status: Passed`.
- `/Users/jrmag/Projects/active/sdd-forge-wt-epic-190/specs/epic-190-a2-capability-registry/requirements.md`: `Spec-Review-Status: Passed`.
- `/Users/jrmag/Projects/active/sdd-forge-wt-epic-191/specs/epic-191-a3-path-ownership/requirements.md`: `Spec-Review-Status: Passed`; its `design.md` additionally carries `Impl-Review-Status: Passed` and a `tasks.md` (`Task-Review-Status: Pending`) — A3 is furthest along of the four.
- `/Users/jrmag/Projects/active/sdd-forge-wt-epic-192/specs/epic-192-a4-facet-manifest/requirements.md`: `Spec-Review-Status: Passed` (its `design.md` carries `Impl-Review-Status: Pending`).

None of the four has landed on `main` yet — each lives on its own feature
branch/worktree, and none has authored `tasks.md` except A3 (Draft-review
stage only). `contracts/` in this worktree (`sdd-forge-wt-epic-193`, based
off the same pre-Epic-A0-merge commit as every sibling worktree) contains
none of the schema files any of A1/A2/A3/A4 defines
(`project-context.schema.json`, `provider-bindings.schema.json`,
`approval-sidecar.schema.json`, `capability-registry.schema.json`,
`facet-manifest.schema.json`, `capability-summary.schema.json`,
`context-projection.schema.json`) — confirmed by `ls contracts/` returning
only the twelve pre-existing contract files unrelated to this Epic set.
This feature is therefore, like its four upstream siblings, a Phase 1
(schema/contract-fixing) spec package with no live implementation to build
against yet — it fixes contracts other future implementation tasks (this
epic's own, and the sibling epics') will build against.

## INV-003: `resolve-project-context.{py,sh,ps1}` and `generated/project-context.resolved.json` are Epic A1's forced-handoff reservation to Epic A5 — the Resolver's canonical script name is not this feature's own choice

Epic A1's `design.md` Components table (`specs/epic-189-a1-project-context/design.md:143-144`)
lists two RESERVED, protected-suffix-shaped placeholders:

```
plugins/sdd-quality-loop/scripts/resolve-project-context.{py,sh,ps1}
  — "RESERVED path for a future Capability Resolver (Epic A2/A5) — not built by A1"
plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json
  — "RESERVED path for a future generated projection (Epic A2/A5) — not built by A1"
```

Both are already registered in A1's Protected-File Statement
(`design.md:195-196`) under the row `Resolver (ADR-0019 item 3)` /
`Generated projection (ADR-0019 item 3)`, each marked `RESERVED, not
built — forced handoff to A2/A5`, contributing 4 of the "24 concrete + 4
reserved = 28 entries" A1's own PROTECTED-MANIFEST accounts for. ADR-0019
item 3 itself names this category directly: "the canonicalizer, hash
generator, approval validator, policy-weakening detector, **resolver**,
and any generated projection are added to guard-invariants
(`PROTECTED_GATE_SUFFIXES`), an explicit Epic A1 deliverable." Epic A4's
own Non-goals independently confirm the same naming and scope split:
"Implementing `resolve-project-context.{py,sh,ps1}` — Epic A1 reserved
this name/path (INV-007); this feature fixes only what the file it
eventually produces must contain (REQ-003)" — i.e. A4 fixes the *shape* of
the Context Projection this script writes; **Epic A5 is the epic that
builds the script's content**, per A4's own REQ-003 "Generation procedure
(normative for Epic A5's future implementation, not built by this
feature)" (`specs/epic-192-a4-facet-manifest/design.md:610-647`).

Consequence for this feature's design (elaborated in design.md's
Protected-File Statement): unlike Epic A3's `resolve-component-paths.*`,
which A3's own investigation confirmed is **not** in
`protected_gate_suffixes` (A3 `design.md:233-239`, "No other file this
feature creates or edits (`resolve-component-paths.*`, ...) appears in
`PROTECTED_GATE_SUFFIXES`"), the Capability Resolver's canonical script
path is **already reserved as protected** by an upstream epic before this
feature's own first line of implementation exists. Grepping the live
`guard-invariants.json` in this worktree for either reserved path returns
no hit today (`grep -n "resolve-project-context" plugins/sdd-quality-loop/references/guard-invariants.json`
→ no match) — because this worktree branched before Epic A1's own
`REQ-007` human-copy batch (which performs that registration) has landed.
By the time Epic A5's implementation phase begins (Epic A1 → A2/A3
(parallel) → A4 → A5 per issue #187's own stated sequencing), the
reservation is expected to already be live, meaning Epic A5's own first
write to that exact path is denied by the hook guard exactly like Epic
A3's `check-component-coverage.*` was denied for a *different* reason (a
new protected-suffix registration *this* epic performs, A3's situation 3)
— here the registration was performed by a *different*, upstream epic.
This feature's own implementation-phase tasks (Phase 2, out of this
Phase-1 package's scope) must therefore stage the Resolver's initial
content under `specs/epic-193-a5-capability-resolver/human-copy/` with a
`MANIFEST.sha256` entry, for human application via `apply-human-copy` (A1
REQ-007's own publisher), never a direct agent write to the live path —
this is a content-population human-copy (the two paths are already
suffix-registered by A1), not a suffix-registration human-copy (A1 already
performed that registration); no further `guard-invariants.json` edit is
implied unless a future task needs additional protected files beyond
these two.

## INV-004: Epic A4 already fixes, and content-freezes, the exact shape of every artifact this feature must produce except Resolver Evidence

`specs/epic-192-a4-facet-manifest/design.md`'s API / Contract Plan defines
three schemas verbatim:

- `contracts/facet-manifest.schema.json` (`sdd-facet-manifest/v1`):
  `schema`, `feature`, `affected_components`, `required_facets`,
  `conditional_facets[]` (`{facet, applied, reason?, evidence[]}`),
  `resolved_gates[]` (`{id, stage, blocking}`), `capabilities`,
  `capability_minimum_enforcement?` (`const: "required"` only),
  `lite_eligibility` (`{eligible, upgrade_reasons[]}`), `context_binding`
  (`{full_context_revision, dependency_pointers[], projection_sha256,
  registry_digest, ownership_digest}`), `resolver` (`{version,
  rule_set_revision}`).
- `contracts/capability-summary.schema.json` (`sdd-capability-summary/v1`,
  Lite track only): `schema`, `feature`, `track` (`const: "lite"`),
  `capabilities`, `required_lite_checks`, `full_upgrade_required` — no
  full-track shape exists ("M full Summary" finding, A4 Non-goals).
- `contracts/context-projection.schema.json` (`sdd-context-projection/v1`):
  `schema`, `source_sha256`, `provider_bindings_sha256?`, `workflow`,
  `components` (object, re-keyed by component `id`), `shared_paths[]`.

A4's `design.md` also fixes, **normatively for this feature to implement**
(its own words, `design.md:610`, "Generation procedure ... normative for
Epic A5's future implementation, not built by this feature"), the exact
two-pass canonicalizer procedure that turns `project-context.yaml` into
`project-context.resolved.json`: (1) `canonicalize-sdd-yaml` in YAML mode
over `project-context.yaml` → hash = `source_sha256` = `context_binding.
full_context_revision`, stdout also `json.loads()`-parsed by the caller
(never a second YAML parse); (2) substitute `components: []`/
`shared_paths: []` for either omitted key, re-key `components` by `id`
(sound only because A1 already guarantees `id` uniqueness upstream); (3)
feed the re-keyed structure back through `canonicalize-sdd-yaml` in JSON
mode → `projection_sha256`; (4) write to the exact reserved path INV-003
names.

Because Epic A4's `Spec-Review-Status: Passed` header places these three
schemas under the repository's "Post-review artifact freeze" convention
(`AGENTS.md`, "Once a review gate passes, its hash-bound artifacts ... are
content-frozen except for the normalized status/approval fields"), this
feature does not, and structurally cannot, propose any field this feature
would need Epic A4 to add — every field this feature's Resolver populates
already has a named home in one of the three schemas above. Epic A4's own
Roles and Permissions section names the consumer directly:
"**Epic A5's Resolver implementer**: the sole intended writer of live
`facet-manifest.yaml`/`capability-summary.yaml`/`project-context.
resolved.json` instances" (`requirements.md:1187-1189`).

## INV-005: Epic A2 already fixes the Registry schema, the Predicate DSL evaluator's single-component CLI shape, the `registry_digest` generator, and (via ADR-0025) the discovery contract this feature reuses unmodified

`specs/epic-190-a2-capability-registry/design.md`'s API / Contract Plan:

- `contracts/capability-registry.schema.json` (`capability-registry/v1`):
  `gates[]` (`{id, stage, blocking, implementation_ref?}`), `capabilities[]`
  (`{id, trigger, required_facets[], conditional_facets[], review_check_ids[],
  gate_ids[], lite_policy? {eligible, upgrade_reasons[]},
  minimum_enforcement? (const "required"), delivery_strategy {kind}}`).
  `#/definitions/predicate` (shared by `trigger` and
  `conditional_facets[].when`) is exactly ADR-0020's DSL shape:
  `all`/`any`/`not` logical nodes, and a leaf `{scope: "affected_component",
  field: <8-value allowlist enum>, operator: <5-value enum>, value?}` node.
- **Predicate DSL evaluator contract**: `evaluate-predicate.py --predicate
  <path|-> --component-properties <path|-> ` → stdout JSON `{"result":
  bool, "evidence": [...]}`, **exit 0 always** for a well-formed predicate
  (a `false`+`WARN` result is a normal, successful evaluation per ADR-0020,
  never an error); a malformed predicate/field-outside-allowlist/bad-`not`-shape
  is a **distinct** non-zero-exit `PREDICATE_SCHEMA_ERROR` — never conflated
  with a `WARN`. Critically, **the CLI takes exactly one
  `--component-properties` object per invocation** — there is no built-in
  multi-component fan-out anywhere in Epic A2's own contract (INV-012,
  below, is what this feature must resolve as a consequence).
- Evidence JSON Schema (each `evidence[]` element): `{operator, path,
  outcome (match|no-match|warn), reason?, children?}`, depth-first
  left-to-right stable order, `outcome: "warn"` requires `reason`
  (`if`/`then`). A4's own `evidenceNode` definition is this shape
  transcribed verbatim (`facet-manifest.schema.json`'s
  `#/definitions/evidenceNode`), so this feature embeds
  `evaluate-predicate`'s own array output directly — no re-shaping step.
- **`generate-registry-digest.py (--capability-ids <ids> | --gate-ids <ids>
  | --whole)`** → stdout the sha256 hex digest of the canonical-JSON
  fragment; **which flag to use is explicitly left to this feature**:
  Epic A2's own REQ-004 states "the fragment selection itself" is "Epic
  A5's Resolver concern, not Epic A2's" (A2 `investigation.md` INV-019
  cross-reference) — except Epic A4 already made that choice on this
  feature's behalf (INV-006, below): `context_binding.registry_digest`
  is fixed as `generate-registry-digest --whole`.
- **Registry discovery contract**, promoted verbatim to
  `docs/adr/0025-registry-discovery-contract.md` (Accepted, 2026-07-21, in
  the Epic A2 worktree — not yet present in this worktree's own
  `docs/adr/`, confirmed by `ls docs/adr/` returning only 0001-0024;
  citable as an Accepted, cross-Epic ADR regardless, since ADR-0025's own
  Context section names Epic A5's Resolver as "the first concretely named
  case" of a future consumer): script-relative real-path resolution →
  `../contracts/<filename>` packaged-copy check → git-root fallback
  (`git rev-parse --show-toplevel` or a `.git`-walk) →
  `<git-root>/contracts/<filename>` → fail closed with both attempted
  paths named. Each artifact defines its own version check (a `schema`
  const, or a `$schema`+`$id` pair for a schema document itself) — never
  one shared rule. This feature reuses this contract unmodified for
  **every** `contracts/*` artifact it locates: `capability-registry.json`,
  `capability-registry.schema.json`, `facet-manifest.schema.json`,
  `capability-summary.schema.json`, `context-projection.schema.json`, and
  its own new `resolver-evidence.schema.json` (INV-019, below) —
  inventing a second discovery algorithm for any of these would directly
  contradict ADR-0025's own stated purpose ("Epic A5's Resolver being the
  first concretely named case" of "adopts this same three-step procedure
  rather than inventing a second, divergent convention").

## INV-006: Epic A3 already fixes the affected-components CLI, output shape, `ownership_digest` full-input binding, and the state-derivation pattern this feature's own state-awareness (REQ-003) must replicate — but not identically

`specs/epic-191-a3-path-ownership/design.md` API / Contract Plan:

- `resolve-component-paths --config <project-context.yaml> [--source-rev
  HEAD] --target-rev <rev> [--include-untracked] [--json]` — exit 0 on a
  clean resolve (UNOWNED/OVERLAP classifications present in the output are
  data, not failure, by themselves); non-zero on a config-shape error, an
  unresolvable rev/unattainable merge-base, an NFC-collision, an exceeded
  rename limit, or a TOCTOU mismatch after one retry. Output (Data Plan,
  `design.md:351-364`): a per-changed-path array (raw/normalized path,
  classification, owning_components, evidence), a top-level
  `affected_components: string[]` (union of EXCLUSIVE owners and touched
  bounded-`shared_paths` components — **cross-cutting shared-paths never
  contribute**), and `ownership_input` (**every** declared `paths`/
  `shared_paths` entry, unconditionally, not a per-resolve-scoped subset)
  feeding `ownership_digest` (full-input binding, computed via Epic A1's
  canonicalizer — the identical soundness argument Epic A4 reapplies to
  `registry_digest`, INV-005 above: "a Capability's `trigger` match/
  no-match outcome is a function of the current Context Projection, so no
  proper subset ... can be soundly treated as not consumed").
- `check-component-coverage --config <...> [--source-rev HEAD] --target-rev
  <rev> --facet-manifest <path>` derives one of three states from
  `workflow.capability_enforcement`/the ADR-0016 file-absence fallback
  **every time it runs, unconditionally** (`disabled-legacy` → zero
  evaluation, `state: "not-applicable (disabled-legacy)"`, exit 0;
  `advisory` → full evaluation and recording, exit always 0 regardless of
  any Fail condition; `required` → full evaluation, exit non-zero iff a
  Fail condition triggers) — **and always emits an evidence record, never
  a bare skip line, even in `disabled-legacy`** (A3's own NEW-001 finding,
  `design.md:444-446`).

This is the pattern this feature's REQ-003 replicates for the *derivation
rule itself* (same three states, same `workflow.capability_enforcement`/
ADR-0016-file-absence source), but **not** for the *`disabled-legacy`
consequence* — see INV-013, below, for why the Resolver's own behavior in
`disabled-legacy` deliberately diverges from `check-component-coverage`'s
graceful no-op.

## INV-007: Epic A1 already fixes the Project Context schema, the canonicalizer's stdin/stdout-only CLI shape, and the ADR-0016 disabled-legacy derivation rule this feature reuses unmodified

`contracts/project-context.schema.json` (per A1 `design.md:441-523`):
top-level `schema` (`sdd-project-context/v1`), `workflow` (`spec_profile`
∈ {full,lite}, `artifact_layout` ∈ {lite-three-file, legacy-seven-layer,
facet-hybrid, facet-native}, `capability_enforcement` ∈ {advisory,
required} — **no `disabled-legacy` value in the schema itself**, confirming
it is purely a derived, absent-file state per ADR-0016 item 4, never a
value an author writes), `components[]` (`id`, `artifact_kinds[]`,
`runtime_classes[]`, `platform_targets[]`, `characteristics` (7 booleans:
`pii`, `ui`, `auto_update`, `local_persistence`, `long_running`,
`replayable`, `human_in_the_loop`), `distribution_channels[]`,
`data_classification[]`, `provider_binding_ids[]`, `paths` (`include[]`,
`exclude[]`)), `shared_paths[]`. `components[].id` uniqueness is enforced
by A1's own content-schema validation step (REQ-005), not by the JSON
Schema document itself (draft-07 cannot express array-item-key-uniqueness
against a plain array-of-objects shape) — this feature's Context Projection
re-keying step (INV-004) depends on that upstream guarantee and performs no
uniqueness check of its own.

`canonicalize-sdd-yaml.{py,sh,ps1,js}` (A1 `design.md:656-705`) is a
stdin/stdout-only CLI over **either** YAML or JSON input mode, emitting
canonical UTF-8 bytes (or `sha256:<hex>` in `--hash-only` mode) on stdout
and nothing else — **it has no parsed-structure API** (A4's own `design.md`
corrects an earlier draft that assumed one, `design.md:610-616`); every
consumer, including this feature, must `json.loads()` its stdout
independently to obtain a manipulable structure, exactly as A4's Context
Projection generation procedure already does twice in sequence (INV-004).

ADR-0016 item 4's `disabled-legacy` derivation rule (§2 of the decision
document): absent `project-context.yaml` + `AGENTS.md` `spec_profile: lite`
marker → `spec_profile: lite`/`artifact_layout: lite-three-file`/
(capability mechanism inactive); absent, otherwise → `spec_profile: full`/
`artifact_layout: legacy-seven-layer`/(capability mechanism inactive).
Present `project-context.yaml` → `workflow.*` fields are the sole source
of truth, and `capability_enforcement` is always `advisory` or `required`
(never `disabled-legacy`, which is not a value in that field's own enum).

## INV-008: ADR-0020's evaluation semantics are already Accepted and must not be reinterpreted by this feature — but they leave the multi-component fan-out entirely open (INV-012 resolves it, as this feature's own orchestration layer, not a DSL change)

ADR-0020 item 4 (evaluation semantics) is quoted verbatim in
`docs/adr/0020-conditional-predicate-dsl.md:46-79`: fail-closed-plus-`WARN`
for `equals`/`not_equals`/`contains`/`in` on a missing path, `null`, or a
type mismatch; `exists`'s override (path exists → `true` even if the value
is `null`; path absent → `false`+`WARN`); `all`/`any` never short-circuit,
every child is evaluated and recorded; `not` inverts its child's boolean
only, never inherits a child's `WARN` reason onto itself (A2's own
`design.md:443-447` fixes the same truth table).
None of this is renegotiable by this feature — Epic A2's evaluator already
implements it, and this feature's only job regarding the DSL itself is to
**call** `evaluate-predicate` correctly and record its output verbatim.
What ADR-0020 does *not* fix, and what no sibling epic's spec fixes either
(confirmed by grepping A1/A2/A3/A4's `design.md`/`requirements.md` for
"multi-component"/"per-component"/"fan-out": no hit in any of the four),
is **how a Resolver evaluating one `trigger`/`when` predicate against a
Feature's potentially *several* affected components should combine the
per-component results into one Feature-level match/no-match** — this is
this feature's own orchestration decision (design.md's Design Decisions),
not a DSL semantics change, and it is scoped narrowly: the DSL evaluator
itself is invoked unmodified, once per (predicate, one affected
component's properties) pair; only the *aggregation* of those per-call
results across the affected-component set is new, Resolver-owned logic.

## INV-009: ADR-0021 already fixes `context_binding`'s shape and the "semantic output" definition A4 already transcribes into its own schema and staleness comparator — this feature populates these fields, it does not redefine what they mean

ADR-0021 items 1-2 (`docs/adr/0021-context-projection-staleness.md`) fix
`context_binding` (`full_context_revision`, `dependency_pointers[]`,
`projection_sha256`, `registry_digest`, `ownership_digest`) and define
"semantic output" as every Facet Manifest field except `context_binding`
and `resolver`. A4's `compare-facet-manifest-staleness` CLI
(`design.md:807-955`) is the actual **consumer** of two Facet Manifest
instances this feature's Resolver produces across two different resolves
of the same Feature — this feature does not build or call that comparator
(A4 owns it entirely), but this feature's Resolver output must be shaped so
that comparator's field-by-field structural-equality comparison is
well-defined: every array A4's REQ-001 names
(`affected_components`, `required_facets`, `conditional_facets` by
`facet`, `resolved_gates` by `id`, `capabilities`,
`lite_eligibility.upgrade_reasons`) must be written **stable-sorted**
(lexicographic) by this feature's own Resolver, exactly as A4's Goals
section already mandates (`requirements.md:256-277`) — "so Resolver purity
(ADR-0020 item 6) extends to array order, not only set membership."

## INV-010: Decision document v2 §19 explicitly deletes v1's self-reported "Change Characteristics" input — affected components are exclusively Epic A3's deterministic output

`docs/ai-dlc-foundation-decision-v2.md:537`: "入力: Project Context /
Affected Components（**§12 の決定論的導出のみ。v1 の「Change
Characteristics」は削除済み** — 自己申告入力を新設しない。将来必要になれば
導出規則・検証Gateとセットで ADR 化）". Issue #193 repeats this verbatim.
This feature therefore has **no** input path for a human- or agent-supplied
characteristics override of any kind — the only route into a DSL
predicate's `scope: affected_component` fields is the Context Projection's
`components[<id>]` object, itself sourced only from `project-context.yaml`
(A1-owned) and gated only by `resolve-component-paths`'s own deterministic
`affected_components` output (A3-owned, INV-006). A design that accepted
even an optional `--override-characteristics`-style flag would directly
contradict this deletion and is explicitly out of scope (requirements.md
Non-goals).

## INV-011: `contracts/` conventions this feature's new `resolver-evidence.schema.json` must follow, and the stdlib-only-Python constraint

Confirmed identically to A4's own INV-014 (`specs/epic-192-a4-facet-manifest/investigation.md:305-319`):
every existing `contracts/*.schema.json` uses `"$schema":
"http://json-schema.org/draft-07/schema#"` and `"$id":
"https://github.com/aharada54914/sdd-forge/contracts/<filename>"`.
`grep -rln "import jsonschema" plugins/ scripts/` and a search for
`requirements.txt`/`pyproject.toml` both return nothing in this
repository (re-confirmed at this feature's own investigation time); every
Python script under `plugins/sdd-quality-loop/scripts/` imports only
stdlib modules. This feature's own `validate-resolver-evidence.py` (REQ-004)
must therefore hand-roll its schema-conformance check exactly like
`validate-capability-registry.py`/A4's three validators already do — no
third-party `jsonschema` dependency.

## INV-012: `evaluate-predicate`'s single-`--component-properties` CLI shape is the concrete evidence this feature's multi-component matching rule must be built on top of, not around

Re-stated from INV-005/INV-008 for emphasis, because it is the one place
this feature makes a genuinely new orchestration decision (design.md
Design Decisions): `evaluate-predicate.py --predicate <p> --component-properties
<c>` accepts **exactly one** component's property object per invocation.
A Feature's `resolve-component-paths` output can legitimately name several
`affected_components` (a change touching more than one component's owned
paths in the same diff). Neither ADR-0020, nor A2's own evaluator design,
nor any other sibling spec defines how a Resolver with several affected
components should combine several single-component evaluations of the
*same* `trigger`/`when` predicate into one Feature-level match/no-match —
this is squarely this feature's own contract to fix (design.md), grounded
directly in the evaluator's own fixed CLI shape (one predicate, one
component, per call) rather than inventing a different evaluator
interface.

## INV-013: ADR-0016 item 4 names "the Resolver" (not `check-component-coverage`) as a thing that must not run at all in `disabled-legacy` — this feature's own state-awareness deliberately diverges from A3's graceful no-op

ADR-0016 item 4 (`docs/adr/0016-workflow-axes-separation.md:68-75`): "In
this state **the Resolver**, the Registry, the Gate stage machinery, and
the effective enforcement `max()` computation do not run at all — they are
outside that computation's domain, not evaluated with a low input." This
sentence names the Capability Resolver specifically (alongside the
Registry and Gate machinery) as something with **no defined behavior** in
`disabled-legacy` — a different design point than `check-component-coverage`,
which A3 deliberately engineered to run-but-noop (INV-006 above) *because*
it is wired unconditionally into the Implementation Gate's required-check
set and therefore must tolerate every project state, capability-aware or
not. The Capability Resolver is not wired unconditionally into any Gate
chain — it is invoked only by capability-aware callers (issue #193's own
"呼出し側統合" bullet: `sdd-bootstrap-interviewer`'s capability interview
phase) that are themselves responsible for checking
`workflow.capability_enforcement`'s derived state before deciding to
invoke it at all. Issue #193's Done-condition bullet ("`sdd-bootstrap-
interviewer` への統合...独立 skill は作らない") and this feature's own REQ-3
framing ("disabled-legacy では Resolver 起動自体が域外（呼出し側契約）")
both read consistently with ADR-0016 item 4's literal text: an invocation
in `disabled-legacy` is a **caller-contract violation**, not a normal input
the Resolver should gracefully absorb — this feature's design therefore
treats it as one of REQ-002's enumerated fail-closed Block conditions,
distinct in kind from `check-component-coverage`'s own truthful no-op.

## INV-014: `check-workflow-state.sh`'s spec-phase file requirement and the tasks.md trap, confirmed for this feature identically to A3's INV-012 and A4's INV-015

`plugins/sdd-quality-loop/scripts/check-workflow-state.sh` requires only
`requirements.md`, `design.md`, `acceptance-tests.md` for a `full`-profile
registry entry with no `tasks.md`; `Spec-Review-Status`/`Impl-Review-Status`
must each read exactly `Pending` or `Passed`. If `tasks.md` exists at all,
the script additionally requires **both** statuses already `Passed`,
regardless of `tasks.md`'s own content — committing a `tasks.md` alongside
`Pending` headers is an unconditional failure. This independently confirms
the task instruction ("tasks.md / traceability.md は作らない") is the only
registry-valid state for a Phase 1 package whose reviews have not run.

## INV-015: `check-sdd-structure.sh`'s `--feature` mode is not the registration-verification invocation; the no-argument, repo-root-only invocation is

`scripts/check-sdd-structure.sh` only enters its per-feature
`ux-spec.md`/`frontend-spec.md`/`infra-spec.md`/`security-spec.md`/
`tasks.md`/`traceability.md` requirement loop when invoked with a second,
feature-name argument. Invoked as `sh scripts/check-sdd-structure.sh .`
(the documented usage in `docs/skill-reference.md`, and the exact
invocation `docs/ai-dlc-foundation-decision-v2.md`-adjacent Epic A4's own
INV-016 confirms and this feature's registration commit reuses), it checks
only repository-root directories this feature's registration commit does
not disturb. This feature therefore authors no `ux-spec.md`/
`frontend-spec.md`/`infra-spec.md`/`security-spec.md` at this phase
(matching A2's and A4's own precedent of adding those later, at
impl-review-prep time) and runs the no-feature-argument invocation for its
own registration verification.

## INV-016: `workflow-state-registry.json`'s `full`-profile entry shape is exactly two keys, and this worktree's own `entries` array does not yet carry any sibling epic's registration

`contracts/workflow-state-registry.schema.json` requires, for a `full`- or
`lite`-profile entry, `(keys | sort) == ["feature","profile"]` — no
additional metadata. Confirmed directly against this worktree's own
`specs/workflow-state-registry.json` (`python3 -c "import json; ...`,
investigation time): the file's `entries` array ends with
`epic-159-pillar-d` and does **not** contain `epic-192-a4-facet-manifest`
or any other A1-A4 sibling epic's own registration — each worktree is an
independent branch off the same pre-Epic-A0 base commit and only carries
its own epic's registration; this feature's own registration entry,
`{"feature": "epic-193-a5-capability-resolver", "profile": "full"}`, is
appended to this worktree's `entries` array alone, matching the file's own
append-only historical pattern (confirmed against A4's own identical
registration diff, `git show e0a2013` in the Epic A4 worktree).

## INV-017: `sdd-bootstrap-interviewer`'s `SKILL.md` carries no capability interview phase today, and Epic A1's own investigation already classified this exact file as unprotected

`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`
(confirmed by direct read at investigation time) implements today's
Intake/Investigation → Full-Profile Layer Interview flow with no mention
of "capability," "Facet," "Resolver," or "Registry" anywhere in its current
text — decision document v2's "改訂: sdd-bootstrap-interviewer に
capability interview phase / deterministic resolver 呼び出し / facet
generation phase を統合" (§7) names work this file has not yet received.
Epic A1's own Components table (`design.md:153`) already classifies this
exact file as **not** protected ("existing, edited (REQ-009)" | Protected?
`no`) — A1 edits it directly for its own `spec_profile`-gating revision.
This feature's own scope explicitly excludes touching `plugins/**` at all
(this task's own hard boundary); this feature's REQ-007 therefore
documents the target integration contract (capability interview phase →
deterministic Resolver invocation → facet generation phase, per decision
document v2 §18.4's "質問は既知情報を再質問しない / 適用 Capability だけ /
1 pass 最大 15 問 / 未解決は Open Questions 保存 / 再開可能") as design
content only, to be applied by a future implementation task as a staged,
reviewed edit — this feature stages the target content the same way this
repository already stages any edit to an existing skill file it does not
apply directly (matching this repository's own general staged-edit
discipline for cross-cutting skill changes, independent of whether the
target file happens to be technically guard-protected); the future
implementation task re-verifies the file's then-current protection status
before choosing a direct edit or a human-copy application, mirroring A3's
own "live-repository snapshot, re-verified at implementation-start time"
disclaimer (`design.md:243-248`).

## INV-018: No sibling epic, and no ADR, defines a Resolver Evidence shape — Epic A5 is the epic that must define it, following the same closed, per-epic schema-definition pattern A2/A3/A4 each already established for their own new artifact

Decision document v2 §19's Epic A5 output line names `Resolver Evidence`
as a fourth, distinct output alongside Facet Manifest / Capability Summary
/ Context Projection — the latter three are exhaustively schema-fixed by
A4 (INV-004); `grep -rn "[Rr]esolver Evidence" docs/ specs/` (repo-wide,
across every worktree readable from this investigation, at investigation
time) returns only decision-document/issue-#193 mentions of the *name*,
never a field list, schema, or CLI contract for it, in any of A1/A2/A3/A4's
own spec packages. This mirrors exactly how A2 defined `capability-registry.
schema.json` for its own new Registry artifact, A3 defined its own
Resolver-output JSON shape (not a `contracts/` schema — Data Plan records
it as "not a repository contract file, an in-process/CLI JSON structure")
for `resolve-component-paths`, and A4 defined three new `contracts/*.
schema.json` files for its own three new artifacts: each epic, when it
introduces a genuinely new artifact type no upstream epic already typed,
defines that artifact's own shape following the repository's established
`contracts/*.schema.json` conventions (INV-011) rather than leaving it
implicit. This feature's REQ-004 does the same for Resolver Evidence.

## INV-019: The Registry schema (A2, content-frozen) has no field encoding a per-Capability Lite check list — decision document v2 §6's own worked example presupposes a source that does not exist in any landed spec

`specs/epic-190-a2-capability-registry/design.md`'s `capabilities[]` schema
(API / Contract Plan, `design.md:359-404`) fixes the complete field set:
`id`, `trigger`, `required_facets`, `conditional_facets`,
`review_check_ids`, `gate_ids`, `lite_policy {eligible, upgrade_reasons}`,
`minimum_enforcement`, `delivery_strategy {kind}` —
`additionalProperties: false`, so no other field can appear on a
`capabilities[]` entry without a Registry schema revision Epic A2 would
own, not this feature. `grep -rn "required_lite_checks|lite_check" specs/epic-190-a2-capability-registry/*.md`
returns no hit anywhere in A2's own package. Decision document v2 §6's own
Lite Capability Summary worked example nonetheless shows
`required_lite_checks: [build, test, installer-dry-run]` — values
(`installer-dry-run` in particular) that are plainly capability/
artifact-kind-specific, not a fixed constant `lite-gate` could hard-code
independently of which Capability actually matched. ADR-0022 item 4
describes `lite-gate` as running "its current placeholder/lint/typecheck/
build/test checks... plus only the Lite-specific checks **defined by the
Registry**" — text that presupposes the same Registry-side field the
landed A2 schema does not carry. This is a genuine, confirmed gap between
what decision document v2 §6 (and ADR-0022) assumes exists and what Epic
A2's own already-`Passed`, content-frozen schema actually contains — Epic
A5 cannot resolve it by adding a field to `contracts/capability-registry.
schema.json` itself (that file is Epic A2's own, already-reviewed
contract; editing it is out of this feature's authority and out of this
task's own `contracts/**` boundary regardless) and cannot resolve it by
inventing a substitute source without contradicting decision document v2
§13's "Registry を唯一の machine-readable 正本とする" rule. This feature's
design (REQ-002, REQ-004) treats this as one of the enumerated
ambiguous/fail-closed conditions — see requirements.md's Risks for the
consequence this has for Lite-track resolution specifically.

## OQ-001 (inherited from Epic A4's own open question): Context Projection regeneration cadence

A4's own `requirements.md` OQ-002 leaves "deciding *when* Context
Projection is regenerated (CI cadence, on-demand, etc.)" explicitly to "an
Epic A5-or-later wiring decision this feature's schema work does not need
to resolve to be complete." This feature's own design fixes *that* Epic A5
answers it, but scopes the answer narrowly: the Resolver regenerates the
Context Projection **every time it runs**, as one step of a single resolve
invocation (design.md, Data Plan) — it does not itself define a
CI-scheduled or file-watch-triggered regeneration cadence independent of a
Resolver invocation; whether some future caller (a Gate step, a
pre-commit hook) invokes the Resolver on a fixed cadence is that caller's
own contract, not this feature's.

## OQ-002: Which caller invokes `compare-facet-manifest-staleness` against two Resolver-produced Facet Manifests, and when

Neither A4's design.md nor decision document v2 §16 names the specific
caller that runs `compare-facet-manifest-staleness` (A4-owned) across two
resolves of the same Feature, or the trigger condition for doing so (a
Gate-time check, a pre-commit hook, a scheduled job). This feature's own
Resolver is a pure producer of one Facet Manifest instance per invocation;
it does not itself call `compare-facet-manifest-staleness` (A4 Non-goals
already exclude this feature's own scope from "deciding when regeneration
happens"). Left open for a future epic (plausibly A6/A8, per decision
document v2 §19) to fix; this feature's Resolver Evidence output (REQ-004)
is designed so a future caller has everything it needs (digests, semantic
output fields) to make that call without needing to re-invoke the
Resolver a second time merely to inspect its prior output.

## OQ-003: `sdd-bootstrap-interviewer`'s exact insertion point for the capability interview phase — **resolved by INV-020, below**

INV-017 confirms the target file's current shape and unprotected status,
but the *exact* step number/insertion point within its existing Intake/
Investigation → Full-Profile Layer Interview flow is not fixed by decision
document v2 §7/§18.4, by issue #193, or by any sibling epic (none of A1-A4
touches this file for this purpose). An earlier revision of this feature's
own design (REQ-007) documented only the target contract's *inputs,
outputs, and ordering relative to existing steps* (capability interview
phase runs after Project-Context/track detection, before Facet-dependent
layer generation) without asserting a specific numbered-step insertion
into the live file. Adversarial review ("M6 caller integration") found
this insufficient — the exact insertion point is now resolved, with a
file:line citation against the live `SKILL.md`, in INV-020 below; what
remains for the future implementation task is only the direct-edit-vs.-
human-copy mechanical choice, gated on that file's then-current protection
status re-check (requirements.md Roles and Permissions/Assumptions).

## INV-020: Adversarial spec review (25 findings, `Spec-Review-Status:
Pending` → this revision) — resolutions recorded here for traceability

An adversarial spec review of an earlier revision of this package
returned 9 Blocker, 10 Major, 3 Minor, and 3 OK findings (25 total,
verdict FAIL). This revision resolves all 25. The findings requiring a
genuinely new investigation-time fact (beyond a requirements.md/design.md/
acceptance-tests.md text correction) are recorded here; the remainder are
resolved entirely within requirements.md/design.md/acceptance-tests.md
themselves (each finding's own resolution is cited inline at its own
point of application, tagged with its own finding id, e.g. "B1", "M6"):

- **M6 (caller insertion point, resolving OQ-003 above)**: a direct read
  of the live `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/
  SKILL.md` (this worktree, at this package's own revision-authoring time)
  confirms it has no step literally named "track detection," but its own
  existing flow already branches on track by the point its `### Full-
  Profile Layer Interview` heading (`SKILL.md:60`) is reached — that
  section's own opening sentence ("For non-LITE work, use `references/
  interview-question-bank.md`...") and its own closing line ("LITE
  excludes this section and produces no layer documents", `SKILL.md:92`)
  both presuppose the track is already known by that point, sourced today
  from `AGENTS.md`'s `spec_profile` marker (the same source this file's
  own Specification/Implementation Policy Review Gates already read,
  `SKILL.md:147,159`). The capability interview phase's own insertion
  point is therefore fixed to **immediately before `SKILL.md:60`**, after
  `## Intake And Investigation`'s own step 8 (`SKILL.md:58`) — design.md
  Design Decisions "caller insertion point" and requirements.md REQ-007
  both cite this exact anchor; design.md Test Strategy item 10 fixes a
  drift check against it for the future implementation task.
- **B5 (Lite-check-source Registry-schema gap → explicit A6
  prerequisite)**: this investigation's own INV-019 already confirmed the
  gap; adversarial review found an earlier revision of this package left
  the consequence as a named Risk only, with no owner. requirements.md
  Dependencies now records the Epic A2 Registry-schema revision this gap
  requires as an **explicit, owned prerequisite for Epic A6** (owner:
  Epic A2's own maintainers; scope: an additive `capabilities[]` field;
  migration: existing Registry instances remain valid) — this
  investigation adds no new fact beyond INV-019's own, only a
  traceability pointer to where the ownership statement now lives.
- **B7 (facet-name cross-Capability aggregation → A4 addendum
  candidate)**: `specs/epic-192-a4-facet-manifest/design.md:413-422` (the
  Epic A4 worktree, read directly for this finding) states `conditional_
  facets[].evidence` is "the whole array... copied verbatim from the
  evaluator's own output" — a single-invocation framing. This feature's
  own new facet-name aggregation rule (design.md Design Decisions) can
  make that field a **concatenation** of several invocations' own output
  when more than one matched Capability shares a `facet` name. The
  concatenated array still satisfies A4's own JSON Schema (an array of
  `evidenceNode` elements, any length) — only A4's own *prose* assumes
  the narrower case. This package's own final report names this as an
  A4-addendum candidate; this package does not edit any Epic A4 file
  (this task's own hard boundary, and Epic A4's own post-review content
  freeze).

25/25 findings resolved: 9 Blocker (B1-B9), 10 Major (M1-M10 — M1/M2
merged into one "representative selection removed" resolution per the
adjudicated finding grouping), 3 Minor (Block count, diagnostic
namespace, discovery fixture count), 3 OK (union-match/digest-order/
parity-target reinforced, not changed in substance).

## INV-021: Second-round adversarial verification (B1/B3/B6/B7/B8/M6
PARTIAL/NOT_RESOLVED, this revision) — resolutions recorded here for
traceability

A second-round adversarial verification of the revision INV-020 above
produced re-tested RESOLVED: 19, PARTIAL: 4 (B3, B6, B7, M6),
NOT_RESOLVED: 2 (B1, B8) — final verdict FAIL. This revision closes all
six remaining findings. The findings requiring a genuinely new
investigation-time fact are recorded here; the remainder are resolved
entirely within requirements.md/design.md/acceptance-tests.md themselves:

- **B1 (crash-safe multi-artifact transaction, NOT_RESOLVED → resolved)**:
  the prior revision's own single atomic commit (temp-file + `fsync` +
  `rename` per file, one file after another) had no cross-file atomicity
  and no crash-safe rollback — a crash between two renames of a
  multi-target batch could leave a mixed generation standing, and an
  in-process failure's own best-effort `unlink` rollback destroyed
  pre-existing live bytes with no restore path. Epic A1 (this worktree's
  own sibling, `specs/epic-189-a1-project-context/design.md:927-1016`,
  read directly for this finding) already fixes an isomorphic problem —
  multi-target human-copy batches — via a journaled, prepare/journal/
  commit/complete/recovery/reader-check protocol with byte-exact
  pre-image backups. This revision applies that same protocol shape to
  this feature's own Resolver-owned publication targets (design.md
  "Resolver publication transactional bundle contract"), reusing Epic
  A1's own already-`Passed` design rather than inventing a second one.
- **B3 (best-effort Evidence on self-referential schema failure, PARTIAL
  → resolved)**: the prior revision's own `output-schema-validation-
  failed` handling wrote a "best-effort" Resolver Evidence instance
  (failed fields omitted) when Evidence itself failed its own schema
  self-validation, on the reasoning that REQ-004's "written on every
  invocation" guarantee should hold even in this one case. This
  instance's own conformance to `contracts/resolver-evidence.schema.json`
  was never itself verified — it could as easily be schema-invalid as
  not, making it exactly the class of artifact this self-validation check
  exists to keep off a live path. This revision removes that rule: this
  one case now writes nothing to any live path (requirements.md REQ-002/
  REQ-004, design.md API / Contract Plan step 12).
- **B6 (validator provenance binding, PARTIAL → resolved)**: the prior
  revision's `validate-resolver-evidence` trusted a caller-supplied
  `--registry`/`--affected-components` pair as the ground truth its own
  exact-set checks compared against, with no independent verification
  that pair was itself correct — a caller could substitute a different,
  smaller Registry or an arbitrary affected-component subset alongside a
  self-consistent-but-wrong Evidence instance and have it pass. This
  revision binds both inputs to Evidence's own recorded provenance
  fields: the Registry is self-resolved via ADR-0025 discovery (or, as an
  override, digest-verified against `context_binding.registry_digest`),
  and the affected-component set is derived from Evidence's own
  `context_binding.dependency_pointers[]` (B9's own already-fixed
  provenance field, `AC-044`), cross-checked against a co-located Facet
  Manifest's own `dependency_pointers[]` when present — design.md
  `validate-resolver-evidence` contract, "Provenance binding."
- **B7 (same-Capability duplicate-facet aggregation, PARTIAL → resolved;
  A2 addendum candidate, NEW)**: the prior revision's facet-name
  aggregation rule keyed contribution by bare `capability_id`, which can
  represent *cross*-Capability same-facet-name collisions but not a
  *single* Capability declaring the identical `facet` name more than once
  in its own `conditional_facets[]` array — a legitimate Registry input,
  since Epic A2's own schema (`specs/epic-190-a2-capability-registry/
  requirements.md:169-173`, the Epic A2 worktree, read directly for this
  finding) neither requires nor forbids this. This revision generalizes
  the aggregation unit to a "predicate instance," `(capability_id,
  declaration_index)`, which covers both collision shapes identically
  (design.md Design Decisions "facet-name aggregation, predicate-instance
  keyed"). Because Epic A2's own prose is silent on whether the
  same-Capability duplicate pattern is intentional or an oversight, this
  revision also names an **A2 addendum candidate** (requesting explicit
  prose either way) alongside the existing A4-addendum candidate above —
  this package edits neither Epic A2 nor Epic A4's own files (this task's
  own hard boundary).
- **B8 (generation-binding completion, NOT_RESOLVED → resolved)**: the
  prior revision's pre-publication recheck re-verified `ownership_digest`
  but never re-derived `affected_components` itself, and `ownership_
  digest` (Epic A3 `requirements.md:530-569`, the Epic A3 worktree, read
  directly for this finding) is a project-wide "the ownership *config*
  changed" signal that does not itself change when only the underlying
  *diff* shifts which components are affected — a second invocation's own
  `affected_components` set could silently drift between this
  invocation's own snapshot and its recheck with no digest ever catching
  it. This revision adds an explicit `affected_components` set comparison
  to the pre-publication recheck, and adds a **second**, later
  verification immediately after the publication transaction's own last
  rename completes (`post-publication-generation-mismatch`, NEW), closing
  the residual "post-recheck race" window the first recheck alone cannot
  close — both re-derivations reuse the identical `resolve-component-
  paths` re-invocation mechanism, never a second algorithm. A new,
  explicit single-writer assumption (mirroring Epic A3's own
  `design.md:351-371`, the Epic A3 worktree, read directly for this
  finding) is stated alongside these two checks.
- **M6 (anchor position-sensitivity, PARTIAL → resolved)**: the prior
  revision's drift check verified only that the cited heading text
  (`### Full-Profile Layer Interview`) still existed verbatim somewhere
  in the live `SKILL.md` — a check that cannot detect the heading
  *moving* to a different position in the document while its own text
  stays unchanged. A direct read of the live file (this worktree, at this
  revision's own authoring time) fixes two independent, recomputable
  drift signals in its place: the sha256 of the literal 11-line window
  `SKILL.md:54-64` (`sha256:d969fa163169ee5a9b5941600382b86b75929
  d6cd90d223dbe991e1dc234fb64`, computed via `sed -n '54,64p' SKILL.md |
  shasum -a 256`, LF-joined), and the heading's own 1-based ordinal
  position among every `##`/`###`-level heading in the file in document
  order (`3` — confirmed by `grep -n '^#\{2,3\} ' SKILL.md`, counting `##
  Invocation`, `## Intake And Investigation`, then this heading). design.md
  Design Decisions "anchor fingerprint" records both values and the
  update procedure for a future, intentional `SKILL.md` revision.

25/25 first-round plus 6/6 second-round findings resolved.

## Summary of Evidence References

- `docs/ai-dlc-foundation-decision-v2.md` §2, §6, §7, §9, §10, §11, §12,
  §13, §16, §17, §18.2, §18.3, §18.4, §19, §20.
- `docs/adr/0016-workflow-axes-separation.md`,
  `0017-gate-stage-model.md`, `0019-approval-sidecar-protection.md`,
  `0020-conditional-predicate-dsl.md`,
  `0021-context-projection-staleness.md`,
  `0022-lite-capability-upgrade.md`,
  `0023-track-selection-contract-migration.md`.
- `docs/adr/0025-registry-discovery-contract.md` (Epic A2 worktree; Accepted
  2026-07-21; not yet present on this worktree's own `docs/adr/` branch
  state, cited as an Accepted cross-Epic ADR regardless, per INV-005).
- `specs/epic-189-a1-project-context/{requirements,design}.md` (Epic A1
  worktree, `/Users/jrmag/Projects/active/sdd-forge-wt-epic-189/`).
- `specs/epic-190-a2-capability-registry/{requirements,design,investigation}.md`
  (Epic A2 worktree, `/Users/jrmag/Projects/active/sdd-forge-wt-epic-190/`).
- `specs/epic-191-a3-path-ownership/{requirements,design}.md` (Epic A3
  worktree, `/Users/jrmag/Projects/active/sdd-forge-wt-epic-191/`).
- `specs/epic-192-a4-facet-manifest/{requirements,design,investigation,acceptance-tests}.md`
  (Epic A4 worktree, `/Users/jrmag/Projects/active/sdd-forge-wt-epic-192/`).
- Issue #193 (`gh issue view 193`) and issue #187 (`gh issue view 187`).
- `AGENTS.md`, `PLUGIN-CONTRACTS.md`, `plugins/sdd-bootstrap/skills/
  sdd-bootstrap-interviewer/SKILL.md`, `plugins/sdd-quality-loop/references/
  guard-invariants.json`, `contracts/` directory listing, `specs/
  workflow-state-registry.json` (this worktree,
  `/Users/jrmag/Projects/active/sdd-forge-wt-epic-193/`).

## Amendment Re-Review Context

This feature's specification package was amended post-implementation under
an explicit, dated human approval, and is re-reviewed under the amendment
re-review lane (`plugins/sdd-review-loop/references/spec-review-calibration.md`,
section `## Amendment Re-Review Context`). Every citation below is a full
commit hash or a SHA-256 fingerprint per that section's evidence bar.

### Amendment commits (full hashes)

1. `d5701194ab11d8d5348d91fc96fdca5e857bb9b5` — ruling A①: amends
   `requirements.md`'s AC-056 sentence (the "warn-only never appears"
   claim) with the "or jointly caused" evaluation-abort exception.
2. `b572fcd65292b1652e6c03f8a08b26e6d8507160` — ruling B①: amends the
   AC-016 byte-identity criterion in all three statement sites
   (`requirements.md` REQ-003 prose, `requirements.md` AC-016 table row,
   `acceptance-tests.md` AC-016/TEST-016 row) to scope byte-identity to
   everything except `state` and the two named enforcement-derived
   `context_binding` digest fields
   (`full_context_revision`/`projection_sha256`).

### Per-document SHA-256 at each amendment commit

As of `d5701194ab11d8d5348d91fc96fdca5e857bb9b5`:

- `specs/epic-193-a5-capability-resolver/requirements.md` =
  `f62043223685ba18c2ec76a1d6268301a5b2045a7bba7ca2306ca437825f3d1e`
- `specs/epic-193-a5-capability-resolver/acceptance-tests.md` =
  `581cc5e9931c62a8f020771302e91ddbea2d9b530f073f1732a73bcfff6d50cc`
  (unchanged by this commit)

As of `b572fcd65292b1652e6c03f8a08b26e6d8507160`:

- `specs/epic-193-a5-capability-resolver/requirements.md` =
  `fefdf075a7309dd30f30a89c8a01274d079b44755f63c15719a72689d74d6425`
- `specs/epic-193-a5-capability-resolver/acceptance-tests.md` =
  `ef78ed2463854cc01933b8e9af860540d2deca1c53387f4feeecda149fec4aa2`
- `specs/epic-193-a5-capability-resolver/investigation.md` =
  `4b63f379d58f18759991e58d27f0c75a7164c6f752b245bd67b4d06ce2738532`
  (this document, as of the amendment commits, before this very section
  was appended; the appended section changes this document's bytes, so
  this pin is the fixed-point-safe pre-entry fingerprint, and the review
  precheck re-pins the post-entry bytes)

### Verbatim, dated human approvals

The human ruled, dated 2026-08-24: 「A①B①C①でやれ」, following the standing
approval, dated 2026-08-23: 「194/195/196の凍結文書について人間は承認する」 —
this epic's frozen-document amendments join that approval family by the
same 2026-08-24 ruling. The rulings, as presented to and approved by the
human, verbatim:

- **A①**: requirements.md's AC-056 sentence (`:526-528` — "A
  `dsl-warn-on-matched-capability` id therefore never appears with only
  `severity: "warn"` entries and no `severity: "block"` summary entry…")
  is amended minimally so that warn entries collected before an
  evaluation abort may lawfully appear alongside a different-id block
  summary when the abort and the warns are jointly caused by the same
  evaluation pass — the "or jointly caused" shape one blind reviewer
  identified as the lossless option. This reconciles the sentence with
  REQ-004's "record every diagnostic-worthy condition", which both
  vendors have now flagged from opposite sides across two rounds.
- **B①**: the AC-016 byte-identity criterion ("advisory and required
  invocations byte-identical except state") is amended minimally to
  exclude enforcement-derived digests — `context_binding.
  full_context_revision` and `projection_sha256` structurally encode
  `workflow.capability_enforcement` because it is part of the canonical
  Project Context, so the criterion as written is (per the panel)
  "internally impossible". The amended text scopes byte-identity to
  everything except `state` and the enforcement-derived digest fields,
  naming them.

### Later-phase artifacts referenced (commit / SHA-256 for each)

- The forwarding reversal this amendment supersedes, and the panel
  findings ("both vendors converged" AC-056 reading; the "AC-016
  byte-identity frozen-doc conflict (WFI candidate)" left open):
  commit `1811ed0edf8bcded80f9093e0f85447279f5516e`.
- The production follow-through restoring `warn_diagnostics` forwarding
  on the three steps-7/8 abort paths, with its mutation-kill evidence:
  commit `18d90c67a201a5a1a082f905159dcf1e3b987932`. As of that commit:
  - `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-loop/scripts/resolve-project-context.py` =
    `d3360c518bf1831e70a63e1344acf64b71852f6310e4ace8c3fce6d033efe73e`
  - `tests/resolve-project-context-block-check.py` =
    `607014db9c43b90d045f1863511df8112d5576c8c1fac72e5555efe3ede50ce1`
  - `tests/resolve-project-context-match-check.py` =
    `d1e3d9a6629a223ce0fb14724d5740ca41c1c497298fe6075a8943424420df7e`
- B① required no production or assertion change: the
  `enforcement-byte-identity` fixture driver
  (`tests/resolve-project-context-match-check.py`, SHA-256 above) already
  asserts the amended scope — it excludes exactly `state` and
  `context_binding.full_context_revision`/`projection_sha256`, with a
  separate non-vacuity assertion that the two digests genuinely differ —
  since the T-004 NEEDS_WORK cycle-2 "late Blocks drop provenance"
  remediation; commit `18d90c67a201a5a1a082f905159dcf1e3b987932` updates
  only that driver's docstring to cite the amended criterion.

### Round-1 remediation extension (attempt 3, spec re-review)

The completion chain gained three commits after the entry above was
authored; per the calibration's re-extension rule they are recorded here:

- `fafa65720c2235d6fedac1aa2030139fbefd8b75` — opens spec re-review
  attempt 3 round 1 (reset lane; manual-precheck fallback documented in
  `reports/spec-review/epic-193-a5-capability-resolver/attempt-3/round-1/manual-precheck-note.md`
  beside `precheck-result.json`, whose SHA-256
  `c7231832ee90d95f831ed325777fd950da2428977e8e16df6ed2a83a4d297200`
  both round-1 reviewer manifests pin).
- `bb048f1df0b8c0c6f1dd7697dc450422a2b45651` — persists round 1
  (blind reviewers at ledger seq 0770/0771; integrated verdict
  NEEDS_WORK, 2 Critical / 3 Major, all findings converging on the
  then-un-mirrored AC-056 restatement rows plus the undefined
  "evaluation pass" term and the missing abort-exception fixture
  description).
- `f585cb0e89a65e194d62197f72cf72c2b02bcf73` — the round-1 remediation:
  mirrors ruling A①'s exception into requirements.md's own AC-056 table
  row and acceptance-tests.md's AC-056/TEST-056 row in the amended
  sentence's own words, anchors "evaluation pass" to REQ-001's steps
  (f)–(g) sweep vocabulary, and names the abort-exception fixture
  (`tests/resolve-project-context-block.tests.sh`/`.ps1`,
  `evaluate-predicate-failure-after-warn`). This commit also carries the
  lane's reset transition (`Spec-Review-Status: Passed` → `Pending`),
  the state under which attempt 3 reviews run. As of this commit:
  - `specs/epic-193-a5-capability-resolver/requirements.md` =
    `5461fd7e50a4140cfcc71b07a08503906f698587d1dca377c9bef5c2b96ef618`
  - `specs/epic-193-a5-capability-resolver/acceptance-tests.md` =
    `531d47d526f8a51a473869d18e5a3b5e0f8a3f65d9dd6f9d33bdc4b810f6fc33`

The verbatim, dated human approvals and both ruling sentences remain
exactly as quoted in the parent section; the remediation introduces no
new ruling — it propagates ruling A① into the two restatement rows the
round-1 reviewers identified, as the ruling's own "where a restatement
exists, mirror" instruction requires.

### `design.md` extension (option ①, human-approved 2026-08-24)

The completion chain gained one further commit, extending both rulings
into `design.md` — the fourth frozen document, and the one document
neither ruling A① nor ruling B① had reached. Per the calibration's
re-extension rule it is recorded here.

**Why this commit exists.** `impl-review-precheck.sh:488-494` requires
every unique `AC-[0-9]{3}` id in `requirements.md` to appear as a literal
substring in `design.md`. 35 of the 56 ids did not. Re-derivation of that
list against the two documents established three classes: 19 criteria
whose substance `design.md` already fixed and which needed only their id
cited beside the discharging sentence; 13 criteria whose substance was
absent or incomplete and had to be written (12 in the first commit, plus
AC-033 — see "AC-033 reopened", below, which corrects a mis-grouping in
the first commit's own version of this entry); and 3 registration-commit
criteria (AC-035/AC-036/AC-037) which **no** design document can honestly
name and which are therefore deliberately still absent. The two
priority items in the middle class were AC-016 and AC-056: the rulings
below had amended them in `requirements.md` and `acceptance-tests.md`
while `design.md` remained completely silent on both, so the amendment
existed in three of four frozen documents. This commit closes that gap.

**Amendment commits.** This extension landed in three commits, and the
invariant `impl-review-precheck.sh:241-243` and
`task-review-precheck.sh:210-213` impose — that no commit may change
`design.md` without updating this record in that *same* commit, since
the predecessor contract pins `investigation.md` at its *current* hash —
holds for each of them individually:

1. `88c3187ac86f5b8dee8c83a40cb714af8f312361` — the citation and
   substance work described below (rulings A①/B① imported, class-A
   citations, class-B substance, class-C omissions), together with the
   first version of this record. `design.md` as of that commit =
   `32f51bb9704e9666eda65949d30945293ad3f5fa9909a66a9904312e72123bda`.
2. `2f35de22924aa51b70035650126d05dc0a9b32f2` — the two internal
   inconsistencies documented under "corrections made beyond the
   citation work", below, together with that record update.
   `design.md` as of that commit =
   `9ff13a09750bf1ede99ac1c210b48728c3d7f744b08b33fd35174bdd69008015`.
3. The commit carrying *this* revision of the record — AC-033 reopened,
   re-examined on the merits, and cited (see "AC-033 reopened", below),
   together with this record's own correction of the mis-grouping that
   left it uncited. Its own hash is not quotable from inside itself; the
   per-document SHA-256 pins immediately below are the verifiable
   evidence for its resulting tree, and are exact.

(A single amending commit was the first choice for commit 2 and was
attempted; this worktree's own pre-commit safety gate declines `git
commit --amend`, so the follow-up form was used, and commit 3 follows
the same form. Each satisfies the invariant independently: every one of
the three changes `design.md` and updates this record in that same
commit.)

**This self-reference was a deliberate decision, not an oversight.** The
evidence bar in `reviewer-calibration.md:139-149` asks for full amendment
commit hashes. A commit cannot contain its own hash, and the only way to
record commit 2's literal hash would be a *third* commit touching
`investigation.md` alone — which is precisely the non-convergence the
per-commit invariant above exists to prevent, since such a commit would
change this document's bytes while changing no `design.md` content,
re-staling the `investigation.md` pin the predecessor contract just
captured and buying nothing. The resolution taken here follows the
precedent this
entry's own parent section already set for `investigation.md`'s
pre-entry fingerprint: state the self-reference openly and pin the
exact, independently verifiable SHA-256 of every document instead. A
reviewer can confirm the amendment bytes with `shasum -a 256` and
`git show <this-commit>:<path>` without needing the hash quoted from
inside the commit.

**Per-document SHA-256, as of that commit:**

- `specs/epic-193-a5-capability-resolver/design.md` =
  `1d96c0affd804540447631d0f5e57a85e2efdfecadd2a7667b9d9a3a31f4838a`
  (the final amended bytes, as of commit 3; its state after commit 2 was
  `9ff13a09750bf1ede99ac1c210b48728c3d7f744b08b33fd35174bdd69008015`,
  after commit 1 was
  `32f51bb9704e9666eda65949d30945293ad3f5fa9909a66a9904312e72123bda`,
  and its pre-amendment state, as of
  `233c48c1074a88d2b1272c578197af1d47ad2c32`, was
  `ac2ae7d86009fc2d3bafa80aa920ec5438a3eee2153a7ca1215cb499f2c857e2`)
- `specs/epic-193-a5-capability-resolver/requirements.md` =
  `56511557d4028c1c043b1aa885a9d7c1c58e6e230cfc29f0c64a69b4b44d68cb`
  (unchanged by this commit; last written by
  `a8ea3bfd6f35592eadae5235405a71d6d3c6dc18`)
- `specs/epic-193-a5-capability-resolver/acceptance-tests.md` =
  `531d47d526f8a51a473869d18e5a3b5e0f8a3f65d9dd6f9d33bdc4b810f6fc33`
  (unchanged by this commit; last written by
  `f585cb0e89a65e194d62197f72cf72c2b02bcf73`)
- `specs/epic-193-a5-capability-resolver/investigation.md` =
  `0693dc91fb1e3d29b9b2a72ad7f7f4d431156abd44ba69199cc640a420705883`
  (this document, immediately **before** this subsection was appended;
  as in the parent section, appending changes this document's own bytes,
  so this pin is the fixed-point-safe pre-entry fingerprint and the
  review precheck re-pins the post-entry bytes. Its last committed state
  is `582b588a10fc6122bbb91354a1c80038e07f5467`)

**Verbatim, dated human approval.** The same 2026-08-24 ruling family
this entry's parent section already quotes governs this extension. The
human ruled, dated 2026-08-24: 「A①B①C①でやれ」, following the standing
approval, dated 2026-08-23: 「194/195/196の凍結文書について人間は承認する」.
The `design.md` extension is that ruling's option ①, applied to the one
frozen document rulings A① and B① had not yet reached; no new ruling is
introduced here, and the two ruling sentences remain exactly as quoted
in the parent section.

**What this commit changed in `design.md`.**

- **Ruling A① imported (AC-056).** A new Design Decision,
  "`diagnostics[]` warn/block cardinality, and its evaluation-abort
  exception", quotes `acceptance-tests.md`'s own AC-056/TEST-056
  exception clause verbatim, maps `requirements.md` REQ-001's steps
  (f)/(g)/(h) onto this design's own API / Contract Plan steps 7/8 and
  step 9, and states the two resulting shapes: the ordinary one warn
  entry per `outcome: "warn"` node plus exactly one same-id block summary
  entry, and the abort exception in which warns already collected by the
  steps-7-8 sweep stand alongside that abort's own different-id block
  entry with no same-id summary. Test Strategy item 2 additionally names
  the `evaluate-predicate-failure-after-warn` fixture the amended
  criterion itself names.
- **Ruling B① imported (AC-016).** A new Design Decision, "`advisory`
  and `required` produce byte-identical output, with exactly three named
  exceptions", quotes `acceptance-tests.md`'s own AC-016/TEST-016 row
  verbatim and states the three design-level consequences: no assembly
  step branches on `capability_enforcement`; `context_binding.full_
  context_revision` and `projection_sha256` structurally encode it and
  therefore *must* differ, making `state` plus those two the complete
  and closed exception set; and the `lite-check-source-undefined` branch
  is excluded from the criterion's own scope. Test Strategy item 3
  additionally names the `enforcement-byte-identity` fixture pair, with
  its non-vacuity assertion.
- **Other written substance** (each the minimum true statement that
  discharges its criterion, cited to the source the requirements
  themselves cite): AC-003 (Context Projection generated by Epic A4's
  REQ-003 procedure verbatim, computed on every track, published on the
  Full track only, plus the hand-computed/Resolver-computed byte-identity
  fixture pair); AC-007 (`capability_minimum_enforcement` and
  `lite_eligibility` named explicitly as Full-track Facet Manifest output
  fields — the delegation to Epic A4's field semantics is genuine and
  deliberate, fixed by `requirements.md` Dependencies and Field
  Definitions, and is now stated rather than left to step 10a's
  catch-all); AC-008 (Facet Manifest schema-conformance fixture);
  AC-009 (the three non-Blocking Lite states each producing a
  schema-valid Capability Summary and neither Full-track artifact);
  AC-025 (the no-clock rule, its repository-wide grep check, and the
  Epic A2 DSL-evaluator carve-out, added to Security Boundaries — which
  `Constraint Compliance` already cross-referenced for exactly this
  content); AC-029/AC-030/AC-031 (the capability interview phase's
  question budget, Open-Questions persistence and resumability rules
  citing decision document v2 §18.4; the Context-absent event-identical
  rule citing §4.3; the on-Block never-silently-degrade rule citing §7);
  AC-042 (the `derives disabled-legacy` sub-case added to Test Strategy
  item 10's spy-harness fixture); AC-046 (the missing fourth lettered
  sub-item, exactly-one-invocation-per-run, plus an explicit mapping
  between this item's own lettering and AC-046's).
- **Class-A citations only** (id appended beside the already-discharging
  sentence, no substance added): AC-002, AC-004, AC-005, AC-013, AC-015,
  AC-017, AC-018, AC-019, AC-020, AC-027, AC-032, AC-038, AC-039,
  AC-040, AC-041, AC-043, AC-045, AC-054, AC-055.
- **Deliberately not cited**: AC-035, AC-036, AC-037 — and **only**
  these three. Each is a criterion about this package's own registration
  commit: `check-workflow-state.sh` exits 0 after it lands,
  `check-sdd-structure.sh` exits 0 after it lands, and
  `specs/workflow-state-registry.json`'s new entry is exactly a given
  literal. Each asserts a property of a *commit and repository state*,
  not a property any design can plan for, so no statement `design.md`
  could make would discharge them and citing them would make this
  document claim coverage it does not have. `requirements.md` scopes all
  three `Global` in their own defining rows (`| AC-035 (Global) | — |`
  and siblings), and the AC-coverage gate reads exactly that cell —
  commit `64915ecf7945215df18e530a8c2c4052c7aa6e80`, "except
  Global-scoped criteria from AC coverage" — so the gate now discharges
  them rather than demanding them. Their absence from `design.md` is
  therefore resolved, not outstanding. They remain the only three ids
  `impl-review-precheck.sh`'s own substring loop reports missing, by
  design and by that gate's own exception.

**AC-033 reopened, and cited (this commit) — correcting a mis-grouping
in the first commit's own version of this entry.** The first commit
grouped AC-033 with AC-035/AC-036/AC-037 as a fourth "package-meta"
criterion and left it uncited. That grouping was wrong, and the evidence
against it is in `requirements.md` itself:

- **The gate's own key refutes it.** The AC-coverage exception
  (`64915ecf`) excuses a criterion only when its own defining row's
  requirement-trace cell reads `Global`. AC-033's row reads
  `| AC-033 | REQ-008 | …` — traced to a real requirement, not scoped
  `Global`. `requirements.md` therefore does not treat it as package-meta.
- **REQ-008 has exactly three clauses, and `design.md` already
  discharges the other two.** REQ-008 requires (i) "every implementation
  task this package's future task phase schedules lands its own
  `CHANGELOG.md` `## Unreleased` entry citing #193"; (ii) "no new ADR is
  authored by this feature"; (iii) "a grep-based self-check confirms no
  version string is mutated anywhere in this feature's diff outside a
  `scripts/bump-version.sh` invocation". Clause (ii) is discharged at
  `design.md`'s ADR Change Log ("No new ADR is authored by this
  feature"); clause (iii) is discharged in the Data Plan, which already
  carries the explicit citation "mutated only via
  `scripts/bump-version.sh` (REQ-008/AC-034)". Clause (i) was the **only**
  REQ-008 clause `design.md` did not state — `grep -n CHANGELOG
  design.md` returned no match at all before this commit.
- **AC-033's own sibling under the same requirement was already cited.**
  AC-034 is REQ-008-traced exactly as AC-033 is, and `design.md`
  discharges it with a real design statement. A requirement cannot be
  package-meta for one of its criteria and design-scoped for the other.
- **This document already states future-task obligations as design
  content.** The `tests/run-all.sh`/`.ps1` registration rule (AC-026),
  the human-copy staging discipline (Protected-File Statement items 1-3),
  and the CI-registration staging rule (Deployment / CI Plan) each bind
  the future Phase-2 task rather than describing this package. A
  CHANGELOG-discipline statement is that same class of content.

The first commit's reasoning ("no statement `design.md` could make would
discharge it") conflated two different things: `design.md` cannot assert
**as fact** that a not-yet-existing commit's diff carries an entry — but
it can **fix the obligation** that it must, which is precisely what
AC-026 and AC-034 already do in this same document. The second reading is
the one AC-033 needs, and it is discharged honestly: an implementer
following `design.md` alone would land exactly the entry AC-033 demands.
Written as a new Deployment / CI Plan bullet, "Per-task `CHANGELOG.md`
discipline (REQ-008/AC-033)", stating the per-task, in-diff rule, naming
its REQ-008 versioning-half sibling, and recording that this Phase 1
package schedules no implementation task and so lands no entry itself.

**Two corrections made beyond the citation work, both human-authorized
on 2026-08-24 and both flagged here for the reviewer to judge rather
than absorb.** Neither is a design decision; each is an internal
inconsistency the same document already refuted, found during the
citation sweep and repaired in this same commit.

1. **Stale enum count corrected: `14-value` → `sixteen-value`
   (`design.md:514`, Data Plan, `diagnostics[]` entity).** That entity
   described `diagnostics[].id` as drawn from "REQ-002's own closed,
   14-value enum". The count is stale — it predates the two NEW
   diagnostic ids `publication-journal-recovery` and `post-publication-
   generation-mismatch` (B1/B8). **Evidence:** the literal `enum` array
   in this same document's own `contracts/resolver-evidence.schema.json`
   block enumerates exactly **16** distinct members (counted
   mechanically from the block, not from prose:
   `disabled-legacy-invocation`, `publication-journal-recovery`,
   `workflow-combination-invalid`, `project-context-validation-failed`,
   `affected-component-resolution-failed`, `registry-validation-failed`,
   `contract-discovery-failed`, `canonicalizer-invocation-failed`,
   `dependency-subprocess-failed`, `dependency-output-malformed`,
   `dsl-warn-on-matched-capability`, `lite-check-source-undefined`,
   `output-schema-validation-failed`, `snapshot-generation-mismatch`,
   `artifact-publication-failed`,
   `post-publication-generation-mismatch`); and three other prose sites
   in this same document already say sixteen (`design.md:1517`,
   `:1767`, `:2564`), as does `requirements.md` REQ-002. `design.md:514`
   was the sole outlier in the whole package. **Deliberately left
   unchanged:** the phrase "fourteen carried forward" at `design.md:1523`
   and `:2565` is correct arithmetic (14 carried forward + 2 NEW = 16)
   and was not touched.
2. **Three dangling cross-references repaired to name their real home
   (`design.md:481`, `:1059`; plus `:1019`, written earlier in this same
   commit).** Two pre-existing sites pointed at an "Edge Cases" section
   *of this document* — `:481` said "Edge Cases **below**" and `:1059`
   said "Edge Cases, \"zero affected components\"". **Evidence:**
   `design.md` has no Edge Cases heading at any level (`grep -nE '^#{1,6}
   .*[Ee]dge [Cc]ase' design.md` returns nothing across all 25 of its
   headings); the section lives in `requirements.md:1035`. Both now read
   "requirements.md Edge Cases", matching the form the AC-007 addition at
   `:1019` already used. This is a pointer repair; no surrounding claim
   changed. **Deliberately left unchanged:** `design.md:478` and `:1922`
   also contain the string "Edge Case", but each uses it as a descriptive
   noun naming the case ("the zero-affected-component Edge Case"), not as
   a section pointer, and neither asserts a location.

**A correction that was considered and rejected.** The identical stale
"14-value enum" string also appears at line 1836 of each of
`specs/epic-193-a5-capability-resolver/verification/T-003.panelist-
input.txt`, `T-004.panelist-input.txt`, and `T-005.panelist-input.txt`.
These were **not** corrected, and must not be: each is a frozen,
sanitized panelist input bundle carrying its own `input_digest` header
and paired with the panelists' returned verdict files. They are a record
of what the cross-model panelists actually saw at review time. Editing
them would falsify that record and invalidate the digest. The stale
string is therefore *correct* in those three files and *incorrect* only
in the live `design.md`.

No requirement, acceptance criterion, or test row was changed by this
commit; `requirements.md` and `acceptance-tests.md` are byte-unchanged,
as their pins above show, and no file outside
`specs/epic-193-a5-capability-resolver/design.md` and this document was
touched.

### Rulings C(1)/C(2) (route (a), human-approved 2026-08-26)

**Disambiguation first**: the 2026-08-24 combined ruling quoted above
(「A①B①C①でやれ」) named a "C①" whose content that day's record never
defined and which was never applied. The rulings recorded HERE — C(1)
and C(2), dated 2026-08-26 — are a separate, later decision and are the
sole "ruling C" this feature's documents cite.

**What was decided.** Review ticket RT-20260826-002
(`docs/review-tickets/RT-20260826-002.yml`) recorded a cross-model
consensus FAIL on T-003: a fresh, blind two-vendor panel (anthropic
PASS; openai/gpt-5.6 NEEDS_WORK with two Majors) against input digest
`ab3589c71578a4b14816575ef00881bcbaf7a53c3e9438b61bd869ee705a9e9d`. The
openai Majors: (1) the Registry document retained at REQ-001 step (e)'s
own first read is not bound to the Registry independently re-discovered
and re-read by `validate-capability-registry` and
`generate-registry-digest --whole` — the same unbound-reads window the
2026-08-24 confirmation panel had flagged and whose unsanctioned
code-only fix (a "step 6.5" recheck) ruling RT-20260826-001 route (b)
had removed to restore frozen-document conformance; (2) an affected
component absent from the Context Projection was silently evaluated
against a defaulted-empty properties document
(`projection_components.get(component_id, {})`) — a fail-open the
quality gate's cycle-1 evaluator had also recorded. The ticket offered
three routes: (a) amend the frozen documents and let code follow;
(b) record a Cross-Model-Waiver; (c) hold.

**The verbatim, dated human approval.** In-session, 2026-08-26, the
human ruled, choosing route (a) and ordering completion through Done:

> aで修正しDoneになるまでやり直して

(Contextual precursors the same day, same session: the route-(b)
execution approval 「他のタスクは君ができるでしょう。承認する。」 and the
fresh-panel order 「resh cross-modelでやりたい」 — the latter is why the
panel evidence above exists.)

**What the amendment did (ruling C(1))**: REQ-002's
`snapshot-generation-mismatch` row gains a second, detection-only,
mid-pipeline trigger site — immediately after REQ-001 step (e)'s own two
dependency invocations complete, a re-read of the Registry bytes alone
no longer matching the raw-bytes digest retained at the first read (or
that re-read failing) Blocks with the same id. design.md's snapshot
paragraph goes two→three rechecks; security-spec.md's B3 boundary row
records the mechanism; tasks.md allocates the site's fixture to T-003.

**(Ruling C(2))**: REQ-002's `dependency-output-malformed` row gains an
absent-component sub-trigger — an `affected_components[]` entry naming a
component id absent from the Context Projection Blocks before any
predicate evaluation; steps (f)-(g) never evaluate such an entry against
an empty or defaulted properties document.

### Amendment commits (full hashes) — rulings C(1)/C(2)

1. `5dcacc8ec06657800793b330847661f70719b747` — the documents-only
   amendment commit (requirements.md, design.md, tasks.md,
   security-spec.md), applied BEFORE any implementation, per the
   amendment-first procedure rulings A(1)/B(1) established.
   (Follow-ups in the same attempt-4 spec re-review round: AC-057/AC-058
   added to acceptance-tests.md, the step-reference wording anchored to
   REQ-001's own lettered steps, TEST-057/TEST-058 added to
   traceability.md's REQ-002 row, and this record itself — per the
   round-1 reviewer findings.)
2. `2ae0b9fdf8236ee95282d6330caabaf64e10671e` (implementation
   follow-up, code and fixtures only — no
   frozen document touched): step-(e) recheck reinstated with
   C(1)-citing comments; absent-component fail-closed with a new
   canonical detail sentence; fixtures
   `registry-swapped-during-validation` (reinstated) and
   `affected-component-absent-from-context` (new); block suite 224/0 in
   both runtimes.

### Per-document SHA-256 at amendment commit 5dcacc8e

- `requirements.md`: `7a27cafab8cf333c83476ed981b9e70175c2d83d653753f76401d8bffa160448`
- `design.md`: `3deccc793d3795e658927607b52cbe8de6a145622d8aec748c4c6975c8b3cdde`
- `tasks.md`: `3b69d7e157b552439a86fd58101a3ced218d03fc274b0960d8b75078016419a1`
- `security-spec.md`: `533c916439b08e0985acaa5142ba393b4e741de9fd48e1ae085918459d07bad7`

### Later-phase artifacts referenced (rulings C(1)/C(2))

- `docs/review-tickets/RT-20260826-002.yml` (the decision record; file
  sha256
  `373c0b5397df926bbdd69978e89c0eb3b1350b0e8dece16e9b0d5fab696193d2`)
  and `docs/review-tickets/RT-20260826-001.yml` (the route-(b)
  predecessor; file sha256
  `33c49afb2ddb186ae564124a67d27f5b55597d3ca916cdd9b9b185c82cbad591`).
- `specs/epic-193-a5-capability-resolver/verification/T-003.panelist-openai.verdict.json`
  (vendor openai, model gpt-5.6, verdict NEEDS_WORK, blind, input_digest
  `ab3589c71578a4b14816575ef00881bcbaf7a53c3e9438b61bd869ee705a9e9d`;
  file sha256
  `5533a3173ad68a671a64d2c4e51a8ffc7be90d644b22b4044627861cb56b6ab8`)
  and
  `specs/epic-193-a5-capability-resolver/verification/T-003.panelist-anthropic.verdict.json`
  (PASS, same input_digest; file sha256
  `1af5bddc5060646dd1f6e55d09ed772cc94adcda9446276a8b4b4a4bf8146ae2`) —
  the two-vendor evidence the ruling responds to.
- `specs/epic-193-a5-capability-resolver/verification/T-003.cross-model.json`
  (aggregate, result FAIL; file sha256
  `8437c9b6ee70d9750f82638a7e140fe5dcb0a0b9d89c75dd5b263fb781d63946`) —
  the consensus record that raised the ticket.

### Round-1/round-2 remediation extension (attempt 4, spec re-review, rulings C(1)/C(2))

The attempt-4 round-1 reviewers found this record's initial slice
incomplete (no dedicated ACs for the two new sub-triggers; a
numeric-step trigger-site reference REQ-001 itself never defines; and —
round 2 — no commit/sha pins for the follow-up slice, plus an
abbreviated commit hash and bare-path later-phase citations above, both
corrected in place). The follow-up commit that closed the round-1
findings is `2a6cb6ee9d909191e23c05c9a1d3f407999ddbdb` (2026-08-26): it
added AC-057/AC-058 (with TEST-057/TEST-058) to `acceptance-tests.md`,
re-anchored the C(1)/C(2) rows to REQ-001's lettered steps
((e), (f)-(g)) in `requirements.md`, propagated TEST-057/TEST-058 into
`traceability.md`'s REQ-002 row, cited AC-057/AC-058 from `tasks.md`'s
T-003 REQ-002 share, and appended the initial form of this very record.
Per-document SHA-256 after that follow-up (stable through this
extension's own authoring; investigation.md itself is excluded — it is
the self-referential record, exactly as the A①/B① lineage's own
extension excluded itself):

- `requirements.md`: `1028bf2c256f337971c7bb669133209fe96550bbcdc7d8460710d9d9a2bda0af`
  (one further one-line edit after the follow-up: commit
  `0d6283ede0cc227f703d4025f19dc998bbb012fb` added an explicit
  approval-evidence pointer to this very record from both amended
  REQ-002 rows — reviewer-visibility only, no semantic change)
- `acceptance-tests.md`: `a9fa4f898c70b7f4ecdf0d08c843555b7c89336b08712cfd6f5530a951916a99`
- `tasks.md`: `65877d63b4a385b9e2ed6aaee2f5034cc98e1674fca346e51338d0bfa77cfadd`
- `traceability.md`: `dc5f207354d1987c12055b28bf06427051b1ffa7fd0f25b7c4a09cc8ced81193`

### Rulings D(1)/D(2) (human-approved 2026-08-27) — an amendment made, then withdrawn on a corrected premise

This entry records BOTH halves deliberately, including the half that was
undone. Ruling D(1) authorised an amendment that landed in the frozen
documents for one commit; the attempt-6 round-1 spec re-review then
refuted the premise D(1) had been decided on, and ruling D(2) withdrew
it. A record that showed only the surviving outcome would leave commit
`fa1ad0e0` and the attempt-6 round-1 NEEDS_WORK evidence unexplained.

**What prompted D(1).** The round-5 cross-model panel on T-007 raised two
Majors that demanded opposite fixes — write Resolver Evidence on the
uncontained-staging Block, and do not write it — which is the signature
of a frozen-specification collision rather than an implementation defect.
The orchestrator escalated with four options; option 4 was to amend the
frozen specification rather than accept the deviation as a recorded
limitation.

**The verbatim, dated human approval (D(1)).** In-session, 2026-08-27,
the human answered the four-option escalation with the single character:

> 4

**What the D(1) amendment did.** Commit
`fa1ad0e01d54be9c7e0a2d58e1064a8a9bfa9f6e` (documents only:
`requirements.md`, `acceptance-tests.md`, `design.md`) gave REQ-002's
Evidence-on-every-Block rule a THIRD named exception — the
publication-journal-recovery sub-case in which this invocation's own
transient staging area is found to resolve outside the feature's
publication write set — mirrored it into the AC-012 rows of both
documents, and rescoped AC-047's "leaving the live state exactly as
found" wording in `acceptance-tests.md` and `design.md`.

**Why D(1) was withdrawn.** The attempt-6 round-1 spec re-review
(`reports/spec-review/epic-193-a5-capability-resolver/attempt-6/round-1/`,
orchestrator run `spec-orch-epic-193-a5-capability-resolver-a6r1`,
reviewer runs seq 0821/0822, ledger-reserved and validated) returned
NEEDS_WORK from two independent blind reviewers: Critical 3, Major 5,
Minor 0. Neither reviewer was told the amendment was sound, and neither
saw the other's findings. The decisive finding was reviewer B's
CONTRADICTION item (3): the amendment justified writing no Evidence by
asserting the write was "structurally impossible: the write would itself
have to pass through the very staging area just found to be uncontained",
but `requirements.md`'s own Main Workflows 4 (the
`disabled-legacy-invocation` Block) already specifies, verbatim,
"minimal Resolver Evidence written directly (no staging area ever exists
in this branch)". A non-staged Evidence write path was in this
specification all along, so the third exception was never forced — it was
a choice made on a misreading. All three cited passages were re-opened
and confirmed by the orchestrator before the finding was accepted.

The reviewers also found the amendment had left two sibling normative
statements asserting the opposite (REQ-004's "sole exception" sentence
and the Security Boundaries every-path guarantee), that its new predicate
"fixed publication write set" was defined nowhere and its two
cross-references disagreed, that its trigger had no row in a taxonomy the
document declares closed at sixteen rows, and that the fixture obligation
it asserted was owned by no test row. Those findings are dissolved by the
withdrawal rather than patched; they are recorded here because they are
the reason the withdrawal is the right outcome and not merely a reversal
of course.

**The verbatim, dated human approval (D(2)).** In-session, 2026-08-27,
the orchestrator put the corrected premise back to the human with three
options — withdraw the exception and write Evidence directly (B); keep
the exception and make it well-formed (A); stop (C) — and the human
selected:

> B: 例外を撤回し直接書く（推奨）

The option as presented read: drop the third exception; on that Block the
Resolver writes Resolver Evidence directly, exactly as Main Workflows 4
does; revert `fa1ad0e0` so the frozen prose returns to its two-exception
form; REQ-004, Security Boundaries and the sixteen-row enum all stay
intact; the cost is that T-007's implementation changes from writing
nothing to writing directly, with a new fixture, a further cross-model
panel round, and a quality gate.

**What ruling D(2) did.** Commit
`c44d056de286acc5afc4753722f47a3f72e1bac7` reverts `fa1ad0e0` in full.
Taking the revert component alone, all three documents return
byte-for-byte to the bytes attempt 5 reviewed and PASSED — `1028bf2c…`,
`a9fa4f89…` and `3af36f44…` respectively, `requirements.md` at its
`Spec-Review-Status: Pending` reset state, exactly as attempt 5's own
contract pinned it. Only `design.md` still carries that hash at the
commit itself, because the same commit also lands the C(1)/C(2) row
propagation described below, which touches the other two; the
authoritative post-commit digests are in the pin subsection further
down. No third exception exists anywhere in this package.
The behaviour change moves to Phase 2, where it belongs: T-007's Resolver
writes minimal Resolver Evidence directly on that Block, and no frozen
document needed amending to say so.

**Un-propagated-row correction carried by the same commit (completing
rulings C(1)/C(2), NOT a new decision).** Both attempt-6 reviewers
independently found that rulings C(1)/C(2) had authored AC-057 and AC-058
into `acceptance-tests.md` and `traceability.md` and amended REQ-002's two
rows to cite them, but had never added the matching rows to
`requirements.md`'s own Acceptance Criteria table, which ended at AC-056;
and that in `acceptance-tests.md` the two rows sat behind a blank line
with no header, so as Markdown they were outside the table entirely.
Commit `c44d056d` adds the two rows to `requirements.md` (its existing 56
rows untouched), removes the stray blank line, and updates the
`acceptance-tests.md` preamble inventory to AC-038 through AC-058 with
the reason the two arrived late. The counts now reconcile — 58 criteria,
55 test rows, the difference being exactly the three Global rows
AC-035/036/037 the file already documents as its one exception class — so
the 1:1 mapping that preamble declares holds in both directions again.

### Amendment commits (full hashes) — rulings D(1)/D(2)

1. `fa1ad0e01d54be9c7e0a2d58e1064a8a9bfa9f6e` — the D(1) amendment.
   Superseded: its every change is reverted by (3) below. Retained in
   history, and named here, because the attempt-6 round-1 review evidence
   is bound to the bytes it produced.
2. `c6f6242bd49cf8dadb507ed2d7759cc955588e37` — attempt-6 round-1 spec
   re-review evidence (reviewer outputs, integrated verdict, contract,
   report). No frozen document changed; `requirements.md`'s
   `Spec-Review-Status` line was set to `Pending` by
   `spec-review-precheck.sh --reset`, which owns that field.
3. `c44d056de286acc5afc4753722f47a3f72e1bac7` — the D(2) withdrawal, plus
   the C(1)/C(2) row propagation described above. Documents only.

### Per-document SHA-256 at amendment commit c44d056d

- `requirements.md`: `6567b5033ae1f56700e5756e81e15e530cde62ea054ab0b8fc40012a5da355fa`
  (at `Spec-Review-Status: Pending`; the field is the orchestrator's, and
  the hash moves with it when the attempt closes)
- `acceptance-tests.md`: `820ee5f6a522c213bc42731376cfe073e7e741128fcbb9bf26906ab394c58492`
- `design.md`: `3af36f445dd311a854d0dfa8f29c16ec7bc9f6e1b4e30f47a7cd4bf817065b69`
  (identical to its pre-`fa1ad0e0` bytes — the revert restored them exactly)
- `traceability.md`: `dc5f207354d1987c12055b28bf06427051b1ffa7fd0f25b7c4a09cc8ced81193`
  (unchanged; it already carried TEST-057/TEST-058 from ruling C)

### Round-2 remediation extension (attempt 6, ruling D(2))

Attempt 6 round 2 split: reviewer A returned PASS (6/0/1); reviewer B
returned NEEDS_WORK with one Critical and one Major. Every round-1
finding was confirmed closed by both. B's two findings are against text
this attempt did not author — the bytes attempt 5 reviewed and passed —
and the orchestrator re-opened and confirmed every cited passage before
accepting them.

**CONTRADICTION (Critical).** `acceptance-tests.md` TEST-012 requires a
full Resolver Evidence record on every TEST-010 Block fixture except two
named ones, and `publication-journal-recovery` is not one of them; the
same file's TEST-047 required that Block to leave "the live state exactly
as found"; and `resolver-evidence.yaml` is itself a member of both
track-exclusive publication target sets, so writing the record
necessarily changes one of the interrupted transaction's own targets. One
acceptance row therefore failed by construction whichever behaviour was
built. This is the same collision the round-5 cross-model panel raised on
T-007: the withdrawn D(1) amendment's AC-047 rescoping had been the part
that addressed it, so reverting `fa1ad0e0` restored it. Reviewer A read
the same clause as shorthand for AC-011's three publication artifacts —
a resolving reading the text does not state. Two independent reviewers
splitting on a clause a cross-model panel had already flagged is itself
the evidence that the wording, not the reviewer, was the problem.

**AMBIGUITY (Major).** The write mechanism for a sole-Evidence Block was
specified twice, incompatibly: REQ-004 said Evidence travels via the
journaled transaction and is "not exempt from that mechanism", and
REQ-001 step (m) said "this same transactional mechanism" writes the
sole-Evidence record while listing step (a) among its sites — yet Main
Workflows 4 and `design.md`'s own step-1 Block branches specified that
same step-(a) Block writes "directly (no staging area exists yet)". No
acceptance criterion discriminated.

**Both are decided by ruling D(2)'s own words** — 「例外を撤回し直接書く」,
quoted verbatim above — which say the Block writes Evidence (not an
exception) and writes it directly (not through the journal). No new human
decision was taken for this remediation; it is that ruling applied to the
places that state the same facts.

**What the remediation did.** Commit
`e6884a39e132915fb931b7670ea69c6b779825e2`, documents only, six sites
located by grepping every sibling statement of both facts BEFORE writing
any of them — two of the six appeared in neither reviewer's citations and
would otherwise have been the next instance of this package's recurring
propagation-drift defect:

1. `requirements.md` REQ-001 step (m) — the one-member Block write set is
   published directly (`temp file + fsync + rename`), no staging area, no
   journal; the journal exists to roll a multi-target rename sequence back
   as a unit, and on the (0) Block a second journal against the very
   Feature whose journal was just declared unconvergeable would be
   incoherent.
2. `requirements.md` REQ-004 — the mechanism is scoped by write-set size:
   alongside the rest of a track's output set Evidence is not exempt from
   the journaled transaction; as the only artifact written it is direct.
   The same edit records that REQ-004's "sole exception" and REQ-002's
   "two named exceptions" are two different scopes (exceptions to writing
   a record at all, versus to writing the full form), closing a Minor both
   rounds raised.
3. `requirements.md` Security Boundaries — that sentence governs *staged*
   artifacts, and a sole-Evidence Block stages nothing, so it is outside
   the sentence's subject rather than an exception to it.
4. `design.md` recovery enumeration — the live-state obligation stated per
   target: every interrupted target other than `resolver-evidence.yaml`
   exactly as found, and `resolver-evidence.yaml` itself receiving this
   invocation's own Block record.
5. `design.md` Security Boundaries mirror — same staged-artifact
   clarification as (3).
6. `infra-spec.md` Unrecoverable branch — the same per-target obligation,
   propagated to the layer spec.

`acceptance-tests.md` TEST-047 now requires the fixture to assert both
halves and states why either half alone is wrong. Checked and deliberately
left unedited: `security-spec.md`'s TEST-047 row and `tasks.md`'s T-007
fixture bullet both stop at "before any Registry/ownership/
Context-Projection work begins" and make no live-state claim, so neither
contradicts the amendment (`tasks.md` is additionally frozen under a
passed task review); `requirements.md`'s own AC-047 row never carried the
"exactly as found" clause. No AC or TEST id is added, renumbered or
removed, the diagnostic-id enum stays closed at sixteen rows, and no
exception is added to REQ-002.

### Per-document SHA-256 at remediation commit e6884a39

- `requirements.md`: `523484a8a1eb1097f2ee971c7da2df829857efe97ffedc4e624aa0703e251062`
  (at `Spec-Review-Status: Pending`)
- `acceptance-tests.md`: `de57e5d1ec91229a1fbffe1807e7953a3600bac37a80914cdb2744ee13d50c22`
- `design.md`: `a2d4068777a2928b5e13ba8ede43ca153f3d62d6249cde931985b9f9f09dac3d`
- `infra-spec.md`: `db1ea71d68a10ad8400004d2acc689c90c8463d5dd7a8cbba3cf4b8fe727ab5a`

### Round-3 remediation extension (attempt 6 BLOCKED, ruling D(2))

Attempt 6 round 3 — the terminal round — returned reviewer A NEEDS_WORK
(5/1/1, one Major) and reviewer B NEEDS_WORK (5/1/1, one Critical).
Merged: Critical 1, Major 1, so the attempt closed **BLOCKED** and
attempt 7 starts with `--reset`. Both findings were, again, the
propagation-drift class: a fact stated in several places and updated in
some of them.

**A, Major, CONSTRAINTS-EXPLICIT** — `requirements.md`'s Roles and
Permissions still routed Resolver Evidence through "the guarded journaled
publication transaction … journaled transactional commit"
unconditionally, contradicting the newly narrowed REQ-001 step (m) and
REQ-004. Seventh sibling site of the write-set-size fact.

**B, Critical, CONTRADICTION** — `requirements.md`'s Edge Cases crash
bullet and the **second sentence of the very Security Boundaries bullet**
the round-2 remediation had edited both still asserted absolutely that no
crash, Block or publication failure ever leaves "a mixed generation across
a multi-target batch" standing. TEST-047's newly explicit no-repair
obligation instantiates exactly that state and requires it to survive, so
the remediation had landed in one sentence of a bullet and left the next
sentence contradicting it. B also observed that the following bullet
already carried the correct exception wording, which is what identifies
the two absolutes as unmaintained siblings rather than a considered
position.

**Why the round-2 sweep missed them, recorded so the lane can be fixed
rather than merely re-run.** Two independent causes, both mechanical:

1. **Line wrapping defeats literal-phrase search.** These documents wrap
   at roughly 70 columns, so a two-word phrase is routinely split across a
   newline. `design.md` carried "leaving the live state exactly as\n
   found"; `grep 'exactly as found'` cannot match that and never could.
   That is how the ninth site survived two remediation rounds. The
   corrected method, used for this round, is to normalise whitespace
   across the whole file and search the normalised text while keeping an
   index back to original line numbers.
2. **A surfaced hit was not acted on.** `journaled publication
   transaction` did match `requirements.md:945` in the round-2 sweep and
   the line was in the output that was read. Reviewer A found it as the
   seventh site. The search was correct; the reading of it was not.

**The substantive resolution, stated once and used identically
everywhere.** The guarantee was never "a mixed generation never stands" —
the unconvergeable journal is precisely a case where one does,
deliberately, because AC-047 forbids repair there. The guarantee is that
**no invocation ever proceeds past one**: it is either converged away by
the mandatory crash-recovery scan, or it fails that invocation closed with
`publication-journal-recovery` and waits for a human. `tasks.md` had
carried the correct shape from the start ("converging … **or** Blocking
`publication-journal-recovery` if recovery cannot safely complete") and is
frozen under a passed task review, so it needed no edit — a useful check
that the formulation adopted here is the package's own, not a new
invention.

**What the remediation did.** Commit
`d74ae0da51c9983585e4b28fdda69088e7281bcc`, documents only:

1. `requirements.md` Edge Cases and `design.md`'s AC-047 acceptance
   mirror — the absolute replaced by the proceeds-past formulation, with
   the unconvergeable branch's no-repair obligation stated in place.
2. `requirements.md` and `design.md` Security Boundaries — the same for
   the multi-target-batch absolute, and the parenthetical permitting a
   fully-written Evidence path widened from "on a Block reached before
   publication" to any Block except REQ-002's two named exceptions, since
   the earlier clause did not cover the step-(m)/step-14 Blocks
   `artifact-publication-failed` and
   `post-publication-generation-mismatch`, for which REQ-001 step (m),
   REQ-004 and AC-012 all require Evidence.
3. `requirements.md` Roles and Permissions — scoped by write-set size,
   matching REQ-001 step (m) and REQ-004.
4. Both "stages nothing" clarifications — now distinguishing the on-disk
   `.resolver-staging/` sense from the separate in-memory assembly, which
   is what made the round-2 version of that clarification read as false;
   `design.md` cites steps 3/10/11/12, the numbers its own Design
   Decisions section uses, and `requirements.md` is reworded to not depend
   on step letters at all.
5. `requirements.md` REQ-002 — the stale "nineteenth" ordinal inside a
   sixteen-row enum, re-recorded by both reviewers in all three rounds,
   corrected to "seventeenth" with the correction stated in place.

One process note against the orchestrator: the verification sweep run
immediately after these edits initially read the **wrong checkout**,
because the shell's working directory had reset to the primary worktree
between calls. The edits themselves used absolute paths and landed
correctly; the sweep was re-run in this worktree before the commit, and
every claim above is verified against these bytes.

### Per-document SHA-256 at remediation commit d74ae0da

- `requirements.md`: `2870d38f6cd7560f74e8310a16c0f5a00c5dce03d57f4c2eeee3e88813a7745a`
  (at `Spec-Review-Status: Pending`)
- `design.md`: `c8fcfcbb1b3275472f15c676eb2344f72569ac4f3de8840ab6f93d2976bc789a`
- `acceptance-tests.md`: `de57e5d1ec91229a1fbffe1807e7953a3600bac37a80914cdb2744ee13d50c22`
  (unchanged by this commit)
- `infra-spec.md`: `db1ea71d68a10ad8400004d2acc689c90c8463d5dd7a8cbba3cf4b8fe727ab5a`
  (unchanged by this commit)

### Attempt-7 round-1 remediation (ruling D(2)) — the unscoped-negative class

Attempt 7 round 1 returned reviewer A NEEDS_WORK (5/1/1, one Critical) and
reviewer B NEEDS_WORK (5/1/1, one Critical). Merged: Critical 2, Major 0.
Both reviewers independently confirmed that attempt 6's findings are
closed — the write-mechanism fact consistent at every site either could
find, the proceeds-past formulation consistent in Edge Cases and Security
Boundaries, the enum closed at sixteen with the ordinal now
arithmetically correct, and the 58/55 AC-to-TEST counts reconciling on
exactly the three documented Global rows.

The two new Criticals are a single class, and it is the **mirror image**
of the one attempt 6 spent three rounds on. Attempt 6 fixed POSITIVE
absolutes that had become false ("never a mixed generation"). These are
NEGATIVE assertions that were always false for one target: clauses
denying that anything is written, at Blocks where `resolver-evidence.yaml`
is in fact written.

- **A** — `requirements.md` Edge Cases said the unconvergeable-journal
  Block leaves "the interrupted targets exactly as found", unscoped, while
  `resolver-evidence.yaml` is by REQ-001 step (m)'s own write-set
  definition always one of those targets. This sentence was written by the
  orchestrator in the round-3 remediation recorded above — and the
  `acceptance-tests.md` TEST-047 row amended in that same commit states
  the obligation per target and explicitly records that asserting the
  first half alone "would contradict AC-012". The first half alone is what
  was then written into `requirements.md`.
- **B** — `AC-040`/`TEST-040` and `AC-057`/`TEST-057` assert "no artifact
  reaches a live path" / "no live artifact" for `snapshot-generation-
  mismatch` Blocks that do write Evidence. `AC-057`/`TEST-057` were
  additionally impossible on their own terms: they assert the value of
  `capability_evaluations`, a field **of** Resolver Evidence, in the same
  sentence that declares the file unwritten. `AC-057` is a row this
  attempt added while completing ruling C's propagation; the defect came
  with the text copied from `acceptance-tests.md`, faithfully.

**Why the correct form needed no new decision.** `AC-011` has carried it
since before any of these rulings: "no `facet-manifest.yaml`,
`capability-summary.yaml`, or `project-context.resolved.json`". The
sibling `AC-058`/`TEST-058` assert the identical empty-array shape and
never carried the offending clause. So the remediation makes every sibling
say what two of them already said, rather than introducing a rule.

**What the remediation did.** Commit
`8d16045773bb6d0c64048c0b3b5351248da67eca`, documents only, seven sites
located by a whitespace-normalised sweep for the negative-claim class over
the whole package rather than from the reviewers' citations alone — **two
of the seven are in `security-spec.md`, which neither spec-stage reviewer
can see**, because the layer specs are outside that stage's input set:

1. `requirements.md` AC-040 and `acceptance-tests.md` TEST-040 — scoped to
   the three publication artifacts, with `resolver-evidence.yaml` stated
   as written.
2. `requirements.md` AC-057 and `acceptance-tests.md` TEST-057 — same, and
   the empty-`capability_evaluations` assertion now explicitly read *from*
   the `resolver-evidence.yaml` the Block writes.
3. `requirements.md` Edge Cases — every interrupted target **other than**
   `resolver-evidence.yaml` left exactly as found; that one target
   receives the Block record.
4. `design.md`'s AC-057 acceptance mirror, and `security-spec.md`'s
   TEST-040 and TEST-057 rows — the same scoping propagated.

Deliberately unchanged, each verified individually: the B3
self-referential `output-schema-validation-failed` case genuinely writes
nothing to any live path (`requirements.md:404`/`:858`,
`acceptance-tests.md:61`), and `design.md`'s "no live artifact this
invocation was not already committed to writing survives partially
written" is about torn writes rather than existence.

### Per-document SHA-256 at remediation commit 8d160457

- `requirements.md`: `758c6bb28b8de2a47c27ef8c92c97578f09b9517cf355b886b784916bc28d2ef`
  (at `Spec-Review-Status: Pending`)
- `acceptance-tests.md`: `fa49e8c7c09e0a9f674b49f73d63da71d13bdecadfd09c81970ba8cf343125fa`
- `design.md`: `928e18b15c249e32c34cd1ca0c951c89daaea8e0f67be0656674755b9dcd3d27`
- `security-spec.md`: `2ab16f8a455a4a2133c318663afaead9e7c3472daf9590665abf0b29109a44fe`

### Attempt-7 round-2 remediation (ruling D(2)) — one scope rule, sixteen sites

Attempt 7 round 2 returned reviewer A NEEDS_WORK (4/2/1) and reviewer B
NEEDS_WORK (4/2/1). Merged: Critical 2, Major 2 — but the two Criticals
are **the same finding, reached independently by both reviewers**, neither
of whom saw the other's output. That is the strongest signal this lane
produces, and it is what makes the diagnosis below reliable rather than a
single reviewer's reading.

**The Critical, found twice.** `AC-049`/`TEST-049` clause (b) required the
`post-publication-generation-mismatch` fixture to assert that "every one
of those renames is rolled back to its own PRE-transaction state before
this invocation exits". `resolver-evidence.yaml` is by REQ-001 step (m)'s
own write-set definition a member of every transaction target set, so
"every one" included it — while Security Boundaries (widened 2026-08-27
naming this exact diagnostic), AC-012 and TEST-012 all require Evidence
fully written at exit. The sibling `AC-047`/`TEST-047` had received the
per-target shape in the previous sweep and records verbatim that asserting
the first half alone contradicts AC-012; `AC-049` asserted that first half
alone.

**The two Majors.** (A) Security Boundaries claimed a Block whose whole
write set is Evidence "never creates that on-disk area at all", but
REQ-004 and REQ-001 step (m) place the two step-(m) Blocks in that class,
and both definitionally ran the journaled transaction that creates the
area — `AC-039` and `AC-049` require fixtures that depend on it existing.
Same site: the step list `(0)/(a)/(h)/(i)/(k)/(l)/(m)` was offered as
coextensive with "Evidence is the only thing written" but omitted at least
seven Evidence-only Blocks raised at steps (b)/(d)/(e) and inside the
(f)–(g) sweep, including the ruling-C(1) and C(2) sites `AC-057` and
`AC-058` govern. (B) `AC-038`/`TEST-038` asserted "no earlier-staged
artifact ever reached a live path" while naming fixtures for which
Evidence is both staged earlier (step (j)) and required to be written.

**The root cause, stated once.** This package's wording says "every
rename", "every target", "no artifact", "no earlier-staged artifact" in
many places where it means the three publication artifacts.
`resolver-evidence.yaml` is the one member of every transaction target set
that must SURVIVE, because AC-012's always-emitted rule excepts two
diagnostic ids and none of these. Every attempt-7 finding is an instance
of that one confusion, and the rounds were finding instances one at a time.

**What the remediation did.** Commit
`f9cd92aea58e76308e96c0455cef3ab2f57a50b0`, documents only. REQ-001 step
(m) now carries a single normative **rollback-and-no-write scope rule**
governing every such statement in the package: the subject is
`facet-manifest.yaml` / `capability-summary.yaml` /
`generated/project-context.resolved.json`, never `resolver-evidence.yaml`,
which instead carries that Block's own record written directly **after**
any rollback of the publication artifacts completes — because rolling
Evidence back would destroy the only record that the rolled-back
publication was ever attempted, the audit obligation REQ-004 exists to
guarantee. Every other site now points at that one rule rather than
restating it, so a future amendment has one place to change.

Sixteen sites, from a whitespace-normalised sweep of the rollback and
staged-artifact language across all seven documents rather than from the
reviewers' citations alone:

- `requirements.md` — REQ-001 step (m) (the rule itself), REQ-002's
  `post-publication-generation-mismatch` row, `AC-038`, `AC-039`,
  `AC-049`, Field Definitions "Block", and the Edge Cases post-recheck
  bullet.
- `acceptance-tests.md` — `TEST-038`, `TEST-039`, `TEST-049`.
- `design.md` — the Post-publication verification branch, the in-process
  rollback branch, the MIX recovery branch, the `AC-039` and `AC-049`
  acceptance mirrors, and the `AC-038` Design Decisions mirror.
- `security-spec.md` — the `TEST-038`, `TEST-039` and `TEST-049` rows.
- `infra-spec.md` — the MIX rollback branch.
- `tasks.md` — T-005's transaction summary and its `AC-038`/`AC-039`/
  `AC-049` Done-When bullets. Its `Status`, `Approval`, headings, Scope
  table and risk tier are untouched; the body had to move because it
  mirrors those AC rows verbatim, and leaving it would guarantee a
  task-stage finding.

Both of reviewer A's Major corrections are carried in the same commit: the
on-disk-area invariant is restated as being about the Evidence write's own
**route** rather than the area's existence, in `requirements.md` and its
`design.md` mirror; and both REQ-001 step (m) and REQ-004 now state the
Evidence-only condition as a **predicate** ("any Block at which no
publication artifact is left standing") instead of a step list.

### Per-document SHA-256 at remediation commit f9cd92ae

- `requirements.md`: `76d37914b80a0b226ee72762adf4eb4d5f33bb103f0f495b4fbaee78cd1d0f76`
  (at `Spec-Review-Status: Pending`)
- `acceptance-tests.md`: `297176439ce42500828e586fda0a04db3f50ecaca906f06f8b9b65ba0f8c3f1a`
- `design.md`: `e0817d5e3ec1f5cda8b4c1dca4858d1081c35983ba674004cf1055b27cb99dab`
- `security-spec.md`: `78200e63b635262b88edaaf80a61eb05d4fe7e794f4279e783f0fdfb381291de`
- `infra-spec.md`: `c8d7237469ece9bbf48bc6beaa29ba90c2e52d322e1da9cd0072850a771664de`
- `tasks.md`: `c087e895c7832ae65f48a52223769ad8ecd3817f450b4492af73b61b239b624c`

### Attempt-7 round-3 remediation (ruling D(2)) — repairing the repair

Attempt 7 closed **BLOCKED** at its terminal round: reviewer A returned
5 PASS / 1 FAIL (Major) / 1 SKIP — the first round in six with no Critical
from A — and reviewer B returned 4 PASS / 2 FAIL (1 Critical, 1 Major) /
1 SKIP. Attempt 8 follows.

**What is now closed, confirmed independently by both reviewers against
the current bytes.** The rollback-and-no-write scope rule is itself
correct and unambiguous; all sixteen sites pointing at it are consistent
with it; no site any longer asserts `resolver-evidence.yaml` is rolled
back or unwritten at a Block AC-012 does not except; the enum is still
closed at sixteen with no id added or renumbered; REQ-002 gained no third
exception; and the 58/55 AC-to-TEST counts reconcile on exactly the three
documented Global rows. The defect class that consumed attempts 6 and 7 is
gone.

**What failed is text the round-3 edit itself wrote**, and both findings
came with the minimal fix named by the reviewer who found it.

- **Critical (B).** The predicate substituted for the step list was
  self-contradictory: "every Block in REQ-002's taxonomy **other than**
  those whose own rollback restores previously-published bytes, and
  **including** … those reached at (m)" excluded and included the identical
  two ids, because the only Blocks step (m) raises are exactly the two
  whose rollback restores such bytes. REQ-004 already stated the same
  predicate without that carve-out, and three further sites resolved it the
  same way. Separately, "left standing" was undefined against artifacts a
  PRIOR successful resolve published — read literally, the predicate
  selected no Block at all, contradicting AC-047.
- **Major (A and B, independently).** `AC-038`/`TEST-038`'s new
  parenthetical asserted `resolver-evidence.yaml` "is written on each of
  these three fixtures", but `output-schema-validation-failed` has two
  sub-cases and `AC-055(a)` — Evidence itself fails its own
  self-validation — is one of AC-012's two exceptions and writes nothing
  at all.

**What the remediation did.** Commit
`8bc863904da9810a4687ee23e93fe8949472b141`, documents only. The rollback
carve-out is deleted, and "left standing" is defined as **"this
invocation's own publication transaction leaves no publication artifact
standing"** — bytes a prior resolve published and this invocation never
touched explicitly do not count, and the two step-(m) ids are explicitly
inside the class, since their own rollback is what leaves nothing
standing. The AC-038 claim is scoped to `AC-055(b)` in all five places it
appears: `requirements.md` AC-038, `acceptance-tests.md` TEST-038,
`design.md`'s Design Decisions mirror, `security-spec.md`'s TEST-038 row,
and `tasks.md`'s T-005 Done-When bullet — the last three located by sweep
rather than by either reviewer, since layer specs and `tasks.md` are
outside the spec stage's input set.

**Recorded against the orchestrator.** A wrong commit hash (`d0f2f0a` for
`d44aa7cf`) was typed into round 3's precheck edit summary instead of being
resolved — the second instance of that mistake this session. The precheck
forbids replay, so rather than editing a gate artifact the error and the
correct value were disclosed to both reviewers at launch, with an explicit
invitation to treat it as a finding of their own. Neither did; B recorded
it as a non-blocking observation with its reasoning. The standing rule this
leaves: never type a hash, always resolve it.

### Per-document SHA-256 at remediation commit 8bc86390

- `requirements.md`: `314a73844e65795405ad7db923df3a4e5540f4407c180e540eba6ace6babd0eb`
  (at `Spec-Review-Status: Pending`)
- `acceptance-tests.md`: `5319edb32874194dbbec583cb63b6a8ed23435f179230299be8341fc0a3043bb`
- `design.md`: `b2376c59e549effd78259f81e4cc23c476306686905c35fe00e3c5156ff4d5e8`
- `security-spec.md`: `a2b15f7eb67f4b357afda778a9569836941e5c58fa44b0ec69aa76fd33b02621`
- `tasks.md`: `855bf0bf6f6abba76d0c5a087c191c8bb84d0cd528e383be8285b5c1ce1ce184`

### Attempt-8 round-1 remediation, and a cross-model whole-package audit

**Round 1.** Reviewer A 5 PASS / 1 FAIL (Critical) / 1 SKIP; reviewer B
5 PASS / 1 FAIL (Critical) / 1 SKIP. The two Criticals are the same
finding, reached independently. Attempt 7's two defects are confirmed
closed by both: REQ-001 step (m)'s predicate is well-formed and selects
correctly for a first resolve and a re-resolve and for both step-(m) ids,
and the AC-038 claim is correctly scoped to AC-055(b).

**The Critical, and ruling D(2)'s application to it.** REQ-003's
advisory/required byte-identity guarantee was unsatisfiable on the Full
track: its permitted-difference set was three fields inside Resolver
Evidence, while its own amendment parenthetical says those digests hash
"the canonical Project Context text and the canonical Context Projection
text, which copies `workflow` verbatim" — and
`generated/project-context.resolved.json` **is** that Projection, so its
bytes must differ; `facet-manifest.yaml` fails identically via its own
`context_binding`. The 2026-08-24 B(1) amendment had recognised this exact
impossibility and propagated its carve-out to the Resolver Evidence
instance alone. The remediation restates the exception as a
set of **enforcement-derived fields excepted wherever they occur**, a
scope both reviewers note is derivable from INV-004's own schema field
lists rather than a new decision; the **Lite track is untouched**, since
`capability-summary.yaml` carries no `context_binding`.

**Then a cross-model whole-package audit, on the owner's suggestion.**
The owner proposed delegating spec work to Codex. It was adapted from
authorship — which is human-ruling-gated regardless — to an **exhaustive
defect enumeration over all seven frozen documents at once**, because the
actual bottleneck was discovery, not writing: the spec-stage reviewers may
read only `requirements.md` and `acceptance-tests.md`, so eight attempts
had each surfaced one or two defects and never the same family twice. The
audit returned **ten findings, four Critical**, and **five of them are in
files no spec-stage reviewer can read** — `security-spec.md`,
`infra-spec.md`, `tasks.md`, `traceability.md`.

Four were spot-verified against the live bytes before any edit, including
one against text this session had written two commits earlier. All four
held, and one was worse than reported:

- `requirements.md` stated that the Resolver "reads the clock, the
  network, and no provider API" — the exact inverse of the determinism
  guarantee its own next clause quotes. It had survived eight attempts and
  several PASS verdicts.
- The ruling-D(2) sweep had applied the rollback-and-no-write scope rule
  to the **recoverable** MIX branch, which raises no Block and proceeds
  into a fresh resolve, inserting a Block-record clause there against
  AC-047's own every-target-back-to-PRE requirement. That was this
  session's own error, in `design.md` and `infra-spec.md`.
- The diagnostic-row partitions summed to seventeen in `traceability.md`
  (which also said "thirteen complete" then "remaining four") and to
  nineteen in `tasks.md` — the two documents disagreeing with each other
  as well. Counting each task's own id list gives 5 + 5 + 3 + 3 = 16; the
  surplus was extra `snapshot-generation-mismatch` **fixtures** counted as
  rows, which `tasks.md`'s own parenthetical already admitted.
- AC-026 required "all ten" suites registered while `tasks.md` and
  `traceability.md` both say nine and explicitly defer the tenth.

**What the remediation did.** Commit
`12fd1241c5cc625677118d80efbfc6ecc74dc294`, documents only, closes all ten
across seven files. AC-026 and the infra CI sequence are narrowed to the
nine scheduled suites rather than scheduling a tenth, because the
alternative expands `tasks.md`'s declared scope and is not an
orchestrator's to take. The security authorization table gains the
Evidence-only direct-write path as an explicit allow, since it previously
forbade the very route REQ-001/REQ-004/`design.md` mandate and the only
route the unrecoverable-journal Block can take. The PRE/POST convergence
absolutes in `security-spec.md` and `infra-spec.md`, the pre-publication
ordering absolute, the "one exception" Block partition, and the "no
assembly step branches on `capability_enforcement`" claim are each scoped
to what they are actually true of. `traceability.md`'s `Status` column was
deliberately left untouched.

**Method note worth carrying forward.** The audit is a complement to the
gate, not a substitute: it reads everything at once and enumerates in
bulk, where the gate reads a narrow input set and adjudicates. Running it
BEFORE a gate attempt is what converts serial discovery into one batch.

### Per-document SHA-256 at remediation commit 12fd1241

- `requirements.md`: `2a9e598969c3154b61e24556d1728020c40e25ed9f7b5a02b9e6507a557220f2`
  (at `Spec-Review-Status: Pending`)
- `acceptance-tests.md`: `8aa438fbefcd03f527359e54932cf66537001ea2f193c6892233223d05c783a5`
- `design.md`: `fd66ac5ce1842adb4c3c00afd017a3c166662e909485335d1a62548530204725`
- `security-spec.md`: `4b63a57503d4e34725b7faaf2f1e87d8cec0df74fec04cabb675d01fcbe3e9aa`
- `infra-spec.md`: `1c0b9ca6e91548d5c2b1101f103adc4926b84b3bfbf0b0ce3103048800bca811`
- `traceability.md`: `55608d6547c6f999ea9f882a90e514255fcba3ee780c5e5ff01704e351765d17`
- `tasks.md`: `79c8cd67d140ac860e638171f81d00ff569b44d1db54f60e06831b4431de01c0`

### Attempt-8 round-2 remediation — the ten-versus-nine family, swept

**Round 2.** Reviewer A 5 PASS / 1 FAIL (Critical) / 1 SKIP; reviewer B
4 PASS / 2 FAIL (1 Critical, 1 Major) / 1 SKIP. Merged: Critical 2,
Major 1. The two Criticals are the same finding, reached independently.
A second Codex audit ran concurrently against the same bytes, told
explicitly that the dominant risk was now one-site fixes rather than
surviving defects; it returned five findings, **four of them drift from
the previous remediation's own repairs**.

**The Critical was a one-site fix of mine.** The first audit's AC-026
narrowing — from "all ten suites registered" to the nine `tasks.md`
schedules — landed in `TEST-026` alone. Its siblings still said ten: the
`acceptance-tests.md` preamble, REQ-006's at-minimum list, AC-027's
fixture matrix, `design.md`'s Infrastructure row, `infra-spec.md`'s CI
sequence, observability signal and rollback trigger, and
`frontend-spec.md`'s Testing section.

**The consequence neither audit saw, which reviewer A found.** `AC-042`,
`AC-046` and `AC-053` name the deferred suite as their **sole** Test
Target, so deferring it strands the whole of REQ-007's automated surface
— including the anchor-fingerprint drift check that is the only guard on
OQ-003's resolved insertion point, and which the Risks section cites as
its own mitigation.

**Reviewer B's Major.** `AC-009` demanded the Lite result "across each of
the three non-Blocking states" while its own `TEST-009` supplies fixtures
for two and states the third is unreachable under Epic A2's frozen
`lite_policy` schema — and forbids the only construction that could
produce it.

**What the remediation did.** Commit
`23be163094b5578e341b3c13430769a1e2bd9ba8`, documents only, eight files.
The package's position is now stated identically everywhere: **ten suites
specified at contract level, nine scheduled/authored/registered by this
package, the tenth deferred.** `AC-027` is scoped to the nine;
`AC-042`/`AC-046`/`AC-053` and their TEST- mirrors each carry an explicit
deferral note; the Risks anchor-drift mitigation is restated honestly, as
the recorded sha256/ordinal pair this package ships plus a specified
obligation rather than a running guard. `AC-009` receives the same
untestable-branch scoping `AC-016` and `AC-026` already use, with the
discharge assigned to the Epic A2 revision Dependencies already owns. The
second audit's four drift findings are closed — the "identical code path"
assertion whose range "3 and 7-11" still contained the step-10b exception
just carved out of it; "the sole Edge Case" still naming one
transaction-phase Block after the definition was widened to two; the
5+5+3+3 partition not propagated to T-007's other ownership cells; and
T-008's Governance Done When forbidding "no path under `plugins/**`"
while T-008's own Scope creates the `validate-resolver-evidence` family,
now narrowed in every task and in `traceability.md` to "no EXISTING
plugin file" with `AC-032`'s registration-commit scope stated.

**Method note, and it is the reusable part.** After editing, a
whitespace-normalised sweep found **five more variants** that the
same-string replacements had missed, because the line wrapping differed.
That post-edit sweep is now part of the loop rather than an afterthought.
The pattern this stretch established: run the cross-model audit BEFORE a
gate attempt, apply its findings, then sweep with normalisation, then
gate. Serial discovery through the gate alone cost six rounds; the audit
plus sweep closes in one.

### Per-document SHA-256 at remediation commit 23be1630

- `requirements.md`: `5ca5d758e6709e171e709507e2fa97b6adee406c725a562967d9926580f54dff`
  (at `Spec-Review-Status: Pending`)
- `acceptance-tests.md`: `fce2aa09b2999174dba37536c08d41b450183cb9b11acc52459f423fd8658618`
- `design.md`: `98feecb166dc1a27a241e62c9c38117420f4a51dd82ce79f9fef879c2b0fc458`
- `security-spec.md`: `4b63a57503d4e34725b7faaf2f1e87d8cec0df74fec04cabb675d01fcbe3e9aa`
  (unchanged by this commit)
- `infra-spec.md`: `0fc91789cdacb7da30b83147e3de58a59cfaa3508a2ce86e01b5ca009490aa35`
- `frontend-spec.md`: `d67d607494c728730691a8cec54cad9da73e3b59dcae5c423a13159ea51c0126`
- `traceability.md`: `2c322b219eadfcd6ff536cc2b754bfb0ef7c479a0c378f0024ce77107f38d5fc`
- `tasks.md`: `134af5107aa3dd27edb601e377e1aae14d9603c6733efde7a682df1d94573f2b`

### Third cross-model audit, run before the terminal round

The third audit was run deliberately **before** attempt 8 round 3 rather
than after it, so the terminal round would not be spent discovering what
an audit can enumerate in one pass. Four findings — one Critical, two
Major, one Minor. Across the three audits the trend is **10 → 5 → 4**
with severity falling, and every finding in this pass was sibling drift.

- **Critical.** The v1 remediation scoped the unrecoverable-journal
  branch's per-target obligation at `design.md`'s recovery enumeration
  and `infra-spec.md`'s MIX branch, but the Security-Boundaries-style
  sentences written in that *same* commit still said the whole state is
  left "exactly as found" while their own adjacent clause requires
  Evidence fully written. Closed at `design.md`'s proceeds-past bullet,
  `security-spec.md`'s crash bullet and `infra-spec.md`'s
  runtime-rollback bullet — and at the `requirements.md` mirror of the
  first, which **the audit did not name and the post-edit normalised
  sweep did**.
- **Major.** AC-047's two mandatory assertions existed only in TEST-047.
  Mirrored into `requirements.md` AC-047, `security-spec.md`'s TEST-047
  row and T-007's Done-When bullet, each stating both halves and why
  either alone is wrong.
- **Major.** `traceability.md` told every task author to register its own
  suite, while `tasks.md`'s serialization contract says only seven of ten
  do — T-003, T-004 and T-007 append fixtures to T-002's already-
  registered shared suite. Following traceability would have produced
  duplicate or unauthorized registration work.
- **Minor.** One stale "item e's four remaining rows" cell counting the
  extra `snapshot-generation-mismatch` fixture as a seventeenth row.

**What this pass demonstrates about the method.** The audit and the
post-edit normalised sweep catch **different** things and both are
needed: the audit found three sites the sweep's patterns would not have
flagged, and the sweep found a fourth site of the audit's own Critical
that the audit missed. Commit
`071c42fab76e0f9372a426c83e00206588682a19`, documents only, six files;
table integrity re-verified afterwards (58 AC rows, 55 TEST rows, the
sixteen-row enum intact, per-row pipe counts correct).

### Per-document SHA-256 at remediation commit 071c42fa

- `requirements.md`: `8ea947c7dca8946b8ed6c5cfb54d1bbe4ecac30d697cea945e1d5ac112d309e9`
  (at `Spec-Review-Status: Pending`)
- `acceptance-tests.md`: `fce2aa09b2999174dba37536c08d41b450183cb9b11acc52459f423fd8658618`
  (unchanged by this commit)
- `design.md`: `72dcf613c007e6e8815c495e5ae3e9c8deeca7dde6161dd6ec61b7da96335f55`
- `security-spec.md`: `20966ebf1bcfbf615807e284dade1a5a79de9923f7c8d0af7fc9d0b48601281b`
- `infra-spec.md`: `6840368c053d94bc4704ae3acb0f521cac647998e90238ba02adf2e03a65d51e`
- `traceability.md`: `420b4b924417688087f65965c35f862a18a0893b93dccbe3edda282e1e648cf2`
- `tasks.md`: `42e91e393365c9ae2692a5dc61a625b64b2cca4a34ecc79c5370a3c9178bb29e`

### Fourth cross-model audit — the security trust-boundary block

Three findings, all Critical, all sibling drift, and all clustered in one
place the previous passes had edited *around* without sweeping:
`security-spec.md`'s B2/B3 trust-boundary statements. Across four audits
the trend is **10 → 5 → 4 → 3**.

- **B2** said "every commit is one journaled, multi-target transaction",
  which requires the Evidence-only Block to journal — precisely what the
  unrecoverable-journal branch cannot do, since its premise is that the
  existing journal is unconvergeable. Scoped to commits that publish a
  track's output set, with the direct single-file route named.
- **B3**, and T-007's Goal, said rollback covers "every/any
  already-completed rename", which includes `resolver-evidence.yaml` —
  the one target that must survive. Scoped to publication-artifact
  renames in both, and in the `requirements.md` REQ-002
  `artifact-publication-failed` row that the post-edit normalised sweep
  then found still carrying the same unqualified wording.
- The **recovery trust boundary** listed three convergence outcomes as if
  exhaustive, leaving no room for the fourth, deliberately non-converging
  fail-closed outcome the package defines. Qualified with "when safely
  convergeable", and the fourth outcome stated.

This is the third consecutive pass in which the audit and the sweep each
caught something the other missed, which is now the strongest practical
argument for running both rather than either.

Commit `0647dad2`, documents only, three files.

### Per-document SHA-256 at remediation commit 0647dad2

- `requirements.md`: `515466ed5a61906dd640ccc4447c8b5ad3ef141bc439db45093d8f31c840aed7`
  (at `Spec-Review-Status: Pending`)
- `security-spec.md`: `3e3aecf7300eef9b0b81b7cba57b012a41653eb08138895d3a9171708a487d96`
- `tasks.md`: `c2026040f0b4207c7dfac96924ef9410508f1dad6efa969fe7b028ee4427e85c`
- `acceptance-tests.md`, `design.md`, `infra-spec.md`, `frontend-spec.md`
  and `traceability.md` are unchanged by this commit and keep the digests
  recorded for `071c42fa` and `23be1630` above.

### Fifth cross-model audit — the two inventories the gate cannot read

Two findings, both Major, **zero Critical**. Across five audits the trend
is **10 → 5 → 4 → 3 → 2**, with severity falling alongside the count.
The structurally interesting fact is *where* they were: neither finding was
in `requirements.md` or `acceptance-tests.md`. Both were in inventories the
spec gate's own reviewers are not permitted to read, which is the reason
eight attempts of that gate could never have surfaced them.

- `TEST-057` and `TEST-058`, the two ruling-C fixtures, existed as criteria,
  as test rows, as T-003's task assignment, and in `security-spec.md`'s
  fixture inventory — but were absent from `traceability.md`'s Acceptance
  Mapping, from its T-003 row, and from `infra-spec.md`'s block-suite CI
  inventory. A verifier following those inventories could have declared
  T-003 and the block suite complete without ever executing either
  fail-closed fixture. The mapping table now runs to 58 rows, matching
  `requirements.md`.
- The suite-topology node still drew RunAll to ten pairs, and
  `traceability.md`'s rationale still framed AC-026 as "satisfied for nine
  of ten only" — a shortfall against wording the criterion no longer
  carries, which reads to a reviewer as incomplete delivery rather than as
  deliberate scope.

This is the same ruling-C propagation gap that produced the AC-057/AC-058
work in `requirements.md` and `acceptance-tests.md`; these were its last two
unreached inventories.

Commit `4c80eb35`, documents only, two files.

### Per-document SHA-256 at remediation commit 4c80eb35

- `infra-spec.md`: `31a49759a3a83adc7f82b08f34e6d7ae3db9e91ef1de65258a9a9b55c8b81e9f`
- `traceability.md`: `7892be74cff2a3289fbb6bb1ad360693ae79b7d2c38dbf07ebf9aaa550192a3d`
- `requirements.md`, `acceptance-tests.md`, `design.md`, `security-spec.md`,
  `tasks.md` and `frontend-spec.md` are unchanged by this commit and keep
  the digests recorded for `0647dad2`, `071c42fa` and `23be1630` above.

### Attempt-8 round-3 — BLOCKED on one clause, and what that clause was

Round 3 is terminal, and it closed **BLOCKED**: Critical 0, Major 1,
Minor 0. `spec-reviewer-b` returned a clean **PASS** — six PASS, one SKIP,
zero findings — the first time in this attempt series that either reviewer
has produced a finding-free verdict. The whole of the BLOCKED verdict rests
on `spec-reviewer-a`'s single `SCOPE-BOUNDARY` Major, and that finding is
against text this session's own remediation wrote.

`AC-042`'s row asserted two incompatible things about itself. It stated, in
bold, that the criterion is discharged by the deferred, unscheduled
`resolve-project-context-caller-contract` pair and "is not closed by this
package's own tasks" — and then closed with "AC-015 and AC-042's own
spy-harness half remain closable here". AC-042's *entire* content is that
spy harness, and the same row defines it as "distinct from, and in addition
to" AC-015's narrower check. So the row named a half that does not exist:
there is no part of AC-042 that AC-015 covers, and no part other than the
deferred one. Under the trailing clause's reading, AC-042 must be closed by
a scheduled task while the frozen `tasks.md` schedules nine suites and
defers this pair — the criterion becomes unsatisfiable by the frozen task
package. That is the identical failure shape as round 2's Critical, where
AC-026 demanded ten registrations against nine scheduled.

The repair kept the true half of the distinction — AC-015 is a separate,
non-deferred row that this deferral does not touch — and dropped the claim
that AC-042 has a closable part.

Every other site was swept, whitespace-normalised, before the edit, and this
repair is genuinely single-site: `traceability.md`'s Acceptance Mapping says
"No task — deferred", `infra-spec.md`'s CI diagram says "DEFERRED — not
scheduled", and `tasks.md`'s deferral paragraph and `requirements.md`'s
REQ-006 sentence both state full deferral. Only the AC-042 row disagreed
with them.

Commit `68ee28ae`, one document, one table row.

### Per-document SHA-256 at remediation commit 68ee28ae

- `requirements.md`: `4f2ddc73f7199496059c28014ba2a6fd31f0571376af876808fd0d23203e4481`
  (at `Spec-Review-Status: Pending`)
- `acceptance-tests.md`, `design.md`, `security-spec.md`, `tasks.md`,
  `infra-spec.md`, `frontend-spec.md` and `traceability.md` are unchanged by
  this commit and keep the digests recorded for `4c80eb35`, `0647dad2`,
  `071c42fa` and `23be1630` above.

### Sixth cross-model audit — truncated by a provider usage limit

Recorded because an incomplete verification must not be reported, or later
read, as a completed one. The sixth audit was launched against the
post-`68ee28ae` bytes and terminated part-way through when the provider
returned a usage-limit error; it produced no findings section and no
"checked and found clean" section, so **it supplies no assurance either
way** and no finding of its own is carried forward from it.

It did surface one lead before stopping: a set difference showing
`TEST-035` present in `acceptance-tests.md` but absent from
`traceability.md`. That was verified by hand and is not a defect. The only
occurrence of the string in `acceptance-tests.md` is at line 8, inside the
sentence that *declares* the exception — "AC-035, AC-036, and AC-037 have no
TEST-035/036/037 rows" — so `traceability.md`'s not carrying the row is the
correct state, and the id-count asymmetry (56 unique strings against 55) is
an artefact of counting a negation as a mention.

Attempt 9 proceeds without a completed sixth audit. That is a deliberate
choice rather than an oversight: round 1 of a new attempt is not terminal,
so rounds 2 and 3 remain available as the buffer the audit would otherwise
have provided, and the audit can be re-run before any terminal round if
attempt 9 raises findings. The rule this package has been operating under —
run the cross-model audit *before* a terminal round — is unchanged.

### The round-3 bridge file was built on the wrong schema, and what that cost

Recorded because it changed which reviewer output is the round's evidence.

`integrated-summary.json` and `integrated-verdict.json` were generated from
the review-loop SKILL document's schemas rather than from
`spec-review-precheck.sh`'s, and the script is the authority. It rejected the
sealed round with `previous terminal contract is invalid`. Three divergences,
each enforced by exact-key equality: the summary requires
`reviewer_a_checks`, an array of `{id, result, severity}`, where a list of
bare check ids had been written; the verdict requires schema
`spec-review-integrated-verdict/v1` with a `finding_counts` object and the
four reviewer run/session ids inline; and the contract is validated against
the **live** summary hash rather than a pinned one.

That last point is why this could not be closed as paperwork. Correcting the
summary changes its digest, and re-pinning that digest into the sealed
contract and into `reviewer-b.json` would have made the evidence assert that
reviewer B had read bytes it never read. The summary is B's only bridge to A,
and the difference is not cosmetic: the canonical file states that
`SCOPE-BOUNDARY` FAILed at Major, and the file B actually received did not.

So the round was reconstructed rather than relabelled. `requirements.md` and
`investigation.md` were restored to their exact round-3 bytes — verified
against the digests already recorded in B's own manifest,
`515466ed…` and `dd82e666…` — the canonical summary was written, and
reviewer B was re-invoked against it under a fresh reserved identity, seq
839. Reviewer A never reads the summary, so its seq-837 output stands
untouched.

B reached a different verdict on the second invocation: `NEEDS_WORK` with one
`APPROVAL-BOUNDARY` Major, where seq 838 had returned a finding-free `PASS`
on byte-identical specification inputs. Two independent instances of the same
role, same bytes, opposite verdicts — the fresh-instance calibration variance
the framework acknowledges elsewhere with its TYPE-H convergence rule, which
the spec stage does not have. The finding was verified independently before
being acted on, and it is real.

Round 3 therefore closes **BLOCKED** on Critical 0, Major 2: reviewer A's
`SCOPE-BOUNDARY` (repaired in `68ee28ae`) and reviewer B's
`APPROVAL-BOUNDARY` (repaired under ruling E, below).

### Ruling E — the approval surface the specification only ever asserted

`requirements.md`'s Security Boundaries bullet 2 states that the Resolver
"never writes to any `*.approval.json` sidecar, any `sdd/.approved-context/`
anchor, or `guard-invariants.json` itself", and `security-spec.md` carries
the same statement as boundary **B6**. Nothing checked it.
`acceptance-tests.md` contained zero occurrences of any of the three
strings, and no acceptance criterion constrained the Resolver's write set in
either direction — neither as a deny-list nor as an allow-list.

What makes this a defect rather than a scope choice is the asymmetry with
its own neighbour: the adjacent Security Boundaries bullet — no clock, no
network, no Provider API — **is** locked, by AC-025/TEST-025, running a
repository-wide grep over exactly the same script set. One boundary got a
lock and the one beside it did not.

`git log -S` dates the bullet to `10f32fe2`, this package's original
2026-07-22 revision. So this is not amendment-propagation drift like rulings
C(1)/C(2) and D(2), and no existing ruling covered closing it — which is why
it was escalated rather than repaired under a standing authorisation.

**Question put to the owner, verbatim:**

> requirements.md の Security Boundaries は「Resolver は *.approval.json /
> sdd/.approved-context/ / guard-invariants.json に一切書かない」と宣言して
> いますが、これを固定する AC/TEST が 1 行も存在しません（隣の
> no-clock/no-network/no-provider-API は AC-025/TEST-025 でリポジトリ全体
> grep により固定済み）。初版からの欠落で、既存 ruling では閉じられません。
> どう処理しますか。

**Ruling, verbatim (2026-08-28):**

> B: T-007 に新 AC-059 を割当（推奨）

AC-059/TEST-059 are therefore added and assigned to **T-007**. T-007 is the
correct owner on two independent grounds: it authors the only code path in
this feature that ever writes a live artifact, and it is still
`Implementation Complete` rather than `Done`, so the criterion lands *before*
its own quality gate rather than as a verification backfill onto a completed
task — which is what assigning it to AC-025's own owner, T-009, would have
required.

TEST-059 is deliberately constructed as AC-025's twin: a registration-time
and CI-gated grep self-check, **not** a `tests/*.tests.sh` file. The
ten-suite Test Strategy and the nine suites `tasks.md` schedules are both
unchanged, and T-007 registers nothing new — so the suite topology that three
earlier rounds fought over does not move.

Propagated to every site that states the fact, after a whitespace-normalised
sweep: `requirements.md`'s AC table; `acceptance-tests.md`'s TEST table and
its preamble inventory; `traceability.md`'s Acceptance Mapping, T-007 task
row, Security layer coverage and REQ-001 test list; `security-spec.md`'s B6
boundary row, B6 STRIDE row and fixture inventory; `tasks.md`'s T-007 Must
Read and Done When; and `design.md`'s Security Boundaries list.

Two scope notes, both deliberate. `design.md` was **not** in the blast radius
described when escalating, and was amended anyway: omitting it would have
recreated the very asymmetry being fixed, one bullet further down, in the
document impl-review reads. `infra-spec.md` was **not** amended, and that is
the consistent choice rather than an omission — its CI inventory lists suite
files, AC-025/TEST-025 do not appear there either, and a grep self-check is
not a suite.

Counts after this amendment: **59 AC rows, 56 TEST rows, 59 traceability
mapping rows**, superseding the 58/55 figures recorded in the earlier
sections above. The difference of three remains exactly the documented
AC-035/036/037 Global exception, so the 1:1 mapping the acceptance-tests
preamble declares still holds in both directions.

Commit `4854a1bc`, six documents.

### Per-document SHA-256 at remediation commit 4854a1bc

- `requirements.md`: `7c5ac0f92ce4286b72f240330aaf5fcc62d52f641062a444921239b9e151e040`
  (at `Spec-Review-Status: Pending`)
- `acceptance-tests.md`: `0e3b90f923913cb058b4e28961040f1648a749c739b27145fea7854e5061b429`
- `design.md`: `cd542e9475c3f4c756784ee5e3e72a6727695ccb98ba11d6bd8586b286de2ae8`
  (at `Impl-Review-Status: Passed`)
- `security-spec.md`: `bb6a4836ab236ee4b6bf144ae3625d176edd1b3ed3bb4c80a6e865dc5a888298`
- `tasks.md`: `b4923f05d960102fb2dafa6e77a510dfbe96fd4ee81b01435c31dc3f3c048a20`
  (at `Task-Review-Status: Passed`)
- `traceability.md`: `0463f93ef01be1ceb04b27f1ccba6040e8638fa8da3c0db874cd49835006b528`
- `infra-spec.md` and `frontend-spec.md` are unchanged by this commit and
  keep the digests recorded for `4c80eb35` and `071c42fa` above.

### Ruling E's own repair — AC-059 named a glob its owner cannot reach

Ruling E's amendment cleared spec attempt 9 round 1 and impl attempt 5
round 1 with zero findings from all four reviewers, then met two Major
findings from `task-reviewer-b` at task attempt 11 round 1. Both were
against the AC-059 addition, and both were mine.

**`DEPENDENCY-OVERLAP` is the substantive one, and it is a real ordering
defect.** AC-059's grep names two Resolver-owned script families. Its
owning task T-007 authors only one of them: `validate-resolver-evidence.*`
is authored by **T-008**, which `tasks.md` sequences *after* T-007
(T-008's Blockers are `T-001, T-006, T-007`). T-007 therefore could not
scan half its own glob at its own gate, and T-008 carried no AC-059 anchor
of its own, so no task-level checkpoint anywhere in the package would have
verified the boundary against those files once they existed.

The mistake was mirroring AC-025 without noticing *why* AC-025 works: its
owner is **T-009**, whose Blockers span `T-002` through `T-008`, placing it
downstream of every script it scans. Ownership by the task that writes the
guarded path is not the same as ownership by a task that can see the whole
guarded set — and only the second makes a single-gate discharge sound.

All three load-bearing facts were verified directly before acting rather
than taken from the reviewer: T-008's Scope creates
`plugins/sdd-quality-loop/scripts/validate-resolver-evidence.{py,sh,ps1}`
as new files; T-008's Blockers include T-007; T-009's Blockers span
T-002..T-008. Neither script exists on disk yet — this is Phase 1, and both
are Phase 2 work — so the defect is genuinely in the specification's own
sequencing rather than an artefact of the current lifecycle state.

**The repair splits the discharge rather than moving the owner.** Moving
AC-059 to T-009, AC-025's own owner, would have made the glob verifiable at
one gate but would have landed the obligation on a task already `Done` —
the verification-backfill problem ruling E chose T-007 specifically to
avoid. So the criterion is now discharged in two parts: T-007 authors and
registers the check and it passes over the scripts that exist at its own
gate, and the registered check — a **per-commit CI gate**, not a one-shot
verification — covers `validate-resolver-evidence.*` when T-008's commit
lands, with no separate task obligation. That is exactly how
AC-032/AC-033/AC-034 already bind every task's commits without per-task
re-verification. The single respect in which AC-059 departs from AC-025 is
now stated at every site rather than glossed.

**`TASK-SIZE`** is the second finding. The bullet I added pushed T-007's
Done When from eight items to nine, past the oversized-task threshold, on
the package's most structurally complex task — and it was also the only
item in that list missing the `- [ ]` checkbox every sibling carries. It is
now folded into T-007's existing **Governance** bullet, which is already
the home of the AC-032/AC-033/AC-034 boundary self-checks and is where a
governance-boundary grep belongs. Done When is back to eight items and the
formatting inconsistency is gone.

Two observations worth keeping. First, this is the third consecutive stage
at which a repair carried its own defect — the ruling-D(2) scope rule, the
AC-042 clause, and now AC-059 — which is the strongest evidence yet that
the risk in this package is no longer missing content but the propagation
of newly written content. Second, `task-reviewer-a` returned PASS on all
fourteen checks against the same bytes in which `task-reviewer-b` found
two Majors, including A's own `AC-COVERAGE` and `TRACEABILITY-SYNC` checks
which read the very rows at issue. The two roles' check sets are genuinely
complementary rather than redundant, and a single-reviewer gate at this
stage would have shipped the ordering defect.

Commit `94704f9c`, six documents.

### Per-document SHA-256 at remediation commit 94704f9c

- `requirements.md`: `052e05edb07782249cb9972942d92978f6a59fd7f378bf110932c4afb6b37d01`
  (at `Spec-Review-Status: Passed`)
- `acceptance-tests.md`: `8d165d055102dcf6767e5441870a05e9384b81d513b20c4892b06e8b1334c92a`
- `design.md`: `c42b74f0662a10463f1c0eeb3e946878f36e937f4642c2e9537051eee542a38f`
  (at `Impl-Review-Status: Passed`)
- `security-spec.md`: `2fb6b21580b0ee6217e2159204742da970401f4316b3b10d9e8c7eed91eb919b`
- `tasks.md`: `9c2684f076a6f8f4779a965fa5302d4758b5c488a98323d5e6e8735095d9df0f`
  (at `Task-Review-Status: Passed`)
- `traceability.md`: `8c64e87e95f753c19d69f630c1217b010bc341a5a4ce1562e1aa7996aa2dc452`
- `infra-spec.md` and `frontend-spec.md` are unchanged by this commit and
  keep the digests recorded for `4c80eb35` and `071c42fa` above.

Because this amendment touches `requirements.md` and `acceptance-tests.md`,
the spec stage is re-staled along with impl and task. The three gates are
therefore re-run in order — spec, then impl, then task — with **no document
edit between them**, which is the only sequence in which this package's
prechecks converge.

### AC-059's real error was one level up: the validator is not the Resolver

The sequencing repair above cleared spec attempt 10 with zero findings from
both reviewers, then met a Major at impl attempt 6 from `impl-reviewer-b`
(`VERIFICATION-PATH-CONCRETE`). The repair had leaned on the registered
check being a **per-commit CI gate** that would cover
`validate-resolver-evidence.*` once T-008's commit landed. `design.md`'s own
Deployment / CI Plan says the opposite: this Phase 1 package performs no CI
wiring, suites register in the unprotected `tests/run-all.*`, and actual
GitHub-Actions gating waits on a separately staged, **human-applied**
`.github/workflows/test.yml` patch — the same caveat AC-026/TEST-026 already
carries. The bridge the repair depended on does not exist.

That was the fourth consecutive round in which a repair carried its own
defect, which is the signal that the repairs were treating a symptom.
Stepping back one level found the actual error, and it is simpler than
either round of repair.

`requirements.md`'s own Field Definitions state:

> **Resolver**: this feature's own name for `resolve-project-context.{py,
> sh,ps1}` … This term never refers to a different script anywhere in this
> package.

The Security Boundaries bullet AC-059 exists to lock has **the Resolver** as
its only subject. `validate-resolver-evidence.*` is not the Resolver. So it
never belonged in AC-059's scanned set: the original drafting widened the
criterion past the boundary it locks — mirroring AC-025's *glob* without
noticing that AC-025's subject is different — and that widening is what
produced the T-008 ordering problem, and then the CI-timing problem
downstream of it. Two rounds of reviewers each found a true consequence of
one upstream mistake.

The scanned set is now the Resolver alone, which T-007 itself authors. That
restores the property that makes AC-025 sound and that both failed repairs
were groping toward: **the owning task verifies the whole scanned set by
direct execution at its own gate**, depending on no later task and no later
human action. AC-025 legitimately scans both script families because
REQ-005's determinism guarantee names both; AC-059's subject is narrower.

The validator's own write scope is not left unguarded — it remains governed
by Epic A1's `guard-invariants.json` suffix enforcement at write time and by
the unchanged Security Boundaries prose. What changed is that this package
no longer *asserts* a criterion over it that no task here could discharge.
The gap is stated as left to a future criterion rather than papered over,
which is the honest form of the same position.

Two lessons worth keeping. First, mirroring an existing criterion copies its
*mechanism* but not its *subject* or its *ownership topology*; AC-025's
soundness rests on all three agreeing, and only the first was copied.
Second, when three successive repairs each draw a new finding, the defect is
upstream of all of them — the right move is to re-read the definitions the
criterion depends on, not to add another bridging clause.

Commit `bf618824`, six documents.

### Per-document SHA-256 at remediation commit bf618824

- `requirements.md`: `35dc2737b968a9e11ea6e9b054eb987fa1f146e89dd5005582d0a1331f601b11`
  (at `Spec-Review-Status: Passed`)
- `acceptance-tests.md`: `bd15dcada852b89c9ce236e0dbb60e7928230d7dfb69c8789e498e89d8418f04`
- `design.md`: `f5baa3b7ed12eb5b5ebf74c1e95aead84a9c1642f6beca54e38dddb4cb02713c`
  (at `Impl-Review-Status: Passed`)
- `security-spec.md`: `e68cf5bd8646ad5c86231d6b456ba1f5a3b0a0745f804e3a020da4801c68a831`
- `tasks.md`: `ed3f391a9fe37ec4a1383ac8036a0b4ca22cc16e4520bff0861e154e69f8dacd`
  (at `Task-Review-Status: Passed`)
- `traceability.md`: `0509e3c8c8534f6e637c62f28509b75f07e39cbc9d8ee228540ba3ca19edef1a`
- `infra-spec.md` and `frontend-spec.md` are unchanged by this commit and
  keep the digests recorded for `4c80eb35` and `071c42fa` above.

One advisory is carried forward rather than fixed, because correcting it
would re-stale all three gates for a citation nit and two independent
reviewers each judged it below the finding bar: the AC-059 prose formerly
cited AC-032 alongside AC-033/AC-034 as sharing a per-commit binding, where
AC-032 is registration-commit-bound and AC-033 is per-task-verified. The
sentence carrying that citation is removed by this commit, so the advisory
is closed as a side effect rather than left open.

### Ruling (A) — a symlinked publication target is never read through; its PRE state is ABSENT

**Put to the owner 2026-08-29 during panel rounds 17-18, answered verbatim:
「A」** — selecting option (A) from three stated alternatives: (A) treat a
symlinked target's PRE as `ABSENT` and never read through the link, (B)
refuse a symlinked publication target at publish time, (C) keep the round-17
repository-containment clause and record the residual as a known limitation.
The recommendation given was (B); the owner chose (A).

**The history that led here, recorded because the panel found it missing.**
Round 17 (openai Major): ruling (b)'s leaf-symlink acceptance let
`_live_bytes` read THROUGH a target symlink, copying an out-of-repository
referent's bytes — a credential included — into the PRE-image staging area,
against security-spec.md line 17's "never ... reads a credential". The
round-17 fix refused only referents that leave the repository. Round 18
(anthropic, two Majors): that fix was under-scoped — the boundary is about
credentials, not repository containment, so an in-repo `.env` or
token-bearing git config still passed — and over-applied, because
`_write_evidence` consults the same predicate before a write that performs no
read at all, silently widening the owner-ruled third AC-012 no-write
exception to an undisclosed fourth condition. Round 18 also found the same
read-escape's sibling on the PRE-image side (`pre/<basename>` as a committed
symlink, read before its hash check), fixed with backup-side containment and
its own fixture.

**What (A) does.** The rule lives where the read happens: `_live_bytes` does
not follow a leaf symlink, so a symlinked target's PRE state is `ABSENT`
everywhere that helper is consulted — PRE capture, rollback verification,
recovery classification, post-restore verification. The round-17 clause is
retired in both directions and `_target_escapes_via_symlink` is purely about
where writes land again, which restores the ruled third-exception boundary
for Block Evidence.

**The accepted deviation, stated plainly.** AC-047's wording expects a
rolled-back target restored to byte-identical PRE. Under (A), a target that
was a SYMLINK before publication is rolled back to `ABSENT` — the link is
unlinked, not put back. This is a real behavioral deviation on a
Security-Sensitive surface, authorized by this ruling: the referent's bytes
are not the artifact's own content, reading them to "restore" them is itself
the boundary violation, and the commit would have clobbered the link entry
anyway. The round-15 leaf-symlink fixture's assertion was rewritten to assert
exactly this outcome (target ABSENT, referent byte-untouched, referent bytes
captured nowhere) rather than deleted, and mutant K mutates `_live_bytes`
back to following the link to keep the ruling itself covered.

### Ruling (c) — the journal-mediated in-set manipulation class is closed as already-adjudicated

**Put to the owner 2026-08-29 after fifteen panel rounds**, with the options
stated as: (a) keep chasing the security findings, (b) issue a scope ruling,
(c) stop here, (d) raise the panel rule itself as a WFI. The recommendation
given was (b) + (d), and the owner answered **「君の推奨案で進めろ」**.

**What (b) covers.** Panel round 14 (openai) and round 15 (anthropic) both
found that a journal planted in the unprotected, repository-local staging area
can steer the MIX rollback into UNLINKING a live in-set artifact — round 14
via an in-set subset, round 15 via a bundle-shaped set with a fabricated
`pre_hash: "ABSENT"` on one entry. Round 15 added `_legitimate_journal_bundles`
and a fixture for the first shape (mutant G kills it on four assertions), and
the anthropic slot correctly observed that constraining the SET leaves the
per-entry PRE/POST encoding unconstrained, so the class survives.

That class is the one panel round 1's MAJOR 1 already put to the owner and had
ruled OUT OF SCOPE: an attacker who can commit a journal into the staging area
manipulating an artifact that stays INSIDE the fixed publication target set.
Round 1's instance was attacker CONTENT written into an in-set target; these
are attacker-driven DELETION of one. Deletion is more destructive than
substitution, and that difference was stated when the question was put — the
owner ruled the class closed anyway. Both artifacts are git-tracked and a
clean resolve republishes them.

**What (b) does NOT cover, and what happens to it.** The ruling is about
attacker-driven manipulation only. Two round-15 openai findings are not in
that class and are handled separately:

- *The `artifact-publication-failed` branch discarded its journal before the
  Block record was durable.* Not attacker-driven, and the same defect already
  fixed on the two post-publication branches. Swept here: the exception now
  carries its transaction and rollback outcome, and the caller discards only
  once `_block_reporting` confirms the record was written. All three
  Block-after-rollback paths now share one discard discipline.
- *An all-POST journal is treated as a completed transaction and deleted,
  although that same state exists after the final rename and before
  post-publication verification.* This is the frozen four-outcome
  classification behaving as design.md specifies. Changing it is a contract
  change, not an implementation choice, so it is recorded here as a known
  limitation rather than patched — the same disposition the 2026-08-27 ruling
  gave the doubly-degraded rollback corner.

**What (d) produced.** `docs/workflow-improvements/WFI-060.md` (renumbered from 038 on 2026-08-29: main already carries a DIFFERENT WFI-038 and its numbering has reached 059, this branch being 575 commits behind; a blanket 038-to-060 text replacement then rewrote this very sentence's explanation into nonsense -- the anthropic panel slot caught it on round 19, and the sweep-breaks-its-own-explanation irony is preserved here on purpose).
`check-cross-model` requires every panelist verdict to be PASS and has no
outcome for panelists diverging from each other — its one `NEEDS_HUMAN` path
fires only when the EVALUATOR diverges from an already-unanimous panel. Across
rounds 13-15 the two slots alternated, contradicted each other on substance,
and once returned different verdicts on identical production bytes. The WFI
proposes splitting step 6 so a no-Critical divergence with at least one PASS
becomes `NEEDS_HUMAN` (a distinct exit code) instead of an unbounded
remediation loop. The aggregate schema already carries `divergence` and
`requires_human_decision`; only the control flow never produces them.

### Rulings (a) and (b) — the third AC-012 exception, and a containment check stricter than its own write

Both cross-model panel slots reached the same code on rounds 8 and 9 and
disagreed only about severity. The openai slot filed a Major with two halves;
the anthropic slot had already filed the first half as a Minor on round 6.
Neither half was an implementer's call, so both were put to the repository
owner, who answered on 2026-08-28: **「(a) 受容 / (b) 承認」**.

**Ruling (a) — the third no-write exception is accepted as a known
limitation.** `requirements.md` line 386 says AC-012's always-emitted rule
"excepts exactly two diagnostic ids". `EvidenceTargetUncontained` is a third:
when `specs/<feature>/resolver-evidence.yaml` does not resolve inside
`specs/<feature>/`, the Block emits no Evidence. The alternatives were stated
plainly and there is no third one — writing to a destination that resolves
outside the tree IS the escape every panel round since round 1 has been
closing, not writing exceeds AC-012's count, and only the latter fails
closed. The owner accepted the deviation rather than authorizing an amendment
to the frozen text.

**No frozen document was amended for it.** The ruling is recorded in this
file and in the `EvidenceTargetUncontained` docstring, which is the same way
the 2026-08-27 ruling on the doubly-degraded rollback corner was recorded.
Amending `requirements.md` would have invalidated all three currently-green
review gates and forced the whole spec → impl → task chain again, for a
sentence whose count is now documented as having a sanctioned exception.

**Ruling (b) — `_target_escapes_via_symlink` is narrowed to the target's
parent.** The check resolved the FINAL path component, but every write in
this file lands via `os.replace(tmp, target)`, which replaces the directory
entry at `target` rather than following a symlink sitting there, and the temp
file is created with `mkstemp(dir=target.parent)`. The parent is therefore
the only component whose symlinks can move a write. Resolving the leaf too
modelled a write the code does not perform, and refused valid in-tree
destinations. The narrowed form still catches a symlinked `specs/<feature>`,
a symlinked `generated/`, any symlink between the trusted base and the
parent, and every lexical `..` traversal.

The two rulings interact: (b) shrinks (a)'s reach to the irreducible case. A
symlink at `resolver-evidence.yaml` itself no longer suppresses Evidence;
what remains is a feature directory that genuinely resolves outside the tree,
where no valid write exists at all.

When the rulings landed, both changes were behaviour-preserving against the
existing suite (356 passed, 0 failed in both runtimes, unchanged by either
edit). **That was not reassurance, it was the warning.** No fixture placed a
symlink at a leaf publication target, so ruling (b)'s whole newly-permitted
branch was unexercised — and the very next panel round found a defect
reachable only through it: `_repo_relative` resolved the entire path, so with
a leaf symlink now accepted the journal recorded the symlink's REFERENT while
the commit replaced the LEXICAL entry, and a rollback then restored the
referent and left the published bytes standing while reporting success.

`_repo_relative_target` now records the lexical entry, by the same
parent-resolve rule the containment check uses — a check and a journal that
disagree about what "the target" means reintroduce exactly this class. The
missing fixture was written rather than disclosed: the
post-publication-mismatch path with `facet-manifest.yaml` planted as a
symlink to an in-tree sibling, asserting that the publish is not refused,
that the LEXICAL entry holds its PRE bytes after rollback, and that the
referent is byte-untouched. The suite is 361/0 in both runtimes, and mutant E
(journal path resolving the leaf again) kills it on three assertions.

#### Per-document SHA-256 after these rulings and the fixture they required

| Path | SHA-256 |
|---|---|
| `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-loop/scripts/resolve-project-context.py` | `46d3143eded2fb771226a1d691613f62c09e72f0d4ae5852825e76b6c920c37c` |
| `tests/resolve-project-context-block-check.py` | `3f4308c8f1c9fc4562d62595502483eca32ee58446c2b61d57529ad60bc5cbfe` |

### Ruling (B) — directory-fsync hardening is POSIX-only; Windows retains the file-fsync + journal discipline as a disclosed limitation

**Date**: 2026-09-03. **Context**: cross-model panel round 32 (the second
Codex run on digest `dee00fdc…`, after the first run's PASS was invalidated
by a missing `blind` attestation in the runner template — a tooling defect,
not a content judgment). That run returned one Major: `_fsync_directory`
returns immediately when `os.name != "posix"`, so on Windows the journal
rename, staging-chain creation, publication renames, rollback unlinks and
pre-discard recovery barriers all proceed without directory-entry
durability, while AC-047's recovery guarantee is stated without a platform
qualifier. The same bytes had drawn PASS from the same vendor slot one run
earlier, and the POSIX-only nature of every one of these barriers has been
disclosed in the shipped code and the report since round 24.

**Options put to the owner** (2026-09-03):

1. **裁定で閉じる（推奨）** — 「directory-fsync 硬化は POSIX 限定、Windows は
   file-fsync + journal 規律（round-19 以前の全プラットフォーム posture）を
   開示済み限定として受理」とオーナー裁定し、investigation.md に逐語記録して
   round 32 を回す。Python に移植可能な代替が無く、ctypes 機構はここでは
   未テスト出荷になるため。
2. **Windows 実装を書く** — ctypes で FlushFileBuffers +
   FILE_FLAG_BACKUP_SEMANTICS のディレクトリ同期を実装する。この環境に
   Windows が無く実行検証不能のまま出荷となり、新たなラウンドを誘発する
   リスクが高い。
3. **もう一度だけ再実行** — verdict shopping に近づくため非推奨。

**The owner's verbatim answer**: 「裁定で閉じる（推奨）」

**Scope of this ruling.** The directory-entry durability barriers introduced
on rounds 19 through 30 (`_fsync_directory` and every call site: the
write-side barrier in `_atomic_write_bytes`, the ABSENT-restore unlink
barrier, the staging-chain barrier in `_publish_bundle`, and the pre-discard
barrier in `_recover_journal`) are POSIX-only by design. On Windows the
Resolver retains what every platform had before round 19: per-file
`os.fsync` before every rename, the journal-before-first-rename ordering,
and the full crash-recovery scan — the posture the panel repeatedly accepted
as satisfying AC-047 before the directory-barrier hardening existed. Python
offers no portable directory-synchronization primitive on Windows; a ctypes
`FlushFileBuffers` mechanism over `FILE_FLAG_BACKUP_SEMANTICS` handles would
ship untested from this environment, and NTFS's own metadata journaling
provides a different (and partially overlapping) guarantee model. The
limitation is DISCLOSED, not silent: the `_fsync_directory` docstring states
it, the implementation report states it, and this ruling records the owner's
acceptance. A future task MAY add a tested Windows barrier; its absence is
not a defect of this task.

**Counter-argument, stated rather than buried.** A hard crash on Windows
between a live rename and the (absent) directory barrier can lose the
journal's directory entry while keeping the rename — the undetected mixed
generation AC-047 targets. That exposure is real, platform-scoped, equal to
the pre-round-19 exposure everywhere, and accepted by this ruling on the
grounds that the only available in-repo remedy is an untestable one.

### Ruling (F) — the frozen criteria text is amended to mirror rulings (a), (A) and (B)

**Date**: 2026-09-03. **Context**: spec-review attempt 12 (the post-Done
re-binding attempt). Both blind reviewers independently raised the same
Critical: the frozen AC-012/AC-047 text contradicts the owner-ruled reality
this file records — rulings (a) (a third, non-diagnostic no-write condition),
(A) (a symlinked target's PRE is ABSENT) and (B) (POSIX-only directory
barriers) were each accepted WITHOUT amending the frozen text, a choice those
rulings made explicitly to avoid re-staling the then-green review gates.
Reviewer A: "AC-012 and AC-047, read literally, are impossible for the
disclosed, owner-approved implementation to satisfy." Reviewer B: "a future
caller would build against a promise the owner has already, on the record,
accepted as false."

**Options put to the owner** (2026-09-03): (1) archive attempt 12 and record
the CI red as a documented known-issue, keeping the wording debt; (2)
authorize amending the frozen criteria text with ruling annotations and
re-run the spec→impl→task chain; (3) rule the wording debt permanently
accepted and complete attempt 12 as BLOCKED.

**The owner's verbatim answer**: 「凍結文書の修正を承認」

**Scope of this ruling.** requirements.md's REQ-002 exception-count sentence
and acceptance-tests.md's AC-012 and AC-047 rows are amended — in the
document's own established annotation style (cf. ruling D(2)) — to mirror
rulings (a), (A) and (B) verbatim by reference, changing no behavioral
requirement: the third no-write condition is stated where the count was
stated; AC-047 carries the symlink-PRE and POSIX-only qualifiers those
rulings already fixed. The spec→impl→task re-review chain runs on the
amended text. The earlier rulings' choice not to amend was correct FOR ITS
TIME (the implementation phase, where a re-staled chain would have blocked
every task); at feature completion the calculus inverts, and the chain is
being re-bound anyway.

**Executed amendment (evidence).** The scope above was the ruling-time
plan; executing it surfaced the amendment-propagation defect class inside
the amendment itself, twice (attempt-12 round 2: both reviewers' Criticals
enumerated the unamended sibling sites in requirements.md; round 3:
reviewer B's Critical named acceptance-tests.md's unamended AC-011/AC-039/
AC-049 rows). The final, comprehensive amendment therefore covers, under
this same authorization: in requirements.md, a document-wide Ruling
Annotations reading rule before the Acceptance Criteria table plus inline
markers at the AC-011/AC-012/AC-039/AC-047/AC-049 rows, the REQ-002
closing paragraph, the REQ-004 reconciliation footnote, the Field
Definitions "Block" entry, Edge Cases, and both Security Boundaries
sentences; in acceptance-tests.md, its own document-scoped Ruling
Annotations rule plus inline markers at the AC-011/AC-012/AC-039/AC-040/
AC-047/AC-049 rows. The authoritative site enumeration is mechanical, not
prose: every line carrying the literal marker `ruling (F)` in either
document as of the amendment commit (12 such lines in requirements.md, 5
in acceptance-tests.md), plus the two rows amended in round 2 under this
ruling before the marker convention existed (acceptance-tests.md's AC-012
and AC-047 rows, whose annotations cite the mirrored rulings directly).
Amendment commit: `45dbe5f1e92c299a3523fff5051ab984e520bd16`
(docs(epic-193-a5-capability-resolver): comprehensive ruling-(F) amendment
of the frozen spec pair). SHA-256 as of that commit:
`specs/epic-193-a5-capability-resolver/requirements.md` =
`6f99607959b0d40e290c6526254d6a9e4e3a4b5c67fab11ef419a97a8c3a24ae`;
`specs/epic-193-a5-capability-resolver/acceptance-tests.md` =
`709f43bce87b9115e167dc629a4a071424ef44b1e3d48976eeec12c2d2ecd8c8`.
No behavioral requirement changed at any site: each annotation states, by
reference, what rulings (a)/(A)/(B) already fixed on the record.
