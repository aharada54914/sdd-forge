# Component coverage regression repair

Base: `021cf42c43981e4e8d4ffa4dde687d8ceffdf8a8`.

Actual focused Red after hydrating sparse-checkout fixture/archive/task dependencies: `bash tests/check-component-coverage.tests.sh` exited 1, 45 passed / 1 failed. TEST-036.4 reported `applied hash mismatch: plugins/sdd-review-loop/scripts/spec-review-precheck.sh`. See `red-bash.log`. Earlier local logs retain missing sparse-checkout dependencies; they are not the actual CI cause.

Cause: the A3 shared archive manifest also pins live spec-review prechecks. A9 T-002 deliberately changed both prechecks. The T002 reviewed-candidate-manifest at the base commit binds their new bytes. The frozen archive remains unchanged.

Fix: both component suites authenticate the same two exact successor SHA256 constants through `tests/lib/component-coverage-successors.py`. Constants were compared to `git show 021cf42c:specs/a9-interrupted-review-recovery/verification/T-002/reviewed-candidate-manifest.json`, not generated from live files under test. All archive hashes, other live rows, and existing additive-invariant controls remain enforced. The helper rejects appended, empty, and missing files independently for each runtime (six negative controls) and accepts real and copied exact bytes. No product implementation, coverage applicability, gate, or formal status changed.

First Green: Bash 46/46, PowerShell 47/47 on Linux. Final logs after tightening the PowerShell live hash comparison and using an ordinal string dictionary (without ConvertFrom-Json -AsHashtable): `green-bash.log`, `green-powershell.log`. Bash syntax and `git diff --check` pass.

CI metadata names this Bash suite as the Ubuntu/Mac version-gates failed step. Windows ownership includes its PowerShell twin, which shares the archival assumption. GitHub job log retrieval redirected to an inaccessible blob (Forbidden); the precise Windows failed sub-suite is not claimed as observed. Actual Windows/macOS reruns remain pending CI. Existing workflow-state formal binding failures are separate and intentionally unresolved here.

T-003 will intentionally change prechecks again. After independent review, update these two fixed pins to that reviewed source, compare them to its saved review manifest, and rerun both suites and mutation controls. Never compute an automatic expected hash from live bytes.

No push, formal gate verdict, private ledger operation, live recovery, or provider call was performed.
