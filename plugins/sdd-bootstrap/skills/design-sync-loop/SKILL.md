---
name: design-sync-loop
description: Specification-phase UI design iteration loop for projects using a design-system/ contract. Ensures design-system/ exists, generates token-driven disposable HTML mockups under specs/<feature>/mockups/, optionally syncs via DesignSync with explicit egress consent, and falls back cleanly to manual workflow when design tools are unavailable.
disable-model-invocation: false
user-invocable: false
---

> **Caller**: `bootstrap` / `sdd-core-spec` から、UI 対象かつ `design-system/` 運用時のみ呼び出される内部スキル。成果物は `specs/<feature>/design.md` の `Design-Source` セクションへ記録する。

# Design Sync Loop

UI アプリケーションの仕様段階デザイン反復ループ。Mermaid と `design-system/` 契約を正本とし、`specs/<feature>/mockups/` 配下の HTML モックアップは使い捨ての視覚参照として扱う。

## 1. Ensure `design-system/`（ローカル契約を先に確保）

プロジェクトルートの `design-system/` の `design-tokens.json` が契約（`schema: design-system-contract/v1` を含むメタデータ）を満たし、`design-system.md` と `ui-patterns.md` が揃っていれば、この手順をスキップする。未整備なら既存の承認済み値を保ち、次の順で不足分を作成して利用者の承認を得る。

1. **`ui-ux-pro-max` と Python 3 が利用可能な場合**、製品種別・業種を確認し、プロジェクトルートからインストール済みスキルの `scripts/search.py` を Python 3 で実行する。引数は `"<製品種別・業種>" --design-system --persist -p "<プロジェクト名>"`。表示された生成先の `MASTER.md` を利用者と確認し、ページ別の上書きがある場合はそれも確認し、承認された配色・タイポグラフィ・余白を `design-system/design-tokens.json` に転記する（`meta.generated_by` は `ui-ux-pro-max`）。同梱テンプレートから `design-system/design-system.md` と `design-system/ui-patterns.md` を作成する。以後の設計では、この3ファイルを正本として参照する。
2. **Figma DTCG JSON の提供がある場合**、ローカルファイルの値を `design-tokens.json` にマッピングし、`meta.generated_by` を `figma-dtcg-import` にする。同梱テンプレートから作成したプロジェクト側の2つの Markdown ファイルに、承認済みの設計規約を記入する。
3. **どちらも利用できない場合**、D6 のテンプレート対話でブランドカラー・タイポグラフィ・余白スケールを利用者に確認する。同梱の `templates/{design-tokens.template.json,design-system.template.md,ui-patterns.template.md}` から3ファイルを作り、`meta.generated_by` を `manual` にする。`Design-Source` に `ui-ux-pro-max unavailable — D6 template interview used` と記録する。

## 2. Capability Detection & Fallback

1. `DesignSync` ツールをプローブする（遅延ロードツールも含め確認）。
2. 利用不可／認証失敗時は `specs/<feature>/design.md` の `Design-Source` に `design tools unavailable — manual workflow used` と記録し、同梱 `references/claude-design-workflow.md` に沿って手動フォールバックして戻る（仕様生成を絶対にブロックしない）。
3. ユーザーが明示的にデザイン参照生成を求め、ホストに別の画像/デザイン生成ツールがある場合は、リポジトリ機密を含まない最小合成ブリーフで参照画像を `specs/<feature>/mockups/` へ保存してよい（プロバイダー名を正確に記録し、DesignSync 接続と混同しない）。

## 3. Mockup & Egress Consent Loop（`DesignSync` 利用可能時）

外部プロバイダーを使う前に、同梱の `../../scripts/resolve-design-sync.py` に `design-sync-request/v1` を標準入力で渡す。読み込みは `operation: pull`、書き込みは `operation: upload` とし、毎回、現在の設定、機能・セッション・送信先、既存の判断記録を使う。結果が `prompt` なら同意の回答を加えて再実行する。 `skip` と `manual` は送信しない。`pull` の許可をアップロードに流用しない。

