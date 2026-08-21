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
