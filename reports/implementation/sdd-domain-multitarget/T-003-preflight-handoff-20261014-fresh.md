# T-003 fresh-context preflight handoff

Run ID: not-assigned-preflight-only
Task Attempt Count: not allocated (no implementation attempt launched)

This is a session handoff, not an implementation completion report, manifest,
quality-gate verdict, or attestation of runtime identity.

## Session Handoff

- Date: 2026-10-14 (Asia/Tokyo).
- Owning checkout: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`.
- Observed HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`.
- Assigned agent path: `/root/issue423_t003_fresh`; this is not an admitted host session UUID or manifest identity.
- Scope: approved Issue #423 T-003 only; companion evaluator, selected plan schema/tests, and mandatory quality-gate invocation. No task status, approval, resolver, legacy check-contract, guard, commit, or push changes.
- Existing extensive dirty changes were inspected and preserved. No implementation or test files were changed by this session. This handoff is its only authored file.
- `rtk proxy bash scripts/check-sdd-structure.sh` returned exit 0, `check-sdd-structure: OK`, with advisory `CLAUDE.md` and host `github`.
- T-003 remains Approved/Blocked; T-002 Done and its 20261014 independent PASS report were read. Task status is owned by the parent.
- Current quality-gate SKILL SHA-256 was rechecked as `c965e9668f584c33b843b61531188c764b5a7fb437012dad7a44040b4cdd43b2`. Parent admits this for the new manifest; it is not a verified installed baseline. Keep historical d032 records. Planned output must not also be an immutable manifest input.
- No new manifest or snapshot was authored, and manifest validation, RED, GREEN, regression, and independent review were NOT RUN. No actual guard refusal occurred.

### Remaining preflight constraint

The parent confirmed that only the agent path is observable; concrete model,
host session identity, and invocation-supplied cost metadata are unavailable.
Do not fabricate them or extend the independent-review exception to an
implementation manifest.

`plugins/sdd-implementation/scripts/validate-task-input-manifest.sh:210-241`
requires identity, model, and cost fields; `model_tier` is closed to
lightweight/standard/strong, decimal cost and a timestamp are required.
Although the generic identifier regex may syntactically accept the literal
`unknown`, this is not a documented semantic unknown allowance or proof of an
actual identity/model. The delegation policy at lines 75-94 requires concrete
provider/model and invocation-supplied cost with host-registry tier selection.
No authorized metadata acquisition mechanism was established in this session.

Minimum unresolved inputs: truthful host session/agent identity mapping,
concrete provider/model and registered tier, estimated per-attempt USD cost,
its source and UTC timestamp. A new run ID also must be assigned under the
normal launch procedure. Do not reuse old launch identities or old cost claims.

### Contract findings for the next fresh launch

- Read `T-003-preflight-handoff-20261014.md` and `design-boundary-addendum-20261004.md`; preserve them.
- Existing selected plan schema is draft `selected-verification-plan/v1`; retain its fields and closed reason vocabulary. Registry v1 has no conditional predicate; do not invent a conditional obligation.
- Preserve all-stage facet manifest gates. Project only implementation-stage gates from canonical registry authority and merge every legacy-required check with stronger obligation winning.
- Bind exact facet manifest, canonical registry, and contract bytes. Resolver registry binding uses whole-registry canonical digest, not the fragment digest.
- Required unavailable/not-run/unknown is BLOCKED; observed executed required failure is NEEDS_WORK. Legacy required migration gap uses migration-pending-required. No empty PASS, stale-binding PASS, optional waiver laundering, or caller-supplied legacy PASS.
- Invoke unchanged legacy checker internally. Required evidence must pass the existing safe-path/existence checks; malformed execution metadata is not proof of observed failure.
- CLI scope: `--facet-manifest --registry --contract --repo-root --output`; fail if output exists.
- Quality-gate invocation must be mandatory for enabled valid context immediately after legacy check-contract; absent/invalid legacy context keeps the old path with no plan. Record exact output digest.
- Existing useful helpers: `generate-registry-digest.py` canonical_digest; `validate-facet-manifest.py` validate_document; `check-contract.py` run and sibling validate_path; resolver assembly functions for fixtures. Do not alter resolver to simplify tests.

### Session termination condition

Context compaction occurred before implementation. The required
`plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md:58-60`
states: "If the context has grown long, or if compaction has occurred, write the
current state to the Session Handoff section of the implementation report and
end the session. Do not rely on summaries or compacted context."
This session therefore ends after preserving this handoff; the next launch
must reconstruct from disk and cannot treat this summary as admitted evidence.