1. **Pull**: `list_projects` の一覧から利用者に対象プロジェクトを選んでもらい、`list_files` / `get_file` でそのトークンと既存コンポーネント一覧を取得し、`Design-Source` へ記録。
2. **Generate Mockups**: 機能の要件（REQ-NNN）と受入条件（AC-NNN）に対応する各画面・状態（default / empty / loading / error、レスポンシブ）について、外部アセット無し・トークン準拠（生カラーコード禁止）の HTML モックアップを `specs/<feature>/mockups/` に生成。
3. **Resolve Egress Consent**: 毎回 `AGENTS.md` の `ds_upload_consent`（`per-feature` [既定] / `standing` / `off`）を確認する:
   判定用の `destination` は実サービスと対象 ID の組を一意に識別する文字列とし、同じ組には毎回同じ値を使う。過去の `records` も、記録時の実サービスと対象 ID から同じ表記に揃える。送信先を特定できない過去の同意は使わず、撤回や禁止が今回の送信先に適用されるか不明な場合は手動フォールバックとする。
   - `off`: アップロードせず手動フォールバック（`Egress-Consent: not-permitted`, `Ds-Upload-Consent-Setting: off`, `Egress-Consent-At: <ISO-8601>` を記録）。
   - `standing`: プロンプト不要で続行し、`(feature, destination)` 初回のみ `Egress-Consent: granted`, `Ds-Upload-Consent-Setting: standing`, `Egress-Consent-At` を記録。
   - `per-feature`: 送信先ごとに判定する。当該 `(feature, session)` で未同意なら、送信内容・送信先（実際のサービス名とプロジェクト名）・外部保持リスク・適用範囲を明示説明して人間の明示同意を得てから `push` する。拒否時はアップロードせず手動フォールバック。
     次の文面は、判定結果の `provider` が `claude-design` で、実際の送信先が `claude.ai/design` の場合に限る。
     判定器が `prompt` を返したときだけ、〈機能名〉と〈プロジェクト名〉を実際の名前に置き換え、次の文面で利用者に同意を求める。
     「〈機能名〉の要件、受入条件、デザイントークンを反映した HTML モックアップを送信します。モックアップには未公開の製品仕様、画面の文言、ブランド情報などの機密情報が含まれる場合があります。
     送信先は外部サービス `claude.ai/design` の、手順1の Pull で選んだプロジェクト〈プロジェクト名〉です。
     送信した内容はサービス側に保持される可能性があり、このリポジトリではその保持や削除を制御できません。
     同意の範囲は、このセッション中に〈機能名〉のモックアップを〈プロジェクト名〉へ送ることです。今後この範囲で再生成するモックアップの送信も含みます。同意が有効な間、この範囲での2回目以降の送信時には改めて確認しません。
     同意すると、この内容を外部へ送る権限がご自身にあると表明したことになります。このツールではその権限を検証しません。この範囲で送信してよいですか？」
     機能・セッション・送信先がすべて同じで、前回の同意が有効なら、2回目以降のアップロードは再同意を求めず送信前検査に進む。
     一度の辞退は今回限りで、継続的な禁止 `not-permitted` を記録せず、設定も `off` に変更しない。辞退後、他の送信条件を満たす次の同一範囲のアップロードは `prompt` となり、改めて同意を求める。
     実際の送信先が `claude.ai/design` の `claude-design` に限り、手順1で選んだプロジェクトの ID を `Egress-Destination` として `Design-Source` に残す。
     送信先を変えた場合、元のプロジェクトの同意は引き継がない。新しい送信先に有効な同意がなく、他の送信条件を満たす場合は、送信前に改めて同意を求める。
     利用者はセッション中でも同意を撤回できる。撤回を受けたら、同じ機能・セッション・送信先の判断を `withdrawn` として `Design-Source` に追記し、次の判定では `records` の末尾に渡す。撤回後、他の送信条件を満たす次の同一範囲のアップロードは `prompt` となり、改めて同意を求める。
   判断結果に `audit` がある場合は、`specs/<feature>/design.md` の `Design-Source` に判断・適用設定・送信先・範囲と、返された `party`（`Egress-Consent-Party`）、記録時の ISO-8601 時刻（`Egress-Consent-At`）を残す。
   アップロード直前に対象の `specs/<feature>/mockups/` を同梱の `design-sync-scan.sh` または `design-sync-scan.ps1` で検査する。終了0なら `Egress-Scan: clean` と検査時刻を記録する。終了1なら検出内容を提示して送信を止め、その検査結果について明示的な上書き承認を得た場合だけ `Egress-Scan: overridden` と時刻を記録して続ける。終了2や異常終了ではツールを復旧して再検査するまで送信しない。
4. **Iterate & Finalize**: フィードバックを反映して再生成・再確認し、確定した視覚方針を `specs/<feature>/design.md` と `requirements.md`（UX 受入条件）へ反映する。

## Boundaries

- `design-system/` の承認は視覚規約の承認であり、タスク `Approval: Approved` や実装着工許可とは独立。
- 仕様生成をツール不在・認証失敗で停止させない。
- 実装フェーズでの実画面確認は `visual-verify-loop` と `sdd-gate` に委ねる。
