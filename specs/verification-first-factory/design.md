# Design: Verification-First & Self-Verification Factory (`verification-first-factory`)

- **Feature:** `verification-first-factory`
- **Version:** `v2.2`（レビュー指摘 C1–C3 / M1–M6 / Minor 全件反映版）
- **Related ADR:** `docs/adr/0054-verification-first-and-agentic-factory.md`（**WFI-013 再確認指示**: 正式起票・マージ直前に `ls docs/adr/` とオープン PR で `0054` の空きを再確認すること）
- **Target Runtime:** Node.js >= 20 LTS（`plugins/sdd-quality-loop/scripts/v2/*.mjs` 単一実装）

---

## 1. Problem Reframing（暗黙の前提とアプローチ比較 — `REQ-001` 準拠）

### 暗黙の前提（Assumptions & WFI-011 根拠）
1. `tests/` 直下には実測 **386 ファイル**（`find tests -maxdepth 1 -type f | wc -l`）、`tests/verification-catalog.json` 登録 **262 件中 252 件（96%）が現行 CI 未実行**（`node tests/verification-catalog-status.mjs`：稼働 10 / CI 外 196 / ゴースト 56、`resolve-project-context*` 24 ファイル）という状態だが、「新検証を足し算するだけで旧テストはそのまま残すしかない」という先入観がある。
2. `plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs` は実測 **663 行**（`wc -l`）であり、Layer 1 に重い検証を追加せず現行 663 行を非肥大化ラチェット（`<= 700` 行）で守る必要がある。

### アプローチ比較
| 観点 | 案A：最小変更案（Incremental） | 案B：両輪 Dogfooding ＋ テスト引き算案（Ambitious / **採用案**） |
| :--- | :--- | :--- |
| **概要** | 利用者向けプラグイン機能だけを追加し、本体テスト 386 ファイルには手を付けない。 | **Self-First（軸Aで本体に先行適用・実証）→ Productize（軸Bへ展開）**の順序を採用。本体コア（`task-lock.mjs`, `run-sdd-gate.mjs`）を TLA+ 化し、Self-Fitness Function と ESM 集約で既存テストの4カテゴリを安全廃止・統合する。境界保護は `git diff`＋`CODEOWNERS` に統一。 |
| **メリット** | 既存テスト棚卸しコストが不要。 | 本体品質の機械保証・CI 負荷圧縮・`ADR-0051` 軽量性維持・既存終了コード非破壊・Windows 互換・将来の `lean4` 拡張を同時達成できる。 |
| **トレードオフ** | 多言語重複テストが放置され、未実証ルールを利用者へ押し付けるリスクが高い。 | `CODEOWNERS` 保護の `sdd/approved-test-retirements.json` と負例ミュータント・パリティ証明の運用が必要だが、回帰と改ざん迂回の双方を防げる。 |

---

## 2. コンポーネント設計・終了コード非破壊・Windows プロセス起動

### 2.1 既存スクリプト終了コードの非破壊方針（M1 対応）
- `task-lock.mjs:345`（`exit 1`）、`sdd-soft-guard.mjs`（`exit 2`）、`validate-concept-test.py`（`2`/`3`）、`finalize-domain-review.*`（`exit 3`）の終了コードは**一切変更しない**。
- 新規終了コード規約（`0: PASS/WARN`, `1: FAIL`, `2: TOOL_ERROR`, `4: TAMPER_DETECTED`, `10: DEFERRED_TO_CI`）は新規 v2 ゲートスクリプト4本（`discover-state-machines.mjs`, `run-formal-gate.mjs`, `run-agent-lint.mjs`, `run-security-gate.mjs`）および `run-sdd-gate.mjs` の集約 JSON 出力のみに適用する。

### 2.2 Windows 互換プロセス起動設計（M5: Node 20.12+ CVE-2024-27980 対応）
- Node.js 20.12+ では `child_process.execFile(..., { shell: false })` で `.cmd` / `.bat` ラッパーを起動できない。
- **JVM ツール（`tlc` / `apalache`）**: ラッパー `.bat`/`.cmd` ではなく `java` 実行ファイル（`JAVA_HOME/bin/java.exe` または PATH 上の `java`）を直接 `execFile('java', ['-Xmx...', '-cp', jarPath, 'tlc2.TLC', ...], { shell: false })` で起動する。
- **ネイティブ・npm CLI ツール（`semgrep`, `gitleaks`, `trufflehog`, `codeql`, `socket`）**: 実行可能バイナリ（`.exe` / ELF / Mach-O）または `node`＋パッケージ JS エントリポイントを直接解決して `execFile(..., { shell: false })` で起動し、未解決の `.cmd`/`.bat` は `TOOL_ERROR`（終了コード `2`）で拒否する。

### 2.3 チェッカー非依存 形式検証アダプタ契約（TLA+ 標準・Lean 4 拡張対応）
```ts
interface FormalCheckerAdapter {
  readonly id: "tlc" | "apalache" | "lean4";
  detectTool(env: NodeJS.ProcessEnv): Promise<{ available: boolean; version?: string; binPath?: string }>;
  checkSpec(input: {
    specEntry: string;
    configFile?: string;
    timeoutSec: number;
    options: Record<string, unknown>;
  }): Promise<{
    status: "PASS" | "FAIL" | "TIMEOUT" | "TOOL_ERROR";
    violatedInvariant?: string;
    traceFile?: string;
    summary: string;
  }>;
  validateTrace?(input: {
    mappingFile: string;
    traceGlob: string;
  }): Promise<{ status: "PASS" | "FAIL"; mismatchedStep?: number; reason?: string }>;
}
```
- 正規 TLA+ 回帰フィクスチャは [tests/fixtures/project-skills/formal-review-reservation/Reservation.tla](https://github.com/aharada54914/sdd-forge/blob/main/tests/fixtures/project-skills/formal-review-reservation/Reservation.tla) を使用する（`reports/verification/` 配下の過去証跡は参照しない）。

---

## 3. 安全廃止プロトコル・CI 時間予算・ロールバック区分

- **人間専用廃止承認マニフェスト（M2 対応）**: `sdd/approved-test-retirements.json` をルートの `CODEOWNERS` および `anti_tampering.protected_repo_paths` で保護し、`{ path, git_blob_sha, reason, approved_by }` の完全一致のみを `REQ-010` のテスト削除例外として受理する。
- **負例ミュータント・パリティ証明（M3 対応）**: 置換先（Fitness Function / TLA+＋Trace Validation / 単一 `.test.mjs`）は、廃止対象テストの各失敗モードに対応する最低1件の明示的ミュータント（負例）を 100% 検知することを Shadow 並走で証明する。カテゴリ2（`.ps1`/`.sh` パリティテスト）は対応本番スクリプトの ESM 集約＋Windows ネイティブ CI 検証完了までブロック（廃止禁止）。
- **CI 時間・コスト見積もり（NFR-004）**: Gitleaks（5〜15s/PR）、Semgrep diff-only（20〜60s/PR）、TLC 有界検査（変更時のみ `<= 120s`）、CodeQL（夜間のみ 5〜15分、公開リポジトリ無料）。
- **ロールバック区分（M4 対応）**: 新規ゲート実行は `sdd/guardrails.yaml` の各 `enabled: false` で即座に無効化できる（可逆）。削除済み旧テストおよび `verification-catalog.json` 変更の復元は該当 PR の `git revert` で行う（フラグ不可逆）。
