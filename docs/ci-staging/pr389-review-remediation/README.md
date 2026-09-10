# PR #389: A-1 / A-2 / A-3 人手適用パッケージ

Status: Staged, not applied. Independent package review pending. This is not a quality-gate PASS or merge approval.

## 適用対象と確認値

対象作業ツリーは `/Users/jrmag/.local/share/sdd-forge-consolidation-wave1-20260905` だけです。`/Users/jrmag/sdd-forge` の main や別の所有者の作業ツリーには適用しません。

- HEAD: `c5d3230714dd064b3e5a48ac79fb179f45ae3a76`
- Tree: `e677808be1a9df76573978a853626c86c180b996`
- 適用前の作業ツリー: clean
- Patch SHA-256: `778cb1f58ac4d4be66551ee60b62af35c4cd8732e21b0b67e915656a544f4e33`
- 適用前 `check-contract.ps1` SHA-256: `10a461f75d62829ff6c86680aa2afa764247b23d49f51db08cd8a8d76c6383ff`
- 適用前 `prepare-panelist-input.sh` SHA-256: `c86dcf9785087b9d0410b2dbf2fd54a991cc630d303c4df038c067e1e1155084`

差分は2ファイル、12行追加・5行削除です。PowerShell のパス解決と大小文字判定、SH の新設履歴スキャン用一時ファイルだけを変更します。SH の既存 `_vdc_blob` は対象外です。終了・処理済みエラー時の一時ファイル削除を扱い、プロセス強制終了時の削除は保証しません。git show / fingerprint / allocation の失敗時には古いアンカーへフォールバックしません。

## 人手で行う適用

以下はユーザー本人のターミナルで行う手順です。エージェント用の別経路・保護解除手順ではありません。HEAD、clean 状態、パッチのダイジェストを上記と照合してください。不一致なら適用せず再レビューします。

```bash
rtk proxy git -C /Users/jrmag/.local/share/sdd-forge-consolidation-wave1-20260905 rev-parse HEAD
rtk proxy git -C /Users/jrmag/.local/share/sdd-forge-consolidation-wave1-20260905 status --short
rtk proxy shasum -a 256 /Users/jrmag/sdd-forge/docs/ci-staging/pr389-review-remediation/remediation.patch
rtk proxy git -C /Users/jrmag/.local/share/sdd-forge-consolidation-wave1-20260905 apply --check /Users/jrmag/sdd-forge/docs/ci-staging/pr389-review-remediation/remediation.patch
rtk proxy git -C /Users/jrmag/.local/share/sdd-forge-consolidation-wave1-20260905 apply /Users/jrmag/sdd-forge/docs/ci-staging/pr389-review-remediation/remediation.patch
```

最後の適用コマンドはエージェント未実行です。`--check` のみ成功を確認しています。適用後はコミット・push・マージせず、以下のミラー整合と再検証を行います。

## ミラー整合: 自動一括同期は使用しない

計画の同期方法を具体化した追記です。`scripts/human_copy_mirrors.py:145-159` はミラーが `origin/main` と一致する場合だけ STALE と判定します。今回のミラーは PR #389 の WFI 変更を既に含み、main と異なるため、新たな修正後は PENDING と判定され得ます。一括同期に任せたり、既存の15件の PENDING を上書きしたりしません。

同じ対象作業ツリーの中で、人手により修正後の `plugins/sdd-quality-loop/scripts/check-contract.ps1` を次の2ファイルだけへバイト一致でコピーしてください。

1. `specs/epic-136-phase2-gates/human-copy/plugins/sdd-quality-loop/scripts/check-contract.ps1`
2. `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/scripts/check-contract.ps1`

その実ファイルの SHA-256 を計算し、各 `human-copy/MANIFEST.sha256` の `plugins/sdd-quality-loop/scripts/check-contract.ps1` の行だけ更新します。他の行、順序、Python ミラー、15件の別作業の PENDING は保持します。適用後に期待される変更は、ライブ2ファイル、PSミラー2ファイル、マニフェスト2ファイルの計6ファイルです。

修正後の予測ハッシュをメモリ上で求める読み取り専用コマンドも保護ゲートに拒否されたため、その処理を別ツールで再試行していません。修正後ハッシュを未検証の値で埋めていません。

## 再現結果と適用後の検証

修正前の正確な HEAD に対して次を実行済みです。

| Harness | 修正前の結果 |
|---|---|
| `test_contract_location.py` | 4件中2件 PASS、A-1 / A-3 の2件が意図した FAIL。絶対パスの実ゲートは成功、相対パスは10件の証跡不足。小文字と specs 外の比較は成功。 |
| `test_anchor_temp.py` | 5件すべて意図した FAIL。0644、一時ディレクトリ内のテスト用シンボリックリンク先の上書き、3種類のエラーでアンカー受容を再現。 |

これは修正前の RED 証拠です。修正後の GREEN は未実行です。PowerShell の A-1 は実ゲート、A-3 は変更していない実装関数の抽出比較です。SH は変更していない実装関数を git / fingerprint のテスト代替と組み合わせた単体テストであり、完全な品質ゲートではありません。実リポジトリ内の証跡や製品コードは変更していません。

```bash
rtk proxy python3 /Users/jrmag/sdd-forge/docs/ci-staging/pr389-review-remediation/test_contract_location.py --repo /Users/jrmag/.local/share/sdd-forge-consolidation-wave1-20260905 -v
rtk proxy python3 /Users/jrmag/sdd-forge/docs/ci-staging/pr389-review-remediation/test_anchor_temp.py --repo /Users/jrmag/.local/share/sdd-forge-consolidation-wave1-20260905 -v
```

適用後は上記9件に加え、WFI-058/059のSH/PS、PS prepare-panelist、contract golden の正負ケース、ミラー鮮度、リポジトリ検証、独立Astraレビュー、必須CIを再実行します。SH prepare-panelist の既存183 PASS / 3 FAILは解消済みと扱いません。今回のパッチで MCP ファイルは変更しませんが、既存446件の成功は適用前のツリーに紐づく記録です。

## テストの識別

- `test_contract_location.py`: `52b54298c5eae72b3a8eb55c9d2a9687dedebe3755f453590475c863064a32dd`
- `test_anchor_temp.py`: `2b8304bc30046721bf199757a3424ff68679446814e96586fa3b1a70d86317e1`

初期の委譲テスト案は実際のA-3実装を検証しておらず、レビューで不採用にしました。その案と説明ファイルだけを削除・置換済みで、上記結果には含めていません。ユーザー由来のファイルは削除していません。
