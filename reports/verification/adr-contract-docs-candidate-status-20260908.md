# ADR contract candidate — incomplete, do not apply

Ticket: RT-20260908-004
Candidate: `adr-contract-docs-candidate-20260908.patch`

This is a data artifact containing a proposed five-file diff, not an applied
product change. It covers the template, boundary reference, both reviewer role
documents and orchestration instructions. The nine protected runtime consumers
and their full regression coverage are still missing. Do not apply this slice
on its own, merge it, or treat it as a completed human-application package.

## Base observations

The following source SHA-256 values were obtained before candidate creation:

| Source under plugins/sdd-review-loop/ | SHA-256 |
| --- | --- |
| templates/impl-review-contract.template.json | 30266f405385bb8cebb41d9ff860b0d51268cb88461fe90354918f00c551430b |
| references/review-context-boundary.md | e4b57e3be96ca39d06e329eb6bca6818d812a57b936c9a4f58a8d3f9f316c757 |
| agents/impl-reviewer-a.md | a516e1f23e53814a7e7d28cbea76986d477c505d85ada161dbf269c8a988f377 |
| agents/impl-reviewer-b.md | 1fc17ed207e03eba96f833e904bc7e9c0dff89d8ef4216d07b751466fa0c061c |
| skills/impl-review-loop/SKILL.md | c211628ffadad5d9bc624e07f9ed5265a7416495316e2b76a7a83b1b9b806653 |

## Verification boundary

A read-only Node command intended to compare exact old hunk text to these
sources and calculate candidate hashes in memory was rejected by PreToolUse.
It did not execute. The subsequent planned `git apply --stat` call was not
reached. No alternate wrapper, copy or renamed validator was used to retry.
Therefore patch applicability, candidate hashes and candidate JSON parsing
are NOT verified. The recorded base hashes are observations, not proof of
current freshness at a future human application.

## Primary review notes — not independent formal approval

The candidate preserves the invocation schema, restricts ADR authority to the
bound design, requires complete precheck/manifest/contract sets, distinguishes
current and historical freshness, and prohibits retroactive evidence repair.
The candidate now explicitly extends each role's earlier Inputs allowlist only
by the admitted ADR set. Its next-round edit-summary diagnostic also names bound
ADR inputs, consistent with the ADR-only progress rule. These are candidate-text
corrections, not an applied contract or an independently approved implementation.

Next: complete runtime consumer changes
as a human-application patch, and obtain actual applicability and behavioral
verification through the permitted human path. Existing 4-pass/44-fail baseline
and old review FAIL records remain unchanged. No CI rerun, push, merge, task
completion or issue closure occurred in this step.

## 2026-09-09 continuation — canonical digest description

The data-only boundary candidate now spells out the byte serialization already
used by the runtime candidates: core digest order, optional sorted complete
layer map, ADR version delimiter, sorted entries with path-before-sha256 keys,
UTF-8 and no trailing newline. This does not change legacy digest semantics.
It makes the cross-runtime contract reviewable without inferring serialization
from one runtime's implementation. Independent implementation review remains
pending; this is not a product change or a completed RT004 fix.

Candidate SHA-256:
`9d5f5ee19cae29ab2d155241e3e722fdec6fe47fee52c991423afffd2bd0c269`.
`rtk proxy git apply --numstat reports/verification/adr-contract-docs-candidate-20260908.patch`
exited 0 and parsed all five file diffs. It did not apply anything or verify
source anchors. `rtk proxy git diff --check` exited 0; untracked candidate
format was checked by the separate numstat parse, not by that git diff.

A separate read-only Node command comparing the Bash generation candidate's
hunks with original protected source was denied by PreToolUse. It was not
executed or retried through an alternate wrapper. That candidate's source
applicability remains unverified here. Do not treat successful documentation
patch parsing as verification of the runtime patch.

GitHub still lists seven open PRs at the previously recorded head hashes.
PR394's exact-head required-checks and Windows test are terminal FAILURE in
run 34023439393, not a live run to wait on. No CI rerun, commit, push, merge,
review-verdict edit or issue closure occurred in this continuation.

## 2026-09-09 continuation — interrupted reviews fail closed

Current candidate SHA-256:
`a092e0e5ef2b86815d0b2b15a26b260c7e9826945f7bd4e0bd8d8e0e96311b15`.
This supersedes the preceding candidate hash, not any historical evidence.
The boundary and orchestration sections now distinguish saved interruption
diagnostics from completed review evidence. They prohibit fabricated results,
successful integration of an interrupted round and implicit reset/identity
reuse. No new failure schema or blanket Critical classification is introduced.
See rt004-missing-input-contract-proposal-20260909.md for calibration evidence
and the independent advisory that narrowed the proposal to this ticket scope.

The five-file patch parsed successfully with git apply --numstat, without
application or source-anchor verification. Runtime code remains unchanged.
The original-path workflow RED remains 14 passed / 96 failed; it is not a
candidate run. The current test inventory includes missing filesystem input
and exact-check mutations, but no explicit interrupted-review completion
case was found in its mode lists (tests/impl-review-adr-inputs.tests.sh:281,
616). Do not claim that a filesystem admission test proves post-precheck
interruption behavior. Add that coverage before claiming this boundary tested.

The complete bundle is still not ready for protected human application.
