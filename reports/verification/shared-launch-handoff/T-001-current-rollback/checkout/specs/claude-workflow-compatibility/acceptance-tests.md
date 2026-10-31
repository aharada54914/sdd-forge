# Acceptance Tests: Claude workflow compatibility

| AC-ID | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | integration | each `plugins/*/.claude-plugin` parent directory | Planned |
| AC-002 | REQ-002 | TEST-002 | release smoke | isolated Claude marketplace install | Planned |
| AC-003 | REQ-003 | TEST-003 | unit | Claude manifest-policy assertions | Planned |
| AC-004 | REQ-004 | TEST-004 | integration | every shipped Claude skill frontmatter | Planned |
| AC-005 | REQ-005 | TEST-005 | CI integration | `.github/workflows/test.yml` | Planned |
| AC-006 | REQ-006 | TEST-006 | installer integration | Bash and PowerShell installer suites | Planned |
| AC-007 | REQ-007 | TEST-007 | workflow integration | `spec-review-loop` state machine | Planned |
| AC-008 | REQ-008 | TEST-008 | structural integration | six review-agent definitions and reports | Planned |
| AC-009 | REQ-009 | TEST-009 | cross-platform integration | shell and PowerShell review prechecks | Planned |
| AC-010 | REQ-010 | TEST-010 | repository integration | host manifests and marketplaces | Planned |
| AC-011 | REQ-011 | TEST-011 | repository integration | workflow documentation | Planned |

## Acceptance Details

- **AC-001:** In the CI job that installs the recorded Claude Code version, a
  loop invokes `claude plugin validate` once for each directory containing
  `.claude-plugin/plugin.json`. Every command exits zero. An invalid-manifest
  fixture exits non-zero on Windows, macOS, and Linux.
- **AC-002:** The release-only smoke test uses isolated HOME/config/cache paths,
  installs the marketplace, runs `/reload-plugins`, and uses `claude plugin
  details` to verify `sdd-bootstrap` and `sdd-ship` are enabled and expose
  `run`. It separately verifies discovered reviewer agents after the supported
  plugin install; lack of credentials reports a documented skipped release
  smoke, never a CI pass. Its machine-readable result records the CLI version,
  plugin version, isolated install root, command-discovery outcome, and skip
  reason; a skipped result never proves discovery.
- **AC-003:** Claude-specific manifests contain no unsupported explicit agent
  directory or ignored `rules` key. Required policy text is reachable from the
  supported skill/reference path.
- **AC-004:** Every shipped `plugins/**/skills/**/SKILL.md`, including the WFI
  audit skill, parses without warnings or dropped `name` or `description`
  metadata.
- **AC-005:** A changed manifest that is invalid fails the real validation job
  on every existing OS matrix entry. The CI version is recorded in output or a
  pinned setup input.
- **AC-006:** A selected invalid manifest causes each applicable installer to
  fail before any corresponding `claude plugin marketplace add` or
  `claude plugin install` command. Documentation contains validation,
  `plugin list`, update/reinstall, and `/reload-plugins` recovery commands.
- **AC-007:** `spec-review-loop` accepts only requirements with
  `Spec-Review-Status: Pending`, writes immutable input hashes plus
  precheck/reviewer/summary/verdict/contract artifacts under
  `reports/spec-review/<feature>/attempt-<M>/round-<N>/`, and changes the
  status to Passed only after a valid merged PASS. It covers clean PASS,
  NEEDS_WORK followed by human `--edit-summary` from `(attempt M, round R)` to
  `(attempt M, round R+1)`, third-round BLOCKED for Major/Critical findings,
  and `--reset` archiving to `(attempt M+1, round 1)`. A round-three result
  containing only Minor findings emits contract `verdict: PASS` with a nonzero
  `warningCount`, so downstream gates accept the same PASS contract. It rejects
  replay, skipped rounds, a stale
  PASS after reviewed-input edits, concurrent writers, and pre-existing or
  symlinked destination directories without overwriting evidence. A Pending,
  inconsistent, missing, malformed, or non-PASS predecessor contract blocks
  impl/task review before report writes.
- **AC-008:** Repository tests verify six unique reviewer definition names;
  read-only tool declarations; stage-specific report paths; fresh-context
  invocation language; and `disallowedPaths` that prohibit all cross-reviewer
  raw reports. Reviewer B sees only an integrated summary containing check IDs
  and counts. Canary raw-report paths, path traversal, and symlinked report
  roots are rejected. Each review contract records reviewer role/run identifiers,
  a host-session identifier, a stage-specific allowed-input manifest, and input
  SHA-256 values. Fixtures verify that all six session identifiers differ and
  reviewer B receives only its canonical inputs plus the permitted summary.
- **AC-009:** POSIX shell and PowerShell prechecks perform equivalent valid,
  missing-status, inconsistent-contract, invalid-slug, and non-positive
  attempt/round checks on Windows, macOS, and Linux. A shared UTF-8 fixture
  corpus and semantic JSON oracle verify normalized paths and contracts. Invalid
  input exits non-zero without creating report files outside or inside the
  report root.
- **AC-010:** The Claude, Codex, and Copilot manifests for `sdd-bootstrap`,
  `sdd-quality-loop`, and `sdd-review-loop`, plus both root marketplace entries,
  share a release version greater than 1.1.0. Repository tests assert version
  consistency and recovery documentation is present.
- **AC-011:** The bootstrap interviewer, root README, workflow guide, skill
  reference, and troubleshooting documentation name
  `/sdd-review-loop:spec-review-loop` before implementation-policy review and
  describe the independent specification, implementation-policy, and task
  review stages.
