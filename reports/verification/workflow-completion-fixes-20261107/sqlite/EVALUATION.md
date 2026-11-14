# Native SQLite workflow evaluation

**Complete, 2026-11-13:** T-001, T-002 and T-003 are Done through installed FULL quality gates. Repository-wide workflow, task-state, canonical traceability and all three evidence bundles pass. No unresolved Critical/Major remains. No deployment, push, merge or external send occurred.

Run: `python3 -B app.py --db data/tasks.sqlite3 --port 8000`, then open `http://127.0.0.1:8000/`. [README.md](README.md) documents restart and test prerequisites. Runtime dependencies are Python standard library/SQLite; frontend is plain HTML/JS/CSS.

## Actual tests and persistence

**37 backend tests and26 browser groups passed**, using a fresh temporary DB. Tests cover real browser CRUD/Enter/duplicates, checkbox both ways, deletion cancellation/confirmation, reload/restart, Japanese keyboard/focus/errors, pessimistic acknowledgement, Unicode200/201 including astral characters, whitespace parity, raw UTF-8 body4096/4097 limits, framing/security negatives, malformed-success recovery, responsive/200% layout, contrast/targets, console and overflow.

Exact executed argv, exit codes, timestamps and source-record hashes: [final-test-commands.json](evidence/final-test-commands.json). Measured cases, timings, geometry and exact persisted state: [final-test-measurements.json](evidence/final-test-measurements.json). Complete raw outputs remain at the indexed workspace paths.

Core actual commands from project cwd, all exit0:

```sh
/opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3 -B -m unittest discover -s tests -v
/opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3 -B tests/browser_task_board.py --output specs/sqlite-task-board/verification/T-003/round-4/browser-run --screenshots specs/sqlite-task-board/verification/T-003/round-4/screenshots
/tmp/sqlite-task-board-quality-tools-n0vojfhn/bin/ruff check --isolated --no-cache tests/browser_task_board.py
node --check static/app.js
```

Mypy and all required deterministic gates also exit0. Component coverage is the configured N/A result; design-system checking retains two non-blocking `#add` selector warnings.

Environment: Python3.12.14, SQLite3.53.1, Playwright1.62.0, `/usr/bin/chromium`154.0.8037.57 on Linux. Browser/static tools are test-only dependencies.

**Persistence: PID149712 → PID150061**, same `/tmp/task-board-browser-soc7mj4m/tasks.sqlite3`, both exit0. Exact before/after arrays match all13 surviving rows; deleted ID1 remains absent. No old manual-app result is reused. At100 rows, PATCHs measured42/28ms, confirmed DELETE42ms and POST49ms; confirmation reading time is excluded.

## Visuals

Final caller captures under `specs/sqlite-task-board/verification/T-003/round-4/screenshots/`:

- [1280×900 desktop](specs/sqlite-task-board/verification/T-003/round-4/screenshots/early-desktop.png)
- [375×812 mobile](specs/sqlite-task-board/verification/T-003/round-4/screenshots/early-mobile.png)
- [Failed-write recovery](specs/sqlite-task-board/verification/T-003/round-4/screenshots/rt0005-post-failure.png)
- [200% long-title layout](specs/sqlite-task-board/verification/T-003/round-4/screenshots/zoom-200.png)

The [reference](specs/sqlite-task-board/mockups/imagegen-reference.png) is the actual parent-generated ImageGen image, SHA256 `60049c2b9d49f059afbe50ec43cc0d0802bae75b15b5dde090c4acdaf00127d8`. No Claude Design live connectivity is claimed. Parent's earlier visual-scope inspection is preserved; fresh agent inspections are labelled as such.

## TDD, identity and review

| Task | Real Red commit | Production commit | Final state |
|---|---|---|---|
| T-001 | `433213c` | `191d8ac` | PASS / Done |
| T-002 | `3940a7a` | `1afa0c5` | PASS / Done |
| T-003 | `ec541c9` | `187d987` | PASS / Done after corrections |

T-003 preserves Unicode Red `d6b8be0`→fix `570dcf0`, coverage commit `f5cbb15`, and stale-success **Red `a173595`→fix `5017085`** (current HEAD). The two-line fix clears obsolete success on mutation entry/failure while retaining durable data/draft/error recovery. The first Green's test-harness framing aggregate failure remains preserved; fresh corrected runs pass with real DELETE framing checks intact.

Adopted workers are actual **gpt-6-astra/high**, canonical unmanaged registered tier strong. [Identity summary](evidence/implementation-identities-summary.json) contains original run/session IDs, selector/manifest pins and fresh continuation metadata. T-003 resumed its same physical context `01a1b60a-87de-77e2-89f4-2396094d6d78`. The USD1 planning estimate is not measured price.

Fresh final evaluator **`01a1d366-6d5b-7051-b889-dcb4016575e7`** used actual gpt-6-astra/high, reserved while idle before first turn, named read-only/network-off `sdd_manifest_review`. It executed standalone `/bin/cat README.md`, verified130 pins, inspected the full acceptance surface and returned **PASS, no findings**. It also ran six pure validation tests and in-memory compilation. [Canonical adoption](reports/quality-gate/T-003/canonical-readback-rt0005.json) exit0/sequence24 confirms identity/delivery/hashes. A caller parser error was repaired without changing reviewer bytes; its failure remains.

## Gate authority and history

[Quality report](reports/quality-gate/20261113-T-003-cycle-4-pass.md), [final contract](specs/sqlite-task-board/verification/T-003.final.contract.json), [bundle](specs/sqlite-task-board/verification/T-003.evidence.json) and [Done transition](evidence/t003-quality-done-transition.json) establish completion. [Final repository checks](evidence/final-repository-checks-749.json) record six exit0 commands, all three bundles and33 measured traceability links. Only T-003's lifecycle status changed in reviewed tasks.md; prior task pins remain valid.

All three prior T-003 NEEDS_WORK cycles and actual cycle-limit exit1/`Escalate-Human` remain unchanged. The user's 「不具合本体直して再実施し完走するまでやり直せ」 and 「時間優先」 instruction authorizes the scoped supported #749 continuation; no reset or invented limit PASS occurred. See [recorded authorization](evidence/t003-authorized-continuation-749.md).

The verified #749 runtime has309 inventoried files; only continuation documentation differs from #745. Scripts, roles and calibration are unchanged. Earlier #735, spec-round2, delivery failures and unadopted raw PASS remain diagnostics, never product gate authority. Parent approval fixtures are explicit disposable-test provenance. The [one retrospective](reports/retrospective/20261113-sqlite-task-board.md) and [canonical run record](reports/runs/RUN-20261113T054252Z-sqlite-task-board.json) retain3 Done,9 historical gate reports and5 historical tickets.

## Limits and collection

Tested scope is Chromium/Linux, local single-user scale; 200% uses Chromium CSS zoom. Other browser/OS behavior and actual screen-reader speech are not certified. Restricted reviewers inspect saved writable/network suite results. Bundles truthfully record a dirty working tree containing local workflow evidence; scoped source/test commits exist.

[COLLECTION.md](evidence/COLLECTION.md) and [curated-artifacts.json](evidence/curated-artifacts.json) list source/spec/tests/screenshots/final evidence/quality/native provenance. Raw logs, auth/profile/session material, caches, generated DBs, runtime copies and `.git` objects are excluded. Full history stays in the workspace; this collection is not a complete portable replay archive.
