# Proposed data contract: spec-review-interrupted-recovery/v1

State: proposed Phase1 contract, not an applied recovery record or authorization.
Feature specification: specs/a9-interrupted-review-recovery/{requirements,acceptance-tests,design,security-spec,infra-spec}.md

## Entry / Outcome

Bash: spec-review-precheck.sh FEATURE ATTEMPT ROUND --recover-interrupted=RECORD
PowerShell: spec-review-precheck.ps1 -Feature FEATURE -Attempt ATTEMPT -Round ROUND -RecoverInterrupted RECORD
Recovery and reset are mutually exclusive. Duplicate, unknown and case-variant options reject. No default/implicit recovery; normal reset keeps its current terminal-contract rule (`plugins/sdd-review-loop/scripts/spec-review-precheck.sh:388-397`; `.ps1:538-555`). Missing runtime prerequisites fail nonzero. Recovery validation failure is nonzero with bounded reason and no target writes; success is a new Pending precheck and blank report, never a review verdict.

## Closed Record

UTF-8 JSON object; duplicate decoded members reject at all depths before ordinary JSON parsing. Exact required keys only. No nullable/optional record fields in this v1 observed route. Every integer is a JSON integer (not boolean, string or fractional number). All comparisons case-sensitive.

| Field | Exact type / constraint |
|---|---|
| schema | string exactly spec-review-interrupted-recovery/v1 |
| feature | string matching CLI feature; lowercase slug `[a-z0-9][a-z0-9-]*` |
| source | object with exactly attempt, round; positive integers; source round 2 or 3 with immediately preceding complete NEEDS_WORK |
| target | object with exactly attempt, round; attempt source+1, round exactly 1 |
| authorization | reference object |
| previous_contract | reference object to source attempt / source round-1 / spec-review-contract.json |
| interrupted_precheck | reference object to source precheck-result.json |
| pinned_inputs | exactly four reference objects, sorted unique paths: current requirements.md, acceptance-tests.md, investigation.md and spec-review-calibration.md |
| interrupted_artifacts | exactly six reference objects, sorted unique paths: source precheck-result.json, reviewer-a.json, reviewer-a-reservation.txt, reviewer-a-host-receipt.json, spec-review-report.md and external reviewer-a invocation manifest |
| reviewer_a | object with exactly invocation, sequence, stage, role, run_id, host_session_id, record_sha256; invocation is reference object, sequence positive integer, stage spec, role spec-reviewer-a, nonempty run/session strings, record_sha256 lowercase SHA256 |

Reference object has exactly path and sha256: path is nonempty repository-relative slash-separated string with no absolute prefix, dot/dotdot/empty segments, backslashes, tab, newline, NUL or other control characters; sha256 matches `[0-9a-f]{64}`. Validate every file and ancestor as real nonsymlink contained paths (lexists catches dangling symlinks). A reference must name its canonical role-specific path, not an arbitrary same-content file. The reviewer_a.invocation duplicates the inventory invocation reference exactly. All repeated pins agree, not merely independently hash.

No verdict, copied ledger-tip hash, approval status or reservation-writing field exists. Unknown fields reject at every object level. Legacy invocation manifests retain their own existing schema and historical path-normalization rules; recovery references themselves are relative.

## Authorization Input (AUTH-001)

Separate human-origin UTF-8 artifact, with exactly one bare line for each binding:

Feature: FEATURE
Source Attempt: N
Source Round: R
Target Attempt: N+1
Target Round: 1
Maximum Rounds: 3
Decision: Authorize interrupted A-before-B recovery
Recovery Binding SHA256: DIGEST

Additional prose may describe capture, without duplicating any required binding. Before launch, the orchestrator must match the original human approval and the human's actual application report in the user channel to the exact artifact and approved content/binding digest, retaining the original user-message references and digest. Agent self-claims, summaries, artifacts alone and human-copy transaction logs alone are not accepted origin evidence. Unknown or mismatched origin blocks launch. The validator checks the eight binding contents, raw artifact hash and recovery binding; it does not authenticate human authorship. No cryptographic signature, new approval sidecar or new product approval is introduced. AUTH-001 records existing scoped approval and actual human application; missing execution evidence blocks real recovery, not drafting.

