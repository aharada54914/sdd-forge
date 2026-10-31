# 共有snapshot実行mode修復 — 限定正式追補候補 v1

状態: 非凍結の管理入力候補。未採用・未予約・正式判定なし。適用バッチは未リリース。
対象候補: candidate-v4.patch（SHA-256 a1129be245b1e4b52035d66163939ba98c661e5a369b178b0b2709ed6b9ece2d）。

## 1. 既存承認と所有の接続

実装契約の元所有者は agent-cost-context-isolation T-003。tasks.md:139-205では Approval: Approved、Status: Implementation Complete、Risk: high、Required Workflow: tdd、REQ-007/REQ-010・AC-003/AC-004、paired snapshot builders/validators/fixturesを対象とし、BlockersはT-001。既存承認と履歴は保持する。依存T-001の受入状態はこの準備では判定していない。

今回の起点は epic-189-a1-rt002-repair T-001 のsnapshot再検証阻害。RT002 T-001はApproved / Implementation Complete / highで、verifierとhandshake suitesの3ファイルを所有する。T-002はDraft / Planned、T-001依存で、release検証を所有する。snapshot修復をRT002の3ファイル本体修復やDraft T-002実装と混同しない。

提案ルートは、元T-003の共有snapshot契約に対する限定修復追補を既存許可の非凍結宣言経路で扱い、RT002へ共有前提修復の正確なハッシュと検証結果を引き渡すもの。routineへの移行、既存タスク分割、Done/承認変更、古いPASSの新候補への流用は提案しない。

現在の人の承認として親から伝達された候補作成・限定修正・回帰・適用準備はその範囲内で使用済みであり、同じ包括承認を再要求しない。既存2026-09-09復旧entryのticket固有許可を一般snapshot修復へ暗黙拡大しない。2026-09-16 task receipt recovery拡張もprecheck・prior-PASS transport・invocation検証の記録であり、このmode規則の正式入力登録済み証拠とはしない。

## 2. 固定範囲・リスク

Owner: /Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge
HEAD: 1e86fb272643e798db4e1ca0c89f0402317a2fc8
branch: codex/rt002-host-denial-repair（既存owner記録）。適用直前に再確認する。

対象は次の4ファイルだけ。各before/after hashは human-apply-v4-unreleased.py のROWSおよび human-apply-v4-check-only.json に固定。

1. plugins/sdd-implementation/scripts/prepare-task-snapshot.sh
2. plugins/sdd-implementation/scripts/prepare-task-snapshot.ps1
3. tests/task-context-isolation.tests.sh
4. tests/task-context-isolation.tests.ps1

highを維持する。変更は共有入力の実行権と変更検出に達するため、行数やroutine開発方針を根拠に管理を軽減しない。既存dirty workflow/AGENTS/review境界/registry/別テスト等は範囲外で保持する。

## 3. 採用候補の規範差分

REQ-007（requirements.md:94-103）、design.md:94-109、security-spec.md:3-8のread-only/no-follow/hash/mutation/atomic公開を保ったまま、Unix snapshot通常ファイルのmodeを次に具体化する。

- 検証したsource modeのexecute maskだけを保持し、出力modeを 0444 | (source_mode & 0111) とする。
- write/setuid/setgid/stickyは付与しない。非実行入力へ拡張子/shebangを根拠にexecuteを追加しない。ディレクトリ0555を維持する。
- source modeをcopy前/open後/copy後/path再照合で確認し、copy中のmode-only変更も既存TASK_INPUT_HASHで拒否する。公開前に候補が意図した出力modeを確認する。
- Windowsの既存ReadOnly/ACL方式を変更しない。Unix modeケースは既存OS判定で限定し、未実施Windowsを成功としない。
- manifest/v1のfield/schema、内容hash、run/session/identity/cost、入出力allowlist、公開/cleanup/拒否条件は変更しない。内容SHAはmodeを束縛せず、TASK_INPUT_OKは公開後mode-only改変の検出証拠ではない。同一uidに対するchmod不可能性も主張しない。
- TEST-003の既存negativeを保持し、実行mask・非実行・readonly・mode-only raceを追加する。callerを別interpreterへ変更して失敗回避しない。

