# 元 T-003 の拘束範囲・依存・起動条件の追補調査

2026-10-06。非凍結の調査記録。正式な approval、review verdict、implementation report、予約ではない。
Owner: `/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge`
確認基準 HEAD: `1e86fb272643e798db4e1ca0c89f0402317a2fc8`
対象: `formal-addendum-candidate-v1.md` の未確認事項の解消。保護原本4ファイル、既存証拠、状態は変更しない。

## 確定した所有・凍結範囲

元機能は `specs/agent-cost-context-isolation/`。`tasks.md:139-205` の T-003 は Approved / Implementation Complete / high / tdd、snapshot builder 両版を含み、Blockers は T-001。T-001 (`tasks.md:9` 以降) も Approved / Implementation Complete であり Done ではない。今回の RT002 消費側 T-001 と元機能の T-001 は別物。

次の各ディレクトリに既存の integrated-verdict.json と契約があり、attempt 2 / round 1 の歴史的 PASS を記録している。今回の候補に対する PASS ではない。

- `reports/spec-review/agent-cost-context-isolation/attempt-2/round-1/spec-review-contract.json`: requirements、acceptance を両 reviewer manifest で拘束。
- `reports/impl-review/agent-cost-context-isolation/attempt-2/round-1/impl-review-contract.json`: requirements、acceptance、design、全4 layer を両 manifest で拘束。
- `reports/task-review/agent-cost-context-isolation/attempt-2/round-1/task-review-contract.json`: 上記に tasks、traceability を追加し両 manifest で拘束。

したがって「元 T-003 の layer がレビュー対象だったか」は未確認ではない。4 layer 全て実際に拘束済み。凍結本文を追補で暗黙に書き換えることはできない。T-003-review-2.md の実装独立確認用17入力 manifest は、上の正式 stage manifest とは別の証拠である。

## 現行 bytes と既存拘束の照合

読み取り専用で SHA-256 を計算。正規化は `plugins/sdd-quality-loop/scripts/check-workflow-state.sh:887-980` の status/approval と traceability 最終セル規則を再現。以下は診断結果であり gate 実行結果ではない。

|入力|現在の raw SHA-256|通常 status 正規化 SHA-256|attempt 2 との関係|
|---|---|---|---|
|requirements.md|a386237a9e36d0e584374ef67a3bc56dc048e671213d49bff4c96c5e71e8696a|dec7e500c3a16cbbc335674c392ffd18c6bcc89a85e1673578d2f02a722993ba|不一致|
|design.md|c7700c4ff46be38e886635b00ebf4e685192f573f128289bea354e45697903f5|491d67704d3ee54aa641c74b818c9a3987b3c55ace21f7262c4d50e60e1c27c7|不一致|
|tasks.md|56ba60faf6853d3392c31240b46d3915e084355fb6b4e0c2295c41a592e35927|e5f13efed5454eb44be2db5957c8497f66b9770e084f1d4775ce622f62124f7e|不一致|
|traceability.md|0dd3d808411ed0240ee1228caefbf2fad9623897f08583d6d14598877971d388|ae232c8245833e8bf4987972e971c2e988a24b78afc5448b0c6c42a4ae167e48|不一致|

tasks の追加許容形式も `Implementation Complete=0b143846c5c2dca43076e2b1ed47c97075aa7e21c9e7b1576b2111158c41bb77`、`Done=01f8b3e38a932d4cac83bb01c6006bbe2e06006a9a38fcdecb03183b7c45ca0e` で、記録 `6537478670f19b7c56c49bf1ab61906466590a031322d55dc1578d90e12a584b` と不一致。単なる通常のライフサイクル差分では説明できない。ただし本文差分の全来歴や過去の個別承認有無をこの照合だけで否定しない。

acceptance は `0ba2e6963a82848f0588735da1ba3cb6f52e7850024f6b37c9bd5ce1f1d1b766`、ux は `926e291b0bb86340d16476022ee5cd115a4b4cd36e5c6f95132d47874f9afe74`、frontend は `0b864688d9db685e54efed2572e3eb4a7bb9968ff7b1c977cd8c5304dcd0b58d`、infra は `2fb8c4611b0ab11a4e6e6cc0683f55d02104461320c607cf2a43c3bc1af1e74d`、security は `cff3fa3f4be9e38bb65e39d407847b22dd3eef34d7d7d1239aa55824db82f51a`。これら5入力は記録値と一致した。

## 依存と過去の不合格を解消済みに扱わない

