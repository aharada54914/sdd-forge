# T-010 の現行配布契約に関する所有者決定

2026-11-26、PR #976 の所有者が次の2点を承認した。

## Bootstrap の TEST-007

旧設計テンプレートだけに依存する以下の8項目は、両スイートの通常検証から退役する。履歴原本での継続実行も求めない。旧仕様での対応は [AC-007](../../../../bootstrap-interviewer-enhancement/acceptance-tests.md#L11) に残る。

| スイート | 退役した項目 |
|---|---|
| bootstrap-cross-layer-index | UX、frontend、infra、security の各リンク4件と、Cross-Layer Dependencies、ADR Change Log、Constraint Compliance の各見出し3件 |
| bootstrap-layer-templates | ワークフロー上の位置と担当タスクがレイヤーを有効にするという旧テンプレートの記述1件 |

通常の FilesOnly インストールで現在配布する requirements.md、design.md、tasks.md をそれぞれ検証する。8項目を外す前後で残る149項目の検査名、判定、実行順は一致した。実配布3文書と既存のソース検査4件が成功した。

## 設計同期の TEST-037・038・043

再生成後は毎回、実際に送る内容をスキャンする。同じ機能・セッションで以前に明示的に承認した例外は、実際の送信ファイルのパスと内容、送信先、今回の所見がすべて一致した場合に再利用できる。いずれかが変わった場合、所見を含む送信には新しい承認が必要になる。スキャンの異常終了は送信を停止する。スキャン例外と外部送信への同意は個別に解決し、例外を辞退した場合は送信や上書き記録を行わず、修正後に再スキャンする。

この決定は、旧仕様の「同一でも例外の再承認を求める」という条項に対して現行配布で優先する。旧仕様の該当箇所は [REQ-006・AC-021](../../../../design-sync-scan/requirements.md#L155)、[設計判断](../../../../design-sync-scan/design.md#L271)、[TEST-037・038](../../../../design-sync-scan/acceptance-tests.md#L47)、[T-003](../../../../design-sync-scan/tasks.md#L608)、[トレーサビリティ](../../../../design-sync-scan/traceability.md#L65) に記録されている。
