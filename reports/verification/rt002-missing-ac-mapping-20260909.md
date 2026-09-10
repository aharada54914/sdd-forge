# RT002 design-precheck AC mapping (read-only investigation)

Date: 2026-09-09
State: reference repair retained; subsequent AC-028 contract amendment under fresh spec review

The separately approved AC-028 resolution now appears in requirements.md's
Shared CI registration amendment and design.md's Authorized AC-028 design
resolution. New TEST-028 branch rows cover registration omissions, retired
artifacts, check preservation and stale baselines. These remain Planned.
Spec precheck attempt-3/round-1 succeeded; independent review is in progress.
The hashes and no-review statements below describe the earlier reference-only
follow-up, not the current amended snapshot. No new PASS is claimed.

## Authorized follow-up outcome

The user subsequently authorized: "14件のACと既存設計・テストの対応を精査し、根拠のある参照を補う範囲拡張を承認する".
Added the 14-row evidence-based crosswalk at design.md:1919. The append-only
section preserves earlier content and explicitly retains AC-028 as unresolved;
requirements.md and acceptance-tests.md were not changed in this follow-up.
The existing test contracts remain Planned, not reported as execution results.

Scoped git diff --check exited 0. The original command
`rtk proxy bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh epic-189-a1-project-context 4 1 --provenance-rereview`
now exited 0, producing the original precheck-result.json in attempt-4/round-1.
Its expected stale prior impl evidence warning remained advisory only under
the existing provenance mode. No check was changed or disabled.

Current design SHA-256: 85fc4c9d989334db1dd331e716e56bc0358f8165d1e300cee2ef4f91e19e31ca.
Unchanged acceptance SHA-256: 079567e6ef2ec31c96c77d4e635f1097e06ae74757bb668dd56050620d90f11a.
The precheck is not semantic approval. No reviewer identity was reserved,
no formal reviewers were launched and no new PASS was recorded. Resolve the
known AC-028 governing-contract conflict through separately authorized
specification changes before seeking dependent design approval. This avoids
spending a formal review attempt on a known unresolved prerequisite; it is
not a claim that the precheck itself still fails.

The investigation below is retained as the pre-authorization history.

The authorized RT002 amendment was applied to design.md, infra-spec.md and
security-spec.md. The original design precheck then rejected 14 missing AC
identifiers. This report investigates those references without expanding the
approved REQ-010 repair into unrelated specification changes.

All paths below are relative to specs/epic-189-a1-project-context/. Line
references describe the current amended working tree, not immutable release
locations. The acceptance-test rows cited below say Planned; they are test
contracts, NOT execution evidence. This investigation does not establish any
test PASS, production conformance or formal review approval.

## Individual mappings

