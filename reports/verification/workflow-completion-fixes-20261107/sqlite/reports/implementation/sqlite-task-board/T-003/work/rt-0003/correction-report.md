# T-003 correction report — RT-0003

- Task: T-003
- Review ticket: RT-0003, genuine critical correctness finding
- Result: Scoped fix and checks complete; independent quality review remains parent-owned.
- Model/effort: existing parent-bound gpt-6-astra/high worker; no new selection or identity.
- Original run: 01a1b60a-8804-7c51-b20d-2361d0daa5b0
- Existing session: 01a1b60a-87de-77e2-89f4-2396094d6d78
- Parent-observed continuation turn: 01a1d33f-1115-7043-b614-8414483aff5d

## Authorization and inputs

File-bound supplement: `reports/implementation/sqlite-task-board/T-003/handoff/rt-0003-supplement.json`, SHA-256 `7e2e926b304e2ed71c1a45e4110b13621313f9245e6664904691544f2d69492d`. All seven supplement input hashes were checked before work. The original admitted manifest/report/snapshot remain immutable. The installed `fix-by-review-ticket` and debugging recovery policy were read from `reports/integration/runtime-snapshot-20261113-745/sdd-quality-loop/1.23.1/`.

The ticket's `auto_fix_allowed: true`, `requires_human_decision: false` and current explicit user/parent authority permit this routine correction and scoped local test/fix commits. This report does not claim a new human-authored fixture. Parent reserved ticket/task lifecycle edits, so neither was changed by the worker.

## Diagnosis and minimal correction

Python `str.strip()` removes C0 U+001C–U+001F and NEL U+0085; JavaScript native `trim()` retains them. Conversely, JS trim removes U+FEFF while Python preserves it. The old client submitted NEL-padded input, the server committed the stripped title, and exact acknowledgment comparison raised a false failure. A user retry could duplicate that already committed task.

`static/app.js` now uses one `normalizeTitle()` function with the complete Python whitespace character set for both submitted-title normalization and normalized DTO validation. It removes only leading/trailing Python whitespace, preserves U+FEFF and interior characters, and retains every existing exact response/title/boolean/id check. No optimistic rendering, fallback, retry, response-check weakening, backend change or specification change was introduced.

Only production `static/app.js` and test `tests/browser_task_board.py` changed. Existing 19 browser assertion groups remain; two RT-0003 groups were added.

## Genuine Red before production edit

Red commit: `d6b8be0be008055e80d84ba7a983af83fb775d85`.

Command: `python -B tests/browser_task_board.py --output reports/implementation/sqlite-task-board/T-003/work/rt-0003/red --screenshots reports/visual-evidence/sqlite-task-board/rt-0003/red`

Actual exit: 1. The real browser submitted `U+0085 + 日本語 + U+0085`; HTTP returned 201 with exactly one saved `日本語` task. The actual server state contained that committed row, while the UI retained the draft and displayed `保存できませんでした。もう一度お試しください。`. The assertion requiring the successful draft clear failed. Exact inputs/response/state/error appear in `red-chronology.json` and `red/observations.json`; the traceback and original test bytes are preserved.

Raw git show/ls-tree and the unchanged pre-fix JS SHA-256 `0ec74a38f3cfd5a12a14363553f9ce2fa93f2ac45013008dd15cc757fe52491d` establish that the failing test-only commit preceded the JS fix.

## Green and coverage

Fix commit: `570dcf0408b9f9be9067af8d49fe8f5253abed85`. Raw git show, source diff and successful Red-ancestor check are in `fix-chronology.json`. The test bytes are unchanged between Red and Green.

Command: `python -B tests/browser_task_board.py --output reports/implementation/sqlite-task-board/T-003/work/rt-0003/green --screenshots reports/visual-evidence/sqlite-task-board/rt-0003/green`

Actual exit: 0, all 21 groups pass. Python independently enumerates its complete 29-character whitespace set. The new UI coverage has 35 successful values and 32 invalid/blank values: C0 separators, NEL, preserved FEFF including a FEFF-only title, all usable single-line whitespace boundaries, mixed whitespace, astral 200/201 and FEFF 200/201 boundaries. Every successful UI case asserts one POST, one exact saved unchecked row, no false alert, success feedback, cleared draft and exact rendered state. Rejections assert no POST and no mutation. Exact rows survive reload. CR/LF are discarded by native single-line HTML inputs, so their raw preservation/normalization is verified independently through the real API.

