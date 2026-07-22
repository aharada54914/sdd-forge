# Acceptance Tests: epic-196-a8-integration

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | static / doc-review | fixture-project contract: artifact + consumer-observable per adjacent handoff | Planned |
| AC-002 | REQ-001 | TEST-002 | integration (classification: TBD by REQ-006) | Claude→Codex handoff step | Planned |
| AC-003 | REQ-001 | TEST-003 | integration (classification: TBD by REQ-006) | Codex→Copilot handoff step | Planned |
| AC-004 | REQ-001 | TEST-004 | integration (classification: TBD by REQ-006) | full 3-hop chain vs. README.md:193's own claim | Planned |
| AC-005 | REQ-001, REQ-006 | TEST-005 | static / doc-review | per-CLI headless contract confirmed-or-unconfirmed marker | Planned |
| AC-006 | REQ-001 | TEST-006 | integration (named SKIP until Epic A1 merges) | hook-activation canary case present in handoff fixture | Planned |
| AC-007 | REQ-002 | TEST-007 | integration | 4-cell install→verify→uninstall→verify matrix definition | Planned |
| AC-008 | REQ-002 | TEST-008 | integration, negative self-check | idempotent re-install (no diff from first install) | Planned |
| AC-009 | REQ-002 | TEST-009 | integration | zero-residue post-uninstall verify | Planned |
| AC-010 | REQ-002 | TEST-010 | doc-review | local-macOS vs. existing 3-OS CI division of labor | Planned |
| AC-011 | REQ-002 | TEST-011 | static / doc-review | `--target FilesOnly` recorded out-of-matrix | Planned |
| AC-012 | REQ-003 | TEST-012 | integration | 3-runtime guard fixture (deny self-approval / allow benign), extends `cli-hook-enforcement.ps1` | Planned |
| AC-013 | REQ-003 | TEST-013 | integration | Codex `plugin_hooks` flag on/off, both independently asserted | Planned |
| AC-014 | REQ-003 | TEST-014 | integration | Copilot subagent non-firing, expected-state assertion + fallback-command reference | Planned |
| AC-015 | REQ-003 | TEST-015 | live-host proof (manual-required or automated, per REQ-006; named SKIP until Epic A1 merges) | genuine hook-activation-handshake denial, 3 runtimes | Planned |
| AC-016 | REQ-003 | TEST-016 | integration (named SKIP until Epic A1 merges) | ≥1 of A1's 5 migrated consumer entry points exercised per runtime | Planned |
| AC-017 | REQ-003 | TEST-017 | regression | `cli-hook-enforcement.ps1` existing assertions stay green, independent of AC-015 | Planned |
| AC-018 | REQ-004 | TEST-018 | integration | Windows path-separator fixture | Planned |
| AC-019 | REQ-004 | TEST-019 | integration | CRLF-vs-LF at `.gitattributes` layer (not the canonicalizer layer) | Planned |
| AC-020 | REQ-004 | TEST-020 | integration | NFC-vs-NFD filename/content fixture | Planned |
| AC-021 | REQ-004 | TEST-021 | static / doc-review | regression-matrix cell disposition table (ASSERT/N-A this package; SKIP-with-activation reserved) | Planned |
| AC-022 | REQ-005 | TEST-022 | integration | installed-cache-vs-repo drift check, ≥1 divergence class modeled on issue #86 | Planned |
| AC-023 | REQ-005 | TEST-023 | integration, negative self-check | distinct not-installed / synced / drifted result states | Planned |
| AC-024 | REQ-005 | TEST-024 | static / doc-review | drift check wired as REQ-002 verify sub-step | Planned |
| AC-025 | REQ-006 | TEST-025 | static / doc-review | exhaustive automated/pending/manual classification table | Planned |
| AC-026 | REQ-006 | TEST-026 | static / doc-review | `live-host-verification-record/v1` schema fixed | Planned |
| AC-027 | REQ-006 | TEST-027 | static, negative self-check | classification-mismatch guard (no automated↔manual substitution) | Planned |
| AC-028 | REQ-003, REQ-006 | TEST-028 | doc-review / evidence audit | ADR-0019/Epic A1 delegation discharged only once all 6 live-host cells exist (or SKIP before Epic A1 merges) | Planned |
| AC-029 | REQ (process) | TEST-029 | doc-review | scope-boundary self-check: no AC re-specifies another Epic's own 3-env build-out | Planned |
| AC-030 | REQ (process) | TEST-030 | doc-review | every factual claim cites file:line evidence (WFI-011) | Planned |

This is internal test-infrastructure specification work with no
user-facing entry point; the UI Integration Checklist is not applicable.

Every `Planned` status above is a Phase 1 (specification-only) placeholder:
no test code exists yet. The `Test ID` column (`TEST-001`–`TEST-030`) is
this package's own Phase 1 AC-to-test placeholder index — one entry per AC,
in AC order — distinct from the real, per-suite-file case numbers Phase 2/3
actually implements once it names concrete files
(`tests/cross-runtime-handoff.tests.sh`, `tests/install-uninstall-matrix.
tests.sh`, `tests/cli-hook-enforcement.ps1`'s own new case numbers,
`tests/path-lineending-regression.tests.sh`, `check-installed-plugin-drift.
{sh,ps1}`, and the `verification/live-host-proof/` record set — design.md
Components/API-Contract Plan), matching the placeholder-index convention
Epic A7's own acceptance-tests.md already establishes for this repository.

The `Test Type` column's "(classification: TBD by REQ-006)" marker on
AC-002/AC-003/AC-004 is intentional: this Phase 1 package fixes those
checks' own pass/fail contract (design.md Data Plan,
`cross-runtime-handoff-trace/v1`) without yet asserting whether their
concrete implementation is `automated`, `automated-pending-confirmation`,
or `manual-required` — that classification is itself AC-025's own
deliverable (design.md's classification table), fixed once, covering these
and every other check in this table, rather than guessed at per-row before
OQ-001 (requirements.md) is resolved.
