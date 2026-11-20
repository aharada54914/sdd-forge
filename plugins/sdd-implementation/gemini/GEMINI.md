# SDD Implementation & Model Selection (Gemini CLI)

新規の対話セッションでは、`../skills/model-selection/SKILL.md` の共通選択UIで、既存CLIの認証経路から取得したモデルとモデル別推論強度を使用者に選んでもらう。固定候補やAPIキー経路への自動切替は行わない。Geminiは認証後のACP一覧を使い、公開されない推論強度はCLI既定と明示する。スクリプトはこのextension rootの `../scripts/session-models.py`。resume・compact・非対話・ワーカーでは繰り返さない。選択結果は実配信証明ではなく、既存の安全な起動経路がない役割は停止して再選択する。

## 実装系スキル（親ディレクトリ `../skills/`）
- `implement-task`: 承認済み単一タスクの実装（`../skills/implement-task/SKILL.md`）
- `implement-tasks`: 依存順バッチ実装と `quality-gate` 連携（`../skills/implement-tasks/SKILL.md`）
- `diagnose`: `/sdd-implementation:diagnose`（`../skills/diagnose/SKILL.md`）
- `sql-develop`: `/sdd-implementation:sql-develop`（`../skills/sql-develop/SKILL.md`）
- `visual-verify-loop`: UI視覚検証ループ（`../skills/visual-verify-loop/SKILL.md`）
