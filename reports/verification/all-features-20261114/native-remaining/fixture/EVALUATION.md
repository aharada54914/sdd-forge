# SDD consumer evaluation: inclusive-calendar-days

## Scope and runtime

Run date: 2026-11-14. This isolated private Python fixture uses installed sdd-forge 1.23.1 plugins from `/workspace/.tools/sdd-forge-dev/codex-verify/plugins/cache/sdd-plugins/`. The preexisting installed-runtime inventory is retained in `evidence/installed-runtime-inventory.json`. No managed policy/model selection was requested or performed. Native configured Codex tools and a real separate investigation agent are used. No development-source or other-application changes are authorized.

## Adoption — complete

Used installed `sdd-adopt/SKILL.md` and its bundled checker/templates. Initial checker exit 1 identified six missing required items. Created `AGENTS.md`, `specs/.gitkeep`, `reports/implementation/.gitkeep`, `reports/quality-gate/.gitkeep`, `docs/adr/.gitkeep`, and `docs/review-tickets/.gitkeep`. Created `CLAUDE.md` as required by skill step 4; its checker classification is advisory, but the user's explicit skip concerns advisory directories. Both `contracts/` and `docs/architecture/` were skipped. No ADR drift, conflicts, or unresolved product questions.

First post-adoption check and second skill invocation each exited 0 with no missing items. The second invocation applied the same process: existing files were retained, advisory directories declined, local templates skipped, no drift. No adoption writes on that second invocation. `evidence/adoption/idempotence.json` records equal hashes for all adopted files before/after it. `original-hashes.json`, `after-first-hashes.json`, and `after-second-hashes.json` prove that every original tracked file (application, existing tests, README, gitignore) remained byte-identical. Initial supplied hash evidence also agrees.

Supported gap: checker reports `host: local`; `git remote -v` exits 0 with empty output. CI/issue/PR templates were skipped per skill step 5. No remote was invented. Raw commands, outputs, and exit statuses are retained under `evidence/adoption/`.

## Investigation — complete

Dispatched installed `investigate-codebase` bugfix procedure to the real separate native agent `/root/investigate` without model overrides. It read the installed skill, investigator role, references and templates, and inspected source without writing or executing tests. Parent persisted its findings in `specs/inclusive-calendar-days/investigation.md`, `codemap.md`, and `baseline-behavior.md`. INV-001–INV-010 and BL-001–BL-009 distinguish defective counts from rejection behavior that must remain. Source-derived observations are explicitly labeled; runtime results belong to diagnosis. The parent subsequently updated AGENTS.md's active-spec list as its template requires; this later workflow edit does not change the measured second-adoption idempotence result.

## Diagnosis — complete; production repair deferred

Used installed `diagnose` skill and diagnosis-loop policy, with its report template. Detailed report: `reports/diagnosis/inclusive-calendar-days.md`. Actual command sources, outputs, exits, and timings are retained under `evidence/diagnosis/`.

1. Baseline: Python 3.12.14; existing two rejection tests pass, exit 0.
2. Added only `test_inclusive_calendar_days.py`. Exact same-date assertion ran twice against unchanged production: `AssertionError: 0 != 1`, exit 1, about 0.06 seconds each.
3. Presented three ranked falsifiable hypotheses to the user before testing: missing endpoint in arithmetic, changed parsed dates, incorrect equality/reversal guard.
4. Three isolated process-memory probes found elapsed-day counts exactly one below inclusive expectations, preserved parsed dates, and correct guard behavior. Each probe exited 0. No temporary probes were inserted into source.
5. Expanded permanent regressions cover adjacent/multi-day/month/year/leap boundaries, Gregorian century cases, date extrema, invalid input at either endpoint, and reversed boundaries. Full suite: 6 methods, 12 failing positive-count assertions, exit 1. Separate original and expanded rejection checks: 4 methods pass, exit 0.

Confirmed root cause: `calendar_days.py:7` computes elapsed days rather than inclusive endpoints. Proposed future minimal repair is adding one to that result, preserving parsing and reversal guard. Phase 5's production repair is explicitly deferred under the skill boundary and user instruction; no green repaired-production result is claimed.

Authorized local test-before-fix commit: `33d96159b2e0a91237c1129d6aa363da55a72e86` (`test: record inclusive calendar regression before production fix`). It includes only the new regression test and diagnostic report/evidence, with original production unchanged. No push occurred. Other adoption/investigation/evaluation evidence remains in the workspace.

## Lite specification — BLOCKED before artifact generation

