# Combined CI-staging candidate

`test-yml-combined-candidate.yml` is a staged replacement for
`.github/workflows/test.yml`, rebuilt on top of the live workflow as merged by
PR #229 (epic-189-a1-project-context, 854 lines). Earlier candidates at this
path, and the standalone draft that issue #135 staged under
`specs/issue-135-mcp-deps-ci/human-copy/`, were both built on a pre-#229 base;
applying either would have reverted the ~164 lines PR #229 added to the
`version-gates` job. This candidate carries no such regression -- it is a
pure superset of the current live workflow (45 inserted lines, 0 removed,
verified by diff).

It bundles two independent staged changes:

1. **Test-suite registration** -- registers the following currently-
   unregistered paired test suites in the workflow's `test` job:

   - `tests/design-system-contract.tests.{sh,ps1}` (DS-29 / TEST-039)
   - `tests/design-sync-scan.tests.{sh,ps1}`
   - `tests/design-sync-standing-consent.tests.{sh,ps1}` (TEST-054)

2. **npm audit signatures (issue #135)** -- adds a `Verify registry
   signatures` step (`npm audit signatures`) immediately after the existing
   `Audit production dependencies` step in each of the `mcp-tests`,
   `local-env-mcp-tests`, and `ci-mcp-tests` jobs.

Applying this candidate makes two designed-red CI-registration cases GREEN:
`design-system-contract` TEST-039 (DS-29, AC-024) and
`design-sync-standing-consent` TEST-054 (AC-028). `design-sync-scan` does not
currently carry an equivalent CI-reachability designed-red assertion -- its
only registration check, TEST-053, asserts registration in
`tests/run-all.{sh,ps1}` and already passes. Registering `design-sync-scan`
here closes the same run-all-vs-CI-workflow gap the other two suites had, but
no unit test flips for it specifically. The `npm audit signatures` step is
not gated by a designed-red test in this repository; it is issue #135's
staged CI-hardening change. It was previously staged as a standalone draft at
`specs/issue-135-mcp-deps-ci/human-copy/.github/workflows/test.yml`, which has
been removed now that this combined candidate covers it -- issue #135 is not
an SDD feature, so that `specs/` directory had no `workflow-state-registry.json`
entry and was blocking CI's `test` job on all three OSes.

**Known blocker: apply after `TEST-038` is resolved.** Applying this
candidate puts `tests/design-system-contract.tests.sh` under CI enforcement
for the first time. As of this writing, that suite's TEST-038 (lite-spec
staged/live parity, AC-023) is FAILING on `main` -- PR #229 changed the live
`plugins/sdd-lite/skills/lite-spec/SKILL.md` to a third state that matches
neither DS-29's staged candidate nor a pre-apply baseline. Applying this
CI-staging candidate before TEST-038 is resolved will turn the `test` job
red on every OS. Resolve TEST-038 first, then apply.

## OQ-5 merge option

This combined candidate is a superset and upgrade of the existing single-suite
candidate at
`specs/design-sync-standing-consent/verification/T-005/staged-workflow-candidate.draft.yml`:
it includes that standing-consent suite and adds the design-system-contract and
design-sync-scan suites. Applying this combined candidate is an alternative to
applying the single-suite candidate. Under the OQ-5 merge option, apply this
combined candidate instead; once applied, the single-suite candidate is
superseded.

## Apply and verify

From the repository root, run:

```sh
cp docs/ci-staging/test-yml-combined-candidate.yml .github/workflows/test.yml
shasum -a 256 -c docs/ci-staging/MANIFEST.sha256
git add .github/workflows/test.yml docs/ci-staging/
git commit -m "ci: register design system and design sync test suites"
```

On a platform without `shasum`, use an equivalent SHA-256 manifest checker such
as `sha256sum -c docs/ci-staging/MANIFEST.sha256`.
