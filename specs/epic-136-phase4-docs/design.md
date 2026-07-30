# Design: epic-136-phase4-docs

Impl-Review-Status: Pending

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
| `plugins/sdd-quality-loop/references/cross-model-verification-policy.md` | Existing (extended) | new "Panelist Failure Taxonomy" section; `:28-31` and `:202-210` unchanged (BL-003) |
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
    "$@" &                                 # child inherits the caller's redirections
    _bw_pid=$!
    _bw_deadline=$(( $(date +%s) + _bw_limit ))
    while kill -0 "$_bw_pid" 2>/dev/null; do
        [ "$(date +%s)" -ge "$_bw_deadline" ] && { kill -TERM "$_bw_pid" 2>/dev/null
            sleep 2
            kill -0 "$_bw_pid" 2>/dev/null && kill -KILL "$_bw_pid" 2>/dev/null
            wait "$_bw_pid" 2>/dev/null
            return 124; }
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

Appended to `cross-model-verification-policy.md`, leaving `:28-31` and `:202-210` intact (BL-003):

| Failure mode | Runner exit | Verdict file | Reaches the gate as |
|---|---|---|---|
| CLI absent | 1 | none | missing verdict → diversity unmet → gate fails |
| CLI exits non-zero | 1 | none | same |
| CLI exceeds `SDD_PANELIST_TIMEOUT` | 1 | none | same |
| CLI rate-limited | 1, **via** one of the two rows above | none | same |
| CLI returns malformed output | 2 | none | tool error; caller cannot claim consensus |
| Runner misconfigured (bad `SDD_PANELIST_TIMEOUT`) | 2 | none | tool error |

The rate-limit row is deliberately not a separate mechanism (AC-002): whether a rate-limited vendor CLI errors or stalls is the vendor's choice, and this repository pins neither CLI. Claiming a rate-limit-specific guarantee would be unverifiable, so the document states the limitation instead.

### `docs/THREAT-MODEL.md`: two appended sections

1. **OWASP LLM Top 10 / MCP cross-reference** — one row per LLM01…LLM10, each row carrying either a named existing control or an explicit N/A with a reason (AC-007, AC-008). The mapping is written by reading the existing Controls Table (`:48-65`) and Threats & Mitigations (`:69-109`) and asking which OWASP entry each already answers — not by inventing controls to fill rows.
2. **Runtime trust surfaces** — the five absent surfaces (INV-011…INV-015), each with a trust assumption and either a mitigation or an explicit residual-risk entry. `.codex/agents/*.toml` is referenced by pointer to its existing rows, never restated (REQ-005).

## Design Decisions (Resolving Open Questions)

- **OQ-1 (rate-limit behaviour): documented as unknowable from this repository.** Neither vendor CLI is pinned or vendored, so their rate-limit behaviour cannot be asserted. Resolved by AC-002 as a stated limitation. Inventing a guarantee here would produce a spec claim no test could hold.
- **OQ-2 (bound value and scope): per-panelist, 600s, env-configurable.** Per-panelist rather than per-collection-phase because the runner is the only component that owns a child process; a collection-phase bound would require the orchestrating skill to become a process supervisor, which is a much larger change than either issue asks for.
- **OQ-3 (exit code on timeout): exit 1.** The load-bearing decision. Exit 1 reuses the entire existing fail-closed chain unchanged; exit 2 would mean "tool error", misattributing a vendor non-response to this repository's tooling and forcing changes in the gate and the caller. See REQ-003.
- **OQ-4 (test coverage): yes, in `tests/cross-model.tests.{sh,ps1}`**, through a stub CLI on `PATH`. A test that calls a real vendor needs credentials and a network and is not a regression signal (AC-011).
- **#134 OQ-3 (does the hang land in the threat model too): yes.** The unbounded-panelist finding is added to `docs/THREAT-MODEL.md`'s Residual Risks as *closed by this feature*, with a pointer to `SDD_PANELIST_TIMEOUT`. A threat model that omits a hole the same release closed would be stale on arrival.

## Test Strategy

1. **AC-003 — configuration parsing.** Unset, empty, `600`, `1`, `0`, `-5`, `abc`. First three proceed; last three exit 2 **before** the CLI is invoked, asserted by a stub that records whether it was called at all.
2. **AC-004 — the bound actually bounds.** `SDD_PANELIST_TIMEOUT=1` plus a stub that sleeps 30s. Assert elapsed wall-clock is under a generous margin (≤ 10s) and that the stub's PID is gone afterwards. The liveness assertion is what distinguishes a real kill from a parent that merely returned.
3. **AC-005 — no partial verdict.** After a timeout, assert exit 1 **and** that the output directory contains no verdict JSON for that task.
4. **AC-006 — the gate actually fails.** Compose 2 and 3 with `check-cross-model` over the resulting verdict directory; assert non-zero and no consensus PASS. This is the only test that demonstrates the issue's stated `critical`-verification concern is closed.
5. **BL-001 — behaviour preservation.** The existing absent-CLI and non-zero-exit cases must pass **unmodified**. If an existing case needs editing to accommodate the timeout, that is evidence BL-001 was broken.
6. **BL-004 — parity.** Every case above exists in both `tests/cross-model.tests.sh` and `.ps1`.
7. **Stream B** is verified by literal-string assertions per REQ-004/REQ-005 — ten OWASP identifiers, five surface identifiers, and `--dangerously-bypass-hook-trust` by name (AC-010). Deliberately literal: a heading-level check would pass against an empty section, which is the text-marker failure mode recorded as FP-02 in the `epic-136-phase3` retrospective.

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
