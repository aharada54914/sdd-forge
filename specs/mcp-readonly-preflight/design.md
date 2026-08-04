# Design: mcp-readonly-preflight

Impl-Review-Status: Pending

## Architecture Overview

Two streams sharing one release, touching disjoint files.

**Stream A — the probe.** A read-only advisory step added near the start of `bootstrap` and `ship`. It is *instructional text in a skill*, not code: the skills are Markdown instruction documents, and the agent executing them is what issues the MCP call. There is no new script, no new binary, and no change to any MCP server. This matters for the whole design — the unit of change is a paragraph an agent reads, so its correctness properties are legibility and unambiguity, and the only mechanically assertable properties are what the text says and what the run does end to end.

The design's central constraint is that the probe must be **strictly subtractive in authority**: it may add information to the agent's context and may add nothing to the agent's decision procedure. `bootstrap`'s routing and `ship`'s target selection keep their existing file-based logic exactly (BL-002), and the probe is layered beside it, not in front of it. The enforceable form of this is AC-012 / AC-013 — outcome equality with and without the probe.

**Stream B — the policy statement.** Two claims appended to `USERGUIDE.md` and `README.md`: MCP is advisory and does not auto-advance the workflow; write tools are not to be added. Both documents already say "read-only" correctly in five places (INV-007, INV-008); this stream extends around them and rewrites none of them (BL-003).

**Why the two streams are not independently landable.** Stream B asserts a property of the system that Stream A's probe is the first live consumer of. Shipping B alone would document an advisory layer nothing uses; shipping A alone would add an MCP touchpoint with no written policy bounding it — which is the state issue #129 was filed to end. They can be implemented in either order and must merge together.

**This design is not yet complete, and the incompleteness is structural rather than a drafting gap.** Ten Open Questions (`investigation.md` OQ-001 … OQ-010) remain unresolved because issue #129 does not decide them. Three of them — OQ-001 (which tools), OQ-005 (what the agent does with the result) and OQ-007 (how ship's protected file is handled) — are load-bearing for the component design below, and the sections that depend on them say so at the point of dependence rather than papering over it with a plausible choice.

## Components

| Component | Status | Change |
|---|---|---|
| `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` | Existing (extended) | add the probe step. Insertion point is OQ-002; the one hard constraint is that it must not land inside the `sed` range `tests/workflow-documentation.tests.sh:65-68` extracts (INV-013) |
| `plugins/sdd-ship/skills/ship/SKILL.md` | **Existing, PROTECTED** | add the probe step near `## Preconditions` (`:45-53`) / before `## Step 1` (`:55`). **Cannot be written by an agent** (`guard_invariants.py:4`, INV-010) — staged human-copy candidate only, subject to OQ-007 |
| `USERGUIDE.md` | Existing (extended) | append the two policy claims in the `## MCP サーバー` region (`:38` onward); `:40`, `:135`, `:213`, `:229` unchanged (BL-003) |
| `README.md` | Existing (extended) | same two claims in the MCP region (`:108-142`); `:108`, `:114`, `:118`, `:130` unchanged (BL-003) |
| `specs/mcp-readonly-preflight/human-copy/` | **New** (conditional on OQ-007) | staged `plugins/sdd-ship/skills/ship/SKILL.md` candidate + `MANIFEST.sha256`, per the `specs/quality-loop-fixes/human-copy/` precedent (INV-011) |
| `specs/workflow-state-registry.json` | Existing (one entry appended) | mechanical registration of this spec directory; without it `check-workflow-state.sh:130-135` fails the repository-wide gate (INV-014, BL-005) |
| `mcp/sdd-forge-mcp/**` | **Untouched** | BL-001. AC-014 asserts existing state |
| `mcp/local-env-mcp/**` | **Untouched** | BL-001. AC-015 asserts existing state |
| `mcp/ci-mcp/**` | **Untouched** | BL-001. AC-016 asserts existing state |
| `install.sh` / `install.ps1` | **Untouched** | registration is the installer's concern and REQ-003 forbids the skills from depending on it |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md` | **Untouched, pending OQ-006** | has zero MCP references like the other two (INV-005); the issue does not name it |
| `tests/workflow-documentation.tests.sh` | **Untouched** | AC-027. Editing it to accommodate this change is a reportable event, not a fix |

## API & Contract Plan

### The probe is a client of an existing contract, and adds nothing to it

