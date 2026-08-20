---
name: lite-spec
description: Lightweight SDD specification for internal/departmental apps. Creates requirements, design, and tasks (single-approval, no traceability/ADR/evidence-bundle). Use for low-stakes internal app work; graduate to sdd-bootstrap-interviewer for higher rigor.
disable-model-invocation: true
user-invocable: false
---

# Lite Spec

社内・部署内アプリ向けの軽量仕様を作る。要件・設計・タスクの3ファイルのみを生成し、traceability/ADR/受入テストの重い記述は任意とする。アプリのコードは実装しない。

## Invocation

Codex:

```txt
Use the lite-spec skill.
Source: <issue URL or 要件テキスト>
```

Claude Code:

```txt
/sdd-lite:lite-spec <source>
```

## Preconditions

リポジトリ root に `AGENTS.md` が存在し、`scripts/check-sdd-structure.sh`（または `.ps1`）が `missing:` を出さないこと。未整備なら `/sdd-bootstrap:sdd-adopt` を案内して停止する。lite でも SDD 構造（AGENTS.md + 必須ディレクトリ）は前提（implement-task の前提条件）。

## Risk-Upgrade Gate

Before beginning the Process or creating any file under `specs/<feature>/`,
resolve the complete user-supplied requirement/source body into one local,
readable UTF-8 file. Do not treat an opaque URL as source text and do not fetch
it remotely for this gate.

**Capability-derived signal (epic-194-a6-lite-integration T-003, REQ-005).**
For every Capability Registry entry, call Epic A2's `evaluate-predicate` once
per component the current Project Context already declares (static,
diff-independent). Union-match across every (Capability, component) pair
determines the matched set. Assemble every matched Capability whose own
`lite_policy.eligible` is `false` into the trigger-fragment shape
`check-risk-upgrade` accepts:

```json
{
  "capabilities": [
    {"id": "<capability-id>", "eligible": false,
     "upgrade_reasons": ["<already-catalog-validated token>", "..."]}
  ]
}
```

Write this fragment to a local temp path. If no Project Context exists at all
(disabled-legacy), skip this step entirely -- no fragment is produced, and the
checker below runs with its first argument only, exactly as before this
extension.

If a Project Context does exist, the caller has attempted to supply a
Capability-derived signal, and that attempt fails -- `evaluate-predicate` is
absent or exits non-zero, the Registry is unreadable or fails to parse as
valid JSON, or writing the temp fragment fails -- do not fall through to the
one-argument, keyword-only invocation. An attempt that fails must never be
silently treated as one that never attempted to. Block immediately, before
the checker below is ever run: stop before any lite artifact write, tell the
user the Capability-derived signal could not be produced, and direct them to
`/sdd-bootstrap:sdd-bootstrap-interviewer`. The second argument's own total
absence (disabled-legacy, above -- a Project Context that does not exist at
all) is the only condition that legitimately falls through to the
one-argument call; every failure encountered once a Project Context is
confirmed to exist is a Block, never a silent degrade.

Run the platform-local checker against the resolved source file, passing the
fragment path (when one was produced) as the second argument:

```txt
plugins/sdd-lite/scripts/check-risk-upgrade.sh <resolved-source-file> [--capability-reasons <fragment-path>]
powershell -NoProfile -ExecutionPolicy Bypass -File plugins/sdd-lite/scripts/check-risk-upgrade.ps1 -Path <resolved-source-file> [-CapabilityReasons <fragment-path>]
```

- Exit 0 with `lite-eligible`: continue to Process.
- Exit 10 with `full-required: ...`: stop before any lite artifact write and
  direct the user to `/sdd-bootstrap:sdd-bootstrap-interviewer` for the full
  workflow. `--lite` never overrides this decision, regardless of whether the
  match came from the keyword scan or from this Capability-derived signal.
- Exit 2 with `risk-upgrade: input unavailable` (primary source) or
  `risk-upgrade: capability-reasons fragment invalid` (fragment path supplied
  but unreadable/malformed/shape-invalid): stop before any lite artifact
  write. Tell the user that a readable local requirement body (and, when
  applicable, a valid Capability-derived fragment) is required and direct
  them to `/sdd-bootstrap:sdd-bootstrap-interviewer`; do not create a partial
  lite specification.

This intake-time Block is layered with, not a substitute for, the existing
`ship`-time recheck (a second, independent `check-risk-upgrade` invocation at
ship time, unmodified by this extension) -- both stages are mandatory.

## Process

1. Issue URL か要件テキストを受け取る（読み取り専用取得を試み、不可なら本文を尋ねる）。
2. 関連コード・既存パターンを軽く調査（大規模調査は委譲可）。
3. 次の3ファイルを `specs/<feature>/` に生成（テンプレは本プラグインの `templates/`）:
   - `requirements.md`（`templates/requirements-lite.md`）
   - `design.md`（`templates/design-lite.md`）
   - `tasks.md`（`templates/tasks-lite.md`）
4. UI アプリで人間が希望する場合のみ、`design-sync-loop` スキル
   （sdd-bootstrap プラグインの内部スキル）を実行する。モックアップは
   `specs/<feature>/mockups/` に、`Design-Source` / `Mockup-Status` は
   `design.md` に記録される。任意・非ブロッキングで、ツールがない環境では
   手動手順にフォールバックする。希望しない場合はこのステップを飛ばす。
5. 各タスクは `Approval: Draft` / `Status: Planned` で生成する。`Risk:` 行は付けない（lite は階層強制を使わない）。
6. 不明な製品判断は `Open Questions` に残す。勝手に埋めない。

## Approval Gate

人間のみが `tasks.md` の `Approval:` を `Approved` にできる。AI は承認できない（既存 hook-guard が `tasks.md` の `Approval: Approved` 増加をブロックする）。要件/設計/スコープ/重要リスクが曖昧なまま承認を促さない。

## Boundaries

- traceability.md・ADR・evidence-bundle・受入テストの厳密記述は生成しない（必要なら sdd-bootstrap-interviewer に切替）。
- アプリのコードを実装しない（実装は `implement-task`）。
- 承認・Done 化を行わない。
- Predicate-DSL/Registry-matching ロジック自体は実装しない（Epic A2 の `evaluate-predicate` を呼び出すのみ）。

## Handoff

生成ファイル・Open Questions・最初の Draft タスクを報告し、「承認後に `/sdd-ship --lite specs/<feature>/tasks.md` で実装開始」と案内する。昇格が必要になったら design.md §6 の手順で full SDD に移行できることも伝える。
