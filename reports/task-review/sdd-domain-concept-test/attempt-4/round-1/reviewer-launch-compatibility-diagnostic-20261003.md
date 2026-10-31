# Reviewer launch compatibility diagnostic — 2026-10-03

Status: launch blocked before reservation. No new reviewer result or verdict.

The user has authorized further review and limited correction without a retry
count limit. The historical three-trial stop recorded in
`reviewer-a4-launch-diagnostic.md` is retained as history, not the current
stopping reason. Sequences 1207–1209 and their unadopted outputs are preserved.

## Claude: a non-planning mode alone is insufficient

`rtk proxy claude --help` (exit 0) confirms `manual` is a supported permission
mode and supports explicit tool allow/deny lists. No mode was changed and no
reviewer was launched during this investigation.

The installed ECC source
`/Users/jrmag/.claude/plugins/cache/everything-claude-code/ecc/2.0.0-rc.1/scripts/hooks/gateguard-fact-force.js:958-962`
unconditionally marks the routine-Bash session key and returns `denyResult`
on the first routine Bash call of a fresh session. `denyResult` emits
`permissionDecision: deny` (lines 855–856). This branch does not inspect the
assistant's facts preamble or permission mode. Therefore emitting the required
two facts before Bash does not prevent the denial. The source's normal recovery
is to present facts and retry the same operation; the current launch instruction
requires stopping after a denial. Do not pre-consume that denial, mutate its
state, disable the hook, or silently relax the stop boundary.

## Codex: formal alternative, with an unresolved model registration boundary

`docs/agent-capability-matrix.md:183` explicitly permits OpenAI/Codex task
reviewers at the standard tier or stronger; the workflow is not Claude-only.
The same document's Provider Tier Mapping requires a substitute to be assigned
the matching canonical tier in the capability registry and fails closed as
`model-tier-unavailable` when none is available. Do not equate model names by
similar spelling or family inference.

Read-only CLI protocol investigation:

- `rtk proxy codex app-server --help`: exit 0.
- `rtk proxy codex app-server generate-json-schema --out /tmp/issue290-native-protocol.n0hkDy --experimental`: exit 0.
- Generated `v2/ThreadStartParams.json` has no input field; it accepts
  `sandbox: read-only`, `developerInstructions`, and
  `allowProviderModelFallback: false`.
- `v2/ThreadStartResponse.json` carries a thread, and
  `v2/TurnStartParams.json` requires `threadId` and `input`. This supports a
  prospective two-stage sequence: create an independent empty read-only thread,
  obtain its real ID, reserve that unused ID, then submit the first review input.
  No resume or fabricated identity is needed. This sequence was inspected only,
  not executed; hooks and read-only scope would still need confirmation before
  review input.
- A short-lived native stdio app-server was initialized and sent only
  `model/list` with `includeHidden: true`, `limit: 100`. It returned successfully
  with `nextCursor: null`, then was terminated. No thread or model turn was
  created. Returned model IDs: `gpt-reserve`, `gpt-5.6-sol`, `gpt-5.6-terra`,
  `gpt-5.6-luna`, `gpt-5.5`, `codex-auto-review`.
- None exactly matches an OpenAI entry in
  `contracts/agent-model-capabilities.v2.json` (including `gpt-5.1-codex`,
  `gpt-5.2-codex`, `gpt-5.5-codex`, and `gpt-5.6-codex`). Availability of those
  registered models is not established by this catalog.

One unrelated read-only directory enumeration (`rtk proxy rg --files
/Users/jrmag/.codex/agents`) was rejected by the host's agent-role-write guard
as lacking `developer_instructions`. The operation was not retried by another
path or tool. Existing role files were not created, edited, or bypassed.

## Next boundary and unchanged state

Before Codex reservation, establish an approved, evidence-backed canonical-tier
registration for an actually available model and confirm the read-only native
thread configuration. Alternatively, resolve the explicit ECC/launch-stop
contract conflict through its authorized owner. Neither is accomplished merely
by switching off plan mode. No same-session fallback or hook bypass is allowed.

No new identity was reserved, no A/B review output was adopted, and no
counts-only summary, integrated verdict, or task contract was produced here.
Frozen specification bytes, approvals, old judgments, protected role definitions,
hooks, and the model registry were not modified. No commit, push, or merge ran.
The temporary generated protocol schemas are diagnostic artifacts only, not
formal reviewer evidence.

## Updated CLI confirmation (2026-10-03)

After the authorized shared-runtime update, `rtk proxy codex --version`
returned `codex-cli 0.160.0` (exit 0). A fresh initialized native app-server
`model/list` returned exact `gpt-5.6-sol` with the same supported efforts and
default low; `nextCursor` was null. New 6.x catalog entries were also present,
but none was silently substituted for the explicitly registered 5.6 Sol model.
No thread/start or turn/start was sent during this catalog query.

`codex app-server generate-json-schema` exited 0 with output under
`/tmp/issue290-native-protocol160.rvCBQh`. The new schema retains separate
input-free `thread/start` and `turn/start`; ThreadStartParams accepts
`allowProviderModelFallback: false`, `sandbox: read-only`, and developer
instructions. ThreadStartResponse exposes actual model, thread, sandbox, and
approval policy. TurnStartParams accepts explicit high effort and
`sandboxPolicy: {"type":"readOnly","networkAccess":false}`.

The v2 registry now contains the authorized standard-tier Sol policy entry
with independently inspected local regression evidence in
`reports/verification/issue290-model-registry-minimal-proposal-20261003.md`.
The next boundary is confirmation of loaded SDD protective hooks and the
independent technical audit, before any fresh review reservation or input.
