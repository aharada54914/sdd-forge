# Issue #423 shared registration / CI preflight

Run ID: issue423-shared-registration-20261007
Task Attempt Count: 1

This is a non-frozen development record, not a formal gate verdict or task-state transition.

## Scope and ownership before edits

- Owner checkout: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`.
- HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`.
- Issue #423 shared launch connection; preserve `sdd-domain-multitarget` T-002 approval/status and all historical evidence.
- Risk: high/protected. This changes the protection inventory and CI execution inventory, not task acceptance, identity or reservation semantics.
- Targets: `plugins/sdd-quality-loop/references/guard-invariants.json`, `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`, four siblings under `plugins/sdd-quality-loop/scripts/generated/guard*`, and `.github/workflows/test.yml`.
- Do not edit `validate-nontty-spec-launch.py`, `probe-nontty-review.py`, or `tests/quality-nontty-transport.tests.py`; another owner is performing native verification. No reservation, native launch, publication, commit, install or baseline change is authorized here.
- Existing tracked dirty work spans evaluator definitions, AGENTS.md, install.sh, registry discovery/validation, both canonical review validators, quality-gate skill, boundary reference, both role renderers, T-001/T-002 implementation and verification evidence, ledger, task plan, and existing regression/run-all scripts. Existing untracked shared launch scripts and reports are preserved. None of the seven registration/CI targets is initially dirty.

## Contract and validation preflight

| Persisted field / claim | Counterpart | Required mismatch / negative verification |
| --- | --- | --- |
| `protected_gate_suffixes` additions | generator exact `BASELINE_SUFFIXES` union | canonical-only or generator-only addition must reject |
| Four generated projections and source digest | canonical JSON + existing generator | `--check` must reject missing/stale projection; regeneration must be deterministic |
| New entrypoints are protected | existing guard runtime consumers | write-shaped operations targeting each new path denied; unrelated read allowed |
| CI transport test registration | existing quality transport suite and runtime dependencies | suite actually runs without skipped missing dependencies; inventory checker detects omission |

Required validation: bounded fixture generation/check, Bash/PowerShell invariant regressions as applicable, exact registration positive/negative checks, CI structure/inventory check, independent diff review. Native Windows/host activation and current-head hosted CI remain unexecuted unless separately observed.

## Application boundary

`docs/development-policy.md` requires the sanctioned scope/hash-bound protected application path. The earlier shared-launch report records that the existing 18-target Windows/NTFS runner and separate Node 22 workflow patch do not admit this target subset. No current write refusal has occurred; historical refusals are not treated as current denials. Candidate preparation is allowed, but the applicable owner application route must be resolved before changing protected owner targets.

CI dependency finding: the transport fixture currently invokes `rtk proxy node` (`tests/quality-nontty-transport.tests.py:334`) while `.github/workflows/test.yml` has no RTK preparation. A bare test step would not establish runnable CI coverage. Dependency preparation must be included without presenting a fixture proxy as native-host proof.

## Candidate verification (not owner application)

Application authorization update: the coordinator explicitly authorized applying this six-entrypoint registration candidate in this owner checkout, connecting the permanent test/CI path, and replacing only the fixture's `rtk proxy node` subprocess wrapper with direct `node`. This is the scoped implementation authority for the exact before/candidate pins below, not a general hook bypass or installation authority. HEAD remains unchanged; all seven protected target before hashes were re-read and match this record. Use the ordinary editing/generator path; stop on any actual refusal rather than changing executor. Prior application-pending statements describe the earlier state and are superseded only for this bounded delta.

Candidate: `issue423-shared-registration-candidate-20261007.patch`; disposable driver: `issue423-shared-registration-candidate.tests.py` in this directory. The patch adds only six entrypoint paths after the existing task-review precheck in the baseline/canonical inventory, then uses the existing generator functions for all four projections. It does not alter `phase2_human_copy_targets`, shell parsing or other policy fields.

Executed `rtk proxy python3 -B reports/verification/issue423-shared-registration-candidate.tests.py`: 4 tests passed. Coverage includes exact additive inventory/order; generator `--check`, deterministic regeneration and stale-output refusal; generator-only/canonical-only mismatch rejection; and 48 guard decisions (Python, Node, Bash wrapper, PowerShell on macOS × six paths × write denial/read allowance). The first fixture run incorrectly delivered only the PAYLOAD environment variable to the Bash wrapper, which reads stdin; six read assertions failed with malformed-payload errors. The fixture was corrected to deliver JSON on stdin as well, then all four tests passed. No product change was made to accommodate the fixture.

