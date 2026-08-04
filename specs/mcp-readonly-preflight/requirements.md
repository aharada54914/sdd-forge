# Requirements: mcp-readonly-preflight

Spec-Review-Status: Pending

Source issue: [#129](https://github.com/aharada54914/sdd-forge/issues/129) (`enhancement`, `workflow-improvement`; Key `ENH-22`, Finding A-4, Plan Phase 4), including its 2026-07-10 runtime addendum.

## Overview

Issue #129 carries two obligations of very different maturity, and the investigation showed the issue's own framing is accurate about one and overstated about the other.

**The probe is a genuine create.** Neither `bootstrap` nor `ship` mentions MCP anywhere — both files return zero case-insensitive matches for `mcp` (INV-004, INV-005). The tools the issue names exist and are registered read-only (INV-006). So there is no partial implementation to extend; the step is absent, and the issue's problem statement holds exactly as written.

**The policy statement is a partial gap-fill, not a blank page.** `README.md` and `USERGUIDE.md` already designate all three MCP servers `**read-only**`, in five places between them, two of which additionally state there is no write API (INV-007, INV-008). What is genuinely absent is the narrower pair of claims the issue's Proposed change actually asks for: that MCP is an advisory layer which **does not auto-advance the workflow**, and a standing policy **against adding write tools**. A near-precedent exists at `docs/adr/0006-ci-mcp-readonly-github-actions.md:36,67-69` but is scoped to `ci-mcp` alone (INV-009).

This distinction matters for scope: a specification that treated the policy half as a create would license rewriting five correct existing sentences.

**The issue's `USERGUIDE.md:27` citation is stale** (INV-003). Line 27 is part of the `--effort-policy welded` discussion and says nothing about read-only. The read-only statements are at `USERGUIDE.md:40`, `:135` and `:213`. No document in this feature may cite `:27` for that claim.

**One target file cannot be written by an agent**, which the issue does not mention. See *Protected Gate Files* below.

**This specification deliberately leaves ten Open Questions unresolved.** They are enumerated in `investigation.md` as OQ-001 through OQ-010 and are load-bearing — OQ-005 in particular (what the agent does with the probe result, and what happens when the probe disagrees with the file-based conclusion) is the difference between a specifiable feature and an unspecifiable one. Several criteria below are therefore explicitly conditioned on a resolution rather than silently assuming one. Per `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:53`, unknown product decisions are recorded, not invented.

## Protected Gate Files

`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4` defines `PROTECTED_GATE_SUFFIXES`. A repo-relative path is protected when it `endswith()` any tuple member. Tested against all four of this feature's named target files (INV-010):

| Target file | Protected? | Consequence |
|---|---|---|
| `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` | no | ordinary agent edit |
| **`plugins/sdd-ship/skills/ship/SKILL.md`** | **YES** | **agent cannot write it; requires a human-applied patch** |
| `USERGUIDE.md` | no | ordinary agent edit |
| `README.md` | no | ordinary agent edit |

`plugins/sdd-ship/skills/ship/SKILL.md` is additionally listed in `PHASE2_HUMAN_COPY_TARGETS` at `guard_invariants.py:18`.

**This changes how tasks must be planned, not merely how one file is edited.** Any task that would modify `ship/SKILL.md` cannot be an ordinary implementation task. The repository's established pattern (INV-011) is to stage a candidate under `specs/<feature>/human-copy/<repo-relative-path>` together with a `MANIFEST.sha256`, and to have a human apply it in a separate commit — precisely as `specs/quality-loop-fixes/human-copy/plugins/sdd-ship/skills/ship/SKILL.md` does, with conformance asserted by `tests/quality-gate-cycle-limit.tests.sh:363-378`. Concretely, task decomposition must:

1. keep the `ship/SKILL.md` change in its own task, disjoint from the three writable targets, so the writable work can reach Done without waiting on a human;
2. express that task's `Done When` in terms of the **staged candidate plus manifest entry**, never in terms of the live file's content, because the agent cannot produce the live file's content; and
3. carry an explicit human action in the handoff.

The alternative — descoping `ship/SKILL.md` — is OQ-007 and is a human decision.

> **Re-verification instruction (AGENTS.md `## Rules`, author-time sweep 3).** The membership table above is a claim about repository-wide, git-tracked, shared state that this branch does not exclusively own: `PROTECTED_GATE_SUFFIXES` is generated from `plugins/sdd-quality-loop/references/guard-invariants.json` and can change on any branch. **At spec-review time, the reviewer must re-derive this table** by reading `guard_invariants.py:4` in the working tree and applying `endswith()` to each of the four repo-relative paths above, rather than accepting this table on the strength of prose. The claim gates a reviewer's conclusion about task decomposition, so the re-verification belongs at the review gate. If any row's answer has changed, the decomposition constraints above change with it.
>
> Reading that file with a shell command may itself be denied by `sdd-hook-guard` even though the read is harmless (INV-012). Restructure the command — a `python3` read succeeded during this investigation — rather than working around the guard.

## Requirements

### REQ-001 — `bootstrap` performs a read-only MCP preflight probe

`plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` must instruct the agent to attempt a read-only MCP state probe near the start of the run, before the file-based flow reaches a conclusion, and to record what the probe reported.

The step must state that the probe is **read-only** and **advisory**: it informs the agent, it does not decide anything.

*Under-specified by the issue:* the exact tool set (OQ-001), the exact insertion point (OQ-002), the behaviour when the feature directory does not yet exist (OQ-003), and which modes and tracks the step applies to (OQ-004). AC-001 asserts only the properties that hold under every resolution of those questions.

#### AC-001

`bootstrap/SKILL.md` contains a preflight step that (a) names at least one registered `sdd-forge-mcp` tool by its exact identifier, (b) states the step is read-only, and (c) states the step is advisory / non-deciding.

All three elements are required. Verified by reading the file and asserting each element separately — not by asserting a section heading, which passes against an empty section, and not by asserting only (a), which would pass against a step that names a tool and then hands it authority.

**Insertion-point constraint that holds regardless of OQ-002.** `tests/workflow-documentation.tests.sh:65-68` extracts a `sed` range from `bootstrap/SKILL.md` bounded by the literal headings ``### `feature` … full track)`` and `### Lite track`, and asserts the extracted block names all three review loops (INV-013). The probe step must not be inserted inside that range unless the change is verified against that suite. This is a fact about an existing consumer, not a design preference.

### REQ-002 — `ship` performs the same read-only MCP preflight probe

`ship` must gain an equivalent step, subject to OQ-007.

`ship`'s zero-argument path currently reads `AGENTS.md` directly at `plugins/sdd-ship/skills/ship/SKILL.md:64` to discover active spec directories — which is exactly the flow `get_next_sdd_command` mirrors ("auto-selects the single active feature the same way sdd-ship:run does", `mcp/sdd-forge-mcp/src/server.ts:141`). The overlap is what makes ship the natural second site.

#### AC-002

Ship's probe step exists, carrying the same three elements AC-001 requires, **and** it was not produced by an agent write to the live protected path.

The second half is asserted, not assumed: `plugins/sdd-ship/skills/ship/SKILL.md` is protected (INV-010), so an agent-authored live edit is either impossible or evidence the guard was circumvented. Whichever artifact OQ-007 selects to carry the wording, this criterion's two halves are both verifiable.

*Blocked on OQ-007.* If OQ-007 resolves to descoping ship, this requirement and AC-002 are withdrawn rather than weakened — a partially-satisfied ship criterion would be worse than an absent one.

### REQ-003 — the probe instruction is runtime-agnostic

Per the addendum: the wording must describe "attempt the MCP tool call; on failure fall back to the file-based flow" without assuming any particular runtime's registration mechanism or configuration file.

Both mechanisms exist and genuinely differ (INV-002): Claude Code registers via `claude mcp add` (`install.sh:357`); Codex registers via a marker-delimited block in `~/.codex/config.toml` (`install.sh:377-378`). A skill that told the agent to inspect either one would be wrong on the other runtime.

**Expansion note — AC-004 through AC-007, expanded from the retired AC-003**

**AC-003 is intentionally retired and must not be reused.** The draft criterion that held that identifier read "the probe wording names no runtime-specific registration surface". That language quantifies over a set ("no … surface") and is expanded here into one criterion per surface, per AGENTS.md `## Rules` author-time sweep 4. A single criterion would have been satisfiable by a document that avoided one surface and named another. The identifier is left vacant rather than renumbered so that the expansion is visible to a reviewer and so no later AC silently inherits a number whose scope was different.

The four surfaces are those established by INV-002 and INV-007 as the registration mechanisms this repository actually uses:

#### AC-004
The probe wording in each skill does not instruct the agent to inspect or depend on `claude mcp` / the Claude Code MCP registration command.

#### AC-005
The probe wording in each skill does not instruct the agent to inspect or depend on `~/.codex/config.toml`.

#### AC-006
The probe wording in each skill does not instruct the agent to inspect or depend on the installer's marker block (`# >>> <name> (managed by sdd-forge installer …`).

#### AC-007
The probe wording in each skill does not instruct the agent to inspect or depend on a client configuration file by name (`mcp.json` for Cursor / VS Code, per `README.md:126`).

Each is asserted independently against **both** skills. A criterion satisfied in `bootstrap` and violated in `ship` is a failure of that criterion, not a partial pass.

### REQ-004 — the file-based flow is reachable when the probe is not

When the probe cannot be performed, each skill must continue through its existing file-based flow with no degradation and no error surfaced to the user as a failure. This is the issue's third acceptance criterion.

The issue's own language names two unavailability conditions — "MCP 不在" (absent) in the criterion, and "MCP ツール呼び出しを試行し、失敗したら" (the call was attempted and failed) in the addendum. These are distinct: the first never reaches a call, the second does.

**Expansion note — AC-008 through AC-011 — expanded from the fallback criterion's quantified language**

The original criterion read "MCP 不在フォールバックが機能" — a single statement covering two skills and two unavailability conditions. Expanded per AGENTS.md `## Rules` author-time sweep 4 into the four branches the issue's own wording commits to:

#### AC-008
`bootstrap` completes its normal file-based flow when no MCP server is registered (no call is attempted).

#### AC-009
`bootstrap` completes its normal file-based flow when the MCP tool call is attempted and fails.

#### AC-010
`ship` completes its normal file-based flow when no MCP server is registered.

#### AC-011
`ship` completes its normal file-based flow when the MCP tool call is attempted and fails.

**A third unavailability condition exists and is deliberately not given criteria here.** `sdd-forge-mcp` returns structured `Result<T>` error envelopes rather than throwing (`mcp/sdd-forge-mcp/src/envelope.ts`), so "the call succeeded but returned an error envelope" is neither of the two conditions above. Whether it takes the same fallback path is **OQ-010**, unresolved. It is named here so its absence is a recorded deferral rather than a coverage hole — an AC written against an undecided branch would be unverifiable, and a silent omission would be exactly the subset-coverage defect sweep 4 exists to prevent.

### REQ-005 — the probe cannot change the outcome

"MCP はワークフローを自動進行させない" is the issue's own constraint. It must be enforceable, not merely stated: the file-based flow's conclusion must be identical whether or not the probe ran and whatever it returned.

#### AC-012
`bootstrap` reaches the same conclusion with the probe available and with it absent, for an identical repository state.

#### AC-013
`ship` reaches the same conclusion with the probe available and with it absent, for an identical repository state.

Two criteria rather than one, because "each skill" quantifies over a set of two and a single criterion could be satisfied by testing whichever skill is easier (sweep 4).

**Divergence handling was OQ-005. It was answered by the human on 2026-08-04 and is now decided here.** AC-012 and AC-013 assert *outcome equality*, which holds under every candidate answer — display-only, log-only, or warn-on-divergence — because none of those changes the conclusion. What they could not assert, until this decision, was what the agent reports when the probe and the file-based flow disagree, because the issue does not say.

**Resolution: warn-on-divergence.** When the probe's view and the file-based conclusion disagree, the agent states the disagreement visibly to the operator, and proceeds on the file-based conclusion.

Two reasons, recorded so a later reader does not have to reconstruct the choice. First, a silent disagreement between two views of the same state is exactly the kind of thing that rots — the file-based flow stays authoritative either way, so the only question was whether the operator learns that the two disagreed, and there is no version of "they should not learn it" that survives being written down. Second, the warning costs nothing in safety: REQ-005 already requires the conclusion to be identical whether or not the probe ran, and AC-012/AC-013 test exactly that, so warning cannot change an outcome it is forbidden from changing.

#### AC-027a
When the probe returns a view of the SDD state that disagrees with the file-based conclusion, the agent's output states that a disagreement occurred, and names which source it acted on.

Asserted as two separate elements — that the disagreement is surfaced at all, and that the authoritative source is identified — because an output that mentions a disagreement without saying which view it followed leaves the operator unable to act on it. A single combined assertion could pass on the weaker half alone.

#### AC-027b
The conclusion the agent acts on in the divergent case is the file-based one.

This is REQ-005's own guarantee restated at the divergence branch specifically, so that the branch cannot be implemented as "warn, then follow the probe" — which would satisfy AC-027a while inverting the authority this requirement exists to protect.

Unlike REQ-002, this requirement was **never withdrawable**: outcome equality is required under every resolution. What was deferred was only the reporting criterion above, and per this requirement's own earlier instruction it lands in this specification rather than in `design.md`, so the reviewed artefact remains the one that states the behaviour.

**Consequence for provenance, stated plainly.** This resolution edits a document that had already passed spec-review, which invalidates that pass by design: the recorded contract binds the reviewed bytes. A fresh spec-review attempt is therefore required, and no part of the earlier pass is carried over.

### REQ-006 — no write capability is added to any MCP server

The issue's second acceptance criterion. This is a **preservation** obligation: it is satisfied today (INV-006 — fourteen registered tools, none write) and the work is to keep it true and write the policy down, not to make it true.

**Expansion note — AC-014 through AC-016 — expanded from "write 権限は追加しない"**

The original criterion quantifies over every MCP server this repository ships. Three exist (`mcp/sdd-forge-mcp`, `mcp/local-env-mcp`, `mcp/ci-mcp`), so it is expanded into one criterion per server per sweep 4. A single criterion could be satisfied by checking only the server the feature happens to touch.

#### AC-014
`sdd-forge-mcp` registers no tool that writes, mutates, or advances state. Asserted against the registered tool set, not against prose.

#### AC-015
`local-env-mcp` registers no such tool.

#### AC-016
`ci-mcp` registers no such tool, and issues no non-GET HTTP method.

### REQ-007 — the addendum's dual-runtime obligation is verified on both runtimes

"Claude Code / Codex 双方で probe→フォールバックが機能すること."

**Expansion note — AC-017 through AC-020 — expanded from "双方で probe→フォールバック"**

"双方" (both) quantifies over two runtimes, and "probe→フォールバック" names two paths. The product is four branches, expanded per sweep 4:

#### AC-017
Under Claude Code, the probe path executes when MCP is available.

#### AC-018
Under Claude Code, the fallback path executes when MCP is unavailable.

#### AC-019
Under Codex, the probe path executes when MCP is available.

#### AC-020
Under Codex, the fallback path executes when MCP is unavailable.

**Verification method is constrained by REQ-003 and is not free.** The skills' wording is runtime-agnostic by construction, so a text assertion cannot distinguish these four branches — it would pass all four against a single sentence, which is the definition of a test that cannot fail. These four therefore require either a runtime-level exercise or an explicitly recorded manual verification per runtime. Which, is **OQ-009**.

### REQ-008 — `USERGUIDE.md` states the advisory policy

`USERGUIDE.md` must carry the two claims that are currently absent (INV-008), without rewriting the five correct read-only sentences that already exist.

**Expansion note — AC-021 through AC-022 — expanded from "read-only 助言層 … write 系ツール追加を抑制する方針"**

The issue's Proposed change names two distinct claims in one sentence. Expanded per sweep 4:

#### AC-021
`USERGUIDE.md` states that MCP does not auto-advance the SDD workflow and is advisory to the agent.

#### AC-022
`USERGUIDE.md` states the standing policy that write tools are not to be added to these servers.

Both asserted with an accompanying substantive statement, not by literal marker alone — a document that contains the word `助言` in an unrelated sentence must not pass. This is the FP-02 text-marker failure recorded in the `epic-136-phase3` retrospective and reproduced in `epic-136-phase4-docs` AC-001.

### REQ-009 — `README.md` states the advisory policy

Same two claims, in `README.md`'s MCP section (`:108-142`).

#### AC-023
`README.md` states that MCP does not auto-advance the SDD workflow and is advisory.

#### AC-024
`README.md` states the standing no-write-tools policy.

**`README.md` is already inside an existing suite's coverage.** `tests/workflow-documentation.tests.sh:6-13` lists it in the `DOCS` array (INV-013), so any addition must keep that suite green.

### REQ-010 — the staged protected-file change is conformant

Applies only if OQ-007 resolves toward staging (option a).

#### AC-025
A candidate exists at `specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md` and its SHA-256 matches its `MANIFEST.sha256` entry, in the `<sha256>  <repo-relative-path>` form used by `specs/quality-loop-fixes/human-copy/MANIFEST.sha256`.

#### AC-026
The live `plugins/sdd-ship/skills/ship/SKILL.md` carries no agent-authored edit from this feature. Asserted without opening the live protected path for write, following `tests/quality-gate-cycle-limit.tests.sh:356-361`.

### REQ-011 — existing consumers stay green

#### AC-027
`tests/workflow-documentation.tests.sh` passes unmodified. Needing to edit it is evidence a documented structural assumption was broken (INV-013) and must be reported, not accommodated.

## Non-goals

- **Adding any write, approval, or state-mutating MCP tool.** This is the inverse of REQ-006 and is stated as a Non-goal so the boundary is explicit rather than inferred.
- **Rewriting the existing read-only prose.** `README.md:108,114,118,130` and `USERGUIDE.md:40,135,213,229` are correct (INV-007, INV-008). This feature adds two claims around them; it does not restate or restructure them.
- **Making the probe authoritative.** The probe never selects the feature, never advances a gate, and never substitutes for `check-sdd-structure.sh` or the file-based reads. REQ-005 is the enforceable form of this.
- **Changing any MCP server's implementation.** No file under `mcp/` is edited. This feature edits skills and documentation only.
- **Registering or configuring MCP servers.** Registration is the installer's job (`install.sh:357,377-378`) and REQ-003 forbids the skills from depending on it.
- **Generalising ADR-0006.** Whether the policy warrants an ADR is OQ-008; the issue names only two documents, and this specification does not enlarge that.
- **Adding the probe to `sdd-bootstrap-interviewer/SKILL.md`.** OQ-006. Named so its absence is a deferral, not an oversight.

## Edge Cases

1. **The feature directory does not exist yet.** In `bootstrap feature` mode the slug names a directory that has not been created. `get_task_state` requires a `feature` argument (`server.ts:89`) and would have nothing to read, while `get_next_sdd_command` accepts none (`server.ts:141`). OQ-003.
2. **`bootstrap adopt` runs against a repository with no `specs/` at all.** The probe has no state to report; whether it is skipped or reports "nothing" is OQ-004.
3. **The probe disagrees with the file-based flow.** `get_next_sdd_command` walks AGENTS.md's Required Workflow gates; ship's `:64` path reads the same file for a different purpose. They can disagree if either is stale. OQ-005 — and REQ-005 guarantees only that the *outcome* is unaffected, not that the disagreement is reported.
4. **The MCP server is registered but stale.** `sdd-forge-mcp` ships as a built `dist/index.js` bundle (`install.sh:355`). A registered-but-outdated bundle answers successfully with data from older parsing logic — indistinguishable from a healthy probe at the call boundary, and therefore *not* caught by any fallback branch in REQ-004.
5. **The probe is invoked in the lite track.** Lite skips all three review loops, so `get_next_sdd_command`'s gate walk describes a workflow lite does not run. OQ-004.
6. **A read-only shell command is denied by the guard.** Verified first-hand during investigation (INV-012): a `grep` that merely *mentions* a gate-script path is denied. Implementation and review agents must restructure the command, not work around the guard.
7. **`ship/SKILL.md` becomes unprotected, or another target becomes protected, before implementation.** The membership list is shared mutable state; see the re-verification instruction under *Protected Gate Files*.

## Assumptions

- **`sdd-forge-mcp`'s fourteen tools are all read-only.** Verified by reading every `server.registerTool(` declaration in `mcp/sdd-forge-mcp/src/server.ts:65-219` (INV-006), not inferred from the documentation that says so.
- **Both registration mechanisms are current.** `install.sh:357` and `:377-378` were read directly (INV-002). They are installer implementation and can change independently of this feature; REQ-003 is written so that a change to either does not invalidate the skills' wording.
- **Re-verify every `file:line` in this document at implementation start.** Citations accurate when written and stale when used are a recorded recurring defect class in this repository (WFI-011) — and issue #129's own `USERGUIDE.md:27` citation is a live instance of it (INV-003).

## Baseline Constraints

- **BL-001 — no MCP server implementation changes.** No file under `mcp/` is edited by this feature. REQ-006's criteria are assertions about the existing state, not about new code.
- **BL-002 — the existing file-based flows are preserved exactly.** `bootstrap`'s `## Preconditions` (`:54-64`) and `ship`'s `## Preconditions` (`:45-53`) plus `## Step 1` (`:55-75`) keep their current meaning and their current outcomes. The probe is added around them.
- **BL-003 — the existing read-only prose is preserved.** `README.md:108,114,118,130` and `USERGUIDE.md:40,135,213,229` are unchanged in meaning.
- **BL-004 — `plugins/sdd-ship/skills/ship/SKILL.md` is not written by an agent.** It is on `PROTECTED_GATE_SUFFIXES` (`guard_invariants.py:4`, INV-010). Any change to it is staged and human-applied, per the *Protected Gate Files* section. This constraint stands whatever OQ-007 resolves to — under option (b) it is satisfied vacuously.
- **BL-005 — `specs/mcp-readonly-preflight/` must be registered in `specs/workflow-state-registry.json`.** `check-workflow-state.sh:130-135` fails the repository-wide gate with `registry-unregistered-directory` for any unregistered `specs/` directory (INV-014). This is a mechanical consequence of creating the directory, not a design choice.
