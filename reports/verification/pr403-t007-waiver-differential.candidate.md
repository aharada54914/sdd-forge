# PR #403 T-007 candidate red/green verification

Candidate-only rerun; this does not rewrite or retroactively validate historical waiver evidence.

## Red probes: protected Second Approval writes must be denied

PowerShell hook suite: PASS
ok: ps sudo: Second Approval denied even with valid sudo (exit 2) -- sudo does NOT bypass
ok: ps: edit adds Second Approval -> deny (exit 2)

## Green probes: approved/independent paths and T-007 candidate checks

ok: sh sudo: primary Approval WITH valid sudo -> allow (exit 0) — primary guard behavior unchanged
ok: wfi016: outside CWD + CLAUDE_PROJECT_DIR + PASS verdict -> allow
POSIX hook guard suite: PASS
ok: sh sudo: Second Approval denied even with valid sudo (exit 2) — sudo does NOT bypass
ok: py sudo: Second Approval denied even with valid sudo (exit 2) — sudo does NOT bypass
ok: node sudo: Second Approval denied even with valid sudo (exit 2) — sudo does NOT bypass
ok: sh: edit adds Second Approval to tasks.md -> deny (exit 2)
T-007 focused candidate regressions: PASS
candidate regression passed (33 checks)

## Scope and limitation

- Both platform suites exercise Second Approval write-deny probes; the paired allowed primary-approval/control probes are recorded above.
- The focused candidate suite exercises risk-source binding, sh/PowerShell approval parity, signature algorithm/tamper rejection, and cross-runtime canonicalization including supplementary Unicode and non-boolean dirty values.
- This is a reproducible current-state red/green scenario rerun, not a before/after execution of historical T-007 artifacts. Historical waiver logs remain unchanged and must not be represented as containing these added hook-suite runs.
PowerShell hook suite: PASS
ok: ps sudo: Second Approval denied even with valid sudo (exit 2) -- sudo does NOT bypass
ok: ps: edit adds Second Approval -> deny (exit 2)

## Green probes: approved/independent paths and T-007 candidate checks

ok: sh sudo: primary Approval WITH valid sudo -> allow (exit 0) — primary guard behavior unchanged
ok: wfi016: outside CWD + CLAUDE_PROJECT_DIR + PASS verdict -> allow
T-007 focused candidate regressions: PASS
candidate regression passed (33 checks)

## Scope and limitation

- Both platform suites exercise Second Approval write-deny probes; the paired allowed primary-approval/control probes are recorded above.
- The focused candidate suite exercises risk-source binding, sh/PowerShell approval parity, signature algorithm/tamper rejection, and cross-runtime canonicalization including supplementary Unicode and non-boolean dirty values.
- This is a reproducible current-state red/green scenario rerun, not a before/after execution of historical T-007 artifacts. Historical waiver logs remain unchanged and must not be represented as containing these added hook-suite runs.
