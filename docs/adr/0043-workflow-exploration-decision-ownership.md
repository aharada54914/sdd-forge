# ADR-0043: Playbooks and decision packets remain passive

Status: Accepted (implementation ownership, not a human choice of a product option)

Issues #599/#622 need reusable methods and a readable comparison without another
workflow engine. A new orchestration service, a second approval form and a thin
local advisory helper were considered. The local helper preserves existing entry
points and authority with the smallest additional surface.

Bootstrap selects one explicit bounded playbook. Ship may hand exploration back
to bootstrap, but its existing target/track checks remain authoritative. The helper
does not execute commands or grant effects. Host isolation must already exist for
prototype writes. Decision packets are versioned, immutable JSON references and
escaped Markdown displays; fixed packet and input hashes prevent stale resume or
cross-target reuse. Observations remain claims attributable to pinned original
artifacts, not new gate verdicts. Concept decisions delegate to existing signed
concept-test validation. Non-concept adopt/reject/hold records extend the existing
human/CI-only approval-sidecar signer with a versioned content type. Its existing
HMAC, registry and staging/publisher machinery binds an immutable packet/target/run/
alternative/reason/expiry record. The choice never grants task approval or Done.
Per-ID signed history retains rejections and holds; a signed successor prevents
replaying the previous choice as current. Canonical live paths and protected
constant basenames preserve source ownership. No new signing key, approval engine,
task state engine or Conversation WAL is introduced.

## Executor evaluation for #623

The current managed model entry's `_run_cli` bounds one subprocess and kills its
process group during cleanup. It is an internal invocation helper, not an adapter
with public work-order admission, restart lease, duplicate event reconciliation,
late-result rejection or atomic port/DB/file ownership reservations.
`run-lite-gate.py` executes required checks with subprocess timeouts; it owns gate
execution and must not become a discretionary factory dispatcher. The verification
runner similarly owns catalog suites, not durable work orders. Read-only MCP tools
have no execution ownership. These are concrete interface gaps even for two jobs;
absence of a large scheduler alone is not the reason to stop.

The initial internal-source inventory did not establish a supported public
adapter with that complete contract. Later real GitHub Actions observations
supersede a blanket “no executor” conclusion: run 40424313355 demonstrated native
cancel/retry and existing origin-reconciler rejection of a cancelled attempt's
zero-exit artifact. Run 40544596926 demonstrated normal Linux cancellation with
the existing subreaper, including a detached grandchild. The unsupervised layout
in run 40539930555 retained its detached processes at the observation point.
These observations select **GitHub-hosted Linux Actions with the existing
supervisor** as the bounded stateless candidate for further integration. They do
not establish force-cancel/host-loss cleanup, durable leases or atomic resource
reservation. See the source-pinned Actions packets under reports/verification.

Three shapes were considered: a new persistent scheduler (duplicates execution
ownership), an immediately dispatching Actions wrapper (would guess missing
lease/reconciliation guarantees), and a pure policy evaluator over an explicit
snapshot. The last shape provides testable admission rules now without granting
execution authority. The existing factory-adapter-readiness command accepts an
optional `--plan request.json`; its original no-argument internal inventory is
unchanged. It does not invoke GitHub, create state, cancel existing quality work,
read approvals, or dispatch a job. `dispatch_authorized` is always false.

## Admission proposal contract

`factory-admission-request/v1` is a closed JSON object with:

- `limits`: `parallel` (2, 4 or 8), `features` (1..parallel), `reviewers`,
  `remaining_runs`, `remaining_seconds`, `ready_limit`, `wait_limit_seconds`.
  Values are bounded nonnegative integers; unknown budgets are rejected.
  Remaining budgets include active reservations, which are deducted before
  considering new work. Completed work has already been charged by the caller.
- `active`, `queued`: ordered job lists, at most 128 each. Every job has `id`,
  `feature`, `kind` (`read_only`, `isolated_prototype`, `product_write`), `workspace`,
  `dependencies`, `paths`, `ports`, `databases`, `seeds`, `seconds`, `reviewers`.
  IDs are bounded ASCII identifiers. Paths are canonical relative literal paths,
  not globs; ancestor overlap conflicts if either job writes in the same workspace.
  An empty read-only path list means **no file reads**, never unknown read scope.
  Unknown scope must be rejected (null is invalid), not represented as empty.
  Workspace identities must describe actual isolation when a host integration is
  built; a caller-supplied label is not evidence of isolation or a reservation.
  Resource names are globally exclusive within the snapshot. One job per feature
  is selected; reviewer capacity is reserved separately from execution slots.
- `completed`: unique completed work-order IDs. An ID cannot also be active.
  Only these IDs satisfy dependencies; a newly selected predecessor is not done.
- `decision_queue`: `ready_count` and `mean_review_seconds` (positive integer or
  null). The ready-count threshold or estimated wait threshold suppresses new
  proposals. A nonempty queue with unknown review time is also suppressed.
  Zero thresholds conservatively disable new proposals.

Duplicate queued events are all deferred; previously active/completed IDs are not
reissued. Active work is preserved even if the current limits are exceeded. A
product-write job is always deferred until actual existing task-approval checks
are connected; a declaration in the request cannot grant approval. Selection is
stable queue order and reserves resources only within that calculation.

`factory-admission-plan/v1` contains the canonical `input_sha256`, selected IDs,
deferred IDs with explicit reasons, and `active_unchanged`. It always carries
`authority: none`, `dispatch_authorized: false`, `cost_guarantee: false`. Input
JSON is limited to 1 MiB, rejects duplicate keys/unknown fields and preserves the
input. Invalid requests exit 2 without a JSON proposal. Successful evaluation is
not an executor receipt, lease, approval, isolation proof, live observation or
monetary guarantee. Concurrent callers can produce identical proposals; the
future host integration must reconcile live ownership and atomically reserve
before any dispatch, and must use existing run/attempt origin checks for results.

Actual dispatch, external-operation reconciliation, lease/resource ownership,
approval integration and native 2/4/8 cost/arrival/queue/human-load comparison
remain incomplete. The policy tests are deterministic simulations, not those
host measurements. No new persistent state engine is introduced to fill the gap.
