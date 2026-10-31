# Investigation: epic-159-pillar-a (issues #141 / #142 / #143 / #144)

Date: 2026-07-14
Branch: feature/epic-159-pillar-a (HEAD 61dea47)
Method: read-only investigation by sdd-investigator (fresh agent, file:line
evidence), materialized by the orchestrator; INV-013 (A3 fix status) was
independently re-verified by the orchestrator against the working tree and
git history before writing this document.

## 1. Loop surface inventory (A1 / #141)

- INV-001 — six review/gate loops exist. Summary table (candidate ids for
  `tests/loops/loop-inventory.json`):

| id (candidate) | kind | cap | driver | schema strings | terminal |
|---|---|---|---|---|---|
| spec-review | dual reviewer A/B | round <= 3 | plugins/sdd-review-loop/scripts/spec-review-precheck.sh:37 | spec-review-precheck/v1, spec-review-integrated-verdict/v1, spec-review-contract/v1 | round-3 Minor-only merges to PASS; Major/Critical → BLOCKED |
| impl-review | dual reviewer A/B | round <= 3 | plugins/sdd-review-loop/scripts/impl-review-precheck.sh:3,206-210 | impl-review-precheck/v1, integrated-verdict/v1 | round>1 requires previous-round summary (see INV-013); round 3 → BLOCKED |
| task-review | dual reviewer A/B | soft cap (round>1 requires persisted impl PASS) | plugins/sdd-review-loop/scripts/task-review-precheck.sh:3,219-222 | task-review-precheck/v1, integrated-verdict/v1 | round 3 → BLOCKED; escalation continues via quality-gate |
| quality-gate | evaluator + escalation | >= 3 gate reports → Escalate-Human | plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh:14-15 | (report Markdown + verification contract) | Escalate-Human at count >= 3 |
| terminal-tier | resume gate | strong-tier recurrence → permanent BLOCK | plugins/sdd-quality-loop/scripts/check-terminal-tier-resume.sh:1-184 | terminal-tier-blocked-state/v1 (schema file lines 1-54), terminal-tier-resume/v1 | recurrence at strong tier = terminal BLOCKED; resume requires human approval record |
| domain-review | dual reviewer A/B | round <= 3 | plugins/sdd-review-loop/scripts/domain-review-precheck.sh:39 | (domain contract set) | round 3 → BLOCKED; post-approval drift detection (AC-014) |

- INV-002 — every `plugins/**/scripts/*-review-precheck.sh` maps to one loop
  above; `validate-review-context-set.sh` authorization pairs (stage:role
  case list) enumerate spec/impl/task/domain reviewer pairs plus
  quality:sdd-evaluator (validate-review-context-set.sh:190).
- INV-003 — caps are grep-able from driver sources (e.g. round<=3 guards in
  the precheck scripts; `count >= 3` in
  check-quality-gate-cycle-limit.sh:14-15), satisfying #141's cap-drift
  check requirement.
- INV-004 — wfi-audit loop: cap `Audit-Attempt >= 3 → Human-Blocked` is
  enforced by skill instruction (wfi-audit-cycle SKILL, preconditions 4),
  not by a repository script; hitl cap (5) likewise lives in skill/prompt
  text. The inventory schema must therefore support `driver_scripts: []`
  with `cap_source: skill-instruction` or the registration-forcing test
  will produce false negatives for these loops. (Design decision for A1.)

## 2. Identity-ledger hash chain (A2 fixture init / #142)

- INV-005 — record structure (validate-review-context-set.sh:215-232):
  sequence (number > 0), stage/role/run_id/host_session_id (canonical
  strings), previous_record_sha256 (empty for genesis or 64-hex),
  record_sha256 (64-hex).
- INV-006 — hash formula (validate-review-context-set.sh:245):
  `sha256(sequence|stage|role|run_id|host_session_id|previous_record_sha256)`;
  chain continuity and immutability validated at lines 239-258. A2's
  `loop_fixture_init` must synthesize a genesis ledger consistent with this
  formula.
