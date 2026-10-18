# T-004 implementation boundary: unresolved local invocation inputs

This is an implementation finding, not a review verdict or a specification amendment.

## Concrete gap

The design requires scans of the deployment unit's **declared roots**
(`specs/cloud-orchestration/design.md:119-128`), contained resolution against a
**declared workspace/artifact root**, and output within the **run's evidence
directory** (`design.md:322-329`). The public CLI declares only operation,
`--request`, and `--output`. The actual strict request contract provides no
root declarations or reference to a deployment-unit ownership inventory.
`cloud-run-request.schema.json:3` forbids additional properties, and its policy
and verification-profile objects are only digest-bearing references (lines
186-233). The shared parser enforces that closed shape rather than ignoring
unknown fields. Its filesystem reader requires the caller to supply a root;
it does not discover an authoritative root (`cloud_contracts.py:334-356`).

The reproducible `probe-contract-gap.py` prints the entire request-property
inventory, parses a conforming Azure request, and demonstrates rejection of
illustrative root/owner fields. Those illustrative names are not a proposed
wire contract. Its exit 0 means this gap was reproduced, not that routing passed.

The policy file body also has no registered local Azure format for mandatory
backup, approved additive attachments, explicit existing resource IDs, or
monitoring/health expectations. The shared T-003 `Policy` dataclass explicitly
represents trusted executor configuration, not an untrusted request policy
parser (`cloud_authorization.py:144-174`). It cannot safely be repurposed as
local deployment ownership metadata.

## Why implementation stopped

Choosing cwd, request-parent, a filename such as owner.json, or an unreviewed
policy-body shape would create an implicit security/ownership contract, not
merely implement the reviewed declared-root boundary. Broadly scanning a guessed
parent can read unrelated units; narrowly scanning only listed Bicep files can
miss pre-existing Terraform/SAM/azd ownership. Making roots user-selectable
through new flags/fields would change the strict public interface. T-004 does
not own the shared contract files and this run cannot amend frozen design.

## Required root decision

Specify the canonical source of workspace/artifact root, unit scan roots,
evidence directory, existing owner/resource-ID metadata and local policy-body
format. Define how these inputs are bound to the request and how invalid-output
errors are represented without inventing an evidence receipt. Root should
coordinate any necessary T-002 contract work and authorized specification
addendum/review; this run has not edited those surfaces or started a new review.
Do not solve this by dropping containment, accepting unknown fields, guessing an
owner, or treating any locally supplied policy as cloud authority.

## Delivered and not delivered

Only the initial unambiguous CLI rejection tests are committed. Four test methods
produce 20 failing cases because no provider CLI exists; plain Python exit 2 is
not a genuine typed BLOCKED result. No route, plan, validate, owner scanner,
provider stub, or cloud operation has been implemented in this run. No positive
routing test was invented around an unspecified metadata format.

Bicep acquisition/compilation, actual upstream file closure, private VM example,
policy-negative fixtures, installed discovery and native platform integration
remain unexecuted. No compiler, ARM validation, deployment or upstream pin is
claimed. OQ-001 separately blocks live acceptance; it is not this local blocker.
