# A9 executable preparation — 2026-10-17

This addendum records implementation and current verification. Historical review
outputs and their Pending/NEEDS_WORK/BLOCKED results remain unchanged. This does
not declare Issue #197 complete, publish a live Context, issue an approval,
collect a release cycle, or authorize Phase-2 promotion.

## Implemented scope

- An unpublished Phase-1 candidate with the approved nine components,
  full/legacy-seven-layer/advisory tuple, exact component classifications, and
  the two scoped CI credential/release-write overrides.
- Optional override shape in the Project Context schema. Ownership validation,
  Resolver admission and approval-content admission reject unknown names,
  non-boolean/no-op values, missing/extra fields, multiline/blank rationales,
  invalid placement, out-of-component scopes and excluded scopes. The existing
  ownership matcher remains authoritative.
- Two Registry capabilities, developer-tooling and cli-library, using the
  approved artifact-kind predicates, facets, review checks, human-copy delivery,
  and Lite eligibility. They introduce no gate or minimum-enforcement override.
- Facet templates and instructions for existing reviewers to inspect the
  already allowed design input. Findings use the existing review schema.
- A read-only candidate validator and regression coverage in the existing
  POSIX inventory, PowerShell runner and three-platform CI topology.

## Current-tree ownership reconciliation

The original seven growing shared directory patterns and plugin/MCP component
subtrees are retained. No catch-all ownership pattern was introduced.

The current session authorizes ordinary implementation decisions needed for a
usable fix. The obsolete fixed-root inventory was therefore reconciled with
tracked responsibilities, rather than treating historically unlisted files as
an unresolvable policy question:

- Installer ownership also includes the two agent-frontmatter renderers and the
  two distribution rollback scripts. They operate on installed distributions.
- Repository metadata, marketplace registration, local agent definitions,
  handoffs, learning records, branch-protection/structure tooling, mirror-sync
  tooling, evaluator-isolation measurements and the standalone adversarial
  review skill are exact-path cross-cutting entries. Their responsibilities
  span the component packages; they do not become arbitrary future subtrees.
- The candidate validator itself is an exact-path cross-cutting maintenance
  tool. Future unlisted root files continue to produce UNOWNED findings.

The candidate validator checks the real tracked-path inventory, rejects
unowned/overlapping files, and requires every component to own tracked files.
The component schema and A9-specific classification checks reject missing,
additional or misclassified components instead of hiding inventory drift.

## Verification actually executed

- Initial new regressions failed on the original schema/Registry/validator:
  the approved overrides were not accepted and both Pack capabilities were absent.
- New Python regression suite: 15 tests passed, including subcases for malformed
  overrides, classification and inventory mutations, and real approval-content
  admission. The PowerShell entry point passed the same suite on Linux.
- Existing Project Context schema: 44 passed, 0 failed.
- Existing component-path resolver: 73 passed, 0 failed.
- Existing approval-sidecar suite: 50 passed, 0 failed.
- Existing Resolver block suite: 407 passed, 0 failed.
- Existing Registry schema: 6 accepted and 16 rejected fixtures passed.
- Existing Registry semantic-validation fixture suite: 27 checks passed.
- Candidate validation against tracked files passed. It explicitly reports
  live activation not attempted, signed approval not issued, and release-cycle
  evidence not collected.

## Integration boundaries still open

PR #535 was integrated at `76e442b3`. Its canonical Registry repairs now
allow the real candidate/Pack pipeline to run. Integration exposed two additional
faults: the output Context Projection schema rejected the valid input overrides,
and the generated repository-wide projection was incorrectly owned by the quality
plugin. The output schema now carries the same bounded override fields, and the
single generated projection path is explicitly cross-cutting. No source path is
ignored and no concurrency or publication check is weakened.

Real subprocess regressions now execute Git diff collection, canonicalization,
ownership, Registry validation, predicate selection, publication and a second
unchanged-source run. Plugin, MCP, installer, mixed, nonmatching and case-variant
inputs produce the expected facets with zero added gates. Full required and Lite
advisory fixture runs preserve their input track; the Lite run produces its
Summary without a Full Manifest/Projection. Removing either the override output
contract or the cross-cutting projection rule reproduces its corresponding
failure, and the failed publication leaves no successful Manifest.

Additional verification after integration: the existing Resolver block suite
passed 407 checks; Context schema passed 44; Facet Manifest schema passed 57;
Registry semantic validation passed 27; Registry schema passed its accepted and
rejected fixtures; install/uninstall matrix passed 20. Candidate ownership includes
the two new exact-path cross-component handoff manifests from #535.

The divergent pre-integration A9 identity ledger is preserved byte-for-byte in
`identity-ledger-pre-integration.json`, with its original sequences and hashes.
The canonical ledger follows #535. The archived A9 review records were not
re-chained, newly signed, or treated as fresh review approval. The immutable
preparation commit `bc7be7f7` also retains the original invocation paths.

Actual live activation still requires usable A7/A8 native integration and a
valid, separately authenticated publication. No signing key or human identity
was invented. All-PR advisory evidence over a bounded release cycle, Phase-2
promotion, a real post-promotion feature, rollback field evidence, and final
friction/WFI disposition remain incomplete. The release cycle cannot be inferred
from deterministic fixtures or successful CI for this preparation change.
