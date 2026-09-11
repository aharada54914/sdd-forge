# ADR-0033: Single-owner POSIX panelist deadline supervision

## Status

Proposed — PR #400 human-authorized design amendment, 2026-09-08.
Not implementation approval or a completed quality gate.
The identifier was absent from the local tracked/untracked `docs/adr` file
inventory when drafted. Recheck the shared namespace against the integration
branch before review/merge; this is not a reservation across other branches.

## Context

The existing helper owns a shell deadline but a Python subprocess owns the
vendor wait and publishes a marker. Deadline handling adds a settling sleep
before consulting that marker and supervisor liveness
(`plugins/sdd-quality-loop/scripts/lib/panelist-common.sh:63-101`).
Amended TEST-004(c1)/(c2) requires actual child-state rechecking, not marker
absence as a proxy. Existing group-wide cleanup at lines 103-115 must survive.

## Decision

Use the existing Python dependency inside the existing shared helper as the
single owner of `Popen`, a monotonic deadline, and cleanup. Launch the vendor
in a new session; keep the supervisor outside its group. Wait with the
remaining deadline; on timeout indication use `poll()` to observe the actual
child. Once observed alive, timeout is final. TERM the saved group, retain the
two-second grace, then KILL survivors and allow at most two further seconds
for cleanup observation/reaping. Preserve stdin, argv and file redirections.

Python documents [`Popen.wait`, `poll`, and `start_new_session`](https://docs.python.org/3/library/subprocess.html).
Process creation itself is not interruptible on every platform; this design
includes its elapsed time in the budget but does not claim a hard-real-time
OS launch guarantee. The specified fixture wall-clock bounds remain required.

## Alternatives and trade-offs

- Retain marker polling plus extra sleep: rejected because it does not observe
  the vendor's actual exit state and can rescue a valid timeout after the fact.
- Signal only the direct PID: rejected because descendants can survive.
- Keep the supervisor in the killed group: rejected because escalation kills
  the actor responsible for collecting status and observing cleanup.
- Introduce a new external timeout dependency: unnecessary; Python is already
  required by the shell runner (`run-panelist-gpt.sh:184-187`).

The selected design changes group leadership and must be tested on macOS and
Linux, including stdin, nonzero status, root-first exit, TERM resistance and
both deadline orderings. Group membership is not a sandbox against a process
that deliberately escapes its session. No broader containment guarantee is
claimed or accepted in place of the existing no-orphan tests.

## Consequences

The helper is protected and needs exact reviewed human application. No runner
implementation is changed by this ADR. PowerShell output ownership and bounded
cleanup require their own concrete design before the overall review can pass;
this POSIX decision does not certify that independent runtime.
