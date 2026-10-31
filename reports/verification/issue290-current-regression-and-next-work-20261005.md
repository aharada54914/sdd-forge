# Issue 290 — unchanged regression inputs and remaining work

Non-formal read-only assessment. No protected application, reservation, formal verdict, task status, or Git mutation. The tester skill limits reruns to changed inputs or a concrete unresolved test concern.

## Current verification performed

The SHA tables in `phase0-v2-full-suite-20261005.md`, `remaining-ac-and-bootstrap-20261005.md` and `independent-absence-and-readiness-20261005.md` were mechanically compared with current files: all 16 table entries matched (12 distinct paths; some schema entries repeat). The 11 path/hash rows in `reports/implementation/sdd-domain-concept-test/T-001.md` also matched, including both approval drivers, both new/extended schemas, renderer, validator, rollback driver and recorded artifacts.

The current Bash and PowerShell sidecar logs retain hashes `f5905ddfe3a54c23045c5c96f06a6faf182724086bc1e3ae512c202519e83f08` and `b2786c3e8a156cf2ccb1e6e6cd221f45b764717c3b5a6964047a811090dd0c5e`. HEAD and main still equal the full-suite record: `badbb7aa5d16114be542c33018967c58770d1a41` and `493ff5a84da4ab993dcdceb8cf5d07927ae45db1`.

Tasks raw SHA remains `8e8c8dafa256652f3ac9adb77b4adf1a54a00bbb59d549bef95970adf6470e02`; acceptance SHA remains `fb0414831b12b78a4c4f6ea32f6f25eb08fcfc9d4f33db9342750bac52eeb8d3`.

Thus no newly changed T-001 core regression input was identified. No tests were rerun this slice. Existing 113/112 sidecar, 319 v2, 183 bootstrap, 9 absence and 6 rollback successes remain earlier execution evidence, NOT new executions or full acceptance. Hash matching does not prove every transitive/environmental input unchanged. No specific new failure or environment change justified a repeat.

## Current downstream implementation and dependencies

All T-002–T-006 are Approved / Planned; T-001 remains Approved / In Progress (`tasks.md` sections T-001–T-006). Current target diffs for domain plugin, bootstrap interviewer, domain-sync tests and canonical manifest-validator twins are empty. This alone would not prove missing implementation, so the current sources were also inspected.

| Task | Declared blockers | Observed implementation / concrete next work |
|---|---|---|
| T-002 | T-001 | `plugins/sdd-domain/skills/` has only domain-interviewer/model/reverse/review-loop/sync; no concept-test skill. Next: acceptance-first four proposal classes, three relation choices, future-only and domain-byte-invariance fixtures, then read-only proposal workflow. |
| T-005 | None | `domain-sync/SKILL.md:62` still names the v1 schema; its test `:37`, `:59`, `:112` still fixes v1. Next: acceptance-first v2 and absent-domain fixtures, then single-path consumer switch; no dual loader. |
| T-003 | T-001, T-002, T-005 | Bootstrap `SKILL.md:33` immediately runs domain-sync detection; `:34–42` retains legacy skip/warning/injection flow. No concept-test token in this source. Next: real signed-validator gate before sync, fail/defer/stop downstream counts zero, baseline absent-domain before/after evidence. Existing bootstrap 183 cases do not cover this. |
| T-006 | T-002 | Three manifests use directory-based skills discovery, not per-skill lists. No concept-test skill exists yet. Next: verify actual three-host discovery/release assertions after T-002; do not invent a required per-skill manifest list or version bump. |
| T-004 | T-001, T-003, T-006 | No concept-test token in either canonical review-context validator; no target diff. Next: full md/json/sidecar/read-input admission and omission/drift/parity fixtures, then complete feature mapping from real results. |

No verification directories T-002–T-006 or feature-scoped reports for them currently exist. This is absence of feature-specific evidence, not proof that similarly numbered reports elsewhere belong to this feature.

## Smallest next workflow

1. The protected role/boundary wording candidate is still awaiting human application; use the separately inspected current candidate, not the stale helper. Follow application with full input recheck and fresh formal task-plan provenance re-review. `tasks.md:9` explicitly makes current adoption conditional on this re-binding, independent of a particular task's blocker list.
2. T-001 core regressions need no same-input rerun on this slice. Remaining T-001 work is independent review of the full implementation and evidence/lifecycle reconciliation; narrow absence/code audits and suite success do not substitute. Preserve shared bootstrap assertions as T-003 pending. Do not require final all-task quality gate before T-001 Implementation Complete (`tasks.md:53`).
3. Complete one active task at a time. Once task-plan/lifecycle conditions permit the next task, T-005 is the dependency-free concrete target above; T-002 follows T-001. T-003 waits for both. T-006 follows T-002; final T-004 waits for T-003 and T-006. This is planning, not permission to start while provenance is stale.
4. Before opening the next implementation report, resolve existing report-path ownership. The task plan names generic `reports/implementation/T-00N.md` paths, which already exist. For example T-002 is explicitly `cross-model-verification` (`T-002.md:4`), T-006 is `claude-workflow-compatibility` (`T-006.md:4`); T-003/T-004/T-005 also already exist and must not be overwritten. Select a sanctioned feature-scoped addendum/report convention or obtain a narrowly scoped task wording amendment as required; do not silently overwrite another feature's evidence or change frozen task bytes.

No newly executable missing T-001 core test was identified in this bounded comparison. Native Windows, formal quality gate, full-feature acceptance, CI and delivery remain unproven by these local records.
