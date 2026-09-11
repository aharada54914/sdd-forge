# RT002 human-applied source verification

Date: 2026-09-12 JST
Base commit: 05683b67c57ec443bf7224e619f8bf100e62c7b0
Status: fixture verification passed; formal provenance and live activation pending.

The working tree already contained the human-applied production change to
`plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py`.
The agent did not apply or rewrite that protected file in this verification.
Its SHA-256 is
`bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5`.

The complete source diff was inspected against the RT002 contract and existing
independent advisory review. Reverse applicability of the existing
`hook-host-contract-human-20260909.patch` passed with `--check --recount`;
this command did not modify source. No new Critical finding was identified
in the bounded adapter, dispatch, JSON duplicate rejection and cleanup change.
This is not a substitute for formal independent provenance review.

Actual original-path regression runs on macOS:

- `bash tests/check-hook-activation-handshake.tests.sh`: 401 passed, 0 failed,
  exit 0; full log `/tmp/sdd-pr400-handshake-20260912.log`.
- `pwsh -NoLogo -NoProfile -File tests/check-hook-activation-handshake.tests.ps1`:
  401 passed, 0 failed, exit 0; full log
  `/tmp/sdd-pr400-handshake-pwsh-20260912.log`.
- `git diff --check`: exit 0.

The remote base's CI run 34565408704 still executes the old production code
and reports 190 passing / 211 failing handshake assertions. A new commit
needs its own CI; local results do not turn that failed run into success.
Workflow validation additionally rejects implementation verdict provenance for
`epic-136-phase4-docs` and `epic-189-a1-project-context`. The MCP live repository
assertion returns `cannot-determine`; retest after repairing workflow evidence.

This checkpoint does not activate the installed adapter, change any review or
task verdict, close an Issue, or authorize merge with failing checks. A fresh
actual host dispatch and original installed-path verification remain required.