## 4. field / counterpart / negative preflight候補

| 変更する観測可能値 | 対応契約 | 不一致で失敗する確認 |
| --- | --- | --- |
| Unix出力execute mask | REQ-007/read-only＋本mode式 | source0755などで旧0444が失敗する既存RED記録 |
| 非実行入力mode | 元execute mask 0を維持 | shebang付き非実行fileの直接起動拒否 |
| write/special bits | security read-only | file write・create/delete拒否、07755→0555 |
| source copy時mode | mutation/no-follow境界 | barrier中0755→0644でTASK_INPUT_HASH、finalなし、tmp清掃 |
| Bash/PowerShell結果 | paired runtime契約 | 両suiteの同じmode/race条件と診断カテゴリ |
| 新manifest evidence | path/content SHAのまま | 既存hash/path/identity/schema negativesを維持 |

この表は正式実装preflightへの採用候補であり、Implementation Completeや品質判定の新規宣言ではない。新しいpersisted schema fieldは追加しない。

## 5. 観測済みと未実施

観測済みのcandidate evidenceは evidence.md / evidence-v3.md / evidence-v4.md / suite-results-v4.json。元両builderは各22確認中6失敗、候補のfocused mode checksは各25/25成功。v4両candidate suiteはexit 0。これはfixture/candidate環境の結果であり原本適用後証明ではない。

v4 Bash待機は1500回の有限poll後SIGKILL/wait。SIGSTOP直接子を26.3246秒で終了回収した（stopped-child-v4.json）。厳密15秒wall deadlineや任意子孫treeの終了保証とはしない。

親よりv4独立差分レビューの追加指摘なしを受領したが、formal gateの予約/入力schema/identity検証済みPASSとは記録しない。新humanバッチはこのレビュー後の追加artifactであり独立レビュー未実施。

未実施: 原本適用・原本path回帰、native Windows/Linux CI、バッチapply/refusal/restore隔離テストと具体restoreリリース、正式gate、installed promotion、RT002 fresh snapshot再検証、release/merge。check-only成功はこれらの代用でない。

## 6. development-policyとの照合

参照版は /Users/jrmag/sdd-forge/docs/development-policy.md、SHA-256 2755c58dc0a6dddd398c89b3ce532cd994a2f34683d0844930b99aa7b50826ca。ownerには当該文書が存在しない。参考照合を行っただけでownerへ自動採用・コピーしていない。

同文書「Existing tasks and evidence: transition procedure」の保持・scope内再利用・normative deltaのspecific decision・fresh input binding・既存review維持に従う案。今回routine routeを採用しないためroutineへの移行承認は不要。ownerへの開発方針採用が必要ならAdoption boundaryに従う別の管理記録とし、snapshot修復の承認代用にしない。

現在の入力hash（凍結範囲を確定したとの主張ではない）:

| 入力 | SHA-256 |
| --- | --- |
| owner AGENTS.md | c528425ccbd81e76a7b6ff5fbff461c4175bdf8643416918056f15097e488850 |
| RT002 tasks.md | d7d70f58f6f02ecc54c88bdda19c601e8e40e2b2d05074ca2afabd1cc882146c |
| agent-cost tasks.md | 56ba60faf6853d3392c31240b46d3915e084355fb6b4e0c2295c41a592e35927 |
| agent-cost requirements.md | a386237a9e36d0e584374ef67a3bc56dc048e671213d49bff4c96c5e71e8696a |
| agent-cost design.md | c7700c4ff46be38e886635b00ebf4e685192f573f128289bea354e45697903f5 |
| agent-cost security-spec.md | cff3fa3f4be9e38bb65e39d407847b22dd3eef34d7d7d1239aa55824db82f51a |
| agent-cost acceptance-tests.md | 0ba2e6963a82848f0588735da1ba3cb6f52e7850024f6b37c9bd5ce1f1d1b766 |
| agent-cost traceability.md | 0dd3d808411ed0240ee1228caefbf2fad9623897f08583d6d14598877971d388 |
| RT002 recovery entry | 2ca4125082c495724b0bbde33e7451edb21fc4042827c1e67b4354eb9215e79f |
| RT002 ticket | ae2b554aa9416c2997bef00143183f3cbcc7d79610c000d7c7b8928175241d74 |

