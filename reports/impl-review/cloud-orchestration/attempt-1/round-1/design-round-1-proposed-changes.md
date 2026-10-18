# Implementation Policy Review Report: cloud-orchestration — Round 1 / Attempt 1

## Verdict: BLOCKED

| Field | Value |
|---|---|
| Feature | cloud-orchestration |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | BLOCKED |
| Critical Findings | 1 |
| Major Findings | 4 |
| Minor Findings | 0 |
| Generated | 2026-10-18 |

Both native reviewers ran in fresh read-only contexts after successful identity
reservation. Their returned schemas, check IDs, identity/manifests, actual read
delivery, final input hashes and derived verdict were validated. The canonical
workflow-state checker passes for the persisted blocked state. No design status
was promoted and no implementation task was created.

## Reviewer-A Findings (Structural Soundness)

1. API-COVERAGE, Major: artifact families are listed, but direct skill/CLI
   invocation inputs, results, failures and compatibility are unspecified.
2. TEST-STRATEGY-COVERAGE, Major: unit-test subjects and mocked boundaries are
   not explicitly distinguished from integration tests.
3. ADR-PRESENT, Major: the Markdown ADR link is not the canonical declaration
   required by the precheck lexer. `adr_inputs` is empty, so the reviewer cannot
   inspect the ADR. This does not mean the ADR file is absent.

## Reviewer-B Findings (Implementability/Risk)

1. NO-REQ-CONTRADICTION, Critical: the Constraint Compliance table omits explicit
   mapping of region/account allowlists and evidence residency/retention,
   although the infrastructure layer already describes those controls.
2. INTEGRATION-IDENTIFIED, Major: provider CLI/API and trusted CI approval API
   contracts need an explicit supported-version and failure-behavior inventory.

## Proposed Changes

These changes refine the already-approved initial scope. They add no provider,
production deployment, generic resource engine or automatic import path. The
following text is proposed for the next design revision, not evidence of an
implemented command or tested cloud integration.

### 1. Public invocation contract

Add a `Public invocation contract` subsection to design.md:

- New skills: `sdd-azure-cloud:orchestrate` and `sdd-aws-cloud:orchestrate`.
  Bootstrap hands each the same canonical run-request path used by direct
  invocation. Interactive skills may collect missing run fields, but cannot
  execute provider writes while doing so.
- Each provider exposes `python3 scripts/cloud.py <operation> --request <path>
  --output <path>`. Operations are `route`, `plan`, `validate`, `prepare`,
  `apply`, `reconcile`, `observe`, and `verify`. Unknown operations/flags and
  provider mismatches are rejected before any external effect.
- `--request` is an existing strict `cloud-run-request/v1` JSON document.
  `--output` must be a new canonical path within the run's evidence directory.
  No overwrite, symlink traversal or output/input alias is allowed. Request
  references resolve only inside the declared workspace/artifact root.
- Every result uses `cloud-operation-result/v1`: `run_id`, `unit_id`,
  `provider`, `operation`, `state`, `result`, `error_code`, `message`,
  `input_manifest_sha256`, `evidence_manifest_path`, and optional
  `native_operation_id`. This envelope joins the six artifact families already
  specified. `result` is PASS, BLOCKED, FAIL, UNKNOWN or NO_CHANGE;
  `error_code` is null only for PASS/NO_CHANGE. The state is the cloud operation
  state, never an SDD task or gate stage.
- Exit codes: 0 for PASS/NO_CHANGE, 2 for BLOCKED, 1 for FAIL, 3 for UNKNOWN.
  Strict JSON is emitted on stdout; human diagnostics go to stderr. Invalid
  requests without a valid run identity use a separate
  `cloud-input-error/v1` envelope containing only `error_code`, `message` and
  `field`; they do not invent a run or evidence receipt.
- `route`, `plan` and `validate` operate locally without cloud-write authority.
  `prepare` and `apply` are callable only from the governed CI executor and
  require authenticated admission at the call site. An environment variable
  such as GITHUB_ACTIONS=true, a local receipt or a command-line approval flag
  cannot establish that admission. Direct local calls return BLOCKED with the
  required workflow/environment action. `reconcile` and `observe` use scoped
  read-only credentials; `verify` consumes authenticated observations.
