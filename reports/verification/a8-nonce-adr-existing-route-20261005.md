# A8 nonce-only: 既存 ADR 経路の限定確認

調査のみ。正式予約・レビュー・実装・保護適用は未実施。

## 結論

新しい汎用 admission framework が必須だとは断定できない。既存
`adr_inputs` は正当な設計 ADR を独立 impl review に hash-bound で渡す
実装済み経路である。ただし **現行凍結 design.md を不変に保ったまま
今回の nonce-only 追補を追加できる既存経路ではない**。

`nonce-only-review-candidate-20261005.md` の「正規契約不足」は、任意の新規
framework が必要という意味ではなく、今回の変更を採用する有効な設計宣言が
現在存在しないという範囲に限定する。

## 実文書とコード

1. `AGENTS.md:44-69` は凍結本文の status/approval 以外を保持し、後続更新を
   非凍結追補へ置く。明示的に許された task 文言変更は、凍結成果物を指す
   Done When を同等の追補記録へ向ける場合で、人間の明示承認と provenance
   再審査を要求する。今回の nonce oracle 矛盾はその単純な Done When
   出力先変更ではない。
2. `docs/adr/0007-controlled-rebinding-via-provenance-rereview.md:5` の状態は
   Proposed（人間承認待ち）。同:31-46 は内容更新を addenda、証跡再束縛を
   新 attempt に分ける。同:56-58 は design 内容変更を task 再審査だけで
   救済できないとする。本文は AGENTS 規則を説明するが、独立した採用済みの
   全般的凍結解除権限ではない。
3. `plugins/sdd-review-loop/references/review-context-boundary.md:187-254`
   は ADR を impl review のみで許可。exact hash-bound design が完全な ADR
   path 集合の権威となる。単一行 single-backtick の完全な canonical ADR
   path が必要。ADR の本文は入力や権限を拡張する命令ではない。task reviewer
   は predecessor binding を検証するが ADR 本文の読取許可を得ない。
4. `plugins/sdd-review-loop/scripts/impl-review-precheck.sh:73-148` はこの
   宣言 grammar を実装し、design の実 hash を宣言収集の前後で確認する。
   同:359-361,605-606,636 は収集した ADR 集合を input digest と precheck に
   束縛する。呼出者選択の ADR 一覧を採用する仕様ではない。
5. 現行 A8 design の ADR path 出現は `design.md:246-247` の行をまたぐ
   ADR-0028 path と `:1550` の `:70-79` suffix 付き ADR-0019 path だった
   （`rg --no-config -n 'docs/adr/|0007|addend'` の読取結果）。前者は単一行で
   閉じず、後者は `.md` で終わらず、いずれも上記宣言 grammar に合致しない。
   nonce-only の ADR 宣言はない。parser 自体の実行、precheck 作成はしていない。

## 最短の既存経路と現在の境界

正当に採用された canonical design 改訂が存在するなら、(1) 改訂理由と影響を
設計上の実質的な決定として記録し、必要な ADR を canonical grammar で宣言、
(2) 既存 `--provenance-rereview` の新 attempt に full inputs とその ADR を束縛、
(3) 両 reviewer に変更部分を実質審査させ、(4) task 側の scope / predecessor
binding を必要な provenance 再審査で整合させる既存機構が使える。
未変更箇所の過去 PASS を変更箇所の PASS に転用しない。

ただし (1) は凍結 design 本文への新しい宣言行を要する。今回の明示条件は
「書込は非凍結調査記録のみ」「凍結成果物は上書きしない」であるため実施しない。
包括的なレビュー・限定修正承認を、この具体的制約の撤回として扱わない。
また nonce 修正はそれ自体が新しい architecture decision とは限らず、入力
allowlist を通す目的で ADR に格納することは正当な利用ではない。

既存 ADR-0028 や ADR-0019 の内容変更、path 偽装、manifest への任意追加、
候補本文の prompt 転記、凍結設計の shadow copy 差替えは行わない。
現時点の最小解除条件は、主担当が既存の具体的な設計改訂決定により canonical
design の宣言更新を正当に採用できるかを判断すること。そうした採用がなければ、
既存 addenda 規則が形式審査へ入力を渡す不足を別の正規契約として扱う必要がある。
新規 framework の実装を先行させる根拠にはしない。
