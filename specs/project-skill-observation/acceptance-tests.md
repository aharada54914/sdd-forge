# Acceptance tests: Project skill execution methods and verification observations (#594)

DRAFT. This revision follows the informal content review and recheck of 2026-10-22. Test IDs
were renumbered because no review round has bound this file yet.

Quantified issue language is expanded below into one row per branch (WFI-014).
That language is "missing/invalid/unexecuted/unavailable" and "tampering,
omission, collision, legacy input".

How the tests run:
- Every validator test runs `validate-project-skill.py` against a temporary
  execution root that the test creates. It is not a Git repository, unless a
  row says otherwise.
- Fixture text lives under `tests/fixtures/project-skill-observation/`.
- The suite is `tests/project-skill-observation.tests.py`, registered in
  `tests/verification-catalog.json`.
- Expected strings are assembled from fragments in the test source (WFI-012
  rule 2).

## Acceptance Criteria

| AC | Requirement | Observable outcome |
|---|---|---|
| AC-001 | REQ-001 | ADR-0040 names the owners. No plugin, MCP tool or status field is added. |
| AC-002 | REQ-002, REQ-004, REQ-005 | Manifest schema, discovery, closure and command shape accept the valid fixtures. Each invalid branch is rejected with its code, in the documented order. |
| AC-003 | REQ-003, REQ-006, REQ-007 | An observation is accepted only when the run, task input manifest, skill digest and source set all bind. Each binding branch has its own test. |
| AC-004 | REQ-008 | Every state is distinguished. The projection with the unchanged evaluator yields PASS for a required check only from a valid `passed` observation. |
| AC-005 | REQ-009 | Skills can neither set nor waive an obligation, and cannot change task state. |
| AC-006 | REQ-010 | A new untracked skill validates and yields trial observations with no Project Context or task manifest. Trial observations are never admissible. |
| AC-007 | REQ-011 | Non-adopter repositories are identical in bytes, structure and events. |
| AC-008 | REQ-012, NFR-003 | The CLI surface, exit codes and wrapper parity hold. |
| AC-009 | REQ-013 | The suite is in the catalog, vendored copies match, and docs are synced. |

## Test Matrix

### Manifest, discovery, closure (AC-002)

| Test ID | Scenario | Assertion |
|---|---|---|
| TEST-001 | valid committed skill | exit 0, stdout `project-skill: VALID lint-docs manifest-only` |
| TEST-002 | `--skill nope` with no such dir | `manifest-missing` |
| TEST-003 | sibling `sdd/skills/empty/` without manifest | `manifest-missing`, even for a valid `--skill` |
| TEST-004 | non-JSON manifest | `manifest-invalid` |
| TEST-005 | unknown top-level field `extra` | `manifest-invalid` |
| TEST-006 | unknown nested field in `files[]` | `manifest-invalid` |
| TEST-007 | `schema` set to `project-skill-manifest/v2` | `manifest-invalid` |
| TEST-008 | `runtime` `./bin/python` (contains a path separator) | `manifest-invalid` |
| TEST-009 | `args: ["../../outside.py"]` (outside-helper operand) | `manifest-invalid` |
| TEST-010 | shell-interpreter attempt: `runtime: "sh"`, `args: ["-c", "echo hi"]` | `manifest-invalid` (space is not allowed in `args`); `-c` alone is a literal arg after the entry, never an interpreter option |
| TEST-011 | `name` ≠ directory | `name-mismatch` |
| TEST-012 | dir `Lint` with `name: "lint"` / dir `Lint` with `name: "Lint"` | `name-mismatch` / `manifest-invalid` |
| TEST-013 | two skills offer `unit-tests` | `check-collision` for either `--skill` |
| TEST-014 | `files[].path` contains `..` (schema-valid) | `closure-escape`, not `manifest-invalid`: the path grammar is checked after the schema |
| TEST-015 | absolute path; backslash path (two fixtures) | `closure-escape` |
| TEST-016 | `entry: "../../outside.py"` | `closure-escape` |
| TEST-017 | `entry` well-formed but not listed in `files` | `closure-escape` |
| TEST-018 | symlink file inside the skill dir | `closure-escape` (POSIX; the Windows symlink case is unverified) |
| TEST-019 | symlinked subdirectory; skill dir itself a symlink (two fixtures) | `closure-escape` |
| TEST-020 | FIFO inside the skill dir (POSIX) | `closure-escape` |
| TEST-021 | nested helper `lib/check.py`, listed | VALID; ordinary directories are allowed |
| TEST-022 | listed file deleted | `closure-missing` |
| TEST-023 | omitted closure: nested helper present but not listed | `closure-incomplete` |
| TEST-024 | helper tampered by one byte | `digest-mismatch` |
| TEST-025 | precedence: unknown field plus `..` path | `manifest-invalid` (schema before path grammar) |
| TEST-026 | discovery order: two valid skills created in reverse order | each is VALID; results do not depend on creation order |

