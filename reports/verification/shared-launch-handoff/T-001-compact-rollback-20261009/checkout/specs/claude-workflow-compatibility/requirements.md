# Requirements: Claude workflow compatibility

Spec-Review-Status: Pending

## Overview

Restore Claude Code discovery of SDD public and internal plugins, prevent the
same manifest regression from merging again, and make the full bootstrap review
chain executable with genuinely independent specification, implementation-policy,
and task-decomposition reviewers.

## Target Users

- Claude Code users installing SDD Forge from the marketplace.
- SDD Forge maintainers validating a release across supported CLI hosts.

## Problems

- The advertised `/sdd-bootstrap:run` command is absent because Claude Code
  rejects its plugin manifest.
- Two internal plugins required by the full workflow are rejected for the same
  reason.
- The CI registration test has a false-positive gap: it never asks Claude Code
  to validate a real plugin manifest.
- The full track requires a nonexistent `spec-review-loop`; therefore Phase 1
  cannot legitimately advance to implementation-policy review.
- Existing review prechecks document, but do not deterministically enforce, the
  prior review status and are not portable across the supported OS matrix.

## Goals

- **REQ-001**: Every shipped `.claude-plugin/plugin.json` validates with the
  recorded Claude Code CLI version used by CI. `sdd-bootstrap`,
  `sdd-quality-loop`, and `sdd-review-loop` load without an invalid `agents`
  declaration.
- **REQ-002**: Preserve the intended public commands
  `/sdd-bootstrap:run` and `/sdd-ship:run`; retain manual-only invocation for
  write-capable orchestration skills.
- **REQ-003**: Remove Claude-manifest fields that the current validator ignores
  and preserve policy guidance through supported skill/reference mechanisms.
- **REQ-004**: Fix malformed skill frontmatter so every shipped Claude skill
  under `plugins/**/skills/**/SKILL.md` retains its metadata at runtime.
- **REQ-005**: Add a CI gate that uses the real installed Claude Code CLI to
  validate every shipped Claude plugin manifest on every existing OS matrix.
- **REQ-006**: Make local installation fail before marketplace registration when
  a selected Claude plugin manifest is invalid, and document a deterministic
  recovery path (`plugin list`, update/reinstall, then `/reload-plugins`).
- **REQ-007**: Add `/sdd-review-loop:spec-review-loop` as the required Phase 1
  gate. It reviews `requirements.md` and `acceptance-tests.md`, persists an
  auditable verdict, and is the only mechanism that can set
  `Spec-Review-Status: Passed`.
- **REQ-008**: Make the specification, implementation-policy, and task-review
  stages independent. `spec-reviewer-a/b`, `impl-reviewer-a/b`, and
  `task-reviewer-a/b` must be six distinct agent definitions; every invocation
  uses a fresh context; no reviewer may read another reviewer’s raw report,
  including reports from another stage. Only an orchestrator-produced summary of
  check IDs and counts may cross from reviewer A to reviewer B in the same
  stage. Canonical input paths must be validated, and report roots must reject
  symlinks and non-owned pre-existing destinations. Each invocation contract
  must record the stage, role, distinct host-session identifier, and allowed
  input manifest so the host's fresh-context guarantee is auditable.
- **REQ-009**: Make all three review gates deterministic and portable. Their
  prechecks must validate feature slugs and numeric attempt/round values before
  writing reports, validate required predecessor status plus a valid persisted
  PASS verdict, and have functionally equivalent POSIX shell and PowerShell
  implementations. An invalid contract is one whose schema, stage, feature,
  attempt, round, input hash, run identifier, or verdict contradicts its
  associated artifacts. Resistance to a user with unrestricted local filesystem
  write access is explicitly out of scope.
- **REQ-010**: Release the corrected affected plugin versions consistently in
  the Claude, Codex, and Copilot manifests for `sdd-bootstrap`,
  `sdd-quality-loop`, and `sdd-review-loop`, plus both root marketplace
  catalogs; prove the new version is newer than 1.1.0 and document cache
  recovery.
- **REQ-011**: Synchronize the bootstrap interviewer, root README, workflow
  guide, skill reference, and troubleshooting documentation so they name
  `spec-review-loop` as the predecessor to implementation-policy review and
  describe the three independently executed review stages.

## Non-goals

- Changing Codex or Copilot agent-discovery behavior.
- Removing or weakening the SDD hook guard, approval gate, or quality gate.
- Automatically approving Draft tasks.
- Changing the lite-track policy.
- Allowing an orchestrator to waive reviewer findings or hand-write a Passed
  status.
- Defending review artifacts against a user or process with unrestricted local
  filesystem write access.

## Acceptance Criteria

See `acceptance-tests.md`.

## Roles and Permissions

Only a human may approve implementation tasks. The resulting work must retain
the existing hook-enforced approval boundary. Reviewers are read-only and cannot
change a status field; the corresponding review-loop state machine performs a
status transition only after its valid merged verdict.

## Main Workflows

1. CI installs Claude Code and validates every Claude plugin manifest.
2. A local installer validates selected Claude plugins before registration.
3. A user verifies that `sdd-bootstrap` is enabled, reloads plugins, and invokes
   `/sdd-bootstrap:run` manually.
4. Phase 1 runs `/sdd-review-loop:spec-review-loop`; only a valid PASS unblocks
   `/sdd-review-loop:impl-review-loop`, which in turn unblocks task generation
   and `/sdd-review-loop:task-review-loop`.

## Edge Cases

- Claude CLI is not installed: existing optional/required CLI behavior remains
  explicit and does not claim successful registration.
- A marketplace cache contains v1.1.0: the corrected plugin release carries a
  version update and documents update/reinstall action.
- A manifest fails validation: no marketplace registration or successful-install
  summary may be emitted for that target.
- A predecessor status is Pending, a report contract is missing or malformed,
  or a feature/attempt/round argument is invalid: the next gate stops before
  creating a report directory or changing a status.
- A pre-existing or symlinked report destination, skipped/replayed round, or
  altered reviewed input: the gate fails without overwriting evidence.

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| Local plugin installation | Existing CLI access only; no new credential handling | None | None |
| Review reports and status fields | Only review-loop orchestrator may transition a review status after verified reports | None | Preserve human task-approval boundary |
| SDD hook enforcement | Existing deterministic guard remains active | None | None |

## Assumptions

- `claude plugin validate` does not require an authenticated Claude session.
- Default agent discovery remains supported when a plugin has an `agents/`
  directory and no invalid explicit `agents` declaration; a release smoke test
  will verify this rather than treating it as proof.
- The recorded CI Claude CLI version is available on Windows, macOS, and Linux.
- The host runtime launches fresh agents and enforces each role's declared input
  allowlist; plugin checks record and validate paths but do not claim to sandbox
  a hostile local process.

## Decision

The repository maintainer selected the high-assurance option: add
`spec-review-loop` to `sdd-review-loop`; do not remove the prerequisite. The
new loop and the two existing loops must use distinct independent reviewer
definitions and context boundaries.

## Risks

- A manifest-only repair without a release/version and recovery path leaves
  users on cached broken copies.
- A review status that can be hand-written or derived from another stage’s
  report reduces the assurance the workflow advertises.
- Cross-platform precheck divergence can deadlock the workflow on a supported
  host.
