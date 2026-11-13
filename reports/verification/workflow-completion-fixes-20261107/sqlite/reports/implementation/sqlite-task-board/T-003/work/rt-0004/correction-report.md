# T-003 correction report — RT-0004

This is a test-only correction of two accepted Major coverage gaps. Only `tests/browser_task_board.py` changed. No production defect or fabricated Red/Green implementation cycle is claimed. Existing application, specifications, backend tests, reports and earlier evidence are unchanged.

Authorization: current user/parent routine test/local-commit authority and the hashed supplement `reports/implementation/sqlite-task-board/T-003/handoff/rt-0004-supplement.json` (`ce51f337b2019b1d21a86fb43aae74a74eb31e1b2fa0e3a3252938c680bd0f6e`). Every declared input was hash-checked before work. This uses the same bound gpt-6-astra/high worker; no identity or model selection was invented. Parent retains ticket/status changes and independent quality review.

## Coverage added

Normal POST, PATCH in both directions and confirmed DELETE now save `perf_counter` elapsed times and assert <1s after acknowledged UI and actual saved-state checks. DELETE timing starts in the confirmation acceptance callback, excluding time spent reading the dialog. Small-list cases remain; additional PATCH both ways and DELETE operate on exactly 100 saved rows, and a POST is measured with 100 rows before insertion. The existing 100-row <2s usable-list assertion remains.

Seventeen malformed **HTTP 200 success** cases supplement the existing POST malformed DTO and HTTP500 tests:

- GET: initial wrong list type; ready-state numeric completion, wrong title type, invalid ID, duplicate IDs, reversed order and extra envelope key. Initial malformed read accepts no untrusted rows and keeps mutations disabled until explicit authoritative retry. Ready-state failures retain draft and last acknowledged rows, restore controls, display Japanese read errors and retain the visible retry action. Real retry restores the authoritative list.
- PATCH: numeric completion, wrong ID, changed title, completion different from the requested value, extra DTO field and wrong envelope key. All preserve the exact saved/UI state and draft, reject false success, restore controls and checkbox focus.
- DELETE: wrong acknowledgment ID, string ID, extra acknowledgment key and wrong key. All preserve the exact saved/UI state and draft, reject false success, restore controls and delete-button focus.

Each malformed-response interception checks no automatic replay during an explicit 200ms quiet window. Actual server state is independently compared; interceptions never mutate the real store. Error text, pending controls, saved rows, input value, success-region preservation and focus are asserted. The browser console still rejects unexpected errors; intentional HTTP errors remain explicitly attributed.

For retained ready-state GET coverage, the test invokes the existing `load()` client routine once with a forced read failure, because no visible reload control exists after a successful load. It then uses the actual visible `再読み込み` button for every malformed-success retry and real recovery. This is explicit client-state integration, not a claim of an additional product UI action. Initial GET coverage uses a real page reload.

All existing 21 groups, including 35 successful Unicode UI cases, 32 rejected UI values, 68 Unicode API cases, real process restart, CRUD, framing, console, focus/contrast, responsive screenshots and CSS zoom, remain intact. The expanded suite has 25 groups.

## Execution

Final command: `python -B tests/browser_task_board.py --output reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-ready --screenshots reports/visual-evidence/sqlite-task-board/rt-0004/green-ready`

Actual exit 0; all 25 groups pass, including all 17 malformed-success cases. The command record verifies the test SHA-256 was identical before and after execution. At 100 rows, PATCH true/false measured 0.052178105s / 0.047571012s; confirmed DELETE 0.046658543s; POST 0.046505097s. The 100-row usable list measured 0.065211650s. Small-list PATCH true/false measured 0.042974793s / 0.090741915s and DELETE 0.046939921s. Exact per-action records, thresholds, row counts and process details are in measured-summary.json and green-ready/observations.json.

Ruff, mypy against the actual Playwright Python interpreter, and Python compile all pass in `static-checks-ready.json`, with exact commands/output. Backend/source files are unchanged; no new backend run is claimed. The existing current 37-test regression evidence remains valid and is separately held by the parent.

## Preserved intermediate failures