`contracts/sdd-forge-mcp-tools.v1.schema.json` already describes both named tools — `get_task_state` at `:100`, `get_next_sdd_command` at `:236`. **No contract change is required or permitted by this feature.** The probe consumes the v1 contract as-is.

The two tools' input shapes differ in a way the design must respect (INV-006):

| Tool | `server.ts` | `feature` argument | Consequence for the probe |
|---|---|---|---|
| `get_task_state` | `:89` | **required** (`FEATURE_ARG`) | cannot be called before a feature slug exists and its directory is populated |
| `get_next_sdd_command` | `:141` | **optional** (`FEATURE_ARG.optional()`) | callable with no argument; auto-selects the single active feature the same way `sdd-ship:run` does |

This asymmetry is why `bootstrap feature` mode — where the feature directory does not yet exist — cannot use the same probe call as `ship`. **That is OQ-003 and is not resolved here.** The design records the constraint the resolution must satisfy: whatever the answer, it must not require the probe to succeed, because REQ-004's fallback obligation already covers a probe that cannot run.

### The probe's tool set is undetermined

Issue #129 names `get_next_sdd_command`/`get_task_state` **等**. Fourteen tools are registered (`server.ts:65-219`). **OQ-001 is not resolved here.** The skills cannot be written until the set is fixed, because AC-001 requires the step name a tool by its exact identifier.

What the design *can* fix, because it follows from REQ-014 rather than from a product choice: whatever set is chosen, every member must be one of the fourteen currently registered tools. The probe may not motivate a new tool — a new tool would be new MCP surface, and REQ-014 plus ADR-0006's precedent (`:67-69`) point the other way.

### The instruction shape, and why it is runtime-agnostic by construction

REQ-003 forbids the skills from depending on any registration surface. The two surfaces genuinely differ (INV-002): `install.sh:357` uses `claude mcp add`; `install.sh:377-378` writes a marker-delimited block into `~/.codex/config.toml`.

The design consequence is that the instruction must be expressed as **attempt-and-degrade**, never as detect-then-branch:

- **Permitted shape**: "attempt `<tool>`; if it is unavailable or the call fails, continue with the file-based flow below."
- **Forbidden shape**: "check whether an MCP server is registered, then …" — because every way of checking is runtime-specific.

This is the same graceful-degradation shape the repository already uses in `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md:28,55` (manual fallback when a design source is unavailable) and `plugins/sdd-lite/skills/lite-spec/SKILL.md:66`. The pattern is established here, not invented for this feature.

**A consequence worth stating because it constrains testing.** Runtime-agnostic wording means one sentence serves both runtimes, so no text assertion can distinguish the four cells of AC-017 … AC-020. See Test Strategy.

### The policy statement's shape

Two claims per document, each needing an accompanying substantive statement rather than a keyword (AC-021 … AC-024):

1. **Advisory / no auto-advance.** MCP informs the agent; the agent's workflow decisions come from files and gates. Nothing MCP returns advances a gate, selects a task, or changes an approval.
2. **No write tools.** A standing policy, not a description of the present. `docs/adr/0006-ci-mcp-readonly-github-actions.md:36,67-69` already states this for `ci-mcp` including the supersede requirement for any future write need; the new text generalises the posture to all three servers.

**Whether generalising it warrants an ADR rather than prose is OQ-008 and is not resolved here.** The issue names only `USERGUIDE.md` and `README.md`. If OQ-008 resolves toward an ADR, the next free 4-digit number must be re-derived at drafting time — `docs/adr/` currently contains **duplicate numbers** (`0002`, `0003` and `0004` each appear twice), so the maximum existing number is not a safe proxy for the next free one, and the namespace is shared with concurrent branches (AGENTS.md `## Rules` author-time sweep 3).

## Data Plan

**No persistent data, no schema, no migration.**

The probe reads and discards. It writes no file, creates no cache, and leaves no artifact. Its result lives only in the agent's context for the duration of the run, which is what makes "read-only" true at the data layer and not merely at the tool layer.

`sdd-forge-mcp` reads the repository's own files (`specs/`, `AGENTS.md`, `reports/`) and returns structured `Result<T>` envelopes (`mcp/sdd-forge-mcp/src/envelope.ts`). No new data flows into the repository as a result of this feature.

The only durable state this feature adds anywhere is:

| Artifact | Kind | Why |
|---|---|---|
| a `specs/workflow-state-registry.json` entry | one JSON object, two keys | mechanical registration (BL-005) |
| `specs/mcp-readonly-preflight/human-copy/**` | staged file + manifest | only if OQ-007 resolves toward staging |

## Security Boundaries

Detailed treatment is in `security-spec.md`. The design-level summary:

- **The probe crosses no new trust boundary.** `sdd-forge-mcp` is already registered by the installer and already runs as a stdio child process; this feature adds a *caller*, not a *server*, and not a new privilege.
- **The probe must not be able to escalate.** The strongest structural guarantee available is that the probe has no write tool to call — all fourteen registered tools are read-only (INV-006), preserved by REQ-014. A design in which the probe merely *promised* not to write would be weaker by a category.
- **The protected-file boundary is respected, not routed around.** `ship/SKILL.md` is on `PROTECTED_GATE_SUFFIXES` (`guard_invariants.py:4`). The design's answer is the staging pattern (INV-011), never an attempt to write the live path. `ship/SKILL.md:314,317-318` — the skill's own Security Boundaries section — instructs agents never to modify gate scripts or hook files, so a feature that edited this very file by agent write would contradict the document it is editing.
- **New failure mode introduced by this feature, and where it is retired.** An agent that treats a probe result as authoritative could select a different feature or skip a gate. That is a real risk created by adding the probe, and it is closed by AC-012 / AC-013 asserting outcome equality — not by the instruction text asking nicely.

## Design Decisions (Resolving Open Questions)

**Three decisions are resolved here, each from repository evidence rather than from preference. Seven are escalated to the human, because issue #129 does not make them and a specification that invented them would be recording a choice as though it were a requirement.**

### Resolved

**D-001 — the probe is attempt-and-degrade, never detect-then-branch.** Forced by REQ-003 plus INV-002: both registration surfaces exist and differ, so any detection step is runtime-specific and violates the addendum. This is a derivation, not a preference.

**D-002 — no MCP server implementation changes, and no new tool.** Forced by REQ-014 and ADR-0006's precedent (`:67-69`), which requires a supersede for any write-direction expansion. The probe uses the existing fourteen tools or it does not ship.

**D-003 — `ship/SKILL.md` is never written by an agent.** Forced by `PROTECTED_GATE_SUFFIXES` membership (`guard_invariants.py:4`, INV-010), which is a mechanical fact about the guard, not a judgement. Note this resolves the *method* (staging, if ship is in scope at all); it does not resolve *whether* ship stays in scope, which is OQ-007.

### Escalated — human decision required before implementation

| OQ | Question | Why this design does not decide it | Repository-derived constraint the answer must satisfy |
|---|---|---|---|
| OQ-001 | Which tools constitute the probe? | The issue writes "等"; fourteen tools qualify | Every member must already be registered (`server.ts:65-219`); the probe may not motivate a new tool (D-002) |
| OQ-002 | Where in each skill does the step go? | Three materially different placements; only one has `check-sdd-structure.sh` already run | Must not land inside `tests/workflow-documentation.tests.sh:65-68`'s `sed` range (INV-013) |
| OQ-003 | What happens when there is no feature to probe? | `get_task_state` requires `feature`; `get_next_sdd_command` does not (INV-006) | The answer must not require the probe to succeed — REQ-004 already covers a probe that cannot run |
| OQ-004 | Which modes and which track? | Six bootstrap modes, two tracks; the issue scopes neither | `adopt` may run with no `specs/` at all; lite runs none of the gates `get_next_sdd_command` walks |
| OQ-005 | What are the consumption semantics, and what happens on divergence? | **The load-bearing one.** "Advisory" constrains authority, not behaviour | Whatever it is, outcome equality (AC-012/AC-013) must hold |
| OQ-006 | Does the interviewer skill also get the step? | Issue names only `bootstrap/SKILL.md`; the interviewer has zero MCP references too (INV-005) | If added, all of REQ-003's criteria apply to it identically |
| OQ-007 | How is ship's protected status handled — stage, descope, or relocate? | Changes what "1 issue = 1 commit" means for #129 | Under (a) the human-copy precedent (INV-011) applies verbatim; under (b) REQ-002 and AC-002 are withdrawn, not weakened |
| OQ-008 | Prose, or an ADR generalising ADR-0006? | Issue names only two documents | If ADR: re-derive the next free number; `docs/adr/` has duplicate `0002`/`0003`/`0004` |
| OQ-009 | Is there a test obligation, and in which suite? | Issue states none | AC-017 … AC-020 cannot be met by a text assertion (see Test Strategy) |
| OQ-010 | Is an error envelope a third fallback condition? | `Result<T>` envelopes mean a call can succeed and still report failure | If yes, AC-008 … AC-011 expand from four branches to six |

