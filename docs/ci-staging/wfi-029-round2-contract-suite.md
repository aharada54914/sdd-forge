# impl-review round-2 contract suite CI handoff

Status: Pending human application

Base commit: `fcb363d60d2e7f0b44672e4e558609b3a3b3898e`

Protected target: `.github/workflows/test.yml`

Patch: `docs/ci-staging/wfi-029-round2-contract-suite.patch`

SHA-256: `8b32c3f089724b24c0b2693595f1dab99f5bb757bcfac4547268160b77e394d9`

The repository's deterministic guard prohibits agents from modifying the active
workflow directly. A human must verify the base commit and digest, then apply
the staged patch from the repository root:

```bash
shasum -a 256 docs/ci-staging/wfi-029-round2-contract-suite.patch
git apply --check docs/ci-staging/wfi-029-round2-contract-suite.patch
git apply docs/ci-staging/wfi-029-round2-contract-suite.patch
```

The patch adds one line: it registers `tests/impl-review-round2-contract.tests.sh`
in the workflow's existing "Test portable review-loop prechecks (bash)" step,
immediately after `tests/task-review-precheck.tests.sh`. No job, matrix, or
`required-checks` change; the protected job graph is untouched.

The suite is already registered in `tests/run-all.sh`, but CI enumerates suites
individually rather than invoking `run-all`, so run-all registration alone
leaves it unreachable from the workflow. This patch closes that gap.

The suite is sh-only, matching its neighbours in the same family
(`task-review-precheck`, `review-context-boundary`, `review-agent-isolation`),
so there is no pwsh twin to register and `tests/run-all.ps1` is unchanged.

It is deterministic: no LLM, no network, no `gh`, no live sudo grant. It builds
its fixtures under `specs/impl-review-round2-fixture/` and
`reports/{spec,impl,task}-review/impl-review-round2-fixture/`, registers a
temporary `lite` entry in `specs/workflow-state-registry.json`, and restores the
registry and removes every fixture directory from a `trap cleanup EXIT`.

This patch does not use `docs/ci-staging/test-yml-combined-candidate.yml`, which
`docs/ci-staging/README.md` marks superseded and which must never replace the
live workflow. It is a current-base, digest-bound patch in the same form as
`node22-runtime-baseline.patch`.

Context: `reports/notes/wfi-029-apply-steps.md` (WFI-029 defects 1-4).
