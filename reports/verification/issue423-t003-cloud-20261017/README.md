# Issue #423 T-003 クラウド継続記録（2026-10-17 JST）

本記録はユーザー承認済みのテスト補完と入場条件の調査結果。正式な実装レポート、独立レビュー判定、quality-gate判定、証拠bundleの代用ではない。

## 開始点と作業境界

- `git clone --branch codex/issue423-boundary-checkpoint --single-branch https://github.com/aharada54914/sdd-forge.git sdd-forge` 成功。
- `git cat-file -t 1f1c908bcc7312e986642afb22670597395f32ad`: `commit`。
- `git branch --show-current`: `codex/issue423-boundary-checkpoint`。
- `git rev-parse HEAD`: `1f1c908bcc7312e986642afb22670597395f32ad`。
- `git status --short`: 開始時は空。既存のremote 4コミットを含む履歴を保持。
- `git ls-remote origin refs/heads/codex/issue423-boundary-checkpoint refs/heads/main`: 開始時の対象remote SHAはHEADと一致。mainは`f10c2c61f93e5deca46f73497ca8feaa0315df26`。`git fetch origin main`は参照確認のみで、merge/rebaseは行っていない。
- AGENTS.md、引継ぎ、cloud-input README、正本のtasks/requirements/design/acceptance-tests/traceabilityと4 layer仕様、関連schemaと実消費者を読んだ。
- `docs/development-policy.md`は対象HEADにも取得したmainにも存在せず、取得済み履歴の当該path検索にも結果なし。別名の規約を同一文書とみなしていない。
- 変更はT-003の既存Pythonテストと本検証記録のみ。製品コード・Registry・凍結仕様・過去NEEDS_WORK・承認・台帳・保護・タスク状態は変更していない。ownerの未コミット作業は取得も公開もしていない。

## テスト補完（AC-003 / TEST-003a〜e）

旧単一gate fixtureは小さな境界controlとして保持し、対象別fixtureを別途追加。期待するfacet/gate集合は各テストに明記し、fixture生成表をそのまま期待値にしていない。Registry v1に既存の`artifact_kinds contains` predicateのみを使用。fixture固有IDはsynthetic Registry内だけに置き、製品Registryや条件付きgate契約を追加していない。

| 対象 | 選択と動作の検証 |
| --- | --- |
| CLI/library | interface/behavior/package/security facets、契約互換・package・security必須検証。UI/IaC/promotionチェックを要求しない。 |
| UI | flows/states/UX/API/data/security facets、interaction/accessibility/API-data/security検証。remote design serviceを要求しない。 |
| design-only | medium/specを明示。requirements/architecture/decisions/contracts/traceabilityを選択。unit/acceptance/buildの未実行・証拠欠落はBLOCKED。unit/acceptanceの降格もBLOCKED。compile免除は既存non-code規則の明示的required:falseと理由が必要。理由空・code stack・項目削除は拒否。 |
| IaC/cloud | resource intent/ownership/policy/topology/interfaceとvalidate/plan/policy。出力はimplementation stageのみ、apply/deploy成功フィールドはschemaで拒否。 |
| low-code | data model/permissions/process/packageと各validation。Registryは普遍的source-code-buildを要求しない。legacy buildは勝手に削除せず、spec stackの明示的compile免除を別検証。 |

各対象の各Registry必須チェックについて、他の成功観測を残したままその観測だけを除くとnot-run/BLOCKEDになること、verifier欠落時にunavailable/BLOCKEDになることを検証。既存AC-004/013とpackaging/schema/binding回帰も維持。synthetic観測のPASSは実サービス・実配備・正式ゲートの成功ではない。

## 実行結果

正確なargv/exit/logは`commands.json`と追加の`*-command*.json`に保存。

| 検査 | 結果 |
| --- | --- |
| T-003 Python suite | 28件成功（従来22件＋6件）。最終bytesは`t003-final.log`。 |
| registry-discovery Bash | 21件成功。 |
| registry-discovery PowerShell | 実行ファイル`pwsh`なし、exit 127。必須回帰としてBLOCKED。過去21件成功を流用していない。 |
| vendor同期 | exit 0、driftなし。 |
| git diff --check | exit 0。 |
| repository-wide check-workflow-state（--featureなし） | exit 0。既存の許容済みprovenance警告をログに保持。 |
| check-task-state（正本tasks.md） | exit 1: T-002がBlockedだが`### Blockers`本文なし。status-only修正はしていない。 |
| structure | 最初は誤ったscript pathでexit 127。正しい`bash scripts/check-sdd-structure.sh . sdd-domain-multitarget`はexit 0。両方を保持。 |
| lint/typecheck利用可否 | ruff/mypyが存在せず各exit 1。未検証でBLOCKED。以前の18型エラーを修正済みとも現行でも再現したとも主張しない。 |
| codex CLI利用可否 | executableなし、exit 127。再インストールなし。 |

