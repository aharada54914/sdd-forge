# Requirements: Project skill execution methods and verification observations (#594)

Spec-Review-Status: Pending

DRAFT. Not reviewed. Source: issue #594 (parent #593); investigation basis
sdd-forge `07ed2e98` (branch `feat/issue-594-contracts`). Every file:line below
was read at that commit and must be re-verified at spec-review time against the
review tree (WFI-011, WFI-013).

## Overview

Connect free-form, project-authored verification skills to the existing
verification foundation without moving any authority into them. A skill only
supplies an **execution method** for a check id; whether that check is required,
how its result is judged, and the final verdict stay where they are today.

Deliverables of #594: one ADR (ADR-0040, Proposed), two new versioned contracts
(`project-skill-manifest/v1`, `project-verification-observation/v1`), one
deterministic validator, fixtures/tests registered in the existing catalog, and
contract documentation. No runtime consumer wiring (see Out of Scope).

## Target Users

Project maintainers who author verification skills; implementers and
quality-gate verifiers who record and consume observations; maintainers of the
dependent issues #595, #596, #602, #605.

## Grounding (cited, re-verify at review)

- G-1 The selected-plan evaluator does not execute verifiers: docstring
  `plugins/sdd-quality-loop/scripts/evaluate-selected-plan.py:3-6`. It reads
  execution facts (`command`, `started_at`, `finished_at`, `exit_code`,
  `passes`, `evidence`) from the verification contract `checks[]`
  (`evaluate-selected-plan.py:147-160`).
- G-2 Required ids come from `check-contract.py` `BASELINE_IDS`/`RISK_TIERS`
  (`plugins/sdd-quality-loop/scripts/check-contract.py:37-44`), registry gates
  with `blocking` (`evaluate-selected-plan.py:91-95,135`) and contract
  `required: true` (`evaluate-selected-plan.py:134`). Baseline downgrades need
  `waiver_reason` (`check-contract.py:248-265`).
- G-3 Required checks that are `unavailable`/`not-run`/`unknown` make the
  verdict `BLOCKED`; only measured failure is `NEEDS_WORK`
  (`evaluate-selected-plan.py:166-172`).
- G-4 Existing result/reason vocabularies are closed enums
  (`contracts/selected-verification-plan.schema.json:47-48`) and the plan,
  Project Context and Registry schemas reject unknown fields
  (`selected-verification-plan.schema.json:6,14,33`;
  `contracts/project-context.schema.json:5`;
  `contracts/capability-registry.schema.json:22-24` gate object).
- G-5 Run input already exists as `task-input-manifest/v1` with `task_id`
  (`T-NNN`), `run_id` and `allowed_inputs[]{path,sha256}`
  (`contracts/task-input-manifest.schema.json:29-35,75-83`). The schema carries
  no approval authority; admission is done by the existing orchestration
  (`plugins/sdd-implementation/skills/implement-tasks/SKILL.md:223-244`) and
  `validate-task-input-manifest.sh`, which rejects duplicate input paths
  (`:257-266`), fallback-evidence defects (`:278-288`) and input/output overlap
  (`:290-298`) and allows directory-form outputs (`:84-97`).
- G-6 Reusable deterministic helpers exist: JSON-schema validation
  (`plugins/sdd-quality-loop/scripts/validate-facet-manifest.py:378`), evidence
  path containment (`plugins/sdd-quality-loop/scripts/validate_path.py:28`),
  packaged-then-repo schema lookup with `$id` check
  (`evaluate-selected-plan.py:41-54`). The schema helper supports `if/then`
  but not `allOf` (`evaluate-selected-plan.py:61`).
- G-7 Project Context trust starts with physical presence
  (`PLUGIN-CONTRACTS.md:94-103`, ADR-0023).
- G-8 `sdd/skills` is unused: `git grep -n 'sdd/skills'` returns nothing at
  `07ed2e98`. Shared-state claim: re-run at review and at implementation.
