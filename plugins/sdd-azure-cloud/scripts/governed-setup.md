# T-012 Azure governed caller (inactive until platform-owner setup)

This is the concrete **Azure** caller integration for T-003's shared admission
boundary, replacing the Azure execution sketch in `templates/cloud/github-azure.yml`.
That sketch remains historical task input, not an executable production recipe.
No workflow in this repository is activated. Do not enable either sketch as-is.
T-012 changes only Azure scripts, its execution tests, and its task addendum.

## Acyclic pins: install in this order

1. Review and commit the executor code plus its trusted shared runtime and Azure
   upstream-lock reference. Record immutable executor repository and commit **E**.
   E contains no expectation of the control workflow's future commit. No policy
   Python file is imported; no artifact can select the executor or policy path.
2. Offline, render `azure_governed.workflow_template(executor_repository=...,
   executor_revision=E, subscription=..., region=..., input_repository=...)`.
   It returns JSON-formatted YAML. Save it as `.github/workflows/cloud-azure.yml`
   in the **single protected control repository**; review and commit it as **W**.
   The renderer accepts only a complete configuration and a 40-hex executor pin.
   `python3 -I plugins/sdd-azure-cloud/scripts/azure_governed.py --render-template`
   emits an intentionally inert placeholder template for inspection only.
3. Configure protected environments `sandbox-prepare` and `sandbox-apply` in
   that control repository. Required named user reviewers, no self-review, no
   administrator bypass, protected branches only; install T-003's custom OIDC
   subject keys `repo`, `context`, `workflow_ref`, `workflow_sha`. Obtain actual
   numeric repository/environment/actor/reviewer IDs from GitHub. Set fixed
   protected-environment variables `AZURE_PREPARE_POLICY` and `AZURE_APPLY_POLICY`
   to the stage-specific JSON below, now pinning **W**. Neither variable is a run
   input or deployment artifact. Restrict environment-variable administration
   to the platform owner; branches cannot supply alternative trusted config.
4. **After W exists**, create distinct Entra applications/service principals and
   federated credentials for prepare and apply. Native issuer is
   `https://token.actions.githubusercontent.com`, audience
   `api://AzureADTokenExchange`, and each exact native subject is:

   `repo:OWNER/CONTROL:environment:sandbox-STAGE:workflow_ref:OWNER/CONTROL/.github/workflows/cloud-azure.yml@refs/heads/main:workflow_sha:W`

   Replace W with the literal reviewed commit in both federation and external
   protected policy. Never use a wildcard/mutable branch alone or derive the
   expected revision from `GITHUB_SHA`, OIDC claims, an unsigned receipt, or a
   request field. Require dispatch at W. When the control branch advances,
   explicitly re-review and update native federation plus protected policy before
   admitting that new commit. Changes to E require a new W; no self-referential
   Git hash is required at any step.
5. Establish exclusive native write ownership for the subscription/region in
   this one control repository. All its write workflows use the identical
   literal `cloud-azure-SUBSCRIPTION-REGION` concurrency key and
   `cancel-in-progress: false`. Deny out-of-band writers. GitHub concurrency is
   repository-local, not a global Azure lock. First attempts only; never rerun
   a write job or remove a consumed journal. Reconcile uncertainty read-only.
6. Configure private artifact access, explicit residency/retention acceptance,
   `AZURE_EVIDENCE_RETENTION_DAYS` matching the bound deployment policy, and a
   read-only `INPUT_ARTIFACT_READ_TOKEN` for the fixed input repository (prepare
   only). Standard runner/provider Python TLS roots must be trusted. Live budget,
   approved image, subnet, identity, monitoring rule, backup vault/policy and
   health expectations remain required. No setup API is called by the renderer.

Example **external** protected policy JSON (replace all placeholders; not valid
admission until configured). Supply separately for each stage; use distinct
client/object and protected environment IDs but the **same** deployment-policy
JSON SHA-256 and logical target. `workflow_revision` is W, not E.

