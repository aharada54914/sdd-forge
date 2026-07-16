# Investigation: epic-159-pillar-a2

Feature: epic-159-pillar-a2
Source Issues: #145 (A5), #146 (A6), #147 (A7), #174 (spec twin — same defect class as A7)
Date: 2026-07-15
Baseline: main after PR #175 merge (loop suites, loop-driver with validator capability probe, loop-inventory at HEAD)
Method: read-only investigation by sdd-investigator (file:line evidence per AGENTS.md "Spec factual-claim evidence citations", WFI-011)

## 1. HITL diagnosis loop implementation and enforcement (A5 / #145)

- INV-001 — hitl-diagnosis loop registered in `tests/loops/loop-inventory.json:154-165` with `id: "hitl-diagnosis"`, `kind: "hitl"`, `cap: { "type": "hitl-attempt", "value": 5 }`, `cap_source: "skill-instruction"`, `driver_scripts: []` (no enforcement script — cap lives in skill only).
- INV-002 — cap limit 5 enforced in `plugins/sdd-implementation/skills/diagnose/scripts/hitl-loop.template.sh:10`: `ITER="${1:-5}"` sets default max iterations to 5; loop-controlled at line 12 `while [ "$i" -lt "$ITER" ]`, incrementing `i` at line 13, terminating when `i >= 5` (lines 31-34 print completion message and exit 0). Template contract: caller passes `ITER` as `$1` or uses default 5.
- INV-003 — terminal state defined in inventory:163 as `"state": "BLOCKED"` with condition `"hitl-loop attempts >= 5 (max iterations) -> Human-Blocked (diagnose skill hitl-loop.template.sh:10)"` — exactly pins the enforcement source.
- INV-004 — skill-instruction enforcement means A5 must test the state machine via HITL integration test (spawning the skill, not invoking the template directly), verifying the workflow stops at attempt 5 with terminal output and non-zero exit. The test fixture must exercise the reproducer-not-found (green iterations) path: loop runs 5 times, reproducer never returns true (line 25 `if CHECK`), exits 0 at line 34 after loop completion.

## 2. WFI audit cycle state machine and enforcement (A5 / #145)

- INV-005 — audit cycle state machine defined in `plugins/sdd-quality-loop/skills/wfi-audit-cycle/SKILL.md:59-240` with preconditions and process steps:
  - Precondition 4 (lines 44-50): `Audit-Attempt >= 3 -> Audit-Status: Human-Blocked` (convergence guard, attempt limit).
  - Precondition 5 (lines 51-57): no-change guard (Audit-Content-Hash SHA-256 comparison).
  - STEP 4 (lines 119-135): Cycle 1 BLOCKED -> increment Audit-Attempt -> if >= 3 set Human-Blocked, else set Not-Started.
  - STEP 7 (lines 186-203): Cycle 2 BLOCKED -> same logic, attempt >= 3 -> Human-Blocked.
  - STEP 9 (line 239): On PASS -> set Audit-Status: Human-Pending.
- INV-006 — Audit-Status field valid values: `Not-Started`, `Cycle-1-In-Progress`, `Cycle-2-In-Progress`, `Human-Pending`, `Human-Blocked` (lines 34-43, 61-65). State transitions form a directed graph (Not-Started -> Cycle-1-In-Progress -> Cycle-2-In-Progress -> Human-Pending; either cycle may -> Not-Started or -> Human-Blocked).
- INV-007 — real audit data: `docs/workflow-improvements/WFI-010.md:44-56` shows a concrete run: Audit-Status: Human-Pending, Audit-Attempt: 1, Audit-Content-Hash recorded at the Cycle-1 BLOCKED verdict (lines 52-55 comment), then Cycle 2 NEEDS_REVISION -> Human-Pending visible in the document sequence. Usable as test-design reference for the state transitions.
- INV-008 — no driver script exists for wfi-audit (inventory line 144: `"driver_scripts": []`). Enforcement is 100% skill-orchestrated via precondition checks + field mutations. A5 test must verify: (a) attempt 1 BLOCKED -> Audit-Attempt becomes 1, (b) attempt 2 BLOCKED -> Audit-Attempt becomes 2, (c) attempt 3 BLOCKED -> Audit-Status becomes Human-Blocked and no further attempt runs.

## 3. Brownfield fixture implementation and check-placeholders restriction (A6 / #146)

