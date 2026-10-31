# Frontend Specification: sdd-domain-concept-contract

N/A — no change: the deliverables are a JSON Schema file
(`contracts/domain-contract.v2.schema.json`), a Bash/PowerShell validator
twin pair (`plugins/sdd-domain/scripts/validate-domain-contract.{sh,ps1}`),
and a Pester test suite. There is no browser or frontend application.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| v2 schema file | JSON Schema draft-07 | same as v1 (`contracts/domain-contract.v1.schema.json:2`) | consistency with the v1 declaration style; validated structurally, not by a generic engine (INV-005) | `additionalProperties: false` at every level, matching v1 |
| `validate-domain-contract.sh` | Bash + `python3` stdlib `json` (single invocation) | existing supported runtimes | no jq/ajv dependency (DD-4); python3 is already assumed by this repository's script corpus | fail-closed `set -euo pipefail`; read-only; no network |
| `validate-domain-contract.ps1` | PowerShell `ConvertFrom-Json` + structural walk | PS 5.1-safe | `Test-Json` is PS6+ only (INV-005 precedent in `tests/sdd-domain/contract-schema.Tests.ps1:4-11`) | ASCII / no-BOM / LF; `Get-PropSafe`-style safe accessors under `Set-StrictMode` |
| `contract-v2-schema.Tests.ps1` | Pester (same style as the existing 11 suites in `tests/sdd-domain/`) | existing | fixture corpus inline + mktemp scope (DD-5, INV-006) | not registered in run-all/CI, matching the current suite convention (INV-007, OQ-002) |

## Component Tree, State Shape, Routes, and API Client

N/A — no change: no component tree, browser state, route, or API client
exists or is added.
