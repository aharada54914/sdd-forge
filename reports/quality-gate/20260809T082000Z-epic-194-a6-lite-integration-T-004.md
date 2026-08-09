Task: Extend lite-gate to consume the Capability Summary and execute Registry-sourced checks
Task ID: T-004
Feature: epic-194-a6-lite-integration
Run ID: RUN-epic-194-a6-lite-integration-qg-T-004-seq0646
Host Session ID: SESS-qg-epic-194-a6-lite-integration-T-004-0646
Ledger Sequence: 646
Allowed-Input Manifest: reports/review-context/pending-epic-194-a6-lite-integration-sdd-evaluator-T-004-seq0646-manifest.json (sha256 67277b84eba6e8ba1887a22a34eaa71fc545672376b4e1878937b67c1a488cd6)
Attempt: 1 (cycle 1 of 3)
VERDICT: NEEDS_WORK

## Launch Integrity (verified, not trusted)

All 31 manifest entries repo-relative, present, hash-matched (0 bad);
`risk-gate-matrix.md` correctly absent. The evaluator did not trust my claim
that the validator reserved: it re-ran the validator (exit 1, stale ledger
hash), then proved that mismatch is exactly and only the reserve's own append
by dropping record 646 and reproducing the declared `identity_ledger_sha256`
byte-for-byte. It derived the chain formula independently and reproduced all
646 record hashes; record 646 equals the quoted `REVIEW_CONTEXT_OK` token.

Noted: the earlier blocked launch's record is not fully gone -- an
sdd-evaluator T-004 record survives at sequence 640 (run_id ...seq0329) -- but
it is a distinct identity from a prior session and does not compromise this
invocation.

## Findings

Critical: 0
Major: 5
Minor: 3

### Major

1. **AC-014 / TEST-014 does not exist.** AC-014 is in T-004's declared
   requirement set (tasks.md:926-928) and acceptance-tests.md:39 mandates a
   fixture locking the Step-2b insertion point and verbatim preservation of the
   ordering note. Mutation proof: replacing that note at SKILL.md:84 and
   re-running all five suites failed zero. The behaviour is correct -- the
   commit is a purely additive insert and the note never appears as a changed
   line -- so this is a missing regression lock, not wrong behaviour.
2. **traceability.json links[3] overstates coverage.** REQ-004 is declared
   covered by TEST-014 and TEST-017 with the RED/GREEN logs as evidence.
   Neither test exists anywhere in the feature, and `grep -c` for both IDs
   returns 0 in the cited logs. This is inside a hash-bound declared Output.
3. **AC-017's required evidence is absent.** tasks.md:1059-1063 requires the
   report to record the `grep -n "sdd-lite" guard-invariants.json` OUTPUT taken
   immediately before the edit. The report only asserts in prose that the check
   was run (T-004.md:24,65). guard-invariants.json is not in the manifest, so
   the evaluator could not substitute its own check. Cannot-verify, and no
   TEST-017 fixture exists either.
4. **CHANGELOG.md is still undeclared.** It is a Planned File
   (tasks.md:980-981) and an explicit Done-When sub-item (tasks.md:1098), and
   commit 31b6911f changes it by +22 lines -- yet it is absent from Outputs and
   therefore from the manifest, so that sub-item cannot be verified.
   Aggravating, and mine: commit 3b396970, whose stated purpose was "declare
   T-004's real outputs before gating it", touched only the report and still
   missed it. Worse, `git diff --stat HEAD -- CHANGELOG.md` shows 11 further
   uncommitted lines, so its gate-time state is pinned by nothing at all.
5. **The shipped deliverable has no behavioural test.** Only 5 of 30
   assertions touch SKILL.md, all as text greps. Four semantic inversions of
   the deliverable each survived all five suites: the backstop clause flipped
   to "continue" (:97), unmapped `VERDICT: FAIL` changed to `N/A` (:102), the
   grammar rule deleted (:108), and missing-Summary FAIL flipped to PASS
   (:94). Only deleting the whole Step 2a block was caught, and only
   incidentally. The simulator approach is sanctioned by the frozen Done-When
   and the prose is correct by inspection, but nothing detects
   simulator/deliverable drift on a Risk: high, Security-Sensitive: true
   enforcement surface.

### Minor

- The scripts/ prefix-containment check in the fixture simulator (:97-98) is
  unreachable dead code -- removing both arms failed zero suites, because the
  step-0 grammar already forbids "/" and "..". Not a security defect (the
  symlink arm is genuinely load-bearing), but SKILL.md:112 documents
  containment as a distinct rule no fixture exercises.
- T-004 is `Status: Implementation Complete` while its declared blocker T-003
  is still `Status: Blocked`.
- The report's Snapshot Notice says it "is not edited after the fact", but
  commit 3b396970 edited its Outputs table after the fact. Its claim that
  check-workflow-state "currently FAILS" is also stale in the favourable
  direction -- it now exits 0.

## The ordering inversion, adjudicated

I asked whether T-004 being Implementation Complete while T-003 is Blocked
undermines its evidence. It does not, and the evaluator did not take the
"no functional dependency" claim on trust: it reproduced all 30 bash
assertions in a scratch tree containing only `tests/` and `SKILL.md`, with no
T-001/T-002/T-003 artifacts present. The suites source only their own fixture
simulator and grep SKILL.md. The single constraint the serialization protects
-- shared `run-all` array order -- is genuinely honoured (T-004 registered
fourth and last, at run-all.sh:105-109).

## What held up

Both runtimes: 30 passed / 0 failed each, 60/60 total, matching the report
exactly. The full `run-all` was executed to completion; all five T-004 suites
pass, and the 7 failing suites are pre-existing and unrelated (including the
known structurally-red deterministic-lane-selfcheck).

TDD evidence is genuine rather than synthesized: the RED log contains exactly
30 `^FAIL:` lines and the GREEN log exactly 60 `^ok:`, matching the claimed
counts. The simulator's tests are non-vacuous -- disabling the backstop,
removing the symlink/regular-file rejection, and removing the grammar check
each failed their suite, and the negative fixtures use real symlinks created
via `ln -sf` rather than assertions about them.

The deterministic gates now pass: check-sdd-structure PASS, check-task-state
"passed for 4 task(s)", check-workflow-state exit 0. The staged CI candidate
registers all five suites across both runtimes.

## Decision

No Critical. The implementation is good work -- SKILL.md is faithful to
design.md, the safety rules are real, and the RED/GREEN evidence is honest.
What blocks Done is evidence binding: two ACs with no fixture, a traceability
link claiming tests that do not exist, an unverifiable deliverable, and a
Planned File the gate is structurally forbidden to read.

T-004 stays `Status: Implementation Complete`. Cycle 1 of 3.
