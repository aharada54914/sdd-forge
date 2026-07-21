# Acceptance Tests: epic-189-a1-project-context

TEST IDs (TEST-001..TEST-042) are namespaced to this feature
(`specs/epic-189-a1-project-context/`) and map 1:1 to AC-001..AC-042 in
requirements.md. All tests are Draft/Planned — none has run, since no
implementation exists yet (this is a spec-only package). AC-030..AC-042/
TEST-030..TEST-042 are new in this revision (adversarial spec-review
remediation); several AC-00x/TEST-00x pairs below (AC-001, AC-003, AC-014,
AC-016, AC-019, AC-021, AC-022, AC-023, AC-025, AC-026, AC-027) are revised
in place — their Test Target column states the current, authoritative
scope; do not rely on any prior draft's wording for these rows.

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 (revised) | REQ-001 | TEST-001 | parameterized schema conformance (positive + negative) | JSON-Schema validator run against `contracts/project-context.schema.json`: a fixture exercising every field validates; a PARAMETERIZED fixture set, one per REQUIRED JSON Pointer in design.md's Field Requirement Matrix, each deleting exactly that one pointer, is rejected | Planned |
| AC-002 | REQ-001 | TEST-002 | field-allowlist coverage | fixture-driven per-path presence check: each of the 8 ADR-0020 allowlist paths resolves against a schema-defined field | Planned |
| AC-003 (revised) | REQ-002 | TEST-003 | parameterized schema conformance (positive + negative) | `contracts/provider-bindings.schema.json`: required-field fixture validates; `state_authority`/`credentials` passthrough fixture (unanticipated shape) still validates; a PARAMETERIZED fixture set, one per REQUIRED `bindings[].*` pointer, each deleted independently, is rejected | Planned |
| AC-004 | REQ-002 | TEST-004 | provider-neutrality proof | fixture with an invented `provider` string value validates — proves no fixed Provider enum exists | Planned |
| AC-005 | REQ-003 | TEST-005 | rejection lock (4 categories) | `canonicalize-sdd-yaml.py`: one fixture each for anchor / alias / custom tag / duplicate key, each exits non-zero with a category-specific diagnostic | Planned |
| AC-006 | REQ-003 | TEST-006 | YAML-1.2-core-schema proof | fixture with `on`/`off`/`yes`/`no` scalars parses them as strings, not booleans | Planned |
| AC-007 | REQ-003 | TEST-007 | NFC-normalization proof | precomposed-vs-decomposed Unicode fixture pair produces byte-identical canonical output and identical SHA-256 | Planned |
| AC-008 | REQ-003 | TEST-008 | JCS-compliance proof | canonical JSON output matches a hand-computed expected byte sequence for a fixture with non-canonical key order/number formatting | Planned |
| AC-009 | REQ-003, REQ-011 | TEST-009 | multi-runtime hash-equality + dispatch proof | `.py`, `.sh`, `.ps1` (dispatch-only, NO PowerShell-native fallback), `.js` (where Node available) produce an identical SHA-256 for the same fixture; each wrapper is proven to dispatch to `.py`, not reimplement | Planned |
| AC-010 | REQ-004 | TEST-010 | schema conformance (positive + negative) | `contracts/approval-sidecar.schema.json`: full-field fixture (non-null `second_approval`/`effective_at`) validates; `hmac` shorter than 64 hex chars, or containing uppercase, is rejected | Planned |
| AC-011 (revised — extends the staged-artifact set, B3) | REQ-004 | TEST-011 | staged-signing round-trip + fail-closed proof | `generate-approval-sidecar.py` produces a STAGED candidate (never a live-path write) whose `hmac` verifies under `validate-approval-sidecar.py`'s independent recomputation, PLUS a staged approved-context content snapshot (the exact bytes hashed into `context_sha256`, for `apply-human-copy` to publish to `sdd/.approved-context/<schema>.approved.yaml` alongside the sidecar, REQ-006's new trust anchor); with no resolvable key (all 4 steps exhausted), the tool exits non-zero and writes NO staged artifact at all | Planned |
| AC-012 | REQ-004 | TEST-012 | preimage self-reference exclusion | internal preimage-dump test hook: two sidecars differing only in `hmac` value produce the identical preimage | Planned |
| AC-013 | REQ-004 | TEST-013 | key-resolution byte-parity | 4-case fixture matrix (env var / env-file / home-path / none) asserts identical key bytes and BOM/whitespace-stripping to `_resolve_sudo_key`/`resolve_evidence_key` | Planned |
| AC-014 (revised) | REQ-005 | TEST-014 | six-way negative proof | `validate-approval-sidecar.py`: content-schema violation (incl. duplicate-`id`) / hash mismatch / HMAC mismatch / unregistered approver id / duplicate approver identity (`DUPLICATE_APPROVER_IDENTITY`) / future `effective_at` — six independent fixtures, each an independent rejection | Planned |
| AC-015 | REQ-005 | TEST-015 | positive proof | fixture with correct hash, HMAC, registered+distinct approvers, and null/elapsed `effective_at` validates PASS | Planned |
| AC-016 (revised — renormalized) | REQ-006 | TEST-016 | per-category classification + N/A reporting | `detect-policy-weakening.py`: one before/after fixture per IMPLEMENTED category (3: `capability_enforcement` weakened, component path narrowed via the glob-coverage algorithm, `spec_profile` full→lite) classifies `policy_weakening: true`; each of the 6 documented-N/A categories (Capability removed, public distribution de-scoped, criticality lowered, Provider allowlist widened, production write-path changed, required Gate removed) is reported as N/A explicitly, no proxy classification | Planned |
| AC-017 | REQ-006 | TEST-017 | negative proof | a strengthening-change fixture (`advisory`→`required`) classifies `policy_weakening: false` | Planned |
| AC-018 | REQ-006 | TEST-018 | two-person/cooldown verdict | 2-identity registry fixture → `two_person_required: true`; 1-identity registry fixture → `two_person_required: false, cooldown_hours: 24` | Planned |
| AC-019 (revised) | REQ-004, REQ-006 | TEST-019 | two-person enforcement at signing, incl. same-identity refusal | `generate-approval-sidecar.py` refuses to sign a policy-weakening change with only `primary_approval` when the verdict requires two-person; signs when TWO DISTINCT registered approver ids are present; refuses (`DUPLICATE_APPROVER_IDENTITY`) when `second_approval.approver` equals `primary_approval.approver` | Planned |
| AC-020 | REQ-004, REQ-005, REQ-006 | TEST-020 | cooldown enforcement (generation + validation) | solo-approver policy-weakening sidecar gets `effective_at` = signing time + 24h; validator rejects applying it before that time and accepts after | Planned |
| AC-021 (revised) | REQ-007 | TEST-021 | staged-inventory conformance, manifest-derived count | staged `human-copy/.../guard-invariants.json` candidate's `protected_gate_suffixes` includes every path in `PROTECTED-MANIFEST.md` (22 concrete + 4 reserved = 26, a count DERIVED from the manifest — includes the two `sdd/.approved-context/*.approved.yaml` anchor snapshots, B3); matching staged `generate-guard-invariants.py` candidate's new `EPIC_A1_TARGETS` includes the identical, manifest-generated set; staged-tree `--check` passes | Planned |
| AC-022 | REQ-007 | TEST-022 | live-file-unchanged proof | SHA-256 of the LIVE `guard-invariants.json`, `generate-guard-invariants.py`, and the four generated files is unchanged before/after this epic's own agent commits | Planned |
| AC-023 (revised — full matrix, M17) | REQ-008 | TEST-023 | protected-write-boundary + never-bypass proof, full matrix | post-human-copy-application: a write attempt against EACH of the FOUR protected basenames (the three sidecar/registry files plus `sdd/.hook-canary-sentinel`), through EVERY ONE of the 12 mutation surfaces `_is_protected_gate_file` is consulted from (design.md Test Strategy item 8's explicit 12-row surface/argv/expected-denial table), is denied — 4×12×2 (sudo active/inactive) = 96 independent assertions, never a per-basename spot check. Surfaces NOT among these 12 (e.g. `ln`, or an interpreter's own in-process write via `python -c`/`node -e`) are an explicitly documented residual gap, out of this matrix's scope (design.md, Constraint Compliance) — never silently implied as covered by "indirect-mutation surface identified at implementation time." | Planned |
| AC-024 | REQ-009 | TEST-024 | document conformance | `PLUGIN-CONTRACTS.md` Track Detection section documents the 4-case Project-Context-present rule ahead of the retitled compatibility-fallback order | Planned |
| AC-025 | REQ-009 | TEST-025 | behavior lock (error-stop + promotion) | fixture project (`spec_profile: full`, VALID signed sidecar) + `--lite` → explicit error, execution stops; fixture project (`spec_profile: lite`) + `--full` → promotes, no error — this is `sdd-ship`'s instance of the AC-039 consumer matrix | Planned |
| AC-026 (revised — supersedes the prior "treated as absent" verdict entirely) | REQ-009 | TEST-026 | `PROJECT_CONTEXT_INVALID` explicit-stop proof | a fixture project with an on-disk (physically present) `sdd/project-context.yaml` whose sidecar FAILS `validate-approval-sidecar.py` for ANY reason (missing sidecar, content-schema violation, hash mismatch, HMAC mismatch incl. rotated key, unregistered/duplicate approver, not-yet-effective `effective_at`) causes every migrated consumer to STOP with `PROJECT_CONTEXT_INVALID` — NEVER falling through to the compatibility fallback; a SEPARATE fixture with `sdd/project-context.yaml` physically ABSENT exercises the (unchanged) compatibility fallback, proving the two routes are genuinely distinct | Planned |
| AC-027 (revised — standalone-probe design retired; defense-tier scope, B4) | REQ-010 | TEST-027 | host-canary challenge/response fail-closed proof (A1's footgun-guard Done condition) | `check-hook-activation-handshake.py --verify-response`, given a fixture recorded-result matching one of the three runtimes' documented expected-deny-signatures AND a matching nonce, reports `HOOK_ACTIVE` for that runtime; given a result showing the write executed, an unrecognized result, a missing recorded-result file, or a stale/mismatched nonce, reports `CAPABILITY_RUNTIME_UNAVAILABLE` — never `HOOK_ACTIVE` without a genuine, fresh, runtime-matched denial. **Scope**: this proves the verify-response logic's correctness against synthetic, fixture-recorded evidence ONLY — it does not and cannot prove a LIVE host's hook actually fires/denies for a real, agent-proposed tool call; that live-host, cross-runtime observation is explicitly OUT of A1's own Done condition and is instead Epic A8's own mandatory Done condition (decision doc §9 v2's two-tier defense scope) — an explicit handoff, not a mere related future test. | Planned |
| AC-028 | REQ-011 | TEST-028 | twin registration + protected-file 3-part proof | every new script's `.sh`+`.ps1` test twin self-registers in `tests/run-all.sh`/`.ps1`; `.github/workflows/test.yml` registration proven via the staged/live-unchanged/post-copy-registered 3-part shape | Planned |
| AC-029 | REQ-011 | TEST-029 | non-use + CI-resilience declarations | no suite invokes a real LLM/`gh`/`sdd-sudo`; every mktemp root is `pwd -P`-normalized; no possibly-empty bash array under `set -u` | Planned |
| AC-030 (revised — trust anchor changed from git-HEAD to the approved-context anchor, closes B3) | REQ-006 | TEST-030 | approved-context anchor CLI contract + injection-attempt rejection | `detect-policy-weakening.py`'s default (no `--approved-context`) resolution reads the protected `sdd/.approved-context/<schema>.approved.yaml` anchor snapshot (the exact content bytes `apply-human-copy` published in lockstep with the last successfully-published sidecar, REQ-004/REQ-007) rather than git HEAD: (1) a candidate IDENTICAL to the approved anchor classifies `policy_weakening: false` for every category (unchanged); (2) a candidate carrying a genuine weakening diff against the approved anchor classifies `policy_weakening: true` for the matching category(ies) — asserted BOTH immediately AND after the candidate has been landed as one or more ordinary git commits (proving a new commit alone never moves the anchor, since the anchor file is itself full-write-deny protected and changes ONLY via a new `apply-human-copy` publish, closing the "commit the weakening, then diff against the new normal" attack); (3) the production call path (no `--approved-context`, the only mode REQ-004/REQ-005 use) is proven immune to a caller-supplied override; (4) no anchor snapshot exists yet (no sidecar has ever been successfully published) reports `policy_weakening: false` for every category (`NO_APPROVED_CONTEXT_ANCHOR`, every capability/path treated as a new addition, never an error and never a silent "assume weakening") | Planned |
| AC-031 (NEW) | REQ-006 | TEST-031 | glob-coverage narrowing algorithm boundary cases | pattern removed (narrows); pattern replaced at an unchanged count (narrows — the same-count-change case); exclude pattern added (narrows); exclude pattern replaced broader (narrows); a pure-broadening change (does NOT narrow) — five independent fixtures against design.md's scope-prefix algorithm | Planned |
| AC-032 (revised — resolves the absent-after-on-every-outcome contradiction, closes B5) | REQ-010 | TEST-032 | sentinel-path two-branch non-mutation proof | the live approval sidecars (untouched by the redesigned handshake in every branch) are byte-identical before/after every handshake invocation, unconditionally. `sdd/.hook-canary-sentinel`'s own state depends on the branch: (a) hook FIRES (deny) — the sentinel is absent-before AND absent-after (the write never executed, so it is never created); (b) hook does NOT fire (write executes, `CAPABILITY_RUNTIME_UNAVAILABLE`) — the write's own success is the detection signal, so the sentinel IS created as a direct, expected side effect; `--verify-response` reports the non-`HOOK_ACTIVE` outcome AND instructs one immediate cleanup tool-call attempt (delete/remove the now-created sentinel), asserted to run before the calling skill's own stop — considered end-to-end across the FULL handshake invocation (challenge → tool call → verify-response → cleanup), the sentinel is absent-before and absent-after in this branch too, with only a transient, expected mid-invocation existence, never a lasting mutation | Planned |
| AC-033 (NEW) | REQ-007 | TEST-033 | human-copy anchored-publisher contract | `apply-human-copy.{sh,ps1}` denies a pre-existing symlink/reparse point at either held handle; preserves hard-link-alias non-propagation; resists held-handle substitution between validation and publish; publishes only via atomic rename (never path-based copy); leaves the live target unchanged on any preparation-stage failure | Planned |
| AC-034 (NEW — extends to the approved-context snapshot artifact, B3) | REQ-004 | TEST-034 | signer staging-only contract + rollback | `generate-approval-sidecar.py` never opens the live sidecar path (nor the live `sdd/.approved-context/*.approved.yaml` anchor path) for writing under any invocation; a simulated mid-write failure between the candidate, its approved-context snapshot, and the manifest leaves no partial artifact at any final staged path; a re-run after such a failure succeeds with a fresh nonce and staging subdirectory | Planned |
| AC-035 (NEW) | REQ-010 | TEST-035 | full A1-time entry-point wiring inventory | each of REQ-009's five migrated consumers independently asserted to invoke `check-hook-activation-handshake` at its own entry point; the future-entry-point contract is documented in a form a later epic's spec-review can check against | Planned |
| AC-036 (NEW) | REQ-004 | TEST-036 | HMAC golden vector + per-field mutation proof | a full-field golden fixture's hand-verified canonical-bytes-and-HMAC pair; twelve one-field-mutated variants each produce a DIFFERENT HMAC, proving the preimage covers every schema field | Planned |
| AC-037 (NEW) | REQ-003 | TEST-037 | canonicalizer accepted-domain boundary vectors | independent fixtures: multi-document rejection; non-string-key rejection; post-NFC duplicate-key-collision rejection; non-finite/out-of-range-number rejection; an RFC 8785 §3.2.2.3 official numeric-formatting boundary vector; byte-exact stdout-framing + documented exit-code assertion for success and every rejection path | Planned |
| AC-038 (NEW) | REQ-007 | TEST-038 | resolver/generated-projection reservation inventory | staged `guard-invariants.json` candidate's `protected_gate_suffixes` includes both reserved entries (`resolve-project-context.{py,sh,ps1}`, `generated/project-context.resolved.json`); an inventory test asserts all six ADR-0019-item-3 categories are represented, concretely or as a reservation | Planned |
| AC-039 (NEW) | REQ-009 | TEST-039 | full per-consumer common-contract-suite matrix | each of the five migrated consumers (`sdd-ship`, `sdd-bootstrap`, `sdd-bootstrap-interviewer`, `lite-spec`, `lite-gate`) independently exercised against the identical six cases (lite+`--full`→promote, lite+`--lite`→no-op, full+`--lite`→error-stop, full+`--full`→no-op, no-Context→compatibility fallback, existing-but-invalid-Context→`PROJECT_CONTEXT_INVALID`) — 30 independent assertions | Planned |
| AC-040 (NEW) | REQ-001, REQ-002 | TEST-040 | component/binding duplicate-`id` semantic-validator rejection | a `components[]` fixture with two entries sharing the same `id` is rejected (`DUPLICATE_COMPONENT_ID`); a `bindings[]` fixture with two entries sharing the same `id` is rejected (`DUPLICATE_BINDING_ID`) — both at the semantic-validator layer, not the JSON Schema | Planned |
| AC-041 (NEW) | REQ-002 | TEST-041 | `adapter_paths` optional-field passthrough | a `bindings[]` entry declaring `adapter_paths` as an array of glob strings validates; a `bindings[]` entry declaring no `adapter_paths` also validates | Planned |
| AC-042 (revised — closes NEW-001, single-source seed inventory) | REQ-001 | TEST-042 | cross-cutting seed-list scaffold conformance, single-source inventory | `contracts/project-context.template.yaml` validates against the schema; a per-pattern presence check confirms `shared_paths` contains all SIX seed patterns — `specs/**`, `reports/**`, `docs/**`, `.github/**`, `tests/fixtures/**`, `CHANGELOG.md` — each `classification: cross-cutting` (this template IS the single canonical inventory; `docs/**` already subsumes `docs/adr/**`, so no separate `docs/adr/**` entry is needed); Epic A3's day-one integration fixture reads this shipped artifact DIRECTLY and validates the complete six-pattern inventory as a cross-epic test (A3's own spec is separately aligned to this identical set, closing the two-epic seed-inventory divergence) | Planned |

Notes:

- TEST-005/TEST-014/TEST-016 are each multi-fixture, per-category tests (4,
  6, and ~9 fixtures respectively) rather than a single pass/fail
  assertion — a single "rejects bad input" case would not prove each
  category is independently detected, mirroring epic-159-pillar-c's
  per-category negative-lock convention (its own TEST-052/TEST-054).
- TEST-009 and TEST-013 are the two "byte-for-byte parity with an existing
  mechanism" proofs this epic introduces (multi-runtime hash equality;
  key-resolution parity with `SDD_SUDO`/`SDD_EVIDENCE_KEY`) — both compare
  against a concrete, already-existing reference behavior, not merely an
  internal self-consistency check. TEST-037 is a THIRD such proof, added in
  this revision, against RFC 8785's own official numeric-boundary vectors.
