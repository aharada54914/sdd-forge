# Security Spec: mcp-readonly-preflight

This feature is partly security work by construction: issue #129's own framing is that giving MCP write/approval/state-mutation authority would be dangerous, and its Proposed change is as much about *withholding* capability as about adding a step. So this document is load-bearing rather than a formality — but the load it bears is unusual, because the feature's principal security property is one it must **preserve**, not one it must build.

## Trust Boundaries

### B1 — the agent ↔ MCP server process boundary (Stream A)

`bootstrap` and `ship` will, for the first time, instruct the agent to call an MCP server during a workflow run. The servers run as stdio child processes registered by the installer (`install.sh:355-357` for Claude Code, `:374-391` for the Codex marker block).

**This boundary already exists and is already crossed.** The three servers are registered by default (`install.sh:18`, `README.md:108`) and any MCP client can already call them. What this feature adds is a *caller inside the SDD workflow*, which changes the consequence of a bad answer, not the reachability of the server.

Current state: all fourteen registered `sdd-forge-mcp` tools are read-only, verified by reading every `server.registerTool(` declaration at `mcp/sdd-forge-mcp/src/server.ts:65-219` (INV-006). The strongest available guarantee is structural — the probe has no write tool to call — rather than behavioural.

### B2 — the workflow's decision authority (Stream A)

This is the boundary the issue actually cares about. SDD's gates decide what may proceed: `Approval: Approved`, `Spec-Review-Status: Passed`, `Impl-Review-Status: Passed`, and the deterministic gate scripts. Those decisions are made from files and from gate scripts, and their integrity is what the whole enforcement chain rests on.

Introducing an MCP consultation *into the workflow* creates a path by which a non-authoritative source could influence an authoritative decision — if the agent were to treat the probe's answer as a conclusion rather than as information. `get_next_sdd_command` is the sharpest case: it returns *the next SDD command*, which reads exactly like an instruction.

**This is a threat this feature creates and must therefore retire.** It does not exist today because no such call exists today (INV-004, INV-005).

### B3 — the protected-file boundary (Stream A)

`plugins/sdd-ship/skills/ship/SKILL.md` is on `PROTECTED_GATE_SUFFIXES` (`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`) and in `PHASE2_HUMAN_COPY_TARGETS` (`:18`). It is part of the enforcement chain, which is why an agent cannot write it.

There is a self-referential hazard worth naming: `ship/SKILL.md:314` instructs agents to "**Never** modify gate scripts … or hook files", and `:317-318` extends that to `plugins/sdd-quality-loop/hooks/` and `sdd-hook-guard.*`. A feature that edited this file by agent write would be contradicting the document it is editing, in the file that carries the instruction.

### B4 — the documentation as a capability inventory (Stream B)

`README.md` and `USERGUIDE.md` are what an operator reads to decide whether MCP can affect their workflow. Documentation that understates a capability invites a reader to conclude a control exists when it does not.

Current state is **accurate but incomplete** (INV-007, INV-008): five statements correctly designate the servers read-only, and two of them state there is no write API. What is absent is the workflow-level claim — that MCP does not auto-advance the workflow — and the forward-looking policy against adding write tools. A near-precedent exists at `docs/adr/0006-ci-mcp-readonly-github-actions.md:36` and `:67-69`, but scoped to `ci-mcp` alone (INV-009).

## STRIDE Analysis

| Boundary | Category | Threat | Current state | Disposition in this feature |
|---|---|---|---|---|
| B2 | **Elevation of Privilege** | The agent treats `get_next_sdd_command`'s answer as authoritative and advances or skips a gate on it | Not reachable — no such call exists (INV-004, INV-005) | **Introduced by this feature**; closed by REQ-005 / AC-012 / AC-013 asserting outcome equality with and without the probe. Closed by an assertion, not by the instruction text asking the agent to behave |
| B2 | **Tampering** | An MCP tool mutates spec, task, or approval state | Structurally impossible — no write tool registered among the fourteen (INV-006) | **Preserved** by REQ-006 / AC-014…AC-016, asserted against the tool registry rather than the prose |
| B2 | **Spoofing of workflow state** | A registered-but-stale `dist/` bundle answers successfully with outdated parsing logic, indistinguishable from a healthy probe | Not reachable today | **Residual, explicitly not closed.** No fallback branch catches it — the call succeeds. Bounded only by AC-012/AC-013: wrong advice cannot change the outcome. Recorded as residual rather than mitigated (Edge Case 4, design R-7) |
| B1 | **Denial of Service** | An unavailable or hanging MCP server stalls a `bootstrap` / `ship` run | Not reachable today | Partially closed by REQ-004 / AC-008…AC-011 for the *unavailable* and *call-fails* cases. **A hung server is neither**, and no timeout is specified — see Residual Risks |
| B1 | **Information Disclosure** | Repository state leaves the machine via the probe | `sdd-forge-mcp` reads local files and returns envelopes over stdio; no network egress. `ci-mcp` does reach `https://api.github.com` but is not part of any probe set under consideration | **Unchanged** — named so its absence from the change set is a decision, not an oversight |
| B3 | **Tampering** | The enforcement chain is weakened by an agent-authored edit to a protected skill | Blocked by the guard | Respected via BL-004 and the staging pattern (INV-011); asserted by AC-002 / AC-026, which check the live path was not agent-written |
| B4 | **Repudiation / false assurance** | A reader concludes MCP cannot influence the workflow because the docs say "read-only", when "read-only" describes the tools and not the workflow relationship | Five accurate but tool-scoped statements exist (INV-007, INV-008) | Closed by REQ-008 / REQ-009 and AC-021…AC-024, each requiring an accompanying substantive statement rather than a keyword |
| B4 | **Elevation of Privilege (future)** | A later change adds a write tool because no policy forbade it | Only `ci-mcp` is covered, by ADR-0006 (INV-009) | Closed by AC-022 / AC-024, which require the standing policy be written for all three servers |

