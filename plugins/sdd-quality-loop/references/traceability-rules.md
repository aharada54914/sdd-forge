# Traceability Rules

Traceability connects requirements, design, contracts, implementation, and tests.

## Required Columns

- Requirement
- Design
- API/Schema
- Code Target
- Test Target
- Status

## Status Values

- Planned
- In Progress
- Done
- Blocked
- Drift Detected

## Rules

- Every implemented requirement should have a code target.
- Every important requirement should have a test target.
- Every API change should map to OpenAPI.
- Every data structure change should map to JSON Schema when applicable.
- Do not mark Done unless implementation and tests exist.