- TEST-011, TEST-019, TEST-020 form a signing/enforcement/cooldown chain:
  TEST-011 proves staged signing works and fails closed with no key;
  TEST-019 proves the two-person gate blocks premature signing AND
  same-identity signing; TEST-020 proves the cooldown time-gate on the
  solo path. None of the three subsumes another. TEST-034 is a FOURTH,
  distinct proof in this chain (the signer never writes the live path at
  all, added in this revision to close finding B7) — it does not subsume
  or get subsumed by TEST-011.
- TEST-021/TEST-022 are a staged/live pairing (mirroring epic-159-pillar-c's
  TEST-004 and TEST-027 shape): "the staged candidate is internally correct"
  and "the live file is untouched" are independently falsifiable claims.
  TEST-038 extends this pairing to the two RESERVED (not-yet-built)
  protection categories this revision adds (resolver, generated
  projection) — proving the manifest's inventory claim, not merely the
  four concrete script families' registration.
- TEST-023 is this package's designated "cooldown/two-person/HMAC-forgery
  resistance actually holds at the tool-mediated layer" proof — it is the
  direct analogue of epic-159-pillar-c's TEST-019/TEST-020 pairing, applied
  to four new basenames (revised — was three; the canary sentinel path
  added in this revision joins the matrix) across all 12 call sites
  instead of one representative surface, and additionally
  requires the never-bypass-under-`SDD_SUDO` case ADR-0019 item 5 names.
