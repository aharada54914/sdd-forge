# T-003 — Post-edit verification record

All commands below were run from the repository root
(`/Users/jrmag/Projects/active/sdd-forge-wt-phase4`) after the single edit to
`USERGUIDE.md`.

## Done-When bullet 1 — advisory / no-auto-advance claim (AC-021, TEST-021)

```
$ sed -n '36p' USERGUIDE.md
MCP サーバーが提供する情報は SDD ワークフローに対して常に **助言的（advisory）** です。エージェントは各 tool の応答を判断材料として利用しますが、それによって `tasks.md` の Approval / Status 判定や品質ゲートの合否確認といったファイルベースの手続きを自動的に進めたり、その判定を上書きしたりすることはありません。SDD ワークフローの決定権は常にファイルベースの手続き側にあり、MCP はそれを補助する情報源にとどまります。
```

One standalone paragraph states, jointly: (a) MCP's output is advisory
(`助言的（advisory）`), (b) it does not auto-advance/decide the workflow
(does not "自動的に進めたり…上書きしたりすることはありません"), and (c)
the decision authority remains with the file-based procedure ("SDD
ワークフローの決定権は常にファイルベースの手続き側にあり"). This is a
substantive sentence, not a bare keyword occurrence. **PASS.**

## Done-When bullet 2 — standing no-write-tools policy (AC-022, TEST-022)

```
$ sed -n '38p' USERGUIDE.md
また、この read-only な助言層としての位置づけを維持するため、write tool（状態を変更・作成・進行させる tool）をこれらの MCP サーバーに追加しない方針を継続しています。以下の `sdd-forge-mcp` / `local-env-mcp` / `ci-mcp` はいずれも読み取り専用の tool のみを登録しており、将来の機能拡張であってもこの方針は変わりません。
```

States the standing (forward-looking) policy explicitly: "write tool …
をこれらの MCP サーバーに追加しない方針を継続しています" plus "将来の機能
拡張であってもこの方針は変わりません" — not merely a snapshot of today's
state, but a policy statement about future additions. Substantive, not a
bare keyword. **PASS.**

## Done-When bullet 3 — added around `## MCP サーバー`, no rewrite of existing correct sentences (BL-003)

```
$ git diff -- USERGUIDE.md
diff --git a/USERGUIDE.md b/USERGUIDE.md
index 90dae8e4..45c2b2dc 100644
--- a/USERGUIDE.md
+++ b/USERGUIDE.md
@@ -33,6 +33,10 @@ epic-159-pillar-c Phase 2) 以降、既定値が `matrix` になった

 ## MCP サーバー

+MCP サーバーが提供する情報は SDD ワークフローに対して常に **助言的（advisory）** です。エージェントは各 tool の応答を判断材料として利用しますが、それによって `tasks.md` の Approval / Status 判定や品質ゲートの合否確認といったファイルベースの手続きを自動的に進めたり、その判定を上書きしたりすることはありません。SDD ワークフローの決定権は常にファイルベースの手続き側にあり、MCP はそれを補助する情報源にとどまります。
+
+また、この read-only な助言層としての位置づけを維持するため、write tool（状態を変更・作成・進行させる tool）をこれらの MCP サーバーに追加しない方針を継続しています。以下の `sdd-forge-mcp` / `local-env-mcp` / `ci-mcp` はいずれも読み取り専用の tool のみを登録しており、将来の機能拡張であってもこの方針は変わりません。
+
 ### sdd-forge-mcp

 #### 概要

$ git diff --stat -- USERGUIDE.md
 USERGUIDE.md | 4 ++++
 1 file changed, 4 insertions(+)
```

Zero `-` lines: the diff is a pure 4-line insertion (two paragraphs + two
blank separators) directly after `## MCP サーバー` (`:34`) and before
`### sdd-forge-mcp` (now `:40`, shifted from `:36`). All five pre-existing
correct read-only sentences (the four `tasks.md` explicitly cites, plus the
fifth at the original `:113` preserved out of caution per
`00-acceptance-first-mapping.md`'s disclosed observation) are present,
unedited, shifted down by exactly 4 lines:

```
$ grep -n "read-only\|write 機能なし\|書き込み系 API は一切実装されていません" USERGUIDE.md
44:`sdd-forge-mcp` は、対象リポジトリの SDD 状態（… **read-only** MCP サーバーです。書き込み API は一切持たず…
117:読み取り可能な範囲は allowlist（…）… 書き込み系 API は一切実装されていません（`tasks.md` の承認状態変更やファイル作成はできません）。
139:`local-env-mcp` は、ローカル開発環境の情報を読み取るための **read-only** MCP サーバーです。…
217:`ci-mcp` は、GitHub Actions の CI 状態（…）… **read-only** MCP サーバーです。write API・write ツールは一切持たず…
233:- **write 機能なし**: GET 専用・ホストは `https://api.github.com` に固定でどのツール引数からも書き換え不可。write API・write ツールは実装されていません
```

Original line numbers were `:40`, `:113`, `:135`, `:213`, `:229` — each
shifted to exactly `original + 4`, confirming pure insertion with no
rewrite. **PASS** (BL-003).

## Done-When bullet 4 — new claims are not satisfied by the pre-existing `:99` occurrence

```
$ grep -n "助言的" USERGUIDE.md
36:MCP サーバーが提供する情報は SDD ワークフローに対して常に **助言的（advisory）** です。…
103:| `evidence_deep_verify` | … `hostRequiredChecks` は助言的メタデータであり `verdict` にも `failures` にも一切影響しない。 |
```

The original `:99` occurrence (now shifted to `:103`, unedited — confirmed
by bullet 3's diff, which touched no line inside the `sdd-forge-mcp` tools
table) is textually distinct: it describes `evidence_deep_verify`'s
`hostRequiredChecks` field specifically, not the workflow-level claim this
task adds. The new claim at `:36` is additional, substantive prose making
its own independent assertion, not a reference to or reliance on `:103`'s
sentence. **PASS.**

## Done-When bullet 5 — line-number citations re-verified fresh (WFI-011)

Performed before the edit; see `00-acceptance-first-mapping.md`'s "WFI-011
fresh line-number re-verification" section. All citations (`:34`, `:36`,
`:38`, `:40`, `:99`, `:135`, `:213`, `:229`) matched the current file exactly
at implementation start, with one disclosed observation (the `:113`
five-vs-four count) recorded there, not silently corrected. **PASS.**

## Regression suite — unmodified pass

```
$ bash tests/workflow-documentation.tests.sh
ok: full SDD documentation names the three independent review stages in order
$ echo "exit=$?"
exit=0
```

`tests/workflow-documentation.tests.sh` was run **unmodified** and passed.
`USERGUIDE.md` is not in this suite's `DOCS` array (`README.md` is T-004's
target, not this task's), so this run is a pure non-regression check, not a
direct assertion of AC-021/AC-022 — those are asserted by direct file read
above, per `acceptance-tests.md`'s own "integration (real file read)" typing
for TEST-021/TEST-022.

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
 M USERGUIDE.md
 M specs/mcp-readonly-preflight/tasks.md
?? specs/mcp-readonly-preflight/human-copy/
?? specs/mcp-readonly-preflight/verification/T-003/
```

The `tasks.md` modification (`Status: Planned -> In Progress` for T-002 and
T-003) and the `human-copy/` directory are **pre-existing working-tree
state from other tasks/sessions in this shared worktree** (confirmed by
`git diff` showing only the two `Status:` line flips, and by `git log`
showing T-001 already committed as `c97cf10f`) — neither was created or
edited by this task. This task's own writes are exactly `USERGUIDE.md` (the
one permitted edit) and `specs/mcp-readonly-preflight/verification/T-003/`
(this verification record). No protected file, no other prohibited file
(`tasks.md`/`traceability.md`/`requirements.md`/`design.md`/
`acceptance-tests.md`/`investigation.md`/`README.md`) was opened for write
by this task, and no `git add`/`git commit` was run.
