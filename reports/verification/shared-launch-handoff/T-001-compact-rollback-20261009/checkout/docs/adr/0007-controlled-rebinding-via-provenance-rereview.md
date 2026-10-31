# ADR-0007 レビュー後アーティファクト更新の再バインドは「provenance 再レビュー(新 attempt)」で行い、バリデータには選択的再バインド機構を追加しない

## Status

Proposed(人間承認待ち — 品質ゲートの検証境界に関わる決定。Issue #86 / WFI-004 の
plugin-maintainer follow-up)

## Context

WFI-004(RT-20260705-001)で、full プロファイルの persisted-state 検証
(`plugins/sdd-quality-loop/scripts/check-workflow-state.sh`)が実装フェーズ後に
デッドロックする 5 つの矛盾が確認された。Issue #86 の第 4 項は「凍結
(freeze)と承認済みタスクスコープが矛盾しないよう、バリデータに sanctioned な
レビュー後アーティファクト更新(controlled re-binding)のサポートを検討する」
ことを求めている。

論点は 2 つの異なる問題が混在していることにある:

1. **アーティファクト内容の更新**: レビューゲート通過後に design.md /
   traceability.md 等の内容を更新したい(open-question 解決、verification-status
   確定など、レビューで承認されたタスクスコープ自体が要求する更新)。
2. **レビューエビデンスの再バインド**: エビデンススキーマのドリフトや不完全な
   レビュアーマニフェストにより、task ステージのレビューエビデンスを実装後に
   現行ハッシュへ束ね直したい。

## Decision

**バリデータ(check-workflow-state.sh / .ps1)は変更しない。** 2 つの問題は別々の
既存機構で解決し、それぞれを明文化する:

1. **アーティファクト内容の更新 → non-frozen addenda(AGENTS.md、WFI-004 で適用済み)**。
   ゲート通過後のアーティファクトは正規化された status/approval 行を除き
   content-frozen とし、sanctioned な後続更新は非凍結の付録記録
   (implementation report / `specs/<feature>/verification/` / ユーザー文書)に
   記録する。凍結アーティファクトを名指しする Done When は人間承認のもとで
   付録記録を指す文言に修正する。再発予防として task-reviewer-a の
   OBSERVABLE-DONE チェックに「凍結アーティファクトの編集を要求する Done When は
   Major finding」を追加した(本 Issue の変更)。
2. **エビデンスの再バインド → post-implementation provenance 再レビュー(新 attempt)**。
   バリデータは最新 attempt のコントラクトに束縛するため、完全なマニフェストと
   正準スキーマで新 attempt を実行すれば、チェック・ゲート・ハッシュ束縛を
   一切減らさずに再バインドが成立する(WFI-004 で exit 1 → 0 を実証済み)。
   デッドロックしていた入口(precheck の canonical workflow-state ゲート)には
   `--provenance-rereview` / `-ProvenanceRereview` モードを追加した:
   事前に persisted な task-review PASS 実績を要求し、緩和されるのは
   workflow-state ゲート 1 点のみ。他の precheck 検証は従来どおり。

**選択的再バインド(バリデータがハッシュ束縛の差し替えを直接受け付ける機構)を
却下する理由**:

- 凍結保証が弱まる。決定的ゲートに「束縛を書き換えられる経路」を作ると、
  エビデンス改変と正当な更新をバリデータ内で区別する承認メタデータ・監査
  ロジックが必要になり、攻撃面と複雑性が増える。
- WFI-004 の検証原則(「enforced checks / gates / hash bindings の削減ゼロ」)に
  反する。新 attempt 方式は既存の攻撃面のまま同じ効果を達成する。
- impl ゲートが束縛する design.md の内容変更は task ステージの再レビューでは
  救済できない(impl コントラクトが陳腐化する)。つまり選択的再バインドを
  導入しても問題 1 は解決せず、addenda 規則は依然必要 — 機構追加の便益が薄い。

## Consequences

- 凍結と承認済みタスクスコープの矛盾は、(a) 付録記録への Done When スコープ
  誘導(レビュー時に検出)と (b) provenance 再レビューによるエビデンス再バインド
  の 2 経路で解消され、バリデータの決定性は不変。
- provenance 再レビューの運用手順は task-review-loop SKILL.md の
  「Post-Implementation Provenance Re-Review」節が正準。INITIAL-STATE の
  lifecycle-validity 評価は task-reviewer-a のロールファイルに明記。
- レビュアー出力の正準スキーマ(reviewer A: `stage: "task-review"` /
  `role: "reviewer-a"` / `manifest` / `checks[].status`、reviewer B:
  `manifest.allowed_inputs` / `checks[].result`、両者 `findings` 配列)は
  ロールファイル側をバリデータに合わせて修正した。バリデータ側のスキーマ変更は
  行わない(既存の受理済みエビデンスを無効化しないため)。
