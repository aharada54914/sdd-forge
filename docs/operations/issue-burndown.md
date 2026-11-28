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
| 3 | #969 | #835, #823, #826, #829, #841, #845, #846, #847, #849, #819 | merged (067aaf7); also added publish-release.yml |
| — | publish-release | v2.1.1 tag + Release | ad19ec42, release.yml signed artifacts attached |
| 4 | #970 | #869, #870, #866, #867, #868, #863, #864, #817, #814, #820 | merged (e848b32) |
| — | #971 | release v2.1.2 | merged (520469d); tagged via publish-release.yml |
| 5 | #972 | #815, #816, #818, #827, #830, #809, #811, #862, #834 | merged (f95bf9f) after 5 independent reviews |
| 6 | #972 | #831, #832 | merged with batch 5 (f95bf9f) |
| — | #973 | release v2.1.3 | merged (484cbe7); tagged via publish-release.yml |
| 7 | #974 | integrates `codex/mcp-ddd-next-action`: closes #871–#965 (each mapped to its passing MCP test); refs the 13 `[監査60]` issues | merged (8052dbf) after 2 independent reviews; owner approval now required on main |
| 8 | #975 | #865, #848, #803, review follow-ups on #974 (`.ps1` evidence-checker parity, v1 signature order, concept-test messages) | merged (3497bb1) |
| — | #977 | release v2.1.4 (+ #850 branch-protection docs) | merged (fa60bc5); tagged via publish-release.yml |
| 9 | #978 | #804 (pre-publish domain-contract validator enforces the full v2 schema in .sh and .ps1) | merged (34f777f) after independent review |
| 10 | #979 | follow-ups: gate EISDIR on a spec path that is a directory; publish-release green-run filter | merged (275f0f9) after independent review |
| — | #980 | release v2.1.5 | merged (2db182a); tagged via publish-release.yml |
| 11 | #981 | #812 workaround + reproduction test (full fix deferred: Draft T-001 on `codex/n14-package-spec`) | merged (dc009c7) |
| 12 | #982, #983, #984 | adopt skill path; v1 Concept Test records retired (owner decision, Breaking); leftover v1 approval names the file | merged (bad6aff, 52c68f4, e0de8d6) after independent reviews |
| 13 | #987 | follow-ups: MCP Done evidence scoped by feature; domain-contract duplicate keys and pwsh date strings; critical evidence signed fields | merged (196ab89) after 7 independent review rounds |
| 14 | #989 | follow-up: a leftover v1 approval without its record blocks the gate; MCP advice says to delete it | merged (2442839) after 2 independent reviews |
| — | (next) | release after #981–#989 | waiting for the owner's version choice (v2.2.0 recommended: #983 is breaking) |

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

| #869 | v2 CLIs detect their main module by real path (guardrails-lib `isMainModule`), so linked launches run. |
| #870 | Agent table matches shipped definitions (all `inherit`); retired agents removed. |
| #866 | Adopt PR template asks for traceability.md only where it exists. |
| #867 | Retired sudo / Lite tooling removed from current lists; v1 sections bannered. |
| #868 | Retrospective drafts WFIs from the canonical template with every audited field. |
| #863, #864 | Domain docs state the concept-test gate and the real effect of editing an approved model. |
| #817 | Unknown / self Blockers are reported and never scheduled; `--strict` fails. |
| #814 | Finalizer diagnostic token names its own operation. |
| #820 | Drift report lists changed IDs no amendment entry mentions. |
| #815 | CLI locks are held by `--owner` until their TTL (not the exiting CLI pid); same-owner re-acquire renews; ship passes one owner id through. |
| #816 | Scope parsing reads paths in prose, drops notes, expands braces, compares real paths; unknown Scope runs alone. |
| #818 | tasks.md baselines normalize `Approval:` and record per-task approvals: new approvals are not drift, revocations are. |
| #827 | Ticket re-verification names feature and task; ship auto-selects gate-pending features. |
| #830 | One `isApprovedValue` grammar for gate, decision view, drift and MCP. |
| #809 | Concept Test answers SKIP without `domain/` for every ship-valid feature name. |
| #811 | v1 domain-review precheck documented as same-tree only and unused by the current review. |
| #862 | Generated report classifies catalog suites against what `test.yml` really runs. |
| #834 | Files over the read cap are `UNVERIFIABLE` (listed in `unreadableFiles`), never deletions. |
| #831 | Gate records `specInputs`; MCP readiness requires them unchanged (legacy evidence only while drift is CLEAN). |
| #832 | Stale Done tasks route to a per-task gate re-run; status is never rewritten without a human. |

