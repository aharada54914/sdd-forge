# Protected admission templates (inactive; no cloud setup performed)

These JSON-formatted YAML workflows and JSON IAM documents are reviewable
**templates**, not enabled deployment configuration. Replace every `REPLACE_*`
value and the zero reviewer ID outside the untrusted IaC repository. Do not
activate before the owner supplies scope, budget, backup/health policy, artifact
retention/residency/access policy, provider federation, bootstrap and exact
reviewed provider executors. T-012/T-013 own those executors; T-003 does not
provide a working deployment CLI. Pins must be verified before adoption.

## External trust prerequisites

1. One orchestration repository exclusively owns all writers for an
   account/subscription-region, including every deployment unit sharing that
   scope. Cloud administrators must prohibit out-of-band roles, repositories and
   local user credentials from making these writes. Merely setting a JSON flag
   cannot establish this. If ownership cannot be enforced, do not enable writes
   or claim serialization. Local locks/receipt files are not cloud locks.
2. Protect the control repository's `main` branch and workflow updates; disallow
   unreviewed actions/policy changes, PR/fork execution, branch protection bypass
   and self-hosted untrusted runners. The entire workflow uses one conservative
   literal `cloud-<provider>-<account-or-subscription>-<lowercase-region>`
   concurrency group with `cancel-in-progress: false`. Configure **the same key**
   in every control-repository workflow for the same scope; never include stage,
   stack, resource group, unit or run ID. GitHub concurrency is repository-local.
3. Configure separate `sandbox-prepare` and `sandbox-apply` protected environments
   with allowed user reviewers, prevent self-review, protected branches only and
   admin bypass disabled (`github-environment.json`; ID 0 is deliberately invalid).
   Team reviewers are not supported by this initial admission adapter. Native
   scheduling must gate **all** id-token-enabled jobs. Revalidate returned
   environment policy and reviewer IDs at every mutation.
4. Install the `github-oidc-subject.json` repository OIDC customization through
   GitHub's administrative API. The subject must contain the exact repository,
   environment, `workflow_ref` and `workflow_sha`, as shown in each federation/trust document.
   Default subjects are rejected. Native trust therefore binds the exact commit,
   not only a mutable ref. The protected workflow commit is additionally pinned in `Policy.workflow_revision` and checked against both
   authenticated GitHub OIDC `workflow_sha`/`sha` and REST `head_sha`. This initial
   shape uses a directly dispatched workflow, not a reusable workflow with a
   different `job_workflow_ref`. Audience is exactly `sts.amazonaws.com` (AWS) or
   `api://AzureADTokenExchange` (Azure).
5. AWS uses two distinct roles and least-privilege permissions. Prepare can
   publish scoped assets and create a Change Set but cannot execute it. Apply
   executes only scoped Change Sets and cannot publish assets or create them.
   The separately bootstrapped CloudFormation service role must itself have only
   reviewed resource permissions. No implicit bootstrap or broad PassRole.
   Azure uses two distinct applications/service principals/federated credentials,
   scoped role assignments, and separate client/object IDs. The apply role's
   deployment permission alone does not grant all resource creation permissions:
   the owner must add only the approved resource actions. These conservative
   skeletons intentionally do not grant Contributor, authorization writes or
   public networking. Read permissions for ARM subscription identity must also
   be explicitly configured. No policy is installed automatically.
6. Checkout only the external, reviewed executor/policy commit with checkout
   credentials disabled. Deployment artifacts are **data** in a different
   directory. Do not import Python/modules, source shell scripts, synthesize CDK,
   install dependencies or run hooks from that bundle in a credentialed job.
   The artifact download credential is separately managed read-only access;
   never put it in evidence. Keep the runner's tools, Python environment and
   credentials isolated from deployment input. Pin tool/dependency inventories.

## Approval and callable boundary

Dispatch a new run for each stage. The authenticated run's `display_title` is
`cloud:<request SHA-256>:<preview SHA-256 or none>`; this must match exactly.
The same frozen request bytes use `operation: apply` and logical target
`environment: sandbox` throughout prepare and apply. Each trusted `Policy` has
`operation` (actual prepare/apply stage), `environment` (protected CI environment,
e.g. sandbox-prepare), and separate `target_environment: sandbox`. Both stage
policies pin the **same deployment-policy JSON SHA-256**; never hash the two
Python policy files as deployment-policy data. The protected executor/workflow
revision protects executable trusted configuration. No data body is imported.
The request binds every input, lock, target policy and verification profile.
Apply must bind the exact preview. Display/review these artifacts before native
approval. Artifact producer run IDs are locators, not authority.

