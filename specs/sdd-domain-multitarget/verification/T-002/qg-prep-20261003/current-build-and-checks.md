# T-002 current-byte deterministic evidence — 2026-10-03

This is owner-side quality-gate preparation, not an independent evaluator result, host plugin registration, CI result, or Done decision. The canonical implementation report remains frozen. Commands below ran in the owner checkout through `rtk proxy` with `login=false`; all exit codes are observed, not inferred.

Source SHA-256 immediately before these checks: `validate-capability-registry.py` = `4794ef81888e83a4d45f37a680ab65436cd1ca97e1d01c59acf8a22dae898788`; imported `registry_discovery.py` = `ea08dbd141b24f4685fd9211b4454d782e5ea80e081e0a59d89ee7f7fe5282ea`; `install.sh` = `9b43d5eaf93a9cefffc562a3108f43ab2bc2a64c675a710ec5c59250f7abe719`.

| Check | Command or immutable source | Exit | Result |
|---|---|---:|---|
| Python lint | `rtk proxy uvx --from ruff==0.13.3 ruff check plugins/sdd-quality-loop/scripts/validate-capability-registry.py plugins/sdd-quality-loop/scripts/registry_discovery.py` | 0 | `All checks passed!` |
| Strict Python typecheck | `rtk proxy uvx --from mypy==1.18.2 mypy --strict plugins/sdd-quality-loop/scripts/validate-capability-registry.py` | 0 | `Success: no issues found in 1 source file` (import following enabled) |
| Ownership boundary unit/acceptance/regression | `rtk proxy python3 -B specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py --repo-root . -q` | 0 | 28 tests, OK; one execution supports these three surfaces |
| Canonical Registry | `rtk proxy bash plugins/sdd-quality-loop/scripts/validate-capability-registry.sh --registry contracts/capability-registry.json` | 0 | All 9 checks passed |
| Repository structure | `rtk proxy bash scripts/check-sdd-structure.sh` | 0 | `check-sdd-structure: OK` |
| Risk | `rtk proxy bash plugins/sdd-quality-loop/scripts/check-risk.sh specs/sdd-domain-multitarget/tasks.md T-002` | 0 | `Risk check passed for task T-002.` |
| Placeholder scan | `rtk proxy bash plugins/sdd-quality-loop/scripts/check-placeholders.sh contracts/project-context.schema.json contracts/context-projection.schema.json plugins/sdd-quality-loop/contracts/context-projection.schema.json plugins/sdd-quality-loop/scripts/validate-capability-registry.py plugins/sdd-quality-loop/scripts/registry_discovery.py` | 0 | `Placeholder scan passed.` |
| Task state | `rtk proxy bash plugins/sdd-quality-loop/scripts/check-task-state.sh specs/sdd-domain-multitarget/tasks.md reports/quality-gate reports/implementation .` | 0 | Six tasks passed; pre-existing T-001 dirty-tree warning |
| Workflow state | `rtk proxy bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh` | 0 | `workflow-state: ok`; four unrelated amendment-growth notices |
| Imported helper regression | `rtk proxy bash tests/registry-discovery.tests.sh` | 0 | `pass=21 fail=0` |

The human-executed isolated assembly log `reports/verification/issue423-t002-build-human.log.h2HQDSYl` has SHA-256 `450aba84af3339e078ec3f9f6e69d57928b1177fa24705edc294ddaf964a2fe8`. It records the same three source hashes, `install.sh --target=FilesOnly` assembly, installed validator and helper hash equality, installed validator `all 9 checks passed`, and final `T-002 installed payload assembly, byte parity, and validator execution: PASS`. The human batch returned exit 0. `FilesOnly` explicitly skipped plugin registration; this is installed-payload build evidence only, not native host activation. Its generic `registration failed` line is misleading in this mode but is not erased or construed as registration success.

The pre-existing `python-toolchain-evidence.md` documents the earlier denied assembly; that denial remains historical. The new human log closes only the current-byte isolated build check. Native Windows and current-head CI remain unverified.
