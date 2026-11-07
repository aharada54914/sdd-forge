# Final focused integration checks

All 12 commands in `results.json` exited 0. This checks the current product source and documentation together; it is not a repetition of every application test. No product code was changed during this verification. The checked source hashes are saved in `source-hashes.json`.

Coverage includes repository plugin manifests and links, review prompt/calibration references, bootstrap layer templates, role authorization parity in Bash and PowerShell, generated protected entrypoints and guard invariants in both runtimes, shared constants, verification catalog registration, and repository SDD structure. Repository validation reports 10 protected read-only targets with zero drift. Bootstrap templates report 97 passed, zero failed. Guard invariants report Bash 42 passed and PowerShell 55 passed, zero failed.

PowerShell was explicitly available through `/workspace/.tools/sdd-forge-dev/bin/pwsh`; `PWSH` and PATH were set, along with the installed RTK path. There are no missing-runtime skips. The PowerShell guard suite retains one existing, explicitly documented staged-runner migration skip; the catalog unittest retains its existing skip. Those are not reported as executed assertions.

## ADR template admission

`adr-template-admission.json` records six direct checks against the actual production Bash parser and the actual PowerShell function extracted via its AST (without executing the precheck's main routine):

- Unrendered design template admits no ADR paths.
- Rendering `adr_ref` as `docs/adr/0042-real-decision.md` admits exactly that path.
- Bare documentation examples and a fenced inline-path example admit no paths.

All six passed. In particular, the new bare `docs/adr/0001-storage.md` explanatory example is not accidentally admitted as an additional ADR. The actual declared inline path remains admitted in both runtimes.

`git diff --check` also passed. Commands, exit codes, durations and individual logs are retained beside this file. Normal native full/SQLite completion is tracked separately from these repository integration checks.

## Follow-up task prerequisite correction

After the 12-command snapshot, bootstrap task guidance was corrected to require committed failing Red tests before implementation, a named independent reviewer/context, and execution evidence outside frozen specifications. `13-bootstrap-task-prerequisites.log` records the targeted rerun: 97 passed, zero failed. The earlier source hash inventory describes its original snapshot; this follow-up is not covered by those older hashes. Human-copy mirror verification and `git diff --check` also passed.
