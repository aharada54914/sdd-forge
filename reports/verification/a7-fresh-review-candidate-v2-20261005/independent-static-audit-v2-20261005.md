# A7 fresh-review recovery v2: independent static audit

Status: informal, read-only static audit of the unapplied candidate. Not a formal SDD review, behavioral test, admission, reservation, or verdict.

## Result

No concrete Critical or Major defect found in the v2 candidate against the limited recovery objective: retain the prior attempt-7/8/9 records, classify old outputs as diagnostic-only without establishing 8-to-9 transition legality, bind an orchestrator-transcribed existing user approval to current inputs and attempt 10, and permit only a fresh attempt-10 round-1 precheck. This finding does not assert that the real recovery contract exists or would pass.

## Static evidence reviewed

- `fresh-review-recovery.py.candidate:46-66, 72-88, 89-176`: the contract is constrained to a regular repository-relative `reports/verification/` file and binds current Pending inputs, exact historical evidence inventory and hashes, both predecessor A reservations, a scoped approval audit record, and `historical_disposition` values `diagnostic-only` / `not-established`. This is an audit transcription, not a cryptographic signature; its real-world source must be checked by the orchestrator before contract creation.
- `spec-review-precheck.sh.candidate:393-412, 486-501, 535-538` and `spec-review-precheck.ps1.candidate:600-626, 736-753, 808-812`: the opt-in path validates before and after the transition lock, refuses an occupied destination, and writes contract-relative path and SHA-256 into the new precheck. The precheck itself does not allocate an identity or issue a verdict.
- `SKILL.md.candidate:52-79` explicitly excludes adoption of a resumed PASS and directs a fresh host/reviewer launch. `spec-review-fresh-recovery.fixture.py.candidate:81-158` includes positive path/hash persistence and negative hash, disposition, reservation, and authority-scope cases. Synthetic fixture data is proper test data, not a real authorization claim.
- `recovery.patch` changes only the candidate's five intended files; the README identifies the baseline and after hashes and reports syntax and apply-check results. I did not run those checks independently or execute the candidate.

## Remaining verification boundary

The real approval audit record and recovery contract are not present. Before any real attempt-10 precheck, the orchestrator must transcribe and verify the actual user approval, calculate the current input/evidence hashes, retain the contract under `reports/verification/`, and perform isolated behavioral checks after authorized apply. This is an execution prerequisite, not an additional demand for a new user approval or historical legality proof. Static inspection cannot establish host behavior, actual admission, independent reviewer validity, PASS, or Done.
