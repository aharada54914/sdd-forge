# Design: epic-136-phase4-docs

Impl-Review-Status: Passed

## Architecture Overview

Two independent streams sharing one release. They touch disjoint files and can land in either order.

**Stream A (#133)** adds a wall-clock bound to the panelist invocation and completes the failure taxonomy in the policy document. The bound goes in the four runner scripts — the only place that owns the child process. It deliberately does **not** go in `check-cross-model` (BL-002): that gate reads verdict files off disk and never invokes a panelist (INV-004), so a timeout there would be a bound on the wrong thing.

The design's central choice is that a timeout must be **indistinguishable downstream from a CLI error**. Nothing after the runner needs to learn a new state: exit 1 with no verdict file already flows through `check-cross-model` → missing verdict → diversity unmet → gate fails (INV-005). Introducing a distinct "timed out" signal would mean touching the gate, the aggregate schema, and the policy's consensus rules to carry information no consumer acts on differently.

**Stream B (#134)** appends two sections to `docs/THREAT-MODEL.md`: an OWASP LLM Top 10 / MCP cross-reference table, and coverage of the five runtime trust surfaces the addendum names. It edits no code.

## Components

| Component | Status | Change |
|---|---|---|
| `plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh` | Existing (extended) | wrap the `codex` invocation (`:216-220`) in the bounded-wait helper; read `SDD_PANELIST_TIMEOUT`; extend the header comment block (`:13-15`) with the timeout case |
| `plugins/sdd-quality-loop/scripts/run-panelist-gemini.sh` | Existing (extended) | same, around `:137-142` |
| `plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1` | Existing (extended) | replace `-Wait` with a bounded `WaitForExit` (`:184-195`) |
| `plugins/sdd-quality-loop/scripts/run-panelist-gemini.ps1` | Existing (extended) | same |
| `plugins/sdd-quality-loop/references/cross-model-verification-policy.md` | Existing (extended) | new "Panelist Failure Taxonomy" section; `:28-31` unchanged; the `:202-210` block (now `:203-211`) carries only the human-ratified exit-code correction (BL-003 posture preserved; tasks.md ruling 2026-08-07) |
| `docs/THREAT-MODEL.md` | Existing (extended) | two new sections; `:39-41` and `:56` unchanged (REQ-005 forbids re-documenting `.codex/agents/*.toml`) |
| `tests/cross-model.tests.sh` | Existing (extended) | AC-003/004/005/006 cases via a stub CLI |
| `tests/cross-model.tests.ps1` | Existing (extended) | parity cases (BL-004) |
| `plugins/sdd-quality-loop/scripts/check-cross-model.sh` | **Untouched** | BL-002 |

## API & Contract Plan

### The bounded-wait pattern (shell)

`timeout(1)` is not available — verified by `command -v timeout gtimeout`, both empty on the specification host (requirements Edge Case 1). The portable pattern this repository already uses for a deadline is `install.sh:758-781`: compute `$(( $(date +%s) + N ))` and poll with `kill -0`. Stream A applies the same shape to a child process:

```sh
_sdd_run_bounded() {                      # usage: _sdd_run_bounded <seconds> <cmd...>
    _bw_limit="$1"; shift
    # setsid puts the child in its own process group so the kill below reaches
    # any grandchild the vendor CLI spawned. Signalling a bare PID would leave
    # that grandchild orphaned holding the API session (Edge Case 2) — the
    # attempt-2 review finding. Where setsid is unavailable, fall back to a bare
    # invocation and record that the no-orphan guarantee is not available there.
    setsid "$@" &                          # child inherits the caller's redirections
    _bw_pid=$!
    _bw_deadline=$(( $(date +%s) + _bw_limit ))
    while kill -0 "$_bw_pid" 2>/dev/null; do
        if [ "$(date +%s)" -ge "$_bw_deadline" ]; then
            # Edge Case 6 — the deadline is not atomic with completion. Re-check
            # liveness once more before treating expiry as authoritative, so a
            # child that finished inside this very interval is reported by its
            # own exit code rather than as a timeout.
            kill -0 "$_bw_pid" 2>/dev/null || break
            # Negative pid = the whole process group, so descendants die too.
            kill -TERM "-$_bw_pid" 2>/dev/null || kill -TERM "$_bw_pid" 2>/dev/null
            sleep 2
            kill -0 "$_bw_pid" 2>/dev/null && \
                { kill -KILL "-$_bw_pid" 2>/dev/null || kill -KILL "$_bw_pid" 2>/dev/null; }
            wait "$_bw_pid" 2>/dev/null
            return 124
        fi
        sleep 1
    done
    wait "$_bw_pid"                        # propagates the child's real exit code
}
```

`SIGTERM` first, then `SIGKILL` after a 2-second grace — resolving the requirements' Assumption about signal handling explicitly rather than assuming the vendor CLI is well-behaved. Return code 124 is `timeout(1)`'s conventional timeout code, used here only as an internal marker; the caller maps it to the runner's exit 1.

Call-site shape at `run-panelist-gpt.sh:216-220`, preserving the existing redirections and the scratch-file ordering that Edge Case 3 depends on:

```sh
if ! _sdd_run_bounded "$_panelist_timeout" \
        "$_codex_cmd" --model "$model" --effort "$effort" --no-project-doc \
        < "$_combined" > "$_raw_output" 2>&1; then
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

Both branches exit 1 and neither reaches the verdict-write step, which is what AC-005 asserts. BL-001 holds by construction: the non-124 branch is byte-identical in behaviour to today's handler.

### The bounded-wait pattern (PowerShell)

`Start-Process … -Wait` has no timeout parameter (INV-003). Replace `-Wait` with `-PassThru` and a bounded wait:

```powershell
$proc = Start-Process -FilePath $CodexCmd -ArgumentList $codexArgs `
    -RedirectStandardInput $combinedFile -RedirectStandardOutput $rawOutput `
    -RedirectStandardError (Join-Path $scratch "stderr.txt") -PassThru -NoNewWindow
if (-not $proc.WaitForExit($PanelistTimeout * 1000)) {
    $proc.Kill($true)                      # $true = kill the whole process tree
    $proc.WaitForExit()
    [Console]::Error.WriteLine("run-panelist-gpt: codex CLI exceeded SDD_PANELIST_TIMEOUT=${PanelistTimeout}s; terminated")
    exit 1
}
if ($proc.ExitCode -ne 0) { <# unchanged #> exit 1 }
```

`Kill($true)` terminates the process tree, matching the shell side's escalation intent.

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

**No data changes.** This feature introduces no database, no persisted schema, and no new document format. The complete set of artifacts it writes or edits is the Components table above: four runner scripts, two Markdown documents, and two test suites.

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

- **No protected gate file is written.** BL-005, verified against `guard-invariants.generated.js:5` (INV-017). `check-cross-model.*` is untouched (BL-002).
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
| AC-004 | TEST-004 | Item 2 below | sub-cases (a)/(b)/(c); wall-clock bound, SIGKILL escalation, boundary re-check |
| AC-005 | TEST-005 | Item 3 below | exit 1 **and** no verdict JSON |
| AC-006 | TEST-006 | Item 4 below | composed with `check-cross-model`; the test that closes the issue's stated concern |
| AC-007 | TEST-007 | Stream B deliverable 1 | ten OWASP identifiers, every disposition cell non-empty |
| AC-008 | TEST-008 | Stream B deliverable 1 | ≥1 N/A row with a reason **and** ≥1 row citing an existing control — the anti-padding assertion |
| AC-009 | TEST-009 | Stream B deliverable 2 | five surface identifiers by literal string |
| AC-010 | TEST-010 | Stream B deliverable 2 | `--dangerously-bypass-hook-trust` named, with what it forfeits |
| AC-011 | TEST-011 | Item 5 below | both suites pass, pre-existing cases unmodified |
| AC-012 | TEST-012 | Item 7 below | the asserted default is read from the script, not hard-coded in the test |
| AC-013 | TEST-013 | Stream B deliverable 1a | all three MCP server names with a trust posture each |
| AC-014 | TEST-014 | Stream B deliverable 2 | residual-risk entry for the unbounded panelist, marked closed, naming `SDD_PANELIST_TIMEOUT` |

1. **AC-003 — configuration parsing.** Seven sub-cases per runner: unset, empty, `600`, `1`, `0`, `-5`, `abc`.
   - **First four** (unset, empty, `600`, `1`): the runner proceeds to invoke the CLI. `1` is a **valid** bound, not an invalid one — it is the same value item 2's timeout sub-cases depend on being accepted.
   - **Last three** (`0`, `-5`, `abc`): exit 2 **before** the CLI is invoked, asserted by a stub that records whether it was called at all.

   Stated as four-plus-three rather than three-plus-three because an earlier draft of this line wrote "first three / last three" against a seven-item list, leaving `1` unclassified — contradicting both item 2 below and the Configuration contract table above, which classify `1` as valid. Spec review caught that arithmetic at the requirements layer (`acceptance-tests.md:43`, both round-2 reviewers independently), but this document kept the stale phrasing; both impl reviewers then caught it here, independently, at attempt 2 round 1.
2. **AC-004 — the bound actually bounds.** Three sub-cases after spec-review round 1, because one was not enough:
   - **(a)** `SDD_PANELIST_TIMEOUT=1` plus a stub that sleeps 30s. Assert elapsed wall-clock ≤ 10s and that the stub's PID is gone afterwards. The liveness assertion distinguishes a real kill from a parent that merely returned.
   - **(b)** the same, but the stub installs `trap '' TERM`. Only the `SIGKILL` escalation can end it, so this is the sub-case that proves the escalation branch exists. A plain `sleep` stub dies on the first `SIGTERM` and can never reach it — which meant the original single case would have passed against a broken or absent escalation.
   - **(c)** `SDD_PANELIST_TIMEOUT=2` with a stub exiting *successfully* at ~2s, repeated ≥ 5 times. Asserts the boundary re-check above: a child that finished inside the expiry interval must be reported by its own exit code, never as a timeout.
3. **AC-005 — no partial verdict.** After a timeout, assert exit 1 **and** that the output directory contains no verdict JSON for that task.
4. **AC-006 — the gate actually fails.** Compose 2 and 3 with `check-cross-model` over the resulting verdict directory; assert non-zero and no consensus PASS. This is the only test that demonstrates the issue's stated `critical`-verification concern is closed.
5. **BL-001 — behaviour preservation.** The existing absent-CLI and non-zero-exit cases must pass **unmodified**. If an existing case needs editing to accommodate the timeout, that is evidence BL-001 was broken.
6. **BL-004 — parity, with one deliberate exception.** Every case above exists in both `tests/cross-model.tests.sh` and `.ps1`, **except AC-004 sub-case (b)**, which the PowerShell suite carries **none of, deliberately**. PowerShell's termination step cannot be survived — `Process.Kill` maps to `TerminateProcess`, which is untrappable — so no stub behaviour would let a (b) sub-case verify anything (a) does not already verify; writing one would be a test that cannot fail. BL-004 is therefore satisfied at the level of **outcome** (both runtimes must end the child and leave no orphan), not by mirroring a POSIX signal model onto a platform with no equivalent. This carve-out is stated in `requirements.md:67,75` and tabulated in `acceptance-tests.md:64-68`; spec review round 3 blocked an earlier draft that got this wrong, so it is restated here rather than left to inference.
7. **AC-012 — the default is not duplicated.** The `600` the tests assert is **derived from the runner script at test time**, not written as a literal in the test — e.g. by extracting the `${SDD_PANELIST_TIMEOUT:-600}` default from the script's own source and comparing against that. A test that carries its own copy of the constant keeps passing after someone changes the script's default, which turns the test from a guard into a decoration. This is the one case where a literal-string assertion is *wrong*: everywhere else in this plan the literal is the point (item 8), but here the literal is the defect. TEST-012 is the check.
8. **Stream B** is verified by literal-string assertions per REQ-004/REQ-005 — ten OWASP identifiers (TEST-007), **the three MCP server names `sdd-forge-mcp`, `local-env-mcp` and `ci-mcp` (TEST-013)**, five surface identifiers (TEST-009), and `--dangerously-bypass-hook-trust` by name (AC-010, TEST-010). Deliberately literal: a heading-level check would pass against an empty section, which is the text-marker failure mode recorded as FP-02 in the `epic-136-phase3` retrospective. TEST-013 is listed separately from TEST-007 on purpose — they verify the two halves of REQ-004, and collapsing them is exactly how the MCP deliverable went missing from this plan in the first place.

## Deployment & CI Plan

No new CI step. The existing `test` job runs `tests/run-all.sh`, which already registers `cross-model.tests.sh`. No `dist/` bundle is involved — these are shell/PowerShell/Markdown files, so ADR-0003 does not apply and there is no rebuild obligation.

Stack for the verification contract is `shell` (shell, PowerShell and Markdown only), which makes `lint`/`typecheck`/`build` waivable with a reason per `risk-gate-matrix.md`'s Stack descriptor table.

## Global Constraints

- No file listed in `PROTECTED_GATE_SUFFIXES` is written (BL-005, INV-017). Confirmed by direct read of `guard-invariants.generated.js:5`; every target of this feature is absent from those 42 entries, so no `human-copy` staging round applies.
- `check-cross-model.*` is not edited (BL-002).
- Shell and PowerShell runners change together in the same commit (BL-004).
- No version literal outside `scripts/bump-version.sh` changes.

## Risks

- **A 600s default that is too tight for a slow vendor** would convert a working panel into a failing gate — a false fail-closed. Mitigated by the env override and by choosing the value against the repository's existing longest-wait constant rather than a guess. Recorded rather than dismissed: if a real panel trips this, the fix is the override, not removing the bound.
- **`sleep 1` polling adds up to one second of latency** to every panelist call. Negligible against a multi-minute LLM review, and the alternative (`wait -n`, or SIGCHLD traps) is less portable across the `sh` implementations this repository targets.
- **The 2-second SIGTERM grace is a guess.** It is stated explicitly in the design so a reviewer can challenge it, rather than buried in the implementation.
- **Stream B's OWASP mapping is a judgement call.** AC-008's anti-padding assertion is the guard against the most likely failure — a table where every row claims coverage. It cannot guarantee the judgements are *right*, only that they are not uniformly self-congratulatory; the impl-review gate is where the substance gets challenged.
