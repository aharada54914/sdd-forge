# A8 T-004 回復契約の現在値・限定回帰（2026-10-05）

Owner: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`

これは非凍結の補助検証記録。正式な実装レポート、独立レビュー、native activation、品質ゲート、Done の証拠ではない。製品コード、凍結文書、承認、台帳は変更していない。

## 現在ハッシュ

`rtk proxy shasum -a 256 -- <明示した8パス>` を owner で実行（login=false、exit 0）。下記は `reports/verification/a8-t004-recovery-v2-pins.json` の after pins と全件一致。同 JSON の現在 SHA-256 は `4e7097cc07e016dc7d185fea807b3ff626ab98a3d56839ef339655e274541a04`。

```text
d0326f3617f0bf6de6ba7f99d7edc2388c79a6731866328133cff7bb1815b722  plugins/sdd-quality-loop/skills/quality-gate/SKILL.md
011f1d9c068e7b2f033f02bbae0fd15cf3a9c9c2c7f409c963fc1d9e941fc09b  plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
e8424eb27598222fe527ffaaa296cd287a4c52f850ed05b91e98023c8c4e7925  plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1
07f7834c17561b3b69093f91b32c7c5d4d655e9bc21bf2ff8bec6322fb02152a  plugins/sdd-review-loop/references/review-context-boundary.md
34eb70012271e5f7f697a0c640fe1a4ce0f547f2ae92569beb5a532cba2e96ca  tests/review-context-boundary.tests.sh
affe11ec4254bc169a0de969e02be484fdca6998bd7a1df34e324925a893d75e  tests/issue311-scratch-isolation.tests.py
24dd3afc8139ae55f04df97ec42da9ae812da829bf28b54baf828591595cd0d0  tests/review-scratch-history.tests.py
7f8d15c2c95aafe4cfa5e812fb2f10c431d775ef0d35aecc72946e932f60c1b9  tests/review-agent-isolation.tests.sh
```

## 保存済み回帰と今回の追加検証

`specs/epic-196-a8-integration/verification/T-004/recovery-validation-20261004/` の readiness とログを照合した。boundary.log は末尾 84 PASS / 0 FAIL、scratch.log は 60 / 0、history.log は 26 / 0。boundary.log の既存出力省略は readiness に記載済みで、今回完全ログを取得したとは扱わない。isolation/reserve の既存結果も確認したが、変更のない対象への不要な再実行はしていない。

既存 readiness / owner continuity に結果が記載されていなかった隣接契約の fixture 回帰を追加実行した。両スイートを全文確認してから実行し、実モデル呼出し、実台帳予約、実 evaluator の書込み canary がないことを確認した。テストは使い捨て fixture を使用する。

| コマンド（owner、login=false） | 結果 |
|---|---|
| `rtk proxy bash tests/task-context-isolation.tests.sh` | exit 0 |
| `rtk proxy pwsh -NoProfile -File tests/task-context-isolation.tests.ps1` | exit 0 |

stdout（それぞれ全出力）:

```text
ok: task context isolation manifests, snapshots, fallback, and selector are deterministic
```

```text
ok: PowerShell task context isolation manifests, snapshots, fallback, and selector are deterministic
```

スイートの現在 SHA-256:

```text
6b12e9ddd97327606d67d28a4e165ce3391afba28cfeaa04d68379f50f77fd9b  tests/task-context-isolation.tests.sh
82641c89fc1b79a3077f18323fd3ac4a7f98aa7dd026e8173c26c9bffd566575  tests/task-context-isolation.tests.ps1
```

macOS 上の fixture 成功であり、Windows 固有分岐の native 実行証明ではない。今回の検証操作に新しい拒否はなかった。

## 最小の残条件

1. 保存済み caller role 本文の proxy-cat 拒否を正規の修復契約で解消すること。拒否された本文を別経路で読み直していない。別 tree の consumer 同期だけでは拒否の解消や guard 製品修復の正式承認を証明しない。
2. 現行入力に束縛した新しい recovery 実装レポートと `task-input-manifest/v1`、正規に観測した新 identity、完全な初回入力配送を揃えること。旧停止 thread、旧 verdict、旧凍結報告は再利用しない。changed-input recovery の追補候補は正式契約として成立するまで代用しない。
3. 上記を主担当で確認するまで native evaluator を起動しない。独立評価、cross-model、evidence bundle、現在 integration head の CI、Done は未完了。

今回追加したものはこの記録のみ。旧成果物と承認状態は保持した。
