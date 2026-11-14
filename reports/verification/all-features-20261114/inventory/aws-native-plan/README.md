# AWS provider-native deployment and rollback probe

Prepared for the already authenticated CloudShell in Tokyo. This script has not itself been executed by the preparing agent. It uses only CloudFormation-owned WaitConditionHandle and WaitCondition resources: no compute, customer S3 bucket, IAM, networking, logging or third-party resources. CloudShell and CloudFormation AWS::* resources have no additional service fee; no chargeable workload resource is requested. Existing account-wide charges are unrelated and not asserted zero. The script stops before mutation if registered private hooks are present or the selected account differs.

Execution (coordinator supplies the actual account privately):

```bash
export SDD_EXPECTED_AWS_ACCOUNT='<selected account id>'
python3 cycle.py --region ap-northeast-1
```

Creates a unique `sdd-forge-verify-...` stack, waits for CREATE_COMPLETE, adds a new handle and an unsignaled WaitCondition with Timeout=1, observes the failure reason and UPDATE_ROLLBACK_COMPLETE, verifies exact initial template restoration, then deletes only the captured stack ARN with its unique run tag. Finally confirms DELETE_COMPLETE and all resource deletion records. No API permission is escalated. No presigned handle IDs, account IDs, caller ARNs or credentials are emitted. Private operational stack ARN is retained under the printed private directory for recovery. Each subprocess has a timeout and each state polling phase is bounded at360seconds; a client timeout is treated as uncertainty, not success.

Official references (checked2026-11-14):
- https://aws.amazon.com/cloudformation/pricing/
- https://aws.amazon.com/cloudshell/pricing/
- https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-cloudformation-waitconditionhandle.html
- https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-cloudformation-waitcondition.html

This tests provider-native API behavior only. Governed sdd-aws-cloud acceptance still needs the owner-controlled immutable executor/control workflow pins, protected environments and actual independent reviewer approval, external protected policies, separate prepare/apply/recovery identities and GitHub OIDC native trust, exclusive writer controls, pinned artifact storage, and authorized workload/dependency/health/budget policy. No console login or native smoke result substitutes for those contracts.

Waiter accepts only the explicitly supplied prior status for up to30seconds before observing progress; after progress any unexpected terminal status fails immediately. Eight offline deterministic waiter checks pass (eventual consistency, fast completion, wrong terminal, prior-status regression, grace expiry and overall deadline). CLI version, coarse identity kind and script SHA-256 are included in runtime evidence; caller ARN remains private.
