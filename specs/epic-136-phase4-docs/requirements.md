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

With a timed-out panelist as the only non-Anthropic vendor, `check-cross-model` fails and does not report consensus PASS. Assert both resulting input sets: a valid remaining Anthropic verdict with insufficient diversity produces exit 1 and an aggregate FAIL; no verdict files at all produces exit 2 and no aggregate. The runner's timeout exit remains 1 in both cases. This is the acceptance criterion that actually closes the issue's stated concern about `critical` verification; AC-005 alone only proves the runner behaved. The empty-set distinction preserves the existing gate behavior (`check-cross-model.sh:89-97`; `check-cross-model.ps1:89-94`; INV-004), rather than equating a runner exit with a gate exit.

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

The timeout default asserted by the tests is read from the same source the scripts read, so a future change to the default cannot leave the tests passing against a stale literal. For each runner, both unset and empty configuration must be observed using that effective bound, not merely accepted. The current product requirement remains 600 seconds (AC-003); changing it requires a specification change, not automatic acceptance of any value extracted from source. A missing or disabled deadline must fail the tests even when the CLI was invoked.

## Non-goals

- **Retries.** `performance-checklist.md` mentions "bounded retries" alongside timeouts, but adding retry logic changes cost and latency characteristics of a `critical` gate and is not required by either issue. Recorded as out of scope, not overlooked.
- **Rewriting the absent/error handler.** Its runner behavior is preserved. Policy wording may receive only the explicit empty-verdict exit-code correction in BL-003 in addition to the taxonomy; this does not authorize changes to the gate or its fail-closed disposition.
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
6. **The polling boundary race.** A polled deadline is not atomic with process completion. After a deadline indication, the runner must re-check actual child completion before committing to timeout. If the child is already exited at that re-check, use its exit status and validate its complete output normally; a successful child with valid output succeeds. If the child is still running at that re-check, timeout is authoritative: terminate its tree/group, exit 1, and publish no verdict. Finishing output or a planned sleep before a deadline is not evidence of process exit. TEST-004(c) must establish and assert both orderings using observable process state; approximate wall-clock timing alone cannot select the expected outcome. The configured bound, no-orphan guarantee, and timeout fail-closed behavior remain unchanged.
7. **A vendor CLI that ignores `SIGTERM`.** The Assumptions section anticipates this and requires escalation to `SIGKILL`, but a stub built from plain `sleep` dies on the first `SIGTERM` by default disposition, so it can never reach the escalation branch. A test suite built only from such a stub would pass against an implementation whose escalation is broken or absent. At least one sub-case must use a stub that installs a `SIGTERM` trap and keeps running.

## Assumptions

- The `codex` and `gemini` CLIs terminate on `SIGTERM`. If one ignores it, an escalation to `SIGKILL` is required; the design must state which signal it sends and whether it escalates. **This assumption is not merely deferred — Edge Case 7 requires a test whose stub ignores `SIGTERM`, so the escalation path is exercised rather than assumed.**
- `install.sh:758-781` is the repository's existing portable-deadline convention (`SDD_INSTALL_LOCK_TIMEOUT`, `date +%s` deadline, `kill -0` polling). Round 1 of spec review noted this citation carries no `INV-` number, unlike every other citation here, because it was verified by the orchestrator after `investigation.md` was written rather than by the investigator. Recorded so the provenance gap is visible; the requirement it supports — no dependency on `timeout(1)` — rests independently on the first-hand `command -v` result in Edge Case 1.
- Re-verify every `file:line` in this document at implementation start. Three of this repository's recorded defects (WFI-011, and the off-by-one citations corrected in `epic-136-phase4-mcp`) came from citations that were accurate when written and stale when used.

## Baseline Constraints