Trusted adapters construct `Policy` from their separately pinned configuration
(see `trusted-policy.example.py`) and `Runtime` with GitHub's job token and OIDC
request endpoint/token. Tokens are credentials, not approval flags. Call:

```python
workspace_root = cloud_contracts.workspace_root()
# Pre-create this exact private directory safely; never follow links or reuse markers.
protected_run_evidence_directory = workspace_root / request["local_context"]["evidence_directory"]
boundary = WriteBoundary(policy, runtime, protected_run_evidence_directory)
receipt_ref, native_result = boundary.write(
    workspace_root, request_ref, preview_ref,
    mutation_id="stable-adapter-operation-id",
    submit=one_native_mutation, scan=trusted_secret_scanner,
)
```

Each fixed provider callback receives freshly federated credentials and performs
**one** mutation. Call for every asset publication, preview creation and apply;
use stable IDs derived from the trusted adapter plan, not fresh IDs on retries.
Never put user-selected callbacks, transport implementations or policies in run
inputs. The default transport performs verified HTTPS with redirects disabled;
there is no fixture-file loader or local CLI credential fallback.

The boundary authenticates GitHub OIDC through its TLS API response (not by
trusting a supplied JWT), obtains authenticated REST run, protected environment
and `/approvals` history with API version `2022-11-28`, then federates at STS or
Entra. AWS additionally signs a GetCallerIdentity request with the new lease;
Azure reads principal claims only from the authenticated Entra token response
and confirms subscription/tenant with ARM `2022-12-01`. That subscription-read
version is distinct from the later deployment API's `2025-04-01` contract.
It rechecks GitHub metadata and local binding after federation, before submit.

Any missing/denied/ambiguous current-environment review blocks. History records
have `state`, `comment`, `environments`, `user`; do not fabricate approval time
or attempt fields from environment timestamps. Only run attempt 1 is admitted;
**rerun jobs is not supported**. Dispatch a fresh run and approve it instead.
Receipt issuance is the authenticated job OIDC lease's `iat`; expiration is the
minimum of its `exp`, provider lease expiration and `iat + policy TTL`. No token
values enter receipts. Expired/revoked identity or unavailable APIs block.

Receipts use T-002's `cloud-authorization-receipt/v1` unchanged. They are immutable
job-local audit evidence, never imported authority. Canonical unit/stage/mutation
paths are published exclusively; an existing file (even altered) denies before
submit. The process latch also denies repeated calls. These are not cross-process
durable authorization or cloud serialization guarantees: native first-attempt
scheduling, external IAM and repository concurrency supply those boundaries.
A submit timeout retains the receipt and is not retried. Provider adapters must
record original native IDs and reconcile read-only. Keep evidence/marker storage
private, single-writer and separate from input; do not delete markers to retry.
Nonempty predecessor receipts currently block at the T-010 integration seam.

All T-003 API tests are labeled deterministic synthetic transports. They prove
request contracts and decision behavior only. Actual federation, IAM permissions,
GitHub scheduling/serialization and native Windows are **unverified**. No live
resource operation, real approval or credential lease was used for these tests.

## Shared local input contracts (T-002 integration repair)

Set `CLOUD_WORKSPACE_ROOT` explicitly to the physical absolute workspace directory
on each host. No cwd or request-parent fallback exists. The same relative paths
and exact bytes may be transported to a different physical checkout. The anchor
selects a filesystem boundary, not authorization. Provider entry points must map
missing/invalid context or `ContractError` to typed BLOCKED, never attempt writes.

The strict optional `cloud-run-request/v1.local_context` object contains:

- `workspace_anchor`: constant `CLOUD_WORKSPACE_ROOT`;
- `artifact_root`: canonical relative directory containing **all** input artifacts,
  dependency files/tool schemas, ownership, provider config, policy and profile;
