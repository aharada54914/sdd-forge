Task ID: T-004
Feature: verification-first-factory
Run ID: eb022b4b-fb3d-4c06-88c0-56ae912547ed
VERDICT: NEEDS_WORK
Critical: 0
Major: 1
Minor: 0

- **VERDICT**: NEEDS_WORK

# Independent quality gate for T-004

Evaluators verified all 36 admitted hashes at `f1fd85c2f609fc9d79d2bb5d94db519f9182e7a3`. G1 through G5 were reviewed by `eb022b4b-fb3d-4c06-88c0-56ae912547ed` (ledger 1243). Machine execution `e3321adc-da6a-4078-8d39-4bc4fa07a111` returned PASS.

G1, G3 and G4 identified one Major defect affecting REQ-008. In strict mode both invalid-date and 2026-99-99 exempted a real no-empty-catch finding with exit 0. The past-date control returned exit 1 and the current-date control returned 0. RT-20261126-009 tracks the correction.

G2 passed. The approved Layer 1 baseline has 677 lines identical to upstream. Drift was CLEAN. Three path warnings concern CI and tests that exercise this feature. G5 does not apply to this CLI. All 70 historical comparisons matched across 401 file observations, including the six generated exceptions matched to their sources. Both tested revisions reported ten shadow warnings across 51 files. The two test groups passed 26/26 and 28/28, and actionlint passed. The two local timing pairs showed +0.173 s and -0.042 s. Independent hosted incremental CI timing and evidence for promotion to strict remain outstanding. No global policy change was authorized by these measurements.
