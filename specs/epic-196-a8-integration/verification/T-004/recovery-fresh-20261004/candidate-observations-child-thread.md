# T-004 recovery candidate: child-thread observations

Date: 2026-10-04. Checkout: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge` at HEAD `495c88d67af44530687ecea3ce9fb0a90a336539`.

This is diagnostic evidence only. It is not an implementation report, a `task-input-manifest/v1`, an evaluator input, or a quality-gate verdict.

## Identity boundary

- Child `CODEX_THREAD_ID`: `01a10758-f042-73a3-b231-d35ffd7c121d` (a thread identifier).
- `CODEX_SESSION_ID`: `01a06d01-11b5-7bd3-83a3-7e29bb3c96cd` (shared host session, not a distinct child session). The canonical identity ledger already records it as `host_session_id` at sequence 960.
- Agent path: `/root/weekly380_current/a8_t004_impl_recovery` (collaboration task identity).
- A new run ID, independent host-session ID, and model/effort provenance suitable for a formal implementation manifest were not established. The child thread ID must not be substituted for the shared host-session ID.
- Canonical absolute implementation scratch root allocated exclusively for this diagnostic context: `/private/tmp/a8-t004-recovery-impl-oct04-cLz1eC`. Allocation does not resolve the host-session provenance gap.

## Current input and source checks

- All eight target `after` SHA-256 values in `reports/verification/a8-t004-recovery-v2-pins.json` match the current files. No protected target was changed here.
- Historical canonical implementation report SHA-256: `48bf3519745073238f230199b9f5dafdb52fdf1108b5e05071931209fc7c928f`; its five `## Outputs` hashes all match current files.
- Current task/source SHA-256: `tasks.md` `8c17b0f6b2fa299d23ce6e892a8e80a841ac4ab68d613c84d6c36fe09bbcde66`; `requirements.md` `f841443d88b4f58fdbb9e32ee050edf8395f3767ebbc08cc2d9d6be76cb3ac44`; `design.md` `14862a80a6f44b49dbf7e1393af66c82c0434bf1109b248e7ff9b4b695fcd18c`; `acceptance-tests.md` `4d089666d69b5f565c4cd6fd091404e31b15eda063463850a862a816d42797c1`; `investigation.md` `888868de019e903375b3cf8b8d25c89f2abf84b950178e99afb534ab8495a77f`; `traceability.md` `b3ca32a2ce5d22208918f58f17a4f1736492023d78ec91dc40f6633e9d039f61`; `T-004.contract.json` `1106f19fd784fa89ab5f54d1b5ee032c1684d893e57040716108cacddd25be79`.
- `tests/cli-hook-enforcement.ps1` SHA-256: `343aa50f12d790619dc5d636831d6f1c7d1559745b9ca289ad67fb28564a3bec`. Diff against `c886b790` adds 34 lines at one insertion point after line 92; the original 100 lines remain unchanged.

## Fresh local checks

- `bash scripts/check-sdd-structure.sh`: exit 0, `check-sdd-structure: OK` (`CLAUDE.md` advisory).
- `env TMPDIR=/private/tmp/a8-t004-recovery-impl-oct04-cLz1eC pwsh -NoProfile -ExecutionPolicy Bypass -File tests/cli-hook-enforcement.ps1`: exit 0, 17 passed, 0 failed; TEST-017 and the three synthetic TEST-012 cases observed.
- `sh plugins/sdd-quality-loop/scripts/check-traceability.sh specs/epic-196-a8-integration/verification/T-004/traceability.json . require-evidence`: exit 0, 1 link passed.
- `git diff --check`: exit 0, no output.
- `python3 tests/issue311-scratch-isolation.tests.py --repo .`: exit 0, PASS 60 / FAIL 0.
- `python3 tests/review-scratch-history.tests.py --repo .`: exit 0, PASS 26 / FAIL 0.
- `bash tests/review-context-boundary.tests.sh`: exit 0, PASS 84 / FAIL 0.
- `bash tests/review-agent-isolation.tests.sh`: exit 0; sequential reviewer/evaluator identities and hash chain succeeded; nested scratch-history check PASS 26 / FAIL 0.
- `bash reports/verification/a8-t004-recovery-reserve-fixture.sh`: exit 0, all negative and positive controls passed; production ledger untouched by the fixture.

## Blocker and next context

`task-input-manifest/v1` has a `session_id` field, and the amended quality-gate boundary requires actual run/session provenance with no implementation/review/evaluation session reuse. This child has only a distinct thread ID while its observed `CODEX_SESSION_ID` is shared with an existing ledger host identity. A truthful distinct-session manifest cannot be emitted here. A genuinely separate host session must repeat the input checks, establish its actual model/effort/run/session identities, then create a noncanonical recovery implementation report and input manifest. The old report remains untouched, and no evaluator reservation or task-state change was made.
