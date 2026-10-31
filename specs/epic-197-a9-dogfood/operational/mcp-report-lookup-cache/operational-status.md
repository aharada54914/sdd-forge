# Operational status for Issue 678

The owner has approved the prospective task, single-owner registry proposal and
exact Phase-1 candidate, and authorized completing the remaining operational
work. See [approval provenance](approval-provenance.json). T-678 is Approved /
Planned, not Done. The original exported draft is retained unchanged.

The request and technical contract now occupy their real repository paths.
Historical raw execution evidence was restored byte-for-byte, not rerun or
redated. Current source comparison confirms the four production files, report
reuse test and dependency lock match the historical record. Generated dist output
was not regenerated or asserted current. The Approved/Planned task-state check
and contract check were executed again; their separately named records retain
actual timestamps and outputs.

## Remaining boundary

PR #681 contains an owner-authorized delegated cloud signature. Its cloud key is
agent-accessible, so it does not satisfy ADR-0019 / A1 B3 external-key custody.
The current GitHub integration returned HTTP 403 (Resource not accessible by
integration) for the repository Actions secrets metadata endpoint. The managed
runtime has no configured independent signing service. These are infrastructure
and access limitations, not a pending request to approve T-678 again.

No live project-context.yaml, approval sidecar, approved anchor, or registry is
activated by this change. The committed request alone cannot activate advisory
collection. Production acceptance still requires an independent authorized
signer, publication through the existing transactional mechanism, genuine
final-head advisory collection with authenticated CI association, and an actual
published-release interval. Promotion is conditional on observed evidence; a
retain-advisory decision must not be reported as completed Phase-2 execution.

Private raw advisory observations must remain private. This directory contains
only the previously reviewed public technical evidence and preparation records.
Issue #678 remains open.

Preparation friction: the first current contract check rejected UTC `+00:00`
notation because its contract requires `Z`. Only the timestamp representation
was corrected; the actual instants and original execution record were preserved.
The failed and successful check outputs are both retained. This is preparation
friction, not a completed live advisory observation.

## Release readiness

The current declared version is 1.18.0 with Unreleased additions. Repository
Release listing returned zero records during preparation. A next minor 1.19.0
is a reasonable proposal for the added features, not a published version or a
version bump performed by this preparation.

After genuine advisory activation, publish a real bootstrap Release to establish
the start boundary (1.19.0 is the provisional proposal above). Then perform the
actual observed PR interval and publish a subsequent Release as its end boundary.
Choose the endpoint version from the actual changes after their checks succeed.
This plan satisfies both release boundaries without inventing a historical
Release; neither Release has been published by this preparation.

Record the start commit and final release head explicitly. The release preflight
accepts explicit base/head commits and requires a genuine published final
Release/tag at the head. Every first-parent commit in that interval must map
exactly once to an observed PR and its final-head checks.

Use the existing contributor release runbook: add the actual CHANGELOG version
heading, run `bash scripts/bump-version.sh <version>` (including its mandatory
loop suites), review and merge the release changes with their own advisory
request/evidence, and obtain successful `test.yml` execution on the exact tag
commit before publication. The existing `release.yml` checks that exact-commit
CI result before building artifacts, checksums, SBOM and attestations. Preserve
authentic PR/check/observation associations and verify the published artifacts.
Release work is authorized in the current task; infrastructure and genuine
execution evidence, rather than renewed blanket approval, remain prerequisites.

Promotion is deferred pending actual advisory/release results. This is a current
status, not a completed evidence-based final promotion decision. If the eventual
decision is to retain advisory, record its measured basis; do not claim Phase-2
or post-promotion feature acceptance occurred.

## Placement and task identity

The original preparation used packet-local T-001 under an unregistered new
specification directory. Repository workflow-state CI rejected that placement.
This work is operational acceptance of existing A9, not a newly completed
full development workflow, so the packet now resides below the existing A9
operational directory. Its unused task identifier is T-678, with the contract
in A9 verification/T-678/contract.json. The owner's approved scope is unchanged.
Historical execution bytes retain their original T-001 and source paths; the
relocation map and current contract provide the explicit correspondence. No
Passed spec/implementation/task review history was fabricated to register a new
full-profile feature.
