# Implementation Policy Review Report: sdd-context — Round 1 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | sdd-context |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 5 |
| Minor Findings | 0 |
| Generated | 2026-08-15T10:52:43Z |

## Reviewer-A Findings (Structural Soundness)

- FAIL — `API-COVERAGE` (Major): `design.md` の `## API / Contract Plan` は
  3つの hook イベントと戻り値のみを記載しており、イベントごとのリクエスト/入力
  schema が欠落している。`source`, `auto_compaction`, `compact_summary` の
  非消費などは `requirements.md` の Field Definitions にあり、API contract
  section にない。既存 endpoint の deprecated / breaking change なしという
  表明もない。

## Reviewer-B Findings (Implementability/Risk)

- FAIL — `DECISION-JUSTIFIED` (Major): 単一決定論的 Node core、sh/PowerShell
  wrapper フォールバック、triple-manifest discovery を選択した理由が設計内に
  ない。ADR `0030-context-handoff.md` は計画のみで実在せず、現時点の技術選択を
  正当化できない。
- FAIL — `ASSUMPTIONS-VALID` (Major): `investigation.md` が存在せず、3つの非自明な
  assumptions に実証的根拠がない。`INV-xxx` 参照、技術的デフォルトの根拠、または
  明示的な受容リスクのいずれも欠落。
- FAIL — `DEPLOYMENT-CONCRETE` (Major): `## Deployment / CI Plan` が4つの
  checklist だけで、対象環境、feature-flag 方針、具体的な CI pipeline 変更、
  migration 実行順序が未定義。
- FAIL — `INTEGRATION-IDENTIFIED` (Major): `## External Integrations` は
  各 runtime の hook descriptor format / API / SDK version と、各 runtime/hook
  interface が利用できない場合の failure behavior を特定していない。

## Proposed Changes

`specs/sdd-context/design.md` に次の修正を加える。

1. `## API / Contract Plan` に hook イベントごとの input/output schema を追加する。
   - `PreCompact`: input `source`、optional `auto_compaction`
   - `SessionStart`: input `source: "compact"`
   - `PostCompact`: `compact_summary?` は非消費
   - 既存 endpoint の deprecated / breaking change がないことを明記する。
2. 技術選択（単一決定論的 Node core、sh/PowerShell wrapper、triple-manifest
   discovery）の理由を追記するか、既存 ADR 参照を具体化する。
3. `investigation.md` を追加するか、`requirements.md` の assumptions を
   根拠付きにして、`INV-xxx` 参照または明示的な受容リスクを示す。
4. `## Deployment / CI Plan` に対象環境、feature-flag 方針、具体的な CI
   pipeline 変更、migration 判断を追記する。
5. `## External Integrations` に各 runtime の hook descriptor format / API /
   SDK version と failure behavior を追記する。

## Next Steps

1. 人間が `specs/sdd-context/design.md` を上記の proposed changes に沿って編集する。
2. `--edit-summary "<編集内容の要約>"` を付けて round-2 を再実行する。
3. `Impl-Review-Status` は手動で変更しない。PASS 判定時のみ state machine が更新する。
