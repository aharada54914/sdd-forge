# UX Specification: sdd-domain-concept-test

Status: Draft

## Scope and User Journeys

利用者はbootstrapを実行する開発者と概念判断をする人間。既存bootstrap intakeから提案・根拠を読み、same/different/undecidedとdecisionを確認してfeature証跡へ残す (REQ-001/002, AC-008/011)。新GUI・route・responsive layout・design tokenはN/A — no change: text skill workflow。

## Component States

domain不在:従来skip (AC-010)。提案生成済み:人間確認待ち (AC-008)。decision欠如:証跡ゲートBLOCKと不足箇所を示す (AC-002〜005)。有効記録:gate通過 (AC-006/007)、後続生成の扱いはOQ-002。不正記録:修正対象を示す (AC-014)。

## Accessibility

提案・根拠・未確定事項はテキストで区別し、色や図だけに依存しない。GUI WCAG/breakpointはN/A — no change。

## Open Questions

OQ-002: ownerはrepository owner、decision後のUX確定が必要。

OQ-003 (non-blocking, resolved observation): 現入力に視覚資料なし。No mockup provided — optional visualization skipped。非GUI skillのためGUIやmockupを追加しない。