失敗感度プローブは`python3 reports/verification/issue423-t003-cloud-20261017/mutation-probe.py`。Resolver出力のfacetを全対象共通にする誤りと、implementation gateを落とす誤りをそれぞれ注入し、5対象テストが拒否することを確認。最初はcompile免除だけのテストも含む6件すべて失敗すると誤って期待したためプローブ自身がexit 1。対象選択を検査する5件に限定した修正版と再実行ログを別保存し、最初の非ゼロを消していない。この注入は過去の実装前TDD REDでも独立レビューでもない。

## 正式入場で未解決の事項

`input-audit.json`と`helper-drift.diff` / `installer-drift.diff`に現行観測を保存。

1. 公開済み49原本はすべてinventoryのSHA-256に一致。原本の配布整合は確認できたが、現行gate適合とは異なる。
2. 公開T-001はImplementation Complete、T-002はBlocked、T-003はPlanned。T-003のBlockersはT-002。過去のローカルDoneを公開状態へ転記していない。
3. 正本`verification/T-002.contract.json`と`verification/T-002.evidence.json`は存在しない。dated bundleの過去判定ではこの欠落を埋められない。凍結bundleをコピー・redact・手書きhashで再作成していない。
4. archived helper/installerと現行bytesは異なる。helperは型注釈等7行ずつの差、installerはEXIT trapにおけるrollback呼出条件の差があり、実行bitも異なる。単なる同名ファイルでレビュー済みとみなせない。archiveへ巻き戻していない。
5. attempt10の183-input admissionには非公開handoffが欠ける。公開49原本が一致しても元の入力集合や承認・provenanceを再現しない。私的archiveの公開もしていない。
6. canonical T-003 implementation reportも存在しない。quality-gateの出力宣言・fresh input manifest・invoking implementation identityを満たす新規入力を過去から合成していない。排他的owner/過去context stopの証明も未取得。
7. `quality-gate/SKILL.md` Process 1は「Reject any target not in Implementation Complete.」。Process 8は正本実装レポートの出力宣言、完全なallowed-input manifest、ledger tip、fresh evaluator reservationを要求し、欠落/再利用時の起動を禁止する。T-003はICでなく、新しい独立Codexレビューを起動する前提を満たさない。CLI不在だけを理由にした起動経路の置換や同一会話の再レビューで代用していない。台帳への架空予約なし。

このテスト補完には製品契約変更は不要だった。portable証拠への移行は今回実施していない。元のraw pinを保持したまま新しい公開契約へ移す場合に必要な差分の候補は、(a) 新しい実行で生成する現行T-002 contract、(b) その現行bytesを評価する新しい実装/独立review/gate record、(c) 正式generatorによるcanonical `verification/T-002.evidence.json`、(d) 旧path/hashと新path/hash・非同値・移行承認を明記する独立の移行記録、(e) fresh T-003 input manifestと正当なownership/identity記録。旧bundleや183-input manifestを編集して新bytesを同一証拠にする案ではない。これを既承認の移行仕様とは扱わず、当該部分で停止する。T-001の真の完了closureも別途必要。欠落policyの提示と実行可能な必須検証環境が必要。

## 状態の区別

- 実装: 承認済みテスト補完のみ実施。製品機能追加なし。
- 回帰: Python28/Bash21、vendor、workflow-state成功。PowerShell/lint/typecheckは利用不能、task-stateは失敗。
- Major: 対象別動作の補完候補を実装。独立再レビュー未実施のため解消確定とはしない。
- 独立レビュー: 入場前提不足でBLOCKED。過去判定保持。
- 正式品質ゲート/Done: 未実施、BLOCKED。tasks.mdは変更なし。
- 全体CI: ローカル実施していない。push後のGitHub状態は別途`publication.json`で報告する。以前のCI成功は新HEADの証明にしない。
- merge: 未実施。PR #535は開始確認時Draft/open、merged:false、mergeable:false。mergeを強行しない。
