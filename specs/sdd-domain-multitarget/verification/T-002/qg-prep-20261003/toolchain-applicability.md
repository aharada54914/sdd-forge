# T-002 toolchain applicability — unresolved

The production change includes Python validation logic and three JSON Schemas.
It is not a documentation-only change. The contract remains `stack: code` and
lint, typecheck and build remain required and unverified.

The repository defines no Python lint, static typecheck or build command for
this validator. MCP package builds do not validate it. Syntax compilation is
not a substitute for those three checks.

`plugins/sdd-quality-loop/references/verification-policy.md` requires configured
commands rather than invented commands. The stack rule in
`plugins/sdd-quality-loop/references/risk-gate-matrix.md` permits three specific
waivers for non-code stacks, describing pure shell, Markdown, JSON and docs.
Its present wording does not clearly cover production Python scripts.

The existing `epic-193-a5-capability-resolver/verification/T-008.contract.json`
uses `stack: shell` for a similar standard-library Python validator with shell
dispatchers. That precedent does not override the narrower written rule.

## Proposed explicit resolution, not applied

Define applicability by the actual configured toolchain for interpreted scripts,
rather than relabeling Python as shell. A missing lint/typecheck/build toolchain
must be recorded as not applicable with a specific reason, never as PASS.
All task-required runtime, negative-case, schema, acceptance and regression
checks remain mandatory. Existing configured checks cannot be waived by this
rule. Contract-validator parity and rejection tests would be required before
adopting a contract change.

This is a policy/contract change, not an existing exemption. No contract,
required-check flag, review verdict or task status was changed by this note.
Current runtime evidence is in `current-validation.md` beside this file.