- TEST-025 is this package's required "full+`--lite` error-stop" case the
  parent task instruction calls out by name; TEST-020 is the
  "cooldown-before-apply rejection" case (a prior draft's note
  mis-attributed this to TEST-026 — corrected here, closing the Minor
  finding). TEST-026 is, as of this revision, the
  `PROJECT_CONTEXT_INVALID` explicit-stop case (NOT a "cooldown" case and
  NOT a "treated as absent" case) — alongside TEST-009 (dual-runtime hash
  equality) and TEST-027 (host-canary challenge/response fail-closed
  proof, redesigned in this revision from a standalone-probe shape).
- TEST-030/TEST-031 (approved-context anchor contract, glob-narrowing
  algorithm) and TEST-036/TEST-037 (HMAC golden vector, canonicalizer
  boundary vectors) are this revision's "byte/verdict-exact known-answer"
  proofs — each compares against an independently hand-computed or
  anchor-snapshot-derived expected value, not merely an internal
  round-trip.
- TEST-032/TEST-033/TEST-034/TEST-035 are this revision's four new
  "integrity of the verification/publication machinery itself" proofs
  (canary two-branch non-mutation, anchored publisher, signer staging-only,
  full entry-point wiring) — each independently falsifiable, none subsuming
  another.
- No test in this feature invokes a real LLM, `gh`, or `sdd-sudo`; TEST-023
  exercises `SDD_SUDO`'s presence as a FIXTURE input (a locally-signed,
  short-TTL token constructed by the test itself), not a live sudo grant;
  TEST-027/TEST-032/TEST-035's host-canary/runtime-signature proofs are
  FIXTURE-simulated (synthetic recorded-result evidence), never a real
  agent session — the live, cross-runtime proof is Epic A8's own MANDATORY
  Done condition, an explicit forced handoff, not merely a designated
  future regression target (REQ-010, requirements.md Non-goals).