- Authentication/authorization unavailable, unsupported owner/version,
  malformed input and missing checks return typed BLOCKED results without a
  new write. A timeout after a submission may have reached the provider returns
  UNKNOWN and the preallocated native operation identity; it never pretends
  no write occurred. NO_CHANGE carries real preview evidence and no fabricated
  apply ID.
- These are additive v1 interfaces. No existing bootstrap argument or
  code/shell/docs/spec verification contract is deprecated or reinterpreted.
  Breaking changes require a new explicit version; unknown versions block.

### 2. Unit and integration test boundaries

Add this test matrix to design.md:

| Level | Subject | Doubles / real boundary | Required examples |
|---|---|---|---|
| Unit | Owner/router decision | Temporary file inventory; no subprocess/cloud | One owner, conflict, unsupported owner, provider mismatch |
| Unit | Strict contract/path/digest validation | Temporary files and synthetic clock | Duplicate keys, traversal, symlink, mutated artifact, expiry, unknown version |
| Unit | Verification/state reduction | Explicit synthetic observations and fixed clock | Missing/stale/failed check, no-op, UNKNOWN reconciliation, dependency failure |
| Integration | Bootstrap → provider CLI → shared validation | Real subprocess/JSON/file flow; fake provider/CI transports clearly labeled | Both entry points enforce the same admission and error contract |
| Integration | CI admission → provider executor → collector | Deterministic fake API/CLI responses; no network writes | Deny fake approvals, stale previews, asset/ARN substitutions and retries |
| Compile/synthesis | Example Bicep/CDK artifacts | Actual pinned compiler/synthesizer; no write identity | Valid artifacts, policy-negative fixture, reproducible asset manifest |
| Isolated host | Skill routing and guarded invocation | verify-codex profile with actual model/tool delivery | Reachability, unsupported route blocking, honest evidence classification |
| Live sandbox | CI/OIDC/IAM/provider behavior | Actual owner-authorized sandbox only | Exact execution, effective network/identity, monitoring and workload health |

Use `tests/cloud-orchestration-contracts.tests.py`,
`tests/cloud-orchestration-routing.tests.py`,
`tests/cloud-orchestration-execution.tests.py` and
`tests/cloud-orchestration-verification.tests.py` as planned deterministic
suite entry points, and wire them into the established CI suite drivers.
Write results under this feature's task-specific verification addenda. Runtime
cloud verification profiles do not report these library unit tests as fake
IaC deployment evidence.

### 3. Canonical ADR declaration

Add this exact standalone design declaration outside a code fence:

`docs/adr/0036-thin-cloud-orchestration.md`

Keep the human-readable link. The new precheck must derive a nonempty
`adr_inputs` containing that path and its actual digest. Both reviewer manifests
must bind and read it. Preserve the prior empty extension; do not retroactively
claim that round 1 reviewed the ADR.

### 4. Complete constraint mapping

Append these rows to design.md's Constraint Compliance table:

| Requirement Constraint | Design Response |
|---|---|
| Region/account allowlists | Trusted CI target policy allowlists provider account/subscription, region, environment and deployment scope; compare authenticated provider identity and request before prepare and apply. Missing policy or mismatch is BLOCKED. Bind policy digest to preview/approval. Covered by TEST-004/005. |
| Evidence residency and retention | Before live preparation, require owner-approved evidence storage region/location, classification, retention duration and access policy; bind their policy digest to the run. Reject an unsupported location or unavailable retention enforcement. No raw secrets enter repository evidence. Covered by TEST-005/010. |
| Backup and budget prerequisites | Require explicit workload backup policy and budget ceiling; a required backup with missing configuration/evidence blocks applicable verification. Missing live budget prevents preparation. Covered by TEST-003/009. |
| Existing ownership and unsupported import | Preserve declared IaC owner and identifiers; block unsupported execution, import and destructive referenced-resource changes. Covered by TEST-002/007. |

These rows expose existing controls to the compliance review rather than
introducing new deployment authority.

