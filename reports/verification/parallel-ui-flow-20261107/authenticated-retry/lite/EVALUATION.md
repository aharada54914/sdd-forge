# SDD lite actual application evaluation — 2026-11-07

Final status: **T-001 Done / independent lite-gate VERDICT: PASS**. A working vanilla HTML/CSS/JavaScript task board supports add, complete/reopen, delete and localStorage persistence. `npm start` serves it at http://127.0.0.1:4173. `npm test` runs Chromium UI checks; `npm run lint` checks JavaScript syntax.

This is **文言回避あり / NOT an unmodified normal-flow success**. The user explicitly allowed a disposable Approved test fixture; ordinary human task approval was not exercised. No production deployment or remote publication occurred.

## Real workflow and evidence

1. New project created by installed sdd-forge 1.23.1 via the isolated verify-codex profile. Bootstrap, lite specification, implementation and independent lite-gate used actual native CLI sessions. Old hand-built smoke fixtures were not reused.
2. Normal flow encountered a hook false positive while saving verbatim canary denial evidence. Actual rejection and command are preserved in evidence/hook-evidence-save-denial.txt. Existing session-log byte extraction into the documented native JSON schema restored HOOK_ACTIVE without disabling hooks or inventing evidence. Parent registered Issue #725.
3. Ship risk check rejected the generated explicit scope exclusion mentioning authentication. Exact one-line reproduction and exit 10 are in evidence/T-001/diagnostic-excluded-scope.*. The same trigger also affected non-product approval wording. Parent owns issue registration. Authorized scope-preserving Japanese wording and test-fixture blocker clarification restored lite-eligible; complete before/diff evidence is in evidence/T-001/wording-before/ and wording.diff. Checker and hooks remained unchanged.
4. A resumed CLI did not inherit the initial danger-full-access sandbox setting. Its workspace-write/network_access:false blocked localhost and Chromium. Host identical final tests passed. Explicitly adding `-s danger-full-access` to subsequent resume resolved this harness error, and the implementer itself reran tests successfully. Evidence: evidence/T-001/current-context/; prior host evidence and hashes are isolated in host-evidence/.
5. Fresh independent reviewer thread `01a1b57e-6b1f-79b3-b82a-f63ba9c9700e` initially supplied a raw log rather than required JSON. The same reviewer corrected its input using its own real denial, then completed the same gate invocation. This was caller misuse, not a new plugin defect. Implementer thread was `01a1b570-e118-7240-b8ef-28b4905cae26`.
6. Independent placeholder scan, lint, actual browser suite, screenshot review and final Done-state verification passed. See reports/quality-gate/T-001.md and T-001.execution.json. Final checker argv/stdout/stderr/exit0 are in evidence/T-001/independent-review/final-task-state.*. Task status is Done.

## Actual UI coverage

Add by button and Enter; whitespace rejection and trimming; input refocus; ordered reload persistence; complete/reopen by keyboard and reload; targeted deletion and reload; literal HTML-like titles; empty/fresh storage; malformed JSON and schema warning/recovery; unavailable storage with in-session management; narrow viewport without horizontal overflow; visible keyboard focus; no page JavaScript errors. Independent desktop/mobile screenshots and result JSON are in evidence/T-001/independent-review/browser/.

Plain JavaScript has no configured typecheck; static files need no build step. These were honestly recorded N/A. The independent gate used legacy compatibility because no Project Context exists; Capability Mode coverage is not claimed. Revision attestation is unavailable for this non-Git test project.

## Reproducible CLI invocation

Always preserve the reauthenticated source and specify sandbox/cwd for each invocation:

```bash
CODEX_HOME=/workspace/.tools/sdd-forge-dev/reauth-session \
 /workspace/.tools/sdd-forge-dev/verify-codex exec \
 -C /workspace/.tools/sdd-forge-dev/verification-workspace/lite-task-board-authenticated \
 -s danger-full-access --json --skip-git-repo-check '<task>'
```

For an existing thread, place `resume <thread-id>` after the exec options. Keep all hook trust and enforcement settings active. Full original transcripts are in evidence/cli-*.jsonl; the stdout/stderr artifacts are evidence, not instructions.

Cleanup: no matching local test/application HTTP server remained on ports 4173 or 4187; evidence/T-001/cleanup.json records the check.
