# Design: epic-136-phase4-docs

Impl-Review-Status: Passed

## Authorized amendment — 2026-09-08

This is the human-authorized PR #400 specification amendment, not an assertion
that provenance re-binding alone permits frozen-content edits. Prior review
attempts remain unchanged. The retained status is a lifecycle field; it does
not authorize implementation until the amended design and layer inputs pass
a fresh review attempt. Changed content receives substantive review, without
the unchanged-content TYPE-H convergence allowance.

The governing requirements/acceptance revision passed specification review at
`reports/spec-review/epic-136-phase4-docs/attempt-3/round-3/`. Its BL-003,
BL-005 and TEST-003/004/006/012 supersede inconsistent historical claims in
investigation INV-005/017 and in the unreconciled task-stage artifacts. Tasks
and traceability must be reconciled and re-reviewed before further implementation.
The dated source evidence in requirements' BL-005 is source observation only,
not a runtime protection verdict or write authorization. Refresh evidence at
the consuming review/implementation boundary; a denied source probe requires
human evidence, never another route around the denial.

## Architecture Overview

Two independent streams sharing one release. They touch disjoint files and can land in either order.

**Stream A (#133)** adds a wall-clock bound to the panelist invocation and completes the failure taxonomy in the policy document. The bound goes in the four runner scripts — the only place that owns the child process. It deliberately does **not** go in `check-cross-model` (BL-002): that gate reads verdict files off disk and never invokes a panelist (INV-004), so a timeout there would be a bound on the wrong thing.

The design's central choice is that a timeout must be **indistinguishable downstream from a CLI error**: runner exit 1 with no verdict. The gate's own result depends on its remaining input set: one otherwise-valid Anthropic verdict with insufficient diversity produces exit 1 and aggregate FAIL; an empty set produces exit 2 and no aggregate (requirements BL-003; TEST-006). Neither permits consensus PASS. The historical INV-005 exit-1 quotation does not override this distinction. No gate or aggregate schema changes are in scope.

**Stream B (#134)** appends two sections to `docs/THREAT-MODEL.md`: an OWASP LLM Top 10 / MCP cross-reference table, and coverage of the five runtime trust surfaces the addendum names. It edits no code.

## Components

| Component | Status | Change |
|---|---|---|
| `plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh` | Existing (extended) | wrap the `codex` invocation (`:216-220`) in the bounded-wait helper; read `SDD_PANELIST_TIMEOUT`; extend the header comment block (`:13-15`) with the timeout case |
| `plugins/sdd-quality-loop/scripts/run-panelist-gemini.sh` | Existing (extended) | same, around `:137-142` |
| `plugins/sdd-quality-loop/scripts/lib/panelist-common.sh` | Existing (extended, protected) | shared shell process-group supervisor; preserve explicit stdin forwarding and group-wide cleanup; reconcile actual child-state re-check with Edge Case 6 |
| `plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1` | Existing (extended) | replace `-Wait` with a bounded `WaitForExit` (`:184-195`) |
| `plugins/sdd-quality-loop/scripts/run-panelist-gemini.ps1` | Existing (extended) | same |
| `plugins/sdd-quality-loop/references/cross-model-verification-policy.md` | Existing (extended) | new "Panelist Failure Taxonomy" section; `:28-31` unchanged; the `:202-210` block (now `:203-211`) carries only the human-ratified exit-code correction (BL-003 posture preserved; tasks.md ruling 2026-08-07) |
| `docs/THREAT-MODEL.md` | Existing (extended) | two new sections; `:39-41` and `:56` unchanged (REQ-005 forbids re-documenting `.codex/agents/*.toml`) |
| `tests/cross-model.tests.sh` | Existing (extended) | AC-003/004/005/006 cases via a stub CLI |
| `tests/cross-model.tests.ps1` | Existing (extended) | parity cases (BL-004) |
| `plugins/sdd-quality-loop/scripts/check-cross-model.sh` | **Untouched** | BL-002 |

## API & Contract Plan

### The bounded-wait pattern (shell)

GNU `timeout` is not a dependency (requirements Edge Case 1). The 2026-09-08
source observation supersedes the old inline-shell sketch: the runner sources
`lib/panelist-common.sh`, whose `_sdd_run_bounded` starts a Python supervisor
with `os.setsid()`, forwards stdin explicitly with `<&0`, waits for the vendor
through `subprocess.call`, and publishes a completion status. See
`plugins/sdd-quality-loop/scripts/lib/panelist-common.sh:45-83` and
`run-panelist-gpt.sh:205-207`. This is existing implementation, not proof that
the amended boundary tests pass.

The amended supervisor contract is:

1. Retain the dedicated session/process group on every POSIX host, including
   macOS through Python's `os.setsid()`. Never fall back to a bare vendor PID.
   If group setup fails, do not launch the vendor outside supervision.
2. Preserve the existing explicit stdin forwarding, scratch-file ownership,
   CLI arguments and output-validation path. The shared helper, not duplicated
   inline runner implementations, owns the shell deadline and cleanup.
3. At deadline indication, re-check the actual vendor child's exit state.
   A supervisor/output marker is evidence only if it follows an observed vendor
   exit; marker absence alone cannot prove that the vendor remains alive.
   Capture the real child status and complete output before the success path.
   Do not add a sleep to turn an already-established c2 timeout into c1 success.
4. Once the child is observed alive at that re-check, commit to timeout. Send
   TERM to the known process group, allow the existing two-second cleanup
   grace, then test the **group**, not only the supervisor PID, for survivors
   and send KILL to the group. Reap the direct child/supervisor. Leader exit
   must not skip escalation while a descendant remains.
5. Exercise both vendor exit/re-check orderings and descendant cleanup through
   TEST-004. Treat cleanup failure as failure with no verdict, never success;
   a return code alone does not prove that descendants were terminated.

The current group-wide escalation is grounded in
`lib/panelist-common.sh:103-115`; preserve that safety property. The existing
post-deadline sleep/marker logic (`:87-101`) is a remediation target, not the
normative definition of Edge Case 6.

**Selected shell mechanism (proposed for fresh review).** Keep Python embedded
in the existing helper, but make it the single owner of the vendor's `Popen`
object and monotonic deadline. Start the vendor with `start_new_session=True`,
leaving the supervisor outside the vendor group so group KILL does not kill
the process responsible for reaping and reporting. Preserve inherited file
descriptors and explicit stdin forwarding. Start the deadline before launch;
pass only its remaining duration to `Popen.wait(timeout=...)`. On
`TimeoutExpired`, call the same object's `poll()` immediately: a return code
is the observed child exit, whereas `None` commits to timeout. Do not inspect
a status marker or add a settling sleep at this branch.

After committing to timeout, retain the original group identity and signal
that group with TERM, then KILL after the existing two-second grace if the
group survives. Poll/reap the direct child during cleanup; its exit does not
cancel the group check. Bound the final reap/cleanup observation to two more
seconds rather than performing an unbounded final wait. A remaining process,
permission error or other cleanup failure returns failure with no verdict and
an accurate diagnostic; it cannot claim successful termination. Preserve the
runner's internal-124-to-exit-1 mapping. The shell caller waits for this
supervisor instead of running a second, marker-based deadline algorithm.

This selects process ownership, not a passed implementation. See proposed
ADR `docs/adr/0033-panelist-supervisor-process-ownership.md`; TEST-004 still
must establish both actual boundary orderings against the resulting runner.

`SIGTERM` first, then `SIGKILL` after a 2-second grace — resolving the requirements' Assumption about signal handling explicitly rather than assuming the vendor CLI is well-behaved. Return code 124 is `timeout(1)`'s conventional timeout code, used here only as an internal marker; the caller maps it to the runner's exit 1.

Call-site shape at `run-panelist-gpt.sh:216-220`, preserving the existing redirections and the scratch-file ordering that Edge Case 3 depends on:

```sh
if _sdd_run_bounded "$_panelist_timeout" \
        "$_codex_cmd" --model "$model" --effort "$effort" --no-project-doc \
        < "$_combined" > "$_raw_output" 2>&1; then
    : # continue to the existing validation and verdict-write path
else
    _rc=$?
    if [ "$_rc" -eq 124 ]; then
        printf 'run-panelist-gpt: codex CLI exceeded SDD_PANELIST_TIMEOUT=%ss; terminated\n' \
            "$_panelist_timeout" >&2
    else
        printf 'run-panelist-gpt: codex CLI exited %d\n' "$_rc" >&2
    fi
    cat "$_raw_output" >&2
    exit 1
fi
```

Both failure branches exit 1 and neither reaches the verdict-write step, which is what AC-005 asserts. Capture the command's status immediately in `else`: using `if ! ...` would instead capture the negated status 0 and lose the timeout/non-zero distinction. This is a design sketch, not a replacement CLI argument list; retain the actual runner's arguments and verify BL-001 with the unchanged regression cases.

### The bounded-wait pattern (PowerShell)

The original INV-003 unbounded baseline is historical. The current GPT runner
already starts an absolute deadline before `Start-Process -PassThru`, restores
the caller's deadline environment value, and clamps the remaining wait to
Int32 milliseconds (`run-panelist-gpt.ps1:242-260`). Preserve launch time inside
the budget and preserve that environment restoration.

The amended wait contract is:

1. Compute remaining time from the same deadline on every wait. Use a bounded
   Int32 wait chunk; expiration of a clamped chunk before the actual deadline
   is not a timeout. Recompute and continue, without restarting the budget.
2. At actual deadline indication, refresh and read the real process exit state.
   An already-exited child follows c1 only with exit 0 and complete valid
   output. A still-live child commits to c2; later exit cannot undo timeout.
3. Request tree termination on c2 and retain exit 1/no verdict on every cleanup
   error. Do not call the parameterless `WaitForExit()` on a possibly-live
   process: that overload waits indefinitely. Cleanup waiting must itself be
   bounded within TEST-004(a)'s total elapsed limit.
4. Do not infer descendant termination from the root's `HasExited` or
   `WaitForExit` result. TEST-004 must independently observe the fixture's
   child and descendant identities through termination, including a root that
   exits first. Unobserved or surviving descendants cannot pass acceptance.
5. Complete output collection before validation on the success path; observing
   the root exit alone is not an output-completion assertion. The concrete
   output-drain and descendant-cleanup mechanism remains a design-review
   prerequisite, not a claim that the current implementation satisfies it.

These constraints replace the earlier unsafe sketch, not the acceptance
criteria. Microsoft's [WaitForExit documentation](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.waitforexit?view=net-9.0)
distinguishes bounded waits from indefinite waiting and output completion.
Its [Kill documentation](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.kill?view=net-9.0)
states that termination is asynchronous, root exit does not establish descendant
exit, and descendants whose details cannot be inspected can be skipped.
Therefore `Kill($true)` alone is not proof of the no-orphan requirement.

**Selected I/O ownership (proposed for fresh review).** Preserve the Windows
native `Start-Process` launch/redirection path, including its existing command
resolution. On Unix, replace that cmdlet's redirected launch with an explicitly
owned `System.Diagnostics.Process` using `UseShellExecute=false`. Preserve
the resolved executable, effective argument string, working directory and
environment; do not add a shell interpreter or change CLI argument semantics.
Open the existing scratch output/error files and start concurrent
`BaseStream.CopyToAsync` transfers from both redirected output streams. Start
the input-file-to-stdin copy concurrently, closing stdin when it finishes.
The runner owns all three transfer tasks and streams; it must not synchronously
write the bundle before starting the bounded process wait.

This OS distinction is grounded in PowerShell 7.6.2's
[Start-Process source](https://github.com/PowerShell/PowerShell/blob/v7.6.2/src/Microsoft.PowerShell.Commands.Management/commands/management/Process.cs#L1937-L1955):
Unix uses managed redirection and calls `WriteToStandardInput` before returning;
that method writes synchronously (lines 2169-2178). Windows uses the native
creation path with inherited file handles (lines 2181-2186). Thus replacing
only the later wait does not bound a Unix CLI that refuses to read stdin.

Observe process completion and all three transfer results separately. After
child exit, allow at most two seconds for owned I/O tasks to settle and flush
the output files before validation. A fault or incomplete transfer yields
exit 1/no verdict, not a truncated success. On timeout, retain the committed
timeout classification, request tree termination, and allow at most four
seconds total for cleanup and transfer cancellation/disposal; never wait
indefinitely on a task after cancellation. Do not label cancellation itself
as proof that the process or descendants exited. On Windows, file-handle
redirection needs no managed drain task; the child/descendant liveness tests
still apply. Tests must also exercise a Unix stub that never reads stdin
with an input larger than the pipe buffer, and concurrent large stdout/stderr,
so neither input backpressure nor a full output pipe bypasses the deadline.

This design narrows the necessary launch rewrite to the platform with the
observed synchronous-input hazard. Replacing both platforms with a new native
launcher is rejected here because it would unnecessarily change Windows CLI
resolution. The normal/nonzero/absent-CLI regressions remain unchanged.

### Configuration contract

| Aspect | Value |
|---|---|
| Variable | `SDD_PANELIST_TIMEOUT` |
| Unit | whole seconds |
| Default | `600` |
| Unset / empty | default applies |
| Non-numeric, `0`, negative | **exit 2** (tool error), before the CLI is invoked |

Naming and default-inline shape follow `install.sh:758` (`SDD_INSTALL_LOCK_TIMEOUT:-120`). 600 is chosen against the neighbouring `SDD_INSTALL_LOCK_STALE:-600` rather than invented: a panelist review is a long LLM call, and a bound tighter than the repository's existing longest-wait constant would false-trip.

### Policy document: the new taxonomy section

Appended to `cross-model-verification-policy.md`, leaving `:28-31` intact and the `:202-210` block (now `:203-211`) with only the human-ratified exit-code correction (BL-003 posture preserved; tasks.md ruling 2026-08-07):

| Failure mode | Runner exit | Verdict file | Reaches the gate as |
|---|---|---|---|
| CLI absent | 1 | none | missing verdict → diversity unmet → gate fails |
| CLI exits non-zero | 1 | none | same |
| CLI exceeds `SDD_PANELIST_TIMEOUT` | 1 | none | same |
| CLI rate-limited | 1, **via** one of the two rows above | none | same |
| CLI returns malformed output | **1** | none | missing verdict → diversity unmet → gate fails |
| Runner misconfigured (bad `SDD_PANELIST_TIMEOUT`) | 2 | none | tool error |

**Correction after spec-review round 1.** An earlier draft of this table gave malformed output exit **2** and called it a tool error. That was wrong, and no artifact supported it. The behaviour already exists and was re-read directly: `run-panelist-gpt.sh:241-297` validates the CLI's output and exits **1** on no-JSON (`:252`), invalid JSON (`:259`), missing required fields (`:266`), wrong schema (`:270`) and `blind` not true (`:274`) — every one of them before the verdict file is written. `run-panelist-gemini.sh` carries the same block. So this row documents existing behaviour, needs no new code (now an explicit Non-goal), and belongs with the other exit-1 rows.

Only the misconfiguration row is genuinely exit 2, and that is correct: a bad `SDD_PANELIST_TIMEOUT` is the caller's bug, not a vendor failure.

The rate-limit row is deliberately not a separate mechanism (AC-002): whether a rate-limited vendor CLI errors or stalls is the vendor's choice, and this repository pins neither CLI. Claiming a rate-limit-specific guarantee would be unverifiable, so the document states the limitation instead.

### `docs/THREAT-MODEL.md`: two appended sections

Section 1 has **two independently verified deliverables**, not one. REQ-004 names both OWASP and MCP, and they are checked separately — AC-007/AC-008/TEST-007 cover the OWASP half, AC-013/TEST-013 cover the MCP half. An earlier draft of this plan described only the OWASP mapping, which would have let an implementer satisfy every criterion it stated while omitting the MCP deliverable entirely. That is the same gap spec review round 1 found one layer up (`requirements.md:115`), reappearing here; impl review round 2 found it at this layer, and this text closes it.

1. **OWASP LLM Top 10 cross-reference (AC-007, AC-008 → TEST-007)** — one row per LLM01…LLM10, each row carrying either a named existing control or an explicit N/A with a reason. The mapping is written by reading the existing Controls Table (`:48-65`) and Threats & Mitigations (`:69-109`) and asking which OWASP entry each already answers — not by inventing controls to fill rows.

1a. **MCP server cross-reference (AC-013 → TEST-013)** — a distinct deliverable in the same section, naming all three of this repository's MCP servers — `sdd-forge-mcp`, `local-env-mcp`, `ci-mcp` — with a stated trust posture for each. TEST-013 asserts each of the three literal server names is present, so a row that gestures at "the MCP servers" collectively does not satisfy it. Trust posture is written from what each server can actually do (`local-env-mcp` has no execution capability; `ci-mcp` and `sdd-forge-mcp` are repository-local), and per AC-013 the posture cites primary MCP documentation rather than asserting a security property of the protocol from memory.

2. **Runtime trust surfaces (REQ-005, AC-009, AC-010, AC-014 → TEST-009, TEST-010, TEST-014)** — the five absent surfaces (INV-011…INV-015), each with a trust assumption and either a mitigation or an explicit residual-risk entry. This section also carries the **AC-014 / TEST-014** residual-risk entry for the unbounded external panelist, marked *closed by this feature* and naming `SDD_PANELIST_TIMEOUT` — a threat model that omits a hole the same release closed would be stale on arrival. The vendor agent role definition files are referenced by pointer to their existing rows, never restated. Note that INV-013's *installer MCP-registration marker block* is a configuration-file surface and is **not** a substitute for deliverable 1a: 1a documents what the three servers are trusted to do, 2 documents that the installer writes a registration block. Both are required.

## Data Plan

**No data changes.** This feature introduces no database, no persisted schema, and no new document format. The complete set of artifacts it writes or edits is the Components table above: four runner scripts, their existing shared shell helper, two Markdown documents, and two test suites.

Two existing on-disk artifacts are read or written by code this feature touches, and neither changes shape:

| Artifact | Shape | Change |
|---|---|---|
| Panelist verdict file (`cross-model-verdict/v1`) | Existing JSON schema, written by the runner on success | **Unchanged.** On the timeout path the runner exits before the write, so no verdict file — not a partial one — is produced (AC-005). The schema itself is not touched. |
| `SDD_PANELIST_TIMEOUT` | Process environment variable, whole seconds, default 600 | **New**, but environment configuration rather than stored data. Contract in the Configuration table above. |

No migration, no backfill, and no retention change follows from this, which is why `infra-spec.md`'s Rollback section can state that a revert is complete and carries no migration.

## Security Boundaries

The authoritative treatment is `security-spec.md`, which is a normative layer of this specification rather than background reading. This section states the boundaries design decisions had to respect; it does not restate the threat analysis.

| Boundary | Trust posture | What the design commits to |
|---|---|---|
| **B1 — vendor CLI process** | Untrusted for availability. The CLI is neither shipped, pinned, nor vendored by this repository, so its liveness cannot be assumed. | The bounded-wait helper. This is the whole point of the feature: a boundary that could previously block forever now has a bound. |
| **B2 — cross-model consensus signal** | Integrity-critical. A verification gate that silently degrades is worse than one that fails. | Fail-closed on timeout: exit 1, no verdict file, diversity unmet, gate fails (AC-006). No skip-and-pass path is introduced. |
| **B3 — threat-model control inventory** | Documentation of record. | The five runtime trust surfaces are added with their real posture, including residual risks that are *not* closed, rather than an inventory that reads as complete. |
| **B4 — hook-trust surface** | Operator-controlled bypass. | Named explicitly in the threat model together with what an operator who uses it forfeits (AC-010). The design adds no new bypass and removes none. |

Authorization and data classification:

- **Protected targets require human application.** BL-005's dated evidence identifies both shell panelist runners as protected. Before review/implementation, obtain current source-hash-bound target evidence as BL-005 prescribes; if the necessary inspection is denied, request human evidence. Human-applied changes must be exact reviewed bytes, with before/after hashes and retained backup. Missing application or verification blocks implementation; broad approval never disables the hook. `check-cross-model.*` remains untouched (BL-002). INV-017 is historical, not a current exemption.
- **No `SDD_SUDO` interaction.** This feature neither reads, creates, nor requires it.
- **No secret is read, written, or transported.** `SDD_PANELIST_TIMEOUT` is a non-secret integer. Vendor credentials remain entirely inside the vendor CLI's own configuration and are never handled here — including on the kill path, where the design terminates a process and never inspects its environment.

## Design Decisions (Resolving Open Questions)

- **OQ-1 (rate-limit behaviour): documented as unknowable from this repository.** Neither vendor CLI is pinned or vendored, so their rate-limit behaviour cannot be asserted. Resolved by AC-002 as a stated limitation. Inventing a guarantee here would produce a spec claim no test could hold.
- **OQ-2 (bound value and scope): per-panelist, 600s, env-configurable.** Per-panelist rather than per-collection-phase because the runner is the only component that owns a child process; a collection-phase bound would require the orchestrating skill to become a process supervisor, which is a much larger change than either issue asks for.
- **OQ-3 (exit code on timeout): exit 1.** The load-bearing decision. Exit 1 reuses the entire existing fail-closed chain unchanged; exit 2 would mean "tool error", misattributing a vendor non-response to this repository's tooling and forcing changes in the gate and the caller. See REQ-003.
- **OQ-4 (test coverage): yes, in `tests/cross-model.tests.{sh,ps1}`**, through a stub CLI on `PATH`. A test that calls a real vendor needs credentials and a network and is not a regression signal (AC-011).
- **#134 OQ-3 (does the hang land in the threat model too): yes.** The unbounded-panelist finding is added to `docs/THREAT-MODEL.md`'s Residual Risks as *closed by this feature*, with a pointer to `SDD_PANELIST_TIMEOUT`. A threat model that omits a hole the same release closed would be stale on arrival.

## Test Strategy

### Coverage table — every AC, every TEST

Impl review attempt 1 found the same defect twice: a design plan that read well against the `REQ-*` headings while silently omitting an `AC-*` that spec review had added later specifically to close a gap. Round 2 caught AC-013; round 3 caught AC-012 and escalated the attempt to BLOCKED. Patching one row at a time would leave the class open, so the plan is stated as an exhaustive table instead. A mechanical cross-check of the current text found AC-001, AC-012 and AC-014 unnamed and ten of fourteen `TEST-*` IDs unmentioned — all now listed here. **If an AC has no row, the plan is incomplete; that is the check.**

Requirement-to-criterion roll-up, so no `REQ-*` is reachable only through prose: **REQ-001** → AC-001, AC-002; **REQ-002** → AC-003, AC-004; **REQ-003** → AC-005, AC-006; **REQ-004** → AC-007, AC-008, AC-013; **REQ-005** → AC-009, AC-010, AC-014; **REQ-006** → AC-011, AC-012.

| AC | TEST | Delivered by | Note |
|---|---|---|---|
| AC-001 | TEST-001 | Policy taxonomy section (`## API & Contract Plan`, taxonomy table) | all five failure-mode names, each with exit code, verdict-file state and propagation |
| AC-002 | TEST-002 | Same section, rate-limit row | states rate-limiting is not separately handled; deliberately a stated limitation, not a guarantee |
| AC-003 | TEST-003 | Item 1 below | 7 sub-cases; invalid values exit 2 **before** the CLI is invoked |
| AC-004 | TEST-004 | Item 2 below | sub-cases (a)/(b)/(c1)/(c2); wall-clock bound, SIGKILL escalation, both proven boundary orderings |
| AC-005 | TEST-005 | Item 3 below | exit 1 **and** no verdict JSON |
| AC-006 | TEST-006 | Item 4 below | composed with `check-cross-model`; the test that closes the issue's stated concern |
| AC-007 | TEST-007 | Stream B deliverable 1 | ten OWASP identifiers, every disposition cell non-empty |
| AC-008 | TEST-008 | Stream B deliverable 1 | ≥1 N/A row with a reason **and** ≥1 row citing an existing control — the anti-padding assertion |
| AC-009 | TEST-009 | Stream B deliverable 2 | five surface identifiers by literal string |
| AC-010 | TEST-010 | Stream B deliverable 2 | `--dangerously-bypass-hook-trust` named, with what it forfeits |
| AC-011 | TEST-011 | Item 5 below | both suites pass, pre-existing cases unmodified |
| AC-012 | TEST-012 | Item 7 below | independently required 600 seconds agrees with source default and observed unset/empty runtime deadlines |
| AC-013 | TEST-013 | Stream B deliverable 1a | all three MCP server names with a trust posture each |
| AC-014 | TEST-014 | Stream B deliverable 2 | residual-risk entry for the unbounded panelist, marked closed, naming `SDD_PANELIST_TIMEOUT` |

1. **AC-003 — configuration parsing.** Seven sub-cases per runner: unset, empty, `600`, `1`, `0`, `-5`, `abc`.
   - **First four** (unset, empty, `600`, `1`): the runner proceeds to invoke the CLI. `1` is a valid bound. For unset and empty separately, observe the actual timeout duration used by each runner and exercise expiry, exit 1, no verdict and process/descendant cleanup. The observation must equal the source-derived default and satisfy the independently required 600 seconds. Source inspection or CLI invocation alone cannot satisfy TEST-003/012. A controllable clock/wait fixture may accelerate elapsed time but must execute the runner's real deadline decision, not inject a success/timeout result.
   - **Last three** (`0`, `-5`, `abc`): exit 2 **before** the CLI is invoked, asserted by a stub that records whether it was called at all.

   Stated as four-plus-three rather than three-plus-three because an earlier draft of this line wrote "first three / last three" against a seven-item list, leaving `1` unclassified — contradicting both item 2 below and the Configuration contract table above, which classify `1` as valid. Spec review caught that arithmetic at the requirements layer (`acceptance-tests.md:43`, both round-2 reviewers independently), but this document kept the stale phrasing; both impl reviewers then caught it here, independently, at attempt 2 round 1.
2. **AC-004 — the bound actually bounds.** Four sub-cases, including both boundary orderings required by the amended specification:
   - **(a)** `SDD_PANELIST_TIMEOUT=1` plus a stub that sleeps 30s. Assert elapsed wall-clock ≤ 10s and that the stub's PID is gone afterwards. The liveness assertion distinguishes a real kill from a parent that merely returned.
   - **(b)** the same, but the stub installs `trap '' TERM`. Only the `SIGKILL` escalation can end it, so this is the sub-case that proves the escalation branch exists. A plain `sleep` stub dies on the first `SIGTERM` and can never reach it — which meant the original single case would have passed against a broken or absent escalation.
   - **(c1)/(c2)** Keep `SDD_PANELIST_TIMEOUT=2`. For each of the four runners, establish each ordering at least five times: (c1) deadline indicated, then actual child exit 0 and complete valid output before the post-deadline re-check; (c2) deadline indicated while the child is still alive at the re-check. Record deadline, output completion, actual process completion/state, re-check and runner result. c1 requires exit 0, intact verdict and no timeout; c2 requires exit 1, no verdict and no surviving child/descendant. Synchronization may hold the observation boundary but cannot replace the decision or extend the production bound. Approximate timing, an output marker alone, missing ordering evidence, discarded failures, favorable-sample retries or increased timeout cannot pass. An unestablished ordering is a failing/incomplete test.
3. **AC-005 — no partial verdict.** After a timeout, assert exit 1 **and** that the output directory contains no verdict JSON for that task.
4. **AC-006 — the gate actually fails.** Compose 2 and 3 with each gate implementation and both remaining input sets: one otherwise-valid Anthropic verdict gives exit 1 and aggregate FAIL; empty input gives exit 2 and no aggregate. Assert no consensus PASS in both, with the runner itself exiting 1 and publishing no verdict. Match policy propagation to these outcomes without editing either gate (BL-002/003).
5. **BL-001 — behaviour preservation.** The existing absent-CLI and non-zero-exit cases must pass **unmodified**. If an existing case needs editing to accommodate the timeout, that is evidence BL-001 was broken.
6. **BL-004 — parity, with one deliberate exception.** Every case above exists in both `tests/cross-model.tests.sh` and `.ps1`, **except AC-004 sub-case (b)**, which the PowerShell suite carries **none of, deliberately**. PowerShell's termination step cannot be survived — `Process.Kill` maps to `TerminateProcess`, which is untrappable — so no stub behaviour would let a (b) sub-case verify anything (a) does not already verify; writing one would be a test that cannot fail. BL-004 is therefore satisfied at the level of **outcome** (both runtimes must end the child and leave no orphan), not by mirroring a POSIX signal model onto a platform with no equivalent. This carve-out is stated in `requirements.md:67,75` and tabulated in `acceptance-tests.md:64-68`; spec review round 3 blocked an earlier draft that got this wrong, so it is restated here rather than left to inference.
7. **AC-012 — source, product requirement and runtime agree.** Derive each source default, independently check it against AC-003's 600-second requirement, then compare it to the effective deadline for each unset/empty run in item 1. Exercise real expiry and cleanup. A wrong or missing fallback must fail even when CLI invocation succeeds and source text still declares the correct value. Source changes cannot redefine acceptance; explicit-value tests cannot replace either fallback test.
8. **Stream B** is verified by literal-string assertions per REQ-004/REQ-005 — ten OWASP identifiers (TEST-007), **the three MCP server names `sdd-forge-mcp`, `local-env-mcp` and `ci-mcp` (TEST-013)**, five surface identifiers (TEST-009), and `--dangerously-bypass-hook-trust` by name (AC-010, TEST-010). Deliberately literal: a heading-level check would pass against an empty section, which is the text-marker failure mode recorded as FP-02 in the `epic-136-phase3` retrospective. TEST-013 is listed separately from TEST-007 on purpose — they verify the two halves of REQ-004, and collapsing them is exactly how the MCP deliverable went missing from this plan in the first place.

## Deployment & CI Plan

No new CI step. The existing `test` job runs `tests/run-all.sh`, which already registers `cross-model.tests.sh`. No `dist/` bundle is involved — these are shell/PowerShell/Markdown files, so ADR-0003 does not apply and there is no rebuild obligation.

Stack for the verification contract is `shell` (shell, PowerShell and Markdown only), which makes `lint`/`typecheck`/`build` waivable with a reason per `risk-gate-matrix.md`'s Stack descriptor table.

## Global Constraints

- BL-005's current-evidence and human-application boundary applies to every target. Both shell runners are protected in the dated human evidence embedded in requirements. No absence from that observation grants a general exemption. Recheck at the next consumption boundary, preserve exact reviewed hashes, and stop the affected operation if the hook denies it. INV-017's no-protection conclusion is superseded.
- `check-cross-model.*` is not edited (BL-002).
- Shell and PowerShell runners change together in the same commit (BL-004).
- No version literal outside `scripts/bump-version.sh` changes.

## Risks

- **A 600s default that is too tight for a slow vendor** would convert a working panel into a failing gate — a false fail-closed. Mitigated by the env override and by choosing the value against the repository's existing longest-wait constant rather than a guess. Recorded rather than dismissed: if a real panel trips this, the fix is the override, not removing the bound.
- **`sleep 1` polling adds up to one second of latency** to every panelist call. Negligible against a multi-minute LLM review, and the alternative (`wait -n`, or SIGCHLD traps) is less portable across the `sh` implementations this repository targets.
- **The 2-second SIGTERM grace is a guess.** It is stated explicitly in the design so a reviewer can challenge it, rather than buried in the implementation.
- **Stream B's OWASP mapping is a judgement call.** AC-008's anti-padding assertion is the guard against the most likely failure — a table where every row claims coverage. It cannot guarantee the judgements are *right*, only that they are not uniformly self-congratulatory; the impl-review gate is where the substance gets challenged.
