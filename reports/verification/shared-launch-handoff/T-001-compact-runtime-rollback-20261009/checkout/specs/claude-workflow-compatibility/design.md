# Design: Claude workflow compatibility

Impl-Review-Status: Pending
Feature Type: library

## Technical Summary

Use Claude Code's supported plugin conventions: skills are discovered from
`skills/<name>/SKILL.md`, plugin names namespace commands, and side-effecting
orchestration skills remain manually invoked. Add a first-class specification
review state machine ahead of the existing implementation-policy and task
reviews; no review stage accepts another stage’s reviewer output as evidence.

## Architecture

`sdd-bootstrap-interviewer` produces Phase 1 artifacts and invokes
`/sdd-review-loop:spec-review-loop`. That loop coordinates only
`spec-reviewer-a` and `spec-reviewer-b`, persists a verified verdict, and is the
sole writer of `Spec-Review-Status`. A passed status plus valid contract unblocks
`impl-review-loop`, which similarly coordinates only `impl-reviewer-a/b` and
writes `Impl-Review-Status`. That passed result unblocks Phase 2 generation and
`task-review-loop`, which coordinates only `task-reviewer-a/b`.

The three orchestrating skills remain separate on-demand skills. Reviewer agents
are read-only; only an orchestrator state machine writes reports and status
fields. Shell and PowerShell prechecks form the deterministic boundary before
any reviewer is invoked. CI runs those prechecks and Claude's CLI validator;
installers use the same validator before registration.

## Components

| Component | Responsibility | Technology | New/Existing |
|---|---|---|---|
| `spec-review-loop` | Review Phase 1 requirements and acceptance criteria; gate implementation-policy review | Markdown skill + portable prechecks | New |
| `spec-reviewer-a/b` | Independent specification completeness and acceptance/risk reviews | Read-only agent definitions | New |
| `impl-reviewer-a/b` | Independent structural and implementability reviews | Read-only agent definitions | Existing, isolation strengthened |
| `task-reviewer-a/b` | Independent task-structure and quality/risk reviews | Read-only agent definitions | Existing, isolation strengthened |
| Review contracts | Persist hashes, reviewer provenance, stage verdicts, and attempts | JSON | New/extended |
| Claude manifests | Declare supported plugin components only | JSON | Existing, corrected |
| CI and installers | Validate manifests and review gates across hosts | GitHub Actions, Bash, PowerShell, Claude CLI | Existing, extended |

## Review Agent Isolation Contract

| Stage | Only permitted reviewers | Raw-report access | Permitted bridge | Status writer |
|---|---|---|---|---|
| Specification | `spec-reviewer-a`, `spec-reviewer-b` | Neither may read any `reports/*-review/**/reviewer-*.json` outside its own report target | Same-stage integrated summary: check IDs and counts only | `spec-review-loop` |
| Implementation policy | `impl-reviewer-a`, `impl-reviewer-b` | Same prohibition, including spec/task outputs | Same-stage integrated summary: check IDs and counts only | `impl-review-loop` |
| Task decomposition | `task-reviewer-a`, `task-reviewer-b` | Same prohibition, including spec/impl outputs | Same-stage integrated summary: check IDs and counts only | `task-review-loop` |

Each reviewer is a distinct agent file and is invoked in a fresh context. No
reviewer definition or execution context may be reused across stages or between
reviewer A and B. Every reviewer contract records its role, fresh run identifier,
distinct host-session identifier, stage-specific allowed-input manifest, and
SHA-256 hashes of the exact input artifacts. The host runtime is responsible for
fresh-agent isolation; the plugin enforces declared paths and structural tests,
but does not claim to sandbox a hostile local process.

## Specification Review State Machine

`spec-review-loop` requires `requirements.md` with
`Spec-Review-Status: Pending` and `acceptance-tests.md`; `design.md` and
`investigation.md` are optional context. It validates a slug matching
`^[a-z0-9][a-z0-9-]*$` and positive integer attempt/round values before it
creates `reports/spec-review/<feature>/attempt-<M>/round-<N>/`.

For each round, the orchestrator writes a precheck result with input hashes,
starts fresh reviewer A, writes a counts-and-IDs-only integrated summary, starts
fresh reviewer B, and writes the integrated verdict and contract. A clean PASS
sets `Spec-Review-Status: Passed`; after round three only Minor findings may
produce a contract with `verdict: PASS` and nonzero `warningCount`; downstream
gates accept that same PASS verdict. Major/Critical findings produce NEEDS_WORK
through round two and BLOCKED at round three. Re-invocation after a human edit
requires `--edit-summary`; `--reset` archives the attempt by starting a new
numbered directory and restores Pending. The orchestrator never waives findings.

`impl-review-loop` and `task-review-loop` prechecks must independently verify a
valid predecessor contract and matching PASS status, rather than trusting a
header string. All three state machines reject forged/malformed contracts and
must not write a report before prerequisite and input validation succeeds.

