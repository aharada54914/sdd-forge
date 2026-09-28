# T-001 schema定義の対応表

調査日: 2026-09-28

既存のCursorV1・task状態型・event kindは再利用候補がある。一方、IDの個別上限、reason語彙、Projectionの内部形、TEST-045g–iの対応は確定していない。本書は非凍結の調査addendumであり、新しい値・仕様・承認・レビュー判定・テスト成功を確定しない。

## 既存定義と不足を分ける

参照パスはリポジトリルートからの相対パス。対象はT-001報告の未解決項目（`reports/implementation/sdd-context-continuity/T-001.md:131–134`）。

| 対象 | 既存の確定事項と根拠 | 未定義または再利用時の注意 |
|---|---|---|
| bounded ID | opaque・非空・bounded。sequenceは非負safe integer、hashはlowercase 64-hex SHA-256（`specs/sdd-context-continuity/design.md:79–83`）。 | 個別IDの数値上限と計量単位は未記載。1 MiB observation／8 MiB transcript／8,192 bytes recoveryは別の全体予算（`specs/sdd-context-continuity/frontend-spec.md:78–80`）。ID上限へ読み替えない。 |
| reasonCode／diagnostic | OutcomeのreasonCodeは必須、diagnosticは任意のbounded approved reason code。失敗結果に内容・例外・private path・digestを含めない（`specs/sdd-context-continuity/design.md:175–183`）。diagnosticsはreason/stage定数のみ（`specs/sdd-context-continuity/security-spec.md:130–134`）。 | 語彙enumは未列挙。既存MCP loggerの再利用は認められておらず、allowlist／no-stackの原則だけを再利用する（`specs/sdd-context-continuity/security-spec.md:94–98`）。 |
| ProjectionV1.authorityHashes | フィールド名と鮮度責務は定義済み（`specs/sdd-context-continuity/design.md:91,141–144`）。現行spec・task approval/status・reports・verificationとの照合が必要（`specs/sdd-context-continuity/requirements.md:40,81`）。 | map／array等の内部形と、ハッシュを取る完全な依存集合は未列挙。欠落・読取不能・矛盾authorityをHANDOFFで補って成功扱いできない。 |
| ProjectionV1.taskLifecycle | 専用の内部形は未記載。ただし既存のstatus enumと閉じたtaskEntryは定義済み（`contracts/sdd-forge-mcp-tools.v1.schema.json:79–96`、`mcp/sdd-forge-mcp/src/parsers/task-types.ts:8–35`）。既存parserの再利用が指定されている（`specs/sdd-context-continuity/tasks.md:19,79`）。 | taskEntryを再利用する候補と、taskStateData全体を保存する候補は同一ではない。後者にはtasksFileや自由文failuresが含まれる（`contracts/sdd-forge-mcp-tools.v1.schema.json:98–119`）。 |
| ProjectionV1.journalCursor | 閉じたCursorV1のfieldsは既存（`specs/sdd-context-continuity/design.md:92`）。foreign cursorはreplayを承認せず、cross-sessionには検証済みの同一worktree／feature関係が必要（同`:135–139`）。 | journalCursorがCursorV1を参照するとの明示、空journal時の扱いは未記載。型の再利用でreplay権限を追加しない。 |
| JournalRecordV1.kind | JournalRecordはkindを持つ（`specs/sdd-context-continuity/design.md:89`）。一般event enumはprompt／final-assistant／observable-transcript／compact-manual／compact-auto／resume（同`:149–150`）。Observationのkindはprompt／final-assistant、Reconcile.recordsはObservationV1[]（同`:164–165`）。 | JournalRecord専用enumとの明示的な紐付けはない。「kindの値が全く未定義」とは扱わない。一般6値を参照するかObservationの2値へ限定するかは区別する。 |
| TEST-045g–i | taskとtraceabilityはa–iを参照（`specs/sdd-context-continuity/tasks.md:40`、`specs/sdd-context-continuity/traceability.md:20`）。acceptanceの定義行はa–fのみ（`specs/sdd-context-continuity/acceptance-tests.md:137–142`）。 | g–iの定義行は確認できない。全copy・omission・raw digest／backup禁止は既に各枝の共通assertion（同`:130–133`、`specs/sdd-context-continuity/security-spec.md:138–149`）。未定義番号を新規テストとして創作したり、達成扱いにしたりしない。 |

既存の `contracts/context-projection.schema.json:7–21` はworkflow/components等を持つ別契約で、hash表現も `sha256:` prefix付き。継続機能のProjectionV1へそのまま流用する根拠にはならない。

## 最小補完案は未採用の提案として扱う

- 構造の再利用候補: journalCursorにCursorV1、taskLifecycleに既存taskEntry、kindに既存event enumを参照する閉じたencodingの対応表を作る。これは候補であり、内部形・必須性・空状態を本書で確定しない。
- ID上限: IDごとの数値と単位を明文化する案を作る。native IDの有効性やretry対応を狭める上限は、実IDの証拠と照合する。OQ-005は実retry IDの観測を要求している（`specs/sdd-context-continuity/requirements.md:195`）。既存全体予算から個別値を捏造しない。
- authorityHashes: 現行authorityの読取依存を列挙し、閉じたpath／hash対応と欠落時の扱いを提案する。単なるarray／mapの選択と、authority対象を減らして鮮度判定を弱める変更は別である。
- reason語彙: 既存の失敗分類に対応する定数名の表を提案する。定数名のencodingと、warn／continue／SAFE／unavailable等の意味を変える要件判断を分ける。本書は新しいenum値を選ばない。
- TEST番号: 親TEST-045とa–fの共通assertionsに対する要求対応を示し、g–iとの不整合を明示する。新しい秘密検出ポリシーや検証済みという主張は追加しない。

次の安全な作業は、上の未確定差分だけを既存根拠付きで整理し、schema実装前のWFI-001 mismatch preflightへ渡すこと。凍結本文への追記やTEST番号の訂正を本書で代行しない。凍結範囲と非凍結addendumの扱いは `AGENTS.md:46–69`、feature側の指定は `specs/sdd-context-continuity/tasks.md:24–25` に従う。

## 調査方法と限界

対象featureのrequirements・design・acceptance・4 layer・tasks・traceability、ADR-0033、既存contracts、および参照されたtask reader／diagnosticsを読み、対象symbolとTEST番号を `rg` で照合した。既存contracts／ADRの対象symbol検索から追加定義は見つからなかった。これは調査対象内の結果であり、全履歴やnative host payloadの検証ではない。

調査ではcode/tests・凍結仕様・Approval/Status・implementation reportを変更せず、Git操作・CI起動・実CLI・レビュー判定を行っていない。本書の保存だけを追加操作とする。
