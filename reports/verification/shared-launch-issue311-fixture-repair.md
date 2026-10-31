# Shared launcher: scratch fixture migration

Owner: shared-review-launch-integration/sdd-forge
Base HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807
Task: shared-review-launch-repair T-004 integration regression follow-up

The existing dirty candidate and historical task evidence are preserved. This
routine fixture-only correction supplies the implementation manifest and report
identity already required by the candidate validator. It reuses the fixture in
`tests/review-scratch-history.tests.py`; no validator, approval, ledger protocol,
assertion, required check, or historical verdict is changed.

Before correction, the full POSIX run in `/tmp/shared-launch-t004-posix.log`
reported 26 failures and two passes in this driver: legacy fixtures stopped at
implementation binding before reaching their scratch-isolation assertions.

Required validation: all 14 cases in Bash and PowerShell, including unchanged
ledger on rejection, saved snapshot identity, changed/omitted scratch-root
rejection, and tampered/deleted snapshot rejection. Independent diff review and
final-candidate full regressions remain required. This note does not amend the
historical T-004 implementation snapshot or declare the task Done.

Executed after correction: `python3 tests/issue311-scratch-isolation.tests.py
--repo .` exited 0, PASS 28 / FAIL 0. Independent read-only diff review found
no blockers; it checked binding fields, validator compatibility, unchanged
assertions and whitespace, and did not claim a formal gate verdict.

The PowerShell full runner also stopped because it invoked `python` exclusively
on a host providing `python3`. The bounded runner correction reuses the existing
python3-then-python resolution pattern, retains all three registered suites and
records each suite as failed when neither interpreter exists. A permanent test
executes the actual runner loop with controlled command discovery and checks
preference, fallback, missing runtime and nonzero suite exits. No product contract
or historical evidence is changed; full final-candidate regression remains pending.

Executed runner checks: `tests/run-all-python.tests.ps1` passed all four cases;
the three Python suites reached through the corrected runner passed 53 tests
(20 transport, 17 supplemental delivery, 16 evaluation preparation). Independent
diff review and a separate four-case rerun found no blockers. These results do
not establish native Windows, full aggregate CI, or a formal quality verdict.
