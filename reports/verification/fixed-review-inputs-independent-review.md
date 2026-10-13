# Fixed-input launcher independent diff review

Date: 2026-10-13
Baseline: `9b16ffba39a090cd3cf2305e986341e24096b835`
Owner: `codex/fixed-review-inputs`
Reviewer: fresh-context Codex agent `fixed_launcher_final_review`

This is the user-authorized independent development review outside the legacy
formal ledger. It is not a quality-gate verdict, reservation or Done transition.

## Earlier reported result (2026-10-13)

No must-fix findings in the implemented fixed-input/launcher slice. The reviewer
independently inspected fixed Git input binding, exact selected paths, session
guard behavior, stage-specific dependency pins and legacy compatibility.

Executed by the reviewer:

- `tests/fixed-review-inputs.tests.py`: 27 passed.
- `tests/fixed-review-launch.tests.py`: 36 passed.
- `tests/unified-launch-order.tests.py`: 9 passed.
- `tests/unified-task-launch.tests.py`: 9 passed.
- `git diff --check`: passed.

Real Node guard process cases permitted selected snapshot/invocation reads and
rejected live/outside reads, Bash commands, writes and policy/digest tampering.
These tests are not proof of real model delivery. The normalized-task fixture
mocks canonical precheck success and is not an end-to-end canonical precheck.

## Earlier boundaries (superseded by the follow-up below)

Authenticated detached approval and progress consumers are not implemented and
were not approved by this review. Real CLI/model delivery, formal reservation,
latest-head CI and whole-feature completion were not established. Windows/macOS
equivalence checks were omitted under the explicit user waiver, not marked PASS.

Owner subsequently reran the first two suites: 27 and 36 passed, respectively.
Historical failed observations and existing approval evidence remain unchanged.

## Follow-up independent review (2026-10-14)

Fresh-context reviewer `fixed_inputs_final_review` initially returned NEEDS_WORK:
fixed delivery still consulted the legacy compact hash command, and its probe
re-read live documents instead of consuming only fixed inputs. Both findings
were repaired without granting additional Bash access or weakening receipt and
out-of-scope rejection checks. The reviewer then returned PASS, independently
executing `tests/fixed-review-launch.tests.py` (44 passed) and `git diff --check`.
The initial NEEDS_WORK is retained here; PASS is not a task Done or quality-gate
transition. Detached approval/state consumers are now connected to the launcher.

Owner integration runs: 147 tests passed across fixed inputs (33), state (7),
launch (44), unified task launch (9), Bash prechecks (7), host preflight (21),
conditional inputs (17), and launch ordering (9). The launch-order fixture now
includes the investigation input it creates; that fixture correction was owner
verified, not part of the reviewer's 44-test run.

Not established: real model delivery, full task lifecycle migration, latest-head
CI or merge. Windows/macOS equivalence was explicitly waived, not passed.

## Final connected-path review (2026-10-14)

The same independent reviewer inspected the final Bash/PowerShell consumers,
authenticated detached observations, required inputs and launcher/validator
connections, and returned PASS with no remaining Critical or Major findings.
Independent execution: Bash prechecks 7, detached state 7, fixed launch 44,
launch ordering 9 (67 total), plus `git diff --check`, all passed. This includes
the investigation-input fixture correction. No reservation or historical verdict
was modified. Task Approved/Done authority remains with its existing lifecycle.

## CI integration repairs (2026-10-14)

Run 38420285663 exposed missing shared helpers in disposable test fixtures,
stale applied A3 mirrors, and stale boundary source anchors. The version-gates
failures on all three operating systems share TEST-036.4's mirror mismatch.
Fixtures now include the existing helper; applied mirrors and anchors match the
current sources. Pending unrelated mirrors remain untouched.

