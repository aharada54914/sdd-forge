# snapshot v4 正規適用準備（未リリース）

現在状態（2026-10-06後続）: 末尾「限定humanリリース」を優先する。本文の未リリース/RELEASED=Falseは各時点の履歴であり、現在は4対象に限りRELEASED=True。ファイル名は履歴参照維持のため変更しない。

## 結果と権限

4ファイル用のhuman-only候補バッチ human-apply-v4-unreleased.py を作成し、--check-only がexit 0となった。原本書込、バックアップ作成、予約、formal状態変更は行っていない。今回の承認は準備とcheck-onlyに限定する。適用分岐は RELEASED=False により停止し、CLIによる解除手段を設けていない。解除には不足条件を解決した別のレビュー済みリリースが必要であり、この定数を利用者が書き換えて実行する案内ではない。

Owner: /Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge
HEAD: 1e86fb272643e798db4e1ca0c89f0402317a2fc8
リスク: high（共有snapshotの権限・変更検出境界）。既存T-001の作業完了やT-002実装ではない。

sdd-verification-applyに従い、現行AGENTS、tasks、実装記録、保護適用契約、helper副作用を確認した。owner AGENTSは旧full-track版、現在の会話で明示された開発方針もhigh-risk保護変更をroutineとして免除しない。対象4原本のgit dirty差分はなく、checkout全体にはworkflow、AGENTS、review validator/skill、registry、別テスト等の既存変更がある。これらは変更せず保持した。

## 固定入力

バッチROWSが4つの原本before SHAとv4候補after SHAを固定する。evidence-v4.mdのパッチSHAとも一致。再利用helperは reports/verification/rt002-source-three-file-human-20261003.py、SHA-256 5fd3353a3769d0879ca5fe06b6ad9758bcfa6cec750929a81e6f0752677e84e8。一般helperとして新設せず、既存read_regular/recheck/backup_original/replace_oneを固定した読込済みバイトから再利用する。既存helperのmainやsource-root定数による適用は呼ばない。

- 初回check-only時のバッチSHA-256: 8d38597e04a10ef106a4ac44089bfefc6cada85b13b45a9060f05ed84051f00f（後述の復旧候補更新前）
- check-only記録SHA-256: 4eecf7ea9666c2dfa558fc7ed278bdeafb126bdb94d9ff0123ffa3337a17d80a
- パッチSHA-256: a1129be245b1e4b52035d66163939ba98c661e5a369b178b0b2709ed6b9ece2d

## バックアップ・再照合設計

将来の正規リリース分岐は全4原本の事前確認後、verification配下の新規0700ディレクトリへ、各原本を0600の排他的作成で保存・fsync・hash照合する。全バックアップ完成後に原本を再照合し、各置換直前にもbyte/device/inode確認を行う。既存helperの同一ディレクトリtemporaryからatomic replace、元ファイルmode維持、全4ファイルafter hash読戻しを再利用する。

バッチ全体はtransactionではない。部分失敗・保護拒否では停止し、バックアップを保持して状態確認を行い、自動再実行・自動rollback・別executorへの切替をしない。復旧は保存された各原本before SHAと現状を確認して同じ許可済みhuman経路のみで実施する。初回準備時点のrestore未作成/未実施は、後述の未リリース候補更新で限定的に解消した。正式リリース・原本での復旧は未実施。

## 実施したcheck-only

owner cwdで次を実行した（login=false）:

```text
rtk proxy python3 -B reports/verification/rt002-snapshot-mode-repair-20261006/human-apply-v4-unreleased.py --check-only
```

exit 0。HEAD、helper/patch hash、全before/after hash、4対象の一致、git apply --check、最後の原本再照合が成功した。stdout全体は human-apply-v4-check-only.json に保存。適用分岐やバックアップ/復旧分岐の実動作はこの結果で証明しない。製品suiteをこの準備で再実行したとは主張しない。

## 未充足条件（解除まで適用不可）

