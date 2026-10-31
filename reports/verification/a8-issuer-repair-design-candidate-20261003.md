# A8 issuer 欠落の最小修復設計候補

日付: 2026-10-03
状態: 設計候補のみ。正式仕様・承認済み task・実装・品質ゲート判定ではない。
今回の変更範囲: この非凍結 report のみ。Git 操作、鍵生成、人間署名、nonce 発行、台帳更新、native 拒否再試行なし。

## 結論と重複調査

A1 を変更せず、A8 が所有する **人間実行の detached-signature issuer broker**
を追加する案を推奨する。秘密鍵を読む signing CLI は追加しない。

確認した既存実装:
- A1 の nonce は secrets.token_hex(16) で生成され、emit は JSON stdout のみ。永続化しないことが明記される
  (plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py:199–239)。
- A8 validator は既存 issuer の登録鍵・署名を検証するが、発行しない
  (plugins/sdd-quality-loop/scripts/validate-live-host-proof.py:307–334)。
- 既存の consumption publisher は ledger.lock ディレクトリ、再読込み比較、同一ディレクトリ temp、fsync、atomic replace を使う (:498–535)。
- package script が秘密鍵を読まないこと自体が契約である
  (specs/epic-196-a8-integration/security-spec.md:130–144)。
- A8 T-005 は validator と台帳 seed を所有し A1 改変を除外、T-008 は人間適用・live proof を所有する
  (tasks.md:904–922,1092–1106,1620–1658)。A1 T-008 Done を新機能の承認に流用しない。

bounded search は owner の plugins/tests、specs/epic-196-a8-integration/verification、
reports/verification と primary checkout の plugins/tests、さらに次の既存 A8 worktree の plugins に限定した:
a8-base-repair-sol2/sdd-forge、a8-explicit-sonnet-live/sdd-forge、
a8-t004-cli-hook-enforcement/sdd-forge、ci-a8-unwired/sdd-forge
（いずれも既存の managed worktree）。
検索語は nonce-issuer / issuer_signature / live-host-nonce-ledger/v1。
他4 worktree は validate-live-host-proof.py のみ、owner/root tests は空台帳と
tests/fixtures/live-host-proof/run_cases.py の synthetic signer のみ。
既存 candidate/specs の design/tasks も見つかったが実行可能 issuer ではない。
最初の他worktree検索は sdd-forge 階層を欠いて exit 2、ls で実在パス確認後に修正して検索した。
これは全ブランチ不存在の証明ではない。実装直前に同じ bounded discovery を再実行し、
新しい issuer 所有者が現れていれば統合を優先する。未PRブランチへの Git 操作は行っていない。

## 所有 task と適用前条件

新規 A8 所有 task の候補名は **T-009: Human-attended nonce issuance broker**。
現行 tasks.md の見出しは T-001〜T-008 だけだが、番号は未予約であり起草時に再確認する。
Risk: high。T-005 の validator 契約へ依存し、T-008 HUMAN APPLY の前提となる。
この report は Draft task の実装を許可しない。

予定変更対象:
- plugins/sdd-quality-loop/scripts/issue-live-host-challenge.py（単一の Python entry point。専用 .sh/.ps1 wrapper は追加しない）
- 既存の nonce ledger entry/signature 契約を再利用し、新規 request/response/receipt schema は追加しない
- tests/fixtures/live-host-proof/ の issuer 専用 disposable fixture と既存 cross-runtime runner 接続
- 人間 runbook（鍵を読む処理は package 外、人間だけが実施）
- docs/adr/ の ADR-0028 amendment または新規 ADR（番号は正規起草時に再確認）

凍結解除・再レビューで扱うべき差分を先に確定する:
1. A8 design.md:101,201–205,620–633 の「A1 が ledger に書く」を
   「A1 は nonce/challenge を生成し、A8 broker のみが署名済み issuance を append」に変更。
2. security-spec.md:99,122 の sole writer を broker に変更。
   :130–144 の秘密鍵非読込み境界は維持。
