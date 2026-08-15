# Node 22 runtime baseline CI handoff

Status: Pending human application

Base commit: `bc2b135ee4cce7a3acb94cf9c15144789aa06af2`

Protected target: `.github/workflows/test.yml`

Patch: `docs/ci-staging/node22-runtime-baseline.patch`

SHA-256: `a237cca87fa2bbd6f4fbdaab6e374541cf552f44c6f80f0358e67752e96be3f3`

The repository's deterministic guard prohibits agents from modifying the
active workflow directly. A human must verify the base commit and digest,
then apply the staged patch from the repository root:

```bash
shasum -a 256 docs/ci-staging/node22-runtime-baseline.patch
git apply --check docs/ci-staging/node22-runtime-baseline.patch
git apply docs/ci-staging/node22-runtime-baseline.patch
```

The patch moves the three required MCP operating-system matrices from Node
20 to the supported floor, Node 22.19.0. Each required MCP job then repeats its tests on Node 24 only
in the Ubuntu lane, so a forward-compatibility failure also fails the existing
`required-checks` aggregation without changing the protected job graph.

The same patch closes the two pre-existing full-suite designed-red failures:
it registers the four deterministic-lane suites and makes both
`design-system-contract` runtime twins reachable from the active workflow.
It intentionally does not use either stale wholesale candidate:
`docs/ci-staging/test-yml-combined-candidate.yml` or
`specs/epic-136-phase3/verification/T-003/staged-workflow-candidate.draft.yml`.
Both predate landed workflow coverage and must never replace the current live
workflow. This base-bound patch is the sole authoritative handoff for the
changes described here.

Do not merge the runtime-baseline PR until the protected workflow change is
present and every required check is green.