Invoked installed `lite-spec/SKILL.md`. Complete user source is preserved verbatim in `evidence/intake/user-source.txt`; no exclusions or approval-fixture wording were removed or paraphrased to obtain eligibility.

- Preconditions: adopted required structure passed with no missing items.
- Actual native canary dispatch was denied by the active PreToolUse hook. Verbatim denial is retained in `evidence/lite-entry/recorded-result.json`, bound to the fresh emitted nonce. The installed verifier returned `HOOK_ACTIVE`, exit 0 (`verify-response.txt`). This was a real dispatch, not a synthetic fixture or inferred hook result.
- Subsequent physical existence check found neither Project Context nor sentinel (`context-presence.txt`). Therefore G3 resolves DISABLED_LEGACY and C1 COMPATIBILITY_FALLBACK; explicit user Lite choice selects the Lite candidate. No Capability Registry fragment is required. No sentinel cleanup is needed.
- Mandatory risk command:

```sh
bash /workspace/.tools/sdd-forge-dev/codex-verify/plugins/cache/sdd-plugins/sdd-lite/1.23.1/scripts/check-risk-upgrade.sh evidence/intake/user-source.txt
```

Actual output:

```text
full-required: AUTH_BOUNDARY; triggers=AUTH_BOUNDARY
exit_code=10
```

Evidence: `evidence/lite-entry/risk-upgrade.txt`. The installed skill's Risk-Upgrade Gate says exit 10 must “stop before any lite artifact write” and direct the caller to `sdd-bootstrap-interviewer`; an explicit Lite choice cannot override it. Its bounded lexical policy recognizes only narrowly formatted exclusion headings/bullets and one exact approval sentence. The complete request contains `auth` in a prose exclusion and `authorization` for disposable approval fixtures; both remain scanned. This is a workflow eligibility false positive relative to the user's explicitly excluded product scope, not evidence that the helper requires authentication.

**Unavoidable blocker within this validation run:** the installed mandatory risk check refuses the unchanged complete request. No platform capability is missing: native independent investigation and the real hook handshake worked. Per the user's stop condition, no full-workflow expansion was started. No `requirements.md`, `design.md`, or `tasks.md` was created; the Lite specification is not ready for the parent approval fixture. No approval fixture was applied, no task was self-approved, and no new human click was claimed. If continuing under the current installed policy, its prescribed route is full `sdd-bootstrap-interviewer`; that is outside this requested stop.

## Other observed tool friction

The active deterministic hook rejected two compound shell wrappers as ambiguous, and rejected Python wrappers that embedded or merely inspected protected canary/context paths. These attempts did not execute. Equivalent direct supported operations succeeded: explicit apply_patch to the ordinary evidence JSON, direct handshake verifier command, and `ls -ld --` existence check. The canary denial itself was expected. No guard, configuration, protected file, or installed script was modified; no bypass or elevated permission was used. These recoverable wrapper rejections are distinct from the final risk-gate blocker.

## Final integrity and handoff

`evidence/final-integrity.json` confirms all four original files are byte-identical, production in the regression commit matches the original hash, all 404 installed-runtime inventory files remain unchanged, no temporary DEBUG probes exist in root Python source, and no Lite specification files exist. Advisory directories remain absent. No application repair, new dependency, network/API/DB/auth/UI feature, merge, push, or publication occurred.

Result: adoption and idempotence PASS; independent investigation COMPLETE; red-capable diagnosis COMPLETE with production repair deferred; mandatory native hook handshake PASS; Lite risk-upgrade BLOCKED (AUTH_BOUNDARY, exit 10). Stop at the requested unavoidable-blocker boundary.

## Caller resubmission — Lite specification ready for inspection

This continuation preserves the preceding evaluation as history. The caller corrected its own test-handoff wording and explicitly clarified that the prior root-written handoff accidentally mixed test-runner permissions with product requirements. This is an intake correction, not a product behavior change or guard relaxation. The complete resubmitted request is stored verbatim in `evidence/intake/user-source-revised.txt`. It uses the installed policy's existing documented `Scope exclusions` heading and closed-vocabulary bullet grammar. Every positive requirement remains in the submitted body and the resulting specification.

The first request (`evidence/intake/user-source.txt`), its exit-10 AUTH_BOUNDARY refusal (`evidence/lite-entry/risk-upgrade.txt`), all original failure records, and the existing independent investigation and red diagnosis remain unchanged. The earlier blocker was not overwritten or reclassified as a pass.

### Actual revised entry checks

