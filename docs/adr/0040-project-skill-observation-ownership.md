# ADR 0040: Project skills supply execution methods; obligations and verdicts stay put

Status: Proposed
Date: 2026-10-22
Normative design: specs/project-skill-observation/design.md (draft, review pending).

Numbering: 0040 was taken because concurrent draft PR #631 (issue #614) uses
0039. Re-verify `docs/adr/` and the index for 0039/0040 ownership at
integration and every review round; renumber only this feature's files.

## Context

Projects want free-form verification skills. The selected-plan evaluator
consumes recorded observations and does not execute verifiers
(`plugins/sdd-quality-loop/scripts/evaluate-selected-plan.py:3-6`). Required
checks come from protected tiers, Registry gates and approved contracts, and
existing result/plan/context schemas reject unknown fields.

## Decision

1. Protected required sets stay owned by `check-contract.py` tiers, the
   capability Registry and approved verification contracts. A skill never
   declares, adds or waives an obligation.
2. Task/run admission stays with the existing implement-tasks orchestration
   and `validate-task-input-manifest`; a supplied manifest is an upstream,
   already-admitted input, never approval proof created by a skill.
3. A project skill (`sdd/skills/<name>/`, `project-skill-manifest/v1`) owns only
   an execution method for named check ids: a runtime program plus a closure
   entrypoint and literal args, run from the execution root, pinned by a
   complete file closure.
4. The runner (#595 trial, #596 task) owns execution, run-time access
   enforcement and its observation (`project-verification-observation/v2`),
   bound to run identity, task input digest, skill digest and a content digest
   of the admitted inputs plus produced outputs. The execution root is composed
   by existing orchestration from the immutable snapshot and declared output
   roots; #594 adds no runner and widens no snapshot access. Observations go to
   a per-run evidence path admitted through `allowed_outputs`; the evidence
   subtree is never input.
5. `sdd-quality-loop` owns a passive deterministic validator of identity and
   consistency; the evaluator and quality-gate keep sole ownership of results
   and the final verdict. Observations reach them only by rewriting execution
   fields of checks already in the approved contract, clearing them for every
   non-executed, invalid or trial state.
6. Everything ships inside existing plugins. No new plugin, approval/state
   engine, MCP write path or field in an existing strict schema.

## Consequences

Non-adopting repositories are unaffected. Integration (#596), authoring
(#595), host projection (#602) and research references (#605) build on these
contracts without changing ownership. Observations remain runner claims; the
contracts add binding, not attestation, and the passive validator cannot prove
run-time file access.

## Toolchain freshness (v2)

Actual runners now record v2. Declared runtime and required executables, the
runner Python, runner/supervisor/validator/schema-validator source bytes, and their filesystem
identities are fingerprinted before and after execution. The validator rechecks
the same binding before projecting execution fields. A same-path executable
replacement, helper change, source change, or inherited variable change therefore
invalidates earlier execution evidence. Filesystem identity includes ctime as
well as content, so replacing and restoring bytes does not restore the old binding.
No tool is executed by this passive comparison. Loaded runner/validator/schema
modules retain their import-time source digest and reject later disk replacements
instead of recording new bytes for code already loaded into memory.

The runner removes shell bookkeeping variables (`_`, `SHLVL`, `PWD`, `OLDPWD`)
from the actual child environment and from its environment digest. Other inherited
variables are hashed without recording their plaintext. Input paths and the
execution cwd remain owned by the existing task-input/temporary-root rules.
This is a binding to declared toolchain files, not arbitrary dynamically loaded
libraries, undeclared subprocesses, host attestation, or a sandbox guarantee.
Such dependencies must remain in the declared input/tool closure; this change
does not establish a general reusable cache.

Historical v1 records remain syntactically readable and their original bytes
are retained. Ran v1 records return `legacy-runtime-unbound` and supply no fresh
execution fields; regenerate evidence with the actual runner instead of adding
fingerprints to old records. Non-adopting legacy contracts are unaffected.
