# Acceptance Tests: epic-136-phase1-guards

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | cross-runtime parity | `.ps1` guard denies protected-table writes for file-tool and shell payloads; decisions match `.py`/`.js` on the shared corpus (new `tests/guard-r10-port.tests.ps1` + shared fixtures) | Planned |
| AC-002 | REQ-001 | TEST-002 | integration | `.ps1` guard denies unauthorized `Impl-Review-Status: Passed` increment on `design.md` without a PASS verdict artifact | Planned |
| AC-003 | REQ-001 | TEST-003 | regression | `.ps1` guard allows read-only shell payloads referencing protected paths (short-circuit parity) | Planned |
| AC-004 | REQ-002 | TEST-004 | security regression (RED-first) | `cd <protected-dir> && rm <basename>` and `pushd` equivalents denied by `.py`/`.js`; RED evidence recorded before the fix (new `tests/guard-cwd-bypass.tests.sh`) | Planned |
| AC-005 | REQ-002 | TEST-005 | regression | existing guard corpus and read-only short-circuit still pass after the working-directory fix; `.py`/`.js` decision parity holds | Planned |
| AC-006 | REQ-003 | TEST-006 | unit / parity | `check-quality-gate-cycle-limit.sh`/`.ps1` return continue for 0/1/2 matching reports and Escalate-Human for 3+, word-boundary task-ID matching, absent directory = 0 (new `tests/quality-gate-cycle-limit.tests.sh`) | Planned |
| AC-007 | REQ-003 | TEST-007 | document conformance | `ship/SKILL.md` Step 4 delegates the count to the script; no prose-only counting remains | Planned |
| AC-008 | REQ-004 | TEST-008 | document conformance / workflow | a `Risk: critical` or `Security-Sensitive: true` task without `--verify` triggers cross-model verification; a `Cross-Model-Waiver:` is honored only with a co-located human `Approval: Approved` (second distinct approver), else treated as absent; absent both, the flow blocks with a task-naming diagnostic | Planned |
| AC-009 | REQ-004 | TEST-009 | document conformance | `Security-Sensitive:` trigger field, `Cross-Model-Waiver:` field (name, setter, valid-only-with-human-approval context, audit value), and the lite-track rule (critical/security-sensitive tasks are ineligible for the lite track; lite gate rejects with a diagnostic to the full track) are specified in `ship/SKILL.md` | Planned |
| AC-010 | REQ-005 | TEST-010 | configuration audit | `self-improvement.yml` permissions minimized; `id-token: write` removed or justified against the pinned action version (new `tests/self-improvement-guard.tests.sh` asserts the permissions block) | Planned |
| AC-011 | REQ-005 | TEST-011 | integration | deterministic guard step fails on an enforcement-chain diff fixture and passes on a compliant diff fixture | Planned |
| AC-012 | REQ-006 | TEST-012 | integration | with extended matcher, Bash protected-file write payload is denied and read-only Bash payload is allowed (new `tests/claude-bash-matcher.tests.sh` driving the guard with Claude-shaped payloads) | Planned |
| AC-013 | REQ-006 | TEST-013 | cross-runtime parity | malformed payloads stay denied; Claude/Codex/Copilot hook paths agree on the shared Bash corpus | Planned |
| AC-014 | REQ-005 | TEST-014 | integration | with no branch and no PR created by the session, the deterministic guard step passes vacuously (exit success) rather than erroring (fixture with empty created-ref set) | Planned |
| AC-015 | REQ-001 | TEST-015 | encoding / static | a deterministic check fails if `sdd-hook-guard.ps1` contains any non-ASCII byte or a BOM, guaranteeing Windows PowerShell 5.1 ASCII-only compatibility (new `tests/guard-ps1-ascii.tests.sh`, run in the suite) | Planned |
| AC-016 | REQ-004 | TEST-016 | integration / document conformance | the lite gate rejects a `Risk: critical` or `Security-Sensitive: true` task with a diagnostic naming the task and directing the human to the full track (lite-gate conformance) | Planned |

Notes:

- `tests/gates.tests.sh`, `tests/eval.tests.sh`, `tests/guard-parity.tests.sh`,
  and `tests/constant-parity.tests.sh` are enforcement-chain protected files;
  all new coverage for this batch lands in the new, unprotected test files
  named above so the agent can author them directly.
- TEST-004 must be committed with its RED evidence (pre-fix failing run
  output) recorded in the implementation report for the owning task.
- This is a CLI/CI hardening batch with no user-facing entry point; the UI
  integration checklist is not applicable.
