# RT004 precheck generation candidate checkpoint

Status: incomplete patch data; not ready for human application.
Ticket: RT-20260908-004 (open).

Companion: `adr-precheck-generation-candidate-20260909.patch`
SHA-256: `31af58442668921a310a705e57d1c3438bb5fa120b999bb30c4e369db83ccb72`
Previous generation candidate SHA-256: `6e64119d51c7193468d7bf882fba23828ec57773ae6b4626045d54482895e731`.
This complements, not replaces, the admission candidate whose SHA-256 is
`ebbb6f890c72ae6f375608d26cb764d3639435be7dba4f79b4f1bde0e7a5cb1c`.

## Candidate scope

Bash implementation precheck generation derives the declared ADR set from the
bound design, checks file safety before hashing, serializes sorted path/hash
objects, and appends a versioned ADR suffix to the input hash material.
Verification rederives and compares the complete set and total input hash.
These are proposed changes, not live behavior.

## Primary review finding and correction

The earlier extension-presence conditional used the exit status of `jq -e` for
both absence and parsing/read errors. A read error or replacement after an
earlier check could therefore skip extension validation. The candidate now
captures presence separately and propagates command failure explicitly. Slurp
mode requires exactly one JSON object; empty input, multiple JSON values and
non-object values are errors. A valid object with no extension returns false;
an object with null still enters manifest validation and must be rejected.

This closes the identified source-level branch ambiguity; it is not a claim
of atomic reads or protection against concurrent path replacement. Overall
primary disposition remains NEEDS_WORK, not an independent review verdict.

## Verification boundary

Patch text was read as data, never extracted or executed. Six hunk old/new
counts and cumulative offsets were checked: 1/111, 1/3, 1/27, 1/3, 6/3, 1/2.
The hash above was computed with shasum. These checks do not establish source
line anchoring, patch applicability, Bash syntax, runtime correctness or parity.
The prior protected source-inspection denial was not retried.

No new runtime tests were run. The separate admission baseline remains
112 passed / 64 failed across 176 cases against unchanged live validators;
it does not test this generation candidate. Generator-specific RED fixtures,
high-risk persisted-field mismatch preflight and direct regression evidence
are still required before claiming implementation completion.

Required regression cases include valid absent/empty/nonempty extension,
present null, malformed/empty/non-object/multiple-value JSON, read failure,
design and ADR hash drift, exact serialization, and unchanged legacy evidence.
They must exercise the actual consumers after authorized application, not a
copied protected implementation. Native Windows is still unverified.

## Remaining implementation

- PowerShell generation/verification is now a separate incomplete candidate;
  see rt004-powershell-precheck-candidate-20260909.md. Identical serialization
  and actual runtime verification remain unproven.
- ADR-only next-round progress with unchanged-full-set rejection.
- Persisted contract, workflow-state and task-stage cross-bindings.
- Windows Bash reparse handling and shared byte-boundary fixtures.
- Complete independent security/contract review, then human application and
  direct consumer regressions and all mandatory CI.

No protected runtime, frozen evidence or review verdict was changed. No commit,
push, merge, issue closure or ticket resolution was performed.
