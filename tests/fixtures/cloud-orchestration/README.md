# Cloud orchestration test inputs

These synthetic/local fixtures are copied from the corresponding
`specs/cloud-orchestration/verification/` paths at the existing `v1.20.0` tag
(`96afb59fcceab422024d5f2d1abc1b478d7058cf`). Their input bytes are preserved.
They support local compiler, transport and authorization-boundary tests; they
are not authenticated cloud deployments or current acceptance records.

The T-013 external input is the pinned AWS CloudFormation service model used
by the wire-format test. Only the consumed JSON is retained. Provider vendored
reference licenses and lock files remain under their respective plugin.
