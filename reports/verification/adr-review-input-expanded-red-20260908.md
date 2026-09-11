# ADR admission expanded RED baseline

Ticket: RT-20260908-004
Date: 2026-09-08
Status: product correction remains unimplemented; not a quality-gate PASS.

Extended `tests/impl-review-adr-inputs.tests.sh` from 12 to 48 runtime
cases. The existing repository validators are executed directly against
disposable fixture repositories. No validator is copied, mocked or modified.
Only fixture ledgers may be reserved; the real repository ledger is not a
test output. The shell harness is the existing test framework for this lane.

Added nine precheck variants for each implementation reviewer in Bash and
macOS PowerShell: null set, object instead of array, missing hash, extra key,
duplicate member, invalid hash, empty set despite a design declaration,
wrong feature, and wrong round. Each variant hashes its mutated precheck
before inserting that hash in the invocation, so it does not merely test a
stale precheck digest. All these variants deliberately omit invocation ADR
entries. Rejection must leave fixture ledger bytes unchanged.

First execution: `rtk proxy bash tests/impl-review-adr-inputs.tests.sh`
returned exit 1, passed=4 failed=44. All four legacy controls passed;
all four valid ADR-bound cases were rejected with REVIEW_CONTEXT_PATH;
the other forty cases returned success and changed their fixture ledger.
The added cases therefore establish that absence of an ADR invocation entry
does not currently force validation of the extended precheck contract.
These are failures against the approved new extension, not proof that the
shipped validator was designed to support that extension already.

Syntax check: `rtk proxy bash -n tests/impl-review-adr-inputs.tests.sh` exited 0.
The repeated execution used pipefail and tee to preserve the complete output
in `adr-review-input-expanded-red-20260908.log`. Its terminal exit was 1,
again passed=4 failed=44. `git diff --check` also exited 0.

## Primary test review (not independent formal review)

Critical: 0 in this test-only delta. The mutation output is isolated from
the input file; invocation hashes are calculated after mutation; the reject
assertion checks both nonzero exit and unchanged ledger bytes. A failed
positive case cannot count as a successful negative case.

Warning: these are combined omission/malformed-input cases, not isolated
proof that each malformed field has a dedicated rejection path. Once the
valid bound case passes, add each mutation with a complete ADR manifest too.
The fixture precheck is intentionally minimal; this suite does not replace
producer, persisted-contract, lifecycle, parser or task-stage coverage.
Reparse points and native Windows have not been tested. Do not register this
intentionally RED suite as a completed CI fix or close the ticket.

No durable memory writeback: these are temporary, uncorrected task findings.
Keep them in task handoff state instead.

## External state observed

PR #400 at 8fa3eb8561d6f59b692ec574900f87e181145928 has 25 successful
Actions checks; formal review findings still prevent merge. PR #394 and
#390 each have two failed checks, #381 eleven, #371 four; #245 has no
Actions checks. None of these PRs had a live check at this observation.
No merge, push, issue closure or check rerun was performed.
