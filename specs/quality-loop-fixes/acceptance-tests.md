# Acceptance Tests: quality-loop-fixes

TEST IDs (TEST-001..TEST-030) are namespaced to this feature
(`specs/quality-loop-fixes/`) and do not collide with any other spec
folder's own TEST numbering (different suite files — design.md Test
Strategy). TEST-NNN numbers match their AC-NNN counterpart 1:1
(requirements.md Acceptance Criteria).

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | unit (fixture-driven, real script) | `tests/quality-gate-cycle-limit.tests.sh`: `check-quality-gate-cycle-limit.sh`/`.ps1` invoked with 0/1 args, and with a malformed feature (uppercase, leading hyphen, empty) → usage error, exit 2, for both a valid and an invalid task id | Planned |
| AC-002 | REQ-001 | TEST-002 | unit (fixture-driven, real script) | same suite: fixture reports carrying the target task id under a DIFFERENT feature's `Feature:` line are never counted; only reports matching BOTH the word-bounded task id AND the exact anchored `Feature:` line for the invoked feature are counted | Planned |
| AC-003 | REQ-001 | TEST-003 | unit (fixture-driven, real script) | same suite: 0/1/2 feature-scoped matches → `continue`/exit 0 (three cases); 3/4 feature-scoped matches → `Escalate-Human`/exit 1 (two cases) — extends QGCL-001..005's existing boundary coverage with the feature argument threaded through | Planned |
| AC-004 | REQ-001 | TEST-004 | unit (fixture-driven, real script) — RED-demonstrable regression | same suite: a task id with 3 reports filed under feature `other-feature` and 0/1/2 reports filed under the target feature `this-feature` returns `continue`/exit 0 for all three target-feature counts — the exact RT-20260712-001 false-positive scenario, run against the UNSCOPED pre-fix script first to prove it currently returns `Escalate-Human` (RED), then against the fixed script (GREEN) | Planned |
| AC-005 | REQ-001 | TEST-005 | unit (fixture-driven, real script) | same suite: explicit sh/ps1 output+exit parity check (mirrors QGCL-011) re-run against the new 2-required-arg contract, including the new feature-mismatch usage-error branch | Planned |
| AC-006 | REQ-001 | TEST-006 | document conformance | `plugins/sdd-ship/skills/ship/SKILL.md` Step 4 prose and both invocation examples (staged copy, human-copy) describe and pass the feature argument; the staged candidate's SHA-256 matches its `MANIFEST.sha256` entry; the LIVE file is confirmed unmodified by the agent at staging time (diff against pre-staging content is empty) | Planned |
| AC-007 | REQ-001 | TEST-007 | CI/registration conformance (grep-based self-check) | same suite: grep-based self-check confirms its own basename appears in `tests/run-all.sh` and is ABSENT from `tests/run-all.ps1` (positive assertion of the combined-suite convention, cross-checked against `tests/second-approval-mask.tests.sh`/`tests/review-agent-isolation.tests.sh`/`tests/review-contract-foundation-parity.tests.sh` each also being absent); a staged `.github/workflows/test.yml` candidate + `MANIFEST.sha256` exists under `specs/quality-loop-fixes/human-copy/`; the live `.github/workflows/test.yml`'s self-check is red until the human-copy commit lands (no staged-candidate fallback) | Planned |
| AC-008 | REQ-002 | TEST-008 | unit (fixture-driven, real script) | `tests/emit-run-record-feature-scope.tests.sh`/`.ps1`: a feature-scoped report with `VERDICT: BLOCKED` on its own anchored header line is counted; a feature-scoped report with `VERDICT: PASS`/`NEEDS_WORK` is not | Planned |
| AC-009 | REQ-002 | TEST-009 | unit (fixture-driven, real script) | same suite: a feature-scoped report with NO `VERDICT:` line at all is not counted as blocked (`gate_reports.blocked` unaffected by its presence) | Planned |
| AC-010 | REQ-002 | TEST-010 | unit (fixture-driven, real script) — RED-demonstrable regression | same suite: a feature-scoped report with `VERDICT: PASS` (or `NEEDS_WORK`) on its own header line, whose BODY prose separately contains the literal substring "BLOCKED" (mirroring the real `reports/quality-gate/T-008.md` shape, INV-009), is run against the UNSCOPED pre-fix keyword-scan first to prove `gate_reports.blocked` is incorrectly incremented (RED), then against the anchored-read fix to prove it is not (GREEN) | Planned |
| AC-011 | REQ-002 | TEST-011 | test-suite coverage-gap closure | same suite: the new AC-010 fixture is a NET NEW test case added to `tests/emit-run-record-feature-scope.tests.sh`/`.ps1` (not a modification of the existing feat-a/feat-b cross-feature fixture at lines 33-57/52-57), explicitly closing the INV-010 gap | Planned |
| AC-012 | REQ-002 | TEST-012 | existing-suite regression | same suite: the pre-existing feat-a/feat-b cross-feature exclusion assertion (`gate_reports.blocked == 0` for feat-a when only feat-b's report says BLOCKED) and the `gate_total`/`max_gate_runs`/`first_pass_tasks`/severity-count assertions all stay green, unedited, after the fix | Planned |
| AC-013 | REQ-003 | TEST-013 | unit (fixture-driven, real script) | `tests/prepare-panelist.tests.sh`/`.ps1`: an `--input` directory containing files in a subdirectory (e.g. `<input>/sub/evidence.md`) has that subdirectory's file content included in the collected/sanitized bundle (proves recursion, independent of the completeness check) | Planned |
| AC-014 | REQ-003 | TEST-014 | unit (fixture-driven, real script) | same suite: a fixture implementation report with an `## Outputs` table listing 2 paths, both present in `--input` with matching SHA-256, produces a successful bundle and a printed digest (positive baseline for the completeness check) | Planned |
| AC-015 | REQ-003 | TEST-015 | unit (fixture-driven, real script) — missing-path case | same suite: a declared-outputs path absent from `--input` → nonzero exit, the gap (the missing path) is printed to stderr, and NO digest line appears on stdout | Planned |
| AC-016 | REQ-003 | TEST-016 | unit (fixture-driven, real script) — hash-mismatch case | same suite: a declared-outputs path present in `--input` but whose actual SHA-256 does not match the implementation report's declared hash → same fail-closed/gap-printed/no-digest contract as TEST-015, distinct fixture and distinct assertion | Planned |
| AC-017 | REQ-003 | TEST-017 | unit (fixture-driven, real script) — subdirectory case | same suite: a declared-outputs path that lives under `--input/sub/...` is located and hash-verified correctly (positive case combining TEST-013's recursion with TEST-014's completeness check) | Planned |
| AC-018 | REQ-003 | TEST-018 | existing-suite regression | same suite: BL-007 (fail-closed consent gate, no `Cross-Model: enabled` and no `SDD_SUDO`), BL-008 (sanitization redaction patterns), and BL-009 (`--effort` second-line contract, single-line output when omitted) assertions all stay green, unedited, after the fix | Planned |
| AC-019 | REQ-004 | TEST-019 | document/skill conformance | `plugins/sdd-quality-loop/skills/cross-model-verify/SKILL.md` contains a new step, positioned between the existing Step 1 (Consent + Sanitize) and Step 2 (Detect available panelists), stating the pre-panel readiness check and its coverage-manifest requirement | Planned |
| AC-020 | REQ-004 | TEST-020 | document/skill conformance | same file: the new step's text states explicitly that it fails closed (does not proceed to Step 2) when any enumerated coverage element is unmapped, reviewed against the exact wording at PR time | Planned |
| AC-021 | REQ-004 | TEST-021 | document/skill conformance | same file: the new step's text states explicitly that it is a no-op when the task's specification does not flag an enumerable coverage requirement, so Steps 2-5's existing flow for ordinary tasks is unchanged — reviewed, not a new automated assertion (mirrors epic-159-pillar-d's T-001 document-conformance precedent for SKILL/doc-only deliverables) | Planned |
| AC-022 | REQ-005 | TEST-022 | unit (fixture-driven, real script, portable CRLF shim) | `tests/review-contract-foundation.tests.sh` (or a new `tests/validate-review-context-crlf.tests.sh` — task-time decision) invokes `validate-review-context-set.sh` against a canonically valid fixture manifest+ledger with a `PATH`-prepended `jq` shim that appends `\r` to every `-r` invocation's stdout; asserts each of the 9 manifest single-value reads (stage/role/feature/run_id/host_session_id/sequence/previous_record_sha256/identity_ledger_sha256/task_id) survives the shim without corrupting downstream comparisons | Planned |
| AC-023 | REQ-005 | TEST-023 | unit (fixture-driven, real script, portable CRLF shim) | same suite: the same CRLF `jq` shim applied to the `@tsv` ledger batch read (lines 250-258) does not corrupt the record-hash recomputation loop — `validate-review-context-set.sh` returns `REVIEW_CONTEXT_OK` against a canonically valid ledger under the shim (this is the RED-demonstrable pair: run against the UNFIXED script first to prove `REVIEW_CONTEXT_IDENTITY: canonical identity ledger record hash is invalid` occurs under the shim, RED; then against the fixed script, GREEN) | Planned |
| AC-024 | REQ-005 | TEST-024 | unit (fixture-driven, real script, portable CRLF shim) | same suite: the CRLF shim applied to line 275's `jq -r '.allowed_input_manifest[].path'` and line 305's `jq -r '.allowed_input_manifest[] | [.path, .sha256] | @tsv'` sites individually does not corrupt the allowed-input path/hash verification loop (two sub-cases, one per site) | Planned |
| AC-025 | REQ-005 | TEST-025 | integration-level, recorded manual verification (not CI-repeated) | one-time confirmation, recorded in the Stream-4 implementation report, that `loop_validator_capability_probe` (`tests/lib/loop-driver.sh:460-519`) flips from `degraded` to `ok` on real `windows-latest` CI after the fix lands — corroborating evidence, not re-asserted by TEST-022..024's portable fixture suite | Planned |
| AC-026 | REQ-005 | TEST-026 | existing-suite regression + non-regression | same suite plus existing `tests/loop-*.tests.sh` suites: BL-010's tampered-ledger cases (wrong sequence, wrong previous hash, symlink traversal, duplicate run/session id) still fail closed with the correct coded error after the fix; `validate-review-context-set.ps1` is confirmed byte-for-byte unmodified (diff against pre-Stream-4 content is empty) | Planned |
| AC-027 | REQ-006 | TEST-027 | existing-suite regression (full baseline re-run) | `tests/run-all.sh` and `tests/run-all.ps1` (or the individual suites BL-001..BL-012 cite) are re-run in full after all 4 streams land; every Must-Preserve baseline behavior stays green except the exact BL-101..BL-105 replacements, recorded per stream in its own implementation report | Planned |
| AC-028 | REQ-006 | TEST-028 | CI resilience conformance (grep/review) | every `.sh` file any stream changes: grep-based self-check confirms no `declare -A` and no unguarded array expansion under `set -u`; every `.ps1` file any stream touches: confirmed to end with an explicit `exit N` (review-time check, mirrors `install.sh:82-83` idiom) | Planned |
| AC-029 | REQ-007 | TEST-029 | document conformance | `CHANGELOG.md`'s `## Unreleased` section contains four independent entries citing #167, #176, #166, and #179 respectively (one per stream's own commit set, not a shared block) | Planned |
| AC-030 | REQ-007 | TEST-030 | document conformance | existing `validate-repository`/skill-reference count sync CI steps (unchanged by this feature) stay green for each stream; review-time check confirms no version-literal edit exists outside a `scripts/bump-version.sh` invocation | Planned |