- `unit_roots`: nonempty unique relative directories inside artifact_root;
- `feature`, `task_id`, `evidence_directory`: the latter must equal
  `specs/<feature>/verification/<task_id>/cloud/<run_id>/<unit_id>` and be disjoint
  from artifact_root. Preview, changes and receipt references stay inside it;
- `ownership`, `provider_config`: exact `{path, sha256}` references.

Every reference uses the workspace anchor, including WriteBoundary's returned
receipt reference. The request manifest itself may be a separate contained
workspace file; it is never an implicit root. Predecessor references must name
separately validated run/unit verification evidence (integrity only); admission
still blocks all predecessors until T-010. Do not infer predecessor authority.

Three closed data-body schemas (all require their named `/v1` schema field):

- `cloud-ownership/v1`: `owners: [{owner, root}]` and
  `existing_resources: [{resource_id, owner, attachments: [{resource_type, name}]}]`.
  Owner is bicep, cdk, terraform, sam, cloudformation or azd. Attachments are
  explicit additive intentions, not import or permission to mutate the parent.
  Empty inventory permits discovery, not execution. For `operation: route`, owner
  may be null/unsupported and route null. Other requests require the supported
  azure/bicep/azure-bicep or aws/cdk/aws-cdk tuple.
- `cloud-deployment-policy/v1`: nonempty `allowed_scopes` (account_id, region,
  deployment_scope), nonempty `allowed_resource_types` strings, `backup_required`
  boolean, `private_networking: true`, `budget: {ceiling_minor_units, currency}`,
  `evidence: {residency, retention_days, access: "restricted"}`. Ceiling uses
  positive integer minor currency units, currency is three uppercase letters;
  retention is positive integer days. These inputs are owner-supplied, not a
  quote, residency attestation, or proof that policy was enforced by a provider.
- `cloud-verification-profile/v1`: `id`, `version`, nonempty unique
  `required_check_ids`, positive integer `max_age_seconds`. The profile id/version
  must match the request reference. Context verification requires resource,
  network, identity, monitoring and workload checks, plus backup when policy
  requires it. Later collectors must actually execute all declared checks and
  enforce freshness; this contract does not produce a health verdict.

`provider_config` is opaque hash-bound data at the shared layer. Each provider
must strictly validate its own settings before consuming it; no common resource
DSL or execution engine is supplied. All integer fields are capped at 2147483647.

Public helpers in `cloud_contracts`:

```python
workspace_root() -> Path
verify_local_context(root, request, *, execution=False) -> list[str]
verify_binding(root, request_ref, preview_ref, receipt_ref=None, *, now, operation=None) -> None
```

`verify_local_context` validates physical containment, hashes and bodies, then
returns every regular file recursively scanned under the declared unit roots.
It rejects links (including directory symlinks), hardlinks and special files.
The router must detect real owner metadata from **all** returned files and combine
that with inventory; the inventory must never hide an undeclared conflicting
owner. This helper does not classify IaC or validate provider-config contents.
Execution additionally requires apply intent and a single supported inventory
owner. A successful scan is not a complete lock proof: adapters still call
`verify_lock` with their independently observed actual transitive reads/tools.

`verify_binding(..., operation="prepare")` accepts a missing preview;
`operation="apply"` requires a fresh bound preview. Receipt operation must match
that explicit phase. Protected CI environment is checked by authenticated
admission against external Policy, not against the logical target. Omitting
operation is allowed **only** for old integrity-only requests without
local_context and preserves their old operation/environment comparisons. It is
not an execution fallback; WriteBoundary always supplies its trusted actual phase
and requires the context. Offline receipt checks grant no authority.

`cloud-operation-result/v1.evidence_manifest_path` may be null only for
pre-publication BLOCKED/FAIL without a native_operation_id. PASS, NO_CHANGE,
UNKNOWN and results carrying native IDs require genuine evidence paths. The
caller must know whether submission occurred; omitting an ID cannot convert an
uncertain submitted operation into a pre-publication failure. Invalid identity
still uses cloud-input-error/v1. Never publish into an unsafe requested output.

Remaining provider obligations include safe creation of the private evidence
directory, complete owner detection, strict provider-config validation, actual
IaC/policy enforcement, normalized preview semantics, immutable in-memory mutation
inputs, tool closure checks, observations and recovery. POSIX no-follow primitives
are required; unsupported filesystems fail closed. No live IAM or Windows claim.