## 7. 不足する最小管理入力と独立確認条件

不足は「もう一度すべて承認」ではなく以下の具体的入力である。

1. 既存限定修復承認をこの元T-003/shared prerequisiteへ接続する管理記録。本追補の4対象・mode具体化を許可済み契約として採用する決定と正規の管理owner/経路。RT002 T-001のPlanned Filesに無断追加しない。
2. 元T-003の実際のpassed-stage入力manifest/歴史verdictと依存T-001の根拠。上表はcurrent hashに過ぎないため、何が凍結済みかを当該gate記録で確定し、変更する規範入力だけ正式再review/rebindする。新規予約は本準備ではしない。
3. distinct reviewerへ本追補・元仕様の必要範囲・4原本/v4候補・実測/未実施・humanバッチ/復旧候補を正規path/SHA入力として渡す条件。追加指摘なしをformal PASSへ転記しない。
4. humanバッチの独立確認と隔離apply/refusal/restore試験、hash固定restore手段。完了までは未リリースを保ち、人に--apply実行を依頼しない。
5. 正規適用後の原本回帰と必要host/CI、およびRT002新manifest/snapshot/fresh実sessionへ渡すexact hashのhandoff。installed選択/昇格は明示scopeがある場合のみ。

過去の承認・判定・予約・raw証拠を変更しない。既存active reviewがあればその固定入力を維持し、本候補を無断差替えしない。USD10は引き続き計画見積のみ。

## 8. 2026-10-06 既存T-003修復ticketへの限定scope接続候補

出典は主担当が本会話で確認し伝達したユーザー原文（追記担当による直接閲覧ではない）:

> 全部承認する
> 追加で何回でもレビュー、限定修正して良い

この追加限定修正承認を、既存 `docs/review-tickets/RT-20260821-011.yml`（agent-cost-context-isolation T-003）の共有snapshot前提修復へ接続する管理記録候補とする。対象は§2のpaired builder/suite 4ファイル、固定candidate-v4.patch、§3のUnix mode保持・copy中mode変更拒否だけ。元ticketにmode修復が初めから記載されていたとは扱わない。正式ticket本文・approval/status・凍結仕様は変更せず、新ticket・新full計画も作らない。既存legacy/ticket経路を用いる判断は `formal-provenance-followup-v2.md` を優先し、§7の歴史full-stage再review調査を今回必須の新計画と読み替えない。

旧ticketのWin32 MoveFileW BOOL修復・AC-003/AC-004の実出力/manifest再gate・独立確認主張整理、および依存T-001の `RT-20260821-009` は免除・解決認定しない。Windows/identity/manifest契約、保護経路、only quality-gate may set Doneを維持する。mode修復の限定証拠だけでticket全体をresolvedにしない（元ticket expected_fix、fix-by-review-ticket/SKILL.md:11-28）。

§5/§7のバッチ隔離試験未実施という記載は初回準備時点のもの。`human-apply-v4-preparation.md` の復旧候補更新で7件成功を記録し、主担当から同7件の再実行成功も受領した。これはcandidate/fixture証拠であり正式PASSではない。humanバッチの `RELEASED=False` を保持し、原本適用・正式予約・判定・状態変更・人への実適用コマンド配布は本追記で行わない。

続く独立指摘のmode復旧修正後は同準備記録の9件成功と新batch/test hashを参照する。§6のticket hashは旧記録値であり、今回読取った元ticketのSHA-256は37183659952b749fc4091c5dd1a9c2f376e7bd6b6dd5644aeffbae89c85f5769（git diffなし）。旧hashを新たな固定入力として流用しない。
