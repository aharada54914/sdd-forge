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
- `f8cfd7a1febd54ff805cd05f2a7490bac6c62a3a` — mechanically annotated
  design.md's existing passages with AC-ID labels for seven of the eleven
  IDs the impl-review AC-coverage precheck names (AC-001/003/009/012/014/
  017/021), substance unchanged, per the 2026-08-24 human ruling quoted
  below; the remaining four IDs (AC-006, AC-010, AC-023, AC-024) were
  left unannotated in that commit (2026-08-24). **The reason that bullet
  originally gave — "the four IDs whose substance design.md does not
  contain" — was wrong for AC-010 and is corrected in the next bullet.**
- This entry's own commit (the AC-006/AC-010 design amendment,
  2026-08-24; its own hash is pinned by the impl re-review round's
  manifests under the same self-pinning disclosure this section already
  applies to `investigation.md`, since a commit cannot embed its own
  hash) — three edits to design.md and the corrections recorded here,
  all under the same 2026-08-24 ruling quoted below:
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
     is therefore explicitly scoped to the design-content clause, and a
     dated note in the same Statement records that the target count is
     superseded by requirements.md AC-010 and not discharged there.
  2. **The 2026-08-21 five-target widening was never propagated into
     design.md — recorded, not silently repaired.** Commits
     `9997091c71244e8cf3f9e46732f7ba164aa49843` and
     `fae561c9d323cf32914f6885cb6f3d24053bd9af` widened
     acceptance-tests.md AC-010/TEST-031 and requirements.md
     AC-010/AC-031 to five targets; README.md follows them. design.md
     does not: it still states four at its Components table, at its
     Protected-File Statement (the payload-set definition and exact-set
     contract item 2), and at Test Strategy item 17 — where its
     pre-existing `(requirements.md AC-031)` citation, written by
     `32b8bf57` **before** the widening, has been stale ever since.
     Propagating five targets would change the runner contract design.md
     fixes, which the annotation-scoped 2026-08-24 ruling does not
     authorize; this commit therefore records the divergence in design.md
     and here rather than closing it. Closing it needs its own human
     ruling.
  3. **AC-006 — substance added.** design.md carried no trace of this
     criterion (`grep` for `decimal` and for `capability-registry/v1`
     returned nothing), so no annotation could discharge it and a minimum
     true statement was written into the Data Plan's `lite_policy` (v1.1)
     entry instead. **This is a substance addition, not a mechanical
     annotation, and therefore goes beyond the "substance unchanged"
     wording of the 2026-08-24 ruling as quoted below** — disclosed here
     rather than folded in silently, for the blind impl re-review to
     judge. Its factual claim was verified against the live contract
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
  4. **Correction to `d5e8d143b1d7b8ef00dcfd3b69726bd065dbdd90`'s commit
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

As of this entry's own commit (the AC-006/AC-010 design amendment,
2026-08-24 — the commit that adds the four numbered items to the
amendment list above; its own commit hash cannot be embedded in itself
and is pinned by the impl re-review round's manifests, the same
self-pinning handling the closing paragraph of this subsection states):

- `specs/epic-194-a6-lite-integration/design.md`:
  `c57b197e74838acd883928eaedc13e22eca2cc25c4c40fc34e14690fad375c14`

This `investigation.md` is itself amended by the commits that introduce and
extend this section; a document cannot embed its own post-amendment hash, so
each such revision's fingerprint is pinned instead by the reviewer
invocation manifests and evidence commits of the review round that
reviewed it (attempt 2 round 3 for the first revision; spec-review
attempt 3 round 1 for the `fe78fa61` revision; the impl re-review round's
manifests for this one — with the disclosed fixed-point handling: prior
contracts validate against the bytes they reviewed, restored temporarily
for that validation only, and the new round's manifests pin the amended
bytes).

### Human approval (verbatim, dated)

- 2026-08-23: 「194/195/196の凍結文書について人間は承認する」
- 2026-08-23: 「限定デプロイ + WFI 起票でやれ」 (authorizing limited
  deployment of this amendment re-review lane for epic-194 and epic-195,
  plus a workflow-improvement filing for the durable mechanism)
- 2026-08-24: 「①でやれ」 (option ① as presented: mechanically annotate
  design.md's existing passages with the AC-ID labels the post-freeze
  impl-review AC-coverage gate requires, substance unchanged, honesty of
  the annotations verified by the blind impl re-review that follows; the
  same ruling applies to epic-195)

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
