Task ID: T-010
Feature: verification-first-factory
Run ID: eacea7f4-1631-47b4-9ac1-4f909640031a
VERDICT: NEEDS_WORK
Critical: 0
Major: 2
Minor: 0

- **VERDICT**: NEEDS_WORK

# Independent quality gate for T-010

Evaluators verified all 74 admitted hashes at `e2f726ab4808eb01afdd7d289bc34669e7940685`. G1/G2/G5 were reviewed by `eacea7f4-1631-47b4-9ac1-4f909640031a` (ledger 1249) and G3/G4 by `81caccad-8429-4224-a062-9f8c39678325` (ledger 1250). Machine execution `121d4a29-a4cb-4f7c-bc60-2c90b729090c` returned PASS.

## 判定の根拠

G1 と G3 では AC-013 の互換性を確認した。カタログに350スイート、local-posix に195スイートがある。今回の機械ゲート20項目は成功した。過去の全体実行は二つの作業スナップショットに分かれ、後半13スイートには9失敗がある。旧設定での8種の終了コードとMCPの73成功も別のリビジョンの測定である。同一SHAで195スイートすべてが成功したレシートがなく、Major 1件を記録した。

G1 と G4 では SELF-AC-005 と NFR-004 を照合した。異なる62差分のアーティファクトは Gitleaks、Semgrep ともに所見0件で、誤検知率の分母が得られていない。以前のローカル3対の増分は +1.691～2.356秒、PR全体の単一対は +33秒、Guardrails ジョブ単独は +125秒だった。今回の統合版で両予算を実証する比較はない。Shadow を維持し、strict の条件を Major 1件として記録した。カテゴリ2のスイート廃止は0件。機械ゲートの securityGate、formalGate、rebuildDifferential は今回スキップされている。

G2 の仕様ドリフトは CLEAN。タスク記載の正規パスに対し、機械ゲートは変更範囲の警告を31件出した。所有者が個別に承認した v2 契約への移植と旧アサーション3件の退役を確認した。重大度3フィールドを維持し、Core の CLI が critical と major および未申告の仕様変更を拒否し、minor とクリーンな仕様を受理した。CI の全体検査順を逆にする対照は失敗した。G5 は対象差分に業務ドメインや UI 規約の変更がなく適用外。

両評価者は入力各74件のハッシュを独立照合した。同じ原因を重複計上していない。未解決は RT-20261126-011 と RT-20261126-012。タスク状態は Implementation Complete。
