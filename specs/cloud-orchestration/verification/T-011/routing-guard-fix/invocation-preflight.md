# Invocation compatibility preflight before shared guard changes

Root confirmed minimal shared guard fixes authorized in the live task message.
`final-guard-parity.log` is registration-only: 373 PASS / 9 FAIL, all failures
are expected allowances of resolved literal environment-prefixed script inputs.
Corrected Set-Content shell payloads now deny in all actual consumers.

| Persisted field / claim | Counterpart | Failing mismatch and safety controls |
|---|---|---|
| allow for first Python script operand with literal cloud workspace/runtime assignments and -B | Existing script-as-input rule; public CLI environment metadata | Actual Python/Node/Bash/PS 9 failures in registration-only parity. Bare and documented variable controls pass. |
| deny for protected output and interpreter rebind | Existing protected target scan and conservative first-command rule | Regression keeps redirect/output target, PATH/PYTHONPATH, mis-cased metadata/flag and prior-command negative controls. |
| Cross-runtime grammar and case | Same first-command/literal-context rule in Python, JS, PS | All four real consumers run the identical payloads; new PS comparisons must be case-sensitive. |
| Typed Python metadata and payload access | Existing runtime values and repository Ruff/mypy config | Pre-change configured mypy reports 20 errors (empty-list/tuple inference and repeated optional dict get); annotate exact existing shapes and narrow unchanged retrieved values, no suppressions or behavior relaxation. |

Only the two already documented CLOUD_WORKSPACE_ROOT/CLOUD_SHARED_RUNTIME_ROOT
assignments (literal, nonempty, no shell operators) may precede the existing
bare Python interpreter; only Python's -B no-bytecode flag is skipped. This
recognizes an input operand, not a trusted command/output or generic exemption.
All remaining tokens still undergo the unchanged protected-path scan. No env
wrapper, PATH/Python-loader assignment, interpreter replacement, arbitrary flag,
preceding command or shell expansion is admitted. Scanner and membership stay
strict. Provider/helper/skill bytes remain unchanged.