### 5. Integration contracts and failure behavior

Add an `External integration inventory` subsection to design.md:

| Integration | Supported contract and purpose | Unavailable/incompatible behavior |
|---|---|---|
| GitHub Actions metadata/approvals | GitHub REST API with `X-GitHub-Api-Version: 2022-11-28`; GET `/repos/{owner}/{repo}/actions/runs/{run_id}` and GET `/repos/{owner}/{repo}/actions/runs/{run_id}/approvals`; protected prepare/apply environments and OIDC issuance | Block when approval history, reviewer identity, environment, current run attempt or trusted workflow/ref cannot be authenticated and matched |
| Azure resource manager | ARM deployment what-if and deployment operation APIs, `api-version=2025-04-01`; explicit subscription/resource-group/deployment identity | Block unknown or incomplete preview shapes and unsupported API versions; no alternate write path |
| AWS CloudFormation | CloudFormation API `2010-05-15`; Create/Describe/ExecuteChangeSet, DescribeStacks and DescribeStackEvents; exact ChangeSetName ARN and ClientRequestToken binding | Block ARN/template/account/region mismatch; ambiguous execution reconciles the original token/stack only |
| Azure authoring toolchain | Azure CLI 2.x and Bicep CLI; exact patch versions and binary/module digests selected and pinned before the first build | Major-version mismatch or lock drift blocks; no implicit latest download in a credentialed job |
| AWS authoring toolchain | AWS CLI 2.x and CDK CLI/library 2.x; exact lockfile/binary versions and complete cloud assembly/asset hashes | Version/assembly drift blocks; no `cdk deploy` or hotswap after approval |
| Upstream skills | The researched Git commit baselines already named in design.md, plus exact consumed/transitive file hashes | Missing pin or unreviewed content change blocks adoption |
| Managed MCP (optional planning) | Recorded endpoint and observed tool-schema digest, read-only compatibility probe | Unavailable/incompatible service blocks that capability; never substitutes another cloud writer |

For GitHub admission, require authenticated review history for the exact
prepare/apply environment, approved state, an allowed reviewer identity, and
an approval timestamp at or after the current run attempt's start. Match the
trusted repository, workflow revision/ref, run ID and attempt to authenticated
runtime/API metadata and the immutable artifact manifest. Require fresh
authorization on reruns. Reject ambiguity rather than guessing that an old
approval applies. Externally protected environment/IAM configuration remains
the authority; locally stored receipts alone are not authorization. Token
values are never persisted. Provider OIDC audiences are explicitly
`api://AzureADTokenExchange` for Azure and `sts.amazonaws.com` for AWS.

Exact CLI patch versions will be selected and compatibility-tested when the
adapter is implemented, then frozen in the dependency lock. The API versions
above are the design's supported provider contracts; selecting an untested CLI
does not waive the API/preview compatibility probes.

Documentation checked read-only on 2026-10-18:

- GitHub: https://docs.github.com/en/rest/actions/workflow-runs?apiVersion=2022-11-28
  (review-history endpoint is documented).
- Azure: https://learn.microsoft.com/en-us/rest/api/resources/deployments/what-if
  (returned documentation names API version 2025-04-01; an older requested view
  also returned this version, so the design must not claim the older view was
  verified).
- AWS: https://docs.aws.amazon.com/AWSCloudFormation/latest/APIReference/API_ExecuteChangeSet.html
  (documents ChangeSetName and ClientRequestToken).

These documentation checks do not establish live target compatibility or a
working CI authorization integration. The acceptance suite must test those
claims before deployment.

## Next Steps

The CLI authentication blocker is resolved. The specification gate is Passed.
The design gate remains Pending with this persisted BLOCKED verdict, and the
proposed revisions above are ready for human review. No product implementation
or cloud deployment has occurred.

The implementation-policy review skill explicitly requires presenting proposed
changes and says: "Halt and await human action." After human direction on this
concrete revision, apply it, preserve round 1 evidence, open the next legal
review attempt/round through the precheck, and run fresh independent reviewers.
Do not overwrite prior prechecks, reuse reviewer identities, or treat this
proposal as a Passed design.
