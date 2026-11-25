# T-001 AC-012 設定済みアダプター診断

Run ID: verification-first-factory-T-001-repair-20261126
Task Attempt Count: 2

## 修正と検証

- AC-012。実際に有効な formal checker と security adapter ごとに、名前、導入状況、判定条件を出力する。TLC・Apalache は Java と設定 JAR、外部セキュリティツールは固定引数によるバージョン照会、内蔵アダプターは内蔵実装の有無を示す。
- Red。設定した6個のアダプターを照合するテストで実際の一覧が `[undefined]` となり1件失敗（終了1）。
- Green。`node --test tests/v2-sdd-doctor.test.mjs` で7件成功、失敗／スキップ0。Apalache、内蔵、Semgrep、TruffleHog、CodeQL、Socket の名前と各診断の対応を検証した。
