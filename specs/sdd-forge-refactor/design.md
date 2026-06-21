# Design: sdd-forge-refactor

Impl-Review-Status: Passed

## Architecture Decision

### ADR-001: プラグイン移動（統合ではなく移動）

**決定**: `sdd-impl-review` と `sdd-task-review` を単一の `sdd-review-loop` プラグインに
「移動」する。2スキルを1スキルに「マージ」（`--phase impl|task` フラグ化）はしない。

**理由**:
- 2スキルには異なる precheck スクリプト（`impl-review-precheck.sh` vs
  `task-review-precheck.sh`）、異なるレポートパス、異なるステータスヘッダー書き込み先、
  異なる LITE-SKIP 条件があり、強制統合すると実装ミスのリスクが高い。
- プラグインディレクトリをまとめるだけで、ファイル間 DRY の恩恵（references 統合）を
  得ながら、各スキルの独立性を保てる。

**却下した代替案**: `--phase impl|task` フラグによる1スキル統合（Round 1 の当初案）。
3ラウンドレビューで分岐複雑度が高すぎると判明し却下。

### ADR-002: 旧プラグインディレクトリの完全削除（stub なし）

**決定**: `plugins/sdd-impl-review/` と `plugins/sdd-task-review/` を完全削除する。

**理由**:
- stub SKILL.md を残した場合、`validate-repository.ps1` が stub の `name:` フィールドを
  カウントしてスキル数不整合エラーを起こす。`name:` を省略すれば "Skill has no name" エラー。
  どちらも CI を壊す。
- 呼び出し元（`sdd-bootstrap/SKILL.md`、`sdd-bootstrap-interviewer/SKILL.md`）を新パスに
  更新するため、後方互換シムは不要。

**前提**: caller の更新が完了してから旧ディレクトリを削除する。ガード更新→新プラグイン作成
→caller 更新→旧プラグイン削除→ガード後処理 の順序を厳守。

### ADR-003: PROTECTED_GATE_SUFFIXES の更新戦略

**決定**: 旧6パスを追加し（削除前）、新6パスを追加し、旧プラグイン削除後に旧6パスを削除する。
削除中の保護空白期間をゼロにする。

**保護対象の範囲（明示）**: 保護するのはセキュリティ強制チェーンのファイルのみ:
- agent ファイル（reviewer-a.md, reviewer-b.md）: レビュアーロジックを保護
- SKILL.md ファイル: オーケストレーターロジックを保護

`scripts/`（precheck スクリプト）と `templates/`（レポートテンプレート）は
**意図的に保護しない**。旧プラグイン（`sdd-impl-review`、`sdd-task-review`）でも
これらは PROTECTED_GATE_SUFFIXES に含まれておらず、移行後も同じ方針を維持する。
precheck スクリプトはガードによって「使用」されるが、エージェントが修正しても
即時のセキュリティバイパスにはならない（verdict の検証ロジックは SKILL.md と agent に存在する）。

**重要制約**: ガードファイル自身が PROTECTED_GATE_SUFFIXES に含まれるため、
エージェントは通常セッションでガードファイルを更新できない。**human/sudo セッション必須。**

### ADR-004: Python ガード Check 2e の path 解決方式

**決定**: `os.listdir('reports/impl-review/' + feature)` — bare relative path（CWD 基準）。

**理由**: JS 版（`fs.readdirSync('reports/impl-review/' + feature)`）と同じ CWD 基準を使う。
`_resolve_project_root()` を使うと JS との CWD 解決方式が異なりパリティが崩壊する。

### ADR-005: sdd-review-loop を marketplace.json に登録しない（廃止）

**決定**: `sdd-impl-review`・`sdd-task-review` が marketplace.json に未登録であったように、
`sdd-review-loop` も未登録を維持する。

**理由**: これらは内部プラグインであり、global skill scan（validate-repository.ps1）
で検出される。marketplace への追加は plugin.json manifest 作成を必要とし、
スコープ外の追加コストが生じる。