**OQ-005 is the one that should block.** The others narrow an implementation; OQ-005 determines whether there is a specifiable behaviour at all. An "advisory layer" whose divergence handling is undefined has no observable contract beyond "does not change the outcome" — which AC-012/AC-013 already assert without any probe existing.

## Test Strategy

### Coverage table — every AC, every TEST

| AC | TEST | Type | Method determined? |
|---|---|---|---|
| AC-001 | TEST-001 | integration (file read) | yes |
| AC-002 | TEST-002, TEST-003 | integration (file read; guard/provenance) | conditional on OQ-007 |
| AC-003 | — | — | **intentionally vacant** (retired in the sweep-4 expansion) |
| AC-004 | TEST-004 | unit (literal absence, both skills) | yes |
| AC-005 | TEST-005 | unit (literal absence, both skills) | yes |
| AC-006 | TEST-006 | unit (literal absence, both skills) | yes |
| AC-007 | TEST-007 | unit (literal absence, both skills) | yes |
| AC-008 | TEST-008 | integration (bootstrap, no MCP) | yes |
| AC-009 | TEST-009 | integration (bootstrap, call fails) | yes |
| AC-010 | TEST-010 | integration (ship, no MCP) | yes |
| AC-011 | TEST-011 | integration (ship, call fails) | yes |
| AC-012 | TEST-012 | integration (differential) | yes |
| AC-013 | TEST-013 | integration (differential) | yes |
| AC-014 | TEST-014 | unit (tool registry) | yes |
| AC-015 | TEST-015 | unit (tool registry) | yes |
| AC-016 | TEST-016 | unit (tool registry + HTTP method) | yes |
| AC-017 | TEST-017 | runtime exercise (Claude Code, probe) | **no — OQ-009** |
| AC-018 | TEST-018 | runtime exercise (Claude Code, fallback) | **no — OQ-009** |
| AC-019 | TEST-019 | runtime exercise (Codex, probe) | **no — OQ-009** |
| AC-020 | TEST-020 | runtime exercise (Codex, fallback) | **no — OQ-009** |
| AC-021 | TEST-021 | integration (file read) | yes |
| AC-022 | TEST-022 | integration (file read) | yes |
| AC-023 | TEST-023 | integration (file read) | yes |
| AC-024 | TEST-024 | integration (file read) | yes |
| AC-025 | TEST-025 | integration (hash conformance) | conditional on OQ-007 |
| AC-026 | TEST-026 | integration (hash conformance) | conditional on OQ-007 |
| AC-027 | TEST-027 | regression | yes |

Twenty-six live ACs, twenty-seven TEST rows, no AC without a row and no row without an AC.

### Three properties of this strategy that are deliberate

**1. Absence assertions are never load-bearing alone.** TEST-004 … TEST-007 assert that runtime-specific surfaces are *not* named. Such a test also passes when the probe wording is missing entirely. They are therefore valid only conjoined with TEST-001/TEST-002; a run where TEST-001 fails must report TEST-004 … TEST-007 as inconclusive, not as passes.

**2. The write-tool assertions target the registry, never the prose.** TEST-014 … TEST-016 read `server.registerTool(` declarations. Asserting the documentation instead would make them pass whenever TEST-021 … TEST-024 pass — decorative rather than protective, and precisely the documentation-versus-behaviour drift #129 exists to prevent.

**3. Four rows have a real obligation and an undetermined method, and are not disguised.** AC-017 … AC-020 cover the addendum's dual-runtime requirement. Because REQ-003 makes the wording runtime-agnostic, *one sentence satisfies all four cells* — so a text-based check would pass unconditionally. That is a test that cannot fail, the exact defect `epic-136-phase4-docs` round 3 caught and removed. Rather than write one, this design records the method as open (OQ-009). Downgrading these four to a text check to make the matrix look complete would be the worse outcome.

## Deployment & CI Plan

