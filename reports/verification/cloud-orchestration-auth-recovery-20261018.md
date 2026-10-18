# CLI authentication recovery and review-host readiness

Date: 2026-10-18

The user completed the device authorization requested by `codex login
--device-auth`. The CLI returned `Successfully logged in` with exit code 0.
`auth-sync.py` confirmed both dedicated profiles still reference the current
runtime authentication source, without copying credentials.

`check-auth.py` then returned exit code 0:

- dev: `account_api_verified`
- verify: `account_api_verified`

A separate native app-server readiness probe in the isolated verify profile
completed a real model turn. It invoked an allowlisted synthetic read-only
tool and returned `READY`; no repository review inputs or findings were used.
Probe thread/session: `01a14d27-d376-7692-aed0-fb7ecc288f09`.
The host reported readOnly sandbox, networkAccess false, zero turns at initial
allocation, no parent thread, and no forked conversation. This establishes
current model connectivity separately from account connectivity.

The independent review route uses a fresh native idle context, saves the host
allocation receipt, reserves its actual thread/session identity through the
repository validator, and only then starts its first model turn. The caller
provides a path/hash-enforcing read tool; shell, apps, plugins, web search and
subagent tools are disabled for the reviewer. The host captures returned JSON.
The role and review-boundary instructions are delivered separately from the
allowlisted substantive inputs. Reviewers cannot write their own reports.

The invoking host identity was registered from the actual host-supplied
CODEX_THREAD_ID and CODEX_SESSION_ID, preserving and validating the existing
ledger hash chain. The native connectivity probe is not a reviewer and is
never reused as one. Reviewer allocation, reservation, delivery and input
hash evidence live under the specification review round directory.

This addendum supersedes the authentication blocker in the earlier readiness
report and investigation. It does not assert a Passed review gate, implemented
cloud adapters, working cloud credentials, or completed live deployment tests.
