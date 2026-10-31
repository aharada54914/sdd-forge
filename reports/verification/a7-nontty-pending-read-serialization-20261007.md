# A7 non-TTY pending Read serialization repair (2026-10-07)

- Issue/task: A7 task-stage formal review transport, attempt 16 round 2 delivery refusal; this is a shared launcher repair, not a T-013 task-state transition.
- Owning checkout: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`.
- Starting HEAD: `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`.
- Starting dirty state: numerous pre-existing tracked and untracked changes. The shared validator/launcher and related regression tests were already untracked; unrelated changes are retained.
- Risk: high/protected review-enforcement transport. No allowlist, pending-state predicate, identity, reservation, verdict, or task-state change is authorized.
- Affected contract: shared exact-command non-TTY prompt must state that non-hash Bash waits for every pending tool result, including Read. A failed overlap must identify a pending tool result accurately.
- Reproduction: the preserved A7 reviewer-A transcript issued an admitted Read, then allowed `rtk proxy test -d domain` before that Read result; postflight rejected it. The hash sequence had completed, so the old “pending hash proof” error text was inaccurate.
- Required validation: focused prompt/overlap/serialized-delivery regression in the existing transport suite; related shared launcher tests; syntax/diff check; independent diff review. Native formal review, new reservation, CI, and task-state change are outside this repair execution.
- Protected preflight: persisted postflight diagnostic must match the actual pending-tool state; a mismatch fixture with pending Read and non-hash Bash must fail, while the same command after the Read result must pass. Prompt guidance must match validator pending semantics; a prompt assertion must fail if the serialization instruction is absent.

## Applied and checked

- Shared control prompt now explicitly serializes non-hash Bash after all pending tool results, including Read. The existing allowlist and `require(not pending)` predicate are unchanged.
- Overlap diagnostics now name pending tool results rather than incorrectly claiming pending hash proof.
- Existing transport regression covers prompt text, pending-Read overlap rejection, and successful delivery after Read completion.
- `tests/a7-nontty-impl-contract.tests.py`: 12 passed.
- `tests/task-structured-output.tests.py`: 13 passed.
- `tests/unified-launch-order.tests.py`: 8 passed.
- `tests/unified-task-launch.tests.py`: 9 passed.
- `tests/quality-nontty-transport.tests.py`: 7 passed.
- `git diff --check`: exit 0, but the targeted shared validator and tests are pre-existing untracked files, so this check does not cover their contents. The Python suites loaded and exercised them directly.
- Not run: native reviewer launch, reservation, formal gate, CI, independent diff review. Historical attempt 16 round 2 and its reservation remain unchanged.
