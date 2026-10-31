# T-001 TEST-075–078 display-label candidate (2026-10-02)

Candidate: `reports/verification/issue290-t001-test-id-labels-20261002.patch`.
The protected test drivers were not edited.

| Target | Before SHA-256 |
| --- | --- |
| `tests/validate-approval-sidecar.tests.sh` | `ff9aed33cfa41026be40fba8c46f882aaa3fe870cc1b4b276a24ded17a37b2f3` |
| `tests/validate-approval-sidecar.tests.ps1` | `43960010e5e0da653486a0955cd7789951288c77b4cb9e996942dcb04b472a38` |

The patch changes only the PASS/FAIL display label mapping in the Markdown
mismatch helpers. It leaves fixture IDs and paths, fixture content, validator
invocations, expected exit codes, and assertions unchanged. The corrected
labels match `acceptance-tests.md`: NEW = TEST-075, CONFLICT = TEST-076,
HUMAN = TEST-077, FITS = TEST-037/078.

Read-only difference check: `rtk proxy patch --dry-run -p1 -i
reports/verification/issue290-t001-test-id-labels-20261002.patch` exited 0 and
reported both target files. The before hashes were re-read unchanged after the
dry run. No post-application suite result is claimed.

Existing `issue290-iconv-human-apply.py` and `issue290-minitems-human-apply.py`
are hash-pinned to different single-file repairs; neither is a generic patch
applier. No new application script was created. The existing
`specs/sdd-domain-concept-test/verification/T-001/evidence-map.md` was preserved.