- INV-007 — workflow-state registry entry for a synthetic feature is a
  one-object entry `{"feature": <slug>, "profile": "full"|"lite"}` in
  specs/workflow-state-registry.json (schema_version 1; see
  contracts/workflow-state-registry.schema.json); task-review-precheck
  reads the profile (task-review-precheck.sh:245-247).

## 3. Reusable test helpers (A2 / #142)

- INV-008 — tests/spec-review-loop.tests.sh:39-99 `write_contract()` builds
  the 5-JSON fixture set (integrated-summary, reviewer-a/b, integrated-
  verdict, spec-review-contract) — the seed for A2's
  `drive_review_round`.
- INV-009 — assertion convention: counter-based `ok()`/`fail()`
  (tests/spec-review-loop.tests.sh:28-31); fixture isolation via mktemp +
  `trap ... EXIT` (lines 13-26).
- INV-010 — twin registration convention: new suites join the
  tests/run-all.sh bash array (lines 7-62; 48 entries at HEAD) plus the
  pwsh path (run-all.sh lines 64-71 pattern for .ps1 suites), and
  .github/workflows/test.yml (PowerShell steps lines 32,79-110; Bash steps
  122-203).

## 4. A3 bug status — FIXED at HEAD; remaining scope is the consistency suite (#143)

- INV-011 — the contradiction as filed: impl-review-precheck.sh:206-210
  requires impl-reviewer-a's manifest to carry the PREVIOUS round's
  integrated-summary.json when round > 1, while the pre-fix
  validate-review-context-set.sh authorized integrated-summary for
  reviewer-b only → round > 1 was structurally impossible (workaround used
  in production: new attempt round 1 / provenance re-review — see
  reports/task-review/epic-136-phase1-guards attempt-2 history).
