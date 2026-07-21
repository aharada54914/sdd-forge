# Investigation: epic-191-a3-path-ownership (issue #191 — Epic A3: Component Path Ownership)

Source: issue #191 (Epic A3), tracked under issue #187 (AI-DLC Foundation) and
issue #188 (Epic A0 — Architecture Decisions, PR #198). Investigated:
2026-07-21, worktree `feature/epic-191-a3-path-ownership`, read-only survey
with file:line evidence. Paths cited relative to the repository root.

Primary source of truth: `docs/ai-dlc-foundation-decision-v2.md` §12 (Q11 —
affected_components under-reporting, Reverse Coverage Gate, git diff basis),
§16 (Q15 — `ownership_digest` staleness binding), §19 (Epic A3 scope), and
ADR-0021 (`docs/adr/0021-context-projection-staleness.md`) / ADR-0016
(`docs/adr/0016-workflow-axes-separation.md`, prerequisite axis separation).
This investigation records only repository-state facts that the decision
document itself does not already settle.

## INV-001: No component path resolver or Reverse Coverage Gate exists today

`grep -rn "check-component-coverage" --include="*.md" --include="*.py"
--include="*.sh" --include="*.ps1" .` (repository root) returns matches only
in `docs/ai-dlc-foundation-decision-v2.md:104,387` and
`docs/adr/0017-gate-stage-model.md:43`, `docs/adr/0018-provider-binding-separation.md:91`,
`docs/adr/0021-context-projection-staleness.md:96,144` — all forward
references in planning documents. No `check-component-coverage.{sh,ps1,py}`,
no `resolve-component-paths.*`, and no test suite named for either exists
under `plugins/` or `tests/`. This is greenfield script work.

## INV-002: No `project-context.yaml` or its schema exists today

`find . -iname "*project-context*" -not -path "./.git/*"` returns no
results, and `ls contracts/` (see INV-010 below for the full listing)
contains no `project-context*.schema.json`. Epic A1 (Project Context,
issue referenced in decision-document v2 §19 as the epic that owns
`sdd/project-context.yaml`'s schema, including `components[].paths` and
`shared_paths`) has not landed in this repository as of this investigation.
Per the task's scope boundary, this feature treats the `paths`/`shared_paths`
field shapes shown in decision-document v2 §12 as the authoritative shape to
consume, and does not redefine or duplicate that schema (see requirements.md
Dependencies).

## INV-003: No Facet Manifest schema exists today (Epic A4, sequenced after A3)

`find . -iname "*facet-manifest*" -not -path "./.git/*"` returns no
results. Decision-document v2 §12's own pseudocode
(`git diff path → component path resolver → affected component →
facet-manifest.affected_components`) means the Reverse Coverage Gate's
Fail-2 ("changed component missing from the manifest") and Fail-4 ("shared
path's declared components missing from the manifest") conditions compare
the resolver's output against a Facet Manifest field that a *later* epic
(§19 Epic A4) defines. This is a genuine forward dependency created by the
decision document's own epic ordering (§19: A1 → A2 → A3 → A4 → A5), not an
oversight of this investigation — see requirements.md Dependencies and
design.md Assumptions for how this feature isolates the parts of the Gate
that do not need Facet Manifest from the parts that do.

## INV-004: No Provider Bindings file exists today

`find . -iname "*provider-binding*" -not -path "./.git/*"` returns only
`docs/adr/0018-provider-binding-separation.md` (the ADR, a planning
document) — no `sdd/provider-bindings.yaml` or its schema exists. Fail-6
("Provider Adapter change not reflected in Provider Binding",
decision-document v2 §12) therefore has nothing to check against in this
repository today; see requirements.md REQ-004 for how Fail-6 is scoped as
conditional/N/A when this file is absent, consistent with Provider Binding
being optional per-component (decision-document v2 §5 Q4).

## INV-005: `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` is not a protected file

`grep -n "quality-gate/SKILL.md" plugins/sdd-quality-loop/references/guard-invariants.json`
returns no match. The file's own two `SKILL.md` protected entries are
`plugins/sdd-ship/skills/ship/SKILL.md` (line 33) and
`plugins/sdd-lite/skills/lite-spec/SKILL.md` (line 37) — a different
plugin's `SKILL.md` in each case
(`plugins/sdd-review-loop/skills/{impl,task}-review-loop/SKILL.md` are also
listed, lines not reproduced here, and are likewise a different plugin).
`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` (the
generated module `sdd-hook-guard.py:891`'s `_load_guard_invariants()`
loads) confirms the same absence: `grep -n "quality-gate"
plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` returns no
match. Documenting the new Reverse Coverage Gate check inside
`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md`'s existing
`## Process` section (`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:30-204`)
is therefore a direct, unprotected agent edit — it does NOT require the
human-copy procedure. This is a live-repository snapshot, re-verified at
this investigation's time, not a permanent guarantee (see requirements.md
Assumptions; every task that edits this file re-verifies at its own
implementation-start time).

