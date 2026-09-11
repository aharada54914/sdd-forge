# RT004 PowerShell ADR binding candidate

Status: DATA candidate only; not applied, not executed, not a formal PASS.

The previous goal turn made concrete progress: added actual-driver regressions,
obtained an independent Bash candidate disposition, and recorded a real protected
application denial. That denial is not a reason to stop independent preparation
of the required PowerShell counterpart.

## Evidence

- Original PowerShell validator SHA-256:
  `af3537e3b54ed6b9a85d79cdac19c995f8f6d504f874d5a031a8e42c8cdb0438`.
- Candidate: `reports/verification/rt004-adr-binding-pwsh-20260911.patch`.
- Candidate SHA-256:
  `4f0add61f1303b74863557419af3c28ae9981e0ce8cbe0406060cfef3befc157`.
- `git apply --verbose --recount --check` accepted all six hunks against the
  current original. This checks applicability, not syntax or behavior.
- macOS PowerShell reported `7.6.2`; `Get-Item README.md` reported UnixStat
  ItemType `File`. This is a runtime capability observation, not Windows evidence.
- Existing original-driver multi-precheck regression: session 12824 terminal
  exit 1, 4 passed / 16 failed. Both runtimes and both reviewer roles erroneously
  admit invalid later prechecks; valid multiple legacy records remain accepted.

## Candidate behavior

Non-ADR entries are processed before ADR entries. The original loop still checks
their authorization, paths, and raw hashes. Captured design bytes and precheck
objects are reused for exact ADR declaration/precheck/invocation matching;
unchecked caller declarations do not grant authority. ADR file hashes and
existing static path checks remain mandatory. POSIX special-file type is checked
before newly admitted ADR reads to avoid opening a FIFO.

Every implementation precheck is inspected, not just the first. Any explicit ADR
extension requires exactly one precheck. Valid multiple legacy records retain
their semantics. Malformed additional prechecks are now rejected explicitly;
they must not silently appear to lack an extension. The stronger atomic initial
acquisition diagnostic is not a new integration requirement (ADR0034 correction).

## Next step and remaining work

Independent reviewer `rt004_check_contract_review` completed the second static
review: the Keys-shadowing Major is addressed by psbase.Keys; no additional
mandatory correction was identified in the limited difference. This is not a
formal PASS or execution evidence. Session 63853 (`--keys-only`) terminated with
exit 1: 8 passed / 12 failed against the original validators. Legacy controls
pass; omitted ADR bindings with additional key fields are erroneously admitted.

The subsequent ordinary apply_patch attempt against the original PowerShell
validator was explicitly denied by the SDD PreToolUse hook. No alternate executor
was used. Human-only instructions are in
`reports/verification/rt004-adr-binding-pwsh-human-20260911.sh`.
After human application, run original-driver regressions and full
required checks. Downstream contract parity, formal review and main integration
are still not proved by this incremental admission change.

GitHub recheck: 11 open PRs, no queued/in-progress checks. PR400 has zero reported
failed checks but still needs its formal recovery-entry conditions; other PRs
have failed checks or conflicts. No merge or issue closure was performed here.
