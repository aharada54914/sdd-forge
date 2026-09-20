# Frontend Specification: epic-196-a8-integration

N/A — no change: this feature introduces no browser/client UI and no new
runtime service (design.md Layer Specifications: "Frontend: N/A — no
browser or frontend application; every future-task deliverable this
package specifies is sh/PowerShell/Python plus JSON."). This document
instead records the script/runtime inventory this design's own
future-task edits actually use, since design.md's Components and API /
Contract Plan sections already own that content and this file restates
it in the layer-file shape the review harness expects.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Cross-runtime handoff fixture + driver | Markdown/YAML fixtures (`tests/fixtures/cross-runtime-handoff/`); sh/PowerShell driver (`tests/cross-runtime-handoff.tests.sh` / `.tests.ps1`) | repository-standard | Drives the two adjacent-CLI handoff steps and the full three-hop chain against the Fixture Contract table (design.md Data Plan); emits `cross-runtime-handoff-trace/v1` | The unified name is registered as both the Phase 2/3 acceptance-test target and the CI job step (design.md API / Contract Plan) — no second, competing script name |
| Install/uninstall matrix driver | sh/PowerShell (`tests/install-uninstall-matrix.tests.sh` / `.ps1`) | repository-standard | Drives REQ-002's install→verify→uninstall→verify cycle across the four `--target` values, calling `install.sh`/`uninstall.sh`/`install.ps1`/`uninstall.ps1` unmodified (design.md Components) | No `--target` runs all four cells sequentially; `--target <value>` runs exactly one cell (design.md API / Contract Plan, Test Strategy items 2-3) |
| Hook-guard cross-runtime regression (existing, extended) | PowerShell (`tests/cli-hook-enforcement.ps1`) | repository-standard, existing file (INV-013) | New assertions (Codex `plugin_hooks` flag matrix scaffolding, Copilot subagent-case scaffolding) are added directly inside this existing file, preserving every existing assertion unmodified (design.md Components, Test Strategy item 4) | No new suite file — this epic's own REQ-003 "synthetic/regression half" (AC-012, AC-017) stays structurally independent of the live-host proof (AC-015) |
| Live-host proof aggregate validator | sh/PowerShell thin wrappers over a shared aggregation routine (`plugins/sdd-quality-loop/scripts/validate-live-host-proof.{sh,ps1}`) | repository-standard | Loads all five semantic-cell `live-host-verification-record/v1` files plus the Nonce Issuance Ledger, Expected-Digest Manifest, `a8-skip-allowlist.json`, and Trusted-Signer Registry; reports `discharged`/`pending`/a named error code (design.md API / Contract Plan) | Read-only over every input except one lock-guarded, atomic, idempotent write to the Nonce Issuance Ledger's own `consumed_by_record` field (Protected-File Statement) |
| Path/line-ending regression driver | sh/PowerShell (`tests/path-lineending-regression.tests.sh` / `.ps1`) | repository-standard | Drives the REQ-004 pairwise covering combination matrix (16 rows × 3 cases, design.md Data Plan) against this epic's own Unicode-Normalization Contract | No flags; emits `path-lineending-fixture-result/v1` (design.md API / Contract Plan) |
| Installed-cache drift checker | sh/PowerShell thin wrappers over a shared comparison routine (`plugins/sdd-quality-loop/scripts/check-installed-plugin-drift.{sh,ps1}`) | repository-standard, matching the existing `sdd-hook-guard` multi-runtime-wrapper precedent | Compares an installed plugin cache against the repository's own install/uninstall-touched source surface by content hash, in `preflight` and `verify` modes (design.md Components, Data Plan) | Read-only; no write flag exists in its own interface (design.md Security Boundaries B2) |
| REQ-003/REQ-006 governance manifests | JSON, new (`plugins/sdd-review-loop/references/a8-skip-allowlist.json`, `a8-expected-hook-config-digests.json`, `a8-trusted-signers.json`) | new, this package's own addition | SKIP-governance allowlist, per-cell expected hook-config digests, and the Ed25519 Trusted-Signer Registry the aggregate validator resolves against (design.md Data Plan, Signing Contract) | Maintainer-committed; `validate-live-host-proof` treats each as read-only ground truth, never self-reported |
| Canonical schemas (six, this package's own addition) | JSON (inline schemas, no separate `.schema.json` file specified by this Phase 1 package) | new, this package's own addition | `cross-runtime-handoff-trace/v1`, `install-uninstall-matrix-result/v1`, `live-host-verification-record/v1`, `live-host-nonce-ledger/v1`, `path-lineending-fixture-result/v1`, `installed-plugin-drift-report/v1` (design.md Data Plan) | Every field is typed and constrained in design.md's own Schema Validation Rules subsections; no schema is a free-text/prose-only contract |

design.md's Components table names no new plugin and no new browser or
client-side artifact of any kind — every touched or new file this
package specifies is a Bash/PowerShell/Python test-infrastructure script
or a JSON data/manifest artifact under `tests/`,
`plugins/sdd-quality-loop/scripts/`, or `plugins/sdd-review-loop/
references/`.

## Component Tree / State Shape / Routes / API Client / Code Splitting / Performance Budget / Empty-Loading-Error-Success

N/A — no change: no browser UI, no client-side state, no routes, and no
API client of this feature's own. The closest analog — the seven CLI
contracts this package fixes (`tests/cross-runtime-handoff.tests.{sh,
ps1}`, `tests/install-uninstall-matrix.tests.{sh,ps1}`,
`check-installed-plugin-drift.{sh,ps1}`,
`validate-live-host-proof.{sh,ps1}`, `tests/path-lineending-
regression.tests.{sh,ps1}`) — is fully specified in design.md's API /
Contract Plan, not duplicated here.

## Dependencies

| Dependency | Status | Purpose | Alternative | License / Supply-Chain Note |
|---|---|---|---|---|
| Epic A1 Project Context / hook-activation handshake (`check-hook-activation-handshake.{py,sh,ps1}`, five migrated consumer entry points) | merged 2026-08-08 (Epic A1) | REQ-003's live-host proof (AC-015, AC-028) and the AC-016 five-consumer fingerprinted inventory depend on this script existing and being the sole issuer of the Nonce Issuance Ledger's own entries (design.md Data Plan, Cross-Layer Dependencies) | none — this package cites, never re-implements, A1's own handshake mechanism; AC-015/AC-016 activate the moment Epic A1's own canonical artifacts exist on `main` — a single-clause predicate with no task-start clause (design.md SKIP Allowlist Activation Gate; requirements.md:389, :536) — and Epic A1 merged on 2026-08-08, so both are activated now: a surviving `SKIP` for either is a hard failure `validate-live-host-proof` reports today, until T-008 discharges it. AC-006 is the one case that additionally requires its own owning task (T-005) to have started before its `SKIP` becomes a hard failure (design.md SKIP Allowlist Activation Gate) | Internal (same repository); no external package |
| `install.sh` / `install.ps1` / `uninstall.sh` / `uninstall.ps1` (existing, unmodified) | existing, live | REQ-002's matrix driver invokes these four scripts unmodified across the four `--target` values (design.md Cross-Layer Dependencies) | none — this package never re-implements installer/uninstaller logic | Internal (same repository); no external package |
| `tests/cli-hook-enforcement.ps1` (existing, extended) | existing, live (INV-013) | REQ-003's synthetic/regression half extends this file's own existing direct-invocation/config-drift assertions (design.md Components, Cross-Layer Dependencies) | none — this package re-uses, never replaces, this existing drift check | Internal (same repository); no external package |
| Three hook config files (`claude-hooks.json`/`hooks.json`/`copilot-hooks.json`) and `sdd-hook-guard.{js,sh,ps1,py}` (existing, unmodified) | existing, live | REQ-003's cross-runtime fixture and REQ-005's drift check both read these files (never modify them) as comparison/regression targets (design.md Cross-Layer Dependencies) | none | Internal (same repository); no external package |
| `.gitattributes` (existing, unmodified) | existing, live (INV-022) | REQ-004's CRLF-vs-LF fixture case asserts against this file's own already-committed `text=auto eol=lf` contract, never a new, competing normalization rule (design.md Data Plan) | none | Internal (same repository); no external package |

No new external (npm/pip/etc.) package is introduced by this feature —
every future-task deliverable is a JSON data/manifest file or an
additive/new Bash/PowerShell/Python test-infrastructure script under
this repository's existing `tests/` and `plugins/sdd-quality-loop/`,
`plugins/sdd-review-loop/` trees (design.md Global Constraints: no edits
to `plugins/**`, `scripts/**`, `.github/**`, `tests/**`, `contracts/**`,
or `docs/**` in *this* task). See security-spec.md's SBOM and Supply
Chain section for the full statement.

## Testing

No `tests/*.tests.sh`/`.tests.ps1` file is authored by this package
itself — this task's own change set is this document, the other three
layer-spec files, and the two named cited edits (design.md's own
Protected-File Statement scope). design.md's Test Strategy names eleven
ordered future-task items (REQ-001 fixture drive, REQ-002 matrix drive
local and CI, REQ-003 synthetic extension, REQ-003 live-host proof
5-cell matrix, REQ-004 path/line-ending drive, REQ-005 drift check,
classification-mismatch guard, citation compliance, aggregate live-host
Done gate, A5 caller-contract fingerprint precheck) that a Phase 2/3
implementation task authors. No browser/UI test tooling applies — no UI
exists for this feature.

## Open Questions

- None.
