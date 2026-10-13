# Detached review state implementation

Run ID: fixed-review-state-20261013
Task Attempt Count: 1

Scope: delegated implementation of the approved fixed-review architecture; owner checkout
`/tmp/sdd-shared-launch-public-20261011`, branch `codex/fixed-review-inputs`, starting HEAD
`9b16ffba39a090cd3cf2305e986341e24096b835`. High risk: authenticated evidence boundary.
Existing dirty launcher, snapshot helper, test/CI registration and verification records belong
to the parent task and are preserved. This owner changes only the new state helper, its tests,
and this non-frozen report.

Preflight persisted-field matrix (before implementation):

| Persisted field | Counterpart | Failing mismatch test |
| --- | --- | --- |
| schema | exact detached-state version | signed unknown schema rejected |
| inventory | trusted launcher inventory and Git blobs/modes | substituted inventory rejected |
| feature, stage, task_id | caller's expected review scope | signed scope substitution rejected |
| approval | canonical authenticated fixed approval for inventory/scope | bad HMAC, unknown approver, future timestamp rejected |
| source_state | historical Git state reference | signed source-state substitution rejected |
| progress | review observation enum, never task lifecycle/verdict | signed Done/PASS rejected |
| hmac | canonical existing approval-auth HMAC implementation | unsigned field tampering rejected |

Required validation: Red before helper exists, focused authenticated state and CLI tests,
existing snapshot regression tests, independent parent review and applicable final-head CI.
No historical approval, frozen input, task status or verdict is mutated by this helper.

Implemented `plugins/sdd-review-loop/scripts/fixed-review-state.py` and
`tests/fixed-review-state.tests.py`. The helper consumes an existing signed
`sdd-fixed-review-approval/v1`; it does not issue approvals. It records a separately
authenticated observation with inventory, review scope, embedded approval, original
Git state reference, and progress (`prepared`, `running`, `completed`, `blocked`).
The existing canonical approval implementation provides key resolution, registry
validation, JSON preimage canonicalization, HMAC, approver and effective-time checks.

Consumer interface:

```python
verify(document, repo, inventory, *, feature, stage, task_id, key, registry_ids)
```

The caller supplies the trusted inventory and expected scope. Verification binds both
outer progress and inner approval, then recomputes historical state from the selected
Git blobs and modes. The CLI resolves the canonical key and the repository's
`sdd/approver-registry.yaml`; `record` additionally requires an existing `--approval`
and `--progress`, while `verify` consumes the embedded approval. Both require
`--repo`, `--inventory`, `--record`, `--feature`, `--stage`, `--task-id`.
Record creation is exclusive, preserving earlier records and selected source files.

Verification:

- RED: five tests failed with missing helper before implementation.
- GREEN: `rtk proxy python3 tests/fixed-review-state.tests.py`: six tests passed.
  Includes authentic roundtrip, original Draft preservation, signed and unsigned
  scope/inventory/source/progress substitution, forged HMAC, unknown identity,
  future approval time, Git bytes mismatch, exclusive output, canonical CLI key and
  YAML registry, duplicate JSON rejection and classified authentication failures.
- `rtk proxy python3 tests/fixed-review-inputs.tests.py`: 33 tests passed.
- One CLI fixture correction: the canonical YAML parser rejects JSON content;
  corrected the fixture to the supported YAML registry syntax, then all six passed.

Limits: observations have no lifecycle transition, verdict, chronological ordering,
anti-replay or task completion authority. `completed` is an authenticated operator
observation, not evaluator PASS or task Done. Full task lifecycle migration is separate.
The launcher must call `verify` with its own trusted inventory/scope and current
selection check; this owner has not changed that shared integration file. Parent
owns test-runner/CI registration, independent review and final-head CI. No real human
approval or production task state was generated. Platform equivalence is waived by
the user; no Windows/macOS equivalence claim is made.

## Parent integration update (2026-10-14)

The delegated ownership boundary above is historical. The launcher now calls
`verify` with its trusted inventory/scope and admits the detached record through
the manifest hash checks. An additionally supplied approval must equal the
record's embedded approval. State regression: 7 passed; launcher regression:
44 passed; canonical Bash precheck regression: 7 passed. The independent launcher
review returned PASS after correcting its legacy-command and live-read findings.
No new task lifecycle or task-completion authority is implied.
