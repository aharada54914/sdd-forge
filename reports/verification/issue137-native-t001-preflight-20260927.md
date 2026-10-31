# issue137 / sdd-context-continuity T-001 native preflight

Date: 2026-09-27 (Asia/Tokyo)
Native session identifier (CODEX_THREAD_ID): 01a0e2ab-2879-7920-a92a-2b0c2fee5017
Runtime: codex-cli
Worktree: /Users/jrmag/.codex/worktrees/issue137-continuity
Scope: approved native preflight only; no implementation or gate invocation.
Result: BLOCKED at physical ProjectContext probe; handshake independently HOOK_ACTIVE.

## Installed instructions and initial observations

Read installed `sdd-ship/1.17.0/skills/ship/SKILL.md` and
`sdd-implementation/1.17.0/skills/implement-task/SKILL.md` under
`/Users/jrmag/.codex/plugins/cache/sdd-plugins/`.
Used installed `sdd-quality-loop/1.17.0/scripts/check-hook-activation-handshake.py`.
All shell calls used `rtk proxy` with `login=false`; guards and permissions were unchanged.

`rtk proxy bash scripts/check-sdd-structure.sh` returned exit 0:

```text
advisory: CLAUDE.md
host: github
check-sdd-structure: OK
```

Initial `git status --short` showed existing tracked and untracked changes,
including continuity specifications and review evidence. They were preserved.
The unconditional read-only MCP `get_next_sdd_command({})` returned
`cannot-determine` / `auto-select-multiple-active`, naming
`epic-195-a7-compatibility`, `epic-196-a8-integration`, and
`sdd-context-continuity`. Explicit user target `sdd-context-continuity T-001`
remained authoritative; no auto-selection was performed.

## Fresh native handshake

`--emit-challenge` returned exit 0, schema `sdd-hook-challenge/v1`,
nonce `3d20033a59b1aaa3cc629620318c01dc`, and target
`sdd/.hook-canary-sentinel`. No stale-sentinel diagnostic was emitted.
Exactly one real native `tools.apply_patch` invocation used the emitted
Codex template, with its relative path and exact patch bytes:

```text
*** Begin Patch
*** Add File: sdd/.hook-canary-sentinel
+sdd-hook-challenge:3d20033a59b1aaa3cc629620318c01dc
*** End Patch
```

Actual host result, verbatim (no added terminal newline in the JSON value):

```text
Script error:
Command blocked by PreToolUse hook: SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。
[EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo.. Command: *** Begin Patch
*** Add File: sdd/.hook-canary-sentinel
+sdd-hook-challenge:3d20033a59b1aaa3cc629620318c01dc
*** End Patch
```

The call failed at native dispatch; no retry, shell write, alternate path,
hook bypass, or cleanup write was attempted. Actual denial was captured in
[`recorded-result.json`](issue137-native-t001-preflight-20260927/recorded-result.json)
using `sdd-codex-host-denial/v1`, `runtime: codex-cli`, and `executed: false`.
No synthetic hook flags were supplied.

Installed verifier command:

```text
rtk proxy python3 /Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-quality-loop/1.17.0/scripts/check-hook-activation-handshake.py --verify-response --nonce 3d20033a59b1aaa3cc629620318c01dc --recorded-result reports/verification/issue137-native-t001-preflight-20260927/recorded-result.json --runtime codex-cli
```

Actual verifier output (exit 0):

```json
{
  "nonce": "3d20033a59b1aaa3cc629620318c01dc",
  "runtime": "codex-cli",
  "schema": "sdd-hook-verify-result/v1",
  "status": "HOOK_ACTIVE"
}
```

## Physical ProjectContext probe: actual blocker

After handshake verification, the first physical-presence probe was submitted
through `exec_command`, `login=false`. It was read-only and intended to use
`os.path.lexists` before approval validation. The host rejected the operation
before execution. Actual returned result:

```text
Script error:
Command blocked by PreToolUse hook: SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。
[EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo.. Command: rtk proxy python3 -c 'import os,json; print(json.dumps({"project_context_lexists":os.path.lexists("sdd/project-context.yaml"),"project_context_is_file":os.path.isfile("sdd/project-context.yaml"),"canary_lexists":os.path.lexists("sdd/.hook-canary-sentinel"),"agents_exists":os.path.isfile("AGENTS.md"),"acceptance_tests_exists":os.path.isfile("specs/sdd-context-continuity/acceptance-tests.md"),"traceability_exists":os.path.isfile("specs/sdd-context-continuity/traceability.md")},sort_keys=True))'
```

This rejection supplies no physical presence/absence result. The later calls
in that failed orchestration cell (profile/task search and labelled environment
read) did not run. Only a separate unrelated `rtk proxy printenv CODEX_THREAD_ID`
was subsequently executed to identify the native session; it returned the
identifier above. The rejected probe was not rerouted or retried.

## Shipped G1–G4 / track resolution

| Gate | Required ProjectContext observation | Handshake | Shipped resolution | Observed applicability |
|---|---|---|---|---|
| G1 | physically present and valid | HOOK_ACTIVE | CAPABILITY_MODE | Unknown: physical probe rejected |
| G2 | physically present and valid | not HOOK_ACTIVE | CAPABILITY_RUNTIME_UNAVAILABLE | Not applicable to verified handshake |
| G3 | physically absent | HOOK_ACTIVE | DISABLED_LEGACY | Unknown: physical probe rejected |
| G4 | physically absent | not HOOK_ACTIVE | DISABLED_LEGACY | Not applicable to verified handshake |

