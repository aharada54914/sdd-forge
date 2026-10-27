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

実失敗に由来する元の5ケースと、新たな2件の保留用ケースを登録済み。
追加時は review ticket / BLOCKED / Regressed WFI や実走ログへ出典を結び付ける。
retrospective の friction pattern も fixture 候補の供給源になる。

## Source-backed deterministic cases (#600/#601)

Five reduced controls now live under this directory: `unrun-pass`,
`wrong-routing`, `weak-cleanup`, `overbroad-validation`, and `stale-skill`.
Each records its actual incident source in `origin.md`. A reduced control is not
an exact historical replay or proof of the original cause. `case.json` is grader
metadata and must stay outside candidate context. The tuning/held-out split is
fixed there; do not tune prompts using held-out outcomes or relabel cases after
seeing results. These cases are public, so they are held out from the local
adjustment cycle, not claimed to be absent from model training.

Two later, fresh held-out controls (`bundled-audit-readiness` and
`cancelled-result-fencing`) derive from actual CI/runner failures observed on
2026-10-27. Their source observations and public output contracts were frozen
before candidate runs. They are separate from the now-exposed original five
cases; retain both cohorts and do not tune instructions from the new outcomes.

The 2026-10-27 native diagnostic exposed all five original cases. Its frozen
first comparison remains a v1 diagnostic; the original `held-out` labels no
longer establish unseen evaluation for later tuning or reruns. Three cases now
provide a public `output-contract.schema.json` alongside their natural input.
It declares the output grammar and alternative values, not the expected verdict,
incident origin, A/B label or grading metadata. This corrects hidden exact-wording
requirements: a model previously had no way to infer that `partial` must be
spelled `incomplete`, or that a free-text human-reconciliation action needed a
specific enum value. Grader expectations, source preservation and negative tests
remain strict. New case hashes define a separate experiment; do not compare its
success count directly with v1 as a framework improvement or call its exposed
cases held out. Establish a fresh unseen set before making a generalization.

Prepare only natural input and project-shaped fixture files for an independently
isolated executor (use neutral workspace names):

```sh
python3 tests/golden-eval.py prepare --case unrun-pass --output /tmp/project-cedar
python3 tests/golden-eval.py grade --case unrun-pass --output /tmp/project-cedar
```

The grader checks actual output bytes/JSON and retained source files. A PASS
claim, output symlink, changed source, extra output, missing cleanup or malformed
JSON cannot substitute for the required artifacts. Every `grader.sh` uses this
same grader. `tests/golden-eval.tests.py` checks valid and intentionally bad
outputs, false completion, retained evidence, source changes and poisoned JSON.

Collection is deliberately separate: no model call or containment claim follows
from creating a temporary directory. Use an existing host executor with verified
filesystem/tool isolation and an observed timeout/cancellation boundary. Keep
rubric, origin, A/B mapping and experiment metadata out of its accessible input.
The collector must enforce limits *before and during execution*; retrospective
comparison cannot enforce an already-spent budget. Do not invoke a plain model
CLI in these directories and call that a blind or contained experiment.

The passive comparison interface is:

```sh
python3 tests/golden-eval.py compare --manifest experiment.json
```

`golden-comparison/v1` has `cases`, `repetitions` (initial value 3; 1–10),
`timeout_seconds`, `total_seconds_limit`, `conditions` (`model`, `effort`, `host`,
`tool_permissions`), `variants` (A/B each with `framework_revision`, `config_sha256`, `adapter_version`),
`case_sha256`, `input_sha256`, and `runs`. Freeze these inputs
before collection. `prepare` returns the case/input digests. Runs are ordered by
case, then repetition, alternating A/B and B/A. Every run records `case`,
`variant` (A/B), `repetition`, `status` (completed/failed/timeout/interrupted/not-run),
`seconds`, identical `conditions` and `input_sha256`, boolean `safety_violation`
and `required_regression`, and observed `tokens`/`cost` or null with explicit
`tokens_unavailable_reason`/`cost_unavailable_reason`. Every attempted run must pin an independently collected nonempty tool log via
relative `trace` and `trace_sha256`; not-run cells carry no execution claim.
Completed runs additionally name a relative `output` directory and its `output_sha256` from `snapshot()`.
Retain all failed, interrupted and unrun cells; omission and duplicate trials
are errors. The externally supplied observations are not independently
authenticated and are never product gate evidence.

The result preserves trial artifacts and checks, n/k, all-success, median/range,
null p95 for the small fixed sample, unknown metrics and the split. Any observed safety/required-check regression or exceeded budget fails
`mechanical_criteria_satisfied`. `adoption_eligible` is always false until
collection authenticity, actual tool traces and independent safety observations
are reviewed outside this passive helper. `adoption_decision` always stays
`pending-human`; this tool does not approve or change task state. Freeze the result before revealing the A/B identities. Human
UX judgments and real-app evaluation remain separate. The deterministic suite
alone does not demonstrate native model behavior, comparative superiority or
retention. Actual native diagnostic epochs and a separately frozen held-out
cohort are recorded in `reports/verification/golden-{native,contract,heldout}-20261027/`.
No automatic adoption or broad superiority claim follows from those results.
