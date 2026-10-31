# T-008 native resume preconditions (read-only audit)

This is a prospective execution checklist, not native acceptance evidence or a quality-gate verdict. No host was relaunched after the permission refusal documented in `live-host-spy-diagnostic-20261004.md`; no protected path, hook, permission configuration, frozen specification, or historical evidence was changed.

## Approved boundary and remaining checks

T-008 remains Approved and Implementation Complete in `tasks.md:1104-1230`. Its ownership is the A5 fixture adoption and AC-004/021/036/037 assertions, separate from T-010's manifest/evaluator. A5's current design item 10 (`specs/epic-193-a5-capability-resolver/design.md:2139-2179`) describes anchor drift, absent/disabled-legacy no-call, Block surfacing, and positive exactly-one-call. The frozen A7 citation still needs the formal re-binding described in T-010's prospective-contract-repair addendum; this audit does not resolve that drift.

1. Recover the normal Claude session's specific prerequisite permission request through its normal approval mechanism. The recorded refusal is `This command requires approval` for `bash scripts/check-sdd-structure.sh`. Broad Bash allowance, permission-mode relaxation, another executor, or rerunning a renamed command are not recovery evidence. The outer structure check is not the host's check.
2. In the native bootstrap turn, complete its own hook challenge, actual canary tool attempt, and response verification. `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md:105-122` requires HOOK_ACTIVE before track selection. A challenge or another session's proof is insufficient.
3. Prepare a genuine positive input for the normal track decision, not merely a file containing `schema: sdd-project-context/v1`. The current diagnostic driver checks only that literal (`live-host-spy-candidate.sh:39-42`), while the actual bootstrap requires approval-sidecar validity (`bootstrap/SKILL.md:123-148`). The standard validator requires content schema, sidecar schema, content hash, HMAC, registered approver identity, effective time, and provenance checks (`plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py:909-922`). The outer preparation must use the sanctioned isolated-input approval workflow and must not forge a live approval or expose key material. Its standard verification command shape is:

   ```text
   rtk proxy bash plugins/sdd-quality-loop/scripts/validate-approval-sidecar.sh --content sdd/project-context.yaml --sidecar sdd/project-context.approval.json --approver-registry sdd/approver-registry.yaml
   ```

   Run from the isolated project's root; require `VALID` and exit 0. `--verify-provenance` is not a substitute for this content-and-approval check. Then still require the native bootstrap to reach the appropriate valid-Context branch and Capability Interview.
4. Prove observation of the actual dispatcher path with the positive control before interpreting negative counts. The current PATH shim delegates to the real dispatcher and records arguments, but an explicit repository path bypasses that shim. Do not replace the protected dispatcher path. The positive native trace must show one executed dispatcher call, captured once, with explicit `--config`, `--target-rev`, and `--feature` (`sdd-bootstrap-interviewer/SKILL.md:63-98`). If not captured, classify observation as unavailable rather than inventing a zero-call result.
5. Only after those prerequisites, run separate isolated F1 absent and F3/F4 invalid cases. Bootstrap C1 must reach COMPATIBILITY_FALLBACK; C2 must report PROJECT_CONTEXT_INVALID and stop before interviewer invocation (`bootstrap/SKILL.md:128-148`). Require zero observed Resolver process calls with the already-proven observer. Stopping earlier at structure, permission, or handshake is not no-call evidence.

## Current next action

The immediate native action is normal-session permission recovery, followed by its own handshake; it is not another invocation of the noninteractive diagnostic driver. The driver always exits 3/UNVERIFIED and currently does not enforce approval-sidecar validity or guarantee interception of explicit paths. Do not treat its receipt fields as an AC verdict. Independently executable T-004 offline structural activation work may proceed while these native prerequisites remain unresolved.

## Original session located by read-only inspection

The original attempt-2 raw stream remains at `/private/tmp/a7-realhost-spy.nhCxLM/output/attempt2/positive.claude-stream.jsonl`. Its result identifies session `c3811461-1e2d-4571-8afc-e1979980b656`; the isolated repository is `/private/tmp/a7-realhost-spy.nhCxLM/repo`. `permission_denials` names the final single-command Bash request as tool use `toolu_013BjpQZBq68o9d3qDXmQ5V4`, command `bash scripts/check-sdd-structure.sh`. Its result is success/is_error=false but its receipt records zero spy calls; neither is acceptance proof.

Read-only inspection of that isolated repository found only the synthetic v1 Context and no approval-sidecar or approver-registry file under `sdd/`. Thus that original setup does not establish a valid positive input for the native bootstrap's standard approval validation. Preserve the original input and raw output as historical failed-attempt evidence. A prospective positive attempt needs a separately prepared, genuinely approved isolated input after normal permission recovery; do not mutate this historical input and retroactively label the prior run positive.