3. tasks.md の冒頭 ownership・T-005/T-008 境界と新規 task、traceability、
   acceptance の発行経路テストを更新。requirements/layer の関連識別子を全面 sweep し、
   必要な変更だけ明示。凍結済みファイルは本 report 作成時には一切変えない。
4. 影響した spec/design/task gates を正規再レビュー・再拘束し、人間 task approval、
   WFI-001 の persisted field/counterpart/失敗テスト三点表を完了後に implement-task。
   現行 T-008 approval だけでこの新規実装を開始しない。

## 具体 CLI と対話契約（提案、未実装）

issue-live-host-challenge.py --matrix-cell CELL --issuer-key-id KEY_ID
  --nonce-ledger PATH --trusted-signers PATH

- CELL は validator :21–27 の厳密な5値のみ:
  Claude-active / Codex-enabled-active / Codex-disabled-expected-unavailable /
  Copilot-primary-active / Copilot-subagent-expected-unavailable。
  schema や任意 issuer 値、nonce、
  timestamp、private-key、signer-command を caller が上書きする引数は設けない。
- PATH は人間が選んだ owner の正規 registry/ledger を指す。通常モードでは repository
  内の既存 regular file のみ、symlink/外部パス拒否。fixture 用 root は本番データを
 参照しない隔離テスト API で差し替え、実運用 CLI の弱い test-mode は作らない。
- canonical A1 sibling script を固定 argv の subprocess で --emit-challenge 呼出し。
  shell=True、任意 executable、caller nonce、手書き challenge JSON の import は禁止。
  A1 schema/nonce/target を厳密確認し、stderr の stale sentinel 警告はそのまま保持する。
  broker は canary を作成・削除せず、challenge の出力は HOOK_ACTIVE の証拠ではない。
- issued_at は生成直後の UTC 時刻（秒精度、Z）を broker が決める。
  unsigned entry は nonce/matrix_cell/issued_at/issuer/issuer_key_id の5項目。
  issuer の既存 literal check-hook-activation-handshake は **nonce generator の識別子**
  として維持し、物理 writer が broker であることを契約 amendment に明記する。
  literal の意味変更を黙って採用しない。合意されなければ schema/version 変更を別途設計する。
- 既存 canonicalizer と validator の JCS/strict Ed25519 検証を再利用する。独自 crypto は追加しない。
  target = SHA256(JCS(unsigned_entry) || ASCII(":nonce-issuer"))。
  署名対象は **32 byte digest 自体**。hex/base64 の文字列、改行付き文字列や追加 hash ではない。
- 人間への stderr に既存 unsigned entry の JSON と、署名対象 digest の base64、
  registry から得た公開鍵を明示した説明を出す。新規 wire envelope は作らない。
  公開鍵等の非秘密情報のみ。nonce を含む署名requestは人間issuerだけへの準備情報であり、
  対象hostへのchallenge deliveryではない。対象native sessionに転送しない。
  stdout はまだ空。コマンドはこの段階で成功ではない。
- 人間が外部の管理済み signer でこの digest を署名する。package は signer を起動せず、
  秘密鍵 path/env/STDIN を受け取らない。人間署名ツールの実選定・公開鍵登録・実署名は
  T-008 の operational procedure。ここでは架空の鍵/署名を用意しない。
- stdin は一行の canonical base64 signature（raw64bytes）のみ。
  改行を除き88 ASCII文字、既存 validator と同じ decode/re-encode 検査と
  保持中の digest・公開鍵に対する署名検証を必須とする。key-id や digest の再入力は不要。
  invalid/EOF/interrupt は fail-closed。署名を集め直す自動 retry なし。
- 人間待機中に lock は保持しない。24時間の絶対deadlineで入力待ち自体を中断し、
  append直前にもUTC経過時間を再確認する。monotonic deadlineも併用し時計巻戻しで
  待機が延びないようにする。期限切れは拒否し、新しい issuance が必要。
  append 前に ledger/registry を再読込みし issuer の信頼と全 ledger を再検証する。
- validator と同じ PATH+".lock" を mkdir 排他取得する。lock 競合は明示失敗で stale lock
  自動削除なし。duplicate nonce は追記せず失敗。無関係な同時追加を失わないよう、
  lock 下で最新 ledger を基準とする。registry が初回 digest と異なれば失敗。