The 68 real API cases exercise every Python whitespace character, whitespace-only rejection, FEFF preservation and codepoint boundaries. Success responses and all saved rows are compared exactly; each 400 leaves the complete state unchanged. They use the current actual server and fresh database, without mocked storage/API responses. Only the suite's existing deliberate failure-injection scenarios use browser interception.

Supplementary exhaustive command: `node reports/implementation/sqlite-task-board/T-003/work/rt-0003/unicode-parity-check.js`. The actual production normalization function was checked over all 1,112,064 Unicode scalar values and compared with independent Python `isspace()` enumeration. The removed set matches all 29 characters exactly; U+FEFF/U+180E/U+200B and interior NEL are preserved. Command/output/expected codepoints are in `unicode-parity.json`.

The complete suite still verifies actual CRUD, duplicates, keyboard/focus, malformed DTO handling, pending/error recovery, byte framing, console attribution, screenshots, contrast, 200% CSS page zoom and actual server restart. Green restarted PID 111662 as 112084 against the same fresh `/tmp/task-board-browser-jlu6w9oz/tasks.sqlite3`; both exited 0. Normal-path console errors remain prohibited; the newly intentional API 400 responses are explicitly attributed to the Unicode rejection phase.

## Regression and static checks

- `python -B -m unittest discover -s tests -p 'test_*.py' -v`: all 37 passed in 15.124s, exit 0. Exact command/output retained.
- `/tmp/sqlite-task-board-quality-tools-n0vojfhn/bin/ruff check tests/browser_task_board.py`: exit 0.
- `/tmp/sqlite-task-board-quality-tools-n0vojfhn/bin/mypy --python-executable /opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python --follow-imports=silent --cache-dir reports/implementation/sqlite-task-board/T-003/work/rt-0003/mypy-cache tests/browser_task_board.py`: exit 0.
- `node --check static/app.js` and Python compile: exit 0. Exact invocations/output in `static-checks.json`.

No failed Green or static run occurred for this correction. The intended Red failure remains unchanged. A supplemental Node-probe heredoc was rejected before execution by the normal shell hook: `SDD deterministic gate: ambiguous shell parsing, unsafe loop binding, or glob-expanded reader options; use ordinary lower-case loop variables, explicit arguments, and an option terminator (--).` The structured apply_patch tool created the probe, followed by an ordinary execution command; hooks stayed enabled. An initial guessed skill-directory lookup returned path-not-found before the parent supplied the exact runtime path; the correct installed skill was then read.

## Preservation and evidence

`preservation-checks.json` verifies 117 hashes: all 81 original report outputs other than the two authorized changed code/test files, plus all 36 immutable snapshot inputs. The original worker report remains SHA-256 `5bb928bbee3b1ed5ee165c912393739d01b1a8d606d2cdf0b037f8371836f2d6`. Original task reports, manifest, snapshot and old evidence were not rewritten. Backend, T-001/T-002 tests and frozen specifications were unchanged.

Fresh Red and Green screenshots are in the corresponding `reports/visual-evidence/sqlite-task-board/rt-0003/` subdirectories; early desktop/mobile paths were shared with the parent. No layout/style change was needed. `mypy-cache` is generated scratch data and intentionally excluded from commits and this Outputs declaration.

## Outputs

