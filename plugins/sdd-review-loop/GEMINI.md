# SDD Review Loop (Gemini CLI)

Gemini CLI 向けの 3 段階独立レビューループ拡張です（`skills/spec-review-loop/SKILL.md`、`skills/impl-review-loop/SKILL.md`、`skills/task-review-loop/SKILL.md`）。各ステージで precheck スクリプトと `validate-review-context-set` のアイデンティティ予約・入力ハッシュ検証を必ず実行します。Gemini に汎用独立レビューアダプターがない管理起動では、未対応経路を明示して再選択を求めます（`gemini -p` による保護迂回は禁止）。
