# PR #400 design reconciliation — 2026-09-08

Status: IN PROGRESS; not an implementation or review PASS.

## Current remote observation

Remote head: `8fa3eb8561d6f59b692ec574900f87e181145928`.
`gh pr checks 400 --required` returned exit 0: required-checks and the
macOS, Ubuntu and Windows test jobs passed. These results do not cover the
uncommitted design/specification changes. Six PRs remain open:
#245, #371, #381, #390, #394, #400. No merge or issue closure performed.

## Authorized design amendment performed

- Preserve actual failing command status in the shell call-site sketch by
  capturing `$?` in `else`, not after logical negation.
- Add the post-deadline process-state re-check to the PowerShell sketch;
  complete output before success-path validation.
- Expand the coverage table to c1/c2 and state the three-way comparison of
  the independently required default, source default and observed runtime.

`git diff --check`: exit 0.
Shell conditional micro-checks for status 1 and 124: two passed, exit 0.
These micro-checks are not the runner regression suite and do not prove
PowerShell or descendant-cleanup behavior.

## Remaining work before independent design review

The shell sketch still contains an impermissible bare-PID fallback and
leader-only escalation observation. Reconcile it against the current runner
and the mandatory descendant-cleanup acceptance conditions; do not weaken
those conditions. The PowerShell sketch still needs the complete bounded
cleanup/error-handling and large-timeout behavior, not merely its re-check.
Finish the full sibling identifier sweep, including stale task-stage claims.
Retain historical review evidence. Use a fresh formal review attempt only
after the amended input set is complete; the existing Passed lifecycle field
does not prove the amended design passed. Reconcile/re-review task-stage
artifacts before implementation. Protected runner changes require exact
reviewed human application, not bypass.

## Subsequent reconciliation in the same dated work session

The old shell sketch described above has now been replaced by a supervisor
contract grounded in the existing shared helper. Both shell runners already
use that helper, so adding duplicate runner-local supervision would be the
wrong change surface. The component/data/distribution lists now include
`lib/panelist-common.sh`; human evidence's protected suffix list includes it.
Group-wide escalation is retained, and a bare-PID fallback is forbidden.
Security baseline prose is explicitly historical; the two gate outcomes are
restated consistently. Source line citations were checked with numbered
output. `git diff --check` passed after the shell design replacement.

Still pending: the concrete child-state synchronization mechanism, complete
PowerShell wait/cleanup design, full identifier sweep, source-hash-bound target
refresh at review consumption, independent reviews and all implementation
verification. No product-source change or new CI result is claimed here.

## Formal design review attempt 4, round 1 launched

The preceding pending-mechanism note is superseded by the current design:
POSIX uses the existing embedded Python supervisor as the sole child-state
and monotonic-deadline owner; PowerShell specifies finite waits, bounded
cleanup, Windows native redirection and Unix owned asynchronous stream copies.
ADR `docs/adr/0033-panelist-supervisor-process-ownership.md` is a proposed
decision, not an approved implementation. The formal review must judge these
choices and their cross-layer consistency; no acceptance condition is waived.

The persisted attempt-4/round-1 precheck exists. An invocation that supplied
both modes was rejected as a replay: the script consumes a single mode.
No evidence was replaced. The correct read-only `--verify-inputs` invocation
then passed. Reviewer A's isolated Astra context is
`/root/pr400_impl_a4r1_a`, encoded as `root:pr400_impl_a4r1_a` in its canonical
identity fields. Reservation succeeded:

```
REVIEW_CONTEXT_OK 28cfc704ff0b4e1618fc5908639088284d1367c7919773efed8b3c4120ec838c sequence=968 previous_record_sha256=d4214274343b8b338cb771ffb6aa0e3d3da95960a65fdf066192bfea643d9e5c pre_append_tip_sequence=967 identity_unique=yes
```

The reviewer has been sent the persisted one-role manifest and reservation
evidence, with no design-author history or prior raw reviews. Reviewer B must
receive only the deterministic A check-ID/count summary, in another fresh
context. Keep all bound inputs unchanged during the round.

Remote refresh still shows six open PRs and 26 open issues. PR #400's four
required checks still pass at `8fa3eb8561d6f59b692ec574900f87e181145928`;
this remains old-head evidence, not validation of the amended design or code.
No merge, issue closure, implementation PASS or whole-workflow PASS is claimed.

Reviewer A has now completed. Its raw JSON is persisted in the round directory:
8 PASS, 2 FAIL (both Major), 1 SKIP; verdict NEEDS_WORK. The two findings are
PowerShell descendant ownership after root exit, and the missing authorized
ADR-existence verification path (not a claim that the ADR file is absent).
The deterministic integrated summary contains only IDs and counts.

Reviewer B is launched in fresh isolated Astra context
`/root/pr400_impl_a4r1_b` with canonical identity `root:pr400_impl_a4r1_b`.
Input re-verification passed before reservation:

```
REVIEW_CONTEXT_OK 925b1984f21d1960620f4208599be39d41f125443c6453a3b25e8924deab05a7 sequence=969 previous_record_sha256=28cfc704ff0b4e1618fc5908639088284d1367c7919773efed8b3c4120ec838c pre_append_tip_sequence=968 identity_unique=yes
```

B received no A narrative or raw result. Await B, persist its exact output,
then produce the merged contract/verdict and proposed changes under the skill;
do not revise bound inputs before the round has concluded. No finding is waived.

## Reconciled completion observation (2026-09-08)

The preceding wait instruction is historical. Both reviewer agent handles are
now terminal, and round-1/reviewer-b.json and integrated-verdict.json are
persisted. The integrated verdict is NEEDS_WORK, Critical 0 / Major 4 / Minor 0.
See that round's design-round-1-proposed-changes.md for the governing findings;
no reviewer remains running and no PASS is inferred from CI. A fresh GitHub
observation still shows PR400 at 8fa3eb8561d6f59b692ec574900f87e181145928 with
25 successful Actions checks plus CodeRabbit, Draft and REVIEW_REQUIRED.
All seven open PRs have terminal checks; this is not an active CI wait.
