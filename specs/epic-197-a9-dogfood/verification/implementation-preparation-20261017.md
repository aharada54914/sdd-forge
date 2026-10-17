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
- New Python regression suite: 16 tests passed, including subcases for malformed
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

The actual repository advisory run also exposed a consumer boundary defect:
Resolver outputs canonical JSON under `facet-manifest.yaml`, but the Manifest
validator selected restricted YAML solely from the extension. The validator now
selects strict JSON canonicalization for JSON object bytes and retains restricted
YAML for block YAML. Both use the existing canonicalizer; malformed or duplicate
JSON fields fail rather than falling back. The real pipeline regression now runs
both independent Manifest and Evidence consumers on its published artifacts.

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


## Phase-2 candidate and release/CI consistency preflight

`scripts/validate-a9-candidate.py --phase phase2` now checks the A9-specific
atomic transition without restricting the generic three-axis Context schema.
Supply `--candidate`, `--baseline`, `--registry`, `--resolver-evidence`,
`--manifest`, and `--release-evidence` as paths to independently collected records.
The baseline must be the approved Phase-1 document; the candidate must retain all
other fields and change both axes to `full/facet-hybrid/required` together.
The existing Resolver Evidence validator remains authoritative for capability,
Registry and affected-component consistency. The supplied Registry must also
match the current canonical Registry, pass its schema, and use a current Registry
that passes the existing semantic validator. Coherently repinning an obsolete
Registry and both observations cannot satisfy that current-tree binding. The preflight additionally binds
its clean advisory result and Manifest to the current baseline Context,
tracked-path ownership and current Resolver version/rule set.

The release evidence is a read-only `a9-release-cycle/v1` index with:

- `base_sha` and `head_sha`: full commit IDs bounding one release cycle.
- `release`: the collected release's `tag_name`, `draft`, `prerelease` and
  timezone-qualified `published_at`. A final, already published release is
  required; its local tag must resolve to `head_sha`.
- `required_checks`: three keys, `linux`, `macos` and `windows`, each containing
  a nonempty list of distinct check names from the applicable CI policy.
- `advisory_check`: the distinct advisory capability Gate check name.
- `pull_requests`: one entry per merged PR with `number`, `head_sha`,
  `merge_commit_sha` and complete `check_runs` exports for that final PR head.
  Each check retains `id`, `name`, `head_sha`, `status` and `conclusion`.

The current repository uses merge/squash commits: the PR merge-commit roster
must equal Git's complete first-parent commit range, with no omission or
duplicate. Direct commits or a rebase-merge range that cannot be represented by
that roster reject and require explicit reconciliation; they are never silently
excluded from the cycle. The latest run ID for every observed check name must
be completed/successful. Missing platform/Gate checks, stale heads, pending,
failed, skipped or newer failed runs reject. Git operands are bounded commit
IDs and the release tag is validated as a ref before lookup.

This is **consistency checking of trusted exports**, not a GitHub authentication
or collection service. The operator must collect the complete release/PR/check
exports and applicable required-check policy from their authoritative sources.
A fabricated JSON index or an incomplete exported check list is not operational
evidence. The checker deliberately does not infer source authenticity from a
hash, a success string, or its own exit status.

Every result keeps `promotion_authorized: false`, `live_activation: not_attempted`
and `signed_approval: not_issued`. A successful Phase-2 preflight means only
`candidate_transition_and_release_ci_consistency`. It does not satisfy the
remaining human promotion approval, false-positive triage/unresolved finding
review, signed end-to-end OQ-004 rollback rehearsal, or post-promotion real
feature workflow. Existing HMAC approval and separate Ed25519 rollback proof
remain mandatory; no new approval or signature format is introduced.

Regression fixtures are explicitly synthetic, never saved as release evidence.
They cover both mixed tuples, unrelated Context changes, stale Resolver/Registry/
ownership bindings, incomplete PR rosters, all four Gate/platform check failures,
old-green/new-failure ordering, and actual isolated Git tag/ancestry lookup.
The pre-existing independent generic-axis positive tests remain unchanged.

Verification of this preflight change: the Bash and PowerShell entry points each
passed all 29 A9 tests on Linux. This includes the actual CLI reading
Resolver-produced JSON in `.yaml` files, a coherent stale-Registry repin negative,
and an isolated real Git release/tag positive that still returns
`promotion_authorized: false`. Repository validation, Python compilation and
whitespace checks also passed. These local results do not claim new Windows or
macOS execution, a genuine release observation, or a signed operational rehearsal.
