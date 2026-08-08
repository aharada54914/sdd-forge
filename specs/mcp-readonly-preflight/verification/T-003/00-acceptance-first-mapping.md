# T-003 — Acceptance-first Done-When ↔ TEST mapping

Authored before editing `USERGUIDE.md`, per `Required Workflow:
acceptance-first` (`tasks.md` T-003).

## WFI-011 fresh line-number re-verification (done now, before edit)

Re-read at implementation start, not trusted from `tasks.md`'s own line
numbers:

```
$ grep -n "^## MCP サーバー$\|^### sdd-forge-mcp$\|^#### 概要$" USERGUIDE.md
34:## MCP サーバー
36:### sdd-forge-mcp
38:#### 概要
133:#### 概要
211:#### 概要

$ sed -n '40p;135p;213p;229p' USERGUIDE.md
```

All five citations in `tasks.md` T-003's Done-When and Risk Rationale match
the current file exactly, with no drift:

- `## MCP サーバー` region starts at `:34`; `#### 概要` (the first
  sub-heading `tasks.md` cites as "`:38` onward") is at `:38` — unchanged.
- `:40` — `sdd-forge-mcp` overview: `**read-only** MCP サーバーです。書き込み
  API は一切持たず…` — unchanged, matches.
- `:99` — the known false positive: `evidence_deep_verify`'s description
  contains `助言的メタデータ` (advisory metadata), about `hostRequiredChecks`
  specifically, not the workflow-level claim this task adds — unchanged,
  matches `acceptance-tests.md:140`'s citation exactly.
- `:135` — `local-env-mcp` overview: `**read-only** MCP サーバーです。` —
  unchanged, matches.
- `:213` — `ci-mcp` overview: `**read-only** MCP サーバーです。write
  API・write ツールは一切持たず…` — unchanged, matches.
- `:229` — `ci-mcp` セキュリティ境界 bullet: `**write 機能なし**: … write
  API・write ツールは実装されていません` — unchanged, matches.

Note: `tasks.md` T-003's Done-When bullet 3 and Rollback both say "the
**five** existing correct read-only sentences" but cite only **four** line
numbers (`:40,135,213,229`). A fifth candidate exists in the file
(`sdd-forge-mcp`'s セキュリティ特性 bullet at `:113`, "書き込み系 API は一切
実装されていません") that is not explicitly cited. This is treated as a
pre-existing minor imprecision in `tasks.md`'s prose, not something this task
may fix (`tasks.md` is frozen/not-editable per the orchestrator's
instructions). Out of caution this task preserves `:113` untouched as well,
in addition to the four explicitly cited lines — reported as a disclosed
observation, not acted on as a blocker.

## Done-When ↔ TEST mapping and verification method

| Done-When bullet | TEST/AC | Verification method used |
|---|---|---|
| 1. `USERGUIDE.md` states, with a substantive sentence, that MCP does not auto-advance the SDD workflow and is advisory to the agent | AC-021, TEST-021 | Integration (real file read): read the final file and confirm a standalone sentence (not a bare keyword) states both (a) MCP does not auto-advance/decide the workflow and (b) MCP's role is advisory to the agent, together, not just the isolated word `助言`. |
| 2. `USERGUIDE.md` states, with a substantive sentence, the standing policy that write tools are not to be added to these servers | AC-022, TEST-022 | Integration (real file read): read the final file and confirm a standalone sentence states the forward-looking ("standing", not merely descriptive-of-today) policy that write tools will not be added, distinct from and in addition to the existing per-server "read-only today" sentences. |
| 3. Both claims added around `## MCP サーバー` (`:38` onward) without rewriting the five (four explicitly cited + `:113` preserved out of caution) existing correct read-only sentences (BL-003) | BL-003 | Diff-verified: `git diff -- USERGUIDE.md` must show a pure insertion (no `-` lines) touching lines `40`, `99`, `113`, `135`, `213`, `229`'s content. |
| 4. Neither claim satisfied by the pre-existing `助言的` occurrence at `:99` | REQ-008 note, `acceptance-tests.md:140` | Text inspection: confirm the new prose is textually distinct from and does not merely repeat/point at `:99`'s `hostRequiredChecks` sentence; confirm `:99`'s sentence is unedited (covered by bullet 3's diff check). |
| 5. Line-number citations re-verified fresh (WFI-011) | — | Done above, this section, before any edit was made. |

## Planned insertion

Insert two new paragraphs directly after the `## MCP サーバー` heading
(`:34`) and its trailing blank line (`:35`), directly before `### sdd-forge-mcp`
(`:36`) — i.e., as the section's lead-in prose, applying to all three
servers listed below it (`sdd-forge-mcp` / `local-env-mcp` / `ci-mcp`)
rather than duplicating the claim three times. This keeps the edit inside
the `## MCP サーバー` region (satisfying "`:38` onward" as the region's
scope, not a strict floor) and is a pure insertion — every existing line
number from `:36` onward simply shifts down by a fixed offset, with no
existing sentence rewritten.