Used the same installed sdd-forge 1.23.1 `lite-spec` workflow with normal native Codex configuration, no managed policy selection, no fabricated identities, and no plugin edits. Raw native denial and actual command outputs are retained under `evidence/lite-entry-revised/`.

- Required structure check: exit 0, no missing items, host local; advisory directories remain skipped.
- Fresh emitted nonce: `cc7b4ca8cafdcb1cc9f910bac362c6bc`. Parent attempted the emitted native apply_patch canary exactly once; hook denied it. The verbatim response was recorded, and the unchanged verifier returned `HOOK_ACTIVE`, exit 0.
- After the handshake, the physical existence check found Project Context and sentinel absent. G3 DISABLED_LEGACY / C1 COMPATIBILITY_FALLBACK apply; explicit caller Lite selection resolves Lite. No Capability fragment or sentinel cleanup is required.
- The unchanged installed `check-risk-upgrade.sh evidence/intake/user-source-revised.txt` returned exactly `lite-eligible`, exit 0. No upgrade result was overridden, and no submitted text was removed to force eligibility.

### Reviewable artifacts

- `specs/inclusive-calendar-days/requirements.md`: REQ-001–REQ-004 retain inclusive endpoints, same/adjacent/multi-day/month/year/leap/century coverage, invalid/reversed rejection, existing seam, stdlib, tests and evidence preservation; source INV/BL references and concrete examples are included.
- `specs/inclusive-calendar-days/design.md`: minimal future change to elapsed days plus one, preserving parser and reversal guard. Existing regressions are reused. No new dependency or product surface. Section 6 records the additive graduation route if scope later requires full SDD.
- `specs/inclusive-calendar-days/tasks.md`: one task T-001, `Approval: Draft`, `Status: Planned`; no Risk tier. Scope, observable completion conditions, verification commands, and the approval prerequisite are explicit.

No product Open Questions remain. The installed `check-task-state-lite.sh` returned `Task state (lite) check passed for 1 task(s).`, exit 0; actual result is retained in `spec-checks.json`. This is a draft-state validation, not an implementation or quality-gate verdict. `git diff --check` also exited 0. Application tests were not rerun in this documentation-only continuation; the genuine pre-fix red runs remain the relevant evidence and production has not changed.

### Preservation and approval boundary

Before continuation, hashes were recorded for all 48 preexisting workspace artifacts excluding Git internals and Python caches. Original EVALUATION.md and AGENTS.md copies were also retained. These two documents receive append-only updates; their prior bytes remain intact. `preservation-check.json` records final comparisons, original-source integrity, and installed-inventory verification. No previous evidence file is overwritten.

Result: revised intake accepted by unchanged guards; complete Lite specification ready for the parent test harness to inspect. No approval fixture, human click, implementation, Done transition, merge, push, or publication was performed. No new independent review is claimed; the genuine prior `/root/investigate` result is retained. The caller's fixture remains the next approval step. After approval, the documented continuation is `/sdd-ship --lite specs/inclusive-calendar-days/tasks.md`, including its mandatory ship-time eligibility recheck and later Lite gate.

Additional observed friction: a supplemental Python preservation-check wrapper contained a negative assertion that the protected approved-state text was absent. The native hook rejected the wrapper as an attempted task approval, even though it read tasks and wrote only an evidence JSON; the command did not execute. The already-successful installed task-state checker remains the state validation. A separate preservation-only comparison omits that redundant state assertion and uses ordinary file reads. No task state or hook was changed.

## Approved disposable ship run — COMPLETE

The caller inspected the three specifications and applied the previously permitted test-only approval fixture before this continuation. `evidence/approval-fixture/record.json` identifies the outer harness actor and explicitly disclaims a new human click or production acceptance. The task's starting SHA-256 matched that record's after-hash; requirements/design matched the reviewed snapshots. The native consumer did not set task approval. The latest user instruction authorizes implementation through completion and supersedes earlier stop-before-implementation notes, which remain preserved as history.

### Ship entry and implementation

Used installed `/sdd-ship --lite specs/inclusive-calendar-days/tasks.md` orchestration with `implement-task`, independent `lite-gate`, and the required all-Done retrospective. No managed policy selection, model override, development plugin, or source modification was introduced.

