# A21 raw-result 拒否の実観測

2026-10-06。これは起動診断であり、正式review verdictではない。

Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`。A21 round1 reviewer Aを一回のみ配送した。予約UUID `c933b018-5af0-4c78-b3ba-9a2d14c9d134`、sequence1210を保持する。Bは未予約・未起動。

## 結果

- CLI exit 0 / wrapper `subtype: success`, `terminal_reason: completed`, `stop_reason: end_turn`, `is_error: false`。
- 通常postflight (`plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py:196`) の `json.loads(wrapper.result)` が `JSONDecodeError: Expecting value: line 1 column 1 (char 0)`。launch driver exit 1。
- `wrapper.result` は欠落でも空でもなく、「ハッシュ検証と全入力の読み込みは終わりました。」で始まる日本語説明、その後に Markdown JSON fence。`structured_output`キー自体は存在しない。内部に記述されたPASSは採用せず、チェック結果として取り出さない。
- delivery proof / reviewer-a.json は作成されていない。fence除去、別field代替、再配送、予約再利用、B起動はしない。

## 変更せず保持した証跡

Round path: `reports/spec-review/epic-195-a7-compatibility/attempt-21/round-1/`。

|証跡|SHA-256|
|---|---|
|reviewer-a-cli-wrapper.json (9230 bytes)|fbc34a2ca3712730495471a439924812cdc370c0e12b8299ece8c0c7e5b40673|
|reviewer-a-first-turn.txt (4065 bytes)|5848396722ac459e63ee1483f538737de4c0b6e60416e10065783146e9643171|
|reviewer-a-reservation-receipt.txt|1d5d40279f5a78d3bf93cdb0e48ca43f12997255316a2f5214457a0af203791d|
|reviewer-a-role-config.json|d39aa863bc97eb6086e0d8a33f06ca7359563b9ed169123481f2875a87e43b74|
|reviewer-a-cli-stderr.txt (0 bytes)|e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855|

Native: `/Users/jrmag/.claude/projects/-Users-jrmag--codex-worktrees-a7-t005-intake-sdd-forge/c933b018-5af0-4c78-b3ba-9a2d14c9d134.jsonl`、1384465 bytes、SHA-256 `0d8f2b0c66ee6d57081c3ddfb899285e1954b84f352536bc0c48b3fbdc40a0e1`。text user messageは1件。通常postflightはnative_deliveryを通過してからraw解析で拒否した。

## 既存未予約probeとの照合

既存記録 `reports/verification/a7-attempt20-formal-20261006/round2-transport-failure.md:18` のprobe UUID `32cd3fb7-d1d8-41fe-9cae-c654d42e543d` と今回のnative transcriptをread-only比較した。

|条件|未予約probe|A21 reviewer A|
|---|---|---|
|native version|2.1.290|2.1.290|
|native model|claude-sonnet-5-5|claude-sonnet-5-5|
|schema|単一probe field|full reviewer-A object|
|prompt配送|`--`後の位置引数|完全expected_promptをstdin|
|agent|default|custom `--agents`/`--agent`、原本role本文|
|tools|`--tools ''`|Read,Grep,Glob,Bash、roleにも同リスト、hash-only Bash許可|
|native tool use|StructuredOutput 1回|Bash 10 / Read 9 / Grep 2 / Glob 1、StructuredOutputなし|
|wrapper|raw JSON + structured_output|前置き + fenced JSON、structured_output欠落|

今回の正確なargv構築は `launch-reviewer-a.py:48` 以降。CLI `--help`は `--json-schema` をstructured output validationと説明するが、wrapper.resultが必ずcanonical JSONになるとは記していない。現物上、同version/modelでもこの追加引数だけでは現行raw-result契約を満たさなかった。

根因の確定範囲は「正式launch構成でstructured-output機構が使われず、通常テキスト応答が返った」まで。custom agent/tools/roleとschema/prompt配送のどれが機構不使用の原因かは、この2観測だけでは一意に特定できない。`structured_output`だけにcanonical JSONが出たためのconsumer不整合、またはversion差、という説明は今回の観測に合わない。旧probeの成功をfull reviewer構成の事前検証として扱った点が不足していた。

wrapperにはBash permission_denialsが2件（printf pipeによるhash、および複数file一括hash）記録されている。権限を拡張せず元の記録を保持する。これらとschema不使用の因果は未確定。

次の正式attemptは開始しない。必要ならreview入力も予約も使用しない診断でcustom agent/tool構成の差を分離し、既存raw-result契約を満たせることを確認する。原本・履歴・判定を変更せず、診断を正式reviewに数えない。
