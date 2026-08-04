# Acceptance Tests: mcp-readonly-preflight

Every acceptance criterion in `requirements.md` has at least one TEST row here, and every AC whose parent language enumerated branches or quantified over conditions was expanded into per-branch criteria before this matrix was written, per AGENTS.md `## Rules` author-time sweep 4. The expansions are recorded under *Expansion Ledger* below so a reviewer can check the arithmetic rather than trust it.

**AC-003 is intentionally vacant** (retired during the sweep-4 expansion; see `requirements.md` REQ-003). No TEST row references it.

## Test Matrix

| Test ID | AC | Test Type | Target | Assertion in one line |
|---|---|---|---|---|
| TEST-001 | AC-001 | integration (real file read) | `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` | probe step present with all three elements: a named tool identifier, "read-only", and an advisory/non-deciding statement |
| TEST-002 | AC-002 | integration (real file read) | ship's probe-carrying artifact | same three elements present |
| TEST-003 | AC-002 | integration (guard/provenance) | live `plugins/sdd-ship/skills/ship/SKILL.md` | the live protected file carries no agent-authored edit from this feature |
| TEST-004 | AC-004 | unit (literal-absence, both skills) | both skills | probe wording does not instruct inspecting `claude mcp` |
| TEST-005 | AC-005 | unit (literal-absence, both skills) | both skills | probe wording does not instruct inspecting `~/.codex/config.toml` |
| TEST-006 | AC-006 | unit (literal-absence, both skills) | both skills | probe wording does not instruct inspecting the installer marker block |
| TEST-007 | AC-007 | unit (literal-absence, both skills) | both skills | probe wording does not instruct inspecting a client config file by name (`mcp.json`) |
| TEST-008 | AC-008 | integration (no MCP registered) | `bootstrap` | file-based flow completes; no error surfaced as failure |
| TEST-009 | AC-009 | integration (registered, call fails) | `bootstrap` | file-based flow completes; no error surfaced as failure |
| TEST-010 | AC-010 | integration (no MCP registered) | `ship` | file-based flow completes; no error surfaced as failure |
| TEST-011 | AC-011 | integration (registered, call fails) | `ship` | file-based flow completes; no error surfaced as failure |
| TEST-012 | AC-012 | integration (differential) | `bootstrap` | conclusion with probe available == conclusion with probe absent, same repo state |
| TEST-013 | AC-013 | integration (differential) | `ship` | conclusion with probe available == conclusion with probe absent, same repo state |
| TEST-014 | AC-014 | unit (static, tool registry) | `mcp/sdd-forge-mcp/src/server.ts` | every registered tool is read-only; no write/mutate/advance tool |
| TEST-015 | AC-015 | unit (static, tool registry) | `mcp/local-env-mcp` | same |
| TEST-016 | AC-016 | unit (static, tool registry + HTTP method) | `mcp/ci-mcp` | same, and no non-GET HTTP method is issued |
| TEST-017 | AC-017 | runtime exercise (Claude Code) | both skills | probe path executes when MCP is available |
| TEST-018 | AC-018 | runtime exercise (Claude Code) | both skills | fallback path executes when MCP is unavailable |
| TEST-019 | AC-019 | runtime exercise (Codex) | both skills | probe path executes when MCP is available |
| TEST-020 | AC-020 | runtime exercise (Codex) | both skills | fallback path executes when MCP is unavailable |
| TEST-021 | AC-021 | integration (real file read) | `USERGUIDE.md` | states MCP does not auto-advance the workflow and is advisory, with substance |
| TEST-022 | AC-022 | integration (real file read) | `USERGUIDE.md` | states the standing no-write-tools policy, with substance |
| TEST-023 | AC-023 | integration (real file read) | `README.md` | states MCP does not auto-advance the workflow and is advisory, with substance |
| TEST-024 | AC-024 | integration (real file read) | `README.md` | states the standing no-write-tools policy, with substance |
| TEST-025 | AC-025 | integration (hash conformance) | `specs/mcp-readonly-preflight/human-copy/` | staged candidate SHA-256 matches its `MANIFEST.sha256` entry |
| TEST-026 | AC-026 | integration (hash conformance) | live ship SKILL.md | live protected file unmodified by an agent, asserted without opening it for write |
| TEST-027 | AC-027 | regression | `tests/workflow-documentation.tests.sh` | the existing suite passes unmodified |