```json
{
  "provider": "azure",
  "repository": "OWNER/CONTROL",
  "repository_id": 0,
  "workflow": ".github/workflows/cloud-azure.yml",
  "workflow_revision": "REPLACE_CONTROL_W_40_HEX",
  "ref": "refs/heads/main",
  "operation": "prepare",
  "environment": "sandbox-prepare",
  "target_environment": "sandbox",
  "environment_id": 0,
  "account_id": "REPLACE_SUBSCRIPTION_UUID",
  "region": "REPLACE_REGION",
  "deployment_scope": "REPLACE_RESOURCE_GROUP",
  "policy_sha256": "REPLACE_DEPLOYMENT_POLICY_64_HEX",
  "actors": [[0, "REPLACE_OPERATOR"]],
  "reviewers": [[0, "REPLACE_REVIEWER"]],
  "exclusive_repository": "OWNER/CONTROL",
  "ttl_seconds": 120,
  "azure_tenant": "REPLACE_TENANT_UUID",
  "azure_client": "REPLACE_STAGE_CLIENT_UUID",
  "azure_principal": "REPLACE_STAGE_OBJECT_UUID"
}
```

The short lease must cover all local checking, current what-if, and final send;
expired policy/OIDC/provider/preview deadlines deny. A new approval, not an
extended local receipt, is needed if the approved window is insufficient.
Config variables select **expected** identities only. Actual GitHub protected
approval metadata, OIDC from the authenticated issuer, Entra token exchange and
ARM subscription readback must match at **every POST/PUT**. Local flags, injected
receipts and environment strings do not grant authority.

## Data acquisition and invocation

- Run T-004 route/plan/local validate in a credential-free planning job. Freeze
  the compiled ARM bytes, parameter/source files, upstream closure, lock, policy,
  ownership, provider config and verification profile. Copy the exact emitted
  locked request bytes to `request.json`; no reserialization or phase change.
  The relative paths in that request remain unchanged. Publish a private immutable
  GitHub Actions artifact containing `request.json` and the entire `bundle/`.
  Include hidden bound inputs. Do not put executable trusted policy in the bundle.
- Dispatch **prepare** using that artifact's immutable ID, producer run ID,
  exact request SHA-256 and literal preview SHA `none`. The workflow downloads
  only data, through authenticated GitHub REST artifact metadata (`2022-11-28`),
  checks ID/run/expiry, obtains the ZIP by immutable ID, follows only a validated
  HTTPS Azure Blob download location without forwarding credentials, verifies
  the metadata's `sha256:` archive digest, and extracts canonical regular files
  into a new private workspace. Unknown digest/redirect/archive shapes block.
  No `pip`, Bicep build, checkout, source hooks or synthesis from this data runs
  in a credentialed job. Only E is checked out as executable code.
- The caller uses the same `cloud.run` public phase dispatch with an in-process
  trusted executor. Direct `cloud.py prepare/apply/reconcile` without that caller
  continues to deny (legacy `OPERATION_UNIMPLEMENTED` code); local route/plan/
  validate behavior is unchanged. No approval CLI switch is added.
- Prepare uses `ProviderNoRbac` semantic what-if validation (API `2025-04-01`),
  so its principal does not need the resources' write permissions. The result
  includes `cloud-preview/v1`, normalized resource/property changes and authentic
  response status/body-digest audit. Potential changes, diagnostics, unknown or
  ambiguous change types block. Resource/property deletion and modification of
  referenced resources block. Only the exact local graph's explicitly declared
  attachments are eligible; there is no import or resource deletion path.
- The workflow's `always()` upload retains the **whole** data workspace as a
  new immutable artifact, including request, bundle, preview, authorizations and
  submission journals even after UNKNOWN. Inspect this artifact and its hashes
  before approving apply. Use its immutable ID/run ID for the separate apply
  dispatch in the control repository. No mutable artifact names select execution.
- Apply consumes identical request and original template/parameter bytes and
  rechecks roots, owner conflicts, policy/lock/tool closure, current native
  what-if semantics and authenticated admission. It does not execute a compiler
  simply to accept an already compiled artifact. Its template is embedded as an
  exact well-formed JSON string, expressly supported by the official schema;
  parameters are parsed from the exact hash-bound original file. No compilation
  or arbitrary parameter override is possible. Incremental mode is fixed.
