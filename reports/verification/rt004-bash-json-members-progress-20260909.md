# RT004 Bash raw JSON candidate and nested regression

Approved ticket: RT-20260908-004. All candidate changes remain unapplied DATA.
Previous turn progressed by authoring the PowerShell raw-member checker.

## Candidate produced

`adr-workflow-bash-json-members-candidate-20260909.patch`: 49 added lines,
SHA-256 `2b36e70a09c549876fcf0b9b6958205dc32ab1bf58ae277875ee43677f2b0ad3`.
The helper uses existing jq with raw slurp input. A token scan and explicit
container frames preserve duplicate member events, decode individual string
keys, and maintain separate key sets for separate object instances. It does
not add Python or another runtime dependency. Every skipped lexical span,
invalid separator, mismatched close, incomplete container and extra root token
must reject. Full parsed-object/schema validation remains the callers job.

Root static review (not independent approval): checked frame transitions,
object-local key ownership, escaped-key decoding, initial/final state and
token-gap checking. Explicit parentheses were added around stack index
arithmetic, and the state key `end` is quoted in construction. No Critical
finding identified in this slice. Outstanding risks: jq regex/Unicode offset
behavior and invalid-encoding parity are not executed or proven. The caller
must check and hash the same snapshot, not pass a path that can change between
raw scanning and object parsing. Both runtime helpers are still unwired.

`git apply --numstat` exited 0 (49 additions), and repository whitespace check
exited 0. These are format checks only: no candidate extraction, parsing,
execution or application occurred. Do not treat this as TDD GREEN.

## New runtime evidence

Added `duplicate-nested-role` to the approved Bash test driver. The isolated
contract has two differently valued `role` members in reviewers[0]. A streaming
jq assertion independently confirms `[null,"impl-reviewer-a"]` at the exact
decoded path. The equal-layer positive control already includes the same
`role` key in two sibling reviewer objects and must remain accepted; a global
key-set implementation would be an incorrect fix.

Command: `rtk proxy bash tests/impl-review-adr-inputs.tests.sh --workflow-only`
(pipefail/tee capture). Session 44220 terminated exit 1.
Full log: `/tmp/rt004-nested-json.6FerkK`.
All 32 cases reached: **6 passed / 26 failed**. Each actual runtime returned
exit 0 / `workflow-state: ok` for the nested duplicate instead of rejection.
These are two new RED observations; the prior 24 failures remain failures.
No native Windows execution or candidate behavior is claimed.

Test SHA-256: `29d082449736b492bc52b97aa2ada4d575dfe3ff73e1e5030a248ca57ab55005`.
Test Bash syntax validation exited 0. Original validator hashes remain
`15a4ef0a72c8be78c40b38e692ee7a46d8664d825e61ab99915086dae0f02d1e` (Bash) and
`7a4663e154e7877362d43916087986849dd7625121d5c058332d3e27eb7b2644` (PowerShell).

Next: safe snapshot/caller composition, strict decoding and parity controls,
complete coherent patch assembly, independent security/contract review, then
human application and actual GREEN verification. Retain historical evidence.
No commit/push/merge, task Done transition, or issue closure occurred.