### Observation binding (AC-003)

TEST-027 sets up the base fixture: an execution root materialized from the
admitted inputs (skill closure plus one ordinary input), output roots `src/` and
`reports/project-skill-observations/T-001/run-1/` admitted in `allowed_outputs`,
and the observation at `reports/project-skill-observations/T-001/run-1/lint-docs.json`.

| Test ID | Scenario | Assertion |
|---|---|---|
| TEST-027 | valid `passed` observation in task mode | `VALID lint-docs passed` |
| TEST-028 | valid `failed` observation, `exit_code: 1` | `VALID … failed` |
| TEST-029 | unknown observation field | `observation-invalid` |
| TEST-030 | `passed` with `exit_code: 1` | `observation-invalid` |
| TEST-031 | `passed` without `started_at` | `observation-invalid` |
| TEST-032 | `not-run` carrying `exit_code` | `observation-invalid` |
| TEST-033 | observation not at its exact per-run evidence path (e.g. `reports/project-skill-observations/x.json`) | `observation-invalid` |
| TEST-034 | `task_id` `T-1` (does not match `T-NNN`) | `observation-invalid` |
| TEST-035 | `check_id` not in the manifest | `skill-mismatch` |
| TEST-036 | manifest edited after observation, closure still consistent | `manifest-digest-mismatch` |
| TEST-037 | task mode without `--task-input-manifest` | `input-required` |
| TEST-038 | trial mode with `--task-input-manifest` | `input-required` |
| TEST-039 | input manifest bytes ≠ `task_input_manifest_sha256` | `input-unbound` |
| TEST-040 | supplied manifest fails its schema | `input-unbound` |
| TEST-041 | duplicate input path with different digests | `input-unbound` |
| TEST-042 | `allowed_inputs` path under the `allowed_outputs` entry `sdd/` | `input-unbound` |
| TEST-043 | closure file missing from `allowed_inputs` | `input-unbound` |
| TEST-044 | path-only trust: correct path listed with a stale digest | `input-unbound` |
| TEST-045 | `allowed_outputs: ["src/", "reports/project-skill-observations/T-001/run-1/"]` and new output `src/new.py` | VALID; directory-form outputs keep the existing semantics and admit the per-run evidence path |
| TEST-046 | `run_id` mismatch; `task_id` mismatch (two fixtures) | `run-mismatch` |
| TEST-047 | `source.commit` set to another 40-hex value; set to `null` (two fixtures) | VALID both; commit is a provenance claim, never compared or treated as approval |
| TEST-048 | existing output file `src/a.py` edited after the observation | `source-mismatch` |
| TEST-049 | new output `src/new.py` present at observation, then changed by one byte | `source-mismatch` |
| TEST-050 | new file added under output root `src/` after the observation | `source-mismatch` |
| TEST-051 | a second evidence file written in the run's evidence directory after the observation | VALID (evidence-only directory excluded) |
| TEST-052 | observation destination not covered by `allowed_outputs` (outputs only `["src/"]`) | `input-unbound` (unadmitted destination) |
| TEST-053 | an `allowed_inputs` entry under `reports/project-skill-observations/` (tracked or not, two fixtures) | `input-unbound` (evidence cannot be input) |
| TEST-054 | git-ignored admitted non-closure input `fixtures/private-case.json` changed after the observation | `input-unbound` (rehashed against its pin despite ignore status) |
| TEST-055 | unrelated ignored cache `node_modules/x` (neither admitted input nor under an output root) changed | VALID; documented unverified-environment limit |
| TEST-056 | output `src/old.py` deleted before the observation, then the same deletion staged and committed in a Git checkout of the root; separately, a present output deleted after the observation (two fixtures) | VALID (absent paths omitted, Git/index not consulted); `source-mismatch` |
| TEST-090 | admitted input deleted after the observation | `input-unbound` |
| TEST-091 | an unreadable, unadmitted file (`secret/x`, mode 000) in the execution root | VALID; the validator reads only discovery, admitted-input, output-root and observation paths |

