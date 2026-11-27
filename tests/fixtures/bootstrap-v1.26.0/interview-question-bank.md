# Interview Question Bank

Use this bank for full-profile interviews. Ask only applicable probes, but do
not silently omit a layer: record a reasoned N/A and identify the owner of any
unresolved answer.

## Product and Scope

- 何を作りたいですか？
- それは誰のどんな課題を解決しますか？
- 既存の代替手段は何ですか？
- そのソフトが成功したと言える状態は何ですか？
- 最初のMVPで絶対必要な機能は何ですか？
- MVPに入れない機能は何ですか？
- EN: Which user outcomes must be visible in UX states and acceptance criteria?
- EN: Which product constraints belong to frontend, infrastructure, or security?
- EN: Which capabilities are explicitly out of scope for every layer?

## Users, Roles, and UX

- 利用者は誰ですか？
- 管理者はいますか？
- 承認者、閲覧者、外部ユーザーはいますか？
- 権限ごとにできることは何ですか？
- EN: Which target views and navigation paths exist for each role?
- EN: What empty, loading, error, success, and recovery states must users see?
- EN: Which WCAG 2.2 AA, breakpoint, input, and assistive-technology constraints apply?

## Data and Contracts

- 主なデータは何ですか？
- 個人情報は扱いますか？
- 添付ファイルは扱いますか？
- データ保持期間はありますか？
- CSV/Excelインポート・エクスポートは必要ですか？
- EN: Which typed request, response, event, and state shapes cross layer boundaries?
- EN: How is each entity classified, encrypted, retained, exported, and deleted?
- EN: Which schema/version compatibility rules and validation failures are observable?

## Workflow and Acceptance

- ユーザーは最初に何をしますか？
- 通常フローは何ですか？
- 異常系は何ですか？
- 承認、差戻し、キャンセルはありますか？
- EN: Which interaction sequence maps each step to REQ-NNN and AC-NNN?
- EN: What retries, timeouts, idempotency, rollback, and partial-failure paths exist?
- EN: Which deterministic evidence proves each layer-owned acceptance criterion?

## Frontend Architecture

- フロントエンドは必要ですか？
- EN: What component tree, route boundaries, and server/client ownership are required?
- EN: Where does state live, how does it transition, and what is persisted?
- EN: What LCP, INP, CLS, code-splitting, and bundle-size budgets must be enforced?

## Backend, API, and Testing

- Webアプリですか？APIですか？CLIですか？
- バックエンドは必要ですか？
- DBは必要ですか？
- 外部システム連携はありますか？
- EN: Which API client, authentication attachment, retry, and error-normalization rules apply?
- EN: Which contract, integration, negative, and end-to-end tests are required?
- EN: Which API or event changes require versioning, ADRs, or migration evidence?

## Infrastructure and Operations

- デプロイ先はどこですか？
- 想定ユーザー数は？
- レスポンス速度の要求は？
- 可用性の要求は？
- 運用者は誰ですか？
- EN: What topology, environments, IaC ownership, and promotion sequence are required?
- EN: What numeric availability, p95 latency, scaling, and capacity targets apply?
- EN: What logs, traces, metrics, alerts, cost controls, backups, and rollback evidence are required?

## Security and Compliance

- 認証はどうしますか？
- 監査ログは必要ですか？
- セキュリティ要件は？
- EN: Which trust boundaries need at least two STRIDE threats and mitigations?
- EN: Which authorization decisions, tenant/entity ownership checks, and denial paths apply?
- EN: Which OWASP, secrets, SBOM, supply-chain, residency, and compliance controls must be tested?

## Layer Coverage Checklist

- UX: views, journeys, component states, navigation, accessibility, responsive behavior, and tokens.
- Frontend: stack, component tree, state, routes, API client, budgets, dependencies, and tests.
- Infrastructure: topology, CI/CD, environments, IaC, scaling, SLOs, data operations, observability, cost, and rollback.
- Security: trust boundaries, STRIDE, authentication, authorization, data controls, OWASP, secrets, supply chain, and security tests.
- Cross-layer: every applicable REQ-NNN has a canonical Layer Spec anchor and every N/A has a reason.