- G-9 The marketplace lists nine plugins (`.claude-plugin/marketplace.json`):
  seven workflow plugins plus `sdd-azure-cloud`/`sdd-aws-cloud`. The issue's
  "existing 7 plugins" is read as the workflow plugins; #594 adds no plugin
  and places everything in `sdd-quality-loop`. Re-verify at review.
- G-12 The task snapshot is a read-only copy of exactly the `allowed_inputs`
  bytes, not a Git work tree (`plugins/sdd-implementation/scripts/prepare-task-snapshot.sh:168-229`);
  workers receive only the snapshot, manifest and declared output roots
  (`implement-tasks/SKILL.md:239-244`, `:280-283`) and must validate produced
  files against `allowed_outputs` before return (`:300-302`).
- G-10 The evidence boundary `reports/project-skill-observations/` is unused:
  `git grep -n 'project-skill-observations'` returns nothing at `07ed2e98`
  (the similar `verification-observations` occurs only under `$RUNNER_TEMP`,
  `.github/workflows/test.yml:1354`). Shared-state claim: re-run at review and
  implementation.
- G-11 Evaluator precedence for a contract check
  (`evaluate-selected-plan.py:140-163`): tier-required without `required: true`
  ⇒ `unknown`; unselected `required: false` ⇒ `not-applicable`; selected gate
  with missing verifier ⇒ `unavailable`; missing execution fields ⇒ `not-run`;
  legacy-required non-success reasons ⇒ `migration-pending-required`.

## Functional Requirements

- REQ-001 Ownership. ADR-0040 fixes the owners: protected required sets
  (G-2 sources only), task/run admission (existing workflow, G-5), local
  execution methods (project skills), execution and run-time enforcement
  (future runner, #595/#596), runner observations (the executing runner,
  recorded as observation files), final verdict (`evaluate-selected-plan.py` /
  `quality-gate`). Placement is inside
  `sdd-quality-loop`; no new plugin, no MCP write tool, no new approval/state
  engine.
- REQ-002 Skill manifest contract `project-skill-manifest/v1` exactly as in
  design.md §Contracts, with no obligation/required/approval/status field and
  `additionalProperties: false` at every level.
- REQ-003 Observation contract `project-verification-observation/v1` exactly as
  in design.md §Contracts, binding run identity, supplied task input manifest
  digest, skill manifest digest, source commit + source-set digest, runner
  context (unverified) and outcome. `environment.runtime_path` is a resolved-path
  claim required for executed outcomes and for `unavailable` with the runtime
  present, and `null` when the runtime itself is missing or the outcome is
  `not-run`; no path is fabricated.
