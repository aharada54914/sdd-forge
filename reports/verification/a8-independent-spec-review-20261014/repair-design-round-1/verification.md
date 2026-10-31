# Bounded D-001/D-002 repair evidence

Run ID: a8-d001-d002-20261014
Task Attempt Count: 1

2026-10-14, macOS owner checkout. No formal SDD gate claim.
RED: new target-contract fixture, bash checker exit 1, exact cause:
`target-contract: non-JSON stdout: ''; stderr='Unknown option: --target\n'`.
All existing fixture groups remained green.

GREEN after repair:
- bash checker: exit 0, TEST-022/023 and 9 new target assertions pass.
- pwsh checker: exit 0, same; Windows default-path branch deferred to native CI.
- bash fresh matrix, all four targets: exit 0, 22 passed / 0 failed.
- pwsh fresh matrix, all four targets: exit 0, 23 passed / 0 failed.
- git diff --check: exit 0.

Checker runs also verify read-only digests of repository/install/Codex home.
Both matrix runtimes now create only an unrelated config precondition; no
agent TOML or managed Codex block is seeded. Claude/Copilot explicitly assert
absence. All/Codex pass using installer-created assets. CLI binaries are
fixture doubles, so these results do not prove real native CLI dispatch.

WFI-023 sweep: REQ-005, check-installed-plugin-drift, Codex agent, OQ-001,
Claude/headless across requirements/design/acceptance/tasks/all four layers.
The dated design amendment governs old coverage/API and sibling references;
AC-002 now requires both producer and consumer contracts, while AC-003/004
remain unchanged. No historical Passed header, ledger, or task status changed.
Independent design round 2 is input-pinned and pending; implementation diff
review, task review, native Windows/CI and genuine T-008 proof remain separate.
