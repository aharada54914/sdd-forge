# Design: workflow-state-integrity

Impl-Review-Status: Passed
Feature Type: library

## Technical Summary

Add one versioned registry and a deterministic repository-state validator with
POSIX shell and PowerShell entry points. The validator applies explicit full,
lite, or legacy policy to every first-level `specs/` directory, verifies passed
review provenance using the existing stage-contract rules, and is reused by
repository validation, CI, downstream review prechecks, and the full quality
gate.

## Architecture

1. `specs/workflow-state-registry.json` is authoritative for profile selection.
   Directory naming and missing headers never imply a profile.
2. `contracts/workflow-state-registry.schema.json` defines the versioned
   registry contract.
3. `plugins/sdd-quality-loop/scripts/check-workflow-state.sh` and
   `check-workflow-state.ps1` independently parse the same artifacts and apply
   the same rule identifiers and exit semantics.
4. Passed-stage provenance is delegated to the existing review-contract
   validation foundation; workflow-state validation composes those results with
   cross-stage ordering and task lifecycle rules.
5. Repository validation, CI, quality-gate instructions, and downstream
   prechecks call the canonical validator rather than reimplementing policy.

Dependencies flow from callers to the paired workflow-state adapters, then to
registry/schema and existing review-contract validation. The validator never
calls repository validation, CI, quality-gate, or review prechecks, so no
circular dependency is introduced.

## Components

| Component | Responsibility | Technology | New/Existing |
|---|---|---|---|
| Workflow-state registry | Enumerate every spec and declare its exact profile and bounded migration metadata | Versioned JSON | New |
| Registry schema | Reject unknown profiles, malformed exceptions, and unsafe paths | JSON Schema | New |
| Workflow-state adapters | Discover specs, validate profiles, ordering, provenance, and lifecycle state | Bash + PowerShell | New |
| Review-contract validation | Validate passed-stage identity, hashes, reviewer provenance, and verdict | Bash + PowerShell | Existing, reused |
| Repository/CI integration | Reject invalid persisted state on supported hosts | PowerShell + GitHub Actions | Existing, extended |
| Review and quality gates | Run scoped/global validation before later workflow actions | Markdown skills + scripts | Existing, extended |
| Regression suites | Exercise valid and invalid state graphs with runtime parity | Bash + PowerShell fixtures | New/extended |

## Architecture Decision Records

| ADR | Decision | Status |
|---|---|---|
| `docs/adr/0002-repository-workflow-state-integrity.md` | Use an explicit profile registry and one portable fail-closed repository invariant | Accepted |

## State Model

### Full profile

Canonical stage states are `Pending` and `Passed`.

| Spec | Impl | Task artifact/status | Allowed |
|---|---|---|---|
| Pending | Pending | `tasks.md` absent | yes, specification phase |
| Passed | Pending | `tasks.md` absent | yes, implementation-policy phase |
| Passed | Passed | `tasks.md` absent or Task Pending | yes, task decomposition/review phase |
| Passed | Passed | Task Passed | yes |
| any other ordering | any | any | no |

`tasks.md` must be absent until Spec and Impl both have valid passing
provenance. Once created and while Task review is pending, every task remains
`Approval: Draft` and `Status: Planned`. After Task validly passes, tasks may
remain Draft/Planned until human approval. Approved, In Progress,
Implementation Complete, or Done states require all three review stages to be
validly Passed. Existing evidence and quality-gate requirements for Done remain
unchanged.

A `Passed` stage is valid only when the latest completed attempt/round has a
matching passing integrated verdict and stage contract. The contract binds the
current canonical artifact hashes required by that stage. Sudo, a manually
edited header, and downstream task state never substitute for provenance.

### Legacy profile

Each legacy entry contains:

- the exact feature slug;
- `introduced_before_commit` fixed to migration baseline
  `0369c8c96de2eb3179868d1949d66644488f65aa`;
- non-empty `reason` and `owner`;
- an enumerated list of exact missing/noncanonical stages and lifecycle states;
- optional retrospective source records.

The checker compares actual state with the narrow declaration. It does not
infer, repair, or upgrade historical review status. Wildcards, unspecified
exceptions, and legacy entries introduced after the baseline are invalid.

### Lite profile

Lite entries are registry-covered but bypass the full review chain. Existing
lite-gate behavior remains authoritative.

## Frontend Plan

Not applicable. This repository feature has no frontend or user-facing browser
surface.

## Backend Plan

The backend surface is local repository tooling only. The paired scripts expose
the same command contract:

```text
check-workflow-state [--feature <slug>] [--registry <path>]
```

No flag validates the whole registered repository. `--feature` narrows
validation for downstream prechecks without relaxing registry coverage or
profile rules. `--registry` exists only for isolated tests and must still pass
schema and containment checks.

Diagnostics use:

```text
workflow-state: <feature>: <rule-id>: <message>
```

Both implementations accumulate deterministic findings where safe and exit
zero only when all applicable checks pass. Malformed input, unreadable files,
I/O failure, contract mismatch, or invariant violation exits nonzero.

## Data Plan

Data Entities: versioned workflow-state registry entries and uninstall
retrospective metadata.

Existing Data Affected: existing specification and review artifacts are read
but are not rewritten or assigned fabricated provenance.

Migration Strategy: add an explicit profile for every current first-level spec
directory, bounded at main commit
`0369c8c96de2eb3179868d1949d66644488f65aa`.