The first expanded browser run passed 25 groups, but Ruff B023 correctly rejected a loop-captured route list. The first attempted lint correction used a lambda default argument; Playwright supplied its second Request argument into that default, producing `AttributeError: 'Request' object has no attribute 'append'` in `green-final`. A bound `list.append` then failed because Playwright needs to attach wrapper metadata (`_pw_impl_instance_`) to the callable; that failure is retained in `green-verified`. These were test-harness failures, not application defects.

The final handler uses a normal one-argument function returned by `route_collector`, binding each destination outside the loop. The complete browser then passed. Ruff's subsequent UP035 import correction moved Callable to collections.abc; a final fresh browser invocation records matching test hashes before/after execution. Every failed/passed command, traceback and screenshot directory remains distinct. No assertion was removed or weakened to accommodate the harness.

## Preservation and commit

Test-only commit: `f5cbb15205132a2802cc50fd6e6b1724327b58f0`. Git reports exactly one changed file, tests/browser_task_board.py. Raw commit/show/diff are in commit-evidence.json. Final test SHA-256: `c5eb1cdb30ec69d0e002fc6776b8fa2fe6f0d54068a1fe3a8f9e8383da3ea335`. No production or evidence rewrite was committed.

`preservation-checks.json` confirms the original RT-0003 report hash and 72 unchanged prior-output/snapshot hashes (all RT-0003 outputs except the authorized browser-test revision, plus all 36 original snapshot inputs). Generated mypy cache is excluded from commit/Outputs. No ticket, task status, root report, old evidence, backend or frozen spec was edited.

## Outputs

