# Acceptance Tests: epic-196-a8-integration

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | static / doc-review (classification: automated, design.md Classification Table) | Fixture Contract table: exact artifact path/bytes/nonce-mutation/oracle per adjacent handoff | Planned |
| AC-002 | REQ-001 | TEST-002 | integration (classification: automated-pending-confirmation, design.md Classification Table) | Claude→Codex handoff step | Planned |
| AC-003 | REQ-001 | TEST-003 | integration (classification: automated-pending-confirmation, design.md Classification Table) | Codex→Copilot handoff step | Planned |
| AC-004 | REQ-001 | TEST-004 | integration (classification: automated-pending-confirmation, design.md Classification Table) | full 3-hop chain vs. README.md:193's own claim | Planned |
| AC-005 | REQ-001 | TEST-005 | static / doc-review (classification: automated, design.md Classification Table; also depends on REQ-006's own vocabulary, see design.md) | per-CLI headless contract confirmed-or-unconfirmed marker | Planned |
| AC-006 | REQ-001 | TEST-006 | integration (classification: automated, design.md Classification Table; this cell previously read "named SKIP until Epic A1 merges, `a8-skip-allowlist.json`" — superseded 2026-08-24: Epic A1 merged on 2026-08-08, so AC-006's own trigger is crossed and this row's presence assertion is live, verified directly here against this package's own fixture chain and never against Epic A1's artifacts; the case's own allowlisted `SKIP` record in `a8-skip-allowlist.json` stays a valid, non-failing state until AC-006's own two-clause SKIP Allowlist Activation Gate predicate — T-005 started AND the handshake script existing on `main` — additionally holds, design.md. AC-015's single-clause hard-failure trigger, which the TEST-015/TEST-016 rows below inherit, is deliberately not carried onto this row; requirements.md AC-006 and Assumptions state the identical rule) | hook-activation canary case present in handoff fixture | Planned |
| AC-007 | REQ-002 | TEST-007 | integration (classification: automated, design.md Classification Table) | 4-cell install→verify→uninstall→verify matrix, per Target × Phase × Surface Registration Table (required MCP-surface preconditions provisioned) | Planned |
| AC-008 | REQ-002 | TEST-008 | integration, negative self-check (classification: automated, design.md Classification Table) | idempotent re-install (no diff from first install) | Planned |
| AC-009 | REQ-002 | TEST-009 | integration (classification: automated, design.md Classification Table) | zero-residue post-uninstall verify, per Target × Phase × Surface Registration Table | Planned |
| AC-010 | REQ-002 | TEST-010 | doc-review (classification: automated, design.md Classification Table) | local-macOS vs. existing 3-OS CI division of labor | Planned |
| AC-011 | REQ-002 | TEST-011 | static / doc-review (classification: automated, design.md Classification Table) | `--target FilesOnly` recorded out-of-matrix | Planned |
| AC-012 | REQ-003 | TEST-012 | integration (classification: automated — direct-invocation synthetic regression only, never a live-host proof; Direct-Invocation De-Spoofing, design.md) | 3-runtime guard fixture (deny self-approval / allow benign), extends `cli-hook-enforcement.ps1` | Planned |
| AC-013 | REQ-003 | TEST-013 | integration (classification: manual-required, upgrades per-cell to automated once a real-session Codex dispatch contract is confirmed — direct guard invocation never substitutes; design.md Classification Table) | Codex `plugin_hooks` flag on/off via real Codex sessions → `Codex-enabled-active`/`Codex-disabled-expected-unavailable` semantic cells | Planned |
| AC-014 | REQ-003 | TEST-014 | integration (classification: manual-required, upgrades per-cell to automated once a real-session Copilot subagent dispatch contract is confirmed; design.md Classification Table) | Copilot subagent non-firing vs. primary-active contrast → `Copilot-primary-active`/`Copilot-subagent-expected-unavailable` semantic cells, + fallback-command reference | Planned |
| AC-015 | REQ-003 | TEST-015 | live-host proof (classification: manual-required, per-cell upgrade path to automated per REQ-006; fortified `live-host-verification-record/v1`; named SKIP until Epic A1 merges) | genuine hook-activation-handshake denial/unavailability, 5 semantic live-host matrix cells | Planned |
| AC-016 | REQ-003 | TEST-016 | integration (classification: manual-required, same upgrade path as AC-015; named SKIP until Epic A1 merges) | all 5 of A1's migrated consumer entry points exercised per runtime, fingerprinted inventory | Planned |
| AC-017 | REQ-003 | TEST-017 | regression (classification: automated, design.md Classification Table) | `cli-hook-enforcement.ps1` existing assertions stay green, independent of AC-015 | Planned |
| AC-018 | REQ-004 | TEST-018 | integration (classification: automated, design.md Classification Table) | Windows path-separator, one axis of the REQ-004 pairwise covering combination matrix (16 rows, OS × script × EOL × normalization × phase) | Planned |
| AC-019 | REQ-004 | TEST-019 | integration (classification: automated, design.md Classification Table) | CRLF-vs-LF at `.gitattributes` layer (not the canonicalizer layer), one axis of the pairwise covering matrix | Planned |
| AC-020 | REQ-004 | TEST-020 | integration (classification: automated, design.md Classification Table) | NFC-vs-NFD filename/content against this epic's own Unicode-Normalization Contract (never `.gitattributes`), one axis of the pairwise covering matrix | Planned |
| AC-021 | REQ-004 | TEST-021 | static / doc-review (classification: automated, design.md Classification Table) | regression-matrix cell disposition table (ASSERT/N-A this package; SKIP-with-activation reserved) | Planned |
| AC-022 | REQ-005 | TEST-022 | integration + negative-lifecycle case (classification: automated, design.md Classification Table; one bundled AC-022 row, never split across two classification-table rows) | installed-cache-vs-repo drift check: ≥1 positive divergence class (issue #86 precedent) plus ≥1 independent negative-lifecycle case (prior-version install→revision, or cache mutate/delete/add) with exact diff/exit oracle | Planned |
| AC-023 | REQ-005 | TEST-023 | integration, negative self-check (classification: automated, design.md Classification Table) | distinct not-installed (preflight mode only) / synced / drifted result states; not-installed is a FAIL in verify mode | Planned |
| AC-024 | REQ-005 | TEST-024 | static / doc-review (classification: automated, design.md Classification Table) | drift check wired as REQ-002 verify sub-step, `mode: verify` | Planned |
| AC-025 | REQ-006 | TEST-025 | static / doc-review (classification: automated; REQ-006 process check, classified in this document — outside design.md's Classification Table, whose own scope is the checks REQ-001–REQ-005 name) | exhaustive automated/pending/manual classification table, single current value per AC | Planned |
| AC-026 | REQ-006 | TEST-026 | static / doc-review (classification: automated; REQ-006 process check, classified in this document — outside design.md's Classification Table, whose own scope is the checks REQ-001–REQ-005 name) | fortified `live-host-verification-record/v1` schema fixed (nonce, raw hashes, session/event IDs, hook/config digest, timestamps, two-party attestation) | Planned |
| AC-027 | REQ-006 | TEST-027 | static, negative self-check (classification: automated; REQ-006 process check, classified in this document — outside design.md's Classification Table, whose own scope is the checks REQ-001–REQ-005 name) | classification-mismatch/replay guard (no automated↔manual substitution, no nonce reuse, no unsigned/single-signature record) | Planned |
| AC-028 | REQ-003 | TEST-028 | automated aggregate validator (`validate-live-host-proof`, Done gate + release gate; classification: automated, design.md Classification Table — this row is AC-028's only classification-table entry; also depends on REQ-006's own record schema, see design.md) | ADR-0019/Epic A1 delegation discharged only once all 5 semantic live-host matrix cells pass validation (or SKIP before Epic A1 merges) | Planned |
| AC-029 | REQ-007 | TEST-029 | doc-review (classification: automated; REQ-007 process check, classified in this document — outside design.md's Classification Table, whose own scope is the checks REQ-001–REQ-005 name) | scope-boundary self-check: no AC re-specifies another Epic's own 3-env build-out | Planned |
| AC-030 | REQ-007 | TEST-030 | doc-review (classification: automated; REQ-007 process check, classified in this document — outside design.md's Classification Table, whose own scope is the checks REQ-001–REQ-005 name) | every factual claim cites file:line evidence (WFI-011) | Planned |

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
{sh,ps1}`, and the `tests/hook-activation-live-proof/` record set —
design.md Components/API-Contract Plan; this is the one canonical path
both the record-producing session and `validate-live-host-proof` use,
never a second `verification/live-host-proof/`-style path), matching the
placeholder-index convention Epic A7's own acceptance-tests.md already
establishes for this repository.

The `Test Type` column's classification markers on AC-002/AC-003/AC-004
(and on every other AC that REQ-001 through REQ-005 name — AC-001 through
AC-024 plus AC-028) cite design.md's own Automated / Manual Classification
Table (AC-025) directly, rather than carrying an independent `TBD`
placeholder — that table is this package's single normative classification
source (REQ-007) for exactly those twenty-five checks, fixed once, so this
column is never out of sync with it. Amended 2026-08-24: this sentence
previously read "fixed once and covering every check in this document",
which overstated the table's scope. The table's own scope sentence in
design.md declares it exhaustive over "every check REQ-001 through REQ-005
name", and it contains no row for AC-025, AC-026, AC-027, AC-029 or
AC-030. Those five are REQ-006's and REQ-007's own process checks; their
`Test Type` classification is fixed in this document directly and is not
sourced from design.md's table. Per
design.md's Design Decisions (OQ-001), AC-002/AC-003/AC-004 currently
resolve to `automated-pending-confirmation` because no CLI's headless
contract is yet confirmed (INV-021); a Phase 2/3 confirmation upgrades
the affected row in both design.md's table and this column in the same
commit, never in only one of the two.
