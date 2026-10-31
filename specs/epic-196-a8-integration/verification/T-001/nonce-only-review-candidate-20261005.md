# T-001 両 nonce 整合追補候補（2026-10-05）

Status: PREPARATION ONLY — 未採用、正式審査未起動、実装変更なし。

## 範囲と承認の扱い

主担当から本ターンに伝達された現行指示は、追加レビュー・限定修正を
包括承認内として進め、凍結成果物を上書きせず、両 nonce 要件と設計の
矛盾を最小追補で解消する既存候補の正規レビュー準備を行うもの。
これはその準備物であり、独自の人間承認記録、正式予約の代替、
凍結本文の変更許可、レビュー入力 allowlist の例外ではない。

既存 `auto-and-ac004-candidate.md` と `candidate.patch` は保持する。
本候補はそこから両 nonce の要件整合だけを抽出する。Auto/default
モデル採用、モデル選択ガードの除去、Gemini 利用、追加実装試行、
従来の実行回数リセットは含めない。既存候補全体を適用してはならない。

## 解消対象と採用時の優先関係案

- `requirements.md:293-296` AC-004 は最終 Copilot 状態が両 upstream
  contribution に依存することを要求する。この要求は変更しない。
- `design.md:338-343` の nonce2 単独 hash と両 contribution の主張、
  `tasks.md:216-217,257` の nonce 再利用表現を、下記の意味に限定して
  追補する案とする。`tasks.md:291-293` の両 contribution Done When は
  弱めない。現段階で本候補に canonical 文書への優先権はない。
- 採用後に必要な意味は、Copilot が handoff-01 の token（nonce1）と
  handoff-02 の comment（nonce2）を各ファイルから読み、UTF-8、末尾改行なしの
  `COPILOT-CONSUMED:<nonce1>:<nonce2>` を既存 output.txt に生成すること。
  generated-file-hash はこの exact bytes の SHA-256 と一致しなければならない。
- nonce1 と nonce2 は独立生成し、どちらか一方だけの変更で期待 hash が
  変わることを個別に検証する。producer/consumer 間の読み取り連鎖は保持する。
- Bash / PowerShell の pseudo oracle、live oracle、Copilot prompt、
  既存自己検査を揃える。trace schema、新規 output file、モデル選択動作は変更しない。

## 正式化に残る契約条件

`impl-review-loop/SKILL.md:336-387` の provenance re-review は既存証跡の
再束縛であり、凍結内容変更の許可ではない。同 skill:308-311 は task 存在下の
Pending reset を禁止する。したがって旧状態を reset して進めない。

`plugins/sdd-review-loop/scripts/impl-review-precheck.sh:21` は canonical
design.md を使用する。`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:326-346`
の impl/task 入力許可集合には本 verification 追補が含まれず、同:887-889 は
role-unlisted path を拒否する。追補を単に manifest に追加したり、canonical
design.md と別の候補を取り替えたり、本文を prompt に転記してはならない。

次の最小工程は「凍結本文保持・本追補 path/hash・限定 precedence・両 reviewer
への同一入力・変更部分への実質審査」を扱う正規追補採用契約を確定すること。
現行の caller read-policy 修復は読取可否の修復であり、この入力 admission を
自動で追加しない。今回確認範囲ではその契約を実装する Approved task / 適用済み
consumer を特定できていない。これは包括承認の再要求ではなく、実行契約の不足。
新契約コードの実装や保護対象適用は本準備に含めない。

契約が整い current hash / 既存履歴 / 正規次 attempt が検証された後、fresh
identity、逐次予約、完全入力配送で独立 impl review と必要な task provenance
review を行う。その後に限り nonce-only 実装へ進む。旧 fixture green は新しい
正式 PASS / live E2E の代用にしない。

## 現在の読取 SHA-256 pins

| Path | SHA-256 |
|---|---|
| `specs/epic-196-a8-integration/requirements.md` | `f841443d88b4f58fdbb9e32ee050edf8395f3767ebbc08cc2d9d6be76cb3ac44` |
| `specs/epic-196-a8-integration/design.md` | `14862a80a6f44b49dbf7e1393af66c82c0434bf1109b248e7ff9b4b695fcd18c` |
| `specs/epic-196-a8-integration/tasks.md` | `8c17b0f6b2fa299d23ce6e892a8e80a841ac4ab68d613c84d6c36fe09bbcde66` |
| `specs/epic-196-a8-integration/verification/T-001/auto-and-ac004-candidate.md` | `050239209067242ca8a5a9a10164f6b58c82ca3098fe3e4ae5632f7dbc4b0ba6` |
| `specs/epic-196-a8-integration/verification/T-001/candidate.patch` | `76158fa2592d5bc6d62263d34f7561da9f142d56fcce31546d4a72b860cc9f42` |

上記は本準備時の実測。正式採用時に再検証する。旧 frozen evidence、ledger、
予約、status、Approval、Done、実装コードを変更していない。新しいテスト結果や
独立レビュー結果は発行していない。
