# PR #393 primary dependency review

Status: MERGED after exact-head independent review and complete mandatory CI.

## Integration result — 2026-09-06

Run `34013683821` completed all 25 checks SUCCESS, including `required-checks`
and all three mandatory OS test jobs. Immediately before merge, head was still
`9abf555e865e6eb7b872effea036e5136bb2a8d4`; base and current main both equaled
`9dd531f94882eb18fe7f783de395cd1c7a8ee208`. Repository rulesets retained strict
updated-base checks and the one-approval rule. The branch-protection endpoint's
404 was not treated as absence of protection; `/rules/branches/main` supplied
the effective rules.

Independent review: https://github.com/aharada54914/sdd-forge/pull/393#pullrequestreview-5124334822.
Final preflight: https://github.com/aharada54914/sdd-forge/pull/393#issuecomment-5557269256.
The user-authorized approval-count bypass used `--match-head-commit` without
changing rules. GitHub confirmed MERGED at `2026-09-06T05:46:33Z`, merge commit
`bca037dd4477ae001de5ee683a9993b8a9946967`. No linked closing issues existed;
no unrelated issue was closed and no branch was deleted. Pending descriptions
below are retained as historical pre-merge observations.

## Updated-base verification

After PR391 merged, update-branch with expected old head succeeded. Fresh head
`9abf555e865e6eb7b872effea036e5136bb2a8d4` has base
`9dd531f94882eb18fe7f783de395cd1c7a8ee208`. Primary re-read the complete live
diff; the same two-file dependency delta remains. Worktree
`/tmp/sdd-forge-pr393b.NSU2U2` has the exact head and clean status.

Actual logs are `/tmp/pr393b-logs.o4QlkX`, obtained from
`/tmp/pr393b-logdir.txt` and inspected directly. The agent's first reported
directory did not exist; its subsequent claim that EXIT markers contain zero
was also incorrect (the markers are blank). Primary rejected both claims.
The preserved test summary is 148 pass, zero fail/cancelled/skipped/todo,
673.727459 ms; install and audit logs show zero vulnerabilities and both build
logs show completion. Primary independently verified tracked dist parity with
git diff --exit-code (exit 0).

To resolve the exit-status evidence gap, primary directly executed unchanged
`npm test` (tool chunk06e977: exit0, 148 pass, all other counts0,
425.71325 ms), `npm run typecheck` (chunk20534d: exit0), and
`npm audit --audit-level=low` (chunk61d089: exit0, zero vulnerabilities).
No test or production behavior was changed. No coverage percentage was measured.

Fresh GitHub run34013683821 is active; watch session14027 is the existing
handle. Local package success does not waive mandatory CI. All required checks
and a final head/base/rules recheck remain necessary before integration.

## Identity and scope

Primary re-read the complete live GitHub diff at head
`8359f6390ad1d3fc1b479c2dcb72eb3983621644`. GitHub reports base
`10ad36e76f5279c1d3689211f3b1feb3700864ca` and BEHIND. Exactly two files
change: `mcp/ci-mcp/package.json` and its lockfile. No source, bundled dist,
test, guard or workflow change is present. Approval is the user's bounded
dependency-only workflow exception, not a waiver of CI or strict base checks.

## Findings and checks

- Inspector is pinned from 2.3.0 to 2.5.0. Its new proper-lockfile dependency
  adds proper-lockfile 4.1.2, graceful-fs 4.2.11 and retry 0.12.0, all marked dev.
- Shared Hono changes from 4.13.0 to 4.13.5 and is not marked dev. Therefore
  describing the entire lockfile change as dev-only would be incorrect.
- Removed peer flags do not themselves change the versions of SDK, Node
  typings, esbuild, express, React-related existing packages, Vite, YAML or Zod.
- Primary npm registry queries match the lockfile's Inspector 2.5.0 and Hono
  4.13.5 integrity values. Inspector requires Node >=22.19.0, matching the
  project manifest; Hono requires >=16.9.0.
- Primary read the entire installed Inspector `scripts/install-clients.mjs`:
  it returns before spawning npm when its resolved package path includes the
  node_modules component. This is source inspection, not a lifecycle execution
  result; the package verification used npm ci --ignore-scripts.
- The package build is the manifest's esbuild command, not build.mjs (that
  guessed file does not exist). Prior independently checked tests, actual log
  paths and build parity are retained in
  `parallel-dependency-packages-20260906.md`. Primary again observed an empty
  git status in `/tmp/sdd-forge-pr393.4CAGMt`.

Critical findings: 0. No blocking finding in the reviewed dependency delta.
This is not a claim to have audited all upstream Inspector source or to have
completed a fresh-main integration gate. Refresh against resulting main after
the preceding integration, inspect the combined lockfile, and obtain complete
mandatory CI for that exact new head before merging. Do not close unrelated
issues or delete the branch based on this review.
