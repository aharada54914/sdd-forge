# T-002 installer delta and evaluator input preparation — 2026-10-04

Scope: owner-side investigation and preparation only. No new distribution, identity reservation, evaluator launch, verdict, approval/status change, or protected-source edit occurred.

Owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`
Baseline HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`

## Finding: distinguish payload evidence from whole-tree currency

The earlier readiness note correctly says the old receipt is not a run of the new installer. It should **not** be interpreted as saying T-002 validator/helper distribution evidence is invalid or that another human build is necessarily a prerequisite for evaluating their ownership boundaries.

`git show HEAD:install.sh | shasum -a 256` returned `9b43d5eaf93a9cefffc562a3108f43ab2bc2a64c675a710ec5c59250f7abe719`, exactly the installer hash in the previous successful build note. `git diff -- install.sh` contains only the EXIT trap change at line 710: invoke `rollback` only when the captured status is nonzero. Current installer hash is `87bcebfeb53f6521f03cc62f2bc760902bd7af2d28ea24ffb2d29662b71bad50`.

- Selection and copying are unchanged: `install.sh:961-986` selects tracked names and reads working-tree bytes into staging. `install.sh:1007-1010` places that tree before registration. `git ls-files` confirms installer, validator, and helper are tracked.
- On the successful FilesOnly path, `REGISTRATION_STARTED=1` is set at line 1022; the old `rollback` registration branch at lines 687-695 retains the installed tree and prints the misleading registration-failure message. The normal success path already removes any backup and clears `NEW_INSTALL_PLACED`. The new trap skips that branch on exit 0, while retaining cleanup and the original exit code. This is source-level impact analysis, not a rerun of the old assembly.
- The validator remains `4794ef81888e83a4d45f37a680ab65436cd1ca97e1d01c59acf8a22dae898788`; helper remains `ea08dbd141b24f4685fd9211b4454d782e5ea80e081e0a59d89ee7f7fe5282ea`. Both match the prior installed-byte parity receipt. Its raw log hash still matches `450aba84af3339e078ec3f9f6e69d57928b1177fa24705edc294ddaf964a2fe8`.
- Therefore the old receipt remains evidence of those exact T-002 payload bytes having been assembled and executed. The source delta does not alter their copy logic or successful retention. It is not evidence that a whole current checkout was freshly distributed: `install.sh` itself is copied, so at least that installed file would differ. No whole-tree equality claim is made.

## Current installer behavioral verification

Command: `rtk proxy bash tests/install.tests.sh`, owner cwd, `login=false`.
Result: exit 0, `Results: 43 passed, 0 failed.`
Installer SHA-256: `87bcebfeb53f6521f03cc62f2bc760902bd7af2d28ea24ffb2d29662b71bad50`.
Test SHA-256: `648d093acbda64a1c3dff445fb2a97f537688a6f6426a64bd2701e36ff444bf4`.

The suite executes current owner `install.sh` (`tests/install.tests.sh:6-7`), overlays it into fixtures (`:41-58`), checks successful FilesOnly skip output and absence of the false failure warning (`:947-970`), lock release, and actual registration failure retaining the new tree (`:366-393`). Fixture payload starts from HEAD, not all dirty owner bytes (`:23`); these 43 tests do not replace the T-002-specific current-tree distribution command. They directly verify the changed success/error behavior without executing the human-only runner or routing around its restriction.

## Autonomous evaluator preparation completed

Created `reports/verification/issue423-t002-evaluator-input-candidate-20261004.json`, SHA-256 `eaea79e776ee9be5ca6e42fe349f246c8624a631726e1d84b130efbb5ce76843`.

The candidate holds 39 unique exact path/hash inputs assembled from the canonical T-002 report, its implementation manifest, nine specifications, calibration, and currently declared Outputs/Post-Fix Artifacts. Every pair was checked against its current file before writing. The current validator pair comes from the existing post-fix declaration, not the obsolete Outputs row. The candidate also pins that declaration and the implementation manifest.

It is deliberately **not** a `review-context-invocation/v2`: it contains no invented run/session, ledger tip, sequence, or scratch identity and cannot be used to reserve or launch. A ship orchestrator can reuse the candidate's input subset after immediate rehashing, then bind the genuinely allocated evaluator identity and current ledger state. No new human-only distribution execution is needed merely to prepare these inputs.

The candidate does not authorize this impact note, the readiness note, installer/test sources, or the private raw build log as evaluator inputs. If the evaluator needs this new impact analysis or installer regression evidence, the launcher must first declare those exact path/hash pairs in a new permitted Post-Fix Artifacts declaration and include them in the validated invocation. It must not paste their contents into the launch prompt or widen the input set informally. That declaration/prelaunch choice belongs to the coordinating ship flow; this preparation neither reserves an identity nor evaluates acceptance.

## Remaining boundaries

Human-only runner remains unexecuted and unchanged. A fresh full current-tree receipt, if required by the delivery scope, still uses that approved normal path. Existing exact-byte T-002 evidence and current installer regression may be presented separately without claiming such a receipt exists. Formal QG and ship's current-session handshake/track checks remain pending. Independent evaluation decides sufficiency; this note does not set a verdict or Done.
