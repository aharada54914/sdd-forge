# 既存 legacy/ticket 経路による限定修復への絞り込み

2026-10-06。追加調査記録。v1 を削除・上書きせず、下記判断を優先する。正式 verdict、approval、ticket status、task state の更新ではない。

## 結論の補正

v1 の hash 不一致は事実だが、それを理由にこの修復へ新たな full spec/design/task 計画を要求しない。元機能は既に `specs/workflow-state-registry.json:6-42` の **legacy**。reason は「1.5.0 release commits で review provenance が drift し、再構成せず grandfathered」。`check-workflow-state.sh:1806-1850` は legacy 用状態確認へ分岐する。

実行した最短の既存・読み取り専用診断（owner checkout、rtk、login=false）:

```text
rtk proxy bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature agent-cost-context-isolation
exit: 0
stdout: workflow-state: ok
```

これは既存 legacy 状態検証の成功であり、新 bytes の full-stage provenance、T-003 実装、Windows、品質 gate の PASS ではない。既存 migration を勝手に解除したり registry を変更したりしない。v1 の impl/task provenance-rereview はその経路を選ぶ場合の条件調査であり、今回必須の次手ではない。

## 差分は今回の mode 修復に起因しない

`git log` と `git diff c0ccc0f0 HEAD -- specs/agent-cost-context-isolation/{requirements,design,tasks,traceability}.md` を実行して切り分けた。

- c0ccc0f0 の requirements raw hash は `eb9de975afa29e47ff14cac53f8ee5c8ac617ad4a78b61acf7eba572244a1a21`、design は `7bf2ed2214b1ab84cb16926f5d75eb3e5288128ce1140259b285ef5ea253aa36`。stage 後続記録値と一致する歴史的基準である。
- requirements の本文差分は同 tier・同 cost 時に `fallback_for` 未指定を優先する T-001 routing 仕様。commit ecdade95。design 同箇所も同規則であり、実行 bit の変更ではない。
- tasks は状態遷移と T-005 の独立 reviewer criterion を実際の round-4 identity/report に合わせた2026-08-23の maintainer 適用記録。d0b109ba と本文コメントに由来がある。T-003 の mode 規範変更ではない。
- traceability の差分は REQ 行と task summary 行の状態セル。現行正規化関数は REQ 行の最終セルだけを対象にするため、task summary の状態セルは hash 差として残る。これを今回の機能本文変更と解釈しない。

これらは v4 候補4ファイルに含まれず、本限定修復のために訂正・復元しない。

## 既存 ticket の再利用範囲

`docs/review-tickets/RT-20260821-009.yml` は open、元 T-001 の fallback/registry/ADR・入力宣言・実証再取得が対象。mode builder 修復の器にしない。依存 T-001 の未完了として残す。

`docs/review-tickets/RT-20260821-011.yml` は open、元 T-003 の builder と独立確認・TEST-003 証拠が対象。既存 `expected_fix` は Win32 MoveFileW BOOL、実出力と drifted acceptance input の再 gate、独立確認主張の整理である。`auto_fix_allowed:false` / `requires_human_decision:false`。snapshot mode保持そのものはまだ明記されていない。

最小経路は、親が保持する今回の明示的な限定修復継続承認を、この既存 T-003 ticket の限定 scope 追補（候補4ファイル、mode規範差分、既存Win32/identity/manifest契約を変えない、旧未解決項目を免除しない）に接続すること。新機能や新full計画を作らない。承認されたという記述の出典は実際のユーザー指示とし、本調査から承認を創作しない。追補候補は `formal-addendum-candidate-v1.md` を利用できるが、旧 full re-review 必須との読み方は本v2で置き換える。

`plugins/sdd-quality-loop/skills/fix-by-review-ticket/SKILL.md:11-28` を全読。既存 ticket を超える修復は stop という境界を維持する。scope接続を記録する前に、旧ticketがmode修復を元から要求していたとは扱わない。formal ticket 本文への適用は今回行っていない。

## 次に実行可能な最短コマンドと後続

今すぐ実行可能な nonmutating コマンドは次の既存バッチの再照合。実適用を伴わず、release=falseを変更しない。

```text
cd /Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge
rtk proxy python3 reports/verification/rt002-snapshot-mode-repair-20261006/human-apply-v4-unreleased.py --check-only
```

その後の実適用への最短正規経路は、既存ticketへの限定scope接続記録 → humanバッチ自身の独立確認と隔離適用/拒否/restore試験 → 既存保護適用手順による人の限定適用 → readback → 現行4原本に対する影響回帰/Windows未実施の追跡 → 独立確認 → 元T-003の既存quality-gate。新しいspec/taskループを先行させない。humanバッチのreleaseは現状許可されていないので実適用コマンドは配布しない。

元T-003再gateの具体的な既存入力入口は `reports/quality-gate/20260821T071500Z.md` を `gate_report_declaration` に用いる ticket 指定である。ただし旧 Post-Fix Artifacts の hash を今回候補に再利用しない。実適用後の正規実装報告 Outputs/manifest で新4bytesを結び、`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` とその時点の制限に従い実identityで起動する（この調査では未起動・未予約）。mode修復だけで旧ticket全体や依存T-001を解決済みとせず、only quality-gate may set Done を維持する。

保護原本、legacy registry、installed、正式状態は変更なし。v4独立差分確認は追加検証であり正式PASSではない。planning USD10 は実費でも支出許可でもない。

## 限定scope接続候補の追記（2026-10-06）

`formal-addendum-candidate-v1.md` §8に、主担当が伝達したユーザー原文「全部承認する／追加で何回でもレビュー、限定修正して良い」を出典とする既存RT-20260821-011/T-003への接続候補を記録した。対象は同§2の4ファイルと§3のmode差分のみ。旧Win32/再gate/独立確認項目と依存T-001のRT-20260821-009は未解決のまま免除しない。正式ticket・承認欄・状態・原本は変更していない。バッチの7件隔離回帰と主担当再実行成功は追加証拠だが、RELEASED=Falseと正式判定なしを維持する。
