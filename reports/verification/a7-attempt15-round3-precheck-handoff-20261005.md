# A7 attempt 15 round 3 precheck handoff — 2026-10-05

This is an orchestration/verification note, not a formal spec-review verdict.
The attempt 15 round 2 evidence and all prior reservations remain unchanged.

## Limited correction

- `requirements.md` AC-010/AC-026 and `acceptance-tests.md` TEST-010/TEST-026 now distinguish the four mandatory local `done-transition` producer branches (Bash and PowerShell inventory) from Context-present `TEST-019` round-drive integration. Only that integration follows the AC-010/AC-034 named SKIP; a SKIP is not a pass.
- `design.md` records the same boundary; `investigation.md` records the 2026-10-05 orchestrator scope transcription of the user's existing broad instruction, without assigning an unknown original message date or claiming a specifically worded human quote. Independent review must judge its adequacy.
- Identifier sweep covered AC-010, AC-026, AC-034, TEST-010, TEST-018, TEST-019, TEST-026 and `Context-present` across requirements, design, acceptance tests, the four layer specifications, and tasks. `git diff --check` on the four edited specification files exited 0.

## Current pins and precheck

| Path | SHA-256 |
|---|---|
| `specs/epic-195-a7-compatibility/requirements.md` | `492f54a812be75ca20d0a05ec41dcf225f9b1b17cd512148498e02cf954dd96c` |
| `specs/epic-195-a7-compatibility/acceptance-tests.md` | `dca8c1551ea0f268fc02944a8e0fe078b557c416ef3f37649c7c33590fff6d13` |
| `specs/epic-195-a7-compatibility/investigation.md` | `7a908bed637e779925d11ef4bd396be0dfd88e20c2e300548302e055acafce57` |
| `specs/epic-195-a7-compatibility/design.md` | `d58d2e91b54260db7d2f02c04a9a9966f4e77e03fcf2585a6eece0c9320adbbf` |
| `reports/spec-review/epic-195-a7-compatibility/attempt-15/round-3/precheck-result.json` | `5628d5625eb30790149d5fa680f6eb22bfc0d6a8ee34ba044e81cfee638cfa3a` |

The normal `spec-review-precheck.sh epic-195-a7-compatibility 15 3 --edit-summary=...` exited 0 and created the round-3 precheck. It records `Spec-Review-Status: Pending`, `reset: false`, and combined `input_sha256: 6511157301430981ef7d5c182972acbdfce8c01c60c15b0e90a2b5a993b61a05`. At the time of this precheck handoff, no review output, invocation manifest, reviewer reservation or verdict had been created. The later reviewer-A launch failure is recorded separately in `reports/spec-review/epic-195-a7-compatibility/attempt-15/round-3/reviewer-a-launch-blocker.md` and supersedes that operational snapshot.

## Next launch boundary

The installed `spec-review-loop/SKILL.md` requires a host-issued run/session identity receipt from an **empty, idle context before model execution**. The accessible Codex collaboration spawn starts a model turn immediately and therefore is not that allocation. Do not fabricate identities or reserve after a review has started. A host supporting separate idle allocation (as used for round 2) must allocate reviewer A, persist its receipt, build the canonical allowed-input and invocation manifests from these current pins, reserve with `validate-review-context-set.sh --reserve`, require `REVIEW_CONTEXT_OK`, and only then launch A's first turn. B follows only after sanitized A summary and its own fresh idle allocation/reservation. No A/B launch was attempted here; formal review and status transition remain pending.

The earlier `investigation.md` table of downstream working-artifact pins is historical; the changed `design.md` has a new digest above. Rehash every downstream artifact before its own gate. This round's precheck binds the three current spec inputs and calibration, not the old design pin.