- Under the scope concurrency key, preallocate `sdd-` plus the first 60 request
  digest characters as the stable unique deployment name (the request includes
  unique run/unit identity), with a deterministic UUIDv5 client request ID.
  Authenticated complete control-repository dispatch history fences the intent
  independently of acquired archives; local journals and native existence checks
  supplement it. Native 404 is never proof that an earlier uncertain PUT did not
  occur. Do not reuse run IDs for different operations. A completed empty
  or all-NoChange preview yields NO_CHANGE, zero PUTs and no apply ID.
- Any ambiguous POST/PUT delivery or polling failure is UNKNOWN with its original
  operation identity and fsynced submission record, never a no-write assertion.
  Polling uses only validated fixed-origin, same-deployment or same-subscription/
  region ARM operation endpoints, bounded response size, 20-second HTTPS timeouts,
  at most 12 polls, bounded Retry-After and a 300-second polling deadline.
- For a submitted deployment, dispatch **reconcile**, using the prior immutable
  apply artifact (or the UNKNOWN intent-fence artifact) and same request/preview
  digests. Public trusted dispatch selects the deployment journal if present,
  otherwise the intent fence; an unsafe existing journal does not fall back.
  A fence is rechecked against fresh authenticated history, not trusted as an
  unsigned local receipt. Both recovery paths first bind provider, account,
  region, resource group, logical target and deployment-policy digest to external
  trusted Policy. A mismatch prevents native reads and retains original-ID UNKNOWN.
  Fresh read identity is required, but expired apply previews or absence of a new
  mutation approval do not bar read-only recovery. It federates anew and makes
  **GETs only** against the original ID. It never calls apply or what-if. A
  missing, unknown, unhealthy, inaccessible or unrecognized state stays UNKNOWN
  or FAIL. Deployment Succeeded yields OBSERVED, not VERIFIED or health PASS.
  T-006 owns actual resource/health checks. A process killed before final upload
  still has a deterministically recoverable native deployment ID from its request;
  retain runner/control evidence and use an owner-approved recovery procedure,
  not a fresh apply. No automatic resource cleanup exists.

## Durable intent history prerequisites and fail-closed bound

The fence reads GitHub REST `2022-11-28` through the existing authenticated,
no-redirect, bounded HTTPS transport:
`GET /repos/OWNER/CONTROL/actions/runs?event=workflow_dispatch&per_page=100&page=1`.
The native response is an object with `total_count` and `workflow_runs` (not an
array of receipts). Each native run carries `id`, `run_attempt`, `event`, `path`,
`head_sha`, `display_title`, `repository`, and `head_repository`; the current run
must also match fresh OIDC/metadata, workflow pin, in-progress state and exact
request/preview title. Unknown JSON keys in native responses remain compatible;
required fields, duplicate run IDs, repository identity and count are checked.
See GitHub's official [list repository workflow runs API](https://docs.github.com/en/rest/actions/workflow-runs#list-workflow-runs-for-a-repository).

This deliberately small implementation accepts only **complete 1–100 dispatches
in the entire control repository**, including the authenticated current run.
It does not paginate or infer absence from the first page: `total_count` must
match the list length and be at most 100. Missing permission, unavailable API,
missing current run, duplicates, mismatched repository, malformed governed titles,
truncated responses and over-bound histories deny before any ARM mutation. The
GitHub filtered-list maximum cannot be used as proof of completeness. An owner
must retain every relevant dispatch and permit visibility of the complete list
for as long as any of its deployment intents can be replayed. Enforce no deletion
of run metadata, no hidden/filtered subsets, and no migration/reset of the control
repository to clear a fence. Artifact retention alone is **not** run-history
retention. These are external platform prerequisites, not facts proven by a
local JSON policy or these deterministic tests. If retention/deletion/visibility
cannot be guaranteed, do not activate write execution. At 101 dispatches this
implementation stops admitting applies: do not delete runs to evade the bound;
a reviewed durable-history upgrade is required.

Within the same repository-wide native concurrency lock, any other dispatch
whose `display_title` is `cloud:REQUEST_SHA:PREVIEW_SHA` fences that request,
regardless of a new preview, new approval, changed workflow revision/path,
run outcome, or a native deployment 404. Prepare uses literal `none` instead of
a preview SHA and is not an apply fence. Reconcile and canceled/unapproved apply
dispatches conservatively fence too: history cannot prove whether they reached
the write site. Unrelated intents are not a fence. No dispatch can reset the
original deterministic deployment/client-request identity. All write-capable
workflows must preserve this title convention and the fixed scope lock, and
must use this reviewed executor. Deny alternate native writers and unauthorized
control workflow/configuration changes. An older already-issued intent is not
made safe by deploying this fix after its history was lost.