- Required structure checker passed (exit 0); local host and advisory-directory gap remain unchanged. Advisory `get_next_sdd_command` was unavailable in active tools, so the skill's file-based flow continued.
- Fresh native ship canary attempt was denied; the unchanged verifier returned `HOOK_ACTIVE`, exit 0, nonce `621cac1e5127495f8a1b6ff4a16fa054`. Project Context and sentinel were physically absent. G3/C1 compatibility and explicit `--lite` resolved Lite.
- Mandatory ship-time scanner received the complete approved T-001 block followed by requirements.md, including all exclusions and approval notes. Result: `lite-eligible`, exit 0. Input and actual outputs are in `reports/implementation/inclusive-calendar-days/T-001-scratch/ship-risk-input.txt` and `ship-entry.json`.
- T-001 progressed Planned → In Progress. The only production change is `calendar_days.py:7`: elapsed days plus one. Parsing, signature, reversal guard and exception message remain unchanged. Both test files were preserved byte-for-byte.
- Actual implementation checks passed: focused same-day command (1 method), full `python3 -m unittest -v` (6 methods with all boundary/rejection subcases), and scoped diff review. The genuine earlier RED records and failing-test commit remain intact.
- Local production commit: `b643938e6f0246a5b68857dd78981939027b2c4c` (`fix: count both calendar date endpoints`), descended from RED evidence commit `33d96159b2e0a91237c1129d6aa363da55a72e86`. Actual scoped Git tree/blob/diff/ancestry results and GREEN run/source hashes are retained in the task scratch directory. No push.
- Implementation report: `reports/implementation/inclusive-calendar-days/T-001.md`, with exact output SHA-256 rows and native parent identity `/root`. T-001 then reached Implementation Complete. The report is frozen at its handoff snapshot; it does not claim independent self-review.

### Independent native Lite reviewer and final gate

A fresh native delegated context `/root/lite_gate` performed the one independent Lite review. It did not implement the task, received no full conversation history, inherited the configured parent model without override, and invented no host/session identity. Its actual evidence run identifier is `fc0ce298-ff60-4308-8d65-8fb2c686bfdb`.

- Independent review: `reports/implementation/inclusive-calendar-days/T-001-review-1.md`.
- Authoritative quality report: `reports/quality-gate/T-001.md` — `VERDICT: PASS`, exact Task ID and Feature recorded.
- Installed adapter execution: `reports/quality-gate/T-001.execution.json`.
- Actual direct checks: `reports/quality-gate/inclusive-calendar-days/T-001-scratch/direct-execution.json`, with separate stdout/stderr/exit files.
- Reviewer performed its own fresh native handshake (nonce `3eb0efcb3f13a0ecbd31a8acf1fd0858`), obtained `HOOK_ACTIVE`, independently resolved absent Project Context and explicit Lite, and ran the installed scoped placeholder scan.
- Reviewer reran the focused same-day and full six-method suite. Every required inclusive boundary and invalid/reversed regression passed. All 22 implementation output hashes, both original test files, and 64 unchanged historical artifact hashes passed its integrity checks.
- No lint/typecheck/build command is configured; the gate records each as justified N/A. The installed adapter's package/paired-script discovery does not cover this README-only Python command, so the reviewer used the skill's permitted direct-command fallback. With no Project Context, the Registry-required list is legitimately empty; adapter PASS alone was not treated as the complete verdict.
- Only after writing its PASS report did the independent gate set T-001 to Done. It then ran `check-task-state-lite.sh specs/inclusive-calendar-days/tasks.md reports/quality-gate reports/implementation .`; output `Task state (lite) check passed for 1 task(s).`, exit 0. Exact final results: `reports/quality-gate/inclusive-calendar-days/T-001-scratch/final-state.stdout`, `final-state.stderr`, and `final-state.exit`.

No quality findings, review tickets, failed quality-gate run, or remaining blocker. Evidence observes dirty workflow artifacts and `reuse_allowed: false`; it does not certify a clean whole-repository revision. Earlier intake and wrapper refusals remain recorded and are not relabeled as passes.

### Ship completion and retrospective

All targeted tasks reached Done for the first time, so the installed workflow-retrospective was invoked as required. Report: `reports/retrospective/20261114T051217Z-inclusive-calendar-days.md`. The unchanged installed emitter wrote `reports/runs/RUN-20261114T051217Z-inclusive-calendar-days.json`, exit 0; no emitted metric was hand-edited. One task/attempt, one independent Lite review, one passing quality gate, no escalation or ticket. Full-track review metrics are N/A, and one-task confidence is low; no WFI or workflow rule change was proposed.

Final result: **1 implemented, 1 Done, 0 remaining; no blocker**. Production change is limited to the approved inclusive count repair. Both test files, complete revised intake, original refused input, every prior RED/failure record, and caller approval fixture remain intact. Final preservation evidence is `evidence/ship-completion/integrity.json`. No plugin source, other fixture, new dependency, product surface, remote, publication, or production rollout was touched.
