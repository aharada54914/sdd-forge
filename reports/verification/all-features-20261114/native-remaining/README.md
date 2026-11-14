# Native brownfield and bugfix workflow verification

This directory records an actual isolated Codex consumer run, not scripted verdicts or a model comparison. The native thread is `01a1d866-9936-7771-8241-1fbe520b6808`; configured model `gpt-6-astra`, effort high. Source runtime was installed through the supported plugin CLI, with 404 source/cache files hash-compared. No original completed Lite/Full/SQLite applications were modified.

## Scope and current outcomes

- Existing-repository `sdd-adopt`: PASS. Initial missing required structure created; application, original tests, README and gitignore hashes unchanged. Repeating adoption made no artifact changes. Local repository has no remote, so hosted CI/PR/issue templates were intentionally skipped.
- `investigate-codebase` in bugfix mode: completed by a real separate native agent. Cited INV/BL artifacts preserve the known defect and rejection behavior.
- `diagnose`: actual initial same-day RED, expanded 12 failing positive assertions, and passing rejection tests before any production repair. Temporary probes were not retained in application source. Pre-fix tests were committed.
- `lite-spec`: first caller-written handoff was conservatively refused (AUTH_BOUNDARY, exit 10). The caller resubmitted the same product requirements using the existing documented exclusion grammar and separated operational permission wording; unchanged scanner and fresh hook handshake then passed. Draft requirements/design/one task were produced and checked. Original failure remains in evidence.
- Approval: outer test harness inspected the three draft documents and applied the previously permitted disposable test-only fixture, changing only Approval Draft to Approved. This is not a new human click, production sign-off, or native self-approval. Snapshots and hashes are retained.
- `sdd-ship --lite`: actual ship-time hook/risk checks passed; a single production arithmetic line was changed. Focused and six-method full suite passed with both test files unchanged. Fresh native reviewer `/root/lite_gate` independently passed the Lite gate, set T-001 to Done, and ran post-Done task-state validation with exit 0. The adapter had no configured additional commands; the actual documented Python tests, placeholder check, integrity review and final state check were independently executed and recorded.

## Evidence and limits

`fixture/EVALUATION.md` is the native detailed account. `fixture/evidence/adoption/`, `diagnosis/`, `lite-entry*/`, `approval-fixture/`, and implementation/quality reports contain exact checks and outcomes. Raw session rollouts, native event streams, authentication files, configuration secrets, caches, and Git internals are excluded from this curated directory.

This fixture is a private stdlib calendar helper, with no UI/DB/provider integration. It adds brownfield/bugfix entrance coverage to the separately verified UI applications; it does not prove those unrelated surfaces. The exclusion resubmission proves the documented grammar, not arbitrary natural-language negation understanding. Advisory remote-host templates and managed routing were not exercised here. All native identities and checks must be interpreted with those limits.

Final native ship outcome: **1 implemented, 1 Done, 0 remaining, no blocker**. Required retrospective and the unchanged machine-readable run-record emitter completed. See `fixture/reports/retrospective/20261114T051217Z-inclusive-calendar-days.md` and `fixture/reports/runs/RUN-20261114T051217Z-inclusive-calendar-days.json`. `observer-verification.json` independently confirms all 404 installed runtime hashes unchanged and only the intended original production file modified.
