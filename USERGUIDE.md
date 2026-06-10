# SDD Plugins User Guide

## 1. 三層ワークフロー

このプラグイン群は、仕様作成、実装、品質保証を別の責務として扱います。

| Stage | Plugin / Skill | 結果 |
|---|---|---|
| 仕様化 | `sdd-bootstrap` / `sdd-bootstrap-interviewer` | 人間が承認できる仕様とDraftタスク |
| 実装 | `sdd-implementation` / `implement-task` | `Implementation Complete` のタスクと実装レポート |
| 品質保証 | `sdd-quality-loop` / `quality-gate` | 独立検証済みの `Done`、またはレビューYAML |
| 指摘修正 | `sdd-quality-loop` / `fix-by-review-ticket` | 指摘限定修正と再品質ゲート待ち状態 |

`tasks.md` はタスクの承認・実行順・状態の正本です。`traceability.md` は要件、設計、契約、コード、テストの整合性の正本です。

```text
Draft → Approved → In Progress → Implementation Complete → Done
                   └──────────→ Blocked
```

人間だけがタスクを `Approved` にできます。`implement-task` は `Implementation Complete` まで進め、`quality-gate` だけが `Done` を設定できます。

## 2. どのSkillを使うか

### sdd-bootstrap-interviewer

新規プロジェクト、機能追加、不具合修正の仕様を作るときに使用します。

```txt
Use the sdd-bootstrap-interviewer skill.
Mode: feature
Source: https://github.com/example/product/issues/42
```

GitHub/GitLab Issue URLを読み取れない場合はIssue本文を入力します。外部サービスへ書込みは行いません。

利用モード:

- `project`: プロジェクト憲章と最初の仕様を作る
- `feature`: 既存プロダクトへ新機能を追加する
- `bugfix`: 現象、期待動作、回帰テスト、最小修正範囲を仕様化する

生成後、要件・設計・契約・受入条件・タスクを人間が確認し、着手可能なタスクの `Approval` を `Draft` から `Approved` へ変更します。

### implement-task

承認済みタスクを1件だけ実装します。

```txt
Use the implement-task skill for specs/reservation/tasks.md#T-001
```

Skillは `tasks.md`、仕様、契約、`git status`、`git diff` を読み、既存の無関係な変更を保護します。仕様が曖昧、設計変更が必要、既存変更と干渉する場合は `Blocked` にして停止します。

実装、タスク必須テスト、関連回帰テスト、自己レビューが完了すると、次を生成します。

```text
reports/implementation/T-001.md
```

その後、タスクは `Implementation Complete` になります。これは品質保証待ちであり、完了ではありません。

### quality-gate

`Implementation Complete` のタスクを独立して検証します。

```txt
Use the quality-gate skill for specs/reservation/tasks.md#T-001
```

全CI相当チェック、仕様・契約・ADR整合性、独立批判レビューを実行します。別エージェントが利用可能なら独立レビューへ使用し、利用できなければ明確に分離した批判レビューを行います。

批判、採否、再批判は最大3サイクルです。UI変更時は利用可能なブラウザまたはPlaywrightで画面、DOM、consoleも確認します。

未解決のCritical/Major指摘がなく、すべての必須検証とトレーサビリティ更新が完了した場合だけ `Done` になります。

### fix-by-review-ticket

品質ゲートが作成したリポジトリ内YAML指摘を限定修正します。

```txt
Use the fix-by-review-ticket skill for docs/review-tickets/RT-0001.yml
```

チケット外の改善は行いません。`requires_human_decision: true` の場合は停止します。修正後は `Implementation Complete` に戻り、再度 `quality-gate` を実行します。

## 3. 新機能開発の例

GitHub Issue `#42: 設備予約のキャンセル機能` を実装する例です。

1. `sdd-bootstrap-interviewer` を `feature` モードで実行する。
2. 既存の予約処理、権限、API契約、テストを調査する。
3. requirements、design、acceptance-tests、tasks、traceabilityを生成する。
4. 人間が仕様を確認し、最初のタスクを `Approved` にする。
5. `implement-task` が承認済みタスクだけを実装する。
6. 実装レポートを確認し、`quality-gate` を実行する。
7. 品質ゲート成功後、タスクが `Done` になる。
8. commit、push、PR作成が必要なら明示的に依頼する。

GitLab Issueでも同じ流れです。bootstrapはGitLab CI、Issue、MR用テンプレートを選択します。

## 4. 不具合修正の例

GitLab Issue `予約枠が重複登録される` を修正する例です。

1. `sdd-bootstrap-interviewer` を `bugfix` モードで実行する。
2. 再現条件、期待動作、影響範囲、必要な回帰テストを仕様化する。
3. 人間が最小修正範囲を承認する。
4. `implement-task` が回帰テストと修正を実装する。
5. `quality-gate` が全体検証と独立批判レビューを行う。
6. 未解決指摘があればレビューYAMLを作成する。
7. 人間判断済み指摘を `fix-by-review-ticket` で修正し、再度 `quality-gate` を実行する。

## 5. 中断後の再開

再開時も同じ `implement-task` を使用します。別のresume用Skillはありません。

```txt
Use the implement-task skill for specs/reservation/tasks.md
```

Skillは `In Progress` タスクを優先し、`git status` と `git diff` から現在位置を復元します。対象外の変更は保護し、タスクと干渉するときだけ `Blocked` にします。

## 6. GitHubとGitLab

| Repository host | Bootstrap成果物 |
|---|---|
| GitHub | GitHub Actions、Issueテンプレート、PRテンプレート |
| GitLab | GitLab CI、Issueテンプレート、MRテンプレート |
| local | 共通仕様、契約、タスク、トレーサビリティ |

Issue URLの読取りはread-onlyです。Issue作成、コメント、commit、push、PR/MR作成は明示依頼時だけ行います。

## 7. Blockedになる条件

- タスクが `Approved` ではない
- 要件、設計、契約、受入条件が曖昧
- 認証・認可、breaking API、主要アーキテクチャの判断が必要
- 対象外の未コミット変更と干渉する
- 必須テストを実行できない
- 指摘に人間判断が必要

仕様不足の場合は `sdd-bootstrap-interviewer` へ戻り、仕様更新と再承認を行います。

## 8. v0.1.0からの移行

| v0.1.0 | v0.2.0 |
|---|---|
| bootstrap後の実装は別手段 | `sdd-implementation:implement-task` |
| `quality-gate` が実装後の小修正も広く担当 | 独立品質保証とDone判定に限定 |
| `update-traceability` | `quality-gate` の必須終了工程 |
| 2プラグイン | 3プラグイン |

通常は3プラグインすべてを導入してください。個別導入する場合:

```powershell
.\install.ps1 -Plugins sdd-bootstrap,sdd-implementation
```

## 9. トラブルシューティング

- 実装が開始されない: タスクの `Approval` と `Status`、Blockersを確認する。
- quality-gateが開始されない: タスクが `Implementation Complete` か確認する。
- Doneにならない: 品質レポートと `docs/review-tickets/*.yml` を確認する。
- UI検証ができない: 必須検証なら環境を整えてquality-gateを再実行する。
- CLI登録に失敗する: インストーラーは初回配置を削除、更新時は以前の配置へ復元する。
