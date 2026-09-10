# RT004 boundary citation repair and downstream regression

Scope: RT-20260908-004; no ticket resolution or formal gate verdict.

The prior boundary driver failed before its behavioral fixtures because its
first schema citation pointed to obsolete line 245. Current source inspection
placed that predicate at line 290. The remaining references were inspected
against their exact predicates rather than adjusted by a uniform offset.

Changed files:

- plugins/sdd-review-loop/references/review-context-boundary.md: references only.
- tests/review-context-boundary.tests.sh: matching reference locations only,
  plus an anchor for the captured-content hash branch alongside the existing
  pathname hash branch. No assertion, fixture, expected outcome or runtime
  branch was removed.

The approved source edits succeeded through apply_patch without an alternate
executor. An earlier read-only Perl inspection was rejected by the guard;
the same program was not retried. Ordinary grep/sed source reads succeeded.
This observation is not proof of hook activation or an authorization bypass.

Local review: no Critical finding in this reference-only delta. Both hash
branches are represented by the cited range 601–606; global ledger ordering
and all existing behavioral assertions remain unchanged. This is same-agent
review, not the independent security review or formal RT004 quality gate.

Executed original-path checks:

- `rtk proxy bash tests/review-context-boundary.tests.sh`: session 50791,
  exit 0. All 32 anchors verified; TEST-RCB-001 through TEST-RCB-010 including
  TEST-RCB-005b passed in Bash and macOS PowerShell.
- `rtk proxy bash tests/impl-review-round2-contract.tests.sh`: session 98713,
  exit 0. Four cases passed: valid round-2 contract, missing A summary,
  summary assigned to B, and missing investigation binding.
- `rtk proxy git diff --check`: exit 0.

Before the round-2 test, all four named fixture directories and the registry
temporary path were absent. No other team agent was running. The existing dirty
registry was retained by the driver: its SHA-256 before and after was
`21b10cd863c13a5d8399ea26dcc86ff9a0dedbe5eb3e91f89b6dbb134f0d18cf`.

Full `tests/impl-review-adr-inputs.tests.sh` completed in session 90797 with
exit 1: `ADR admission: passed=348 failed=64`. The driver does not reset its
counters between history and admission (lines 984–1072); these are cumulative
full-suite counts, not 412 admission-only cases. Do not add the earlier
restricted-suite counts to this total or substitute their results for it.

Observed remaining PowerShell failures include valid bound ADRs rejected as
role-unlisted, and malformed/omitted ADR bindings accepted with fixture ledger
mutation. The fixture ledger is not the repository's production ledger.
JSON and stationary path checks in the full run continued to pass. These results
do not prove atomic initial acquisition, which those stationary tests do not
exercise.

Source isolation: `validate-review-context-set.sh:180–242` still contains no
ADR extension in the impl role allowlist. Lines 546–606 capture and frame-check
precheck JSON but do not establish equality of its ADR declaration with the
design declaration and invocation set. The old DATA lexical candidate contains
that binding logic but also an unresolved acquisition implementation; it must
not be applied wholesale over the newer JSON/path repairs. Independent review
of the minimum acquisition design was requested from the existing
`rt004_snapshot_static_review` reviewer. No protected implementation change,
formal verdict change or ledger repair was made by this evidence update.

Native Windows, atomic initial acquisition, formal review and main integration
remain incomplete. Historical failures are retained in prior reports.
