# Issue #423: applied owner-worktree regression

Date: 2026-10-01
Base commit: 06bc32cc26f2d67adb02e827610b5230e1658f72
Result: focused regressions passed; formal quality verification and delivery pending.

This addendum supersedes the owner-application-pending statements in the
dated migration handoff. It does not change historical verdicts or task status.
The human applied six Registry/Resolver targets. Readback matched:

| Targets | SHA-256 |
| --- | --- |
| Canonical and vendored capability Registry | 42b884b2b58d2b370b03b64b115d0f20b7a049e60b5e715e673fe12c022564c1 |
| Resolver and A5 human-copy Resolver | ae27deb32d5af3d31dcbfd505812fd737603a9d682476451a855d48fb36ed511 |
| Generated gate capabilities | e9db61b7a9eeb28c1c50668e017fd8d570e490684daf68bc5d98f5348b0a31e1 |
| A5 human-copy manifest | cde02121eed5f7d0e9726c77b223bc72ff5e462cbd139bfcdcda45f09178ec5d |

## Regression repairs

Three test drivers retained assumptions about the illustrative capability
being present in production. Provider-neutrality cases now use the existing,
schema-validated example fixture; the actual Registry still has its own
provider-neutrality assertion. Missing-implementation and legacy-obligation
baselines use the retained pre-migration Registry. New assertions require the
applied canonical Registry to validate and match the approved candidate.
No rejection assertion, iteration count, or validator check was removed.

Observed RED before these repairs: contract boundaries had 19 IndexErrors
across 28 methods; registration had one failure; migration had three failures.
These were stale test assumptions after the approved application, not proof
that production should again contain the nonexistent migration checker.

## Executed in the owner checkout

All commands below used `rtk proxy` and returned exit 0.

| Command | Result |
| --- | --- |
| `python3 specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py -v` | 28 passed |
| `python3 specs/sdd-domain-multitarget/verification/T-002/registry-registration.tests.py -v` | 3 passed, 2 pre-application candidate-only cases skipped |
| `python3 specs/sdd-domain-multitarget/verification/T-002/registry-migration-20261001/registry-migration.tests.py -v` | 11 passed |
| `bash tests/resolve-project-context-cli.tests.sh` | 13 passed, 0 failed |
| `bash tests/resolve-project-context-lite.tests.sh` | 18 passed, 0 failed |
| `git diff --check` | No whitespace errors |

The separate paired-regression report records the earlier, larger regression
run against the same six applied hashes. Those checks are not rerun or added
to the owner-run counts here. macOS PowerShell is not native Windows evidence.

## Committed-source migration regression

The migration CLI driver now defaults to the actual Resolver and canonical
Registry, not untracked candidate copies. It reuses the existing CLI test
helpers and committed example Registry. Running
`python3 specs/sdd-domain-multitarget/verification/T-002/registry-migration-20261001/registry-migration-cli.tests.py`
returned exit 0: six test methods passed (8.357 seconds). These exercise
legacy full/Lite rejection before publication, retained custom-Registry
obligations, unaffected components, malformed input, and Lite output shape.
This is local CLI evidence, not native Windows, formal review, or CI evidence.

The same command also passed all six methods in a fresh local clone of
commit `a5e46b70` (8.407 seconds), with no untracked candidate files copied
from the owner checkout. The clone remained clean after execution.

## Formal-review blocker and resume point

The quality-gate launch contract requires the canonical identity ledger to
already contain the invoking implementation identity
(`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:184`). Neither the
owner ledger nor the root checkout ledger contains the recorded T-001/T-002
implementation IDs (`sdd423-t001-20260928-737dfb49` and
`sdd423-t002-20260928-b2e4033f`). No retrospective reservation was fabricated.
The original implementation reports also cannot be rewritten to claim later
repair bytes: new evaluator inputs need a valid post-fix artifact declaration
under the same skill's lines 161–176.

Next: recover a legitimate implementation-identity chain and declare current
post-fix hashes, then reserve a fresh isolated evaluator and run the formal
gate. Keep RT-20260930-001 open until that gate is complete. T-003 must not
start by assuming T-002 is Done. Current-head CI, native Windows checks,
merge, and post-merge confirmation remain unperformed for this checkpoint.

## Follow-up audit: CI coverage boundary

At head `fc36148a1f60bbcfe9cd0c2499851c3d969e2c27`, GitHub Actions run
`36874536793` remained in progress with 29 successful jobs and seven unfinished
jobs. No completed job had failed at observation time; this is not a final CI
result.

The six-method migration CLI driver above has no execution reference in
`.github/workflows/test.yml` or `tests/` (checked with
`rg -n 'registry-migration|registry-registration' .github/workflows/test.yml tests`).
The POSIX fallback runner consumes `tests/suite-inventory.posix`, not arbitrary
drivers under `specs/`. Therefore this CI run must not be cited as execution of
the new migration cases. Register the regression through an existing test
entrypoint before treating future CI as protection for this repair.

