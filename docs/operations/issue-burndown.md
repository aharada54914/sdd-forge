# Issue Burndown Log

Scheduled autonomous issue resolution (every 5 hours, started 2026-11-24).
Working branch: `claude/ecstatic-dijkstra-93sy7p`. One PR per ~10 resolved issues;
a release roughly every 2 merged PRs. Issues needing a human decision (repository
settings, permissions, product judgement) are listed as **Deferred** and skipped.

## Batches

| Batch | PR | Issues | Status |
|---|---|---|---|
| 1 | #966 | #801, #802, #851, #855, #857, #858, #859, #861, #821, #825 | merged (aafd184) |
| 2 | #967 | #822, #828, #824, #833, #840, #843, #852, #837, #844, #838 | merged (c037db8) |
| — | #968 | release v2.1.1 | merged (ad19ec4); tagged via publish-release.yml |
| 3 | (pending) | #835, #823, #826, #829, #841, #845, #846, #847, #849, #819 | PR open |

## Resolved

| Issue | Summary of fix |
|---|---|
| #801 | `install.tests.sh` + shared `install-payload-check.py` realigned to the v2.1 installer contract (always-placed `sdd-forge-mcp` runtime, Node 20 floor, `sdd-lite` removal, retired Claude hook preflight); new `installers` CI job; self-improvement prompt now points at `sdd-soft-guard.mjs` / `v2-soft-guard.test.mjs`. |
| #802 | Root cause was #801's failing mandatory verification (`guards.tests.sh` missing, `install.tests.sh` failing). |
| #851 | `required-checks` runs with `if: always()` and fails unless every dependency succeeded. |
| #855 | Codex hook file renamed to `hooks/codex-hooks.json` so Claude no longer auto-loads a second copy of the guard. |
| #857 | CI installs `mcp/sdd-forge-mcp` deps and sets `SDD_REQUIRE_AJV=1`; negative envelope check added. |
| #858 | All workflow and adopt-template actions pinned to commit SHAs; regression test. |
| #859 | PowerShell structure check requires the same 3 Core v2 files as Bash; both twins run in CI. |
| #861 | `install.ps1` Cloud entry list includes `.antigravity-plugin/plugin.json`; parity test. |
| #821 | Gate task heading lookup uses the exact ID. |
| #825 | Gate records `coverage`; MCP ignores incomplete-coverage PASS artifacts for Done readiness. |

| #822, #828 | Gate change discovery uses `-z`, `core.quotePath=false` and `diff --relative`. |
| #824 | Gate normalizes `critical` to `high` via `normalizeRiskTier`. |
| #833 | `countPrimaryApprovals` no longer subtracts `Second Approval:` lines. |
| #837 | `record-final-verdict` + `finalReviews` separate from mechanical gate runs. |
| #838 | Per-attempt breakdown kept in metrics (`attemptsByTask`). |
| #840 | Guard auto-denials split from human interventions. |
| #843 | OQ blocks counted only when the OQ check stopped the run. |
| #844 | Attributions deduplicated by gate `runId`. |
| #852 | Spec Drift CI reports coverage and lists unbaselined approved features. |

| #835 | Done evidence is the independent report's first plain `VERDICT:` line; execution.json alone never counts. |
| #823 | Gate blocks on open critical/major review tickets for exactly this feature and task. |
| #826 | `run-sdd-gate --base <ref>` for tasks that committed midway. |
| #829 | Out-of-Scope changes labelled (`inTaskScope`, `scope.outOfScopeFiles`); verdict unchanged. |
| #819 | Baseline recording is idempotent (`EXISTING`); `--rerecord` for agreed re-baselines. |
| #841, #845, #846, #847, #849 | WFI auditors, template and audit-cycle skill share one vocabulary and carve-out. |

## Deferred (needs human decision)

| Issue | Reason |
|---|---|
| #850 | Changes GitHub branch-protection / ruleset policy (owner review, required contexts); needs the repository owner's decision. |
| #805, #806, #807, #808, #810, #813, #836, #839, #842, #853, #854, #856, #860 | Audit marks these "resolved in candidate, awaiting integration": the fix lives on the owner's local branch `codex/mcp-ddd-next-action` (64812dc8), which is not on the remote. Re-implementing would conflict; push that branch (or say to re-implement) to unblock. |

## Follow-ups

- Design pending (scheduled run): #831 + #832 (stale PASS evidence after a spec change needs input digests and a re-baseline policy), #834 (2 MiB read cap reported as deletion needs an IO status channel).
- Pre-existing, found by review: Done evidence accepts any `reports/quality-gate/*` file mentioning `T-NNN`, including another feature's report. Should be scoped by feature.
- Release tags: the session's git proxy refuses tag pushes (HTTP 403). After a release PR merges, dispatch `publish-release.yml` (version + release merge commit), which creates the tag and Release and runs release.yml.
- Batch-3 re-review minors (next batch): flow-style `target: {…}` tickets are skipped instead of blocking (fail-open); Scope bullets like `path(note)` / `dir/{a,b}` are labelled out of scope.

- Method (since batch 2): pstack (`michael-denyer/pstack-claude` @66181d3c) poteto-mode Bug fix playbook; failing test committed before the fix; independent `thermo-nuclear-review` before merge for guard / gate / Done-evidence changes.
- `docs/contributor/coding-standards/audit/*.json` still name the pre-rename `hooks/hooks.json` (historical audit records, nothing executes them).

- `tests/install.tests.ps1` still carries the same v1-era expectations fixed in the bash twin (sdd-lite, MCP default placement, Node 26.13 floor, Claude hook preflight). It is not wired into CI yet; porting needs a PowerShell runtime to verify.
