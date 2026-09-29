# Issue 137 — privacy text idempotence RED

Date: 2026-09-29. Scope: two appended tests in the existing privacy grammar suite; unchanged production. This records local RED, not implementation completion or a formal review verdict.

- Command: `rtk proxy node --test --test-reporter=spec --test-name-pattern=^PRIVACY-IDEMPOTENCE- tests/sdd-context/privacy-grammar.test.mjs`; login=false, Node v24.13.0, Darwin arm64.
- Actual one run: **2 tests, 0 pass, 2 fail, 0 skip; exit 1; corrections 0**. Existing 31 test bodies were preserved and excluded from execution.
- TEXT evaluated actual generated output for six families. Bare/single/double-quoted assignment output with Unicode/CRLF gained an extra closing bracket on a second scan; the five other families retained exact text. Original synthetic values remained absent from generated/reprocessed output.
- PREFIX passed three near/unfinished-marker controls before failing the complete assignment-marker plus contiguous synthetic suffix: the suffix survived. The closing bracket ends the current bare-value span before the whole generated marker is consumed (`plugins/sdd-context/privacy.mjs:104,175`).
- omission retains its current-scan meaning (`privacy.mjs:182`); no original-event history, journal integrity or persistence claim is made.
- Original grammar prefix: 8,442 bytes / `b5077aa06d4e380c29016824c62dbf7d375b048191610ce46f502012c071e8d5`. Expanded test: `6d59f363a1f267b24045449c900d1712dc56d908f4dc857af44663444952ab16`. Unchanged production privacy: `349fd8a55fe4c2609251927945b384c9383fd79b2a33ed69fe833da5c046eeb1`.
- Private provenance, raw output and source/test/state guards: `specs/sdd-context-continuity/verification/T-001/privacy-idempotence-red-20260929-01a0ebb9/red-run.json`; SHA-256 `a2d31a51946acb5ebe2097deebdb4d2cf7933feabbd640b528d97051f325c202`.

Stop for root's RED review/commit before GREEN. No production, JournalRecord, status, ledger, registry, frozen artifact or Git mutation occurred.

## GREEN continuation — 2026-09-29

Root reviewed RED and committed the fixed tests/note at `3fba2ee2ff54e0139c63b712558d1a3540819d6f`, then authorized the repair. Added **2 lines** in `privacy.mjs:104–105` to consume only the exact complete assignment marker before the existing terminator loop. Contiguous suffixes still enter the same redaction span; bounds and current-scan omission meaning remain unchanged.

- Actual fixed two plus prior 31 JSON/privacy tests: **33/33**; full validation: **112/112**. Each suite ran once, exit 0, failure/skip/correction 0, Node v24.13.0, Darwin arm64, login=false.
- Fixed grammar unchanged: `6d59f363a1f267b24045449c900d1712dc56d908f4dc857af44663444952ab16`. Updated privacy source: `3f70c35ffb3e3a936ac697a137473749fe04e51b66d8c3a24718b63bf1ba67ff`.
- Private actual results: `specs/sdd-context-continuity/verification/T-001/privacy-idempotence-green-20260929-01a0ebb9/green-run.json` and `validation-run.json`; SHA-256 respectively `e4da9ed8e5d1688f55795506ed774aea3477db789630f4012f92b0de4e0411ad` and `b5b4690ca238f6963992bd4cde5eef16290a9f514a8fb7d7233acb8465f7dee2`.

The earlier RED stop is superseded by this authorized continuation. Stop for root's ordinary independent review and Git processing. Tests, other production, RED evidence, prior note/report prefixes and frozen/task/status/ledger/registry inputs remain unchanged. No JournalRecord, persistence, native/CI, formal verdict or T-001 completion is claimed; no worker Git mutation occurred.

## Overlap RED continuation — 2026-09-29

Root's additional diagnostic identified the same terminator defect in overlapping spans. The preceding GREEN counts cover their fixed cases; this continuation records one appended `PRIVACY-IDEMPOTENCE-OVERLAP` test against unchanged production.

- Command: `rtk proxy node --test --test-reporter=spec --test-name-pattern=^PRIVACY-IDEMPOTENCE-OVERLAP tests/sdd-context/privacy-grammar.test.mjs`. One run: **1 test, 0 pass, 1 fail, 0 skip; exit 1**, Node v24.13.0, Darwin arm64, login=false. Prior test bodies were excluded.
- Bare assignment plus multiline PEM and bare assignment plus credentialed URL containing `]` in its path both removed the synthetic credential on the first scan. Their generated family markers both changed to assignment markers with an extra closing bracket on the second scan. One final assertion collected both failures (`tests/sdd-context/privacy-grammar.test.mjs:189–200`; overlapping family selection/replacement at `plugins/sdd-context/privacy.mjs:163–177`).
- Fixed grammar prefix remains 9,764 bytes / `6d59f363a1f267b24045449c900d1712dc56d908f4dc857af44663444952ab16`; production remains `3f70c35ffb3e3a936ac697a137473749fe04e51b66d8c3a24718b63bf1ba67ff`. Private actual evidence: `specs/sdd-context-continuity/verification/T-001/privacy-overlap-red-20260929-01a0ebb9/red-run.json`, SHA-256 `bf662b19a26daabb2a6ea62d02bc3e235e8a8604c5062f4f6c429d3794e7709b`.

Stop for root's RED review/checkpoint before further production work. Prior note/report prefixes, source/state/frozen inputs and saved evidence remain preserved; no worker Git mutation occurred. This is additional correction 1 within maximum 3; remaining allowance 2. T-001 remains incomplete.

## Overlap GREEN continuation — 2026-09-29

Root verified RED and committed the fixed test/note at `c075cb1e84f3675644c1a9c3153eed13b45349d0`, authorizing this repair. Bare assignment scanning now consumes exact complete markers for the existing six families and retains their family before the existing suffix scan/span creation (`plugins/sdd-context/privacy.mjs:84,105–117`). Contiguous suffixes remain masked; bounds, quoted/header/overlap rules and current-scan omission are unchanged.

- Actual fixed JSON/privacy **34/34**, validation **112/112**, each once, exit 0, fail/skip 0; Node v24.13.0, Darwin arm64, login=false. Tests unchanged. Source SHA-256 `fdafb645a4dc881489442d9443c780b6836b5bb202b4fd1cd5b84bccb4ca57c6`; grammar SHA-256 `80f806a43c941f13de1a5c07c4a63df9df039d3e42af4f04a544009ece44c19e`.
- Private actual command/output/UTC/environment/guards: `specs/sdd-context-continuity/verification/T-001/privacy-overlap-green-20260929-01a0ebb9/green-run.json` and `validation-run.json`, SHA-256 respectively `12996d8465a7b424c21c4ee0e9658e66eb59b26ce03f05c188515a3aff197cc1` and `62b06a3c6f43fde657e21501d907e334c528b1861d6106c8aea85ec744a6c1bb`.

The preceding RED stop is superseded by this authorized continuation. Stop for ordinary independent review; prior evidence/prefixes, fixed tests, other production and frozen/task/status/ledger/registry inputs remain preserved. No worker Git mutation or JournalRecord/persistence/CI/formal-verdict/T-001-completion claim. Correction remains 1/3; remaining allowance 2.