- REQ-004 Discovery: only `<execution-root>/sdd/skills/<name>/skill-manifest.json`
  (task mode: only manifests listed in `allowed_inputs`), byte-order sorted; `name` equals the directory name; two skills offering the
  same check id is a collision that invalidates discovery. Host directories
  (#602 projections) are never discovery sources.
- REQ-005 Closure and command shape: the manifest lists every regular file in
  its skill directory tree (except itself) with sha256; nested directories are
  allowed; omitted, missing, escaping, symlinked, special or tampered entries
  are invalid. The executed argv is fixed as runtime program + closure
  entrypoint + literal non-path args, with working directory = the execution root. The
  passive validator binds the entrypoint to the closure; it does not prove what
  the entrypoint loads at run time, which is runner responsibility (#595/#596).
- REQ-006 Task input binding: a task-mode observation is valid only if its
  `task_input_manifest_sha256` matches the supplied `task-input-manifest/v1`
  bytes, its `task_id`/`run_id` match, the manifest is schema-valid with no
  duplicate input path and no input under an output, and the skill manifest and
  every closure file appear exactly once in `allowed_inputs`. Every
  `allowed_inputs` entry, whatever its Git-ignore status or location, must be
  present and rehash to its pin; none may lie under the evidence-only subtree
  `reports/project-skill-observations/`; and an `allowed_outputs` entry must
  cover the observation's per-run evidence path. Paths alone never confer trust.
  The validator reads only the execution root's discovery, admitted-input,
  output-root and observation paths (design.md §Execution root and handoff);
  existing orchestration materializes that root from the immutable snapshot
  plus declared outputs (#596), without widening snapshot access. Admission of that manifest for
  the current run (G-5) is an upstream precondition for consumers (#596); VALID
  is identity/consistency, never proof of approval.
- REQ-007 Freshness: `source.tree_sha256` (design.md §Task-mode source set:
  every admitted input plus every regular file present under the output roots,
  except the run's evidence directory; absent paths omitted; no Git) must equal
  the value recomputed at validation. Added, deleted or changed outputs and
  changed inputs are stale; writing the observation cannot invalidate it;
  files neither admitted nor under output roots (e.g. unrelated caches) are
  unverified environment (stated limit). `source.commit` is a runner provenance
  claim, never compared and never approval proof.
- REQ-008 States: the validator distinguishes missing skill, invalid
  skill/observation, not executed (no observation, or `not-run`), environment
  unavailable (`unavailable`), `failed` and `passed`.
  - The projection (design.md) rewrites only the execution fields of a check
    already in the approved contract.
  - It writes those fields only for valid task-mode `passed`/`failed`, and
    removes all of them, including stale ones, for every other state. This is
    the single fallback.
  - The evaluator's existing precedence (G-11) is preserved, so a required
    check is PASS only from a valid `passed` observation; unknown never
    becomes PASS.
- REQ-009 Skills cannot change Approved/Done, task status, or required sets; a
  manifest carrying `required` (any value) is rejected; required-ness is decided
  only by G-2 sources.
- REQ-010 Trial: skill manifests and `trial`-mode observations validate without
  Project Context, task manifest, task or run, including a new untracked skill
  (enables #595 generation/trial); no Git needed; its source set is
  the skill closure only (it binds no project source). Trial observations are never
  admissible verification evidence.
- REQ-011 Non-adopter compatibility: with no `sdd/skills/` directory, every
  existing command output, file byte, JSON structure and event emission is
  unchanged; no existing schema gains a field.
- REQ-012 Validator surface: one script trio
  `validate-project-skill.{py,sh,ps1}` with exactly the flags, outputs, exit
  codes and error codes in design.md §Validator; unknown flags are rejected.
- REQ-013 Evidence and docs: tests in `tests/verification-catalog.json`;
  `PLUGIN-CONTRACTS.md`, `CHANGELOG.md` and vendored contract copies synced;
  frozen specs/reports/evidence and pending human-copy are not edited.

## Non-Functional Requirements

- NFR-001 Deterministic: same bytes in, same stdout/stderr/exit out; no network
  and no clock reads (timestamps are only parsed and compared).
- NFR-002 Python standard library plus existing in-repo helpers only.
- NFR-003 Bash/PowerShell wrappers are argument-transparent; parity is planned
  to be tested on Linux (not yet executed); macOS/Windows/host
  (Claude/Codex/Copilot) parity stays **unverified** until observed there.

## Out of Scope (owned elsewhere)

- #595 skill creation/authoring flow and trial runner.
- #596 Full/Lite integration: calling the validator from implement/quality-gate
  and projecting observations into verification contracts.
- #602 host projection of skills into Claude/Codex/Copilot locations.
- #605 external research-reference interface. #605 owns research artifacts and
  does not own the skill manifest/observation contracts or add a runner. The v1
  contracts carry no research field. A research artifact a run uses is bound
  through the existing `allowed_inputs` path+sha256 (G-5). Any future field
  arrives as a new contract version, not as a v1 extension.
- Executing skills, deployment stages, new approval/state engines, MCP writes.

## Resolved Questions (2026-10-22)

- OQ-1 Captured output: not in v1. The issue requires run/check/source
  correspondence, not log attestation; runner claims stay unverified.
- OQ-2 Task id: `^T-[0-9]{3}$`, matching the bound `task-input-manifest/v1`
  (`contracts/task-input-manifest.schema.json:29-31`); the broader plan pattern
  (`contracts/selected-verification-plan.schema.json:11`) is untouched.
