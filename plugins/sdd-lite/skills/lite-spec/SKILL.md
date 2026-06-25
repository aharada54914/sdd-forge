---
name: lite-spec
description: Lightweight SDD specification for internal/departmental apps. Creates requirements, design, and tasks (single-approval, no traceability/ADR/evidence-bundle). Use for low-stakes internal app work; graduate to sdd-bootstrap-interviewer for higher rigor.
disable-model-invocation: true
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

## Process

1. Issue URL か要件テキストを受け取る（読み取り専用取得を試み、不可なら本文を尋ねる）。
2. 関連コード・既存パターンを軽く調査（大規模調査は委譲可）。
3. 次の3ファイルを `specs/<feature>/` に生成（テンプレは本プラグインの `templates/`）:
   - `requirements.md`（`templates/requirements-lite.md`）
   - `design.md`（`templates/design-lite.md`）
   - `tasks.md`（`templates/tasks-lite.md`）
4. 各タスクは `Approval: Draft` / `Status: Planned` で生成する。`Risk:` 行は付けない（lite は階層強制を使わない）。
5. 不明な製品判断は `Open Questions` に残す。勝手に埋めない。

## Approval Gate

人間のみが `tasks.md` の `Approval:` を `Approved` にできる。AI は承認できない（既存 hook-guard が `tasks.md` の `Approval: Approved` 増加をブロックする）。要件/設計/スコープ/重要リスクが曖昧なまま承認を促さない。

## Boundaries

- traceability.md・ADR・evidence-bundle・受入テストの厳密記述は生成しない（必要なら sdd-bootstrap-interviewer に切替）。
- アプリのコードを実装しない（実装は `implement-task`）。
- 承認・Done 化を行わない。

## Handoff

生成ファイル・Open Questions・最初の Draft タスクを報告し、「承認後に `/sdd-ship --lite specs/<feature>/tasks.md` で実装開始」と案内する。昇格が必要になったら design.md §6 の手順で full SDD に移行できることも伝える。
