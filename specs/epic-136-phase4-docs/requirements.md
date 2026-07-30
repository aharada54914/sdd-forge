# Requirements: epic-136-phase4-docs

Spec-Review-Status: Pending

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

#### AC-001

`cross-model-verification-policy.md` contains a failure-taxonomy section naming all five failure modes above, each with its exit code and its propagation to the gate verdict. Verified by reading the file and asserting each of the five mode names is present with a stated exit code — not by asserting the section merely exists.

#### AC-002

The taxonomy explicitly states that **rate-limiting is not separately handled**: it reaches the gate through whichever of the exit-non-zero or timeout paths the vendor CLI happens to take, because this repository neither controls nor pins vendor CLI behaviour (Open Question 1 of the investigation, resolved as a documented limitation rather than an invented guarantee). A specification that claimed a rate-limit-specific guarantee would be unverifiable.

### REQ-002 — the vendor CLI invocation is bounded (#133)

All four runner scripts — `run-panelist-gpt.{sh,ps1}`, `run-panelist-gemini.{sh,ps1}` — must bound the vendor CLI invocation with a wall-clock timeout. On expiry the child process must be terminated and the runner must exit non-zero.

The bound must be configurable through the environment, following the repository's existing convention (`install.sh:758` reads `SDD_INSTALL_LOCK_TIMEOUT` with an inline default). The variable is `SDD_PANELIST_TIMEOUT`, in whole seconds, defaulting to **600**.

#### AC-003