The identity audit also found that implementation instructions create run and
session identities without registering them, while the quality gate requires
prior registration. A fresh implementation-identity registration/recovery
contract is needed; reconstructing a historical reservation is not evidence.
No ledger or historical verdict was changed by this audit.

The existing fallback runner executes only the shell suites enumerated in
`tests/suite-inventory.posix` (`tests/run-ci-unwired.sh:48-52,142-147`).
The bounded registration repair is a thin shell entrypoint for the committed
Python migration driver plus its inventory entry; changing workflow jobs or
duplicating the full Resolver suite is unnecessary. This would add POSIX CI
coverage only, not native Windows evidence. At that audit point, the entrypoint
had not yet been applied.

## Terminal CI observation — 2026-10-01

Run `36874536793` for exact head
`fc36148a1f60bbcfe9cd0c2499851c3d969e2c27` completed as `cancelled` at
14:51:24 UTC. The Ubuntu job stopped while the Bash cross-model gate step
was unfinished. GitHub's check annotation explicitly states:
`The job has exceeded the maximum execution time of 30m0s`.
The same step took approximately 116 seconds in four recent successful runs,
but remained unfinished for over 24 minutes in this run. Its individual log
was unavailable and the run had no uploaded artifacts. The timeout is proven;
the underlying stall is not yet diagnosed. No retry, cancellation request, or
merge was performed here.

## Bounded timeout diagnosis

At the same head, one local execution of `bash tests/cross-model.tests.sh`
completed in 118.3 seconds with `76 passed, 0 failed` (exit 0). The suite's
test doubles were used; this was not a live Gemini or Codex panelist run.
The owner checkout's tracked and untracked status was unchanged by the test.
This narrows the problem to the CI execution or environment, but does not
establish the root cause of the timed-out job.

The GitHub job-log endpoint returned `BlobNotFound` (HTTP 404), so the
unfinished step's output could not be inspected. To obtain one fresh CI
observation without changing the head, tests, or 30-minute job limit, the
owner requested a single diagnostic rerun of only the timed-out job with
`gh run rerun 36874536793 --job 110410939301 --debug`. GitHub accepted the
request as attempt 2. Its new Ubuntu job is `110431934739`; its final result
was not available at this report update. No further retry is authorized by
this observation. A passing rerun would not supply the missing formal quality
gate, run registration, or native Windows evidence.

## Migration CLI regression CI wiring (local, not in attempt 2)

The approved T-002 boundary regression now has a thin POSIX entrypoint at
`tests/registry-migration-cli.tests.sh` and one canonical inventory entry in
`tests/suite-inventory.posix`. The existing `tests/run-ci-unwired.sh` fallback
selects it without a workflow or runner change. Locally, the entrypoint
passed all six Python test methods (8.488 seconds),
`tests/ci-suite-wiring.tests.sh` passed its wiring and 21 behavioral controls,
and `tests/run-ci-unwired.sh --list` included the new entrypoint. The scoped
`git diff --check` found no whitespace errors.

The newly reachable branch is the POSIX fallback shard's execution of this
entrypoint on a future CI run. That first real CI execution remains pending;
run `36874536793` attempt 2 uses the earlier committed head and cannot prove
this uncommitted wiring. This does not add native Windows evidence, change a
formal quality-gate verdict, or satisfy the missing identity registration.

## Current-head CI verification — 2026-10-02

PR #535 head `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9` has 37
completed successful check runs, including `required-checks`. Run
`36882890633` executed `tests/registry-migration-cli.tests.sh` in POSIX
unwired shard (2); its log records six tests in 7.157 seconds. This replaces
the earlier pending-first-CI statement for that POSIX entrypoint only.

The PR remains draft and formal quality verification remains blocked on the
implementation-identity registration contract. These CI results do not prove
native Windows execution of the new migration driver or repair historical
identity evidence. No merge or quality-gate verdict was changed.

## Registration-path diagnosis — 2026-10-02

The missing identities cannot be repaired by invoking the existing reservation
command with an implementation role: its admission list accepts only spec,
implementation-policy, task, quality and domain reviewer roles
(`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:415`).
This is distinct from the ledger record schema, whose stage/role fields accept
identifier strings (lines 477–478). A syntactically valid hand-added record
would therefore not establish an authentic prior reservation and was not added.

The smallest legitimate repair needs a prospective implementation-registration
path and an explicit historical-recovery contract; it must not reuse a reviewer
role to impersonate an implementer, backdate registration, or remove identity
separation. This diagnosis does not approve or implement that contract change.
Post-fix artifact declarations must also use a new gate report rather than
rewriting the frozen implementation report (quality-gate SKILL.md:161–176).

The GitHub API reconfirmed run `36882890633` completed successfully for exact
head `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`. This does not resolve the
registration boundary or complete T-003 through T-006.
