---
name: lite-spec
description: Lightweight SDD specification for internal/departmental apps. Creates requirements, design, and tasks (single-approval, no traceability/ADR/evidence-bundle). Use for low-stakes internal app work; graduate to sdd-bootstrap-interviewer for higher rigor.
disable-model-invocation: false
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

## Track Detection

本スキルは lite トラックを前提に呼ばれるが、その前提自体が Capability Mode
の解決結果に従う。よってここが本スキルの Capability Mode 関連エントリポイント
であり、Project Context の内容を信頼する前に、まず hook-activation
ハンドシェイクを実行する:

<!-- sdd:handshake-wiring v1 -->

1. `check-hook-activation-handshake --emit-challenge` — 新しい単回使用 nonce と
   カナリア対象 `sdd/.hook-canary-sentinel` を返す。前回の実行で残ったセンチネル
   があれば、まず1回だけクリーンアップを試み結果を記録する。新しいチャレンジは
   いずれにせよ発行される。
2. エージェント自身のセッションが、チャレンジに含まれるランタイム別テンプレート
   を用いてそのカナリア対象への**実際の**ツール呼び出しを試み、生の結果をその
   まま記録する。ツール自身がプローブ書き込みを行うことはない。
3. `check-hook-activation-handshake --verify-response --nonce <nonce>
   --recorded-result <path> --runtime <claude-code|codex-cli|copilot-cli>`。
4. `HOOK_ACTIVE` ならトラック解決へ進む。それ以外の結果が止めるのは
   **Capability Mode のみ**であり、どのプロジェクトが止まるかはこの手順単独
   ではなく下のゲート表が決める: Project Context が物理的に存在し、かつ妥当
   である場合に**限り** `CAPABILITY_RUNTIME_UNAVAILABLE` で停止する
   (ゲート G2)。物理的に存在しない場合、そのプロジェクトは Capability Mode
   に入ったことがないため、`DISABLED_LEGACY` として互換フォールバックを続行
   する (ゲート G3/G4)。妥当な Context を持つプロジェクトから、レガシー動作へ
   黙ってフォールバックしてはならない。

<!-- /sdd:handshake-wiring -->

**存在・妥当性プローブを実行する時点**: ハンドシェイク自身は Project Context
を読まないため、手順 4 の時点ではどのゲート行に当たるかはまだ確定していない。
G1/G2 と G3/G4 を分ける物理的存在・妥当性プローブは、下の「トラック解決」の
**最初の**手順であり、そこで実行する — ハンドシェイクの後、トラックを選ぶ前
である。本節がトラック解決より前に置かれているのはハンドシェイクの意味に関する
規範だからであって、プローブを前倒しせよという指示ではない。

### `HOOK_ACTIVE` でない場合に何が止まり、何が止まらないか

上の手順 4 が止めるのは **Capability Mode** であって、本スキルの呼び出し
すべてではない。どちらになるかは、そのプロジェクトが Capability Mode に
入っていたかどうかで決まる。次の表は**両方向とも**規範である:

<!-- sdd:capability-gate-scope v1 -->

| Gate | Project Context | Handshake | Resolution |
|---|---|---|---|
| G1 | physically present and valid | `HOOK_ACTIVE` | `CAPABILITY_MODE` |
| G2 | physically present and valid | not `HOOK_ACTIVE` | `CAPABILITY_RUNTIME_UNAVAILABLE` |
| G3 | physically absent | `HOOK_ACTIVE` | `DISABLED_LEGACY` |
| G4 | physically absent | not `HOOK_ACTIVE` | `DISABLED_LEGACY` |

<!-- /sdd:capability-gate-scope -->

- **G2 — 停止する。** 有効な Project Context を持つプロジェクトは Capability
  Mode に入っている。nonce 一致した本物の拒否を観測できなかったハンドシェイク
  は `CAPABILITY_RUNTIME_UNAVAILABLE` で停止しなければならず、下の互換フォール
  バック経路へ降格してはならない。その降格こそ ADR-0023 が塞ぐ silent
  downgrade である（`design.md:1112` — 呼び出し側スキルは **Capability Mode**
  を停止するのであって、黙ってレガシーへフォールバックしてはならない）。
- **G4 — 続行する。** Project Context を持たないプロジェクトは Capability Mode
  に一度も入っていない。ADR-0016 の `disabled-legacy` — 「Project Context を
  持たないプロジェクトにとって正常かつ想定内の状態であり、エラーではない」
  (`requirements.md:1821-1827`) — であり、`CAPABILITY_RUNTIME_UNAVAILABLE` とは
  「決して同一視されない」(`design.md:1734`)。ハンドシェイクが門番をするのは
  `HOOK_ACTIVE` で条件付けられた振る舞いだけである
  (`requirements.md:1078`) ため、`HOOK_ACTIVE` 以外の結果はこの種の
  プロジェクトを止めない。下の互換フォールバック経路をそのまま続行する。

禁止されている遷移は Capability Mode → レガシーであって、レガシー → レガシー
は降格ではない。G2 がそうだからという理由で G4 を
`CAPABILITY_RUNTIME_UNAVAILABLE` として報告してはならない。

### トラック解決

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
  解決トラックが lite なら以下の Process を実行し、full なら本スキルを実行せず
  `/sdd-bootstrap:sdd-bootstrap-interviewer` へ切り替える。
- `PROJECT_CONTEXT_INVALID`（C2）— その名前を報告して停止する。`specs/<feature>/`
  配下に何も生成せず、C1 のフォールバックへ落とさず、暗黙の `full`/`lite` 選択へも
  進まない。
- `PROMOTE_FULL` / `NO_OP_FULL` — 解決トラックは `full`。本スキルは実行せず、
  `/sdd-bootstrap:sdd-bootstrap-interviewer` に切り替える。
- `NO_OP_LITE` — 解決トラックは `lite`。以下の Risk-Upgrade Gate と Process を
  実行する。
- `ERROR_STOP` — 明示的なエラーで停止する。`--lite` が `full` プロファイルを
  格下げすることは決してない。

この表の正本は `PLUGIN-CONTRACTS.md` の Track Detection セクションである。

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
   `specs/<feature>/design.md` に記録される。任意・非ブロッキングで、ツール
   がない環境では手動手順にフォールバックする。希望しない場合はこのステップ
   を飛ばす。
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
