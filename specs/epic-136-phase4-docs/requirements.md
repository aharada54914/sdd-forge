# Requirements: epic-136-phase4-docs

Spec-Review-Status: Passed

Source issues: [#133](https://github.com/aharada54914/sdd-forge/issues/133) (`documentation`), [#134](https://github.com/aharada54914/sdd-forge/issues/134) (`documentation`, `security`). Both are Phase 4 items of epic #136.

## Overview

Two documentation obligations that the investigation showed are each **half-done**, in opposite ways.

**#133** is not the open question its title implies. The cross-model failure policy *is* written down and the runner scripts *do* implement it — for the failure modes anyone thought about. `cross-model-verification-policy.md:28-31` and `:202-210` state a fail-closed posture for a vendor CLI that is "absent or errors", and all four runner scripts exit 1 on a non-zero CLI exit (INV-001, INV-002, INV-003). What no document and no script addresses is a CLI that **neither succeeds nor exits**: there is no timeout anywhere — not in the four runners, not in the gate, not in the orchestrating skill (INV-001, INV-003, INV-004, INV-006). A hung panelist is therefore neither skip-and-pass nor block; the collection phase stalls indefinitely. That is precisely the "抜け道" (loophole) the issue worries about for `critical` verification, and it is the only part of #133 still open.

This is also an internal inconsistency, not a matter of taste: `performance-checklist.md` already requires that "External calls have timeouts and bounded retries (no unbounded fan-out)" (INV-007), and a panelist invocation is an external call.

**#134**'s title says "を作成" (create), which is stale — `docs/THREAT-MODEL.md` already exists at 164 lines and already satisfies the issue's first acceptance criterion, tabulating trust boundaries and their mitigations (INV-008). Two gaps remain: the checklist cross-reference the second criterion requires is entirely absent (INV-009), and five of the six runtime trust surfaces named in the issue's 2026-07-10 addendum are undocumented (INV-011 through INV-015); only `.codex/agents/*.toml` is covered (INV-010).

Consumer-visible consequence, stated plainly: after this feature, a hung panelist fails the gate instead of hanging it. That is a **behaviour change**, not only a documentation change, and it is the change the issue's own "スクリプトの挙動と一致させる(critical は fail-closed 推奨)" asks for.

## Requirements

### REQ-001 — the failure taxonomy is stated completely, not partially (#133)

`cross-model-verification-policy.md` must enumerate every way a panelist invocation can fail to yield a verdict, and state the disposition of each. Today it names two ("absent or errors") and is silent on the rest, which is why the timeout hole survived review.

The taxonomy must distinguish, by name: **CLI absent**, **CLI exits non-zero**, **CLI rate-limited**, **CLI hangs / exceeds the time bound**, and **CLI returns malformed output**. For each, the document must state the exit code, whether a verdict file is produced, and how the missing verdict propagates through the diversity requirement to the gate verdict.

**Malformed output is already implemented, and this specification originally got its exit code wrong.** Round 1 of spec review flagged that the taxonomy's "malformed output" row had no evidentiary basis in `investigation.md`, leaving it ambiguous whether the row documents existing behaviour or demands new validation code. Re-verified directly: `run-panelist-gpt.sh:241-297` runs a Python validation block that rejects output with no JSON object (`:252`), invalid JSON (`:259`), missing required fields (`:266`), the wrong schema (`:270`), or `blind` not true (`:274`) — each with **`sys.exit(1)`**, and all of it *before* the verdict file is written. `run-panelist-gemini.sh` carries the same block.

So this row documents behaviour that already exists, requires **no new code**, and its exit code is **1** — not the 2 an earlier draft of this specification asserted. That draft error is exactly the "spec premise false at implementation time" class this repository records as WFI-011, caught here at spec review rather than after implementation.

#### AC-001

`cross-model-verification-policy.md` contains a failure-taxonomy section naming all five failure modes above. For **each** mode the section states all three elements REQ-001 requires: its exit code, whether a verdict file is produced, and how it propagates to the gate verdict.

Verified by reading the file and asserting, per mode, that all three elements are present — not merely the mode name, and not merely the exit code. An earlier draft of this criterion verified only the exit code, which would have let five bare mode-name-plus-number lines pass while the propagation narrative REQ-001 actually demands was never written. That is the text-marker failure mode recorded as FP-02 in the `epic-136-phase3` retrospective, reproduced by a criterion whose own verification clause was narrower than its parent requirement.

#### AC-002

The taxonomy explicitly states that **rate-limiting is not separately handled**: it reaches the gate through whichever of the exit-non-zero or timeout paths the vendor CLI happens to take, because this repository neither controls nor pins vendor CLI behaviour (Open Question 1 of the investigation, resolved as a documented limitation rather than an invented guarantee). A specification that claimed a rate-limit-specific guarantee would be unverifiable.

### REQ-002 — the vendor CLI invocation is bounded (#133)

All four runner scripts — `run-panelist-gpt.{sh,ps1}`, `run-panelist-gemini.{sh,ps1}` — must bound the vendor CLI invocation with a wall-clock timeout. On expiry the child process must be terminated and the runner must exit non-zero.

The bound must be configurable through the environment, following the repository's existing convention (`install.sh:758` reads `SDD_INSTALL_LOCK_TIMEOUT` with an inline default). The variable is `SDD_PANELIST_TIMEOUT`, in whole seconds, defaulting to **600**.

#### AC-003

Each of the four runner scripts reads `SDD_PANELIST_TIMEOUT`, defaults to 600 when unset or empty, and rejects a non-numeric or non-positive value with exit 2 (tool error — a malformed invocation is the caller's bug, distinct from a vendor failure).

#### AC-004

With `SDD_PANELIST_TIMEOUT=1` and a stub CLI on `PATH` that sleeps well past the bound, **each of the four runners** — `run-panelist-{gpt,gemini}.{sh,ps1}` — terminates the stub and returns within a bounded margin of the deadline. Asserted by measuring elapsed wall-clock time against the bound, and by confirming the stub process is no longer alive afterwards — not by asserting the exit code alone, which a script could produce without ever killing the child.

**The pass bar is stated per runtime, because the mechanisms differ (round-2 remediation).** An earlier draft scoped this criterion to "each shell runner", which contradicted BL-004's parity mandate, AC-011's requirement that both suites gain cases, and REQ-002's requirement that all four scripts implement the bound — and left a task author free to satisfy the literal text with shell-only tests.

| Runtime | Bound mechanism | Escalation | Liveness assertion |
|---|---|---|---|
| POSIX shell | `date +%s` deadline polled with `kill -0` (no `timeout(1)` — Edge Case 1). The child is started in **its own process group** (`setsid`, or an equivalent), so the group id is known and signalable. | `SIGTERM` then `SIGKILL` after a grace period, sent to the **process group** (`kill -TERM -<pgid>`), not to the single PID | `kill -0 <pid>` fails after the runner returns, **and** no orphan of any child the stub spawned remains |
| PowerShell | `Start-Process -PassThru` plus a bounded `WaitForExit(<ms>)` — the existing `-Wait` has no timeout parameter (INV-003) | `Kill($true)`, a single unconditional tree-kill. **No soft-request step precedes it, and none is to be added.** | the process object reports exited, and no orphan of any child the stub spawned remains |

**Edge Case 7 has no PowerShell counterpart, and that is a finding rather than an omission (round-3 remediation).** An earlier draft claimed one — "a stub that does not exit on a close request" — while the same table said `Kill($true)` was "not a second mechanism". Those cannot both hold: describing a stub that *ignores* a request presupposes a request is sent, which is exactly the soft step the table denies. Reviewer A caught the contradiction and was right; `Process.Kill()` maps to `TerminateProcess`, which user-mode code cannot trap or refuse the way a POSIX process can trap `SIGTERM`.

So the escalation asymmetry is stated plainly instead of papered over:

- **POSIX** genuinely has two steps, and a CLI can survive the first. TEST-004(b) exists to prove the second step is reached.
- **PowerShell** has one step that cannot be survived. There is no stub behaviour that would make a (b) sub-case verify anything (a) does not already verify, so **the PowerShell suite carries no (b) sub-case** — writing one would be a test that cannot fail.

What replaces it, so the runtime is not simply less covered: the PowerShell (a) sub-case additionally asserts that a stub which spawns its own child leaves **no orphan** after the runner returns. That is the property `Kill($true)`'s `$true` argument buys and a plain `Kill()` would not, and it is the one PowerShell-specific escalation behaviour that *can* fail.

**The no-orphan assertion is required of both runtimes, not only PowerShell (attempt-2 remediation).** An earlier draft added it to the PowerShell row only, framed as compensation for losing sub-case (b). That was wrong in a way worth naming: it implied POSIX is structurally exempt, and POSIX is not. `kill -TERM <pid>` reaches one process; a grandchild the vendor CLI spawned survives it, which is precisely the orphan Edge Case 2 warns about, and it holds the API session just the same. Nothing in that draft required or tested descendant reachability on POSIX, so the runtime with the *weaker* guarantee was the one carrying no assertion.

Hence the POSIX row now commits to process-group semantics — start the child with `setsid`, signal `-<pgid>` — and carries the same no-orphan assertion. BL-004's outcome parity is what forces this: "no orphan holding the API session" is an outcome, and an outcome parity claim cannot hold if only one runtime is required to deliver it.

BL-004's parity requirement is satisfied at the level of **outcome** — bounded, terminated, no partial verdict, in both runtimes — not by mirroring a POSIX signal model onto a platform that has no equivalent.

**Scope note for TEST-004(c).** This criterion's "terminates the stub" clause describes the *timeout* path only. The polling-boundary-race sub-case asserts the opposite outcome — a child that finished inside the expiry interval must **not** be terminated, and must be reported by its own exit code. That sub-case is governed by Edge Case 6, not by this sentence.

### REQ-003 — a timeout is fail-closed by the *existing* mechanism, not a new one (#133)

A timed-out panelist must exit **1**, identically to a CLI that errors. It must not exit 2.

The reasoning is that exit 1 leaves the already-documented chain intact: no verdict file is written → `check-cross-model` sees a missing verdict → the diversity minimum is unmet → the gate fails and blocks auto-Done (`cross-model-verification-policy.md:28-31`, INV-005). Exit 2 means "tool error", which would misattribute a vendor non-response to a defect in this repository's own tooling, and travels a different path through the caller.

#### AC-005

A timed-out runner — **any of the four**, shell or PowerShell — exits 1 and writes **no** verdict JSON to the output directory. Asserted by both the exit code and the absence of the file, since a runner could exit 1 after having written a partial verdict, which would be worse than hanging.

Scoped to all four for the same reason as AC-004: an earlier draft said "shell runner", which left the no-partial-verdict guarantee unasserted for exactly the two scripts whose kill mechanism differs most from the one the criterion was written against.

#### AC-006

With a timed-out panelist as the only non-Anthropic vendor, `check-cross-model` fails and does not report consensus PASS. This is the acceptance criterion that actually closes the issue's stated concern about `critical` verification; AC-005 alone only proves the runner behaved.

### REQ-004 — the threat model records a checklist cross-reference (#134)

`docs/THREAT-MODEL.md` must carry an OWASP LLM Top 10 mapping and an MCP security cross-reference, satisfying the issue's second acceptance criterion (INV-009).

The mapping must be **honest about non-applicability**. Entries that this repository's surface genuinely does not touch must be recorded as N/A with a one-line reason, not padded with a plausible-sounding control. A mapping in which all ten entries are "addressed" would be evidence of padding, not of coverage.

#### AC-007

`docs/THREAT-MODEL.md` contains a table with one row per OWASP LLM Top 10 entry, each row carrying either a named control that already exists in this repository (with the `file:line` or control-name that implements it) or an explicit N/A with a reason. Verified by asserting all ten identifiers are present and that every row's disposition cell is non-empty.

#### AC-008

At least one row is N/A with a stated reason, and at least one row cites an existing control by name. This is a deliberate anti-padding assertion: it fails both a mapping that claims universal coverage and one that claims none.

#### AC-013 — the MCP half of REQ-004 is verified, not just the OWASP half

`docs/THREAT-MODEL.md` carries an MCP security cross-reference naming this repository's three MCP servers (`sdd-forge-mcp`, `local-env-mcp`, `ci-mcp`) and stating, for each, the trust posture that applies to it.

**Resolving investigation Open Question 2 for #134.** That question asked whether an authoritative MCP security checklist exists to cite, or whether the cross-reference must point at primary MCP documentation. Resolved as: **cite primary MCP documentation**. No authoritative third-party MCP security checklist is established by anything in this repository, and citing one this specification cannot name would be an unverifiable requirement.

Round 1 of spec review found that REQ-004's MCP clause had **no acceptance criterion and no test at all** — AC-007 and AC-008 cover only the OWASP table — so an implementer could have satisfied every stated criterion for REQ-004 while omitting the MCP cross-reference entirely. AC-013 closes that gap, and the resolution above closes the open question the gap was hiding behind.

### REQ-005 — the five absent runtime trust surfaces are documented (#134)

`docs/THREAT-MODEL.md` must cover the surfaces the #134 addendum names and the investigation found absent: Codex hook trust including first-run approval and the existence of `--dangerously-bypass-hook-trust` (INV-011); `~/.codex/config.toml` `hooks.state` (INV-012); the installer's MCP-registration marker block (INV-013); `plugins/sdd-quality-loop/hooks/claude-hooks.json` in its node exec form (INV-014); and the Claude Code settings/permissions model (INV-015).

`.codex/agents/*.toml` is already covered (INV-010) and must not be re-documented — a second, divergent description of the same control is the failure mode WFI-020 is about.

#### AC-009

Each of the five surfaces appears in `docs/THREAT-MODEL.md` with a stated trust assumption and at least one mitigation or an explicit residual-risk entry where no mitigation exists.

Verified per surface by **two** assertions, both required: (1) the surface's own identifier is present by literal string (e.g. `--dangerously-bypass-hook-trust`, `hooks.state`, `claude-hooks.json`), and (2) a trust-assumption statement and a mitigation-or-residual-risk statement accompany it in the same section.

An earlier draft verified only (1). That is the same defect as AC-001's: a document that name-drops `hooks.state` in an unrelated sentence would have passed while never carrying the substance REQ-005 demands. AC-010 on this same requirement already asserted an accompanying statement, which is what makes the omission in AC-009 an inconsistency rather than a considered choice.

#### AC-010

The document names `--dangerously-bypass-hook-trust` explicitly and states what an operator who uses it gives up. A threat model that describes hook trust without naming its documented bypass is not a threat model.

#### AC-014 — the hole this feature closes is recorded where the threat model can see it

`docs/THREAT-MODEL.md` gains a residual-risk entry for the unbounded external panelist, marked **closed by this feature** and naming `SDD_PANELIST_TIMEOUT`.

**Resolving investigation Open Question 3 for #134.** That question asked whether #133's hung-panelist finding should also land in #134's document. Resolved as **yes**. Round 2 of spec review found it was the one open question this specification left neither answered nor explicitly deferred, while closing every other one by name — so a task author scoping the THREAT-MODEL.md changes had no guidance on it.

The reasoning is that a threat model shipped in the same release as a denial-of-service fix, omitting the hole that fix closes, is stale on arrival. Recording it as *closed* rather than open also gives the next reader the `SDD_PANELIST_TIMEOUT` knob without having to find this specification.

### REQ-006 — documentation and behaviour are verified equal, not asserted equal (#133, #134)

The issue's second acceptance criterion is "スクリプト挙動と一致" — behaviour matches the document. That must be established by an executable check, because the whole reason this issue exists is that a prose claim and an implementation drifted apart unnoticed.

#### AC-011

`tests/cross-model.tests.{sh,ps1}` gain cases covering AC-003, AC-004, AC-005 and AC-006, and both suites pass. The tests must exercise the runners through a stub CLI on `PATH`, never by invoking a real vendor CLI — a test that needs network or vendor credentials is not a regression signal.

#### AC-012

The timeout default asserted by the tests is read from the same source the scripts read, so a future change to the default cannot leave the tests passing against a stale literal.

## Non-goals

- **Retries.** `performance-checklist.md` mentions "bounded retries" alongside timeouts, but adding retry logic changes cost and latency characteristics of a `critical` gate and is not required by either issue. Recorded as out of scope, not overlooked.
- **Rewriting the already-correct half of #133.** The absent/error path is documented and implemented correctly; this feature extends the taxonomy around it and must not restate or restructure it.
- **Adding or changing output validation.** The malformed-output path is already fully implemented at `run-panelist-gpt.sh:241-297` (and its `gemini` twin) and already exits 1 before writing a verdict. This feature *documents* it and writes no new validation code. Stated as a Non-goal because round 1 of spec review correctly found the boundary between "document existing behaviour" and "implement new behaviour" was drawn for the timeout and the absent/error path but left ambiguous for this row.
- **Re-documenting `.codex/agents/*.toml`** (INV-010).
- **Changing `check-cross-model`'s own logic.** The gate reads verdict files and is already correct (INV-004); the defect is upstream.
- **Pinning or vendoring the `codex` / `gemini` CLIs.** Their failure behaviour is outside this repository's control, which is exactly why AC-002 documents the limitation instead of asserting a guarantee.

## Edge Cases

1. **`timeout(1)` is unavailable.** Neither `timeout` nor `gtimeout` exists on the development host this feature was specified on — verified by `command -v`. The implementation must therefore not depend on GNU coreutils. `install.sh:758-781` already establishes the portable pattern this repository uses: a deadline computed from `date +%s`, polled with `kill -0`. A design that reaches for `timeout(1)` will work in CI and fail on a maintainer's machine.
2. **The child must actually die.** Terminating the runner without killing the vendor CLI leaves an orphan holding the API session. AC-004 asserts the child is gone, not merely that the parent returned.
3. **A partially written verdict.** If the CLI is killed mid-write, a truncated JSON must not be left where `check-cross-model` will read it — hence AC-005's absence assertion. The existing scripts write to a scratch path and move on success; the design must preserve that ordering.
4. **`SDD_PANELIST_TIMEOUT=0` or negative.** Rejected as a tool error (AC-003) rather than silently meaning "no bound", which would reintroduce the defect through configuration.
5. **A vendor CLI that rate-limits by sleeping rather than erroring.** Indistinguishable from a hang at the process boundary, and correctly handled as one — this is the substance of AC-002.
6. **The polling boundary race.** A polled deadline is not atomic with process completion: the CLI can exit successfully inside the very interval in which the poller is about to declare the deadline exceeded. The implementation must not report a timeout for a child that has already exited successfully — after the deadline fires, it must re-check whether the child completed before treating the expiry as authoritative. Raised by round 1 of spec review; the original edge-case list covered "killed mid-write" but not this, and every planned test used a 1-second bound against a 30-second stub, a margin so wide it could only ever exercise the unambiguously-hung case.
7. **A vendor CLI that ignores `SIGTERM`.** The Assumptions section anticipates this and requires escalation to `SIGKILL`, but a stub built from plain `sleep` dies on the first `SIGTERM` by default disposition, so it can never reach the escalation branch. A test suite built only from such a stub would pass against an implementation whose escalation is broken or absent. At least one sub-case must use a stub that installs a `SIGTERM` trap and keeps running.

## Assumptions

- The `codex` and `gemini` CLIs terminate on `SIGTERM`. If one ignores it, an escalation to `SIGKILL` is required; the design must state which signal it sends and whether it escalates. **This assumption is not merely deferred — Edge Case 7 requires a test whose stub ignores `SIGTERM`, so the escalation path is exercised rather than assumed.**
- `install.sh:758-781` is the repository's existing portable-deadline convention (`SDD_INSTALL_LOCK_TIMEOUT`, `date +%s` deadline, `kill -0` polling). Round 1 of spec review noted this citation carries no `INV-` number, unlike every other citation here, because it was verified by the orchestrator after `investigation.md` was written rather than by the investigator. Recorded so the provenance gap is visible; the requirement it supports — no dependency on `timeout(1)` — rests independently on the first-hand `command -v` result in Edge Case 1.
- Re-verify every `file:line` in this document at implementation start. Three of this repository's recorded defects (WFI-011, and the off-by-one citations corrected in `epic-136-phase4-mcp`) came from citations that were accurate when written and stale when used.

## Baseline Constraints

- **BL-001 — the absent/error path is behaviour-preserving.** A CLI that is absent or exits non-zero must behave exactly as it does today (exit 1, no verdict). The timeout is an additional bound, not a rewrite of the existing handler.
- **BL-002 — `check-cross-model` is unchanged.** No file under `plugins/sdd-quality-loop/scripts/check-cross-model.*` is edited by this feature.
- **BL-003 — the existing policy text is extended, not replaced.** `cross-model-verification-policy.md:28-31` and `:202-210` keep their current meaning; the taxonomy is added around them.
- **BL-004 — dual-runtime parity.** Whatever the shell runners do, the PowerShell runners must do. This repository enforces parity between the two runtimes and a one-sided fix would fail that.
- **BL-005 — no file in `PROTECTED_GATE_SUFFIXES` is written.** Confirmed for every target of this feature by direct read of `guard-invariants.generated.js:5` (INV-017), so no `human-copy` staging round applies.