To avoid a circular hash, Recovery Binding SHA256 is SHA256 of canonical JSON of the recovery record with the top-level authorization member removed: recursively sort object keys, retain array order, UTF-8, no terminal newline, separators comma/colon without spaces, ensure_ascii true. Numbers are contract-constrained integers. All remaining fields and pins are bound. The complete authorization artifact's raw SHA256 then goes in authorization.sha256. The complete recovery record's raw SHA256 is persisted in the new precheck. Any binding mismatch rejects. AUTH-001 captures the already-approved scope; it does not ask for a new product decision.

## Semantic Validation

1. Pending exactly; actual immediately previous attempt's latest round equals source. Target matches CLI and source+1/1; target absent including dangling symlink. No status normalization on this route.
2. previous_contract hash matches and existing own-stage contract validation establishes NEEDS_WORK with coherent precheck, both reviewers, summary and integrated verdict (`spec-review-precheck.sh:225-364`). Use that validator, not a verdict-string-only check. Existing negative fixtures remain applicable.
3. Interrupted precheck is own feature/source spec-review-precheck/v1 Pending; all four pinned live inputs match its saved hashes and A invocation manifest. Recompute existing composite requirements:acceptance:investigation digest and match input_sha256; calibration stays separately pinned. No absent-investigation legacy shape is admitted by this observed v1.
4. Exact six-item interrupted inventory matches raw disk bytes. Source directory contains exactly five inventory-local files; reject extra/subdirectory entries, B output/receipt/reservation, integrated summary/verdict/contract, or any complete round. External A invocation matches source and A allocation session. A raw is preserved unreadable-input interruption with BLOCKED diagnostics, host receipt records execution not started, interrupted diagnostic report contains no final integrated result. The actual source report records launch failure and B not launched (`reports/spec-review/epic-197-a9-dogfood/attempt-3/round-3/spec-review-report.md:5-11`); it is not blank. These diagnostics never become completed reviewer results (`review-context-boundary.md:260-269`).
5. Reuse validate-review-context-set.sh/.ps1 without reserve. Persisted A must match sequence/stage/role/run/session/record hash and input binding, and reservation receipt's REVIEW_CONTEXT_OK facts. Full chain must validate; later valid records are accepted, historical tip hash is not a current-tip test (`validate-review-context-set.sh:518-573`). Reject duplicates, partial collisions, wrong previous hash or broken prefix. Record_sha256 binds the historical record, not the whole ledger.
6. Scan canonical invocation manifests for the same feature/source round and correlate persisted ledger input bindings. Require only the one A launch and no B launch/reservation, including orphan records attributable to the source. If attribution cannot exclude B, reject; absence of a local reviewer-b file alone is insufficient. No re-reservation and no synthesized B evidence.
7. Pure checks precede the existing single-writer lock; under that lock recheck all pins, source latest-ness, authorization/record hash and absent destination before publication. Reuse existing destination containment and lock semantics. No old evidence, ledger, input or status is changed.

## Additive Precheck Provenance / Compatibility

New route still writes spec-review-precheck/v1 with existing core fields, Pending, reset false, target feature/attempt/round and freshly computed same input pins. Add exactly:

recovery: {record_path: relative path to admitted record, record_sha256: its raw SHA256}

This object is optional for legacy prechecks and required for recovery-generated prechecks; when present validate exact keys/types and referenced bytes. Include the whole generated precheck in downstream reviewer manifests as usual. Neither this field nor the recovery record supplies verdict, PASS, review reservation or stage advancement. Current production construction is `spec-review-precheck.sh:440-449`; its consumers require compatibility tests before implementation release. Successful initial publication creates only precheck-result.json and blank spec-review-report.md through existing target writer. Failures before publication create no target; a partial I/O failure is nonzero with no valid successful evidence, leaves partial target fail-closed for separate remediation and releases only its own lock.

## Concrete Parameter Sets for Acceptance Matrix

TEST-050/051/052/055 enumerate every field in Closed Record, source/target, reference, reviewer_a and recovery objects; TEST-053 includes escaped duplicate member names. TEST-057/083/086/088 enumerate authorization, previous_contract, interrupted_precheck, all four pinned_inputs, all six interrupted_artifacts, reviewer_a.invocation and saved recovery.record_path slots. Missing and altered are separate fixtures for TEST-062-067. No omission or sampling is permitted. Both runtimes exercise each fixture separately; parity includes independent operator and cmdlet/language case-sensitivity checks.

## Scope

Only observed A-interrupted-before-B with preceding complete NEEDS_WORK. No change to global approval validators, terminal-tier resume, task/impl gates, guards, historical rounds or ledger. Proposed consumer updates require concrete dependency evidence and reviewed scope; no broad infrastructure rewrite.
