# T-013 AWS governed executor — inactive until owner setup

This is the AWS execution integration for the shared T-003 `WriteBoundary`,
using T-005 frozen CDK assembly and T-012's bounded authenticated dispatch-history
fence/acquisition pattern. It supersedes the **inactive** sketch in
`templates/cloud/github-aws.yml` for this API path; do not enable that sketch as-is.
No deployed workflow or cloud resources are created by this task.

## Acyclic trusted pins

1. Review and commit this executor, the shared admission/contracts runtime, and
   provider reference locks as immutable executor commit **E**. E does not contain
   the future control workflow commit. No deployment artifact can select code,
   policy, roles, interpreter packages or imports.
2. Render `aws_governed.workflow_template(executor_repository=..., executor_revision=E,
   account=..., region=..., input_repository=...)` offline. Save the returned
   JSON-formatted YAML in the **single protected control repository**. Review and
   commit this workflow as **W**. `python3 -I plugins/sdd-aws-cloud/scripts/aws_governed.py
   --render-template` prints inert placeholders only. Configure all renderer
   arguments together; account/region concurrency has `cancel-in-progress: false`.
3. Set owner-administered protected variables `AWS_PREPARE_POLICY`,
   `AWS_APPLY_POLICY`, `AWS_RECOVERY_POLICY`, `AWS_VERIFY_POLICY` and `AWS_EXECUTION_CONTROL`. They are
   not workflow-dispatch inputs, files in the deployment bundle, or mutable
   source-revision expectations inferred from the current run. Each policy is the
   exact shared `cloud_authorization.Policy` JSON record (actors/reviewers are
   `[numeric_id, login]` pairs), with `provider: aws`, fixed repository/workflow,
   `workflow_revision: W`, fixed account/region/deployment_scope, target environment,
   policy artifact SHA-256, exclusive repository, and lease TTL. Prepare/apply
   use `operation: prepare/apply`, environments `sandbox-prepare/sandbox-apply`
   and **different** `aws_role_arn` values. No Azure fields are needed.
4. Only after W exists, provision separate native IAM federation trusts with
   issuer `https://token.actions.githubusercontent.com`, audience `sts.amazonaws.com`,
   and the exact GitHub customized subject keys `repo, context, workflow_ref,
   workflow_sha`. The stage-specific native subject is:

   `repo:OWNER/CONTROL:environment:sandbox-STAGE:workflow_ref:OWNER/CONTROL/.github/workflows/cloud-aws.yml@refs/heads/main:workflow_sha:W`

   Substitute literal reviewed W, repository, path and environment in both the
   native trust and protected policy. Neither mutable branch trust alone nor
   trusting a supplied receipt is sufficient. Prepare/apply require named
   environment reviewers, no self-review/admin bypass, protected branches,
   first run attempt only, and exact `cloud:REQUEST_SHA256:PREVIEW_SHA256` title.
5. Recovery is a **separate read-only identity/environment**
   `sandbox-recovery-apply`. `AWS_RECOVERY_POLICY.operation` is `apply` (the shared
   original-operation scope discriminator), with its own native read-only role
   and exact recovery-environment OIDC subject. It does not require new mutation
   approval or an unexpired preview merely to read the original intent. The
   executor does not invoke `WriteBoundary.write` during recovery. Environment
   and workflow administration must still be protected. Do not assign any
   resource-write, asset-write, Change Set create/execute, or PassRole permission
   to the recovery role.

The fixed `AWS_EXECUTION_CONTROL` shape is:

```json
{
  "execution_role_arn": "arn:aws:iam::111111111111:role/OWNER_CONFIGURED_CFN_EXECUTION",
  "bucket": "cdk-hnb659fds-assets-111111111111-us-east-1",
  "unit_id": "OWNER_CONFIGURED_UNIT",
  "existing_stack_id": null
}
```

These identifiers are illustrative, not approved targets. For UPDATE, the owner
must supply the **exact existing stack ARN** in `existing_stack_id` and establish
its ownership independently. Native stack tags must exactly match `sdd-owner=cdk`
and `sdd-unit=<unit_id>` and its RoleARN must match the protected execution role.
A name match alone does not authorize adoption/import/retagging. CREATE requires
an unambiguously absent stack. A new CREATE placeholder may omit RoleARN while
`REVIEW_IN_PROGRESS`; existing stacks and completed stacks cannot. The native
Change Set description binds the exact authenticated create request (including
RoleARN/token), asset version and request digest. Exclusive writers and the
native role request condition below are essential, not facts established by hashes.

## Native permissions and separate CloudFormation service role

