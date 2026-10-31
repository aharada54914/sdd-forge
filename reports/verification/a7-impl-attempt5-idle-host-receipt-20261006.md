# A7 impl attempt 5 idle host receipt — blocked before reservation

Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`
HEAD: `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`

通常契約の実host確認を1回実施。正式レビューの判定ではない。prompt未配送、予約未実施、reviewer出力未作成。A22専用nonTTY例外は使用していない。

## 実行と観測

owner cwd、login=falseで実行:

```sh
rtk proxy claude --bg --model sonnet --permission-mode dontAsk --tools Read,Grep,Glob,Bash --disallowedTools Write,Edit,NotebookEdit --plugin-dir plugins/sdd-review-loop --agent sdd-review-loop:impl-reviewer-a --name a7-impl-attempt5-reviewer-a-idle
```

exit0、実出力:

```text
warning: no agent named 'sdd-review-loop:impl-reviewer-a' — spawning with default template
backgrounded · a563e04e · a7-impl-attempt5-reviewer-a-idle (idle — send a prompt to start)
  claude agents             list sessions
  claude attach a563e04e    open in this terminal
  claude logs a563e04e      show recent output
  claude stop a563e04e      stop this session
```

`rtk proxy claude agents --json --cwd /Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge` の対象entry:

```json
{"pid":99301,"id":"a563e04e","cwd":"/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge","kind":"background","startedAt":1791257093049,"sessionId":"a563e04e-c991-4570-8d7a-df9bc5a89e87","name":"a7-impl-attempt5-reviewer-a-idle","status":"idle","state":"blocked"}
```

`rtk proxy claude logs a563e04e` はClaude Code v2.1.290、Sonnet 5.5、役割名表示と空prompt、dontAsk表示を返した。一方で起動stdoutがdefault templateへのfallbackを明示しているため、表示名だけでは正しい独立reviewer roleの読込・受理を確認したことにしない。hook設定のunknown-key警告も表示されたが、これをrole解決失敗の根因と断定しない。

## 停止点と不足条件

実session IDの存在は確認できたが、要求roleの受理は未確認（起動時には明示的にfallback）。通常契約のfallbackなし条件を満たしたと扱えないため、予約前停止。正式入力は送らず、別executor・別起動方式への切替や追加診断も実施しない。次の最小条件は、通常host経路で要求する`impl-reviewer-a` roleがdefault templateへのfallbackなしにロードされたことを立証すること。A/B結果、統合、workflow-stateの新成功は未実施。

終了時読取でidentity-ledger SHA256は `be8e6cb7fd7ddf756106a2ef7efd16810371aa743be4897545f7c3efaacd7bee`、attempt5 precheck SHA256は `ca6e38c657c17627da4ac5e9043fb0c94c40d8062dc6b91a45d2a91685e60bfc`。予約による台帳変更なし。既存Passedヘッダ・古い証跡・保護実装は変更していない。idle contextは未配送のまま保持。
