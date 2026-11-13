# RT-0005 correction report

Task T-003; accepted RT-0005 only. Same admitted worker continuation; parent independently verified native metadata. Implementation correction is complete and awaits independent quality. No Done decision or ticket/status mutation was performed.

Admission: reports/implementation/sqlite-task-board/T-003/handoff/rt-0005-supplement.json SHA256 cfdd8c170b5fce35140b866581352ff579a5d9bb0cefc96518fe226b05f1aad1. Used the admitted runtime-snapshot-20261113-749 fix-by-review-ticket skill and unchanged original manifest/snapshot. Earlier evidence, reports, RT-0003 Unicode normalization, RT-0004 malformed-success/timing coverage, backend and frozen specifications remain unchanged.

## Diagnosis and correction

A successful POST followed by a held then failed POST kept 「タスクを追加しました。」 visible during pending and alongside the Japanese failure. The actual Red saved this precise state while preserving the draft and real server rows. The two-line JS fix clears status after the mutation guard and clearError, before invalid-title validation, and in the write catch. Successful acknowledgment alone sets new success feedback. Read loading/retry feedback remains separate.

Regression coverage establishes real POST/PATCH/DELETE success, holds the next corresponding write, rejects it with500, and checks blank pending/failure status, exact draft and acknowledged rows through real HTTP, restored controls/focus, and no automatic replay. It also checks invalid-title submission after success and subsequent successful recovery. Existing timeout, malformed POST/PATCH/DELETE success and server400 failure assertions now require blank status rather than preserving obsolete success. All25 existing assertion groups and Unicode/API cases are retained; final suite has26 groups.

## Actual Red and Green chronology

- Red test-only commit: a17359533d15de5b2dad7bdf0af7cebf3f6f57c8. Production app SHA at this commit remains a3e96eddbe6ecff7d19110266959736928db57bf83507f4c6eaa4f9a7cca4bc5. Exact failing test bytes match red-test.py.txt (0c6f3831020b20005d1ce81d8981a9591e47af7b79ef1240df8f0fab8b4122e2). Red exit1 is the genuine stale-success assertion.
- First Green exit1 is retained: all new status regressions passed, but the former pre-mocking DELETE framing aggregate now included the newly introduced injected DELETE500. Its mocked request lacks browser transport-added Content-Length; actual delivered DELETEs have0. Added explicit request phase capture and scoped the framing aggregate to normal actual requests, retaining the actual success DELETE and normal confirmed DELETE. No production framing change or relaxed framing assertion.
- Green-2 exit0;26 assertion groups pass. Actual new-process persistence PIDs148579→148814 on the same temporary SQLite DB; both processes exit0. Both real captured DELETEs carry Content-Length:0. Normal browser console errors are absent; expected errors retain explicit injected-phase/actual413 attribution.
- Final scoped Ruff, mypy, JS syntax and Python compilation all exit0. Backend is unchanged; caller owns independent37-test rerun.
- Fix commit after actual Green: 50170859b1658ea808c61c703e351e577cd548b8. Includes only static/app.js and the request-phase refinement in tests/browser_task_board.py. Git proof records commit details, source diff, exact Red match and clean scoped source status.

## Commands

- python -B tests/browser_task_board.py --output reports/implementation/sqlite-task-board/T-003/work/rt-0005/red --screenshots reports/visual-evidence/sqlite-task-board/rt-0005/red — exit 1
- python -B tests/browser_task_board.py --output reports/implementation/sqlite-task-board/T-003/work/rt-0005/green --screenshots reports/visual-evidence/sqlite-task-board/rt-0005/green — exit 1
- python -B tests/browser_task_board.py --output reports/implementation/sqlite-task-board/T-003/work/rt-0005/green-2 --screenshots reports/visual-evidence/sqlite-task-board/rt-0005/green-2 — exit 0
- /tmp/sqlite-task-board-quality-tools-n0vojfhn/bin/ruff check tests/browser_task_board.py — exit 0
- /tmp/sqlite-task-board-quality-tools-n0vojfhn/bin/mypy --python-executable /opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python --follow-imports=silent --cache-dir reports/implementation/sqlite-task-board/T-003/work/rt-0005/mypy-cache tests/browser_task_board.py — exit 0
- node --check static/app.js — exit 0
- python -B -c 'from pathlib import Path; p=Path('"'"'tests/browser_task_board.py'"'"'); compile(p.read_text(),str(p),'"'"'exec'"'"')' — exit 0

The initial and final static records are both retained. Full request/response/console records, process arguments, exact restart state, timings, malformed variants and style/contrast calculations are in Green-2 observations.json. Browser version154.0.8037.57 and Playwright1.62.0 are recorded there.

