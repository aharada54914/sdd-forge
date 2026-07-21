# Acceptance Tests: epic-189-a1-project-context

TEST IDs (TEST-001..TEST-029) are namespaced to this feature
(`specs/epic-189-a1-project-context/`) and map 1:1 to AC-001..AC-029 in
requirements.md. All tests are Draft/Planned — none has run, since no
implementation exists yet (this is a spec-only package).

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | schema conformance (positive + negative) | JSON-Schema validator run against `contracts/project-context.schema.json`: a fixture exercising every field validates; a fixture missing a required field (`workflow`, or any of its three sub-fields) is rejected | Planned |
| AC-002 | REQ-001 | TEST-002 | field-allowlist coverage | fixture-driven per-path presence check: each of the 8 ADR-0020 allowlist paths resolves against a schema-defined field | Planned |
| AC-003 | REQ-002 | TEST-003 | schema conformance (positive) | `contracts/provider-bindings.schema.json`: required-field fixture validates; `state_authority`/`credentials` passthrough fixture (unanticipated shape) still validates | Planned |
| AC-004 | REQ-002 | TEST-004 | provider-neutrality proof | fixture with an invented `provider` string value validates — proves no fixed Provider enum exists | Planned |
| AC-005 | REQ-003 | TEST-005 | rejection lock (4 categories) | `canonicalize-sdd-yaml.py`: one fixture each for anchor / alias / custom tag / duplicate key, each exits non-zero with a category-specific diagnostic | Planned |
| AC-006 | REQ-003 | TEST-006 | YAML-1.2-core-schema proof | fixture with `on`/`off`/`yes`/`no` scalars parses them as strings, not booleans | Planned |
| AC-007 | REQ-003 | TEST-007 | NFC-normalization proof | precomposed-vs-decomposed Unicode fixture pair produces byte-identical canonical output and identical SHA-256 | Planned |
| AC-008 | REQ-003 | TEST-008 | JCS-compliance proof | canonical JSON output matches a hand-computed expected byte sequence for a fixture with non-canonical key order/number formatting | Planned |
| AC-009 | REQ-003, REQ-011 | TEST-009 | multi-runtime hash-equality + dispatch proof | `.py`, `.sh`, `.ps1`, `.js` (where Node available) produce an identical SHA-256 for the same fixture; each wrapper is proven to dispatch to `.py`, not reimplement | Planned |
| AC-010 | REQ-004 | TEST-010 | schema conformance (positive + negative) | `contracts/approval-sidecar.schema.json`: full-field fixture (non-null `second_approval`/`effective_at`) validates; `hmac` shorter than 64 hex chars, or containing uppercase, is rejected | Planned |
| AC-011 | REQ-004 | TEST-011 | signing round-trip + fail-closed proof | `generate-approval-sidecar.py` + `validate-approval-sidecar.py` round-trip verifies with a resolvable key; with no resolvable key (all 4 steps exhausted), the tool exits non-zero and writes no file | Planned |
| AC-012 | REQ-004 | TEST-012 | preimage self-reference exclusion | internal preimage-dump test hook: two sidecars differing only in `hmac` value produce the identical preimage | Planned |
| AC-013 | REQ-004 | TEST-013 | key-resolution byte-parity | 4-case fixture matrix (env var / env-file / home-path / none) asserts identical key bytes and BOM/whitespace-stripping to `_resolve_sudo_key`/`resolve_evidence_key` | Planned |
| AC-014 | REQ-005 | TEST-014 | four-way negative proof | `validate-approval-sidecar.py`: hash mismatch / HMAC mismatch / unregistered approver / future `effective_at` — four independent fixtures, each an independent rejection | Planned |
| AC-015 | REQ-005 | TEST-015 | positive proof | fixture with correct hash, HMAC, registered approvers, and null/elapsed `effective_at` validates PASS | Planned |
| AC-016 | REQ-006 | TEST-016 | per-category classification + N/A reporting | `detect-policy-weakening.py`: one before/after fixture per implemented weakening category classifies `policy_weakening: true`; each of the 4 documented-N/A categories is reported as N/A explicitly | Planned |
| AC-017 | REQ-006 | TEST-017 | negative proof | a strengthening-change fixture (`advisory`→`required`) classifies `policy_weakening: false` | Planned |
| AC-018 | REQ-006 | TEST-018 | two-person/cooldown verdict | 2-identity registry fixture → `two_person_required: true`; 1-identity registry fixture → `two_person_required: false, cooldown_hours: 24` | Planned |
| AC-019 | REQ-004, REQ-006 | TEST-019 | two-person enforcement at signing | `generate-approval-sidecar.py` refuses to sign a policy-weakening change with only `primary_approval` when the verdict requires two-person; signs when both approvals present | Planned |
| AC-020 | REQ-004, REQ-005, REQ-006 | TEST-020 | cooldown enforcement (generation + validation) | solo-approver policy-weakening sidecar gets `effective_at` = signing time + 24h; validator rejects applying it before that time and accepts after | Planned |
| AC-021 | REQ-007 | TEST-021 | staged-inventory conformance | staged `human-copy/.../guard-invariants.json` candidate's `protected_gate_suffixes` includes every new path; matching staged `generate-guard-invariants.py` candidate's `expected_protected` includes the same set; staged-tree `--check` passes | Planned |
| AC-022 | REQ-007 | TEST-022 | live-file-unchanged proof | SHA-256 of the LIVE `guard-invariants.json`, `generate-guard-invariants.py`, and the four generated files is unchanged before/after this epic's own agent commits | Planned |
| AC-023 | REQ-008 | TEST-023 | protected-write-boundary + never-bypass proof | post-human-copy-application: a write attempt against each of the three new protected basenames is denied, including under an active `SDD_SUDO` token | Planned |
| AC-024 | REQ-009 | TEST-024 | document conformance | `PLUGIN-CONTRACTS.md` Track Detection section documents the 4-case Project-Context-present rule ahead of the retitled compatibility-fallback order | Planned |
| AC-025 | REQ-009 | TEST-025 | behavior lock (error-stop + promotion) | fixture project (`spec_profile: full`) + `--lite` → explicit error, execution stops; fixture project (`spec_profile: lite`) + `--full` → promotes, no error | Planned |
| AC-026 | REQ-009 | TEST-026 | fail-closed compatibility-fallback proof | a Project Context that fails `validate-approval-sidecar` is treated identically to "no Project Context" by every migrated consumer | Planned |
| AC-027 | REQ-010 | TEST-027 | handshake fail-closed proof | real, correctly installed guard → `HOOK_ACTIVE`; fixture stub guard that does not deny → `CAPABILITY_RUNTIME_UNAVAILABLE`, never `HOOK_ACTIVE` | Planned |
| AC-028 | REQ-011 | TEST-028 | twin registration + protected-file 3-part proof | every new script's `.sh`+`.ps1` test twin self-registers in `tests/run-all.sh`/`.ps1`; `.github/workflows/test.yml` registration proven via the staged/live-unchanged/post-copy-registered 3-part shape | Planned |
| AC-029 | REQ-011 | TEST-029 | non-use + CI-resilience declarations | no suite invokes a real LLM/`gh`/`sdd-sudo`; every mktemp root is `pwd -P`-normalized; no possibly-empty bash array under `set -u` | Planned |