`aws_governed.role_setup(account, region, stack, control)` emits inactive,
stack/bucket-scoped identity policy examples. The official AWS service
reference admitted in this task establishes that Create/ExecuteChangeSet use
**stack** resource ARNs, not changeSet resource ARNs. Create supports
`cloudformation:RoleArn`, `cloudformation:ChangeSetName`, `cloudformation:TemplateUrl`
and request tag conditions. Execute supports ChangeSetName, **not RoleArn**.

The prepare policy requires the explicit protected role with
`ArnEquals cloudformation:RoleArn`, and grants `iam:PassRole` on that single
role with `iam:PassedToService=cloudformation.amazonaws.com`. It never grants
prepare EC2 deployment authority. Narrow PassRole alone is **not** sufficient:
CloudFormation can reuse an associated stack role even without PassRole. The
explicit CreateChangeSet role input, native RoleArn condition, associated-role
validation and exclusive-writer prerequisites together prevent that fallback.
Apply only executes the approved ARN in the fixed stack scope; it cannot create
another Change Set. Both principals must have no additional policies permitting
alternate writers, direct resource mutation or ungoverned role passing.

The **pre-existing CloudFormation service/execution role** is separate from all
three caller identities. The owner must configure its CloudFormation service trust
and narrowly scoped resource permissions for the approved private EC2/security
 group/CloudWatch/Backup graph, referenced subnet/VPC/profile/backup plan and
instance/backup role passing. Its S3 read permission must include the immutable
versioned template objects. Review actual supported IAM resource/condition keys
for each workload API; this task does not invent a universally safe EC2 role or
create/bootstrap one. Missing role or native permission blocks; it is not repaired
by adding EC2 authority to prepare. TagResource dependent permissions in the
example are limited to the ownership tags and exact stack; UntagResource is not
granted because this path never removes tags. If native behavior requires it,
stop for an owner-reviewed narrowly scoped policy change, not an automatic grant.

Require existing bucket in the declared account **and actual region**, enabled
versioning, all four S3 Block Public Access settings, restricted access, encrypted
storage, owner-approved retention/residency and no foreign writers/deleters.
Every bucket/object request sends `x-amz-expected-bucket-owner`; names containing
an account number are not ownership proof. PutObject explicitly uses AES256,
records native VersionId/ETag, and reads exact version bytes back. Apply repeats
bucket prerequisites and versioned readback. Null/missing versions, changed
ETag/bytes/encryption or foreign-owner denial never become usable assets. KMS,
docker/ECR, executable, remote and non-template assets are explicitly unsupported.

## API and immutable-byte contract

Native adapter is Python standard library only; no AWS CLI/SDK installation or
ambient credential chain. It implements CloudFormation **2010-05-15** Query XML
and S3 **2006-03-01** HTTPS, with bounded status/header-aware transport and SigV4.
AWS-maintained botocore model commit: `4de93abe62cc263980414f7a66be5226bd541b77`.
CloudFormation model SHA-256:
`142ac136f30bf2ba93723536c67e66443b00d86cc2128448916d6d7ab145eec3`;
S3 model SHA-256:
`84c3a4e6ac1c80ed49cb1ddf1f548ea7f51d8a41acbfa0f198b9ba0028d784e8`.
The native IAM model SHA-256 is
`5f5214d42df63c5d04964ae9086788bc060bd09d52c92a75ba51f6914385e83c`.
Exact consumed schema and source/acquisition evidence are in T-013's admitted
inputs; parser/serializer changes require explicit reviewed executor repinning.
Local CDK/library/Node dependencies remain T-005's actual frozen locks.

Credentialed acquisition is data-only: bounded authenticated GitHub artifact
ID/run/digest, redirect origin allowlist without forwarded credentials, safe
archive extraction into a new directory, no hooks/dependency scripts. Pure local
checks verify every source, lock, owner, policy, assembly and staged byte; no
`plan`, `validate` CLI, CDK synthesis/deploy/hotswap/bootstrap or npm is executed.
Only T-005's JSON stack-template file asset is supported. The exact template bytes
are published; CloudFormation uses its versioned TemplateURL. Default parameters
are sent explicitly, capabilities are empty, and every semantic change is bound.
`GetTemplate(TemplateStage=Original)` checks exact original bytes. Native
DescribeChangeSet has no RoleARN/ClientToken fields; none are invented.
`IncludePropertyValues=true` is always sent. Any NextToken blocks explicitly;
pagination is not silently truncated. Unsupported/replacement/deletion/reference
mutations block. Detailed properties remain bound to preview semantics.

