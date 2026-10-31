# T-002 evaluator startup precheck stopped — 2026-10-03

The owner-side deterministic T-002 contract check passed after current-byte lint, strict typecheck, focused/regression checks, Registry validation, and the human isolated FilesOnly build were recorded. The frozen implementation report was not edited. A separate hash-pinned post-fix declaration exists at `reports/quality-gate/issue423-t002-post-fix-declaration-20261003.md`.

Before any evaluator manifest reservation or native launch, the quality-gate skill requires resolution of the live model and a comparison to `.codex/agents/sdd-evaluator.toml` reference comments. The first source-inspection command was denied before execution:

```text
Command: rtk proxy rg -n 'gpt-6.1-sol|gpt-5.6-sol|gpt-6-sol|gpt-6-luna|sdd-evaluator' contracts/agent-model-capabilities.v2.json .codex/agents/sdd-evaluator.toml
Script error:
Command blocked by PreToolUse hook: SDD決定論ゲート: developer_instructions の無い Codex エージェントロールファイルの書き込みを拒否しました。.codex/agents/ 配下のファイルは developer_instructions を定義する必要があり、無い場合 Codex は起動時にこれを無視します（'Ignoring malformed agent role definition'）。新規作成せず、同梱の sdd-investigator / sdd-evaluator ロールを使用してください。
[EN] SDD deterministic gate: refusing to write a Codex agent role file without developer_instructions. Files under .codex/agents/ must define developer_instructions or Codex ignores them at startup ('Ignoring malformed agent role definition'). Use the shipped sdd-investigator/sdd-evaluator roles instead of creating new ones..
```

The requested command was read-only, but the hook classified it as a prohibited role-file write. No part of it ran. This is a real preparatory refusal, not evaluator evidence. It was not retried through another tool or split into alternate read commands. No evaluator identity was reserved, no native evaluator was launched, no review verdict was produced, and task status remains `Implementation Complete`.

Minimum human action: inspect the shipped `.codex/agents/sdd-evaluator.toml` and live model-registry entries under the user's own authority, resolve the hook's false-positive classification through the normal protected change process, and provide or authorize a clean ordinary read for the model/TOML drift check. Then the coordinator can recheck declaration and input hashes, create and validate a fresh invocation, reserve one evaluator identity, and launch the fresh evaluator. Do not bypass the hook or treat FilesOnly assembly as native host activation.