Notes:

- TEST-005/TEST-014/TEST-016 are each multi-fixture, per-category tests (4,
  4, and ~10 fixtures respectively) rather than a single pass/fail
  assertion — a single "rejects bad input" case would not prove each
  category is independently detected, mirroring epic-159-pillar-c's
  per-category negative-lock convention (its own TEST-052/TEST-054).
- TEST-009 and TEST-013 are the two "byte-for-byte parity with an existing
  mechanism" proofs this epic introduces (multi-runtime hash equality;
  key-resolution parity with `SDD_SUDO`/`SDD_EVIDENCE_KEY`) — both compare
  against a concrete, already-existing reference behavior, not merely an
  internal self-consistency check.
- TEST-011, TEST-019, TEST-020 form a signing/enforcement/cooldown chain:
  TEST-011 proves signing works and fails closed with no key; TEST-019
  proves the two-person gate blocks premature signing; TEST-020 proves the
  cooldown time-gate on the solo path. None of the three subsumes another.
- TEST-021/TEST-022 are a staged/live pairing (mirroring epic-159-pillar-c's
  TEST-004 and TEST-027 shape): "the staged candidate is internally correct"
  and "the live file is untouched" are independently falsifiable claims.
- TEST-023 is this package's designated "cooldown/two-person/HMAC-forgery
  resistance actually holds at the tool-mediated layer" proof — it is the
  direct analogue of epic-159-pillar-c's TEST-019/TEST-020 pairing, applied
  to three new basenames instead of four pre-existing ones, and additionally
  requires the never-bypass-under-`SDD_SUDO` case ADR-0019 item 5 names.
- TEST-025/TEST-026 are this package's required "full+`--lite` error-stop"
  and "cooldown-before-apply rejection" cases the parent task instruction
  calls out by name, alongside TEST-009 (dual-runtime hash equality) and
  TEST-027 (canary non-denial detection).
- No test in this feature invokes a real LLM, `gh`, or `sdd-sudo`; TEST-023
  exercises `SDD_SUDO`'s presence as a FIXTURE input (a locally-signed,
  short-TTL token constructed by the test itself), not a live sudo grant.