- 新 entry の consumed_by_record は null のみ。以前の全 entry/consumption 値を保存し、
  同じ temp+fsync+atomic replace discipline で append。完了後にのみ stdout へ
  A1 challenge JSON を出す。新規 receipt artifact は作らず、既存署名済み ledger entry
  が issuance の正本となる。stdout は native verdict、two-party record、discharged の代替ではない。
- append 成功後に stdout delivery が失敗する可能性は残る。その nonce は未使用 entry として
  保持し再出力/削除/再使用しない。fresh issuance で回復する。途中で作った自身の temp/lock
  のみ finally cleanup。失敗前の台帳は不変、成功後の既存履歴も不変。
- proposed exit: 0=durable issuance completed、2=input/schema、3=trust/signature、
  4=lock/storage、5=A1 generation、6=expiry/interruption。stdout は成功時のみ challenge。
  exit と入出力の挙動を既存 design の追記および tests で相互束縛する。

## 人間独立性と残る運用境界

issuer は role=issuer の登録済み鍵のみ。operator/reviewer の登録や署名を broker は行わない。
operator と reviewer は異なる identity/public key を必須のまま維持
(validate-live-host-proof.py:398–414)。issuer key を operator/reviewer role として代用しない。
人間二者の鍵・attestation を agent が代行しない。署名を運ぶプロセスと custody は分離する。

署名対象を正しく提示する broker の binary/source を人間が確認する必要は残る。
また署名は native event を自動で真実にしない。T-008 は各発行 **成功後** に別の fresh native
session を開始し、issued_at < session_start <= issued_at+24h を満たす実観測・raw capture・
独立 countersignature を別途提供する。既存 Copilot 拒否は本修復で解除されず、再試行しない。

## RED→GREEN 設計と AC 対応（今回は未実行）

| proposed test | RED baseline / 改変 | GREEN の具体 assertion | AC |
|---|---|---|---|
| ISS-01 | 現行 CLI 欠落、A1 emit 後も ledger 不変 | broker成功後1entryのみ追加、nonce=出力challenge、A1 bytes/3-mode CLI不変 | 015,026 |
| ISS-02 | unsigned/不正署名/別role/別key/hex文字列への署名 | exit3、ledger byte-for-byte不変、stdout空 | 026,027 |
| ISS-03 | nonce/cell/time/key-id/issuer の各1field改変 | 各々signature不一致。5fieldを独立ケースに展開 | 026,027 |
| ISS-04 | same nonce / same・different cell | 二重追加なし、既存entry不変 | 027,028 |
| ISS-05 | lock競合、consumer更新競合、atomic replace失敗 | partial JSON・lost updateなし、他者lock削除なし | 027,028 |
| ISS-06 | signature待機EOF/interrupt/expiry/registry変更 | stdout空、台帳追記なし（append済stdout失敗はentry保持） | 026,027 |
| ISS-07 | input overrides、symlink、unknown cell、oversize/noncanonical base64 | 拒否、秘密鍵file/env読込みなし | 026 |
| ISS-08 | issued_at>=session_start / >24h | 既存validator ERR_NONCE_ISSUED_AFTER_SESSION / ERR_NONCE_EXPIRED維持 | 027,028 |
| ISS-09 | operator/reviewer同一鍵・同一identity・片署名欠落 | 既存validator拒否、issuer署名で代用不可 | 026,027 |
| ISS-10 | 5cell/5consumer一部欠落・synthetic代用・staleSKIP | discharged不可。実観測全5cell+全consumerのみ最終候補 | 015,016,028 |
| ISS-11 | Python entry point の argv・exit・case・LF/CRLF差異 | 3OS同一decision、mis-cased negative、署名line末尾以外は不変 | 026,028 |

本番人間署名はテスト生成しない。将来の暗号/transaction tests は隔離 fixture の既存
synthetic signer だけを使用し、live-proof directory や trusted registry へ出力しない。
既存 run_cases.py と A1 challenge regressions、3OS CI に接続し、runbookレビューも独立実施。
WFI-001 三点表は ledger 7field と challenge 出力との対応に展開する。対話 envelope は永続化しない。
上表の GREEN は目標であって実行結果ではない。今回 run は read-only source discovery のみ。

