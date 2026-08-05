# T-004 — Acceptance-first Done-When ↔ TEST mapping

Authored before editing `README.md`, per `Required Workflow:
acceptance-first` (`tasks.md` T-004).

## WFI-011 fresh line-number re-verification (done now, before edit)

Re-read at implementation start, not trusted from `tasks.md`'s own line
numbers:

```
$ grep -n "^### MCP サーバー$\|^#### sdd-forge-mcp$\|^#### local-env-mcp$\|^#### ci-mcp$" README.md
110:### MCP サーバー
112:#### sdd-forge-mcp
116:#### local-env-mcp
128:#### ci-mcp

$ sed -n '108p;114p;118p;130p' README.md
`install.sh` / `install.ps1` には read-only の MCP サーバーが同梱されており、既定で配置・登録されます。
`sdd-forge-mcp` は、対象リポジトリの SDD 状態（spec / タスク / レビューチケット / 品質ゲート結果 / evidence）を構造化データとして読み取るための **read-only** MCP サーバーです。書き込み API は一切持たず、stdio 経由で MCP クライアント（Claude Code / Codex）から子プロセスとして起動されます。
`local-env-mcp` は、ローカル開発環境の情報を読み取るための **read-only** MCP サーバーです。実行機能を一切持たず、以下の 3 つの構造化 JSON ツールで環境情報を提供します:
`ci-mcp` は、GitHub Actions の CI 状態（ワークフロー実行・ジョブ・ジョブログ・成果物メタデータ）を読み取るための **read-only** MCP サーバーです。write API・write ツールは一切持たず、GitHub REST API へは `https://api.github.com` 固定ホストへの GET リクエストのみ発行します（サブプロセス実行なし）。以下の 5 ツールを提供します:
```

All four citations in `tasks.md` T-004's Done-When bullet 3 and Rollback
(`README.md:108,114,118,130`) match the current file exactly, with no
drift. The region cited (`:108-142`) runs from the `install.sh` /
`install.ps1` lead-in sentence through the closing
`導入オプション（詳細と トラブルシュート）は USERGUIDE.md を参照してください。`
line — confirmed by reading `README.md:108-142` in full; unchanged since
`tasks.md` was authored.

## Done-When ↔ TEST mapping and verification method

| Done-When bullet | TEST/AC | Verification method used |
|---|---|---|
| 1. `README.md` states, with a substantive sentence, that MCP does not auto-advance the SDD workflow and is advisory | AC-023, TEST-023 | Integration (real file read): read the final file and confirm a standalone sentence (not a bare keyword) states both (a) MCP's output is advisory (`助言的（advisory）`) and (b) it does not auto-advance/override the file-based `tasks.md` Approval/Status/quality-gate procedure, together. |
| 2. `README.md` states, with a substantive sentence, the standing no-write-tools policy | AC-024, TEST-024 | Integration (real file read): read the final file and confirm a standalone sentence states the forward-looking ("standing", not merely descriptive-of-today) policy that write tools will not be added — distinguished from the existing per-server "read-only today" sentences by an explicit future-tense/continuation claim. |
| 3. Both claims added in the existing MCP region (`:108-142`) without rewriting the four existing correct read-only statements at `:108`, `:114`, `:118`, `:130` (BL-003) | BL-003 | Diff-verified: `git diff -- README.md` must show a pure insertion (no `-` lines) touching lines `108`, `114`, `118`, `130`'s content. |
| 4. `tests/workflow-documentation.tests.sh` passes unmodified (AC-027) | AC-027, TEST-027 | Run the suite unmodified after the edit and confirm exit code 0 / `ok:` output; `README.md` is already in the suite's `DOCS` array (`:6-13`), so this is real, pre-existing coverage, not a new registration. |
| 5. Line-number citations re-verified fresh (WFI-011) | — | Done above, this section, before any edit was made. |

## Planned insertion

Insert two new paragraphs directly after the `### MCP サーバー` heading
(`:110`) and its trailing blank line (`:111`), directly before
`#### sdd-forge-mcp` (`:112`) — i.e., as the section's lead-in prose,
applying to all three servers listed below it (`sdd-forge-mcp` /
`local-env-mcp` / `ci-mcp`) rather than duplicating the claim three times.
This mirrors the placement `USERGUIDE.md:36,38` already uses relative to
its own `## MCP サーバー` heading (T-003 precedent), keeps the edit inside
the `:108-142` region `tasks.md` cites, and is a pure insertion — every
existing line from `:112` onward simply shifts down by a fixed offset, with
no existing sentence rewritten. The two new paragraphs reuse the same
already-reviewed substance as `USERGUIDE.md:36,38` (T-003's wording),
adapted to no other document than to sit in README's own MCP region, per
the orchestrator instruction to write "同じポリシーの README 版" ("the
README version of the same policy") in README's own context.
