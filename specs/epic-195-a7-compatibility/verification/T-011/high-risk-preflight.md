# T-011 high-risk persisted-evidence preflight

Recorded before implementation changes for WFI-001.

| Persisted evidence field | Sibling contract / traceability counterpart | Failing mismatch test captured before implementation |
|---|---|---|
| Eleven Bash suite paths in `tests/run-all.sh` | Identical eleven-suite inventory in `tests/run-all.ps1`; tasks.md T-002–T-010/T-013 Planned Files; traceability T-011 → TEST-015 | Registration-completeness check fails if any expected Bash path is absent or duplicated |
| Eleven PowerShell suite paths in `tests/run-all.ps1` | Bash aggregate runner and the same task inventory | Registration-completeness check fails if any `.ps1` twin is absent or duplicated |
| Eleven Bash and eleven PowerShell workflow invocations | Aggregate-runner inventory; AC-015 / TEST-015 | RED runs the assertion against the current live workflow basis and fails on the six suite pairs genuinely missing from that basis |
| Staged workflow bytes | Current live `.github/workflows/test.yml` plus only the T-011 registration block; R-10 protected-file rule and Epic A5 cumulative human-copy precedent | Basis check fails while the existing feature-local staged workflow does not equal the current live workflow plus the expected registration block |
| `human-copy/MANIFEST.sha256` digest | SHA-256 of `human-copy/.github/workflows/test.yml`; ADR-0011 staging pattern | Manifest check fails on a missing, stale, duplicated, or non-lowercase digest entry |
| T-012 live-refresh exclusion | requirements.md AC-031; design.md Test Strategy item 9 and Deployment / CI Plan | Registration check fails if `structural-compatibility-live-refresh.tests.sh` or its `.ps1` twin appears in either aggregate runner or staged gating workflow |
| AC-028 `ASSERT` disposition | design.md Compatibility Matrix and acceptance-tests.md TEST-028 | Matrix check fails if any ASSERT cell lacks a mapped passing suite case in the assembled evidence set |
| AC-028 `SKIP-with-activation` disposition | T-010 `skip-allowlist-manifest/v1`; REQ-007 AC-034/AC-035 | Matrix check fails if any SKIP cell is not backed by an exact manifest assertion entry read by an assembled suite |
| AC-028 `N/A` disposition | design.md Compatibility Matrix F7/F8 and byte-column N/A cells | Matrix check fails if an N/A cell is assigned a suite case |
| T-011 implementation status and REQ-005 evidence claim | tasks.md T-011 lifecycle; traceability T-011 → REQ-005 / TEST-015 / TEST-028 | Traceability check fails while T-011 remains Planned/In Progress or evidence paths are absent |

No implementation verdict is persisted by this phase. Independent quality-gate
and cross-model verdicts remain separate, future orchestrator actions.
