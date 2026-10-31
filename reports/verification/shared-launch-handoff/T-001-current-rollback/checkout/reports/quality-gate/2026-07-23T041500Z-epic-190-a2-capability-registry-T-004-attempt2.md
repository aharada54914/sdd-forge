Task: Author the Registry validator and the provider-terms allowlist
Task ID: T-004
Feature: epic-190-a2-capability-registry
Run ID: RUN-epic-190-a2-capability-registry-qg-T-004-a2-seq0348
Host Session ID: SESS-qg-epic-190-a2-capability-registry-T-004-a2-0348
Ledger Sequence: 348
Allowed-Input Manifest: reports/review-context/pending-epic-190-a2-capability-registry-sdd-evaluator-T-004-a2-seq0348-manifest.json (sha256 805a3cbd9e5a8fa4275bfd2d48e2a1eef7d6d006b5d5c834f1fb4a0a39fb298a)
Attempt: 2 (post-remedy, re-evaluation of RT-20260723-001)
Prior Attempt: reports/quality-gate/2026-07-23T020000Z-epic-190-a2-capability-registry-T-004-attempt1.md (NEEDS_WORK, Critical 0 / Major 2 / Minor 3)
VERDICT: PASS

## Launch Integrity (verified, not trusted)

- Ledger final record is sequence 348, stage quality, role sdd-evaluator, run_id/host_session_id matching the assignment exactly.
- Recomputed record_sha256 for seq 348 from `348|quality|sdd-evaluator|RUN-...-a2-seq0348|SESS-...-a2-0348|4ba28ca4...` = 765bbb223f8601a6dfc37fda767f1a87dafff6d2a0e5e9e8598148e001f1b319 — matches the reserved value.
- Recomputed seq 347 record_sha256 = 4ba28ca4... — equals seq 348's previous_record_sha256; chain 346->347->348 consistent.
- All 53 allowed-input manifest entries hash-match actual file content (0 missing, 0 mismatched).
- Working tree clean; evaluator modified no repository file.

## Default-FAIL Verification Contract (Risk: high; Required Workflow: tdd)

High tier = medium-tier set + requirement-traceability; every test-type check carries non-empty red_evidence/green_evidence.

| Check | Type | passes | red_evidence | green_evidence / evidence |
|---|---|---|---|---|
| unit-and-acceptance-suite (sh) | acceptance-tests (tdd) | true | verification/T-004/red-sh.log (11/12 vs stub) + red-sh-remedy.log (25 pass / 2 fail; the two collision assertions fail against pre-remedy 2e79289) | Re-ran `bash tests/validate-capability-registry.tests.sh` -> pass=27 fail=0, exit 0; green-sh-remedy.log 27/0 |
| unit-and-acceptance-suite (ps1) | acceptance-tests (tdd) | true | red-ps1.log + red-ps1-remedy.log (25/2, same two collision assertions) | Re-ran `pwsh -NoProfile -File tests/validate-capability-registry.tests.ps1` -> pass=27 fail=0, exit 0; green-ps1-remedy.log 27/0 |
| gate-implementation-collision (AC-016) | source+differential | true | Ran pre-remedy validator (git 2e79289) vs adversarial registries: NO gate-implementation-collision line emitted (bug reproduced) | Post-remedy validator on my own crafted registries: exit 1 + `gate-implementation-collision: [...] all resolve to <real path>`; symlink-alias collision, 3-way collision, and no-false-positive clean case all correct |
| collision/unregistered independence (AC-016+AC-017) | source | true | n/a | 3-way collision fixture + an unreferenced check-bar.py in one run emits BOTH gate-implementation-collision AND unregistered-script; neither masks the other |
| non-.py implementation_ref rejection (AC-016) | acceptance-test | true | already-passing pre-remedy (untested) | TEST-016(1): .sh ref does not register its .py master -> master flagged unregistered-script; traced fixture + assertion, discriminating |
| symlink resolution (AC-016) | acceptance-test | true | already-passing pre-remedy (untested) | TEST-016(2): gate->check-registered-symlink.py (real mode-120000 symlink) registers the real master; assert_not_contains discriminates a broken resolution |
| requirement-traceability (high-tier) | traceability | true | n/a | REQ-003(a-i)/AC-014..022,AC-039 mapped to TEST-014..022/028/039; Done-When items all satisfied; design.md rule 4 + requirements.md L268 + AC-016 map to the collision behavior |
| declared-output integrity | output-binding | true | n/a | Recomputed sample Outputs hashes (validator.py f689e38d, tests.sh 9fdc94bd, tests.ps1 0f0041b8, T-004.md b1882ffb, RT ticket ba14363f) — all current; bc60969 removed non-parseable " (remedy)" from 3 cells |
| provider-neutrality Boundary B1 (AC-020) | security | true | n/a | TEST-020: provider term fires; durable_workflow clean-fixture no false positive; check (g) scans every string field |
| suite + CI registration (AC-028) | ci-resilience | true | n/a | run-all.sh:60 / run-all.ps1:43 register the suite; live .github/workflows/test.yml byte-unchanged since 2e79289; human-copy test.yml/MANIFEST unchanged; suite asserts staged-candidate sha256 == MANIFEST |
| scope discipline | spec-conformance | true | n/a | 81c9cab bounded to validator.py + both suites + 3 fixtures + symlink + 4 logs + RT + report; bc60969 report-format only; no unrelated edits |

