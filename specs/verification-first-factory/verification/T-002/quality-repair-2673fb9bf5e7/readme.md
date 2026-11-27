# T-002 第3回修正の独立検証資料

実装コミットは `2673fb9bf5e7ef55557f4fc631be676e1bb43b0c`、RED コミットは `aac66a7a2`。RED では README の説明文とソースの引用例を違反と判定し、未追跡のソース2ファイルに追加した抑止コメントを見落とした。修正後の公開 CLI テストは25件、TLC を使う隣接3スイートは合計68件成功した。両方ともスキップは0件だった。

| 統合ゲートの記録 | 入力変更 | 保護検査 | 統合判定と終了コード |
|---|---|---|---|
| execution.json | 変更なし | CLEAN、対象0ファイル | PASS、0 |
| integrated-positive.json | README に抑止指示の意味を説明する一文を追加 | CLEAN、対象1ファイル | PASS、0 |
| integrated-directive.json | テストの末尾に抑止指示の行コメントを追加 | LINT_DISABLE_ADDED、OQ-002 | FAIL、1 |
| integrated-negative.json | 保護対象の廃止承認マニフェストに改行を追加 | PROTECTED_PATH_MODIFIED、OQ-001 | FAIL、1 |

4件ともテスト対象のコミットを隔離して公開の run-sdd-gate.mjs を実行し、--anti-tamper を指定した。specDrift は全件 CLEAN。個別 CLI の違反終了コード4は回帰テストが確認した。integration.json に引数と観測結果を、directive-question.json と negative-question.json に実際の OQ を収めた。

runtime.json は公開ゲート、check-traceability.mjs、ベースライン記録器の推移的なローカル import と、回帰テストおよびルール関連のファイルを列挙する。これらのファイルだけを空のディレクトリにコピーして node --test tests/v2-spec-drift.test.mjs を実行したところ、25件すべてが通過した。結果は restricted-replay.log にある。

tested-tasks.md は実装コミットのタスク台帳である。admission.json は入場時の正本の tasks.md も記録する。差分がある場合は current-task-status.diff に収めている。previous-findings.md は直前の NEEDS_WORK 記録である。