## INV-006: Implementation Gate scripts of this kind are the protected precedent

`plugins/sdd-quality-loop/references/guard-invariants.json:14-19` lists
`check-contract.sh`, `check-contract.ps1`, `check-contract.py`,
`check-evidence-bundle.sh`, `check-evidence-bundle.ps1`, and
`check-evidence-bundle.py` as R-10 protected
(`PROTECTED_GATE_SUFFIXES`) — these are the two existing Implementation
Gate check scripts most similar in role to the new Reverse Coverage Gate
(both are deterministic, security-relevant validators the Implementation
Gate depends on; decision-document v2 §3.1 lists
`check-component-coverage` alongside them: "componentとgit diffの整合性
（check-component-coverage、§12） / 設計契約 / 単体・結合・回帰テスト"). No
`check-component-coverage.*` file exists yet (INV-001), so it is not
currently in `PROTECTED_GATE_SUFFIXES` — but design.md records the design
decision to add it there by the same precedent, which means editing
`plugins/sdd-quality-loop/references/guard-invariants.json` itself, which
IS already protected (`guard-invariants.json:34`, self-referential entry
`"plugins/sdd-quality-loop/references/guard-invariants.json"`), and so is
`plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`
(`guard-invariants.json:35`) and every file under
`plugins/sdd-quality-loop/scripts/generated/` (`guard-invariants.json:36-39`).
Registering the new Gate script as protected is therefore itself a
protected-file change requiring the human-copy procedure (ADR-0011;
precedent below, INV-007).

## INV-007: Human-copy precedent

`specs/epic-136-phase2-gates/human-copy/` contains `MANIFEST.sha256` (one
SHA-256 line per staged file) and `apply-protected-files.ps1`, alongside
`plugins/` and `specs/` subtrees holding the staged candidate content for
each of that feature's protected-file targets — this is the established
staging shape (ADR-0011,
`docs/adr/0011-phase2-handle-relative-protected-copy.md`).
`specs/epic-159-pillar-c/design.md:110-167` (Protected-File Statement)
documents the same pattern applied to a *different* file
(`.github/workflows/test.yml`, which became protected between that
feature's round 1 and round 2): stage full corrected content under
`specs/<feature>/human-copy/<real-relative-path>`, update the same
`MANIFEST.sha256`, never open the real protected path for write, and
require a human `cp` + SHA-256 verification before the task can be marked
Done. This feature's Gate-registration work (design.md; the corresponding
task is deferred to this feature's Phase 2 task decomposition, per
INV-012) follows this same shape for `guard-invariants.json` +
`generate-guard-invariants.py` (**edited, not merely read** — see
INV-015, this investigation's own earlier "unchanged, read-only input"
characterization was wrong) + `generated/guard_invariants.py` + the three
`generated/guard-invariants.generated.{js,ps1,sh}` siblings — six files
total, staged together as one unit since they are produced by one
generator run.

## INV-015: `generate-guard-invariants.py` itself must be edited to add a new protected suffix, and the epic-136 precedent already did so

`plugins/sdd-quality-loop/scripts/generate-guard-invariants.py:37-56` fixes
`PHASE2_TARGETS` as a hardcoded tuple, and `:57-88` fixes `BASELINE_SUFFIXES`
likewise; `load_and_validate()` (`:129-147`) computes `expected_protected =
BASELINE_SUFFIXES + (entries of PHASE2_TARGETS not already in
BASELINE_SUFFIXES)` and raises `ValueError("protected_gate_suffixes must be
the exact baseline/inventory union")` (`:145-147`) the moment
`guard-invariants.json`'s `protected_gate_suffixes` array is not
byte-for-byte equal to that computed tuple — **before** `--check`
(`:271-291`) ever compares generated output for staleness. Adding
`check-component-coverage.{sh,ps1,py}` to `guard-invariants.json` without
also adding the identical three entries to `generate-guard-invariants.py`'s
own `PHASE2_TARGETS` tuple therefore makes `load_and_validate()` reject the
edited JSON outright — `--check` would never even reach its staleness
comparison. This corrects this investigation's own earlier INV-007/INV-006
characterization of `generate-guard-invariants.py` as "unchanged, read-only
input": it is a sixth file this feature's Gate-registration work must edit
and stage. The epic-136 precedent already did exactly this —
`specs/epic-136-phase2-gates/human-copy/MANIFEST.sha256` carries a line for
`plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`
(`827d154754599f6231445fad6056c17700bb371e72f01346b56d0147ce4facc7`), and
`specs/epic-136-phase2-gates/human-copy/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`
exists as staged content — so this feature's requirements.md/design.md
mischaracterized its own established precedent, not merely a hypothetical
edge case.

## INV-016: ADR-0016 fixes the derivation source `check-component-coverage`'s applicability must use — never file presence

`docs/adr/0016-workflow-axes-separation.md:17-26` states the ADR's whole
premise: "Prior designs risked using incidental file existence … as an
implicit mode-selection variable," which "makes mode detection depend on
accidents of what happens to exist on disk." `:30-39` fixes three
explicit, single-valued `workflow.*` axes (`spec_profile`,
`artifact_layout`, `capability_enforcement: advisory | required`) read
from `project-context.yaml` as the sole source of truth (`:56-67`), with a
file-existence fallback used ONLY for the compatibility case where
`project-context.yaml` itself is absent. `:68-75` redefines
`disabled-legacy` as a **derived internal state** ("the entire capability
evaluation pipeline is inactive… the Resolver, the Registry, the Gate
stage machinery… do not run at all — they are outside that computation's
domain"), and `:90-93` requires "any component that consults
`capability_enforcement`" to "first check whether the capability pipeline
is in the `disabled-legacy` derived state." This feature's original
requirements.md/design.md instead used the presence/absence of a Facet
Manifest *file* as `check-component-coverage`'s mode selector — precisely
the anti-pattern ADR-0016 forbids — and must instead derive the Gate's
own applicability from `workflow.capability_enforcement`/`disabled-legacy`,
per requirements.md REQ-004 (revised).

## INV-017: an existing protected required-check-set mechanism already solves "unprotected caller can bypass a protected script"

`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:30-75` (`## Process`,
unprotected, INV-005) step 6 is agent-followed *instructional* text — an
agent could delete or rename its `check-component-coverage` bullet without
touching any protected file. But `plugins/sdd-quality-loop/references/risk-gate-matrix.md:80-92`
already defines the pattern this feature reuses instead: a machine-form
`Required check ids` set per risk tier that `check-contract` (itself R-10
protected, `guard-invariants.json:14-16`) independently enforces as a
contract-required superset, verified equal to `risk-gate-matrix.md`'s own
text by `tests/gates.tests.sh` T-003 (also R-10 protected,
`guard-invariants.json:20`) per `risk-gate-matrix.md:9-11`'s own invariant
note. Registering `check-component-coverage` into that already-protected
required-check-set (rather than relying solely on `PROTECTED_GATE_SUFFIXES`
suffix protection of the script's own content) closes the gap INV-005's
"direct, unprotected edit" of `quality-gate/SKILL.md` would otherwise leave
open: deleting the SKILL.md bullet no longer removes the Gate's
enforcement, because `check-contract`'s protected required-check-set
still refuses a `high`/`critical` contract lacking a passing
`check-component-coverage` evidence entry.

## INV-008: Script convention — Python master + sh/ps1 wrappers

`plugins/sdd-quality-loop/scripts/sdd-hook-guard.{py,sh,ps1,js}` and
`plugins/sdd-quality-loop/scripts/check-contract.{py,sh,ps1}` (confirmed via
`ls`) are both existing four-and-three-file examples of this repository's
established convention: one Python "master" implementation plus thin
POSIX-shell / PowerShell (/ JavaScript, for the Codex-facing case)
wrapper scripts that invoke it. `check-evidence-bundle.{sh,ps1}` exist
without a `check-evidence-bundle.py` master (`ls
plugins/sdd-quality-loop/scripts/check-evidence-bundle.*` shows only the
two), an existing repository inconsistency this feature's new
`resolve-component-paths.*` / `check-component-coverage.*` scripts do not
replicate — this feature's design.md specifies a Python master for both,
consistent with decision-document v2 §18.3's own instruction ("実装は
Python 単一実装 + sh / ps1 / js の薄いラッパー…ランタイムごとの再実装をしない").

## INV-009: Fixture directory convention

`tests/fixtures/workflow-state/` (six `invalid-registry-*.json` files) and
`tests/fixtures/phase2-contract-path-golden/` (with `evidence/`,
`green_evidence/`, `red_evidence/` subdirectories) are the established
shape: `tests/fixtures/<suite-name>/...`. This feature's monorepo fixture
follows the same convention at `tests/fixtures/component-path-ownership/`.

## INV-010: 3-OS / sh+ps1 twin test registration

`tests/run-all.sh:7-42` (partial listing) registers suites as a bash array
consumed in CI order; `.github/workflows/test.yml` registers matching
`bash ./tests/<suite>.tests.sh` and `./tests/<suite>.tests.ps1` steps as
separate CI steps (confirmed for the existing `agent-model-routing` pair at
`.github/workflows/test.yml:148,152`). `.github/workflows/test.yml` is
itself R-10 protected (`plugins/sdd-quality-loop/references/guard-invariants.json:40`:
`".github/workflows/test.yml"`), so any new suite's CI-step registration
follows the same human-copy staging as INV-006/INV-007, while
`tests/run-all.sh`/`.ps1` (not in the protected list) are direct edits.

## INV-011: `workflow-state-registry.json` entry shape for a new "full"-profile feature

`contracts/workflow-state-registry.schema.json` (`definitions.entry`)
defines a non-legacy entry as exactly `{"feature": <slug>, "profile": "full"}`
or `{"feature": <slug>, "profile": "lite"}` — no additional fields are
permitted (`additionalProperties: false`). `specs/workflow-state-registry.json`'s
existing `epic-159-pillar-a`/`-a2`/`-b`/`-c`/`-d` entries (verified via
`python3 -c "..."` filter over the file) are all exactly this two-key
shape. This feature's registration entry is
`{"feature": "epic-191-a3-path-ownership", "profile": "full"}`.

## INV-012: `check-workflow-state.sh` validation semantics for a spec-phase feature

`plugins/sdd-quality-loop/scripts/check-workflow-state.sh:657-715` is the
authoritative validator for a newly-registered non-legacy, non-lite entry:

- Only `requirements.md`, `design.md`, and `acceptance-tests.md` are
  *required* to exist (line 657); `tasks.md` and `traceability.md` are not
  checked by this validator at all when absent.
- `Spec-Review-Status` (in `requirements.md`) and `Impl-Review-Status` (in
  `design.md`) must each be exactly `Pending` or `Passed` (lines 671, 673)
  — `Passed` is not reachable without running `spec-review-loop` /
  `impl-review-loop`, so this feature's spec-phase artifacts carry
  `Pending` for both.
- **Critical, previously under-reported finding**: line 681-682 —
  `[[ ! -f "$tasks" || ( "$spec" == Passed && "$impl" == Passed ) ]] ||
  diagnostic "$feature" task-lifecycle "tasks.md requires Spec and Impl
  Passed"` — means that **if `tasks.md` exists in the feature directory at
  all**, `Spec-Review-Status` and `Impl-Review-Status` **must both already
  be `Passed`**, regardless of `tasks.md`'s own `Task-Review-Status` or any
  task's `Approval:`/`Status:` values. A `tasks.md` committed alongside
  `Spec-Review-Status: Pending`/`Impl-Review-Status: Pending` (as this
  feature's requirements.md/design.md necessarily carry, since neither
  review loop has run) would unconditionally FAIL
  `check-workflow-state.sh` — independent of, and in addition to, the
  Task-Review-Status/Approval/Status handling below.
- This is also the intended shape of this repository's own SDD workflow
  (AGENTS.md "Required Workflow", steps 1-4): Phase 1
  (`sdd-bootstrap-interviewer`) authors `requirements.md`/`design.md`/
  `acceptance-tests.md` only; `spec-review-loop` then `impl-review-loop`
  run and flip both statuses to `Passed`; only THEN does Phase 2 author
  `tasks.md` (and `traceability.md`). `tasks.md` is therefore a Phase 2
  artifact by construction, never co-authored with a still-`Pending` spec
  phase. **Design decision (this feature): this spec package accordingly
  contains only `investigation.md`/`requirements.md`/`design.md`/
  `acceptance-tests.md`. `tasks.md` and `traceability.md` are deferred to
  Phase 2, after `spec-review-loop`/`impl-review-loop` pass** — their
  content (task breakdown, human-copy staging plan, traceability mapping)
  is drafted separately for that future phase, not committed now.
- If `tasks.md` did exist, it would additionally need a
  `Task-Review-Status` header (line 668-670) with value `Pending` or
  `Passed` (line 675); when `Pending`, every `Approval:` line would need to
  be `Draft` and every `Status:` line `Planned` (lines 701-710); and lines
  711-714 would additionally require `spec`/`impl`/`task` all `Passed` if
  any `Status:` were `In Progress`/`Implementation Complete`/`Done` or any
  `Approval:` were `Approved`. None of this is reachable in practice given
  line 681-682 above — it is recorded here only because it was this
  investigation's original (incomplete) reading before the line 681-682
  finding was confirmed.

## INV-013: `check-sdd-structure.sh` does not require the four layer-spec files outside `--feature` mode

`scripts/check-sdd-structure.sh:1-13` only enters its per-feature
`required_file specs/$feature/$name` loop (which includes `ux-spec.md`,
`frontend-spec.md`, `infra-spec.md`, `security-spec.md`) when invoked with
a second (`feature`) argument (`if [ "$#" -ge 2 ]`). The verification
command specified for this task, `sh scripts/check-sdd-structure.sh .`
(one argument), never sets `feature_selected=1`, so it only checks
repository-root-level directories (`specs`, `reports/implementation`,
`reports/quality-gate`, `docs/adr`, `docs/review-tickets`, `AGENTS.md`) —
none of which this feature's Task 1/Task 2 change in a way that would fail
this check. This feature therefore does not need to author
`ux-spec.md`/`frontend-spec.md`/`infra-spec.md`/`security-spec.md`, matching
the task's explicit file list.

## INV-014: ADR numbering — next free number

`ls docs/adr/ | grep -E "^00[0-9]{2}" | sort | tail -5` shows
`0020`, `0021`, `0022`, `0023`, `0024` as the highest existing numbers (plus
`README.md`, not a numbered ADR). `0025` is the next free number as of this
investigation. Per the precedent in `specs/epic-159-pillar-c/design.md:201-236`
(ADR-0012 was provisionally assigned, then re-verified/renumbered at
drafting time because a concurrent merge had occupied it), this feature's
new ADR is provisionally `docs/adr/0025-component-path-ownership-resolver-semantics.md`,
re-verified via `ls docs/adr/` at drafting time.

## OQ-001: Fail-6 (Provider Adapter / Provider Binding drift) exact matching rule

Decision-document v2 §12 names this Fail condition in one line without
detailing how a "Provider Adapter change" is identified against a
Provider Binding record. Since `sdd/provider-bindings.yaml`'s file-level
structure is an Epic A1 deliverable not yet landed (INV-004), this
feature's requirements.md scopes Fail-6 to run only when that file exists,
using the component's own `provider_binding_ids` field (already fixed by
decision-document v2 §5/§12's example) as the join key, and defers the
exact "which sub-path counts as touching the adapter" rule to a follow-up
once Epic A1 ships the file's real shape — recorded as an Open Question,
not silently assumed.

**Resolved** (requirements.md Dependencies, design.md Design Decisions
"Fail-6 scope"): the join rule is fixed as a new optional
`adapter_paths: string[]` (glob array, matched with REQ-001's own glob
engine) field per binding entry in `sdd/provider-bindings.yaml` — a schema
addition attributed to Epic A1 (this feature consumes it, does not define
the file's schema, consistent with Non-goals) and tracked as a named,
required Dependency rather than an indefinitely deferred follow-up. A
binding that declares `adapter_paths` and whose glob matches a diff path
without the corresponding binding facet/revision also present in the diff
triggers Fail-6; a binding that exists but does not declare
`adapter_paths` records Fail-6 as WARN "evaluation not possible" (not a
silent pass) rather than N/A.

## OQ-002: Whether T-001/T-002 should hard-block on Epic A1 landing

Decision-document v2 §12 already fixes the `components[].paths` /
`shared_paths` field shape (the same shape Epic A1 is chartered to
implement as schema, per the task's scope-boundary instruction). This
investigation records both readings considered: (a) hard-block resolver
work on Epic A1 merging, versus (b) build the resolver against
self-contained fixtures matching the documented shape now, with
reconciliation as a tracked follow-up if Epic A1's landed schema diverges.
requirements.md Dependencies and design.md Assumptions adopt (b) for
T-001/T-002 (parsing logic only needs the field *shape*, which is already
fixed) and reserve a hard block for T-003 (needs Epic A1's canonicalizer
*utility*, which has no shape-only substitute) and part of T-004 (needs
Epic A4's Facet Manifest to exist as an artifact, not merely a shape).

## INV-018: `check-contract.py`'s tier-minimum mechanism has no capability-state axis

`grep -n "capability\|disabled-legacy\|project-context\|workflow\."
plugins/sdd-quality-loop/scripts/check-contract.py` returns no match —
`RISK_TIERS` (`:37-42`) and `_pass4_risk_tier()` (`:127-157`) key
required-check-set membership purely off a contract's own `risk`/`stack`
fields, never off `project-context.yaml`'s `workflow.capability_enforcement`
or any capability-pipeline state. Registering `check-component-coverage`
into this tier-minimum set without making the check itself
capability-state-aware would therefore either require a `disabled-legacy`
`high`/`critical` task to fabricate `passes:true` evidence for a check
that never evaluated anything, or force every `high`/`critical` task in
`disabled-legacy` to be permanently unable to satisfy `check-contract` —
grounding the NEW-001 verification finding and this feature's REQ-004
state-aware Gate design (requirements.md Problems, Goals REQ-004).

## INV-019: `emit-run-record` establishes this repository's existing run-record schema convention

`plugins/sdd-quality-loop/scripts/emit-run-record.sh:19-21,247,285` emits
a `"schema": "sdd-run-record/v1"` (or `"sdd-run-record/v2"` with an
additive `effort` sibling object) literal field as part of every run
record it writes to `reports/runs/RUN-<...>.json` — an established,
versioned schema-tagging convention this feature's
`check-component-coverage` evidence record reuses (the `schema` key —
not `schema_version` — design.md Data Plan) rather than inventing an
unrelated shape, and the precedent for treating a script's own output as
a versioned, self-describing record rather than an untyped blob.

## INV-020: ADR-0019's two-tier defense-claim scope is the existing precedent this feature's reachability claims must not exceed

`docs/adr/0019-approval-sidecar-protection.md:70-77,96-103` states its own
claim in exactly two tiers: "hook layer + deterministic validator"
prevents misoperation and simple self-approval (a footgun guard), while
"adversarial-agent resistance comes from the protected file, the
external-key HMAC, branch protection/CODEOWNERS, and human review as the
external boundary" — explicitly declining to claim an unconditional
"defended across all three runtimes" guarantee.
`plugins/sdd-quality-loop/references/deterministic-check-policy.md:62-67`
separately confirms `high`/`critical` tier's own evidence-bundle
provenance and HMAC-signature requirements are the mechanism that scope
references. This feature's AC-035/AC-055 producer-digest and
required-check-set claims are deliberately scoped to the same two tiers,
not a broader unconditional reachability guarantee — correcting an
earlier draft's unqualified reachability language (Problems; formerly a
NOT_RESOLVED verification finding).

## INV-021: Epic A1's `contracts/project-context.template.yaml` does not exist yet, but is the assigned single source of the default cross-cutting seed inventory

`find . -iname "*project-context*" -not -path "./.git/*"` (INV-002)
confirms no `project-context.yaml`, schema, or template artifact exists in
this repository yet. Per the orchestrator's separate cross-epic
instruction to Epic A1, `contracts/project-context.template.yaml`'s
`shared_paths` section is assigned as the sole canonical source of the
default cross-cutting seed list (`specs/**`, `reports/**`, `docs/**`,
`.github/**`, `tests/fixtures/**`, `CHANGELOG.md`) — this feature (A3)
does not author a competing or duplicate list (REQ-006, Dependencies);
REQ-007's day-one integration fixture is written to read that artifact
directly once it lands, and to FAIL closed (never skip) against a
documented stand-in shape before then, mirroring the same discipline
AC-011's schema-conformance fixture already established for Epic A1's
`project-context.yaml` schema itself.

## Summary of Evidence References

| Finding | File | Lines |
|---------|------|-------|
| INV-001 no resolver/gate today | grep across `docs/`, `plugins/`, `tests/` | N/A (no match) |
| INV-002 no project-context.yaml | `find . -iname "*project-context*"` | N/A (no match) |
| INV-003 no facet-manifest schema | `find . -iname "*facet-manifest*"` | N/A (no match) |
| INV-004 no provider-bindings file | `find . -iname "*provider-binding*"` | N/A (only the ADR) |
| INV-005 quality-gate/SKILL.md unprotected | `plugins/sdd-quality-loop/references/guard-invariants.json` | 33, 37 (contrast) |
| INV-005 generated module confirms | `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` | N/A (no match) |
| INV-006 check-contract/check-evidence-bundle protected | `plugins/sdd-quality-loop/references/guard-invariants.json` | 14-19 |
| INV-006 guard-invariants.json self-protected | `plugins/sdd-quality-loop/references/guard-invariants.json` | 34-39 |
| INV-007 human-copy precedent | `specs/epic-136-phase2-gates/human-copy/`; `specs/epic-159-pillar-c/design.md` | MANIFEST.sha256, apply-protected-files.ps1; 110-167 |
| INV-008 script wrapper convention | `plugins/sdd-quality-loop/scripts/sdd-hook-guard.*`, `check-contract.*` | N/A (directory listing) |
| INV-009 fixture directory convention | `tests/fixtures/workflow-state/`, `tests/fixtures/phase2-contract-path-golden/` | N/A (directory listing) |
| INV-010 3-OS twin registration | `tests/run-all.sh`; `.github/workflows/test.yml` | 7-42; 148, 152 |
| INV-010 test.yml protected | `plugins/sdd-quality-loop/references/guard-invariants.json` | 40 |
| INV-011 registry entry shape | `contracts/workflow-state-registry.schema.json`; `specs/workflow-state-registry.json` | `definitions.entry`; N/A |
| INV-012 check-workflow-state.sh semantics | `plugins/sdd-quality-loop/scripts/check-workflow-state.sh` | 657-715 |
| INV-013 check-sdd-structure.sh feature-mode gating | `scripts/check-sdd-structure.sh` | 1-13, 40-52 |
| INV-014 ADR next free number | `docs/adr/` directory listing | 0020-0024 present, 0025 free |
| INV-015 generator exact-match forces edit + epic-136 already staged it | `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`; `specs/epic-136-phase2-gates/human-copy/MANIFEST.sha256` | 37-88, 129-147, 271-291; generate-guard-invariants.py line |
| INV-016 ADR-0016 axis derivation, not file presence | `docs/adr/0016-workflow-axes-separation.md` | 17-26, 30-39, 56-75, 90-93 |
| INV-017 protected required-check-set closes SKILL.md reachability gap | `plugins/sdd-quality-loop/references/risk-gate-matrix.md`; `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` | 80-92, 9-11; 30-75 |
| INV-018 check-contract has no capability-state axis | `plugins/sdd-quality-loop/scripts/check-contract.py` | 37-42, 127-157 |
| INV-019 emit-run-record schema-tagging convention | `plugins/sdd-quality-loop/scripts/emit-run-record.sh` | 19-21, 247, 285 |
| INV-020 ADR-0019 two-tier defense-claim scope precedent | `docs/adr/0019-approval-sidecar-protection.md`; `plugins/sdd-quality-loop/references/deterministic-check-policy.md` | 70-77, 96-103; 62-67 |
| INV-021 no project-context template yet; A1-assigned single seed source | `find . -iname "*project-context*"` | N/A (no match, per INV-002) |
