---
name: update-traceability
description: Update Spec-Anchored AI Development traceability after implementation by connecting requirements, design, contracts, code, tests, and status. Detects spec drift and reports ambiguous gaps.
---

# Update Traceability

Use this skill after implementation or after review-ticket fixes.

## Invocation

Codex:

```txt
Use the update-traceability skill for specs/<feature>
```

Claude Code:

```txt
/sdd-quality-loop:update-traceability specs/<feature>
```

## Purpose

Update the mapping between requirements, design, contracts, code, tests, and implementation status.

## Process

1. Read `requirements.md`.
2. Read `design.md`.
3. Read `tasks.md`.
4. Read OpenAPI and JSON Schema files.
5. Inspect changed code with `git diff`.
6. Inspect added or changed tests.
7. Update `traceability.md`.
8. Detect spec drift.

## Spec Drift Examples

- A requirement exists but has no test.
- OpenAPI has an operation but no implementation.
- Code was implemented but is not described in `tasks.md`.
- A test exists but is missing from traceability.
- Architecture changed without an ADR.
- API changed without OpenAPI updates.
- JSON shape changed without JSON Schema updates.

## Drift Handling

- Small traceability gaps may be updated directly.
- Ambiguous gaps require a report under `reports/spec-drift/<timestamp>.md`.
- Major changes require human review.
- Do not perform large fixes while updating traceability.

## Status Values

Use these status values:

- Planned
- In Progress
- Done
- Blocked
- Drift Detected

Do not mark a row `Done` unless implementation and tests exist.

## Completion Report

Report:

- Traceability rows added or updated
- Code targets discovered
- Test targets discovered
- Drift found
- Reports created
- Remaining risks
