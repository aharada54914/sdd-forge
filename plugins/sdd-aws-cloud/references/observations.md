# Private EC2 read-only observations (T-006)

`observe` and `verify` require the trusted governed executor; a direct local CLI
without one returns `TRUSTED_COLLECTOR_REQUIRED`, not `OPERATION_UNIMPLEMENTED`.
Other phase errors and zero-write behavior are unchanged. The verifier collects
fresh responses; a saved receipt, `classification: native`, local approval flag,
or zero exit status cannot authorize verification.

An optional `observation` object in the original `aws-local-config/v1` enables
collection. Omitting it preserves local planning/validation behavior; collection
blocks with `OBSERVATION_CONFIGURATION_REQUIRED`. Its closed executable contract
is `aws-local-config.schema.json`. It must be frozen **before** prepare/apply:

```json
{
  "instance_logical_id": "Workload",
  "security_group_logical_ids": ["PrivateGroup"],
  "alarm_logical_id": "Health",
  "vpc_id": "vpc-11111111",
  "subnet_id": "subnet-11111111",
  "instance_profile_arn": "arn:aws:iam::111111111111:instance-profile/workload",
  "role_arn": "arn:aws:iam::111111111111:role/workload",
  "guard_policy_name": "ObservationGuard",
  "workload_metric": {"namespace": "Workload", "name": "Healthy", "minimum": 1, "maximum": 1},
  "backup": {
    "plan_id": "owner-plan",
    "selection_logical_id": "Protection",
    "vault_name": "owner-vault",
    "role_arn": "arn:aws:iam::111111111111:role/backup"
  }
}
```

These IDs are illustrative, not live defaults. Compiled selectors must name the
exact `AWS::EC2::Instance`, VPC `AWS::EC2::SecurityGroup`,
`AWS::CloudWatch::Alarm`, and `AWS::Backup::BackupSelection` resources in the
original immutable assembly. `DescribeStackResource` resolves physical IDs from
the exact original stack, checking stack/logical/type/status; EC2 readback checks
that instance and account, not an arbitrary healthy substitute. Generated IDs
and recovery-point ARNs are not predeployment configuration. The earlier T-006
candidate's physical-ID observation configuration is intentionally rejected.

Original stack completion is joined to the original execution request token.
Native events must be reverse chronological, and the latest stack operation must
still be the original successful operation. A newer/equal-time foreign-token
stack or resource event, missing token, ambiguous ordering or incomplete history
blocks before resolving current physical IDs. After health collection, operation
and physical membership are checked again before publication. This preserves the
exclusive governed-writer prerequisite; it is not proof against deleted history
or arbitrary out-of-band resource mutations.
All observations bind the original request, unit, scope, profile, principal,
native operation and resource. EC2/IAM/CloudWatch use their own native Query
protocols, endpoints and API versions; Backup uses its REST protocol, not the
CloudFormation endpoint. Network evidence is restricted to the supported private
single-NIC EC2 shape. Unsupported shapes block rather than infer access.

The identity upper-bound proof is an exact inline policy: unconditional
Deny/NotAction excluding only `cloudwatch:PutMetricData`, plus Deny of that action
outside the configured namespace and Allow inside it. Attached role names and
IAM simulation are not proof. The collector never installs or changes this
policy. The owner must arrange read access for the observer and this deliberately
narrow workload role; unsupported effective permission contexts block.

Monitoring requires enabled instance monitoring, the exact StatusCheckFailed
alarm configuration, and a received recent metric. Workload health is a custom
Maximum metric in the explicit integer range, dimensioned by **InstanceId,
RunId and UnitId**. It cannot reuse a previous deployment's metric series.
Backup checks the native selection and queries `ListRecoveryPointsByBackupVault`
with the actual resource ARN, approved plan, account, vault and post-completion
creation bound. Responses are independently joined to those fields. One page of
at most 100 entries is supported; continuation tokens block, not silently pass.
The selected latest point must be completed, encrypted and in the profile's
post-completion/freshness window. Missing, denied, stale or unknown data blocks;
genuine unhealthy checks fail. Backup is omitted only if both original policy
and selected profile allow omission, never after a failure.

Freshness is relative to current verification time, not maximum deployment age:
completed <= sample <= collected <= now and now - sample <= profile age. Metric
StartTime intersects the recent age window with original completion, rounded
**up** to a whole minute before sending: CloudWatch documents rounding recent
starts **down**, so inward alignment prevents pre-completion/stale buckets.
Period remains 60 seconds; EndTime is the captured current time (native exclusive
end). No deployment-wide historical query or healthy-point cherry-picking is
used. All returned samples must satisfy the selected range and health criteria;
a returned stale/future point blocks. Windows exceeding 1440 one-minute buckets
are unsupported; not-yet-ready windows block. Backup createdAfter likewise uses
the recent/post-completion intersection. A long-lived deployment can therefore
have fresh current evidence without resetting its original completion bound.

## Evidence and trust

Closed schemas: `contracts/cloud-collection-context.schema.json`,
`contracts/cloud-check-result.schema.json`, and
`contracts/cloud-observation-evidence.schema.json`, alongside the existing
observation and verification schemas. The context binds original request path
and SHA-256, run/unit/provider/scope, lock/policy/profile refs, native operation,
resource IDs, authenticated observer, completion/collection UTC and classification.
Each check binds the context digest, check ID, status/reason/sample time and
native query locator plus exact request/response byte hashes and HTTP status.
Raw native bodies remain in process memory; they are not published as repository
evidence. Digests are not authentication. Query evidence and publication use
fixed diagnostics, mandatory secret scanning, contained paths, symlink rejection
and no-overwrite writes. Every native read checks the credential lease before
and after transport; library fixtures have a bounded synthetic read window.

The evidence manifest binds original request, context, each observation and
result, verification, classification and provenance. Its
`saved_receipt_authorizes_nothing: true` is a warning, not an authentication
mechanism. Receipt consumers must authenticate acquisition or re-collect; the current
shared dependency validator authenticates original producer runs/artifacts as
documented in [predecessor owner configuration](dependencies.md). Synthetic transport success remains BLOCKED at
the public result and never sets production `evidence_complete`.

Workload GetMetricStatistics requests both Minimum and Maximum in the same fixed
query. Every returned bucket must satisfy both configured bounds; Maximum alone
cannot hide a below-minimum sample. StatusCheckFailed monitoring keeps Maximum.
Unknown native states block instead of becoming a purported measured failure.

Azure's supported scoped permission closure and DCR readback are documented in
its observation reference. These local capabilities do not establish live
production readiness. Live
TEST-003/005/009 remain BLOCKED by OQ-001 owner prerequisites. No cloud writes,
IAM expansion, profile dispatch, dependency scheduling or live trial occurs here.