Owner reruns: quality transport 20, loop-driver 26, mirror freshness 6 (19
informational pending), component coverage 46, boundary anchors 32, runtime
boundary 3, regular investigation 116, hardlink 84, and symlink 84 passed.
The initial boundary run's four symlink failures were diagnostic expectations:
each operation already rejected with exit 1 and unchanged ledger. Expectations
now name the earlier conditional-input rejection; exit and ledger assertions
remain required. The final symlink rerun returned 84 PASS, 0 FAIL.

Independent reviewer returned PASS for this integration diff and independently
reran the four final Bash/impl/symlink/omitted cases: exit 1, unchanged ledger,
and the required diagnostic in each. Earlier independent checks also covered
quality transport 20, loop-driver 26, mirror freshness 6, and all 32 anchors.
`git diff --check` passed. No product rejection rule was relaxed.

Latest-head CI and merge are still pending. Additional Windows/macOS equivalence
runs are waived, not PASS; required hosted CI remains enabled.

## Static-check follow-up (2026-10-14)

Run 38424375969 reported Ruff F401 for an unused `sys` import in
`probe-nontty-review.py`. Removed only that import. Ruff on the six configured
shared-launch files, fixed-review-launch (44), and shared-launch-build (1)
passed. The independent reviewer inspected the one-line source diff, confirmed
no remaining reference or dynamic use, and returned PASS; whitespace passed.
Latest-head hosted static checks and the remaining CI still require confirmation.

## Type-check follow-up (2026-10-14)

Run 38425268819 reported 11 mypy errors: nullable dynamic import specifications
and loaders, repeated executable lookup, and a nullable legacy command key.
The two-file repair explicitly rejects missing loaders/legacy commands and
reuses the executable lookup result. Fixed-input permissions are unchanged.
Configured mypy (six files) and Ruff passed, as did fixed launch 44 and isolated
FilesOnly build 1. Independent diff review returned PASS and independently ran
fixed launch 44, quality transport 20 and build 1 (65 total). Whitespace passed.
These are local results; latest-head CI and merge remain pending. Additional
Windows/macOS equivalence remains waived, not passed.

## Fixed-revision dependency correction (2026-10-14)

PR review identified that dependency discovery still consulted live files before
validating the fixed binding. Both boundary validators now validate that binding
first and discover investigation/domain/design-system inputs from its Git tree.
Git reads exclude inherited GIT_* settings and replacement objects; read failures
reject admission. Legacy discovery and ledger/identity checks are retained.

The added regression tests fail on the prior HEAD (four failing assertions in
three tests) and pass after repair. Final fixed-launch suite: 47 passed;
conditional-input suite: 17 passed. The complete original-path boundary driver
completed with exit 0, including Bash/PowerShell cases, 32 source anchors, and
regular/hardlink/symlink investigation checks. Syntax and whitespace checks pass.

Fresh independent Codex diff review returned PASS with zero Critical/Major
findings; it independently ran the 47 fixed-launch tests, 32 anchors and initial
RCB001-010 Bash/PowerShell cases. This is the authorized independent review
exception, not a fabricated formal-ledger verdict or task Done transition.
Additional native Windows/macOS equivalence is NOT RUN under the user waiver.
Latest-head hosted CI and merge must still be verified separately.

## Hosted-CI compatibility repair (2026-10-14)

Run 38429776810 failed on macOS because Bash 3.2 with nounset rejects expansion
of an empty array. Dependency discovery now uses an always-nonempty argument
array, preserving the same arguments and validation. The original failure was
reproduced with Bash 3.2; the complete foundation suite passed after repair.

Python 3.9 also rejects slicing Path.parents directly. Both snapshot directory
collections now convert parents to a list before slicing; their scope and
permission handling are unchanged. The final Python 3.9 input suite passed all
33 tests. Fresh independent Codex review returned PASS with no Critical/Major
findings and independently passed 47 launch tests under Python 3.9 and 47 under
the default Python, plus directory-scope and whitespace checks. These focused
compatibility regressions do not claim full native OS equivalence. Updated-head
hosted CI, merge and post-merge verification remain pending.
