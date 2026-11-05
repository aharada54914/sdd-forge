# Order filter sample

Run npm test against the provisioned private PostgreSQL fixture. The filter minimum is inclusive.

既存npm testは毎回、実行sandboxのnetwork namespace内に新規DBを作成し、127.0.0.1だけで受入を確認し所有PIDを停止する。外部domainはnetwork proxyの既定deny、別namespaceからDBへ到達できない。db/runtime.jsonは固定構成、実資源IDと接続先・データ不変・cleanup結果はreports/db-checkへ保存。Unix socket制限を解除しない。
