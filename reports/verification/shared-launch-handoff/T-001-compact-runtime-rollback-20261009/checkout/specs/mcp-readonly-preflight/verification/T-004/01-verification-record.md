# T-004 — Post-edit verification record

All commands below were run from the repository root
(`/Users/jrmag/Projects/active/sdd-forge-wt-phase4`) after the single edit to
`README.md`.

## Done-When bullet 1 — advisory / no-auto-advance claim (AC-023, TEST-023)

```
$ sed -n '112p' README.md
MCP サーバーが提供する情報は SDD ワークフローに対して常に **助言的（advisory）** です。エージェントは各 tool の応答を判断材料として利用しますが、それによって `tasks.md` の Approval / Status 判定や品質ゲートの合否確認といったファイルベースの手続きを自動的に進めたり、その判定を上書きしたりすることはありません。SDD ワークフローの決定権は常にファイルベースの手続き側にあり、MCP はそれを補助する情報源にとどまります。
```

One standalone paragraph states, jointly: (a) MCP's output is advisory
(`助言的（advisory）`), (b) it does not auto-advance/decide the workflow
(does not "自動的に進めたり…上書きしたりすることはありません"), and (c) the
decision authority remains with the file-based procedure ("SDD ワークフロー
の決定権は常にファイルベースの手続き側にあり"). This is a substantive
sentence, not a bare keyword occurrence. **PASS.**

## Done-When bullet 2 — standing no-write-tools policy (AC-024, TEST-024)

```
$ sed -n '114p' README.md
また、この read-only な助言層としての位置づけを維持するため、write tool（状態を変更・作成・進行させる tool）をこれらの MCP サーバーに追加しない方針を継続しています。以下の `sdd-forge-mcp` / `local-env-mcp` / `ci-mcp` はいずれも読み取り専用の tool のみを登録しており、将来の機能拡張であってもこの方針は変わりません。
```

States the standing (forward-looking) policy explicitly: "write tool …
をこれらの MCP サーバーに追加しない方針を継続しています" plus "将来の機能
拡張であってもこの方針は変わりません" — not merely a snapshot of today's
state, but a policy statement about future additions. Substantive, not a
bare keyword. **PASS.**

## Done-When bullet 3 — added inside `:108-142`, no rewrite of existing correct statements (BL-003)

```
$ git diff -- README.md
diff --git a/README.md b/README.md
index ab4c96c6..7fc6a442 100644
--- a/README.md
+++ b/README.md
@@ -109,6 +109,10 @@ flowchart LR

 ### MCP サーバー

+MCP サーバーが提供する情報は SDD ワークフローに対して常に **助言的（advisory）** です。エージェントは各 tool の応答を判断材料として利用しますが、それによって `tasks.md` の Approval / Status 判定や品質ゲートの合否確認といったファイルベースの手続きを自動的に進めたり、その判定を上書きしたりすることはありません。SDD ワークフローの決定権は常にファイルベースの手続き側にあり、MCP はそれを補助する情報源にとどまります。
+
+また、この read-only な助言層としての位置づけを維持するため、write tool（状態を変更・作成・進行させる tool）をこれらの MCP サーバーに追加しない方針を継続しています。以下の `sdd-forge-mcp` / `local-env-mcp` / `ci-mcp` はいずれも読み取り専用の tool のみを登録しており、将来の機能拡張であってもこの方針は変わりません。
+
 #### sdd-forge-mcp

 `sdd-forge-mcp` は、対象リポジトリの SDD 状態（spec / タスク / レビューチケット / 品質ゲート結果 / evidence）を構造化データとして読み取るための **read-only** MCP サーバーです。書き込み API は一切持たず、stdio 経由で MCP クライアント（Claude Code / Codex）から子プロセスとして起動されます。

$ git diff --stat -- README.md
 README.md | 4 ++++
 1 file changed, 4 insertions(+)
```

Zero `-` lines: the diff is a pure 4-line insertion (two paragraphs + two
blank separators) directly after `### MCP サーバー` (`:110`) and before
`#### sdd-forge-mcp` (now `:116`, shifted from `:112`). The insertion point
lands inside the `tasks.md`-cited `:108-142` region. All four pre-existing
correct read-only statements are present, unedited:

```
$ grep -n "read-only" README.md
108:`install.sh` / `install.ps1` には read-only の MCP サーバーが同梱されており、既定で配置・登録されます。
114:また、この read-only な助言層としての位置づけを維持するため、write tool（状態を変更・作成・進行させる tool）をこれらの MCP サーバーに追加しない方針を継続しています。以下の `sdd-forge-mcp` / `local-env-mcp` / `ci-mcp` はいずれも読み取り専用の tool のみを登録しており、将来の機能拡張であってもこの方針は変わりません。
118:`sdd-forge-mcp` は、対象リポジトリの SDD 状態（… **read-only** MCP サーバーです。書き込み API は一切持たず…
122:`local-env-mcp` は、ローカル開発環境の情報を読み取るための **read-only** MCP サーバーです。…
134:`ci-mcp` は、GitHub Actions の CI 状態（…）… **read-only** MCP サーバーです。write API・write ツールは一切持たず…
144:**トークン設定**: 実行時に read-only の GitHub PAT が必要です。…
```

The original `:108` citation is **before** the insertion point (`:110-111`)
and is therefore unshifted, still at `:108`, unedited. The three citations
that sit after the insertion point (`:114`, `:118`, `:130`) each shifted by
exactly `+4`, landing at `:118`, `:122`, `:134` respectively — the `:114`
match at the unshifted line number belongs to this task's own new second
paragraph, not the original text, confirmed by content comparison against
`00-acceptance-first-mapping.md`'s pre-edit citation of the original
`:114` sentence (`` `sdd-forge-mcp` は、対象リポジトリの SDD 状態… ``, now at
`:118`). All four original sentences are present, unedited, at their
shifted positions. **PASS** (BL-003).

## Done-When bullet 4 — `tests/workflow-documentation.tests.sh` passes unmodified (AC-027, TEST-027)

```
$ git status --porcelain -- tests/workflow-documentation.tests.sh
(no output — file unmodified)

$ bash tests/workflow-documentation.tests.sh
ok: full SDD documentation names the three independent review stages in order
$ echo "exit=$?"
exit=0
```

`README.md` is already in the suite's `DOCS` array
(`tests/workflow-documentation.tests.sh:7`), so this run exercises real,
pre-existing coverage of the edited file, not a new registration. The suite
requires each `DOCS` entry to contain `spec-review-loop`, `impl-review-loop`,
`task-review-loop`, and an `independent|独立` match; none of those literals
sit inside the `:108-142` MCP region this task touched, so the pure
insertion could not have and did not regress them. **PASS.**

## Done-When bullet 5 — line-number citations re-verified fresh (WFI-011)

Performed before the edit; see `00-acceptance-first-mapping.md`'s "WFI-011
fresh line-number re-verification" section. All citations (`:108`, `:110`,
`:112`, `:114`, `:116`, `:118`, `:128`, `:130`, `:142`) matched the current
file exactly at implementation start, with no drift. **PASS.**

