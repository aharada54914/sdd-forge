# PR #568 corrective implementation record

Run ID: fixed-approval-issuer-pr568-python39-repair
Task Attempt Count: 1

Scope: approved fixed-format issuer extension, dedicated checkout
`codex/fixed-approval-issuer`; repair baseline
`946bb25fe1150c79be275711f7bfb20deaef46c9`, clean before this correction.
Risk: high; product identity, signatures and input binding are unchanged.
This is a repository-development record, not a formal task verdict.

## Preflight before corrective source editing

The initial field checklist was recorded in
`reports/verification/fixed-approval-issuer-development.md`, not in an
implementation report. This record corrects its location prospectively; it does
not claim the original placement satisfied the implementation-report rule.

| Persisted field | Counterpart | Rejecting regression |
|---|---|---|
| schema | fixed approval consumer | unsupported schema |
| commit / path / mode / SHA-256 | Git inventory | changed digest, mode, absent path, duplicate JSON |
| feature / stage / task_id | invocation scope | scope mismatch |
| primary_approval.approver | canonical registry | unknown identity or missing registry |
| effective_at | UTC nonfuture contract | future or malformed timestamp |
| hmac | canonical signature verifier | missing/wrong key, document mutation |
| staged bytes / manifest | byte readback and publication | interruption, I/O error, occupied destination |

Observed RED: system Python 3.9.6 ran the 12 fixed-state tests with two
failures and two errors. `Path.write_text(newline=...)` is unsupported there.
Correction: write the already encoded bytes directly and keep interruption
coverage on the actual write operation. No signature bytes or approval semantics
change. Also synchronize the one applied issuer mirror reported stale by CI;
leave pending human-copy proposals untouched.

Required validation: Python 3.9 and current fixed-state suites, all fixed-review
suites, legacy Bash/PowerShell issuer checks, mirror freshness, independent diff
review, final-head CI and postmerge confirmation.

## Corrective validation

- Python 3.9.6: fixed-state 12 tests passed.
- Current Python: all five fixed-review suites passed (33 + 50 + 7 + 6 + 12).
- Legacy Bash and PowerShell issuer suites passed; combined validation exited 0.
- Mirror freshness: 6 passed, 0 failed, 19 pending proposals preserved.
- Independent Codex diff review: PASS, no blocking findings. It independently
  ran both Python versions' fixed-state suites and 69 legacy Bash checks, checked
  mirror bytes/digest, and observed clean whitespace validation.
- `git diff --check`: passed.

These are local results, not final-head CI or postmerge evidence. No production
approval was issued and no real credential was used by these fixture tests.
