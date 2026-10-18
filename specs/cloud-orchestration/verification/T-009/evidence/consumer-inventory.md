# T-009 current consumer/mirror inventory (before product edits)

Base: 0ec52d9853ac56c9022196834f0286cebe69bf53. Exact current bytes, including
pre-existing uncommitted T-006 work, are in the input manifests/snapshot.
`consumer-reference-inventory.json` retains all 270 current reference files and
line matches from runtime, contract, generator, installer and test trees. This
is a reference closure, not a claim that every matching comment is a consumer.
No raw reviewer reports or host event streams were read into this inventory.

## Direct dispatch and downstream consumers

- `plugins/sdd-quality-loop/scripts/check-contract.py`: standalone stdlib
  Python 3.6+ legacy entry; absent schema means legacy, explicit v2 accepted,
  explicit v1 and all other declared versions rejected. Baseline/risk sets and
  TDD/cross-model/producer-digest passes must remain unchanged.
- `check-contract.sh`: python3 then native PowerShell fallback. `check-contract.ps1`:
  independent legacy implementation, case-sensitive schema and check vocabulary.
  New cloud-only branch can require Python >=3.10; old branch must not import it.
- `evaluate-selected-plan.py`: imports check-contract AND independently computes
  risk-required IDs, validates Registry and Facet Manifest projections/digests,
  emits selected-verification-plan/v1. Explicit cloud dispatch must precede its
  legacy obligation recomputation, never happen from file existence.
- `check-evidence-bundle.sh/.ps1`, `prepare-panelist-input.sh/.ps1`,
  `check-traceability.sh/.ps1`, `check-criterion-freeze.sh`, quality-gate skill,
  verification-contract template: full-SDD callers/readers, NOT cloud executors.
  Cloud saved-file branch remains non-successful, so it cannot bypass their gate.
- `cloud_verification.py`: reduce and publish_collection; only the latter has the
  caller's fresh native decision. Existing provider `azure_observation.observe`
  and `aws_observation.observe` call it after federation, original-operation and
  resource binding. Saved manifests explicitly grant no authority.

## Source of truth and projections

- Capability Registry source: `contracts/capability-registry.json`, schema v1;
  packaged mirrors in `plugins/sdd-quality-loop/contracts/`. Provider-neutrality
  scan in `validate-capability-registry.py` forbids provider names. No registry
  v1 schema/stage changes and no provider resource gate added here.
- `registry_discovery.py`: packaged-first, git-root fallback, version failure is
  terminal. `generate-registry-digest.py`, `resolve-project-context.py`,
  `validate-resolver-evidence.py`, `validate-facet-manifest.py`, component-path
  consumers retain this v1 contract. `generate-gate-capabilities.py` derives
  scripts/generated/gate-capabilities.json from canonical registry v1.
- New separate runtime-profile allowlist: protected reference
  `plugins/sdd-quality-loop/references/cloud-verification-registry.json`; this
  does not redefine Foundation gates, capabilities or provider-neutral stages.
  Reserved profile id cloud-compute/version 2 opts into this additive path;
  cloud-verification-profile/v1 wire schema and older profiles remain intact.
- New verification-contract/v3 and selected-verification-plan/v2 schemas have
  canonical root sources and packaged copies produced by existing
  vendor-capability-registry.py. Existing selected-verification-plan/v1 schema
  and both capability-registry mirrors remain byte-identical.
- Guard source: references/guard-invariants.json. Generator:
  generate-guard-invariants.py. Four generated languages: guard_invariants.py,
  guard-invariants.generated.js/.sh/.ps1. No hand-maintained projection edits.
  Existing guards and human-copy membership remain unchanged; add protection
  for new runtime profile/schema dependencies, then regenerate.
- Distribution consumers: install/uninstall scripts, .github/workflows/test.yml,
  tests/run-all.sh/.ps1, registry/guard suites. No driver/install changes here.

## Actual old/new behavior

`boundary-probes.json` records eight inputs through Python, POSIX, PowerShell,
selected-plan subprocesses, including exact old required sets. Current v2 DOES
ignore arbitrary unknown fields (including a profile discriminator); this is a
measured legacy parser fact, not a claim of old strict rejection. The reserved
cloud discriminator will explicitly reject use under old schemas. Other legacy
fields, required IDs and waiver rules remain untouched. New v3 is fully closed.
The initial prospective-v3 probe rejects at version dispatch, not at a later
field mismatch guard; never label it executed mismatch validation.

## Provenance resolution

Root's supplemental root-provenance-design.md selects existing in-process
fresh collection as authority. Deterministic selection can succeed offline;
file-only consumers always BLOCK cloud overall success. No issuer, signature,
public trust override or T-010 scheduling introduced. Real IaC/policy checks use
existing executor.check over pinned exact artifacts; preview checks bind the
original cloud-preview record, request, semantic bytes and no-destructive policy.
Post-deploy results come from the existing T-006 collector/reducer, not fake unit
or TDD checks. Old profiles do not gain new mandatory checks implicitly.