1. specs/epic-189-a1-rt002-repair/tasks.md のT-001 Planned Filesはhandshake verifierと対向suiteの3ファイルで、今回4ファイルを含まない。既存Approval: Approved / Status: Implementation Completeを今回の共有修復承認と読み替えない。T-002はDraft/Plannedを保持する。
2. shared snapshot修復の管理対象・明示承認範囲を確定し、必要なhigh-risk preflight/正式レビューと契約addendumを整える。必要な凍結入力の再bindを省略しない。追加契約候補は rt002-snapshot-execute-mode-candidate-20261006.md の「正式契約」節に記載されたREQ-007/design/security/TEST-003/implement-tasks対応。mode式、変更拒否、公開前検査、Windows不変、manifest v1非mode束縛を明記する。
3. reports/verification/hook-recovery-entry-contract-20260909.md:20-50 の復旧entryはticket固有の限定経路であり、snapshot変更の無条件実装許可として拡張しない。正式gateのidentity/precheck等は別途必要。
4. この新バッチ自身の独立レビューが必要。隔離した適用/拒否/復旧テストとhash固定した復旧候補は後述の追加承認範囲で作成したが、原本の適用/復旧は引き続き未承認・未実施。
5. 正規適用/readback後の原本path回帰、Windows/Linuxの適用対象検証、exact-final-head CI、installed baseline採用はそれぞれ別の証拠が必要。candidate suite成功から推定しない。

## 独立v4差分レビューの追加記録

親 /root から「v4の独立差分レビューで追加指摘なしを確認」と受領した。これは追加検証の伝達記録であり、当agentがformal reviewer予約/入力manifest/結果schemaを検証した正式PASSではない。既存verdict・statusは変更しない。バッチはこのv4レビュー後に新規作成されており、同レビューで既に評価済みとは扱わない。

USD10は従来の暫定計画見積であり実費・usage・支出承認ではない。新実装identityは作らない。

## 2026-10-06 復旧候補の限定更新

親担当から追加された範囲は、未リリースcandidateの復旧実装と一時fixture検証のみ。Owner/HEAD/4原本before hashは上記と同一。high-risk共有境界の実適用承認には拡張せず、RELEASED=False、T-001/T-002、正式予約・verdict、production/保護対象、既存dirty変更を保持する。coderとsdd-verification-applyを使用した。

既存 reports/verification/rt002-bare-envelope-candidate-20260929/apply-human.py:141 のrestoreを先に確認した。単一対象の固定hashに結合しているためそのままimportせず、同じ「backupのbefore hash/現状after hash照合とatomic replace」を既にhash固定したhelperのread_regular/recheck/replace_oneで再利用した。汎用helperや別executorは追加しない。

- 現候補バッチSHA-256: ff45619d7b6676f21059611a1818b1a5d52310d1fc2d7d0c270ec1706b1535aa
- human-apply-v4-recovery.tests.py SHA-256: 8edcef7a75bde5db8f6ce9023d897e83e9c34c7e20b9222dcb2a52539a1da0ec
- helper/patch/ROWSの全before/after pinは変更なし。

追加した --restore-human BACKUP_DIRECTORY も未リリースで即時拒否する。将来の別途レビュー済み正規リリースではexact owner/HEAD/helper hashを確認し、batch配下のno-follow 0700 backup、全4個の0600 backup before hash、全対象のbeforeまたはafter hashを全件確認してからafter対象だけを原子置換する。before対象は保持し、最後に全before hashを再確認する。未知hash/欠損/読取り不能は書込み前に停止する。候補afterファイルやpatchが失われても固定beforeとbackupから復旧可能な設計であり、これは現在の解除指示ではない。

適用・復旧中の例外と最終readback不一致はbackupパス、全対象のBEFORE/AFTER/UNKNOWN/UNREADABLE、承認済みhuman復旧のみという案内を出す。自動rollbackはしない。stopをValueErrorに統一し、以前SystemExitで失敗案内を通らなかった分岐を修正した。

実行（owner cwd、login=false）:

```text
rtk proxy python3 -B reports/verification/rt002-snapshot-mode-repair-20261006/human-apply-v4-recovery.tests.py
Ran 7 tests in 0.057s
OK
```

7 passed / 0 failed / 0 skipped。成功適用・復旧（before状態の明示再確認を含む）、backup不一致で全件無変更、未知現状hashで全件無変更、2件適用後の例外と復旧、最終readback不一致の案内と復旧、2件復旧後の例外と明示復旧再開、未リリース両書込みmode拒否を検証した。temp fixture内だけでRELEASEDをメモリ上で有効にし、同じ固定helper bytesを使用した。テスト後fixtureは削除。実ファイルのflagを変更していない。

同じ --check-only コマンドも更新後にexit 0: 全4 PIN_OKとCHECK_ONLY_OK、原本変更なし/backup作成なしを再確認した。初回保存jsonは歴史証拠として変更しない。実OSの保護拒否やdisk障害そのものは再現しておらず、例外注入の失敗経路検証である。Windows/Linux、原本適用/readback、独立レビュー、quality-gate、exact-head CI、installed adoptionはこの検証で証明しない。

### 同日・独立レビュー指摘のmode復旧修正

