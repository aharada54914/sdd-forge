# T-001 設定と診断の再検証（2026-11-26）

macOS の隔離クローンで、同じ `tests/v2-sdd-doctor.test.mjs` を修正前後の実装に対して `node --test tests/v2-sdd-doctor.test.mjs` で実行した。テストファイルは修正コミットから取得し、SHA-256 は `19cdb0115daddaea79b9e80a6256bb4ff98555ff88dd4f9732303d33a72fc743`。

| 検証 | 修正前 | 修正後 |
|---|---|---|
| ネストしたフロー形式の YAML 設定 | 有効にした形式検証が無効になった | 4つの拡張の設定を保持し、引用符内にカンマを含む JAR パスとアダプタ配列を読み取った |
| チェッカーの JAR パス型 | 数値 `123` を渡しても検証が終了値 0 を返した | TLC・Apalache 双方で検証がキーのパスを含む JSON と終了値 2 を返し、doctor は NG の JSON と終了値 1 を返した |
| Apalache の有無 | テストで Java と JAR の両方を用意した条件でも `unavailable` になった | テスト内で Java の応答を固定し、一時 JAR の有無と組み合わせた3条件が通った。別途、実 JRE でも JAR の有無で `available` と `unavailable` を確認した |

- 修正前 `d423236fb4452a4dbb5f4ab147ff801c5e18d620` は終了値 1、6件成功、3件失敗、スキップ0件。[Red 出力](red.txt)
- 修正後 `8a3c91857ebbcdaa0688da1ff97a95e54a40e17b` は終了値 0、9件成功、失敗・スキップ0件。[Green 出力](green.txt)

同じ修正で、再生成した配布 MCP の stdio からフロー形式のセキュリティ監査設定を取得し、`enabled=true`、`mode=shadow`、`enabled_adapters=["semgrep"]` を確認した。`v2.1.3` の既存 YAML サンプルは検証終了値 0。形式モデルの source pin を実装に合わせ、固定済みの TLC JAR を使う回帰テストでもベースライン、指定した不変条件の違反、実装トレースの再生を確認した。
