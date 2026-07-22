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

## OQ-001: Should `lite-gate/SKILL.md` be newly registered as a protected file, given REQ-004's extension to it?

INV-008 confirms `lite-gate/SKILL.md` is not currently in `guard-invariants.
json`'s protected-file inventory, and neither ADR-0022 nor decision
document v2 §6 names it as protected. This feature's own REQ-004 extends
`lite-gate/SKILL.md`'s Process to execute Registry-sourced Lite-specific
checks — a change to the file that determines what counts as a passing
Lite quality gate, arguably as enforcement-critical as the four files
ADR-0022 item 5 already protects. This package does not decide, on its own
authority, to expand the protected-file inventory beyond what ADR-0022
already fixed (that would be an independent design judgment this task's
own instructions ask this feature not to make); `requirements.md`'s Open
Questions restates this for human/spec-review ruling, and this feature's
own design (REQ-004) proceeds on the ADR-0022-literal, `guard-invariants.
json`-confirmed basis — a direct edit to `lite-gate/SKILL.md`, not a
human-copy one — unless and until that ruling adds it to the protected set.

## OQ-002: What supplies a Capability-aware signal at `lite-spec`'s pre-generation Risk-Upgrade Gate, before any Feature-specific code diff exists?

INV-010 establishes that `lite-spec`'s Risk-Upgrade Gate runs before any
`specs/<feature>/` file exists — necessarily before Epic A3's
`resolve-component-paths`/Epic A5's Resolver has a Feature-specific git
diff to compute `affected_components` from (the Resolver's own `--feature`
and `--target-rev` inputs presuppose a Feature already has a diff to
resolve against). No sibling epic's spec, ADR, or the decision document
itself states how Capability matching is supposed to produce a signal at a
point in the flow that precedes the very computation (`affected_
components`) every existing Capability-matching mechanism (A2's
`evaluate-predicate`, A5's Resolver) depends on. `requirements.md`'s Open
Questions names two candidate resolutions this investigation identifies
without selecting between them (matching this task's own instruction not
to add independent design judgment where the正本 is silent): (a) evaluate
Registry `trigger`s directly against every component the Project Context
already *declares* (Epic A1, static, diff-independent), rather than
against a diff-scoped `affected_components` subset; or (b) scope this
feature's own Capability-aware forced-upgrade check to the *existing*
second invocation point only (`ship`'s pre-selection recheck, INV-010),
where a real code diff already exists, and leave the pre-generation gate's
own Capability-awareness as a no-op until a Feature-specific diff exists.
This is the single largest open design question this package carries
forward to spec review.

## OQ-003: Does `full_upgrade_required` in a written Capability Summary require any `lite-gate`-side re-check, or is it purely an upstream (pre-generation) signal that already prevented `lite-gate` from ever running?

A4's `capability-summary.schema.json` (INV-005) fixes `full_upgrade_
required` as a required boolean field on every Capability Summary A5's
Resolver writes. Because A5's own Lite-track resolve path Blocks
(`lite-check-source-undefined`) whenever a matched Capability needs a Lite
check the Registry cannot yet source (INV-004), and because REQ-005's own
full-upgrade Block is scoped to the same pre-generation position as the
existing Risk-Upgrade Gate (decision document v2 §19's own literal Epic A6
line), it is not self-evident from any正本 text whether a *written*
Capability Summary can ever legitimately carry `full_upgrade_required:
true` in practice, or whether that field exists purely for forward-
compatibility / defense-in-depth. `requirements.md`'s Open Questions
restates this narrowly, scoped to whether REQ-003/REQ-004's `lite-gate`
extension needs its own `full_upgrade_required` re-check (a second,
independent enforcement point) or may treat a written Capability Summary's
mere existence as proof the Feature already cleared every full-upgrade
determination upstream.
