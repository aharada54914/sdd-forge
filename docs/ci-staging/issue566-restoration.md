# Issue 566: isolated CI restoration candidate

## Bounded scope extension: Issue 563 (2026-10-15)

Before editing: parent owns `issue559-bounded-audit/sdd-forge`, branch
`codex/issue559-completion-diagnostics`, clean HEAD
`0b3ced25968af92eb9cc3719e377215ca4aeec7a`. The user's existing repair and
merge authority also covers the known receipt-suite registration gap in #563.
This supersedes only the earlier two-step scope; historical results remain.
Risk remains high (required CI wiring). No product validator, approval,
ledger, frozen evidence, skip policy or required-job identity is changed.

Reach: register the existing Bash receipt wrapper in `suite-inventory.posix`,
the PowerShell wrapper in `run-all.ps1`, and standalone blocking PowerShell
steps in the existing non-Windows test and Windows-heavy jobs. The POSIX
inventory already feeds required Ubuntu shards. Standalone steps preserve
the wrapper's nonzero exit instead of masking it behind a later command.
Evidence field: each suite registration; counterpart: existing wrapper and
required lane; mismatch test: missing-registration assertion before editing
(exit 1, RED), followed by inventory/wiring checks and both native wrappers.
Independent diff review, final-head CI, postmerge and real weekly recovery
remain required; no previous failure is relabeled.

## Authorized application (2026-10-15)

Parent owner now applies the independently reviewed two-step candidate under
the user's existing repair/CI/merge authority. HEAD and dirty state are unchanged
from the candidate except these three untracked preparation files. The workflow
hash was rechecked before application. This high-risk CI repair retains all
required jobs, approvals, audit completion semantics and historical evidence.
Validation fields are the two suite registrations and required-job dependencies;
their mismatch tests are the structural RED and fourteen negative mutations.
The fresh-context Codex independent-review exception applies; no product review
verdict or task status is synthesized. Exact-head CI, postmerge CI and an actual
weekly run must still succeed before claiming recovery.

Application completed on 2026-10-15: the live workflow now contains exactly
the two proposed steps. The structural check and all fourteen negative controls
passed against that file; `git diff --check` passed. Earlier no-application
statements below describe candidate preparation, not the current state.
The preparation patch is retained in commit `f56cac0a`, not duplicated in the
final tree: its context-only blank lines triggered the whitespace checker.
The final workflow diff and structural regression are the maintained artifacts.

## Pre-edit scope (2026-10-14)

- Owner: `weekly_recovery_oct14`; checkout `issue559-bounded-audit/sdd-forge`;
  branch `codex/issue559-completion-diagnostics`; HEAD
  `d1707010873e9c10d0ce40a61de0e2ebd889e5d7`; initially clean. Its tree is
  identical to current main `d5766615bbdf6b5ec9e24269eb46eb770358840b`.
- Authority: parent authorized an isolated two-suite restoration proposal and
  regression preparation only. No live workflow edits, commit, push, dispatch,
  issue closure, installed-baseline changes, or frozen evidence changes.
- Risk: protected CI execution surface. This candidate restores previously
  registered checks; it does not change weekly completion semantics, PR guards,
  authorization, required-check identities, or skipped-check policy.
- Candidate target: `.github/workflows/test.yml`, current SHA-256
  `e0864920644e270f6f4aa2c41f4c9430a22d416ac1cbee524c683e358903d955`.
  Re-check the target hash and current lane structure before any authorized apply.
- Validation: apply only in a disposable directory; YAML structural assertions
  and independently mutated negative fixtures; real existing PowerShell suites
  on this macOS host; unchanged live-target hash. Windows/Ubuntu execution and
  exact-head CI remain pending approved application.

## Observed cause and bounded proposal

- Real audit run `38575173364` at main `d5766615` failed only because its
  completion record said `partial`. Its identity/HEAD and all five required
  check fields passed the new validator diagnostics. Claude succeeded with
  zero permission denials. This is not an identity or permission failure.
- Issue #566 reports a protected CI repair, so `partial` is consistent with
  `.github/self-improvement-prompt.md:40` and `:82`. Do not convert it to success.
- `git show 80694f62 -- .github/workflows/test.yml` confirms deletion of the
  two PowerShell registrations. Current `test.yml` has neither invocation;
  `tests/run-all.ps1:28` and `:118` still register the suites locally.