Creation omits OnStackFailure. Execute explicitly sends `DisableRollback=true`
and `RetainExceptOnCreate=false`: these preserve provisioned resources on failure
without sending incompatible OnStackFailure plus DisableRollback. No cleanup,
delete, rollback or resource destruction API is called. A genuine empty native
FAILED preview is NO_CHANGE only with the exact unambiguous no-change diagnosis,
empty changes and UNAVAILABLE execution status. Other failures are not no-ops.

## Durable uncertainty, replay and recovery

Both prepare **and** apply authenticate the complete bounded dispatch history in
the exclusive control repository. Prior prepare intent fences all further prepare
writes for the same request, even with a new native run/session or new approval.
Prior apply intent fences execution even when a fresh runner re-downloads an old
prepare archive without the local consumed journal. Apply intentionally permits
its originating prepare dispatch. A local marker alone is never replay protection.

As in T-012, history must be complete within one 100-run page. Missing/ambiguous
history blocks writes. Owners must enforce full visibility, retention/no deletion
of intent history and exclusive scope writers; these external prerequisites are
**not proved by fixture tests**. If history cannot meet them, do not enable writes.
A new approval does not resolve uncertainty. The fixed original request/token is
never changed to make a retry look new. On disk, intent and consumed authorization
are fsynced before any possible send; all native mutations use WriteBoundary and
recheck authenticated approval after remote readbacks without renewing the receipt
lease or exchanging another writer identity.

Public `reconcile` selects the retained execute/fence/create/publish intent and
performs no native writes. It binds trusted provider/account/region/stack/unit/
owner/policy first, then authenticates native reads. Execute response loss retains
original ARN/token and queries exact stack events; empty ExecuteChangeSet results
are not invented operation ARNs. Missing native history remains UNKNOWN.
Creation response loss can resolve the original deterministic Change Set name,
verify exact native description/template/assets and publish a **local** recovered
preview for new apply approval, without creating another Change Set. A lost S3
VersionId cannot safely be replaced by a latest-object read or another PUT: that
case remains UNKNOWN with the original scoped key and no blind republish. When a
fresh archive omits original prepare evidence, its durable fence remains UNKNOWN;
obtain the original restricted evidence instead of fabricating a version.

Transport timeout is 20 seconds per native request; polling is at most eight
iterations with capped delay, no automatic HTTP or mutation retries. Raw provider
bodies stay in memory and are not written into public evidence; trace records are
endpoint/status/request/response digests, not a claim that raw responses were
archived or workload health verified. Native completion alone is OBSERVED, never
VERIFIED/EVIDENCE_COMPLETE. Observation/health collectors belong to T-006.

## Limits and rollback

Deterministic tests exercise real adapter/signing/parsing/admission code through
labeled synthetic transports. They are **not** live IAM, concurrency, S3 retention,
CloudFormation acceptance, or workload tests. OQ-001 live TEST-003/005/009 remain
BLOCKED until owner scope/federation/bootstrap/images/budget/retention/health and
backup prerequisites are supplied. No cloud actions are authorized here.

Disable the inactive workflow/caller on defects; restore only the task-owned code
in a disposable checkout as recorded in T-013's rollback experiment. Code rollback
does not destroy cloud resources or erase native uncertainty. Retain original
intents and evidence; cleanup/correction needs separate environment authorization.

## Current fixed-phase observation and dependency setup

Use the current generated JSON workflow, not old task-input templates. See
[observation contract](../references/observations.md) and
[complete predecessor owner fields](../references/dependencies.md). Configure
read-only sandbox-verify and PROVIDER_VERIFY_POLICY (replace PROVIDER with
AZURE or AWS), whose operation apply denotes the original operation only.
The shared WriteBoundary rejects this environment as a writer. Producer proof
requires the exact generated verify job, successful collection/upload steps and
original request/preview title plus pinned E/W and immutable artifact digest.
Cross-repository GitHub artifact/run/jobs/workflow/environment/approval reads
need explicit owner-arranged token permissions; no automatic privilege widening.
Freshness propagates to the existing receipt expires_at and both native callback
guards. Changes to immutable predecessors require new consumer authorization.

Dispatch ref: `gh workflow run --ref "$CONTROL_REF"` accepts a branch/tag name,
not the raw W commit SHA. Choose the protected branch matching Policy.ref and
verify it resolves to W; shipped examples use refs/heads/main. Native
workflow_sha/Policy.workflow_revision still require exact W, so a moved branch
cannot substitute another revision. No live dispatch is part of documentation validation.
