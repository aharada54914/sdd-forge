# ADR 0048: Shared schema validation runtime

Status: Accepted — 2026-11-07

The facet manifest, capability summary and context projection validators copied
one bounded JSON Schema engine. New constraints such as `maxLength` were silently
ignored. INV-014 prohibited dependencies and shared imports as an implementation
convention; neither is needed to preserve deterministic standalone CLI entry points.

All three entry points now use `plugins/sdd-quality-loop/scripts/sdd_schema.py`.
Their schema discovery, YAML canonicalization, semantic checks and CLI contracts
remain local. The adapter preserves diagnostic IDs, RFC 6901 paths, existing
messages, ordering and UTF-8/LF output; the library decides schema validity.

## Alternatives and decision

- Generate three copies: rejected; adds a build step while retaining redundant output.
- Python `jsonschema`: supports iterative diagnostics, but its `rpds-py` dependency
  requires native wheels and a new managed Python installation/distribution model.
- Bundled `fastjsonschema`: selected. Version 2.22.3 is pure Python, supports
  Draft 7 and collection of multiple errors. It has no transitive dependencies.
  Python 3.10 or newer is required for these three validators. Node is not needed
  for JSON-input schema validation.

The unmodified hash-locked wheel is shipped as a zip-importable dependency,
including its BSD license. It is loaded under a private package namespace. `scripts/update-schema-vendor.py` reproduces it; `manifest.json` records
upstream file hashes. Installers copy the package through the existing `plugins/`
payload rule. Runtime execution requires neither pip, network nor ambient packages.
Development checkouts execute exactly the same packaged code.

The adapter explicitly selects Draft 7, validates schemas against the bundled
Draft 7 metaschema, rejects unknown schema keywords (an explicit project profile),
and admits only same-document `$ref` values. Literal data keys are not schema keywords. It disables data
mutation via defaults and optional format assertions, preserving existing behavior.
ECMA end-anchor adaptation preserves the trailing-newline rejection contract.
The adapter's narrow generator subclass prevents diagnostic rendering from treating
literal `$ref` data inside `const`/`enum` as schema references. This private-library
extension is pinned and covered by regression tests; updates must requalify it.
The original vendor source is never patched.

The library exposes display paths rather than JSON Pointers. The adapter maps
those using actual document keys, so dots, brackets, slashes and tildes in keys
are not split. If distinct paths have the same library display string, diagnostics
use the document root rather than falsely identifying a field. Validation still
fails. Python regex support is not a claim of complete ECMA-262 compatibility.

The metaschema is reproduced from `jsonschema` 4.26.0's Draft7Validator.META_SCHEMA
(the official Draft 7 schema); its MIT license is included with the bundled data.
Historical implementation descriptions in the original feature spec are retained
with a superseding notice. Approval-sidecar and component-path validators remain
separate because their independence and PowerShell parity contracts differ.

## Verification and maintenance

The historical `schema-engine-identity.tests.sh` entry point now checks shared
callable identity, all 126 equality cases, newly enforced keywords, reference
policy, input immutability, vendor integrity and installed execution with Python
site packages disabled. Existing Bash/PowerShell schema, semantics, staleness and
parity suites remain mandatory. The dependency integrity check must fail if a
Dependabot lock update has not been followed by vendor regeneration.

Dependabot checks Actions, the three MCP packages and the Python schema runtime
quarterly; compatible minor/patch updates are grouped. Security fixes need not
wait for the next scheduled ordinary update. Do not automatically merge dependency
updates or bypass validation.

The same refactoring finishes the previously staged Node 26 setup and Claude CLI
pin in CI, and gives each local-env MCP server its own probe cache while retaining
the process-wide concurrency cap of four. Explicit injected probes remain supported.
