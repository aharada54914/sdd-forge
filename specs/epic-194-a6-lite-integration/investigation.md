# Investigation: epic-194-a6-lite-integration

Source: Issue #194 (Epic A6 — Lite統合), tracked under epic #187 (AI-DLC
Foundation) / `docs/ai-dlc-foundation-decision-v2.md` §6 (Q5: liteトラック
との関係) and §19 (Epic A6) / ADR-0022 (Lite Capability Upgrade), ADR-0016
(Workflow Axes Separation), ADR-0017 (Gate Stage Model). Snapshot commit
for every direct-repository-read finding below:
`b085ec761ca75c0231384b3861aac7f2403474ed` (this worktree's `HEAD` at
investigation time, `feature/epic-194-a6-lite-integration`, branched from
Epic A0's own tip).

## INV-001: Epic A6's normative scope is "connect and extend already-decided mechanisms," not a fresh architectural decision

Decision document v2 §19 lists Epic A6's deliverables literally:
"Capability-aware risk-upgrade / lite eligibility / capability-summary.yaml
/ lite gate checks / full upgrade / artifact生成前Block / 保護ファイル
（lite-spec SKILL / risk-upgrade-policy）変更のhuman-copy工程." Every one of
these six items names an existing mechanism (the risk-upgrade gate, the
lite-eligibility field, the Capability Summary artifact, `lite-gate`'s
check list, the full-upgrade escalation, the human-copy flow) that this
feature wires together or extends — none of the six is "design a new
subsystem." ADR-0022's own Context section states the same constraint from
the opposite direction: "Extending Capability enforcement... to the lite
track must preserve that design's lightness rather than forcing every lite
project through the full Capability pipeline." This investigation and the
sibling `requirements.md`/`design.md` therefore treat every REQ as a
connection or an additive extension of a already-fixed contract, citing the
owning sibling epic's own spec text wherever one exists, per this task's
own instruction not to add independent design judgment beyond the正本.

## INV-002: Sibling epics' review status, confirmed directly against each worktree

| Epic | Worktree | `Spec-Review-Status` (`requirements.md`) |
|---|---|---|
| A2 (Capability Registry) | `sdd-forge-wt-epic-190` | `Passed` |
| A3 (Component Path Ownership) | `sdd-forge-wt-epic-191` | `Passed` |
| A4 (Facet Manifest) | `sdd-forge-wt-epic-192` | `Passed` |
| A5 (Capability Resolver) | `sdd-forge-wt-epic-193` | `Pending` |

(`grep -n "Spec-Review-Status" specs/epic-19{0,1,2,3}-*/requirements.md` in
each sibling worktree, investigation time.) A2's, A3's, and A4's schemas are
therefore content-frozen per this repository's own `AGENTS.md` "Post-review
artifact freeze" convention; A5 is not yet frozen and could still change
before its own spec review completes. This package treats A2/A3/A4's
already-`Passed` contracts as hard, unmodifiable-by-this-feature
dependencies (matching the pattern A5's own `requirements.md` Dependencies
section already applies to the same four contracts), and treats A5's
current text as the best available statement of the Resolver's own
contract while flagging, wherever load-bearing, that A5's own package could
still move under it (Risks, below; this is the same caveat A5's own
Dependencies section applies to its A2 prerequisite in reverse).

## INV-003: The Registry's `capabilities[]` schema (A2, content-frozen) fixes `lite_policy`'s exact current shape, both at the object level and at its own two-key `additionalProperties: false` boundary

`specs/epic-190-a2-capability-registry/design.md:359-389` (API / Contract
Plan) fixes the complete `capabilities[]` item field set — `id`, `trigger`,
`required_facets`, `conditional_facets`, `review_check_ids`, `gate_ids`,
`lite_policy`, `minimum_enforcement`, `delivery_strategy` —
`additionalProperties: false` at the item level, with `required: ["id",
"trigger", "required_facets", "conditional_facets", "review_check_ids",
"gate_ids", "delivery_strategy"]` (`lite_policy` and `minimum_enforcement`
are the only two genuinely optional fields). `lite_policy` itself, when
present, is fixed to exactly `{eligible: boolean (required), upgrade_
reasons: array of non-empty strings (optional, default [])}`, also
`additionalProperties: false` (`design.md:385-389`). This means a v1.1
extension that adds a third key to `lite_policy` requires editing two
distinct `additionalProperties: false` boundaries in
`contracts/capability-registry.schema.json`: the `lite_policy` sub-schema
itself (to admit the new key) — the top-level `capabilities[]` item schema
does not need to change, since `lite_policy` itself stays optional and
its own internal shape is what widens. No `contracts/capability-registry.
schema.json`/`contracts/capability-registry.json` file exists anywhere in
this repository yet (`find . -iname "*capability-registry*"` in this
worktree returns nothing) — A2 is itself still Phase 1 (schema fixed in
`design.md` prose/JSON-Schema fragments only, not yet an authored
`contracts/*.schema.json` file). This feature's own REQ-001 is therefore
scoped identically to A2's own REQ-001: a documented schema *design*, not
an edit to a file that does not exist yet.

## INV-004: A5's own `requirements.md` Dependencies section already names the Registry gap this feature must close, with an explicit owner and scope

`specs/epic-193-a5-capability-resolver/requirements.md:119-152` (Dependencies,
Epic A2 sub-bullet) states, verbatim in relevant part: "Epic A2's own
Registry schema (content-frozen, `Spec-Review-Status: Passed`) carries no
field `required_lite_checks` (decision document v2 §6) can be sourced from
(investigation.md INV-019) — a **future Epic A2 Registry-schema revision**
(owner: Epic A2's own maintainers, not this feature; scope: a new,
additively-versioned `capabilities[]` field the current schema's
`additionalProperties: false` does not yet admit; migration: existing
Registry instances remain valid until a Capability author opts into the new
field) is a **named prerequisite for Epic A6 (Lite統合) to begin**." A5's
own `investigation.md:515-545` (INV-019) and `design.md:942-964`/`:2338-
2354` restate the same gap and name the consequence for A5's own build
today: A5's Lite-track resolve path Blocks with `lite-check-source-
undefined` for essentially every real Lite Feature with at least one
matched Capability, until this field exists (A5 `design.md:1729-1748`,
citing a fixture that can only reach a non-Blocked Lite resolve via the
zero-matched-Capability edge case). This is the single most load-bearing
finding for this feature's own REQ-001 scope: A6, not A2, owns the new
field (A5's own text says so explicitly, and this task's own instructions
say the same), and A5's own text is written expecting the new field's
*aggregated* form to be reachable under the literal name
`required_lite_checks` (A5 `design.md:947`: "`required_lite_checks` — for
each matched Capability, attempt to source its own contribution").

## INV-005: A4's `capability-summary.schema.json` (content-frozen) fixes the exact Lite Capability Summary shape this feature's `lite-gate` extension consumes; this feature must not alter it

`specs/epic-192-a4-facet-manifest/requirements.md:278-294` (REQ-002) fixes
`contracts/capability-summary.schema.json` to exactly: `schema` (`const:
"sdd-capability-summary/v1"`), `feature` (slug pattern), `track` (`const:
"lite"`), `capabilities` (array of unique strings, required),
`required_lite_checks` (array of unique strings, required),
`full_upgrade_required` (boolean, required); `additionalProperties: false`
at the top level, and explicitly "no `facet_manifest_ref` or other
full-track-only field exists in this schema at all" (A4 ships no
`track: "full"` shape). This is the only artifact A6's own `lite-gate`
extension (REQ-003/REQ-004) reads — this feature adds no field to it, no
alternate shape, and no Full-track analogue (A4's own Non-goals already
reserve that question for a future ADR). The same package's `requirements.
md:244-277` (REQ-001) also fixes the Facet Manifest's `lite_eligibility`
aggregate field (`{eligible (boolean, required), upgrade_reasons (array,
required, always present, `[]` when none)}`, "matching the per-Capability
`lite_policy` shape but representing the Feature-level aggregate") — this
is the field A5's Resolver populates on the *Full* track only (never
written alongside a Capability Summary, A4/A5's own track-exclusive-output
contract, A5 `design.md` B4). Neither `capability-summary.schema.json` nor
`facet-manifest.schema.json` exists as an authored file anywhere in this
repository yet (`find . -iname "*capability-summary*" -o -iname
"*facet-manifest*"` under `contracts/` in every readable worktree returns
nothing) — same Phase-1-everywhere state as INV-003.

## INV-006: A5's own aggregation reasoning for `lite_eligibility`/Capability-Summary fields is union-match across matched Capabilities, not a rule this feature invents

A5 `design.md:1875-1893` (Design Decisions) states the governing reasoning
directly: "if a Feature touches a component with `characteristics.pii:
true`, the PII-driven Capability must apply to that Feature even if a
second, also-affected component has no PII... The rejected alternative —
conjunctive matching (*every* affected component must satisfy the
predicate) — is inconsistent with `lite_policy.upgrade_reasons`' own
existing semantics (decision document v2 §6: a single PII-handling
component forces the whole Feature to `full`, regardless of whether every
other touched component also handles PII)." Applied to this feature's own
new `required_lite_checks` field (INV-004): the same union-match reasoning
implies the Feature-level `required_lite_checks` (A4's own field,
Capability Summary) is the set union of every *matched* Capability's own
per-Capability `required_lite_checks` contribution — this feature does not
redefine that aggregation rule (it is A5's own Resolver-side computation,
out of this feature's build scope, REQ-003 below), it only confirms the
per-Capability field's own shape and name are consistent with the
aggregate A4 already fixed and A5 already expects to populate that way.

## INV-007: `contracts/lite-upgrade-reason-catalog.json`'s starting vocabulary is A2's; its own growth to ADR-0022's full forced-upgrade list is explicitly handed to Epic A6

A2 `design.md:125-139` defines the catalog's illustrative starting content
(`{"schema": "lite-upgrade-reason-catalog/v1", "catalog_version": 1,
"reasons": ["public_distribution", "production_cloud_runtime",
"durable_workflow", "external_identity", "pii"]}` — ADR-0022's own YAML
example's five tokens) and states, verbatim: "the broader eleven-category
prose list, ADR-0022's own item 4, is Epic A6's decision about what to
*add* to this catalog, not this spec's. The catalog is additive/versioned:
a new `catalog_version` may add reasons without changing
`capability-registry.schema.json`." (A2's own citation names ADR-0022
"item 4"; a direct re-read of `docs/adr/0022-lite-capability-upgrade.md`
finds the eleven-category forced-upgrade prose — "cloud production, a
Durable Workflow, a public package registry, Store distribution,
auto-update, Stable distribution involving code signing, external
authentication, PII, payments, multiple tenants, or a high-risk
migration" — inside the ADR's own numbered item **2** ("Per-Capability lite
eligibility"), not item 4 ("`lite-gate` stays lightweight"); this
investigation records A2's exact citation text without silently correcting
it, and treats the *content* identification — the eleven-category
forced-upgrade list is what A6 must fold into the catalog — as the
controlling fact, independent of which item number names it). This is a
second, distinct sub-task inside this feature's own REQ-001, alongside the
new `required_lite_checks` field (INV-004): growing
`lite-upgrade-reason-catalog.json`'s own `reasons` vocabulary via a
`catalog_version` bump, with **no** `capability-registry.schema.json`
change required for that half of REQ-001 (the catalog's own additive-
versioning mechanism, already fixed by A2, is exactly what makes this a
data change, not a schema change).

## INV-008: `guard-invariants.json`'s actual protected-file list names four `sdd-lite`-owned files, not five — `lite-gate/SKILL.md` is not currently among them

`grep -n "sdd-lite" plugins/sdd-quality-loop/references/guard-invariants.
json` (this worktree, investigation time) returns exactly these four
`sdd-lite`-owned paths, present in **both** `protected_gate_suffixes` and
`phase2_human_copy_targets`:

```
plugins/sdd-lite/references/risk-upgrade-policy.md
plugins/sdd-lite/scripts/check-risk-upgrade.sh
plugins/sdd-lite/scripts/check-risk-upgrade.ps1
plugins/sdd-lite/skills/lite-spec/SKILL.md
```

`plugins/sdd-lite/skills/lite-gate/SKILL.md` does **not** appear in either
array. This matches ADR-0022 item 5's own text exactly ("`lite-spec`'s
`SKILL.md`, `risk-upgrade-policy.md`, and `check-risk-upgrade.*` are
already protected files... as of epic-136 Phase 2") and decision document
v2 §6's identical v2-addition note — neither names `lite-gate/SKILL.md`.
This feature's own task framing (orchestrator instructions) describes
"lite-gate/SKILL.md" as one of "すべて保護ファイル" alongside the other
four; that characterization is broader than what either the正本 (ADR-0022,
decision v2 §6) or the live `guard-invariants.json` actually states. This
investigation records the discrepancy as a fact rather than silently
resolving it either way — see OQ-001, below, and Risks.

## INV-009: `check-risk-upgrade.{sh,ps1}`'s exact current I/O contract is the surface this feature's REQ-002 extends — a single positional path argument, three exit codes, no capability-aware input today

Direct read of `plugins/sdd-lite/scripts/check-risk-upgrade.sh` and `.ps1`
(this worktree, investigation time) confirms both scripts: accept exactly
one positional argument (a path to a local UTF-8 source file); print
`lite-eligible` and exit `0` on no keyword match; print `full-required:
<primary-id>; triggers=<ordered-ids>` and exit `10` on a match; print
`risk-upgrade: input unavailable` and exit `2` on a missing/unreadable/
NUL-containing/malformed-UTF-8 input or wrong argument count. The matching
logic itself is a fixed, six-row ordered keyword table (`AUTH_BOUNDARY`,
`TOKEN_CREDENTIAL`, `MCP`, `EXTERNAL_API`, `SECRET`, `GITHUB_ACTIONS`,
`plugins/sdd-lite/references/risk-upgrade-policy.md:26-38`) with no
parameter, environment variable, or second input path for any
externally-supplied trigger list. Any Capability-aware extension therefore
needs either (a) a new, additional input this exact script accepts (a
second, optional argument) whose *tokens* it merges into its own trigger-
reporting output without re-deriving them, or (b) a second, independent
invocation this feature composes with the first at the calling skill's own
level. Both keep the six-row keyword table itself untouched (ADR-0022's own
"must not duplicate upgrade logic" instruction — Non-goals, below, records
which of the two this feature's own design chooses and why).

## INV-010: The two existing invocation points of `check-risk-upgrade` are already fixed, both documented, and neither currently has a capability-aware step

`plugins/sdd-lite/references/risk-upgrade-policy.md:40-51` ("Workflow use")
names both invocation points verbatim: `lite-spec` passes "the complete
user-supplied source body" to the checker "before creating any lite
artifact"; `ship` passes "the selected complete `## T-NNN` block followed
by that feature's `requirements.md`... whenever lite could otherwise be
selected." `plugins/sdd-lite/skills/lite-spec/SKILL.md:31-52` ("Risk-Upgrade
Gate") fixes the first of these as running "Before beginning the Process or
creating any file under `specs/<feature>/`" — i.e. before any `requirements.
md`/`design.md`/`tasks.md` exists for the Feature, and necessarily before
Epic A3's `resolve-component-paths`/Epic A5's Resolver has anything
Feature-specific to diff (no code change has been scoped yet at this point
in the flow — Risks, below, and requirements.md Open Questions record the
consequence this has for REQ-002/REQ-005's exact wiring). `plugins/
sdd-lite/skills/lite-gate/SKILL.md`'s own five-step Process (`SKILL.md:32-
40`) runs later, after `implement-task`, and is the target of this
feature's own REQ-003/REQ-004 (Capability Summary consumption, Registry-
sourced check execution) — its own Preconditions/Boundaries sections name
no Capability-related step today.

## INV-011: This package's own registration-time verification commands, run against the live worktree, both pass today (pre-registration baseline)

```
$ bash scripts/check-sdd-structure.sh .
advisory: CLAUDE.md
advisory: docs/architecture
host: github
check-sdd-structure: OK

$ bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh
workflow-state: ok
```

(Both run from this worktree's repository root, investigation time, no
argument beyond the documented no-feature-argument invocation — matching
A4's own INV-016 and A5's own INV-014/INV-015 precedent for what a Phase-1
registration commit's own "green" check consists of: `check-sdd-structure.
sh`'s per-feature 9-file loop only activates when a second, feature-name
argument is supplied, which this feature's own registration commit does
not use, matching A5 `investigation.md:434-448`'s identical finding;
`check-workflow-state.sh` requires only `requirements.md`/`design.md`/
`acceptance-tests.md` — not `investigation.md`, and not `tasks.md`/
`traceability.md` — for a `full`-profile entry with `Spec-Review-Status`/
`Impl-Review-Status` each `Pending` or `Passed`, confirmed by direct read of
`plugins/sdd-quality-loop/scripts/check-workflow-state.sh:657-676`). This
feature's own registration commit (AGENTS.md + `specs/workflow-state-
registry.json`) must keep both commands green after it lands — Acceptance
Criteria, below, restates this as a testable condition.

## INV-012: `workflow-state-registry.json`'s `full`-profile entry shape is exactly two keys, and this worktree's own `entries` array carries no sibling epic's registration

`contracts/workflow-state-registry.schema.json` (read via `check-workflow-
state.sh:93-106`'s own jq validation, which this investigation reuses
rather than re-deriving) requires, for a `full`- or `lite`-profile entry,
`(keys | sort) == ["feature", "profile"]` — no additional metadata.
Confirmed directly: this worktree's own `specs/workflow-state-registry.
json` `entries` array ends with `epic-159-pillar-d` and does not contain
`epic-190-a2-capability-registry`, `epic-191-a3-path-ownership`,
`epic-192-a4-facet-manifest`, or `epic-193-a5-capability-resolver` — each
Foundation epic's worktree is an independent branch off the same
pre-Epic-A0 base commit and only ever carries its own epic's own
registration (this repeats A5's own identical INV-016 finding, confirmed
independently here for this worktree). This feature's own registration
entry, `{"feature": "epic-194-a6-lite-integration", "profile": "full"}`, is
appended to this worktree's `entries` array alone.

## INV-013: No `contracts/*` artifact any Foundation epic (A1-A6) would define exists anywhere in any readable worktree yet — every epic, including this one, is still Phase 1

`find . -iname "*capability-registry*" -o -iname "*facet-manifest*" -o
-iname "*capability-summary*" -o -iname "*resolver-evidence*" -o -iname
"*context-projection*" -o -iname "*lite-upgrade-reason-catalog*" -o -iname
"*lite-check-catalog*"` under `contracts/` returns nothing in this worktree
or in the A2/A4/A5 sibling worktrees (investigation time). This confirms
the entire Foundation epic set (A0-A6) is presently in the Phase 1
(requirements/design/investigation/acceptance-tests only) stage across
every parallel worktree — this feature's own REQ-001's "Registry schema
v1.1 additive extension" is therefore, like A2's own REQ-001, a documented
*design* for a schema revision, never an edit to a file that exists today.

## INV-014: `check-risk-upgrade`'s current design silently degrades an unreadable/malformed/shape-invalid *supplied* fragment to "no Capability-derived trigger" — an accepted fail-open path this feature's own Security Boundaries text mislabels "fail-closed"

An earlier revision of this design (`design.md` Data Plan / API / Contract
Plan) stated that when `--capability-reasons` is *supplied* but the file at
that path is unreadable, malformed, or missing the `upgrade_reasons` key,
`capability_triggers[] = []` — degrading silently to the same output as if
the second argument had never been given at all, never an error exit.
`design.md`'s own Security Boundaries text simultaneously claimed this same
behavior was "fail-closed... never a parse error that silently permits a
Lite-ineligible Capability through" — a direct contradiction: a
*supplied-but-invalid* fragment is exactly the case where a Capability
author or upstream signal-source producer made an error, and silently
treating it as "no Capability signal" is the fail-*open* direction (a
genuinely ineligible Capability's signal is lost, not preserved). The
2026-07-22 adversarial review (Blocker [B3]) identifies this contradiction;
the orchestrator's ruling (OQ-002 is unrelated; see requirements.md REQ-002,
revised) reverses the *supplied-but-invalid* path to a hard Block (exit
`2`), reserving the silent-degrade behavior for the *omitted* (legacy, no
second argument at all) case only.

## INV-015: A5's own design.md states `advisory` and `required` enforcement produce byte-identical Resolver output content — only `Resolver Evidence`'s own `state` field differs

`specs/epic-193-a5-capability-resolver/design.md` (REQ-003 discussion,
cited directly): "`advisory` and `required` are **not** distinguished by
this feature's own Resolver output content — the same inputs under either
state produce byte-identical output across this invocation's own
**track-exclusive output set**... within that set, only Resolver Evidence's
own `state` field differs between the `advisory` and `required` fixture of
an otherwise-identical pair." This means neither a written
`capability-summary.yaml` nor its own `required_lite_checks`/`capabilities`
content ever reveals, on its own, whether a specific matched Capability's
absent `lite_policy.required_lite_checks` key was tolerated (`advisory`) or
should have Blocked (`required`) — that distinction, if enforced at all,
must be made by a mechanism this feature (A6) names explicitly, since A5's
own Resolver output alone cannot carry it (2026-07-22 adversarial review,
Blocker [B5]).

## INV-016: A5's own design.md step 10b stages a Capability Summary on **every** resolvable (non-Blocked) Lite-track resolve, including the zero-matched-Capability case — a written Summary's mere absence under active enforcement is therefore never a legitimate "nothing to check" state

`specs/epic-193-a5-capability-resolver/design.md` step 10b: "On a
resolvable source... **stage** (do not yet write) `specs/<feature>/
capability-summary.yaml` only." The zero-matched-Capability case is
explicitly named as a resolvable source producing a schema-valid Summary
with empty `capabilities`/`required_lite_checks` arrays (A5 `design.md`
Test Strategy item 4, `resolve-project-context-lite`, "track-exclusive-
output-set fixture"). Under an active Project Context (`workflow.
capability_enforcement` is `advisory` or `required`, ADR-0016 item 4), a
Lite-track Feature's successful resolve therefore *always* produces a
Summary, zero-matched-Capability included — an absent `capability-summary.
yaml` under that condition can only mean the Resolver Blocked, failed, was
never invoked, or the file was deleted after the fact, never a legitimate
zero-checks state (2026-07-22 adversarial review, Blocker [B6]). The only
condition under which "no Capability Summary, and this is fine" remains
true is `disabled-legacy` (no Project Context at all, ADR-0016 item 4's own
"outside that computation's domain" framing, requirements.md Edge Cases
"Compatibility fallback") — the Resolver mechanism itself never runs, so
there is nothing to have produced a Summary from.

## INV-017: ADR-0022 item 3's own worked `capability-summary.yaml` example, and A4's own AC-013 fixture built directly from it, name three check-ids (`build`, `test`, `installer-dry-run`) — not one — as the canonical Feature-level `required_lite_checks` content this feature's `lite-check-catalog.json` design must admit

`docs/adr/0022-lite-capability-upgrade.md` item 3's own literal YAML
example: `required_lite_checks: [build, test, installer-dry-run]`.
`specs/epic-192-a4-facet-manifest/requirements.md` AC-013 independently
fixes the identical three-token array as the canonical fixture `contracts/
capability-summary.schema.json` must validate. An earlier revision of this
feature's own `lite-check-catalog.json` design seeded only
`["installer-dry-run"]`, reasoning that `build`/`test` are already
`lite-gate` baseline check names, not new catalog entries — but the
Registry-level validator check (j) (REQ-001 item 5) validates every
`lite_policy.required_lite_checks` **token**, including a Capability
author's own `build`/`test` declarations, against the catalog; a Capability
entry declaring `required_lite_checks: [build, test, installer-dry-run]`
(this feature's own `design.md` Test Strategy item 7 fixture, and the
literal ADR-0022/A4 canonical example) would fail check (j) on `build`/
`test` under the single-token seed — the design's own fixture would fail
its own validator. The 2026-07-22 adversarial review (Major [M1])
identifies this self-contradiction; the orchestrator's ruling expands the
seed to all three canonical tokens (Field Definitions, requirements.md,
revised).

## INV-018: A2's own `requirements.md` Dependencies section states Epic A5 reads `lite_policy`/`trigger`/`required_facets` directly from the **full Registry**, never through the projection generator's own output — contradicting this feature's pre-review "passive flow through the projection" description

`specs/epic-190-a2-capability-registry/requirements.md` (Dependencies,
"Epic A5 (Capability Resolver) — downstream consumer, not a blocker"):
"Because the generated projection (REQ-005) carries only `stage:
implementation` Gate data, Epic A5's need for `trigger`, Facets, and
`lite_policy` is met by reading the full Registry directly through
REQ-005's package-relative discovery contract... not through the
projection." An earlier revision of this feature's own REQ-001 item 5
stated the new `required_lite_checks` field "passively flows through the
existing `--check` drift-detection mode" of `generate-gate-capabilities` —
implying the projection is the delivery path to A5, which A2's own text
directly contradicts (the projection never carries `lite_policy` at all, in
any version). The 2026-07-22 adversarial review (Major [M2]) identifies
this; the orchestrator's ruling corrects REQ-001 item 5 to state the true
mechanism (full-Registry direct read, no generator-logic change) and
isolates the one real ripple (the projection's own `_generated` metadata
hash changing when the underlying Registry file's bytes change) as a
separate, narrower claim.

## INV-019: `specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1` is hard-anchored to its own `specs/epic-136-phase2-gates/human-copy` prefix and cannot read this feature's own staged directory

Direct read, this worktree: `$HumanCopyPrefix = 'specs/epic-136-phase2-
gates/human-copy'` (`apply-protected-files.ps1:31`) is a literal,
unparameterized string constant; every staged-source path this runner
computes is `$HumanCopyPrefix + '/' + $target` (`:635`), and the runner
additionally requires a **staged canonical `guard-invariants.json` copy**
at that exact fixed prefix (`$HumanCopyPrefix + '/plugins/sdd-quality-
loop/references/guard-invariants.json'`, `:621-622`) whose own `phase2_
human_copy_targets` array it cross-checks, in order, against the live
file's own array (`:627-628`) — a file this feature's own REQ-002/REQ-005
human-copy batch does not stage (this feature does not propose changing the
protected-file inventory, OQ-001, Minor finding, below). This runner
therefore cannot apply this feature's own `specs/epic-194-a6-lite-
integration/human-copy/` batch as-is, on either count (wrong prefix,
missing canonical file). The 2026-07-22 adversarial review (Major [M3])
identifies this; the orchestrator's ruling adds a design-level contract
(design.md Protected-File Statement, revised) for the feature-scoped
anchored runner a future implementation task must author, rather than
assuming the Epic-136 runner applies unmodified.

## INV-020: The Protected-File Statement's own "exact-set" wording, as first drafted, forbade the runner and manifest control files it also required to exist in the same staged directory

Direct read, this package's own `design.md` Protected-File Statement
(pre-correction text): it places `apply-protected-files.ps1` and requires
a `MANIFEST.sha256` **inside** `specs/epic-194-a6-lite-integration/
human-copy/`, while simultaneously requiring that same directory's own
file set contain *exactly* the four payload targets and "no more" — the
runner and manifest are therefore forbidden by the same rule that
requires them, an internal contradiction the 2026-07-22 adversarial final
verification identified (M3, PARTIAL). The real Epic-136 runner does not
read this as a contradiction because it never enumerates its own staging
root's raw filesystem listing: `Get-ManifestDigests` only requires the
manifest to carry exactly one line per declared target
(`apply-protected-files.ps1:81-101`), and the staged canonical
`guard-invariants.json` copy and `MANIFEST.sha256` are read as control
inputs the copy process consumes, never as members of the
`phase2_human_copy_targets` set they themselves describe
(`apply-protected-files.ps1:68-101`, `:621-629`). The orchestrator's
ruling adopts the same reading explicitly: `design.md`'s Protected-File
Statement now defines a **payload file set** (recursive staged paths
excluding this batch's own control files — `MANIFEST.sha256`, the runner
script, and any machine-readable target-inventory file) and states the
exact-set requirement as a three-way equality among the declared
four-target list, `MANIFEST.sha256`'s own target set, and the enumerated
payload set — never a raw directory-listing diff. TEST-010/TEST-031
(acceptance-tests.md) are revised to the same definition. This closes
M3 (previously PARTIAL).

## INV-021: The `required_lite_checks`/`checks[]` catalog schemas admit any non-empty string, while `lite-gate`'s own command-discovery contract interpolates that string into a `scripts/<id>.{sh,ps1}` filesystem path with no stated identifier grammar, canonical-path containment proof, regular-file/no-link policy, or argv-safe invocation

Direct read, this package's own pre-correction text: the designed
`lite_policy.required_lite_checks`/`lite-check-catalog.json` `checks[]`
item schemas (design.md Data Plan) constrained each token only to
`{"type": "string", "minLength": 1}`, and the "Lite-check
command-discovery contract" (design.md API / Contract Plan, requirements.
md REQ-004 Step 2b) named `scripts/<id>.sh`/`scripts/<id>.ps1` as a
resolution target with no stated grammar on `<id>`, no canonical-path
containment proof against `scripts/`, no regular-file/no-symlink policy,
and no argv-safe invocation guarantee — a schema-valid check-id such as
`../outside` could therefore make the stated "bounded to `scripts/`"
claim false, and TEST-016 (acceptance-tests.md, pre-correction) covered
only "neither mapping exists," not traversal/option-like ids or a link
escaping the scripts root. The 2026-07-22 adversarial final verification
identifies this as a new, significant finding (NEW-01, NOT_RESOLVED)
against text that had otherwise closed the original Blocker [B7]. The
orchestrator's ruling: constrain every check-id to
`^[a-z0-9][a-z0-9-]*$` (this repository's own lowercase-hyphenated
identifier convention), enforced fail-closed at three independent points
— the catalog schema, the Registry's `required_lite_checks` item schema,
and `lite-gate`'s own pre-discovery re-validation (Field Definitions,
requirements.md; Data Plan/API-Contract-Plan, design.md) — require a
canonical-path repo-root-`scripts/`-containment proof before a
`scripts/<id>` candidate is touched, require it be a regular file (reject
symlinks/reparse points), require argv-direct invocation (never a
shell-interpolated command string), and resolve the "pair" ambiguity
between requirements.md's and design.md's own pre-correction text: "pair"
means **both** `.sh` and `.ps1` runtime members must exist and pass these
rules for an id to be mapped (the dual-runtime principle already implicit
in every other `plugins/**/scripts/*.{sh,ps1}` pair this repository
establishes) — a partial pair is unmapped, never "resolved for the
running runtime only." Paired POSIX/PowerShell negative fixtures for
`../`, path separators, option-like ids, and a scripts-root-escaping link
are added to design.md Test Strategy item 7 and requirements.md REQ-006
fixture (e). This closes NEW-01 (previously NOT_RESOLVED).

## Open Questions

Each entry below records this spec's original disposition and, where the
2026-07-22 adversarial spec review (14 findings) required a change, the
orchestrator's ruling that supersedes it. No entry below authorizes
changing `Spec-Review-Status`/`Impl-Review-Status` — both remain `Pending`
for a human reviewer.

## OQ-001: Should `lite-gate/SKILL.md` be newly registered as a protected file, given REQ-004's extension to it?

Status: **CLOSED (orchestrator ruling 2026-07-22, Minor finding).**
INV-008 confirms `lite-gate/SKILL.md` is not currently in `guard-invariants.
json`'s protected-file inventory, and neither ADR-0022 nor decision
document v2 §6 names it as protected. This feature's own REQ-004 extends
`lite-gate/SKILL.md`'s Process to execute Registry-sourced Lite-specific
checks — a change to the file that determines what counts as a passing
Lite quality gate, arguably as enforcement-critical as the four files
ADR-0022 item 5 already protects. The 2026-07-22 adversarial review
correctly noted an earlier revision left this re-opened as a question for
human ruling even though this feature's own investigation already had the
only fact that matters (the live `guard-invariants.json` state) and no
正本 source proposes protecting it. Ruling: this package does not itself
propose adding `lite-gate/SKILL.md` to the protected-file inventory
(expanding ADR-0022's own already-fixed four-file list stays outside this
feature's own authority) — REQ-004's edit is a **direct** edit,
definitively, not a question deferred to a later ruling. The existing,
narrower "live-repository snapshot, re-verified at implementation-start
time" caveat (`requirements.md` Roles and Permissions; `design.md`
Protected-File Statement) is retained — that re-verification is a factual
check against a file that could change for reasons entirely outside this
feature's own scope, not an open design question this package itself
still needs resolved.

## OQ-002: What supplies a Capability-aware signal at `lite-spec`'s pre-generation Risk-Upgrade Gate, before any Feature-specific code diff exists?

Status: **RESOLVED (orchestrator ruling 2026-07-22, Blocker [B1]).**
INV-010 establishes that `lite-spec`'s Risk-Upgrade Gate runs before any
`specs/<feature>/` file exists — necessarily before Epic A3's
`resolve-component-paths`/Epic A5's Resolver has a Feature-specific git
diff to compute `affected_components` from (the Resolver's own `--feature`
and `--target-rev` inputs presuppose a Feature already has a diff to
resolve against). No sibling epic's spec, ADR, or the decision document
itself states how Capability matching is supposed to produce a signal at a
point in the flow that precedes the very computation (`affected_
components`) every existing Capability-matching mechanism (A2's
`evaluate-predicate`, A5's Resolver) depends on. An earlier revision of
this investigation named two candidate resolutions without selecting
between them. **Ruling: candidate (a) is selected, and is layered with the
existing `ship`-time recheck as a mandatory second stage — not a fallback,
not an either/or choice.** Concretely: (1) at the pre-generation position
(before any `specs/<feature>/` file is created), `lite-spec`'s extended
Risk-Upgrade Gate evaluates every Registry Capability's own `trigger` (via
A2's `evaluate-predicate`, one call per Capability × declared component)
against every component the Project Context (Epic A1) already declares —
Project-Context-wide, diff-independent, per candidate (a)'s own advantage
(satisfies decision document v2 §19's own literal pre-generation-Block
position, with no dependency on a Feature-specific diff existing yet); any
matched, ineligible Capability (`lite_policy.eligible: false`) Blocks at
this position, via REQ-002's own merged-trigger output contract. (2) The
existing `ship`-time recheck (`plugins/sdd-lite/references/risk-upgrade-
policy.md:40-51`, INV-010's second invocation point) remains independently
mandatory and unmodified in position — it is not superseded by (1), and is
not merely a fallback for when (1) was skipped; it is retained explicitly
as a second, independent enforcement layer, because a Feature's own real
diff can touch components the whole-project, declared-component evaluation
in (1) did not itself flag as relevant to a given Capability's own
`trigger` at intake time (a component added or changed after intake, or a
component whose relevant `characteristics` field was not yet accurate at
intake time). Both stages are now normative parts of this feature's own
design (`requirements.md` REQ-005, Main Workflows; `design.md`
Architecture/API-Contract-Plan/Design Decisions), not two candidates
awaiting a choice.

## OQ-003: Does `full_upgrade_required` in a written Capability Summary require any `lite-gate`-side re-check, or is it purely an upstream (pre-generation) signal that already prevented `lite-gate` from ever running?

Status: **RESOLVED (orchestrator ruling 2026-07-22, Blocker [B2]).**
A4's `capability-summary.schema.json` (INV-005) fixes `full_upgrade_
required` as a required boolean field on every Capability Summary A5's
Resolver writes. Because A5's own Lite-track resolve path Blocks
(`lite-check-source-undefined`) whenever a matched Capability needs a Lite
check the Registry cannot yet source (INV-004), and because REQ-005's own
full-upgrade Block is scoped to the same pre-generation position as the
existing Risk-Upgrade Gate (decision document v2 §19's own literal Epic A6
line), it was not self-evident from any正本 text whether a *written*
Capability Summary could ever legitimately carry `full_upgrade_required:
true` in practice, or whether that field existed purely for forward-
compatibility / defense-in-depth. **Ruling: yes** — `lite-gate` performs
its own independent `full_upgrade_required` re-check, immediately after
Capability Summary schema validation succeeds (REQ-003/REQ-004's own
existing validate-before-trust discipline, AC-012), and Blocks (`VERDICT:
FAIL`, `Status` unchanged, Full-track redirection named in the reason)
whenever the field reads `true` — never treating a written Summary's mere
existence as proof every full-upgrade determination already happened
upstream. This does not reopen or duplicate REQ-005's own pre-generation
Block (a different position, a different mechanism, and — per INV-015/
INV-016 below — potentially a different, later-discovered ineligibility a
whole-project intake-time evaluation could not have seen) — it is
`lite-gate`'s own backstop, the same "never trust upstream self-report"
posture ADR-0022 item 4 already requires of every other check `lite-gate`
runs. `false` continues to Step 2b unchanged; an invalid/missing value is
already covered by REQ-003's existing schema-invalid-Summary Edge Case,
since `full_upgrade_required` is a required field on the schema `lite-gate`
already validates against before reading it.

## Adversarial Spec Review Response (orchestrator ruling 2026-07-22)

A 14-finding adversarial review (7 Blocker, 3 Major, 1 Minor, 3 OK) was
conducted against this spec package. All 14 findings were accepted by
orchestrator ruling; the ruling for each is recorded at the point of the
affected REQ/AC/design text rather than duplicated here. This section is a
pointer index only — it does not itself change `Spec-Review-Status`/
`Impl-Review-Status`, both of which remain `Pending`:

- Blocker [B1] (OQ-002/TEST-020 non-selection leaves the pre-generation
  Block inert) → OQ-002 above (RESOLVED); requirements.md REQ-005/AC-020/
  Main Workflows step 2/Open Questions/Risks; design.md Architecture/API-
  Contract-Plan/Design Decisions/Open Questions/Risks; acceptance-tests.md
  TEST-020/AC-019.
- Blocker [B2] (`full_upgrade_required: true` read but never Blocked) →
  OQ-003 above (RESOLVED); requirements.md REQ-003/REQ-004/AC-026; design.md
  API/Contract Plan Step 2a (NEW); acceptance-tests.md TEST-026.
- Blocker [B3] (supplied-but-invalid capability fragment fail-opens to
  keyword-only) → INV-014 above; requirements.md REQ-002/Security
  Boundaries; design.md Data Plan/API-Contract-Plan/Security Boundaries/
  AC-027; acceptance-tests.md TEST-027.
- Blocker [B4] (`eligible: false` with no reasons is unrepresentable in the
  fragment) → requirements.md REQ-002/Field Definitions/Edge Cases/AC-028;
  design.md Data Plan/API-Contract-Plan; acceptance-tests.md TEST-028.
- Blocker [B5] (no enforcement owner for "opted-in" vs. absent per-matched-
  Capability under `required`) → INV-015 above; requirements.md REQ-001
  Field Definitions/Edge Cases/AC-029; design.md Cross-Layer Dependencies;
  acceptance-tests.md TEST-029.
- Blocker [B6] (active-pipeline Summary absence bypasses every check) →
  INV-016 above; requirements.md REQ-003/AC-011 (narrowed)/AC-030; design.md
  Components/API-Contract-Plan Step 2a; acceptance-tests.md AC-011/TEST-011
  (narrowed), AC-030/TEST-030.
- Blocker [B7] (`required` check can stay unmapped `N/A` and still PASS) →
  requirements.md REQ-004/AC-016 (reversed); design.md API-Contract-Plan/
  new "Lite-check command-discovery contract"; acceptance-tests.md AC-016/
  TEST-016 (reversed).
- Major [M1] (single-token catalog seed self-contradicts the design's own
  `build`/`installer-dry-run` fixture and the ADR-0022/A4 canonical
  example) → INV-017 above; requirements.md AC-003/Field Definitions/
  Non-goals/Design Decisions; design.md Data Plan/Design Decisions/Test
  Strategy; acceptance-tests.md AC-003/TEST-003.
- Major [M2] (projection "passive flow" claim contradicts A5's full-
  Registry-direct-read contract) → INV-018 above; requirements.md REQ-001
  item 5; design.md Architecture/Design Decisions/new Test Strategy item
  11.
- Major [M3] (no runner can apply this feature's own protected-file batch)
  → INV-019 above; design.md Protected-File Statement (revised)/AC-031;
  acceptance-tests.md AC-010 (revised)/AC-031/TEST-031.
- Minor (OQ-001 re-opened as a question despite no正本 basis to protect
  the file) → OQ-001 above (CLOSED); requirements.md Roles and Permissions/
  Non-goals/AC-017/Risks; design.md Protected-File Statement/Open
  Questions.
- OK (schema shape / 12-token vocabulary / lightness boundary) → preserved
  as-is; the required-mapping fail-closed reversal (B7) and the
  fragment-shape addition (B4) are both designed to coexist with, not
  widen, these boundaries (design.md Global Constraints, restated).

## Adversarial Final Verification Response (orchestrator ruling 2026-07-22)

A follow-on adversarial final verification re-reviewed the six items the
first-round review had left PARTIAL/NOT_RESOLVED (M3, NEW-01) or flagged
as depending on a sibling package (B5), and re-confirmed the remaining
twelve RESOLVED findings unchanged. Two of the three remaining items are
closed by this ruling; the third (B5) is intentionally left open on this
package's own side, since its remaining half is A5's own addendum
obligation, not this package's:

- Major [M3] (PARTIAL → **RESOLVED**: the Protected-File Statement's own
  "exact-set" wording forbade the runner/manifest control files it also
  required to exist in the same staged directory) → INV-020 above;
  design.md Protected-File Statement ("Payload file set, defined")/Test
  Strategy item 17; requirements.md AC-010/AC-031; acceptance-tests.md
  TEST-010/TEST-031.
- New Major [NEW-01] (NOT_RESOLVED → **RESOLVED**: command-discovery had
  no stated check-id grammar, canonical-path containment proof,
  regular-file/no-link policy, or argv-safe invocation, and "pair" was
  read two ways) → INV-021 above; requirements.md Field Definitions
  ("Check-id identifier grammar")/REQ-004 Step 2b/Edge Cases/Security
  Boundaries/AC-001/AC-003/AC-016/REQ-006(e); design.md Data Plan (both
  schema fragments)/API-Contract-Plan ("Lite-check command-discovery
  contract")/Test Strategy item 7/Security Boundaries; acceptance-tests.md
  TEST-016.
- Blocker [B5] (PARTIAL, **left PARTIAL by design** — this package's own
  text is internally consistent, but not yet mutually consistent with
  A5's own currently-`Pending` text) → this package makes no further
  content change here; requirements.md AC-029 and acceptance-tests.md
  TEST-029/Spec-Authoring-Time Manual Review Record now each state
  explicitly that this AC/TEST records this feature's own half of a
  cross-epic contract, normative only once A5's own reciprocal addendum
  (narrowing `lite-check-source-undefined`'s trigger condition and A5's
  own REQ-003/AC-016 byte-identity guarantee to this exact case) is
  itself normalized in A5's own package — a dependency-direction
  clarification (A6→A5), not a substantive change to what this package
  itself already specifies. Tracked for closure in A5's own package, not
  this one.

## Amendment Re-Review Context

This section is the declared amendment re-review context for this package,
per `plugins/sdd-review-loop/references/spec-review-calibration.md`
("Amendment Re-Review Context"). It records, with full citations, the
human-approved post-implementation amendments under which this package is
being re-reviewed (spec-review attempt 2, and attempt 3 after the
completion chain below).

### Amendment commits (full hashes)

- `9997091c71244e8cf3f9e46732f7ba164aa49843` — widened acceptance-tests.md
  AC-010 from a four-target to a five-target declared payload set, closing
  two Major findings both vendor slots of the T-001 blind cross-model panel
  raised independently (2026-08-21).
- `fae561c9d323cf32914f6885cb6f3d24053bd9af` — completed that amendment
  consistently across the document set (TEST-031/AC-031 sibling rows widened
  to the same five-target set; Overview dated phase note added; positional
  CLI wording aligned to the named-flag form the staged implementation
  uses), remediating spec-review attempt 2 round 1 findings (2026-08-23).
- `c362d3f508792c6415fc6308c4143f6c5883808f` — reworded the Overview's
  dated note to point at this section and recorded the attempt-2 round-3
  evidence; the revision of this document that first carried this section
  (2026-08-23).
- `f577a3615ce79db3bd04cacdba23ea51df0add20` — grounded the fifth payload
  target in this feature's own scope (INV-022, below, and REQ-002's
  fifth-target requirement statement with the AC-010/AC-031 trace
  citations), remediating attempt 2 round 3's ASSUMPTIONS-RESOLVABLE /
  DOWNSTREAM-READINESS findings (2026-08-23).

### Amended-document fingerprints (SHA-256, as of each amendment commit)

As of `9997091c71244e8cf3f9e46732f7ba164aa49843`:

- `specs/epic-194-a6-lite-integration/acceptance-tests.md`:
  `691db158e25045959809f32d67e1132974163cb72ef6729806427b3c193180f5`

As of `fae561c9d323cf32914f6885cb6f3d24053bd9af`:

- `specs/epic-194-a6-lite-integration/requirements.md`:
  `580cce4d0f10ccf11667f90fd9d0286ab9b735fc257379bbc051d5ea6e7a4be5`
- `specs/epic-194-a6-lite-integration/acceptance-tests.md`:
  `d782157cd90594388008cd221c1fcdc4c619dab2e84ec3895ae5e8fb37d7367b`

As of `c362d3f508792c6415fc6308c4143f6c5883808f`:

- `specs/epic-194-a6-lite-integration/requirements.md`:
  `fbcca3c04b1f66374cb7e03483c64a47dd9a32749b80f61ba8231272405df5f6`
- `specs/epic-194-a6-lite-integration/investigation.md`:
  `e82a6cd6fa5aad1a4da058d67e84f06daaa38eea18c10d980d6008009e8db593`

As of `f577a3615ce79db3bd04cacdba23ea51df0add20`:

- `specs/epic-194-a6-lite-integration/requirements.md`:
  `fafd348b2bdb0b58456a8016324bd363a690cbe36032a440fd0a3e66aa78b179`
- `specs/epic-194-a6-lite-integration/investigation.md`:
  `92e46294fbf98f13ff6be1195cd92f6d636c96a3a1b4429b4ee9e9d41688c077`

This `investigation.md` is itself amended by the commits that introduce and
extend this section; a document cannot embed its own post-amendment hash, so
each such revision's fingerprint is pinned instead by the reviewer
invocation manifests and evidence commits of the spec-review round that
reviewed it (attempt 2 round 3 for the first revision; the current round's
manifests for this one).

### Human approval (verbatim, dated)

- 2026-08-23: 「194/195/196の凍結文書について人間は承認する」
- 2026-08-23: 「限定デプロイ + WFI 起票でやれ」 (authorizing limited
  deployment of this amendment re-review lane for epic-194 and epic-195,
  plus a workflow-improvement filing for the durable mechanism)

These approvals were given in conversation; this entry, committed into the
hash-pinned package under review and pinned by the round-3 reviewer
invocation manifests, is itself the durable, citable approval record.

### Later-phase artifacts referenced by this package (commit / SHA-256)

Referenced by the amended AC-010 row and TEST-031 row
(acceptance-tests.md), the AC-010/AC-031 rows and the Overview's dated note
(requirements.md):

- `specs/epic-194-a6-lite-integration/tasks.md` — SHA-256
  `b1ab0ddd49ab36badcfd0906a79158d24aaf8673612ea3e4b5b127c4611846d1`,
  last amended in commit `4fea3d64123a5ae14da2b5c3b4ce103b92aeb143`. Its
  Protected Files item 3 is the text whose fifth staged target AC-010's
  five-target widening admits into the declared payload set.
- `specs/epic-194-a6-lite-integration/traceability.md` — SHA-256
  `0bdaa87dce92b4075d98874660f82226ab67fc8ad0a82b826c15200eaa30321e`,
  last amended in commit `522a1ccab0cdc08e4094e12a2a84b156caf0dc7f`.
- `specs/epic-194-a6-lite-integration/traceability.json` — SHA-256
  `9f292087e4e2466c8e8ee3530a91af96698be1a4408c1f703e6ccf4d37208b84`,
  last amended in commit `859209955dcf1f99d4be0305f3dea317577b8006`.
- The T-001 cross-model verdicts (2026-08-21), the panel evidence the
  amended AC-010 row cites:
  - `specs/epic-194-a6-lite-integration/verification/T-001.panelist-anthropic.verdict.json`
    — SHA-256
    `18471b6023754934a8f1b371c78f7fe222a3b27b4fee298ce122bdd2294f0da7`,
    last amended in commit `89a0700d42e8badf348f8d9322417ff0044c8043`.
  - `specs/epic-194-a6-lite-integration/verification/T-001.panelist-openai.verdict.json`
    — SHA-256
    `37d15b1811698a4f3639fac438fb9ab18beec2615d6b1265ddcbd92e29cfb9aa`,
    last amended in commit `2461da5d08a6cb90d36e338dc5291d89ff217dda`.

Every fingerprint above is of the committed state at authoring time
(`git show <commit>:<path>` hashed with SHA-256), never of uncommitted
working-tree bytes.

### Amendment record extension (appended 2026-08-25): the 2026-08-24/25 design and layer-spec lane

Everything above this heading is the Amendment Re-Review Context exactly as
the spec-review attempt-3 round-1 reviewer manifests pinned it —
`specs/epic-194-a6-lite-integration/investigation.md` = SHA-256
`fe78fa618a206fb9173a91aa0e874175407ebaba3424e8385bb267d020b46b85`, the
committed state at contract commit
`e6bfe05800ebcb53be5a6e0333bf28dbaa0814d9` — and is left byte-identical, as
is INV-022 below this subsection. This lane records its own additions here,
appended below that reviewed text, rather than woven into it: a reviewed
record is extended, never rewritten. Where a fingerprint or a statement
above is superseded, the earlier text stays exactly where the reviewed
record put it — still true of the commit it names — and the superseding
value is recorded under "Fingerprints and statements above that this lane
supersedes" at the end of this subsection.

That is a shape requirement, not only an editorial preference. The
workflow-state gate reconciles an upstream stage's stale
`investigation.md` pin only when the live file's sole difference from the
pinned bytes is pure, contiguous growth confined to this section, with the
pinned section an exact prefix of the live one and everything outside it
byte-identical
(`plugins/sdd-quality-loop/scripts/check-workflow-state.sh`,
`investigation_growth_only_change`). An entry spliced above pre-existing
text in this section, or a fingerprint replaced in place, fails that test
even at zero net deletions. The first form of this lane's record did both;
this subsection is the same record in the additive form.

#### Completion-chain entries added by this lane

- `f8cfd7a1febd54ff805cd05f2a7490bac6c62a3a` — mechanically annotated
  design.md's existing passages with AC-ID labels for seven of the eleven
  IDs the impl-review AC-coverage precheck names (AC-001/003/009/012/014/
  017/021), substance unchanged, per the 2026-08-24 human ruling quoted
  below; the remaining four IDs (AC-006, AC-010, AC-023, AC-024) were
  left unannotated in that commit (2026-08-24). **The reason that bullet
  originally gave — "the four IDs whose substance design.md does not
  contain" — was wrong for AC-010 and is corrected in the next bullet.**
- `113b97a3a864141e0b0f08cd1f395341d449d35a` — the AC-006/AC-010 design
  amendment's first commit (2026-08-24): three edits to design.md and the
  corrections recorded in the numbered items below. Its own
  disposition of the four-versus-five payload count was superseded within
  the same day by the ruling recorded in the next bullet; item 2 below
  records both states.
- `8e736b82aff9ca7f6fbf925355bc7ac263c41665` — propagated the five-target
  declared payload set into design.md and rewrote the superseded dated
  note the previous commit had placed in its Protected-File Statement, per
  the second 2026-08-24 ruling quoted below (2026-08-24).
- `c917556d0ebd29d4789ffb859f96cc432c567a49` — propagated the same count into
  tasks.md (six payload-set counts, plus the extraneous-path negative
  check that had to move from "fifth" to "sixth"), and recorded the
  `security-spec.md`/`infra-spec.md` blocker rather than resolving it
  (2026-08-24). The superseding `tasks.md` fingerprint it produced is
  recorded under "Fingerprints and statements above that this lane
  supersedes" at the end of this subsection, not by editing the two
  places above and below that pin the earlier value.
- `23fe659f57685c5e7dde304035ce8887658d86bc` — scoped the CI-workflow
  claim in `security-spec.md` and `infra-spec.md` and propagated the
  payload count into both, per the 2026-08-25 ruling quoted below
  (2026-08-25).
- This entry's own commit — appended this subsection, and changed no
  document other than this one. It restructures the 2026-08-24/25 record
  from edits made in place inside the already-reviewed text above into
  this strictly additive extension below it, carrying every statement
  forward unchanged in substance; the pinned text above is restored
  byte-identical to what spec-review attempt 3 round 1 reviewed. Its own
  commit hash cannot be embedded in itself and is pinned by the impl
  re-review round's manifests (2026-08-25).
  1. **AC-010 — annotated; the earlier "does not contain" reason
     retracted.** design.md's Protected-File Statement already carried
     that criterion's entire design-content clause before this commit: it
     names all three protected-file targets REQ-002 edits
     (`risk-upgrade-policy.md`, `check-risk-upgrade.sh`,
     `check-risk-upgrade.ps1`), states staging under
     `specs/epic-194-a6-lite-integration/human-copy/` with a
     `MANIFEST.sha256` entry for a human to apply via
     `apply-protected-files` (ADR-0011) as their application path, cites
     INV-008 for all of them being protected today, and cites INV-019 in
     its Major [M3] paragraph for the Epic-136 runner being unable to
     read this feature's own staged directory. Only AC-010's second
     sentence — the **five**-target declared payload set — is absent, and
     it is not merely absent but contradicted: design.md declares a
     **four**-target set with explicit "no fewer, no more" exact-set
     wording. The `(AC-010)` citation added at the Human-copy path bullet
     names that criterion's design-content clause explicitly. **AC-010 is
     now discharged in full**, the count included, by the propagation
     recorded in item 2.
  2. **The 2026-08-21 five-target widening, and its propagation into
     design.md.** Commits `9997091c71244e8cf3f9e46732f7ba164aa49843` and
     `fae561c9d323cf32914f6885cb6f3d24053bd9af` widened
     acceptance-tests.md AC-010/TEST-031 and requirements.md
     AC-010/AC-031 to a five-target declared payload set; README.md
     followed them. design.md did not, and commit
     `113b97a3a864141e0b0f08cd1f395341d449d35a` recorded that divergence
     rather than closing it, on the reading that the earlier
     annotation-scoped ruling did not authorize a runner-contract change.
     A further human ruling the same day (2026-08-24, quoted verbatim
     below) directed the opposite: **propagate the widening into
     design.md**. This commit does so. Every payload-set count in
     design.md now reads five and enumerates `.github/workflows/test.yml`
     as the fifth declared target — Components table, the Major [M3]
     paragraph's staged-batch reference, exact-set contract item 2, and
     Test Strategy item 17. No property was invented for the fifth target
     beyond the one requirements.md already fixes: it is subject to the
     same exact-set/hash/post-copy properties as the other four, and to no
     others. The dated note the previous commit placed in the
     Protected-File Statement, which said the count was "superseded by
     requirements.md AC-010's own five-target declaration and is not
     discharged here", is rewritten accordingly — leaving it would have
     been a left-behind sibling of this lane's own making.
     **Test Strategy item 17's `(requirements.md AC-031)` citation was
     stale, not correct, for the three days between `9997091c` and this
     commit**: `32b8bf57` wrote it against a four-target contract before
     the widening existed, and it is recorded here as having been stale
     rather than being allowed to become quietly true.
     **Four sites in design.md say "four" and were deliberately left
     alone, each re-verified on 2026-08-24 rather than pattern-matched:**
     (a) the Protected-File Statement's opening "exactly four
     `sdd-lite`-owned paths are protected today" — that is the count of
     `sdd-lite`-**owned** protected paths, and `.github/workflows/test.yml`
     is not `sdd-lite`-owned (`guard-invariants.json`
     `protected_gate_suffixes` lines 34-37 versus line 44); (b) and (c)
     the Cross-Layer Dependencies bullet and the Constraint Compliance
     bullet stating ADR-0022 item 5's authorization scope — ADR-0022
     item 5 (`docs/adr/0022-lite-capability-upgrade.md:73-77`) names
     `lite-spec`'s `SKILL.md`, `risk-upgrade-policy.md` and
     `check-risk-upgrade.*` and no others, so widening either to five
     would have asserted an authorization ADR-0022 does not grant; the
     fifth target's human-copy authority is instead
     `guard-invariants.json`'s own `phase2_human_copy_targets` array,
     which already lists `.github/workflows/test.yml` at line 157, under
     ADR-0011's general mechanism; and (d) the "Payload file set,
     defined" paragraph's historical account of a superseded revision,
     which genuinely declared four at the time — clarified with "it then
     declared" rather than falsified. A cross-reference for (b)/(c) was
     added so the surviving fours cannot be misread as unpropagated
     siblings.
     **`tasks.md`, propagated in commit
     `c917556d0ebd29d4789ffb859f96cc432c567a49` (2026-08-24
     ruling).** Six payload-set counts moved to five: the T-001 fixture
     root's "correct five-target payload", the runner contract's declared
     payload list (now enumerating `.github/workflows/test.yml`), the
     `guard-invariants.json` input note's "five target paths", the
     acceptance-check fixture's "correct five-target payload", and the
     negative check's "missing one of the five declared targets". One
     further change was forced by the widening and is not a count
     substitution: the extraneous-path negative check read "a payload file
     set with an undeclared **fifth** path is rejected", which the
     five-target set makes describe a legitimate member — it now reads
     "undeclared **sixth** path". The two places this document pins
     `tasks.md`'s SHA-256 — the later-phase artifact block above and
     INV-022's inline citation below — are deliberately left carrying the
     pre-propagation fingerprint
     `b1ab0ddd49ab36badcfd0906a79158d24aaf8673612ea3e4b5b127c4611846d1`,
     which remains true of the commit each names; the superseding value is
     recorded under "Fingerprints and statements above that this lane
     supersedes" at the end of this subsection, so no pin is left behind
     and the prior state stays auditable without any already-reviewed line
     being rewritten. No `Status:` line was touched.
     **Seven `tasks.md` sites deliberately left at four**, each checked
     against its own predicate: Protected Files item 1 ("Human-copy path
     (four files, R-10 protected today)") enumerates only the four
     `sdd-lite` files and is listed *alongside* item 3, which carries
     `.github/workflows/test.yml` separately — raising item 1 to five
     would double-count the fifth target; item 3's own "applies this
     staged candidate the same way it applies the four payload files" is
     the very sentence AC-010's widening quotes, where "the four" means
     item 1's four; the three "four-point contract"/"all four contract
     points" references count the runner contract's items (i)-(iv), not
     targets; and the two "four new suites" references count test suites.
     **`security-spec.md` and `infra-spec.md`, propagated 2026-08-25
     after the blocker was ruled on.** The first attempt at these two
     documents stopped rather than propagating, because both assert in
     five places that this feature does not modify CI — `infra-spec.md`'s
     flowchart CI node, its sequence-diagram participant, its
     provisioning row and its cost row, and `security-spec.md`'s actor
     list — all of the form "unmodified by this feature" applied to
     `.github/workflows/test.yml`, which the five-target payload set
     stages an append to. That was reported rather than resolved. The
     human ruled on it (2026-08-25, quoted verbatim below): **scope the
     claim so both statements are true, then propagate.**
     **The reconciliation is a scoping distinction, not a reversal**, and
     is recorded as such for the blind reviewer to judge rather than
     absorb. The two statements answer different questions. (i) This
     feature's own commits leave the live `.github/workflows/test.yml`
     byte-unchanged — permanently, not incidentally, because that path is
     R-10 protected (`guard-invariants.json` `protected_gate_suffixes`),
     so no agent can write it and only a human applies the staged batch.
     That is what the diagrams and provisioning tables were describing.
     (ii) The feature's declared deliverables include a staged append to
     that same workflow, the fifth member of the five-target declared
     payload set, staged by T-001..T-004 and installed by a human via the
     anchored runner. That is what `traceability.md` and AC-010/AC-031
     were describing. Each of the five sites is amended to say (i)
     explicitly instead of the unqualified "unmodified by this feature",
     and one reconciling paragraph naming the staged append and its
     human-apply path was added to each document.
     Payload-set counts then propagated to five at `security-spec.md`'s
     B5 boundary row (five instances in that one row: the staged payload
     enumeration, which now names the workflow file; the live
     already-protected path count; the write-boundary integrity count;
     the direct-write deny clause; and the exact-set item (ii)), its
     human-maintainer authorization row, its data-asset row, and its Test
     Strategy item 17 row; and at `infra-spec.md`'s flowchart payload edge
     label, its publication-step sentence, and its rollback/backup row.
     **The `:24`/`:25` diagram pair was fixed together, not separately.**
     Raising the `stages 4-file payload` edge label alone would have left
     the adjacent `PROTECTED` node enumerating only the four `sdd-lite`
     paths, making that one flowchart self-contradictory; the node now
     also names `.github/workflows/test.yml`, so edge and node agree.
     **Verified not to contradict the "no new CI job" claims.**
     `infra-spec.md` states "no new CI job introduced by this Phase 1
     package" and "This feature adds no new CI job itself", quoting
     design.md's Deployment / CI Plan, and `traceability.md` adds "no new
     CI job/matrix dimension is added". The staged append adds steps to
     the existing job, so all of these remain true and are untouched.
     Both documents already carried the scoping distinction latently —
     `infra-spec.md` and design.md both already said the future task's
     suite pairs "are wired into `.github/workflows/test.yml` ... this
     design does not itself edit that file" — so this amendment makes an
     existing distinction explicit rather than introducing a new claim.
     **Five sites in these two documents deliberately stay at four**,
     each an `sdd-lite`-owned count rather than a payload count:
     `security-spec.md`'s ADR-0011 mechanism split (four already-protected
     plus one unprotected), its B5 threat row ("four protected
     `sdd-lite` paths"), its Broken Access Control row ("Four
     already-protected `sdd-lite` paths") — whose own "the fifth"
     already denotes `lite-gate/SKILL.md` and must not be allowed to
     collide with the CI file — and `infra-spec.md`'s two rollback
     references to "the four `sdd-lite`-owned paths". Two further
     "unmodified" phrases in `infra-spec.md` are also untouched because
     they describe the `generate-gate-capabilities.py --check` step's own
     logic and the concurrency posture, not the workflow file.
     **Still not staged, and correctly so:** the live `human-copy/` tree
     contains only the four `sdd-lite` files today. The fifth target is
     *declared*, not yet staged; staging it is T-001..T-004's own
     implementation work and no part of this documentation lane.
  3. **AC-006 — substance added.** design.md carried no trace of this
     criterion (`grep` for `decimal` and for `capability-registry/v1`
     returned nothing), so no annotation could discharge it and a minimum
     true statement was written into the Data Plan's `lite_policy` (v1.1)
     entry instead. This is a substance addition rather than a mechanical
     annotation. Commit `113b97a3a864141e0b0f08cd1f395341d449d35a`
     disclosed it as exceeding the earlier ruling's "substance unchanged"
     wording; the second 2026-08-24 ruling quoted below resolves that by
     authorizing design 加筆 and naming AC-006 explicitly, so the addition
     is within its authorization and the earlier caveat is withdrawn. Its
     factual claim was verified against the live contract
     files before it was written, not carried over on trust: every
     `schema` const/enum in every `contracts/*.schema.json` in this
     worktree is an integer `vN` form (`capability-registry/v1`,
     `sdd-capability-summary/v1`, `sdd-project-context/v1`,
     `sdd-provider-bindings/v1`, `sdd-approver-registry/v1`,
     `sdd-context-projection/v1`, `sdd-facet-manifest/v1`,
     `domain-contract/v1`, `design-system-contract/v1`,
     `review-contract/v1`, `task-input-manifest/v1`,
     `terminal-tier-blocked-state/v1`, and
     `approval-sidecar.schema.json`'s two-member enum); the four
     remaining `*.schema.json` files declare no `schema` const at all;
     `workflow-state-registry.schema.json`'s nearest neighbour is
     `schema_version`, whose const is the integer `1`, under a different
     property name. No decimal (`vN.M`) `schema` const exists anywhere in
     `contracts/*.schema.json`.
  4. **AC-023 and AC-024 are discharged by a gate exception, not left
     outstanding.** design.md names neither, and no design document can
     honestly name either: both are `Global`-scoped criteria about this
     spec package's own registration commit, and AC-024 requires both
     review-status headers to read `Pending` "at commit time", which is
     historically false now that both read `Passed`. Commit
     `64915ecf7945215df18e530a8c2c4052c7aa6e80` ("fix(impl-review): except
     Global-scoped criteria from AC coverage, and stop overclaiming", on
     branch `claude/plugins-pin-stability`, 2026-08-24) adds the narrow
     exception a human ruled for on 2026-08-24. It keys on the
     requirement-trace cell of the criterion's **own** defining row in
     requirements.md — a `REQ-NNN` trace is still required to appear in
     design.md, only a `Global` declaration is excused — and this
     package's rows read `| AC-023 | Global |` and `| AC-024 | Global |`
     (requirements.md), so both are excused and reported to stderr rather
     than refused. The AC-coverage loop's residual list of exactly AC-023
     and AC-024 is therefore the correct terminal state for this package,
     not outstanding design work.
  5. **Correction to `d5e8d143b1d7b8ef00dcfd3b69726bd065dbdd90`'s commit
     message.** That message concluded that because
     "impl-review-precheck's `--verify-inputs` mode does not read
     investigation.md, ... the route stays open at the impl stage." The
     premise is true and the conclusion is false. `--verify-inputs`
     (`plugins/sdd-review-loop/scripts/impl-review-precheck.sh:281-308`)
     is the *reviewer-invocation* mode: it hashes only design.md,
     requirements.md, acceptance-tests.md and the layer files against
     `precheck-result.json`, then exits. The **round-opening** invocation
     is a different code path — it falls through that block and calls
     `assert_contract_reviewer_agreement` (`:254`), which requires the
     persisted predecessor-stage contract's reviewer manifests to carry
     `specs/<feature>/investigation.md` at its **current live** SHA-256
     (`:241-243`); `task-review-precheck.sh:210-213` imposes the same
     requirement. Editing investigation.md therefore does stale the
     predecessor contract for the next round-opening, which is exactly
     why every amendment in this lane is made in a single commit.

#### Amended-document fingerprints added by this lane

These extend the "Amended-document fingerprints" subsection above; they are
recorded here rather than inserted into it. The same rule stated there
applies: every fingerprint is of the committed state at authoring time
(`git show <commit>:<path>` hashed with SHA-256), never of uncommitted
working-tree bytes.

As of `e6bfe05800ebcb53be5a6e0333bf28dbaa0814d9` — the spec-review
attempt-3 round-1 evidence commit that validated the completion chain
above and, per the state table, flipped requirements.md's
`Spec-Review-Status` from `Pending` to `Passed` (a lifecycle transition
the workflow-state gate's normalized hashing absorbs, not a content
amendment; its investigation.md change is this section's own extension):

- `specs/epic-194-a6-lite-integration/requirements.md`:
  `c2a0be281775fdd94ce67b09f3e043416f4748ba5f982436cac256ea5080ae41`
- `specs/epic-194-a6-lite-integration/investigation.md`:
  `fe78fa618a206fb9173a91aa0e874175407ebaba3424e8385bb267d020b46b85`

As of `f8cfd7a1febd54ff805cd05f2a7490bac6c62a3a` (the design.md AC-ID
annotation amendment, 2026-08-24):

- `specs/epic-194-a6-lite-integration/design.md`:
  `7875ac5fab3d9336edc710dc735d5fae60f42bb21b1fe2c490e0fb3139ae8b13`

As of `113b97a3a864141e0b0f08cd1f395341d449d35a` (the AC-006/AC-010
design amendment's first commit, 2026-08-24):

- `specs/epic-194-a6-lite-integration/design.md`:
  `c57b197e74838acd883928eaedc13e22eca2cc25c4c40fc34e14690fad375c14`

As of `8e736b82aff9ca7f6fbf925355bc7ac263c41665` (the four-to-five payload-set
propagation into design.md, 2026-08-24):

- `specs/epic-194-a6-lite-integration/design.md`:
  `43d486353958d1b344774dfd0604461dc667c8eb5fd1ec84df313773a3090c3c`

As of `c917556d0ebd29d4789ffb859f96cc432c567a49` (the same propagation into
tasks.md, 2026-08-24):

- `specs/epic-194-a6-lite-integration/tasks.md`:
  `d3c7d7e3670f79d7aaee93febd68c4a3a044ce1706b641dec96348ea459376b4`

As of `23fe659f57685c5e7dde304035ce8887658d86bc` (the layer-spec
CI-workflow scoping and payload-count propagation, 2026-08-25):

- `specs/epic-194-a6-lite-integration/security-spec.md`:
  `7aee7ea715e9abe36a9bbc3ee8cd3368d3b38a12595830022a03775bf2d3f88d`
- `specs/epic-194-a6-lite-integration/infra-spec.md`:
  `245e19aa940e95118502671eb4b6ce16799e72a02115e43f36161c83e763991e`

#### Human approval (verbatim, dated) — rulings added by this lane

These extend the "Human approval (verbatim, dated)" list above, on the same
terms stated there: the approvals were given in conversation, and this
entry, committed into the hash-pinned package under review and pinned by the
impl re-review round's invocation manifests, is itself the durable, citable
approval record.

- 2026-08-24: 「①でやれ」 (option ① as presented: mechanically annotate
  design.md's existing passages with the AC-ID labels the post-freeze
  impl-review AC-coverage gate requires, substance unchanged, honesty of
  the annotations verified by the blind impl re-review that follows; the
  same ruling applies to epic-195)
- 2026-08-24, later the same day, on the question of the four IDs the
  first ruling left unannotated: 「① 注記＋design 加筆＋狭いゲート例外」
  (option ① as presented: a dated note, plus substantive addition to
  design.md — the option's text named AC-006 explicitly as one of the
  criteria whose substance is to be written into design.md — plus a
  narrow gate exception for the two `Global` meta-criteria, AC-023 and
  AC-024, that no design document can honestly name). This ruling
  authorizes the design 加筆 that the first ruling's "substance
  unchanged" wording did not, and supersedes the caveat commit
  `113b97a3a864141e0b0f08cd1f395341d449d35a` recorded against the AC-006
  addition.
- 2026-08-24, on the four-versus-five declared payload count, after the
  operational consequence was put to the human — that the fifth target is
  `.github/workflows/test.yml`, a CI workflow file, so admitting it to a
  human-copy payload is a real design commitment: option ① as presented,
  **propagate the widening into design.md**. This is the ruling item 2
  above executes.
- 2026-08-25, on the layer-spec blocker reported after that propagation —
  that `security-spec.md` and `infra-spec.md` deny in five places that
  this feature modifies CI, while `traceability.md` already lists the
  staged CI-workflow append as a declared output of all four of T-001
  through T-004: option ① as presented, **scope the claim so both
  statements are true, then propagate**. The option's text stated the
  reconciliation it authorizes: this feature's own commits leave the live
  CI workflow byte-unchanged, permanently, because the file is R-10
  protected and only a human applies the staged batch; and the feature's
  declared deliverables separately include a staged append to that
  workflow, applied by a human. Each of the five sites is to say the
  first thing explicitly, with one reconciling sentence per layer spec
  naming the staged append and its human-apply path. This is the ruling
  the final paragraphs of item 2 above execute.

#### Fingerprints and statements above that this lane supersedes

Recorded here rather than by editing the text they supersede. Each earlier
value stays where the reviewed record put it and remains true of the commit
it names; each item below names what replaced it, and when.

- `specs/epic-194-a6-lite-integration/tasks.md`, pinned in "Later-phase
  artifacts referenced by this package" above at
  `b1ab0ddd49ab36badcfd0906a79158d24aaf8673612ea3e4b5b127c4611846d1`
  (last amended, as of that pin, in commit
  `4fea3d64123a5ae14da2b5c3b4ce103b92aeb143`), is superseded by
  `d3c7d7e3670f79d7aaee93febd68c4a3a044ce1706b641dec96348ea459376b4`, last
  amended in commit `c917556d0ebd29d4789ffb859f96cc432c567a49` — the
  payload-count propagation described in item 2 above. The claim that
  bullet attaches to the earlier fingerprint — that tasks.md's Protected
  Files item 3 is the text whose fifth staged target AC-010's five-target
  widening admits into the declared payload set — is unaffected by the
  supersession and remains true of the superseding revision.
- INV-022's inline `tasks.md` citation, in the section below this one,
  pins the same earlier
  `b1ab0ddd49ab36badcfd0906a79158d24aaf8673612ea3e4b5b127c4611846d1`
  value and is superseded by the same
  `d3c7d7e3670f79d7aaee93febd68c4a3a044ce1706b641dec96348ea459376b4`
  value and the same commit. INV-022's own finding is unaffected: the
  Protected Files item 3 text it quotes (`tasks.md:68`,
  "`.github/workflows/test.yml` (R-10 protected)") is present in both
  revisions, and the finding is about the pre-widening four-target cap,
  which the superseding revision is precisely what lifted.
- The closing paragraph of "Amended-document fingerprints" above states
  that this document's own post-amendment fingerprint is pinned by "the
  reviewer invocation manifests and evidence commits of the spec-review
  round that reviewed it (attempt 2 round 3 for the first revision; the
  current round's manifests for this one)". That stands as written for the
  two revisions it names — "the current round" there being spec-review
  attempt 3 round 1, whose contract commit
  `e6bfe05800ebcb53be5a6e0333bf28dbaa0814d9` pins the `fe78fa61…`
  revision. It is extended, not corrected, for the revisions this lane
  adds: the revision this commit produces is pinned by the impl re-review
  round's invocation manifests, and the task-review round's manifests pin
  whatever revision they in turn read.
- No earlier contract is restaged, re-validated against amended bytes, or
  temporarily reverted to make it validate. Each prior contract keeps
  pinning the bytes it actually reviewed; the workflow-state gate
  reconciles the difference on its own, and only because the difference is
  pure growth of this section over those bytes. The first form of this
  lane's record contemplated a "restored temporarily for that validation
  only" fixed-point handling in this document's closing paragraph; that
  handling is withdrawn as unnecessary and is not used.

### Amendment record extension, second entry (appended 2026-08-25): design.md's Deployment / CI Plan

Appended below the previous extension rather than woven into it, for the
same reason that one was appended below the record above it: the bytes
above this heading are pinned by rounds that have already run —
spec-review attempt 3 round 1 pins this document at
`fe78fa618a206fb9173a91aa0e874175407ebaba3424e8385bb267d020b46b85`
(contract commit `e6bfe05800ebcb53be5a6e0333bf28dbaa0814d9`), and impl
re-review attempt 2 round 1 pins it at
`929d112f3f33705c1458cfbd5f67bfa005878673c0807dd5a89c5c9f44830012`
(contract commit `7a84303f521a9a7b1749b4a43bc9ce5aa2bf49ad`). Nothing
above is edited. Fingerprints this entry supersedes are listed at the end
of this subsection, with the earlier values left where they are.

**What this entry records, and what it deliberately does not.** impl
re-review attempt 2 round 1 returned NEEDS_WORK on two Major findings
raised by `impl-reviewer-b` (run
`RUN-epic-194-a6-impl-review-a2-r1-reviewer-b-seq774`, persisted at
`reports/impl-review/epic-194-a6-lite-integration/attempt-2/round-1/reviewer-b.json`).
This entry executes the disposition of the second finding only. The first
(`ASSUMPTIONS-VALID` — INV-013's "no `contracts/*.schema.json` artifact
exists anywhere yet, every epic is still Phase 1" premise) was
independently re-verified as **true**: the premise is stale and has been
for roughly a month. How far that correction reaches is a human decision
still outstanding, and nothing in this entry touches INV-013 or any
statement resting on it.

**`DEPLOYMENT-CONCRETE`, closed 2026-08-25.** The 2026-08-25 ruling quoted
above directed that the CI-workflow claim be scoped wherever it appears in
this package. The first pass applied it to `security-spec.md` and
`infra-spec.md` and missed design.md's own `## Deployment / CI Plan`,
which carried the same unqualified "this design does not itself edit that
file" wording and named no CI deliverable at all — a site inside a
document the ruling had already named first. Completing that ruling rather
than extending it, this entry's own commit adds a `**CI workflow, scoped
(2026-08-25 ruling).**` paragraph to that section, in the same form the
two layer specs already use: this feature's own commits leave the live
`.github/workflows/test.yml` byte-unchanged, permanently, because the path
is R-10 protected (`guard-invariants.json` `protected_gate_suffixes`) and
only a human applies the staged batch; and, separately, the feature's
declared deliverables include a staged append to that same workflow as the
fifth member of the five-target declared payload set, installed by the
feature-scoped anchored runner. The section's two existing bullets are
untouched, and its "no new CI job" statement is explicitly preserved and
reaffirmed — appending steps to the existing job creates no new job and no
new matrix dimension.

**The sweep was done before the write, and is recorded here.** This
finding was itself a left-behind sibling of an amendment whose entire
purpose was to close a left-behind sibling. So rather than patching the
one site the reviewer named, every statement of the fact was first
enumerated across the package:

- `design.md:1095-1098` (`## Deployment / CI Plan`) — the one remaining
  unqualified site anywhere in the package. Amended by this entry; the
  scoping paragraph now stands at `design.md:1100-1116`.
- `security-spec.md:83-85` (Authentication actor list), scoped by its own
  `**CI workflow, scoped (2026-08-25 ruling).**` paragraph at `:87-101`.
  Already correct; unchanged here.
- `infra-spec.md:26` (flowchart CI node), `:46` (sequence-diagram
  participant), `:53-59` (the no-new-CI-job paragraph), `:87`
  (provisioning row) and `:152` (cost row), all scoped by its own
  paragraph at `:61-80`. Already correct; unchanged here.
- `requirements.md:690-695` (Non-goals, second bullet) — states the
  `.github/**` boundary as "in this Phase 1 commit (this task's own
  explicit boundary)" and says every script/skill edit REQ-002/REQ-004/
  REQ-005 names is a design applied by a future implementation task. That
  is already the scoped form, so it is deliberately **not** amended;
  design.md's `(Non-goals)` citation at `:1098` therefore points at text
  that never made the unqualified claim.
- `traceability.md:25` (Infrastructure row) and `:144-147` (the T-001
  through T-004 output cells) — these already state the staged `test.yml`
  append positively, as a declared output of all four tasks. They are the
  documents whose disagreement with the layer specs raised the blocker in
  the first place. Unchanged.
- `tasks.md` (Protected Files item 3, and every per-task Outputs cell) and
  `README.md` (payload table and its "Why `.github/workflows/test.yml` is
  a declared payload target" section) — every reference names the staged
  candidate under `human-copy/`, never asserting the live file is
  untouched. Unchanged.
- Two design.md phrases that match the same keywords but state different
  facts, checked and left alone: `:146` ("unmodified by this feature")
  describes `contracts/capability-summary.schema.json`, and `:1092`
  ("re-runs, unmodified in its own logic") describes
  `generate-gate-capabilities.py`. Neither is a claim about `test.yml`.

No other unqualified statement of the fact exists in the package.

#### Fingerprints and statements this second entry supersedes

- `specs/epic-194-a6-lite-integration/design.md`, recorded above as
  `43d486353958d1b344774dfd0604461dc667c8eb5fd1ec84df313773a3090c3c` as of
  commit `8e736b82aff9ca7f6fbf925355bc7ac263c41665`, is superseded by
  `537ad9b37a8c037e3336cd341bc1d3cf92856546c1c3d8110a6b51e4be9b53d1` as of
  this entry's own commit. The earlier value stays where it is and remains
  true of the commit it names; it is additionally the exact value impl
  re-review attempt 2 round 1's two reviewers read
  (`reports/impl-review/epic-194-a6-lite-integration/attempt-2/round-1/impl-review-contract.json`,
  `design_sha256`), so it is the pin that contract keeps and must keep.
- This document's own bytes as pinned by impl re-review attempt 2 round 1
  (`929d112f3f33705c1458cfbd5f67bfa005878673c0807dd5a89c5c9f44830012`) are
  superseded by the revision this entry's own commit produces. As before,
  a document cannot embed its own post-amendment hash; that revision is
  pinned by the next impl re-review round's invocation manifests. No prior
  contract is restaged or re-validated against the amended bytes — each
  keeps pinning what it reviewed, and the workflow-state gate reconciles
  the difference only because this entry, like the one above it, is pure
  growth at this section's tail
  (`plugins/sdd-quality-loop/scripts/check-workflow-state.sh`,
  `investigation_growth_only_change`).

### Amendment record extension, third entry (appended 2026-08-25): INV-013's premise corrected

Appended below the second entry, on the same terms: nothing above this
heading is edited. That includes **INV-013 itself**, which sits at
`investigation.md:297-308`, before this section — the growth tolerance
requires every line preceding the section to stay byte-identical, so the
finding is superseded here rather than rewritten there, exactly as
fingerprints are superseded rather than replaced.

**The finding, and the ruling.** impl re-review attempt 2 round 1's other
Major finding (`ASSUMPTIONS-VALID`, `impl-reviewer-b`, run
`RUN-epic-194-a6-impl-review-a2-r1-reviewer-b-seq774`) reported INV-013's
premise as false. It was independently re-verified and **is** false, and
has been for about a month. A human ruled on 2026-08-25, option ① as
presented: **correct the premise-dependent statements to say what is true
now, and state explicitly that designing the eventual live edit's
application path is owned by the task that performs it, not by this
package.** The reasoning put to the human, and confirmed by direct check
before the ruling was sought, is that this is documentation staleness and
not design invalidity — see the shape verification below.

#### INV-013's recorded evidence, superseded

INV-013 (`## INV-013: No `contracts/*` artifact any Foundation epic
(A1-A6) would define exists anywhere in any readable worktree yet — every
epic, including this one, is still Phase 1`) records this evidence
verbatim, and it remains in place above:

> `find . -iname "*capability-registry*" -o -iname "*facet-manifest*" -o
> -iname "*capability-summary*" -o -iname "*resolver-evidence*" -o -iname
> "*context-projection*" -o -iname "*lite-upgrade-reason-catalog*" -o -iname
> "*lite-check-catalog*"` under `contracts/` returns nothing in this worktree
> or in the A2/A4/A5 sibling worktrees (investigation time). This confirms
> the entire Foundation epic set (A0-A6) is presently in the Phase 1
> (requirements/design/investigation/acceptance-tests only) stage across
> every parallel worktree — this feature's own REQ-001's "Registry schema
> v1.1 additive extension" is therefore, like A2's own REQ-001, a documented
> *design* for a schema revision, never an edit to a file that exists today.

That was true at investigation time (snapshot commit `b085ec76`,
2026-07-19). Re-running INV-013's own command under `contracts/` on
2026-08-25 returns **six of its seven globs**, not nothing:

```
contracts/capability-registry.json
contracts/capability-registry.schema.json
contracts/capability-summary.schema.json
contracts/context-projection.schema.json
contracts/facet-manifest.schema.json
contracts/lite-upgrade-reason-catalog.json
```

Only `*resolver-evidence*` and `*lite-check-catalog*` still return
nothing. When and why it changed, from `git log` on each path:

- `capability-registry.schema.json`, `capability-registry.json` and
  `lite-upgrade-reason-catalog.json` — commit
  `e48c9008` (2026-07-23), "feat(epic-190-a2): author Capability Registry
  schema, instance, and lite-upgrade-reason catalog (T-001)". Epic A2's
  Phase 2.
- `facet-manifest.schema.json` — commit `a3a993bc` (2026-07-23),
  "feat(facet-manifest): T-001 schema, validator, and regression suite".
- `capability-summary.schema.json` — commit `de5220c6` (2026-08-17),
  "impl(epic-192-a4-facet-manifest): T-002 Capability Summary schema".
  Epic A4's Phase 2.
- `context-projection.schema.json` — commit `21b1e087` (2026-08-17).

So INV-013's three claims fare differently, and are superseded
individually rather than as a block:

1. **"returns nothing" — false**, six ways, as above.
2. **"the entire Foundation epic set (A0-A6) is presently in the Phase 1
   stage" — false.** A2 and A4 have both shipped Phase 2 artifacts.
3. **"this feature's own REQ-001 is a documented *design* for a schema
   revision, never an edit to a file that exists today" — still true**,
   and untouched by this correction. The file now exists; what REQ-001
   designs is its **v1.1 revision**, which no task in this package
   applies.

**What changed is access, not shape.** Three of the six —
`contracts/capability-registry.schema.json`,
`contracts/capability-registry.json` and
`contracts/lite-upgrade-reason-catalog.json` — are listed today in the
live `plugins/sdd-quality-loop/references/guard-invariants.json` under
**both** `protected_gate_suffixes` and `phase2_human_copy_targets`. The
eventual v1.1 edit is therefore a staged, human-applied change to an
already-R-10-protected file. Per the ruling, that application path is
named as the performing task's responsibility and is deliberately not
designed here.

#### Shape verification: REQ-001's technical content stands

Checked against the live files on 2026-08-25 before the ruling was
sought, so the ruling rests on measurement rather than on the reviewer's
summary:

- `definitions/litePolicy` in the live
  `contracts/capability-registry.schema.json` is `{type: object,
  additionalProperties: false, required: ["eligible"], properties:
  {eligible: boolean, upgrade_reasons: array of string(minLength 1),
  default []}}` — exactly what INV-003 asserts, so the two-key
  `additionalProperties: false` boundary INV-003 says a third key must
  widen is real and is the only one that must widen.
- `definitions/capability` has precisely the nine properties INV-003
  lists (`id`, `trigger`, `required_facets`, `conditional_facets`,
  `review_check_ids`, `gate_ids`, `lite_policy`, `minimum_enforcement`,
  `delivery_strategy`), precisely the seven `required` entries it lists,
  and `additionalProperties: false` — so `lite_policy` and
  `minimum_enforcement` really are the only optional fields, as INV-003
  states.
- `contracts/lite-upgrade-reason-catalog.json` is live at
  `catalog_version: 1` with exactly the five-token seed INV-007
  describes.
- Every `schema` const across `contracts/*.schema.json` is an integer
  `vN` form, so AC-006's design.md citation still holds.

No shape drift. REQ-001, REQ-002, REQ-003, REQ-004, REQ-005 and REQ-006
are unchanged by this entry; only the statements describing the files'
*existence and protection status* are.

#### Sites amended by this entry

Enumerated in full before any of them was written, on the same discipline
the second entry records, and each re-read at its current line before
editing:

- `design.md` header (`:12-16` before this entry) — the self-claim ("no
  live schema file … is authored by this package") kept; the sibling
  claim ("exactly like every sibling Foundation epic's own Phase 1
  package") corrected, not deleted.
- `design.md` Components table row 1 (`:137`) — "not-yet-authored file" /
  "not yet applicable — file does not exist" replaced with "existing
  (A2-owned, shipped `e48c9008` 2026-07-23)" and a `**YES**` Protected?
  cell, making row 1 consistent with row 6, which already read "existing
  (A4-owned, content-frozen)" correctly.
- `design.md` Protected-File Statement (`:302-309`) — the scope statement
  ("this feature's own build scope never touches `contracts/**` at all")
  is unchanged and still true; the sentence it grounds now says that the
  future task's edit targets an already-protected file, and that
  designing its application path belongs to that task.
- `design.md` Cross-Layer Dependencies, REQ-001 (`:328-332`) — "blocked
  until A2's own Phase 2 lands" replaced: A2's Phase 2 landed 2026-07-23,
  and what remains is the v1.1 revision. This was the most load-bearing
  of the stale statements, because it misstated REQ-001's actual
  prerequisite state.
- `design.md` `## Layer Specifications` — see the decision recorded
  below.
- `requirements.md` Dependencies, Epic A2 bullet (`:138-146`) — "that
  file does not exist yet anywhere" replaced with the authorship date and
  the revision framing.
- `requirements.md` Non-goals, first bullet (`:681-689`) — "or do not yet
  exist anywhere" replaced; the four named files exist, three are R-10
  protected, and the application path is named as the performing task's.
- `requirements.md` Assumptions (`:1176-1178`) — the conclusion survives
  and the citation does not. A Capability *Pack* is a distinct artifact
  from the Registry instance (ADR-0018) and none ships, so "every REQ-006
  fixture is synthetic" stands; but `contracts/capability-registry.json`
  now ships one real Capability (`durable-workflow`) with a live
  `lite_policy`, so the claim is weaker than when written. The INV-013
  citation is withdrawn and replaced by that reasoning.
- `traceability.md` REQ-001 row (`:12`) — wording only. Authorship
  happened; the revision is still deferred. The Status column is **not**
  touched and still reads `Deferred`.
- `frontend-spec.md` Epic A2 dependency row (`:39`) — "not yet shipped …
  does not exist yet" replaced. This site is outside the four documents
  `impl-reviewer-b` examined; including it is what stops this correction
  from manufacturing its own left-behind sibling.

#### Decision on design.md's `## Layer Specifications` (adjacent, not INV-013-dependent)

That section read "Not applicable — this feature has no `ux-spec.md`/
`frontend-spec.md`/`infra-spec.md`/`security-spec.md` at this phase". All
four exist and are hash-bound into every impl-review contract's
`layer_sha256`, including the contract of the very round that read the
sentence. `impl-reviewer-a` saw this in attempt 2 round 1 and chose not
to raise it, on the ground that adding layer specs later at
impl-review-prep time is established A2/A4/A5 precedent and that every
layer spec cross-references design.md without contradiction.

**Decided: corrected, not left.** The precedent reviewer A cited is real
and is recorded in the replacement text, but it explains why the specs
were added late, not why a sentence denying their existence should
survive after they were added. The statement is false against the same
round's own precheck manifest, so leaving it would guarantee the next
reviewer re-raises it — the exact failure mode this lane keeps hitting.
It is decided in this pass rather than deferred, and the substance the
sentence stood for (no UI, no new infrastructure, security posture
covered below) is preserved verbatim in the replacement.

#### Fingerprints and statements this third entry supersedes

- `specs/epic-194-a6-lite-integration/design.md`, recorded in the second
  entry above as
  `537ad9b37a8c037e3336cd341bc1d3cf92856546c1c3d8110a6b51e4be9b53d1`, is
  superseded by
  `7ea9df83f848a07f2b1b3a4ab58dd158dac39bc165525fb7e2ad0f3a3b974db6` as of
  this entry's own commit. Both earlier design.md values stay where they
  are: `43d48635…` is the pin impl re-review attempt 2 round 1's two
  reviewers actually read and the pin that contract keeps, and `537ad9b3…`
  is the state after the `DEPLOYMENT-CONCRETE` amendment alone.
- `specs/epic-194-a6-lite-integration/requirements.md` — as of this
  entry's own commit,
  `04d298716ac869b43e85110502e365e86c5acdad3c6ff1e8eabb08a773c79303`. The
  spec-review attempt-3 round-1 pin
  (`c2a0be281775fdd94ce67b09f3e043416f4748ba5f982436cac256ea5080ae41`,
  recorded above as of `e6bfe05800ebcb53be5a6e0333bf28dbaa0814d9`) stays
  as recorded; that contract keeps pinning the bytes it reviewed.
- `specs/epic-194-a6-lite-integration/traceability.md`, pinned in
  "Later-phase artifacts referenced by this package" above at
  `0bdaa87dce92b4075d98874660f82226ab67fc8ad0a82b826c15200eaa30321e` (last
  amended, as of that pin, in commit
  `522a1ccab0cdc08e4094e12a2a84b156caf0dc7f`), is superseded by
  `1ef3e001c9eec54b9eca87663d77badb97897c430c1ca514b766d60a9b8fb6c1` as of
  this entry's own commit. The earlier value stays where it is. Only the
  REQ-001 row's two prose cells changed; no `Status` cell was touched, so
  the row still reads `Deferred` and this is a body edit, not a lifecycle
  transition.
- `specs/epic-194-a6-lite-integration/frontend-spec.md` — as of this
  entry's own commit,
  `f06b45a468321a4a9f9f041d989f6a101a9e19cf9759bd9284f857fedb5377ee`
  (previously `72ae1eee6c95968944772c010ada27f38ca385a1a1a948ae2cd81e26e4eb3499`,
  the value impl re-review attempt 2 round 1's contract pins in its
  `layer_sha256` and keeps).
- This document's own bytes, as pinned by impl re-review attempt 2 round 1
  at `929d112f3f33705c1458cfbd5f67bfa005878673c0807dd5a89c5c9f44830012`
  and grown by the second entry, are superseded again by the revision this
  entry's own commit produces. A document cannot embed its own
  post-amendment hash; that revision is pinned by impl re-review attempt 2
  round 2's invocation manifests. As before, no prior contract is
  restaged or re-validated against amended bytes — each keeps pinning what
  it reviewed, and the workflow-state gate reconciles the difference only
  because this entry, like both before it, is pure growth at this
  section's tail.

### Amendment record extension, fourth entry (appended 2026-08-25): the glossed rulings, recorded verbatim; and the design.md and tasks.md sites a line-based sweep could not reach

Appended below the third entry, on the same terms: nothing above this
heading is edited.

#### Human approval (verbatim, dated) — the rulings this lane recorded only in gloss

`impl-reviewer-a` observed during impl re-review attempt 2 round 2 that
this document records some 2026-08-25 rulings as "option ① as presented"
plus an English gloss, while others carry a verbatim quotation
(`「①でやれ」`, `「① 注記＋design 加筆＋狭いゲート例外」`), and that
`plugins/sdd-review-loop/references/reviewer-calibration.md` requires a
verbatim dated quotation for every element of a declared amendment
re-review. That observation is correct, and the gap was in how the
rulings reached this lane — they were conveyed in prose rather than
passed through as text. The human's selections were made by choosing a
labelled option; the labels are, verbatim, supplied 2026-08-25:

- 2026-08-25, the CI-workflow scoping ruling (the one the second entry
  above executes): 「① スコープを分けて両立させる（推奨）」
- 2026-08-25, the ruling that the premise correction propagate beyond
  the single site where it was found (the label's own count is
  `3 文書`; this entry does not restate which documents that count
  refers to, because the gloss it replaces did not record them):
  「① 3 文書にも波及させる（推奨）」
- 2026-08-25, the INV-013 premise ruling (the one the third entry above
  executes): 「① 前提を直し、適用経路は将来タスクに帰属と明記（推奨）」

The 2026-08-25 quotations recorded in this subsection stand alongside,
and do not replace, the quotations already recorded in this section's own `### Human approval (verbatim, dated)`
subsection and in the first appended entry. No ruling's substance changes
by being quoted; what changes is that the chain of custody is now uniform
across every ruling this lane acted on.

#### Two further INV-013-dependent sites, corrected

impl re-review attempt 2 round 2 returned NEEDS_WORK on one Major finding
from `impl-reviewer-b`: `design.md`'s own `## Assumptions` section, first
bullet, still grounded its sourcing of A2's schema fragments on there
being "no live `contracts/capability-registry.schema.json`", contradicting
the same document's own corrected Cross-Layer Dependencies section. A
sweep run afterwards on whitespace-flattened text confirmed that site and
surfaced one more: `tasks.md`'s Global Constraints quoted a
`requirements.md` Assumptions sentence that no longer exists. The `design.md` site and
the `tasks.md` site are each corrected in this entry's own commit, under the same 2026-08-25 ruling
that governs every other site in the third entry above — a sweep that
could not physically reach a site does not narrow the ruling.

- `design.md` `## Assumptions`, first bullet — the "no live
  `contracts/capability-registry.schema.json`" grounding is retracted and
  replaced with the narrower assumption that actually survives: A2's prose
  and the shipped file agree on every field this design cites, and neither
  is expected to diverge before this feature's own spec review completes.
- `tasks.md` Global Constraints — the bullet quoted "No Capability Pack
  exists yet anywhere in this repository... every fixture this feature's
  REQ-006 names is synthetic, not drawn from a real, shipped Capability",
  which the per-fixture split replaced. The quotation is corrected to the
  split rather than paraphrased into survival, and the bullet is restated
  around the point it actually supported, which the split does not
  disturb: no task is blocked on a real Epic A2, A4 or A5 artifact
  existing. No `Status:` line and no task body was touched.

#### Why twelve sweeps could not reach the design.md site

Recorded because the mechanism, not the miss, is the reusable part. The
phrase spans a line break inside a backticked path: the source reads
`contracts/capability-registry.` then a newline and two spaces, then
``schema.json` exists yet``. Every sweep this lane ran matched line by
line, so no pattern — however well chosen — could ever have hit it. This
is the third distinct sweep defect this package has produced, and each was
a different shape:

1. Sweeping by **phrase** rather than by **predicate**: matching the
   wording the old fact happened to use, which silently misses every
   statement that depended on the fact without repeating its words.
2. Using a **blocklist** of banned referring expressions where an
   **allowlist** over one's own sentences was needed: a blocklist can
   always miss a word, because the space of referring expressions is open.
3. Matching **line by line** against a wrapped document: the pattern space
   was the wrong shape entirely.

The working form combines all three: derive the facts the correction
changes, sweep for statements depending on each fact regardless of
wording, on whitespace-flattened text, then run the per-sentence
enumeration check over whatever is written. Flattening is a property of
the tool, not a fix for one instance — a wrapped document is the normal
case in this repository.

#### Fingerprints this fourth entry supersedes

- `specs/epic-194-a6-lite-integration/design.md`, recorded in the third
  entry above as
  `7ea9df83f848a07f2b1b3a4ab58dd158dac39bc165525fb7e2ad0f3a3b974db6`, is
  superseded by this entry's own commit. Every earlier design.md value
  recorded above stays where it is; in particular `43d48635…` remains the
  pin impl re-review attempt 2 round 1's reviewers read, and the value
  impl re-review attempt 2 round 2's reviewers read remains that round's
  own contract pin.
- `specs/epic-194-a6-lite-integration/tasks.md`, recorded above at
  `d3c7d7e3670f79d7aaee93febd68c4a3a044ce1706b641dec96348ea459376b4`, is
  superseded by this entry's own commit. The earlier value stays where it
  is and remains true of the commit it names.
- This document's own bytes, as pinned by impl re-review attempt 2 round 2,
  are superseded by the revision this entry's own commit produces. A
  document cannot embed its own post-amendment hash; that revision is
  pinned by impl re-review attempt 2 round 3's invocation manifests. As
  before, no prior contract is restaged or re-validated against amended
  bytes, and the workflow-state gate reconciles the difference only
  because this entry, like the first, second and third appended entries
  before it, is pure growth at this section's tail.

### Amendment record extension, fifth entry (appended 2026-08-25): the A/B/C landing, and the runner change behind design.md's fifth contract point

Appended below the fourth entry, on the same terms: nothing above this
heading is edited.

This entry exists because it was missing. `impl-reviewer-a` found, during
impl re-review attempt 3 round 1, that design.md's Protected-File
Statement point 5 cited its authority only as an unelaborated human ruling,
and that this section — the mechanism this package uses to record every
other ruling with full commit hashes, per-document SHA-256 fingerprints and
verbatim dated quotations — carried no entry for the commit that added it.
That was correct: a grep of this document for
`cf631ea748b86fc94f7570907669dc71ae563bfd` returned nothing. Point 5
changes the protected-file human-copy boundary that `security-spec.md`
names B5, so an unverifiable authority there is a real gap, not a
formatting one.

#### Human approval (verbatim, dated) — the rulings behind the fifth point

Both are the human's own words, given 2026-08-25, in the order they were
given:

- 「現在の挙動を文書化するでよい」
- 「君の推奨案で進めよ」

The first authorized documenting the runner's current behaviour. The
second authorized the recommendation put to the human after measurement:
that the runner be **changed** rather than have the gap documented into the
contract as sanctioned design. **The second ruling supersedes the first
ruling's scope**, and that distinction is load-bearing — design.md's point
5 describes a runner that was changed, not one that was merely described.
Recording only the first ruling would misstate what point 5 rests on.

#### What was measured before the second ruling was sought

The T-001 cross-model panel found that
`specs/epic-194-a6-lite-integration/human-copy/apply-protected-files.ps1`
published protected targets one at a time with no rollback, and that on a
mid-batch failure it named only the failing target before throwing. Because
the failure helper throws out of the copy routine, the batch-wide post-copy
pass never ran either. A partial application of protected files was
therefore left both unenumerated and unverified — the state the runner's
own four-point contract exists to prevent.

Documenting that as designed behaviour would have sanctioned it. The
recommendation was to change the runner instead, and the second ruling
authorized that.

#### What the commit landed

`cf631ea748b86fc94f7570907669dc71ae563bfd` (2026-08-25) landed three
frozen-document edits together, because all three needed the same stage
re-pin:

- `specs/epic-194-a6-lite-integration/acceptance-tests.md` — AC-024's
  parenthetical gained a dated qualifier. No criterion changed.
- `specs/epic-194-a6-lite-integration/traceability.md` — the T-003 row
  named two evidence paths that do not exist and never did; replaced with
  the paths that do. `specs/epic-194-a6-lite-integration/traceability.json`
  already carried the correct paths, so the two now agree.
- `specs/epic-194-a6-lite-integration/design.md` — the Protected-File
  Statement gained a fifth point.

The same commit changed the runner itself. Its copy routine now records
publish state, and the entry-point catch reports, before the stack trace,
which targets are installed, which one failed, which were not attempted,
that the installed files are live and were not rolled back, and that
re-running is the recovery. A failure before the copy phase reports instead
that no live file was modified.

The reporting sits in the entry-point catch rather than in the failure
helper or in the copy routine's own catch arms. The failure helper has
roughly twenty call sites and nearly all fire before any copy, so reporting
from there would attach an install report to failures that installed
nothing. The copy routine's catch arms would each need a copy and would
still miss a batch-wide post-copy failure, which is a fully-applied batch
with a corrupt member. The entry-point catch sees every post-copy-phase
failure in one place.

#### Point 4 was documented, not changed

Point 5's second paragraph fixes the scope of point 4 rather than editing
point 4's text. The per-target verification point 4 reads as promising
already exists: the copy routine re-opens each just-renamed file and
re-compares its digest before returning, on both the Unix and the Windows
path. The batch-wide pass is a second check. A third, separate per-target
pass was considered and rejected because it would duplicate the copy
routine's own published-digest check without adding a property. Cost was
not the deciding factor and is not claimed as one.

`impl-reviewer-a` recorded, as a non-blocking readability observation, that
correcting point 4's scope by a forward disclaimer in point 5 rather than
by editing point 4 leaves a reader to hold both passages at once. That
observation stands as recorded; it was judged a readability concern rather
than a contradiction, because point 5 reconciles the two explicitly.

#### Test Strategy item 17, extended

`impl-reviewer-a`'s second finding was that design.md Test Strategy item 17
is the only item mapped to AC-031, and that item 17, AC-031 and the
`specs/epic-194-a6-lite-integration/acceptance-tests.md` row all named only
the exact-set, hash and post-copy properties of contract points 1 through
4. None named point 5's properties, so a future implementation task could
satisfy every traceable criterion for this runner and never build a fixture
for the property the second ruling exists to guarantee. Item 17 is extended
in this entry's own commit to name point 5's properties individually: the
per-target atomic publish with its published digest verified inside the
publish step; the explicit acknowledgment that the batch is not
transactional and has no rollback; live-state reporting on any failure
after the copy phase begins; and recovery by re-running the runner.

#### Amended-document fingerprints added by this entry

As of `cf631ea748b86fc94f7570907669dc71ae563bfd` (the A/B/C landing and the
runner change, 2026-08-25):

- `specs/epic-194-a6-lite-integration/design.md`:
  `7864267708592b65d4b05762e51564734dca213bcc8682e91c29f7d29bb6b105`
- `specs/epic-194-a6-lite-integration/acceptance-tests.md`:
  `77f60bf2d21f085ca656575a0795dbc8877fb5daf838068d5365202ed0d82c2e`
- `specs/epic-194-a6-lite-integration/traceability.md`:
  `8bc33c5363598b181dc6d565703df58500e8149c747be4dbc1fe92de99933003`
- `specs/epic-194-a6-lite-integration/human-copy/apply-protected-files.ps1`:
  `8fc01f58b04618cbcffb2f17cf6e29719e8fd9e6c28e6c141c254a3ee3cd2c5d`

As of `a4800cfad16af2d333883abacb0d07774c7c0bc7` (the AC-024 qualifier
anchored to a commit, 2026-08-25):

- `specs/epic-194-a6-lite-integration/acceptance-tests.md`:
  `8748f5cae5fddc9ccef34c4ab81e7bbb33d644e0c79aaf47c93e712429cf115b`

#### Fingerprints and statements this fifth entry supersedes

- `specs/epic-194-a6-lite-integration/design.md`, recorded in the fourth
  entry above at
  `7ea9df83f848a07f2b1b3a4ab58dd158dac39bc165525fb7e2ad0f3a3b974db6` and
  again in this entry at
  `7864267708592b65d4b05762e51564734dca213bcc8682e91c29f7d29bb6b105` as of
  `cf631ea748b86fc94f7570907669dc71ae563bfd`, is superseded by this entry's
  own commit, which extends Test Strategy item 17. Both earlier values stay
  where they are and each remains true of the commit it names.
- `specs/epic-194-a6-lite-integration/acceptance-tests.md` at
  `77f60bf2d21f085ca656575a0795dbc8877fb5daf838068d5365202ed0d82c2e` is
  superseded by
  `8748f5cae5fddc9ccef34c4ab81e7bbb33d644e0c79aaf47c93e712429cf115b`, both
  recorded above against their own commits.
- This document's own bytes, as pinned by spec-review attempt 6 round 2 and
  by impl re-review attempt 3 round 1, are superseded by the revision this
  entry's own commit produces. A document cannot embed its own
  post-amendment hash; that revision is pinned by impl re-review attempt 3
  round 2's invocation manifests. As with the first, second, third and
  fourth appended entries before it, no prior contract is restaged or
  re-validated against amended bytes, and the workflow-state gate
  reconciles the difference only because this entry is pure growth at this
  section's tail.

### Amendment record extension, sixth entry (appended 2026-08-25): the fifth property item 17 omitted, and security-spec.md's B5 rows

Appended below the fifth entry, on the same terms: nothing above this
heading is edited.

#### The enumeration discipline failed inside the sentence that invoked it

The fifth entry recorded that design.md Test Strategy item 17 had been
extended to name contract point 5's properties "each named here rather
than referred to collectively". It then named **four** of point 5's
**five** properties. `impl-reviewer-b` found the omission in impl
re-review attempt 3 round 2.

That is worth recording as a lesson rather than as an incident. This
package adopted the rule *never refer to a set except by enumerating it*
after three consecutive spec rounds lost to referring expressions, and the
rule was invoked by name in the very clause that then failed it. **Stating
a discipline is not applying it.** The check that catches this is
mechanical — enumerate the source set, enumerate the citing set, diff them
— and it was not run against point 5's own text before item 17 was
written.

The omitted property is not a footnote: a failure *before* the copy phase
begins reports instead that no live file was modified. That is the branch
telling an operator the repository is untouched, which is the answer they
most need and the one they receive least often. Item 17 now names it, and
says so.

#### `security-spec.md`'s B5 rows, extended

`impl-reviewer-b`'s same finding also reported that `security-spec.md`'s
B5 STRIDE row and its Security Tests row predated the commit that added
point 5 and therefore did not reflect it. B5's threat text describes "a
`cp` that silently fails partway, installs bytes that do not match the
reviewed, hash-verified payload" — which is exactly point 5's scenario, so
the security analysis of that boundary was being judged against a runner
that no longer exists. Both rows are extended in this entry's own commit
to name point 5's properties individually.

**A correction to the finding's own evidence.** The reviewer attributed
`security-spec.md`'s last amendment to commit
`23fe659f57685c5e7dde304035ce8887658d86bc`. `git log` shows it was
`ac7a2e649427aeb042fac872e03debbe5472cbe4`, which is what `git log -1` reports for that path. Either way both predate
`cf631ea748b86fc94f7570907669dc71ae563bfd`, so the finding holds on its
own terms and the misattribution changes nothing about it. It is corrected
rather than adopted.

#### The enumerated sweep, including the sites deliberately left alone

Run before writing, by listing candidate sites rather than searching for a
phrase — the third time in this feature that extending one document
revealed a sibling, and each earlier one was found by a reviewer after the
fact rather than by a sweep before.

- `design.md` Protected-File Statement points 1, 2, 3 and 4 — **left**.
  Points 1 through 3 describe exact-set, manifest and pre-copy hash
  properties that point 5 does not disturb. Point 4's scope is corrected
  by point 5's forward disclaimer rather than by editing point 4, which
  `impl-reviewer-a` recorded in round 1 as a non-blocking readability
  observation and which stands as recorded.
- `design.md` Protected-File Statement point 5 — **left**. It is the
  authority the other sites cite.
- `design.md` Test Strategy item 17 — **amended**, adding the fifth
  property.
- `security-spec.md` B5 STRIDE row — **amended**.
- `security-spec.md` Security Tests row for item 17 — **amended**.
- `requirements.md` AC-031 — **left**. It names the exact-set contract and
  cross-references design.md; the ruling's remedy was item 17. See the
  fragility recorded below.
- `acceptance-tests.md`'s AC-031 row — **left**, for the same reason.
- `infra-spec.md` Rollback and Verification-after-rollback — **left**.
  Its protected-path sentence cites B5's post-copy re-verification as the
  check that a corrected, re-applied state is self-consistent. That is a
  claim about the success path after a re-apply and is unaffected by point
  5, and its citation of B5 stays accurate as B5 grows.
- `tasks.md` T-001's Reference Files block — **reported, not amended**. It
  cites design.md's "full four-point contract", a count that point 5 makes
  stale. `tasks.md` is frozen and outside the authorization for this
  entry, so it is recorded here rather than changed.
- `specs/epic-194-a6-lite-integration/README.md` — **left**. It contains
  no statement about runner failure behaviour, repository state after a
  failure, or what the operator learns.

#### A fragility recorded, not changed

`impl-reviewer-b` observed that `requirements.md` AC-031 and the
`acceptance-tests.md` AC-031 row both rely entirely on a cross-reference
to design.md Test Strategy item 17, which makes item 17's completeness the
sole guarantee that the runner's contract is covered. That is exactly how
the omitted fifth property escaped: nothing else in the package would have
caught it. The structure is recorded here as a fragility. Changing it
would mean amending two more frozen documents and was not authorized.

#### Known, unreachable citation debt in this section

The mechanical checklist run over this whole section reports abbreviated
commit-like tokens. Five are genuinely abbreviated commit references, all
introduced by this lane's own third appended entry:
`e48c9008`, `a3a993bc`, `de5220c6`, `21b1e087`, `b085ec76`. They cannot be
corrected: they sit above this section's tail, and editing there would
break the growth-only shape the spec stage's tolerance depends on. They
are recorded here so a future reader finds them already identified rather
than discovering them as new.

Three further tokens the same run flags — `43d48635`, `537ad9b3` and
`fe78fa61` — are **not** defects: they are SHA-256 prefixes used in prose,
which the checker's hex-run pattern reads as commit references. Several
unaccounted SHA-256 values are likewise checker gaps rather than document
defects, because that run walked a fixed path list at cited commits and so
could never resolve `specs/epic-194-a6-lite-integration/traceability.json`
or the T-001 panelist verdict files.

#### A derived artifact, disclosed

impl re-review attempt 3 round 1 was halted after `impl-reviewer-a` and
before `impl-reviewer-b`, so that round's `integrated-summary.json` was
never produced. Round 2's reviewer-A manifest requires the previous
round's summary, so it was derived afterwards from round 1's persisted
`reviewer-a.json` — a deterministic function of an immutable report,
carrying no narrative — and `impl-reviewer-a` was told so in its round-2
launch prompt.

#### Fingerprints and statements this sixth entry supersedes

- `specs/epic-194-a6-lite-integration/design.md`, recorded in the fifth
  entry above at
  `7864267708592b65d4b05762e51564734dca213bcc8682e91c29f7d29bb6b105` as of
  `cf631ea748b86fc94f7570907669dc71ae563bfd`, is superseded by this
  entry's own commit. Every earlier design.md value recorded in this
  section stays where it is and each remains true of the commit it names.
- `specs/epic-194-a6-lite-integration/security-spec.md` is superseded by
  this entry's own commit; the value it held before this commit remains
  true of the commit that last set it.
- This document's own bytes, as pinned by spec-review attempt 6 round 2
  and by impl re-review attempt 3 round 2, are superseded by the revision
  this entry's own commit produces. A document cannot embed its own
  post-amendment hash; that revision is pinned by impl re-review attempt 3
  round 3's invocation manifests. As with the first, second, third, fourth
  and fifth appended entries before it, no prior contract is restaged or
  re-validated against amended bytes, and the workflow-state gate
  reconciles the difference only because this entry is pure growth at this
  section's tail.

## INV-022: The pre-widening four-target payload cap forced the batch's own CI-workflow candidate onto a bare-`cp` route the design's own runner contract exists to forbid — the requirement-level reason `.github/workflows/test.yml` is a declared payload target

Recorded 2026-08-23, in this document's amendment-context era (see
`## Amendment Re-Review Context`, above), grounding the five-target
declared payload set's fifth member in this feature's own scope.

**The panel finding.** Both vendor slots of the T-001 blind cross-model
panel — reviewing independently, neither seeing the other's output —
raised the same pair of Major findings (2026-08-21):

- `specs/epic-194-a6-lite-integration/verification/T-001.panelist-anthropic.verdict.json`
  — SHA-256
  `18471b6023754934a8f1b371c78f7fe222a3b27b4fee298ce122bdd2294f0da7`,
  recorded in commit `89a0700d42e8badf348f8d9322417ff0044c8043`.
- `specs/epic-194-a6-lite-integration/verification/T-001.panelist-openai.verdict.json`
  — SHA-256
  `37d15b1811698a4f3639fac438fb9ab18beec2615d6b1265ddcbd92e29cfb9aa`,
  recorded in commit `2461da5d08a6cb90d36e338dc5291d89ff217dda`.

The finding, seen from its two ends: `tasks.md`'s own Protected Files
item 3 (tasks.md:68, "`.github/workflows/test.yml` (R-10 protected)";
tasks.md — SHA-256
`b1ab0ddd49ab36badcfd0906a79158d24aaf8673612ea3e4b5b127c4611846d1`,
last amended in commit `4fea3d64123a5ae14da2b5c3b4ce103b92aeb143`)
directs every task registering a test pair to stage its CI steps under
this feature's `human-copy/` directory and commits the runner to applying
that staged candidate "the same way it applies the four payload files" —
while the pre-widening AC-010 capped the payload set at exactly four.
`Test-ExactSet` therefore rejected the real staged tree: the runner could
never complete one successful run against the directory it exists to
apply. The then-staged README's documented workaround directed a human to
remove the extras and bare-`cp` the CI file to its R-10-protected live
path — no `MANIFEST.sha256` entry, no pre-copy hash check, no post-copy
re-verification.

**Conclusion (the investigation's own).** That workaround is exactly the
operation the design's runner contract exists to forbid: design.md's
Protected-File Statement requires per-target hash verification before any
copy and post-copy re-verification of every installed file's own hash —
"never a bare `cp` with no confirmation the bytes actually landed
correctly" (design.md:262; the five-target amendment commit's own message
refers to this same discipline as its STRIDE tampering row, B5). An
R-10-protected CI workflow file was reaching the live tree outside any
integrity mechanism. The requirement-level consequence: any CI-workflow
candidate this feature stages must ride the same exact-set /
`MANIFEST.sha256` / post-copy re-verification envelope as the other four
payload targets — which is precisely what the five-target widening
(commit
`9997091c71244e8cf3f9e46732f7ba164aa49843`) implements, and what its
commit message demonstrates by measurement: the real committed staging
directory copied byte-for-byte into a scratch root, the actual runner
invoked out-of-process, exit `0`, and every one of the five installed
files verified byte-identical to its staged source afterwards, including
the CI workflow, "which now gets the same integrity envelope as the
rest."

### Amendment record extension, seventh entry (appended 2026-08-28): design.md 2b/2c ratify the upgrade_reasons validation that 2499e813 already implemented

Appended below the sixth entry, on the same terms: nothing above this
heading is edited.

Owner approval, verbatim (2026-08-28): 「design.md 2b/2c を amendment
レーンで追認する」. Adjudication trail: docs/review-tickets/
RT-20260828-001.yml (severity Major, owner-ruled 2026-08-28).

#### What was stale, and how it was found

The 2026-08-25 remediation commit `2499e813` added, to both
`check-risk-upgrade` twins, validation of `upgrade_reasons` — a
present-and-truthy value must be an array, and every element must be a
non-empty string matching `[a-z0-9][a-z0-9_-]*` — closing a measured
trigger-forgery (`["evil,forged"]` → a forged second trigger entry;
`["x; triggers=NONE"]` / `["x\ntriggers=NONE"]` → a broken single-line
record; the exact attack the id grammar already blocks, TEST-013m/n/p)
and a silent sh/ps1 stringifier divergence on null/object/nested-array
shapes. design.md's Processing step 2b enumerated its invalid conditions
exhaustively WITHOUT these two, and step 2c said upgrade_reasons tokens
are "not re-validated here" flatly. The design text predated the
remediation and never caught up.

The staleness surfaced through the 2026-08-27/28 cross-model panel: all
three vendors flagged the `eligible: true` validation gap (OpenAI and
Google as Critical, Anthropic as Minor); the owner adjudicated it Major;
a peer session (sdd-forge-42) then observed that the implementation's
branch comment quotes design.md's own `entry['eligible'] == false`
verbatim, which reframed a "code defect" as a specification-staleness
defect, and the `git log` pull over `2499e813` settled the direction:
deleting the checks to match the design text would reintroduce a proven
injection.

#### What the amendment changes (five sites: design.md four, requirements.md one)

1. Step 2b's invalid-condition enumeration gains the two ratified
   conditions, applying to EVERY entry regardless of `eligible`, because
   2b runs before eligibility is consulted. A present-but-falsy
   `upgrade_reasons` (false, 0, "", [], null) is treated as absent —
   ratifying the live twins' measured behavior — and only a present,
   truthy non-array value, or a malformed element inside a real array,
   is shape-invalid.
2. Step 2c's parenthetical rescopes "not re-validated here" to catalog
   membership alone.
3. The Data Plan paragraph (the `eligible: true` / `eligible: false`
   contribution rules) rescopes its own copy of the same sentence
   identically — the sibling that a 2b/2c-only sweep would have missed
   (the propagation-defect class this package has hit nine times).
4. The Design Decisions bullet "No re-validation inside
   check-risk-upgrade" now states the scoping and corrects the script's
   self-description from "a keyword scanner plus a trivial merge step"
   to include the eager shape/grammar gate.
5. requirements.md's REQ-002 input-state 2 parenthetical — the same
   invalid-condition enumeration, found by the pre-edit sibling sweep —
   gains the identical two conditions. This is an alignment, not a new
   claim: the Field Definitions shape that parenthetical cites has
   always declared `upgrade_reasons` as an array of tokens; only the
   summary enumeration was narrower than its referent.

#### What the amendment deliberately does NOT do

It does not ratify the validation's current PLACEMENT. Both twins today
run the ratified checks inside the `eligible == false` branch, so a
shape-invalid `upgrade_reasons` on an `eligible: true` entry is silently
accepted (exit 0, lite-eligible) where amended 2b requires exit 2. That
is a conformance fail-open, not an exposure — both token-emitting sites
sit inside the false branch, so nothing malformed can reach the output
record — but it is a spec-vs-implementation delta this amendment
KNOWINGLY creates, recorded in RT-20260828-001 stage 2: move the checks
ahead of the eligibility test in both twins, through human-copy staging,
a reissued MANIFEST.sha256, and a second HUMAN APPLY STEP (the payload
was applied live on 2026-08-28, so a fix reaches the live tree no other
way). The regression fixture for that change must assert exit 2 — never
"no forged tokens appear in the record", which passes today against the
live defect.
