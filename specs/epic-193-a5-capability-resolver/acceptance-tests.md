# Acceptance Tests: epic-193-a5-capability-resolver

TEST IDs are namespaced to this feature
(`specs/epic-193-a5-capability-resolver/`) and map 1:1 to `requirements.
md`'s Acceptance Criteria by matching row number (AC-NNN ↔ TEST-NNN), with
one documented class of exception:

- **AC-035, AC-036, and AC-037 have no TEST-035/036/037 rows.** All three
  are spec-commit-bound scope-boundary statements about *this Phase 1
  package's own registration commit*, not automated implementation-phase
  tests a future `tests/*.tests.sh` suite would run — they are checked
  directly against the live repository by running the named validator
  scripts once, at registration time, mirroring
  `specs/epic-192-a4-facet-manifest/acceptance-tests.md`'s identical
  AC-036/037/038 exception (which this feature's own AC-035/036/037
  intentionally reuse the same numbering *meaning* for, one index lower,
  since this feature's own REQ list runs one item shorter than Epic A4's).
  See "Spec-Authoring-Time Manual Review Record", below.

Every other row named below is a **design-phase target**: no suite file
exists yet (`design.md`'s own Test Strategy names eight suites this
feature's future `tasks.md` schedules authoring; `Spec-Review-Status`/
`Impl-Review-Status` must both reach `Passed` first, per `AGENTS.md`'s
Required Workflow). `Status` below is `Planned` for every row unless noted
otherwise.

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | required-flag matrix | `tests/resolve-project-context-cli.tests.sh`/`.ps1`: one fixture per required flag (`--config`, `--target-rev`, `--feature`), each deleted in turn, each rejected as a usage error (exit 2); `--source-rev` omitted defaults to `HEAD` (a fixture confirms the resolved `HEAD` value is what is passed through to `resolve-component-paths`) | Planned |
| AC-002 | REQ-001 | TEST-002 | discovery-contract reuse lock | `tests/resolve-project-context-discovery.tests.sh`/`.ps1`: every `contracts/*` artifact this feature's scripts locate (Registry + its schema, Epic A4's three schemas, this feature's own `resolver-evidence.schema.json`) resolves via the identical script-relative-then-git-root-fallback procedure (ADR-0025) — a fixture confirms no environment variable of any kind is consulted at any point | Planned |
| AC-003 | REQ-001 | TEST-003 | Context Projection byte-identity lock | `tests/resolve-project-context-match.tests.sh`/`.ps1`: a `project-context.yaml` fixture's Context Projection, computed once by hand per Epic A4's own REQ-003 procedure and once by invoking the Resolver, is byte-identical (`source_sha256`/`projection_sha256` both match) | Planned |
| AC-004 | REQ-001 | TEST-004 | `resolve-component-paths` pass-through lock | same suite: a fixture asserts the Resolver invokes `resolve-component-paths` with `--config`/`--source-rev`/`--target-rev`/`--include-untracked` values byte-identical to its own received flags — no rev resolution, merge-base computation, or diff-basis logic performed by the Resolver itself | Planned |
| AC-005 | REQ-001 | TEST-005 | `registry_digest --whole` binding lock | same suite: `context_binding.registry_digest` equals `generate-registry-digest --whole`'s own output for the identical Registry — never a `--capability-ids`/`--gate-ids` fragment | Planned |
| AC-006 | REQ-001 | TEST-006 | union-match lock | same suite: a two-affected-component fixture where only one component's properties satisfy a Capability's `trigger` (e.g. `characteristics.pii: true` on one, absent on the other) results in that Capability present in `capabilities[]` | Planned |
| AC-007 | REQ-001 | TEST-007 | field-assembly conformance | same suite: `required_facets`/`conditional_facets`/`resolved_gates`/`capabilities`/`capability_minimum_enforcement`/`lite_eligibility` each populated per Epic A4's own field rules, verified against a multi-Capability fixture with at least one `minimum_enforcement: required` Capability and one without | Planned |
| AC-008 | REQ-001 | TEST-008 | Facet Manifest schema-conformance lock | same suite: the written `facet-manifest.yaml` validates via `validate-facet-manifest` (Epic A4) against a representative multi-Capability, multi-affected-component fixture | Planned |
| AC-009 | REQ-001 | TEST-009 | Capability Summary schema-conformance lock (forward-compatibility fixture) | `tests/resolve-project-context-lite.tests.sh`/`.ps1`: on a synthetic Registry extension supplying a resolvable `required_lite_checks` source, the written `capability-summary.yaml` validates via `validate-capability-summary` (Epic A4) | Planned |
| AC-010 | REQ-002 | TEST-010 | Block diagnostic-id table lock | `tests/resolve-project-context-block.tests.sh`/`.ps1`: one fixture per REQ-002/`design.md` diagnostic-id row (eight total, including `project-context-validation-failed`), each independently triggerable, plus one fully-clean fixture proving a negative (no diagnostic fires) | Planned |
| AC-011 | REQ-002 | TEST-011 | no-partial-artifact lock | same suite: for every Block fixture in TEST-010, none of `facet-manifest.yaml`/`capability-summary.yaml`/`project-context.resolved.json` exists (or, if a pre-existing file was present before the run, is byte-unchanged) after the run | Planned |
| AC-012 | REQ-002 | TEST-012 | Resolver Evidence always-emitted lock | same suite: every Block fixture in TEST-010 except `disabled-legacy-invocation` writes a full Resolver Evidence record; the `disabled-legacy-invocation` fixture writes the minimal record `design.md`'s API / Contract Plan step 1 defines | Planned |
| AC-013 | REQ-002 | TEST-013 | exit-code contract lock | same suite: `0`/`1`/`2` fixtures for success/Block/usage-error respectively, one each, confirming the mapping is fixed | Planned |
| AC-014 | REQ-002 | TEST-014 | diagnostic line format lock | same suite: every diagnostic line emitted across TEST-010's fixtures matches `capability-resolver: <check-id>: <detail>`, `<check-id>` drawn only from the fixed enum | Planned |
| AC-015 | REQ-003 | TEST-015 | `disabled-legacy` short-circuit lock | same suite (`resolve-project-context-block`): a fixture with `--config` pointing at a nonexistent path confirms no `resolve-component-paths`/Registry-discovery subprocess is ever invoked (a mock/spy harness on the subprocess boundary) before the `disabled-legacy-invocation` Block fires | Planned |
| AC-016 | REQ-003 | TEST-016 | advisory/required byte-identity lock | `tests/resolve-project-context-match.tests.sh`/`.ps1`: a fixture pair identical except `workflow.capability_enforcement` (`advisory` vs. `required`) produces byte-identical `facet-manifest.yaml`/`capability-summary.yaml`/`project-context.resolved.json`; only Resolver Evidence's own `state` field differs | Planned |
| AC-017 | REQ-004 | TEST-017 | contract existence + `$id` convention | `tests/resolver-evidence-schema.tests.sh`/`.ps1`: `contracts/resolver-evidence.schema.json` exists, is valid draft-07, and its `$id` matches every other `contracts/*.schema.json`'s convention | Planned |
| AC-018 | REQ-004 | TEST-018 | all-Capabilities-recorded lock | same suite: a fixture with one matched and one unmatched Registry Capability confirms `capability_evaluations[]` carries an entry for both, the unmatched one with `matched: false` and a non-empty `trigger_evaluations[]` | Planned |
| AC-019 | REQ-004 | TEST-019 | conditional-facet-evaluation scoping lock | same suite: a matched Capability's entry carries one `conditional_facet_evaluations[]` element per its own `conditional_facets[]`; an unmatched Capability's entry carries the key omitted entirely (schema `if`/`then`, `design.md` API / Contract Plan) | Planned |
| AC-020 | REQ-004 | TEST-020 | always-emit-on-success lock | same suite: a fully successful resolve fixture confirms Resolver Evidence is written with `diagnostics: []` | Planned |
| AC-021 | REQ-004 | TEST-021 | `validate-resolver-evidence` diagnostic-id lock | `tests/validate-resolver-evidence.tests.sh`/`.ps1`: one fixture per diagnostic-id row (`schema-invalid`, `capability-evaluation-id-duplicate`, `matched-without-evidence`), plus one clean fixture | Planned |
| AC-022 | REQ-005 | TEST-022 | repeated-invocation determinism lock | `tests/resolve-project-context-parity.tests.sh`/`.ps1`: two `.py` invocations against the identical input produce byte-identical output across all four written artifacts | Planned |
| AC-023 | REQ-005 | TEST-023 | dual-runtime parity lock | same suite: `.py`/`.sh`/`.ps1` invocations of the identical input produce byte-identical output across all four artifacts and identical stdout/stderr/exit code; includes at least one Windows-style (`\`-separated) path argument | Planned |
| AC-024 | REQ-005 | TEST-024 | stable-sort discipline lock | same suite: `capability_evaluations[]` sorted by `capability_id`; `diagnostics[]` sorted by `(id, detail)`; every Epic-A4-mandated Facet Manifest array sorted per Epic A4's own rule — a fixture with an intentionally-out-of-order Registry `capabilities[]` declaration order still produces sorted output | Planned |
| AC-025 | REQ-005 | TEST-025 | no-nondeterministic-source lock | repository-wide grep-based self-check (registration-time and CI-gated): no Resolver-owned script under `plugins/sdd-quality-loop/scripts/resolve-project-context.*` or `validate-resolver-evidence.*` calls `datetime.now()`/`time.time()`/any network primitive/any provider-API client | Planned |
| AC-026 | REQ-006 | TEST-026 | test-registration procedure proof | future `tasks.md`'s test-registration task is verified: all eight new `tests/*.tests.sh`/`.tests.ps1` pairs are registered directly (unprotected) in `tests/run-all.sh`/`.ps1`; a staged candidate for `.github/workflows/test.yml` registration exists under `specs/epic-193-a5-capability-resolver/human-copy/` with a correct `MANIFEST.sha256` entry | Planned (Status resolves through a human `cp` action for the `test.yml` portion) |
| AC-027 | REQ-006 | TEST-027 | fixture-matrix completeness lock | `tests/resolve-project-context-match.tests.sh`/`.ps1`'s own setup: confirms all five REQ-006 fixture-matrix items (match/no-match/conditional/WARN-accepted/WARN-Blocked) are present and independently invocable under `tests/fixtures/capability-resolver/` | Planned |
| AC-028 | REQ-006 | TEST-028 | installed-layout discovery lock | `tests/resolve-project-context-discovery.tests.sh`/`.ps1`: three fixtures per runtime (nine total) with only the packaged `plugins/sdd-quality-loop/contracts/*` copy present (no monorepo `contracts/`, no reachable `.git`) each resolve and validate correctly for every artifact this feature's scripts locate | Planned |
| AC-029 | REQ-007 | TEST-029 | design-content review record (no automated test) | verified directly against this package's own `design.md`/`requirements.md` text at spec-authoring time: the capability interview phase's insertion point, 15-question-per-pass budget, Open-Questions-persistence rule, and resumability rule are each present and each cites decision document v2 §18.4 directly | Planned (Spec-Authoring-Time Manual Review Record, below) |
| AC-030 | REQ-007 | TEST-030 | design-content review record (no automated test) | verified directly against `design.md`/`requirements.md`: the Context-absent case is documented as event-identical to today's existing bootstrap flow, with an explicit citation to decision document v2 §4.3's Orchestration Compatibility Test | Planned (Spec-Authoring-Time Manual Review Record, below) |
| AC-031 | REQ-007 | TEST-031 | design-content review record (no automated test) | verified directly against `design.md`/`requirements.md`: the on-Block behavior is documented with an explicit citation to decision document v2 §7's "legacy mode へ黙ってフォールバックしてはならない" principle | Planned (Spec-Authoring-Time Manual Review Record, below) |
| AC-032 | REQ-007 | TEST-032 | scope-boundary lock (registration-commit-bound) | `git diff` of this package's own two registration commits touches no path under `plugins/**` | Planned (Spec-Authoring-Time Manual Review Record, below) |
| AC-033 | REQ-008 | TEST-033 | per-task CHANGELOG lock | future implementation-phase check (run once per task landing): each landing task's diff carries its own `CHANGELOG.md` `## Unreleased` entry citing #193 | Planned |
| AC-034 | REQ-008 | TEST-034 | version-mutation self-check | repository-wide grep-based self-check (implementation-phase, run once per task landing): no version string is mutated anywhere in the diff outside a `scripts/bump-version.sh` invocation | Planned |

## Spec-Authoring-Time Manual Review Record

AC-029, AC-030, AC-031, and AC-032 (REQ-007) are design-content review
items, not automated tests: REQ-007 documents a target integration
contract for a file this package's own commits never touch
(`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`,
requirements.md Non-goals). Their content is verified by direct
inspection of this package's own `design.md`/`requirements.md` text,
recorded here once, at this package's own spec-authoring time:

- **AC-029**: `requirements.md` REQ-007 items (b)-(c) name the insertion
  point ("after track detection, before any Facet-dependent layer is
  generated") and transcribe decision document v2 §18.4's own four rules
  ("質問は既知情報を再質問しない / 適用 Capability だけ / 1 pass 最大 15
  問 / 未解決は Open Questions 保存 / 再開可能") verbatim, each cited by
  section number. Confirmed present.
- **AC-030**: `requirements.md` REQ-007 item (a) and Main Workflows'
  workflow 5 both state the Context-absent case is "unchanged, event-
  identical to today's behavior," citing decision document v2 §4.3's
  Orchestration Compatibility Test by name. Confirmed present.
- **AC-031**: `requirements.md` REQ-007 item (d) states the on-Block
  behavior and cites decision document v2 §7's "legacy mode へ黙って
  フォールバックしてはならない" principle by direct quotation. Confirmed
  present.
- **AC-032**: verified by `git diff --stat` against both of this
  package's own commits (the spec-package commit and the registration
  commit) at registration time — no path under `plugins/**` appears in
  either diff, matching this task's own hard scope boundary.

None of the four requires a `tests/*.tests.sh` suite of its own: each is a
one-shot fact about this specific package's own text and commit scope, not
a reusable, fixture-driven regression test a future code change could
break — the same reasoning `specs/epic-192-a4-facet-manifest/acceptance-
tests.md` records for its own AC-036/037/038 exception, applied here to a
design-content-review class of Acceptance Criterion instead of a
registration-command class.

AC-035, AC-036, and AC-037 (Global, requirements.md) are verified directly
against the live repository as part of this Phase 1 package's own
registration commit, not by an automated test suite:

- **AC-035** (`check-workflow-state.sh --feature epic-193-a5-capability-
  resolver` exits 0): verified after the registration commit lands the
  new `specs/workflow-state-registry.json` entry, `requirements.md`'s
  `Spec-Review-Status: Pending` header, and `design.md`'s `Impl-Review-
  Status: Pending` header, with no `tasks.md`/`traceability.md` present.
- **AC-036** (`check-sdd-structure.sh` — no feature argument — exits 0):
  verified after the registration commit, run as `sh scripts/check-sdd-
  structure.sh .` (matching the documented usage in `docs/skill-
  reference.md` and this feature's own investigation.md INV-015), which
  never enters the per-feature four-layer-file check.
- **AC-037** (registry entry shape): verified by inspecting the new
  `specs/workflow-state-registry.json` entry directly —
  `{"feature": "epic-193-a5-capability-resolver", "profile": "full"}`, no
  additional keys — and by `check-workflow-state.sh`'s own registry-shape
  `jq` assertion (which independently enforces `(keys | sort) ==
  ["feature","profile"]` for any `full`/`lite` entry) passing as part of
  AC-035's same run.

None of the three requires a `tests/*.tests.sh` suite of its own: all
three are one-shot facts about this specific package's own registration
commit, not reusable, fixture-driven regression tests a future code
change could break — the same reasoning
`specs/epic-190-a2-capability-registry/acceptance-tests.md`'s AC-034 and
`specs/epic-192-a4-facet-manifest/acceptance-tests.md`'s AC-036/037/038
each already record for their own, structurally identical exception.

- **Draft-07 metaschema conformance** (`design.md`, `contracts/resolver-
  evidence.schema.json` API / Contract Plan — matching Epic A4's own
  identical practice for its own three schemas): this feature's one new
  schema document is validated once, at this package's own spec-authoring
  time, against the official draft-07 metaschema (`http://json-schema.
  org/draft-07/schema#`), using a tool outside this feature's own future
  closed-subset hand-rolled validator (e.g. a one-off interpreter session
  or an external validator, not committed as a repository dependency,
  investigation.md INV-011). Result: conforms. This is not a reusable
  regression test for the same reason AC-035/036/037 are not: the schema
  file is content-frozen once this package's own design review passes
  (`AGENTS.md`, "Post-review artifact freeze"), so a future edit to it
  would itself be a new, reviewed change, not a silent drift this record
  needs to catch on every CI run.