- INV-009 — brownfield fixture support implemented in `tests/lib/loop-driver.sh:106-138`. Function `loop_fixture_init <greenfield|brownfield> <feature>` accepts profile parameter (line 108); greenfield case uses mktemp from scratch; brownfield case (lines 132-138): validates LOOP_FIXTURE_SEED environment variable points to an existing directory, then copies seed contents: `cp -R "${LOOP_FIXTURE_SEED}/." "${LOOP_FIXTURE_ROOT}/"` (line 137).
- INV-010 — brownfield seed is a "caller-supplied synthetic seed" per the T-002 implementation report ("caller-supplied synthetic seed ... until A6/#146 delivers the canonical seed"). A6 must deliver the actual canonical seed directory at `tests/fixtures/loops/brownfield-seed/` containing (per issue #146): (i) valid `raise NotImplementedError` abstract-base-class examples, (ii) existing unrelated TODO markers, (iii) bootstrap-complete tasks.md.
- INV-011 — check-placeholders.sh behavior documented in `docs/troubleshooting.md:66-75` ("brownfield" section). Restriction (line 75): passing changed files only is the quality-gate caller's responsibility; passing a full directory detects existing markers too.
- INV-012 — check-placeholders.sh:28-49 uses grep exit code branching (rc_cs=$? / rc_ci=$?), detecting genuine scan errors (exit >= 2) vs no-match (exit 1). Per line 50, results are merged and deduplicated. A6 must write two test variants: (a) pass only changed files -> PASS (existing markers ignored), (b) pass full directory -> FAIL (existing markers detected). The two-test lock verifies the current behavior and prevents future silent relaxation.

## 4. Spec and domain precheck .ps1 twins missing (A7 / #147, and #174)

- INV-013 — `plugins/sdd-review-loop/scripts/spec-review-precheck.sh` exists; its .ps1 twin DOES NOT EXIST. Confirmed in `tests/loop-driver.tests.ps1:2-11` comment: "spec-review-precheck.ps1 does not exist anywhere in this repository (only the .sh form exists)". Issue #174 tracks this defect.
- INV-014 — `plugins/sdd-domain/scripts/domain-review-precheck.sh` exists (signature at line 9: `Usage: domain-review-precheck.sh <attempt> <round> ...`); its .ps1 twin DOES NOT EXIST. Confirmed in `tests/loop-consistency.tests.ps1:13`. Issue #147 tracks this defect.
- INV-015 — spec-review-precheck.sh signature: `spec-review-precheck.sh <feature-slug> <attempt> <round> [--edit-summary=<text>] [--reset]` (line 8). domain-review-precheck.sh signature: `domain-review-precheck.sh <attempt> <round> [--edit-summary=<text>] [--reset]` (line 9; note: no feature parameter — domain is repo-scoped, not feature-scoped).
- INV-016 — .sh/.ps1 twin-pair mandate documented in `specs/epic-159-pillar-a/design.md:309`. Translation reference implementations exist: `plugins/sdd-review-loop/scripts/impl-review-precheck.ps1` and `plugins/sdd-review-loop/scripts/task-review-precheck.ps1`. The two missing twins block pwsh-lane execution of spec-review and domain-review loops.
- INV-017 — auto-recovery design documented in `tests/loop-consistency.tests.ps1:6-11` (AC-015 recorded SKIP-with-reason; spec-review-precheck.ps1 absence transitively degrades impl/task legs) and `tests/loop-driver.tests.ps1:6-7`. When the twins are authored, the existence-guard conditions convert the named SKIPs back to real execution — no test edits needed ("self-healing").

## 5. Protected-gate-suffix status (A7 / #147, #174)

- INV-018 — `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:886-927` defines `_PROTECTED_GATE_SUFFIXES`. Lines 917-924 list sdd-review-loop gate files (reviewer agent .md files, impl-review-loop/SKILL.md, task-review-loop/SKILL.md). **The precheck scripts are NOT listed.** Implication: *-review-precheck.sh/.ps1 are NOT protected-gate files; agents can author the new .ps1 twins directly without human-copy staging.
- INV-019 — human-copy pattern (for protected files) documented in `specs/epic-136-phase1-guards/design.md:11` and `sdd-hook-guard.py:887` ("R-10: Enforcement-chain file protection ... NOT bypassable by sudo"). Not required here per INV-018.
- INV-020 — consequence for Planned Files: #147 and #174 can list the new .ps1 twins directly, avoiding the epic-136 human-copy procedure.

## 6. Twin arrival auto-recovery SKIPs (existing tests awaiting the fixes)

- INV-021 — `tests/loop-driver.tests.ps1:2-11` and `tests/loop-consistency.tests.ps1:6-16` declare named SKIPs citing #147 and #174.
- INV-022 — AC-015 recorded SKIP convention: tests emit `SKIP: <reason> (#<issue>)` rather than fail, with comments explaining the transitive blocking.
- INV-023 — auto-recovery mechanism: existence-guard conditions re-enable the real execution path when the twins land. No test edits needed on twin arrival.
- INV-024 — verification approach: post-fix, `pwsh tests/loop-driver.tests.ps1` must convert TEST-006 from named SKIP to executed checks; same for loop-consistency TEST-008 spec and domain legs. Decreasing SKIP count on windows-latest CI is the observable.

## 7. pwsh lane verification environment (CI and local)

- INV-025 — CI wiring in `.github/workflows/test.yml:32` and lines 79-110 (pwsh steps): direct invocation of .ps1 test files.
- INV-026 — pwsh step pattern: `shell: pwsh` + direct .ps1 run (no bash wrapper); bash steps use tee-to-log.
- INV-027 — 3-OS matrix (windows/macos/ubuntu) at test.yml:18; both lanes must pass on all three.
- INV-028 — local entry points: `bash tests/run-all.sh` and `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1`.

## 8. CI lessons learned — implementation resilience (mandatory for new code)

- INV-029 — bash 3.2 (macOS CI default /bin/bash) empty-array handling: `tests/lib/loop-driver.sh:326-330` documents that `"${arr[@]}"` on a declared-but-never-appended array is an unbound-variable error under `set -u` on bash 3.2. New scripts must never expand a possibly-empty array; keep arrays structurally non-empty or guard expansions.
- INV-030 — macOS `$TMPDIR` is a symlink; physical-path normalization required: `tests/lib/loop-driver.sh:124` (`pwd -P`). New fixtures must use `pwd -P` for temp paths.
- INV-031 — Windows jq.exe emits CRLF: all jq output consumption must pipe through `tr -d '\r'` unconditionally (no OS branching; harmless on Unix). Precedent: commit c756a5a hardened all 25 sites.
- INV-032 — real validator (validate-review-context-set.sh:241-258 @tsv+read loops) is itself Windows-CRLF-broken (issue #179). `tests/lib/loop-driver.sh` provides `loop_validator_capability_probe` (runtime behavior probe, no OS branching) + `loop_validator_skip` for named SKIPs; A5 tests that drive the real validator must gate through the same probe. LF-only files (crlf-parity), ASCII-only .ps1 (guard-ps1-ascii), and constant-parity are enforced by existing suites.

## 9. Dependencies and interactions between issues

- INV-033 — #145 (HITL + WFI audit) and #146 (brownfield fixture) are INDEPENDENT; both use loop-driver fixtures; no ordering constraint.
- INV-034 — #147 and #174 are INDEPENDENT of each other; both must complete before the pwsh lane runs fully green.
- INV-035 — all four depend only on the first wave (A1-A4, merged in PR #175); no ordering constraints among themselves beyond shared-registration-file commit serialization (Global Constraints precedent from wave 1).
- INV-036 — #145's WFI-audit testing targets the skill-orchestrated state machine; the wfi-audit-cycle skill mutates WFI files and may call gh (GitHub issue creation for plugin-improvement WFIs) — tests must use fixture-scoped WFI copies and must not reach GitHub (see OQ-2).
- INV-037 — #146 changes `tests/lib/loop-driver.*` (seed default wiring) — these files MUST be in #146's Planned Files from the start (wave-1 T-003 Planned Files omission lesson).

## Open Questions (for spec author / human)

- OQ-1 (A5/#145): HITL loop testing — drive the full diagnose-skill chain or the template in isolation? (Template is a user-writable copy; full-chain testing requires mocking user input. Suggested: drive hitl-loop.template.sh with a reproducer-stub script and mocked stdin; lock the iteration cap and terminal outputs.)
- OQ-2 (A5/#145): WFI audit cycle testing — real files in docs/workflow-improvements/ or fixture-scoped copies? (Suggested: fixture-scoped copies; the state machine is file-field-driven so it can be exercised on copies. GitHub issue creation must be skipped or stubbed — no network in suites per infra-spec precedent.)
- OQ-3 (A6/#146): canonical brownfield seed contents — are the three categories (NotImplementedError base classes, existing TODO markers, bootstrap-complete tasks.md) sufficient, or add more realistic brownfield patterns?
- OQ-4 (A6/#146): check-placeholders variants — loop-driver-driven AND direct unit tests, or unit tests only? (Suggested: unit tests only, mirroring existing check-placeholders test patterns; no loop-driver overhead needed.)
- OQ-5 (#147/#174): twin scope — (a) full parity port of every check, (b) gate-blocking checks only, or (c) bash shim? (Suggested: (a) full parity, following the impl-review-precheck.ps1 / task-review-precheck.ps1 precedent as translation models.)
- OQ-6 (#147/#174): tests/lib/loop-driver.ps1's precheck symlink/copy list must gain the new twins when they land — confirm whether that wiring belongs to #147/#174 (suggested) or to the suites' self-healing guards alone.
- OQ-7 (#147/#174): acceptance criterion for self-healing: pwsh TEST-006 (loop-driver) and TEST-008 spec/domain legs (loop-consistency) must report a decreasing SKIP count after each twin lands, confirmed by windows-latest CI green.

## Summary

epic-159-pillar-a2 completes Pillar A: HITL-diagnosis and WFI-audit terminal-behavior verification (A5/#145), canonical brownfield fixture seed plus check-placeholders behavior lock (A6/#146), and .ps1 parity for the spec-review and domain-review prechecks (#147/#174, non-protected per INV-018, self-healing SKIP re-enablement per INV-023). All findings carry file:line evidence from the merged post-PR-#175 repository state.
