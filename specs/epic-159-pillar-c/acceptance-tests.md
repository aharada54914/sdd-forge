# Acceptance Tests: epic-159-pillar-c

TEST IDs (TEST-001..TEST-050) are namespaced to this feature
(`specs/epic-159-pillar-c/`) and map 1:1 to AC-001..AC-050 in
requirements.md; they do not collide with any other epic-159 pillar's own
TEST numbering (different spec folder, different suite files, different CI
step names — design.md Test Strategy).

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | schema conformance | `tests/agent-capabilities-v2.tests.sh`/`.ps1`: `contracts/agent-model-capabilities.v2.json` has `schema: "agent-model-capabilities/v2"`; every model entry has non-empty `supported_efforts`, `default_effort` ∈ `supported_efforts`, `effort_control.claude-code`/`effort_control.codex-cli` ∈ {flag, frontmatter, none} | Planned |
| AC-002 | REQ-001 | TEST-002 | schema conformance | same suite: `risk_effort_matrix` = {low→low, medium→medium, high→high, critical→high}, `escalation_bump: true`; no risk key maps directly to `xhigh` | Planned |
| AC-003 | REQ-001 | TEST-003 | schema conformance | same suite: `role_defaults` present for spec-reviewer/impl-reviewer/task-reviewer/sdd-evaluator/sdd-investigator, each with minimum tier + effort | Planned |
| AC-004 | REQ-001 | TEST-004 | parity lock (two-directional) + negative canary | same suite: v1 file SHA-256 unchanged before/after; every v1 model present in v2 with identical `canonical_tier`; every v1 `efforts` value ⊆ v2 `supported_efforts`; mutated-fixture negative self-check turns red | Planned |
| AC-005 | REQ-001 | TEST-005 | document conformance | `PLUGIN-CONTRACTS.md` contains a v2 schema section (grep-based presence check) | Planned |
| AC-006 | REQ-002 | TEST-006 | byte-identical golden | `tests/agent-model-routing.tests.sh`/`.ps1`: v1-registry output (incl. legacy positional `--candidate`) identical to pre-feature baseline fixture | Planned |
| AC-007 | REQ-002 | TEST-007 | byte-identical golden + negative canary | same suite: v2-registry, no/`welded` `--effort-policy`, output identical to pre-feature baseline; mutated golden fixture proves comparison is live | Planned |
| AC-008 | REQ-002 | TEST-008 | behavior lock | same suite: `--effort-policy matrix --risk high --required-tier standard` → `sonnet` + `high` | Planned |
| AC-009 | REQ-002 | TEST-009 | behavior lock (clamp + gate) | same suite: matrix-selected effort outside `supported_efforts` clamps; escalation-bumped `xhigh` still requires `--xhigh-reason` | Planned |
| AC-010 | REQ-002 | TEST-010 | behavior lock | same suite: `--requested-effort <e>` overrides policy selection, still clamped, still `xhigh`-gated | Planned |
| AC-011 | REQ-002 | TEST-011 | behavior lock | same suite: `--role <role>` seeds `--minimum-tier` + default effort from `role_defaults` | Planned |
| AC-012 | REQ-002 | TEST-012 | JSON contract (additive) | same suite: `--host` resolves `effort_control`; `effort_source` correctly attributed per case; all pre-existing JSON keys unchanged | Planned |
| AC-013 | REQ-002 | TEST-013 | behavior lock (v1/v2 divergence) | same suite: v2 `--candidates-file` entry with omitted `effort` succeeds; v1 `--candidates-file` with omitted `effort` still rejects | Planned |
| AC-014 | REQ-003 | TEST-014 | render correctness | `tests/render-agent-frontmatter.tests.sh`/`.ps1`: unprotected Claude `.md` targets get only the `model:` line rewritten + `x-sdd-effort:` inserted/refreshed, sourced from `role_defaults` | Planned |
| AC-015 | REQ-003 | TEST-015 | render correctness | same suite: Codex `.toml` targets get `# x-sdd-model:`/`# x-sdd-effort:` comment lines | Planned |
| AC-016 | REQ-003 | TEST-016 | drift detection + CI wiring | same suite: `--check` performs no write, exits non-zero on injected drift, wired into CI and `tests/validate-repository.ps1` | Planned |
| AC-017 | REQ-003 | TEST-017 | no-op proof | same suite: render against real, current production files (seeded `role_defaults`) produces zero diff on every unprotected target | Planned |
| AC-018 | REQ-003 | TEST-018 | exclusion lock | same suite: `model: inherit` agents and role-map-absent agents are untouched by any render (file mtime/hash unchanged) | Planned |
| AC-019 | REQ-003 | TEST-019 | protected-file boundary (positive) | same suite: the four protected reviewer `.md` files are never opened for write by the render path; corrected content lands only under `specs/epic-159-pillar-c/human-copy/` with a SHA-256 manifest entry | Planned |
| AC-020 | REQ-003 | TEST-020 | protected-file boundary (read path) | same suite: `--check` against the four protected files runs unattended (no guard trip) and reports drift status correctly | Planned |
| AC-021 | REQ-004 | TEST-021 | schema conformance (additive) | `tests/emit-run-record-feature-scope.tests.sh`/`.ps1`: `schema: "sdd-run-record/v2"` when any `--effort-*` flag supplied; three new fields per role slot; all v1 fields unchanged | Planned |
| AC-022 | REQ-004 | TEST-022 | field-population lock | same suite: `effort_requested` recorded whenever its flag is supplied, any host/outcome | Planned |
| AC-023 | REQ-004 | TEST-023 | field-population lock | same suite: `effort_applied` non-null only under `effort_control: flag` + confirmed application; null otherwise | Planned |
| AC-024 | REQ-004 | TEST-024 | field-population lock (both directions) | same suite: `effort_degraded_reason` populated iff `effort_applied` is null AND a flag was supplied; never populated when `effort_applied` has a value; never empty when it should be populated | Planned |
| AC-025 | REQ-004 | TEST-025 | backward compatibility | same suite: a pre-feature v1 record validates successfully under the post-feature validator | Planned |
| AC-026 | REQ-004 | TEST-026 | document conformance | same suite / grep check: `implementation-report.template.md` contains `- Model:`/`- Effort:` lines; `validate-implementation-report.sh` checks presence/format only; quality-gate SKILL.md documents the same two-line requirement | Planned |
| AC-027 | REQ-005 | TEST-027 | twin existence + registration | `tests/agent-model-routing.tests.ps1` (new file) exists; both twins registered in `tests/run-all.sh`/`.ps1` and `.github/workflows/test.yml` (self-registration grep) | Planned |
| AC-028 | REQ-005 | TEST-028 | byte-identical golden + negative canary | both twins: welded-golden assertion (mirrors TEST-007) with mutation-based negative self-check | Planned |
| AC-029 | REQ-005 | TEST-029 | behavior lock | both twins: matrix `--risk high --required-tier standard` → `sonnet` + `high` | Planned |
| AC-030 | REQ-005 | TEST-030 | behavior lock | both twins: clamp case (mirrors TEST-009's clamp half) | Planned |
| AC-031 | REQ-005 | TEST-031 | behavior lock | both twins: `xhigh` gated under matrix mode including escalation bump | Planned |
| AC-032 | REQ-005 | TEST-032 | invariance lock | both twins: `terminal-tier-recurrence` output byte-unchanged | Planned |
| AC-033 | REQ-005 | TEST-033 | behavior lock | both twins: `--role sdd-evaluator` → `strong` tier floor | Planned |
| AC-034 | REQ-005 | TEST-034 | projection invariant | both twins: v1↔v2 projection cases (may share fixtures with TEST-004) | Planned |
| AC-035 | REQ-006 | TEST-035 | argv composition | `tests/run-panelist-effort.tests.sh`/`.ps1`: `run-panelist-gpt.sh`/`.ps1` `--effort <e>` present in the assembled `codex --model ... --effort ...` argv | Planned |
| AC-036 | REQ-006 | TEST-036 | argv composition | same suite: `prepare-panelist-input.sh`/`.ps1` threads a selector-derived effort value through to `run-panelist-gpt`'s `--effort` | Planned |
| AC-037 | REQ-006 | TEST-037 | argv composition | same suite: Codex-host evaluator/investigator startup path supplies `select-agent-model --host codex-cli` model+effort as `codex` CLI flags | Planned |
| AC-038 | REQ-006 | TEST-038 | drift detection | same suite: cross-check between REQ-003's rendered `.toml` reference comments and live selector output reports divergence when the two are made to differ | Planned |
| AC-039 | REQ-006, REQ-008 | TEST-039 | degradation lock | same suite: Claude Code path records `effort_applied=null` + populated `effort_degraded_reason` (mirrors TEST-024's null-path case for this specific host) | Planned |
| AC-040 | REQ-006 | TEST-040 | construction proof | same suite: a grep-based self-check over new files in this task asserts no direct LLM-invocation call is required for any assertion — all cases assert argv/JSON composition only | Planned |
| AC-041 | REQ-007 | TEST-041 | default-value lock | `tests/effort-policy-flip.tests.sh`/`.ps1` (T-007-scoped): `select-agent-model` with no `--effort-policy` flag resolves to `matrix` post-flip | Planned |
| AC-042 | REQ-007 | TEST-042 | no-op / diff-investigation proof | same suite: first production `role_defaults` render post-flip is zero-diff, or a documented cause is recorded if not | Planned |
| AC-043 | REQ-007 | TEST-043 | document conformance | grep-based check: `USERGUIDE.md`, `docs/agent-capability-matrix.md`, `CHANGELOG.md` describe the matrix-default policy | Planned |
| AC-044 | REQ-007 | TEST-044 | smoke (real run-record) | same suite: a real Codex-host run's run-record shows non-null `effort_applied` | Planned |
| AC-045 | REQ-007 | TEST-045 | prerequisite-gate proof | `git merge-base --is-ancestor 2d8c6a5 <release-commit>` succeeds; T-001..T-006 merge commits are ancestors of the release commit | Planned |
| AC-046 | REQ-007, REQ-009 | TEST-046 | process conformance | T-007's PR is distinct from any T-001..T-006 PR; its `scripts/bump-version.sh` invocation is a separate, later release from Phase 1's | Planned |
| AC-047 | REQ-008 | TEST-047 | degradation coverage audit | grep/self-check across TEST-024, TEST-039: every effort-consuming surface added by REQ-001..007 has at least one Claude Code degradation case | Planned |
| AC-048 | REQ-008 | TEST-048 | non-failure proof | same audit: no suite in this feature reports FAIL/SKIP-as-failure solely due to Claude Code's absent effort mechanism — the degraded-reason path is a PASS outcome | Planned |
| AC-049 | REQ-009 | TEST-049 | document conformance | per-task grep check: applicable REQ-009 docs updated same-PR; `CHANGELOG.md` `## Unreleased` entry present per issue (#149/#150/#151/#153/#154/#152); `validate-repository` and skill-reference count sync green | Planned |
| AC-050 | REQ-009 | TEST-050 | version-bump conformance | grep-based self-check: no version string mutation anywhere in this feature's diff outside a `scripts/bump-version.sh` invocation; T-007's release is a separate invocation from any T-001..T-006 release | Planned |

Notes:

- Every suite this feature adds or extends is red-demonstrable at the
  granularity that applies to it: TEST-004/TEST-007/TEST-028 embed explicit
  mutation-based negative self-checks; TEST-009/TEST-013/TEST-024/TEST-039
  are positive/negative field-population pairs; TEST-019/TEST-020 form a
  write-boundary positive/read-boundary proof pair rather than a single
  assertion, because "never writes" and "may read" are independently
  falsifiable claims.
- `tests/gates.tests.sh`, `tests/eval.tests.sh`, `tests/guard-parity.tests.sh`,
  and `tests/constant-parity.tests.sh` are enforcement-chain protected
  files; nothing in this feature touches them.
- TEST-001..TEST-034 (REQ-001, REQ-002, REQ-005) are fully deterministic,
  fixture-driven, and require no LLM invocation, no network call, and no
  `gh` invocation. TEST-035..TEST-040 (REQ-006) assert only assembled CLI
  argv/JSON composition — no real `codex`/LLM call is made. TEST-041..
  TEST-046 (REQ-007) are the one place a real Codex-host smoke run (TEST-044)
  is exercised, gated to T-007's own implementation-time verification, not
  to CI's deterministic lane.
- No test writes a real repository path outside its own new/edited files,
  invokes `gh`, invokes `sdd-sudo`, or emits an approval string
  (security-spec.md); the four protected reviewer `.md` files are read-only
  inputs to TEST-019/TEST-020, never write targets.
- This is contract/script/test-infrastructure work with one narrow
  documentation surface (`PLUGIN-CONTRACTS.md`, `docs/agent-capability-matrix.md`,
  `USERGUIDE.md`) and no GUI entry point; the UI integration checklist is
  not applicable (see ux-spec.md, frontend-spec.md).
