# SDD AWS Cloud (Gemini CLI)

Gemini CLI 向けの AWS CDK / CloudFormation オーケストレーション拡張です。公開コマンドは `/sdd-aws-cloud:orchestrate`（`skills/orchestrate/SKILL.md`）です。ローカルでは `route` / `plan` / `validate` のみ実行でき、`prepare` / `apply` は保護された CI 境界で制御されます。