## Deferred (needs human decision)

| Issue | Reason |
|---|---|
| #812 | Owner decision (2026-11-25): workaround and a CI reproduction first; the full fix (`specs/native-concept-runtime/` T-001, Draft, on `codex/n14-package-spec`) waits until Codex-plugin DDD support is a goal. `tests/codex-versioned-cache.tests.py` rebuilds the cache layout; its two expected failures turn into the T-001 acceptance test. |

## Follow-ups

- Done evidence scoped by feature (batch 13): the MCP lookup skips a quality-gate report whose file name (`[<ts>-]<feature>-T-NNN.*`, longest existing `specs/` slug) or first `Feature:` identity line (bare, bulleted or bold; not quoted or fenced) names another feature. Reports with neither still count (legacy); in this repo `sql-development-flow` T-002 and `shared-review-launch-repair` T-002 still resolve to such a report (`2026-06-23T001628Z-T-002.md`, a `claude-workflow-compatibility` review). Review minors left: an own report whose first `Feature:` value is not exactly the slug (empty, `Own`, `own (rework)`) is excluded (fails closed); `| Feature | x |`, `## Feature: x` and a Feature-less report in `reports/quality-gate/<other>/` still count.
- Release tags: the session's git proxy refuses tag pushes (HTTP 403). After a release PR merges, dispatch `publish-release.yml` (version + release merge commit), which creates the tag and Release and runs release.yml.
- Batch-3 re-review minors: flow-style ticket targets fixed in batch 4. Still open: Scope bullets like `path(note)` / `dir/{a,b}` are labelled out of scope (labels only).
- publish-release review minor (open): document recovery when a run fails after the tag is created. The green-run count and event filter are fixed (batch 10).

- Method (since batch 2): pstack (`michael-denyer/pstack-claude` @66181d3c) poteto-mode Bug fix playbook; failing test committed before the fix; independent `thermo-nuclear-review` before merge for guard / gate / Done-evidence changes.
- `docs/contributor/coding-standards/audit/*.json` still name the pre-rename `hooks/hooks.json` (historical audit records, nothing executes them).

- Batch-4 review minors: a hand-edited baseline without the per-file `amendmentCount` treats every amendment as new; an amendment inserted above older ones in the same file shifts which entries count as new. Ranges like `T-002..T-005` in Blockers are not expanded (prose, ignored as before).
- Release-suite drift, resolved 2026-11-28 (owner decision: delete): `tests/bump-version-gate.tests.sh`/`.ps1` and `tests/release-config-lock.tests.sh` were removed. They failed on main with v1-era expectations and no runner or CI job invoked them; the v2 release path is covered by `scripts/bump-version.sh` and `publish-release.yml`.

