# 最小tool追加の未予約GREEN

2026-10-06。追加承認された未予約診断を1回のみ実行。正式入力・予約・A22作成・保護編集はない。

`unreserved-configuration-green.py` は前回custom診断の保存済みargvを読み、`--agents`値の `transport-probe.tools` に `StructuredOutput` だけを追加した。argv差はindex22のagent JSONだけ。CLI permission modeを追加・変更せず、元の通常sandbox/settings/denyとRead/Grep/Glob/hash-only Bash許可を維持した（元argvに明示 `--permission-mode dontAsk` はなく、今回も追加していない）。

## 実結果

- session `cfb6644b-ef1e-4add-a700-2719c2e2afdd`、CLI2.1.290 / claude-sonnet-5-5。
- CLI exit 0 / is_error false / permission_denials空。
- raw resultは厳密に `{"probe":"ok"}`。前後説明やfenceなし。
- structured_outputは存在し、object `{"probe":"ok"}`。raw JSON解析結果とともに、要求した単一field・enum・additionalProperties falseのschemaに完全一致。
- native tool useはStructuredOutput 1回のみ。Read等の正式入力アクセスなし。
- wrapper SHA256 `038d4340f012e02f9bf7ce3adcf73fde87b48933d717b0e56795cec32c1e3f7f`。
- native SHA256 `f09fcb4ce07a36cf6784c1c14c60a6b15c96c8af6325d56c8b00f078c8804ec7`。

保存: `custom-structured-output-green.{command.json,wrapper.json,stderr.txt,exit.txt,validation.json}`。診断成功は正式reviewの成功ではない。full reviewer schemaでのGREENは未実施。

## 将来の変更点と契約境界

1. 非保護launcherの候補差分は `launch-reviewer-a.py:18` の生成custom roleconfig `tools` にStructuredOutputを1項目追加すること。将来Bを生成する場合も同じscope設定が必要。A21の保存済みroleconfig/launcher/出力を改変・再実行せず、新規の事前承認済みlaunch成果物へ反映する。
2. `spec-review-loop/SKILL.md:253-255,273-285` の通常hooks/deny/read-only/原本role/完全stdin prompt/raw-result postflight/完全output検証は維持する。StructuredOutputは出力生成用で書込みtoolではなく、この許容追加のためにraw-result consumerや保護コードを緩和する必要はない。schema追加がrole本文の内容や判定結果を代作するものではないことも維持する。
3. A21 admission contractはA20失敗を束縛する既存の不変記録。これをA21失敗に書換えてはならない。新たな正式attemptが別途認められた場合のみ、A21の実native/予約/8-file inventory/現在入力を束縛した新契約・auditと通常precheckが必要。
4. ただし現行 `failed-last-attempt.py:64-66` はfailed_final_roundを2または3に限定する。A21はround1なのでA21失敗をこのlater-round modeに置換して進めることはできない。`fresh-review-recovery.py:306-411` のround1 transport inventory経路が今回の実証跡とauthorityを過不足なく扱えるかは、別の事前契約確認が必要。新attemptの実行や保護契約変更が不要だと、この診断だけでは判断しない。

以上で追加1診断を完了。正式再試行は停止したまま。
