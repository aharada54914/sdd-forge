# A8 caller proxy-cat: current normal-path refusal

2026-10-05. Root explicitly authorized one normal read against the currently installed guard. This is a fresh actual refusal, not a synthetic native success or an alternative executor.

Tool: exec_command; login=false; max_output_tokens=4500.
Cwd: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`.
Exact submitted command:

```text
rtk proxy cat .codex/agents/sdd-investigator.toml .codex/agents/sdd-evaluator.toml
```

Raw returned refusal:

```text
Command blocked by PreToolUse hook: SDD決定論ゲート: developer_instructions の無い Codex エージェントロールファイルの書き込みを拒否しました。.codex/agents/ 配下のファイルは developer_instructions を定義する必要があり、無い場合 Codex は起動時にこれを無視します（'Ignoring malformed agent role definition'）。新規作成せず、同梱の sdd-investigator / sdd-evaluator ロールを使用してください。
[EN] SDD deterministic gate: refusing to write a Codex agent role file without developer_instructions. Files under .codex/agents/ must define developer_instructions or Codex ignores them at startup ('Ignoring malformed agent role definition'). Use the shipped sdd-investigator/sdd-evaluator roles instead of creating new ones.. Command: rtk proxy cat .codex/agents/sdd-investigator.toml .codex/agents/sdd-evaluator.toml
```

The shell did not run. No post-shell argv exists. No alternate role read, native allocation, reservation or formal turn followed.

## Current source classification

Read-back SHA-256 for installed Python at `/Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-quality-loop/1.18.0/scripts/sdd-hook-guard.py`: `248b78aa0419e6693d3d1e29d20390af1a1de422a411c4fdd7e30b5066126227`.
Working #536 Python at `/private/tmp/sdd-guard-main.3JEj4I/repo/plugins/sdd-quality-loop/scripts/sdd-hook-guard.py`: `7392cccf47ece13bd6af919bcd319926f92911b11a41a6e7dd243eb41f68c77a`.
Both are unchanged from the saved bounded cat diagnostic. Hashes identify those inspected files; the actual refusal does not expose which runtime generated it, so no unsupported runtime-attestation claim is made.

Installed Python lines 75–77 admit direct reader verbs only. Lines 1720–1754 admit the exact `rtk proxy rg` form only. Line 1764 classifies any role-path command matching neither as a write. The exact proxy-cat command matches neither. Saved inert-input diagnostic (`handoffs/t004-fresh-01a107c3-2a6f-75b3-8704-56d694e60af4/caller-verification/cat-policy-diagnostic.log`) previously showed both of these same source hashes deny exact/proxy cat, accept direct cat, and deny redirect/compound writes. This run adds a current real normal-path refusal; it does not re-execute those inert tests or the payload by another path.

Thus this is a missing proxy-cat operation classification, not the Unicode/--no-config rg grammar fix. #536's existing rg candidate is not a completed cat repair awaiting installation. The older native worker rg refusal still has unknown argv and is NOT diagnosed by this finding.

## Minimal legitimate repair boundary

`/private/tmp/sdd-guard-main.3JEj4I/repo/reports/verification/read-policy-implementation-boundary-20261004.md` requires a complete-invocation pure-read classifier shared by Python/JavaScript/PowerShell and forbids stacking another prefix exception. Its required matrix includes direct/proxy cat, multiple literal paths, redirect/compound rejection and native identity. Do not add broad Node permission or weaken isolation. Current requirements line 3 remains Spec-Review-Status Pending; design line 3 remains Impl-Review-Status Pending; bounded spec file inventory has no tasks.md. The recovery data contract line 3 remains Draft.

Accordingly no guard product implementation or installed edit is allowed under the current SDD phase. Existing user repair authorization is preserved and is not requested again; the missing artifact is reviewed/approved implementation scope, not general permission. The prepared changed-input proposal is `handoffs/t004-fresh-01a107c3-2a6f-75b3-8704-56d694e60af4/caller-verification/changed-input-prelaunch-recovery-addendum-candidate-20261005.md`. It is only a candidate, not an executable recovery contract. Root must complete the consumer/recovery formal path, reviewed scope and approved task, then apply the guarded implementation normally and rerun this exact normal read. Preserve old incomplete rounds, frozen hashes and identities. Do not demand a write canary from a read-only evaluator.

No repair GREEN is claimed. This note is the only addition in this follow-up. Existing dirty state, protected sources, role contents and evidence were preserved. Debugger skill was used to separate current observation, source cause, historical inert-test evidence and the formal implementation boundary.
