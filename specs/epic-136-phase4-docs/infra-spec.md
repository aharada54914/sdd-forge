# Infrastructure Spec: epic-136-phase4-docs

## CI/CD Sequence

**No new CI step, and no CI file is edited by this feature.** This does not imply an exemption from human application: the 2026-09-08 requirements BL-005 source evidence identifies both shell runners as protected. Obtain refreshed evidence at the consuming boundary and require exact reviewed human application where protected; no hook bypass is permitted. The earlier inference that this feature had no staging surface is superseded by the human-authorized PR #400 amendment.

The existing `test` job is authoritative. `tests/run-all.sh` already registers `cross-model.tests.sh`, so the new cases in REQ-006 are picked up with no registration change. The PowerShell parity suite (`cross-model.tests.ps1`) is likewise already registered on the Windows leg.

Sequence at merge time:

1. `test` job, 3-OS matrix — runs `tests/run-all.sh`, which now includes the timeout cases.
2. No `dist/` rebuild step applies. This feature changes shell, PowerShell and Markdown only; there is no esbuild bundle in scope, so ADR-0003's same-commit rebuild obligation does not attach and `git diff --exit-code -- dist/` is not a leg of any acceptance criterion.
3. No `npm audit` interaction. No package manifest or lockfile is touched.

**Timing and coverage.** TEST-004 uses explicit short bounds but cannot replace TEST-003/012's separate unset/empty default-expiry checks. Those checks observe the real timeout duration and exercise the actual decision using a controllable clock/wait fixture or the real bound; they cannot inject a result. TEST-004(c1)/(c2) requires both established process-state orderings at least five times per runner, without favorable-sample selection. All mandatory CI remains required; cost is not grounds to omit coverage or reinterpret a failed ordering as success.

## Deployment Topology

Nothing is deployed. The changed artifacts are:

| Artifact | Consumed by | Distribution |
|---|---|---|
| 4 panelist runner scripts | invoked by the `cross-model-verify` skill on the operator's machine | shipped inside the plugin, no build step |
| existing `lib/panelist-common.sh` | sourced by both shell runners; owns group supervision | shipped inside the plugin; protected human-application target |
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
