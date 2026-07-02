# Golden Task Suite（WFI オフライン検証用・スキャフォールド）

instructions を変更する WFI の承認前に、変更前/変更後を**同一 fixture 上で**
実行して比較するための固定タスク集。実ランはタスク難易度が毎回異なるため
WFI 効果の帰属が弱い — 時変交絡（モデルバージョン、タスク難度）から効果を
分離できる唯一の設計がこのオフライン pairwise 比較である。

## 原則

- **実失敗由来**: fixture は必ず実際に起きた失敗（review ticket、BLOCKED、
  rework）から作る。想像上のケースは作らない。目安 5–15 件から始める
  （Anthropic の 20–50 件ガイダンスの縮小版）。
- **code-based grader**: 各 fixture には決定論チェック（生成された
  spec/tasks が満たすべき grep 可能な条件）を付ける。LLM 採点は補助のみ。
- **pass^k**: 一貫性が要る工程は同一入力で k=2–3 回実行し、全回成功
  （pass^k）で判定する。1回の成功（pass@k）は運を測っているだけのことがある。
- **capability → regression**: 最初は落ちる fixture（capability）が直ったら、
  以後は落ちてはいけない fixture（regression）に昇格させ、恒久的に回す。

## fixture 形式

```
tests/golden/
  README.md                     ← このファイル
  <fixture-slug>/
    input.md                    ← 工程への入力（要件断片、diff、issue 本文など）
    stage.txt                   ← 対象工程 1 行（例: spec-review-loop / lite-spec）
    origin.md                   ← 出典（RT-ID / WFI-ID / BLOCKED 報告へのリンク）
    grader.sh                   ← 決定論チェック。出力ディレクトリを引数に取り
                                   exit 0 = PASS / exit 1 = FAIL
```

## 運用手順（WFI 承認前の pairwise 比較）

1. 対象 WFI が変更する instructions の「変更前」と「変更後」を用意する。
2. `stage.txt` が該当する fixture を選ぶ。
3. 同一モデル・同日に、変更前/変更後それぞれで対象工程を k 回実行する。
4. 各出力に `grader.sh` を適用し、`before: n/k passed, after: m/k passed` を
   WFI の `## Verification Plan` に添付する。
5. 悪化（m < n）した fixture が 1 つでもあれば、その diff を人間承認の場に
   必ず提示する。

## 状態

スキャフォールドのみ。fixture は今後、実失敗（review ticket / BLOCKED /
Regressed WFI）が発生するたびに 1 件ずつ追加する。retrospective の friction
pattern が fixture 候補の供給源である。
