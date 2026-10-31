# PR #532 review-evidence publication checkpoint

Published head: `9be0fc5428745f453330b5fad866df248f62d20d`.

The prior head `451e051424dbb3ef12211299cddbde59f823685e` failed run
`36732701670` on all three OS test jobs with
`spec top-level contract hashes are stale`. Latest independent spec a2r3,
design a3r1 and task a2r3 review evidence had not been published.

The repair publishes those existing canonical outputs and their four changed
layer/task inputs, without altering verdicts or approval/status fields.
Historical tracked evidence is retained; private identity-ledger changes,
implementation logs, raw host captures and unfinished code changes are excluded.
All 23 selected files passed the scoped absolute-path/email/credential scan
and `git diff --cached --check`.

Verification used a fresh export of exactly the staged tree, not the dirty
working tree. Bash and PowerShell feature workflow-state checks exited 0.
Claude Sonnet independently ran the full PowerShell workflow-state check
(exit 0) and the four JSON/privacy/validation test files
(191 tests: 190 pass, 0 fail, 1 Windows-native diagnostic skip; exit 0).
Claude's full Bash workflow-state command was refused before execution;
it is not counted as a successful full Bash run.

GitHub confirmed the published head and its completed CI run
[36757559757](https://github.com/aharada54914/sdd-forge/actions/runs/36757559757):
all 37 Actions jobs succeeded, including `required-checks`. The PR remains draft
and requires review. No merge, quality-gate completion, native activation or
Issue #137 closure is claimed. The two local parser/privacy default-deadline
changes remain unpublished and are not covered by that published-head CI result.

## Unpublished deadline verification

Claude Sonnet session `e3be6b5e-350e-4bd5-9338-f18e071880c8` reran the four
JSON/privacy/validation suites against the current working tree: 191 tests,
190 pass, 0 fail, 1 Windows-native diagnostic skip; exit 0.
It also executed
`specs/sdd-context-continuity/verification/T-001/default-deadline-differential.mjs`
against the exported published tree and current working tree; exit 0.
All 12 deadline cases passed: both published defaults rejected at 1500ms,
both current defaults accepted at 1500ms, and both trees rejected at 3000ms
and when an explicit 1000ms deadline was exhausted. Errors at the closed
boundary retained no stack or cause. The clock was mocked without sleeps.

The initial inline-evaluator attempts were refused by Claude's tool permission
mode and are not counted as executions. The saved standalone verification ran
without refusals or permission changes. These results do not establish native
process-lifecycle timing, installed-hook activation or task completion.

## Deadline repair publication

Commit `9511bb94b046d27ab1192dd36b9e20027a124bdc` publishes only the two
approved 3000ms default corrections and the 12-case differential check. An
independent Sol reviewer inspected the exact three file hashes and ran the
differential check successfully. Other dirty reports, ledger entries and
unfinished implementation were excluded.

The supervising agent also ran all six current `tests/sdd-context/*.test.mjs`
suites using the existing CI's required `--experimental-vm-modules` flag;
exit 0. An earlier invocation without that flag failed at the Windows adapter
test's `SourceTextModule` import and is not counted as a successful run. These
macOS tests include simulated Windows dispatch, not native Windows storage proof.

Current-head CI run
[36765488490](https://github.com/aharada54914/sdd-forge/actions/runs/36765488490)
completed successfully on the exact published head: all 37 jobs succeeded,
including `required-checks`. This is not the previous head's result.
The PR remains draft. Formal quality verification, remaining implementation and
native activation are still pending; no merge or Issue closure is claimed.

## Current-head native context checks

On 2026-10-01 the supervisor inspected the completed logs of the same
`9511bb94b046d27ab1192dd36b9e20027a124bdc` run, not a rerun or older head.
The context tests are in `mcp-tests`, not the general OS test job:

- [Windows job 110058475906](https://github.com/aharada54914/sdd-forge/actions/runs/36765488490/job/110058475906): context suites 211 pass, 0 fail, 3 platform/isolation skips. The subsequent native ACL step executed fresh private creation, owner/protected ACL assertions, existing-directory preservation and the production adapter. Its isolated full preparation check and cost diagnostic both passed, 0 skipped. Full preparation measured 1735.1ms against the approved 3000ms budget; validation 245.7ms, adapter 1218.7ms. The `create-win32-183` diagnostic came from the intentionally rejected existing-directory case, not an unhandled job failure.
- [macOS job 110058475724](https://github.com/aharada54914/sdd-forge/actions/runs/36765488490/job/110058475724): context suites 213 pass, 0 fail, 1 Windows-only skip; native preparation measured 233.4ms.
- [Ubuntu job 110058475595](https://github.com/aharada54914/sdd-forge/actions/runs/36765488490/job/110058475595): context suites 213 pass, 0 fail, 1 Windows-only skip; native preparation measured 36.2ms.

This establishes the executed native store/path/privacy cases only. It does not
prove later-task journal durability, host capture/activation, every future copy
path, independent quality-gate approval, merge or Issue completion. Preserve
the task's remaining conditions and existing correction counts.
