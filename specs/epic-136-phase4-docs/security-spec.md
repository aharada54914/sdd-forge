# Security Spec: epic-136-phase4-docs

This feature is itself security work, so this document is load-bearing rather than a formality: Stream A closes an availability hole in a `critical`-tier verification path, and Stream B is a threat-model edit whose own accuracy is a security property.

## Baseline and amendment precedence — 2026-09-08

The INV-based descriptions below, including "today", "current state" and
"no bound exists", describe the original investigation baseline, not the
present implementation. The current shell helper already implements group
supervision (`plugins/sdd-quality-loop/scripts/lib/panelist-common.sh:63-120`)
and the GPT PowerShell runner already implements a bounded wait
(`plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1:242-273`). Neither
observation proves the amended boundary acceptance tests pass. The amended
design governs remediation and preserves group-wide cleanup, including when
the leader has exited. Its shared helper is explicitly in scope and protected.
For B2 and INV-005, requirements BL-003/AC-006 override the old undifferentiated
gate-failure description: one remaining valid Anthropic verdict means gate
exit 1 and aggregate FAIL; empty input means gate exit 2 and no aggregate.
Both follow runner timeout exit 1 with no verdict and neither permits PASS.

The B1 closure claims below are required outcomes, not established evidence.
In particular, PowerShell root exit after `Kill($true)` does not establish
descendant exit; Microsoft's [Process.Kill contract](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.kill?view=net-9.0)
explicitly distinguishes them. TEST-004 must observe child and descendant
liveness independently. Cleanup failure remains exit 1/no verdict and does
not satisfy the no-orphan acceptance condition. The amended design must
resolve bounded cleanup/output completion before implementation review passes.

## Trust Boundaries

### B1 — the vendor CLI process boundary (Stream A, #133)

`run-panelist-{gpt,gemini}.{sh,ps1}` hand control to an external binary (`codex`, `gemini`) that this repository neither ships, pins, nor vendors. Everything past the invocation is untrusted: its exit code, its runtime, its output bytes, and whether it returns at all.

Today the boundary is only half-guarded. Exit codes are handled (INV-001, INV-002, INV-003); **duration is not** — no bound exists anywhere in the four runners, the gate, or the orchestrating skill (INV-004, INV-006). An unbounded external call inside a security gate is the defect this feature closes.

### B2 — the cross-model consensus as an assurance signal (Stream A, #133)

`check-cross-model`'s consensus is consumed as evidence that more than one vendor examined a `critical` task. Anything that lets that signal be produced, withheld, or stalled without the gate noticing weakens the assurance the signal is supposed to carry.

The already-correct half: a missing verdict makes diversity unmet, which fails the gate (INV-005). The hole: a hung panelist never produces the missing verdict *and* never lets the gate run, so the failure is a stall rather than a decision.

### B3 — the threat model as a control inventory (Stream B, #134)

`docs/THREAT-MODEL.md` is read by humans deciding whether a control exists. A threat model that omits a live trust surface is worse than absent, because it invites the reader to conclude the surface was considered and found safe. Five such surfaces are currently omitted (INV-011 through INV-015).

### B4 — the hook-trust surface the threat model omits (Stream B, #134)

Codex's first-run hook-trust approval, and the documented `--dangerously-bypass-hook-trust` escape, together decide whether this repository's entire deterministic-gate chain runs at all. That is the highest-leverage control in the system and it is currently undocumented. `~/.codex/config.toml`'s `hooks.state` persists the decision; the installer writes an MCP-registration marker into the same file; `hooks/claude-hooks.json` is the equivalent surface on the Claude Code side.

## STRIDE Analysis

