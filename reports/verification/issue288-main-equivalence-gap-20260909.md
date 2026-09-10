# Issue 288: main equivalence audit

Date: 2026-09-09
Status: incomplete; keep issue open.

GitHub main and local origin/main both resolve to
`4366438f3b243210a4ece5a17f873ca2d920600a`.
Issue 288 names `18a588101c64e746c0a7592b7c30f5761fcc94ee` as its landed fix.
GitHub compare `18a58810...main` reports diverged (ahead 902, behind 2), and
local `git branch -a --contains 18a58810` returned no branches. This excludes
direct ancestry but does not exclude equivalent later changes.

## Partial equivalence and remaining gap

Main does contain later contract-derived investigation pin handling:
`spec-review-precheck.sh:286-292` and `.ps1:380-392` derive the pin from
recorded reviewer inputs. Commit `0c48cf16` also changes both downstream
precheck twins and adds downstream regression suites. Its commit message
describes growth, never-pinned and disagreeing-reviewer cases. Those historical
test claims were not re-executed in this audit.

The original issue's second requirement is distinct: newly reserved spec and
impl reviewers must include an investigation file that already exists.
The original commit adds that check to both `validate-review-context-set`
implementations. At the current main pin, all investigation references in
those two files are in role path authorization (Shell 140/154, PowerShell
96/111); the original explicit omission rejection is absent. Shell lines
517-519 proceed directly from the manifest-entry loop to round consistency,
where the original commit inserted the completeness check. Shell line 532
continues on an absent manifest hash, rather than proving completeness.

This is a source-level gap relative to the issue's stated fix, not a fresh
runtime exploit verdict. No new reservation or fabricated review was run.
Do not close the issue solely because later commits fix the historical audit
half. Next: examine new-round construction/authorization for equivalent
omission enforcement and exercise existing negative tests through an allowed
fixture interface. If absent, scope the missing behavior and rejection tests
under an approved contract before changing protected validators.

No product code, historical evidence, issue state or branch was changed.

## Follow-up: distinguish procedure from enforcement

Current checkout follow-up on 2026-09-09 found a procedural inconsistency:
`plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md:68` calls
investigation optional, whereas `impl-review-loop/SKILL.md:211-212` requires
both manifests to contain it whenever it exists. That prose requirement does
not supply the missing deterministic reservation rejection.

The downstream Shell implementation now resides in
`scripts/lib/review-precheck-common.sh`, sourced by impl-review-precheck.sh:56.
The shared helper's lines 232-266 validate a persisted investigation pin when
declared; they intentionally do not require an undeclared file. This preserves
the historical-audit behavior and should not be reversed to fix new admission.

The foundation `review-contract-validate.sh:37-44` validates a small identity,
digest and PASS-shaped object, not the reviewer input manifest; it cannot be
treated as equivalent omission enforcement.

Existing test references inspected cover historical sealed-pin growth,
never-pinned records, ambiguity and malformed pins (spec-review-loop and
downstream-review-precheck), and declared investigation symlink rejection
(review-agent-isolation.tests.sh:286-288). A symlink rejection with a declared
entry does not test omission of an existing ordinary file. No such omission
test was found in the inspected review-agent-isolation or review-context-boundary
suites. This is limited source inspection, not a claim about every repository
test or a successful runtime reproducer.

### Bounded implementation/review acceptance proposal

- Keep historical validation contract-derived. Never retrofit old manifests.
- For fresh spec/impl reservations, reject omission of an existing ordinary
  investigation file for each of reviewer A and reviewer B, in both runtimes.
- Keep task-role authorization unchanged: this change must not require a file
  its role is forbidden to read.
- Separate missing-file success, present-and-correct success, present-and-omitted
  rejection and wrong-hash rejection. Test each role/runtime independently.
- Verify that auditing an already reserved manifest is not reclassified as a
  fresh reservation when the file appeared later. The old commit's unconditional
  check must not simply be cherry-picked across the newer reservation/audit split.
- Retain malformed/ambiguous pin, symlink, identity-ledger, replay, and historical
  growth regressions; add a mutation check removing only the new omission guard.
- Reconcile the spec skill's optional wording with the approved new-admission
  contract and rebind affected formal review inputs. No retroactive PASS edits.

The user already authorized changes to #288; this proposal does not ask for
that same permission again. Implementation still needs an approved task/review
contract and the protected-file application path. Formal entry has the separately
recorded unresolved host-evidence blocker. No candidate code was executed or
protected validator edited during this follow-up.