| Path | SHA-256 |
|---|---|
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/fix-chronology.json` | `ad46400c83ea299187dd13d0d6a9a5d39ef2a34131019d7157321408658baf0a` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/green/observations.json` | `6243886a17ea0bc4d853131b23294b694b8b22d52c130a80cfcd1e892befd298` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/green/server.log` | `ffa9f1e5c972ce797e685907862a22d076d2503ac6028b7aeee2820b5a41dcba` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/green-command.json` | `43183e1715f5962a99f3925e7998a82fbe99bb485e7ce45cae81464b23495ef1` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/green.log` | `91a2c821e51617d865d2106a8976a73db47c911f76d1461051d478a465c45f5a` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/preservation-checks.json` | `202f9ddbc59f6400f6bec8f0579c756ad97b9ee00d80d04c8d4e14d25724d760` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/red/observations.json` | `e49ebc281178dad1be2d42849f64543235f0099205893ce6af76fe97810cd18c` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/red/server.log` | `faf77d399adbaa7794df9cf1b8bc5aa8657c93dd4b6d7458aa7af90cc1333bc6` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/red-chronology.json` | `c0d30ca425f80f49665b80a7131bd6e00917d49ca9f8aab645906184d5072dfd` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/red-command.json` | `ebe460cb3b4623d7285435230ebb66dd65d43bff84b9026038982c2d772f5d15` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/red-test.py.txt` | `35528cef929ef6b781d1dcef42d4807c9d89046b33d8c7fb41a2f8c5d1771547` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/red.log` | `0540cdc334ec6e1a626e1973528fcf43b2ca93b00905ed8c99b066c7695a111e` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/regression-command.json` | `36d1f95c220b0092fdfc3c090b05aa5d87cb271f73c13f4ba76a176ba901eb15` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/regression.log` | `e8a6f99e14fa9070740713617c61771de3342971b04faaebfe25e6b6cc3b05d1` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/static-checks.json` | `abdda2907254bcd7fde3d1d91c9045ad446145c813f41cc383b7b2a582e567e9` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/unicode-parity-check.js` | `579a47f41cc07a681b55f6f4a3646c8f1713c6c1f948ae595aa788ee95dcb8ec` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0003/unicode-parity.json` | `5b480156899b462ac2f68eb1815063c26ac6d3ac0fe85bdbe5065b5a4916e4ac` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/green/desktop.png` | `5df59f418bbf472761fb186e33b7acaf8615bb6f9a90e7804820f7cb2c2e2ab6` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/green/early-desktop.png` | `4453491084f9eea9fd0c9c50cace6ab21ccef68660181e82b7bc79a41271e7e5` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/green/early-mobile.png` | `e806501c5f4ea3f865244b789f8c5be4addf4fefb95b7ef2d15892d6dcad08ac` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/green/empty.png` | `81736ec99d4954bce6cfcb0ad331fe3d8931b2d734c0d9d04aa068fe4b4cf7ba` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/green/loading.png` | `c26e71aabf4f7f7f5ec00fee82389c1d30f94e0480694c806bf342b87b440447` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/green/mobile.png` | `9ed99c778efb99b4e53a4f5e58d95f098c1c349879f545bf6f5892f1c60e53f2` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/green/read-error.png` | `bf0c805da79c46be58f2fce3e3f9cfb66b954f273cb01cd65965d12285efa8e0` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/green/write-error.png` | `bb9e502239a4521095a8cc26c149f8a45fa8706dfa5a4d7e9c6b4810c076d018` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/green/zoom-200.png` | `b751850ecae13e949b52be325882969a3511ac22f192b02eed0b476b870ce7ee` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/red/desktop.png` | `5df59f418bbf472761fb186e33b7acaf8615bb6f9a90e7804820f7cb2c2e2ab6` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/red/early-desktop.png` | `4453491084f9eea9fd0c9c50cace6ab21ccef68660181e82b7bc79a41271e7e5` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/red/early-mobile.png` | `e806501c5f4ea3f865244b789f8c5be4addf4fefb95b7ef2d15892d6dcad08ac` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/red/empty.png` | `81736ec99d4954bce6cfcb0ad331fe3d8931b2d734c0d9d04aa068fe4b4cf7ba` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/red/loading.png` | `c26e71aabf4f7f7f5ec00fee82389c1d30f94e0480694c806bf342b87b440447` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/red/mobile.png` | `9ed99c778efb99b4e53a4f5e58d95f098c1c349879f545bf6f5892f1c60e53f2` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/red/read-error.png` | `bf0c805da79c46be58f2fce3e3f9cfb66b954f273cb01cd65965d12285efa8e0` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/red/write-error.png` | `bb9e502239a4521095a8cc26c149f8a45fa8706dfa5a4d7e9c6b4810c076d018` |
| `reports/visual-evidence/sqlite-task-board/rt-0003/red/zoom-200.png` | `b751850ecae13e949b52be325882969a3511ac22f192b02eed0b476b870ce7ee` |
| `static/app.js` | `a3e96eddbe6ecff7d19110266959736928db57bf83507f4c6eaa4f9a7cca4bc5` |
| `tests/browser_task_board.py` | `35528cef929ef6b781d1dcef42d4807c9d89046b33d8c7fb41a2f8c5d1771547` |

## Handoff

The scoped correction is complete and committed. Parent should resolve/update the authorized ticket/task lifecycle and run a fresh independent quality gate. No Done decision or independent reviewer verdict is claimed here.
