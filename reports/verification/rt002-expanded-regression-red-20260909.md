# RT002 expanded original-path regression RED

Date: 2026-09-09
Status: incomplete repair; expected RED against unchanged production.
Ticket: RT-20260909-002 (still open). No historical verdict or task status changed.

## Changes and scope

Edited only the two original handshake test suites under the authorized
recovery scope. Added twelve rejection fixtures per wrapper: Japanese guard
message alteration; schema false for each of three runtimes; six outer-only
invalid nonce variants; nested duplicate cleanup JSON; and duplicate-member
legacy response JSON. Added exact reason assertions to existing RT002
negative cases. No existing assertion was removed or relaxed.

Nonce literals were measured, not inferred: baseline 32; self-consistent
uppercase/short/long/nonhex fixtures 32/31/33/32. They were already correct
and were not changed. Outer-only mutations keep CLI and echoed nonce intact.

## Executed checks

| Command | Result |
| --- | --- |
| rtk proxy sh -n tests/check-hook-activation-handshake.tests.sh | Exit 0 |
| PowerShell Parser.ParseFile on original .ps1 suite | No parse errors; exit 0 |
| rtk proxy git diff --check -- tests/check-hook-activation-handshake.tests.sh tests/check-hook-activation-handshake.tests.ps1 | Exit 0 |
| rtk proxy sh tests/check-hook-activation-handshake.tests.sh | Exit 1; 187 passing / 205 failing assertions |
| rtk proxy pwsh -NoProfile -File tests/check-hook-activation-handshake.tests.ps1 | Exit 1; 187 passing / 205 failing assertions |

These are assertion counts, not distinct test-case counts or coverage percent.
Both suites used their original wrapper paths on this macOS host. This is not
native Windows proof. No copied verifier or candidate production code ran.
Captured command output is preserved in rt002-expanded-red-shell-20260909.log
and rt002-expanded-red-powershell-20260909.log. Their SHA-256 values are:

- Shell: 1b14d1afd73c9ab111a21e9d8678b36a4e05b47dafba063302e94e89d6487f86
- PowerShell: 6b533d9e9237375dd80c00cef2b2732672da6e20cc849a8781d1af0fa5954649

All emitted assertion failures are RT002 assertions; existing TEST-/HARDEN/
self-registration assertions did not report failure. Existing success cases
for all three legacy runtimes passed. New adapter acceptance, explicit schema
rejection, accurate diagnostics and duplicate loading remain unimplemented.
In particular, a duplicate no-schema legacy response currently yields
HOOK_ACTIVE, and a nested duplicate cleanup record currently confirms cleanup.
These observed failures are retained, not reclassified as success.

## Provenance and review

Current eleven-file input snapshot: rt002-expanded-regression-inputs-20260909.sha256,
SHA-256 45a870be0273eea8b2c3f2a65b4d8a734ce799005bbffc8ae5e8b9cdd96c2939.
The earlier review-input manifest is preserved as historical; it does not
bind these new test bytes. Original production verifier remains at
d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064.

Author review found no introduced Critical issue; exact reason/status checks
remain fail-closed and PowerShell string comparisons are case-sensitive.
Independent recovery-only advisory requested from
/root/hook_contract_security_review completed with no Critical findings and
two coverage Warnings. Both source hashes verified independently. New cases
and reason assertions were judged sound by static inspection; the reviewer
did not run tests. This is not formal PASS.

Coverage work is not complete: separately reconcile the two both-runtime
Claude/Copilot rows (recorded and CLI runtime together with explicit new schema)
against the existing selector/mismatch fixtures. Do not claim that the entire
109-row specification matrix is covered from this partial expansion.
The second Warning requires a truncated new-response JSON fixture with exit
61, RECORDED_RESULT_UNREADABLE and unavailable-status assertions; existing
malformed JSON cases assert only exit 61. Next bounded change is these three
fixtures per wrapper, followed by a new original-path RED run. Preserve this
run and its input hashes rather than rewriting it to refer to later tests.

Human spec publication, remaining provenance reviews, protected production
application, GREEN original-path suites and one fresh real host challenge
remain required before ordinary implementation/integration resumes.
