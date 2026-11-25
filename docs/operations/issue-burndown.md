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
| 8 | (this PR) | #865, #848, review follow-ups on #974 (`.ps1` evidence-checker parity, v1 signature order, concept-test messages) | open |

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
| #804 | The pre-publish validator deliberately leaves the v1-inherited shape (e.g. `contexts[].aggregates`, `meta.status` enum) to the schema; `specs/sdd-domain-concept-contract/` scopes it out (authority table, Negative-path matrix), while the Concept Test validates the full schema. Decide the pre-publish guarantee: recommended, reject everything the downstream schema check rejects, in both .sh and .ps1 (spec amendment). |
| #812 | Specified on `codex/n14-package-spec` (pushed by the owner); next to implement after #803/#804. |
| #850 | Changes GitHub branch-protection / ruleset policy (owner review, required contexts); needs the repository owner's decision. |

## Follow-ups

- Pre-existing, found by review: Done evidence accepts any `reports/quality-gate/*` file mentioning `T-NNN`, including another feature's report. Should be scoped by feature.
- Release tags: the session's git proxy refuses tag pushes (HTTP 403). After a release PR merges, dispatch `publish-release.yml` (version + release merge commit), which creates the tag and Release and runs release.yml.
- Batch-3 re-review minors: flow-style ticket targets fixed in batch 4. Still open: Scope bullets like `path(note)` / `dir/{a,b}` are labelled out of scope (labels only).
- publish-release review minors: green-run count should be regex-checked; the green check should use release.yml's event filter (push / workflow_dispatch); document recovery when a run fails after the tag is created.

- Method (since batch 2): pstack (`michael-denyer/pstack-claude` @66181d3c) poteto-mode Bug fix playbook; failing test committed before the fix; independent `thermo-nuclear-review` before merge for guard / gate / Done-evidence changes.
- `docs/contributor/coding-standards/audit/*.json` still name the pre-rename `hooks/hooks.json` (historical audit records, nothing executes them).

- Batch-4 review minors: a hand-edited baseline without the per-file `amendmentCount` treats every amendment as new; an amendment inserted above older ones in the same file shifts which entries count as new. Ranges like `T-002..T-005` in Blockers are not expanded (prose, ignored as before).
- Release-suite drift: `tests/bump-version-gate.tests.sh` and `tests/release-config-lock.tests.sh` fail on main too (v1-era expectations, not in CI). Retire or port them.

- Batch-5 review (accepted trade-off): a task approved after the baseline is surfaced (drift Markdown, gate `APPROVED_AFTER_BASELINE`), not blocked; a shell self-approval is caught only by the independent review and CODEOWNERS. A signed approval record would make it deterministic.
- Batch-5 review minors: a prose Scope directory without extension or trailing slash (`- src/lib を更新`) yields no path, so the gate labels every file in scope for that task; the gate crashes with EISDIR when a spec file is replaced by a directory.
- Workable issues: none left after batch 6. Everything open is Deferred (owner decision or the owner's local branches).
- Review-5 minors on #972: a failed write after the no-hard-link fallback's exclusive create leaves an empty lock (fails closed, needs --break-stale); on Windows FAT `linkSync` may report `EISDIR`, which the fallback list lacks (unverified); the pre-existing --break-stale restore path (`linkSync(claim, lock)`) has no no-hard-link fallback; evidence inputs do not bind lazy unindented continuations, bold-label paragraphs, or heading bodies of IDs that also have a bullet elsewhere (all pre-existing; document in skill reference).
- `tests/install.tests.ps1` still carries the same v1-era expectations fixed in the bash twin (sdd-lite, MCP default placement, Node 26.13 floor, Claude hook preflight). It is not wired into CI yet; porting needs a PowerShell runtime to verify.
- Audit-60 issues referenced by #974 (#805–#808, #810, #813, #836, #839, #842, #853, #854, #856, #860): verify each on main and close with evidence. Tests located so far: D5 `v2-mcp-server` 'D5:', D6 `v2-software-factory` 'D6:', R3/H4/N21 `v2-prompts-and-delegation` 'H4/N21/G7/R3', R6 and N12/N24 `v2-real-flows-e2e`, H5 `v2-hooks-and-ci` '(H5)', N27 MCP `dashboard.test.ts`, D4 MCP `next-command.test.ts` (sdd_feature_state path untested), H7 specs list == AGENTS list; D3 (#805) is documentation.
- Main ruleset (since 2026-11-25): 1 approving review required, stale approvals dismissed on push. Agent PRs need the owner's approval or a ruleset change (relates to #850).
- Batch-8 review Low 4: `check-evidence-bundle.ps1` renders a non-string `required_workflow` (number, array, object) differently from Python's `str()` in the signed canonical form, so such a critical bundle verifies on `.sh` only. Both v1 signers wrote strings and the generator is retired; a type check (string or absent) on both sides would close it.
