# Independent Implementation Review: T-005 Attempt 2

## Identity

- Task: `T-005`
- Reviewer run ID: `agent-cost-context-isolation-T-005-review-run-02`
- Reviewer session ID: `agent-cost-context-isolation-T-005-review-session-02`
- Reviewer agent instance ID: `agent-cost-context-isolation-T-005-review-agent-02`
- Model tier: `standard`
- Isolation mode: `fresh-agent`
- Input manifest: `reports/implementation/agent-cost-context-isolation/manifests/T-005-review-2.json`
- Manifest schema: `implementation-review-input/v1`

## Manifest gate

PASS. The manifest was read before any substantive input. All 22 allowed inputs
existed and matched their declared SHA-256 values. Only manifest-listed inputs
were inspected.

The first hash command could not run because the session PATH did not expose
`shasum` or `awk`; its empty results were discarded rather than treated as hash
mismatches. The retry used `/sbin/sha256sum` and verified all 22 entries as
`OK`.

## Prior-finding retest

| Prior finding | Result | Evidence |
|---|---|---|
| Arbitrary existing path authorization | **PARTIAL / unresolved at evaluator boundary** | Both runtimes now reject `private/arbitrary-existing.txt`, but both accept an unrelated, existing, correctly hashed `plugins/internal/arbitrary-existing.txt` for `sdd-evaluator`; see Critical finding 1. |
| Sequential launch feasibility and integration at all six reviewer plus evaluator boundaries | PASS | Each review-loop skill and quality gate now specifies a one-role manifest, `--reserve`/`-Reserve`, `REVIEW_CONTEXT_OK`, and launch of the exact reserved role/session. The focused suite chronologically reserved all seven roles and ended with eight ledger records including the implementation seed. |
| Freshness from persisted history rather than caller assertions | PASS with atomicity defect | The caller-supplied reserved-ID arrays are gone. The suite rejected reuse of a prior reviewer run and the persisted implementation session from the hash-chained ledger. PowerShell reservation is nevertheless not atomic under contention; see Critical finding 2. |
| Bash/PowerShell whitespace parity | PASS | Both rejected whitespace-only run and session IDs as `REVIEW_CONTEXT_IDENTITY`. |
| Actual `7df7318` rollback restoration | PASS | The focused suite restored the listed boundary from `7df7318`, deleted post-baseline validators, and compared the restored tree byte-for-byte. Independently, a full `git archive 7df7318` ran its baseline isolation test successfully: `ok: spec, implementation, and task review roles are distinct and isolated`. |
| Committed Red ordering | PASS | Commit `a745aed583291b9b4eda91237a06996896e5d5e8` has direct parent `1bba72f4a8b539b070956d6fe3644a8ca4aa8f3a` and changes only `tests/review-agent-isolation.tests.sh` plus `red.log`. Overlaying that committed test onto the parent exited 1 with the recorded fail-closed evaluator failure. |

## Commands and observed results

- Manifest SHA loop using `/sbin/sha256sum`: PASS, 22/22 `OK`.
- `PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin /bin/bash tests/review-agent-isolation.tests.sh`: PASS, `ok: sequential reviewer and evaluator contexts are distinct, authorized, and hash-chained`.
- `git show --no-renames --format=... --name-status a745aed`: PASS; direct parent `1bba72f`, only the Red test and Red log changed.
- Parent archive plus `git show a745aed:tests/review-agent-isolation.tests.sh`: expected Red, exit 1, `not ok: quality gate must fail closed instead of using evaluator fallback`.
- Full `git archive 7df7318` plus its `tests/review-agent-isolation.tests.sh`: PASS.
- Adversarial evaluator manifest containing a real, hash-matching `plugins/internal/arbitrary-existing.txt`: Bash exit 0 and PowerShell exit 0, both `REVIEW_CONTEXT_OK`.
- Pre-existing PowerShell reservation-lock fixture: validator exited 1 with `REVIEW_CONTEXT_IDENTITY`, but deleted the pre-existing lock (`lock=deleted`).
- Manifest with object-valued rather than array-valued `allowed_input_manifest`: Bash exit 1 `REVIEW_CONTEXT_CONTRACT`; PowerShell exit 0 `REVIEW_CONTEXT_OK`.
- Ledger with string `"sequence":"1"` rather than a JSON integer: Bash exit 1 `REVIEW_CONTEXT_IDENTITY`; PowerShell exit 0 `REVIEW_CONTEXT_OK`.

## Findings

### Critical

1. **The Done-evaluator boundary still authorizes arbitrary existing repository
   content under broad namespaces.**
   `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:91-97` and
   `plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1:87-95`
   authorize every canonical file below `plugins/`, `tests/`, `contracts/`, and
   `docs/adr/`, without binding the invocation to a task ID, implementation
   report output list, diff, or other proof that the file is one of the task's
   changed/required inputs. Both validators therefore returned
   `REVIEW_CONTEXT_OK` for a manifest whose sole evaluator input was a real,
   correctly hashed but unrelated `plugins/internal/arbitrary-existing.txt`.
   The private-path fixture at
   `tests/review-agent-isolation.tests.sh:225-229` only proves rejection outside
   these wildcard namespaces. This leaves the attempt-1 arbitrary-file finding
   unresolved for the evaluator and violates the bounded, role-authorized input
   boundary required by REQ-005 and described at
   `plugins/sdd-quality-loop/agents/evaluator.md:36-40`.

2. **A contending PowerShell reservation deletes the lock owned by another
   process, so identity reservation is not atomic.**
   The lock acquisition failure at
   `plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1:267-277`
   calls `Fail-ReviewContext`, but the surrounding `finally` always removes
   `$lockPath` at lines 295-301 even when this process never acquired it. A
   focused fixture created a pre-existing owner lock; PowerShell correctly
   returned an in-progress error but left `lock=deleted`. A third process can
   then acquire the lock while the original owner is still staging/publishing,
   allowing two launches to receive success from competing reservations while
   the last ledger replacement loses one identity. Bash does not remove a lock
   when its `mkdir` acquisition fails
   (`validate-review-context-set.sh:257-260`). This breaks the atomic freshness
   guarantee central to REQ-005/AC-002.

### Major

1. **PowerShell accepts malformed contracts that Bash rejects.**
   The PowerShell top-level checks at
   `plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1:118-135`
   do not require `allowed_input_manifest` to be an array, and lines 220-258
   silently wrap a single object with `@(...)`. It returned
   `REVIEW_CONTEXT_OK` for an object-valued manifest that Bash rejected as
   `REVIEW_CONTEXT_CONTRACT` under
   `validate-review-context-set.sh:106-143`. PowerShell also casts ledger
   sequences at lines 193-210 without requiring their JSON type to be an
   integer, accepting `"sequence":"1"` while Bash rejected the same ledger at
   lines 175-202. These are contract-language differences, not diagnostic
   wording differences, and violate REQ-010. The parity fixtures cover
   whitespace but omit malformed collection and ledger scalar types.

### Minor

None.

## Verdict

**FAIL**

T-005 attempt 2 has unresolved Critical and Major defects. It must not proceed
to a passing quality-gate decision until evaluator authorization is task-bound,
PowerShell releases only locks it acquired, and both runtimes enforce the same
JSON types.
