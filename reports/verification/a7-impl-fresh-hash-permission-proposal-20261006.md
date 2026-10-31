# Fresh impl-review scoped hash permission proposal

Read-only contract investigation and non-frozen proposal; NOT execution authorization or formal review. Owner `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`, HEAD `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`. Existing tracked dirty changes were inspected and preserved. No launcher, settings, protected file, ledger, prior evidence or verdict changed. No child created and no reservation made. Latest on-disk attempt is 6; attempt 7 below is a conditional proposed destination, not an existing admitted attempt.

## Contract conclusion

The ordinary impl launch contract does not prescribe a closed Claude CLI argv allowlist. STEP 2/4 require fresh independent, read-only, manifest-bound reviewers and successful current verify-inputs/reservation (`plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md:111-152`, `:174-199`). The existing role already exposes Bash for read-only hashing (`plugins/sdd-review-loop/agents/impl-reviewer-a.md:4-5`, `:16`). Narrowly permitting exactly those admitted file hashes therefore has no identified conflict with that product contract, provided all other boundaries remain unchanged. This is a contract-compatibility finding, not proof of native permission matching or permission to modify the host.

`validate-review-context-set.sh:327-370` fixes the invocation JSON key set, `fallback_mode: none`, and `read_only: true`; it does not accept an `allowedTools` field or validate actual native permissions. Put no new permission field in that manifest. Installed CLI help supports `--allowedTools` independently of `--tools`. A launch-scoped allow rule is a host permission delta even when it enables only an already-required read operation. Previous permission to review / prepare diagnostics does not silently apply that delta. No A22-only launch exception is relevant or used.

Preserve A6 and its consumed identity. There is no discovered same-session recovery authority. A future authorized attempt must use the existing provenance re-review route (skill Post-Implementation Provenance Re-Review), current M+1, unchanged Passed header, fresh actual native identity, normal precheck/verify/reserve, and independent A/B.

## Exact proposed argv delta: single-file hashes only

These are the exact additional argv elements proposed for reviewer A if the next normal precheck admits exactly these ten paths at attempt 7 round 1. Insert them into the existing ordinary fresh custom-agent launcher; keep `--permission-mode dontAsk`, `--tools Read,Grep,Glob,Bash`, write denials, Sonnet, exact original role definition, empty prompt, and DEVNULL stdin. No wildcard or extra CLI option is implicit. Do not run the old A6 helper; it lacks this delta and names the consumed attempt.

```json
[
  "--allowedTools",
  "Bash(rtk proxy shasum -a 256 plugins/sdd-review-loop/references/reviewer-calibration.md)",
  "Bash(rtk proxy shasum -a 256 reports/impl-review/epic-195-a7-compatibility/attempt-7/round-1/precheck-result.json)",
  "Bash(rtk proxy shasum -a 256 specs/epic-195-a7-compatibility/acceptance-tests.md)",
  "Bash(rtk proxy shasum -a 256 specs/epic-195-a7-compatibility/design.md)",
  "Bash(rtk proxy shasum -a 256 specs/epic-195-a7-compatibility/frontend-spec.md)",
  "Bash(rtk proxy shasum -a 256 specs/epic-195-a7-compatibility/infra-spec.md)",
  "Bash(rtk proxy shasum -a 256 specs/epic-195-a7-compatibility/investigation.md)",
  "Bash(rtk proxy shasum -a 256 specs/epic-195-a7-compatibility/requirements.md)",
  "Bash(rtk proxy shasum -a 256 specs/epic-195-a7-compatibility/security-spec.md)",
  "Bash(rtk proxy shasum -a 256 specs/epic-195-a7-compatibility/ux-spec.md)"
]
```

Each command must be issued alone, with the exact spelling and one named file; no shell assignment, pipe, redirect, added argument, wrapper interpreter or appended command. No `Bash`, `Bash(*)`, `Bash(rtk *)`, or prefix wildcard grant. If the actual next manifest differs, regenerate and inspect the exact list instead of treating this proposal as admission. Reviewer B needs its independently admitted list (including its new sanitized summary); do not reuse A's grants blindly. Native exact-rule interpretation/negative matching has NOT been tested. These additions also do not remove inherited user permissions: they are narrow additions, not an OS sandbox or proof of a deny-all policy.

## Remaining limits and minimal human action

This hash-only delta does not authorize the failed compound command or solve the entire launch. Independent receipt/input-digest calculation still needs stdout-only literal hashing; directory existence checking has its separately stated boundary exception (`review-context-boundary.md:291-297`). No wildcard Bash rule for those operations is proposed here. Their exact normal commands and native permission behavior must be resolved before another formal reservation; otherwise the next attempt could consume another identity without evaluating anything. Future receipt literals include fresh identity/sequence values not yet available, so no fabricated executable receipt argv is supplied. First-use Fact-Forcing also remains enabled and must be honored normally.

The minimum user action for the file-hash delta is scoped approval, not a global settings edit or restarting A6. Suggested approval wording: “A7の次の正式fresh impl-reviewだけ、通常precheckがadmitした各exact pathの単独 `rtk proxy shasum -a 256` に限定した上記 `--allowedTools` 追加を承認する。dontAsk・既存write拒否・fresh identity・通常ゲートを維持し、A6を再利用しない。receipt計算など未確定操作は別途exact範囲を確認する。” The parent can then prepare the non-protected fresh launcher under that scope; this report has not applied it. Do not ask the user to execute a made-up full launch or attach/approve the already interrupted A6.

If an existing genuine human approval already explicitly covers this exact host read/hash permission delta, cite that approval instead of requesting it again. Approval of protected read-allowance code repair or of additional reviews alone is not evidence that native host permissions were configured, and the investigator has not applied or verified them.

Conclusion: scoped exact-path hash flags are compatible with the inspected ordinary product launch contract in principle. Host permission-change authority must be attributed to its actual approval, and native acceptance remains unverified by this investigation. No full fresh-review command is released as ready; no formal gate result is claimed.
