# T-001 残AC照合と既存bootstrap回帰 — 2026-10-05

非正式の検証追補。正式レビュー、品質判定、タスク完了認定ではない。testerスキルに従い、成功済み319件を再実行せず、未実行の既存bootstrap回帰に限定した。製品・テスト原本、凍結仕様、予約、承認、タスク状態、既存Gitを変更していない。

## 追加実行

ownerルートで以下を実行。いずれも終了0。実行中sessionはない。完全stdoutは同ディレクトリの各 `*-20261005.log` に保存した。

| コマンド | 結果 |
|---|---|
| `rtk proxy bash tests/bootstrap-interview-guidance.tests.sh` | 32 PASS / 0 FAIL |
| `rtk proxy bash tests/bootstrap-layer-templates.tests.sh` | 97 PASS / 0 FAIL |
| `rtk proxy bash tests/bootstrap-cross-layer-index.tests.sh` | 54 PASS / 0 FAIL |

合計183件。macOSローカル実行。cross-layerのPowerShell分岐も実行され、SKIP出力はない。Windows native証明ではない。

実行前に全3本を読んだ。interviewは一時カテゴリ一覧のみ、layer-templatesは一時コピーの欠損fixtureのみ、cross-layerはmktempのfixtureとtraceabilityコピーのみを書き、各自削除する。原本は読取りだけ。cross-layerは実Python/PowerShell validatorを呼ぶ。Git操作や外部送信はない。

| 試験原本 | 実行前後で一致したSHA-256 |
|---|---|
| tests/bootstrap-interview-guidance.tests.sh | 1b16b8012e7540c618c6ddde0845e37abc9e86d80a4dd2efbde6ad250eca51bf |
| tests/bootstrap-layer-templates.tests.sh | 5705201ecf666d98c9ce7b354e0d4b0193eff2ceb9635de83b2846080354528b |
| tests/bootstrap-cross-layer-index.tests.sh | 4b7ee150057258c73c10a5e83d787454710a92b827f2c0d7f847864bd2e6bff5 |

これらは質問bank、layer template、cross-layer index/validatorの既存構造回帰であり、Concept Test前後の生成物比較、Concept Test→domain-sync呼出順序、署名不適合時の下流0回を検査しない。suite内TEST番号は既存bootstrap仕様の番号であり、本featureの同番号TEST充足に転用しない。

## 319件で覆われない条件の整理

現行 `tasks.md` raw SHA-256: `8e8c8dafa256652f3ac9adb77b4adf1a54a00bbb59d549bef95970adf6470e02`。
現行 `acceptance-tests.md` SHA-256: `fb0414831b12b78a4c4f6ea32f6f25eb08fcfc9d4f33db9342750bac52eeb8d3`。
319件の実結果・固定入力は `phase0-v2-full-suite-20261005.md` を参照。

| 範囲 | 証拠と残条件 |
|---|---|
| T-001: AC-001–007/014–016の契約・署名validator側 | 319件とは別に、既存Bash113件・PowerShell112件、rollback6件、evidence-map.mdが対応する。現行SHAと保存ログの照合は independent-absence-and-readiness-20261005.md に記録。今回再実行していない。 |
| T-001: 既存型・Phase 0契約回帰 | 既存署名validator型回帰に加え、直前のv2全319件（子v1 suite含む）と今回のbootstrap183件。bootstrap183件は補助証拠であり、署名境界や全AC証明ではない。 |
| TEST-022、TEST-051–078のbootstrap停止/下流0回 | tasks.md:49–57 がT-003 pendingと明記。既存bootstrap3本に当該統合試験はなく、このタスクで新たに実行できる既存試験としては発見していない。T-003の実装・実統合試験が必要。 |
| AC-008/009 | T-002の人間確認・read-only proposal。T-001へ遡及拡張しない。 |
| AC-010/011/017、AC-016のbootstrap E2E | T-003担当。domain不在のconsumer側はT-005にも分担。absence9件は実conformance gateの狭い回帰であり、bootstrap生成物全体のbefore/afterや呼出順序の代替ではない。 |
| AC-012/018、AC-013 | T-004のmanifest/最終mapping、T-006のrelease。T-001完了前に勝手に実装しない。 |

根拠: tasks.md:9 の承認済み移管、:45–61 のT-001所有と除外、:118以降のT-003、:173以降のT-004、:228以降のT-005、:277以降のT-006。acceptance-tests.mdの各AC/TEST表を照合した。

## 最小残条件

1. 現行task-planはtasks.md:9自身が再束縛を要求する。既存Passedヘッダを現行証明としない。本作業では正式経路・予約状態を新たに網羅検証せず、予約もしていない。
2. T-001全実装に対する独立レビューと必要な実装証跡整理は残る。今回のテスト・狭いabsence監査を正式独立レビューに読み替えない。
3. T-001のImplementation Complete前に、全Approved task完了後の独立quality-gateを要求しない（tasks.md:53）。一方、Doneには後続Approved tasksの実装、bootstrap E2E、完全feature mapping、独立quality-gateが必要。現在状態は変更していない。

今回の限定範囲では追加の実行可能な未実行bootstrap suiteは残していない。新たな失敗や実装修復はない。未実装のConcept Test統合試験を既存回帰の成功で埋めない。
