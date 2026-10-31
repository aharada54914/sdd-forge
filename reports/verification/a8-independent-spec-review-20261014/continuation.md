# A8 AC-016 continuation — 2026-10-14

This is separate exception-route evidence, not a formal SDD gate verdict.

## Scope and authority

- Owner: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`, detached HEAD `495c88d67af44530687ecea3ce9fb0a90a336539`.
- Parent delegated the user's approved continuation: independently re-review current design, then task inputs with fresh non-inheriting Codex reviewers; retain old formal ledger and Passed headers; bounded findings repair and affected regression; implement approved T-005/T-008 only after required review/dependency boundaries. No Git publication or genuine human signing authority is granted.
- Risk: existing high-risk evidence/security contract, not routine development. T-005 and T-008 retain Approved (`sudo 2026-08-08T16:33:11Z`), Planned and TDD. No status changes are made.
- All existing dirty changes are preserved; no other checkout is changed. Old candidates are not reapplied. Frozen/history artifacts remain historical.
- Current specification result is the independent exception PASS in `repair-req004/review-after.json`, not a formal status change. Revised requirements SHA-256 is `244f2c539a8242e36fe7a2d88a04b32476c15306534fa83db043bc0132b9775e`.
- Design input manifest: `design-round-1-inputs.json`, SHA-256 `04a4ed807f71df42eb693c53c5e7af1fa3d6110e1381b835891182e798a207ba`. Reviewer `/root/a8_remaining_oct14/fresh_a8_design_review` was launched using `fork_turns: none`; no prior review output or implementation was included.

## Dependency observations (not task acceptance)

T-005's exact functional prerequisite is T-003's existing staged workflow and manifest (tasks.md:886–900); T-001/T-002 are serialized ordering dependencies, not validator fixture dependencies. The staged candidate contains T-003's PowerShell/POSIX install-uninstall steps at lines 324–334. Its SHA-256 `e045e20f2d4fdc14f9ba118dadd882b750ec33b0d733c6fc78ebad1d3aaac999` matches `human-copy/MANIFEST.sha256`. This verifies prerequisite content, not T-003's quality-gate/CI completion.

The existing T-005 implementation report is a preflight/unfinished report. It does not establish Done When satisfaction. Existing validator code still accepts `live-host-verification-record/v1` only (validate-live-host-proof.py:337), with no `consumer_inventory` validation. Current v2 requirements therefore still need implementation after design/task review.

T-008's authentic records, trusted identities and countersignatures remain human-dependent; fixture success cannot discharge them. Current real nonce ledger SHA-256 is `2042affc954b460842f6cf1294998eb4e2ee0e8b09e06f0ada63b8dccc8a3857`; trusted registry SHA-256 is `f6ec9affdaec7ce9eab180b5dcad45a468dd083a0261aebba64392ead8176886`. Neither is changed.

## Baseline validation

Executed in the owner checkout with `rtk proxy bash tests/validate-live-host-proof.tests.sh`, login disabled: exit 0, `live-host-proof: 91 passed, 0 failed`. This is the pre-change v1 fixture baseline, not v2 acceptance, native activation, independent evaluation or CI. The fixture driver directs records/nonce/keys to disposable roots (run_cases.py:203–213,378–389,426–433); committed T-008 records are read-only inputs (414–419).

PowerShell twin also executed with `rtk proxy pwsh -NoProfile -File tests/validate-live-host-proof.tests.ps1`, login disabled: exit 0, `live-host-proof: 91 passed, 0 failed`. This is macOS PowerShell, not Windows evidence.

Task review preparation pins 19 files in `task-round-1-inputs.json`, SHA-256 `cc794a5161ea6ebea560d41d73a4dd3f045d4ef8e86ae661aac61d43ce07910c`. All 16 design and 19 task input hashes were rechecked with zero mismatches. The task reviewer has not been launched yet; design review precedes it.

The design reviewer requested `references/impl-review-rubric.md` mentioned in the checklist. That file does not exist in the owner checkout (`cat` and `shasum` ENOENT, repository file enumeration has no impl/task-review-rubric). It was not invented or imported from another checkout; the reviewer was asked to state any resulting evaluation limitation. Exact AC-016 allowlist commit/path Git blob-ID lookup was explicitly admitted as read-only source-map verification, without reading implementation content or widening to other objects.

No implementation edit has begun. The required design/task re-reviews (tasks.md:1692–1693) precede the v2 delta and a new field/counterpart/failing-test preflight must precede production code changes.

## Independent design result and scope boundary

The independent reviewer returned NEEDS_WORK, two Major findings. Its original JSON is preserved in `design-round-1-result.json`, including an infra-spec SHA transcription omission. The same reviewer rehashed all 16 inputs, confirmed the omission was transcription only and supplied `design-round-1-sha-correction.json`; the original result was not overwritten. Assessment is unchanged.

- D-001: design.md:1047 defines no target input for drift verification, while Coverage Scope unconditionally asserts Codex surfaces and the target matrix requires their absence for clean Claude/Copilot-only installations.
- D-002: design.md:1510 allows AC-002 automation once Claude headless is confirmed, although its actual consumer is Codex and requires that contract too.
- AC-016 v2 consistency and the five accepted Git blob identities passed; no native proof is inferred.
- Domain applicability was not verified by the reviewer from its manifest. Coordinator inspection finds no root `domain/` directory; no domain evidence is invented.

Post-review coordinator inspection confirms D-001 reaches existing T-002/T-003 implementation, not only prose: `check-installed-plugin-drift.py:233–234` unconditionally compares Codex agents and MCP regions; its parser lines 244–245 accepts only install-root/mode. `install-uninstall-matrix.tests.sh:69–84` and its PowerShell twin lines 69–76 seed Codex agents/regions even for non-Codex target cells. The Bash comment explicitly says this enables drift verification on every target. This hides the clean target-specific missing-surface case.

D-001 therefore needs a specified target-selection/default contract and bounded T-002/T-003 repair beyond the currently selected T-005/T-008 implementation delta. The parent has been asked to resolve that scope before any normative or implementation edit. D-002 has a local two-runtime conjunction repair. Task review remains unlaunched; the prepared manifest is not a review verdict or admission of changed future bytes. No existing gates, task states, protected code, ledger, native identities or historical inputs have been changed by this continuation.
