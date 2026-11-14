# 要件: order-filter

REQ-001: 注文金額一覧のminimum下限を包含比較に修正する。現状は境界と同額の行が欠落する。
REQ-002: 整数minimumを値として渡し、id・amount_cents・labelを返す。amount_cents降順、同額はid昇順。Unicodeを保持する。
REQ-003: 該当なしは空集合、minimum 0と負数は既存非負全行を返す。不正な整数は呼出側でSQL実行前に拒否する。
REQ-004: 提供済み4合成行・キー・値・schema・権限を変更しない。

対象は新規作成済みの専用PostgreSQL 18.6、ローカルper-check namespace loopback TCPのみ、共有利用者なし。性能改善・移行・スキーマ変更・クラウド操作は対象外。検証コマンドはnpm test。実測結果と対象を既存実装報告・品質execution.jsonに残す。

既存npm testは毎回、実行sandboxのnetwork namespace内に新規DBを作成し、127.0.0.1だけで受入を確認し所有PIDを停止する。外部domainはnetwork proxyの既定deny、別namespaceからDBへ到達できない。db/runtime.jsonは固定構成、実資源IDと接続先・データ不変・cleanup結果はreports/db-checkへ保存。Unix socket制限を解除しない。
