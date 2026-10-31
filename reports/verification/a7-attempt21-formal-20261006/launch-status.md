# A21 launch status

2026-10-06。正式review outputはまだ未採用。

主担当は実approval audit全文とcontractのauthority/input/failed_turn/history dispositionおよび実precheckを独立確認し、実会話承認・scopeとの一致を確認した。その後主担当がread-only fresh helperを再実行したところ、A21が既に存在するため `only the next attempt may be opened` でexit 1。これはnext-attempt制約による拒否で状態変更なし。再試行しない。

既存未予約transport diagnostic `cfb4e9a5-4cdb-44a9-abee-ba0ccf0f8e78` のnative SHA256 `b689a96b68e6c7cb41d962ded57f08450e57e60199690cb6e5512ded33d48c50`、prompt全1259byte一致、text user1件、ledger未予約を現物再検証した。既存collision exit1の実観測は `a7-attempt18-recovery-candidate-20261005/unreserved-transport-result-20261005.md` に保持。診断IDはreviewerへ再利用しない。

A21 reviewer Aは新規caller UUID `c933b018-5af0-4c78-b3ba-9a2d14c9d134`。通常manifest5入力を現在hashで作成、preflight `PREFLIGHT_OK` とcaller-proposal（host acceptanceではない）を予約前保存した。通常validatorで1回のみreserve、sequence1210、record SHA256 `aa797603f30b209abd3a9fdf25ec4fccc7b526c7b504c3848552b7407fe30cdb`。

`launch-reviewer-a.py` が一度限りnon-TTY Sonnet配送中。role本文とexpected_promptは適用済み原本からそのまま取得。書込みtool禁止、hash-only Bash許可、既存output/nativeなら拒否。未来launchにcanonical JSON shapeの `--json-schema` を指定した。適用済skillはこの追加引数を禁じるclosed allowlistではなく、既定の `-p`/`--session-id`/json wrapperとfull stdin prompt/同一identity/raw result要件を維持する。別 `structured_output` の代替採用やfence変換は禁止。CLI成功でもpostflight・通常schema/manifest validator成功まではreviewer outputにしない。

Bは未予約・未起動。正式verdict・stage statusの変更なし。

## 終了結果

CLIはexit 0で終了したが、通常postflightは `validate-nontty-spec-launch.py:196` の `json.loads(raw)` で `JSONDecodeError: Expecting value: line 1 column 1 (char 0)`、launch driverはexit 1。raw resultは日本語前置きとMarkdown fenceを含み、canonical raw JSONではない。`structured_output`キーもない。実拒否に従い停止した。上記「配送中」は過去の開始記録であり現在は終了済み。

予約sequence1210と元証跡を保持し、再配送・fence変換・reviewer-a.json採用・B予約を行わない。詳細は同ディレクトリ `transport-failure-analysis.md`。旧候補PASSやCLI成功を正式review成立に転用しない。
