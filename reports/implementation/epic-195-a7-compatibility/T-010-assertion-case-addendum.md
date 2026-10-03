Run ID: a7-t010-assertion-case-20260927-01
Task Attempt Count: 1

# T-010 narrow correction addendum

Scope: reject mis-cased assertion identifiers in the shared PowerShell lookup, matching Bash's exact `jq` comparison. No manifest, grammar, task state, approval, verdict, or frozen specification changes. This is correction cycle 1, not a live-model trial or a quality-gate verdict.

## High-risk preflight (before implementation)

| Evidence field | Counterpart | Failing mismatch test |
|---|---|---|
| Manifest `assertion_id` lookup identity (existing, unchanged persisted field) | Bash evaluator exact `.assertion_id==$ac`; REQ-007 / AC-035 unknown-assertion rejection | New `case-sensitive-assertion` case requests `ac-004` against `AC-004`, requiring exit 2, unknown-identity diagnostic, and no rendered skip line. It must fail before the lookup correction. |
| Local RED/GREEN result claims in this addendum | Actual command exit and suite output | RED must report failure before correction; GREEN must report success after correction. No independent-verdict or traceability-status claim is persisted. |

Applicable root AGENTS and T-010 Must Read were read; structure precheck passed (CLAUDE.md advisory only). Existing implementation report provenance and cross-model-consent gap remain unchanged. Formal QG/Done is not claimed.

## Measured correction evidence

Base: `b8aeb796df666b648f3994867459b4be87de9699`. All commands used `rtk proxy`, with non-login shell. No model invocation, external write, or protected-hook bypass occurred; edits were accepted without a protection refusal.

RED, after adding only the negative test:

```text
pwsh -NoLogo -NoProfile -File tests/skip-allowlist-manifest.tests.ps1 -Case case-sensitive-assertion
FAIL: mis-cased assertion identity is rejected without rendering
0 passed, 1 failed
exit: 1
```

Production correction: only `Where-Object assertion_id -eq $Assertion` → `Where-Object assertion_id -ceq $Assertion` in `Get-Entry`. The existing diagnostic and exit handling are unchanged. The new test captures native stderr, saves the exit code immediately, requires exit 2 and the exact diagnostic text, and prohibits rendered skip output using the existing runtime-assembled marker.

GREEN, after that one-line correction:

```text
pwsh -NoLogo -NoProfile -File tests/skip-allowlist-manifest.tests.ps1 -Case case-sensitive-assertion
PASS: mis-cased assertion identity is rejected without rendering
1 passed, 0 failed
exit: 0
```

Full task-suite regression:

```text
pwsh -NoLogo -NoProfile -File tests/skip-allowlist-manifest.tests.ps1
23 passed, 0 failed
exit: 0
bash tests/skip-allowlist-manifest.tests.sh
20 passed, 0 failed
exit: 0
git diff --check
exit: 0 (no output)
```

The PowerShell suite's expected `ERROR` diagnostics are its existing negative fixtures; its exit was 0. These are implementation-run results, not independent quality-gate evidence. No new grammar, manifest value, other parity issue, task state, verdict, approval, frozen artifact, commit, or push was changed. Cross-model authorization/verification and formal QG remain outside this correction's completion claim.

## Independent bounded code review

The coordinator read both changed code files and traced the existing evaluator callers. No issue was found in this one-line correction: exact uppercase identities retain their behavior, while the shared lookup rejects a mis-cased identity before rendering. This review is not the formal quality gate.

Coordinator verification: the focused negative case passed 1/0; the full PowerShell suite passed 23/0; `git diff --check` returned 0. The unchanged Bash escalation suite passed 37/0.

An additional `bash tests/escalation-skip-activation.tests.sh` check returned 1 in its first Bash clean case. `bash -x` showed that the child suite returned 0, then the wrapper's `grep -F 'audited 1 allowlisted line'` failed. The current child prints that the resolver assertion is deferred without emitting a stale skip, so that expected audit line is absent. Neither this Bash path nor the wrapper was changed by this correction. This separate stale wrapper expectation remains unresolved; the supplemental check is not reported as successful, and no merge/Done claim is made.

## Supplemental wrapper repair

The preceding failure is retained as the pre-repair result. The wrapper's manifest mutations could no longer reach the consumer's caller-presence branch; replacing its expected message alone would erase the negative checks. Two supplemental correction cycles (path separation, then exact invalid-exit assertions) change only `tests/escalation-skip-activation.tests.sh` to exercise two distinct paths:

- Actual escalation consumers: clean caller absence succeeds with the spy self-check and explicit deferral; a caller fixture in the temporary clone fails with the missing real-invocation-driver diagnostic. The fixture is detected, not executed, and is not a live-host activation proof.
- Existing evaluator, using its own rendered line: clean evidence succeeds; active AC-004 and AC-021 both fail with activation diagnostics; zero-commit evidence is rejected with the exact runtime-specific exit and diagnostic (Bash 1, PowerShell 2).

No production consumer, evaluator, manifest, CI registration, frozen input, task status, approval, or review verdict changes in this supplemental repair. Independent coordinator review traced the consumer and both evaluator flows and read the complete wrapper diff. Measured regression results follow after execution; formal quality-gate, cross-model verification, latest-head CI and merge remain separate conditions.

Implementer and coordinator independently ran `rtk proxy bash tests/escalation-skip-activation.tests.sh` on macOS with Bash and PowerShell available: each run passed all ten cases, exit 0. Coordinator `rtk proxy git diff --check` returned 0. This resolves the preceding supplemental wrapper failure without promoting the deferred production assertion to PASS.

Implementer reran the existing manifest suites after the wrapper repair: Bash 20 passed / 0 failed, PowerShell 23 passed / 0 failed, both exit 0. No Windows execution is claimed by these macOS runs.
