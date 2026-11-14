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
