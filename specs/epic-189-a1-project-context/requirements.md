# Requirements: epic-189-a1-project-context

Spec-Review-Status: Pending
Source Issues: https://github.com/aharada54914/sdd-forge/issues/189
Epic: https://github.com/aharada54914/sdd-forge/issues/187 (tracking) /
https://github.com/aharada54914/sdd-forge/issues/188 (Epic A0, Architecture
Decisions) — Epic A1 itself
Investigation: specs/epic-189-a1-project-context/investigation.md
(INV-001..INV-015, OQ-001..OQ-003)

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
coverage. No implementation code is produced by this package. Per this
repository's Phase model (`plugins/sdd-bootstrap/skills/bootstrap/SKILL.md:88-112`;
`plugins/sdd-quality-loop/scripts/check-workflow-state.sh:681-682`;
investigation.md INV-008), `tasks.md` and `traceability.md` are Phase 2
outputs, generated only after `Impl-Review-Status: Passed` — this package
does not include them. A Draft task decomposition was authored during this
spec-authoring session and is preserved outside the repository (coordinator
decision, 2026-07-22) for reintroduction once the Phase 1 review gates
(`spec-review-loop`, `impl-review-loop`) actually pass against this
package; REQ↔Test correspondence in the interim is carried by
`acceptance-tests.md`'s own Requirement/Test-ID columns.

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
  required unique string — uniqueness across the array is NOT expressible in
  JSON Schema draft-07 alone (no native "array items' key is unique"
  predicate against a plain array-of-objects shape), so REQ-001 additionally
  requires a schema-external semantic check, run as part of REQ-005's
  content-schema validation step (both `validate-approval-sidecar.py`,
  before trusting content, and `generate-approval-sidecar.py`, before
  signing it): reject a `components` array containing two entries with the
  same `id` (case-sensitive, exact string match, checked pairwise across
  every entry, not just adjacent pairs) with a distinct, named diagnostic
  (`DUPLICATE_COMPONENT_ID`) — REQ-002 requires the identical check for
  `bindings[].id` (`DUPLICATE_BINDING_ID`); `artifact_kinds` array of string;
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
  **Cross-cutting seed-list scaffold (NEW — cross-epic addition, closes the
  "day-one unowned-path FAIL" migration gap decision doc §12 names)**: A1
  ships `contracts/project-context.template.yaml` — a schema-conformant,
  UNPROTECTED starter scaffold (distinct from an actual `sdd/*.yaml`
  instance for sdd-forge itself, which remains Epic A9/Non-goals scope;
  this template is a generic, ANY-project starter artifact, never a live
  instance for THIS repository) — whose `shared_paths` array PRE-
  POPULATES decision doc §12's own "運用上必ず増える path" cross-cutting
  seed list: `specs/**` and `reports/**` (the paths decision doc §12's own
  prose names as needing bootstrap-time cross-cutting registration) and
  `docs/**` (the path decision doc §12's own `shared_paths` YAML example
  itself declares `classification: cross-cutting`) — each entry shaped
  `{pattern: "<glob>", classification: cross-cutting}`. This closes the gap
  where a project adopting Epic A3's Reverse Coverage Gate on day one,
  with no `shared_paths` entries yet declared for its own
  always-growing, no-single-owner directories, would immediately FAIL
  every changed-path-not-owned-by-any-component check for paths no
  component was ever meant to own. Epic A3's day-one integration fixture
  consumes this template directly (a cross-epic contract this REQ records
  for A3 to rely on, not itself implement) — A1 defines the schema and
  ships the seed-populated template; A3 owns the Reverse Coverage Gate
  logic that reads it.
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
  `credentials`/`state_authority` value vocabulary), `adapter_paths`
  OPTIONAL array of glob string (NEW field, cross-epic addition — Epic A3's
  Reverse Coverage Gate Fail-6 condition, "Provider Adapter変更が Provider
  Binding未反映" (decision doc §12 Q11), needs a declared set of repository
  paths a binding's adapter implementation occupies; this schema defines the
  field only, as an optional passthrough-adjacent array with no glob-syntax
  validation beyond "array of string" — REQ-002 does not consume it itself).
  When `adapter_paths` is declared on a binding AND Epic A3's Reverse
  Coverage Gate diff touches one of its patterns, Epic A3's Fail-6 check
  requires that diff's facet-manifest revision to also reference the
  binding (this cross-epic consumption contract is recorded here so A1's
  schema and A3's gate do not silently diverge; A3 owns the actual
  diff/enforcement logic). When a binding declares no `adapter_paths` at
  all, Epic A3's Fail-6 check is NOT evaluable against that binding — A3
  treats this as a documented WARN ("adapter/binding linkage unverifiable,
  no `adapter_paths` declared"), never a silent PASS and never a hard FAIL
  this schema alone could not justify. No Capability Pack or
  Provider name may appear inside `project-context.yaml`'s own component
  fields (REQ-001) — only `provider_binding_ids` cross-references into this
  file, preserving the Capability/Provider boundary decision doc §5
  establishes.
- **REQ-003** (canonicalizer + hash generator; decision doc §18.3; INV-005,
  INV-014): a single Python implementation,
  `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py`, with thin
  `sh`/`ps1`/`js` dispatcher wrappers
  (`canonicalize-sdd-yaml.sh`/`.ps1`/`.js`) following the
  `sdd-hook-guard.sh` shape (INV-005) for RUNTIME DISPATCH ONLY. **Wrapper
  runtime resolution (revised — no PowerShell-native fallback)**: every
  wrapper (`.sh`, `.ps1`, `.js` alike) locates `python3`, else `python`, on
  `PATH` and execs `canonicalize-sdd-yaml.py "$@"` unchanged; if neither
  binary is found, the wrapper denies fail-closed with the SAME common,
  documented non-zero exit code (`CANONICALIZER_RUNTIME_UNAVAILABLE`,
  exit 3) across `.sh`/`.ps1`/`.js` — never a partial success, never a
  silently-empty-output success. Unlike `sdd-hook-guard.sh:41-50` (whose
  `.ps1` fallback path invokes a SEPARATE, fully native PowerShell
  re-implementation of the guard's own decision logic, INV-005), the
  canonicalizer has exactly ONE behavioral implementation
  (decision doc §18.3: "Python 単一実装 + sh/ps1/js の薄いラッパー...
  ランタイムごとの再実装をしない") — there is no native PowerShell
  canonicalization logic for `.ps1` to fall back TO, so `.ps1` MUST NOT
  attempt a `pwsh`/`powershell`-native reimplementation path; it dispatches
  to `python3`/`python` exactly like `.sh` and `.js` do, or fails closed.
  Given a YAML or JSON file, it: (a) parses YAML strictly per the 1.2
  **core schema** (rejecting 1.1-only `on`/`off`/`yes`/`no` boolean
  coercion), and accepts **single-document YAML only** — a multi-document
  stream (`---` document separators producing more than one parsed
  document) is rejected fail-closed with a named diagnostic
  (`MULTI_DOCUMENT_REJECTED`), never silently canonicalizing only the
  first document; (b) rejects any document containing an anchor (`&name`),
  an alias (`*name`), a custom (non-core) tag, a duplicate mapping key, OR
  a **non-string mapping key** (YAML 1.2 core schema permits non-string
  scalar keys — e.g. an integer or boolean key — which RFC 8785 JCS cannot
  represent as a JSON object key; rejected fail-closed,
  `NON_STRING_KEY_REJECTED`), exiting non-zero with a diagnostic naming the
  rejection category — never silently accepting one interpretation of an
  ambiguous document; (c) normalizes every string scalar to Unicode NFC,
  THEN re-checks mapping keys for a **post-NFC duplicate-key collision**
  (two distinct source keys that normalize to the identical NFC string,
  e.g. a precomposed vs. decomposed accented character used as two
  "different" keys) — rejected fail-closed
  (`POST_NFC_DUPLICATE_KEY_REJECTED`), since silently keeping either one
  would make the canonical hash depend on which the parser happened to
  keep; (d) rejects any numeric scalar that is non-finite (YAML's
  `.inf`/`-.inf`/`.nan`) or outside the IEEE-754 double-precision
  representable range, fail-closed (`NUMBER_OUT_OF_RANGE_REJECTED`) — RFC
  8785 JCS numeric formatting is defined only for finite,
  double-representable values; (e) serializes the parsed structure to
  canonical JSON strictly per **RFC 8785 (JCS)** — object keys sorted by
  UTF-16 code unit, numbers formatted per JCS's ECMAScript-`Number`-based
  rule (the shortest round-tripping decimal representation a double can
  produce, NOT a bespoke "integers never carry an exponent" rule — RFC 8785
  §3.2.2.3 governs exponent presence, this REQ does not restate or narrow
  it), strings escaped per JCS's minimal-escaping rule, no insignificant
  whitespace; (f) computes and emits the SHA-256 hex digest of the
  canonical UTF-8 byte sequence, plus the canonical bytes themselves (for
  HMAC preimage construction, REQ-004). **Output/exit contract**: default
  invocation writes the canonical UTF-8 bytes to stdout byte-exact (no
  trailing newline the canonicalization step itself did not produce, no
  interleaved diagnostic text on stdout — diagnostics go to stderr only)
  and exits 0; `--hash-only` writes `sha256:<hex>\n` to stdout and exits 0;
  any rejection category exits non-zero (a dedicated, stable exit code per
  category, documented in the script's own `--help` and in design.md's
  API/Contract Plan) with the diagnostic on stderr, and writes NOTHING to
  stdout. This script is the single implementation every other new script
  in this epic that needs canonical bytes or a canonical hash calls into —
  none reimplements YAML canonicalization independently.
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
  convention at `guard_invariants.py:3`). **`approver` identity binding
  (closes a same-identity two-person bypass)**: `primary_approval.approver`
  and `second_approval.approver` (when present) are each the **immutable
  `id` field of an entry in `sdd/approver-registry.yaml` (REQ-006)** —
  never a free-text display name, and never the registry's `name` field.
  Binding the signed field to the registry's immutable identity key (rather
  than a mutable display name) is what makes "are these two approvals from
  two DIFFERENT people" a well-defined, checkable question: when both
  `primary_approval` and `second_approval` are present,
  `generate-approval-sidecar.py` REFUSES to sign (before any hashing/HMAC
  work) if `primary_approval.approver == second_approval.approver` (same
  registry id presented twice) — a distinct, named diagnostic
  (`DUPLICATE_APPROVER_IDENTITY`), never silently accepted as satisfying a
  two-person requirement. **HMAC preimage** (ADR-0019 v2.1, decision doc
  §18.3 v2.1): the approval object with the `hmac` field excluded, passed
  through REQ-003's canonicalizer (YAML/JSON parse → NFC → JCS), producing
  a UTF-8 byte sequence; the HMAC-SHA256 of that byte sequence, keyed by the
  resolved external key, is the `hmac` field's value — this preimage
  includes EVERY other field (`schema`, `context_sha256`, both approval
  objects' every sub-field, `effective_at`), not merely the fields REQ-011's
  existing round-trip test happens to vary; REQ-011 requires a golden known-
  answer vector plus a per-field mutation proof (AC-036/TEST-036) that
  omitting or altering any one non-`hmac` field changes the computed HMAC,
  closing the gap where a generator/validator pair that both independently
  mis-implemented the preimage (e.g. both silently dropped
  `effective_at`) would still round-trip-verify against each other.
  **Key resolution** follows the same four-step order as `SDD_SUDO`/
  `SDD_EVIDENCE_KEY` (INV-003, INV-004): env `SDD_CONTEXT_KEY` → env
  `SDD_CONTEXT_KEY_FILE` (file read, BOM/whitespace-stripped) →
  `<HOME>/.sdd/context-key` → no key (fail-closed: signing is impossible,
  never silently unsigned).
  **Signer output contract (revised — no live-path write; closes the
  gap between "sidecar full-write-deny" and "how a legitimate signature
  ever reaches the live sidecar path")**:
  `plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py`
  (+ `.sh`/`.ps1` wrappers) is the human/CI-invoked tool that computes
  `context_sha256` (via REQ-003 against the live content file), accepts
  `--approver`, `--second-approver` (registry ids), `--status`, and (only
  for the solo-cooldown path) an `--effective-at` value, and signs — but it
  **NEVER writes to the live `sdd/*.approval.json` path** (that path is
  itself `PROTECTED_GATE_SUFFIXES`-denied to every write source, REQ-007/
  REQ-008, including the signer's own process, which runs as an
  unprivileged human/CI shell, not as a tool call with guard-bypass
  authority). Instead it writes exactly two artifacts to a
  human-designated staging directory (`--stage-dir`, default
  `sdd/.staging/<schema-id>/<nonce>/`): (a) the fully-signed candidate
  sidecar JSON (the same shape REQ-004's schema defines), and (b) a
  `MANIFEST.sha256` entry recording the candidate's own SHA-256 and a
  fresh, single-use `nonce` (a 32+ hex-character random value, generated by
  the signer itself, embedded in the manifest, never reused across
  invocations — its purpose is solely to make each staged candidate
  distinguishable from a stale or replayed prior staging output, not a
  cryptographic input to the HMAC itself). The signer's own process exit
  code and stdout report the staged path and manifest entry; it never
  claims the live sidecar has been updated. **Publishing the staged
  candidate to the live path is REQ-007's human-copy-applied anchored
  publisher (see REQ-007's generalization of ADR-0011), run only after**:
  (i) `validate-approval-sidecar.py` (REQ-005) independently verifies the
  STAGED candidate (hash match, HMAC, approver identities, `effective_at`)
  — the publisher refuses to apply a staged candidate that fails REQ-005's
  own validator, closing the gap where "signed" and "valid" could
  silently diverge; (ii) the human/CI operator visually confirms the
  manifest SHA-256. **Failure/rollback**: if signing succeeds but staging
  write fails partway (e.g. disk full after the sidecar JSON is written but
  before `MANIFEST.sha256` is updated), the tool leaves NO partial artifact
  at the final staged path — it writes to a temp path inside the same
  staging directory first, then renames both files into place only after
  both are fully written and re-hashed, mirroring REQ-007's anchored-
  publisher temp-then-rename discipline at the staging layer itself; a mid-
  write failure is recoverable by simply re-running the signer (idempotent:
  a fresh nonce, a fresh staging subdirectory, no live state to roll back).
  This tool itself never runs with agent-accessible credentials as part of
  an agent-driven workflow; an agent may author and test the SCRIPT, but the
  signing operation always requires a human or CI principal holding
  `SDD_CONTEXT_KEY`.
- **REQ-005** (approval validator; ADR-0019, decision doc §9 (Q8)):
  `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` (+
  `.sh`/`.ps1`) verifies, for a given content file + sidecar pair, in
  order, short-circuiting on the FIRST failure with that failure's own
  named diagnostic: (0) **content-schema conformance** — the content file
  must parse under REQ-003's canonicalizer (rejecting every category REQ-003
  rejects: anchor/alias/tag/duplicate-key/multi-document/non-string-key/
  post-NFC-duplicate-key/out-of-range-number) AND validate against
  REQ-001's or REQ-002's JSON Schema AND pass the REQ-001/REQ-002
  duplicate-`id` semantic check (`DUPLICATE_COMPONENT_ID`/
  `DUPLICATE_BINDING_ID`) — any one of these failing is a hard validation
  failure, checked BEFORE hash comparison, never skipped because "the hash
  matches anyway"; (1) hash
  match — `context_sha256` equals REQ-003's canonical hash of the live
  content file, exactly (byte-for-byte content binding); (2) HMAC
  verification — recompute the REQ-004 preimage, HMAC with the resolved
  `SDD_CONTEXT_KEY`, and `hmac.compare_digest` against the stored `hmac`
  (constant-time, mirroring `sdd-hook-guard.py:480`); no key available is a
  hard failure, never a skip; (3) approver-identity check —
  `primary_approval.approver` (and `second_approval.approver` when present)
  must each be a registered `id` in `sdd/approver-registry.yaml` (REQ-006)
  — an unregistered approver id fails validation even with a structurally
  valid HMAC; **AND, when `second_approval` is present,
  `primary_approval.approver` MUST NOT equal `second_approval.approver`**
  (the same registry id presented twice is rejected as
  `DUPLICATE_APPROVER_IDENTITY`, the identical check REQ-004's generator
  applies at signing time, re-applied independently at validation time so
  a sidecar forged or hand-edited to carry two identical approver ids after
  signing — e.g. by an operator error in a future signing tool, not
  necessarily this one — cannot pass validation merely because its HMAC
  happens to still verify against altered-but-key-matching content); (4)
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
  (+ `.sh`/`.ps1`) compares a baseline and a candidate `project-context.yaml`
  (or `provider-bindings.yaml`) and classifies the diff against the exact
  **nine** weakening categories decision doc §9 names, normalized here (this
  supersedes any prior draft of this REQ that implied six-implemented/
  four-N/A or any other split — the canonical count is nine categories,
  of which three are implementable against A1's schema today and six are
  documented N/A, below):
  1. `capability_enforcement` weakened (`required`→`advisory`) —
     **implemented**, direct field comparison.
  2. A Capability removed from a component — **documented N/A, fail-closed,
     with a forced handoff gate**: A1 defines no canonical Capability
     reference field anywhere in its schema (REQ-001 defines
     `artifact_kinds`/`runtime_classes` as free-text classification arrays,
     not a Capability reference — treating their shrinkage as a proxy for
     "Capability removed" was a prior draft's own invented policy, not a
     Foundation decision, and is REMOVED by this revision). Until the Epic
     that introduces a canonical Capability reference field (A2/A5) lands,
     this category is N/A for every diff, reported as such in the
     detector's diagnostic output; the handoff is a Done-condition
     dependency this epic records for that future epic, not something A1
     approximates with an unrelated field.
  3. A component's effective path ownership narrows — **implemented**,
     via the deterministic glob-coverage algorithm design.md's Policy-
     weakening-categories section defines (set-inclusion over each glob's
     literal scope prefix, covering pattern REMOVAL, pattern REPLACEMENT
     at an unchanged pattern count, and `paths.exclude` growth — not merely
     "the array got shorter"); boundary cases are enumerated as AC-040/
     TEST-040.
  4. Public distribution de-scoped — **documented N/A, fail-closed, with a
     forced handoff gate**: REQ-001's `distribution_channels` is a free-text
     string array with NO Foundation-fixed "public" vocabulary (no epic has
     yet defined which literal channel strings denote public distribution
     vs. any other classification) — treating "any entry removed" as
     de-scoping public distribution was a prior draft's own invented
     semantics with no textual basis, and is REMOVED by this revision.
     Until the epic that fixes a canonical public/private channel
     vocabulary lands, this category is N/A for every diff, same
     handoff-gate treatment as category 2.
  5. Criticality lowered — documented N/A (Foundation reserves the field
     name for Epic A2; no such field exists in REQ-001's schema).
  6. Provider allowlist widened — documented N/A (no allowlist field
     exists in REQ-002's skeleton).
  7. Production write-path declaration changed — documented N/A (no such
     field exists until a future epic).
  8. Required Gate removed — documented N/A (Gate declarations are Epic A2
     scope).
  9. `workflow.spec_profile` moving from `full` to `lite` — **implemented**,
     direct field comparison.

  A change matching zero of the three implemented categories is NOT
  policy-weakening (tightening or lateral changes proceed under
  single-approval); the six N/A categories NEVER contribute a `true`
  verdict in A1 (there is no field for them to inspect), and are reported
  as explicit `N/A` entries in the detector's diagnostic output every run,
  never silently omitted.

  **CLI baseline/candidate contract (closes the "no defined baseline, no
  re-derivation API" gap)**: `detect-policy-weakening.py --candidate <path>
  [--baseline <path>] [--baseline-repo-path <repo-relative-path>]`.
  `--candidate` is REQUIRED — the working-tree (or staged) file being
  evaluated. **Default baseline resolution (no `--baseline` given)**: the
  tool resolves the baseline ITSELF, internally, as `git show
  HEAD:<repo-relative-path-of-candidate>` (or `--baseline-repo-path`'s
  value, when the file was renamed and the OLD path differs from the
  candidate's current path) — it is NEVER handed a baseline blob by the
  caller in this, the only mode REQ-004's generator and REQ-005's validator
  are permitted to invoke. `--baseline <path>` (an explicit override to an
  arbitrary local file) exists ONLY for this script's own fixture-driven
  tests (REQ-011) — **REQ-004's generator and REQ-005's validator MUST
  invoke this script WITHOUT `--baseline`** (default git-HEAD resolution
  only), which is what makes the "pass the candidate as its own baseline to
  erase the diff" attack structurally unavailable in the only code path
  those two tools actually use: an attacker controlling the candidate file
  content cannot also rewrite what `git show HEAD:<path>` returns without
  rewriting committed git history (a different, already-out-of-scope threat
  class, not one this detector needs to additionally defend against).
  **First-time creation** (no blob for `<repo-relative-path>` exists at
  `HEAD`, verified via `git cat-file -e`): baseline is treated as absent,
  and the detector reports `policy_weakening: false` for every category —
  there is no prior declaration to weaken FROM — this is a documented rule
  (`FIRST_COMMIT_NOT_WEAKENING`), not a silent default. **Rename**: when
  `--baseline-repo-path` differs from the candidate's own path, the
  baseline is read from THAT path at `HEAD` (git's own rename tracking is
  NOT relied on — the caller supplies the old path explicitly). **Deletion**
  (a candidate that does not exist, or is empty) is OUT OF SCOPE for this
  detector — REQ-007/REQ-008's protected-file guard governs whether a
  content file may be deleted at all; this detector's `--candidate` must
  resolve to a schema-valid document or the tool exits non-zero
  (`CANDIDATE_NOT_SCHEMA_VALID`) rather than emitting any weakening
  verdict. **Generator/validator never trust an externally-supplied
  verdict**: `generate-approval-sidecar.py` and `validate-approval-sidecar.py`
  never accept a pre-computed weakening verdict as an input flag/file — each
  invokes `detect-policy-weakening.py` itself, in-process against the SAME
  default (git-HEAD) baseline resolution described above, at the moment it
  needs the verdict (generation time and validation time respectively) —
  never reading a verdict a prior, potentially-stale or forged invocation
  wrote to disk.

  For a change classified as policy-weakening (any ONE of the three
  implemented categories), the
  detector additionally reads `sdd/approver-registry.yaml` (REQ-007,
  protected) and outputs a machine-readable verdict: `two_person_required:
  true` when the registry lists 2 or more distinct real identities, else
  `two_person_required: false` with `cooldown_hours: 24` (reusing
  `SDD_SUDO`'s TTL constant family, INV-003) — this verdict is what
  REQ-004's sidecar-generation tool and REQ-005's validator both consult:
  generation requires `second_approval` present (not merely
  possible) AND its `approver` distinct from `primary_approval.approver`
  (REQ-004's `DUPLICATE_APPROVER_IDENTITY` check) before signing when
  `two_person_required: true`; generation sets
  `effective_at` to now+24h and permits `second_approval: null` when
  `two_person_required: false`; validation rejects a policy-weakening
  sidecar missing the approvals (or carrying duplicate approver identities)
  its own detector verdict requires, at
  validate time (re-derived from the same registry, never trusted from the
  sidecar's own claim).
- **REQ-007** (protected registration via human-copy; decision doc §9 (Q8)
  item 3; INV-006, INV-011): a single canonical manifest,
  `specs/epic-189-a1-project-context/human-copy/PROTECTED-MANIFEST.md`
  (committed alongside this spec package as the one authoritative source
  every other artifact this REQ produces is DERIVED from — never a second,
  independently-maintained count), enumerates every path this epic adds to
  `protected_gate_suffixes` in
  `plugins/sdd-quality-loop/references/guard-invariants.json`, grouped by
  the six canonical protection categories ADR-0019 item 3 names
  (canonicalizer / hash generator / approval validator / policy-weakening
  detector / resolver / generated projection):
  - Canonicalizer (4): `canonicalize-sdd-yaml.py`, `.sh`, `.ps1`, `.js`.
  - Hash generator (3): `generate-approval-sidecar.py`, `.sh`, `.ps1`.
  - Approval validator (3): `validate-approval-sidecar.py`, `.sh`, `.ps1`.
  - Policy-weakening detector (3): `detect-policy-weakening.py`, `.sh`,
    `.ps1`.
  - Hook-activation handshake (3, REQ-010 — grouped with the validator
    family for guard-invariants purposes, since it is also a verification-
    machinery script ADR-0019 item 3 covers under "and any generated
    projection"): `check-hook-activation-handshake.py`, `.sh`, `.ps1`.
  - Sidecar/registry data files (4): `sdd/project-context.approval.json`,
    `sdd/provider-bindings.approval.json`, `sdd/approver-registry.yaml`,
    and `sdd/.hook-canary-sentinel` (REQ-010's redesigned handshake target
    — a dedicated, never-real-content placeholder path registered here so
    the handshake's canary tool-call has a genuinely protected, harmless
    target distinct from the live sidecars, closing the "canary write
    truncates/corrupts the real approval sidecar" gap a prior draft left
    open).
  - **Resolver (reserved, 3) and generated projection (reserved, 1) —
    NEW, closes the "guard-invariants has no entry for the two categories
    ADR-0019 item 3 also names" gap**: A1 does not build a Capability
    Resolver or its generated projection (Non-goals — Epic A2/A5 scope),
    but ADR-0019 item 3 lists them as required protection categories
    alongside the four this epic DOES build, so A1 reserves their canonical
    path pattern now rather than leaving the category entirely
    unaddressed until a future epic accidentally introduces an
    unprotected one: `plugins/sdd-quality-loop/scripts/resolve-project-context.{py,sh,ps1}`
    (resolver, reserved) and
    `plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json`
    (generated projection, reserved, "Do not edit" header convention
    matching `generated/guard_invariants.*`). These reserved paths are
    added to `protected_gate_suffixes` NOW (the generator's own
    `_validate_repo_path` checks path SHAPE only, regardless of on-disk
    existence, design.md's Protected-File Statement) — a **forced handoff
    gate**: the epic that actually introduces the Capability Resolver or
    its generated projection (A2/A5) MUST use these exact reserved names,
    or amend this reservation via its own spec's explicit `guard-invariants`
    diff; it may not introduce a parallel, differently-named, unprotected
    resolver/projection file and treat this reservation as satisfied by
    proximity alone.

  The manifest's total entry count (**20 concrete + 4 reserved = 24**, at
  spec-authoring time) is a DERIVED value the manifest itself enumerates,
  never a separately-asserted literal elsewhere in this package (a prior
  draft's "five new protected files"/"sixteen `EPIC_A1_TARGETS`"/"nineteen
  paths" language, each independently wrong, is retired — every other
  section of this package that needs the count reads it FROM this
  manifest). `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`
  is extended in the SAME change (INV-006 — the generator's
  `expected_protected` is an exact-match hardcoded tuple, so a JSON-only
  edit fails `--check`) with a new `EPIC_A1_TARGETS` constant whose entries
  are generated FROM the manifest (a code-generation or hand-transcription
  step that a task-level test asserts stays in sync with the manifest,
  never hand-maintained independently of it). The four generated
  `guard_invariants.*` files (already protected) are regenerated to reflect
  the updated inventory. **Every file this REQ touches
  (`guard-invariants.json`, `generate-guard-invariants.py`, the four
  generated files) is itself R-10-protected before this change lands**, so
  every edit is staged under
  `specs/epic-189-a1-project-context/human-copy/` with a `MANIFEST.sha256`
  entry per file, per the epic-159-pillar-c precedent (INV-011) — never a
  direct write. **Human-copy publisher contract (revised — generalizes
  ADR-0011's anchored-copy guarantee to sh/ps1, closes the "simple `cp`
  loses TOCTOU/reparse/hard-link defenses" gap)**: every human-copy
  application this epic's tasks stage (this REQ's guard-invariants batch,
  REQ-004's sidecar-signature publication, REQ-009's `PLUGIN-CONTRACTS.md`/
  skill-file edits, REQ-011's `.github/workflows/test.yml` registration)
  is applied through a publisher providing the SAME guarantees
  ADR-0011's Windows PowerShell `AnchoredCopySession` provides, generalized
  to a cross-platform `sh`/`ps1` pair
  (`apply-human-copy.{sh,ps1}`, new, itself R-10-protected — staged in this
  epic's own human-copy batch, its FIRST use is bootstrapped by a plain,
  human-verified `cp` + SHA-256 check exactly once, matching how
  `apply-protected-files.ps1` itself was originally installed, INV-011):
  (a) opens the repository root and every destination parent directory via
  a HELD handle (POSIX: an `O_DIRECTORY` fd held for the operation's
  duration; Windows: `NtCreateFile`/`OBJECT_ATTRIBUTES.RootDirectory` per
  ADR-0011) and resolves every relative path one segment at a time through
  that held handle (handle-relative traversal — never a fresh path-string
  re-open between check and use); (b) re-hashes the staged source bytes
  through the SAME held source handle immediately before writing, and
  writes to a new EXCLUSIVE temporary file in the held destination-parent
  handle, re-hashing the temporary's own bytes after the write completes
  and before any rename; (c) publishes only via an ATOMIC rename
  (`renameat`-family on POSIX, `SetFileInformationByHandle(FileRenameInfo)`
  on Windows) using the held destination-parent handle — **no path-based
  copy fallback is ever permitted** on any platform, matching ADR-0011's
  own "No path-based copy fallback is permitted" constraint verbatim; (d) a
  validation, preparation, or capability-preflight failure occurs BEFORE
  any live replacement, with every held temporary handle cleaned up on
  failure — mirroring ADR-0011's Consequences section's rollback
  discipline generalized to the sh/ps1 pair. REQ-011 requires an executable
  `.sh`+`.ps1` test twin for `apply-human-copy` proving: pre-existing
  symlink/reparse-point denial at both the repo-root and destination-parent
  handles, hard-link-alias non-propagation (replacing one hard-linked name
  does not mutate content visible through the other), held-handle
  substitution resistance (renaming/deleting the source or destination
  parent between validation and publish does not redirect the copy), and
  no live-path mutation on any preparation-stage failure (AC-033/TEST-033).
- **REQ-008** (hook-guard extension — sidecar full-write-deny; ADR-0019 item
  1): `sdd-hook-guard.py`'s `_is_protected_gate_file` already denies writes
  to any suffix in `_PROTECTED_GATE_SUFFIXES` (INV-006), so once REQ-007's
  registration lands, `sdd/project-context.approval.json`,
  `sdd/provider-bindings.approval.json`, `sdd/approver-registry.yaml`, and
  `sdd/.hook-canary-sentinel` (REQ-010's redesigned handshake target,
  REQ-007) are automatically covered by the EXISTING protected-file deny
  path — no new deny logic is required in the guard's decision code. This
  REQ's own scope is: (a) confirm, with an executable **full matrix**
  (closes the "one surface tested per basename is not proof for the other
  eleven" gap) — **4 basenames × every mutation surface
  `_is_protected_gate_file` is consulted from × {`sudo` active, `sudo`
  inactive}** — that a write
  attempt against each of the four protected basenames is denied
  through EVERY call site, not merely one representative surface per
  basename. The full call-site set (verified at implementation time against
  `sdd-hook-guard.py:1102,1110,1133,1136,1207,1210,1234,1237,1255,1258,1471,1486`,
  12 sites) is enumerated in design.md's Test Strategy as a table with one
  row per (basename × call-site × sudo-state) combination — 4 × 12 × 2 = 96
  cells, each an independent test assertion, not a single "denied somewhere"
  proof. The 12 call sites, grouped by tool surface (verified at
  implementation time, this grouping is a snapshot, not load-bearing on
  exact line numbers): direct `Edit`/`Write`/`MultiEdit` `file_path` checks;
  Bash/shell command-string redirect/`cp`/`mv`/`rm`-target parsing (multiple
  call sites for different shell-verb patterns); `apply_patch` envelope
  `*** Update/Add/Delete File:` target parsing; any indirect-mutation
  surface identified at implementation time (e.g. an `Edit` whose
  `old_string`/`new_string` pair targets the protected path via a symlink or
  relative traversal) — every one of the 12 gets its own row, never
  collapsed into "the same tool-call surface" shorthand a prior draft of
  this REQ used; (b) `sudo` never bypasses ANY of the 96 cells (never-bypass
  — ADR-0019 item 5, matching `SDD_SUDO`'s existing never-sudo class) —
  the sudo-active column is not merely a spot check, it repeats the FULL
  12-call-site sweep under an active, locally-fixture-signed `SDD_SUDO`
  token; (c) since `sdd-hook-guard.py`/`.sh`/`.ps1`/`.js` are
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
  fallback for "no Project Context" only (ADR-0023 item 2).

  **Presence/validity semantics (revised — closes the downgrade-via-
  induced-validation-failure gap)**: every migrated consumer's FIRST check
  is whether `sdd/project-context.yaml` is **physically present on disk**
  (`os.path.isfile`/equivalent, not "did it validate") — this is the ONLY
  condition under which the compatibility fallback (old CLI-flag-first
  order, ADR-0023 item 2) applies. When the file is physically present, the
  consumer NEXT runs REQ-005's validator (content-schema conformance, hash
  match, HMAC, approver identity, `effective_at`) against it:
  - **Validation PASSES** → the Project-Context-present rule applies
    (`--lite` against a `full` Context is an explicit error-stop; `--full`
    against `lite` promotes; both no-op cases pass through).
  - **Validation FAILS for any reason** (missing sidecar entirely, content
    schema violation, canonicalizer rejection, hash mismatch, HMAC
    mismatch/rotated-key mismatch, unregistered or duplicate approver
    identity, not-yet-effective `effective_at`) → the consumer STOPS with a
    named, non-silent error (`PROJECT_CONTEXT_INVALID`, Field Definitions
    below) — it NEVER falls through to the compatibility fallback and NEVER
    proceeds under an implicit `full` or `lite` selection. This is the
    load-bearing distinction a prior draft of this REQ collapsed: "the file
    exists but its signature is broken" (tampering, expired cooldown,
    rotated key, a stale/forged sidecar) is a SECURITY-RELEVANT event a
    caller could otherwise induce (by corrupting or replay-attacking the
    sidecar) to force the OLD, weaker CLI-flag-first behavior back on for a
    project that has explicitly opted into a Project Context — it is
    intentionally NOT equivalent to "no Project Context was ever declared."
    Only the file's OWN PHYSICAL ABSENCE reaches the compatibility
    fallback; every other failure mode is a stop, matching ADR-0023's
    §1/§2 "when a Project Context exists" / "when no Project Context
    exists" wording literally — a validation failure against an existing
    file is neither of those two ADR-0023 branches, so it gets a third,
    explicit outcome instead of being folded into the "absent" branch.

  **Consumer enumeration and common contract suite (revised — closes the
  "some consumers get the 4-case matrix, most don't" partial-migration
  gap)**: every current CLI-flag consumer is enumerated exhaustively per
  ADR-0023's own "no partial migration" warning, confirmed at
  investigation time (INV-002) and re-confirmed at implementation time:
  `plugins/sdd-ship/skills/ship/SKILL.md:76-117` (protected — human-copy),
  `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md:80-132` (unprotected —
  direct edit),
  `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:147,159,199`
  (unprotected — direct edit), `plugins/sdd-lite/skills/lite-spec/SKILL.md:48`
  (protected — human-copy), and
  `plugins/sdd-lite/skills/lite-gate/SKILL.md` — **resolved (was an open
  implementer-verifies item in a prior draft): confirmed at spec-authoring
  time to read `spec_profile: lite`/track-selection state
  (`plugins/sdd-lite/skills/lite-gate/SKILL.md` branches on the same
  `AGENTS.md` marker `lite-spec/SKILL.md:48` does, to decide whether its own
  risk-upgrade gate applies) and confirmed unprotected — it is IN SCOPE for
  direct-edit migration, not deferred to implementation time.** Every one of
  these five consumers — not merely `sdd-ship` and one fallback case, as a
  prior draft's AC-025/AC-026 exercised — is migrated against the IDENTICAL
  common contract suite REQ-011 requires: (i) Context `lite` + `--full` →
  promote; (ii) Context `lite` + `--lite` → no-op; (iii) Context `full` +
  `--lite` → error-stop; (iv) Context `full` + `--full` → no-op; (v) no
  Project Context + either flag → compatibility fallback (old order)
  unchanged; (vi) Context file present but `validate-approval-sidecar.py`
  fails → `PROJECT_CONTEXT_INVALID` error-stop (this REQ's revised
  semantics, above) — six cases, per consumer, not a 2-case spot check on
  one consumer generalized by assertion to the other four.
- **REQ-010** (hook-activation handshake, REDESIGNED; decision doc §7 v2
  "Hook 稼働ハンドシェイク"): a prior draft of this REQ had the standalone
  `.py`/`.sh`/`.ps1` script itself perform a child-process file-write probe
  against the live sidecar path and inspect its OWN result. **This is
  closed as unable to observe the property it claims to prove**:
  `sdd-hook-guard.py` is invoked BY THE HOST RUNTIME as a `PreToolUse` hook
  — the host intercepts a proposed tool call the AGENT SESSION itself is
  about to make (a JSON payload `{tool_name, tool_input}` piped to the
  guard on stdin/`PAYLOAD`, `sdd-hook-guard.py:1401-1436`), and the guard's
  decision (exit code in `--emit exit` mode; `{"permissionDecision": ...}`
  JSON in `--emit copilot` mode, `sdd-hook-guard.py:34-36`) determines
  whether the host actually executes that tool call. A subprocess a script
  spawns via ordinary file I/O (`open()`, `Write-File`, etc.) is not a
  proposed AGENT tool call at all — it never reaches the host's
  `PreToolUse` dispatch, so a standalone script's own write attempt
  "succeeding" or "failing" proves nothing about whether the host's hook is
  installed; it only proves whether the OS-level file permissions allow the
  write, which they always do (the guard's protection is a tool-mediation
  layer, not a filesystem ACL).

  **Redesigned protocol — host-side canary tool-call, challenge/response**:
  `check-hook-activation-handshake.py` (+ `.sh`/`.ps1`) NEVER itself
  performs a write attempt. It has two modes:
  - `--emit-challenge`: generates a fresh, single-use `nonce` and prints a
    machine-readable challenge (JSON: `nonce`, the canary target path —
    a dedicated **sentinel path**, `sdd/.hook-canary-sentinel`, NOT the
    live approval sidecar, Edge Cases below — and a per-runtime tool-call
    template: for Claude Code/Copilot CLI, an `Edit`/`Write` tool call with
    `file_path: sdd/.hook-canary-sentinel`; for Codex CLI, the equivalent
    `apply_patch`/shell-redirect form). The calling SKILL (the ONE call
    site this epic wires, REQ-009's migrated Track Detection entry points,
    below) instructs the AGENT SESSION ITSELF — not a nested subprocess —
    to attempt EXACTLY that one tool call, once, through its own native
    tool-call surface, and to record the RAW, verbatim result the host
    surfaces (success, or the host's own denial/error signature) to a
    plain evidence file alongside the nonce.
  - `--verify-response --nonce <nonce> --recorded-result <path> --runtime
    <claude-code|codex-cli|copilot-cli>`: reads the recorded evidence and
    applies a **per-runtime, documented expected-deny-signature check**:
    Claude Code — the recorded result must show the tool call did not
    execute and carries the guard's `--emit exit` deny signature (non-zero
    exit surfaced through the host's own tool-call-denial reporting);
    Codex CLI — the equivalent denial surfaced through Codex's
    `plugin_hooks`-mediated dispatch (if the `plugin_hooks` feature flag is
    unset, the guard is never invoked at all, so no denial signature can
    appear — this is indistinguishable from, and correctly collapses into,
    "hook not active"); Copilot CLI — the recorded result must contain the
    guard's `--emit copilot` JSON (`{"permissionDecision": "deny", ...}`);
    the well-known "Copilot subagent hook often does not fire" case
    (decision doc §7 v2) surfaces here as an ABSENT or affirmatively-allow
    `permissionDecision`, correctly triggering the non-`HOOK_ACTIVE` branch,
    not a special case. The verify step additionally checks the recorded
    evidence's `nonce` matches the challenge's own — a stale or replayed
    prior "it worked last time" recording is rejected
    (`STALE_CHALLENGE_REJECTED`), closing a cache/replay bypass a naive
    "did it ever succeed once" check would admit.
    Only when the runtime-specific deny signature is present AND the nonce
    matches does the tool report `HOOK_ACTIVE`. Any of: no recorded-result
    evidence, a nonce mismatch, a result indicating the write actually
    executed, or a result this REQ's per-runtime signature table does not
    recognize ⇒ `CAPABILITY_RUNTIME_UNAVAILABLE` (fail-closed by default —
    the burden of proof is on demonstrating denial, never on demonstrating
    non-denial) and the calling bootstrap/gate skill MUST stop Capability
    Mode rather than silently falling back to legacy mode (decision doc §7
    v2, restated verbatim: "legacy modeへ黙ってフォールバックしてはならな
    い").

  **Entry-point wiring (revised — was scoped to "the ONE call site
  REQ-009 touches"; now covers every A1-time bootstrap/track/gate entry
  point, closing the "loud claim, one narrow test" gap)**: this handshake
  is wired at the START of every one of REQ-009's five migrated consumer
  entry points (`sdd-ship`'s Track Detection, `sdd-bootstrap`'s track
  selection, `sdd-bootstrap-interviewer`'s three `spec_profile` read
  sites, `lite-spec`, and `lite-gate`) — every A1-time bootstrap/track/gate
  entry point that exists at this epic's authoring time, not a single
  representative one. **Future-entry-point contract**: any Capability-Mode-
  relevant entry point a LATER epic introduces (A2's Registry-driven gates,
  A4's Facet Manifest consumers, A5's Resolver call sites) MUST invoke this
  same handshake as its first Capability-Mode-relevant action before
  trusting `HOOK_ACTIVE`-gated behavior — this is a forced integration
  contract recorded here as a Done-condition dependency for those epics,
  not merely a suggestion; each such future epic's own Done condition
  includes its own cross-runtime E2E proof of this wiring (mirroring this
  epic's own REQ-011 requirement, below), and Epic A8's cross-runtime
  handoff suite (decision doc §7 v2) is the place ALL such wirings are
  jointly regression-tested end-to-end across the three runtimes. This
  epic's own Done condition (REQ-011) includes a per-runtime E2E case for
  each of the three runtimes against ITS OWN five wired entry points — a
  fixture-driven simulation of the challenge/response protocol (no real
  LLM session, per REQ-011's non-use declaration), not merely the
  synthetic guard-stub unit test a prior draft relied on alone.
- **REQ-011** (three-environment test coverage; decision doc §6, §7 v2;
  INV-012): every new script REQ-003..REQ-007, REQ-010 introduces gets a
  `.sh`+`.ps1` test-twin pair under `tests/`, registered directly in
  `tests/run-all.sh`/`.ps1` (both unprotected, INV-012), with the
  `.github/workflows/test.yml` step registration staged via human-copy
  (protected, INV-011). Mandatory cases across the suites (expanded — this
  list supersedes any prior draft's shorter list; each bullet is its own
  independent fixture/assertion, not a shared "one case covers the
  category" shortcut; new AC/TEST numbers AC-030..AC-041/TEST-030..TEST-041
  are introduced below alongside revisions to several existing AC-00x/
  TEST-00x pairs — Acceptance Criteria, below, is the authoritative
  numbering):
  REQ-003's dual-runtime hash-equality fixture (the `.py`-canonical and the
  `.js` wrapper — where Node is available — produce an identical SHA-256
  for the same fixture file; the `.sh`/`.ps1` wrappers are dispatch-only
  and are proven to call the same `.py`, not a divergent reimplementation,
  AC-009/TEST-009); REQ-003's accepted-domain boundary vectors
  (multi-document rejection, non-string-key rejection, post-NFC
  duplicate-key-collision rejection, non-finite/out-of-range-number
  rejection, RFC 8785 numeric-form official boundary vectors, byte-exact
  stdout framing + documented exit-code contract, AC-037/TEST-037);
  REQ-004's HMAC golden known-answer vector covering every sidecar field
  plus a per-field, one-at-a-time mutation proof that each non-`hmac`
  field change breaks signature verification (AC-036/TEST-036); REQ-004/
  REQ-005's same-registry-identity two-person rejection, both at
  generation time (refuses to sign, extends AC-019/TEST-019) and
  validation time (rejects a sidecar carrying two identical approver ids
  even with an otherwise-valid HMAC, extends AC-014/TEST-014 with a fifth
  case); REQ-004/REQ-005's cooldown-not-yet-elapsed rejection (AC-020/
  TEST-020); REQ-004's signer staging-artifact-only contract (no
  live-path write occurs; a nonce-tagged staging candidate plus manifest
  is produced; a simulated mid-write failure leaves no partial artifact)
  and the human-copy publisher's post-verification atomic-apply + rollback
  behavior (AC-034/TEST-034); REQ-006's baseline CLI contract, including
  the baseline-injection-attempt rejection case (candidate passed as its
  own `--baseline` is never the code path REQ-004/REQ-005 use; a fixture
  proves the generator/validator's own invocation never supplies
  `--baseline`) and the first-commit/rename baseline-resolution rules
  (AC-030/TEST-030); REQ-006's nine-category renormalization — one
  before/after fixture for each of the three implemented categories, one
  documented-N/A assertion for each of the six N/A categories (extends
  AC-016/TEST-016), and the glob-coverage narrowing algorithm's boundary
  cases (pattern removed, pattern replaced at an unchanged count, exclude
  added, exclude replaced broader, a pure-broadening change correctly
  classified non-weakening) (AC-031/TEST-031); REQ-007's canonical
  protected-path manifest inventory test (every one of the six
  ADR-0019-item-3 categories — including the two RESERVED, not-yet-built
  resolver/generated-projection entries — is present in the staged
  `guard-invariants.json` candidate) (AC-038/TEST-038); REQ-007's
  human-copy anchored-publisher (`apply-human-copy`) proof (held-handle
  traversal, hard-link-alias non-propagation, temp-rehash-then-atomic-
  rename, no path-copy fallback, no live mutation on preparation failure)
  (AC-033/TEST-033); REQ-008's full 3-basename × 12-call-site × sudo-state
  matrix (72 independent assertions, never a per-basename spot check,
  extends AC-023/TEST-023); REQ-001/REQ-002's component/binding duplicate-
  `id` semantic-validator rejection (AC-040/TEST-040); REQ-001's
  parameterized required-field negative test — one fixture per REQUIRED
  JSON Pointer in the Field Requirement Matrix (design.md), each deleting
  exactly that one pointer and asserting rejection, replacing a prior
  draft's four-subfield spot check (extends AC-001/TEST-001); REQ-002's
  `adapter_paths` optional-field passthrough (AC-041/TEST-041);
  REQ-001's cross-cutting seed-list scaffold template — a per-pattern
  presence check for `specs/**`/`reports/**`/`docs/**`, each declared
  `classification: cross-cutting` (AC-042/TEST-042); REQ-009's
  full per-consumer common contract suite (six cases × five migrated
  consumers = 30 independent assertions, AC-039/TEST-039), including the
  Context-`full` + `--lite` error-stop case (AC-025/TEST-025) and the
  REVISED `PROJECT_CONTEXT_INVALID` explicit-stop-on-existing-but-invalid-
  Context case (never the old "treated as absent" semantics, extends
  AC-026/TEST-026); REQ-010's per-runtime (Claude Code, Codex CLI, Copilot
  CLI) challenge/response fixture simulation — a synthetic recorded-result
  fixture proves each runtime's expected-deny-signature check
  independently, PLUS the canary-non-denial detection case (a fixture
  recorded-result that does NOT show a denial, or carries a stale/
  mismatched nonce, proves the handshake fails closed rather than silently
  reporting `HOOK_ACTIVE`) (extends AC-027/TEST-027); REQ-010's full
  A1-time entry-point wiring inventory (all five migrated consumers
  actually invoke the handshake, not a single representative one) plus the
  documented future-entry-point contract (AC-035/TEST-035); REQ-010's
  sentinel-path deny-only, non-mutating proof — persistent state at the
  sentinel path (and the live sidecar, which the redesigned handshake never
  touches at all) is byte-identical before and after every handshake
  invocation, whether the simulated hook fires or not (AC-032/TEST-032).
  No suite in this epic invokes a real LLM, `gh`, or `sdd-sudo`.

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
  pipeline is in the `disabled-legacy` derived state"). **Forced handoff
  gate (revised)**: this Non-goal does NOT mean these categories are
  unaddressed in A1 — REQ-006's policy-weakening detector reserves a
  documented, fail-closed N/A verdict for "Capability removed" and
  "public distribution de-scoped" (no proxy classification against
  `artifact_kinds`/`runtime_classes`/`distribution_channels`, REQ-006
  above) until the epic that defines a canonical Capability reference or
  public-channel vocabulary lands, and REQ-007 reserves the resolver's and
  generated projection's canonical protected-file path now (both above) —
  the epic that actually builds any of these four items MUST either
  populate A1's reservation/N/A placeholder or explicitly amend it via its
  own spec's stated `guard-invariants`/detector-category diff; silently
  introducing a parallel, unreserved mechanism is not a valid way to
  satisfy this handoff.
- Creating an actual `sdd/project-context.yaml` instance for sdd-forge
  itself — that is Epic A9 (Dogfood) scope; A1 ships schema, scripts, and
  contracts only, no target-repository instance data.
  `contracts/project-context.template.yaml` (REQ-001, above) is NOT an
  exception to this Non-goal — it is a generic, any-project starter
  scaffold consumed by future bootstrap tooling and by Epic A3's day-one
  fixture, never sdd-forge's own `sdd/project-context.yaml`.
- Wiring `check-hook-activation-handshake` (REQ-010) into any Capability
  Mode entry point NOT YET introduced by this or an earlier epic — every
  A1-time bootstrap/track/gate entry point (REQ-009's five migrated
  consumers) IS wired by this epic (REQ-010, revised); only entry points a
  LATER epic (A2, A4, A5) introduces are that epic's own wiring
  responsibility, under the future-entry-point contract REQ-010 states —
  Epic A8's cross-runtime handoff suite is where every such wiring,
  present and future, is jointly regression-tested end-to-end.
- Any Artifact Gate or Promotion Gate work (decision doc §3.2, §3.3 — enum
  reservation only, no implementation, matching the Foundation-wide
  `stage: implementation`-only scope).
- Any `sdd-delivery` or `sdd-operability` plugin work (decision doc §7, §9,
  §14 — new plugins explicitly out of Foundation scope).
- Actually running `spec-review-loop`, `impl-review-loop`, or
  `task-review-loop` against this package — that is a separate, human-gated
  workflow step this spec-authoring session does not perform (see
  investigation.md INV-008 for the `check-workflow-state.sh` rule this
  drives; OQ-003 records how it was resolved).
- Authoring `tasks.md`/`traceability.md` in this package — per the Phase
  model (`plugins/sdd-bootstrap/skills/bootstrap/SKILL.md:88-112`,
  investigation.md INV-008), both are Phase 2 outputs, generated only after
  `Impl-Review-Status: Passed`. A Draft task decomposition was authored
  during this spec-authoring session and is preserved outside the
  repository (coordinator decision, 2026-07-22), for reintroduction once
  the Phase 1 gates pass — it is a Non-goal of THIS package's committed
  content, not of the epic overall.
- Modifying `plugins/**`, `scripts/**`, `.github/**`, `tests/**`, or
  `contracts/**` directly in this spec-authoring session — every concrete
  script, schema, and test file this package specifies is Draft design for
  a future implementation session (task decomposition deferred to Phase 2,
  above), not code produced now.

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
  field — **revised: a PARAMETERIZED negative test**, one fixture per
  REQUIRED JSON Pointer REQ-001 defines, listed in design.md's Field
  Requirement Matrix, each deleting EXACTLY that one pointer (never more
  than one at a time) and asserting rejection; a single "missing
  `workflow` and its three sub-fields" spot check is NOT sufficient —
  every required pointer (including `components[].id` and
  `platform_targets[].{os,architecture}`) gets its own independent case.
  (REQ-001)
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
  validates (passthrough proof); a parameterized negative fixture per
  REQUIRED `bindings[].*` pointer (`id`, `provider`, `product`, `purpose`),
  each deleted independently, is rejected (mirroring AC-001's
  parameterization, applied to REQ-002's own required set). (REQ-002)
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
  resolvable `SDD_CONTEXT_KEY`, produces a **staged** candidate sidecar
  (never a live-path write, REQ-004 revised) whose `hmac` field
  verifies under `validate-approval-sidecar.py`'s independent
  recomputation of the same preimage when run against the staged
  candidate; given NO resolvable key (all four resolution steps
  exhausted), the tool exits non-zero and writes no staged artifact at
  all — never producing an unsigned or placeholder-signed file, staged or
  live. (REQ-004)
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
  case): a content-schema violation (content file fails REQ-001/REQ-002's
  schema, or the canonicalizer's own accepted-domain checks, or the
  duplicate-`id` semantic check); a hash mismatch (content file mutated
  after signing); an HMAC
  mismatch (signature bytes altered, or recomputed under a different key);
  an unregistered approver id; a `primary_approval.approver` identical to
  `second_approval.approver` (same registry id presented twice,
  `DUPLICATE_APPROVER_IDENTITY`, closes the same-identity two-person
  bypass); and an `effective_at` timestamp in the
  future relative to validation time — six independent fixture cases, none
  producing a false PASS. (REQ-005)
- AC-015: `validate-approval-sidecar.py` PASSES a fixture whose
  `context_sha256`, `hmac`, and approver identities are all correct and
  whose `effective_at` is null or already elapsed. (REQ-005)
- AC-016 (revised — renormalized to the canonical nine categories, no
  proxy classification; supersedes any prior "6 implemented / 3 remaining
  / 4 N/A" arithmetic, which was internally inconsistent and is retired):
  `detect-policy-weakening.py`, given a before/after
  `project-context.yaml` pair for each of the **three** categories A1's
  schema can actually express (`capability_enforcement` `required`→
  `advisory`; a component's effective path ownership narrowing, via the
  glob-coverage algorithm design.md defines — AC-031; `spec_profile`
  `full`→`lite`), classifies each as `policy_weakening: true`; the
  remaining **six** categories decision doc §9 names (Capability removed,
  public distribution de-scoped, criticality lowered, Provider allowlist
  widened, production write-path changed, required Gate removed) are
  asserted as documented N/A — no field or proxy exists for any of them in
  A1's schema — a dedicated case asserts the detector's own diagnostic
  names each of the six as N/A explicitly, not merely omits them; the
  detector's category table sums to exactly nine (3 implemented + 6 N/A)
  in every run's diagnostic output, with no other split accepted as
  conforming. (REQ-006)
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
  sign; given the same verdict with two DISTINCT registered approver ids
  present, it signs successfully; given the same verdict with
  `second_approval.approver` equal to `primary_approval.approver` (the
  SAME registry id offered twice), it refuses to sign with a distinct
  `DUPLICATE_APPROVER_IDENTITY` diagnostic — three independent cases,
  closing the same-identity two-person bypass at the point of signing.
  (REQ-004, REQ-006)
- AC-020: `generate-approval-sidecar.py`, given a `two_person_required:
  false` verdict, sets `effective_at` to (signing time + 24 hours) and signs
  with `second_approval: null`; `validate-approval-sidecar.py` rejects
  applying that sidecar's approval before `effective_at` (AC-014's fourth
  case) and accepts it after. (REQ-004, REQ-005, REQ-006)
- AC-021: every path enumerated in REQ-007's canonical
  `PROTECTED-MANIFEST.md` (the 20 concrete + 4 reserved paths — a count
  DERIVED from the manifest itself, never independently re-asserted) is
  present in the staged
  `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json`
  candidate's `protected_gate_suffixes` array (including the two RESERVED
  resolver/generated-projection placeholders), with a matching
  `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`
  candidate whose new `EPIC_A1_TARGETS` constant includes the identical
  set, generated from (not hand-duplicated independently of) the manifest;
  the
  staged candidate's `generate-guard-invariants.py --check` (run against the
  staged tree, not the live one) passes. (REQ-007)
- AC-022: the LIVE `guard-invariants.json`, `generate-guard-invariants.py`,
  and the four `generated/guard_invariants.*` files are byte-identical
  before and after this epic's own implementation commits — no task ever
  writes them directly (SHA-256 comparison). (REQ-007)
- AC-023: after a human applies the REQ-007 staged candidates, a write
  attempt against each of `sdd/project-context.approval.json`,
  `sdd/provider-bindings.approval.json`, `sdd/approver-registry.yaml`, and
  `sdd/.hook-canary-sentinel`, through EVERY one of the 12 mutation
  surfaces `_is_protected_gate_file` is consulted from (not a single
  representative surface per basename), is denied by the live hook guard
  — a 4-basename × 12-call-site × {`SDD_SUDO` active, inactive} matrix, 96
  independent assertions, including the never-bypass-under-`SDD_SUDO`
  proof for every cell (ADR-0019 item 5). (REQ-008)
- AC-024: `PLUGIN-CONTRACTS.md`'s Track Detection section documents the
  Project-Context-present rule (four cases: lite+`--full`→promote,
  lite+`--lite`→no-op, full+`--lite`→error-stop, full+`--full`→no-op) ahead
  of the existing CLI-flag-first order, which is retitled as the
  compatibility-fallback path for "no Project Context". (REQ-009)
- AC-025: a fixture project with `sdd/project-context.yaml` declaring
  `workflow.spec_profile: full`, and a VALID, correctly-signed sidecar,
  invoked with `--lite`, causes `sdd-ship`'s
  documented Track Detection procedure to stop with an explicit,
  non-silent error message — never proceeding as `lite`. A parallel fixture
  with `spec_profile: lite`, invoked with `--full`, promotes to `full`
  without error. (This is `sdd-ship`'s instance of the six-case suite
  AC-039 requires across all five consumers.) (REQ-009)
- AC-026 (revised — closes the induced-validation-failure downgrade gap;
  supersedes the prior "treated identically to no Project Context" verdict
  entirely): a fixture project with an on-disk `sdd/project-context.yaml`
  (physically present) whose sidecar FAILS `validate-approval-sidecar.py`
  (REQ-005) for ANY reason — missing sidecar file, content-schema
  violation, hash mismatch, HMAC mismatch (including a rotated-key
  fixture), unregistered or duplicate approver identity, or a
  not-yet-effective `effective_at` — causes every migrated consumer to
  STOP with the named `PROJECT_CONTEXT_INVALID` error, NEVER falling
  through to the compatibility fallback and NEVER proceeding under an
  implicit `full` or `lite` selection. A SEPARATE fixture in which
  `sdd/project-context.yaml` is physically ABSENT from disk entirely
  exercises the (unchanged) compatibility fallback — proving the two
  fixtures produce genuinely different, correctly-routed outcomes, not the
  same "treated as absent" branch reused for both. (REQ-009)
- AC-027 (revised — the standalone-script canary probe this AC previously
  described is retired; supersedes it entirely with the host-side
  challenge/response redesign, REQ-010): `check-hook-activation-handshake.py
  --verify-response`, given a fixture recorded-result matching one of the
  three runtimes' (Claude Code, Codex CLI, Copilot CLI) documented
  expected-deny-signatures AND a matching nonce, reports `HOOK_ACTIVE` for
  that runtime. Given a fixture recorded-result showing the write actually
  executed, an ambiguous/unrecognized result, a missing recorded-result
  file, or a nonce that does not match the emitted challenge (stale/replayed
  evidence), it reports `CAPABILITY_RUNTIME_UNAVAILABLE` for EVERY one of
  those cases — never `HOOK_ACTIVE` when a genuine, fresh denial was not
  actually observed for the runtime under test. (REQ-010)
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
- AC-030 (NEW — closes the "baseline never defined, verdict trivially
  erased by self-diffing" gap, B3): `detect-policy-weakening.py --candidate
  <path>` with NO `--baseline` given resolves its baseline via `git show
  HEAD:<repo-relative-path>` and classifies correctly against a fixture
  git history (a committed baseline blob differs from the working-tree
  candidate). A fixture that attempts to invoke the SAME code path
  `generate-approval-sidecar.py`/`validate-approval-sidecar.py` use (no
  `--baseline` flag) with a candidate identical to its own git-committed
  HEAD content correctly reports `policy_weakening: false` for a genuinely
  unchanged file — proving the tool cannot be tricked into self-diffing
  through the production call path, since that path never accepts an
  externally supplied baseline at all. A first-commit fixture (no HEAD blob
  for the path) reports `policy_weakening: false` for every category
  (`FIRST_COMMIT_NOT_WEAKENING`), not an error and not a silent "assume
  weakening." A rename fixture (`--baseline-repo-path` pointing at the old
  path) correctly diffs against the OLD path's HEAD content, not the new
  path's (which would have no history). (REQ-006)
- AC-031 (NEW — the glob-coverage narrowing algorithm's boundary cases,
  M13): given a component's `paths.include`/`paths.exclude`, the following
  each independently classify per design.md's deterministic scope-prefix
  algorithm: an include pattern REMOVED outright (narrows); an include
  pattern REPLACED with a more specific pattern at an UNCHANGED pattern
  count (narrows — the same-count-change case a naive "did the array get
  shorter" check would miss); an exclude pattern ADDED (narrows); an
  exclude pattern REPLACED with a broader pattern at an unchanged count
  (narrows); an include pattern ADDED that strictly broadens coverage with
  no other change (does NOT narrow — classified `policy_weakening: false`
  for this category, proving the algorithm is not "any change is
  weakening" in disguise). (REQ-006)
- AC-032 (NEW — sentinel-path deny-only, non-mutating proof, B5):
  `sdd/.hook-canary-sentinel` (and, separately, the live
  `sdd/project-context.approval.json`/`sdd/provider-bindings.approval.json`
  sidecars, which the redesigned handshake never targets at all) are
  byte-identical (or, if absent before, still absent after) across every
  `check-hook-activation-handshake.py --emit-challenge`/`--verify-response`
  invocation this epic's tests exercise, whether the simulated hook fires
  or not — the handshake causes NO persistent-state change under any
  outcome. (REQ-010)
- AC-033 (NEW — human-copy anchored-publisher contract, B6):
  `apply-human-copy.{sh,ps1}` denies a pre-existing symlink/reparse point
  at either the repository-root handle or a destination-parent handle;
  preserves hard-link-alias non-propagation (replacing one hard-linked
  name's content does not mutate content visible through another existing
  hard link to the same prior inode); resists a source or destination-
  parent rename/delete attempted between validation and publish (held-
  handle substitution resistance); performs the actual publish step only
  via an atomic rename (never a path-based copy); and leaves the live
  target UNCHANGED if any validation/preparation/capability-preflight step
  fails, with every held temporary handle cleaned up. (REQ-007)
- AC-034 (NEW — sidecar signer staging-only contract + rollback, B7):
  `generate-approval-sidecar.py` never opens the live `sdd/*.approval.json`
  path for writing under any invocation (asserted via a fixture that
  intercepts/mocks filesystem writes and asserts no write targets the live
  path); it writes a nonce-tagged candidate + `MANIFEST.sha256` entry to a
  staging subdirectory; a simulated failure between writing the candidate
  and writing its manifest entry leaves NO partial candidate at the FINAL
  staged path (temp-then-rename discipline at the staging layer); re-running
  the signer after such a failure succeeds cleanly with a fresh nonce and
  staging subdirectory (idempotent recovery, no rollback state required).
  (REQ-004)
- AC-035 (NEW — full A1-time entry-point handshake wiring inventory +
  future-entry-point contract, M8): every one of REQ-009's five migrated
  consumer entry points (`sdd-ship`, `sdd-bootstrap`, `sdd-bootstrap-
  interviewer`'s three read sites, `lite-spec`, `lite-gate`) invokes
  `check-hook-activation-handshake` at its own Capability-Mode-relevant
  entry point — asserted per-consumer, not by inspection of one and
  assertion-by-similarity for the other four; the future-entry-point
  contract (REQ-010) is documented in a form a LATER epic's own spec-
  review can check against (a named, quotable requirement, not prose
  buried in a Non-goal). (REQ-010)
- AC-036 (NEW — HMAC golden vector + per-field mutation proof, M9): a
  fixed, committed sidecar fixture with every field populated (non-null
  `second_approval`, non-null `effective_at`) has a documented, hand-
  verified canonical-bytes-and-HMAC golden pair; twelve additional
  fixtures, each identical to the golden fixture except for ONE non-`hmac`
  field changed (or, for optional-shape fields, omitted), each produce a
  DIFFERENT computed HMAC than the golden pair's — proving the preimage
  construction actually includes every field the schema defines, not
  merely the fields an internal round-trip test happens to vary. (REQ-004)
- AC-037 (NEW — canonicalizer accepted-domain boundary vectors, M11):
  independent fixtures for: a multi-document YAML stream (rejected,
  `MULTI_DOCUMENT_REJECTED`); a non-string mapping key (rejected,
  `NON_STRING_KEY_REJECTED`); two keys that collide only after NFC
  normalization (rejected, `POST_NFC_DUPLICATE_KEY_REJECTED`); a
  non-finite (`.inf`/`.nan`) or IEEE-754-out-of-range numeric scalar
  (rejected, `NUMBER_OUT_OF_RANGE_REJECTED`); an RFC 8785 §3.2.2.3 official
  numeric-formatting boundary vector (e.g. a value whose canonical
  ECMAScript-`Number` serialization requires an exponent) producing the
  RFC-correct byte sequence, NOT a "no exponent for integers" bespoke rule;
  and a byte-exact stdout-framing + exit-code assertion (default mode
  emits canonical bytes only, no trailing artifact; `--hash-only` emits
  `sha256:<hex>\n` only; every rejection category's exit code is stable and
  documented, and no bytes are ever written to stdout on rejection).
  (REQ-003)
- AC-038 (NEW — resolver/generated-projection reservation inventory +
  forced handoff gate, M14): the staged `guard-invariants.json` candidate's
  `protected_gate_suffixes` includes BOTH reserved entries
  (`resolve-project-context.{py,sh,ps1}` and
  `generated/project-context.resolved.json`) alongside the four concrete
  categories this epic builds — an inventory test asserts all SIX
  ADR-0019-item-3 categories (canonicalizer, hash generator, validator,
  weakening detector, resolver, generated projection) are represented,
  either concretely or as a reservation, never with a category silently
  absent. (REQ-007)
- AC-039 (NEW — full per-consumer common-contract-suite matrix, M16): each
  of REQ-009's five migrated consumers (`sdd-ship`, `sdd-bootstrap`,
  `sdd-bootstrap-interviewer`, `lite-spec`, `lite-gate`) is independently
  exercised against the SAME six cases (lite+`--full`→promote,
  lite+`--lite`→no-op, full+`--lite`→error-stop, full+`--full`→no-op, no-
  Context+either-flag→compatibility fallback, existing-but-invalid-
  Context→`PROJECT_CONTEXT_INVALID` stop) — 30 independent assertions
  total, never a 2-case proof on one consumer generalized by assertion to
  the other four. (REQ-009)
- AC-040 (NEW — component/binding duplicate-`id` semantic-validator
  rejection, M18): a `project-context.yaml` fixture with two `components[]`
  entries sharing the same `id` is rejected (`DUPLICATE_COMPONENT_ID`) by
  the content-schema validation step (REQ-005); a `provider-bindings.yaml`
  fixture with two `bindings[]` entries sharing the same `id` is rejected
  (`DUPLICATE_BINDING_ID`) the same way — neither case is expressible by
  `contracts/project-context.schema.json`/`contracts/provider-bindings.schema.json`
  alone (JSON Schema draft-07 has no native array-uniqueness-by-key
  predicate), so both are proven at the semantic-validator layer
  specifically, not merely asserted as a schema property. (REQ-001,
  REQ-002)
- AC-041 (NEW — `provider-bindings.yaml` optional `adapter_paths` field,
  cross-epic ruling): a `bindings[]` entry declaring `adapter_paths` as an
  array of glob strings validates; a `bindings[]` entry declaring no
  `adapter_paths` at all also validates (the field is optional, its
  absence is not a schema violation) — proving A1's schema change is
  additive-only and does not itself implement or require Epic A3's Fail-6
  diff/WARN behavior (A3's own scope, requirements.md's REQ-002 text,
  above). (REQ-002)
- AC-042 (NEW — cross-cutting seed-list scaffold, cross-epic ruling):
  `contracts/project-context.template.yaml` validates against
  `contracts/project-context.schema.json`; its `shared_paths` array
  contains an entry with `pattern: "specs/**"`, an entry with
  `pattern: "reports/**"`, and an entry with `pattern: "docs/**"`, each
  with `classification: cross-cutting` — asserted by a fixture-driven
  per-pattern presence check (not by inspection alone), proving a project
  that adopts this template has its always-growing, no-single-owner
  directories pre-declared cross-cutting BEFORE Epic A3's Reverse Coverage
  Gate can ever evaluate a changed path against it. (REQ-001)

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
  new, protected (REQ-007) file listing real registered approver identities.
  Each entry's `id` is the **immutable identity key** every
  `approval.approver` field (REQ-004) MUST reference — never the entry's
  `name` (a mutable display label, not load-bearing for identity
  comparison). its own integrity is load-bearing for REQ-006's two-person/solo-cooldown
  branch, so it is added to `guard-invariants` alongside the sidecars, not
  left agent-writable (an agent-writable registry would let an agent shrink
  it to defeat the two-person requirement).
- `human-copy procedure` (REQ-007, REQ-009, REQ-011; ADR-0011; INV-011) —
  the epic-159-pillar-c-precedent staging shape, GENERALIZED by this epic
  to an anchored-publisher-equivalent guarantee (REQ-007's
  `apply-human-copy.{sh,ps1}`, above) rather than a plain `cp`: an agent
  renders corrected
  content to `specs/epic-189-a1-project-context/human-copy/<path>` with a
  `MANIFEST.sha256` entry; a human runs `apply-human-copy` (bootstrapped
  once via a human-verified plain `cp` + SHA-256 check, then self-hosting
  thereafter, REQ-007) rather than a bare `cp`, and verifies the SHA-256.
  This
  epic does NOT extend or reuse `apply-protected-files.ps1`
  (INV-011 — that tool is pinned to its own frozen bootstrap inventory).
- `CAPABILITY_RUNTIME_UNAVAILABLE` (REQ-010; decision doc §7 v2) — the
  named stop condition when the hook-activation handshake cannot observe a
  DENIAL matching the runtime-specific expected signature (a fresh,
  nonce-matched host tool-call result, REQ-010 revised) for the runtime
  under test; distinct from any Capability-mode-inactive state (ADR-0016's
  `disabled-legacy`), which is a normal, expected condition for a project
  with no Project Context, not an error.
- `PROJECT_CONTEXT_INVALID` (REQ-009; NEW, closes B1) — the named stop
  condition every migrated track-selection consumer reports when
  `sdd/project-context.yaml` is PHYSICALLY PRESENT on disk but fails
  REQ-005's validator for any reason (missing sidecar, content-schema
  violation, hash mismatch, HMAC mismatch, unregistered/duplicate approver
  identity, not-yet-effective `effective_at`). Distinct from the
  compatibility fallback (which applies ONLY when the file is physically
  absent) — this distinction is the entire point of the fix: an attacker
  who can induce a validation failure against an EXISTING Project Context
  (by corrupting the sidecar, replaying a stale one, or exploiting a key
  rotation window) must not thereby regain the OLD CLI-flag-first
  behavior; they get a loud stop instead.
- `sdd/.hook-canary-sentinel` (REQ-007, REQ-010; NEW) — a dedicated,
  protected, intentionally-never-populated-with-real-content path the
  redesigned hook-activation handshake targets for its canary tool-call
  attempt; distinct from the live approval sidecars specifically so a
  canary attempt (successful OR denied) can never corrupt, truncate, or
  otherwise mutate real approval state (closes B5).
- `adapter_paths` (REQ-002; NEW, cross-epic addition) — an OPTIONAL array
  of glob strings on a `provider-bindings.yaml` binding entry, declaring
  the repository paths that binding's adapter implementation occupies;
  consumed by Epic A3's Reverse Coverage Gate Fail-6 condition (Provider
  Adapter change not reflected in Provider Binding), not by anything in
  A1 itself — A1 defines the schema field only (REQ-002's Constraint
  Compliance / API Contract Plan, design.md).
- `DUPLICATE_APPROVER_IDENTITY` (REQ-004, REQ-005; NEW, closes B2) — the
  named diagnostic both the sidecar generator (at signing time) and the
  validator (at validation time) emit when `primary_approval.approver`
  and `second_approval.approver` reference the SAME approver-registry
  `id` — closes the same-identity two-person bypass (one real person
  supplying both signature slots to satisfy a two-person requirement in
  form only).
- `DUPLICATE_COMPONENT_ID` / `DUPLICATE_BINDING_ID` (REQ-001, REQ-002;
  NEW, closes M18) — the named diagnostics the content-schema validation
  step (REQ-005) emits when `project-context.yaml`'s `components[]` or
  `provider-bindings.yaml`'s `bindings[]` contains two entries sharing the
  same `id` — a check JSON Schema draft-07 cannot express natively, so
  REQ-005 performs it as a semantic (non-schema) validation step.
- `contracts/project-context.template.yaml` (REQ-001; NEW, cross-epic
  addition) — a generic, unprotected, schema-conformant starter scaffold
  (not a live instance for sdd-forge itself, Non-goals) whose
  `shared_paths` pre-populates decision doc §12's cross-cutting seed list
  (`specs/**`, `reports/**`, `docs/**`) so a newly-bootstrapped project
  does not immediately fail Epic A3's Reverse Coverage Gate for its own
  always-growing, no-single-owner directories; consumed by Epic A3's
  day-one integration fixture (A3's own scope to implement the gate logic
  that reads it).

## Roles and Permissions

- Agent: authors every new schema, script, template, and test file this
  package
  specifies (a future implementation session) directly — none of
  `contracts/project-context.schema.json`,
  `contracts/project-context.template.yaml`,
  `contracts/provider-bindings.schema.json`,
  `contracts/approval-sidecar.schema.json`,
  `canonicalize-sdd-yaml.{py,sh,ps1,js}`,
  `generate-approval-sidecar.{py,sh,ps1}`,
  `validate-approval-sidecar.{py,sh,ps1}`,
  `detect-policy-weakening.{py,sh,ps1}`,
  `check-hook-activation-handshake.{py,sh,ps1}`,
  `apply-human-copy.{sh,ps1}`, or their test twins is
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
   `SDD_CONTEXT_KEY` resolvable, supplying `--approver` (an approver-
   registry `id`) and, when
   `detect-policy-weakening` (REQ-006) reports `two_person_required: true`,
   a second, DISTINCT registered `--second-approver` id too (identical ids
   are refused, `DUPLICATE_APPROVER_IDENTITY`); the tool computes
   `context_sha256`
   via REQ-003, and (for a non-policy-weakening or two-person-approved
   change) signs immediately, or (for a policy-weakening, solo-approver
   change) sets `effective_at` to now+24h and signs — writing ONLY a
   nonce-tagged STAGED candidate + manifest entry, never the live sidecar
   path (REQ-004, revised). A human then runs `apply-human-copy` (REQ-007)
   to publish the staged, REQ-005-revalidated candidate to the live path.
3. A consuming skill (REQ-009's track-selection migration wires all five
   A1-time entry points, above; a future Epic A2/A5/A9 concern for
   call sites this epic does not itself introduce) FIRST checks whether
   `sdd/project-context.yaml` is physically present. If absent, the
   compatibility fallback applies unchanged. If present, it calls
   `validate-approval-sidecar` (REQ-005) before trusting the content file;
   a validation failure against an EXISTING file stops with the named
   `PROJECT_CONTEXT_INVALID` error — it is never treated as "no Project
   Context" and never silently falls through to the compatibility
   fallback (REQ-009, revised — closes B1).
4. Before trusting Capability Mode at all, the calling skill's own AGENT
   SESSION performs the host-side canary tool-call handshake
   (`check-hook-activation-handshake --emit-challenge`, then the agent's
   own real tool-call attempt against `sdd/.hook-canary-sentinel`, then
   `--verify-response`, REQ-010 revised); a non-`HOOK_ACTIVE` result stops
   with `CAPABILITY_RUNTIME_UNAVAILABLE`, never a silent legacy-mode
   fallback, and the sentinel/live-sidecar state is unchanged regardless
   of outcome (REQ-010's non-mutation guarantee).
5. A maintainer proposing a policy-weakening edit to `project-context.yaml`
   runs `detect-policy-weakening` (REQ-006, its default git-HEAD baseline
   resolution, no `--baseline` override) against the working-tree
   candidate before requesting sign-off; the returned verdict determines
   whether a second approver is required or a 24-hour cooldown applies.
6. Implementation of this epic's own new scripts stages every protected-file
   edit (guard-invariants registration, `PLUGIN-CONTRACTS.md`'s protected
   consumers, `.github/workflows/test.yml`) under
   `specs/epic-189-a1-project-context/human-copy/`; a human applies each via
   `apply-human-copy` (REQ-007's anchored-publisher-equivalent tool,
   bootstrapped once via plain `cp` + SHA-256 verification) before the
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
  whose sidecar does not exist AT ALL (never signed) is a validation
  FAILURE (REQ-005) — and, because the CONTENT file itself is physically
  present, REQ-009's revised semantics route this to the
  `PROJECT_CONTEXT_INVALID` explicit stop (AC-026), NOT to the
  compatibility fallback and NOT to an implicit, auto-approved default —
  this is the exact case a prior draft's "treated as absent" language
  would have silently downgraded to the old CLI-flag-first behavior.
- A Project Context whose sidecar previously validated but now fails
  (key rotated, sidecar corrupted, cooldown window re-triggered by a
  replayed stale sidecar) must ALSO route to `PROJECT_CONTEXT_INVALID`,
  never to the compatibility fallback — an attacker who can induce a
  validation failure against an EXISTING Project Context must not thereby
  regain the weaker pre-ADR-0023 CLI-flag-first behavior (B1, closed).
- A `detect-policy-weakening.py` invocation that supplies its own
  candidate file's content as `--baseline` (self-diffing) must never be
  the code path REQ-004's generator or REQ-005's validator use — both
  invoke the tool with NO `--baseline` flag, relying solely on the tool's
  own git-HEAD default resolution, which the candidate's own author cannot
  retroactively rewrite (B3, closed) — `--baseline` remains available only
  for this script's own fixture tests (REQ-011).
- A sidecar carrying two structurally valid, individually-registered
  approver ids that happen to be the SAME id (one person filling both
  slots) must be rejected — at generation time by the signer's own refusal
  to sign, and independently at validation time even against an otherwise
  perfectly-formed, correctly-HMAC'd sidecar (B2, closed) — a valid HMAC
  over a self-defeating two-person claim is not evidence of genuine
  two-person review.
- The hook-activation handshake's redesigned canary tool-call targets a
  DEDICATED sentinel path (`sdd/.hook-canary-sentinel`), never the live
  approval sidecar — a denied OR non-denied outcome must never mutate any
  persistent state, sentinel or sidecar alike (B5, closed); and the
  handshake's own script component never performs a write attempt itself
  (only the AGENT's own real tool call does, per the challenge/response
  redesign, REQ-010) — a standalone script's own file-write "succeeding"
  or "failing" proves nothing about host hook installation (B4, closed).

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: agent write access to `project-context.yaml`/`provider-bindings.yaml` content | agent may edit content freely (REQ-001/REQ-002 are content schemas, not protected files); every content change requires a FRESH sidecar signature (REQ-004) before any consumer trusts it (REQ-005) — content editability is intentionally unrestricted, approval is not | internal source only | none identified |
| B2: agent write access to the approval sidecars and approver registry | full deny, no partial permission, no `sudo` bypass (REQ-007/REQ-008/ADR-0019 item 1/item 5); human-copy is the only legitimate change path | internal source only | none identified |
| B3: HMAC key custody | `SDD_CONTEXT_KEY`/`SDD_CONTEXT_KEY_FILE`/`~/.sdd/context-key` are never read by an agent-driven signing operation — signing is human/CI-only (Roles and Permissions); an agent may read a PUBLIC sidecar's `hmac` field (verification-only, no key needed) but never the signing key itself | internal source only | none identified |
| B4: policy-weakening self-approval | the detector's `two_person_required`/`cooldown_hours` verdict is re-derived from the protected approver registry at BOTH generation and validation time (Edge Cases, above), from a baseline the detector resolves ITSELF via git-HEAD (never an externally supplied or candidate-as-baseline value) — an agent cannot manufacture a favorable verdict by controlling only the content file, and cannot satisfy a two-person requirement with one identity presented twice (`DUPLICATE_APPROVER_IDENTITY`) | internal source only | none identified |
| B5: track-selection fail-open/fail-open-via-tampering risk | a Project Context PHYSICALLY ABSENT from disk uses the compatibility fallback (unchanged); a Project Context PHYSICALLY PRESENT that fails REQ-005 validation for ANY reason (including one an attacker could induce — sidecar tampering, replay, key-rotation-window exploitation) STOPS with the named `PROJECT_CONTEXT_INVALID` error (REQ-009, revised) — never treated as absent, never an implicit `full` or `lite` grant | internal source only | none identified |
| B6: hook-activation handshake integrity | the redesigned handshake never targets the live approval sidecar (a dedicated sentinel path only, REQ-007/REQ-010) and never performs a write attempt from the standalone script itself (only a real, host-intercepted agent tool call counts as evidence, REQ-010) — closes both "canary corrupts live state" and "script's own subprocess I/O cannot observe host-level tool-call interception" | internal source only | none identified |

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
- `plugins/sdd-lite/skills/lite-gate/SKILL.md` — RESOLVED (was an open
  implementer-verifies item in a prior draft): confirmed at spec-authoring
  time to read track-selection state and confirmed unprotected (REQ-009,
  revised) — it is in scope for direct-edit migration; an implementer
  re-verifies its exact content at task-start time (this remains an
  Assumption re-verification, only the "does it need edits at all"
  uncertainty is resolved).
- The registry-entry rule INV-008 documents (`tasks.md`'s mere existence
  requiring `Spec-Review-Status: Passed` and `Impl-Review-Status: Passed`)
  is a property of `plugins/sdd-quality-loop/scripts/check-workflow-state.sh`
  as it exists today; this package follows that rule (deferring `tasks.md`/
  `traceability.md` to Phase 2, per the coordinator's 2026-07-22 decision)
  rather than working around it.

## Open Questions

See investigation.md's Open Questions (OQ-001..OQ-003): the approver-registry
file location (OQ-001, resolved provisionally by REQ-006's own definition,
subject to impl-review confirmation), the `distribution_channels`/
`data_classification` array-vs-scalar shape (OQ-002, resolved provisionally
by REQ-001's array choice), and the `tasks.md`/`traceability.md`
Phase-2-deferral question (OQ-003) — RESOLVED by coordinator decision
(2026-07-22): this package follows the repository's Phase model exactly
(`tasks.md`/`traceability.md` are Phase 2 outputs, generated only after
`Impl-Review-Status: Passed`); a Draft task decomposition authored during
this session is preserved outside the repository for reintroduction at that
time, rather than committed alongside Phase-1-Pending status headers.

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
- Medium: `check-hook-activation-handshake`'s canary tool-call, if it ever
  targeted a path with real content, risks corrupting that content if the
  attempt were ever actually applied rather than denied. Mitigation:
  REQ-010's redesign targets a DEDICATED sentinel path
  (`sdd/.hook-canary-sentinel`) that never carries real content, distinct
  from the live sidecars, and Edge Cases/AC-032 require persistent state to
  be provably unchanged whether the simulated hook fires or not.
- Medium (NEW, from the host-canary redesign, B4): the redesigned
  handshake depends on each host runtime's own tool-call-denial reporting
  surface being distinguishable and stable (Claude Code's `--emit exit`
  denial signature; Codex CLI's `plugin_hooks`-gated dispatch; Copilot
  CLI's `--emit copilot` JSON) — a host runtime changing how it surfaces a
  denied tool call would silently break this epic's per-runtime signature
  table without necessarily breaking the underlying guard. Mitigation:
  REQ-011's per-runtime fixture tests pin each signature explicitly (not
  merely "some denial occurred"), and Epic A8's cross-runtime handoff
  suite is the designated place this drifts into a real, live-runtime
  regression check beyond this epic's own fixture-only proof.
- Medium (NEW, from REQ-006's git-HEAD baseline resolution, B3): the
  weakening detector's default baseline resolution depends on the
  repository actually being a git working tree with the candidate's prior
  content committed at `HEAD` — a non-git deployment, a shallow clone
  missing the needed blob, or a repository state mid-rebase could make
  `git show HEAD:<path>` fail in ways distinct from "first commit."
  Mitigation: REQ-006 requires the tool to fail closed
  (`CANDIDATE_NOT_SCHEMA_VALID`-adjacent diagnostic, distinct from
  `FIRST_COMMIT_NOT_WEAKENING`) rather than silently defaulting to either
  verdict when git resolution itself errors, distinguishing "no prior
  commit exists" from "git resolution failed" as two different, both
  non-silent, outcomes.
- Medium: three independent HMAC-key-bearing mechanisms now coexist in this
  repository (`SDD_SUDO`, `SDD_EVIDENCE_KEY`, `SDD_CONTEXT_KEY`) with similar
  but not identical resolution code, risking silent behavioral drift between
  them if one is patched and the others are not. Mitigation: REQ-004
  explicitly requires byte-for-byte matching resolution/stripping behavior
  (AC-013) as an executable proof, not merely a documented convention;
  design.md records this as a candidate for future de-duplication, out of
  this epic's own scope.
- Low: a future implementation session must remember to reintroduce the
  preserved Draft `tasks.md`/`traceability.md` (investigation.md INV-008,
  OQ-003) rather than re-authoring task decomposition from scratch, and
  must re-verify it still matches this requirements.md/design.md pair
  (which may have changed during the intervening spec-review/impl-review
  rounds) before recommitting it. Mitigation: the preserved draft's
  location and provenance are recorded in investigation.md and in this
  package's commit history, not left as tribal knowledge.
