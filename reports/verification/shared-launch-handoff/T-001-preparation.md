# T-001 implementation handoff preparation

Prepared 2026-10-08. This is orchestration preparation, not a task transition, implementation report, reservation, or verdict.

- Issue/task: #423 bounded shared launch repair, T-001; subsequent order T-005, T-002, T-003, T-004.
- Owner checkout: /Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge
- HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807.
- tasks.md SHA-256: bfc70a0ecaa14ba6cbad5879665e3acd84a29fa277c5ee45a4d5350b4d4819ea (read back).
- Risk high / Required Workflow tdd. Scope: REQ-001 CLI and effective permission assembly.
- Existing dirty source/config/tests/specs/review records were preserved. Snapshot inputs pin 34 current files, including the dirty T-001 candidate. Existing candidate tests do not become acceptance evidence.
- Structure check: check-sdd-structure: OK; advisory CLAUDE.md.
- Required references were read from implement-task/references; implement-tasks/references does not exist.

## Prepared artifacts and observed checks

T-001-snapshot-inputs.json is an input inventory, deliberately not labeled task-input-manifest/v1. It contains real raw SHA-256 hashes and no invented identity/cost.
T-001-snapshot/ was published by the checked-in prepare-task-snapshot.sh:
`rtk proxy bash plugins/sdd-implementation/scripts/prepare-task-snapshot.sh --manifest reports/verification/shared-launch-handoff/T-001-snapshot-inputs.json --repo-root . --snapshot-root reports/verification/shared-launch-handoff/T-001-snapshot`
Result: TASK_INPUT_OK. Separate shasum readback matched all 34 entries; find -perm +0222 returned no writable entries.

The canonical manifest validator rejects this preparation inventory:
TASK_INPUT_JSON: unexpected field: purpose
This rejection is expected and is not a launch PASS.

## Remaining launch prerequisites

1. Acquire actual new implementation session/agent identities before validating the final manifest. The checked-in implementation scripts found are selector, snapshot, manifest/report validators and terminal-resume checker; no identity allocator was found there. Native codex exec --help exposes --json but no caller-selected session or agent ID option. A returned real host identity must be bound; do not manufacture values to satisfy the schema or reuse reviewer identities.
2. Persist a real invocation-time cost estimate, source and UTC timestamp. select-agent-model.sh requires supplied candidate costs. No cost was invented. Its invocation without candidates returned BLOCKED model-tier-unavailable; this establishes missing routing input, not that a model was actually unavailable.
3. Superseded by the v2 correction below: the v1-only registry conclusion was incomplete. The checked-in v2 registry explicitly admits gpt-6-astra/strong/high on codex-cli.
4. Finish required dependency admission for the implementation working copy. These 34 files form the known minimum handoff; imported modules, test helpers, applicable scoped instructions and task-required contracts must be added if read or executed. A needed unlisted input blocks, and requires republishing a new snapshot rather than changing this one.
5. Final allowed_outputs must name a separate staged output root because the validator rejects any input/output path overlap. Do not authorize the owner checkout wholesale. Bind the staged file mapping and only T-001 targets, report and verification artifacts. Existing sandbox proof supplied by coordinator covers a disposable workspace; verify the final launch uses the same exclusion settings and actual narrow output root.
6. Create task-input-manifest/v1 with real identity, routing/cost, exact input hashes and separate allowed outputs; run individual snapshot validation and batch validation over all persisted manifests before execution. Capability decision must select fresh-agent for the whole batch. This host supports independent implementation contexts; incapable-host fallback is not justified.
7. The orchestrator alone serializes tasks.md and report acceptance. Before any implementation, the actual worker must record target before-bytes and high-risk persisted-field/counterpart/executed RED mismatch evidence in its implementation report. No task state was changed by this preparation.

## Remaining command forms

After actual routing candidates and cost provenance are saved:
`rtk proxy bash plugins/sdd-implementation/scripts/select-agent-model.sh --risk high --host codex-cli --registry contracts/agent-model-capabilities.json --candidates-file reports/verification/shared-launch-handoff/T-001-candidates.json --json`

After the actual identity-backed T-001-manifest.json is saved:
`rtk proxy bash plugins/sdd-implementation/scripts/validate-task-input-manifest.sh --manifest reports/verification/shared-launch-handoff/T-001-manifest.json --snapshot-root reports/verification/shared-launch-handoff/T-001-snapshot --expected-task T-001`
`rtk proxy bash plugins/sdd-implementation/scripts/validate-task-input-manifest.sh --batch reports/verification/shared-launch-handoff/T-001-manifest.json`
Expand the batch list with every manifest persisted in this batch.

The final native implementation command cannot yet be truthfully fixed: its actual model, identity-bound launch mechanism, dependency-complete snapshot and output directory are unresolved. It must use /Users/jrmag/.nvm/versions/node/v24.13.0/bin/codex, workspace-write, sandbox_workspace_write.exclude_tmpdir_env_var=true and sandbox_workspace_write.exclude_slash_tmp=true, a narrow output working directory, and only the validated file handoff. No launch was executed.

Unperformed: implementation, RED/GREEN, rollback, independent review, quality gate, CI and Git delivery. The snapshot publication check proves copied immutable bytes only.