### States and projection (AC-004)

Joint tests reuse the Registry/manifest/contract fixture shape of
`tests/sdd-domain-multitarget-T-003.tests.py:36-67`. The test applies the
design.md projection, then runs the **unmodified** `evaluate-selected-plan.py`.
Reason codes are asserted exactly as the existing evaluator emits them.

| Test ID | Scenario | Assertion |
|---|---|---|
| TEST-057 | runtime missing: `unavailable`, `missing: ["python3"]` (the runtime), `runtime_path: null` | `VALID … unavailable` |
| TEST-058 | `unavailable` with empty `missing` | `observation-invalid` |
| TEST-059 | `missing` not ⊆ `requires` ∪ {`runtime`} | `observation-invalid` |
| TEST-060 | `not-run` observation | `VALID … not-run` |
| TEST-092 | runtime in `missing` but `runtime_path` non-null | `observation-invalid` (no fabricated path) |
| TEST-093 | runtime present, another prerequisite `jq` missing: `runtime_path: "/usr/bin/python3"`; same with `runtime_path: null` (two fixtures) | `VALID … unavailable`; `observation-invalid` |
| TEST-094 | `passed` with `runtime_path: null`; `not-run` with a non-null `runtime_path` (two fixtures) | `observation-invalid` |
| TEST-061 | joint: required (`required: true`) `unit-tests`, valid `passed` | `passed`; verdict equals the hand-written legacy-equivalent contract |
| TEST-062 | joint: required, valid `failed` | `failed` / `observed-failure`; `NEEDS_WORK` |
| TEST-063 | joint: required, `unavailable` / `not-run` / `manifest-only` / skill missing (four fixtures) | execution fields absent; `not-run` / `migration-pending-required`; `BLOCKED` |
| TEST-064 | joint: required, prior projection had `passes: true`, then the observation becomes invalid (TEST-024 state) | after re-projection, `passes`, `exit_code`, `evidence`, `command` and timestamps are all absent; result is not `passed`; `BLOCKED` |
| TEST-065 | joint: optional unregistered check absent from the contract | plan check set and verdict identical to a run without the skill |
| TEST-066 | joint: optional unregistered check present with `required: false`, valid `passed` projected | `not-applicable` / `legacy-optional-not-selected`; verdict unchanged |
| TEST-067 | joint: selected Registry gate whose verifier file is missing, valid `passed` projected | `unavailable` / `verifier-missing`; `BLOCKED` |
| TEST-068 | joint: tier-required id with no `required: true`, valid `passed` projected | `unknown` / `migration-pending-required`; `BLOCKED` |

### Obligation immutability (AC-005)

