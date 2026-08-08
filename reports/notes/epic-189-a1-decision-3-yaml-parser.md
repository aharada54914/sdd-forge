# Decision record: epic-189-a1 判断3 — canonicalizer YAML パーサー依存

**Date**: 2026-07-24
**Decider**: human (repository owner)
**Verbatim answer**: 「B で」
**Question presented (判断3)**: `canonicalize-sdd-yaml` (T-002, REQ-003) の
YAML パースを、(a) PyYAML/ruamel.yaml をこのツール初の第三者 Python 依存と
して導入する、(b) design.md を改訂して手書きパーサーを認可する、(c) その他、
のいずれで解決するか。T-002 実装セッションが 2026-07-22 に Blocked 起票
(tasks.md T-002 Blockers 節、commit `1018c10b`): design.md 旧 Design
Decisions は「標準ライブラリ (PyYAML / ruamel.yaml、将来の実装セッションで
利用可能と確認)」を選んでいたが、実環境にはどちらも存在せず、リポジトリは
requirements.txt / pyproject.toml を一切持たず、既存 `.py` は全て stdlib
のみに依存する。

## Decision (選択肢 B)

`project-context.yaml` のパースは外部 YAML ライブラリ (PyYAML 等) を導入
せず、**制限付きサブセットの手書きパーサー**で実装する。

- project-context.yaml が実際に使う構文サブセットのみ受理し、範囲外構文は
  明示的に拒否する (fail-closed、best-effort 解釈をしない)。
- bash/jq 側と PowerShell 側の両ランタイムで同等挙動とする。
- `requirements.txt` 新設・配布/インストール設計の改訂は行わない。
- **A3 (epic-191) に同型のレビュー済み先例がある**ため、その設計記述を参照・
  踏襲する: `specs/epic-191-a3-path-ownership` T-001 の
  `plugins/sdd-quality-loop/scripts/resolve-component-paths.py`
  (commit `41881071`、impl-review Passed 済みパッケージ配下) が
  「Minimal restricted YAML-subset parser」を stdlib-only で実装し、
  `docs/adr/0025-component-path-ownership-resolver-semantics.md` が
  restricted-subset 哲学 (ADR-0020 の restricted-DSL 系譜) と
  「先頭シジルはクォート必須」等の帰結を記録している。A3 の rationale
  逐語 (resolve-component-paths.py docstring):
  "This module must NOT import from outside the standard library so it
  runs in any Python 3.6+ environment without additional packages — this
  repository's CI installs no Python packages for its gate scripts
  (check-contract.py sets the same precedent), so a YAML library such as
  PyYAML is unavailable."

## Scope

- design.md の Design Decisions (パーサー選択) と Canonicalization
  procedure の該当記述を、制限付きサブセットパーサーに固定する記述へ改訂
  する。受理サブセットの明示的定義・範囲外構文検出時の明示エラー・両
  ランタイム同等性・A3 先例参照を含める。
- requirements.md / acceptance-tests.md への波及は必要最小限 (不要なら
  触らない)。
- design.md は Impl-Review-Status: Passed のため、改訂は
  `plugins/sdd-review-loop` の規定手続き (impl-review amendment) を経て
  再レビューする。
- T-001 の staging-only Blocked (判断1) はこの決定の対象外 — 触らない。

## Unblocks

T-002 (canonicalizer) の実装再開、および T-002 を transitively 待っていた
T-003 / T-005 / T-006..T-010 / T-012 のチェーン。