| Current state | Invocation | Result | Next state / write rule |
|---|---|---|---|
| Pending, no attempt | normal | clean PASS | Write `(M=1,R=1)` contract and set Passed atomically |
| Pending, no attempt | normal | any finding | Write `(M=1,R=1)` NEEDS_WORK; retain Pending |
| Pending, `(M,R=1)` NEEDS_WORK | `--edit-summary` | clean PASS / any finding | Write only `(M,R=2)`; set Passed only for clean PASS, otherwise retain Pending with NEEDS_WORK |
| Pending, `(M,R=2)` NEEDS_WORK | `--edit-summary` | clean PASS / Minor-only / Major/Critical | Write only `(M,R=3)`; set Passed for clean PASS or Minor-only `PASS` with warnings, otherwise write BLOCKED |
| Pending, `(M,R=3)` Major/Critical | normal | any | Reject; only `--reset` is permitted |
| Passed | normal | any | Reject unless explicit reset restores Pending |
| Any failed attempt M | `--reset` | valid input | Preserve prior attempt, take an exclusive lock, start `(M+1,R=1)` |

`attempt` identifies a preserved review cycle; `round` identifies the sequential
review within that attempt. A contract uses only `PASS`, `NEEDS_WORK`, or
`BLOCKED` as its verdict; `warningCount` distinguishes a round-three Minor-only
PASS without creating a second downstream-success verdict.

The state machine rejects a pre-existing destination, symlinked report root,
replayed or skipped round, concurrent writer, and PASS contract whose recorded
input hashes do not match current canonical input bytes. Paths are normalized
before containment checks and no failed transition overwrites prior evidence.

## Compatibility Design

1. Keep `skills: ["./skills/"]`; it is accepted by the current Claude CLI and
   preserves `/sdd-bootstrap:run` from `skills/run/SKILL.md`.
2. Remove invalid explicit `agents` directory arrays from Claude manifests and
   rely on supported default agent discovery. Do not change Codex/Copilot
   manifest behavior in this task.
3. Remove ignored Claude `rules` manifest fields. Move any necessary policy
   references into the owning skill's explicit required-reading path; retain
   existing source files until the supported replacement is verified.
4. Quote the WFI skill description as YAML so its metadata is retained.
5. Bump affected plugin and marketplace versions consistently so users can
   update a cached v1.1.0 installation.

## Data Plan

- **Data Entities:** No data changes.
- **Existing Data Affected:** No data changes.
- **Migration Strategy:** No migration required; this repository stores plugin
  assets and review reports, not application data schemas.

## API / Contract Plan

No API changes. The review-contract JSON files are internal file contracts, not
network endpoints; their schemas and SHA-256 provenance fields are versioned in
plugin templates and covered by repository tests.

## Security Boundaries

The feature crosses local plugin files → Claude CLI/installer and reviewer
input artifacts → review reports/status. It introduces no authentication,
authorization, credentials, or PII. Trust is limited by read-only reviewer
tools, stage-specific report path restrictions, deterministic contract/hash
validation, and the existing hook-enforced human approval boundary. A "forged"
contract means an internal artifact inconsistency (schema, stage, feature,
attempt, round, input hash, run identifier, or verdict), not resistance to
unrestricted local filesystem writes. Relevant risks are path traversal and
inconsistent status/report files; portable prechecks validate inputs before
writes and verify the contract before progression.

## Test Strategy

- **Unit:** Validate JSON/template and agent-isolation structural assertions,
  including unique names, cross-stage `disallowedPaths`, and review contract
  provenance fields.
- **Integration:** Exercise each state transition and negative precondition in
  shell and PowerShell fixtures using a shared UTF-8 fixture corpus and semantic
  JSON oracle; invoke Claude's validator once per plugin directory; test
  installer failure ordering.
- **Acceptance:** Run the OS-matrix CI suite for AC-001, AC-005, and AC-007
  through AC-010. Perform AC-002 as a documented isolated release smoke test
  because marketplace credentials are not a CI precondition.

## Deployment / CI Plan

Release corrected `sdd-bootstrap`, `sdd-quality-loop`, and `sdd-review-loop`
versions through both marketplaces only after all manifests, host manifests, and
marketplace entries agree on a version newer than 1.1.0. No feature flag is
appropriate because plugin skills are released atomically and the prior workflow
is broken. No database migration exists. CI installs a recorded Claude CLI
version, validates each plugin directory, runs portable review-precheck tests on
the full OS matrix, and retains fake-CLI tests only for installer sequencing.
The optional release smoke emits a machine-readable result containing CLI and
plugin versions, isolated install root, discovery outcome, and any skip reason.

## Architecture Decision Records

- `docs/adr/0001-independent-review-gates.md` records the selected independent
  specification-review gate and the rejected lower-assurance alternative.

## Constraint Compliance

| Requirement Constraint | Design Response |
|---|---|
| Public commands remain manual | Keep `disable-model-invocation: true` on write-capable `run` skills |
| No weakened enforcement | Preserve existing PreToolUse hooks and add deterministic predecessor verification |
| Human task approval | All future tasks remain Draft until a human approves |
| No unsupported manifest field | Gate every manifest with the real Claude CLI |
| Independent stage reviewers | Use six distinct read-only agent definitions, fresh contexts, and cross-stage raw-report denial |
| Supported OS matrix | Provide equivalent shell/PowerShell prechecks and test both |

## Assumptions

- The current report-directory layout can be extended with a sibling
  `reports/spec-review/` tree; this follows the established impl/task pattern.
- SHA-256 can be computed with portable platform-native tooling and compared
  deterministically in both precheck implementations.

## Open Questions

None. The repository maintainer selected the new `spec-review-loop` design.

## Risks

- High: a flawed predecessor check would let later stages bypass a review gate.
- Medium: manifest and installer behavior are cross-platform and user-facing.
- Medium: default agent discovery must be confirmed by the release smoke test.