## Data Classification and Protection

**No secrets are read, written, or transported by this feature.**

The probe reads and discards: it writes no file, creates no cache, and leaves no artifact (design Data Plan). Its result exists only in the agent's context for the duration of the run.

Two points where a secret could plausibly appear, and why it does not:

1. **`ci-mcp` requires a GitHub PAT** (`USERGUIDE.md:237-243`). It is not among the tools issue #129 names, and OQ-001 is constrained by D-002 to the already-registered set — but if OQ-001 were resolved to include a `ci-mcp` tool, this section would need revisiting. Named so the dependency is visible rather than discovered later.
2. **Probe output in the run transcript.** `sdd-forge-mcp` returns SDD state — feature names, task IDs, review statuses — which is repository content, not credentials. If OQ-005 resolves toward displaying probe output, the displayed content should remain the envelope's own fields and must not echo file contents wholesale.

## Authorization

- **No file in `PROTECTED_GATE_SUFFIXES` is written by an agent.** Verified by `endswith()` against all four named targets (INV-010): `ship/SKILL.md` is a member; `bootstrap/SKILL.md`, `USERGUIDE.md` and `README.md` are not. The member is handled by staging (BL-004).

  > **Re-verify at spec-review** (AGENTS.md `## Rules`, author-time sweep 3). This membership is repository-wide, git-tracked, shared state that this branch does not exclusively own, and it gates the reviewer's conclusion about task decomposition. Re-derive it from `guard_invariants.py:4` rather than accepting it from this document. Note that a read-only shell command mentioning that path may itself be denied by `sdd-hook-guard` (INV-012, confirmed first-hand); restructure the command rather than work around the guard.

- **No `SDD_SUDO` interaction.** This feature neither reads nor requires sudo state, and sudo would not help: `guard_invariants.py`'s protection is not sudo-bypassable, as `sdd-hook-guard`'s own denial message states.
- **No approval, gate, or review status is set by this feature**, and the probe cannot set one because no registered tool can.
- **No installer or registration change.** REQ-003 forbids the skills from depending on registration, and BL-001 keeps `install.sh` untouched.

## Security Tests

The mapping from boundary to executable check:

| Boundary / threat | Test | What would be missed without it |
|---|---|---|
| B2 EoP (probe treated as authoritative) | TEST-012, TEST-013 | the central threat this feature creates — an advisory layer that quietly decides |
| B2 Tampering (write tool exists) | TEST-014, TEST-015, TEST-016 | a write tool added later with no assertion to catch it |
| B1 DoS (unavailable) | TEST-008, TEST-010 | a run that fails when MCP is simply absent — a supported configuration (`install.sh:45`) |
| B1 DoS (call fails) | TEST-009, TEST-011 | the attempted-and-failed path the addendum's own wording describes |
| B3 Tampering (protected path) | TEST-003, TEST-026 | an agent-authored edit to the enforcement chain |
| B4 false assurance | TEST-021, TEST-023 | a keyword passing for a statement |
| B4 future EoP | TEST-022, TEST-024 | the standing policy never being written |

**TEST-012 and TEST-013 are the load-bearing pair.** Every other test proves a component behaves; only these two prove the probe cannot influence a workflow decision — which is the entire security thesis of issue #129. They are differential tests (same repository state, probe present versus absent, conclusions compared) precisely because a single-run test cannot distinguish "the probe did not influence the outcome" from "the probe happened to agree".

**TEST-014 … TEST-016 assert against the tool registry, never the documentation.** Asserting the prose would make them pass whenever TEST-021 … TEST-024 pass, converting a control into a decoration — and the drift between a prose claim and an implementation is the exact failure mode #129 exists to prevent.

## Residual Risks

1. **A hung MCP server is not bounded.** REQ-004 covers "unavailable" and "call fails". A server that accepts the call and never returns is neither, and no timeout is specified anywhere in this feature. This is the same class of hole `epic-136-phase4-docs` found and closed for the cross-model panelists (`SDD_PANELIST_TIMEOUT`), and this repository's own `plugins/sdd-quality-loop/references/performance-checklist.md:33` requires that "External calls have timeouts and bounded retries (no unbounded fan-out)". **Not closed by this specification, and not silently omitted either** — it is closely related to OQ-010 but is a distinct condition, and whether it is in scope for #129 is a human decision. Recorded so it is not rediscovered as a surprise.
2. **A stale MCP bundle gives confident wrong advice.** B2 spoofing above. Bounded but not eliminated by AC-012/AC-013.
3. **The advisory framing depends on an agent following prose.** AC-012/AC-013 assert the outcome is unaffected, which is the strongest available check, but it is a check on observed runs, not a structural impossibility. Unlike B2 tampering — which is structurally impossible because no write tool exists — B2 elevation is prevented by discipline plus assertion. Stated plainly because the asymmetry between the two B2 rows is real and a reader should not assume both carry the same strength of guarantee.
4. **`ship/SKILL.md`'s protected status is re-verified only at review time.** Between spec-review and implementation, another branch could change the membership list. R-5 in `design.md`; the re-verification instruction above is the mitigation, and it is a process control, not a mechanical one.
