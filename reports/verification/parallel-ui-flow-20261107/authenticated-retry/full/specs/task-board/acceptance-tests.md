# Acceptance Tests: ローカルタスク管理

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | e2e | ブラウザから追加 | Planned |
| AC-002 | REQ-002 | TEST-002 | e2e | 完了と未完了の往復 | Planned |
| AC-003 | REQ-003 | TEST-003 | e2e | 複数件から選択削除 | Planned |
| AC-004 | REQ-004 | TEST-004 | integration + e2e | 再読み込みと実 JSON ファイル照合 | Planned |
| AC-005 | REQ-005 | TEST-005 | integration + browser network | 待受アドレス・外部通信 | Planned |
| AC-006 | REQ-006 | TEST-006 | inspection | 依存定義・新規ソース・起動説明 | Planned |
| AC-007 | REQ-007 | TEST-007 | inspection | reports 内の実行証拠とゲート結果 | Planned |

## UI Integration Checklist

追加入力で確定した画面到達経路と安全条件。

- [ ] AC-008: http://127.0.0.1:3000/ のトップページから入力欄と追加ボタン、一覧各行の完了切替と削除へ直接到達できる。
- [ ] AC-009: 空白のみの追加は UI と API の双方で拒否し、保存中は変更操作を無効化する。
- [ ] AC-010: 保存失敗時に成功表示へ遷移せず、本文を保持してエラーと再試行経路を表示する。

## 実ブラウザ検証手順（未実行）

承認されたタスクの実装後、ブラウザを実起動し、新規データディレクトリで空状態の画面を保存する。「買い物」と「書類」を追加し、買い物を完了にして再読み込みする。買い物を未完了に戻し、書類を削除して再読み込みする。各段階の DOM・スクリーンショット・ネットワークエラー・JSON 内容を保存して照合する。診断用既存アプリや fixture は使わない。

## 追加の受け入れ検証

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-008 | REQ-001,002,003,009 | TEST-008 | e2e | トップページから全操作へ到達 | Planned |
| AC-009 | REQ-008 | TEST-009 | integration + e2e | 空白・201文字・保存中の無効化 | Planned |
| AC-010 | REQ-004,010 | TEST-010 | integration + e2e | 保存失敗・破損JSON・入力保持・再読込 | Planned |
| AC-011 | REQ-009 | TEST-011 | e2e + visual | 日本語・320/1280px・キーボード・通知 | Planned |
| AC-012 | REQ-005,010 | TEST-012 | integration + e2e | Host/Origin/型/容量/XSS/未知ID | Planned |
| AC-013 | REQ-004 | TEST-013 | integration | 続けた保存・再起動・失敗時の旧内容維持 | Planned |

失敗系は実保存先を壊さず一時ディレクトリと注入可能な保存アダプタで検証する。本文のスクリプト文字列は実ブラウザでも不実行を確認。保存中は応答を制御して全変更コントロールの無効化を検査する。各TESTは承認タスクの実装後に実行し、現時点はすべて未実行。
