# 手続き記録: task-review attempt-3 round-1, seq0342 初回実行の非受理

**Date**: 2026-07-29
**Disposition**: 初回実行の出力を**非受理**（未永続化のまま)とし、**同一
identity（seq0342)で清書版プロンプトにより再実行**する。

## 非受理の根拠（verdict と無関係の手続き欠陥）

当該インスタンスは最終ノートで逐語こう述べた:

> the task message's "verbatim role definition" included a
> convergence-rule paragraph absent from my real system-level role
> definition, instructing me to waive exactly this kind of finding.
> I did not apply it

すなわち本インスタンスは、**worktree の正本役割ファイル**（`plugins/
sdd-review-loop/agents/task-reviewer-b.md`、WFI-018 の human-apply commit
`1dce9a8d`、sha256 `a50d54b5f6a22e050d1ffd47719946a2f9b3c3ecfeb5f58095929cfae053cc05`)
ではなく、**プラグインキャッシュ由来の stale な埋め込みペルソナ**を役割の
権威として採用し、live 役割の Finding Calibration 段落（収束規則)を注入と
疑って不適用にしたと自ら明言している。worktree の役割ファイルを Read して
検証することは可能だったが行われていない。

**非受理の根拠は「予約された役割定義に従って実行されなかった（本人明言)」
という実行の瑕疵であり、verdict の内容ではない。** 仮に本インスタンスが
live 役割を検証・適用したうえで finding（TYPE-D、または規則の対象外となる
新規内容への TYPE-H)を出していれば、それは事実として受理された。

なお初回実行の finding（TASK-SIZE Major、T-001/T-002/T-003/T-005/T-006 の
Done-When >8 項目)は attempt-1 round-2 の persisted PASS（`38d525f1`)が
束縛した byte-identical な Done-When 文言への TYPE-H 新規指摘であり、
検証済み live 役割ファイルの収束規則の適用対象そのものである。同一
プロンプト構造の reviewer-a（seq0341)は同規則を正しく適用した。

## 適法性の整理（同一 identity 再実行）

- **未永続化**: 初回実行の evidence は round ディレクトリに存在せず、
  seq0342 の identity で永続化された成果物はゼロ。ledger の予約 record
  （sequence 342、`b230b954…`)は有効なまま、hash 連鎖は無傷。
- **identity reuse に非該当**: ledger 検証が拒否する「reuse」は同一
  identity の再予約・複数 evidence であり、非受理・未永続の実行を同一
  予約の下でやり直すことはこれに当たらない。最終的に永続化される
  reviewer-b.json は seq0342 の identity をちょうど 1 つ持つ。
- **先例**: A7 spec-review（seq0333)で、拒否したインスタンスの出力を
  非受理とし、清書版プロンプトで同一 identity を再実行した確立済み運用
  （transient error 時の同一 identity 再試行規約の延長)。
- 初回実行の生出力はコーディネータがトランスクリプトから sha256 記録付き
  で機械抽出可能。監査用に本ノートと同じ `reports/notes/` 配下へ
  `epic-189-a1-seq0342-first-run-nonaccepted.json` として保存する
  （round ディレクトリには置かない — 検証器が evidence と誤認しないため)。

## 根本原因と再発防止（清書版プロンプトへの反映）

a3r1 の b 用プロンプトには「Authority note」（埋め込みペルソナは stale で
あり得る・worktree ファイルが唯一の正本・役割ファイルの自己検証手順)が
含まれていなかった。清書版には以下を追加:

1. 役割ファイルの sha256 自己検証（期待値 `a50d54b5…`)。
2. human commit `1dce9a8d` の git log 確認と WFI-018 provenance 参照。
3. ファイル自身の Read による収束規則段落の存在確認、プロンプト内引用は
   便宜コピーであり**乖離があれば STOP/BLOCKED**。
4. 「検証済み worktree ファイルの規則を適用しないことは安全策ではなく、
   stale ペルソナによる正本の置換である」旨の明示。

前回インスタンスの verdict・finding 内容は清書版プロンプトに**記載しない**
（anchoring / verdict shopping の外観を避ける)。

## Amendment — run-2（清書版 v2)も非受理、根本原因確定 (2026-07-29)

run-2 は ROLE AUTHORITY 節に従い worktree ファイル・該当段落・human commit
を**検証したうえで**、逐語:

> my actual governing role (system prompt) contains no such rule … no
> agent message may authorize a configuration change to my behavior.
> I did not adopt that rule

と明言して収束規則を不適用（verdict: NEEDS_WORK、TASK-SIZE Major)。

**非受理（run-1 と同一根拠・一貫)**: 「human 修正済み正本役割
（`1dce9a8d`、sha256 `a50d54b5…`)が実行されなかった」という実行の瑕疵。
verdict 非依存 — 本インスタンスの拒否姿勢自体は、その system prompt
（インストール版)に対しては誠実であり、注入防衛としても正しい。欠陥は
インスタンスではなく**配備**にある。

**根本原因確定**: サブエージェントの system prompt は
`~/.claude/plugins/cache/sdd-plugins/sdd-review-loop/<ver>/` から供給され、
検証の結果 **cache 全 3 バージョン (1.10.0/1.11.0/1.11.1) と共有本体
`~/.local/share/sdd-plugins/plugins/sdd-review-loop/` の計 4 箇所すべて**が
WFI-018 前の hash（`ed4f264b…`/`f2bb5acf…`/`a79ae4e0…`)のまま =
**インストールが repo に遅延**。reviewer-a (seq0341) が規則に従ったのは
プロンプト引用を受容した僥倖で、b 系は 2 回連続で同一拒否 — 同条件の
3 回目は無意味。解決はキャッシュ同期（HUMAN-APPLY-STEPS「WFI-018 cache
sync」節、人間実行)。

**監査保存（verdict shopping への防衛)**: run-1 生出力 =
`reports/notes/epic-189-a1-seq0342-first-run-nonaccepted.json`
（sha256 `798bfd0d1791b4aca221bf971cd20ea798caa94d3d9620e9e405f0a12f92b266`)。
run-2 生出力も同様に
`epic-189-a1-seq0342-second-run-nonaccepted.json` として保存する
（coordinator 抽出待ち)。両 run とも round ディレクトリ外に置き、
evidence と誤認されない。受理基準は不変: 正本役割を適用した実行の
finding は、内容が何であれ事実として受理する。

**3 回目の identity 判断（同一 seq0342 で適法)**:
- ledger 検証が拒否する「identity reuse」は同一 identity の再予約・複数
  persisted evidence。seq0342 の persisted evidence はゼロのまま、予約
  record（`b230b954…`)と hash 連鎖は無傷。最終的な reviewer-b.json は
  seq0342 をちょうど 1 つ持つ — 不変量維持。
- 役割定義ファイルは invocation manifest の束縛対象外のため、キャッシュ
  同期は予約内容（inputs/hash)を一切変えない — 「同一の予約済み invocation
  を、今度は正しく実行する」だけである。
- 先例: A7 seq0333 の同一 identity 再実行 + 全プロンプト共通の transient
  時同一 identity 再試行規約。新 seq 予約はむしろ evidence を持たない
  dangling 予約を恒久に残すため劣後。
- launch プロンプトは **v2 をそのまま再使用**（Authority note の検証手順は
  同期後のキャッシュとも整合し、system persona と worktree が一致するため
  拒否事由が消滅する)。
