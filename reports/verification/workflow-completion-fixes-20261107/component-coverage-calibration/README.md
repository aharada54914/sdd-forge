# Component-coverage applicability calibration (#742)

Issue: https://github.com/aharada54914/sdd-forge/issues/742

The real full-workflow evaluator verified 56 admitted hashes and inspected the task implementation, then raised a Major finding solely because a required component-coverage invocation returned `not-applicable (disabled-legacy)`. It requested capability activation or an optional waiver. The original result and gate JSON are preserved here. The project had no `project-context.yaml`; the public gate and quality skill explicitly specify this as a legitimate executed N/A with exit 0.

The root correction is documentation/calibration only. The evaluator's admitted calibration now distinguishes required execution from applicability and from substantive coverage. Main, Codex and Copilot evaluator guidance and the quality skill repeat the distinction so isolated runtime roles do not infer an activation requirement from `required: true` alone. This does not change any gate implementation or infer PASS for an unexecuted command.

A legitimate N/A requires the actual invocation, exit status, authoritative configuration/input binding and producer-bound record. Missing execution, unsupported N/A assertions, parse errors and missing enabled-mode coverage remain failures or cannot-verify. Advisory exit 0 retains its findings. Independent explicit acceptance requirements for active coverage remain obligations and must be cited separately.

Validation results:

- Existing component-coverage suite: Bash 46 passed; PowerShell 53 passed; zero failures.
- Six direct runtime controls in `applicability-controls.json`: absent context produces the canonical N/A record and exit 0; required mode with a missing manifest fails with exit 2; malformed context fails with exit 2. All three controls passed in both runtimes.
- Role/reference parity: 65 passed in each runtime.
- Quality calibration source checks: passed, including explicit positive/negative applicability clauses in all evaluator definitions.
- Human-copy check: no stale mirrors; pending bundles unchanged. Whitespace check passed.

The deterministic tests establish the existing gate behavior and the checked-in instruction distinctions, not a guarantee of model interpretation. The normal full-session re-evaluation remains the behavioral confirmation. Already pinned project calibration files must not be silently replaced mid-run; the parent coordinates immutable runtime snapshots and any new admitted evidence.