after bytesのSHAが同じでも外部でmodeだけ変更された場合、旧restoreはそのmodeを維持して復旧してしまうという具体的指摘を受け、未リリース候補内だけを修正した。原本4件の実modeはstatで全て0644。MODESに固定し、apply前・restore全件事前確認・置換直前・最終readbackでmodeも照合する。backupにはoriginal-modes.jsonを0600/O_EXCL/O_NOFOLLOW/fsyncで保存する。schemaはversion:1と4個のpath/modeのみで、固定ROWS/MODESから生成するcanonical bytesとSHAの双方に完全一致することを要求し、metadata側の値を信頼してpinを更新しない。mode-only外部変更はUNKNOWN_MODEとして表示し、restoreは1件も書かず拒否する。元modeを推測して外部変更を上書きしない。helper/原本/RELEASED=Falseは変更なし。

同じfixtureコマンドを再実行: 9 passed / 0 failed / 0 skipped、0.081s、exit 0。追加2件はmode-only現状変更とmetadata schema/hash不一致の全件書込み前拒否。更新後check-only exit 0。ticketと原本4件のgit diff --exit-codeも0。元7件成功は歴史記録として保持する。

- 現候補バッチSHA-256: 24bf3f6b3d7f585c036f860f3c6005c4aacae1b278e43d08883eceb94d158b07
- 現fixtureテストSHA-256: 3495df9ccf788d29f1f5cdc0b9df0d02d27c4f2c62da55b45b0e36bf3af89b49
- 以前のff45619d…/8edcef7a…はmode復旧修正前の証拠に限定。追加修正後の独立確認・正式リリースは未実施。

## 2026-10-06 限定humanリリース

主担当から、独立scratch_candidate_auditによるmode指摘解消・9/9/check-only成功・新具体不具合なしを受領した。これは正式gate verdictではない。主担当が適用したRT-20260821-011のgit diffを本担当も確認した: 不足3対象path、fixed candidate-v4.patchを伴う限定mode expected_fix、2参照だけを追加し、status open/既存3条件/auto_fix_allowed:false/requires_human_decision:falseを保持している。ticket SHA-256はa483e11485e9a01ff80a3a724c43f40a5cce61ab84af9416cd254de0609d795f。formal-addendum-candidate-v1.md §8の既存ユーザー承認原文へ接続され、新full計画や新承認欄は作成していない。

この条件確認と主担当の限定リリース指示を根拠にRELEASED=Trueへ変更した。4原本だけを対象としticket自体をbatch対象に追加していない。機能差分はrelease flagと案内文のみ。fixture setupはreleased状態をassertTrueし、test_unreleased_blocks_both_write_modesは明示RELEASED=Falseで両書込みmode拒否を検証するまま保持した。

再実行（上記owner、login=false）: python3 -B human-apply-v4-recovery.tests.py は9 passed / 0 failed / 0 skipped、0.081s、exit 0。python3 -B human-apply-v4-unreleased.py --check-only は全4 PIN_OK/CHECK_ONLY_OK、exit 0。どちらもrtk proxy経由。原本apply/restore、実backup作成、正式gate/予約/状態変更は未実施。リリースは人の限定適用の準備完了であり、製品release/merge/installed adoptionとは別。

- リリースbatch SHA-256: 66ea9364090bf23372be020c3e292912c7ab83a9967d63c01892aebafe734b19
- リリースfixtureテストSHA-256: 43d09fd5cf85d922dd9f30709bc354a462ff20bc488b2a417bb1ead6b50ee54b
- HEAD/helper/patch/4対象before-after/modeのpinは変更なし。

人間だけが実行する限定適用コマンド（エージェントは実行禁止）:

```sh
cd /Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge
rtk proxy python3 -B reports/verification/rt002-snapshot-mode-repair-20261006/human-apply-v4-unreleased.py --apply-human
```

成功時のAPPLIED_ONCE_READBACK_OKとBACKUP_DIRECTORYを保存して主担当へ返す。失敗・guard拒否なら停止し、pin変更/別executor/自動再実行を行わず全出力とbackupを保持する。restoreは同batchの--restore-humanへ表示された正確な絶対backup directoryを渡す人間限定経路だが、現状調査前の機械的rollbackはしない。UNKNOWN/UNKNOWN_MODE/UNREADABLEは先に調査する。

残件は原本適用後のreadback/原本回帰、Windows/Linux対象検証、元ticketのWin32/既存AC/独立主張整理・依存T-001、正式quality-gate、fresh RT002 session、CI/installed/release。これらを本batchリリースで解決扱いにしない。新full計画を要求せず、既存ticket/legacy経路で追跡する。