- **BL-001 — the absent/error path is behaviour-preserving.** A CLI that is absent or exits non-zero must behave exactly as it does today (exit 1, no verdict). The timeout is an additional bound, not a rewrite of the existing handler.
- **BL-002 — `check-cross-model` is unchanged.** No file under `plugins/sdd-quality-loop/scripts/check-cross-model.*` is edited by this feature.
- **BL-003 — preserve the fail-closed policy, correct the empty-set exit code.** Preserve the absent/error posture and extend the taxonomy. The historical empty-verdict policy quoted in INV-005 incorrectly said exit 1, whereas INV-004 records exit 2. Explicitly permit that one numeric correction to exit 2, with no aggregate and no consensus PASS, matching the unchanged gate. This supersedes any instruction to preserve the historical empty-set number; it does not permit softening failure, skipping diversity, or changing gate code. The corrected policy is currently at `cross-model-verification-policy.md:230-240`; re-verify these citations at review and implementation time.
- **BL-004 — dual-runtime parity.** Whatever the shell runners do, the PowerShell runners must do. This repository enforces parity between the two runtimes and a one-sided fix would fail that.
- **BL-005 — no agent writes a protected file.** Re-check each proposed target by suffix against the current `PROTECTED_GATE_SUFFIXES` at specification review, design review, task drafting, and immediately before implementation. Record the source hash and matching targets at each consumption point; never inherit an exemption from INV-017. On 2026-09-08, direct inspection of `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js:5` and `guard_invariants.py:4` found both shell `run-panelist-*` scripts protected, superseding INV-017's historical no-match conclusion. A matching target requires the approved human-application workflow; an unavailable or denied application blocks that target, not permission to bypass enforcement. A no-human-copy conclusion is valid only for the exact re-verified nonmatching targets. BL-002 still forbids changes to `check-cross-model.*` regardless of who applies them.

## Review correction precedence — 2026-09-08

The current BL-003, BL-005, AC-006, AC-012 and Edge Case 6 are normative for this amendment. INV-005's quoted exit 1 and INV-017's protected-list snapshot are retained as historical investigation evidence, not current behavioral or authorization requirements. Any sibling restatement of the old empty-set number, unconditional no-staging exemption, approximate-time success rule, or invoke-only default check must be reconciled under its own review gate before it can authorize implementation; a previously recorded PASS does not establish conformance to these amended requirements.

### BL-005 review-input procedure and human source evidence

For a review whose allowed inputs exclude guard sources, the orchestrator must
obtain current source observations before launching the review, using human
collection if the protection hook denies the agent's probe. Bind the observation
time, source hashes, relevant source excerpts and target classification into this
canonical requirements input. The independent reviewer checks that evidence and
its limitations within the hashed input; it must not read an unlisted guard file.
This assigns collection and review to their respective roles rather than waiving
BL-005's re-verification. A changed source, new target, missing observation or
incomplete classification requires refreshed evidence before consumption. Every
later design, task and implementation boundary still requires its own refresh.
No source observation authorizes an otherwise denied operation.

Human collection received for this specification review at
2026-09-07T23:05:35.797Z–2026-09-07T23:05:35.801Z reported four source records
and `errors=0`. Original transcript SHA-256:
`df555c9a145143546718a48329a8612c456d45686b2de7ac265a8b8bf6e58dc7`.
The transcript is retained in the user attachment
`/Users/jrmag/.codex/attachments/eaff7de8-878b-481d-acc7-8ce29f82be39/pasted-text.txt`;
reviewers do not need or receive access to that external path. These are
human-reported source hashes, not an independently executed protection verdict.

| Observed source | SHA-256 |
|---|---|
| Repository `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` | `0202c8f32f8810d77ba438a965f6b57213fb907f1a3c724f318cda9fd7b19d90` |
| Installed `sdd-quality-loop/1.17.0/scripts/sdd-hook-guard.py` | `da37e08d7341f58ee61bbd0aa146486be21a069b4435ccd449114eaf72363889` |
| Repository `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` | `777a8a0f880f52a066b111daf6f8e204381f6a3604c77a70a3dce0070b0b9197` |
| Installed `sdd-quality-loop/1.17.0/scripts/generated/guard_invariants.py` | `777a8a0f880f52a066b111daf6f8e204381f6a3604c77a70a3dce0070b0b9197` |

The installed root is
`/Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-quality-loop/1.17.0`.
Both main-source excerpts show the adjacent generated-module path at line 955,
assignment from `PROTECTED_GATE_SUFFIXES` at line 1008, and normalized suffix
matching at line 1077. Both complete generated inventory lines (line 4) include
`plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh` and
`plugins/sdd-quality-loop/scripts/run-panelist-gemini.sh`. Accordingly both shell
runner targets require human application. The `.ps1` twins, the policy document
and `docs/THREAT-MODEL.md` have no matching entry in these observed suffix lists;
this bounded inventory observation is not a blanket exemption from other guards.
`plugins/sdd-quality-loop/scripts/check-cross-model.sh` is also listed, but
BL-002 prohibits editing either gate implementation regardless of membership.
Any additional implementation target must be classified before use.

The differing main-source hashes must not be described as identical installations.
The matching generated hashes and cited loading/matching spans support this
specific source-membership finding only. They do not prove runtime hook activation,
end-to-end write rejection or permission to bypass a refusal. INV-017's historical
no-staging conclusion remains superseded; prior review failures remain unchanged.