- Restore `installer-idempotency.tests.ps1` to `installers`, running once on
  Windows (`core` lane), macOS and Ubuntu (`all` lane), avoiding four identical
  Windows runs. Restore `boundary-reference-authorization-parity.tests.ps1`
  to its original `loops-routing` job (Windows and Ubuntu). Both existing jobs
  are already required by `required-checks` (`test.yml:1455`).
- No PowerShell fallback inventory or general CI redesign is proposed. Issue
  #563's task-prior-pass-receipt registration and historical BOM observations
  remain separate. Fixing #566 cannot guarantee the next audit finds no other
  protected candidate and therefore cannot by itself prove weekly recovery.

## Validation results

- RED: `ruby docs/ci-staging/issue566-restoration.tests.rb .github/workflows/test.yml`
  exited 1 and identified both missing direct suite invocations.
- `git apply --check docs/ci-staging/issue566-restoration.patch`: PASS (no live
  application). The same patch hunks were applied only to a temporary copy.
- GREEN: the isolated candidate passed the structural validator, exact parsed
  delta check (only two added steps), and 14 independent negative controls:
  removal, disabled step, wrong shell, nonblocking step, disabled job, missing
  required dependency, and duplicate invocation for each suite.
- `ruby -c docs/ci-staging/issue566-restoration.tests.rb`: syntax OK. YAML parsing
  passed as part of the validator. The live workflow SHA-256 remains the exact
  pre-edit value above; no production file was modified.
- Existing suite executions on macOS: boundary parity 19 passed / 0 failed;
  installer idempotency all seven scenarios passed (real local pwsh execution,
  with the suite's temporary installer fixtures and stub CLIs).
- The candidate validator is a local review aid, not wired into production CI.
  It is not an ongoing registration guard. A general PowerShell inventory or
  durable registration-guard expansion is outside this two-step proposal.
- Newly reachable after apply: installer idempotency on Windows core, macOS all,
  Ubuntu all; boundary parity on Windows/Ubuntu loops-routing. Native Windows
  and Ubuntu execution is **pending first real execution at CI time**. Require
  current-head CI and independent review before merge; no SKIP counts as PASS.
- Unperformed: production apply, formal acceptance, commit/push/PR, exact-head
  CI, weekly rerun, and unattended scheduled execution. #559/#563/#566 stay open.

## Independent candidate review (2026-10-15)

- Separate read-only reviewer `weekly_completion_diagnosis` found no blocking
  defect in the two added steps, their lane selection, or required dependencies.
  It independently observed current RED, isolated GREEN, 14 negative controls,
  Ruby syntax success, and boundary parity 19 passed / 0 failed. This is a
  candidate diff review, not formal acceptance or exact-head CI evidence.
- The existing installer suite (`tests/installer-idempotency.tests.ps1:467`)
  can SKIP case 6 on POSIX when a chmod-000 file remains readable, yet exit 0.
  Check the actual case-6 `ok` output in matching CI; a green job alone does
  not prove that branch executed. The independent reviewer did not rerun the
  installer suite because its fixtures perform Git writes outside that review's
  read-only scope. The earlier implementation-run result remains separate.
- Run `38575173364` remains failed at `Validate audit completion` on
  `d5766615bbdf6b5ec9e24269eb46eb770358840b`; finalization was skipped.
  No unchanged rerun was requested and no recovery or issue closure is claimed.

## Applied registration repair and independent verification (2026-10-15)

The #563 extension above adds the existing receipt suite to the POSIX inventory,
PowerShell full runner, and blocking PowerShell CI steps on all three operating
systems. No suite assertions, authorization rules, or required dependencies were
removed. Before application, the registration check failed; afterwards the
receipt suites passed nine checks each in Bash and PowerShell.

Fresh-context read-only reviewer `weekly_wiring_final_review` inspected the final
four-file extension at `0b3ced25968af92eb9cc3719e377215ca4aeec7a` plus its working
diff and found no blocking findings. It independently ran receipt checks (9+9),
CI wiring controls (21), restoration negative controls (14), boundary parity
(19), required-check controls (5), and whitespace validation successfully.
The review confirms the four blocking workflow registrations and unchanged
required-job failure propagation. This is independent diff verification, not
a fabricated product quality-gate verdict.

Native Windows/Ubuntu execution, exact-head CI, merge, post-merge CI, and a fresh
weekly audit remain pending. Installer case 6 must be inspected separately for
an actual execution versus its existing privilege-dependent SKIP.
