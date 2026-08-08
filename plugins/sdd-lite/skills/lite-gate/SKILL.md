---
name: lite-gate
description: Lightweight deterministic quality gate for the sdd-lite flow. Runs placeholder-scan and the project's lint/typecheck/build/test commands, writes a lite quality report, moves the task to Done, then validates the final Done state with check-task-state-lite. Use after implement-task in the lite flow.
disable-model-invocation: true
user-invocable: false
---

# Lite Gate

sdd-lite の軽量品質ゲート。実装者の自己申告でなく、ゲート自身が検証コマンドを再実行して結果を記録する（自己採点防止の核を低コストで維持）。evidence-bundle / contract.json / cross-model / 署名は扱わない。

## Invocation

Codex:

```txt
Use the lite-gate skill for specs/<feature>/tasks.md#T-001
```

Claude Code:

```txt
/sdd-lite:lite-gate specs/<feature>/tasks.md#T-001
```

## Preconditions

- 対象タスクが `Status: Implementation Complete` かつ `Approval: Approved`。
- `reports/implementation/<task-id>.md` が存在する。
- 望ましくは別コンテキスト/別セッション（または委譲）で実行し、実装者の主張を独立に再検証する。

## Track Detection

本スキルはトラック選択を読む Capability Mode 関連のエントリポイントである。
lite ゲートとして実行してよいか、full quality-gate に切り替えるべきかは、
ここで解決したトラックが決める。まず hook-activation ハンドシェイクを実行する:

<!-- sdd:handshake-wiring v1 -->

1. `check-hook-activation-handshake --emit-challenge` — 新しい nonce と
   カナリア対象 `sdd/.hook-canary-sentinel` を返す。
2. エージェント自身が、チャレンジに含まれるランタイム別テンプレートを用いて
   そのカナリア対象への**実際の**ツール呼び出しを試み、生の結果をそのまま記録する。
3. `check-hook-activation-handshake --verify-response --nonce <nonce>
   --recorded-result <path> --runtime <claude-code|codex-cli|copilot-cli>`。
4. `HOOK_ACTIVE` なら続行。それ以外の結果はすべて
   `CAPABILITY_RUNTIME_UNAVAILABLE` で停止する。レガシー動作へ黙って
   フォールバックしない。

<!-- /sdd:handshake-wiring -->

次にトラックを解決する。**物理的存在の確認が先、承認検証が後**である。
`sdd/project-context.yaml` が存在するのに `validate-approval-sidecar` に
失敗する状態は、ファイルが存在しない状態とは**別物**として扱う。両者を同一
視することが ADR-0023 の塞ぐ fail-open である。

<!-- sdd:track-selection-contract v1 -->

| Case | Project Context | Flag | Resolution |
|---|---|---|---|
| C1 | physically absent | `--full`, `--lite`, or none | `COMPATIBILITY_FALLBACK` |
| C2 | physically present, REQ-005 validation fails | `--full`, `--lite`, or none | `PROJECT_CONTEXT_INVALID` |
| C3 | physically present and valid, `spec_profile: lite` | `--full` | `PROMOTE_FULL` |
| C4 | physically present and valid, `spec_profile: lite` | `--lite` | `NO_OP_LITE` |
| C5 | physically present and valid, `spec_profile: full` | `--lite` | `ERROR_STOP` |
| C6 | physically present and valid, `spec_profile: full` | `--full` | `NO_OP_FULL` |

<!-- /sdd:track-selection-contract -->

- `COMPATIBILITY_FALLBACK`（C1 のみ）— 従来の優先順位（`--lite` → lite、
  `AGENTS.md` の `spec_profile: lite` → lite、既定 → full）をそのまま適用する。
- `PROJECT_CONTEXT_INVALID`（C2）— その名前を報告して停止する。品質レポートを
  生成せず、`Status` も変更せず、C1 のフォールバックへ落とさない。
- `PROMOTE_FULL` / `NO_OP_FULL` — 解決トラックは `full`。本スキルは実行せず、
  full quality-gate に切り替える。
- `NO_OP_LITE` — 解決トラックは `lite`。以下の Process を実行する。
- `ERROR_STOP` — 明示的なエラーで停止する。`--lite` が `full` プロファイルを
  格下げすることは決してない。

この表の正本は `PLUGIN-CONTRACTS.md` の Track Detection セクションである。

## Process

