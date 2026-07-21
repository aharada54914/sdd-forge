# Design: epic-189-a1-project-context

Impl-Review-Status: Pending
Feature Type: schema + security-infrastructure (canonicalization, HMAC
approval sidecar, protected-file registration, hook-guard extension,
track-selection contract migration) — no UI, no new plugin, no Provider
integration

## Technical Summary

Eleven requirements land as one dependency-ordered chain, root-first:
REQ-001/REQ-002 (the two YAML schemas) are consumed by REQ-003 (the
canonicalizer, which needs something byte-stable to hash) and by REQ-009
(track-selection reads `workflow.*`); REQ-003 is consumed by REQ-004
(the sidecar's HMAC preimage is canonical-JSON bytes) and by REQ-006 (the
weakening detector diffs canonicalized before/after documents, resolving
its own trust anchor internally from a protected approved-context snapshot
(the last content a human actually approved, REQ-004/REQ-007) rather than
accepting one from a caller or from git HEAD); REQ-004 is
consumed by REQ-005 (the validator recomputes REQ-004's own construction,
including the `DUPLICATE_APPROVER_IDENTITY` check REQ-004's generator also
applies); REQ-005 and REQ-006 are consumed by REQ-009: a Project Context
PHYSICALLY ABSENT uses the compatibility fallback, while one PHYSICALLY
PRESENT but failing REQ-005 validation (for any reason) STOPS with
`PROJECT_CONTEXT_INVALID` — these are two distinct outcomes, not one
"treated as absent" outcome reused for both (revised, closes a Blocker
finding); REQ-007 (protected registration, generalized to an anchored-
publisher-equivalent human-copy tool) is a precondition every other new
script and the new sidecar/registry/sentinel files structurally depend on
for their integrity claim to hold; REQ-008 (hook-guard extension) is not new
code — it is the existing `_is_protected_gate_file` deny path, activated by
REQ-007's registration, with its own dedicated full-matrix test coverage;
REQ-010 (hook handshake, redesigned as a host-side canary tool-call
challenge/response protocol — no standalone-script file-I/O probe) is wired
into all five of REQ-009's migrated entry points; REQ-011 (3-env
tests) closes every REQ above.

The guiding principle, carried from ADR-0019's own Context section: an
unsigned hash is a *binding*, never an *authenticity* claim. Every new
mechanism in this design either produces a binding (REQ-003's canonical
hash), an authenticity claim (REQ-004's HMAC, signed by a key no agent ever
holds), or a check that both hold before anything is trusted (REQ-005). No
new mechanism in this design ever asserts authenticity from a hash alone.

## Architecture

```mermaid
flowchart TB
  PC["sdd/project-context.yaml (REQ-001, target-project instance — NOT created by A1 itself)"]
  PB["sdd/provider-bindings.yaml (REQ-002, same)"]
  SCHEMA_PC["contracts/project-context.schema.json (new)"]
  SCHEMA_PB["contracts/provider-bindings.schema.json (new)"]
  SCHEMA_PC -.->|validates| PC
  SCHEMA_PB -.->|validates| PB

  CANON["canonicalize-sdd-yaml.py + .sh/.ps1/.js wrappers (REQ-003, new; python3/python dispatch only, no PowerShell-native fallback)"]
  PC --> CANON
  PB --> CANON
  CANON -->|canonical hash| SIDE_PC["sdd/project-context.approval.json (REQ-004, PROTECTED, LIVE — never written by GEN directly)"]
  CANON -->|canonical hash| SIDE_PB["sdd/provider-bindings.approval.json (REQ-004, PROTECTED, LIVE)"]

  GEN["generate-approval-sidecar.py/.sh/.ps1 (REQ-004, new; human/CI-only, needs SDD_CONTEXT_KEY; REFUSES duplicate approver id)"]
  GEN -->|nonce-tagged sidecar candidate + approved-context snapshot + MANIFEST.sha256, staging ONLY| STAGE["sdd/.staging/<schema-id>/<nonce>/ (REQ-004, new, unprotected staging area)"]
  REG["sdd/approver-registry.yaml (REQ-006, PROTECTED, new — id is the immutable identity key)"]
  REG -.->|approver id + count| GEN
  ANCHOR["sdd/.approved-context/*.approved.yaml (REQ-006/007, PROTECTED, new — the last human-approved content, published by PUBLISHER alongside its sidecar)"]
  PUBLISHER -.->|publishes in lockstep with the sidecar| ANCHOR

  DETECT["detect-policy-weakening.py/.sh/.ps1 (REQ-006, new; default anchor = the protected sdd/.approved-context/*.approved.yaml snapshot, NEVER caller-supplied or git-HEAD-derived in production call path)"]
  PC -.->|candidate, no --approved-context| DETECT
  PB -.->|candidate, no --approved-context| DETECT
  ANCHOR -.->|default-resolved trust anchor| DETECT
  REG -.->|two_person_required / cooldown_hours| DETECT
  DETECT -->|verdict, recomputed fresh, never trusted from a file| GEN
  DETECT -->|verdict, recomputed fresh, never trusted from a file| VALIDATE

  VALIDATE["validate-approval-sidecar.py/.sh/.ps1 (REQ-005, new; content-schema + hash + HMAC + approver-id + duplicate-id + effective_at)"]
  STAGE -.->|pre-publish validation| VALIDATE
  SIDE_PC -.->|post-publish re-check| VALIDATE
  SIDE_PB -.->|post-publish re-check| VALIDATE
  PC -.->|hash re-check| VALIDATE
  PB -.->|hash re-check| VALIDATE
  REG -.->|approver identity + distinctness check| VALIDATE

  PUBLISHER["apply-human-copy.sh/.ps1 (REQ-007, new, anchored-publisher-equivalent; ADR-0011-generalized)"]
  VALIDATE -->|staged candidate PASSES| PUBLISHER
  PUBLISHER -->|atomic rename, held-handle, no path-copy fallback| SIDE_PC
  PUBLISHER -->|atomic rename, held-handle, no path-copy fallback| SIDE_PB
  PUBLISHER -.->|same publisher applies| GINV_STAGE["guard-invariants.json / generate-guard-invariants.py / generated/* / PLUGIN-CONTRACTS.md consumers / test.yml (REQ-007/009/011 staged candidates)"]

  GUARD["sdd-hook-guard.py/.sh/.ps1/.js — _is_protected_gate_file (EXISTING, unchanged decision logic)"]
  GINV["guard-invariants.json + generate-guard-invariants.py + generated/* (REQ-007, human-copy edit via PUBLISHER)"]
  GINV -.->|registers SIDE_PC, SIDE_PB, REG, SENTINEL, CANON, GEN, VALIDATE, DETECT, HANDSHAKE, RESOLVER(reserved), PROJECTION(reserved) as protected| GUARD
  GUARD -->|full write-deny, no sudo bypass, 4-basename x 12-call-site matrix| SIDE_PC
  GUARD -->|full write-deny, no sudo bypass| SIDE_PB
  GUARD -->|full write-deny, no sudo bypass| REG
  GUARD -->|full write-deny, no sudo bypass| SENTINEL["sdd/.hook-canary-sentinel (REQ-007/010, PROTECTED, new — canary target ONLY, never live approval state)"]

  HANDSHAKE["check-hook-activation-handshake.py/.sh/.ps1 (REQ-010, REDESIGNED: emits challenge/nonce; verifies AGENT-recorded response; never itself attempts a write)"]
  AGENT["Agent session's OWN native tool-call (real Edit/Write/Bash/apply_patch attempt against SENTINEL, per-runtime)"]
  HANDSHAKE -->|--emit-challenge: nonce + sentinel target| AGENT
  AGENT -->|proposed tool call, host-intercepted| GUARD
  GUARD -->|deny (or non-deny) surfaced via host's own reporting| AGENT
  AGENT -->|recorded raw result + nonce| HANDSHAKE
  HANDSHAKE -->|--verify-response: HOOK_ACTIVE or CAPABILITY_RUNTIME_UNAVAILABLE| ENTRYPOINTS

  VALIDATE -.->|PROJECT_CONTEXT_INVALID (if present-but-invalid) or pass-through to compatibility fallback (if absent)| ENTRYPOINTS["REQ-009's five migrated entry points"]
  CONTRACTS["PLUGIN-CONTRACTS.md Track Detection (REQ-009, unprotected edit)"]
  SHIP["sdd-ship Track Detection (REQ-009, human-copy via PUBLISHER)"]
  BOOT["bootstrap SKILL.md (REQ-009, unprotected edit)"]
  INTERVIEWER["sdd-bootstrap-interviewer SKILL.md, 3 read sites (REQ-009, unprotected edit)"]
  LITESPEC["lite-spec SKILL.md (REQ-009, human-copy via PUBLISHER)"]
  LITEGATE["lite-gate SKILL.md (REQ-009, unprotected edit — confirmed in-scope)"]
  ENTRYPOINTS --- SHIP
  ENTRYPOINTS --- BOOT
  ENTRYPOINTS --- INTERVIEWER
  ENTRYPOINTS --- LITESPEC
  ENTRYPOINTS --- LITEGATE
  SHIP --> CONTRACTS
```

## Components