| Path | SHA-256 |
|---|---|
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/commit-evidence.json` | `0b1ebcefb611118fdd82208032ca64cd1944c0711fdfd8de879edb4227e460f8` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green/observations.json` | `a7c743a64038939614780e7335bd645370d81d3980b10eca20ab05d9143674c2` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green/server.log` | `cd5e10480526c9973fc6f77a7183252b07ceaf1a1e8ad70dc837210ad7067554` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-command.json` | `e4db55ef509858fff91f5545b2bdbd40f3109039109cf139bb92fb3b2c8c8255` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-complete/observations.json` | `5d8bdacb08b4fbe951751b38c53594298ee750227bbe2e02a9fdefa01b936db7` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-complete/server.log` | `c1f98fac3806761f208067278b3054eee66aca349fe307c2e796ab11752e18e3` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-complete-command.json` | `78b3a826b619b1a92657374b7fd9af65ca423f11f41b186e8122c46d8ce87a29` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-complete.log` | `baea5ec0283360937d0049fe3029d4896058828b4eed899065f8ca7f24460506` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-final/observations.json` | `f81389b9cb99981b80c0d4af352178dd3034b343d3ce53e0d014439993f65294` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-final/server.log` | `5153ae52be943da66d1eb036c988e64cda36ce0ef2438b6586eca0de580220f1` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-final-command.json` | `65e26126d282aaa14c9d068269be4a46b2fe74aca3be6944ea61d73b5ee3f443` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-final.log` | `3ad425e8fa6d27189bf38a73b216f80d0437b01b2fbdfc4342dbb9e7c130aca0` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-ready/observations.json` | `578eb4a05a816678c9956c0cf59ba911a3f355d62fcc583981531cbf3bfeb7a7` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-ready/server.log` | `1ff80a35eba24e75cbcf5da6d21824fb3e6cb1ab8a0cf2aa8b0e3e770bf53223` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-ready-command.json` | `fad76edc8274954236f5939816c2fa77d99af1bc7183c7229f6a5632f96a4b52` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-ready.log` | `4a35226e9b09ff8f84151c3f0d7dbc35594e2c6c3a541f91870bc314e6412a2a` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-verified/observations.json` | `2108a30d39c104d679006f57c41601bffadeacdc0ddbe9bdf47a143a0b512df1` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-verified/server.log` | `2d30271f3f455da9b2cfb69460dbc21e3d61db2981838c55b9a6b3c2b9870d26` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-verified-command.json` | `c69e0ba15ad3dae18e0ed37060b6833825071082eac5862edd4ce8046a7c9b78` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green-verified.log` | `cd13040f11fa33bd494743d063aa69ade56d05ddb3f664ff37aa79bf35a6bfc1` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/green.log` | `60044d44be4f8e6d5c8526b42a3e69c4be207afd7228cc3990051c0dc689063d` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/measured-summary.json` | `825a172de0c97709e6f43bbf8299cedc589ad0bfef08da077a799c53a73f134f` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/preservation-checks.json` | `385277d01087f4d2c537798734a1051f72f5fb323f8ce91adb69d2b00b9e36b2` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/static-checks-complete.json` | `0e32896a81c2d6b010b9a35161c5517e419f86533493955f405b5ef28e5db669` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/static-checks-final.json` | `ce3ba0ac5cfe4d2f524331eae9ebab014c67cb945c0b39313d08c1e61096d2dd` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/static-checks-ready.json` | `ce3ba0ac5cfe4d2f524331eae9ebab014c67cb945c0b39313d08c1e61096d2dd` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/static-checks-verified.json` | `ce3ba0ac5cfe4d2f524331eae9ebab014c67cb945c0b39313d08c1e61096d2dd` |
| `reports/implementation/sqlite-task-board/T-003/work/rt-0004/static-checks.json` | `fa82cd004f677fdca5dbeee6c362fd73e31113061893c9937e8c4872a371a6f5` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green/desktop.png` | `5df59f418bbf472761fb186e33b7acaf8615bb6f9a90e7804820f7cb2c2e2ab6` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green/early-desktop.png` | `4453491084f9eea9fd0c9c50cace6ab21ccef68660181e82b7bc79a41271e7e5` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green/early-mobile.png` | `e806501c5f4ea3f865244b789f8c5be4addf4fefb95b7ef2d15892d6dcad08ac` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green/empty.png` | `81736ec99d4954bce6cfcb0ad331fe3d8931b2d734c0d9d04aa068fe4b4cf7ba` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green/loading.png` | `c26e71aabf4f7f7f5ec00fee82389c1d30f94e0480694c806bf342b87b440447` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green/mobile.png` | `9ed99c778efb99b4e53a4f5e58d95f098c1c349879f545bf6f5892f1c60e53f2` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green/read-error.png` | `bf0c805da79c46be58f2fce3e3f9cfb66b954f273cb01cd65965d12285efa8e0` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green/write-error.png` | `bb9e502239a4521095a8cc26c149f8a45fa8706dfa5a4d7e9c6b4810c076d018` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green/zoom-200.png` | `b751850ecae13e949b52be325882969a3511ac22f192b02eed0b476b870ce7ee` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-complete/desktop.png` | `5df59f418bbf472761fb186e33b7acaf8615bb6f9a90e7804820f7cb2c2e2ab6` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-complete/early-desktop.png` | `4453491084f9eea9fd0c9c50cace6ab21ccef68660181e82b7bc79a41271e7e5` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-complete/early-mobile.png` | `e806501c5f4ea3f865244b789f8c5be4addf4fefb95b7ef2d15892d6dcad08ac` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-complete/empty.png` | `81736ec99d4954bce6cfcb0ad331fe3d8931b2d734c0d9d04aa068fe4b4cf7ba` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-complete/loading.png` | `c26e71aabf4f7f7f5ec00fee82389c1d30f94e0480694c806bf342b87b440447` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-complete/mobile.png` | `9ed99c778efb99b4e53a4f5e58d95f098c1c349879f545bf6f5892f1c60e53f2` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-complete/read-error.png` | `bf0c805da79c46be58f2fce3e3f9cfb66b954f273cb01cd65965d12285efa8e0` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-complete/write-error.png` | `bb9e502239a4521095a8cc26c149f8a45fa8706dfa5a4d7e9c6b4810c076d018` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-complete/zoom-200.png` | `b751850ecae13e949b52be325882969a3511ac22f192b02eed0b476b870ce7ee` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-final/desktop.png` | `5df59f418bbf472761fb186e33b7acaf8615bb6f9a90e7804820f7cb2c2e2ab6` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-final/early-desktop.png` | `4453491084f9eea9fd0c9c50cace6ab21ccef68660181e82b7bc79a41271e7e5` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-final/early-mobile.png` | `e806501c5f4ea3f865244b789f8c5be4addf4fefb95b7ef2d15892d6dcad08ac` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-final/empty.png` | `81736ec99d4954bce6cfcb0ad331fe3d8931b2d734c0d9d04aa068fe4b4cf7ba` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-final/loading.png` | `c26e71aabf4f7f7f5ec00fee82389c1d30f94e0480694c806bf342b87b440447` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-final/mobile.png` | `9ed99c778efb99b4e53a4f5e58d95f098c1c349879f545bf6f5892f1c60e53f2` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-final/read-error.png` | `bf0c805da79c46be58f2fce3e3f9cfb66b954f273cb01cd65965d12285efa8e0` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-final/write-error.png` | `bb9e502239a4521095a8cc26c149f8a45fa8706dfa5a4d7e9c6b4810c076d018` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-final/zoom-200.png` | `b751850ecae13e949b52be325882969a3511ac22f192b02eed0b476b870ce7ee` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-ready/desktop.png` | `5df59f418bbf472761fb186e33b7acaf8615bb6f9a90e7804820f7cb2c2e2ab6` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-ready/early-desktop.png` | `4453491084f9eea9fd0c9c50cace6ab21ccef68660181e82b7bc79a41271e7e5` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-ready/early-mobile.png` | `e806501c5f4ea3f865244b789f8c5be4addf4fefb95b7ef2d15892d6dcad08ac` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-ready/empty.png` | `81736ec99d4954bce6cfcb0ad331fe3d8931b2d734c0d9d04aa068fe4b4cf7ba` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-ready/loading.png` | `c26e71aabf4f7f7f5ec00fee82389c1d30f94e0480694c806bf342b87b440447` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-ready/mobile.png` | `9ed99c778efb99b4e53a4f5e58d95f098c1c349879f545bf6f5892f1c60e53f2` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-ready/read-error.png` | `bf0c805da79c46be58f2fce3e3f9cfb66b954f273cb01cd65965d12285efa8e0` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-ready/write-error.png` | `bb9e502239a4521095a8cc26c149f8a45fa8706dfa5a4d7e9c6b4810c076d018` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-ready/zoom-200.png` | `b751850ecae13e949b52be325882969a3511ac22f192b02eed0b476b870ce7ee` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-verified/desktop.png` | `5df59f418bbf472761fb186e33b7acaf8615bb6f9a90e7804820f7cb2c2e2ab6` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-verified/early-desktop.png` | `4453491084f9eea9fd0c9c50cace6ab21ccef68660181e82b7bc79a41271e7e5` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-verified/early-mobile.png` | `e806501c5f4ea3f865244b789f8c5be4addf4fefb95b7ef2d15892d6dcad08ac` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-verified/empty.png` | `81736ec99d4954bce6cfcb0ad331fe3d8931b2d734c0d9d04aa068fe4b4cf7ba` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-verified/loading.png` | `c26e71aabf4f7f7f5ec00fee82389c1d30f94e0480694c806bf342b87b440447` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-verified/mobile.png` | `9ed99c778efb99b4e53a4f5e58d95f098c1c349879f545bf6f5892f1c60e53f2` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-verified/read-error.png` | `bf0c805da79c46be58f2fce3e3f9cfb66b954f273cb01cd65965d12285efa8e0` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-verified/write-error.png` | `bb9e502239a4521095a8cc26c149f8a45fa8706dfa5a4d7e9c6b4810c076d018` |
| `reports/visual-evidence/sqlite-task-board/rt-0004/green-verified/zoom-200.png` | `b751850ecae13e949b52be325882969a3511ac22f192b02eed0b476b870ce7ee` |
| `tests/browser_task_board.py` | `c5eb1cdb30ec69d0e002fc6776b8fa2fe6f0d54068a1fe3a8f9e8383da3ea335` |

## Handoff

Coverage correction complete. Parent should adopt the post-fix artifacts and perform the final permitted fresh independent review. This report does not decide Done or claim an independent verdict.