`git diff --check` passed. All six protected owner targets and `.github/workflows/test.yml` remain clean/unchanged. No owner ledger/reservation/native launch or installation was performed. Candidate checks are not native Windows, installed-hook activation, formal acceptance or CI evidence. Independent candidate review and sanctioned owner application remain pending.

| Candidate target | Owner before SHA-256 | Candidate SHA-256 |
| --- | --- | --- |
| `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` | `344e035ea9313d0d39a1972e9c1084d9cfaf8afa6e31802222fe9df44c3b1757` | `d07e11567d750d3250b6cf66f819f94bfbe44d300a4a62ea2575865400346d12` |
| `plugins/sdd-quality-loop/references/guard-invariants.json` | `e37af15bfa44cc04029e65f25602fe9bc617594e847b9af3bceeb450e31367f5` | `ee21fcc622b31fde2d31dff70316052372839d2f2366bf9eb46d0d5c43ef64a5` |
| `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` | `777a8a0f880f52a066b111daf6f8e204381f6a3604c77a70a3dce0070b0b9197` | `025e134865d1b54e7be2e9aa52f227ca2669641000829dce5edef10ea2143974` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js` | `7818d14498781683739c2238339db55dea3d9cd6f907741673b60379a9afc821` | `ea18b3bc200b9e7e6b48ee3f582d6ae58571ee686c8b4624a6d131b5976da1ea` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1` | `ab7900a4e6ac25f6233642b86a40cb1071b68ea782bbcc718379065f3d5c6f9e` | `70bd561d72e643dcaa7b02f365d48d3a7067b92ebfb2dae99059e0ce29fe2bec` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh` | `f919a53dd72d450fd3a37fabefc431d683e3d567cb1cfe7689d5ced1c8095f4c` | `bab185d4d0b8924a9136bf9e542cde92b778f24e4a871d98036fa2b42a12f33d` |

## Owner application and local regression addendum

The bounded authorized application is complete. This section supersedes the earlier owner-unchanged/application-pending observations, not their historical record. All six applied protected files read back to the candidate hashes above. The ordinary editing and existing generator path accepted the application; no denied operation was rerouted. No frozen artifacts, transport/probe implementation, ledger, reservation, installed baseline or Git state were changed by this work.

The six new protected entries are `launch-impl-review.py`, `preflight-host-review.py`, `validate-nontty-spec-launch.py`, `probe-nontty-review.py`, and `nontty-impl-pretool-guard.mjs` under `plugins/sdd-review-loop/scripts/`, plus `plugins/sdd-quality-loop/scripts/preflight-evaluator-delivery.py`. Both canonical and generator inventories contain exactly those additions; all four projections were generated by the existing generator.

Permanent CI now invokes `python3 -B tests/quality-nontty-transport.tests.py` in the POSIX regression job. Existing `run-all.sh`/`run-all.ps1` registrations and existing CI generator/invariant checks are retained. Only this worker's fixture launcher line changed from `rtk proxy node` to direct `node`; inspected command strings, actual guard and expectations are unchanged. No fake RTK proxy or new dependency was installed. The latest suite also includes another owner's concurrent test addition (`test_diagnostic_reads_are_representative_not_all_inputs`); this worker did not author it.

Executed results:

- Existing generator regeneration and `--check`: exit 0; six SHA-256 values match the candidate table.
- Transport suite: initial 14/14 passed. Subsequent execution with PATH containing only a symlink to the actual Node executable (no RTK) passed the latest 15/15. This proves only fixture-wrapper dependency independence, not native launch or installed-host activation.
- Bash Phase 2 invariant suite: 42 passed, 0 failed.
- PowerShell Phase 2 invariant suite on macOS: 55 passed, 0 failed, 1 existing skip. Skipped branch: TEST-013 installed runner reads evicted staged canonical; its separately governed refresh remains pending. This is not native Windows proof.
- Disposable candidate driver after application: 4/4 passed, including 48 write-denial/read-allowance decisions across four guard runtimes. Its reverse/reapply operation is confined to the temporary copied fixture, never owner files.
- `git diff --check`: exit 0. Source/list and CI diff inspected; existing unrelated dirty changes retained.

CI workflow readback SHA-256: `964cf2d64080691c308833e37f17bbe1744817b2925f382d75bb8fc522c7f008`.
Latest transport suite observed SHA-256: `947c6b27493bc3aa77530bf3649cea87f3b76e45dd557786d5fb5a7224319400` (includes the separately owned concurrent addition).

Outstanding: independent review of this applied delta, hosted CI at the exact final HEAD, and separately owned native-host validation. No formal quality-gate verdict or task-state transition is asserted. No commit, push or publication was performed.
