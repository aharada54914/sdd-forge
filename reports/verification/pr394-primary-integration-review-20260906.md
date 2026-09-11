# PR394 primary integration review

## Latest-main integration candidate

Candidate 423edd3b0f9f6710e1de00183e4040fdd8de8ef3 has parents 9901e8657bd591600a85a272867cf7339626c5c3 and current main 4366438f3b243210a4ece5a17f873ca2d920600a (primary 4ab542). Full delta versus main remains exactly the manifest, lock and generated bundle in mcp/sdd-forge-mcp (20e410). Primary read the entire manifest/lock delta (b9ab5b): only zod 4.4.3 to 4.5.4, preserving main's js-yaml 5.4.1 and other dependency updates. Independently rebuilt (04a8f0), confirmed byte-identical tracked bundle (26e8a6), diff check (66e9e1), and clean worktree (f4a636). No blocking scoped dependency review finding.

Primary read actual final test log /tmp/pr394-test-final.XXXXXX.log (92ec8f): 247 passed, zero failed/cancelled/skipped, 11085.181792 ms. Worker reports final full test exit 0 using the /bin-first PATH. Install with scripts disabled, typecheck, production audit, and two build logs use /tmp/pr394-{ci,typecheck,audit,build}-postmerge.XXXXXX.log and /tmp/pr394-build-postmerge-2.XXXXXX.log; primary read these (54d4a4, 60475f), including zero vulnerabilities. Install emits an upstream server-legacy deprecation warning, not a clean warning-free claim. An earlier intermediate test failed while the unresolved bundle still contained a merge marker; rebuilding corrected that local candidate defect. This is not classified as transient or evidence that historical Windows deadline failures are fixed.

Publish this new combination for exact-head CI; no main merge, historical FAIL reversal, or issue closure is authorized by these local results alone.

Candidate: 9901e8657bd591600a85a272867cf7339626c5c3
Current main verified via commits/main API: 91cf642ccbacbae3dafdf4ee89386eb3275e612f

Primary inspected the complete manifest/lock delta against current main:
only sdd-forge-mcp zod 4.4.3 -> 4.5.4 and its matching root requirement,
registry tarball and integrity change. The registry integrity was independently
queried and matches. The third changed file is the tracked generated bundle.
Primary rebuilt it with the declared npm build script (chunk b6476f, exit 0)
and verified byte equality with the candidate using git diff --exit-code
(b4e814, exit 0). No application source or test changes are present.
Full candidate diff checking succeeds (547190). Worker worktree is clean.

Primary read actual test log summaries: ci-mcp 148 pass, zero fail/cancel/skip;
sdd-forge-mcp 247 pass, zero fail/cancel/skip under the labelled /bin-first PATH
runtime comparison. The default Homebrew Bash run was terminated with exit 143
after hanging; a serial diagnostic had pending-promise failures. Neither is
reported as a pass. Logs: /tmp/pr394-ci-mcp-npm-test.log,
/tmp/pr394-sdd-mcp-npm-test-binpath.log,
/tmp/pr394-sdd-mcp-node-test-serial.log. Production npm audit reports zero
vulnerabilities. Worker reports both package typechecks passed.

Scoped dependency integration review: accepted for publication to existing PR.
This is not a main-merge decision. Mandatory exact-head CI, fresh main ancestry
and the approval-only bypass conditions must be checked before merge.
PR has no closing issue references. No issue closure is justified by this PR.

## Exact-head CI failure — 2026-09-06

Run 34017470829 failed at the published candidate above. Windows job
101443710794 records TEST-004(c), GPT iteration 4: elapsed_ms=2749,
deadline_ms=2000, stub_launch_ms=720, exit=1, verdict=0. The suite ends
with 63 passed, 1 failed. Primary read the captured log (tool output df6cd5).
No underlying runner error reason was emitted in that failure excerpt.

Log: `/tmp/pr394-win-job-101443710794.log`; SHA-256:
`1b3af34c545b3e7ab3b76d7362ec34041c6cf5f6219c9b9a44b7bf6f335db7f9`.

The cause remains unproven. An untouched test and a similar historical
failure do not establish that the dependency change is unrelated. This FAIL
must not be replaced by an unsupported baseline-failure claim or treated as
merge-eligible. Current main has since advanced to b4fa4ef399f99d3bec0798718b75587ad672c7bf.
