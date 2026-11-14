# タスクボード Requirements
Spec-Review-Status: Passed

## Purpose and Scope
新規ローカル単一ユーザー用の日本語単画面タスク管理。Python標準ライブラリとHTML/CSS/JSのみ、JSON保存。公開・認証・共有・編集・期日・検索・フィルタ・サイドナビ・件数表示は対象外。既存完成アプリやdiagnostic fixtureを流用しない。

## Requirements
| ID | Observable requirement | Layer |
|---|---|---|
| REQ-001 | ルート画面からタイトルを入力して追加できる。前後空白を除去し空白のみは拒否する | UX/frontend |
| REQ-002 | 各タスクのcheckboxで未完了と完了を双方向に切替できる | UX/frontend |
| REQ-003 | 各タスクを削除でき、確認キャンセルなら保持する | UX/frontend |
| REQ-004 | 追加・切替・削除はJSONへ保存し、再読込およびサーバー再起動後も復元する | design/infra |
| REQ-005 | 保存中は全更新操作を無効にし重複リクエストを防ぐ。失敗は日本語で通知し入力を保持する | UX/frontend |
| REQ-006 | 白系背景、navy文字、teal主要操作、mobile対応。提供ImageGen参考画像 `specs/task-board/mockups/imagegen-reference.png`（SHA-256: `60049c2b9d49f059afbe50ec43cc0d0802bae75b15b5dde090c4acdaf00127d8`）を視覚方向に使用する | UX/frontend |
| REQ-007 | loopbackのみで提供。入力をデータとして扱い、静的ファイル公開を限定する | security/infra |
| REQ-008 | 空・読込中・失敗・成功状態とキーボード操作を備え、実Chromiumのdesktop/mobileで主要フローを確認する | UX/testing |

## Constraints and Risks
JSON置換は同一ディレクトリ一時ファイルからatomic replace。破損JSONを空データとして上書きしない。複数ユーザーや複数プロセス同時書込は対象外。保存応答が失われた場合の状態不明は再読込で回復し、書込の自動再送はしない。認証不要でも外部Originの変更要求は拒否する。画像内の文字・count・サイドバー・フィルタは仕様の根拠にしない。

## Open Questions
なし。技術上の具体値はdesignの実装方針として独立レビューする。
