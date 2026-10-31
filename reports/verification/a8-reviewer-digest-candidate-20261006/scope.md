# A8 reviewer digest capability candidate

Owner: /Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge
HEAD: 495c88d67af44530687ecea3ce9fb0a90a336539
Risk: high (reviewer tool access and input/evidence validation contract).
Authority: parent relayed the user's scoped launch-contract/digest repair approval;
candidate preparation and isolated fixtures only, not original application or launch.

Existing dirty state includes both context validators, shared boundary, workflow-state
validators, impl prechecks, A8 ten specification documents, ledger and test drivers.
These bytes are the candidate baseline, not HEAD. Preserve all of them. The separate
idle-identity SKILL candidate is not applied and remains a prerequisite of live A8.
No formal verdict, task status, reservation, installed baseline or historical output
is changed by this work. Formal high-risk review/application remains required.

## Contract and minimal change

Spec roles currently permit only Read/Grep/Glob (agents/spec-reviewer-{a,b}.md:4),
but review-context-boundary.md:97–110 requires raw input hashes, canonical ordered
input digest, and reserved record recomputation. Normal validator verification
reads the ledger even without --reserve (validate-review-context-set.sh:515–594),
so reviewers cannot use that path. Hashing JSON files themselves is not equivalent.

Add a spec-only read-only calculation mode to the two existing validator entrypoints.
It reads fixed canonical invocation/receipt paths and only the manifest's authorized
spec inputs. It uses a small common Python calculation module for runtime parity,
not a new evidence schema/framework. It accepts the existing invocation/v2 and exact
REVIEW_CONTEXT_OK text, never reads the ledger, writes files, or reserves. Its stdout
is a calculation confirmation, never a new reservation receipt or review verdict.
Role/boundary/skill text and the candidate launcher carry the same exact-command-only
capability; no unrestricted Bash or Python prefix permission is proposed.

The caller must still perform ordinary preflight/reservation; the reviewer must compare
real host identity with its manifest and the saved receipt with the caller's quoted
receipt. This calculator cannot authenticate caller provenance or host identity.
It is not a substitute for either check, semantic review, or normal postflight.

## Preflight field/counterpart/mismatch checks

| Calculated field | Existing counterpart | Required negative fixture |
| --- | --- | --- |
| each raw SHA256 | manifest path+sha256 | changed bytes, missing file, unlisted path |
| allowed-inputs-v1 digest | manifest ordered entries and receipt chain hash | reordered/removed input |
| record SHA256 | saved REVIEW_CONTEXT_OK and invocation identity/sequence/previous | wrong hash/run/session/sequence/previous |
| unique flag and pre-append tip | existing quoted receipt convention | unique=no, wrong tip |
| read boundary | spec A/B path rules, fixed invocation/receipt | ledger/raw-peer/traversal/symlink/hardlink input |
| stdout-only result | no reserve/output mode | extra option/--reserve, tree mutation check |
| scoped tool call | exact allow rule and canonical role | changed argv, no wildcard; live matcher NOT PROVEN |

## Integration boundary

The validators are shared with other owners. This candidate is based on this owner's
dirty preimages and must not overwrite another checkout. Integrate by reviewed hunks,
re-pin each final preimage and run shared regression suites on the combined candidate.
The ordinary paths must remain byte-identical apart from an early explicit new-mode
dispatch. Other review stages are not enabled by this repair.

Native access boundary is not established by unit/mocked tests: inherited Bash allows,
deny precedence, command substitutions/chaining, actual custom-agent tool availability,
fixed-path byte stability and host-id/receipt correspondence require matching native
verification before formal launch. Do not alter settings, retry a refused operation,
or claim mock permission matching proves the host matcher.

RELEASE_READY: false
