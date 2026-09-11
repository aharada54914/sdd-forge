# PR381 candidate recovery — 2026-09-08

Scope: approved RT-20260809-002 T-006 remediation and user-authorized generator,
candidate, regression, and manifest recovery. No formal verdict or Done decision.

Checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`
HEAD: `3971c93a5705dc15f86ba56cc62118613e4b19db`

## Current evidence

- Workflow candidate is byte-identical to live (bc99ed), retaining every step,
  job, runtime, and timeout. An initial context-ambiguous patch put a timeout on
  the wrong job; byte comparison caught it and job-specific context corrected
  it before the final comparison. No live workflow changed.
- Generator candidate is byte-identical to live (669601). The former candidate
  omitted WFI-048 shell key requirements, export mappings, and character-list
  validation. Existing tuple-only checks did not detect these omissions.
- Expanded Bash/PowerShell checks preserve shell sets and export key:value
  mappings. Two mutation controls reject missing keys across three contracts
  and an incorrectly lowercased export. Bash now parses literal AST constants
  without importing/executing either generator.
- A full seven-file audit exposed five additional stale manifest entries that
  the previous workflow-only hash check missed. All were recomputed from the
  actual files. New full-bundle checks require exactly seven bound candidates.
- Full seven-file hash and live-byte comparison passed (dea6ed). Six human-copy
  files already match. Only its workflow and manifest remain stale.
- Final manifest SHA256:
  `cb7eb6800d988664e934bda35e62ce62efc421dc518a226bed66377d02be5025`.
- Bash generator suite: exit 1, 25 pass / 0 fail / 1 designed-red (4697b4).
- PowerShell generator suite: exit 1, same counts (f05a13).
- Designed-red is the missing POSIX job in the unchanged human-copy workflow.
- `git diff --check`: exit 0 (e83014).

## Review and limits

Primary self-review is not independent SDD verification. It checked the actual
candidate/live diff, fail-closed exit behavior, mapping value preservation,
case-sensitive negative control, all seven hashes, and unchanged live targets.
No critical defect was found in that bounded review. Formal re-review remains
required. Manifest-failure mutation controls and wider workflow step-removal
controls remain to be strengthened; current byte equality proves this candidate
preserves the workflow but not that the existing job-only regression check can
detect every future step-level deletion.

The active hook refused `python3 .../generate-guard-invariants.py --check`.
The denial was not bypassed, and this generator check remains unexecuted.
Human-only script `reports/verification/pr381-human-apply-20260908.sh` validates
the exact HEAD, original target hashes, seven source hashes, and live equality;
backs up the two targets; updates only those mirror targets; and runs generator
and both suites. Syntax check passed (71cc3a); the script was not executed.

No sub-agent, commit, push, merge, issue closure, or protection change occurred.
Next: human mirror application and generator check; formal T-006 re-evaluation;
then integration conflict resolution and all required remote CI before merging.

## Manifest negative controls — subsequent verification

The approved regression scope now includes four manifest-only mutations in
each existing runtime suite: missing entry, duplicate entry, malformed entry,
and wrong digest. Both the unchanged candidate and the mutations call the same
checker; rejection must include the expected diagnostic, not just any error.
Only the two test suites changed in this step. Candidate bytes, human-copy
targets, live protected scripts, and historical task/review records did not.

Executed in the checkout above:

- `bash tests/generate-gate-capabilities.tests.sh`: **29 pass / 0 fail /
  1 designed-red**, exit 1. Full output: `/tmp/pr381-manifest-bash-20260908.log`.
- `pwsh -NoProfile -File tests/generate-gate-capabilities.tests.ps1`: **29 pass /
  0 fail / 1 designed-red**, exit 1. Full output:
  `/tmp/pr381-manifest-pwsh-20260908.log`. This is macOS PowerShell, not Windows.
- `git diff --check`: exit 0.

Primary review of the actual diff found no Critical in this bounded test
extension: the normal seven-file check is retained, PowerShell path membership
and diagnostic matching are ordinal, temporary manifest data does not execute,
and unexpected errors cannot satisfy the negative controls. This is not an
independent quality-gate verdict. Wider workflow step-removal coverage remains
pending; these four controls are not an exhaustive bundle-security proof.

The designed-red remains the stale human-copy workflow missing
`posix-regression`. The human-only application script has not been run, the
denied standalone guard generator check has not been retried, and the ticket
has not been resolved. No commit, push, merge, or issue closure occurred.

At the same observation, PR401 run `34173392316` remained in progress:
Windows job `101897943495` advanced to `Test check-component-coverage suite
(pwsh)` (started `2026-09-08T00:55:06Z`). The three platform workflow-state
jobs remain failed. This live run was polled without restarting it.

## Step-level verification boundary

A subsequent read-only Node invocation intended to parse live/candidate YAML,
compare their complete structures, and remove each step in memory was rejected
by PreToolUse. The command never executed; there is no measured step count or
mutation result. No alternate wrapper, renamed file, or copied executable was
used to retry it. Step-level preservation/mutation coverage therefore remains
unverified beyond the previously recorded byte-equality observation.

The seven open PR heads were re-read and remain unchanged. PR245 is conflicted;
PR381 and PR401 are Draft and behind; PR400 remains Draft and blocked. None of
these observations authorizes merging. The human-only mirror script remains
`reports/verification/pr381-human-apply-20260908.sh`; it has not been executed
by the agent and its application result has not been supplied by the human.