- INV-012 — fix landed in commit 2d8c6a5 "fix: unblock impl review rounds
  after the first (#143)": validate-review-context-set.sh:86-98 now
  authorizes `reports/impl-review/<feature>/attempt-N/round-N/
  integrated-summary.json` for BOTH impl-reviewer roles, with an Issue #143
  comment block; CHANGELOG.md:19-25 records the fix for both twins
  (.sh/.ps1) and a regression test added to review-agent-isolation.
- INV-013 — ORCHESTRATOR-VERIFIED (2026-07-14): the working tree at HEAD
  61dea47 contains the fixed authorization case and the CHANGELOG entry;
  `git log` shows 2d8c6a5 in ancestry. Consequence for the spec: #143's
  "red-first fix" item is already satisfied upstream; the feature's A3
  scope is the loop-consistency suite that regression-locks the fix and
  drives rounds 1→3 for all dual-reviewer loops with the bidirectional
  invariant ("inputs a downstream gate requires are inputs the upstream
  gate authorizes"). RED evidence remains obtainable by pointing the suite
  at the pre-fix parent commit (`2d8c6a5^`), mirroring the
  epic-136-phase1-guards red-differential pattern.

## 5. A4 parity surface (#144)

- INV-014 — evaluator authorization boundary:
  validate-review-context-set.sh:110-116 (quality:sdd-evaluator path
  rules), evaluator_output_is_declared() lines 63-74 (scans EXACTLY the
  `## Outputs` section for `` | `path` | `sha256` | `` rows; `###`-level
  attempt tables are NOT scanned — production-observed during
  epic-136-phase1-guards T-001 attempt 2).
- INV-015 — implementation report identity requirements
  (validate-review-context-set.sh:268-282): exact path
  `reports/implementation/<feature>/<task_id>.md`, heading
  `# Implementation Report: <task_id>` (line 278), full-line field
  `- Task ID: <task_id>` (line 280).
- INV-016 — template state: implementation-report.template.md is schema v2
  (line 5) with the WFI-005/006 fields (Snapshot Notice lines 7-12,
  `## Outputs` two-column table lines 30-40).
  tests/template-validator-parity.tests.sh already pins template⇔validator
  agreement for the heading/Task-ID/Outputs/Feature-line checks (10 checks
  green at HEAD). A4 must EXTEND, not duplicate: its new assertions are
  (a) escalation-path artifacts (select-agent-model escalation,
  terminal-tier-recurrence output, terminal-tier-blocked-state schema
  validity, check-terminal-tier-resume contract) driven end-to-end, and
  (b) the #112 cycle-limit script as the drive target
  (check-quality-gate-cycle-limit.{sh,ps1} landed with
  epic-136-phase1-guards T-003).
- INV-017 — python3 dependency: check-terminal-tier-resume.sh:29-32 and
  select-agent-model.sh:84-88 fail closed with
  "deterministic-runtime-unavailable" when python3 is absent — the A4 leg
  must treat that as an explicit degradation case, not a failure.

## 6. #125 alignment (constraint from epic #159)

- INV-018 — tests/workflow-scenarios/ does NOT exist at HEAD; no scenario
  schema exists yet. tests/scenario.tests.sh:4-6 covers scenario families
  A (multi-tier T-101/102/103 lifecycle), B1 (hook contract across 3 CLI
  forms), E (signing round-trip) with ad-hoc vocabulary.
- INV-019 — existing profile vocabulary is "lite"|"full"
  (task-review-precheck.sh:245-247, workflow-state registry); the epic
  mandates fixture-profile names like greenfield/brownfield for the
  harness. A1 therefore DEFINES the fixture-profile vocabulary
  (greenfield/brownfield as fixture axes, orthogonal to the lite/full
  registry profile), and #125 must adopt it — record as a design decision
  + ADR candidate, and as an explicit note for the future #125 implementer.

## 7. CI wiring

- INV-020 — .github/workflows/test.yml: 3-OS matrix
  [windows-latest, macos-latest, ubuntu-latest]; pwsh steps invoke .ps1
  suites directly (lines 32, 79-110); bash steps run with tee-to-log
  (lines 122-203); POSIX-conditional guards at lines 117, 150. New suites:
  add .sh to the run-all.sh array, add .ps1 to the pwsh step (and run-all
  pwsh block precedent from guard-r10-port at run-all.sh:64-71).

## 8. Cross-host surfaces

- INV-021 — hook execution paths differ per host: Claude Code uses
  plugins/sdd-quality-loop/hooks/claude-hooks.json (node exec form);
  Codex uses hooks.json (sh dispatcher → .py/.ps1). The loop driver itself
  is host-neutral (.sh/.ps1 separate implementations, no in-script host
  branching); host coverage is achieved by the twin pair + CI matrix, and
  the Codex-side degradation notes are documentation-level.

## 9. Round>1 coverage baseline

- INV-022 — with coverage today: spec-review rounds 2→3
  (tests/spec-review-loop.tests.sh:156-180); impl-review round-2
  regression added by 2d8c6a5 inside tests/review-agent-isolation.tests.sh.
  WITHOUT dedicated round>1 coverage: task-review (beyond precheck unit
  tests), quality-gate escalation chaining, terminal-tier recurrence
  (only cross-model integration), domain-review (no suite in run-all at
  all). This gap list is the acceptance surface for A3's suite.

## Open Questions (for the spec author / human)

- OQ-1 (A1): how should skill-instruction-enforced caps (wfi-audit
  Audit-Attempt, HITL 5) be represented in loop-inventory.json so the
  registration-forcing test neither misses them nor false-positives?
  (Proposed: cap_source field; see INV-004.)
- OQ-2 (A1/#125): confirm greenfield/brownfield as the fixture-profile
  vocabulary that #125 must adopt (INV-019 proposal).
- OQ-3 (A3): is domain-review round>1 driving in scope for the
  loop-consistency suite, or deferred (no domain suite exists in run-all
  today — INV-022)?
- OQ-4 (A4): terminal-tier resume has no dedicated .tests.sh; A4's
  escalation leg would become its first direct driver — confirm that
  scope inclusion.
- OQ-5 (A3): task-review-precheck.sh:219-222 references impl-review
  artifacts in require_persisted_pass for stage "impl" — confirm intended
  cross-stage dependency semantics before encoding the bidirectional
  invariant for task-review.
