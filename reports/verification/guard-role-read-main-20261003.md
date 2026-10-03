# Main-based role-read repair: verification checkpoint

Base commit: `49e1602459108fd8ef318b644b51301a3b61d0b1`.

This checkpoint adds a narrowly parsed `rtk proxy rg --no-config -n`
read exception to the three agent-role guards. Existing approval, protected
write, SDD_SUDO, and legacy-reader behavior is unchanged. The legacy-reader
hardening proposal and arbitrary Node launcher changes are excluded.

## Applied source identity

| File under plugins/sdd-quality-loop/scripts/ | SHA-256 |
|---|---|
| sdd-hook-guard.py | 6f3419047febeadc8d657b125df8af4fb1237a86fa20b723eae9215e39d385e3 |
| sdd-hook-guard.js | 28f36062c9de25e9f5fc1c46e2ff87e042f9a222e468aba832feed37ab2e1328 |
| sdd-hook-guard.ps1 | 4590ccc6301b9fbcc70de611049a447ee0380be1d7e40c43cc610b2ab28c5d22 |

The human applied the pinned patch with backups. The implementer separately
recomputed these three hashes and checked whitespace after application.

## Observed local verification

Run on macOS, with the installed PowerShell runtime. All commands below
were run through `rtk proxy` in the isolated main-based checkout.

| Command | Observed result |
|---|---|
| bash tests/guards.tests.sh | 135 passed, 0 failed; exit 0 |
| bash tests/guard-parity.tests.sh | 110 passed, 0 failed; exit 0 |
| bash tests/guard-negative-corpus.tests.sh | 47 passed, 0 failed, 0 skipped; exit 0 |
| pwsh -NoProfile -File tests/hooks.tests.ps1 | Hook guard tests passed; exit 0 |
| git diff --check | exit 0 |

An additional ephemeral driver pinned the hashes above and exercised the
actual guard entry points: nine cases in both exit and Copilot output modes
for each of Python, Node, and PowerShell. All 54 checks passed. Cases covered
the intended proxy read, retained bare cat read, dangerous preprocessing
options before and after the pattern, compound commands, invalid role writes,
approval increases, the kill switch, and malformed input. Synthetic shell
strings were classification data, not executed shell commands.

The ephemeral driver reused the previously prepared top-level case helper;
it is not yet a repository/CI regression driver. Its success must not be
represented as persistent CI coverage.

## Independent review

A separate read-only reviewer inspected the three helpers, callers, option
boundaries, quoting restrictions, and cross-runtime consistency. It reported
zero Critical, Major, or Minor findings. Its attempted additional dynamic
check was blocked by the active hook and did not execute. This is a static
diff review, not a formal SDD quality-gate verdict.

## Outstanding delivery conditions

- Persist the new behavior's regression cases in the repository test suite.
- Complete the applicable formal review and required current-head CI.
- Deliver through a versioned installation without reverting other approved
  installed repairs, then verify a fresh native role read and guard denial.
- Safely merge and verify post-merge CI before treating an issue as resolved.

No installed-host activation, native Windows execution, formal gate PASS,
task Done, CI success, merge, or issue closure is claimed by this record.
