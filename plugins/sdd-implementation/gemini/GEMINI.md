# SDD model selection

新規の対話セッションでは、`../skills/model-selection/SKILL.md` の共通選択UIで、既存CLIの認証経路から取得したモデルとモデル別推論強度を使用者に選んでもらう。固定候補やAPIキー経路への自動切替は行わない。Geminiは認証後のACP一覧を使い、公開されない推論強度はCLI既定と明示する。スクリプトはこのextension rootの `../scripts/session-models.py`。resume・compact・非対話・ワーカーでは繰り返さない。選択結果は実配信証明ではなく、既存の安全な起動経路がない役割は停止して再選択する。