`reports/quality-gate/*.md` を機能と Task ID で確認した範囲で、T-001 の最終発見記録は `reports/quality-gate/20260826T023000Z.md` (NEEDS_WORK、seq 855)、T-003 は `reports/quality-gate/20260821T071500Z.md` (NEEDS_WORK、seq 825)。この checkout でそれ以降の同2タスクの gate 記録は発見していない。

`docs/review-tickets/RT-20260821-011.yml:1-2` は status open。expected_fix は Win32 BOOL 回帰、実 command output の再取得、独立確認の誤った主張の整理、旧 gate report を gate_report_declaration とする再 gate を要求する。今回 v4 の macOS 候補試験・追加独立差分確認だけでこの ticket を close できない。Windows 未実施は未実施のまま。

T-001 が Done でないことと T-003 の Blockers 記載は確定した。今回の調査は依存を削除・免除しない。どの実行段階で Blockers が要求されるかは、その正式起動時の既存 task/preflight が判断し、準備だけを実装許可に昇格させない。

## 既存起動手順と現在止まる点

設計・タスクの post-implementation provenance re-review は既存手順である。`plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md` の該当節、`plugins/sdd-review-loop/skills/task-review-loop/SKILL.md:265` 以降を適用する。既存 attempt 最大2を確認したため、現時点の次候補は attempt 3 / round 1。ただし起動直前に空き番号を再確認する。

予定入口（未実行）:

```text
rtk proxy bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh agent-cost-context-isolation 3 1 --provenance-rereview
rtk proxy bash plugins/sdd-review-loop/scripts/task-review-precheck.sh agent-cost-context-isolation 3 1 --provenance-rereview
```

これは順番に即実行できるという意味ではない。impl precheck は `plugins/sdd-review-loop/scripts/impl-review-precheck.sh:378-379` で現行 requirements に結び付く spec PASS を要求する。現行 requirements は上記のとおり既存 spec 拘束と一致しない。`--provenance-rereview` は全条件免除ではない。

上流 spec の入口は `plugins/sdd-review-loop/scripts/spec-review-precheck.sh` だが、現在の同 script:7-35,149-151,424-430 は --reset による Passed→Pending を扱い、impl/task のような --provenance-rereview を提供しない。既存 Approved / advanced task を持つこの feature で、そのまま reset すればよいとは指示できない。現行 requirements の承認・binding 来歴を回収し、既存ライフサイクルと矛盾しない上流再拘束の正式な手順を確定することが具体的な未解決入力である。今回 reset や状態変更は行っていない。

さらに `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:324-356` の spec/impl/task 許可リストには `reports/verification/`、候補 patch、今回の追補は含まれない。単に manifest に追補を足すと許可されるとはいえない。追補に置いた mode 規範差分をどの既存許容入力・正式な承認記録に結び付けるかが必要である。ここで allowlist 拡張を提案・実装したり、候補を別名に偽装したりしない。

前提解消後のみ、各 reviewer の直前に同 precheck の `--verify-inputs`、現行 ledger に束縛した1 roleの `review-context-invocation/v2`、`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh <manifest> <owner-root> --reserve` の REVIEW_CONTEXT_OK、実在 fresh run/session と独立 A/B を用いる。B への橋渡しは counts/IDs summary のみ。全4 layer を含める。task の tasks_sha256_form=normalized は precheck 値を使用。最終 `plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature agent-cost-context-isolation` exit0 が必要。これらは未実行・未予約。

## 最小限残る管理入力と承認の境界

既存の限定修復継続承認は candidate v4、検証、適用準備、追補調査を継続する根拠として保持する。同じ包括承認は再要求しない。それを凍結本文変更、歴史的 PASS の再利用、dependency waiver、正式 reviewer 起動承認として創作しない。

未確認は次に絞られた: (1) 現行 requirements/design/tasks/traceability の既存 binding との差の承認・来歴、および advanced lifecycle を保持した上流 spec 再拘束入口、(2) mode 規範差分の正式許容入力への接続、(3) 元 T-001 の依存条件と RT-20260821-011 の未解決証拠の正式処理。新たな管理 framework は不要。

human-apply-v4-unreleased.py の release flag は false のまま。batch 自身の独立確認、隔離適用・拒否・restore 試験、Windows、正式 quality gate、exact final HEAD CI はこの調査では実行していない。planning USD 10 は実費、請求、支出許可ではない。既存 v4 履歴も追加独立確認も正式 PASS へ昇格しない。
