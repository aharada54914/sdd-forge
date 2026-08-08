# Combined CI-staging candidate

`test-yml-combined-candidate.yml` is a staged replacement for
`.github/workflows/test.yml`. It registers the following currently-unregistered
paired test suites in the workflow's `test` job:

- `tests/design-system-contract.tests.{sh,ps1}` (DS-29 / TEST-039)
- `tests/design-sync-scan.tests.{sh,ps1}` (TEST-054)
- `tests/design-sync-standing-consent.tests.{sh,ps1}` (TEST-054)

Applying this candidate makes the three designed-red CI-registration cases
GREEN: TEST-039, TEST-054 for `design-sync-scan`, and TEST-054 for
`design-sync-standing-consent`.

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
