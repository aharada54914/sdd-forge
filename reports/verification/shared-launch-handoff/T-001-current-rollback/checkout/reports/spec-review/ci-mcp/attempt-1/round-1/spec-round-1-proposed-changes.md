# Proposed Changes — spec-review ci-mcp attempt-1 round-1

Findings addressed: AMBIGUITY (Major), DOWNSTREAM-READINESS (Major) — REQ-006 /
AC-010 の 401・403 エラーコード写像が選言(「または」)のままで、実装者ごとに
挙動が分岐しうる。

## Change 1 — specs/ci-mcp/requirements.md REQ-006

選言を排し、決定的な写像規則に置換する:

- 401 → 常に `auth-missing`(トークン未設定・無効・失効を区別せず。区別が必要な
  場合は `details.status: 401` で示す)。`upstream-error` へは写像しない。
- 403 → レスポンスに rate limit 指標(`x-ratelimit-remaining: 0` ヘッダまたは
  `retry-after` ヘッダ)が存在する場合に限り `rate-limited`。指標がない 403 は
  `upstream-error`(`details.status: 403`)。`path-denied` は上流 403 には使用
  しない(ローカル入力ガード専用のコードとして予約)。
- 404 → `not-found`、429 → `rate-limited`、5xx / ネットワーク失敗 →
  `upstream-error`(変更なし)。

根拠: REQ-005 が「トークン未設定 → auth-missing」を既に規定しており、401(認証
不能)を同カテゴリへ一本化するのが最小驚愕。`path-denied` は sdd-forge-mcp /
local-env-mcp でローカル境界拒否に使われており、上流権限拒否への転用は意味の
衝突を生むため除外。

## Change 2 — specs/ci-mcp/acceptance-tests.md AC-010

写像規則の全分岐(401 → auth-missing、403+rate-limit 指標 → rate-limited、
指標なし 403 → upstream-error、404 → not-found、429 → rate-limited、5xx /
ネットワーク失敗 → upstream-error)を明記し、指標なし 403 のテストケースを
追加する。

## Disposition

Orchestrator applied both changes verbatim (editorial disambiguation within
already-approved scope; no new product decision — OQ-001..004 remain open and
unchanged). Round 2 re-review invoked with `--edit-summary`.