Each of the four runner scripts reads `SDD_PANELIST_TIMEOUT`, defaults to 600 when unset or empty, and rejects a non-numeric or non-positive value with exit 2 (tool error — a malformed invocation is the caller's bug, distinct from a vendor failure).

#### AC-004

With `SDD_PANELIST_TIMEOUT=1` and a stub CLI on `PATH` that sleeps well past the bound, each shell runner terminates the stub and returns within a bounded margin of the deadline. Asserted by measuring elapsed wall-clock time against the bound, and by confirming the stub process is no longer alive afterwards — not by asserting the exit code alone, which a script could produce without ever killing the child.

### REQ-003 — a timeout is fail-closed by the *existing* mechanism, not a new one (#133)

A timed-out panelist must exit **1**, identically to a CLI that errors. It must not exit 2.

The reasoning is that exit 1 leaves the already-documented chain intact: no verdict file is written → `check-cross-model` sees a missing verdict → the diversity minimum is unmet → the gate fails and blocks auto-Done (`cross-model-verification-policy.md:28-31`, INV-005). Exit 2 means "tool error", which would misattribute a vendor non-response to a defect in this repository's own tooling, and travels a different path through the caller.

#### AC-005

A timed-out shell runner exits 1 and writes **no** verdict JSON to the output directory. Asserted by both the exit code and the absence of the file, since a runner could exit 1 after having written a partial verdict, which would be worse than hanging.

#### AC-006

With a timed-out panelist as the only non-Anthropic vendor, `check-cross-model` fails and does not report consensus PASS. This is the acceptance criterion that actually closes the issue's stated concern about `critical` verification; AC-005 alone only proves the runner behaved.

### REQ-004 — the threat model records a checklist cross-reference (#134)

`docs/THREAT-MODEL.md` must carry an OWASP LLM Top 10 mapping and an MCP security cross-reference, satisfying the issue's second acceptance criterion (INV-009).

The mapping must be **honest about non-applicability**. Entries that this repository's surface genuinely does not touch must be recorded as N/A with a one-line reason, not padded with a plausible-sounding control. A mapping in which all ten entries are "addressed" would be evidence of padding, not of coverage.

#### AC-007

`docs/THREAT-MODEL.md` contains a table with one row per OWASP LLM Top 10 entry, each row carrying either a named control that already exists in this repository (with the `file:line` or control-name that implements it) or an explicit N/A with a reason. Verified by asserting all ten identifiers are present and that every row's disposition cell is non-empty.

#### AC-008

At least one row is N/A with a stated reason, and at least one row cites an existing control by name. This is a deliberate anti-padding assertion: it fails both a mapping that claims universal coverage and one that claims none.

### REQ-005 — the five absent runtime trust surfaces are documented (#134)

`docs/THREAT-MODEL.md` must cover the surfaces the #134 addendum names and the investigation found absent: Codex hook trust including first-run approval and the existence of `--dangerously-bypass-hook-trust` (INV-011); `~/.codex/config.toml` `hooks.state` (INV-012); the installer's MCP-registration marker block (INV-013); `plugins/sdd-quality-loop/hooks/claude-hooks.json` in its node exec form (INV-014); and the Claude Code settings/permissions model (INV-015).

`.codex/agents/*.toml` is already covered (INV-010) and must not be re-documented — a second, divergent description of the same control is the failure mode WFI-020 is about.

#### AC-009

Each of the five surfaces appears in `docs/THREAT-MODEL.md` with a stated trust assumption and at least one mitigation or an explicit residual-risk entry where no mitigation exists. Verified per surface by literal-string search for the surface's own identifier (e.g. `--dangerously-bypass-hook-trust`, `hooks.state`, `claude-hooks.json`), not by a generic heading match.

#### AC-010

The document names `--dangerously-bypass-hook-trust` explicitly and states what an operator who uses it gives up. A threat model that describes hook trust without naming its documented bypass is not a threat model.

### REQ-006 — documentation and behaviour are verified equal, not asserted equal (#133, #134)

The issue's second acceptance criterion is "スクリプト挙動と一致" — behaviour matches the document. That must be established by an executable check, because the whole reason this issue exists is that a prose claim and an implementation drifted apart unnoticed.

#### AC-011

`tests/cross-model.tests.{sh,ps1}` gain cases covering AC-003, AC-004, AC-005 and AC-006, and both suites pass. The tests must exercise the runners through a stub CLI on `PATH`, never by invoking a real vendor CLI — a test that needs network or vendor credentials is not a regression signal.

#### AC-012

The timeout default asserted by the tests is read from the same source the scripts read, so a future change to the default cannot leave the tests passing against a stale literal.

## Non-goals

- **Retries.** `performance-checklist.md` mentions "bounded retries" alongside timeouts, but adding retry logic changes cost and latency characteristics of a `critical` gate and is not required by either issue. Recorded as out of scope, not overlooked.
- **Rewriting the already-correct half of #133.** The absent/error path is documented and implemented correctly; this feature extends the taxonomy around it and must not restate or restructure it.
- **Re-documenting `.codex/agents/*.toml`** (INV-010).
- **Changing `check-cross-model`'s own logic.** The gate reads verdict files and is already correct (INV-004); the defect is upstream.
- **Pinning or vendoring the `codex` / `gemini` CLIs.** Their failure behaviour is outside this repository's control, which is exactly why AC-002 documents the limitation instead of asserting a guarantee.

## Edge Cases

1. **`timeout(1)` is unavailable.** Neither `timeout` nor `gtimeout` exists on the development host this feature was specified on — verified by `command -v`. The implementation must therefore not depend on GNU coreutils. `install.sh:758-781` already establishes the portable pattern this repository uses: a deadline computed from `date +%s`, polled with `kill -0`. A design that reaches for `timeout(1)` will work in CI and fail on a maintainer's machine.
2. **The child must actually die.** Terminating the runner without killing the vendor CLI leaves an orphan holding the API session. AC-004 asserts the child is gone, not merely that the parent returned.
3. **A partially written verdict.** If the CLI is killed mid-write, a truncated JSON must not be left where `check-cross-model` will read it — hence AC-005's absence assertion. The existing scripts write to a scratch path and move on success; the design must preserve that ordering.
4. **`SDD_PANELIST_TIMEOUT=0` or negative.** Rejected as a tool error (AC-003) rather than silently meaning "no bound", which would reintroduce the defect through configuration.
5. **A vendor CLI that rate-limits by sleeping rather than erroring.** Indistinguishable from a hang at the process boundary, and correctly handled as one — this is the substance of AC-002.

## Assumptions

- The `codex` and `gemini` CLIs terminate on `SIGTERM`. If one ignores it, an escalation to `SIGKILL` is required; the design must state which signal it sends and whether it escalates.
- Re-verify every `file:line` in this document at implementation start. Three of this repository's recorded defects (WFI-011, and the off-by-one citations corrected in `epic-136-phase4-mcp`) came from citations that were accurate when written and stale when used.

## Baseline Constraints

- **BL-001 — the absent/error path is behaviour-preserving.** A CLI that is absent or exits non-zero must behave exactly as it does today (exit 1, no verdict). The timeout is an additional bound, not a rewrite of the existing handler.
- **BL-002 — `check-cross-model` is unchanged.** No file under `plugins/sdd-quality-loop/scripts/check-cross-model.*` is edited by this feature.
- **BL-003 — the existing policy text is extended, not replaced.** `cross-model-verification-policy.md:28-31` and `:202-210` keep their current meaning; the taxonomy is added around them.
- **BL-004 — dual-runtime parity.** Whatever the shell runners do, the PowerShell runners must do. This repository enforces parity between the two runtimes and a one-sided fix would fail that.
- **BL-005 — no file in `PROTECTED_GATE_SUFFIXES` is written.** Confirmed for every target of this feature by direct read of `guard-invariants.generated.js:5` (INV-017), so no `human-copy` staging round applies.
