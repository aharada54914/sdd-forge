# T-001 Validation Summary

- Date: 2026-08-08
- Run ID: `a6-t001-resume-20260808T125638Z`
- Scope: `epic-194-a6-lite-integration` / `T-001`
- Candidate: `specs/epic-194-a6-lite-integration/drafts/apply-protected-files.ps1`

## Critical RED to GREEN

| Boundary | RED against unchanged protected baseline | GREEN against draft candidate |
|---|---|---|
| Ordinal control + lowercase digest | `-SecurityRegression case-sensitive`: 25 pass / 11 fail; TEST-008a..g all failed | focused suite Green; included in full 45/45 |
| Ancestor link + canonical/atomic containment | `-SecurityRegression ancestor-symlink`: 26 pass / 11 fail; external target was modified and containment/race defenses were absent | focused suite Green; included in full 45/45 |
| Recursive nested `PROPOSED/` | `-SecurityRegression nested-proposed`: 27 pass / 5 fail; TEST-010b lacked the required explicit policy | focused suite Green; included in full 45/45 |

The old baseline also lacks the candidate's real-CLI post-copy corruption seam,
so four TEST-006 failures appear in all three RED totals. The Critical-specific
failures are separated in `red-critical-*.log`.

Final commands:

```text
pwsh -NoProfile -File tests/human-copy-runner-contract.tests.ps1 -SecurityRegression all -RunnerUnderTest specs/epic-194-a6-lite-integration/drafts/apply-protected-files.ps1
# Results: 45 passed, 0 failed

bash tests/human-copy-runner-contract.tests.sh
# Results: 45 passed, 0 failed
```

## Contract coverage

- Three-way declared/manifest/recursive-payload equality: payload extra,
  payload missing, manifest extra, and manifest missing each reject before all
  four live targets change.
- Per-target staged hash and real-CLI installed post-copy hash are exercised.
- Exact ordinal control names are excluded; mis-cased controls are payload and
  are rejected. Uppercase digest text is rejected by grammar.
- Feature-scoped lookup ignores the Epic-136 prefix.
- Static ancestor links, canonical traversal, and deterministic post-validation
  ancestor substitution are rejected without modifying external/live bytes.
- Nested `PROPOSED/` is recursively enumerated and explicitly rejected.
- Both run-all twins register this suite first among Epic-194 suites; the CI
  fragment is present only as a non-protected draft.

## Independent reviews

- Security re-review: PASS, Critical 0 / High 0.
- Contract re-review: Critical 0 / Major 0; independent full suite 45/45.
- These are implementation/review evidence, not the repository's formal
  `quality-gate` Done verdict. No quality gate was run.

## Repository-level state and constraints

- Prerequisite recheck: 10 present / 0 missing (`preflight-prerequisites.log`).
- Earlier scoped structure check: PASS (advisories only).
- Final `bash tests/run-all.sh`: exit 1, 97/102 suites passed. The five
  failures were the pre-existing human-copy/CI-state failures in
  `deterministic-lane-selfcheck`, `repository-release-validation`,
  `design-system-contract`, `design-sync-standing-consent`, and
  `design-sync-scan`; the T-001 suite itself passed 45/45 inside that run.
- `tasks.md`, every `specs/*/human-copy/` path, `.github/workflows/test.yml`,
  and protected gate targets were intentionally unchanged.
- The protected runner/manifest/CI candidate therefore remain unapplied, and
  the task cannot satisfy governance or receive a quality-gate Done decision.
