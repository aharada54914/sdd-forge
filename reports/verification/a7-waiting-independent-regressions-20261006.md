# A7 independent checks while protected application is pending

Observed: 2026-10-06. Owner checkout: `a7-t005-intake/sdd-forge`.
HEAD: `654ce55d2b23b3a0cd0d72c3e45e46144399e90e`.
Existing dirty work was preserved. No source, approval, task status, reservation,
review verdict, commit, push or merge was changed by these checks.

## Executed original-path checks

Commands below ran through `rtk proxy`, with the owner checkout as cwd.

| Command | Observed result |
| --- | --- |
| `bash tests/promote-golden-baseline-ci-guard.tests.sh` | Exit 0; 3 passed, 0 failed |
| `pwsh -NoProfile -File tests/promote-golden-baseline-ci-guard.tests.ps1` | Exit 0; 3 passed, 0 failed |
| `bash tests/structural-compatibility.tests.sh` | Exit 0; 77 passed, 0 failed |
| `pwsh -NoProfile -File tests/structural-compatibility.tests.ps1` | Exit 0; 84 passed, 0 failed |
| `bash tests/skip-allowlist-manifest.tests.sh` | Exit 0; 29 passed, 0 failed |
| `bash tests/loop-escalation.tests.sh` | Exit 1; 36 passed, 1 failed |

PowerShell ran on macOS, not native Windows. Limited `git diff --check` on the
loop-escalation and structural twins and Bash skip-allowlist test exited 0.
These are local regression observations, not full-suite, native activation,
independent formal review, quality-gate, CI or delivery evidence.

## Remaining behavioral failure

`loop-escalation.tests.sh` emitted:

```text
FAIL: TEST-019.10b: merged resolver dependency is active but no real interviewer invocation was driven
INFO: TEST-019.10b spy observed 0 invocation(s) across F1/F3-invalid/F4-invalid fixtures
```

The fixture validation and direct spy self-check passed. The suite constructs
fixtures but does not drive a real interviewer (Bash lines 875–897; PowerShell
lines 750–770). With the resolver dependency active, it correctly fails closed.
AC-037/TEST-019.11c is also explicitly inactive until an executable interviewer
caller invokes the resolver. This is missing caller execution/proof, not a timing
failure and not a reason to weaken the check or rerun it unchanged.

The existing T-008 `native-resume-preconditions-20261004.md` is a prospective
checklist, not successful native evidence: it requires the same host's activation,
a genuinely signed valid Context, and one actual resolver call with the specified
arguments before invalid/absent Context zero-call cases are meaningful. No new
native session was launched in this audit.

## What is already corrected, and what remains

- Current structural suites execute the F3/F4 activation and artifact comparison
  paths (Bash lines 260–274; PowerShell lines 193–218). Do not carry forward the
  older unconditional F3 SKIP diagnosis as a current failure. F5/F6 dependency
  SKIPs remain explicit and allowlisted.
- T-011 and T-013 remain Approved/Planned, and their implementation reports are
  absent. Registration entries are present in the canonical POSIX inventory,
  PowerShell runner and workflow, but this audit does not establish T-011's full
  Compatibility Matrix, registration RED/GREEN or independent quality gate.
  The six passing promotion-guard checks do not change T-013's lifecycle state.
- T-004/T-010 remain In Progress. T-005–T-009/T-012 being Implementation Complete
  is not proof of their pending formal acceptance.
- The inventory recovery candidate is independently checked (13 candidate tests),
  but the two protected originals still await sanctioned human application.
  Do not reserve a new A20 identity until normal precheck succeeds after application.

Next executable work: complete the genuine T-008 positive caller/host fixture
under its existing launch and permission contract, then run its negative cases;
separately apply the prepared inventory repair and run the ordinary precheck.
Keep all prior failed and interrupted evidence unchanged.
