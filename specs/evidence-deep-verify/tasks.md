# Tasks: evidence-deep-verify

Task-Review-Status: Passed

Source: specs/evidence-deep-verify/requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed — integrated-verdict.json PASS,
reports/impl-review/evidence-deep-verify/attempt-1/round-1/) / Issue #68

Lifecycle: `Draft -> Approved -> In Progress -> Implementation Complete -> Done`

> Risk 注記: 各タスクの `Risk` tier と `Risk Rationale` は起草エージェントの
> **提案**である。承認(Approval)時に human が確定・変更する。提案のみでゲートは
> 緩和されない(risk-classification-policy.md)。`Required Workflow` は
> risk-gate-matrix.md に従い tier から機械的に導出している(low→test-after /
> medium→acceptance-first / high・critical→tdd)。

## T-001 per-artifact 再計算エンジン(6 ステータス分類 + 正準 artifacts ダイジェスト)

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: 本タスクは deep-verify の判定核であり、per-artifact ステータス分類の誤りは改竄の見逃し(mismatch を match と誤判定)または誤検知に直結する(REQ-002/003、security-spec.md B2)。invalid-recorded-sha の誤分類・例外送出は AC-017 で明示的に禁止された欠陥クラスであり、正準 artifacts ダイジェスト式(ADR-0009)のずれは host スクリプトとの判定不一致(REQ-009 破綻)を引き起こす。全読取は path-guard 経由(REQ-011)で、境界の破れは鍵ファイル読取(B3)への入口になる。
Required Workflow: tdd
Requirements: REQ-002, REQ-003, REQ-004, REQ-011
Rollback: 本タスクのコミットを revert(既存 5 ツールは無変更で残置可能)。design.md「Deployment / CI Plan」参照。

### Goal
`mcp/sdd-forge-mcp/src/tools/evidence.ts` に deep-verify の中核となる per-artifact
再計算ロジックを実装する: 記録された `artifacts[]` の各エントリについて path-guard
(`guardedRead`)経由でディスクから読み取り SHA-256 を再計算し、6 値ステータス
(match / mismatch / missing / too-large / path-denied / invalid-recorded-sha)へ
決定的に分類する。記録 sha256 が 64-hex でない場合は mismatch へ誤分類せず
invalid-recorded-sha とし(AC-017)、読取失敗(欠落・2 MiB 超・allowlist 外)で
throw しない(REQ-011)。正準 artifacts ダイジェスト(ソート済み `path\x00sha256`
行を `\n` 結合した列の SHA-256、ADR-0009 の逐語式)を再計算し記録値と比較する。
空 `artifacts[]` は空集合ダイジェスト比較として扱う(AC-018)。全体 verdict
(pass/fail)と failures 列挙(REQ-003)の骨格もここで実装する。

### Scope
- mcp/sdd-forge-mcp/src/tools/evidence.ts(deep-verify 中核: per-artifact 再計算・分類・正準ダイジェスト・verdict/failures)
- mcp/sdd-forge-mcp/tests/tools/(AC-002/003: 改竄→mismatch、AC-018: 空 artifacts)
- mcp/sdd-forge-mcp/tests/error-paths/(AC-004: 欠落→missing、AC-005: too-large / path-denied、AC-017: invalid-recorded-sha)

### Done When
- [ ] AC-002/AC-003: 成果物 1 バイト改竄 / 記録ハッシュ改竄(別の 64-hex)が mismatch + verdict fail に写像される
- [ ] AC-004/AC-005/AC-017: 読取失敗・不正記録系の分類 — 欠落→missing、2 MiB 超→too-large、allowlist 外→path-denied、非 64-hex 記録 sha→invalid-recorded-sha(mismatch へ誤分類しない・複合条件でも fail に収束)— いずれも throw なしで verdict fail に写像される
- [ ] AC-018: 空 artifacts[] が空集合正準ダイジェスト比較で処理される(vacuous pass、他不変条件失敗時は fail、throw なし)
- [ ] 正準 artifacts ダイジェスト式が generate/check-evidence-bundle.sh の evidence_canonical と逐語一致(ADR-0009、コード内で式を検証可能)
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] quality gate pass(provenance(spec_revision 含む)付き evidence bundle 生成と実装レポート reports/implementation/evidence-deep-verify-T-001.md の作成を含む)

### Blockers
None