| Component | Responsibility | Technology | New/Existing | Protected? |
|---|---|---|---|---|
| `contracts/project-context.schema.json` | schema for `sdd/project-context.yaml` (`sdd-project-context/v1`) | JSON Schema | new | no |
| `contracts/project-context.template.yaml` | generic starter scaffold; SINGLE-SOURCE cross-cutting seed-list inventory (`specs/**`/`reports/**`/`docs/**`/`.github/**`/`tests/fixtures/**`/`CHANGELOG.md`) pre-populated (closes NEW-001); read directly by Epic A3's day-one fixture | YAML | new | no |
| `contracts/provider-bindings.schema.json` | schema for `sdd/provider-bindings.yaml` (`sdd-provider-bindings/v1`), skeleton only | JSON Schema | new | no |
| `contracts/approval-sidecar.schema.json` | schema for both `*.approval.json` sidecars | JSON Schema | new | no |
| `contracts/approver-registry.schema.json` | schema for `sdd/approver-registry.yaml` | JSON Schema | new | no |
| `canonicalize-sdd-yaml.py` | YAML 1.2 core-schema parse (single-doc only), anchor/tag/dup-key/non-string-key/post-NFC-collision/out-of-range-number reject, NFC, RFC 8785 JCS, sha256, byte-exact stdout framing | Python | new | **YES** (REQ-007) |
| `canonicalize-sdd-yaml.sh` / `.ps1` / `.js` | thin dispatchers, `python3`/`python` resolution ONLY — no PowerShell-native fallback (revised, M10) | POSIX sh / PowerShell / Node | new | **YES** (REQ-007) |
| `generate-approval-sidecar.py` / `.sh` / `.ps1` | human/CI tool: compute hash, accept DISTINCT approver ids, HMAC-sign, write STAGED candidate + manifest only (never live path, revised) | Python + sh/ps1 wrappers | new | **YES** (REQ-007) |
| `validate-approval-sidecar.py` / `.sh` / `.ps1` | content-schema (incl. duplicate-id) + hash match + HMAC verify + approver-identity + approver-distinctness + `effective_at` gate | Python + sh/ps1 wrappers | new | **YES** (REQ-007) |
| `detect-policy-weakening.py` / `.sh` / `.ps1` | 9-category (3 implemented + 6 N/A) before/after diff classification against an internally-resolved, protected approved-context anchor snapshot (never git HEAD, never caller-supplied) + two-person/cooldown verdict | Python + sh/ps1 wrappers | new | **YES** (REQ-007) |
| `check-hook-activation-handshake.py` / `.sh` / `.ps1` | host-side canary challenge/response verifier (never itself performs a write); `HOOK_ACTIVE` / `CAPABILITY_RUNTIME_UNAVAILABLE` per runtime | Python + sh/ps1 wrappers | new | **YES** (REQ-007) |
| `apply-human-copy.sh` / `.ps1` | anchored-publisher-equivalent human-copy applier (held handle, handle-relative traversal, temp-rehash, atomic rename, no path-copy fallback) | POSIX sh / PowerShell | new | **YES** (REQ-007) |
| `sdd/project-context.yaml`, `provider-bindings.yaml` | target-project content instances (not created by A1) | YAML | n/a (consumer-owned) | no |
| `sdd/project-context.approval.json`, `provider-bindings.approval.json` | approval sidecars — LIVE path, published only by `apply-human-copy` after REQ-005 re-validation | JSON | new (schema only; instances are consumer-owned) | **YES** (REQ-007/008) |
| `sdd/approver-registry.yaml` | registered approver identities (`id` = immutable identity key) | YAML | new | **YES** (REQ-007) |
| `sdd/.hook-canary-sentinel` | dedicated canary target for REQ-010's handshake — absent-after when the hook fires; transiently created then cleaned up when it does not (revised, B5) | (empty/placeholder) | new | **YES** (REQ-007) |
| `sdd/.approved-context/project-context.approved.yaml`, `provider-bindings.approved.yaml` | REQ-006's weakening-detector trust anchor — byte-exact snapshot of the content last hashed into the live sidecar's `context_sha256`; published only by `apply-human-copy` in lockstep with that sidecar (closes B3) | YAML | new | **YES** (REQ-007) |
| `plugins/sdd-quality-loop/scripts/resolve-project-context.{py,sh,ps1}` | RESERVED path for a future Capability Resolver (Epic A2/A5) — not built by A1 | n/a | reserved, not built | **YES (reserved)** (REQ-007) |
| `plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json` | RESERVED path for a future generated projection (Epic A2/A5) — not built by A1 | n/a | reserved, not built | **YES (reserved)** (REQ-007) |
| `specs/epic-189-a1-project-context/human-copy/PROTECTED-MANIFEST.md` | single canonical protected-path manifest this REQ-007 batch and its count are derived from | Markdown | new | no |
| `plugins/sdd-quality-loop/references/guard-invariants.json` | protected-file inventory | JSON | existing, edited via `apply-human-copy` (REQ-007) | **YES** |
| `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` | generator + exact-match validator, new `EPIC_A1_TARGETS` constant | Python | existing, edited via `apply-human-copy` (REQ-007) | **YES** |
| `plugins/sdd-quality-loop/scripts/generated/guard_invariants.{py,js,ps1,sh}` | generated provenance modules | Python/JS/PS1/sh | existing, regenerated via `apply-human-copy` (REQ-007) | **YES** |
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.{py,sh,ps1,js}` | `_is_protected_gate_file` deny path (read-only reference; no decision-logic edit) | Python/sh/PS1/JS | existing, UNCHANGED (REQ-008) | **YES** |
| `PLUGIN-CONTRACTS.md` | Track Detection section revision (Project-Context-present rule + `PROJECT_CONTEXT_INVALID` semantics) | Markdown | existing, edited (REQ-009) | no |
| `plugins/sdd-ship/skills/ship/SKILL.md` | Step 2 Track Detection revision + handshake wiring | Markdown (skill) | existing, human-applied via `apply-human-copy` (REQ-009) | **YES** |
| `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` | track-selection revision + handshake wiring | Markdown (skill) | existing, edited (REQ-009) | no |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md` | `spec_profile` gating revision (3 read sites) + handshake wiring | Markdown (skill) | existing, edited (REQ-009) | no |
| `plugins/sdd-lite/skills/lite-spec/SKILL.md` | track-selection revision + handshake wiring | Markdown (skill) | existing, human-applied via `apply-human-copy` (REQ-009) | **YES** |
| `plugins/sdd-lite/skills/lite-gate/SKILL.md` | track-selection revision + handshake wiring — CONFIRMED in scope (revised, was conditional) | Markdown (skill) | existing, edited (REQ-009) | no (verified) |
| `.github/workflows/test.yml` | new-suite CI registration | YAML | existing, human-applied via `apply-human-copy` (REQ-011) | **YES** |
| `tests/run-all.sh` / `.ps1` | new-suite registration | Bash / PowerShell | existing, edited (REQ-011) | no |

## Protected-File Statement