Notes:

- TEST-004 and TEST-010 are this feature's two central RED-demonstrable
  regression pairs: TEST-004 proves Stream 1's cross-feature false-positive
  is real (run against the pre-fix script) before proving the fix resolves
  it; TEST-010 does the same for Stream 2's body-text-"BLOCKED"
  miscounting. TEST-023 is the third RED-demonstrable pair, for Stream 4's
  CRLF corruption, using a portable `jq` shim rather than requiring actual
  Windows CI to reproduce the RED state (WFI-014 discipline: every
  branch-enumerating AC gets its own TEST, and every RED-demonstrable
  claim is actually run RED before GREEN, not merely asserted).
- WFI-014 branch enumeration is applied explicitly: Stream 4's "every
  `jq -r` site" (REQ-005) is split into TEST-022 (9 manifest single-value
  reads), TEST-023 (the `@tsv` ledger batch read), and TEST-024 (lines
  275/305, itself two sub-cases) rather than one combined assertion.
  Stream 3's "every path in the declared-outputs table" (REQ-003) is
  split into TEST-014 (present/positive baseline), TEST-015 (missing),
  TEST-016 (hash-mismatch), and TEST-017 (subdirectory), each its own
  fixture and its own assertion.
- TEST-022..024 are deliberately OS-independent: the CRLF `jq` shim is a
  `PATH`-prepended wrapper script any of the 3 CI OSes can run, so the
  defect and its fix are exercised on macOS/Linux CI as well as Windows
  CI — not gated behind `windows-latest` alone. TEST-025 is the
  corroborating, non-repeated, real-Windows-CI confirmation that the
  capability probe (`tests/lib/loop-driver.sh:460-519`, INV-018) observes
  the same fix.
- All fixtures are synthetic and mktemp-scoped: no test in this feature
  makes a live network call, reserves a REAL record against
  `reports/review-context/identity-ledger.json` (`--reserve` fixtures use
  a fixture-scoped copy of the ledger, never the real file), or invokes
  the real `gh` CLI. TEST-006/TEST-007 operate on a small mktemp
  comparison of the human-copy staging directory plus the SHA-256 in
  `MANIFEST.sha256` — never a write to the live protected targets.
- This is CI/script/skill-prose work with no user-facing entry point; the
  UI integration checklist is not applicable (ux-spec.md,
  frontend-spec.md — both N/A stubs, mirroring epic-159-pillar-d's own
  convention for non-UI features).
- TEST-019..021 are reviewed at PR time (grep/manual inspection against
  the exact wording design.md's API/Contract Plan specifies for the new
  `cross-model-verify/SKILL.md` step), matching epic-159-pillar-d's own
  precedent for documentation/skill-prose-only deliverables (verified by
  review, not a dedicated automated suite) — `cross-model-verify/SKILL.md`
  has `disable-model-invocation: true`/`user-invocable: false`
  frontmatter, so it is not independently exercisable by an automated
  test the way a script is.