## Expansion Ledger

Every AC in `requirements.md` that came from enumerating or quantified issue language, with the branch count and the resulting TEST rows. Sweep 4 requires the expansion be done *before* spec-review, not left for `EDGE-CASE-COVERAGE` to catch.

| Source language (issue #129) | Quantifier | Branches | ACs | TESTs |
|---|---|---|---|---|
| "the probe wording names no runtime-specific registration surface" (retired AC-003) | "no … surface" over a set of 4 | 4 registration surfaces | AC-004…AC-007 | TEST-004…TEST-007 |
| "MCP 不在フォールバックが機能" | implicit over skills × unavailability conditions | 2 skills × 2 issue-named conditions = 4 | AC-008…AC-011 | TEST-008…TEST-011 |
| "MCP はワークフローを自動進行させない" | "each skill" | 2 skills | AC-012, AC-013 | TEST-012, TEST-013 |
| "write 権限は追加しない" | over every MCP server | 3 servers | AC-014…AC-016 | TEST-014…TEST-016 |
| "Claude Code / Codex **双方**で probe→フォールバックが機能" | "双方" × two named paths | 2 runtimes × 2 paths = 4 | AC-017…AC-020 | TEST-017…TEST-020 |
| "read-only 助言層 … write 系ツール追加を抑制する方針" | two distinct claims × two documents | 2 claims × 2 docs = 4 | AC-021…AC-024 | TEST-021…TEST-024 |

**One branch is deliberately excluded and named rather than dropped.** The fallback expansion covers the two unavailability conditions issue #129 itself names — "MCP 不在" (never reaches a call) and "呼び出しを試行し、失敗した" (call attempted, failed). A third exists: `sdd-forge-mcp` returns structured `Result<T>` error envelopes rather than throwing (`mcp/sdd-forge-mcp/src/envelope.ts`), so a call can succeed at the transport level and still report failure. Whether it takes the same fallback path is **OQ-010**, unresolved by the issue. It has no AC and no TEST row *by decision*, recorded here so the coverage gap is a stated deferral rather than an oversight. An AC written against an undecided branch would be unverifiable.

## Test Details

### TEST-001 / TEST-002 (AC-001, AC-002) — the probe step is substantive, not a heading

Read the file and assert **three separate elements**, all required:

1. at least one registered `sdd-forge-mcp` tool named by its exact identifier (the registered set is enumerated at `mcp/sdd-forge-mcp/src/server.ts:65-219`);
2. an explicit "read-only" characterisation of the step; and
3. an explicit statement that the step is advisory and does not decide.

Deliberately **not** a section-heading check — a heading assertion passes against an empty section. Deliberately **not** element (1) alone either: a step that names `get_next_sdd_command` and then treats its answer as authoritative would satisfy a tool-name check while violating the requirement the step exists to encode. This is the FP-02 text-marker failure recorded in the `epic-136-phase3` retrospective, and `epic-136-phase4-docs` AC-001 reproduced it one level down; asserting all three elements is what avoids it here.

TEST-002 targets whichever artifact **OQ-007** selects to carry ship's wording. It is written against the artifact's content, not against a fixed path, so it survives every resolution of that question except descoping — under which REQ-002 and this test are withdrawn together.

### TEST-003 (AC-002) — ship's live protected file was not agent-written

`plugins/sdd-ship/skills/ship/SKILL.md` is on `PROTECTED_GATE_SUFFIXES` (`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`). Assert that this feature's change set contains no agent-authored edit to the live path.

This is a distinct assertion from TEST-002, not a restatement: TEST-002 proves the wording exists somewhere, TEST-003 proves it did not arrive by a route the guard should have blocked. A feature could pass TEST-002 and fail TEST-003, and that combination is precisely the failure worth catching.

Follows `tests/quality-gate-cycle-limit.tests.sh:356-361`, which states its equivalent check "never opens the live protected path for write".

### TEST-004 – TEST-007 (AC-004 … AC-007) — one surface per test, both skills per test

Each test asserts the absence of an *instruction to depend on* one registration surface, in **both** skills:

| Test | Surface | Established by |
|---|---|---|
| TEST-004 | `claude mcp` registration command | `install.sh:357` |
| TEST-005 | `~/.codex/config.toml` | `install.sh:377-378` |
| TEST-006 | the installer's marker block (`# >>> <name> (managed by sdd-forge installer …`) | `install.sh:377-378` |
| TEST-007 | a client config file by name (`mcp.json`) | `README.md:126` |

**These are absence assertions, and absence assertions are weak by nature — stated so the weakness is visible.** A literal-absence check cannot distinguish "the wording is properly runtime-agnostic" from "the wording is missing entirely". Each of TEST-004 … TEST-007 is therefore valid only in conjunction with TEST-001/TEST-002, which establish the wording exists. A run in which TEST-001 fails must treat TEST-004 … TEST-007 as inconclusive rather than as passes.

Asserting per-skill rather than over the concatenation matters: a criterion satisfied in `bootstrap` and violated in `ship` is a failure, and concatenating the two files before searching would still catch that, but reporting would not say which file. Report per skill.

### TEST-008 – TEST-011 (AC-008 … AC-011) — fallback, per skill per condition

Four independent cases; the 2×2 grid is the point.

| | no MCP registered | registered, call fails |
|---|---|---|
| `bootstrap` | TEST-008 | TEST-009 |
| `ship` | TEST-010 | TEST-011 |

In each, assert the skill reaches its normal file-based conclusion — `bootstrap` proceeds through `## Preconditions` (`bootstrap/SKILL.md:54-64`) into `## Routing` (`:66`); `ship` proceeds through `## Preconditions` (`ship/SKILL.md:45-53`) into `## Step 1 — Target Selection` (`:55`) — and that no probe failure is surfaced to the user as a run failure.

The two columns are genuinely different code paths: the left never issues a call, the right issues one and handles its rejection. Collapsing them would leave the attempted-and-failed path — the one the addendum's own wording describes — untested.

### TEST-012 / TEST-013 (AC-012, AC-013) — outcome equality, not behaviour equality

Run each skill twice against an **identical** repository state, once with the probe available and once without, and assert the conclusion is the same: for `bootstrap`, the mode/track routing decision; for `ship`, the selected `specs/<feature>/tasks.md`.

This is the enforceable form of "MCP はワークフローを自動進行させない". A probe that shifted the selection would fail here even if every other test passed.

**What these tests deliberately do not assert.** They say nothing about what the agent *reports* when the probe and the file-based flow disagree — that is **OQ-005**, and the issue does not decide it. Outcome equality holds under every candidate answer (display-only, log-only, warn-on-divergence), which is exactly why it is the assertable part. Inventing a divergence-reporting assertion here would smuggle a design decision into a test.

### TEST-014 – TEST-016 (AC-014 … AC-016) — the preservation obligation, one server per test

These assert a property that is **already true** (`investigation.md` INV-006: fourteen registered tools, none write), so their job is regression protection, not construction.

Assert against the tool registry itself — `server.registerTool(` declarations for `sdd-forge-mcp` (`mcp/sdd-forge-mcp/src/server.ts:65-219`) and the equivalent for the other two — **not** against the prose in `README.md` / `USERGUIDE.md`. Asserting the documentation would make TEST-014 … TEST-016 pass whenever TEST-021 … TEST-024 pass, which would make them decorative: the whole point of #129's second criterion is that a prose claim and an implementation can drift apart.

TEST-016 additionally asserts no non-GET HTTP method is issued, matching the control ADR-0006 already commits `ci-mcp` to (`docs/adr/0006-ci-mcp-readonly-github-actions.md:36`).

### TEST-017 – TEST-020 (AC-017 … AC-020) — the dual-runtime grid

| | probe path (MCP available) | fallback path (MCP unavailable) |
|---|---|---|
| Claude Code | TEST-017 | TEST-018 |
| Codex | TEST-019 | TEST-020 |

**These four cannot be satisfied by a text assertion, and saying so is load-bearest here.** REQ-003 requires the skills' wording be runtime-agnostic, so by construction the same sentence serves all four cells. A test that read the wording would pass all four against one sentence — a test that cannot fail, which is the defect `epic-136-phase4-docs` round 3 caught when it invented a PowerShell sub-case with no failing mode.

So each of these requires either a runtime-level exercise or an explicitly recorded manual verification naming the runtime and the observed path. **Which, is OQ-009** — the issue states no test obligation at all. Until OQ-009 resolves, these four rows name a real obligation with an undetermined method; they must not be quietly downgraded to a text check to make the matrix look complete.

### TEST-021 – TEST-024 (AC-021 … AC-024) — two claims × two documents, with substance

Per document, two independent assertions:

1. MCP does not auto-advance the SDD workflow / is advisory to the agent;
2. write tools are not to be added to these servers.

Each asserted **with an accompanying substantive statement**, not by literal marker alone. A document containing the word `助言` in an unrelated sentence must not pass. `USERGUIDE.md:99` already uses `助言的` in the `evidence_deep_verify` description, which makes a bare keyword check a live false positive in this exact file rather than a hypothetical one — verified during investigation, not assumed.

**These tests must also confirm the existing prose survived.** `README.md:108,114,118,130` and `USERGUIDE.md:40,135,213,229` already state read-only correctly (INV-007, INV-008) and BL-003 preserves them. A change that replaced rather than extended them would satisfy the two new assertions while regressing five correct sentences.

`README.md` is already inside `tests/workflow-documentation.tests.sh`'s `DOCS` array (`:6-13`), so it carries pre-existing coverage that TEST-027 protects.

### TEST-025 / TEST-026 (AC-025, AC-026) — staged candidate conformance

Applies only if **OQ-007** resolves toward staging.

TEST-025: compute the SHA-256 of `specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md` and assert a matching `<sha256>  plugins/sdd-ship/skills/ship/SKILL.md` line exists in `specs/mcp-readonly-preflight/human-copy/MANIFEST.sha256`, in the two-space-separated form used by `specs/quality-loop-fixes/human-copy/MANIFEST.sha256`.

TEST-026: assert the live protected file's state without opening it for write.

Modelled directly on `tests/quality-gate-cycle-limit.tests.sh:363-378` (case `QGCL-015`), which does exactly this for the same protected path in a different feature.

**Expect the live half to be red before the human-copy commit lands.** That is the correct pre-human-copy state, not a suite defect — `tests/quality-gate-cycle-limit.tests.sh:390-392` records the same expectation for its own `.github/workflows/test.yml` half. Any task decomposition must state this so a red result is not misread as a blocker.

### TEST-027 (AC-027) — the existing documentation suite is unmodified

`tests/workflow-documentation.tests.sh` passes **without being edited**. Needing to edit it is evidence that a documented structural assumption was broken — most likely the `sed` range at `:65-68` bounded by ``### `feature` … full track)`` and `### Lite track` (INV-013) — and must be reported, not accommodated by adjusting the suite to fit the change.

## Notes

- **Test types follow the repository's convention**: a case that drives a real process or a real skill run is *integration* even when it exercises one file; a case that reads a source file or a static registry is *unit*. The `epic-136-phase4-mcp` gate recorded a Minor for exactly this mislabelling, so the tier is stated deliberately per row.
- **TEST-017 … TEST-020 have no determined method.** This is the single largest open item in this matrix and it traces to OQ-009. It is recorded as an open method rather than filled with a text assertion that would pass unconditionally.
- **Every `file:line` in this document must be re-verified at implementation start.** Citations accurate when written and stale when used are a recorded recurring defect class here (WFI-011) — and issue #129's own `USERGUIDE.md:27` is a live instance (INV-003).
- **Reading gate-adjacent paths may be denied even for read-only commands** (INV-012). Restructure rather than work around.