## 採らない案と次の正規作業

- A1 に署名/台帳書込み追加: Done 済み A1 無書込み契約を壊し cross-epic scope が広がるため不採用。
- fixture signer を production 流用: 秘密鍵非読込み・人間custody境界を壊すため不採用。
- 手書き ledger/署名、既存raw eventへの後付け issuance: generation provenance と
  issued-before-session を満たさないため不採用。
- validator の未知nonce/署名チェックを緩和: evidence gateの根本要件を消すため不採用。

### 最小性の再評価（2026-10-03）

新規3 schema と shell wrappers は削除した。追加 entry point の必要性は暗号方式の追加ではなく、
既存 A1 emit、外部署名、既存 ledger append の間にある「検証済み登録が成功するまで
対象 host に challenge を渡さない」順序と排他・失敗時不変性を機械的に保証する点にある。
現在確認した既存 CLI は nonce を発行する A1 と consumption を記録する validator のみで、
issuance append の正規操作はない。署名を人間が行う既存運用は維持し、追加の人間承認や
追加の署名者・鍵・署名回数は要求しない。手作業だけの runbook は、この原子性と
challenge delivery の制御を検証可能な形で提供しないため、現契約の修復としては選ばない。
この判断は上記 bounded discovery の範囲内であり、正式レビュー前に既存 issuer が
見つかれば重複実装せず再評価する。

次は正式な仕様 amendment・所有task の正規レビューへ載せる。
包括承認は候補策定を許すが、本文だけで凍結解除/新task Approved/実装開始とはしない。
broker実装完了も AC-015/016 の実観測や AC-028 discharge 完了ではない。

## 正式 amendment の最小対象と現在の開始境界

2026-10-03 の追加 identifier sweep で、frontend-spec.md:47 にも
「A1 が sole issuer of ledger entries」という同じ帰属があることを確認した。
これも design/security と同時に generator と writer の区別へ修正する必要がある。
frontend-spec.md:23 の既存 six schemas は増やさない。
ux-spec.md の issuer/ledger 検索一致はなかった。infra-spec.md:208 の
append-only 台帳契約は維持し、同じ lock を issuer と consumer が共有する点だけ補う。

正式差分の単位:

1. requirements.md AC-026 の「A1-issued nonce recorded in ledger」は維持しつつ、
   A1 が生成し A8 が外部署名を検証して native session 前に durable append する責務を明記。
   署名者数、秘密鍵境界、AC-015/016/027/028 の合否基準は変更しない。
2. acceptance-tests.md に上表 ISS-01〜11 を既存 AC へ紐付けた具体 TEST 行として追加。
   5 unsigned fields、5 cells、列挙した failure branches は個別 assertion を持たせる。
3. design.md/security-spec.md/frontend-spec.md の上記 writer 帰属を一致させ、
   design に既存形式だけの broker 入出力・transaction・中断契約を追加。
   infra の共有 lock/append 契約と人間 runbook への参照も一致させる。
4. spec/design の再レビュー完了後にだけ Phase 2 で T-009 候補を Draft/Planned として作成し、
   T-005→T-009→T-008 の依存関係および traceability を task-review で再拘束する。
   既存 Approval 値は保持し、新規 task Approval を代筆しない。

上記は未適用である。bootstrap-interviewer の mandatory native handshake のため owner で
fresh emit-challenge は成功したが、調整 subagent の native apply_patch の既定 cwd が
owner と異なる。relative canary template を別 checkout に適用しないため own-session
canary attempt はまだ行っていない。正式仕様/status変更・review identity予約も未実施。
PLUGIN-CONTRACTS.md:123–142 は own real tool call と HOOK_ACTIVE を継続条件とする。
この入口を通過できる owner-cwd native session へ正式 phase 作業を引き継ぎ、
同 session が新しい challenge から自身で preflight を完了する必要がある。
調整側の emit nonce や他 session の判定を流用しない。失敗時は拒否を保持し停止する。