## T-002 内部不変条件再計算(spec_revision / git_commit 形状 / cross-binding)

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: spec_revision の再計算式(specs/<feature>/{requirements,design,acceptance-tests}.md 連結の SHA-256)が host の compute_spec_revision と 1 バイトでもずれると REQ-009(判定一致)が破綻し、ゴールデン(AC-012)以前に検証体系全体の信頼を毀損する(ADR-0009)。git_commit 検証は 40-hex 形状のみで git を起動しない(no-exec 境界、ADR-0008)——ここで subprocess を導入すると B2/B3 境界違反となる。contract/report クロスバインドの欠陥は task_id/feature の取り違え(別タスクの証拠で Done を通す攻撃面)に直結する(REQ-007)。
Required Workflow: tdd
Requirements: REQ-005, REQ-006, REQ-007
Rollback: 本タスクのコミットを revert(T-001 の per-artifact 判定は独立して残置可能)。

### Goal
deep-verify の内部不変条件 3 系を実装する: (1) spec_revision — specs/<feature>/ の
requirements.md / design.md / acceptance-tests.md から host の compute_spec_revision
と逐語一致の式で再計算し記録値と比較(全 spec 不在時は空文字列 "" を正準値として
match/mismatch を判定、throw しない、AC-019)。(2) git_commit — `^[0-9a-f]{40}$`
形状検証のみを行い、git を起動せず ancestry 検証は host-deferred として
`ancestryVerified: false` をエコーする(ADR-0008、AC-007/008)。(3) contract/report
クロスバインド — verification contract と quality report の task_id / feature が
バンドル記録値と一致することを検証し、不一致を mismatch + fail に写像する
(AC-009/010)。

### Scope
- mcp/sdd-forge-mcp/src/tools/evidence.ts(invariants: specRevision / gitCommit / crossBinding)
- mcp/sdd-forge-mcp/tests/tools/(AC-006: spec ドリフト→mismatch、AC-007: 非 40-hex→fail、AC-008: 外部 40-hex→ancestry 未検証・git 不起動、AC-009/010: クロスバインド不一致→mismatch、AC-019: 全 spec 不在 spec_revision="")

### Done When
- [ ] AC-006: spec ファイルドリフトが specRevision mismatch + verdict fail に写像される
- [ ] AC-007/AC-008: git_commit 形状検証系 — 非 40-hex は形状不正で verdict fail、リポジトリに存在しない 40-hex は形状 pass + `ancestryVerified: false`(いずれも git プロセスを起動しない)
- [ ] AC-009/AC-010: contract / report の task_id・feature 不一致が mismatch + fail に写像される
- [ ] AC-019: 全 spec 不在で spec_revision="" が正準値として match/mismatch 判定される(throw なし)
- [ ] spec_revision 式が host の compute_spec_revision と逐語一致(ADR-0009)
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] quality gate pass(provenance(spec_revision 含む)付き evidence bundle 生成と実装レポート reports/implementation/evidence-deep-verify-T-002.md の作成を含む)

### Blockers
T-001

## T-003 署名境界(no-key / no-verify)+ 静的 read-only 検査

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: 本タスクは Issue #68 の最重要セキュリティ不変条件(REQ-008、ADR-0008、security-spec.md B3)を担う。署名鍵(~/.sdd/evidence-key 等)の読取経路が 1 つでも入ると、MCP ツール経由の鍵流出(Information Disclosure)と、ツール側での署名検証という誤った信頼委譲(host 検証の形骸化)に直結する。canary 検査・静的検査の穴は資格情報流出の検知漏れとなる。
Required Workflow: tdd
Requirements: REQ-008
Rollback: 本タスクのコミットを revert(署名エコーは parseEvidenceBundle 既存挙動へ戻る)。

### Goal
署名の取り扱い境界を実装・検証する: signature ブロックは present の事実と記録値の
エコーのみ(`verified: false` 固定)とし、鍵ファイル(path-guard denylist の
鍵パス)を一切読取らず、HMAC 計算・署名検証コードパスを持たない。canary 鍵
ファイルを配置した no-secrets テストで応答・stderr・エラーのいずれにも canary 値が
漏えいしないことを検証する(AC-011)。tests/readonly の静的検査を拡張し、
deep-verify 実装に fs 書込み・subprocess・network・鍵パス参照が 0 件であることを
グレップ検査で担保する(AC-014)。

### Scope
- mcp/sdd-forge-mcp/src/tools/evidence.ts(signature エコー・verified:false 固定)
- mcp/sdd-forge-mcp/tests/no-secrets/(AC-011: canary 鍵非読取・非漏えい・verified:false)
- mcp/sdd-forge-mcp/tests/readonly/(AC-014: 静的 read-only / no-exec / 鍵読取経路 0 件)

### Done When
- [ ] AC-011: signature present/verified:false がエコーされ、canary 鍵ファイルの値が応答・stderr・エラーに不在(鍵ファイル非読取)
- [ ] AC-014: 静的検査で deep-verify 実装の fs 書込み / subprocess / network / 鍵パス読取が 0 件
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/evidence-deep-verify-T-003.md)
- [ ] quality gate pass

### Blockers
T-001, T-002

