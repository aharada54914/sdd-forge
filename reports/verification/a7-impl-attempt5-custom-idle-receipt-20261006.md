# A7 impl attempt 5 custom-agent idle receipt

## 後続読取調査による訂正・child受理確認

下記の初回停止判断を履歴として保持する。追加調査により「通常custom-agentでもroleをロードできない」という解釈は撤回する。警告は親background起動のseed metadata検索から発生し、子のrole受理とは別だった。

実体は `/Users/jrmag/.local/bin/claude` から `/Users/jrmag/.local/share/claude/versions/2.1.290` へのsymlinkで、後者はMach-O arm64（SHA256 `b8412a3826b2dc8ecb1c0605970c28dea28355de5faa740407dd881acdd40237`）。別shell wrapperではない。bundled codeのTnは `let V=x?_z((await KT(s??se(),g)).activeAgents,x):void 0` でcustom JSONを渡さず事前検索し、Vなしで警告する。一方childには `args:[...oe,...Vn(e)]` を渡す。Vnはsession-idのみ除去し--agents/--agentは保持する。childの_sは `xmt(Ce,"flagSettings")` でcustom定義をparseし、`koe(G,[...G.allAgents,..._e])` にmergeして `yr(pe.activeAgents,s)` で再解決する。bg機能もdaemon連携も同CLIの実装であり、外部製品bugとは断定しない。

追加の起動なしで既存childのnative記録を読取確認した:

- `/Users/jrmag/.claude/jobs/ad69addb/state.json` のrespawnFlagsに--agents/--agentを保持。custom定義のpromptは原本role全文と同SHA256 `6d302654a8662e233e038e254548bad68d593cd1181433174f9c950bc6a2b7aa`。tools=Read/Grep/Glob/Bash、disallowedTools=Write/Edit/NotebookEdit、model=sonnet。intentは空、needsはsend a prompt to start。
- child session `ad69addb-98ad-47e4-8179-bc1123a103ed` のnative transcriptはagent-setting=impl-reviewer-a、mode=normal、permission-mode=dontAsk。user/assistant turnは0。hook attachmentは存在するが正式入力未配送。
- 通常`claude logs ad69addb`は@impl-reviewer-a、Sonnet 5.5、dontAsk、空promptを表示。childでroleが未解決ならCLIが返す `--agent ... not found` fatalはない。

以上はchild role受理と未使用実IDの証跡。read-onlyは原本roleのBash読取限定命令、available tools限定、write系denyで維持する。保護設定や信頼設定の変更なし。親指示に従いこのcustom childのみを通常予約・配送候補とし、旧default-template contextは使わない。

前のplugin名前解決失敗を受け、親の指示で通常CLIの明示custom-agent定義を1回試行した。正式レビューではない。

Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`

## 契約と実行

impl-review-loop STEP2とreview-context-boundaryはfresh独立role、file-manifest/read-only/fallback noneと通常予約を要求するが、roleをplugin名前空間でしか指定できないという制限はない。CLI helpは`--agents <json-or-file>`でcustom agentを定義し、`--agent <agent>`でそのsession roleを選択できると明記する。JSONファイル指定はprint限定なので、通常bgにはJSON文字列を渡した。

非保護helper `reports/verification/a7-impl-attempt5-custom-idle-launch.py` は原本role全文をそのままpromptに設定し、tools Read/Grep/Glob/Bash、disallowedTools Write/Edit/NotebookEdit、Sonnet、dontAsk、既存plugin-dirを維持。正式入力・prompt引数は一切渡さない。role本文SHA256: `6d302654a8662e233e038e254548bad68d593cd1181433174f9c950bc6a2b7aa`。

実行: `rtk proxy python3 reports/verification/a7-impl-attempt5-custom-idle-launch.py`（owner cwd、login=false）。exit0、実stdout:

```text
role_sha256=6d302654a8662e233e038e254548bad68d593cd1181433174f9c950bc6a2b7aa
custom_prompt_equals_full_role=true
warning: no agent named 'impl-reviewer-a' — spawning with default template
backgrounded · ad69addb · a7-impl-attempt5-reviewer-a-custom-idle (idle — send a prompt to start)
  claude agents             list sessions
  claude attach ad69addb    open in this terminal
  claude logs ad69addb      show recent output
  claude stop ad69addb      stop this session
```

`claude agents --json --cwd <owner>`で実sessionを確認:

```json
{"pid":93144,"id":"ad69addb","cwd":"/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge","kind":"background","startedAt":1791257231537,"sessionId":"ad69addb-98ad-47e4-8179-bc1123a103ed","name":"a7-impl-attempt5-reviewer-a-custom-idle","status":"idle","state":"blocked"}
```

## 結論と最小不足条件

通常custom-agent指定でも起動時のdefault-template fallback警告が解消しなかった。bg経路がcustom定義を解決できない正確な内部原因は未確定。CLI exit0や実session存在をrole受理と取り違えず、予約前で停止した。二つのdefault-template contextへ正式入力は送っていない。

必要条件は、現行の通常host経路でexact role定義を受理し、fallbackしないfresh contextを得た実証。登録・信頼・契約・保護対象を変更しておらず、A22非TTY例外も転用していない。追加の試行は行わない。原本validator予約、A/Bレビュー、統合は未実施。

終了時ledger SHA256は `be8e6cb7fd7ddf756106a2ef7efd16810371aa743be4897545f7c3efaacd7bee` で前回と一致。保護原本と旧証跡は不変。新たなファイルはこの診断receiptと非保護idle helperだけ。
