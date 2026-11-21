# SDD Implementation & Model Selection (Gemini CLI)

実装・診断・モデル選択を担う Gemini CLI 拡張です。

## 実装系スキル（親ディレクトリ `../skills/`）
- `implement-task`: 承認済み単一タスクの実装（`../skills/implement-task/SKILL.md`）
- `implement-tasks`: 依存順バッチ実装（`Implementation Complete` で `ship` へ返却、`../skills/implement-tasks/SKILL.md`）
- `diagnose`: `/sdd-implementation:diagnose`（5 フェーズバグ診断、`../skills/diagnose/SKILL.md`）
- `sql-develop`: `/sdd-implementation:sql-develop`（隔離 DB 検証、`../skills/sql-develop/SKILL.md`）
- `visual-verify-loop`: UI 視覚検証（任意、`../skills/visual-verify-loop/SKILL.md`）
- `model-selection`: セッションモデル選択（任意、`../skills/model-selection/SKILL.md`）
