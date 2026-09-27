# Issue 137 specification readiness

## Saved work

- `d6813790`: requirements and acceptance tests now contain the bounded redaction, timeout and serialized-output contracts needed by specification reviewers. The five recorded human policy choices are unchanged.
- `a985862e`: integrated main `96c040a6cf7644981f94956e0878092d0ac85c04` without conflicts.
- Remote branch: `codex/issue137-continuity`.

## Verification

- `git diff --check` and staged whitespace check: exit 0.
- Specification precheck, attempt 1 round 1: exit 0. Its immutable receipt is in `reports/spec-review/sdd-context-continuity/attempt-1/round-1/precheck-result.json`.
- After main integration, requirements, acceptance tests, investigation and calibration still match all four receipt hashes.
- `bash tests/review-context-boundary.tests.sh`: exit 0; 32 documentation anchors verified, Bash/PowerShell reservation and replay boundary checks passed, and the investigation-manifest matrix finished with `PASS: 84; FAIL: 0`.

## Remaining boundary

No formal reviewer was launched, no identity reserved, and no review verdict, task approval or lifecycle status changed. The implementation is not complete and Issue 137 must remain open.

The repository's `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md:71-80` requires host-issued run/session identities from an idle allocation before reservation and before the first reviewer turn. Lines 47-49 also require complete canonical identity history. The branch ledger has 1,189 records; later A9 reservations remain on its separate branch. Neither a caller-created UUID nor copying selected identity rows establishes the required launch/history evidence.

Resume by checking the original identity receipts and full ledger chain, obtaining a conforming idle read-only host context, reserving reviewer A against the preserved inputs, and starting its first turn only after `REVIEW_CONTEXT_OK`. Then launch independent reviewer B with the permitted counts-and-IDs summary. Do not replay the existing precheck, infer PASS from this note, or relax live acceptance requirements.
