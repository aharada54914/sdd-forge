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
| YAML parsing (canonicalizer-internal — no library) | Hand-written restricted YAML-subset parser, Python stdlib only | repository-internal code inside `canonicalize-sdd-yaml.py` — no package exists to pin | `canonicalize-sdd-yaml.py`'s parse step (REQ-003, Canonicalization procedure) is a HAND-WRITTEN, stdlib-only, RESTRICTED YAML-SUBSET parser per the 2026-07-24 human decision (design.md Design Decisions, revised — option B; `reports/notes/epic-189-a1-decision-3-yaml-parser.md`): scalar resolution follows the YAML 1.2 core schema over the normatively defined accepted subset only, and anchors/aliases/non-core tags/duplicate keys/non-string keys plus every out-of-subset construct are rejected fail-closed at parse time, each with its own named category (`UNSUPPORTED_SYNTAX_REJECTED` for out-of-subset syntax) — never a best-effort interpretation | NO third-party YAML library (the prior draft's PyYAML/`ruamel.yaml` choice is retired, Design Decisions), no `requirements.txt`, no packaging change; the parser is part of the canonicalizer's single behavioral implementation, wrappers stay dispatch-only |

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
| (none — zero new packages) | n/a | YAML parsing for `canonicalize-sdd-yaml.py` (REQ-003) is a hand-written restricted YAML-subset parser internal to the script itself, Python stdlib only (design.md Design Decisions, revised 2026-07-24 — human decision-3 = B) | The prior draft's PyYAML/`ruamel.yaml` standard-library choice was RETIRED when the implementation session confirmed neither module exists in the target environment and this repository has never had a Python packaging file; the reviewed A3-shape precedent (epic-191 branch's restricted YAML-subset config parser) is followed instead (Design Decisions) | Zero new external (npm/pip/etc.) packages; nothing enters any SBOM; no new external service dependency |

No new external (npm/pip/etc.) package dependency of any kind is introduced
by this Epic — see security-spec.md's SBOM and Supply Chain section for the
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