Actual gate and track remain UNRESOLVED, not G2 or G4. No physical absence
was inferred from a denial. REQ-005 approval validation was not run because
presence was not established. C1 compatibility fallback and C2 invalid-context
resolution were not asserted. No implicit full/lite track was selected.

## Boundary and unresolved work

The expected canary denial was verified successfully. The separate physical
ProjectContext operation rejection is the blocker preventing preflight completion.
Per the user's explicit no-reroute instruction, work stopped at that blocker.
No implementation, task status/approval edit, frozen-spec mutation, guard or
permission change, commit, push, or PR was performed. Only this report and its
task-local actual-response JSON were added. Evidence includes operational paths,
nonce, and native session ID required for provenance; no credentials or unrelated
environment contents were captured.

## Dated addendum — 2026-09-27 human physical preflight and resume

The human subsequently reported this read-only physical observation:
`acceptance_tests_exists=true`, `agents_exists=true`, `canary_lexists=false`,
`project_context_is_file=false`, `project_context_lexists=false`,
`traceability_exists=true`. This is a later human observation, not a successful
rerun of the earlier denied agent probe. That probe was not retried or rerouted.
The historical refusal and genuine HOOK_ACTIVE result above remain unchanged.

Human collection: `/tmp/sdd-preflight-readonly.sLWw3r`.
Agent read-only `rtk proxy shasum -a 256` verified both `repository-guard.py`
and `installed-guard.py` in that collection have SHA256
`0202c8f32f8810d77ba438a965f6b57213fb907f1a3c724f318cda9fd7b19d90`,
matching the human-reported repository/installed guard hash. This hashes the
collected copies; it does not replace native hook activation evidence.

Resuming the same native session's already verified handshake, the later
human physical-absence observation resolves G3: DISABLED_LEGACY, and C1:
COMPATIBILITY_FALLBACK. The requested full legacy track resolves to
`[sdd-ship] Track: full (--full override)`. The human confirmed both required
full-track artifacts exist. No REQ-005 sidecar validation is required for an
absent ProjectContext. Resume structure check returned `check-sdd-structure: OK`
(exit 0); advisory MCP again reported multiple active features, so the explicit
T-001 selector remains authoritative.

Authorized implementation target is T-001 only. T-005 remains Draft, pending
two distinct named human approvers. Remaining launch/verification conditions
must still be enforced; no implementation or quality verdict is inferred from
the completed preflight.

### Actual resume result and remaining launch condition

The installed full-track `implement-tasks` launch contract was read. It requires
checked-in model routing plus a validated immutable task snapshot/manifest and
fresh implementation agent on a capable host. Capability/model inventory is
recorded in [`launch-capability.md`](issue137-native-t001-preflight-20260927/launch-capability.md).
This host exposes implementation subagents, so its incapable-host fallback
cannot be asserted. Exact host-model/registry intersection is empty; the empty
candidate list is preserved in `launch-candidates.json`. No model aliases,
availability proof, invocation cost, or launch identity was invented.

Actual remaining launch-gate command (`login=false`, no bypass flags):

```text
rtk proxy bash plugins/sdd-implementation/scripts/select-agent-model.sh --risk high --host codex-cli --registry contracts/agent-model-capabilities.v2.json --candidates-file reports/verification/issue137-native-t001-preflight-20260927/launch-candidates.json --json
```

Actual stdout:

```text
BLOCKED model-tier-unavailable
```

Process exit code was 0: the selector reports this semantic blocked result on
stdout. This is a deterministic launch block, not a new native hook refusal,
implementation failure, or quality-gate verdict. No alternate launch route or
same-session implementation was attempted.

Installed instruction:
[`agent-delegation-policy.md`](/Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-implementation/1.17.0/skills/implement-task/references/agent-delegation-policy.md)
says: "If no available candidate satisfies the role tier or floor, block with
`model-tier-unavailable`." Installed
[`implement-tasks/SKILL.md`](/Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-implementation/1.17.0/skills/implement-tasks/SKILL.md)
says: "If launch identity, snapshot validation, saved reload evidence, or
output-root enforcement cannot be established, fail closed before implementation."
These are explicit launch requirements, not a request for repeat task approval.

T-001 remains Approved / Planned on disk; no implementation agent, run ID,
implementation report, snapshot/manifest success, Red/Green result, independent
review or Done verdict exists from this resume. Task statuses/approvals and frozen
specifications were not edited. T-005 remains Draft / Planned; two distinct named
human approvers are still required. Other user changes were preserved.

Pending: a provably callable model registered under its actual exact identity
is needed for the shipped launch contract. After launch is possible, T-001 still
requires WFI-001 mismatch preflight, TDD evidence and the task's native owner/path/
ACL lanes (OQ-009), path-complete synthetic privacy verification (OQ-011), and
independent quality verification. The task plan also requires a pre-implementation
failing-regression commit; no commit authorization was supplied, and no commit
was made. That requirement is not deemed satisfied by uncommitted evidence.
No guards/permissions, code, commits, pushes, PRs, or T-005 implementation changed.