| Test ID | Scenario | Assertion |
|---|---|---|
| TEST-069 | manifest `"required": false`; manifest `"required": true` (two fixtures) | `manifest-invalid` |
| TEST-070 | manifest with `approval` field; with `status` field (two fixtures) | `manifest-invalid` |
| TEST-071 | joint: skill offers protected `unit-tests`; contract sets `required: false` without `waiver_reason` | evaluator and legacy errors identical to the same contract without the skill; `BLOCKED` |
| TEST-072 | projection keeps `id`, `required` and `waiver_reason` bytes | the projected contract differs from the input only in the six execution fields |

### Trial (AC-006)

| Test ID | Scenario | Assertion |
|---|---|---|
| TEST-073 | no `sdd/project-context.yaml`, new untracked skill in a directory that is not a Git repository, no task manifest | `VALID … manifest-only`; a `trial` passed observation gives `VALID … trial-passed` |
| TEST-074 | trial skill helper edited after the observation | `digest-mismatch` |
| TEST-075 | trial observation carrying `run_id` | `observation-invalid` |
| TEST-076 | joint: `trial-passed` projected onto a required check | execution fields absent; `not-run` / `migration-pending-required`; never `passed` |
| TEST-077 | project file outside the closure changed after a trial observation | `VALID … trial-passed`; trial binds the closure only (documented limit) and stays inadmissible (TEST-076) |
| TEST-095 | second local trial for the same skill/check | may replace its own trial observation; new result remains inadmissible under TEST-076; existing task evidence is unchanged |

### Non-adopter compatibility (AC-007)

| Test ID | Scenario | Assertion |
|---|---|---|
| TEST-078 | non-adopter selected-plan | existing selected-plan fixtures give output bytes identical to `07ed2e98` for the same input bytes and evidence paths; no re-captured goldens |
| TEST-079 | non-adopter structure | `git diff 07ed2e98 -- contracts/` touches no existing schema; vendored copies identical |
| TEST-080 | non-adopter events | run unchanged, asserting each fixture has no `sdd/skills/`: `tests/emit-run-record-feature-scope.tests.{sh,ps1}` (byte lock normalizes only `run_id`/`generated`, `.sh:348-366`), `tests/loop-consistency.tests.{sh,ps1}` (golden `.sh:447`, `.ps1:413`), `tests/loop-escalation.tests.{sh,ps1}` (goldens `.sh:725,741`, `.ps1:607,616`); no broader normalization is added |
| TEST-081 | legacy input | old verification contracts with free-form `evidence` paths evaluate exactly as before; no observation parsing is triggered |

### CLI and parity (AC-008)

| Test ID | Scenario | Assertion |
|---|---|---|
| TEST-082 | unknown flag `--force` | exit 2, no stdout |
| TEST-083 | `--task-input-manifest` without `--observation` | exit 2 |
| TEST-084 | determinism | TEST-027 run twice gives identical stdout, stderr and exit |
| TEST-085 | `.sh` wrapper parity | TEST-001, TEST-024 and TEST-082 via `.sh` equal `.py` |
| TEST-086 | `.ps1` wrapper parity | the same three via `/workspace/.tools/sdd-forge-dev/bin/pwsh` on Linux; mis-cased flag `--Execution-Root` rejected identically (WFI-012 rule 1); macOS/Windows unverified |

### Registration and ownership (AC-009, AC-001)

| Test ID | Scenario | Assertion |
|---|---|---|
| TEST-087 | catalog | `tests/verification-catalog.json` lists the suite; the existing catalog checker passes |
| TEST-088 | vendored copies | each new schema is byte-equal to its `plugins/sdd-quality-loop/contracts/` copy, and `$id` follows the evaluator rule (G-6) |
| TEST-089 | ownership | ADR-0040 present with its index row; no new marketplace entry; no MCP tool added |

## UI Integration Checklist

There is no graphical UI. The entry point is the validator CLI; its consumers
(#596) are out of scope.

Every test above is planned and none has been executed yet. Host and platform
rows not executed for real remain unverified.
