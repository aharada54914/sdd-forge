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

No supported existing adapter with the required cancellation/resume/lease contract
was established. Per #623's explicit first-task condition, no admission policy or
new persistent executor is implemented. Selecting an external executor requires
documented supported APIs and one real-host cancellation/resume proof. Until then,
#624 is a single-host fixture experiment; 2/4/8 cost/queue/human-load claims remain
unmeasured. This outcome does not waive quality checks or claim #623 complete.

`scripts/factory-adapter-readiness.py` reports `factory-adapter-readiness/v1`
with current source digests/symbol presence and each unestablished capability
explicitly `not-demonstrated`. It always reports `admissible: false` for this
reviewed inventory and invokes no subprocess/host. Successful JSON inventory output
is not an admission or proof that every external executor is unsupported.