On a match, return UNKNOWN with the original native ID and publish
`intent-fence.json` binding exact request/scope/ID, repository identity, current
and prior run IDs, full bounded parsed history, authenticated response SHA-256,
fixed API locator and timestamp. No what-if or deployment mutation is attempted.
Read-only reconcile refetches authenticated complete history and requires the
recorded prior intent IDs still present, then GETs that same deployment. Missing
history blocks; local/imported markers never authorize a write. Final
credential/policy/preview deadline checks remain after all history, source scans,
hashing and journal publication at the actual native send boundary.

## Least privilege for the supported VM/NIC/monitoring/backup graph

Use `azure_governed.role_setup(subscription, resource_group)` offline to render
stage-separated custom-role definitions at the exact deployment group. It names
individual actions, not Contributor, `*`, role-assignment, public-IP or delete
permissions. Apply includes deployments/write and the actual VM, disk, NIC,
VM-extension, DCR-association and backup protected-item read/write actions.
Prepare has only deployment read/whatIf/validate and resource reads, **not** those
resource writes. Apply also needs whatIf for its freshly authorized refresh.
No actions are automatically installed. Validate registered operation names and
scopes with the target provider before activation; deterministic tests are not
native IAM acceptance.

The owner must additionally create these **separately scoped** assignments; do
not broaden the entire group merely because references live elsewhere:

| Exact scope | Prepare principal | Apply principal |
|---|---|---|
| Subscription | `Microsoft.Resources/subscriptions/read` for identity readback | Same |
| Referenced subnet (and parent VNet read scope if required by provider) | `Microsoft.Network/virtualNetworks/subnets/read`, parent `Microsoft.Network/virtualNetworks/read` | Same plus subnet `Microsoft.Network/virtualNetworks/subnets/join/action` |
| Referenced user-assigned identity | `Microsoft.ManagedIdentity/userAssignedIdentities/read` | Same plus `Microsoft.ManagedIdentity/userAssignedIdentities/assign/action` |
| Approved gallery image version (and required gallery/image ancestor read scopes) | `Microsoft.Compute/galleries/images/versions/read`, ancestor `Microsoft.Compute/galleries/read`, `Microsoft.Compute/galleries/images/read` | Same; no image writes |
| Referenced DCR | `Microsoft.Insights/dataCollectionRules/read` | Same; association write is scoped to the new VM, not the DCR |
| Existing backup vault/policy and selected fabric/container | `Microsoft.RecoveryServices/vaults/read`, `Microsoft.RecoveryServices/vaults/backupPolicies/read`, `Microsoft.RecoveryServices/vaults/backupFabrics/read`, `Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/read` | Same; protected-item write only for the approved new VM under that vault |

The sample graph assumes pre-existing vault/policy/subnet/DCR/image/identity.
Do not add their create/write/delete actions or bootstrap them implicitly. If a
resource provider requires additional supported actions for this exact graph,
record the native denial and obtain an owner-reviewed least-privilege amendment;
never fall back to Contributor or role-assignment rights. Backup/monitoring
service identities, subscription registration, health probes and budget are
external prerequisites. Optional managed NSG graphs need separately reviewed
NSG actions; this concrete role setup covers the mandatory minimal example only.

## Evidence and limitations

The official API snapshot is admitted under
`specs/cloud-orchestration/verification/T-012/inputs/external-6.json`, SHA-256
`65ab0762e17c23943f8247bfac9d62b1a80d526bbdf64fc24700a7599abc78aa`, with acquisition
URL/time in `external-7.json`. This is hash-bound research of an official mutable
URL, not an upstream immutable Git pin. Deterministic ARM and GitHub transport
cases, acyclic renderer tests and real native local compile regressions are
separately labeled in the implementation report. Actual cloud TEST-003/005/009,
native federation/roles/concurrency and artifact storage enforcement remain
**BLOCKED** until an owner-authorized sandbox exists. Azure's final preview/PUT
race against external writers remains. No cloud writes, messages, cleanup,
release publication or independent review were performed by T-012 development.
