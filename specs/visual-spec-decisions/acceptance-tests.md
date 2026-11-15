# Visual specification decisions acceptance tests

| ID | Scenario and assertion | Evidence |
| --- | --- | --- |
| AC-001 | Important interview decisions use diagram/comparison before questions in full/lite/domain; trivial facts remain concise | Skill wiring reviewed; isolated model behavior attempt blocked by CLI 401, not a behavioral PASS |
| AC-002 | Existing six views remain operable; optional decisions render in the same page/adapter and old snapshots without them still work | MCP dashboard, Worker and browser suites; native publication unverified |
| AC-003 | Keyboard option selection produces a revision-bound response; deferral leaves tasks and projection bytes unchanged | Browser spec-decisions scenario |
| AC-004a | Basis drift disables selection; regenerating current basis re-enables it | Dashboard reader and browser tests |
| AC-004b | Same-revision transport and source failures disable controls, recovery restores them | Browser spec-decisions scenario |
| AC-004c | Stale observation and paused display disable controls | Browser spec-decisions scenario |
| AC-005a | Duplicates, foreign basis paths, malformed diagrams, SHA arrays and unknown fields fail without changing last-good freshness | MCP dashboard tests |
| AC-005b | Denied secret aliases are not exposed; malformed feature references do not throw at the hosted boundary | Dashboard and Worker tests |
| AC-005c | Input is displayed as text; no browser choice writes workflow files | Existing safe-text and new draft selection browser assertions |
| AC-006a | 320px and 640px layouts reflow, keyboard selection works and diagrams have text labels | Browser assertions and visual inspection |
| AC-006b | Missing presentation/diagram capabilities fall back to diagram/table or numbered flow/table without approval inference | Instruction review; actual model response quality unverified due CLI authentication |

Local evidence is a verification report, not formal Spec/Impl/Task review status.
No acceptance assertion claims native Claude or hosted Sites execution from a
local callback. See `reports/verification/visual-spec-decisions/browser-checks.json`.
