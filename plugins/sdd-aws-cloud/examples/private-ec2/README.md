# Private EC2 local example

This is a local synthesis example, **not an approved deployment target**.
Use the strict request/config schemas and ownership/policy/profile bodies
shown in `tests/cloud-orchestration-routing.tests.py`'s AwsNativePreparation.
That executable fixture builds all required immutable references, invokes the
real pinned CLI and checks both providers. Its scope/AMI/network/identity values
are intentionally synthetic. Never use them as live defaults.

The task's verification `evidence/native-workspace/` preserves a complete actual
local synthesis, original request, locked request and assembly. Paths inside
requests are workspace-relative; explicitly set CLOUD_WORKSPACE_ROOT to the
physical copy, CLOUD_CDK_ROOT to the preinstalled pinned dependency root and
CLOUD_NODE_BIN to the physical pinned executable. For another plan use a fresh
workspace/output; existing artifact and evidence paths cannot be overwritten.

Provide `parameters.json` with all ten explicit fields: account, region,
stackName, vpcId, subnetId, instanceProfile, imageId, instanceType, backupPlanId,
backupRoleArn. The VPC/subnet, instance profile and backup policy/role are
pre-existing references. Owner-approved private connectivity, least privilege,
backup retention/recovery and live health probes remain external prerequisites.
The example's egress CIDR is a private example range, not discovered topology.

See `../../references/local-preparation.md` for commands, trust boundaries,
source inventory rules, strict policy support, template-only asset support and
POSIX/Linux binary limits. Do not execute untrusted CDK on a credentialed host.
No install lifecycle, cloud write, implicit bootstrap or asset upload is included.
