# Preserve frozen parity coverage while adding helper protection tests

Run 41163869095, Windows job 124427466395, found that the two new helper
read/write cases in guard-parity changed a file whose existing phase2 inventory
requires exact frozen bytes. This is separate from the protected-helper defect,
which remains fixed in the canonical/generated guard lists.

Restored tests/guard-parity.tests.sh byte-for-byte to its frozen counterpart.
Moved the added real Python/JavaScript guard write-denial and read-allowance
checks into the existing unfrozen fixed-review-inputs suite. No test expectation,
protected path or frozen file was weakened, and no new successor exception was
introduced. The earlier 264-case local run remains historical evidence at its
recorded source; the additional checks now live in the dedicated helper suite.

Local results: fixed-review-inputs 36 passed; phase2 Bash 42 passed;
phase2 PowerShell 55 passed and one existing installed-runner capability skip.
Both phase2 checks now validate staged/current parity. PowerShell was executed
on Linux; this is not a claim of Windows hosted success. Ruff and diff checks
passed. Logs and exact test-source hashes are retained for the new hosted run.
