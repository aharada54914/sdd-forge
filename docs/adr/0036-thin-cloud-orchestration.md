# ADR 0036: Thin Azure/AWS orchestration with CI authorization

Date: 2026-10-18
Status: Proposed — initial scope approved; repository design review pending

## Context

The user approved development of Azure and AWS orchestration after the #423
audit and review of the shared conversation. The initial execution paths are
Bicep and CDK/CloudFormation. Provider previews, write permissions and health
checks differ, while artifact integrity and result envelopes can be shared.

## Decision

Build two thin provider plugins around upstream skills, with shared strict
contract/digest validation only. Use GitHub protected environments and scoped
OIDC as the initial authorization authority. Separate prepare writes from apply
writes. Keep cloud operation state distinct from SDD task and review state.
Route each deployment unit to one primary executor and one IaC owner.

Pin Azure artifacts and revalidate what-if under serialization before apply.
Execute AWS's exact prepared Change Set, without resynthesis. Verify real
resource/health observations after native completion. Keep legacy verification
profiles intact through explicit versioned cloud profile dispatch.

The normative detailed design lives in `specs/cloud-orchestration/design.md`
and is bound by implementation-policy review.

## Alternatives

- A generic cross-cloud engine would duplicate provider lifecycle and resource semantics; reject for the initial scope.
- Calling upstream skills with unrestricted production credentials would make prompt compliance the write boundary; reject.
- Treating what-if as an immutable plan would overstate Azure guarantees; reject.
- Treating successful deployment as verified health would omit required postconditions; reject.
- Migrating existing Terraform/SAM/azd owners automatically would expand scope and risk; detect and block unsupported execution instead.

## Consequences

Provider-specific code remains necessary. CI/IAM configuration is an external
prerequisite, not a fact established by local tests. Azure retains a preview/
apply race against external writers. Cross-cloud failure recovery is explicit
and per-unit, with no promised distributed rollback. Live sandbox validation
requires target configuration and separate cloud-operation authorization.
