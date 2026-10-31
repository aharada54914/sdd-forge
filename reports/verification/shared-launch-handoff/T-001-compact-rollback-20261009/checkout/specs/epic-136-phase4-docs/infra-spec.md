# Infrastructure Spec: epic-136-phase4-docs

## CI/CD Sequence

**No new CI step, and no CI file is edited.** `.github/workflows/test.yml` is on `PROTECTED_GATE_SUFFIXES` (`guard-invariants.generated.js:5`) and is untouched by this feature — which also means this feature has no `human-copy` staging surface at all, unlike `epic-136-phase3`, whose CI-step addition forced the draft-then-human-apply pattern.

The existing `test` job is authoritative. `tests/run-all.sh` already registers `cross-model.tests.sh`, so the new cases in REQ-006 are picked up with no registration change. The PowerShell parity suite (`cross-model.tests.ps1`) is likewise already registered on the Windows leg.

Sequence at merge time:

1. `test` job, 3-OS matrix — runs `tests/run-all.sh`, which now includes the timeout cases.
2. No `dist/` rebuild step applies. This feature changes shell, PowerShell and Markdown only; there is no esbuild bundle in scope, so ADR-0003's same-commit rebuild obligation does not attach and `git diff --exit-code -- dist/` is not a leg of any acceptance criterion.
3. No `npm audit` interaction. No package manifest or lockfile is touched.

**Timing note that matters for CI, not just correctness.** TEST-004 runs a real process to expiry. With `SDD_PANELIST_TIMEOUT=1` plus the 2-second SIGTERM grace, each timeout case costs ~3 seconds of wall-clock, and the suite runs on all three OS legs. The design keeps the bound configurable specifically so tests can use `1` rather than the 600s default; a test that waited out the real default would add ten minutes per case and would be disabled within a week.

## Deployment Topology

Nothing is deployed. The changed artifacts are:

| Artifact | Consumed by | Distribution |
|---|---|---|
| 4 panelist runner scripts | invoked by the `cross-model-verify` skill on the operator's machine | shipped inside the plugin, no build step |
| `cross-model-verification-policy.md` | read by agents and humans | same |
| `docs/THREAT-MODEL.md` | read by humans | repository-only, not shipped in the plugin |
| 2 test suites | `tests/run-all.sh` | repository-only |

There is no service, no container, no IaC resource, and no external endpoint. `SDD_PANELIST_TIMEOUT` is read from the process environment at invocation time; it needs no provisioning and has a working default when unset (AC-003).

## Rollback

Revert the single commit. The change is additive to script control flow and additive to two documents, so the revert is complete and carries no migration:

- Reverting the runners restores the unbounded invocation. That reopens the B1 denial-of-service hole, so a rollback is a **security regression, not a neutral undo** — this is stated explicitly rather than left for the person doing it to discover.
- Reverting the documents removes the taxonomy and the threat-model sections. No consumer parses them, so nothing breaks mechanically.
- No state, cache, or artifact persists across the revert. `SDD_PANELIST_TIMEOUT` set in an operator's environment after a revert is simply ignored by the restored scripts.

Partial rollback is possible and safe in one direction only: Stream B (documents) may be reverted independently of Stream A. Reverting Stream A while keeping Stream B would leave `cross-model-verification-policy.md` describing a bound that no longer exists — the precise documentation-versus-behaviour drift that issue #133 was filed about. If Stream A is reverted, Stream B's taxonomy section must be reverted with it.
