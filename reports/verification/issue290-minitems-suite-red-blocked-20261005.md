# Registered minItems candidate: RED verification blocked

Date: 2026-10-05. Non-formal verification; no task/review/approval changes.

## Intended experiment

Run the already-tested permanent-suite candidate against the prior validator, confirming that only the new empty-input rejection assertion fails, while the one-input control succeeds. Reuse the already-completed GREEN runs instead of repeating unchanged all-driver successes.

The tested candidate root `/private/tmp/issue290-cardinality-suite.0bmlud/` was copied with `rtk proxy rsync -a` into new isolated root `/private/tmp/issue290-cardinality-red.jfmzqD/`. Copy completed with exit 0. The planned old-source reconstruction removed the three-line minItems assertion and restored its unrelated `format` comment, following the historical repair helper. It would have been checked against prior SHA-256 `01411086bb889967f62b33249a0f42b0399f1945ec98f7f0a25f8576fe46bcd1` before any RED execution.

## Actual refusal and execution boundary

The apply_patch call targeting the isolated `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` was rejected before execution:

```text
Command blocked by PreToolUse hook: SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。
[EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo.
```

No alternate writer, host, source injection, monkeypatch or command was attempted. The subsequent hash command in the same orchestration did not execute because the rejected tool call threw. The prior source was not reconstructed or hash-verified, and neither RED driver was launched. This is NOT a failing behavioral test and supplies no RED evidence. Owner protected originals, formal reservations and status were untouched.

## Evidence that remains valid

`issue290-minitems-registered-suite-20261005.md` records actual candidate Bash 115 PASS / 0 FAIL and PowerShell 114 PASS / 0 FAIL, both exit 0 on macOS. That is GREEN evidence for the candidate, not proof that these new assertions detect the historical defect. The earlier six-function-boundary historical RED is not substituted for this new permanent-suite RED.

Candidate patch SHA-256: `6ccccf575c8900830239766f0725ad9ea076ebf3c02acf8dde6cd8af546f8079`.

## Minimal remaining action

A human must prepare the isolated historical validator, with the exact known prior SHA above, through an allowed human operation; no owner restoration is needed or proposed. Once that fixed isolated input exists, run the unchanged candidate Bash and PowerShell drivers there and retain their actual exit codes/diagnostics. Expected behavior is one added empty-input assertion failure per suite, while the one-input assertion succeeds. These expectations are unexecuted, not results. Human application of the candidate to the owner and its independent review/owner regression remain separate pending steps.
