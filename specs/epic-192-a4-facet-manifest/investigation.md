# Investigation: epic-192-a4-facet-manifest

Source Issues: https://github.com/aharada54914/sdd-forge/issues/192,
https://github.com/aharada54914/sdd-forge/issues/187
Epic: https://github.com/aharada54914/sdd-forge/issues/187 (AI-DLC
Foundation tracking) — Epic A4 (Facet Manifest), issue #192, per
`docs/ai-dlc-foundation-decision-v2.md` §19.

## INV-001: Epic A4's normative scope is schema-first, resolver-later

`docs/ai-dlc-foundation-decision-v2.md` §19 Epic A4 (v2: "旧A5と順序入替"):
"実装: schema / context projection hash / registry_digest・ownership_digest
束縛 / affected component / required・conditional facet / N/A理由 / stale
detection / resolver version policy（Resolver 実装より先に出力の型を確定す
る）". Epic A5 (Capability Resolver, sequenced *after* A4) is the one that
actually builds the Resolver script and produces live instances of the
artifacts A4 only defines the shape of: "出力: Facet Manifest / Capability
Summary / Context Projection / Resolver Evidence". This investigation and
the requirements/design that follow treat "build the Resolver" as
out-of-scope (Non-goals) and "define the schema every future Resolver
output must conform to, including a schema-conformance validator" as
in-scope, matching the same schema-before-implementation split Epic A2 used
for the Capability Registry (`generate-registry-digest`, `evaluate-predicate`
exist without a Resolver caller yet).

## INV-002: No Facet Manifest, Capability Summary, or Context Projection artifact exists in this repository today

`find . -iname "*facet-manifest*" -o -iname "*capability-summary*" -o
-iname "*context-projection*"` (excluding `.git`) returns exactly one hit:
`docs/adr/0021-context-projection-staleness.md` itself — the ADR that
*names* these artifacts, not an instance of one. No
`contracts/facet-manifest.schema.json`,
`contracts/capability-summary.schema.json`, or
`contracts/context-projection.schema.json` exists. This confirms Epic A4 is
authoring these three schemas from a clean slate, constrained only by the
decision document, ADR-0020/ADR-0021, and the concrete field-level
commitments Epics A1/A2/A3 already made about how they will read or produce
fields on these artifacts (INV-006, INV-007, INV-009).

## INV-003: ADR-0021 already fixes the `context_binding`/`resolver` block and the "semantic output" definition verbatim

