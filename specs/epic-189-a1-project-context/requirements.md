# Requirements: epic-189-a1-project-context

Spec-Review-Status: Pending
Source Issues: https://github.com/aharada54914/sdd-forge/issues/189
Epic: https://github.com/aharada54914/sdd-forge/issues/187 (tracking) /
https://github.com/aharada54914/sdd-forge/issues/188 (Epic A0, Architecture
Decisions) — Epic A1 itself
Investigation: specs/epic-189-a1-project-context/investigation.md
(INV-001..INV-014, OQ-001..OQ-003)

## Overview

`docs/ai-dlc-foundation-decision-v2.md` §19 defines Epic A1 as the epic that
introduces `project-context.yaml` and `provider-bindings.yaml` as the sole,
signed source of truth for a project's workflow axes
(`spec_profile`/`artifact_layout`/`capability_enforcement`, ADR-0016) and
Provider-neutral component classification (ADR-0018), together with the
"承認防衛" (approval defense) mechanism a bare `status: Approved` field
cannot provide (ADR-0019): content/approval separation, deterministic
canonicalization (ADR-0021 depends on it; §18.3), external-key HMAC signing,
a policy-weakening detector with conditionally-activated two-person approval,
and full-write-deny protection for the sidecar and its verification
machinery via `guard-invariants` (INV-006). It also migrates the
track-selection contract (ADR-0023) so that a CLI flag can no longer silently
override a Project Context's declared `spec_profile` once one exists
(INV-001, INV-002), and introduces the hook-activation handshake (decision
doc §7 v2) so Capability Mode never silently falls back to legacy mode on a
runtime whose guard is not actually installed.

This is a **spec-only** package: eleven requirements (REQ-001..REQ-011)
covering schema, canonicalization, the approval sidecar, its validator and
weakening detector, protected-file registration, hook-guard extension, the
track-selection migration, the runtime handshake, and three-environment test
coverage. No implementation code is produced by this package; `tasks.md`
below is a Draft plan for a future implementation session.

## Target Users

- Project maintainers who need `project-context.yaml` to be the single,
  auditable place a project's workflow strictness and component boundaries
  are declared, instead of inferring mode from incidental file presence
  (ADR-0016; decision doc §2).
- Capability-mode consumers (Epics A2/A4/A5, not built by A1) that will read
  `project-context.yaml`'s component/`shared_paths` fields once A1 defines
  their schema.
- Human approvers who sign Project Context and Provider Binding changes and
  need the sidecar's HMAC and policy-weakening gate to make self-approval by
  an agent structurally impossible, not merely discouraged (ADR-0019).
- `sdd-ship`, `sdd-bootstrap-interviewer`, and lite-track operators whose
  track-selection behavior changes once a Project Context exists (INV-002,
  ADR-0023).
- CI and per-runtime hosts (Claude Code, Codex CLI, Copilot CLI) that must
  fail closed (`CAPABILITY_RUNTIME_UNAVAILABLE`) rather than silently
  degrade to legacy mode when their guard is not actually installed
  (decision doc §7 v2; ADR-0016 §7 cross-reference).

## Problems

- No `project-context.yaml` schema exists today; `spec_profile` is inferred
  today only via `AGENTS.md`'s free-text `spec_profile: lite` marker
  (INV-001, INV-002), which cannot express `artifact_layout` or
  `capability_enforcement` at all, and gives a CLI flag (`--full`/`--lite`)
  unconditional priority over any such marker (`PLUGIN-CONTRACTS.md:61-66`).
- The DSL field allowlist ADR-0020 defines (`characteristics.pii`,
  `distribution_channels`, `data_classification`, etc.) has no schema "home
  field" for two of its members (`distribution_channels`,
  `data_classification`) anywhere in this repository — ADR-0020 explicitly
  defers defining them to this epic.
