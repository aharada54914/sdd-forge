# Requirements: sdd-forge-refactor

## Overview

v0.15.0 で `/sdd-bootstrap` + `/sdd-ship` の2コマンド化が完了した。
このリファクタリングはその内部構造を整理し、メンテナンスコストを下げ、
セキュリティパリティを修正することを目的とする。
**すべての変更は加法的または等価的であり、既存の機能を削除・弱体化させない。**

## Target Users

- **sdd-forge コントリビューター**: プラグインの内部構造を把握・修正する開発者。
  現在 2 プラグインに分散する review-loop ロジックを 1 プラグインで管理できるようになる。
- **sdd-forge エンドユーザー**: 変更に気づかない。BL-001〜BL-014 の振る舞いはすべて保たれる。
- **セキュリティ審査者**: Python ガードの Check 2e 不在（INV-002）が修正され、
  JS/Python 間のパリティが回復する。

## Problems

- 並列プラグインの維持コスト: SKILL.md 475 行の同構造ロジックが 2 ファイルに分散（INV-001）。
- Python ガードのセキュリティパリティギャップ: Check 2e 不在（INV-002）。
- `validate-repository.ps1` の既存不整合: `$expectedSkills` 15 件 vs 実数 17 件（INV-003）。
- ドキュメントのユーザーモデルズレ: 2コマンド化後も内部スキル詳細がユーザー向け文書に混在（INV-006）。
- `sdd-bootstrap-interviewer` がベア命令でレビュープラグインを呼び出す（INV-005）— サイレント no-op リスク。

## Goals

- **REQ-001**: `sdd-impl-review` と `sdd-task-review` の SKILL.md・agent ファイル・policy ドキュメントを `sdd-review-loop` プラグインに統合移動する。各スキルは独立を保ち（`--phase` 統合はしない）、呼び出し後の振る舞いは BL-001〜BL-006 を完全に保持する。
- **REQ-002**: Python ガードに Check 2e（`impl_review_status_passed_increases` 相当）を追加し、JS/Python のパリティを回復する。bare relative path 解決（JS と同じ CWD 基準）を使用する。
- **REQ-003**: `validate-repository.ps1` の `$expectedSkills` を修正して `sdd-bootstrap` と `sdd-ship` を追加し（15 → 17 件）、旧プラグインパスを `$forbiddenPaths` に追加する。
- **REQ-004**: `sdd-bootstrap/SKILL.md` と `sdd-bootstrap-interviewer/SKILL.md` の全呼び出しサイトを新プラグイン名 `/sdd-review-loop:impl-review-loop` / `/sdd-review-loop:task-review-loop` に更新する。
- **REQ-005**: `docs/skill-reference.md` と `docs/workflow-guide.md` をユーザー向けコンパクト版と内部コントリビューター向けの 2 層に再構成する。
- **REQ-006**: guard-parity テストスイートに Scenarios 19/20/21 を追加し、Check 2e の JS/Python パリティを検証する。

## Non-goals

- PS1 ガードへの R-10 / Check 2e 追加（別 issue で追跡）。
- `sdd-review-loop` の marketplace.json 登録（旧プラグイン同様、未登録を維持）。
- 既存のフックガード crypto（HMAC sudo、署名検証）の変更。
- `sdd-ship` や `sdd-bootstrap` の振る舞い変更。
- `docs/workflow-guide.md` Mermaid 図の更新（スキル名はベア名のままで正確）。

## Acceptance Criteria

`acceptance-tests.md` の AC-NNN を参照。

- AC-001: `/sdd-bootstrap` 実行時に新 `/sdd-review-loop:impl-review-loop` が起動する
- AC-002: hook guard が新パス `plugins/sdd-review-loop/` 配下への不正書き込みを拒否する
- AC-003: hook guard が旧パス `plugins/sdd-impl-review/` `plugins/sdd-task-review/` への書き込みを拒否する（削除後は no-op）
- AC-004: Python ガードが `Impl-Review-Status: Passed` + verdict なしを exit 2 で拒否する
- AC-005: Python ガードが valid PASS verdict ありなら exit 0 で許可する
- AC-006: guard-parity.tests.sh が Scenarios 19/20/21 を含む全シナリオで pass する
- AC-007: `validate-repository.ps1` が 17 件のスキルを正常検出し pass する
- AC-008: `scenario.tests.sh`・`install.tests.sh` が変更前後で同じ結果を返す（BL-010/BL-011 維持）