## Visual evidence

Early actual desktop/mobile and per-method pending/failure captures are under reports/visual-evidence/sqlite-task-board/rt-0005/green-2/. Red and first failed Green captures remain in their own directories. visual-comparison.md records actual visual inspection separately from pixel files.

## Outputs

All declared paths are project-relative. Generated mypy-cache is excluded; this report is separately hashed by the caller to avoid self-reference.

| Path | SHA256 |
| --- | --- |
| static/app.js | 0599f4de7369608d0c09a233660eeedcb5bc57f2c023467489b59e5d619f038a |
| tests/browser_task_board.py | 0269273583c3136430b20c355f814414c3c58172973fa93da5ebd045cc4f4dca |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/git-proof.json | 255b18581c1088488f6701e943e260a06305299df9d9faa8c2c25420d8204c4e |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/green/observations.json | 6fc0f4b5fc23613ee2b9309a7ee824a6850149d0cca0b5d51b49083b1fb80699 |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/green/server.log | 4fd76f7e1893e57cd8f7c317ae8756f7ba97ab57a2131f23f5c322b0bb829ddd |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/green-2/observations.json | 1d04806d52c8aa8379a49743f151f2aa8bd48f75413f664ea896081bc26e7207 |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/green-2/server.log | ae633c243ce49a37c0e9b31a003b7c855f074429a91e4a4df07f2d9d4eaede1f |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/green-2-command.json | 8c80f7a4ccc689fae37dec8d5374a3e4d261ee108f9cd389e6cb3d454b2cd0ec |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/green-2.log | da97407a19d773953ddc19afdb23252e1d026b34242feb31139f9f83e14ede49 |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/green-command.json | 2eb7ae48ac1e44dab49726336e02419309cd81119dc9cb6890f7f1f0e37456bf |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/green.log | fcc828bf054f78f519fdef9f44216751baef81d4340854bba14ea30d6081b477 |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/red/observations.json | e8e8afe1bed1b1040ae544f1f5258201130eb0cc0c203bc8f32479adff68fda9 |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/red/server.log | 0cfcd98321d9a13b8dfd469274c82ac6cb295d6f32bc1bcfd48d4c63d7db8c40 |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/red-command.json | 1401fdcb35a86fce0f2654fe043b002baf948ae9a17574d90d1842fdd863287c |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/red-test.py.txt | 0c6f3831020b20005d1ce81d8981a9591e47af7b79ef1240df8f0fab8b4122e2 |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/red.log | 9426837a79286a20fe6e9e5422d0e55855d23538006991d276b8d89089260f63 |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/static-checks-final.json | 7b091ce8e0a8cd5e7a0bb955a8de3433f5a46a34537038180ec0f5b3ad4eb041 |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/static-checks.json | 7b091ce8e0a8cd5e7a0bb955a8de3433f5a46a34537038180ec0f5b3ad4eb041 |
| reports/implementation/sqlite-task-board/T-003/work/rt-0005/visual-comparison.md | 3c89d67d00ea7854dcaf8d81dc22e82f94dc4ed2fc1c8ef7b99f8e40c3e6396d |
| reports/visual-evidence/sqlite-task-board/rt-0005/green/desktop.png | 249cf4f81cb8bceebf2f4cdab2d8642780f42e95f5bd8d42b979a0896d889082 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green/early-desktop.png | 4453491084f9eea9fd0c9c50cace6ab21ccef68660181e82b7bc79a41271e7e5 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green/early-mobile.png | e806501c5f4ea3f865244b789f8c5be4addf4fefb95b7ef2d15892d6dcad08ac |
| reports/visual-evidence/sqlite-task-board/rt-0005/green/empty.png | 81736ec99d4954bce6cfcb0ad331fe3d8931b2d734c0d9d04aa068fe4b4cf7ba |
| reports/visual-evidence/sqlite-task-board/rt-0005/green/loading.png | c26e71aabf4f7f7f5ec00fee82389c1d30f94e0480694c806bf342b87b440447 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green/mobile.png | 84738215732e480e55cd8a984361a76888fc07aca06b4ad0441b5aafd1461ab7 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green/read-error.png | bf0c805da79c46be58f2fce3e3f9cfb66b954f273cb01cd65965d12285efa8e0 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green/rt0005-delete-failure.png | fa9b3c5cd557bd4df4c39b8b437f8bb16031c20cd1cc3e2e97145bd027f40b54 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green/rt0005-delete-pending.png | bc883f9b83b411b35a7819a322b33cefbcb012824ea573af9a09d95eee1d2f43 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green/rt0005-patch-failure.png | c84dcbfd5dcbc8a4aa7c3ba21933fdfa98559597f865e18171bd2a9e0668c493 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green/rt0005-patch-pending.png | af5eb333c67b742f193b6ef1c9a0f834b9ac223e2c0c7576f029b3ee3a8a3bde |
| reports/visual-evidence/sqlite-task-board/rt-0005/green/rt0005-post-failure.png | b000039b2d526d164b22a46bf95be5eebe8177a0ab41fe5708200ef1f2561b8c |
| reports/visual-evidence/sqlite-task-board/rt-0005/green/rt0005-post-pending.png | b3cabe8b60f71b5baf17438c2933b75aae11ff6a484cd7224cb877befe126062 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green/write-error.png | 2d0a5e63b0ac11ac0b96bda2436ad0a7a233a5a0af2e789b7b7e640c9a09512a |
| reports/visual-evidence/sqlite-task-board/rt-0005/green/zoom-200.png | 3e2f795f41e87596bb4ae76485ed08814fc94c34ce825c8da31c46af2084d8bf |
| reports/visual-evidence/sqlite-task-board/rt-0005/green-2/desktop.png | 249cf4f81cb8bceebf2f4cdab2d8642780f42e95f5bd8d42b979a0896d889082 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green-2/early-desktop.png | 4453491084f9eea9fd0c9c50cace6ab21ccef68660181e82b7bc79a41271e7e5 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green-2/early-mobile.png | e806501c5f4ea3f865244b789f8c5be4addf4fefb95b7ef2d15892d6dcad08ac |
| reports/visual-evidence/sqlite-task-board/rt-0005/green-2/empty.png | 81736ec99d4954bce6cfcb0ad331fe3d8931b2d734c0d9d04aa068fe4b4cf7ba |
| reports/visual-evidence/sqlite-task-board/rt-0005/green-2/loading.png | c26e71aabf4f7f7f5ec00fee82389c1d30f94e0480694c806bf342b87b440447 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green-2/mobile.png | 84738215732e480e55cd8a984361a76888fc07aca06b4ad0441b5aafd1461ab7 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green-2/read-error.png | bf0c805da79c46be58f2fce3e3f9cfb66b954f273cb01cd65965d12285efa8e0 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green-2/rt0005-delete-failure.png | fa9b3c5cd557bd4df4c39b8b437f8bb16031c20cd1cc3e2e97145bd027f40b54 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green-2/rt0005-delete-pending.png | bc883f9b83b411b35a7819a322b33cefbcb012824ea573af9a09d95eee1d2f43 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green-2/rt0005-patch-failure.png | c84dcbfd5dcbc8a4aa7c3ba21933fdfa98559597f865e18171bd2a9e0668c493 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green-2/rt0005-patch-pending.png | af5eb333c67b742f193b6ef1c9a0f834b9ac223e2c0c7576f029b3ee3a8a3bde |
| reports/visual-evidence/sqlite-task-board/rt-0005/green-2/rt0005-post-failure.png | b000039b2d526d164b22a46bf95be5eebe8177a0ab41fe5708200ef1f2561b8c |
| reports/visual-evidence/sqlite-task-board/rt-0005/green-2/rt0005-post-pending.png | b3cabe8b60f71b5baf17438c2933b75aae11ff6a484cd7224cb877befe126062 |
| reports/visual-evidence/sqlite-task-board/rt-0005/green-2/write-error.png | 2d0a5e63b0ac11ac0b96bda2436ad0a7a233a5a0af2e789b7b7e640c9a09512a |
| reports/visual-evidence/sqlite-task-board/rt-0005/green-2/zoom-200.png | 3e2f795f41e87596bb4ae76485ed08814fc94c34ce825c8da31c46af2084d8bf |
| reports/visual-evidence/sqlite-task-board/rt-0005/red/early-desktop.png | 4453491084f9eea9fd0c9c50cace6ab21ccef68660181e82b7bc79a41271e7e5 |
| reports/visual-evidence/sqlite-task-board/rt-0005/red/early-mobile.png | e806501c5f4ea3f865244b789f8c5be4addf4fefb95b7ef2d15892d6dcad08ac |
| reports/visual-evidence/sqlite-task-board/rt-0005/red/empty.png | 81736ec99d4954bce6cfcb0ad331fe3d8931b2d734c0d9d04aa068fe4b4cf7ba |
| reports/visual-evidence/sqlite-task-board/rt-0005/red/rt0005-post-failure.png | eca0e4c3989c8a18dc123279fc89b154935f8132d5d48dbb54d088dc4e8cf56f |
| reports/visual-evidence/sqlite-task-board/rt-0005/red/rt0005-post-pending.png | acd03b43810a5a98cb5b83a7626e5385f5060b25e3a8ca9888266f59ae51b9e0 |