| Existing feature | Profile | Exact migration treatment |
|---|---|---|
| `claude-workflow-compatibility` | legacy | Permit the observed Pending Spec/Impl headers, Passed Task header, and Done tasks without valid predecessor contracts; no broader states |
| `cross-model-verification` | legacy | Permit missing stage headers/contracts and the observed Done task states only |
| `risk-adaptive-layer` | legacy | Permit missing stage headers/contracts and the observed Approved / Implementation Complete task states only |
| `sdd-forge-refactor` | legacy | Permit missing Spec header/contract and historical Impl/Task Passed records lacking current contracts, with observed Done tasks only |
| `sdd-lite` | lite | Continue existing lite-gate behavior; no full-review exception |
| `workflow-state-integrity` | full | Require the complete current review chain; legacy is forbidden |

Add `specs/uninstall-workflow/retrospective.md` as a source record for commit
`277a79d`, naming implementation/tests and explicitly stating that prior SDD
review provenance is unavailable. The retrospective directory is itself
registered as legacy with only the enumerated absent historical stages.

No database or application-data migration exists. Rollback is a normal Git
revert of registry/schema/checker integration before publishing v1.3.0.

## API / Contract Plan

No network API, RPC, or event contract changes. The registry is an internal
versioned file contract at
`contracts/workflow-state-registry.schema.json`; schema version `1` rejects
unknown properties and defines profile-specific required fields. Existing
review-contract formats remain unchanged.

## Discovery and Path Safety

- Enumerate immediate child directories of `specs/`; ignore nondirectory files.
- Registry keys match `^[a-z0-9][a-z0-9-]*$`.
- Resolve every registered path beneath the repository `specs/` root.
- Reject traversal, `.`/`..` segments, absolute/drive-qualified paths, duplicate
  semantic entries, escaping symlinks, missing directories, and uncovered
  directories.
- Parse JSON strictly and never execute registry or specification content.

## Integration

- `tests/validate-repository.ps1` invokes the PowerShell checker and confirms
  both adapters, schema, and registry are packaged.
- `.github/workflows/test.yml` invokes the shell checker on Unix jobs and the
  PowerShell checker on every matrix job.
- `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` runs workflow-state
  validation before `check-task-state`.
- Impl/task review prechecks run `--feature <slug>` before their existing
  explicit predecessor checks.
- Deterministic-check policy and workflow documentation state the invariant and
  bounded legacy policy.

## Test Strategy

- **Unit/fixture:** Add `tests/workflow-state.tests.sh` and
  `tests/workflow-state.tests.ps1`. Fixtures live under
  `tests/fixtures/workflow-state/` and cover every AC-001 through AC-014 rule,
  including traversal, escaping symlinks, forged/stale contracts, task
  lifecycle states, malformed JSON, unreadable files, lite isolation, and
  overbroad legacy entries.
- **Parity:** Add `tests/workflow-state-parity.tests.sh` to execute both
  adapters over a shared LF/CRLF corpus and compare normalized JSON diagnostics,
  rule IDs, and exit results.
- **Integration:** Extend `tests/downstream-review-precheck.tests.sh`,
  `tests/downstream-review-precheck.tests.ps1`,
  `tests/downstream-review-precheck-parity.tests.sh`, and repository validation
  fixtures to prove the canonical gate is called without weakening current
  preconditions.
- **Regression:** Run `bash tests/run-all.sh` and
  `pwsh -NoProfile -File tests/run-all.ps1`.
- **Retained evidence:** CI logs preserve both run-all results. The
  implementation report maps tests to AC IDs; the quality-gate report records
  exact commands, exit codes, and artifact hashes.

## Security Boundaries

| Trust Boundary | Auth/Authz Mechanism | Data Classification | OWASP Concerns |
|---|---|---|---|
| Registry/spec files → validator | Local filesystem containment and strict parsing; no auth | Repository metadata | Path traversal, injection, unsafe deserialization |
| Review reports → Passed provenance | Existing hash and reviewer-identity contract validation | Repository metadata | Forged/stale evidence, integrity failure |
| Validator → CI/gates | Exit status plus stable rule diagnostics | Build evidence | Fail-open handling, inconsistent runtime behavior |

The validator quotes paths, avoids `eval`, rejects symlink escape, and treats
malformed or unreadable artifacts as failures. The named fixture and parity
suites are the concrete verification path for these controls.

## Deployment / CI Plan

Publish the synchronized v1.3.0 plugin and marketplace manifests only after the
full Bash/PowerShell suites and repository validator pass on the GitHub Actions
OS matrix. This repository-local enforcement ships atomically with its registry
and schema; no feature flag is appropriate because partial rollout would make
the invariant host-dependent. It requires no environment variables, secrets,
service deployment, database migration, or external dependency. Release and
install behavior otherwise remains unchanged.

## Constraint Compliance

| Requirement Constraint | Design Response |
|---|---|
| Architecture changes require an ADR | Reference accepted ADR-0002 |
| API/data formats require a versioned schema | Add registry schema version 1 under `contracts/` |
| New full features cannot use legacy | Register this feature as full and bound legacy to the main baseline |
| Only quality-gate sets Done | Validator is read-only and preserves the existing Done writer |
| Six plugin versions stay synchronized | Update all plugin/marketplace manifests and validation constants to 1.3.0 |

## Assumptions

- `jq`, Bash, and PowerShell remain supported repository/test dependencies.
- Existing review-contract validators remain the source of truth for
  stage-specific contract shape and reviewer provenance.
- The migration baseline is main commit
  `0369c8c96de2eb3179868d1949d66644488f65aa`; new specs after that commit cannot
  be registered as legacy.

## Open Questions

None. The maintainer approved the registry-based refactoring plan, v1.3.0
revision, and bounded historical migration.

## Risks

- High: a fail-open or divergent adapter could permit inconsistent state.
- High: an overbroad legacy record could hide a new workflow violation.
- Medium: status-neutral hashing must not normalize fields beyond the stage
  status line.
- Medium: adding a spec directory without a registry update will intentionally
  fail repository validation.