**状態**: ADR-006 により廃止。review-loop を呼ぶ `sdd-bootstrap` が marketplace
登録なしでは新規インストールで実行不能になるため、内部であることは未登録の根拠にならない。

### ADR-006: sdd-review-loop を内部依存として配布・登録する

**決定**: `sdd-review-loop` に Claude/Codex/Copilot の manifest を追加し、両 marketplace
に `[internal]` として登録する。installer は dependency closure を固定点まで展開する。

**理由**: bootstrap → review-loop、lite → bootstrap → review-loop、ship → 全内部
依存という実行時依存を、クリーン環境でも確実に満たすためである。

**ローカル入力の安全性**: `--source-directory` は Git worktree root に限り、`git ls-files`
で得た追跡ファイルのみを staging する。これにより root・入れ子双方の未追跡秘密情報や
キャッシュが配布ツリーへ混入しない。

---

## Directory Structure（変更後）

```
plugins/
├── sdd-bootstrap/          ← 変更: sdd-bootstrap/SKILL.md L88/L99 を更新
├── sdd-ship/               ← 変更なし
├── sdd-implementation/     ← 小変更: Caller ヘッダー追加
├── sdd-quality-loop/       ← 変更: hook-guard.py に Check 2e 追加（human/sudo）
├── sdd-lite/               ← 変更なし
├── sdd-review-loop/        ← 新規作成・internal marketplace 登録（impl-review + task-review から移植）
│   ├── .claude-plugin/plugin.json
│   ├── .codex-plugin/plugin.json
│   ├── .plugin/plugin.json
│   ├── skills/
│   │   ├── impl-review-loop/SKILL.md  ← パス参照を sdd-review-loop に更新
│   │   └── task-review-loop/SKILL.md  ← パス参照を sdd-review-loop に更新
│   ├── agents/
│   │   ├── impl-reviewer-a.md
│   │   ├── impl-reviewer-b.md
│   │   ├── task-reviewer-a.md
│   │   └── task-reviewer-b.md
│   ├── scripts/                       ← 新規（旧プラグインから移植）
│   │   ├── impl-review-precheck.sh    ← sdd-impl-review/scripts/ から移動
│   │   └── task-review-precheck.sh    ← sdd-task-review/scripts/ から移動
│   ├── templates/                     ← 新規（旧プラグインから移植）
│   │   ├── impl-review-contract.template.json   ← sdd-impl-review/templates/ から移動
│   │   ├── impl-review-report.template.md       ← sdd-impl-review/templates/ から移動
│   │   ├── task-review-contract.template.json   ← sdd-task-review/templates/ から移動
│   │   └── task-review-report.template.md       ← sdd-task-review/templates/ から移動
│   └── references/
│       └── phase-review-checklist.md  (impl + task を統合)
├── sdd-impl-review/        ← 削除（T-002 Phase 4）
└── sdd-task-review/        ← 削除（T-002 Phase 4）
```

---

## Hook Guard 更新計画（PROTECTED_GATE_SUFFIXES）

### 追加する6パス（T-002 Phase 1 で human/sudo 実施）

```
plugins/sdd-review-loop/agents/impl-reviewer-a.md
plugins/sdd-review-loop/agents/impl-reviewer-b.md
plugins/sdd-review-loop/agents/task-reviewer-a.md
plugins/sdd-review-loop/agents/task-reviewer-b.md
plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md
plugins/sdd-review-loop/skills/task-review-loop/SKILL.md
```

### 削除する6パス（T-002 Phase 5 で human/sudo 実施）

```
plugins/sdd-impl-review/agents/impl-reviewer-a.md
plugins/sdd-impl-review/agents/impl-reviewer-b.md
plugins/sdd-task-review/agents/task-reviewer-a.md
plugins/sdd-task-review/agents/task-reviewer-b.md
plugins/sdd-impl-review/skills/impl-review-loop/SKILL.md
plugins/sdd-task-review/skills/task-review-loop/SKILL.md
```

### Python Check 2e 追加仕様