## T-004 evidence_deep_verify ツール登録と統合応答

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: server.ts に外部呼出可能な 6 番目ツールを登録し、T-001〜T-003 の判定核を統合した完全応答を組み立てる。外部呼出可能なツールの登録・応答組み立ての欠陥は誤 verdict の外部露出に直結する(REQ-001)。risk-classification-policy.md の外部可視 API 面に該当するため high とし、証跡最低線(tdd Red→Green・独立レビュー・provenance bundle)を課す。契約スキーマ自体の加算は T-007、決定論/スモーク/dist は T-008 が担う。
Required Workflow: tdd
Requirements: REQ-001, REQ-012
Rollback: 本タスクのコミットを revert(ツール未登録状態に戻る。T-001〜T-003 のロジックは残置可能)。

### Goal
`evidence_deep_verify` ツールを server.ts に登録し(zod 入力 {feature, taskId})、
T-001〜T-003 の判定核を統合して完全な evidenceDeepVerifyData 応答
(verdict / artifacts[] / invariants / signature / failures)を返す。
エラーエンベロープ(invalid-input / not-found / cannot-parse)を既存規約どおり
写像する。整合バンドルの end-to-end pass(AC-001)を確認する。
契約スキーマへの evidenceDeepVerifyData 加算は T-007、決定論・スモーク・dist
再ビルドは T-008 が担う。

### Scope
- mcp/sdd-forge-mcp/src/server.ts(evidence_deep_verify 登録)
- mcp/sdd-forge-mcp/src/tools/evidence.ts(統合・応答組み立て・エラーエンベロープ)
- mcp/sdd-forge-mcp/tests/tools/(AC-001: 整合バンドル→pass、エラーエンベロープ写像)

### Done When
- [ ] AC-001: 整合バンドルで verdict pass(全 artifacts match・全不変条件成立)
- [ ] エラーエンベロープ(invalid-input / not-found / cannot-parse)が既存規約どおり写像される(tests/tools のエラー系テスト green)
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] quality gate pass(provenance(spec_revision 含む)付き evidence bundle 生成と実装レポート reports/implementation/evidence-deep-verify-T-004.md の作成を含む)

### Blockers
T-001, T-002, T-003

## T-007 evidenceDeepVerifyData 契約加算(v1 後方互換)

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: 本タスクは外部可視の公開 API 契約(contracts/sdd-forge-mcp-tools.v1.schema.json)へ evidenceDeepVerifyData を加算する(REQ-012)。risk-classification-policy.md は公開 API 契約を high tier の sentinel surface に列挙しており、加算が後方互換を破ると既存クライアント全体に波及する。契約を出荷するタスクとして high の証跡最低線(tdd Red→Green・独立レビュー・provenance bundle)を課す。
Required Workflow: tdd
Requirements: REQ-012
Rollback: 本タスクのコミットを revert(契約は既存 5 ツール状態に戻る。T-004 のツール実装は残置可能で、AC-015 検証のみ red に戻る)。

### Goal
contracts/sdd-forge-mcp-tools.v1.schema.json の okEnvelope.data.oneOf に
evidenceDeepVerifyData を加算的に追加する(v1 維持・後方互換、REQ-012)。
ajv により evidence_deep_verify 応答の契約適合と、invalid-input / not-found /
cannot-parse のエラーエンベロープ規約適合を検証する(AC-015)。

### Scope
- mcp/sdd-forge-mcp/contracts/sdd-forge-mcp-tools.v1.schema.json(evidenceDeepVerifyData 加算)
- mcp/sdd-forge-mcp/tests/tools/(AC-015: ajv 契約適合・エラーエンベロープ規約)

### Done When
- [ ] AC-015: 応答が evidenceDeepVerifyData 契約に ajv 適合し、invalid-input / not-found / cannot-parse がエラーエンベロープ規約どおり
- [ ] 契約変更が加算的である(既存 5 ツールの data.oneOf 分岐がバイト不変であることをスキーマ diff で確認)
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] quality gate pass(provenance(spec_revision 含む)付き evidence bundle 生成と実装レポート reports/implementation/evidence-deep-verify-T-007.md の作成を含む)

### Blockers
T-004

## T-008 統合検証(決定論・tools/list スモーク)と dist 再ビルド

Approval: Approved
Status: Implementation Complete
Risk: medium
Risk Rationale: 決定論検証(REQ-010)・tools/list スモーク(REQ-013)・esbuild dist 再ビルド(ADR-0003)は、契約面・機微判定核を変更しない検証と必須 housekeeping(dist-parity CI)である。検証の穴は出荷品質の見逃しにつながるため low ではないが、新規セキュリティ面・契約面を持たないため medium とする。
Required Workflow: acceptance-first
Requirements: REQ-010, REQ-013
Rollback: 本タスクのコミットを revert(テスト・dist のみ。src/ 実装コードは無変更)。