| Boundary | Category | Threat | Current state | Disposition in this feature |
|---|---|---|---|---|
| B1 | **Denial of Service** | A vendor CLI that hangs — from a rate limit implemented as a sleep, a network stall, or a wedged process — blocks the collection phase indefinitely | No bound exists (INV-001/003/004/006), contradicting `performance-checklist.md`'s own "External calls have timeouts" requirement (INV-007) | Closed by REQ-002: `SDD_PANELIST_TIMEOUT`, default 600s, SIGTERM then SIGKILL |
| B1 | **Elevation of Privilege** | A killed CLI leaves an orphan holding a live vendor API session | Not addressed; nothing kills the child today | Closed by AC-004's liveness assertion — the test fails if the child survives |
| B2 | **Spoofing of assurance** | A truncated verdict written by a CLI killed mid-write is read by `check-cross-model` as a real verdict | Not reachable today (nothing kills the CLI), but **introduced** by REQ-002 unless guarded | Closed by AC-005: exit 1 **and** no verdict file. This is a threat this feature creates and must therefore retire |
| B2 | **Tampering (by configuration)** | `SDD_PANELIST_TIMEOUT=0` read as "no bound", reintroducing the hole through config rather than code | N/A (variable does not exist yet) | Closed by AC-003: `0`, negative and non-numeric all exit 2 before the CLI is invoked |
| B3 | **Repudiation / false assurance** | A reader concludes an undocumented surface was assessed and cleared | Five surfaces absent (INV-011..015) | Closed by REQ-005; AC-009 asserts each by its own literal identifier so an empty section cannot pass |
| B4 | **Elevation of Privilege** | An operator disables the whole gate chain via `--dangerously-bypass-hook-trust` without understanding what is forfeited | Flag is entirely unmentioned in the threat model (INV-011) | Closed by AC-010, which requires the flag be named *and* its cost stated |
| B1 | **Information Disclosure** | The panelist input bundle reaches an external vendor | Already governed by the existing consent gate and sanitisation in `cross-model-verification-policy.md` | **Unchanged** — out of scope, named here so its absence from the change set is a decision, not an oversight |

## Data Classification and Protection

Nothing in this feature reads, writes, or transports secrets. `SDD_PANELIST_TIMEOUT` is a non-secret integer. The timeout path deliberately produces **no** new artifact — its correctness is defined by the absence of a file (AC-005), which is also why it cannot leak.

The stderr message on timeout names the configured bound and the vendor CLI, and must not echo the panelist input bundle. The existing handler's `cat "$_raw_output" >&2` already prints vendor output on failure and is unchanged by this feature (BL-001); widening it is out of scope.

## Authorization

- The human-authorized 2026-09-08 PR #400 amendment supersedes INV-017's no-protection claim. Requirements BL-005 binds dated source evidence identifying both shell runners as protected and requires refreshed evidence at each consumption boundary. Obtain human evidence if inspection is denied, and require human application of exact reviewed bytes with before/after hashes for protected targets. Source membership is not a runtime verdict or authorization; missing evidence/application blocks the affected operation, and no alternate path may bypass a hook denial.
- `check-cross-model.*` is not edited (BL-002). The gate that judges is not modified by the change it judges.
- No `SDD_SUDO` interaction. This feature neither reads nor requires sudo state.

## Security Tests

The mapping from boundary to executable check:

| Boundary | Test | What would be missed without it |
|---|---|---|
| B1 DoS | TEST-004 | a bound that is documented but not enforced |
| B1 EoP | TEST-004 assertion 2 | an orphaned vendor process holding a session |
| B2 Spoofing | TEST-005 | a truncated verdict treated as real — the threat this feature introduces |
| B2 assurance | TEST-006 | the runner behaving correctly while the gate still passes |
| B2 Tampering | TEST-003 | `SDD_PANELIST_TIMEOUT=0` silently disabling the bound |
| B3 | TEST-007, TEST-009 | an empty section satisfying a heading-level check |
| B4 | TEST-010 | hook trust described without naming its bypass |

TEST-006 is the one that closes the issue's stated concern. The others prove components behave; only TEST-006 proves the assurance signal cannot be produced by a stalled panel.

Every case drives a stub binary on `PATH` (AC-011). A security test that needs vendor credentials cannot run in CI, and a security test that cannot run is not a control.