```python
# sdd-hook-guard.py の Check 2d 末尾（L973 付近）の後に挿入
# JS の implReviewVerdictExists に対応する Python 実装:

def _impl_review_verdict_exists(feature: str) -> bool:
    """CWD-relative path resolution (matches JS behavior)."""
    import glob as _glob
    import json as _json
    pattern = f"reports/impl-review/{feature}/attempt-*/round-*/integrated-verdict.json"
    for f in _glob.glob(pattern):
        try:
            with open(f) as fh:
                data = _json.load(fh)
            if data.get("verdict") in ("PASS", "PASS-with-warnings"):
                return True
        except Exception:
            pass
    return False

# Check 2e: implReviewStatusPassedIncreases
# 条件: specs/<feature>/design.md への書き込みで Impl-Review-Status: Passed が新規出現
# 　    かつ integrated-verdict.json が存在しないまたは PASS でない場合は deny
```

---

## ドキュメント再構成計画

### `docs/skill-reference.md` (1374行 → ~500行)

- Part 1（ユーザー向け）: `/sdd-bootstrap` と `/sdd-ship` のフラグ・起動形式・トラック検出
- Part 2（コントリビューター向け）: `docs/contributor/skill-reference-detail.md` に移動

更新が必要な行:
- L3: プラグイン数 7 → 6、`sdd-impl-review`/`sdd-task-review` → `sdd-review-loop`
- L16-17: skill テーブルの「所属プラグイン」列
- L786-788: 呼び出し例 `/sdd-impl-review:impl-review-loop` → `/sdd-review-loop:impl-review-loop`
- L851-853: 呼び出し例 `/sdd-task-review:task-review-loop` → `/sdd-review-loop:task-review-loop`

### `docs/workflow-guide.md` (998行 → ~400行)

- Quick Reference を冒頭に固定（変更済み）
- フルトラック詳細を `docs/contributor/workflow-detail.md` に移動
- Mermaid 図はスキル名がベア名のため変更不要

### `plugins/sdd-quality-loop/references/wfi-category-guide.md`

- forbidden terms に `sdd-review-loop` を追記（既存エントリは変更しない）

---

## SKILL.md パス参照更新（T-002 Phase 2 必須）

旧 SKILL.md は plugin-local パスを hardcode している:
- `impl-review-loop/SKILL.md`: `plugins/sdd-impl-review/scripts/impl-review-precheck.sh`、
  `plugins/sdd-impl-review/templates/impl-review-contract.template.json`、
  `plugins/sdd-impl-review/templates/impl-review-report.template.md`
- `task-review-loop/SKILL.md`: `plugins/sdd-task-review/scripts/task-review-precheck.sh`、
  `plugins/sdd-task-review/templates/task-review-contract.template.json`、
  `plugins/sdd-task-review/templates/task-review-report.template.md`

**Phase 2 の「移植」はファイルコピーだけでなく、これら6パスの書き換えを含む**:
- `plugins/sdd-impl-review/scripts/` → `plugins/sdd-review-loop/scripts/`
- `plugins/sdd-impl-review/templates/` → `plugins/sdd-review-loop/templates/`
- `plugins/sdd-task-review/scripts/` → `plugins/sdd-review-loop/scripts/`
- `plugins/sdd-task-review/templates/` → `plugins/sdd-review-loop/templates/`

---

## Migration & backward compatibility

- `impl-review-loop`・`task-review-loop` のスキル名は維持されるが、呼び出し namespace は
  `/sdd-review-loop:*` に変更される。旧 `/sdd-impl-review:*` と `/sdd-task-review:*` alias は提供しない。
- レポートパス `reports/impl-review/`・`reports/task-review/` は移行後も同一。
  `implReviewVerdictExists` の path は変更不要。
- sdd-ship・quality-gate・implement-tasks の動作は一切変わらない。
- `validate-repository.ps1` の `$expectedVersion` (`0.14.0`) は変更しない（非目標）。
  バージョン番号の更新は別 issue で追跡する。
