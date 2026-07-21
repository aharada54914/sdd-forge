# Frontend Specification: epic-189-a1-project-context

N/A — no change: this Epic introduces no browser/client UI and no new
runtime service (design.md header, Feature Type: "no UI, no new plugin, no
Provider integration"). This document instead restates the script/runtime
inventory design.md's Components section already owns, in the layer-file
shape the review harness expects.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Script runtime (master, five script families) | Python | repository-standard (not independently pinned by this spec) | `canonicalize-sdd-yaml.py`, `generate-approval-sidecar.py`, `validate-approval-sidecar.py`, `detect-policy-weakening.py`, and `check-hook-activation-handshake.py` each implement the actual operator/evaluation-semantics/validation logic; Python + thin `sh`/`ps1` wrapper pairs is the established repository pattern (Components) | `.py` is always the canonical implementation; wrappers are dispatch-only (Canonicalization procedure, REQ-003) |
| Script runtime (wrappers, five script families) | POSIX sh, PowerShell | repository-standard | Thin argument-forwarding dispatchers only — locate `python3`, else `python`, on `PATH` and exec the `.py` file with stdin/stdout passed through unchanged; no logic duplication | one wrapper pair (`.sh`/`.ps1`) per `.py` master, same directory, same basename (Components); if neither Python binary is found, ALL wrappers deny fail-closed with the SAME documented exit code (`CANONICALIZER_RUNTIME_UNAVAILABLE`, exit 3, for the canonicalizer specifically) |
| Script runtime (canonicalizer only, fourth wrapper) | Node.js (`.js` wrapper) | repository-standard | `canonicalize-sdd-yaml.js` is the ONE script family in this Epic that ships a fourth wrapper, matching `sdd-hook-guard`'s own four-runtime precedent (decision doc §18.3, Constraint Compliance) | `.js` is unique to the canonicalizer; the other four script families (`generate-approval-sidecar`, `validate-approval-sidecar`, `detect-policy-weakening`, `check-hook-activation-handshake`) ship only `.sh`/`.ps1` (Components) |
| Script runtime (publisher, one exception) | POSIX sh, PowerShell only — NO Python master | repository-standard | `apply-human-copy.sh` / `.ps1` (REQ-007) is the one script family in this Epic with no `.py` master at all — its logic (held handle, handle-relative traversal, temp-rehash, atomic rename, journal-write-before-rename) is implemented directly in each of the two wrapper runtimes, not dispatched to a shared Python implementation (Components) | exactly two runtime implementations (`sh`, `ps1`), each independently authoritative — no third `.py`/`.js` twin exists for this family |
| YAML parsing library (canonicalizer's own dependency) | PyYAML or `ruamel.yaml` (Python, standard library ecosystem) | confirmed available at a future implementation session (not independently pinned by this spec) | `canonicalize-sdd-yaml.py`'s YAML 1.2 core-schema, single-document, anchor/alias/tag/duplicate-key-rejecting parse (REQ-003, Canonicalization procedure) is built on a standard library in its strictest built-in mode, PLUS an explicit post-parse structural walk that independently rejects any alias/anchor/non-core-tag/duplicate-key node — never a bare loader-flag reliance, since a library's "safe" mode is not guaranteed to reject duplicate keys (Design Decisions: "PyYAML's `SafeLoader` silently keeps the LAST occurrence of a duplicate key by default") | the choice between PyYAML and `ruamel.yaml` is left to implementation time; either must support the strictest-built-in-mode-plus-explicit-post-parse-walk contract |

## Component Tree / State Shape / Routes / API Client / Code Splitting / Performance Budget / Empty-Loading-Error-Success

N/A — no change: no browser UI, no client-side state, no routes, and no API
client of this Epic's own. The closest analog — each script's CLI argument
contract, exit-code taxonomy, and stdout/stderr framing — is fully specified
in design.md's API / Contract Plan (the Canonicalization procedure, HMAC
preimage and signing, Weakening-detector approved-context anchor CLI
contract, and Human-copy publisher transactional bundle contract
subsections), not here.

## Dependencies

| Dependency | Version | Purpose | Alternative | License / Supply-Chain Note |
|---|---|---|---|---|
| PyYAML or `ruamel.yaml` | confirmed available at a future implementation session (Design Decisions) | YAML 1.2 core-schema parsing step for `canonicalize-sdd-yaml.py` (REQ-003) | Either library satisfies the contract; a hand-rolled parser was considered and rejected in favor of a standard library in strictest mode plus an explicit post-parse structural walk (Design Decisions) | Internal to the Python ecosystem already used by this plugin family; no new external service dependency |

No other new external (npm/pip/etc.) package dependency is introduced by
this Epic — see security-spec.md's SBOM and Supply Chain section for the
full statement. This Epic defines no Provider integration and no External
Integrations of its own (design.md header, Feature Type).

## Testing

`tests/*.tests.sh`/`.tests.ps1` pairs (Test Strategy items 1-12, design.md),
each new suite self-registering (grepping `tests/run-all.sh`/`.ps1` for its
own basename, unprotected, checked directly at agent-commit time, mirroring
`tests/second-approval-mask.tests.sh:285-289`'s established pattern, Test
Strategy item 11) and staged via `apply-human-copy` for
`.github/workflows/test.yml` (Protected-File Statement; Global Constraints).
No browser/UI test tooling applies — no UI exists for this Epic. Test
Strategy item 12 declares the same non-use/CI-resilience discipline prior
epics established: no suite invokes a real LLM, `gh`, or `sdd-sudo`; every
mktemp fixture root is `pwd -P`-normalized immediately after creation; no
possibly-empty bash array is expanded under `set -u`.

## Open Questions

- None.