| AC | Existing design evidence | Acceptance test contract | Remaining design-review work |
|---|---|---|---|
| AC-002 | design.md:531 schema includes the eight paths: artifact_kinds, runtime_classes, characteristics.pii/ui/auto_update/local_persistence, distribution_channels, data_classification | acceptance-tests.md:163 TEST-002 | Bind the eight-path fixture assertion explicitly; schema presence is not fixture execution. |
| AC-004 | design.md:645 provider is a nonempty string with no enum | acceptance-tests.md:165 TEST-004 | Bind the invented-provider positive fixture, not merely a generic schema test. |
| AC-006 | design.md:792 canonicalization specifies YAML 1.2 core-schema resolution; design.md:1528 repeats scalar resolution | acceptance-tests.md:167 TEST-006 | Name the on/off/yes/no string cases explicitly; core-schema prose is not the four-case proof. |
| AC-010 | design.md:673 required fields; design.md:679 nullable effective_at; design.md:683 lowercase 64-hex HMAC pattern | acceptance-tests.md:171 TEST-010 | Bind the full-field positive fixture and both short/uppercase HMAC negatives. |
| AC-011 | design.md:876 key-resolution failure refuses unsigned output; design.md:905 staged snapshot/sidecar/manifest; design.md:919 independent validation before publication; design.md:1262 key-resolution matrix | acceptance-tests.md:172 TEST-011 | Explicitly bind successful independent recomputation and no-key/no-staged-artifact assertions. |
| AC-015 | design.md:224 validator responsibilities and design.md:919 validation gate; design.md:1283 names premature effective_at negative | acceptance-tests.md:176 TEST-015 | Add explicit positive null and elapsed-time branches to the design test mapping; a premature-time negative alone is insufficient. |
| AC-018 | design.md:163 registry-to-verdict flow; design.md:718 verdict types; design.md:1765 re-derivation boundary | acceptance-tests.md:179 TEST-018 | Existing excerpts do not spell out the two-identities versus one-identity classification formula. Document the existing requirement's true/false and 24-hour rule, not just an identifier. |
| AC-020 | design.md:679 effective_at shape; design.md:919 validation gate; design.md:1765 two-person/cooldown boundary | acceptance-tests.md:181 TEST-020 | Explicit signing-time-plus-24-hours derivation and before/after validation cases are needed in the mapping. Types and general cooldown language are not that algorithm. |
| AC-022 | design.md:348 stages all six guard artifacts with pre-application staged-tree verification | acceptance-tests.md:183 TEST-022 | Add the separate live-file before/after SHA-256 assertion for agent commits; staged verification does not prove live bytes were unchanged. Keep human application distinct. |
| AC-024 | design.md:198 PLUGIN-CONTRACTS Track Detection component; design.md:1821 all four stricter-only outcomes and design.md:1822 physical-presence/fallback ordering | acceptance-tests.md:185 TEST-024 | Bind document conformance including placement before the compatibility fallback; behavior-only tests do not prove documentation order. |
| AC-025 | design.md:1428 per-consumer six-case matrix; design.md:1821 error/promotion/no-op outcomes | acceptance-tests.md:186 TEST-025 | Explicitly map the sdd-ship instance of AC-039's matrix to this AC. |
| AC-028 | design.md:1452 registration plan and design.md:1772 deployment plan retain staged/live/post-copy workflow proof | acceptance-tests.md:189 TEST-028 | Historical conflict, not just a missing reference: requirements.md:1610 still requires the per-feature workflow snapshot removed by commit c8ac93a27e2f8fc351100fb8fa76958781532797. investigation.md:513 explicitly discloses the absence and forbids treating it as satisfaction. A reviewed contract decision is required; do not restore the stale snapshot or substitute a live hash silently. |
| AC-029 | design.md:1460 directly states no real LLM/gh/sdd-sudo, pwd -P normalization, and empty-array safety; design.md:1772 deterministic lane | acceptance-tests.md:190 TEST-029 | Explicit trace reference can bind the existing declaration. It still does not prove suite conformance by execution. |
| AC-041 | design.md:642 required binding keys omit adapter_paths; design.md:650 array-of-string property; design.md:658 optional/no A1 glob interpretation | acceptance-tests.md:202 TEST-041 | Bind both present and absent field fixtures; do not introduce A3 interpretation into A1. |

## Boundary and proposed next scope

The 14 missing identifiers are not uniformly a trivial documentation typo.
Several have existing behavior descriptions and separate acceptance-test
contracts, while the positive/time/classification/live-hash obligations need
more explicit design treatment. AC-028 has a disclosed historical artifact
conflict that cannot honestly be fixed by inserting its number.

Proposed authorization: expand the design amendment to map these 14 existing
AC/test obligations truthfully, retain all mandatory checks, and resolve
AC-028 through an explicitly reviewed equivalent CI-registration contract
that does not reintroduce the deleted shared-workflow snapshot. Any change to
requirements or acceptance-tests requires a new specification review before
dependent design review; the earlier spec PASS must not be reused for changed
bytes. Preserve all prior evidence and follow the existing freeze/rebinding
process. Do not change production code or historical task verdicts here.

No failed precheck was rerun during this investigation. No reviewer was
launched. The installed impl-review-loop SKILL.md STEP 1 requires halting the
gate on nonzero precheck; no bypass or relaxed coverage check is proposed.
