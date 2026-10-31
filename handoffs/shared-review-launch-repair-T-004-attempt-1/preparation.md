# T-004 scoped native launch preparation

Prepared only; native launch, npm installation, implementation and review are NOT RUN.
Owning checkout: `/Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge`.
Expected HEAD: `9ce19abe90df0cb83e385f96855e4843318a8807`.
T-004 is Approved / In Progress (parent owns state and reservations).

Only this handoff directory was edited. The preparation context compacted before writing these files; it performed no native implementation. The launch creates a genuinely new native identity, not a retrospective identity for this preparer.

## Commands for the parent

Run from the owning checkout with `login=false`, in this order:

```sh
rtk proxy node handoffs/shared-review-launch-repair-T-004-attempt-1/prepare-native.cjs --check
rtk proxy node handoffs/shared-review-launch-repair-T-004-attempt-1/prepare-native.cjs --cache
rtk proxy node handoffs/shared-review-launch-repair-T-004-attempt-1/prepare-native.cjs
```

`--check` is read-only. `--cache` copies only the two package files into `output/dependency-cache` and runs lockfile npm ci with scripts disabled and cache confined to `output/npm-cache`. It does not launch native work. Native work separately installs offline into `output/work/mcp/ci-mcp`, after the genuine missing-Ajv RED. No global cache/install, owner node_modules, or sandbox network-setting changes. The cache command needs ordinary existing network access. Missing/incomplete cache remains a concrete failure, never fallback permission.

The final command uses T003's existing native app-server protocol and T002's isolated launch configuration/model provenance: actual `thread/start` identity, disabled-MCP check, manifest, immutable snapshot, manifest validation, then first turn. No identity/manifest is fabricated during preparation. It records current before-byte hashes/modes and checks the expected HEAD at actual launch, then rechecks all bytes before snapshot admission. A pre-existing identity or artifact is not overwritten or silently relaunched.

## Input boundary

`inputs.txt` enumerates 57 explicit files. No recursive checkout admission, reviews, ledger, or unrelated handoff history.

- Governing AGENTS, implement skill/three policies/template/report validator; task/spec contracts, model routing provenance.
- Workflow and both normal runners; registry/schema and integration addendum for approved source scope.
- Structured-output suite and its transport/probe/guard dependencies; pinned npm package and lockfile for actual Ajv RED/GREEN.
- TEST-013 host suite fixture dependency closure (six protected entrypoints, canonical invariant/generator/four projections/four guards), plus loaded skill/conditional-input dependencies. These remain read-only candidate source.
- Explicit registry directory topology reused from T003 for structural preflight; source modes for faithful rollback. Launcher metadata is admitted separately with its own hashes.

The native implementation must add permanent scoped wiring evidence tests, not widen test-source changes, weaken checks or claim isolated mutation RED as original-production RED. It must preserve POSIX/Windows applicability and record real commands/results. Whole runners/transport/traceability, native Windows, exact-head CI, combined rollback, independent review, quality and delivery are expressly parent-owned downstream work, not implied successful.

## Preparation checks

`rtk proxy node --check handoffs/shared-review-launch-repair-T-004-attempt-1/prepare-native.cjs`: exit 0.
`rtk proxy node handoffs/shared-review-launch-repair-T-004-attempt-1/prepare-native.cjs --check`: verifies all enumerated canonical regular files; no launch.

Limitations: runtime admission and npm-cache completeness are untested until parent runs the commands. This is preparation evidence, not implementation, review, CI or approval evidence.