### Goal
evidence_deep_verify の出荷前統合検証を実装する: 決定論(同一入力 2 回呼び出しの
バイト等価、REQ-010、AC-013)と tools/list スモーク(evidence 6 番目、AC-016)を
検証し、esbuild dist を再ビルドしてコミットする(dist-parity、ADR-0003)。

### Scope
- mcp/sdd-forge-mcp/tests/tools/(AC-013: 決定論)
- mcp/sdd-forge-mcp/tests/smoke/(AC-016: tools/list に evidence 6 番目)
- mcp/sdd-forge-mcp/dist/(esbuild 再ビルド)

### Done When
- [ ] AC-013: 同一入力 2 回呼び出しで応答バイト等価(決定論)
- [ ] AC-016: tools/list に evidence_deep_verify が 6 番目の evidence ツールとして列挙される
- [ ] acceptance テストが実装(dist 確定)に先行して記述される(acceptance-first)
- [ ] dist 再ビルド済みで dist-parity CI が green(ADR-0003)
- [ ] quality gate pass(実装レポート reports/implementation/evidence-deep-verify-T-008.md の作成を含む)

### Blockers
T-007

## T-005 host スクリプト判定一致ゴールデン(parity)

Approval: Approved
Status: Planned
Risk: medium
Risk Rationale: ゴールデン検証は実装コードを変更しないテスト追加だが、REQ-009(host スクリプトとの判定一致、ADR-0009)は本 feature の中核保証であり、fixture 設計の穴(pass 系のみ・改竄系欠落)は「一致している」という誤った確信を生む。検証専用タスクであるため tdd は要求せず acceptance-first とする。
Required Workflow: acceptance-first
Requirements: REQ-009
Rollback: 本タスクのコミットを revert(テスト・fixture のみ、実装コード無変更)。

### Goal
tests/golden/ に host スクリプト(generate-evidence-bundle.sh /
check-evidence-bundle.sh)と evidence_deep_verify の判定一致を検証するゴールデンを
実装する: 整合バンドル(pass)・成果物改竄(fail)・spec ドリフト(fail)・
記録ハッシュ改竄(fail)の各 fixture について、host スクリプトの判定と
evidence_deep_verify の verdict が一致することを検証する(AC-012)。fixture は
リポジトリ内合成データのみを用い、テスト実行時に host スクリプトを直接実行して
比較するか、事前計算済みゴールデン出力をコミットして突合する(いずれの場合も
evidence_deep_verify 本体は git / シェルを起動しない)。

### Scope
- mcp/sdd-forge-mcp/tests/golden/(AC-012: pass/fail 双方向の判定一致 fixture + 検証)

### Done When
- [ ] AC-012: 整合(pass)・改竄/ドリフト(fail)の双方向で host スクリプト判定と evidence_deep_verify verdict が一致する
- [ ] acceptance テスト(fixture と期待判定)が検証実装に先行して記述される(acceptance-first)
- [ ] 実装レポート作成(reports/implementation/evidence-deep-verify-T-005.md)
- [ ] quality gate pass

### Blockers
T-008

## T-006 ドキュメント + traceability 最終化

Approval: Approved
Status: Planned
Risk: low
Risk Rationale: README / USERGUIDE への追記と traceability の Verification Status 最終化のみで、制御フロー・データ・セキュリティへの影響がない。
Required Workflow: test-after
Requirements: REQ-001, REQ-013
Rollback: 本タスクのコミットを revert。

### Goal
README / USERGUIDE に evidence_deep_verify の概要(6 番目の read-only evidence
ツール)・入出力・セキュリティ境界(署名鍵非読取・署名非検証は host 責務、
git ancestry は host-deferred)を追記し、REQ→AC→TEST→Task チェーン全行の最終化
(Verification Status)を addendum(reports/implementation/evidence-deep-verify/
T-006 addendum)に記録する。traceability.md 本体はタスクレビュー済みバイトで凍結
(Post-review artifact freeze、WFI-004 に基づく)。

### Scope
- README.md / USERGUIDE.md(evidence_deep_verify 追記)
- reports/implementation/(traceability 最終化 addendum)

### Done When
- [ ] README / USERGUIDE に evidence_deep_verify の概要・入出力・セキュリティ境界(no-key / no-verify / host-deferred ancestry)が記載される
- [ ] REQ→AC→TEST→Task チェーン全行の Verification Status が addendum に記録される(traceability.md 本体はレビュー済みバイトで凍結)
- [ ] 実装レポート作成(reports/implementation/evidence-deep-verify-T-006.md)
- [ ] quality gate pass

### Blockers
T-001, T-002, T-003, T-004, T-005, T-007, T-008
