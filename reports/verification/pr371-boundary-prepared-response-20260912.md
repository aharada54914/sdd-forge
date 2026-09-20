# PR #371: prepare the boundary fixture response before waiting

## Observed failure

GitHub Actions run 34631953936, Windows job 103370990475, tested
6fccd747e546c3172f54679399b3d26ae7b9abc9. The PowerShell cross-model suite
reported 62 passed and 2 failed: Gemini boundary repetitions 4 and 5 timed
out after recording wait_end, without recording output_end. Repetition 4
finished waiting 792 ms before the runner deadline. Response serialization
was still performed after that wait, making cold serialization/JIT work part
of the supposed completion instant.

Downloaded job log: /tmp/pr371-windows-34631953936.log
SHA256: b28f840ecbd4e49be7f885c7007d798d9b911172ce9c27b0baa3b8c420d9f997

## Scoped repair

Port the test-fixture repair already present in PR #381 commit
165d3038f1871e7f08ec5caafb9555f3cc0bdbbe. Serialize the same fixed response
before the timed wait, then write that response after the wait. No production
runner changes. The 2-second deadline, 800-ms completion margin, five
repetitions per runner, verdict checks, and timeout/descendant termination
assertions remain unchanged.

## Verification

- Local macOS: `rtk proxy pwsh -NoProfile -File tests/cross-model.tests.ps1`
  exited 0: 64 passed, 0 failed (terminal session 36486).
- Both runners completed all five boundary repetitions; timeout negative
  cases continued to require termination and absence of a verdict.
- `git diff --check` passed.
- Independent read-only reviewer `/root/pr371_merge_review` returned PASS
  for this scoped repair, confirming unchanged timeout and assertion rules.

This local result does not prove native Windows reliability. Fresh Windows
CI on the repair commit and all other applicable CI remain required before
merge. The earlier failed run is retained as a failure, not reclassified.
