# ADR-0010 ループ状態機械の唯一のレジストリとして機械可読ループインベントリを採用し、fixture-profile 語彙 greenfield/brownfield と cap_source 軸を定義する

## Status

Proposed(人間承認待ち — epic #159 Pillar A の spec 承認と併行。Issue #141 /
#125 の語彙契約に関わる決定)

## Context

リポジトリには 8 つのレビュー/ゲートループが存在する: スクリプト強制の 6 つ
(spec-review / impl-review / task-review / domain-review / quality-gate /
terminal-tier — INV-001)と、スキル指示のみで強制される 2 つ(wfi-audit の
Audit-Attempt >= 3、hitl-diagnosis の上限 5 — INV-004)。各ループの上限
(cap)・終端状態・成果物スキーマ・cross-gate は precheck ソースやスキル文面に
散在し、機械可読な台帳が無い。その帰結として:

1. 新しいループを追加しても何も赤にならず、検証漏れが構造的に起き得る
   (impl-review round>1 のゲート矛盾 #143 が実例 — 2d8c6a5 で修正済みだが、
   同クラスのバグを恒久検出する仕組みが無い)。
2. cap がソース側で変わっても(例: round<=3 が round<=2 に縮む)、それを
   照合する対象が無く、enforcement の無言の縮小を検出できない。
3. #125(workflow-scenarios ハーネス)が別途 fixture 語彙を発明すると、
   ループハーネスとシナリオハーネスで互換性の無い二重語彙が生まれる
   (epic #159 は語彙整合・重複実装禁止を明記)。
4. スキル指示強制のループ(wfi-audit / hitl)は driver スクリプトを持たない
   ため、登録強制テストが「driver 必須」を前提にすると誤検出(false red)
   するか、除外すると登録漏れ(false green)する(OQ-1)。

既存語彙との関係: workflow-state registry の profile は "lite"|"full" であり
(INV-019、task-review-precheck.sh:245-247)、これはワークフロー追跡の深さを
表す。ハーネスが必要とするのは「fixture をどう構築するか」の軸であり、両者は
直交する。

## Decision

1. **`tests/loops/loop-inventory.json`(schema `loop-inventory/v1`)を、
   ループ状態機械の唯一の機械可読レジストリとする。** エントリは
   `id / kind / cap / cap_source / driver_scripts / cross_gates /
   artifact_schemas / terminal / fixture_profiles` を持つ(全文スキーマは
   specs/epic-159-pillar-a/design.md「API / Contract Plan」が正準)。
   登録強制テスト(tests/loop-inventory.tests.sh/.ps1)がリポジトリから
   ループ面を導出してインベントリと双方向に突合し、未登録ループ・cap ドリフト
   を CI で赤にする。インベントリはレビュー対象アーティファクトであり、
   ソースとインベントリの片側だけの変更は必ず赤になる(ADR-0009 の
   「両者同時更新」パターンを踏襲)。
2. **fixture-profile 語彙を閉集合 `greenfield` | `brownfield` と定義する。**
   greenfield = mktemp 上でゼロから合成する fixture、brownfield = 既存
   成果物 seed からコピー初期化する fixture(正準 seed は A6/#146 が提供)。
   registry の "lite"|"full" とは直交。**#125(workflow-scenarios)の
   シナリオスキーマはこの識別子をそのまま採用しなければならない**(epic #159
   の語彙整合要件の具体化)。語彙の拡張は本 ADR の改訂として行い、場当たり的な
   追加を禁止する。
3. **`cap_source` 軸(`script` | `skill-instruction`)を導入する。**
   `script` のエントリは cap 値が driver ソースから grep 照合されドリフトを
   赤にする。`skill-instruction`(wfi-audit / hitl-diagnosis)は
   `driver_scripts: []` を許容し grep 照合を免除するが、登録強制の対象には
   含める — スキル文面強制のループも台帳に載り、脱落しない(OQ-1 の解決)。
   **実装時 grep 実測(T-001, INV-003 の要求)により、impl-review /
   task-review の round<=3 上限も `impl-review-precheck.sh` /
   `task-review-precheck.sh`(いずれの `.sh`/`.ps1` にも)に数値ガードが
   存在せず、`impl-review-loop`/`task-review-loop` の SKILL.md 文面
   (「Runs up to three rounds」)でのみ強制されると判明した。両ループは
   `cap_source: skill-instruction` を取るが、`driver_scripts` は空にせず
   自身の precheck スクリプトを登録する(INV-002 の登録要件は cap_source
   と独立)。この軸は wfi-audit / hitl-diagnosis 専用ではなく、cap の実強制
   箇所がスキル文面かソースかを問う一般軸である。根拠は
   `reports/implementation/epic-159-pillar-a/T-001.md` の逸脱記録を参照。

## Consequences

- ループの追加・変更は必ずインベントリ更新を伴い、レビュー可能な 1 diff に
  収まる。登録漏れ・cap ドリフト・終端状態の食い違いは CI が検出する
  (「追加したが検証されないループ」を構造的に排除)。
- #125 実装者は fixture 語彙を発明せず本 ADR を参照する。ループハーネスと
  シナリオハーネスの fixture が同じ語彙で分類され、seed(#146)や
  リリースゲート(#148)が両者を同一軸で扱える。
- スキル指示強制ループが台帳に載ることで、将来それらをスクリプト強制へ移行
  する際(cap_source を script へ変える)も、変更点がインベントリ diff として
  可視化される。
- 制約: インベントリと driver ソースの二重管理コストが生じる。これは意図した
  コストであり(ドリフト検出のための独立した照合対象)、単一生成源への統合を
  行う場合は本 ADR の改訂を要する。
- 制約: `terminal` の照合は state(PASS / BLOCKED / Escalate-Human)の
  完全一致のみで、condition 文面は自由記述として照合外(過剰結合の回避)。
