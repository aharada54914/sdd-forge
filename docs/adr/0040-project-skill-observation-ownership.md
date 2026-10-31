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
   enforcement and its observation (`project-verification-observation/v3`),
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

V2 introduced the following runtime binding, which v3 retains. Declared runtime and required executables, the
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

## Documentation-only methods (manifest v2)

The same manifest supports `method: command|document` in v2. Existing v1 bytes
and command sealing remain unchanged. A document method requires null runtime
and entry, empty args/requires, and SKILL.md in the closed source files. Schema
and executable admission both reject attempts to attach execution to that method.
A fabricated runtime name, a second document manifest or executing Markdown as
a program were rejected because they obscure the lack of executable evidence.

`seal --document-only` produces draft, refuses runtime/entry/requires options,
and never overwrites existing manifests or handwritten text. Existing project
wrappers remain usable. `run` records not-run without resolving/launching tools;
cleanup=false means no process cleanup was demonstrated. `maintain` reports
blocked/procedure-not-executable. Even a forged passed observation is refused.
Documents can describe useful manual steps without pretending those steps ran.

## Executable source permissions (observation v3)

The runner preserves the executable bits of admitted files when staging them.
Those bits can change command behavior even when file bytes are unchanged, so
v3 separately binds a sorted path-to-executable-bits digest in
`source.executable_modes_sha256`. The manifest's byte hashes retain their existing
meaning. Runner and validator use the same source-mode function. The runner
checks admitted permissions before execution and on both the isolated and
original trees afterward; input mutation cannot become successful evidence.
Published output files preserve their executable bits so current output binding
matches the observed tree.

V2 execution records lack this binding and return `legacy-source-modes-unbound`;
v1 retains `legacy-runtime-unbound`. Both remain historical records and cannot
supply current execution fields. Re-execute to obtain v3; do not add new hashes
to historical results. This records the copied executable bits, not an OS-wide
ACL, ownership, dynamic-library closure or an ABA-proof filesystem snapshot.
