# Private VM read-only observations (T-006)

The optional closed `observation` configuration is defined by
`azure-local-config.schema.json`. Existing local v1 behavior without that object
is unchanged; observe/verify block instead of guessing targets. VM, NIC, subnet,
sole user-assigned workload identity, DCR association/rule, `monitoring_workspace_id`, workload metric and
(when required) protected backup item/policy IDs are explicit. Recovery-point IDs
are discovered after deployment, not required before CREATE. No arbitrary shell
commands, queries, URLs or model-generated probes are accepted.

The direct local CLI returns `TRUSTED_COLLECTOR_REQUIRED` for observe/verify.
This replaces `OPERATION_UNIMPLEMENTED` only for these implemented entry paths.
The governed collector authenticates fresh read-only federation, checks leases
before/after native reads, and joins selected resources to the original compiled
request body and successful original deployment operations, not just configured
IDs or deployment outputResources. It uses fixed ARM GETs and the native
read-only `effectiveNetworkSecurityGroups` POST. Pagination/202/incomplete data
blocks. Transport fixtures remain explicitly synthetic.

## Original completion bound and generated workflow migration

ARM deployment `timestamp` is not treated as terminal time. The shipped inactive
workflow template now has distinct fixed prepare/apply/reconcile/observe/verify
jobs, literal phase commands and separate protected environments/variables. Apply
requires actual original native completion; skipped/no-op/reconcile results
cannot provide completion authority. E/W pinning, exact request/title binding,
first-attempt/replay fences, concurrency and no automatic write retry remain.

Observe authenticates GitHub metadata for the original successful APPLY run/job
and its pinned W contents. Exact repository IDs/names, run/attempt, W SHA/path,
request+preview title, pinned E, fixed template semantics and successful literal
apply step/job are checked. Original native submission/body/deployment joins
remain mandatory. The original successful job's completion is a conservative
upper bound after native completion; a local receipt selects only a candidate
run and is not authority. A step merely named apply is insufficient. Incomplete
job pagination, skipped/no-op/reconcile and ambiguous old workflows are rejected.

**Migration:** regenerate old ambiguous generated workflows and review/pin a new
protected W before using this verification path. Owner-provided read-only
phase federation/environment setup is still required. No deployed workflow or
permissions were changed here. Real CI/native execution remains unperformed.

## Current checks and explicit limits

Monitoring requires native DCR association **and rule** readback plus a received
platform CPU signal. The supported DCR is Linux, Succeeded, in the declared region,
with exactly one performance counter: `\Processor(_Total)\% Processor Time`,
60-second sampling, stream `Microsoft-Perf`, one Log Analytics destination whose
workspaceResourceId equals explicit `monitoring_workspace_id`, and one direct
untransformed flow to that destination. Unknown sources/destinations, transforms,
missing configuration or denied reads block; known unhealthy configuration fails.
This is deliberately not a generic DCR/query engine or proof that every possible
agent stream has been received. Workload health separately requires the configured
custom metric bound to this RunId/UnitId. Both native Minimum and Maximum are
requested and checked against the configured range for every returned bucket;
a healthy maximum cannot hide an unhealthy minimum. Platform CPU uses Maximum.
Metric response ID, namespace, region, interval, window and unique dimensions
must match the fixed request; incomplete context blocks. Recovery discovery reads
a bounded complete list for the exact protected item, validates contained unique
IDs, and selects the newest post-completion point by time, never by health.
Missing/incomplete lists block; actual latest backup health remains mandatory.

Freshness is relative to current collection/verification time, not deployment
age: completed <= sample <= collected <= now, and now - sample <= profile age.
Metric queries intersect the recent profile window with original completion;
the lower bound is explicitly rounded inward to a whole minute for PT1M, with
AutoAdjustTimegrain=false. No undocumented Azure server rounding is assumed.
Responses outside the selected window block; all returned metric samples are
checked, so an unhealthy point cannot be hidden by a healthy one. At most 1440
one-minute buckets are supported. An empty/not-yet-ready window blocks. Backup
history is time-selected locally; no undocumented OData time filter is invented.

## Supported effective identity proof and prerequisites

The observer must authenticate as the VM's **sole user-assigned workload principal**.
Native `assignedTo('<principalId>')` subscription enumeration includes inherited and
descendant assignments and transitive group assignments. Every assignment and
role-definition ID is checked; at most 128 assignments/definitions, complete single
pages only. Unknown scope, principal, conditions, delegated identity, groups,
wildcards, NotActions or data rights block. Role display names are never authority.
The finite supported grant scopes/actions are:

- Declared subscription: `Microsoft.Authorization/roleAssignments/read` and
  `Microsoft.Authorization/roleDefinitions/read` only (audit enumeration).
- Governed resource group: `Microsoft.Resources/deployments/read` and
  `Microsoft.Resources/deployments/operations/read` only (original/current proof).
- Exact VM, NIC, identity, DCR association/rule and required backup item: finite
  read actions for their actual probes, `Microsoft.Authorization/permissions/read`,
  plus VM `Microsoft.Insights/metrics/write`. Backup recovery read is bounded to
  the protected item. The executable ceilings are `permission_ceiling`.

All grants are direct ServicePrincipal assignments. Same-principal native caller
permissions at each exact workload target must equal the enumerated applicable
grants. Enumeration/role definitions are re-read after these checks and must remain
unchanged. Excess observed rights fail; unsupported/incomplete proof blocks. This
checks the declared subscription/governed policy scope, not unrelated tenants or
accounts. No policy or IAM privileges are created by collection.

**Consistency limit:** ARM/RBAC is not an atomic snapshot. This path requires stable
direct assignments and exclusive governed writes. Group/App Role/Lighthouse or
recently changed/cached authorization contexts are unsupported. Microsoft documents
managed-identity group/role token caching around 24 hours; fresh enumeration is
**not** evidence that old grants/tokens were revoked. Owners must establish a stable
direct-assignment context before live acceptance; a local approval flag cannot
substitute for native reads. Received run-specific health remains independently
mandatory. Explicitly synthetic protocol tests exercise the real native transport
class with scoped mocked I/O; they do not claim production verification.

## Current/original operation binding

Before resource binding and again after collection, read a bounded complete list
of deployments in the governed resource group. The original successful deployment
must still be uniquely latest by native template timestamp; later/equal-timestamp
or nonterminal competing deployments, missing history, denied reads or pagination
block. The timestamp orders templates only; it is **not** used as completion time.
Original compiled membership and successful deployment operations are checked
again before publication, with the credential lease checked on both sides.
As with the execution harness, direct/out-of-band writers and deleted history are
outside the supported exclusive-writer prerequisite; this is not a general drift
or global IAM-history audit. The completion bound remains the authenticated original
successful fixed APPLY job described above.

Shared closed context/check-result/evidence-manifest contracts and publication
rules are described in the AWS [evidence section](../../sdd-aws-cloud/references/observations.md#evidence-and-trust).
Raw native responses are not repository publications; exact-byte digests are
integrity records, not provenance authority. Saved records cannot grant proof.
Live TEST-003/005/009 remain BLOCKED (OQ-001); synthetic success never creates
production EVIDENCE_COMPLETE. No cloud actions or IAM privilege changes occurred.