> **順序が重要**: `check-task-state-lite` の `Done` 専用検証（実装レポート + 品質レポート `VERDICT: PASS` の存在）は、品質レポートを生成し `Status: Done` に遷移した**後**に実行する。先に実行すると（タスクがまだ `Implementation Complete` でレポート未生成のため）Done 専用検証が一度も実走せず、不正・別タスク向けの PASS レポートでも Done が残る。

1. 変更範囲に対し `plugins/sdd-quality-loop/scripts/check-placeholders.sh`（または `.ps1`）を実行。
2. プロジェクトの lint / typecheck / build / test コマンドを**自分で実行**し、出力を捕捉する（コマンドはプロジェクトの AGENTS.md / 設定から判定）。コマンドが無い種別は「N/A」と記録し理由を添える。

2a. **`full_upgrade_required` バックストップ**（epic-194-a6-lite-integration T-004, REQ-003, Blocker [B2]/[B6]）:
   a. Project Context の `workflow.capability_enforcement` を読む（存在すれば）。これは単純な参照であり、A3 自身の三値ロジックの再導出ではない。
   b. Project Context が全く存在しない場合（disabled-legacy）: `capability-summary.yaml` が無いのは正当。`required_lite_checks = []` とし、空リストのまま Step 2b へ進む。
   c. それ以外（`capability_enforcement` が advisory または required）:
      - `specs/<feature>/capability-summary.yaml` を探す。
      - **無い場合** → 本タスクの `VERDICT: FAIL`、理由「capability-summary.yaml missing under active capability_enforcement」（Blocker [B6] — アクティブな enforcement 下で正当に解決された Lite Feature は必ず Summary を生成している）。`disabled-legacy` の場合（b）とは明確に区別する。
      - **ある場合** → `contracts/capability-summary.schema.json` に対して A4/A5 所有のバリデータを呼んで検証する（このスキルが再実装することは決してない）。
        - 無効 → `VERDICT: FAIL`、理由=検証エラーの文言、`Status` は変更しない。
        - 有効 → `required_lite_checks = summary.required_lite_checks` とする。`summary.full_upgrade_required == true` なら `VERDICT: FAIL`、理由にこのフィールド名を明記し full ワークフローへ誘導する（Blocker [B2]、OQ-003 解決）。それ以外は続行。

2b. **Registry-sourced チェック実行**（Lite-check コマンド発見契約 — Blocker [B7]、位置は不変）: `required_lite_checks` の各 id について:
   - id が `placeholder` / `lint` / `typecheck` / `build` / `test`（既存 baseline 名）のいずれか → no-op。
   - それ以外で、下記「Lite-check コマンド発見契約」がコマンドを解決できる（新規） → それを Step 2 と同じ捕捉・記録規律で自己実行する。
   - 解決できない → `VERDICT: FAIL`、理由「`<id>`: required Lite check has no discoverable command」（Blocker [B7]、reversed — 未マップは決して `N/A` にしない。`N/A` は Step 2 既存の、Registry 由来ではないローカルコマンド欠如という規約専用のまま変わらない）。

### Lite-check コマンド発見契約（新規、Blocker [B7]、安全性強化 NEW-01）

既存5つの baseline 名以外の Registry-sourced な check-id について、`lite-gate` はまず id 自身の形を検証し、その後、固定・境界付き・移植可能な順序でのみ実行コマンドを解決する（逆順にせず、この順序を厳守する）:

0. **check-id 文法（NEW-01）**: id は `^[a-z0-9][a-z0-9-]*$` に一致しなければならない。この文法チェックは fail-closed で独立に3箇所（`contracts/lite-check-catalog.json` 自身のスキーマ、Registry の `lite_policy.required_lite_checks[]` 自身のスキーマ、そして `lite-gate` 自身が Step 2b の各 id ループ直前に再検証）で強制される — 上流の検証が正しく実行されたかどうかに関わらない。一致しない id は `VERDICT: FAIL`、理由「`<id>`: check-id does not match the required `^[a-z0-9][a-z0-9-]*$` grammar」とし、発見処理が試みられる**前に**ブロックする。決してパスセグメントとして後続へ渡さない。
1. リポジトリルートの `package.json`（存在する場合）で `scripts[<id>]` キーが存在する → そのエコシステム自身のクロスランタイム・スクリプト起動（`npm run <id>` 相当。argv-direct — `id` はパッケージマネージャのスクリプト名引数へのリテラル引数として渡し、シェル文字列へは決して補間しない）で実行する。
2. リポジトリルートの `scripts/<id>.sh`（POSIX ランタイム）/ `scripts/<id>.ps1`（Windows ランタイム）— 以下すべての安全規則のもとで解決・起動する（NEW-01）:
   - 候補パスは、文法検証済み（ステップ0）の `id` を固定の `scripts/` セグメントへ結合して構築する。他のパス構成要素は呼び出し側にも Registry にも制御させない。
   - 解決後のパスを正規化し（シンボリックリンク・`..`・`.` を解決）、ファイルに触れる**前**に、正規化後のパスの接頭辞が正規化済みリポジトリルートの `scripts/` ディレクトリのままであることを証明する。`scripts/` から脱出する解決は、どのように構築されたものであっても「未発見」と同一に扱い、決して実行しない。
   - 解決されたパスは**通常ファイル**でなければならない。そのパスにあるシンボリックリンクやリパースポイント（それ自体が `scripts/` 内へ解決される場合も含む)は同様に拒否する。
   - 選択されたスクリプトは、そのパス自身をインタプリタへの直接 argv 要素として渡して起動する（例: `sh scripts/<id>.sh` / `pwsh -File scripts/<id>.ps1`）。補間されたシェルコマンド文字列としては決して構築しない。
   - **「pair」とは両方のランタイムメンバーを意味する**: ある check-id がこのステップで**マップ済み**とみなされるのは、`scripts/<id>.sh` **と** `scripts/<id>.ps1` の**両方**が存在し、上記の封じ込め・通常ファイル規則を通過した場合のみである。どちらか一方のランタイムメンバーしか存在しないリポジトリは、その id を全くマップしていない。id が `required` であれば、これはどちらのメンバーも存在しない場合と同じく `VERDICT: FAIL` である。
3. ステップ1・2のいずれも解決しない → **未マップ**（Step 2b が上記で FAIL の帰結を述べる）。

この契約は境界付き（文法チェック1つ + 固定・チェックイン済みの2箇所のみで、無制限の探索は行わない）であり、構造上パストラバーサル・シンボリックリンク/リパースポイント脱出・シェル補間に対して fail-closed であり（NEW-01）、移植可能（OS 固有のみの探索を行わず、デュアルランタイム・ペアリング規則はどのランタイムが実行中かに関わらず同一に適用される）— evidence-bundle / cross-model / 二者承認機構を一切追加しない（ADR-0022 item 4 自身の境界、不変）。

3. `reports/quality-gate/<task-id>.md` を `templates/quality-report-lite.md` から生成する。先頭に `Task ID: <task-id>` と `VERDICT: PASS|FAIL` を必ず置く（`check-task-state-lite` の Done 判定が依存）。各チェックの PASS/FAIL と根拠を列挙する。Step 1/2/2a/2b のいずれかに1つでも FAIL があれば（Step 2 自身の既存規約による `N/A` を除く）`VERDICT: FAIL` を記録し、`Status` は変えず実装者へ差し戻して終了する。
4. `VERDICT: PASS` のときのみ `tasks.md` の対象タスクを `Status: Done` にする。
5. **最終検証**: Done 化と品質レポート生成の**後**に `plugins/sdd-lite/scripts/check-task-state-lite.sh`（または `.ps1`）を実行し、`Done` 状態を決定論的に検証する（実装レポートのタスク ID 言及 + 品質レポートの `VERDICT: PASS` 言及を含む Done 専用チェックがここで初めて実走する）。失敗したら `Status` を `Implementation Complete` に戻し、レポートに失敗理由を記録して差し戻す（`Done` のまま残さない）。

## Boundaries

- evidence-bundle / contract.json / cross-model-verify / 二者承認 / リスク階層強制は行わない（昇格時は full quality-gate に切替）。
- `Approval` を変更しない（人間のみ）。
- Done は本スキルのみが設定する（implement-task は設定しない）。
- `required_lite_checks` を Capability 横断で再集約しない（epic-194-a6-lite-integration T-004, REQ-003/REQ-004）— A5 の Resolver が既に書いた、単一の集約済みフィールドを読むだけであり、Predicate-DSL / Registry-matching ロジック自体は実装しない。
- `contracts/capability-summary.schema.json` 自体は編集しない（A4 所有、内容凍結）— このスキルは A4/A5 所有のバリデータを呼び出すだけで、検証ロジックを再実装しない。

## Handoff

VERDICT と各チェック結果、Done 化の有無を報告する。FAIL 時は不足点を明示し implement-task への差し戻しを案内する。
