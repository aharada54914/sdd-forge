# Issue #423 installer evidence scope — 2026-10-05

非正式の差分調査・検証記録。予約、正式判定、task 状態、保護原本は変更していない。

## 結論

旧 build receipt は現在も同一 SHA の T-002 validator/helper が配布され、installed validator の 9 checks が成功した証拠として有効。installer SHA の変更だけを理由に、T-002 ownership boundary 評価の前提として人間に build 再実行を必須要求する根拠はない。前の回答の「現行 installer の build 証明ではない」は正しいが、「したがって評価前に再実行が必要」と解釈してはならない。

最新 checkout 全体を新 installer で再配布した receipt、native registration、正式 quality-gate、CI、Done はこの既存ログでは証明できない。必要性は実際の評価・配送契約に限定する。

## 現物照合と差分

- `git show HEAD:install.sh | shasum -a 256` 相当の rtk 経由読取で、旧ログと同じ `9b43d5eaf93a9cefffc562a3108f43ab2bc2a64c675a710ec5c59250f7abe719` を再確認。
- `git diff -- install.sh` は line 710 の EXIT trap 一行のみ。非ゼロ exit の場合だけ rollback を実行し、cleanup と元の exit status は保持する。
- `install.sh:967-986` の選択・コピー、`:1007-1010` の配置は変更なし。成功時は `:1022` で registration phase に入り、`:1063-1070` で backup を処理して rollback を解除する。旧 `rollback` の registration branch (`:687-695`) は成功時にも誤った failure message を出したが配置済みツリーを保持した。今回の修正は成功時のこの呼出しを抑制する。
- 現行 installer: `87bcebfeb53f6521f03cc62f2bc760902bd7af2d28ea24ffb2d29662b71bad50`。
- 現行 test: `648d093acbda64a1c3dff445fb2a97f537688a6f6426a64bd2701e36ff444bf4`。
- 現行 validator: `4794ef81888e83a4d45f37a680ab65436cd1ca97e1d01c59acf8a22dae898788`、helper: `ea08dbd141b24f4685fd9211b4454d782e5ea80e081e0a59d89ee7f7fe5282ea`。いずれも旧 receipt の installed-byte pins と一致。
- 旧 raw log `reports/verification/issue423-t002-build-human.log.h2HQDSYl` は SHA `450aba84af3339e078ec3f9f6e69d57928b1177fa24705edc294ddaf964a2fe8` のまま。内容や誤表示を改変していない。

## 検証と限界

今回の新規実行は owner cwd / login=false / rtk 経由の差分・SHA 読取と `bash -n install.sh tests/install.tests.sh` (exit 0)。この bash 呼出しが構文検査した主ファイルは install.sh であり、test suite の新規実行を意味しない。

既存 `reports/verification/issue423-t002-installer-impact-20261004.md` および `issue423-current-installer-recheck-20261004.md` は現行 installer/test SHA で 43 passed / 0 failed を記録。今回は両 SHA の一致を再確認したが、無目的な同一 green suite の再実行はしていない。既存記録には成功 FilesOnly の誤表示抑制、lock cleanup、実際の registration failure 時の警告・新ツリー保持が含まれる。fixtures は HEAD payload ベースであり、dirty checkout 全体の再配布 receipt とは区別する。

`specs/sdd-domain-multitarget/verification/T-002/qg-prep-20261003/python-toolchain-evidence.md:39-48` は assembly operation の実 PreToolUse 拒否を保持する。現行 runner `reports/verification/issue423-t002-build-human-run.sh:2` は human-only。今回 runner、同等 assembly、代替 executor は一切実行していない。

独立 evaluator にこの差分調査や既存 installer regression を提示する場合も、正規の新しい Post-Fix Artifacts 宣言と invocation への exact path/hash admission が必要。既存 manifest、予約、verdict を書換えて代用しない。manifest-binding 未適用など他の admission 条件は別途残る。
