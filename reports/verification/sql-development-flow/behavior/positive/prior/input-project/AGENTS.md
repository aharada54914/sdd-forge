# Query sample

spec_profile: lite

This project uses SDD Forge. The active feature is specs/order-filter. Modify only the task Scope. Existing acceptance checks and fixtures are the supplied contract.

## Active Spec Directories
- specs/order-filter

## Project checks
- test: npm run test
- No lint, typecheck or build commands: this is one SQL SELECT query exercised through PostgreSQL psql and Python standard-library acceptance checks.

## Database
The owned disposable PostgreSQL instance and read-only connection are described in db/runtime.json. Only that per-check namespace loopback TCP is authorized. Schema baseline-v1 is fixture-owned and unchanged; no schema migration is requested. Read specs/order-filter/design.md for the full contract.

既存npm testは毎回、実行sandboxのnetwork namespace内に新規DBを作成し、127.0.0.1だけで受入を確認し所有PIDを停止する。外部domainはnetwork proxyの既定deny、別namespaceからDBへ到達できない。db/runtime.jsonは固定構成、実資源IDと接続先・データ不変・cleanup結果はreports/db-checkへ保存。Unix socket制限を解除しない。
