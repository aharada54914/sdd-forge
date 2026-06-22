# Investigation: sdd-forge-refactor

Source: 2026-06-21 architecture audit of sdd-forge post-v0.15.0 (2-command
consolidation). Findings were produced by a 3-round dual-reviewer analysis
(Reviewers A and B × 3 rounds). Each claim references the exact file and line
number in the codebase. This file formalizes the audit as INV findings so
requirements stay traceable to evidence.

## Context: v0.15.0 で確立した基盤（MUST NOT regress）

v0.15.0 で `/sdd-bootstrap` と `/sdd-ship` の2コマンド化が完了した。
この基盤は変更せず、内部構造の整理のみを行う。

| ID | 確立済み強み | Evidence |
|----|-----------|----------|
| STR-001 | 2コマンドエントリポイント: `/sdd-bootstrap` + `/sdd-ship` | `plugins/sdd-ship/skills/sdd-ship/SKILL.md` |
| STR-002 | 薄いオーケストレーター: sdd-ship は内部スキルに委譲するのみ | `PLUGIN-CONTRACTS.md` §sdd-ship |
| STR-003 | フックガード自己保護: PROTECTED_GATE_SUFFIXES で gate ファイルを保護 | `plugins/sdd-quality-loop/scripts/sdd-hook-guard.js:148-156` |
| STR-004 | 承認ガード: エージェントが `Approval: Approved` を自己設定できない | `sdd-hook-guard.js:Check 1` |
| STR-005 | Impl-Review-Status ガード (JS): 有効 verdict なしの `Impl-Review-Status: Passed` 書き込みをブロック | `sdd-hook-guard.js:L1086 implReviewStatusPassedIncreases` |

## Findings（v0.15.0 後の技術的負債）

| ID | Finding | Severity | 証拠 |
|----|---------|----------|------|
| INV-001 | `sdd-impl-review` と `sdd-task-review` が独立プラグインとして存在するが、構造が並列で共有するインフラが多い。SKILL.md 475行のほぼ同一ロジックが2ファイルに分散。 | Medium | `plugins/sdd-impl-review/skills/impl-review-loop/SKILL.md`(248行); `plugins/sdd-task-review/skills/task-review-loop/SKILL.md`(227行) |
| INV-002 | Python ガードに Check 2e（Impl-Review-Status: Passed 検証）が完全不在。JS ガードとパリティギャップが存在する。 | High | `sdd-hook-guard.py:L974`（Check 2d 後に Check 2e がなく直接 Check 3 へ）; `sdd-hook-guard.js:L1086` に対応関数あり |
| INV-003 | `validate-repository.ps1` の `$expectedSkills` が 15 件だが実際の SKILL.md は 17 ファイル存在する（`sdd-bootstrap` と `sdd-ship` が未登録）。既存の CI 検証が常に失敗する状態。 | High | `tests/validate-repository.ps1:L6`（$expectedSkills 15件）; glob で確認した SKILL.md 実数 17件 |
| INV-004 | `sdd-impl-review` と `sdd-task-review` が marketplace.json に未登録だが、PROTECTED_GATE_SUFFIXES には 6 パスとして登録されている。プラグイン登録と保護の基準が不整合。 | Medium | `.claude-plugin/marketplace.json`（両プラグイン不在）; `sdd-hook-guard.js:L148-153`（両プラグインのパス保護あり） |
| INV-005 | `sdd-bootstrap/SKILL.md` と `sdd-bootstrap-interviewer/SKILL.md` が旧プラグイン名を直接参照している。`sdd-bootstrap/SKILL.md` は完全修飾名、`sdd-bootstrap-interviewer/SKILL.md` はベア名（サイレント no-op リスク）で呼び出す。 | High | `sdd-bootstrap/SKILL.md:L88,L99`; `sdd-bootstrap-interviewer/SKILL.md:L105,L111,L118,L119,L145,L150` |
| INV-006 | `docs/skill-reference.md` (1374行) と `docs/workflow-guide.md` (998行) がユーザー向けと内部開発者向けの情報を混在させており、2コマンド化後のユーザーモデルと乖離している。 | Medium | `docs/skill-reference.md:L3`（7プラグイン全列挙）; `docs/workflow-guide.md:L31-45`（内部スキル詳細） |
| INV-007 | PS1 ガードに R-10（PROTECTED_GATE_SUFFIXES）と Check 2e が未実装。Windows 環境で reviewer ファイルとゲートファイルが無保護。 | Medium | `sdd-hook-guard.ps1`（R-10 セクション不在を確認） |
| INV-008 | `review-loop` 系の参照ポリシードキュメント（impl-review-checklist.md / task-review-checklist.md）が並列構造で維持コストが高い。 | Low | `sdd-impl-review/references/impl-review-checklist.md`(388行); `sdd-task-review/references/task-review-checklist.md`(465行) |

## Out of investigation scope

- PS1 ガードへの R-10 / Check 2e 追加（INV-007）— 本リファクタリングでは対処しない。別 issue として追跡。
- `docs/workflow-guide.md` の Mermaid 図の全面改訂 — ベア skill 名を使っているため実際にはリファクタリング後も変更不要。
