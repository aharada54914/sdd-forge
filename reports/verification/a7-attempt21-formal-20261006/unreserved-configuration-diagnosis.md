# 未予約構成差診断 — custom agent の tool scope

2026-10-06。正式入力・予約・判定を使用しない2回の診断。A21の元証跡は変更せず、A22は作成しない。debugger手順で構成差を切り分けた。製品コードの修正なし。

## 結論

custom agent の明示的 `tools: [Read,Grep,Glob,Bash]` が StructuredOutput を実効tool集合から除外する。CLIはschemaが指定されても実効tool集合にStructuredOutputがなければ強制を有効化しない。このため `--json-schema` 単独追加は不十分だった。

CLI全体の `--tools Read,Grep,Glob,Bash` および `--allowedTools` のhash-only Bash制約だけでは、この不具合は再現しない。default agentでは同じCLI tool/permission設定でStructuredOutputが利用できた。

## 制御した実験

driver: `unreserved-configuration-probe.py`。各argv・wrapper・stderr・exitは `default-readonly-tools.*` / `custom-readonly-tools.*` に排他的に保存。二度の診断のみ実行、再試行なし。

共通: CLI2.1.290 / claude-sonnet-5-5、既存probeと完全同一の単一field schema、同一promptを位置引数で配送。promptは「Transport diagnostic only, not a review. Return the structured object with probe equal to ok. Do not read or change any files.」。通常設定・hooks・permissionを維持し、Write/Edit/NotebookEdit禁止。正式spec内容やrole本文は渡さない。

|条件|default-readonly-tools|custom-readonly-tools|
|---|---|---|
|session|2de9ed5c-9aaf-4207-8767-363fcb74661b|7a7a2b2b-6400-4cdf-82c6-79f6ea61d531|
|差|custom agentなし|同じ診断promptのcustom agentを選択、agent側toolsを4種に固定|
|exit / is_error|0 / false|0 / false|
|native tools|StructuredOutput 1回|tool呼出しなし|
|permission_denials|なし|なし|
|result|`{"probe":"ok"}`|JSONの後に「StructuredOutput ツールがこのセッションでは利用できなかったため…」という説明|
|structured_output|`{"probe":"ok"}`|キー欠落|

双方に正式入力のRead/Grep/Glob/Bash呼出しなし。native transcriptは通常のClaude projectログ配下にsession ID名で保持。旧probe（default agent、`--tools ''`）もStructuredOutputが成功していたため、CLI tools指定の有無のみではなくcustom agent側の明示tool scopeが決定的な差となる。

## ローカルCLI実装のread-only根拠

実体: `/Users/jrmag/.local/share/claude/versions/2.1.290` (Mach-O)、SHA-256 `b8412a3826b2dc8ecb1c0605970c28dea28355de5faa740407dd881acdd40237`。埋込みJavaScriptをread-only検索した。バイナリなので行番号ではなくbyte offsetで特定する。

- offset197530871 `function pA(e,s,n=!1...)`: agentの `tools:A` を取得。Aが未指定/wildcardなら全resolved集合、明示リストなら `for(let J of A)` で選択した集合 `resolvedTools:x` だけを返す。
- offset206697976 `let cr=pA(vt,i3(vt,x,...),!1,!0);x=cr.resolvedTools`：main custom agentの実効tool集合をその解決結果に絞る。
- offset206529886 `requiresStructuredOutput:jo!==void 0&&nr.some((Fe)=>Ot(Fe,Qi))`：schemaありだけでなく実効toolsにQi (=StructuredOutput)が存在する場合だけ強制する。

これは単なるモデルの自己申告ではなく、対照実験・tool呼出し記録・tool選択/強制条件の三点が一致する原因特定である。

## 最小修正候補（未適用・未検証）

将来launcherが生成するcustom agentの `tools` に `StructuredOutput` を明示追加し、Read/Grep/Glob/Bashの制約、Write/Edit/NotebookEdit禁止、通常hooks、原本role本文、完全first-turn、raw-result postflightは変更しない。wildcard化やagent側tools制約の撤去は不要。これはCLIの出力生成用toolの許容候補であり、raw応答の変換や別field採用ではない。

当該修正候補でのGREENは未実施（承認された最大2診断を消費済み）。正式再試行を増やす前に、承認された別の未予約診断でこの1要素追加を検証し、full schemaでもraw resultが受理されることを確認する必要がある。診断の成功は正式reviewでもA21修復でもない。