Verified directly against
`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4` (the
module `sdd-hook-guard.py:891`'s `_load_guard_invariants()` loads) at
design time. **This epic's tasks touch nine already-protected files**:
`plugins/sdd-quality-loop/references/guard-invariants.json`,
`plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`, the four
`generated/guard_invariants.{py,js,ps1,sh}` files,
`plugins/sdd-ship/skills/ship/SKILL.md`,
`plugins/sdd-lite/skills/lite-spec/SKILL.md`, and
`.github/workflows/test.yml` — none is ever opened for write directly by an
agent; each is staged under
`specs/epic-189-a1-project-context/human-copy/<repository-relative-path>`
with a `MANIFEST.sha256` entry, for a human to apply via `apply-human-copy`
(REQ-007, generalizing the epic-159-pillar-c per-spec staging precedent to
an anchored-publisher-equivalent guarantee, closing finding B6 — never a
bare `cp`, and never `apply-protected-files.ps1`, which is pinned to its
own frozen bootstrap inventory and out of this epic's edit scope, INV-011).

**Single canonical manifest (revised — closes the "five/sixteen/nineteen,
independently wrong" arithmetic gap, M15)**:
`specs/epic-189-a1-project-context/human-copy/PROTECTED-MANIFEST.md` is the
ONE authoritative enumeration every count elsewhere in this package is
DERIVED from. It lists, grouped by ADR-0019 item 3's six canonical
protection categories:

| Category | Entries | Count | Status |
|---|---|---|---|
| Canonicalizer | `canonicalize-sdd-yaml.{py,sh,ps1,js}` | 4 | built by A1 |
| Hash generator | `generate-approval-sidecar.{py,sh,ps1}` | 3 | built by A1 |
| Approval validator | `validate-approval-sidecar.{py,sh,ps1}` | 3 | built by A1 |
| Policy-weakening detector | `detect-policy-weakening.{py,sh,ps1}` | 3 | built by A1 |
| Hook-activation handshake (grouped with validator family) | `check-hook-activation-handshake.{py,sh,ps1}` | 3 | built by A1 |
| Sidecar/registry/sentinel/approved-context-anchor data (revised, closes B3) | `sdd/project-context.approval.json`, `sdd/provider-bindings.approval.json`, `sdd/approver-registry.yaml`, `sdd/.hook-canary-sentinel`, `sdd/.approved-context/project-context.approved.yaml`, `sdd/.approved-context/provider-bindings.approved.yaml` | 6 | built by A1 |
| Resolver (ADR-0019 item 3) | `plugins/sdd-quality-loop/scripts/resolve-project-context.{py,sh,ps1}` | 3 | **RESERVED, not built** — forced handoff to A2/A5 |
| Generated projection (ADR-0019 item 3) | `plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json` | 1 | **RESERVED, not built** — forced handoff to A2/A5 |

**Total: 22 concrete + 4 reserved = 26 entries** — this number is read FROM
the table above by every other section of this package that needs it
(AC-021, AC-038); no other section restates a competing literal. These 22
concrete entries are NOT protected at
authoring time (they do not exist yet, except the reserved 4, which never
exist in A1); they become protected only once
REQ-007's human-copy-applied `guard-invariants.json`/
`generate-guard-invariants.py` update lands. The implementation sequencing
this implies (recorded here for the Phase 2 task decomposition that will
consume it): author the concrete scripts UNPROTECTED first
(agent-editable, fully testable), THEN stage the guard-invariants
registration (covering the 22 concrete paths AND the 4 reserved
placeholders in the SAME batch) that protects them going forward — never
the reverse, since staging protection for a file that does not exist yet
would fail
`generate-guard-invariants.py`'s own path-existence-agnostic but
content-exact-match validation trivially (the path string is accepted
regardless of whether the file exists on disk; `_validate_repo_path`,
`generate-guard-invariants.py:121-127`, checks path SHAPE only) but would
leave no reviewable, tested script for a human to actually apply for the
22 concrete entries (the 4 reserved entries have no script to review by
design — they are a pure path reservation, not a pending review item).

**Exact-match constraint (INV-006, critical for this REQ)**:
`generate-guard-invariants.py:145-147`'s `load_and_validate` requires the
live `protected_gate_suffixes` array to equal
`BASELINE_SUFFIXES + (PHASE2_TARGETS-not-in-BASELINE)`, a tuple HARDCODED in
the generator's own Python source (lines 37-88) — not merely schema-checked.
Editing `guard-invariants.json`'s array without a matching edit to
`generate-guard-invariants.py`'s own constants makes `--check` fail (CI step
`.github/workflows/test.yml:27-35`), for every subsequent unrelated change
in this repository, not just this epic's own. This design therefore
introduces a THIRD constant tuple in the generator,
`EPIC_A1_TARGETS` (26 entries — GENERATED from
`PROTECTED-MANIFEST.md` above, never hand-duplicated independently of it; a
task-level test asserts the generator's own `EPIC_A1_TARGETS` Python tuple
and the manifest's table are kept in sync), added to `expected_protected`'s
computation
alongside `BASELINE_SUFFIXES`/`PHASE2_TARGETS`, and a matching
`epic_a1_targets` array added to `guard-invariants.json`'s own JSON (a new
top-level key; `REQUIRED_TOP_LEVEL`, `generate-guard-invariants.py:16-23`,
is extended to include it) — validated the same way
`phase2_human_copy_targets` already is (exact-tuple match, ordered,
no duplicates). `PHASE2_TARGETS` itself is left untouched (it is a frozen,
historical, epic-136-scoped constant; this epic does not conflate its own
additions with that one). REQ-007's task stages ALL SIX touched files
(`guard-invariants.json`, `generate-guard-invariants.py`, the four generated
outputs) together in one human-copy batch, with a staged-tree
`generate-guard-invariants.py --check` proof recorded before any live
application (AC-021), applied via the same `apply-human-copy` publisher
(above) as every other staged artifact this epic produces (REQ-004's
sidecar-signature publication included, REQ-004 revised — B7).

## ADR Change Log

No new ADR. Every design decision this epic makes is already recorded in
`docs/adr/0016-workflow-axes-separation.md`, `0018-provider-binding-separation.md`,
`0019-approval-sidecar-protection.md`, `0020-conditional-predicate-dsl.md`,
and `0023-track-selection-contract-migration.md` — this design implements
those five ADRs' decisions, it does not make a new one requiring its own
ADR. The one genuinely new artifact this design introduces without a
direct ADR citation — `sdd/approver-registry.yaml` (REQ-006/OQ-001) — is a
necessary supporting file for ADR-0019 item 6's already-Accepted
"approver registry" concept, not an independent architectural decision; if
impl-review disagrees, promoting it to its own ADR is a low-cost follow-up
(Design Decisions, below, records this as a resolved-but-revisitable
choice, not a gap).

## Data Plan

Data Entities:

- `sdd/project-context.yaml` (REQ-001; consumer-owned instance, not created
  by A1): `schema` (const `sdd-project-context/v1`), `workflow`
  (`spec_profile`, `artifact_layout`, `capability_enforcement`),
  `components[]` (`id`, `artifact_kinds[]`, `runtime_classes[]`,
  `platform_targets[]` (`{os, architecture}`), `characteristics`
  (`pii`, `ui`, `auto_update`, `local_persistence`, `long_running`,
  `replayable`, `human_in_the_loop` — all boolean), `distribution_channels[]`
  (string), `data_classification[]` (string), `provider_binding_ids[]`
  (string), `paths` (`include[]`, `exclude[]`, glob strings)),
  `shared_paths[]` (`pattern` + either `components[]` or
  `classification: cross-cutting`).
- `contracts/project-context.template.yaml` (REQ-001, new, unprotected,
  cross-epic addition): a schema-conformant generic scaffold with
  `shared_paths` PRE-POPULATED with three cross-cutting entries
  (`{pattern: "specs/**", classification: cross-cutting}`,
  `{pattern: "reports/**", classification: cross-cutting}`,
  `{pattern: "docs/**", classification: cross-cutting}`) — decision doc
  §12's own cross-cutting seed list, closing the day-one unowned-path FAIL
  gap for a project adopting Epic A3's Reverse Coverage Gate; not a live
  instance for sdd-forge itself (Non-goals).
- `sdd/provider-bindings.yaml` (REQ-002): `schema` (const
  `sdd-provider-bindings/v1`), `bindings[]` (`id`, `provider`, `product`,
  `purpose` — all required string; `state_authority`, `credentials` —
  optional, unconstrained object passthrough; `adapter_paths[]` — OPTIONAL
  array of glob string, NEW, cross-epic addition consumed by Epic A3's
  Fail-6 check, REQ-002).
- `sdd/project-context.approval.json` / `provider-bindings.approval.json`
  (REQ-004): `schema` (const, one of the two approval schema ids),
  `context_sha256` (`sha256:<64-hex>`), `primary_approval`
  (`status: "Approved"`, `approver` — an approver-registry `id`, NOT a
  display name, `approved_at`), `second_approval`
  (`null` or same shape — its `approver`, when present, MUST differ from
  `primary_approval.approver`), `effective_at` (`null` or ISO 8601),
  `hmac` (64 lowercase hex chars). LIVE instances of these two paths are
  written ONLY by `apply-human-copy` (REQ-007), never directly by
  `generate-approval-sidecar` (REQ-004, revised — B7).
- `sdd/.staging/<schema-id>/<nonce>/` (REQ-004, new, UNPROTECTED staging
  area): the signer's own output — a candidate sidecar JSON (same shape as
  above) plus `MANIFEST.sha256` (candidate hash + nonce) — never itself
  trusted as a live approval record; REQ-005's validator re-checks the
  STAGED candidate before `apply-human-copy` publishes it.
- `sdd/approver-registry.yaml` (REQ-006/OQ-001, new): `schema` (const
  `sdd-approver-registry/v1`), `approvers[]` (`id` unique string — the
  IMMUTABLE identity key every `approval.approver` field references,
  `name`
  string — a mutable display label, NEVER used for identity comparison,
  `registered_at` ISO 8601) — the count of DISTINCT `id` entries is
  what REQ-006's detector compares against the two-person threshold.
- `sdd/.hook-canary-sentinel` (REQ-007/REQ-010, revised — resolves the
  absent-after-on-every-outcome contradiction, B5): no defined content
  shape — a path-existence-agnostic protection target only (matches
  `_is_protected_gate_file`'s suffix-only semantics, INV-006). When the
  hook fires (deny), the write never executes and the sentinel is never
  created. When the hook does NOT fire, the write DOES execute — this is
  the direct, expected proof of hook-inactivity — and the handshake
  requires one immediate follow-up cleanup tool-call (delete) before
  completing, so no lasting content ever remains at this path across a
  full handshake invocation, in either branch.
- `sdd/.approved-context/project-context.approved.yaml`,
  `provider-bindings.approved.yaml` (REQ-006/REQ-007, new, closes B3): a
  byte-exact snapshot of the content REQ-004's signer last hashed into the
  corresponding LIVE sidecar's `context_sha256` — REQ-006's weakening
  detector's default trust anchor. Written ONLY by `apply-human-copy`, in
  the SAME atomic operation that publishes the sidecar it accompanies;
  never shares a basename with the live, freely-editable
  `project-context.yaml`/`provider-bindings.yaml` content files (which
  would otherwise also become protected under `_is_protected_gate_file`'s
  suffix-match semantics, breaking B1).
- `specs/epic-189-a1-project-context/human-copy/PROTECTED-MANIFEST.md`
  (REQ-007, new): the single canonical protected-path manifest,
  Protected-File Statement above.
- `specs/epic-189-a1-project-context/human-copy/` (new, committed as a
  review artifact for a future implementation session, not deleted by any
  test): staged corrected copies of the nine already-protected files this
  epic's tasks touch, plus `MANIFEST.sha256`, published via
  `apply-human-copy` (REQ-007).

**Field Requirement Matrix (NEW — closes M19's "parameterized negative
test needs a canonical required/optional list to iterate")**: every
REQUIRED JSON Pointer REQ-001/REQ-002 define, used directly by AC-001/
AC-003's parameterized negative tests (one fixture per pointer, deleting
exactly that one):
- REQ-001 (`project-context.yaml`): `/schema`, `/workflow`,
  `/workflow/spec_profile`, `/workflow/artifact_layout`,
  `/workflow/capability_enforcement`, and, for each `components[]` entry,
  `/components/*/id`; for each `platform_targets[]` entry,
  `/components/*/platform_targets/*/os`,
  `/components/*/platform_targets/*/architecture`. Every other REQ-001
  field (`artifact_kinds`, `runtime_classes`, `characteristics.*`,
  `distribution_channels`, `data_classification`, `provider_binding_ids`,
  `paths.*`, `shared_paths`) is OPTIONAL at the schema level (may be
  entirely absent from a conforming document).
- REQ-002 (`provider-bindings.yaml`): `/schema`, `/bindings`, and, for each
  `bindings[]` entry, `/bindings/*/id`, `/bindings/*/provider`,
  `/bindings/*/product`, `/bindings/*/purpose`. `state_authority`,
  `credentials`, and `adapter_paths` are OPTIONAL.

Existing Data Affected: `plugins/sdd-quality-loop/references/guard-invariants.json`,
`generate-guard-invariants.py`, and the four `generated/guard_invariants.*`
files are READ (for re-verification, Assumptions below) throughout
implementation and WRITTEN only via `apply-human-copy` (REQ-007), exactly
once, by REQ-007's task. `PLUGIN-CONTRACTS.md` is edited directly
(unprotected). No existing production `sdd/*.yaml` instance exists anywhere in this
repository today (verified: `find . -path ./node_modules -prune -o -path
'*/sdd/project-context.yaml' -print` returns no match) — this design
creates no such instance either (Non-goals; Epic A9 scope).

Migration Strategy: none. Every artifact this epic defines is wholly new;
no existing schema, script, or content file is migrated in place.

## API / Contract Plan

### `contracts/project-context.schema.json` (REQ-001)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "SDD Forge project-context",
  "type": "object",
  "additionalProperties": false,
  "required": ["schema", "workflow"],
  "properties": {
    "schema": { "const": "sdd-project-context/v1" },
    "workflow": {
      "type": "object",
      "additionalProperties": false,
      "required": ["spec_profile", "artifact_layout", "capability_enforcement"],
      "properties": {
        "spec_profile": { "enum": ["full", "lite"] },
        "artifact_layout": {
          "enum": ["lite-three-file", "legacy-seven-layer", "facet-hybrid", "facet-native"]
        },
        "capability_enforcement": { "enum": ["advisory", "required"] }
      }
    },
    "components": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["id"],
        "properties": {
          "id": { "type": "string", "minLength": 1 },
          "artifact_kinds": { "type": "array", "items": { "type": "string" } },
          "runtime_classes": { "type": "array", "items": { "type": "string" } },
          "platform_targets": {
            "type": "array",
            "items": {
              "type": "object",
              "additionalProperties": false,
              "required": ["os", "architecture"],
              "properties": { "os": { "type": "string" }, "architecture": { "type": "string" } }
            }
          },
          "characteristics": {
            "type": "object",
            "additionalProperties": false,
            "properties": {
              "pii": { "type": "boolean" },
              "ui": { "type": "boolean" },
              "auto_update": { "type": "boolean" },
              "local_persistence": { "type": "boolean" },
              "long_running": { "type": "boolean" },
              "replayable": { "type": "boolean" },
              "human_in_the_loop": { "type": "boolean" }
            }
          },
          "distribution_channels": { "type": "array", "items": { "type": "string" } },
          "data_classification": { "type": "array", "items": { "type": "string" } },
          "provider_binding_ids": { "type": "array", "items": { "type": "string" } },
          "paths": {
            "type": "object",
            "additionalProperties": false,
            "properties": {
              "include": { "type": "array", "items": { "type": "string" } },
              "exclude": { "type": "array", "items": { "type": "string" } }
            }
          }
        }
      }
    },
    "shared_paths": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["pattern"],
        "oneOf": [
          { "required": ["components"], "properties": { "components": { "type": "array", "items": { "type": "string" } } } },
          { "required": ["classification"], "properties": { "classification": { "const": "cross-cutting" } } }
        ]
      }
    }
  }
}
```

**Duplicate-`id` semantic validator (M18 — not expressible in the JSON
Schema above)**: `components[].id` uniqueness is enforced by REQ-005's
content-schema validation step, NOT by this JSON Schema document (draft-07
has no array-items'-key-uniqueness predicate against a plain
array-of-objects shape). A `components` array with two entries sharing the
same `id` string (case-sensitive, exact match) validates successfully
against the schema ABOVE but is rejected by `validate-approval-sidecar.py`/
`generate-approval-sidecar.py`'s shared content-schema step with
`DUPLICATE_COMPONENT_ID` (see `contracts/provider-bindings.schema.json`,
below, for the identical `DUPLICATE_BINDING_ID` case).

### `contracts/provider-bindings.schema.json` (REQ-002)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "SDD Forge provider-bindings (skeleton)",
  "type": "object",
  "additionalProperties": false,
  "required": ["schema", "bindings"],
  "properties": {
    "schema": { "const": "sdd-provider-bindings/v1" },
    "bindings": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["id", "provider", "product", "purpose"],
        "properties": {
          "id": { "type": "string", "minLength": 1 },
          "provider": { "type": "string", "minLength": 1 },
          "product": { "type": "string", "minLength": 1 },
          "purpose": { "type": "string", "minLength": 1 },
          "state_authority": { "type": "object" },
          "credentials": { "type": "object" },
          "adapter_paths": { "type": "array", "items": { "type": "string" } }
        }
      }
    }
  }
}
```

