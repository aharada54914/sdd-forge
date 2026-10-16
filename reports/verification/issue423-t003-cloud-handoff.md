# Issue #423 T-003 cloud continuation

## Checkpoint scope

- Owner branch: `codex/issue423-boundary-checkpoint` in `aharada54914/sdd-forge`.
- Base HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`.
- The local owner checkout had 259 dirty/untracked entries. This checkpoint selects only T-003 evaluator/schema, packaging, tests and runner/gate wiring; unrelated shared-launch repairs and historical evidence are not included.
- Risk: existing high-risk SDD task. Preserve approved contracts, required checks, reviewer independence and frozen evidence. This checkpoint is not a Done decision.
- Affected contracts: selected verification plan, Registry/Resolver selection, task contract, quality-gate invocation and vendored schema discovery.

## Current evidence and unresolved finding

The preceding local cycle reported 22 focused tests passing and an independent result of NEEDS_WORK (Critical 0, Major 1, Minor 0). These are historical local observations, not proof for the cloud checkout or CI. The remaining Major is in `tests/sdd-domain-multitarget-T-003.tests.py`: the five target fixtures share the same selection shape and mostly assert different names. They do not prove the target-specific checks, artifacts and exclusions required by AC-003a through AC-003e.

The user explicitly approved test-only additional repair and re-review beyond the preceding three-cycle limit, retaining all mandatory criteria, until a formal quality gate can mark T-003 Done. Do not overwrite prior NEEDS_WORK results or relabel this checkpoint as PASS.

## Next work

Checkpoint validation on 2026-10-17 used an isolated export of the staged index, excluding unrelated working-tree changes: `python3 tests/sdd-domain-multitarget-T-003.tests.py` passed 22 tests; `bash tests/registry-discovery.tests.sh` and `pwsh -NoProfile -File tests/registry-discovery.tests.ps1` each passed 21 checks. All exited 0. The vendoring `--check` initially failed because the export lacked Git metadata; after initializing only that disposable export as a Git repository, it exited 0 with no drift. These checks do not resolve the target-specific coverage Major or establish formal acceptance.

1. Read repository instructions, `docs/development-policy.md`, and the authoritative `specs/sdd-domain-multitarget/` task, requirements, design, acceptance tests and traceability. Check current branch/HEAD, prerequisite state and accessible evidence before modifying anything.
2. Expand only the T-003 tests with distinct synthetic Registry/Project Context profiles. Assert concrete inclusion/exclusion and required observations for CLI/library, UI, design-only, IaC/cloud and low-code. Use existing approved definitions; do not create production providers or weaken the legacy contract.
3. Required checks are never skipped: unavailable or unrun means BLOCKED. Only originally optional and unselected checks may be reasoned not-applicable. Do not invent conditional checks absent from the Registry. Plan/mock is not deployment; FilesOnly packaging is not live activation.
4. Re-run focused tests, Registry discovery on available runtimes, vendored-copy verification, syntax/static checks and applicable integration regressions. Record real commands, exit codes and limitations for the exact candidate. A passing name-only fixture is not acceptance.
5. Obtain an independent, no-history code review and resolve Major findings. Use the existing authorized repository-development review exception where applicable; do not fabricate a formal identity reservation or reuse another review's verdict.
6. Run the sanctioned quality-gate transition only when required inputs and prerequisites are proven. Only that gate may set T-003 Done. Preserve frozen artifacts and old failures. Commit/push the approved scoped work when verified.

## Portability and limitations

Local temporary snapshots, evaluator sessions and uncommitted reports are not available to a cloud task. Recreate disposable fixtures honestly; do not claim their provenance was transferred. The local handoff noted a missing canonical T-002 evidence filename even though a dated artifact existed; verify actual current prerequisites and report any blocking missing artifact rather than renaming/promoting evidence to make a gate pass.

No full-suite, native Windows execution, latest-head CI, formal quality-gate PASS, merge or Done is claimed by this checkpoint. Do not reinstall plugins, change global permissions/trust, copy credentials, use Gemini, or bypass a refusal. The cloud task must distinguish a focused local green result, independent review, CI and Done.
