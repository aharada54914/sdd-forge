Task: Author the Registry validator and the provider-terms allowlist
Task ID: T-004
Feature: epic-190-a2-capability-registry
Run ID: RUN-epic-190-a2-capability-registry-qg-T-004-seq0347
VERDICT: NEEDS_WORK

- Model: Claude Opus 4.8 (claude-opus-4-8[1m])
- Effort: high (Claude Code has no per-invocation effort control; effort is the
  record-only x-sdd-effort value in evaluator.md, effort_applied=null)

Host Session ID: SESS-qg-epic-190-a2-capability-registry-T-004-0347
Allowed-Input Manifest: reports/review-context/pending-epic-190-a2-capability-registry-sdd-evaluator-T-004-seq0347-manifest.json (sha256 02c09c11330dcf37c9d11b6754e90087f1bfb1093505b4a2903883c6648c35e0)
Identity ledger: reports/review-context/identity-ledger.json, final record seq 347, record_sha256 4ba28ca49f05303de52a56c70322f5192dcfd8a03c54057584e2bfd38b31bcbe (recomputed, chain 1..347 intact).

## Verdict
NEEDS_WORK — two Major findings block Done. Eight of the nine REQ-003 checks
(a,b,d,e,f,g,h,i) are implemented correctly and independently verified by direct
invocation and re-run of both runtimes (23/23). Check (c)'s Gate-implementation-
identity is only partially delivered: the wrapper-group-collision leg of
AC-016/TEST-016 is missing in both behavior and tests.

## Findings
1. [Major] Wrapper-group collision not detected (REQ-003(c)/AC-016/TEST-016).
   validate-capability-registry.py:178-209. Demonstrated: two gates referencing
   the same check-*.py master pass validation (exit 0) against a clean root;
   spec requires "fail validation."
2. [Major] TEST-016 substantially unimplemented in tests/validate-capability-
   registry.tests.{sh,ps1}: no fixture/assertion for (1) non-.py implementation_ref
   rejection, (2) symlink resolution, (3) wrapper-group collision. The block
   labeled "TEST-016/017" only covers TEST-017(i)-(iv).
3. [Minor] check (d) glob is top-level only vs REQ-003(d) "anywhere in the
   repository / plugin-nested equivalent."
4. [Minor] check (g) substring matching on short provider tokens carries
   false-positive risk (spec-mandated approach; clean-fixture guards vocabulary).
5. [Minor] fully-clean fixture couples to check-contract.py being the sole
   check-*.py master (disclosed; currently valid).

## Evidence
See CHECKED list in the evaluator return: preconditions/hash-chain verified;
sh+pwsh suites 23/23; combined-duplicate non-masking; identity fixture four
AC-017 sub-cases; provider clean/dirty; real registry INV-002 gaps only; RED
11/12 non-vacuous, GREEN 23/0; CI staging + live-workflow immutability; and the
crafted-input proof that a two-gate wrapper-group collision returns exit 0.

## Decision
Retain T-004 Status: Implementation Complete (not Done). Create a blocking
review ticket for findings 1-2 and route back to implement-task. Retrospective
not invoked (gate did not reach Done).