`adapter_paths` (NEW, cross-epic addition, REQ-002) is OPTIONAL and
schema-typed as a bare array of string (no glob-syntax validation beyond
"array of string" — this schema does not itself interpret the glob syntax;
Epic A3's Reverse Coverage Gate does). `bindings[].id` uniqueness, like
`components[].id` above, is enforced by REQ-005's content-schema
validation step (`DUPLICATE_BINDING_ID`), not by this JSON Schema.

### `contracts/approval-sidecar.schema.json` (REQ-004)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "SDD Forge approval sidecar",
  "type": "object",
  "additionalProperties": false,
  "required": ["schema", "context_sha256", "primary_approval", "second_approval", "effective_at", "hmac"],
  "properties": {
    "schema": { "enum": ["sdd-project-context-approval/v1", "sdd-provider-bindings-approval/v1"] },
    "context_sha256": { "type": "string", "pattern": "^sha256:[0-9a-f]{64}$" },
    "primary_approval": { "$ref": "#/definitions/approval" },
    "second_approval": { "oneOf": [{ "type": "null" }, { "$ref": "#/definitions/approval" }] },
    "effective_at": { "oneOf": [{ "type": "null" }, { "type": "string", "format": "date-time" }] },
    "hmac": { "type": "string", "pattern": "^[0-9a-f]{64}$" }
  },
  "definitions": {
    "approval": {
      "type": "object",
      "additionalProperties": false,
      "required": ["status", "approver", "approved_at"],
      "properties": {
        "status": { "const": "Approved" },
        "approver": { "type": "string", "minLength": 1 },
        "approved_at": { "type": "string", "format": "date-time" }
      }
    }
  }
}
```

**`approver` semantics (revised, closes B2)**: `approver` is schema-typed
as a non-empty string (unchanged) but is SEMANTICALLY constrained (checked
by REQ-005's validator, not by this JSON Schema, which cannot cross-
reference `sdd/approver-registry.yaml`) to be an approver-registry `id` —
never a free-text display name. When both `primary_approval` and
`second_approval` are present, `second_approval.approver` MUST differ from
`primary_approval.approver` (`DUPLICATE_APPROVER_IDENTITY` otherwise,
checked at both generation and validation time).

### Canonicalization procedure (REQ-003, revised — closes M10/M11)

1. Read file bytes; decode as UTF-8 (reject on decode error).
2. Parse as YAML restricted to the 1.2 **core schema** resolver (no 1.1
   `on`/`off`/`yes`/`no` → boolean coercion), **single-document only**
   (reject a multi-document `---`-separated stream,
   `MULTI_DOCUMENT_REJECTED`). Reject (non-zero exit, named
   diagnostic) if the document contains an anchor, an alias, any tag other
   than the core-schema implicit tags, a mapping with a duplicate key at
   any nesting level (`DUPLICATE_KEY_REJECTED`), or a **non-string mapping
   key** (`NON_STRING_KEY_REJECTED` — YAML 1.2 core schema permits
   integer/boolean scalar keys, which RFC 8785 JCS cannot represent).
3. Walk the parsed structure; normalize every string scalar to Unicode NFC
   (`unicodedata.normalize("NFC", s)`), THEN re-check every mapping's keys
   for a **post-NFC duplicate-key collision** (two distinct source keys
   that normalize to the same NFC string) — reject
   (`POST_NFC_DUPLICATE_KEY_REJECTED`) rather than silently keeping
   whichever the parser encountered last.
4. Reject any numeric scalar that is non-finite (`.inf`/`-.inf`/`.nan`) or
   outside the IEEE-754 double-precision representable range
   (`NUMBER_OUT_OF_RANGE_REJECTED`) — RFC 8785 JCS numeric formatting is
   defined only for finite, double-representable values.
5. Serialize to canonical JSON strictly per RFC 8785 (JCS): object keys sorted by
   UTF-16 code unit; numbers formatted per JCS §3.2.2.3's ECMAScript-
   `Number`-based rule (the shortest round-tripping decimal representation
   a double can produce — including an exponent where JCS's own rule
   produces one; NOT a bespoke "integers never carry an exponent" rule, a
   prior draft's own invented restriction, retired); strings escaped per
   JCS's minimal-escaping rule;
   no insignificant whitespace.
6. Emit: the canonical UTF-8 byte sequence (stdout, byte-exact — no
   diagnostic text interleaved on stdout, no extraneous trailing bytes
   beyond what the canonicalization itself produces), or
   `sha256:<hex>\n` (`--hash-only` mode). Every rejection category exits
   non-zero with a STABLE, documented, category-specific exit code and
   writes nothing to stdout; the diagnostic itself goes to stderr only.

`canonicalize-sdd-yaml.sh` / `.ps1` / `.js` each locate `python3`, else
`python`, on `PATH` and exec
`canonicalize-sdd-yaml.py "$@"` with stdin/stdout passed through unchanged;
if neither binary is found, ALL THREE wrappers deny fail-closed with the
SAME documented exit code (`CANONICALIZER_RUNTIME_UNAVAILABLE`, exit 3) —
**no wrapper, including `.ps1`, falls back to a native PowerShell
reimplementation** (M10, revised): unlike `sdd-hook-guard.sh:36-50`, which
falls back to a SEPARATE, fully native `.ps1` decision-logic
implementation when `python3` is unavailable (INV-005), the canonicalizer
has exactly one behavioral implementation (decision doc §18.3), so there
is no native `.ps1` logic to fall back TO; none re-parses YAML
independently.

### HMAC preimage and signing (REQ-004, revised — closes B2/B7/M9)

Preimage = `canonicalize-sdd-yaml` applied to the approval JSON object with
the `hmac` key removed (JSON, not YAML, input mode — REQ-003's canonicalizer
accepts either), covering EVERY other field (`schema`, `context_sha256`,
both approval sub-objects' every field, `effective_at`) — a golden known-
answer vector (a fixed, committed fixture with every field populated) plus
twelve one-field-at-a-time mutation fixtures (AC-036/TEST-036) prove this
directly, closing the gap where an internal generator/validator round-trip
test alone could not distinguish "the preimage is correct" from "the
generator and validator both independently made the same mistake."
`hmac = HMAC-SHA256(key, preimage_bytes).hex()`, key
resolved via: env `SDD_CONTEXT_KEY` → env `SDD_CONTEXT_KEY_FILE` (BOM/
whitespace-stripped) → `<HOME>/.sdd/context-key` (same stripping) → none
(fail-closed — `generate-approval-sidecar` refuses to write an unsigned
sidecar, staged or live). `validate-approval-sidecar` recomputes the identical preimage and
compares with `hmac.compare_digest` (constant-time), matching
`sdd-hook-guard.py:478-481`'s pattern exactly. **Before computing the
preimage**, `generate-approval-sidecar` checks
`primary_approval.approver != second_approval.approver` (when
`second_approval` is present) and refuses to sign
(`DUPLICATE_APPROVER_IDENTITY`) on a match — this check happens BEFORE any
hashing work, since a same-identity two-person claim is invalid
regardless of what it would hash to. **Output (revised — no live-path
write, B7; adds the approved-context anchor snapshot, closes B3)**:
`generate-approval-sidecar` writes the signed sidecar candidate, a
byte-exact **approved-context content snapshot** (the live content file's
bytes exactly as they were when hashed into `context_sha256` — never
re-read from the live path later, which could have drifted by publish
time), PLUS
a `MANIFEST.sha256` entry (both files' hashes + a fresh, single-use `nonce`) to
`sdd/.staging/<schema-id>/<nonce>/` ONLY — it never opens
`sdd/project-context.approval.json`/`sdd/provider-bindings.approval.json`
NOR `sdd/.approved-context/*.approved.yaml`
for writing. `apply-human-copy` (REQ-007) publishes both staged candidates to
their live paths, atomically and in lockstep, ONLY after `validate-approval-sidecar` independently PASSES
the staged sidecar against the staged snapshot (hash, HMAC, approver identity/distinctness, `effective_at`) — a
signed-but-invalid staged candidate is never published, and the live
approved-context anchor is updated ONLY when its accompanying sidecar is.

### Policy-weakening categories (REQ-006, revised — closes M12/M13,
renormalized to the canonical nine, no invented proxy classifications)

| # | Category (decision doc §9) | Detected as | Foundation status |
|---|---|---|---|
| 1 | `capability_enforcement` weakened | `required` → `advisory`, direct field comparison | **implemented** |
| 2 | Capability removed from a component | — | **documented N/A, fail-closed, forced handoff to A2/A5** (no canonical Capability reference field exists in A1's schema; the `artifact_kinds`/`runtime_classes` shrink-as-proxy a prior draft used is REMOVED — those fields are free-text classification, not a Capability reference, and treating their shrinkage as equivalent to Capability removal was an invented policy with no textual basis in decision doc §9) |
| 3 | Component path narrowed | glob-coverage-narrowing algorithm, below (covers `paths.include` removal/replacement AND `paths.exclude` growth) | **implemented** |
| 4 | Public distribution de-scoped | — | **documented N/A, fail-closed, forced handoff** (no Foundation-fixed public/private channel vocabulary exists for `distribution_channels`; "any entry removed" was an invented proxy with no vocabulary basis, REMOVED) |
| 5 | Criticality lowered | — | documented N/A (no such field exists in Foundation schema) |
| 6 | Provider allowlist widened | — | documented N/A (no allowlist field in REQ-002's skeleton) |
| 7 | Production write-path changed | — | documented N/A (no such field exists) |
| 8 | Required Gate removed | — | documented N/A (Gate declarations are Epic A2 scope) |
| 9 | `spec_profile` moved `full`→`lite` | direct field comparison | **implemented** |

Exactly **3 of 9** categories are implemented against A1's schema; the
other **6** are N/A in every run, reported explicitly in the detector's
diagnostic output (never silently omitted) — this 3+6=9 split is the ONLY
correct arithmetic for this table; any other split (a prior draft's
"6 implemented" or "9 named / 6 expressed / 3 remaining / 4 N/A") is
retired.

**Glob-coverage narrowing algorithm (NEW, closes M13's "set-inclusion
including replacement and same-count changes" requirement)**: for a
component's `paths.include`/`paths.exclude`, compute each pattern's
**scope prefix** — the substring before its first glob metacharacter
(`*`, `?`, `[`), normalized to use `/` and a trailing separator (a literal
path with no metacharacter is its own scope prefix). Let `B_inc`/`B_exc`
be the baseline's include/exclude scope-prefix sets and `C_inc`/`C_exc`
the candidate's. The change **narrows** (weakens) coverage if EITHER:
- (include narrows) some `p ∈ B_inc` has NO `q ∈ C_inc` such that `q` is a
  prefix of (or equal to) `p` — i.e., candidate no longer includes
  anything at or under a path baseline used to include. This correctly
  flags: outright removal of an include pattern (fewer patterns); AND
  REPLACEMENT of a broad pattern with a more specific one at an UNCHANGED
  pattern count (e.g. `src/**` → `src/desktop/**` — same count, but
  `src/desktop/` is not a prefix of `src/`, so `src/`'s coverage is lost).
- (exclude widens) some `q ∈ C_exc` has NO `p ∈ B_exc` such that `p` is a
  prefix of (or equal to) `q` — candidate excludes something (or a broader
  region) baseline did not, carving additional area out of the component's
  effective ownership.

The change does NOT narrow (and may be a pure strengthening/lateral
change, `policy_weakening: false` for this category) when include
coverage only stays equal or grows AND exclude coverage only stays equal
or shrinks — e.g. an include pattern ADDED that strictly broadens coverage
with no other change. The algorithm is deliberately **syntactic-prefix-
based, not glob-execution-equivalent** — a semantically-equivalent but
syntactically-different rewrite (e.g. an equivalent-coverage pattern
spelled differently) is treated conservatively (fail-closed toward
"review this," never fail-open toward "silently permit a possible
narrowing"). Boundary cases (pattern removed; pattern replaced at
unchanged count; exclude added; exclude replaced broader; pure broadening
correctly classified non-weakening) are AC-031/TEST-031.

A verdict of `policy_weakening: true` on ANY one of the three implemented
categories is sufficient
(Edge Cases, requirements.md); N/A categories are explicitly reported as
such in the detector's diagnostic output, never silently omitted.

### Weakening-detector approved-context anchor CLI contract (REQ-006,
revised — the trust anchor is the currently-APPROVED Project Context, not
git HEAD; closes B3)

```
detect-policy-weakening.py --candidate <path> [--approved-context <path>]
```

- `--candidate` (required): the working-tree/staged file under evaluation.
- Default (no `--approved-context`): the anchor is resolved INTERNALLY by
  reading the protected snapshot
  `sdd/.approved-context/<schema-basename>.approved.yaml` (e.g.
  `sdd/.approved-context/project-context.approved.yaml`) — the byte-exact
  content `generate-approval-sidecar` (REQ-004) last hashed into the
  CURRENTLY-LIVE, valid sidecar's `context_sha256`, published by
  `apply-human-copy` in lockstep with that sidecar (REQ-007). **This is the
  ONLY mode `generate-approval-sidecar` and `validate-approval-sidecar` are
  permitted to invoke** — neither tool ever passes `--approved-context`,
  which is what makes "pass the candidate as its own anchor" structurally
  unavailable on the production call path. **Why an ordinary commit cannot
  move the anchor**: the snapshot file is itself full-write-deny protected,
  exactly like the sidecar it accompanies (REQ-007/REQ-008) — it changes
  ONLY via a complete, human/HMAC-signed `apply-human-copy` publish, never
  via a commit to the live content file. An attacker who commits a
  weakening change to `project-context.yaml` directly (any number of
  times, on any branch, merged or not) never touches
  `sdd/.approved-context/*`; the next `detect-policy-weakening` invocation
  (production call path, no override) still diffs the candidate against
  the untouched, previously-approved anchor and correctly reports the
  weakening — this retires the prior git-HEAD design's vulnerability,
  where landing the weakening as a normal commit silently redefined
  "HEAD" to match the candidate, erasing the diff.
- `--approved-context <path>` (explicit override to an arbitrary local
  file): exists ONLY for this script's own fixture tests (REQ-011); never
  used by REQ-004/REQ-005.
- No anchor snapshot exists yet (no sidecar for this schema has ever been
  successfully published — first-time bootstrap): the anchor is treated as
  absent, and the detector reports `policy_weakening: false` for every
  category (`NO_APPROVED_CONTEXT_ANCHOR`) — every capability, path, and
  enforcement setting in the candidate is a NEW addition, not a weakening
  of anything previously approved; documented, never a silent default.
- Deletion (candidate missing or empty): out of scope, tool exits non-zero
  (`CANDIDATE_NOT_SCHEMA_VALID`) rather than emitting any verdict.
- This design RETIRES the prior git-HEAD-based resolution entirely (no
  `--baseline`/`--baseline-repo-path` flags, no `git show`/`git cat-file`
  dependency, no shallow-clone/mid-rebase failure mode) — the anchor is a
  plain protected file read, not a git operation.

## Test Strategy

1. Dual/multi-runtime hash-equality (REQ-003, AC-009): the SAME fixture file
   canonicalized by `.py` directly, by `.sh` (dispatch to `.py`), by `.ps1`
   (dispatch to `.py`, NEVER a native-PowerShell fallback, M10), and by
   `.js` (where Node is
   available) must all produce an identical SHA-256 — proven as a
   dispatch-verification test (assert the wrapper's underlying call target),
   not merely a hash-equality coincidence.
2. Anchor/alias/tag/duplicate-key rejection (REQ-003, AC-005): one fixture
   per category, each independently asserted to exit non-zero with a
   category-specific diagnostic — a single "any invalid YAML rejected"
   fixture would not prove each category is actually detected.
2b. Accepted-domain boundary vectors (REQ-003, AC-037, NEW — closes M11):
    independent fixtures for multi-document rejection, non-string-key
    rejection, post-NFC duplicate-key-collision rejection, non-finite/
    out-of-range-number rejection, an RFC 8785 §3.2.2.3 official
    numeric-formatting boundary vector, and a byte-exact stdout-framing +
    documented-exit-code assertion for both the success and every
    rejection path.
3. NFC/JCS canonical-output determinism (REQ-003, AC-007/AC-008): a
   precomposed-vs-decomposed Unicode fixture pair asserts identical output;
   a hand-computed expected byte sequence for at least one JCS fixture is
   committed as a golden comparison target.
4. HMAC preimage self-reference exclusion (REQ-004, AC-012): an internal
   preimage-dump test hook (not a production code path) proves the `hmac`
   field's own value never affects the preimage — two sidecars differing
   ONLY in `hmac` produce the identical preimage.
4b. HMAC golden vector + per-field mutation (REQ-004, AC-036, NEW — closes
    M9): a full-field golden fixture's hand-verified HMAC, plus twelve
    one-field-mutated variants each producing a DIFFERENT HMAC — proves
    the preimage covers every field, not merely the fields an internal
    round-trip test happens to exercise.
5. Key-resolution byte-parity (REQ-004, AC-013): a 4-case fixture matrix
   (env var / env-file / home-path / none) asserts identical key-selection
   and BOM/whitespace-stripping behavior to `_resolve_sudo_key`/
   `resolve_evidence_key` — not merely "a key is found," but the SAME bytes.
5b. Same-identity two-person rejection (REQ-004/REQ-005, AC-014/AC-019,
    NEW — closes B2): a fixture with `primary_approval.approver ==
    second_approval.approver` (both individually valid registry ids, HMAC
    otherwise correctly computed) is refused at generation time and
    rejected at validation time — proving a valid HMAC over a self-
    defeating two-person claim is not treated as evidence of genuine
    two-person review.
5c. Signer staging-only contract + rollback (REQ-004, AC-034, NEW — closes
    B7): a fixture asserting the signer never opens the live sidecar path
    for writing under any invocation; a simulated mid-write failure between
    candidate and manifest writes leaves no partial artifact at the final
    staged path; a re-run after such a failure succeeds with a fresh
    nonce.
6. Six-way validator negative proof (REQ-005, AC-014, extended — was
   four-way): content-schema violation (including duplicate-`id`), hash
   mismatch, HMAC
   mismatch, unregistered approver, duplicate approver identity, premature
   `effective_at` — each its own
   independent fixture and assertion, mirroring epic-159-pillar-c's
   "positive/negative field-population pairs" convention (never one
   combined "rejects bad input" case).
7. Weakening-category coverage plus negative case (REQ-006, AC-016/AC-017,
   revised to the canonical 3-implemented/6-N/A split, M12/M13):
   one fixture per implemented category (now three, not six), one N/A-reporting proof per
   the six documented-N/A categories (now six, not three/four), and one strengthening-change fixture that MUST
   NOT be misclassified as weakening — the same red/green discipline
   epic-159-pillar-a2/b/c established for golden baselines, applied here to
   a classification function instead of a byte-identical comparison.
7b. Glob-coverage narrowing algorithm boundary cases (REQ-006, AC-031, NEW
    — closes M13's algorithm requirement): pattern removed; pattern
    replaced at an unchanged count (the same-count-change case a naive
    array-length check misses); exclude pattern added; exclude pattern
    replaced broader; a pure-broadening change correctly classified
    non-weakening — five independent fixtures against design.md's
    scope-prefix algorithm, above.
7c. Approved-context anchor CLI contract + injection-attempt rejection
    (REQ-006, AC-030, revised — closes B3): default resolution against the
    protected `sdd/.approved-context/*.approved.yaml` snapshot proven
    against a fixture (identical candidate → `false`; genuinely weakening
    candidate → `true`, asserted BOTH immediately and after the candidate
    is landed as an ordinary git commit, proving a new commit never moves
    the anchor); the production call path (no `--approved-context`) proven
    immune to self-diffing; the no-anchor-exists-yet
    (`NO_APPROVED_CONTEXT_ANCHOR`) rule independently asserted.
8. Protected-file write-boundary proof (REQ-008, AC-023, extended to the
   full matrix, M17 — an explicit 12-row surface/argv/expected-denial
   table, not a summary count): a write attempt
   against each of the FOUR protected basenames (`sdd/project-context.approval.json`,
   `sdd/provider-bindings.approval.json`, `sdd/approver-registry.yaml`,
   `sdd/.hook-canary-sentinel`), through EVERY ONE of the 12
   mutation surfaces `_is_protected_gate_file` is consulted from (not one
   representative surface per basename), INCLUDING under an
   active `SDD_SUDO` token — 4 × 12 × 2 = 96 independent assertions, the
   never-bypass proof, mirroring
   epic-159-pillar-c's TEST-019/TEST-020 write/read-boundary pairing shape
   generalized to a full matrix rather than a spot check. **The 12-row
   surface table (verified against `sdd-hook-guard.py`'s current call
   sites; a snapshot, not load-bearing on exact line numbers if the guard
   is later refactored)** — each row applies IDENTICALLY to and is
   instantiated once for EACH of the 4 protected basenames (substituting
   `<TARGET>` below) and once for EACH of the 2 `SDD_SUDO` states (never a
   bypass in either), since `_is_protected_gate_file`'s suffix-match logic
   and every one of these 12 call sites treat all four protected basenames
   identically — the surface and argv shape do not vary by basename, only
   the literal target path string does — giving the full 12 × 4 × 2 = 96
   independent assertions:

   | # | `sdd-hook-guard.py` site | Tool surface | Example argv/input shape (`<TARGET>` = one of the 4 basenames) | Expected denial |
   |---|---|---|---|---|
   | 1 | `_simple_shell_command_is_safe` (detached redirect) | Bash redirect, detached form | `echo x > <TARGET>` | denied, both `SDD_SUDO` states |
   | 2 | `_simple_shell_command_is_safe` (attached redirect) | Bash redirect, attached form (non-fd-dup) | `echo x >`+`<TARGET>` (no space) / `2>`+`<TARGET>` | denied, both `SDD_SUDO` states |
   | 3 | `_simple_shell_command_is_safe` (`cp`/`mv` dest) | Bash `cp`/`mv` destination argument | `cp src.yaml <TARGET>` | denied, both `SDD_SUDO` states |
   | 4 | `_simple_shell_command_is_safe` (`tee`/`touch`/`rm`) | Bash `tee`/`touch`/`rm` target argument | `rm <TARGET>` / `touch <TARGET>` | denied, both `SDD_SUDO` states |
   | 5 | `_cwd_write_target_is_protected` (absolute) | Bash redirect/`cp`/`mv`/`tee`/`touch`/`rm` target, absolute path, after a tracked `cd` | `cd /tmp && echo x > <TARGET-absolute>` | denied, both `SDD_SUDO` states |
   | 6 | `_cwd_write_target_is_protected` (relative) | same, relative path resolved against tracked `cd` | `cd sdd && echo x > <TARGET-basename>` | denied, both `SDD_SUDO` states |
   | 7 | `_segment_write_hits_protected` (detached redirect) | Bash detached redirect within a `cd`-aware compound segment | `cd sdd && >` then `<TARGET-basename>` | denied, both `SDD_SUDO` states |
   | 8 | `_segment_write_hits_protected` (attached redirect) | Bash attached redirect within a `cd`-aware compound segment | `cd sdd && echo x >`+`<TARGET-basename>` (no space) | denied, both `SDD_SUDO` states |
   | 9 | `_shell_cwd_write_hits_protected` via `_segment_write_hits_protected` (`cp`/`mv`) | Bash `cp`/`mv` destination within a `cd`-aware compound segment | `cd sdd && cp x.yaml <TARGET-basename>` | denied, both `SDD_SUDO` states |
   | 10 | same (`tee`/`touch`/`rm`) | Bash `tee`/`touch`/`rm` target within a `cd`-aware compound segment | `cd sdd && rm <TARGET-basename>` | denied, both `SDD_SUDO` states |
   | 11 | `main()` (`Edit`/`Write`/`MultiEdit`) | native tool call, `file_path` field | `{"tool_name":"Write","tool_input":{"file_path":"<TARGET>"}}` | denied, both `SDD_SUDO` states |
   | 12 | `main()` (`apply_patch`) | native tool call, `apply_patch` envelope | `*** Update File: <TARGET>` | denied, both `SDD_SUDO` states |

   **Documented residual gap (never silently implied as covered by this
   matrix)**: `sdd-hook-guard.py`'s shell-command analysis does not model
   `ln` (symlink/hard-link creation), an interpreter's own in-process write
   via a code string (`python -c "..."`, `node -e "..."`), or any
   PowerShell write cmdlet beyond its existing indirect-fail-closed list —
   these are NOT among the 12 rows above and are recorded as a known
   residual risk for a future hardening epic, not covered by this REQ's
   96-cell matrix.
9. Handshake fail-closed proof (REQ-010, AC-027, REDESIGNED — defense-tier
   scope, B4): `--verify-response`, given a fixture recorded-result
   matching each of
   the three runtimes' documented expected-deny-signatures AND a matching
   nonce, `HOOK_ACTIVE` for that runtime; given a fixture recorded-result
   showing the write executed, an unrecognized result, a missing
   recorded-result file, or a stale/mismatched nonce, `CAPABILITY_RUNTIME_UNAVAILABLE`
   — never the reverse. **Scope**: this is A1's own footgun-guard Done
   condition — a FIXTURE-SIMULATED proof of the
   challenge/response verify logic's correctness (no real LLM session, REQ-011's
   non-use declaration); it does not, and cannot, exercise a live host's actual
   tool-call dispatch — that live-host, cross-runtime observation is
   explicitly OUT of A1's own Done condition and is instead Epic A8's own
   MANDATORY Done condition (decision doc §9 v2's two-tier defense scope;
   REQ-010, Non-goals) — an explicit forced handoff, not a mere related
   future test.
9b. Sentinel two-branch non-mutation proof (REQ-010, AC-032, revised —
    resolves the absent-after-on-every-outcome contradiction, B5): the
    live sidecars (untouched by the redesigned handshake in every branch)
    are byte-identical before/after every handshake invocation,
    unconditionally. `sdd/.hook-canary-sentinel`'s own state depends on
    the branch: hook FIRES (deny) → absent-before AND absent-after (never
    created); hook does NOT fire (write executes,
    `CAPABILITY_RUNTIME_UNAVAILABLE`) → the sentinel IS created as the
    direct proof of hook-inactivity, and `--verify-response` requires one
    immediate follow-up cleanup tool-call attempt (delete the sentinel)
    before the calling skill's own stop — end-to-end across the FULL
    handshake invocation, the sentinel is absent-before and absent-after in
    this branch too, with only a transient, expected mid-invocation
    existence, never a lasting mutation.
9c. Full entry-point wiring inventory (REQ-010, AC-035, NEW — closes M8):
    each of REQ-009's five migrated consumers is independently asserted to
    invoke the handshake at its own entry point.
10. Human-copy anchored-publisher proof (REQ-007, AC-033, NEW — closes B6):
    `apply-human-copy` denies a pre-existing symlink/reparse point at
    either held handle; preserves hard-link-alias non-propagation; resists
    held-handle substitution between validation and publish; publishes
    only via atomic rename (never path-based copy); leaves the live target
    unchanged on any preparation-stage failure.
10b. Protected-path manifest inventory (REQ-007, AC-038, NEW — closes M14):
    all six ADR-0019-item-3 categories (including the two RESERVED
    resolver/generated-projection entries) present in the staged
    `guard-invariants.json` candidate.
10c. Duplicate-`id` semantic-validator rejection (REQ-001/REQ-002, AC-040,
    NEW — closes M18): a `components[]` or `bindings[]` array with a
    repeated `id` is rejected by the content-schema validation step.
10d. Parameterized required-field negative test (REQ-001/REQ-002, AC-001/
    AC-003, revised — closes M19): one fixture per REQUIRED JSON Pointer in
    the Field Requirement Matrix (Data Plan, above), each deleting exactly
    that one pointer.
10e. Full per-consumer common-contract-suite matrix (REQ-009, AC-039, NEW
    — closes M16): each of the five migrated consumers independently
    exercised against all six cases (four Project-Context-present cases,
    the compatibility-fallback case, and the `PROJECT_CONTEXT_INVALID`
    existing-but-invalid case) — 30 independent assertions.
11. Self-registration (REQ-011): every new `.sh` suite greps
    `tests/run-all.sh`/`.ps1` for its own basename (unprotected, checked
    directly at agent-commit time), mirroring
    `tests/second-approval-mask.tests.sh:285-289`'s established pattern;
    `.github/workflows/test.yml` registration is proven by the
    staged/live-unchanged/post-copy-registered three-part shape
    epic-159-pillar-c's AC-027 established, generalized to every task that
    touches it here.
12. No suite in this feature invokes a real LLM, `gh`, or `sdd-sudo`
    (declared non-use, matching every prior epic-159-pillar spec's
    convention); every mktemp fixture root is `pwd -P`-normalized
    immediately after creation (`tests/lib/loop-driver.sh:124`); no
    possibly-empty bash array is expanded under `set -u`.

## Design Decisions (resolving open questions)

- OQ-001 (approver-registry location) → `sdd/approver-registry.yaml`, new,
  protected via the same REQ-007 human-copy batch as the sidecars (Data
  Plan, above). Revisitable: if impl-review judges this warrants its own
  ADR (a new file format decision, not merely a schema addition to an
  already-decided ADR), promoting it is a low-cost follow-up that does not
  block this epic's other deliverables.
- OQ-002 (`distribution_channels`/`data_classification` shape) →
  arrays-of-string, not scalars, because ADR-0020's DSL example uses
  `contains`/`in` against these fields, and both operators are meaningless
  against a scalar (`contains`: "array ∋ scalar"; `in`: "scalar ∈ array
  literal") — API/Contract Plan's schema reflects this choice.
- OQ-003 (`tasks.md`/`traceability.md` Phase-2-deferral question,
  investigation.md) → RESOLVED by coordinator decision (2026-07-22): this
  package follows the repository's Phase model exactly — `tasks.md`/
  `traceability.md` are Phase 2 outputs and are not part of this package's
  committed content; a Draft task decomposition authored during this
  spec-authoring session is preserved outside the repository for
  reintroduction once the impl-review gate passes and this document's
  header is updated accordingly by that later session.
- New decision: whether `canonicalize-sdd-yaml`'s YAML parser is a
  hand-rolled 1.2-core-schema parser or a widely available library
  constrained to core-schema-only behavior (e.g. Python's `PyYAML` with
  `yaml.BaseLoader`/`SafeLoader` plus an explicit anchor/alias/duplicate-key
  post-check, since neither loader natively rejects duplicate keys or
  anchors by default). Decided: use a standard library (`PyYAML` or
  `ruamel.yaml`, confirmed available at a future implementation session) in
  its strictest built-in mode, plus an explicit post-parse walk that rejects
  any node the loader tags as an alias/anchor/non-core-tag or any mapping
  with a duplicate key BEFORE trusting the parsed structure — never rely on
  a loader flag alone without an independent structural check, since a
  library's "safe" mode is not guaranteed to reject duplicate keys (PyYAML's
  `SafeLoader` silently keeps the LAST occurrence of a duplicate key by
  default).
- New decision: whether the four `generate-guard-invariants.py`-generated
  files need a FIFTH consumer (a `.py`/`.sh`/`.ps1` trio for the new
  `EPIC_A1_TARGETS` constant, analogous to `PHASE2_HUMAN_COPY_TARGETS`).
  Decided: no new generated-file consumer is needed — `EPIC_A1_TARGETS` is
  folded into the SAME `protected_gate_suffixes`/`PROTECTED_GATE_SUFFIXES`
  list every existing consumer already reads (Protected-File Statement,
  above); it does not need its own generated-output projection the way
  `phase2_human_copy_targets` does, because this epic's own human-copy
  procedure (epic-159-pillar-c shape) does not consult
  `PHASE2_HUMAN_COPY_TARGETS`/`BootstrapTargets` at all.
- New decision (defense-tier scope, B4): why the hook-activation handshake
  is redesigned
  as a challenge/response protocol driven by the AGENT's own tool call
  rather than a standalone script's file I/O, and why nonce generation and
  the deny-signature/nonce match are performed by the PROTECTED script
  (never the agent) even though this is not, by itself, adversarially
  complete. A subprocess script cannot
  originate a `PreToolUse`-intercepted event — that interception happens
  only for tool calls the AGENT SESSION itself proposes through its host's
  native tool-call surface (INV-015, investigation.md). Decided: the
  script's role is reduced to challenge issuance (nonce generation stays on
  the protected-script side, embedded in the challenge — the agent records
  ONLY the raw tool-call result, never computes or supplies its own nonce)
  and evidence verification
  only; the SKILL layer (out of this package's own file scope except the
  ONE call site REQ-009 wires) is responsible for instructing the agent to
  make the real tool-call attempt and for recording its raw result. **Scope
  boundary, explicit**: this makes the verification LOGIC correct against
  synthetic evidence (a footgun guard against an agent trusting its own
  unmediated I/O) — it does not make A1 itself capable of observing a real
  host's live hook firing; that adversarial-tier proof is Epic A8's own
  mandatory Done condition (REQ-010, Non-goals), not something this design
  decision claims to deliver.
- New decision (resolved, B5): why the canary target is a dedicated sentinel
  path rather than the live approval sidecar, and why the sentinel is
  allowed to be transiently created rather than requiring absent-after on
  every outcome. The live sidecar is a
  security-load-bearing artifact; ANY write attempt against it — even a
  denied one that nonetheless triggers unexpected interaction with an
  existing sidecar's contents (e.g. a `Write` tool's diff-based apply
  logic touching the file's mtime, an OS-level lock, or a partial-write
  race) — is an avoidable risk with no compensating benefit, since the
  guard's protection is suffix-match-based and does not care WHICH
  protected suffix is probed. A prior draft additionally required
  absent-after on EVERY outcome, which is internally inconsistent: when the
  hook does not fire, the write genuinely succeeds — that success IS the
  detection signal for hook-inactivity, so the sentinel must be allowed to
  exist at that moment. Decided: reserve a dedicated,
  never-real-content path for canary use exclusively; require
  absent-before/absent-after when the hook fires (deny, never created);
  require the sentinel's creation, followed by one required cleanup
  tool-call, when the hook does not fire — end-to-end across the full
  handshake invocation, no branch leaves a lasting mutation.
- New decision (closes B3): why the weakening-detector trust anchor is a
  protected approved-context snapshot rather than git HEAD. Git HEAD is
  trivially redefinable by an ordinary commit — an attacker who commits a
  weakening change normally makes that change the new "HEAD," erasing any
  diff against it on the next invocation. Decided: the anchor is instead
  "the content a human actually last approved" — the exact bytes REQ-004's
  signer hashed into the currently-live sidecar's `context_sha256` — stored
  in a dedicated, full-write-deny-protected snapshot
  (`sdd/.approved-context/*.approved.yaml`) that changes ONLY via a new,
  complete `apply-human-copy` publish (REQ-004/REQ-007), never via a commit
  to the live content file. This makes injection/substitution of a
  favorable "baseline" structurally impossible on the production call path,
  which never accepts a caller-supplied anchor at all — and, as a side
  benefit, retires the prior design's git-repository/shallow-clone
  dependency entirely (Risks, below).
- New decision (closes M14): the resolver/generated-projection RESERVED
  path names (`resolve-project-context.{py,sh,ps1}`,
  `generated/project-context.resolved.json`) are chosen to match this
  epic's own script-family naming convention
  (`<verb>-project-context`/`generated/<noun>.<verb-past-participle>.json`)
  rather than inventing a distinct convention a later epic might not
  expect — a later epic amending this reservation (REQ-007's forced
  handoff gate) can therefore either use these exact names or explicitly
  document a rename in its own spec's stated `guard-invariants` diff, never
  silently drift.

## Global Constraints

Files touched by more than one task in this epic:

- `plugins/sdd-quality-loop/references/guard-invariants.json`,
  `generate-guard-invariants.py`, and the four `generated/guard_invariants.*`
  files (**R-10 PROTECTED**) — exactly ONE task (REQ-007's) edits these, in
  a single staged human-copy batch; no other task in this epic stages a
  competing edit to any of the six.
- `tests/run-all.sh` / `.ps1` (UNPROTECTED) — every REQ-003..REQ-007/
  REQ-010 task appends only its OWN new suite's registration lines, in
  dependency order (canonicalizer → sidecar generator → validator →
  weakening detector → guard-invariants registration test → handshake),
  landed in serialized, per-task commits.
- `.github/workflows/test.yml` (**R-10 PROTECTED**) — the same tasks each
  stage their own registration addition via human-copy, in the SAME
  serialized order, so no two tasks' staged candidates race under
  `specs/epic-189-a1-project-context/human-copy/`.
- `PLUGIN-CONTRACTS.md` — REQ-009's task is the sole editor within this
  epic.
- `apply-human-copy.{sh,ps1}` (**R-10 PROTECTED once REQ-007 lands**) —
  authored and tested UNPROTECTED by REQ-007's own task first (bootstrapped
  via a one-time human-verified plain `cp`), then registered as protected
  in the SAME human-copy batch as `guard-invariants.json`; every OTHER
  task's staged human-copy artifact (REQ-004's sidecar publication,
  REQ-009's skill edits, REQ-011's `test.yml` registration) is APPLIED
  using this tool, but no other task edits the tool itself.
- `sdd/.staging/` (UNPROTECTED, REQ-004) and `sdd/.hook-canary-sentinel`
  (**R-10 PROTECTED once REQ-007 lands**, REQ-010) — neither path is ever
  targeted by more than REQ-004's/REQ-010's own task respectively; no
  IMPLEMENTATION task ever authors real content for the sentinel path — its
  only legitimate, transient occupant is the handshake's own hook-inactive
  detection branch at test/run time (REQ-010, revised, B5), never
  committed content.
- `CHANGELOG.md`'s `## Unreleased` section — each task adds its own entry
  citing issue #189 (a single source issue for this whole epic, unlike
  epic-159-pillar-c's seven-issue fan-out) — tasks append distinct entries,
  never edit another task's entry in place.

## Security Boundaries

| Trust Boundary | Auth/Authz Mechanism | Data Classification | Concern |
|---|---|---|---|
| B1: content vs. approval separation | content files (`project-context.yaml`, `provider-bindings.yaml`) are freely agent-editable; EVERY consumer requires a fresh, validated sidecar (REQ-005) before trusting content — editability and trust are structurally decoupled | internal | Tampering (mitigated by hash+HMAC binding) |
| B2: sidecar/registry write boundary | full deny, no `sudo` bypass, for `*.approval.json`, `approver-registry.yaml`, AND `sdd/.hook-canary-sentinel` (REQ-007/REQ-008, revised — 4-basename matrix) | internal | Elevation of Privilege (prevented at the tool-mediated layer; adversarial-agent resistance additionally relies on the external HMAC key + human review, per ADR-0019's two-tier scope) |
| B3: HMAC key custody | `SDD_CONTEXT_KEY`/`_FILE`/home-path never read by an agent-driven signing operation; the signer itself never opens the live sidecar path for writing (REQ-004, revised — staging-only output) | internal | Spoofing (an agent cannot forge a valid signature without the key, nor smuggle an unsigned/invalid candidate onto the live path without `apply-human-copy`'s post-verification publish step) |
| B4: policy-weakening self-approval | two-person/cooldown verdict re-derived from the protected registry, from a protected approved-context anchor snapshot the caller cannot supply and an ordinary commit cannot move, at BOTH generation and validation time (revised — closes the "commit the weakening, then re-diff against the new normal" gap) | internal | Repudiation / self-approval (an agent cannot manufacture a favorable verdict by controlling only the content file, cannot self-diff via a supplied anchor, and cannot satisfy two-person review with one identity presented twice) |
| B5: track-selection fail-open / fail-open-via-tampering | a Project Context PHYSICALLY ABSENT uses the compatibility fallback; one PHYSICALLY PRESENT but failing validation STOPS with `PROJECT_CONTEXT_INVALID` (REQ-009, revised) — never treated as absent, closing the induced-validation-failure downgrade path | internal | Broken Access Control (prevented by the explicit-stop/compatibility-fallback distinction, not a single "treated as absent" branch) |
| B6: `generate-guard-invariants.py`'s own exact-match self-defense | a JSON-only edit to `guard-invariants.json` (without the matching Python-constant edit) fails `--check` deterministically | internal | Tampering (a single-file forgery of the protected-file inventory does not silently take effect) |
| B7: hook-activation handshake integrity | the redesigned handshake targets a dedicated sentinel path only (never the live sidecar; the sentinel itself is created only transiently, then cleaned up, when the hook is inactive) and never itself performs a write attempt (only a real, host-intercepted agent tool call counts as evidence, REQ-010) | internal | Tampering / false-negative Capability Mode activation (closes "canary corrupts live state" and the standalone-script blind spot for A1's own footgun-guard scope — does NOT extend to proving a live host's hook fires for a real, unscripted action, which is Epic A8's own mandatory Done condition) |
| B8: human-copy publish integrity | every protected-file publish (guard-invariants, sidecar signatures, skill-file edits, CI registration) goes through `apply-human-copy`'s held-handle, atomic-rename, no-path-copy-fallback discipline (REQ-007, generalizing ADR-0011) | internal | Tampering / TOCTOU (a bare `cp` would not defend against symlink/reparse/hard-link/rename-race attacks during the publish window) |

## Deployment / CI Plan

No runtime deployment; no new plugin. New suite pairs join
`tests/run-all.sh`/`.ps1` directly (unprotected); each corresponding
`.github/workflows/test.yml` step is staged via `apply-human-copy` (Global
Constraints, above) rather than joining the file directly.
`generate-guard-invariants.py --check` (already CI-wired,
`.github/workflows/test.yml:27-35`) is the first CI signal that would catch
an incomplete or out-of-order REQ-007 human-copy application. Deterministic
lane: every test this epic adds requires no LLM invocation, no network call,
and no `gh` invocation — including REQ-010's handshake tests, which use
fixture recorded-result evidence, not a live agent session (Epic A8 owns
the live, cross-runtime proof). Rollback: every task is
independently revertible (all new files, no existing behavior removed);
reverting REQ-007's agent-authored staging commit does NOT automatically
revert an already-human-applied `guard-invariants.json`/generated-file
change — the revert description must state explicitly whether a human
should also hand-revert that application. A staged sidecar-signing
candidate (REQ-004) that is never applied leaves no live-state change to
roll back at all (staging-only output, B3 above) — this is a strictly
lower-risk rollback surface than the guard-invariants batch.

## Constraint Compliance

| Requirement Constraint | Design Response |
|---|---|
| `workflow.*` single-valued, no array notation (REQ-001, ADR-0016) | schema `enum` on each of the three fields, `additionalProperties: false` on the `workflow` object rejects any array or extra key |
| `distribution_channels`/`data_classification` newly defined as component fields (REQ-001, ADR-0020) | both present as first-class array-of-string fields directly under `components[]` in the schema (API/Contract Plan, above) |
| component/binding `id` uniqueness (REQ-001/REQ-002, M18) | schema-external semantic check in REQ-005's content-schema validation step (`DUPLICATE_COMPONENT_ID`/`DUPLICATE_BINDING_ID`) — JSON Schema draft-07 cannot express this natively |
| cross-cutting seed-list scaffold (REQ-001, cross-epic addition) | `contracts/project-context.template.yaml` pre-populates `shared_paths` with `specs/**`/`reports/**`/`docs/**` as `classification: cross-cutting`, consumed by Epic A3's day-one fixture |
| Provider name never appears in Project Context (REQ-001, REQ-002, ADR-0018) | `provider_binding_ids` is the ONLY cross-reference field; the schema has no `provider` field anywhere under `components[]` |
| `provider-bindings.yaml` skeleton only, no `credentials`/`state_authority` vocabulary (REQ-002) | both fields typed `{"type": "object"}` with no nested schema — any object passes, nothing is validated beyond "is an object"; the new OPTIONAL `adapter_paths` field is a bare array-of-string, no glob interpretation in A1 |
| YAML 1.2 core schema, single-document, anchor/tag/dup-key/non-string-key/post-NFC-collision/out-of-range-number rejected (REQ-003, revised M11) | explicit post-parse structural walk (Design Decisions, above), not a bare loader-flag reliance; each rejection category has its own diagnostic and exit code |
| RFC 8785 JCS canonical JSON, ECMAScript-`Number` numeric form (REQ-003, revised — the "no exponent for integers" bespoke rule is retired) | deterministic key order, RFC-8785-correct numeric formatting (including exponents where JCS's own rule produces one), minimal string escaping — golden byte-sequence fixture asserts this directly |
| single Python implementation + thin wrappers, NO PowerShell-native fallback (REQ-003, decision doc §18.3, revised M10) | `.sh`/`.ps1`/`.js` are dispatch-only (`python3`/`python` resolution ONLY), mirroring `sdd-hook-guard.sh:1-53`'s DISPATCH shape but NOT its native-`.ps1`-fallback shape (which does not apply — there is no native canonicalizer implementation to fall back to); no wrapper reimplements canonicalization |
| HMAC preimage excludes `hmac` field itself, covers every other field (REQ-004, ADR-0019 v2.1, extended M9) | preimage construction operates on a field-excluded copy of the object, never the object with `hmac` present; AC-012's self-reference-exclusion test PLUS AC-036's golden-vector/per-field-mutation test are the executable proof |
| `approver` is a registry immutable id, primary/second must differ (REQ-004/REQ-005, NEW B2) | `DUPLICATE_APPROVER_IDENTITY` checked at generation time (before hashing) and independently at validation time |
| signer never writes the live sidecar path (REQ-004, NEW B7) | staged candidate + nonce-tagged manifest only; `apply-human-copy` publishes after REQ-005 re-validates the STAGED candidate |
| key never read by an agent-driven operation (REQ-004) | `generate-approval-sidecar` is authored and tested by an agent, but its SIGNING invocation is a human/CI-only operation — this is a documented operational constraint the design surfaces (Roles and Permissions, requirements.md), not one the script can enforce technically against a human who chooses to expose the key to an agent shell — the design's actual guarantee is that no key material is ever committed, logged, or echoed by the script itself |
| approver identity checked against a protected registry (REQ-005, REQ-006) | `sdd/approver-registry.yaml` is itself protected (REQ-007) — an agent cannot expand or shrink it to manufacture a favorable validation or weakening-detector outcome |
| weakening trust anchor internally resolved from an approved-context snapshot, never caller-supplied or git-derived in production (REQ-006, revised, closes B3) | default resolution reads the protected `sdd/.approved-context/*.approved.yaml` snapshot (published by `apply-human-copy` in lockstep with the sidecar, REQ-004/REQ-007); `--approved-context` override exists only for this script's OWN fixture tests, never used by REQ-004/REQ-005; an ordinary commit to the live content file cannot move this anchor |
| policy-weakening categories renormalized to the canonical nine, N/A categories reported, not silently skipped or proxy-classified (REQ-006, revised M12/M13) | the detector's diagnostic output enumerates all NINE decision-doc §9 categories every run (3 implemented + 6 N/A), with the invented `artifact_kinds`/`runtime_classes`/`distribution_channels`-shrink proxies REMOVED |
| exact-match guard-invariants registration (REQ-007) | `EPIC_A1_TARGETS` constant (26 entries, generated from `PROTECTED-MANIFEST.md`) added to the generator alongside `guard-invariants.json`'s new key, staged together in one `apply-human-copy` batch, staged-tree `--check` proof recorded before live application |
| resolver/generated-projection protection categories reserved, not silently absent (REQ-007, NEW M14) | two reserved paths added to the SAME batch, with a forced handoff gate for the epic that populates them |
| human-copy publish provides anchored-publisher-equivalent guarantees (REQ-007, NEW B6) | `apply-human-copy.{sh,ps1}` — held handle, handle-relative traversal, temp-rehash, atomic rename, no path-copy fallback, generalizing ADR-0011 |
| no hook-guard decision-logic edit (REQ-008) | `_is_protected_gate_file`'s suffix-match logic is unchanged; this epic relies on the EXISTING mechanism activating automatically once REQ-007's inventory lands, verified by the full 4×12×2 matrix rather than a spot check |
| CLI-flag stricter-only once Project Context exists (REQ-009, ADR-0023) | `full` + `--lite` is an explicit, loud error (never silently ignored); `lite` + `--full` promotes; both no-op cases pass through unchanged — mirrors ADR-0016 §10's `capability_enforcement` override asymmetry exactly |
| Project Context validation failure against an EXISTING file ⇒ explicit `PROJECT_CONTEXT_INVALID` stop, never treated as absent (REQ-009, revised AC-026, closes Blocker B1) | every migrated consumer FIRST checks physical presence (compatibility fallback only if absent), THEN calls REQ-005's validator when present — a failure routes to a NAMED stop, never to the compatibility-fallback branch |
| all five current CLI-flag consumers migrated together, none deferred (REQ-009, revised M16) | `sdd-ship`, `sdd-bootstrap`, `sdd-bootstrap-interviewer`, `lite-spec`, `lite-gate` all exercised against the identical 6-case common contract suite |
| hook not firing ⇒ stop, never silent fallback, via a HOST-observable mechanism (REQ-010, decision doc §7 v2, revised B4/B5) | `CAPABILITY_RUNTIME_UNAVAILABLE` is reported only when a runtime-specific expected-deny-signature is NOT observed from a genuine agent tool-call attempt; wired into all five A1-time entry points, never conflated with `disabled-legacy` |
| `.sh`/`.ps1` twin pairs mandatory, `.js` for the canonicalizer specifically (REQ-011, decision doc §18.3) | every new script ships both twins from creation; the canonicalizer additionally ships `.js`, matching `sdd-hook-guard`'s own four-runtime precedent |
| CI resilience (bash 3.2 array safety, macOS `$TMPDIR`, Windows `jq.exe` CRLF, no real-validator probing) | carried verbatim from epic-159-pillar-a2/b/c's established Constraint Compliance rows; Test Strategy item 12 restates the non-use declarations |

## Assumptions

`_PROTECTED_GATE_SUFFIXES`
(`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`) and
`generate-guard-invariants.py`'s exact-match validation (lines 129-167)
remain as observed at design time (2026-07-21); REQ-007's implementer
re-verifies both at task-start time. No existing script or schema already
defines an approver registry, a Project Context schema, or a canonical
YAML/JCS procedure anywhere in this repository (investigation.md
Assumptions). `sdd-hook-guard.py`'s decision logic (`_is_protected_gate_file`
and its call sites) is assumed stable for the duration of this epic — REQ-008
adds no new call site, it relies on the existing ones. The redesigned
hook-activation handshake (REQ-010) assumes each host runtime's
tool-call-denial reporting surface (Claude Code's `--emit exit` signature;
Codex CLI's `plugin_hooks`-gated dispatch; Copilot CLI's `--emit copilot`
JSON) is stable and distinguishable at implementation time (INV-015,
investigation.md) — re-verified per Risks, below. `detect-policy-weakening`'s
default anchor resolution (revised, closes B3) assumes only that
`apply-human-copy` has correctly published the approved-context snapshot in
lockstep with its accompanying sidecar whenever one exists — no git
working-tree/history assumption remains, since the anchor is a plain
protected-file read (Risks, below, covers the narrower missing/corrupted-
snapshot failure mode this replaces the prior git-dependency risk with).

## Open Questions

None blocking. OQ-001 and OQ-002 (investigation.md) are resolved above with
design decisions, both explicitly revisitable at low cost. OQ-003
(investigation.md — the `tasks.md`/`traceability.md` Phase-2-deferral
question) is resolved above (Design Decisions) by following the
repository's Phase model; it does not block this design's own content.

## Risks

Principal risk is an incomplete or out-of-order REQ-007 human-copy
application (Protected-File Statement, above) — mitigated by requiring the
staged-tree `--check` proof before any live application and by CI's own
`--check` step catching drift immediately after. Secondary risk is a
weakening-category under-classification (design.md Data Plan /
API-Contract-Plan table) letting a policy-weakening change through as
ordinary, single-approval content — mitigated by Test Strategy item 7's
per-category coverage plus negative (non-weakening) case, now against the
renormalized 3-implemented/6-N/A split (no invented proxy categories to
under-classify against). Tertiary risk is
key-material handling discipline for `SDD_CONTEXT_KEY` depending on human
operational practice the design cannot enforce technically (Constraint
Compliance, above) — mitigated by documenting the constraint explicitly
rather than presenting the script as a stronger guarantee than it is.
Quaternary risk is a future implementation session reintroducing
`tasks.md`/`traceability.md` from the preserved Draft (Open Questions,
above) without re-verifying it still matches this requirements.md/design.md
pair after any intervening spec-review/impl-review edits — mitigated by
recording the preserved draft's location and provenance in
investigation.md rather than leaving it as tribal knowledge. Quinary risk
(from the host-canary redesign, B4) is a host runtime's tool-call-
denial reporting surface drifting from this epic's pinned per-runtime
signature table without breaking the underlying guard itself — mitigated
by REQ-011's per-runtime fixture tests pinning each signature explicitly,
with Epic A8's cross-runtime handoff suite as this epic's own MANDATORY
handoff for a live, ongoing regression check beyond this epic's
fixture-only proof — a forced Done condition for A8, not merely a
designated future target. Senary risk (revised, from REQ-006's
approved-context anchor resolution, B3) is now a NARROWER risk than the
prior git-HEAD design's: the anchor snapshot itself could be missing (no
sidecar for a schema has ever been successfully published) or, in
principle, corrupted at the filesystem level — mitigated by the
`NO_APPROVED_CONTEXT_ANCHOR` fail-closed rule (missing snapshot ⇒ every
category `false`, never "assume weakening") and by the snapshot's own
full-write-deny protection (REQ-007/REQ-008), which an agent cannot
silently corrupt. This revision RETIRES the prior git-HEAD design's
non-git-deployment/shallow-clone/mid-rebase risk entirely, since the anchor
no longer depends on git history at all.
