# Registry Lite opt-in contract

This follow-up implements the Registry revision designed by Epic A6 REQ-001
and explicitly deferred to an A2-owned task in its task scope and traceability.
It does not replace historical approvals or claim that the earlier revision
implemented these contracts.

## Product behavior

- Registry instances keep `schema: capability-registry/v1`.
- `lite_policy.required_lite_checks` is an optional array of unique check IDs
  matching `^[a-z0-9][a-z0-9-]*$`. An omitted field stays omitted. The Resolver
  continues to reject a matched Capability without that field under required
  Lite enforcement; advisory and zero-match handling remain unchanged.
- The version-1 Lite check catalog contains exactly `build`, `test`, and
  `installer-dry-run`. Its schema fixes the object keys, positive integer
  catalog version, nonempty unique check list and check-ID grammar.
- Registry validation check (j) independently rejects unknown check IDs with
  `unknown-lite-check: <capability-id>: <token>`. Invalid check declarations,
  missing catalogs and malformed catalogs fail closed. The existing packaged
  copy first, repository fallback discovery contract is retained; a malformed
  packaged catalog never falls back to a valid repository catalog.
- The upgrade-reason catalog is version 2: the existing five reasons plus
  `public_package_registry`, `store_distribution`, `auto_update`,
  `code_signing`, `payments`, `multi_tenant`, and `high_risk_migration`.
- Both new catalog artifacts are packaged by the existing vendor command and
  covered by its drift check. Canonical and packaged catalog paths are
  protected by the generated guard inventory.

The bundled developer-tooling and cli-library records, the A9 full Context,
and the Gate projection are unchanged. No current Pack is silently opted into
required Lite, no executable check is added, and no migration is performed.
A dedicated opted-in test Registry exercises the new authoring contract.

## Verification

The existing Registry validator Bash and PowerShell suites invoke the focused
Lite contract regressions. These use the real schema, CLI validator, catalog
discovery and Resolver; the positive Resolver case publishes only Capability
Summary and Resolver Evidence. Negative cases cover malformed/duplicate check
IDs, catalog shape and source precedence, independent (h)/(j) diagnostics,
and the absent/explicit-empty/zero-match distinction. Schema twins and the
three-runtime guard suite cover the new data contracts and actual write denial.
Existing discovery, runtime parity, A9 and current-byte compatibility checks
remain independent. Historical compatibility baselines are not rewritten.

Implementation basis: Epic A6 requirements REQ-001 and AC-001–AC-006/AC-029;
its design Data Plan and validator check (j); ADR-0022's opt-in Lite matrix.
