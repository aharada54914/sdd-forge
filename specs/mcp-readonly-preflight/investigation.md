# Investigation: mcp-readonly-preflight

| Field | Value |
|-------|-------|
| Feature | mcp-readonly-preflight (read-only MCP preflight probe in bootstrap/ship + read-only policy statement) |
| Mode | feature |
| Date | 2026-08-04 |
| Investigator | orchestrating session (direct read-only verification, no delegated investigator) |

Source: GitHub issue [#129](https://github.com/aharada54914/sdd-forge/issues/129) (`enhancement`, `workflow-improvement`; Key `ENH-22`, Finding A-4, Plan Phase 4), including its **2026-07-10 runtime addendum**. Investigated against branch `docs/wfi-021-gate-masking` @ working tree, worktree `sdd-forge-wt-phase4`.

Every `file:line` below was read directly during this investigation. Two of the issue's own citations were checked rather than trusted; one is accurate and one is stale (INV-002, INV-003).

## Scope

Issue #129 asks for two things that are related but separable:

1. **A read-only MCP preflight probe.** `bootstrap` and `ship` should, at their start, consult MCP state tools (`get_next_sdd_command` / `get_task_state` 等) as a *read-only advisory probe*, falling back to the existing file-based flow when MCP is unavailable.
2. **A written read-only policy.** `USERGUIDE.md` and `README.md` should state that MCP is a read-only advisory layer that does not auto-advance the workflow, and should record a standing policy against adding write tools.

The addendum adds a runtime-independence constraint: the probe wording must not assume a particular runtime's MCP registration mechanism, and probe→fallback must work under both Claude Code and Codex.

## Summary

**The probe half of the issue is a genuine create, not a gap-fill.** Neither target skill mentions MCP anywhere — `bootstrap/SKILL.md` and `ship/SKILL.md` each contain **zero** case-insensitive matches for `mcp` (INV-004, INV-005). The tools the issue names both exist and are registered (INV-006). So there is nothing to extend; the step does not exist in any form.

**The policy half is a partial gap-fill, and the issue's framing overstates what is missing.** `README.md` and `USERGUIDE.md` already describe all three MCP servers as **read-only** with no write API, in five separate places (INV-007, INV-008). What is genuinely absent is the *workflow* claim the issue actually wants: that MCP does not auto-advance the workflow, and a forward-looking policy against adding write tools. A near-precedent exists but is scoped to one server only — ADR-0006 forbids write tools for `ci-mcp` and says a future write need must go to a separate component rather than an extension (INV-009). Nothing generalises that to `sdd-forge-mcp` or `local-env-mcp`.

**One of this feature's four named target files is guard-protected**, which the issue does not mention: `plugins/sdd-ship/skills/ship/SKILL.md` is a member of `PROTECTED_GATE_SUFFIXES` (INV-010). An agent cannot write it. The repository has an established human-copy staging pattern for exactly this file (INV-011), so the obstacle is solved but it changes how the work must be planned.

**The issue's own `USERGUIDE.md:27` citation is stale** (INV-003) — the same class of defect `epic-136-phase4-docs` recorded when #134's title said "create" for a document that already existed at 164 lines.

## Findings

### Stream A — the probe (issue AC 1 and AC 3, addendum AC)

#### INV-001: `ship/SKILL.md:64` — the issue's first citation is accurate

`plugins/sdd-ship/skills/ship/SKILL.md:64`

```
1. Read `AGENTS.md` at the repository root. Look for an `## Active Spec Directories`
```

This is the zero-argument target-selection path (`## Step 1 — Target Selection` at `:55`, `### Zero-argument (no path given)` at `:62`). The issue's claim that ship proceeds by direct file reading holds exactly as stated, at exactly the line stated.

#### INV-002: the MCP-registration surfaces the addendum names both exist

- Claude Code: `install.sh:357` — `run_plugin_command claude mcp add "$name" --scope user -- node "$entry_point"`.
- Codex: `install.sh:377-378` — a per-MCP marker pair written into `~/.codex/config.toml`:

```sh
local marker_begin="# >>> ${name} (managed by sdd-forge installer; do not edit by hand) >>>"
local marker_end="# <<< ${name} <<<"
```

The addendum's premise — that registration differs by runtime — is confirmed against the installer, not assumed.

#### INV-003: `USERGUIDE.md:27` — the issue's second citation is **stale**

The issue cites `USERGUIDE.md:27` for "read-only 明記". That line does not say anything about read-only:

`USERGUIDE.md:27`

```
`welded`(effort を tier に溶接した従来挙動)は、`--effort-policy welded`
```

It belongs to the `## エージェントモデルルーティング — Effort Policy` section. The actual read-only statements are at **`USERGUIDE.md:40`** (`sdd-forge-mcp`), **`:135`** (`local-env-mcp`) and **`:213`** (`ci-mcp`).

Recorded as a finding rather than silently corrected, because a specification that repeats `:27` would be citing a line that does not support the claim. Downstream documents must cite `:40` / `:135` / `:213`.

#### INV-004: `bootstrap/SKILL.md` contains no MCP reference at all

`plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` is 160 lines. A case-insensitive search for `mcp` returns **zero** matches (grep exit status 1).

Its structure, for placement purposes: `## Invocation` `:14`, `## Preconditions` `:54`, `## Routing` `:66`, `## Context Compaction` `:134`, `## Handoff` `:152`. The existing preflight is file-based and lives at `:54-64` (`check-sdd-structure.sh`, `sdd-adopt` recovery, refactor-mode artifact requirements).

#### INV-005: `ship/SKILL.md` contains no MCP reference at all

`plugins/sdd-ship/skills/ship/SKILL.md` is 332 lines. A case-insensitive search for `mcp` returns **zero** matches.

Structure: `## Invocation` `:12`, `## Preconditions` `:45`, `## Step 1 — Target Selection` `:55`, `## Step 2 — Track Detection` `:76`, … `## Security Boundaries` `:309`, `## Handoff` `:322`. The existing preflight is `## Preconditions` `:45-53` (AGENTS.md existence + `check-sdd-structure.sh` reports no `missing:` items).

**Also checked and also zero:** `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`. Recorded because `bootstrap` delegates Phase 1 to the interviewer, so "bootstrap has no MCP step" is true of the delegate as well — relevant to Open Question 6.

#### INV-006: both named tools exist and are registered read-only

`mcp/sdd-forge-mcp/src/server.ts` registers **14** tools via `server.registerTool(`. The two the issue names:

- `:89` — `get_task_state`, described as "Parses specs/<feature>/tasks.md's state machine, shell-equivalent to check-task-state.sh (pass/fail verdict and per-task failures)." Input schema: `{ feature: FEATURE_ARG }` — **feature is required**.
- `:141` — `get_next_sdd_command`, "Determines the next SDD workflow command for a feature (or, with no feature argument, auto-selects the single active feature the same way sdd-ship:run does) by walking AGENTS.md's Required Workflow gates." Input schema: `{ feature: FEATURE_ARG.optional() }` — **feature is optional**.

The asymmetry is load-bearing and feeds Open Question 3: `get_next_sdd_command` can be called with no feature argument, `get_task_state` cannot.

The full registered set, in declaration order (`:65`–`:219`): `list_active_specs`, `get_spec_status`, `get_task_state`, `list_approved_tasks`, `list_blocked_tasks`, `list_review_tickets`, `get_quality_gate_summary`, `get_next_sdd_command`, `evidence_get_bundle`, `evidence_validate_paths`, `evidence_find_missing`, `evidence_summarize_contract_checks`, `evidence_compare_to_traceability`, `evidence_deep_verify`. None is a write tool.

### Stream B — the policy statement (issue AC 2)

#### INV-007: `README.md` already states read-only, in four places

`README.md:108` — "`install.sh` / `install.ps1` には read-only の MCP サーバーが同梱されており、既定で配置・登録されます。"

`README.md:114` (`sdd-forge-mcp`), `:118` (`local-env-mcp`), `:130` (`ci-mcp`) each carry a `**read-only**` designation. `:114` and `:130` additionally state there is no write API / no write tools.

#### INV-008: `USERGUIDE.md` already states read-only, in three places plus a dedicated bullet

`USERGUIDE.md:40`, `:135`, `:213` — one per server, each `**read-only**`. `:229` adds an explicit `- **write 機能なし**: …` bullet for `ci-mcp`.

**So the issue's "read-only 方針を明文化" is not a blank page.** What is absent from both documents is the specific pair of claims the issue's Proposed change actually asks for: (a) that MCP **does not auto-advance the workflow** and is advisory only, and (b) a standing policy **suppressing future write tools**. Zero matches for `自動進行` / `auto-advance` in `README.md` or `USERGUIDE.md`.

#### INV-009: a write-suppression precedent exists but covers only `ci-mcp`

`docs/adr/0006-ci-mcp-readonly-github-actions.md:36`

```
     re-run / cancel / dispatch / delete / approve 等の write ツールを公開しない。
```

and `:67-69`, under Consequences

```
- write 系の要求(re-run 等)が将来必要になっても、本サーバーの拡張ではなく
  read/write 分離方針に沿った別経路(write 通常 OFF の別コンポーネント/設定)で
  設計することになり、本 ADR の supersede が必要になる。
```

This is very close to the policy #129 wants, but its scope is `ci-mcp` only. Nothing generalises it to `sdd-forge-mcp` or `local-env-mcp`. Whether #129's policy statement should be prose, or should instead extend/supersede this ADR, is Open Question 8 — the issue names only `USERGUIDE.md` and `README.md`, so this specification must not decide it.

### Stream C — protection status of the target files

#### INV-010: `ship/SKILL.md` is a protected gate file; the other three are not

`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4` defines `PROTECTED_GATE_SUFFIXES`. Membership was tested by `endswith()` on each repo-relative target path, as the guard itself does:

| Target file (repo-relative) | On `PROTECTED_GATE_SUFFIXES`? |
|---|---|
| `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` | **no** |
| `plugins/sdd-ship/skills/ship/SKILL.md` | **YES** — matched by the identical literal entry |
| `USERGUIDE.md` | **no** |
| `README.md` | **no** |

`plugins/sdd-ship/skills/ship/SKILL.md` additionally appears in `PHASE2_HUMAN_COPY_TARGETS` at `guard_invariants.py:18`.

**The issue does not mention this.** It lists all four target files at the same level, as if all four were ordinarily writable. One of them cannot be written by an agent at all.

#### INV-011: the human-copy staging pattern for this exact file already has a worked precedent

`specs/quality-loop-fixes/human-copy/` contains:

```
specs/quality-loop-fixes/human-copy/.github/workflows/test.yml
specs/quality-loop-fixes/human-copy/MANIFEST.sha256
specs/quality-loop-fixes/human-copy/plugins/sdd-ship/skills/ship/SKILL.md
```

`MANIFEST.sha256` records one `<sha256>  <repo-relative-path>` line per staged file. Conformance is asserted by `tests/quality-gate-cycle-limit.tests.sh:363-378` (case `QGCL-015`), which checks that the staged candidate's SHA-256 matches its manifest entry and that the live protected file exists — explicitly "never opens the live protected path for write" (`:358-361`).

Eight other features carry a `human-copy/` directory, so the pattern is established rather than improvised.

#### INV-012: the guard's Bash-command matcher is broader than its write-path list — confirmed first-hand

During this investigation a purely **read-only** command (`grep -n` over several paths, one of which was a gate-script path) was denied by `sdd-hook-guard.sh` with the deterministic-gate message. No write was attempted.

This reproduces the hazard `specs/epic-136-phase4-docs/investigation.md:168` recorded. Implementation agents must expect it and restructure the command (this investigation re-ran the same reads through `python3` successfully) rather than attempt to work around the guard.

### Stream D — consumers that constrain the change

#### INV-013: an existing test asserts on the structure of `bootstrap/SKILL.md`

`tests/workflow-documentation.tests.sh:65-68`

```sh
run_skill="${ROOT}/plugins/sdd-bootstrap/skills/bootstrap/SKILL.md"
run_full="$(sed -n '/^### `feature` .*full track)/,/^### Lite track/p' "$run_skill")"
for stage in spec-review-loop impl-review-loop task-review-loop; do
  grep -Fq "$stage" <<<"$run_full" || fail "bootstrap run full track must name $stage"
done
```

The extraction is a `sed` range bounded by the literal headings ``### `feature` … full track)`` and `### Lite track`. Inserting a probe step **inside** that range would place it inside the extracted block; inserting it before `## Routing` `:66` would not. The same file's `DOCS` array at `:6-13` includes `README.md`, so `README.md` is already under this suite's coverage.

#### INV-014: `specs/` directories must be registered or the repository-wide gate fails

`plugins/sdd-quality-loop/scripts/check-workflow-state.sh:130-135` walks every directory under `specs/` and emits

```
diagnostic "$feature" registry-unregistered-directory "specification directory is not registered"
```

for any that has no entry in `specs/workflow-state-registry.json`. The diagnostic function exits 1 immediately.

Creating `specs/mcp-readonly-preflight/` therefore turns the repository-wide gate red until a registry entry exists. Both gates were confirmed green immediately before this directory was created (`check-sdd-structure: OK`; `workflow-state: ok`).

The registry's bounded schema (`contracts/workflow-state-registry.schema.json`) accepts `{"feature": …, "profile": "full"}` with exactly those two keys for a full-profile entry, and `tests/workflow-state-registry.tests.sh:150` states that full/lite membership is deliberately **not** pinned — so adding an entry is the ordinary registration path, not a test-breaking change.

## Open Questions

Recorded rather than resolved. Each is a decision issue #129 does not make.

**OQ-001 — Which tools constitute "the probe"?**
The issue writes `get_next_sdd_command`/`get_task_state` **等** ("etc."). Fourteen read-only tools are registered (INV-006). Whether the probe is exactly those two, or also `get_spec_status` / `list_active_specs` / `list_approved_tasks`, is unstated. The set must be fixed before the skills can name it.

**OQ-002 — Where in each skill does the probe go?**
The issue says "冒頭" (at the beginning). Both skills already have a `## Preconditions` block (`bootstrap:54`, `ship:45`) and both have a first working step after it (`bootstrap` `## Routing` `:66`; `ship` `## Step 1 — Target Selection` `:55`). Before Preconditions, inside Preconditions, or between Preconditions and the first step are three materially different answers — the third is the only one where `check-sdd-structure.sh` has already run. INV-013 makes this more than cosmetic for `bootstrap`.

**OQ-003 — What does the probe do when there is no feature to probe?**
`get_task_state` requires a `feature` argument (INV-006). In `bootstrap feature` mode the feature slug names a directory that does not exist yet, so the tool has nothing to read. `get_next_sdd_command` accepts no feature and auto-selects. Whether the probe is skipped, called with a best-effort slug, or restricted to the no-argument tool in this case is undecided.

**OQ-004 — Which bootstrap modes and which track does the probe apply to?**
`bootstrap` has six modes (`feature`, `bugfix`, `refactor`, `project`, `adopt`, `investigate`) and two tracks (full, lite). `adopt` runs against a repository that may have no `specs/` at all; `investigate` is read-only analysis. The issue scopes the probe to neither modes nor tracks.

**OQ-005 — What are the consumption semantics of the probe result, and what happens on divergence?**
This is the load-bearing question. The issue requires the probe be read-only and requires MCP not auto-advance the workflow, but does not say what the agent *does* with the result: display it, log it, or compare it against the file-based conclusion. If it compares, a disagreement between `get_next_sdd_command` and the file-based selection is either an error, a warning, or ignored — and the issue picks none. An "advisory" layer whose divergence handling is unspecified is not yet specifiable.

**OQ-006 — Does `sdd-bootstrap-interviewer/SKILL.md` also need the step?**
`bootstrap` delegates Phase 1 and Phase 2 to the interviewer, which likewise has zero MCP references (INV-005). The issue's file list names only `bootstrap/SKILL.md`. Adding it in one place and not the other is a coverage decision, not an oversight to be silently corrected.

**OQ-007 — How is `ship/SKILL.md`'s protected status to be handled?**
INV-010 makes this unavoidable and the issue is silent on it. Three answers are open: (a) stage a human-copy candidate per the INV-011 precedent and require a human-applied patch; (b) drop `ship/SKILL.md` from scope so the feature stays agent-applicable end to end; (c) place ship's probe wording in a non-protected file that `ship` already reads. This is a human decision because it changes what "1 issue = 1 commit" means for this issue.

**OQ-008 — Prose, or an ADR?**
INV-009 shows ADR-0006 already carries a `ci-mcp`-scoped version of the write-suppression policy, with an explicit supersede clause. Generalising it to all three servers plausibly warrants an ADR rather than only prose in two READMEs — but the issue names only `USERGUIDE.md` and `README.md`.

*Re-verification instruction (AGENTS.md `## Rules`, author-time sweep 3):* if OQ-008 is resolved toward a new ADR, the next free 4-digit number in `docs/adr/` must be re-derived at drafting time and **not** taken from this document. `docs/adr/` currently contains duplicate numbers — `0002`, `0003` and `0004` each appear twice — so the highest existing number is not a reliable proxy for the next free one, and the namespace is shared repository-wide with concurrent branches.

**OQ-009 — Is there an executable-test obligation, and in which suite?**
The issue lists no test criterion. Repository convention for a documentation-behaviour claim is a conformance check (INV-013 is one such suite, and `README.md` is already inside its `DOCS` array). Whether this feature extends `tests/workflow-documentation.tests.sh`, adds its own suite, or ships prose-only is undecided.

**OQ-010 — Is "MCP unavailable" one condition or several?**
The addendum says "MCP ツール呼び出しを試行し、失敗したらファイルベースへフォールバック". At least three distinguishable states exist: the server is not registered at all; it is registered but the tool call errors; the tool returns an error envelope (`sdd-forge-mcp` returns structured `Result<T>` envelopes rather than throwing). Whether all three take the same fallback path is unstated, and it determines how many branches the fallback criterion has.

## Acceptance Criteria Verification

Against the issue's three original criteria plus the addendum's:

| Issue AC | Current state | Evidence |
|---|---|---|
| MCP 有効時に preflight probe が読取参照される手順 | **Absent in both skills.** Zero MCP references in either file | INV-004, INV-005 |
| write 権限は追加しない | **Currently satisfied** — 14 registered tools, none write; existing docs already say so | INV-006, INV-007, INV-008 |
| MCP 不在フォールバックが機能 | **Vacuously true today** (there is no probe to fall back from); becomes a real obligation only once the probe exists | INV-004, INV-005 |
| Claude Code / Codex 双方で probe→フォールバックが機能 (addendum) | **Not applicable yet**; both registration surfaces confirmed to exist and differ | INV-002 |

The second criterion is a **preservation** obligation, not a construction one: the work is to keep it true and to write the policy down, not to make it true.