- A bare `status: Approved` field inside a YAML file is forgeable by any
  agent with write access to that file; the repository's only existing
  precedent for detecting unauthorized approval mutation
  (`approval_increases`, `sdd-hook-guard.py:489` onward) is an
  increase-count heuristic that a hash-recomputation attack defeats for a
  content/hash-coupled file (ADR-0019 Context — "an agent can modify the
  YAML, then run the public canonicalization procedure to recompute the
  hash, and rewrite `context_sha256` alone").
- No canonical, cross-runtime-stable hashing procedure exists for YAML
  content in this repository: `sudo_active`'s and
  `generate-evidence-bundle.sh`'s canonicalizations (INV-003, INV-004) are
  both bespoke, field-order-specific preimages, not a general YAML/JSON
  canonicalization — nothing here implements YAML 1.2 parsing, anchor/tag/
  duplicate-key rejection, NFC normalization, or RFC 8785 JCS.
- No policy-weakening detector exists; nothing distinguishes an
  enforcement-tightening Project Context edit from an enforcement-weakening
  one, so nothing can conditionally require a second approver only for the
  latter (decision doc §9 v2).
- `guard-invariants` (INV-006) has no entries for any Project-Context-related
  path today — the sidecar, the approver registry, and the new verification
  scripts this epic introduces are all, today, ordinary agent-writable
  files.
- The track-selection priority order gives `--lite`/`--full` unconditional
  priority over any project-level declaration (INV-001), which ADR-0023
  identifies as directly conflicting with ADR-0016's single-source-of-truth
  claim once a Project Context exists.
- Nothing in this repository verifies that a runtime's hook guard is
  actually installed and firing before trusting Capability Mode; a runtime
  whose guard silently fails to attach (decision doc §7 v2: "Codex は
  `plugin_hooks` feature flag 必須、Copilot の subagent hook は非発火という
  既知の実態がある") would today have no detectable difference from one
  whose guard is present.

## Goals

- **REQ-001** (`project-context.yaml` schema; decision doc §2, §5 (Q4), §11
  (Q10), §12 (Q11); ADR-0016, ADR-0018, ADR-0020): define
  `contracts/project-context.schema.json` for `sdd/project-context.yaml`,
  schema id `sdd-project-context/v1`. Top level: `schema` (const), `workflow`
  (`spec_profile: full|lite`, `artifact_layout:
  lite-three-file|legacy-seven-layer|facet-hybrid|facet-native`,
  `capability_enforcement: advisory|required` — each single-valued per
  ADR-0016, no array notation), `components` (array; each entry: `id`
  required unique string; `artifact_kinds` array of string;
  `runtime_classes` array of string; `platform_targets` array of `{os,
  architecture}` objects; `characteristics` object with boolean sub-fields
  `pii`, `ui`, `auto_update`, `local_persistence`, plus non-DSL-allowlisted
  informational booleans `long_running`, `replayable`, `human_in_the_loop`
  (decision doc §5 Q4 example); `distribution_channels` array of string
  (NEW field, ADR-0020 Decision item 5 — no fixed enum in Foundation, since
  no downstream Capability Pack vocabulary is fixed yet); `data_classification`
  array of string (NEW field, same ADR-0020 provenance); `provider_binding_ids`
  array of string, each referencing an `id` in `provider-bindings.yaml`
  (REQ-002) — referential integrity between the two files is NOT validated
  by A1's schema alone (JSON Schema cannot cross-file-reference); `paths`
  object with `include`/`exclude` arrays of glob string (decision doc §12 Q11
  — schema fields only; the Reverse Coverage Gate that consumes them is
  explicitly A3 scope, not built here)), and `shared_paths` (array; each
  entry either `{pattern, components: [...]}` or `{pattern, classification:
  cross-cutting}`, decision doc §12 Q11 example). `distribution_channels` and
  `data_classification` are the two fields ADR-0020 says this schema must
  newly define as "first-class fields under a component" so the DSL field
  allowlist (`artifact_kinds`, `runtime_classes`, `characteristics.pii`,
  `characteristics.ui`, `characteristics.auto_update`,
  `characteristics.local_persistence`, `distribution_channels`,
  `data_classification`) has a schema home for every one of its members —
  every one of those eight paths resolves against a field this REQ defines.
- **REQ-002** (`provider-bindings.yaml` schema, skeleton only; decision doc
  §5 (Q4), v2 注記; §14 (Q13) 注記; ADR-0018): define
  `contracts/provider-bindings.schema.json`, schema id
  `sdd-provider-bindings/v1`. Top level: `schema` (const), `bindings` (array;
  each entry: `id` required unique string, `provider` required string (no
  fixed enum — provider-neutral, Foundation does not fix a provider
  vocabulary), `product` required string, `purpose` required string,
  `state_authority` OPTIONAL, schema-present but validated only as "object,
  no fixed sub-schema" (a JSON Schema `{"type": "object"}` passthrough —
  detailed vocabulary explicitly deferred to a future ADR when a real cloud
  Pack lands, decision doc §5 Q4 v2 注記 and §14 Q13 注記), `credentials`
  OPTIONAL, same passthrough treatment — Foundation confirms only "binding の
  骨格（id / provider / product / purpose / binding 参照）", never a
  `credentials`/`state_authority` value vocabulary). No Capability Pack or
  Provider name may appear inside `project-context.yaml`'s own component
  fields (REQ-001) — only `provider_binding_ids` cross-references into this
  file, preserving the Capability/Provider boundary decision doc §5
  establishes.
- **REQ-003** (canonicalizer + hash generator; decision doc §18.3; INV-005,
  INV-014): a single Python implementation,
  `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py`, with thin
  `sh`/`ps1`/`js` dispatcher wrappers
  (`canonicalize-sdd-yaml.sh`/`.ps1`/`.js`) following the
  `sdd-hook-guard.sh` shape (INV-005) — every wrapper locates and invokes the
  Python implementation (or, for `.ps1`, a `pwsh`/`powershell` fallback path
  identical in spirit to `sdd-hook-guard.sh:41-50`) and denies fail-closed if
  neither runtime is available; no wrapper reimplements canonicalization
  logic. Given a YAML or JSON file, it: (a) parses YAML strictly per the 1.2
  **core schema** (rejecting 1.1-only `on`/`off`/`yes`/`no` boolean
  coercion); (b) rejects any document containing an anchor (`&name`), an
  alias (`*name`), a custom (non-core) tag, or a duplicate mapping key,
  exiting non-zero with a diagnostic naming the rejection category — never
  silently accepting one interpretation of an ambiguous document; (c)
  normalizes every string scalar to Unicode NFC; (d) serializes the parsed
  structure to canonical JSON per RFC 8785 (JCS) — deterministic key
  ordering, numeric formatting, and string escaping; (e) computes and emits
  the SHA-256 hex digest of the canonical UTF-8 byte sequence, plus the
  canonical bytes themselves (for HMAC preimage construction, REQ-004). This
  script is the single implementation every other new script in this epic
  that needs canonical bytes or a canonical hash calls into — none
  reimplements YAML canonicalization independently.
- **REQ-004** (approval sidecar schema + HMAC signing; ADR-0019; decision doc
  §9 (Q8) v2, §18.3 HMAC preimage note (v2.1)): define
  `contracts/approval-sidecar.schema.json` for `sdd/project-context.approval.json`
  (schema id `sdd-project-context-approval/v1`) and
  `sdd/provider-bindings.approval.json` (schema id
  `sdd-provider-bindings-approval/v1`, same shape, per ADR-0019 "and,
  identically, `provider-bindings.yaml`"). Fields, matching ADR-0019's JSON
  example literally: `schema` (const, one of the two ids above),
  `context_sha256` (string, `sha256:<64-hex>` — literal field name preserved
  from ADR-0019/decision doc §9 for both sidecars, not renamed per-artifact),
  `primary_approval` (object: `status` const `"Approved"`, `approver`
  non-empty string, `approved_at` ISO 8601 string), `second_approval`
  (`null` or an object with the same shape as `primary_approval`),
  `effective_at` (`null` or an ISO 8601 string — populated only when REQ-006's
  solo-maintainer-cooldown path is taken; decision doc §9 v2 "発効予定時刻を
  HMAC 署名し、期限前の適用を validator が拒否する" places this inside the
  signed record, not a side channel), `hmac` (string, 64 lowercase hex
  characters, matching the existing `SUDO_SIGNATURE_HEX_LENGTH = 64`
  convention at `guard_invariants.py:3`). **HMAC preimage** (ADR-0019 v2.1,
  decision doc §18.3 v2.1): the approval object with the `hmac` field
  excluded, passed through REQ-003's canonicalizer (YAML/JSON parse → NFC →
  JCS), producing a UTF-8 byte sequence; the HMAC-SHA256 of that byte
  sequence, keyed by the resolved external key, is the `hmac` field's value.
  **Key resolution** follows the same four-step order as `SDD_SUDO`/
  `SDD_EVIDENCE_KEY` (INV-003, INV-004): env `SDD_CONTEXT_KEY` → env
  `SDD_CONTEXT_KEY_FILE` (file read, BOM/whitespace-stripped) →
  `<HOME>/.sdd/context-key` → no key (fail-closed: signing is impossible,
  never silently unsigned). `plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py`
  (+ `.sh`/`.ps1` wrappers, `check-contract.{sh,ps1,py}` three-file shape)
  is the human/CI-invoked tool that computes `context_sha256` (via REQ-003
  against the live content file), accepts `--approver`, `--status`, and
  (only for the solo-cooldown path) an `--effective-at` value, and signs.
  This tool itself never runs with agent-accessible credentials as part of
  an agent-driven workflow; an agent may author and test the SCRIPT, but the
  signing operation always requires a human or CI principal holding
  `SDD_CONTEXT_KEY`.
- **REQ-005** (approval validator; ADR-0019, decision doc §9 (Q8)):
  `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` (+
  `.sh`/`.ps1`) verifies, for a given content file + sidecar pair: (1) hash
  match — `context_sha256` equals REQ-003's canonical hash of the live
  content file, exactly (byte-for-byte content binding); (2) HMAC
  verification — recompute the REQ-004 preimage, HMAC with the resolved
  `SDD_CONTEXT_KEY`, and `hmac.compare_digest` against the stored `hmac`
  (constant-time, mirroring `sdd-hook-guard.py:480`); no key available is a
  hard failure, never a skip; (3) approver-identity check — `primary_approval.approver`
  (and `second_approval.approver` when present) must each be a registered
  identity in `sdd/approver-registry.yaml` (REQ-006); an unregistered
  approver name fails validation even with a structurally valid HMAC; (4)
  `effective_at` gate — if non-null and in the future (validator's current
  time < `effective_at`), validation fails with a distinct
  not-yet-effective diagnostic (never silently treated as already
  effective) — the direct analogue of `SDD_SUDO`'s `issued > now` rejection
  (`sdd-hook-guard.py:454-455`). Any gate that consumes a Project Context or
  Provider Binding (a future Epic A2/A4/A5 concern; A1 ships the validator
  itself, not its call sites in those gates) must call this validator and
  treat any of the four failure modes identically — a failed validation
  blocks, it never degrades to "advisory."
- **REQ-006** (policy-weakening detector; decision doc §9 (Q8) v2 "二者承認:
  条件付き活性化"): `plugins/sdd-quality-loop/scripts/detect-policy-weakening.py`
  (+ `.sh`/`.ps1`) compares a previous-committed and a candidate
  `project-context.yaml` (or `provider-bindings.yaml`) and classifies the
  diff against the exact weakening list decision doc §9 enumerates:
  weakening `capability_enforcement` (`required`→`advisory`), removing a
  Capability a component references, narrowing a component's `paths.include`
  or widening its `paths.exclude`, removing an entry from
  `distribution_channels` that de-scopes public distribution, lowering a
  component's declared criticality (Foundation reserves the field name for
  Epic A2; this detector treats its absence as "not weakening" until that
  epic defines it — a documented N/A, not a silent skip), widening a
  Provider allowlist (Foundation has no Provider allowlist field yet in
  REQ-002's skeleton; same documented-N/A treatment), changing a production
  write-path declaration (same N/A treatment — no such field exists until a
  future epic), removing a required Gate (same N/A treatment — Gate
  declarations are Epic A2 scope), and `workflow.spec_profile` moving from
  `full` to `lite`. A change matching zero of these categories is
  NOT policy-weakening (tightening or lateral changes proceed under
  single-approval). For a change classified as policy-weakening, the
  detector additionally reads `sdd/approver-registry.yaml` (REQ-007,
  protected) and outputs a machine-readable verdict: `two_person_required:
  true` when the registry lists 2 or more distinct real identities, else
  `two_person_required: false` with `cooldown_hours: 24` (reusing
  `SDD_SUDO`'s TTL constant family, INV-003) — this verdict is what
  REQ-004's sidecar-generation tool and REQ-005's validator both consult:
  generation requires `second_approval` present (not merely
  possible) before signing when `two_person_required: true`; generation sets
  `effective_at` to now+24h and permits `second_approval: null` when
  `two_person_required: false`; validation rejects a policy-weakening
  sidecar missing the approvals its own detector verdict requires, at
  validate time (re-derived from the same registry, never trusted from the
  sidecar's own claim).
- **REQ-007** (protected registration via human-copy; decision doc §9 (Q8)
  item 3; INV-006, INV-011): the following NEW paths are added to
  `protected_gate_suffixes` in `plugins/sdd-quality-loop/references/guard-invariants.json`,
  with `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`
  extended in the same change (INV-006 — the generator's `expected_protected`
  is an exact-match hardcoded tuple, so a JSON-only edit fails `--check`):
  `sdd/project-context.approval.json`, `sdd/provider-bindings.approval.json`,
  `sdd/approver-registry.yaml`, and every new script REQ-003..REQ-006 and
  REQ-010 introduce (`canonicalize-sdd-yaml.{py,sh,ps1,js}`,
  `generate-approval-sidecar.{py,sh,ps1}`,
  `validate-approval-sidecar.{py,sh,ps1}`,
  `detect-policy-weakening.{py,sh,ps1}`,
  `check-hook-activation-handshake.{py,sh,ps1}`). The four generated
  `guard_invariants.*` files (already protected) are regenerated to reflect
  the updated inventory. **Every file this REQ touches
  (`guard-invariants.json`, `generate-guard-invariants.py`, the four
  generated files) is itself R-10-protected before this change lands**, so
  every edit is staged under
  `specs/epic-189-a1-project-context/human-copy/` with a `MANIFEST.sha256`
  entry per file, per the epic-159-pillar-c precedent (INV-011) — never a
  direct write.
- **REQ-008** (hook-guard extension — sidecar full-write-deny; ADR-0019 item
  1): `sdd-hook-guard.py`'s `_is_protected_gate_file` already denies writes
  to any suffix in `_PROTECTED_GATE_SUFFIXES` (INV-006), so once REQ-007's
  registration lands, `sdd/project-context.approval.json`,
  `sdd/provider-bindings.approval.json`, and `sdd/approver-registry.yaml`
  are automatically covered by the EXISTING protected-file deny path — no
  new deny logic is required in the guard's decision code. This REQ's own
  scope is: (a) confirm (with an executable test, REQ-011) that a write
  attempt against each of the three sidecar/registry basenames is denied
  through every mutation surface `_is_protected_gate_file` is consulted from
  (`sdd-hook-guard.py:1102,1110,1133,1136,1207,1210,1234,1237,1255,1258,1471,1486` —
  the full call-site set, verified at implementation time), including
  `sudo` (never-bypass — ADR-0019 item 5, matching `SDD_SUDO`'s existing
  never-sudo class); (b) since `sdd-hook-guard.py`/`.sh`/`.ps1`/`.js` are
  themselves R-10-protected, this confirmation is achieved by TESTING the
  live guard as it stands after REQ-007's human-copy lands — this REQ does
  not itself require editing the guard's decision logic, only its
  `_PROTECTED_GATE_SUFFIXES` inventory (REQ-007) and its test coverage
  (REQ-011).
- **REQ-009** (track-selection contract migration; ADR-0023; INV-001,
  INV-002): revise `PLUGIN-CONTRACTS.md:61-66`'s Track Detection section to
  state the Project-Context-present rule (ADR-0023 item 1: Context `lite` +
  `--full` → promote to full; Context `lite` + `--lite` → no-op; Context
  `full` + `--lite` → **error, execution stops**, explicit message, never
  silently ignored; Context `full` + `--full` → no-op) ahead of the existing
  CLI-flag-first priority order, which becomes the documented compatibility
  fallback for "no Project Context" only (ADR-0023 item 2). Consumer
  migration, enumerated exhaustively per ADR-0023's own "no partial
  migration" warning: `plugins/sdd-ship/skills/ship/SKILL.md:76-117`
  (protected — human-copy),
  `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md:80-132` (unprotected —
  direct edit),
  `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:147,159,199`
  (unprotected — direct edit), and the lite-track family:
  `plugins/sdd-lite/skills/lite-spec/SKILL.md:48` (protected — human-copy)
  and `plugins/sdd-lite/skills/lite-gate/SKILL.md` (unprotected — direct
  edit, if it reads track selection at implementation time; confirmed
  unprotected but not yet confirmed to read track selection — implementer
  verifies at task start). Every migrated consumer first checks for
  `sdd/project-context.yaml` (REQ-001) and, only when present, applies the
  Project-Context-present rule via REQ-005's validator (a Project Context
  that fails validation is treated as absent for track-selection purposes —
  fail-closed to the compatibility fallback, never fail-open to
  "assume full").
- **REQ-010** (hook-activation handshake; decision doc §7 v2 "Hook 稼働ハンド
  シェイク"): `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py`
  (+ `.sh`/`.ps1`) issues a harmless canary probe the guard is already known
  to unconditionally deny — a zero-byte write attempt against the live
  `sdd/project-context.approval.json` path (REQ-007/REQ-008; the file need
  not exist for the probe, since `_is_protected_gate_file` matches on path
  suffix alone, INV-006) — through the SAME tool-call surface a real agent
  write would use, and inspects the result. Denial observed ⇒ hook is
  installed and firing; report `HOOK_ACTIVE`. No denial observed (the write
  would have succeeded, or the probe cannot determine an outcome) ⇒ report
  `CAPABILITY_RUNTIME_UNAVAILABLE` and the calling bootstrap/gate skill MUST
  stop Capability Mode rather than silently falling back to legacy mode
  (decision doc §7 v2, restated verbatim: "legacy modeへ黙ってフォールバック
  してはならない"). This REQ ships the handshake script and its
  documentation; wiring it into `sdd-bootstrap-interviewer` and the gate
  skills' own entry points (a Capability Mode concern, most of whose
  consuming skills do not exist before Epic A2/A5) is limited to the ONE
  call site this epic's own track-selection migration (REQ-009) touches —
  broader wiring is out of scope (see Non-goals).
- **REQ-011** (three-environment test coverage; decision doc §6, §7 v2;
  INV-012): every new script REQ-003..REQ-007, REQ-010 introduces gets a
  `.sh`+`.ps1` test-twin pair under `tests/`, registered directly in
  `tests/run-all.sh`/`.ps1` (both unprotected, INV-012), with the
  `.github/workflows/test.yml` step registration staged via human-copy
  (protected, INV-011). Mandatory cases across the suites: REQ-003's
  dual-runtime hash-equality fixture (the `.py`-canonical and the `.js`
  wrapper — where Node is available — produce an identical SHA-256 for the
  same fixture file; the `.sh`/`.ps1` wrappers are dispatch-only and are
  proven to call the same `.py`, not a divergent reimplementation);
  REQ-004/REQ-005's cooldown-not-yet-elapsed rejection; REQ-009's
  Context-`full` + `--lite` error-stop case; REQ-010's canary-non-denial
  detection (a fixture guard stub that does NOT deny, proving the handshake
  itself fails closed rather than silently reporting `HOOK_ACTIVE` when it
  cannot tell). No suite in this epic invokes a real LLM, `gh`, or `sdd-sudo`.

## Non-goals

- Building the Reverse Coverage Gate (`check-component-coverage`) that
  consumes `project-context.yaml`'s `paths.include`/`paths.exclude` and
  `shared_paths` — REQ-001 defines the schema fields only; the Gate itself
  is explicitly Epic A3 scope (decision doc §12, §19 Epic A3; parent task
  instruction).
- Fixing a `credentials`/`state_authority` value vocabulary for
  `provider-bindings.yaml` — REQ-002 confirms only the binding skeleton;
  the detailed vocabulary is deferred to an ADR written when a real
  cloud-service Pack lands (decision doc §5 Q4 v2 注記, §14 Q13 注記).
- The Capability Registry, Resolver, Facet Manifest, or any Gate-stage
  machinery that consumes `workflow.capability_enforcement` or
  `components.*` beyond schema definition — Epics A2, A4, A5 (decision doc
  §19; ADR-0016 Consequences: "any component that consults
  `capability_enforcement` ... must first check whether the capability
  pipeline is in the `disabled-legacy` derived state").
- Creating an actual `sdd/project-context.yaml` instance for sdd-forge
  itself — that is Epic A9 (Dogfood) scope; A1 ships schema, scripts, and
  contracts only, no target-repository instance data.
- Wiring `check-hook-activation-handshake` (REQ-010) into every future
  Capability Mode entry point — only the ONE call site REQ-009's own
  migration touches is wired here; broader wiring belongs to the epics that
  introduce those entry points (A2, A5, A8's cross-runtime handoff suite).
- Any Artifact Gate or Promotion Gate work (decision doc §3.2, §3.3 — enum
  reservation only, no implementation, matching the Foundation-wide
  `stage: implementation`-only scope).
- Any `sdd-delivery` or `sdd-operability` plugin work (decision doc §7, §9,
  §14 — new plugins explicitly out of Foundation scope).
- Actually running `spec-review-loop`, `impl-review-loop`, or
  `task-review-loop` against this package — that is a separate, human-gated
  workflow step this spec-authoring session does not perform (see
  investigation.md INV-008/OQ-003 for the resulting, honestly-reported
  `check-workflow-state.sh` tension).
- Modifying `plugins/**`, `scripts/**`, `.github/**`, `tests/**`, or
  `contracts/**` directly in this spec-authoring session — every concrete
  script, schema, and test file this package specifies is Draft design for
  a future implementation session (`tasks.md`), not code produced now.

## User Stories

As a project maintainer, I declare my project's workflow axes once in
`sdd/project-context.yaml` and know that CLI flags can no longer silently
downgrade my `full` profile to `lite`, nor can an agent forge the file's
approval by editing content and recomputing a hash — every legitimate change
requires a human-copy-applied, externally-keyed HMAC signature I control. As
a solo maintainer, I can still roll back an overly strict enforcement policy
myself, via a documented first-approval-plus-24-hour-cooldown path, without
inventing a fictitious second identity. As a human security reviewer, I can
verify that the sidecar's verification machinery (the canonicalizer,
validator, and weakening detector) is itself protected from agent tampering,
the same way the hook guard protects itself. As a `sdd-ship` operator, I
either get an explicit error when I pass a track flag that would silently
weaken my project's declared policy, or a clear promotion message when it
would strengthen it — never a silent override in either direction. As a CI
maintainer, I know Capability Mode never silently degrades to legacy
behavior on a runtime whose hook guard failed to attach — it stops with a
named, diagnosable error instead.

## Acceptance Criteria

- AC-001: `contracts/project-context.schema.json` validates a fixture
  `sdd/project-context.yaml` exercising every REQ-001 field
  (`workflow.*` single-valued triple; a `components` entry with
  `artifact_kinds`, `runtime_classes`, `platform_targets`,
  `characteristics.{pii,ui,auto_update,local_persistence,long_running,replayable,human_in_the_loop}`,
  `distribution_channels`, `data_classification`, `provider_binding_ids`,
  `paths.{include,exclude}`; a `shared_paths` entry of each of the two
  documented shapes) and rejects a fixture missing any REQ-001-required
  field. (REQ-001)
- AC-002: every one of the eight ADR-0020 field-allowlist dotted paths
  (`artifact_kinds`, `runtime_classes`, `characteristics.pii`,
  `characteristics.ui`, `characteristics.auto_update`,
  `characteristics.local_persistence`, `distribution_channels`,
  `data_classification`) resolves against a field REQ-001's schema defines —
  asserted by a fixture-driven per-path presence check, not by inspection
  alone. (REQ-001)
- AC-003: `contracts/provider-bindings.schema.json` validates a fixture
  `sdd/provider-bindings.yaml` with `id`/`provider`/`product`/`purpose`
  required and present, and accepts (without further validation)
  `state_authority`/`credentials` as arbitrary objects; a fixture with
  `state_authority` or `credentials` present in an unanticipated shape still
  validates (passthrough proof). (REQ-002)
- AC-004: no field in REQ-002's schema or a conforming fixture names a
  specific Provider (Azure/AWS/GCP/etc.) as an enum value — `provider` is
  schema-typed as an unconstrained string, asserted by a fixture using an
  invented provider name that still validates. (REQ-002)
- AC-005: `canonicalize-sdd-yaml.py`, given a YAML document containing an
  anchor, an alias, a custom tag, or a duplicate mapping key (one fixture per
  category, four fixtures total), exits non-zero with a diagnostic naming
  the specific rejection category for each. (REQ-003)
- AC-006: given a YAML document using 1.1-only boolean tokens (`on`, `off`,
  `yes`, `no`) as scalar values, the canonicalizer parses them as plain
  strings, not booleans (1.2 core-schema behavior), asserted by a
  round-trip fixture. (REQ-003)
- AC-007: given a fixture containing non-NFC-normalized Unicode (e.g. a
  precomposed vs. decomposed accented character in two otherwise-identical
  fixture files), the canonicalizer produces byte-identical canonical output
  and an identical SHA-256 hash for both. (REQ-003)
- AC-008: given a fixture with keys in non-canonical order and
  non-canonical number formatting, the canonicalizer's JSON output is RFC
  8785 (JCS) compliant — deterministic key order, canonical number
  formatting — asserted against a hand-computed expected byte sequence for
  at least one fixture. (REQ-003)
- AC-009: `canonicalize-sdd-yaml.py`, `.sh`, `.ps1`, and (where Node is
  available) `.js`, given the SAME fixture file, produce an IDENTICAL
  SHA-256 hash — the dual/multi-runtime hash-equality fixture test REQ-011
  requires; a wrapper-dispatch proof (not a reimplementation-comparison)
  confirms each wrapper actually invokes the `.py` implementation rather
  than an independent code path. (REQ-003, REQ-011)
- AC-010: `contracts/approval-sidecar.schema.json` validates a fixture
  sidecar exercising every REQ-004 field, including a non-null
  `second_approval` and a non-null `effective_at`, and rejects a fixture
  with `hmac` shorter than 64 hex characters or containing an uppercase hex
  character. (REQ-004)
- AC-011: `generate-approval-sidecar.py`, given a content file and a
  resolvable `SDD_CONTEXT_KEY`, produces a sidecar whose `hmac` field
  verifies under `validate-approval-sidecar.py`'s independent
  recomputation of the same preimage; given NO resolvable key (all four
  resolution steps exhausted), the tool exits non-zero and writes no
  sidecar — never producing an unsigned or placeholder-signed file. (REQ-004)
- AC-012: the HMAC preimage is proven to exclude the `hmac` field itself —
  a fixture pair with identical content except for the `hmac` field's own
  value produces the SAME preimage (asserted by an internal preimage-dump
  test hook), confirming no self-reference. (REQ-004)
- AC-013: `SDD_CONTEXT_KEY` resolution follows the documented four-step
  order — a fixture matrix (env var set / env-file var set / home-path file
  present / none) asserts the correct key bytes are selected at each step
  and that BOM/trailing-whitespace stripping matches `_strip_key_bytes`'s
  existing behavior byte-for-byte. (REQ-004)
- AC-014: `validate-approval-sidecar.py` rejects (distinct diagnostic per
  case): a hash mismatch (content file mutated after signing); an HMAC
  mismatch (signature bytes altered, or recomputed under a different key);
  an unregistered approver name; and an `effective_at` timestamp in the
  future relative to validation time — four independent fixture cases, none
  producing a false PASS. (REQ-005)
- AC-015: `validate-approval-sidecar.py` PASSES a fixture whose
  `context_sha256`, `hmac`, and approver identities are all correct and
  whose `effective_at` is null or already elapsed. (REQ-005)
- AC-016: `detect-policy-weakening.py`, given a before/after
  `project-context.yaml` pair for each of the nine decision-doc §9
  weakening categories REQ-006 enumerates that this schema can currently
  express (`capability_enforcement` `required`→`advisory`; a Capability
  removed from a component — modeled against `artifact_kinds`/
  `runtime_classes` shrinking, since Epic A2's Capability vocabulary does
  not exist yet; `paths.include` narrowing; `paths.exclude` widening;
  `distribution_channels` entry removed; `spec_profile` `full`→`lite`),
  classifies each as `policy_weakening: true`; the remaining three
  categories decision doc §9 names (criticality, Provider allowlist,
  production write-path, required-Gate removal) are asserted as documented
  N/A (schema field does not exist yet) rather than silently ignored — a
  dedicated case asserts the detector's own diagnostic names each as N/A,
  not merely omits them. (REQ-006)
- AC-017: `detect-policy-weakening.py`, given a before/after pair that
  matches none of the weakening categories (e.g. `capability_enforcement`
  `advisory`→`required`, a strengthening change), classifies
  `policy_weakening: false`. (REQ-006)
- AC-018: given a policy-weakening change and an `sdd/approver-registry.yaml`
  fixture with 2 distinct registered identities, the detector emits
  `two_person_required: true`; given the same change against a
  1-identity registry, it emits `two_person_required: false,
  cooldown_hours: 24`. (REQ-006)
- AC-019: `generate-approval-sidecar.py`, given a `two_person_required: true`
  verdict and only a `primary_approval` (no `second_approval`), refuses to
  sign; given the same verdict with both approvals present, it signs
  successfully. (REQ-004, REQ-006)
- AC-020: `generate-approval-sidecar.py`, given a `two_person_required:
  false` verdict, sets `effective_at` to (signing time + 24 hours) and signs
  with `second_approval: null`; `validate-approval-sidecar.py` rejects
  applying that sidecar's approval before `effective_at` (AC-014's fourth
  case) and accepts it after. (REQ-004, REQ-005, REQ-006)
- AC-021: `sdd/project-context.approval.json`,
  `sdd/provider-bindings.approval.json`, `sdd/approver-registry.yaml`, and
  every REQ-003..REQ-006/REQ-010 script path are present in the staged
  `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json`
  candidate's `protected_gate_suffixes` array, with a matching
  `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`
  candidate whose `expected_protected` constant includes the same set; the
  staged candidate's `generate-guard-invariants.py --check` (run against the
  staged tree, not the live one) passes. (REQ-007)
- AC-022: the LIVE `guard-invariants.json`, `generate-guard-invariants.py`,
  and the four `generated/guard_invariants.*` files are byte-identical
  before and after this epic's own implementation commits — no task ever
  writes them directly (SHA-256 comparison). (REQ-007)
- AC-023: after a human applies the REQ-007 staged candidates, a write
  attempt (through the same tool-call surface a real agent write would use)
  against each of `sdd/project-context.approval.json`,
  `sdd/provider-bindings.approval.json`, and
  `sdd/approver-registry.yaml` is denied by the live hook guard, including
  under an active `SDD_SUDO` token (never-bypass proof). (REQ-008)
- AC-024: `PLUGIN-CONTRACTS.md`'s Track Detection section documents the
  Project-Context-present rule (four cases: lite+`--full`→promote,
  lite+`--lite`→no-op, full+`--lite`→error-stop, full+`--full`→no-op) ahead
  of the existing CLI-flag-first order, which is retitled as the
  compatibility-fallback path for "no Project Context". (REQ-009)
- AC-025: a fixture project with `sdd/project-context.yaml` declaring
  `workflow.spec_profile: full`, invoked with `--lite`, causes `sdd-ship`'s
  documented Track Detection procedure to stop with an explicit,
  non-silent error message — never proceeding as `lite`. A parallel fixture
  with `spec_profile: lite`, invoked with `--full`, promotes to `full`
  without error. (REQ-009)
- AC-026: a fixture project with an on-disk `sdd/project-context.yaml` that
  FAILS `validate-approval-sidecar.py` (REQ-005) is treated by every
  migrated consumer identically to "no Project Context" (compatibility
  fallback), never as an implicit `full` or `lite` selection. (REQ-009)
- AC-027: `check-hook-activation-handshake.py`, run against a live,
  correctly-installed hook guard, reports `HOOK_ACTIVE`. Run against a
  fixture guard stub that does NOT deny the canary probe, it reports
  `CAPABILITY_RUNTIME_UNAVAILABLE` — never `HOOK_ACTIVE` when denial was
  not actually observed. (REQ-010)
- AC-028: every REQ-003..REQ-007, REQ-010 script has a `.sh`+`.ps1` test
  twin registered directly in `tests/run-all.sh`/`.ps1` (self-registration
  grep), with its `.github/workflows/test.yml` step staged under
  `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  + a `MANIFEST.sha256` entry, mirroring epic-159-pillar-c's AC-027
  three-part proof shape (staged-candidate / live-unchanged /
  post-copy-registered). (REQ-011)
- AC-029: no suite this epic adds invokes a real LLM, `gh`, or `sdd-sudo`;
  every mktemp fixture root is `pwd -P`-normalized immediately after
  creation (macOS `$TMPDIR` symlink resilience, matching
  `tests/lib/loop-driver.sh:124`'s established pattern); no possibly-empty
  bash array is expanded under `set -u`. (REQ-011)

## Field Definitions

- `workflow.spec_profile` / `workflow.artifact_layout` /
  `workflow.capability_enforcement` (REQ-001) — the three independent,
  single-valued axes ADR-0016 defines; `project-context.yaml.workflow` is
  their sole source of truth once the file exists and validates
  (REQ-005/REQ-009).
- `context_sha256` (REQ-004, REQ-005) — the field name ADR-0019's own JSON
  example uses; reused literally (not renamed) for both the project-context
  sidecar and the provider-bindings sidecar, per ADR-0019's "and,
  identically" instruction — it names "the sha256 of the content file this
  sidecar approves", not specifically "project context" in the
  provider-bindings case.
- `effective_at` (REQ-004, REQ-006) — new field, not present in ADR-0019's
  literal JSON example; introduced because decision doc §9 v2's
  solo-maintainer-cooldown path requires an HMAC-signed effective time the
  validator can compare against "now" (the direct sidecar-level analogue of
  `SDD_SUDO`'s `issued-epoch`/`expires-epoch` fields, INV-003). Null when no
  cooldown applies (two-person path, or a non-policy-weakening change).
- `two_person_required` / `cooldown_hours` (REQ-006) — the detector's
  machine-readable verdict fields; `cooldown_hours` is always `24` when
  present (decision doc §9 v2's stated constant, reusing `SDD_SUDO`'s TTL
  ceiling, INV-003), never a configurable value in Foundation.
- `approver registry` / `sdd/approver-registry.yaml` (REQ-006, OQ-001) — a
  new, protected (REQ-007) file listing real registered approver identities;
  its own integrity is load-bearing for REQ-006's two-person/solo-cooldown
  branch, so it is added to `guard-invariants` alongside the sidecars, not
  left agent-writable (an agent-writable registry would let an agent shrink
  it to defeat the two-person requirement).
- `human-copy procedure` (REQ-007, REQ-009, REQ-011; ADR-0011; INV-011) —
  the epic-159-pillar-c-precedent staging shape: an agent renders corrected
  content to `specs/epic-189-a1-project-context/human-copy/<path>` with a
  `MANIFEST.sha256` entry; a human runs `cp` and verifies the SHA-256. This
  epic does NOT extend or reuse `apply-protected-files.ps1`
  (INV-011 — that tool is pinned to its own frozen bootstrap inventory).
- `CAPABILITY_RUNTIME_UNAVAILABLE` (REQ-010; decision doc §7 v2) — the
  named stop condition when the hook-activation handshake cannot observe a
  denial; distinct from any Capability-mode-inactive state (ADR-0016's
  `disabled-legacy`), which is a normal, expected condition for a project
  with no Project Context, not an error.

## Roles and Permissions

- Agent: authors every new schema, script, and test file this package
  specifies (a future implementation session) directly — none of
  `contracts/project-context.schema.json`,
  `contracts/provider-bindings.schema.json`,
  `contracts/approval-sidecar.schema.json`,
  `canonicalize-sdd-yaml.{py,sh,ps1,js}`,
  `generate-approval-sidecar.{py,sh,ps1}`,
  `validate-approval-sidecar.{py,sh,ps1}`,
  `detect-policy-weakening.{py,sh,ps1}`,
  `check-hook-activation-handshake.{py,sh,ps1}`, or their test twins is
  R-10-protected at authoring time. The agent does NOT write
  `sdd/project-context.approval.json`, `sdd/provider-bindings.approval.json`,
  or `sdd/approver-registry.yaml` directly (REQ-007/REQ-008 — full deny, no
  partial permission); it does NOT sign any sidecar (REQ-004 — signing
  requires a human/CI principal holding `SDD_CONTEXT_KEY`, which an agent is
  never given, matching the THREAT-MODEL principle ADR-0019 cites for
  `SDD_EVIDENCE_KEY`/`SDD_SUDO`). For every already-protected file this
  epic's tasks must edit (`guard-invariants.json`,
  `generate-guard-invariants.py`, the four `generated/guard_invariants.*`
  files, `plugins/sdd-ship/skills/ship/SKILL.md`,
  `plugins/sdd-lite/skills/lite-spec/SKILL.md`,
  `.github/workflows/test.yml`), the agent stages corrected content under
  `specs/epic-189-a1-project-context/human-copy/` only.
- Human maintainer: runs `cp` for every staged human-copy candidate,
  verifying each SHA-256 against `MANIFEST.sha256` before the corresponding
  task can be marked Done; holds `SDD_CONTEXT_KEY` (or its file/home-path
  form) and runs `generate-approval-sidecar` to actually sign Project
  Context and Provider Binding changes; is the sole registered identity in
  `sdd/approver-registry.yaml` (or one of several); approves specs and
  tasks; actually runs `spec-review-loop`/`impl-review-loop` against this
  package in a later session (INV-008/OQ-003).
- CI: runs `generate-guard-invariants.py --check`,
  `check-workflow-state.{sh,ps1}`, and `tests/validate-repository.ps1` on
  every push, per the existing 3-OS matrix (INV-007); once REQ-011's
  human-applied `test.yml` staging lands, also runs every new suite this
  epic adds on that same matrix.

## Main Workflows

1. A human authors `sdd/project-context.yaml` and `sdd/provider-bindings.yaml`
   by hand or via a future bootstrap-interviewer capability-interview phase
   (Epic A6/A2 concern, not built here), conforming to REQ-001/REQ-002's
   schemas.
2. The human runs `generate-approval-sidecar` (REQ-004) with
   `SDD_CONTEXT_KEY` resolvable, supplying `--approver` (and, when
   `detect-policy-weakening` (REQ-006) reports `two_person_required: true`,
   a second human's `--approver` too); the tool computes `context_sha256`
   via REQ-003, and (for a non-policy-weakening or two-person-approved
   change) signs immediately, or (for a policy-weakening, solo-approver
   change) sets `effective_at` to now+24h and signs.
3. A consuming skill (a future Epic A2/A5/A9 concern for most call sites;
   REQ-009's track-selection migration for the one call site this epic
   wires) calls `validate-approval-sidecar` (REQ-005) before trusting the
   content file; a validation failure is treated as "no Project Context"
   (fail-closed compatibility fallback), never as an implicit selection.
4. Before trusting Capability Mode at all, the calling skill runs
   `check-hook-activation-handshake` (REQ-010); a non-`HOOK_ACTIVE` result
   stops with `CAPABILITY_RUNTIME_UNAVAILABLE`, never a silent legacy-mode
   fallback.
5. A maintainer proposing a policy-weakening edit to `project-context.yaml`
   runs `detect-policy-weakening` (REQ-006) against the working-tree
   candidate before requesting sign-off; the returned verdict determines
   whether a second approver is required or a 24-hour cooldown applies.
6. Implementation of this epic's own new scripts stages every protected-file
   edit (guard-invariants registration, `PLUGIN-CONTRACTS.md`'s protected
   consumers, `.github/workflows/test.yml`) under
   `specs/epic-189-a1-project-context/human-copy/`; a human applies each via
   `cp` + SHA-256 verification (Roles and Permissions, above) before the
   corresponding task is marked Done.

## Edge Cases

- A `project-context.yaml` that parses as valid YAML 1.1 but contains an
  anchor, alias, custom tag, or duplicate key must be REJECTED by the
  canonicalizer (REQ-003/AC-005), not silently accepted with
  implementation-defined anchor-resolution behavior — this is the exact
  Blocker-adjacent surface ADR-0019's Context section discusses (a forged
  document that canonicalizes ambiguously could let an attacker's intended
  interpretation diverge from a human reviewer's).
- Byte-identical-except-for-line-endings YAML (CRLF vs. LF) must canonicalize
  to an identical hash — covered by the existing `.gitattributes`
  normalization (INV-014) PLUS the canonicalizer's own YAML-parse-based
  approach (parsing then re-serializing removes source line-ending
  sensitivity entirely, a stronger guarantee than `.gitattributes` alone).
- A sidecar whose `context_sha256` matches the live content file but whose
  `hmac` was computed under a DIFFERENT (e.g. rotated) key must fail
  validation (REQ-005/AC-014) — hash match alone is never sufficient.
- A policy-weakening change to `capability_enforcement` bundled in the SAME
  commit as an unrelated tightening change to `paths.include` must still be
  classified `policy_weakening: true` overall (any one weakening category
  present is sufficient) — the detector does not average or net weakening
  and tightening changes against each other.
- `sdd/approver-registry.yaml` itself changing (a registered identity added
  or removed) between `detect-policy-weakening`'s verdict and
  `validate-approval-sidecar`'s later check must be re-derived fresh at
  validate time, never trusted from a cached verdict recorded at generation
  time (REQ-006's "re-derived from the same registry, never trusted from the
  sidecar's own claim").
- A Project Context that is syntactically valid per REQ-001's schema but
  whose sidecar does not exist AT ALL (never signed) must be treated
  identically to a validation FAILURE (REQ-005/AC-026), not as an implicit,
  auto-approved default.
- The hook-activation handshake's own canary probe must never itself
  succeed in writing to the probed path, even transiently, before observing
  denial — REQ-010's probe targets a path that does not need to exist and
  is denied on the write-intent check alone (matching
  `_is_protected_gate_file`'s path-suffix-only matching, INV-006 — no
  content is ever actually written).

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: agent write access to `project-context.yaml`/`provider-bindings.yaml` content | agent may edit content freely (REQ-001/REQ-002 are content schemas, not protected files); every content change requires a FRESH sidecar signature (REQ-004) before any consumer trusts it (REQ-005) — content editability is intentionally unrestricted, approval is not | internal source only | none identified |
| B2: agent write access to the approval sidecars and approver registry | full deny, no partial permission, no `sudo` bypass (REQ-007/REQ-008/ADR-0019 item 1/item 5); human-copy is the only legitimate change path | internal source only | none identified |
| B3: HMAC key custody | `SDD_CONTEXT_KEY`/`SDD_CONTEXT_KEY_FILE`/`~/.sdd/context-key` are never read by an agent-driven signing operation — signing is human/CI-only (Roles and Permissions); an agent may read a PUBLIC sidecar's `hmac` field (verification-only, no key needed) but never the signing key itself | internal source only | none identified |
| B4: policy-weakening self-approval | the detector's `two_person_required`/`cooldown_hours` verdict is re-derived from the protected approver registry at BOTH generation and validation time (Edge Cases, above) — an agent cannot manufacture a favorable verdict by controlling only the content file | internal source only | none identified |
| B5: track-selection fail-open risk | a Project Context that fails REQ-005 validation is treated as absent (AC-026) — never as an implicit `full` grant that could mask a downgrade, and never as an implicit `lite` grant that could weaken review requirements | internal source only | none identified |

Details deferred to a future `security-spec.md` if the impl-review gate
requests one (parent task's Task 1 file list does not name `security-spec.md`
as a required output for this package).

## Assumptions

- `PROTECTED_GATE_SUFFIXES` and the exact-match validation
  `generate-guard-invariants.py:load_and_validate` enforces (INV-006) remain
  as observed at investigation/spec time (2026-07-21); an implementer of
  this epic's tasks re-verifies both at task-start time before relying on
  the human-copy procedure, matching epic-159-pillar-c's own re-verification
  discipline.
- `sdd-hook-guard.py`'s `_is_protected_gate_file` call-site list
  (REQ-008, `sdd-hook-guard.py:1102` onward) is re-enumerated at REQ-008's
  own implementation time, since it is cited here as a snapshot, not
  re-read line-by-line for every call site in this spec-authoring pass.
- No existing script, schema, or skill in this repository already defines
  `sdd/approver-registry.yaml` or an equivalent (verified: `grep -rn
  approver-registry` across `plugins/`, `contracts/`, `docs/adr/` returns no
  match at investigation time) — REQ-006/OQ-001's new-file decision is not
  duplicating an existing mechanism.
- `plugins/sdd-lite/skills/lite-gate/SKILL.md`'s current content was not
  read for a track-selection reference during this investigation (only its
  protection status was checked); REQ-009's implementer confirms at task
  start whether it needs edits at all.
- The registry-entry conflict INV-008 documents (tasks.md's mere existence
  requiring `Spec-Review-Status: Passed` and `Impl-Review-Status: Passed`)
  is a property of `plugins/sdd-quality-loop/scripts/check-workflow-state.sh`
  as it exists today; this assumption is re-verified, not silently
  worked around, at Task 2 registration time.

## Open Questions

See investigation.md's Open Questions (OQ-001..OQ-003) for the three
unresolved items this requirements pass surfaces: the approver-registry file
location (OQ-001, resolved provisionally by REQ-006's own definition, subject
to impl-review confirmation), the `distribution_channels`/
`data_classification` array-vs-scalar shape (OQ-002, resolved provisionally
by REQ-001's array choice), and the `tasks.md`/`check-workflow-state.sh`
registration tension (OQ-003, deliberately left for human decision at Task 2
of the parent instruction, not resolved by this requirements pass).

## Risks

- Critical: an agent successfully forging a Project Context approval (hash
  match without a genuine human HMAC) would let an agent unilaterally
  activate or weaken Capability Mode enforcement for a project — this is
  exactly the Blocker ADR-0019 was written to close. Mitigation: REQ-004's
  full-write-deny-plus-external-key-HMAC design, REQ-007's protected
  registration of the verification machinery itself, and REQ-011's
  executable proof that the guard actually denies writes through every
  mutation surface (AC-023) rather than resting on construction-only
  claims.
- High: the exact-match validation `generate-guard-invariants.py` enforces
  (INV-006) means a partial or out-of-order human-copy application (JSON
  updated, generator constant not updated, or vice versa) would make
  `--check` fail in CI for EVERY subsequent, unrelated change to this
  repository, not just this epic's own work — a high-blast-radius mistake.
  Mitigation: REQ-007/AC-021 requires both files staged and verified
  together in the SAME human-copy batch, with a staged-tree `--check` proof
  before any live application.
- High: a policy-weakening detector that under-classifies a weakening change
  as non-weakening would silently skip the two-person/cooldown gate ADR-0019
  item 6 exists to enforce. Mitigation: AC-016's per-category fixture
  coverage plus AC-017's negative case (a strengthening change must NOT be
  misclassified as weakening, proving the detector is not merely
  "everything is weakening" in disguise).
- Medium: `check-hook-activation-handshake`'s canary probe, if implemented
  against a probe target that happens to already exist with real content,
  risks corrupting that content if the probe's write intent were ever
  actually applied rather than merely attempted. Mitigation: REQ-010 targets
  a path whose protection is matched on suffix alone (no existence
  requirement) and Edge Cases requires the probe to never actually write,
  even transiently.
- Medium: three independent HMAC-key-bearing mechanisms now coexist in this
  repository (`SDD_SUDO`, `SDD_EVIDENCE_KEY`, `SDD_CONTEXT_KEY`) with similar
  but not identical resolution code, risking silent behavioral drift between
  them if one is patched and the others are not. Mitigation: REQ-004
  explicitly requires byte-for-byte matching resolution/stripping behavior
  (AC-013) as an executable proof, not merely a documented convention;
  design.md records this as a candidate for future de-duplication, out of
  this epic's own scope.
- Low: `tasks.md`'s inclusion in this spec package (INV-008/OQ-003) is known
  to make `check-workflow-state.sh` fail at registration time until the real
  review gates run. Mitigation: honestly reported, not hidden, in this
  package's final report; does not block Task 1's artifact creation, since
  the parent instruction explicitly requests `tasks.md` as a Task 1
  deliverable.
