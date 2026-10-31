# T-003 native preparation (not launched)

Owner: `/Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge`
Prepared HEAD: `9ce19abe90df0cb83e385f96855e4843318a8807`
Scope: preparation only; no native launch, reservation, production/spec/status edits or formal review.

`prepare-native.cjs` reuses T-002 attempt 4's native app-server request and metadata pattern. A future authorized invocation obtains a real native session ID before constructing its task-bound manifest; no session identity is invented. Source hashes and executable modes are pinned in `before-byte-inventory.json` (53 exact files). `registry-topology.json` declares 50 existing, real, non-symlink directories, without admitting directory contents. The helper generates source-modes and admits 56 exact files in total. The sole native output is this handoff's `output/`.

Input rationale: approved task/spec/authority and implement-task contracts; canonical inventory, generator, four projections and four runtime guards; six entrypoint sources and host-preflight import closure; four caller skills; host tests, parity suite, both suite runners and actual `.github/workflows/test.yml`; structure registry/checker and report validator; pinned model-registration evidence; dot-path repair record. There are no broad directory admissions. Existing eight registration additions must remain intact.

Validation: `rtk proxy node --check .../prepare-native.cjs` exited 0. Read-only checks matched all 53 source SHA256/modes and verified all 50 topology directories. No native-thread-start-result exists. The parity suite only scans admitted fixture files; its passing result must not be represented as exhaustive inventory verification of the full owner checkout. Its regeneration copies occur solely inside the admitted disposable fixture.

Launch prerequisite: task status currently remains Approved/Planned. Any orchestrator status transition or other pinned-byte change requires explicit before-byte inventory refresh before launch; otherwise helper rejects stale input. Do not weaken that check. The preparation helper itself has not been executed.

Prompt requires high-risk persisted-field/counterpart/mismatch preflight, isolated mutation RED and restored-byte GREEN with hashes, truthful post-hoc reproduction labeling, real CI registration omission test, output delivery-index hashes, and explicit NOT RUN for formal review/quality gate/CI/installed-host or native Windows proof. RT-20261009-001's T-001 exception is not extended.
