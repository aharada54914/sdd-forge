# RT002 snapshot mode candidate v4 — bounded child collection

## Scope and preflight

- Owner: `/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge`
- Observed owner HEAD: `1e86fb272643e798db4e1ca0c89f0402317a2fc8`.
- Work item: explicitly authorized additional limited correction of the v3 Bash copy-mode-race test's unbounded post-release child wait.
- Risk: high/protected shared snapshot behavior remains candidate-only. No approved contract change, Draft-task implementation, reservation, task-state change, installed-runtime promotion, commit or push.
- The original two builders and two suites were re-read after validation and remained byte-identical to the originals captured for this candidate work. Other checkout changes were preserved.
- v3 candidate, evidence and results remain unchanged. v4 uses separate filenames.
- coder/tester guidance was used for the focused candidate correction and failure-path verification.

## Minimal v3 to v4 change

Only the proposed Bash suite changes: after releasing the copy barrier, reuse the existing suite pattern of 1,500 iterations with a 0.01-second sleep and a child-liveness check before collecting status. A child still alive is killed with SIGKILL and collected with wait before reporting failure. The barrier-not-ready cleanup also uses SIGKILL before wait, so a stopped child cannot retain that cleanup path indefinitely.

The PowerShell proposed v4 suite is byte-identical to v3. Builder candidates retain v3 behavior. Runtime suite copies only substitute candidate routing; those substitutions are excluded from candidate-v4.patch.

This is a finite polling budget, not a strict 15-second wall-clock timeout: process and scheduler overhead add to the nominal sleep sum. The stopped-child run below measured 26.32 seconds. No claim is made about arbitrary descendant process-tree termination.

## Executed validation

All commands ran through rtk proxy with login=false in the owner checkout on the existing macOS environment; no rejected operation was rerouted.

| Check | Observed result |
| --- | --- |
| bash suite-candidate-v4.sh | Exit 0: task context isolation manifests, snapshots, fallback, and selector are deterministic |
| pwsh -NoLogo -NoProfile -File suite-candidate-v4.ps1 | Exit 0: PowerShell task context isolation manifests, snapshots, fallback, and selector are deterministic |
| git apply --check candidate-v4.patch | Exit 0, empty output; patch was not applied |
| Exact v4 wait block against a genuinely SIGSTOPped direct child | Experiment exit 0; tested block exit 1 with expected timeout diagnostic, elapsed 26.324561333982274 seconds |
| Child collection | PID 33961 absent after wait; stopped-child-v4.json records child_absent_after_wait=true |
| Protected original readback | All four original files unchanged |
| v3 to v4 diff | Only the Bash bounded-wait/cleanup correction described above |

The stopped-child experiment extracts the actual v4 polling/kill/wait block rather than a rewritten equivalent. Its outer subprocess timeout is 45 seconds and its observed-duration assertion is below 40 seconds. No child or command session from these completed checks remains running.

Files: candidate-v4.patch, suite-proposed-v4.sh, suite-proposed-v4.ps1, suite-candidate-v4.sh, suite-candidate-v4.ps1, stopped-child-v4.py, stopped-child-v4.json, suite-results-v4.json.

## Remaining boundaries and unverified work

- Independent v4 review and authorized protected application/readback remain pending.
- Native Windows/Git Bash and Linux CI were not run; no Windows PASS is claimed. Existing Unix-only guards and runtime/safety conditions remain.
- Manifest v1 continues to bind path/content hashes, not file modes. This candidate does not turn TASK_INPUT_OK into mode provenance.
- Formal contract approval/addendum, exact-final-head CI, installed promotion, and a fresh real RT002 execution remain pending.
- Prior USD 10.00 is only the explicitly supplied provisional planning estimate, not measured usage, billed cost or spending authorization. No fresh implementation identity is invented here.

## Candidate hashes

- candidate-v4.patch: `a1129be245b1e4b52035d66163939ba98c661e5a369b178b0b2709ed6b9ece2d`
- suite-proposed-v4.sh: `3f4c0daa832c41db0c2b9899073508616f910a867dbf6673f43afc0cb15a04b5`
- suite-proposed-v4.ps1: `ef3954581c1578914943e43cc3f73fd2bfd9e50ccd0d1f0355c632b25da8a1ae`