## Findings

Critical: 0
Major: 0
Minor: 3 (recorded, non-blocking)

- [Minor] reports/implementation/epic-190-a2-capability-registry/T-004.md (## Outputs) — the committed symlink tests/fixtures/capability-registry/identity-bidirectional-repo/plugins/sdd-quality-loop/scripts/check-registered-symlink.py (git mode 120000, added in 81c9cab, load-bearing for TEST-016(2)) is mentioned only in the Remedy prose, not as an Outputs-table row with a path+hash pair. Report-completeness/traceability gap; the file itself is present and functionally verified. Also surfaces as the manifest omission below.
- [Minor] specs/epic-190-a2-capability-registry/design.md:496-506 — the diagnostic-ID table enumerates only checks (a-i) and does not list the `gate-implementation-collision` sub-diagnostic; it is documented only in the validator module docstring. Not a conformance defect: the collision behavior itself is specified in prose (design.md rule 4 "Wrapper grouping", requirements.md:268, AC-016) and the diagnostic string is not spec-mandated. design.md is a spec file, correctly not edited by an implementation task. Record-only.
- [Minor] reports/review-context/pending-...-seq0348-manifest.json — the allowed-input manifest omits docs/review-tickets/RT-20260723-001.yml even though T-004.md's Outputs table declares it (hash ba14363f..., independently verified as current). Manifest-construction/process observation, outside T-004 implementation scope; RT content was treated as a claim and independently verified.

Attempt-1 Minor findings 3-5 (check (d) top-level-only glob scope; check (g) substring false-positive risk; fully-clean fixture coupling to check-contract.py) remain durably recorded in docs/review-tickets/RT-20260723-001.yml:27-28 and T-004.md:328-331 and are appropriately deferred — I concur they are genuinely Minor and out of the two-Major remedy scope; not escalated.

## Attempt-1 Major Resolution

1. Wrapper-group collision undetected (AC-016) — RESOLVED. check_c_unregistered_script now keys real-path -> [gate ids] and emits gate-implementation-collision when len>1. Independently reproduced: pre-remedy 2e79289 emits no collision diagnostic (exit 0 on collision absent other errors); post-remedy emits exit 1 naming all colliding gate ids for direct, symlink-alias, and 3-way cases; no false positive on distinct masters.
2. TEST-016 three missing assertions — RESOLVED. TEST-016(1) non-.py-ref, TEST-016(2) symlink resolution, TEST-016(3) collision (naming both ids) all present in both runtimes; each traced against its fixture and confirmed discriminating (non-vacuous); RED-remedy logs show exactly the two collision assertions failing pre-remedy, GREEN 27/27.

## Domain Surfaces

- Security (provider-neutrality Boundary B1): touched — verified (AC-020, check (g)).
- Performance / Accessibility: not touched — out of scope.

## Decision

All six Done-When conditions satisfied; zero Critical, zero Major. T-004 -> Done.
Post-Done: T-005..T-007 remain Approval: Draft / Status: Planned, so per SKILL.md Post-Done step 3 the retrospective is deferred.

## Checked (self-executed)

- Re-ran both suites: 27/27 each, exit 0.
- Crafted independent collision registries (symlink-alias, 3-way, clean) with --repo-root; confirmed correct exit codes and diagnostics.
- Ran pre-remedy validator (git show 2e79289) against the same cases; confirmed the collision was silently absorbed (differential proof).
- Traced the three new fixtures/assertions and the mode-120000 symlink; confirmed non-vacuous.
- Verified run-all registration, live CI byte-unchanged since 2e79289, remedy change surface bounded, sample Outputs + ledger + manifest hashes recomputed.