- Batch-5 review (accepted trade-off, owner decision 2026-11-28: keep as a warning): a task approved after the baseline is surfaced (drift Markdown, gate `APPROVED_AFTER_BASELINE`), not blocked; a shell self-approval is caught only by the independent review and CODEOWNERS. A signed approval record would make it deterministic; not planned.
- Batch-5 review minors: a prose Scope directory without extension or trailing slash (`- src/lib を更新`) yields no path, so the gate labels every file in scope for that task.
- Workable issues: none left after batch 6. Everything open is Deferred (owner decision or the owner's local branches).
- Review-5 minors on #972: a failed write after the no-hard-link fallback's exclusive create leaves an empty lock (fails closed, needs --break-stale); on Windows FAT `linkSync` may report `EISDIR`, which the fallback list lacks (unverified); the pre-existing --break-stale restore path (`linkSync(claim, lock)`) has no no-hard-link fallback; evidence inputs do not bind lazy unindented continuations, bold-label paragraphs, or heading bodies of IDs that also have a bullet elsewhere (all pre-existing; document in skill reference).
- `tests/install.tests.ps1` still carries the same v1-era expectations fixed in the bash twin (sdd-lite, MCP default placement, Node 26.13 floor, Claude hook preflight). It is not wired into CI yet; porting needs a PowerShell runtime to verify.
- Audit-60 issues referenced by #974: all 13 closed. #805–#808, #813, #836, #839, #842, #854, #856 verified on main (2026-11-25); #810, #853, #860 verified on a real host (2026-11-26, Claude Code 2.1.332 `claude -p` with `--plugin-dir`): adopt writes only shipped public commands, ship without AGENTS.md points to `/sdd-bootstrap:bootstrap adopt`, and the v2 A/B domain review writes `reports/domain-review/latest.md` (NEEDS_FIX keeps `Pending`).
- Main ruleset "Protect main branch": 1 approving review, with an always-bypass for the admin role (agent merges through the API pass). The 2026-11-25 merge failures on #974 were GitHub 5xx errors, not the ruleset.
- Batch-8 review Low 4, fixed in batch 13: critical bundles must carry the signed fields (`task_id`, `feature`, `risk`, `required_workflow`, `spec_revision`, `git_commit`) as strings or leave them out, on both twins (exact-case names). Pre-existing, not in CI: `tests/python-input-boundaries.tests.py` (4 failures), `tests/gates.tests.sh` (3, H-02 retired generator), `tests/scenario.tests.sh` (needs `xxd`), `tests/template-validator-parity.tests.sh` (retired `sdd-lite`).
- Found while fixing #804, fixed in batch 13: `validate-domain-contract` rejects duplicate member names (`V2-DUPLICATE-KEY`, both twins), and the `.ps1` twin keeps ISO-date-like strings as strings on pwsh 6.0–7.4. Still open there: Windows PowerShell 5.1 `ConvertFrom-Json` turns `"\/Date(...)\/"` strings into DateTime (unverified, no 5.1 runtime here). `tests/current-byte-capture.tests.py` fails on main (13 errors: retired `generate-guard-invariants.py`); not in CI.
- Real-host run of adopt (2026-11-26): `sdd-adopt` named `scripts/check-sdd-structure.sh`, which does not exist beside the skill; fixed in this batch.
- v1 Concept Test records retired for the validator, the gate and review launches that read the working tree (owner decision 2026-11-26, step 1). Step 2 (deleting the now-unused v1 signing/finalizer code) was declined by the owner; the code stays, and `review-conditional-inputs.py` still reads v1 records at a pinned historical revision and, with `--allow-v1-history`, for the provenance of passed reviews.
- `tests/workflow-state-session.tests.py` `WorkflowSession.test_real_history_dependent_state_requires_cold_check` fails on main as well (found when the suite first ran on a GitHub runner with bubblewrap, 2026-11-26): the copied `workflow-state-integrity` review records report `spec reviewer manifest input hash is stale`. CI runs only `GateAuditBinding` until the fixture is pinned to the reviewed revision.
- Fixed in batch 14: a leftover `concept-test.approval.json` with no record (working tree or index only) now blocks the gate with the validator's leftover message, and MCP advice says to delete it (then re-run the gate). Review note: review launches (`review-conditional-inputs.py` `has_concept`) still ignore an approval-only state; the gate is the stricter of the two. Batch-14 review Lows (wording only): with a v2 record and an approval both present the MCP advice is the general inspect action, not the delete action; for an index-only copy the advice says "delete" and "also in the index" where only `git rm --cached` is needed; after the approval is deleted the stale-stop rationale says "v1 record" rather than "v1 approval".
- PR #983 fourth-review Lows still open: MCP advice when no record is left ignores whether `domain/` exists; live launches now read `concept-test.md` in more cases and fail closed if it is unreadable.
