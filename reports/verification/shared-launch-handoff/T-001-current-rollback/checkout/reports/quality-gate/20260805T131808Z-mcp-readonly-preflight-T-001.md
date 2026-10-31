# Quality Gate Report: T-001 (mcp-readonly-preflight)

Task ID: T-001
Feature: mcp-readonly-preflight

**Persistence note (orchestrator).** The evaluator returned the verdict JSON
below and the orchestrating session wrote it verbatim; no wording, number,
verdict or finding was altered.

```
RUN_ID: RUN-mcp-readonly-preflight-qg-T-001-seq0507
HOST_SESSION_ID: SESS-qg-mcp-readonly-preflight-T-001-0507
ALLOWED_INPUT_MANIFEST: reports/review-context/pending-mcp-readonly-preflight-sdd-evaluator-T-001-seq0507-manifest.json  sha256=6f81575d631f22cfa44387505e3baeb49f0051dfc910b3a4cf06eba72beadb4d
VERDICT: NEEDS_WORK
```

- Model: claude-fable-5 (session-inherited by the sdd-evaluator subagent)
- Effort: frontmatter-controlled, record-only (effort_applied=null)

## Evaluator verdict

NEEDS_WORK. Two Major (both recommended Accepted), three Minor.

1. **Major — Accepted.** AC-012 / Done-When item 5 has no real test and the
   offered structural substitute is invalid: byte-unchanged `## Routing`
   prose cannot establish outcome equality when the executing agent has
   already read the probe's suggestion in the same context; the only
   protection is exactly the prose sentence the record denies relying on,
   and security-spec.md:83 forecloses this substitution ("a single-run test
   cannot distinguish 'did not influence' from 'happened to agree'" — a
   static diff is weaker still). traceability.md:70 types AC-012
   integration (differential) with no open-method annotation. Missing
   evidence: two /sdd-bootstrap:bootstrap runs over one identical repository
   state (probe registered vs. forced absent) with observed mode/track
   conclusions compared. The "PASS (structural verification)" label on
   bullet 5 of verification/T-001/02-verification-record.md is withdrawn by
   this gate (superseding note recorded here; the original record is left
   unedited as historical evidence).
2. **Major — Accepted.** AC-008/AC-009 / Done-When item 4 requires both
   fallback cases independently exercised; neither was. TEST-009 openly not
   run; TEST-008's "first-hand environmental evidence" is an observation of
   the session's server list plus a counterfactual, not a bootstrap run. The
   OQ-009 open-method deferral covers AC-017..020 only (traceability.md:75-78,
   T-001's own Test Type line) — it does not extend to items 4 or 5.
3. **Minor — Accepted.** TEST-018 grid cell marked observed is likewise an
   environment observation, not a runtime exercise; effectively 0 of 4 cells
   exercised. Should read "environment observed; skill not run". Not Major
   because the record disclosed its exact method and Done-When item 7 demands
   only recorded manual verification plus disclosure while OQ-009 is open.
4. **Minor — Deferred.** REQ-001's "record what the probe reported" clause is
   unimplemented as an unconditional instruction (only the divergence branch
   reports); no AC asserts it, but REQ-001 is on T-001's Requirements line.
   Deferred to the same follow-up as the runtime evidence.
5. **Minor — Deferred.** Launch-harness note (not a T-001 defect): reserved
   manifests can never re-validate read-only post-reserve; batch reservation
   compounds it. The evaluator proved its reservation cryptographically
   instead. Recorded for the framework backlog.

The evaluator's summary confirms everything statically verifiable is genuine
and good: all three AC-001 elements present and separately assertable, all
four forbidden surfaces absent by the evaluator's own greps, correct insertion
position, attempt-and-degrade with no detect-then-branch and no mode/track
gate, regression suite green and untouched, BL-001 upheld, no pre-ticked
boxes, high disclosure quality, nothing fabricated.

## Gate decision

Done is blocked: two Accepted Major findings name in-scope acceptance
criteria (AC-008, AC-009, AC-012) whose required runtime evidence cannot be
produced in this session's environment (no MCP server is registered for any
session this orchestrator can launch, and a registered-but-failing MCP cannot
be arranged mid-session). Per the quality-gate skill (stop early when missing
evidence cannot be produced; do not downgrade findings to end the loop), no
further evaluator cycle is spent. Blocking review ticket
docs/review-tickets/RT-20260805-001.yml records the exact runs required and
the environment step (register sdd-forge-mcp locally) that unblocks them.

**Status: T-001 retains Implementation Complete.** Not Done, not Blocked (not
a valid field value); the ticket is the actionable path.

Retrospective: not invoked (gate did not reach Done).
