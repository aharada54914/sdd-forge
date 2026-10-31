# A8 T-001 nonce-only 設計改訂候補

Status: PREPARATION ONLY / NOT APPLIED / NOT FORMALLY REVIEWED.

## 成果物と適用境界

主担当から伝達された既存の設計変更・追加修正承認を前提に候補を作成した。
原本や旧候補を変更せず、予約・review verdict・Approval・Done・試行回数は不変。
Auto変更、新規 admission framework、製品コード修正は含まない。

候補は次の2成果物を1組として採用検討する。patch単体では完結しない。

| Candidate | SHA-256 | Intended target |
|---|---|---|
| `reports/verification/a8-nonce-design-revision-20261005.patch` | `51283f7c22548b55a55b3e930e4670b6d03faf9d0e835f73c067cb48aeb35a45` | design.md、tasks.md、ADR index の3対象差分 |
| `reports/verification/a8-nonce-adr0035-candidate-20261005.md` | `50cf6c313940ccfa182cc8632d59215430183957e6e0ea02d6d064c934109923` | `docs/adr/0035-a8-two-contribution-handoff-oracle.md` の新規本文候補 |

ADR採用後のcanonical本文はこの候補と同じbytesを想定する。正式採用時の
編集が必要なら新hashを取得し、古い候補hashを流用しない。今回はcanonical
ADRを作成していない。

## 最小差分

- design: 単一行single-backtickの正規ADR宣言を追加。nonce2単独の最終
  oracleを両独立nonceへ変更。Copilotは両ファイルから値を取得し、値のprompt
  直渡しはしない。片方ずつの変更とstale output拒否を明示。
- task: T-001 GoalとTEST-004 Scopeだけを整合。Done Whenの両contribution
  要求、承認・状態・他タスクは変更しない。
- ADR: cross-runtime handoff の最終consumerが何を証明するかという検証設計の
  決定。nonce2維持／nonce2をnonce1から導出／両成果物を直接読む方式を比較。
  単なる審査入力データの移送ではなく、独立producer mutationと最終依存性の
  両立を選ぶ。task reviewerにADR読取を追加せず、必要な仕様はdesignにも記す。
- ADR index: Proposed行のみ追加。Acceptedや正式レビュー成功を主張しない。

## Namespace調査と採用直前条件

`rtk proxy rg --files docs/adr` で現checkout最大0032を確認。
`rtk proxy git log --all --format= --name-only -- docs/adr` の全出力を確認し、
0033 worktree-local-context-continuity / panelist-supervisor-process-ownership、
0034 a9-domain-component-ownership / review-input-acquisition-before-dispatch
の既存履歴を確認した。0035はその読取時点で未出現なので候補番号とした。
fetchはしておらず他checkoutの未commit候補は網羅していない。番号の予約ではない。
`docs/adr/README.md` のmax+1規則とAGENTS WFI-013に従い、採用直前に共有refsと
進行中候補を再確認する。衝突時はdesign宣言・index・ADR名を同一新番号へ修正し
候補hashを更新する。既存0033/0034へ上書きしない。

## 今回の検証

`rtk proxy git apply --check --unidiff-zero reports/verification/a8-nonce-design-revision-20261005.patch`
はexit 0、stdout/stderrなし。read-onlyのcheckであり、適用成功を意味しない。
patchはゼロcontextのため、適用時には下記before pinsの一致も必須。

| Unchanged original | Raw SHA-256 |
|---|---|
| `specs/epic-196-a8-integration/design.md` | `14862a80a6f44b49dbf7e1393af66c82c0434bf1109b248e7ff9b4b695fcd18c` |
| `specs/epic-196-a8-integration/tasks.md` | `8c17b0f6b2fa299d23ce6e892a8e80a841ac4ab68d613c84d6c36fe09bbcde66` |
| `docs/adr/README.md` | `56d9d0197f1978f27724f506631b7a3f16d334bd2bee09adda594ad9264dd07f` |

requirements/acceptance/design/tasksと全4layerをAC-004、nonce再利用、
COPILOT-CONSUMEDでsweepした。旧nonce単独表現は本patchのdesign/task箇所。
acceptance TEST-004の参照、AC-004要求、Done When、headless契約未確認の分類は
維持する。既存bash token_hexとPowerShell GUID(N)生成はdelimiter-safeである
（`tests/cross-runtime-handoff.tests.sh:119`、`.ps1:139-140,183-185`）。
行動テストは未実行。旧nonce candidateのgreenを今回の実装結果にしない。

## 必要な再レビュー入力と順序

1. 正規採用時に上記原本pins、ADR namespace、承認根拠と変更範囲を照合し、
   履歴を保持した設計改訂として採用する。人間専用適用ならagentは実行しない。
2. impl provenance再審査は既存機構を使用。canonical requirements、acceptance、
   改訂design、存在するinvestigation、全4layer、reviewer-calibration、現行precheck、
   designが宣言したADRの完全なpath/hash集合を両reviewerへ同じpinsで渡す。
   Bには正規sanitized summary。現在の候補ファイルやpatchをmanifestに直接追加しない。
3. precheckの`adr_inputs`とinput digest、invocation、両出力、contractの一致を
   現行validatorで検証。変更箇所へ旧PASSの収束規則を適用しない。
4. task provenance再審査では改訂tasksとdesign、現行canonical入力／traceability／
   layersと完全なimpl predecessorを束縛する。task reviewerへADRアクセスを
   独自付与しない。正規skillのrole別入力集合・fresh identity・逐次予約を守る。
5. 採用・再審査後に初めてnonce-onlyの実装と両runtime検証へ進む。
   model可用性、正規caller読取、fresh実装identity、実live handoffは別の未完条件。

本調査では新attempt番号を選定せず、precheck・予約・native起動をしていない。
追加の汎用framework実装を先行させる必要はない。