**No new CI step, and no CI file is edited.** `.github/workflows/test.yml` is on `PROTECTED_GATE_SUFFIXES` (`guard_invariants.py:4`) and is untouched.

1. `tests/workflow-documentation.tests.sh` already covers `README.md` (`:6-13`) and asserts structure in `bootstrap/SKILL.md` (`:65-68`). It is already registered and runs unchanged; AC-027 requires it stay green **without being edited**.
2. Whether this feature adds a suite of its own is OQ-009. If it does, it must self-register in `tests/run-all.sh` following the convention `tests/quality-gate-cycle-limit.tests.sh` demonstrates (`QGCL-016`).
3. No `dist/` rebuild applies. No file under `mcp/` changes (BL-001), so ADR-0003's same-commit rebuild obligation does not attach.
4. No package manifest or lockfile is touched; no `npm audit` interaction.

**The human-copy leg, if OQ-007 resolves toward staging.** The staged-candidate half (TEST-025) passes as soon as the candidate and manifest are committed. The live half (TEST-026) is **expected red until the human applies the patch in a separate commit** — the correct pre-human-copy state, matching the expectation `tests/quality-gate-cycle-limit.tests.sh:390-392` records for its own protected leg. Task decomposition must say so, or a correct red will be misread as a blocker.

**Registration is a merge-blocking prerequisite, not a follow-up.** `check-workflow-state.sh:130-135` fails the repository-wide gate for any unregistered `specs/` directory (INV-014). The entry must exist in the same change as the directory.

## Global Constraints

- **BL-001** — no file under `mcp/` is edited.
- **BL-002** — `bootstrap`'s `## Preconditions` (`:54-64`) and `ship`'s `## Preconditions` (`:45-53`) plus `## Step 1` (`:55-75`) keep their current meaning and outcomes.
- **BL-003** — `README.md:108,114,118,130` and `USERGUIDE.md:40,135,213,229` are unchanged in meaning.
- **BL-004** — `plugins/sdd-ship/skills/ship/SKILL.md` is never written by an agent.
- **BL-005** — `specs/mcp-readonly-preflight/` is registered in `specs/workflow-state-registry.json`.
- **Guard-command hazard** — a read-only shell command that merely mentions a gate-script path can be denied (INV-012, confirmed first-hand). Restructure; do not work around.
- **Citation freshness** — re-verify every `file:line` at implementation start (WFI-011). Issue #129's own `USERGUIDE.md:27` is a live instance of a stale citation (INV-003).

## Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-1 | **Implementation starts before OQ-005 is answered**, and an implementer picks divergence semantics by default | high | high — a design decision enters the codebase without ever being decided | OQ-005 is flagged as the blocking question in Design Decisions; task decomposition must not schedule the probe step before it resolves |
| R-2 | AC-017 … AC-020 are quietly satisfied with a text assertion to make the matrix green | medium | high — four criteria become tests that cannot fail | Named explicitly in Test Strategy point 3 and in the coverage table's "method determined?" column |
| R-3 | An agent attempts to write the live `ship/SKILL.md` | medium | medium — guard denial, wasted cycle, possible misdiagnosis as a tooling bug | BL-004, D-003, and the `Protected Gate Files` section of `requirements.md`; the guard blocks it regardless |
| R-4 | The probe step is inserted inside the `sed` range at `tests/workflow-documentation.tests.sh:65-68` | medium | low — caught by AC-027, but presents as an unrelated suite failure | Constraint stated in AC-001 and in the OQ-002 row |
| R-5 | `PROTECTED_GATE_SUFFIXES` membership changes on another branch before this lands | low | high — the whole task decomposition rests on the current table | Re-verification instruction in `requirements.md` §Protected Gate Files, executed at spec-review |
| R-6 | The policy prose is added by *replacing* the existing read-only sentences rather than extending them | medium | medium — five correct sentences regress while the new ACs still pass | BL-003, and TEST-021 … TEST-024 confirm the existing prose survived |
| R-7 | A registered-but-stale MCP bundle answers successfully with outdated parsing logic | low | medium — a healthy-looking probe returns wrong advice; **not caught by any fallback branch** | Bounded by AC-012/AC-013: wrong advice cannot change the outcome. Recorded as a residual risk, not a closed one |
| R-8 | The spec directory is created without the registry entry | medium | high — repository-wide gate red for every concurrent agent | BL-005; entry must land in the same change |