`docs/adr/0021-context-projection-staleness.md` (Status: Accepted) is not a
proposal this feature ratifies — it is a already-Accepted, three-pass
adversarially-reviewed decision this feature *transcribes into a schema and
a testable contract*. Item 2 defines **semantic output** precisely: "the
resolved required/conditional facets, their N/A reasons, the resolved gate
set (each gate's ID, `stage`, and `blocking` value), the effective minimum
enforcement applying to the Feature (the Registry-derived input to the
effective-enforcement computation, decision document v2 §10, Q9), the
capability set, and the lite eligibility determination — i.e. everything in
the Facet Manifest *except* the `context_binding` and `resolver` blocks,
which are binding/provenance metadata, not output." Item 2 also fixes two
non-obvious inclusions: a gate whose ID is unchanged but whose `stage` or
`blocking` changed IS a semantic-output change, and a minimum-enforcement
tightening IS a semantic-output change. Item 6 fixes the resolver-version
rule (patch/minor/major) verbatim (decision document v2 §18.2 cross-
reference). This feature's REQ-004/REQ-005 do not re-derive these rules;
they give them field names and a testable comparison contract.

## INV-004: ADR-0020 fixes the Predicate DSL, its evaluation semantics, and the Evidence shape Epic A2 already schematized

`docs/adr/0020-conditional-predicate-dsl.md` fixes: `all`/`any`/`not`
logical operators; `equals`/`not_equals`/`contains`/`in`/`exists`
comparison operators; the fail-closed-plus-WARN general rule and `exists`'s
documented exception; the closed 8-field allowlist sourced from the Project
Context schema; and Resolver purity ("the same input always produces the
same Facet Manifest", item 6). Epic A2's design.md (§ REQ-002, "Predicate
DSL evaluator contract") already builds the evaluator
(`evaluate-predicate.py`) and its Evidence JSON Schema:

```json
{
  "type": "object", "additionalProperties": false,
  "required": ["operator", "path", "outcome"],
  "properties": {
    "operator": {"enum": ["all","any","not","equals","not_equals","contains","in","exists"]},
    "path": {"type": ["string","null"]},
    "outcome": {"enum": ["match","no-match","warn"]},
    "reason": {"type": "string"},
    "children": {"type": "array", "items": {"$ref": "#"}}
  },
  "if": {"properties": {"outcome": {"const": "warn"}}},
  "then": {"required": ["operator","path","outcome","reason"]}
}
```

`conditional_facets[].when` reuses `capability-registry.schema.json`'s
`#/definitions/predicate` (ADR-0020 item 4, "no second condition
language"). Facet Manifest's own `conditional_facets[]` entries therefore
carry the *result* of evaluating this exact predicate/evidence shape, not a
new one — REQ-001 embeds Epic A2's Evidence JSON Schema by structural
reference rather than redefining it.

## INV-005: Epic A2's Registry schema is what Facet Manifest's `required_facets`/`conditional_facets`/`resolved_gates`/`capabilities` resolve *from*

`specs/epic-190-a2-capability-registry/design.md` (API / Contract Plan,
`contracts/capability-registry.schema.json`) fixes `capabilities[]` as
`required: ["id","trigger","required_facets","conditional_facets",
"review_check_ids","gate_ids","delivery_strategy"]` with `lite_policy`
and `minimum_enforcement` optional, and `gates[]` as `{id, stage
(enum: implementation/artifact/promotion), blocking (boolean),
implementation_ref (required iff stage=="implementation")}`. A Facet
Manifest is the *per-Feature projection* of this Registry: `capabilities[]`
whose `trigger` matched → their `required_facets`/`conditional_facets`
(evaluated) → their `gate_ids` (resolved into `gates[]` id/stage/blocking
triples) → the `max()` of their `minimum_enforcement` values. REQ-001's
field shapes are chosen so every field has a direct, named Registry-side
counterpart (Field Definitions, requirements.md) and no field invents
Registry vocabulary Epic A2 did not already fix (e.g., `stage`'s enum is
copy-consistent with `gates[].stage`, not a new enum).

## INV-006: Epic A3 already fixes the exact read contract for `facet-manifest.affected_components`, and treats it as a hard cross-epic dependency

`specs/epic-191-a3-path-ownership/requirements.md` states: "Epic A4 owns the
schema for `facet-manifest.affected_components`" (line ~198) and, in
Assumptions: "Epic A4's Facet Manifest will expose `affected_components` as
a **JSON/YAML-readable list keyed by component id**, consistent with every
other Facet Manifest field decision-document v2 §16 already shows
(`context_binding`, etc.) — the exact read path is deferred to Epic A4
landing." `check-component-coverage` (A3 REQ-004) takes `--facet-manifest
<path>` as a **structurally required** flag in the `advisory`/`required`
derived states (missing/unreadable path is a hard error, never a WARN); it
compares the real `git diff`-derived affected-component set against this
field for Fail-2 (an EXCLUSIVE owner missing from
`affected_components`) and Fail-4 (a bounded `shared_paths` entry's
declared components missing from `affected_components`). This fixes
REQ-001's `affected_components` as a flat array of component-id strings
(matching decision document v2 §12's own diagram: "affected component →
facet-manifest.affected_components") — not a nested object, not a list of
`{id, reason}` pairs — since A3 already committed to reading it as a plain
id list and A4 must not retroactively break that contract.

## INV-007: Epic A1 already reserved the Resolver script name and the Context Projection artifact path, as a forced handoff gate

`specs/epic-189-a1-project-context/requirements.md` (REQ-007) reserves,
under the "Resolver (reserved, 3) and generated projection (reserved, 1)"
protected-file category: `plugins/sdd-quality-loop/scripts/
resolve-project-context.{py,sh,ps1}` (resolver) and
`plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json`
(generated projection), already added to `guard-invariants.json`'s
`protected_gate_suffixes` even though neither file exists on disk yet
(design.md's Design Decisions table, M14: "resolver/generated-projection
protection categories reserved, not silently absent"). The reservation text
is explicit: "the epic that actually introduces the Capability Resolver or
its generated projection (A2/A5) MUST use these exact reserved names, or
amend this reservation via its own spec's explicit `guard-invariants` diff;
it may not introduce a parallel, differently-named, unprotected
resolver/projection file." Epic A2 already built its *own*, differently-
named, differently-scoped projection (`generate-gate-capabilities.py` →
`plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json`, a
Registry-wide projection, unrelated to Project Context) — so A1's
reservation is not yet consumed by any landed epic. Its singular,
placeholder-free path (no `<feature>` segment) means it names exactly one
repository-wide artifact, not a per-Feature one: this is the **Context
Projection** decision document v2 §19 Epic A5 lists as a distinct output
from the Facet Manifest. REQ-003 therefore defines this artifact's schema
under the exact reserved path/name Epic A1 already fixed, and explicitly
defers *building* `resolve-project-context.{py,sh,ps1}` to Epic A5 — A4
only fixes what that future script must emit.

## INV-008: Epic A1's canonicalizer is a stdin/stdout CLI over YAML **or** JSON input, already reused twice inside Epic A1 itself for non-file preimages

`specs/epic-189-a1-project-context/design.md` ("Canonicalization procedure",
REQ-003): `canonicalize-sdd-yaml.py` parses YAML 1.2 core schema (or JSON —
"REQ-003's canonicalizer accepts either" per the HMAC preimage section)
single-document input, rejects anchors/aliases/non-core tags/duplicate
keys/non-string keys/post-NFC duplicate keys/non-finite or out-of-range
numbers, NFC-normalizes every string scalar, and emits RFC 8785 (JCS)
canonical JSON bytes to stdout, or `sha256:<hex>\n` in `--hash-only` mode.
Every rejection is a stable, category-specific non-zero exit with a named
diagnostic on stderr only. `.sh`/`.ps1`/`.js` wrappers exec the same
`.py` master unchanged; if no Python interpreter is found, **all three**
wrappers fail closed with `CANONICALIZER_RUNTIME_UNAVAILABLE` (exit 3) —
there is no independent PowerShell reimplementation, unlike
`sdd-hook-guard.sh`. Critically, Epic A1's own HMAC preimage construction
(REQ-004) already establishes the precedent this feature's REQ-003 relies
on: it feeds an **in-memory JSON object** (not a file, not YAML) back
through `canonicalize-sdd-yaml` a second time ("Preimage = ...applied to
the approval JSON object..., JSON, not YAML, input mode") to get a
byte-exact canonical form of a *derived* structure, rather than
hand-rolling a second serializer. REQ-003 reuses this exact two-pass
pattern for Context Projection (canonicalize the raw YAML once, transform
the parsed structure, canonicalize the transformed JSON a second time).

## INV-009: Epic A1's Project Context schema fixes the exact top-level keys, the `components[]`/`shared_paths[]` shapes, and `id`-uniqueness enforcement location

`specs/epic-189-a1-project-context/design.md`
(`contracts/project-context.schema.json`) fixes the document's top level as
`{schema, workflow, components?, shared_paths?}` — `schema` and `workflow`
required, `components`/`shared_paths` optional arrays. `workflow` is
`{spec_profile, artifact_layout, capability_enforcement}` (ADR-0016).
`components[]` items carry `id` (required) plus optional
`artifact_kinds`/`runtime_classes`/`platform_targets`/`characteristics.*`/
`distribution_channels`/`data_classification`/`provider_binding_ids`/
`paths.{include,exclude}`. `shared_paths[]` items carry `pattern` plus
either `components` (bounded) or `classification: cross-cutting`
(unbounded). **`components[].id` uniqueness is enforced by Epic A1's own
content-schema validator (`validate-approval-sidecar.py`/
`generate-approval-sidecar.py`, `DUPLICATE_COMPONENT_ID`, M18), not by the
JSON Schema** (draft-07 cannot express array-items key-uniqueness). This
matters directly to REQ-003: Context Projection re-keys `components[]` into
an object keyed by `id`; that re-keying is sound (never silently drops or
overwrites a component) only because Epic A1 already guarantees `id`
uniqueness upstream, at content-validation time, before the Context
Projection generator (Epic A5) ever runs.

## INV-010: Decision document §6 fixes the Lite Capability Summary's exact field set; a full-track Capability Summary's fields are undecided anywhere and out of this feature's scope (revised per adversarial review, "M full Summary")

`docs/ai-dlc-foundation-decision-v2.md` §6 (Q5) fixes: "liteでは個別Facet
ファイルを生成せず `specs/<feature>/capability-summary.yaml` だけを生成す
る" with the literal example `capabilities: [...]`, `required_lite_checks:
[...]`, `full_upgrade_required: false`. It also fixes the combination
matrix (lite/full × spec_profile/artifact_layout/enforcement →
verdict) and the per-Capability `lite_policy: {eligible, upgrade_reasons}`
Registry field. §19 Epic A5's own output list ("Facet Manifest / Capability
Summary / Context Projection / Resolver Evidence") names Capability Summary
as a distinct Epic A5 output, but neither §6 nor §19 specifies a *separate*
full-track shape, and no sibling epic's spec names a concrete consumer for
one. An earlier revision of this spec resolved that silence by inventing a
`track`-discriminated schema with a full-track `facet_manifest_ref`
compressed view — adversarial review (finding "M full Summary") correctly
identified this as inventing an output-type decision beyond REQ-002's
schema-fixing scope, unsupported by anything §6 or §19 actually specifies.
REQ-002 now fixes **only** the Lite Capability Summary shape §6 already
gives verbatim (`schema`, `feature`, `track: "lite"` — a single-valued,
constant discriminator retained for forward-compatible parsing, not for any
branching schema logic — `capabilities`, `required_lite_checks`,
`full_upgrade_required`). Whether a full-track Capability Summary is needed
at all, and if so what it contains, is deferred to a future ADR (Non-goals,
requirements.md) — this investigation's own evidence (no named consumer, no
decision-document shape) is exactly why that deferral, not a spec-phase
invention, is the correct resolution.

## INV-011: §18.2/ADR-0021 item 6 fix the resolver-version rule as a closed three-way switch

`docs/ai-dlc-foundation-decision-v2.md` §18.2: "patch → 出力変更なしなら再
生成不要 / minor → 影響判定を実行し、semantic output（§16 定義）が変われば
stale / major → 再resolve必須." `docs/adr/0021-context-projection-
staleness.md` item 6 restates this with the same three tiers, adding that a
**major** bump forces re-resolve for *every* Feature that used the affected
Resolver version "regardless of whether the semantic output would change"
— major bumps skip the semantic-output comparison entirely, they do not
merely make it more likely to fire. This is the one case in the whole
staleness contract where a Feature is marked stale without ever comparing
semantic output.

## INV-012: Only 3 of ADR-0019's 9 named Policy-Weakening categories are actually detected by any landed epic; the other 6 are reserved

`docs/adr/0019-approval-sidecar-protection.md` item 6 *names* nine
weakening categories: "weakening enforcement, removing a Capability,
narrowing a component path, de-scoping public distribution, lowering
criticality, widening a provider allowlist, changing a production write
path, removing a required Gate, or moving `full` to `lite`."
`specs/epic-189-a1-project-context/design.md`
(`contracts/approval-sidecar.schema.json`,
`weakening_verdict.categories`) implements only three as live
`enum: ["weakened","not_weakened"]` fields:
`capability_enforcement_weakened`, `component_path_narrowed`,
`spec_profile_full_to_lite`. The other six —
`capability_removed`, `public_distribution_descoped`,
`criticality_lowered`, `provider_allowlist_widened`,
`production_write_path_changed`, `required_gate_removed` — are each
`const: "n/a"`: structurally reserved, not evaluated, by design (Epic A1's
own scope boundary, not an oversight this feature can silently assume away).
Epic A2's capability-registry spec introduces no weakening detector of its
own (no `weakening` hit anywhere in
`specs/epic-190-a2-capability-registry/requirements.md`), and Epic A3
likewise defines no Registry- or ownership-scoped weakening detector. **As
of this investigation, "Policy Weakening" detection exists only for the
Project-Context/Provider-Bindings axis** (the three live categories above),
never for a Registry edit (e.g., a Capability's `minimum_enforcement`
loosened, or a Gate's `blocking` flipped false) or an ownership edit (e.g.,
an owner removed for a path). This is a load-bearing fact for REQ-004: a
literal reading of decision document v2 §16's "Policy Weakening → 全影響
FeatureをBlock" bullet, applied uniformly across all three axes
(Context/Registry/ownership), would describe a mechanism that does not
exist for two of the three axes in any epic's current build scope.

## INV-013: guard-invariants protection is selective — a generated *projection* and its source are protected; a general-purpose *validator* utility is not

Epic A2's own protected-file registration (REQ-005, requirements.md line
~367) protects exactly three things: the generated projection file
(`gate-capabilities.json`), its generator script
(`generate-gate-capabilities.{py,sh,ps1}`), and its source contract files
(`contracts/capability-registry.{json,schema.json}`) — "must all be
registered as protected files." REQ-002 (`evaluate-predicate`), REQ-003
(`validate-capability-registry`), and REQ-004 (`generate-registry-digest`)
carry **no** protected-file registration anywhere in that spec — they are
general-purpose deterministic utilities, not part of the causal chain
feeding a Gate's live enforcement data. This is the governing precedent for
this feature's own Protected-File Statement (design.md): REQ-006's three
new validator scripts (`validate-facet-manifest`,
`validate-capability-summary`, `validate-context-projection`) are
structurally identical in role to `validate-capability-registry` (schema/
structural conformance checking, not a Gate-consumed generated
projection) — Facet Manifest and Capability Summary instances are
per-Feature files under `specs/<feature>/`, analogous in protection status
to `tasks.md` (agent-writable, unprotected, reviewed per Feature), not to a
repository-wide generated projection. The one artifact this feature's REQ-
003 touches that *is* already protection-scoped is Context Projection
(`project-context.resolved.json`) — but that protection was already
registered by Epic A1 (INV-007); this feature adds no new guard-invariants
entry for it.

## INV-014: `contracts/` conventions — `$id` format and stdlib-only Python

Every existing `contracts/*.schema.json` in this repository uses `"$schema":
"http://json-schema.org/draft-07/schema#"` and `"$id":
"https://github.com/aharada54914/sdd-forge/contracts/<filename>"`
(`contracts/workflow-state-registry.schema.json` is the reference
instance). `grep -rln "import jsonschema" plugins/ scripts/` and a search
for `requirements.txt`/`pyproject.toml` both return nothing anywhere in
this repository: every existing Python script
(`generate-guard-invariants.py`, `check-contract.py`, etc.) imports only
stdlib modules (`argparse`, `hashlib`, `json`, `os`, `sys`, `pathlib`,
`typing`). REQ-006's three validator scripts must therefore hand-roll
JSON-Schema-shaped structural validation in pure Python, exactly like
`validate-capability-registry.py` does, not depend on a third-party
`jsonschema` package.

## INV-015: `check-workflow-state.sh`'s spec-phase validation requires only three files, and independently confirms the "no tasks.md yet" instruction

`plugins/sdd-quality-loop/scripts/check-workflow-state.sh` (lines ~657-715)
requires only `requirements.md`, `design.md`, `acceptance-tests.md` to
exist for a non-legacy, non-lite (`full`) registry entry; `tasks.md`/
`traceability.md` are not checked when absent. `Spec-Review-Status`
(`requirements.md`) and `Impl-Review-Status` (`design.md`) must each be
exactly `Pending` or `Passed` — `Passed` is unreachable without running
`spec-review-loop`/`impl-review-loop`, so this feature's headers carry
`Pending`. Line ~681-682 is a sharp trap this investigation confirms
independently of Epic A3's own identical finding (its INV-012): **if
`tasks.md` exists at all**, the script requires `Spec-Review-Status` AND
`Impl-Review-Status` to already both be `Passed`, regardless of
`tasks.md`'s own internal state — committing a `tasks.md` alongside
`Pending` headers is an unconditional `check-workflow-state.sh` failure.
This independently confirms the task instruction ("tasks.md /
traceability.md は作らない") is not just a scope-discipline preference —
it is the only registry-valid state for a spec package whose reviews have
not yet run.

## INV-016: `check-sdd-structure.sh` only demands the four layer-spec files in `--feature` mode; the registration verification command must omit the feature argument

`scripts/check-sdd-structure.sh` only enters its per-feature
`required_file specs/$feature/$name` loop (which includes `ux-spec.md`,
`frontend-spec.md`, `infra-spec.md`, `security-spec.md`, `tasks.md`,
`traceability.md`) when invoked with a second, `feature`, argument (`if
[ "$#" -ge 2 ]`). Invoked with a project-root argument alone (`sh
scripts/check-sdd-structure.sh .`), it only checks repository-root
directories (`AGENTS.md`, `specs/`, `reports/implementation/`,
`reports/quality-gate/`, `docs/adr/`, `docs/review-tickets/`) — none of
which this feature's registration commit touches in a way that would fail
this check. `docs/skill-reference.md`'s own documented usage line
(`sh plugins/sdd-bootstrap/scripts/check-sdd-structure.sh [project-root]`)
omits the feature argument entirely, confirming the no-feature invocation
is the standard, documented usage, not an ad hoc workaround. This feature's
registration commit therefore runs `check-sdd-structure.sh` without a
feature argument and does not author `ux-spec.md`/`frontend-spec.md`/
`infra-spec.md`/`security-spec.md` at this phase — matching Epic A2's own
precedent, where those four files were added later, at impl-review-prep
time, not as part of the spec-phase commit (confirmed by this worktree's
own file timestamps: `specs/epic-190-a2-capability-registry/{ux,frontend,
infra,security}-spec.md` are dated hours after that spec's own
`Spec-Review-Status: Passed` commit).

## INV-017: `workflow-state-registry.json`'s `full`-profile entry shape is exactly two keys

`contracts/workflow-state-registry.schema.json` requires, for any entry
with `profile == "full"` or `"lite"`: `(keys | sort) ==
["feature","profile"]` — no `legacy` sub-object, no additional metadata.
Twelve existing entries (`local-env-mcp`, `epic-159-pillar-c`, etc.) confirm
this shape in practice: `{"feature": "<slug>", "profile": "full"}`. This
feature's registration entry is
`{"feature": "epic-192-a4-facet-manifest", "profile": "full"}`, appended to
the existing `entries` array (alphabetical-adjacent placement not enforced
by the schema; existing entries are not alphabetically sorted either, e.g.
`agent-cost-context-isolation` precedes `bootstrap-interviewer-enhancement`
but `epic-159-pillar-a` precedes `sdd-domain` later in the file — insertion
order is append-only in practice, so this feature's entry is appended at
the end of `entries`, matching the file's own historical pattern).

## INV-018: Epic A2's script-relative discovery + vendored-copy contract is a reusable, already-fixed pattern this feature's own new schemas should follow, not reinvent

`specs/epic-190-a2-capability-registry/design.md` ("Registry discovery
contract", REQ-005) fixes a discovery algorithm any `plugins/sdd-quality-
loop/scripts/*.py` script needing a `contracts/*` artifact should use: (1)
resolve the invoking script's own symlink-resolved real path, look for a
packaged copy at the fixed script-relative offset
`../contracts/<filename>`; (2) else resolve the repository root via `git
rev-parse --show-toplevel` (or a `.git`-directory walk) and use
`<git-root>/contracts/<filename>`; (3) fail closed with a diagnostic naming
both attempted paths if neither resolves or the version check fails. Each
artifact's version check is a distinct, artifact-specific top-level key
(`schema == "<artifact>/vN"`, or `$schema`+`$id` for a JSON Schema
document itself) — never one shared rule. A release-gating `--check` mode
compares each canonical `contracts/<filename>`'s sha256 against its
vendored `plugins/sdd-quality-loop/contracts/<filename>` counterpart.
REQ-006 reuses this exact discovery/version-check/vendoring contract for
`contracts/facet-manifest.schema.json`,
`contracts/capability-summary.schema.json`, and
`contracts/context-projection.schema.json`, rather than re-deriving a
second discovery algorithm — this keeps `plugins/sdd-quality-loop/scripts/`
internally consistent for whichever epic (A2, now A4) adds a new schema
artifact requiring 3-runtime, installed-plugin-context discovery.

## INV-019: Epic A2's `registry_digest` primitive supports `--whole`, and Epic A3's `ownership_digest` already establishes the "no sound fragment" precedent this feature's own binding choice follows

`specs/epic-190-a2-capability-registry/requirements.md` REQ-004: the
`registry_digest` generation script "accepts an explicit `--capability-ids`
list, an explicit `--gate-ids` list, or both (at least one required, or
`--whole` for the entire Registry) as its fragment-selection input,"
explicitly leaving "the fragment selection itself" as "Epic A5's Resolver
concern, not Epic A2's." This feature (Epic A4), not Epic A5, is the one
that fixes what a Facet Manifest's `context_binding.registry_digest`
*binds to* — REQ-004 must therefore pick a fragment-selection policy,
because leaving it to each future Resolver implementation would let
`registry_digest` diverge across implementations for the identical Registry
state. `specs/epic-191-a3-path-ownership/requirements.md` REQ-005 already
faced the structurally identical question for `ownership_digest` and
resolved it as **full-input binding**, with an explicit soundness argument:
"deciding EXCLUSIVE requires checking every other component's residual
match too... so no proper subset of the ownership input can be soundly
labeled 'unconsumed' by a given resolve — a selective, evaluated-subset
binding is not a scoping refinement, it is unsound" (line ~543-546). The
identical argument applies to `registry_digest`: a Capability's `trigger`
match/no-match outcome is a function of the current Context Projection, and
a Registry edit to a Capability's `trigger` that does not currently match
could start matching (or vice versa) on the very next resolve without any
other input changing — so no proper subset of "the capabilities whose
trigger currently matches" can be soundly treated as "not consumed" by a
given resolve; the Resolver necessarily evaluates every Capability's
`trigger` to determine the matching set in the first place. This feature's
REQ-004 therefore binds `registry_digest` via `generate-registry-digest
--whole`, by the same soundness reasoning A3 already established for
`ownership_digest`, not a `--capability-ids`/`--gate-ids` fragment of only
the currently-matched set.

## OQ-001 (retired, folded into Non-goals): whether, and in what shape, a full-track Capability Summary exists at all

Decision document v2 §19 lists Capability Summary as a distinct Epic A5
output, but no epic's spec (A1/A2/A3, this one included) names a concrete
*consumer* that would read a full-track Capability Summary instead of the
Facet Manifest it would be derived from, and neither §6 nor §19 specifies
what such an artifact would contain. An earlier revision of this spec
treated this as a narrow "which consumer" open question and answered the
larger "what shape" question itself by inventing a `facet_manifest_ref`
compressed view — adversarial review ("M full Summary") found that
resolution out of REQ-002's own scope (schema-fixing for an already-decided
artifact, not deciding whether a second artifact should exist). This is no
longer an open question this spec carries forward: REQ-002 now fixes only
the Lite Capability Summary (INV-010), and whether a full-track counterpart
is needed, by whom, and in what shape is recorded as a Non-goal — a future
epic's own spec, not this feature's Open Question to resolve later.

## OQ-002: Context Projection regeneration cadence

REQ-003 fixes Context Projection's *schema* and the canonicalization
procedure that must produce it, but not *when* `resolve-project-context`
(Epic A5) re-runs it (on every commit touching `project-context.yaml`/
`provider-bindings.yaml`, via a CI hook mirroring
`generate-gate-capabilities.py --check`'s drift gate, or only on-demand
when a Feature resolve requests a fresh `projection_sha256`). This is an
Epic A5 CI-wiring decision, not a schema decision, and is left open here.

## Summary of Evidence References

- `docs/ai-dlc-foundation-decision-v2.md` §6, §10, §11, §12, §16, §18.2,
  §19.
- `docs/adr/0019-approval-sidecar-protection.md`,
  `docs/adr/0020-conditional-predicate-dsl.md`,
  `docs/adr/0021-context-projection-staleness.md`.
- `specs/epic-189-a1-project-context/{requirements,design}.md` (REQ-001,
  REQ-003, REQ-004, REQ-006, REQ-007).
- `specs/epic-190-a2-capability-registry/{requirements,design}.md`
  (REQ-001..REQ-005).
- `specs/epic-191-a3-path-ownership/requirements.md` (Dependencies,
  Assumptions, REQ-004, Field Definitions).
- `plugins/sdd-quality-loop/scripts/check-workflow-state.sh`,
  `scripts/check-sdd-structure.sh`,
  `contracts/workflow-state-registry.schema.json`.
- `plugins/sdd-quality-loop/references/guard-invariants.json`,
  `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`.
