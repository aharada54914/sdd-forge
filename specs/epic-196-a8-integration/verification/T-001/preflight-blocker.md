# T-001 Preflight Blocker

Date: 2026-08-09

Run ID: epic196-a8-t001-codex-20260809-01

Task Attempt Count: 1

## Result

Implementation and the acceptance-first Red run did not start because the
post-review repository state makes the approved T-001 contract internally
unsatisfiable.

## Re-verification evidence

The task package was authored against Epic A1 commit
`661e05d29927806fb7204d3e0fa49a25024f9c22`. At implementation preflight:

- `origin/main` was `f8dc6f54bc3fb55adc26b3ebdf2752776e991d7d`.
- `git merge-base HEAD origin/main` returned the same commit.
- `git show -s --format='%H %cs %s' a8d65c73` reported
  `a8d65c7316f53787121874968e14878bc90c75aa 2026-08-08 Merge pull request #229 from aharada54914/feature/epic-189-a1-project-context`.
- The current tree contains the three canonical handshake scripts and all five
  consumer entry points named by `design.md`; none is a branch-only addition in
  `git diff --name-only origin/main...HEAD`.
- `git branch -a --contains 661e05d29927806fb7204d3e0fa49a25024f9c22`
  includes `main` and `origin/main`.

An exact `git cat-file` read command naming the canonical protected paths was
also rejected by the deterministic PreToolUse gate. Per the user instruction,
the command was not retried with split or encoded strings to evade matching.

## Contract conflict

The approved T-001 task requires TEST-006 to emit the AC-006 canary as an
allowlisted, non-failing `SKIP` with `coverage_complete: false`, and its Out of
Scope section explicitly excludes un-skipping AC-006 or exercising Epic A1's
artifacts until a follow-up after Epic A1 merges.

The frozen design's `SKIP Allowlist Activation Gate` simultaneously requires an
Epic-A1-dependent `SKIP` to become a non-zero hard failure once its canonical
artifacts exist on `main`. That activation condition is now true. Consequently:

- retaining the required T-001 `SKIP` cannot produce the required Green run;
- treating the canary as PASS would perform work explicitly placed Out of Scope;
- ignoring activation would violate the design and would register a new failing
  or fail-open suite in `tests/run-all.sh` and `tests/run-all.ps1`.

The repository's post-review artifact-freeze rule prevents resolving this by
silently editing the approved task or design. A human decision is required to
authorize either a post-A1 T-001 wording amendment/re-review or an intentional
blocked implementation that preserves the stale-SKIP failure.

## Other verified preflight facts

- Required Workflow: `acceptance-first`.
- PowerShell is available: `PowerShell 7.6.2`.
- Live `.github/workflows/test.yml` baseline SHA-256:
  `8beba70cd04800f9ab79c24b911c9f43043968edf3362bbcd2ac50e76c380998`.
- The user-prohibited `specs/*/human-copy/` paths and live workflow were not
  written.
- `specs/epic-196-a8-integration/tasks.md` was not edited by this attempt.
- No fixture, suite, allowlist, runner registration, or CI draft was authored.
- No test command or Red probe was run because doing so would first require
  selecting one side of the conflicting acceptance contract.
