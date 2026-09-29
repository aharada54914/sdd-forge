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