## BL-001 — no file under `mcp/` touched

```
$ git status --porcelain -- mcp/
(no output)
$ git diff --stat -- mcp/
(no output)
```

**PASS.**

## Overall change-set scope check

```
$ git status --porcelain
 M README.md
 M specs/mcp-readonly-preflight/tasks.md
?? specs/mcp-readonly-preflight/human-copy/
?? specs/mcp-readonly-preflight/verification/T-002/
?? specs/mcp-readonly-preflight/verification/T-004/
?? specs/mcp-readonly-preflight/verification/T-005/
```

The `tasks.md` modification (`Status: Planned -> In Progress` for T-004 and
T-005) and the `human-copy/`, `verification/T-002/`, `verification/T-005/`
directories are **pre-existing working-tree state from other tasks/sessions
in this shared worktree** (confirmed by `git diff -- specs/mcp-readonly-preflight/tasks.md`
showing only the two `Status:` line flips, and by `git log` showing T-001
and T-003 already committed as `c97cf10f` and `ef74aeed`) — none of it was
created or edited by this task. This task's own writes are exactly
`README.md` (the one permitted edit) and
`specs/mcp-readonly-preflight/verification/T-004/` (this verification
record and `00-acceptance-first-mapping.md`). No protected file, no other
prohibited file (`tasks.md` / `traceability.md` / `requirements.md` /
`design.md` / `acceptance-tests.md` / `investigation.md` / `USERGUIDE.md`)
was opened for write by this task, and no `git add` / `git commit` was run.
