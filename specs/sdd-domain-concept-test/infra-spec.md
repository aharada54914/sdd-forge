# Infrastructure Specification: sdd-domain-concept-test

Status: Draft

## Deployment Topology / Environments

local agent host → repository内Concept Test skill → feature証跡 → deterministic gate (REQ-001/003)。既存sh/ps1 twinと既存CIで検証する。新service/region/DB/IaC/scaling/SLOはN/A — no change: local repository workflow。

## CI/CD and Supply

既存release surfaceのskill検査と三重manifestを合わせる (REQ-006, AC-013)。Phase0 suiteを回帰実行する。gate twinsを同一fixtureで検証しOS/tool欠如SKIPは報告する。新依存・新外部uploadは要求していない。

## Data / Observability / Rollback

feature側md/jsonをrepositoryの既存履歴運用で保持する。gateは不足・不正をRULE-ID付きで報告する。rollbackは当該追加とconsumer配線を一括で戻し、既存domain/およびfrozen証跡を維持する。costは既存agent実行内、追加service費用なし。

## Open Questions

OQ-002 (repository owner): deterministic gateの正確な実行時点が運用検証をblockする。
