# SDD Quality Loop (Gemini CLI)

Gemini CLI 向けの品質ゲート・安全フック拡張です。

- **BeforeTool 安全フック**: `hooks/hooks.json` が全ツール呼出前に `../scripts/sdd-hook-guard.py --emit gemini` を実行します。`AGENT_STOP` キルスイッチ、`tasks.md` の `Approval: Approved` / `Second Approval: Approved`、`domain/context-map.md` の `Domain-Model-Status: Approved`、`WFI-*.md` の `Status: Approved`、`design.md` の未検証 `Impl-Review-Status: Passed`、`SDD_SUDO`、および強制チェーン保護対象ファイルへの `write_file` / `replace` / `run_shell_command` を決定論的に拒否します。
- **スキル配置**: 親ディレクトリ `../skills/` 配下に `quality-gate`、`fix-by-review-ticket`、`sdd-sudo`、`cross-model-verify`、`workflow-retrospective`、`wfi-audit-cycle` があります。
- **コマンド**: `/sdd-quality-loop:fix-by-review-ticket <ticket>`、`/sdd-quality-loop:sdd-sudo <args>`。
- **検証原則**: 独立評価と決定論的ゲート（`check-contract` / `check-evidence-bundle` / `check-placeholders` / `check-task-state` / `check-quality-gate-cycle-limit` / `validate-review-context-set`）はファイルベース手続きが正本です。
