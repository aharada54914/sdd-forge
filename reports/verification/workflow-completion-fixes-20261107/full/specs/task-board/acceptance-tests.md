# Acceptance Tests

## UI Integration Checklist
- AC-001 / REQ-001: localhostの `/` にアクセスすると日本語見出し、ラベル付き入力、追加ボタン、一覧へ直接到達する。認証や別ナビは不要。

## Observable Scenarios
| AC | REQ | Given / When / Then | Evidence plan |
|---|---|---|---|
| AC-002 | REQ-001 | 空一覧で「  買い物  」を追加すると「買い物」が1件だけ表示され入力が空になる | TEST-001 browser + API |
| AC-003 | REQ-001 | 空文字、半角空白、全角空白、改行のみの追加を拒否しJSON件数は変わらない | TEST-002 negative API/browser |
| AC-004 | REQ-002,REQ-004 | checkboxをcheck、reloadすると完了。uncheck、reloadすると未完了 | TEST-003 browser |
| AC-005 | REQ-003,REQ-004 | 削除確認をcancelすると保持。確認すると行が消えreload後も戻らない | TEST-004 browser |
| AC-006 | REQ-004 | 追加後サーバー再起動しGETすると同一id/title/completedが戻る | TEST-005 stdlib integration |
| AC-007 | REQ-005 | 保存応答を遅延中に連打/Enter/checkbox/削除を操作しても更新requestは1件だけ。応答後に再操作可能 | TEST-006 Playwright route delay |
| AC-008 | REQ-005,REQ-008 | 保存を失敗させると日本語エラー、入力保持、操作解除。自動再送せずreloadで正しい状態を表示する | TEST-007 browser fault injection |
| AC-009 | REQ-006,REQ-008 | 1440pxと390pxおよび320pxで横スクロールなく操作でき、長い日本語が折り返す。navy/teal/白系・余白・丸角を参考画像 `specs/task-board/mockups/imagegen-reference.png`（SHA-256: `60049c2b9d49f059afbe50ec43cc0d0802bae75b15b5dde090c4acdaf00127d8`）と比較する。比較前に実ファイルのhash一致を確認する | TEST-008 actual screenshots + reference hash |
| AC-010 | REQ-007 | HTML風titleは文字表示。不正JSON、型違い、存在しないid、外部Origin変更要求、静的path traversalは拒否 | TEST-009 negative integration |
| AC-011 | REQ-008 | 初期空表示、読込中、GET失敗と再読込回復を確認。Tab/Enter/Spaceで追加と切替と削除確認cancelが使える | TEST-010 browser |
| AC-012 | REQ-004 | JSON破損および書込失敗では非2xxを返し既存ファイルを保持する | TEST-011 stdlib temporary storage |
| AC-013 | REQ-007 | server起動後、実processのlisten socketを調べ、起動portのlisten addressが `127.0.0.1` のみであることを確認する。`0.0.0.0`、`::`、`::1`、非loopback addressには同portのlistenerがない。`127.0.0.1` 経由のGET `/` は200。同一hostの実非loopback IPv4 addressに同portでTCP接続しても成立せず、HTTP画面が公開されないことを確認する。非loopback interfaceがない環境では未検証と記録し、ある環境で検証するまでPASSにしない | TEST-012 actual process/socket inspection + direct TCP probe (proxy不使用)、address/port/接続結果を保存 |

検証出力はreports/以下へ実コマンド・exit code・スクリーンショットとともに保存。実行前の表は検証計画でありPASSではない。
