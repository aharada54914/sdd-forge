# Baseline Behavior: {{feature_name}}

| Field | Value |
|-------|-------|
| Feature | {{feature_name}} |
| Date | {{date}} |
| Investigator | {{investigator}} |

## Behaviors

| BL-ID | Trigger | Observable Behavior | Evidence | Must Preserve | Verification Hint |
|-------|---------|---------------------|----------|---------------|-------------------|
| BL-001 | {{trigger}} | {{behavior}} | `{{file}}:{{line}}` | yes \| no | {{hint}} |

`Must Preserve: yes` means the refactor or bugfix must not alter this behavior.
`Must Preserve: no` means the behavior is incidental and may change.

## Known Defects

Behaviors that are intentionally **not** preserved. List here to avoid
accidentally restoring them during refactor or bugfix work.

| BL-ID | Defect Description | Evidence | Replacement Behavior |
|-------|-------------------|----------|---------------------|
| BL-NNN | {{defect}} | `{{file}}:{{line}}` | {{replacement}} |

## Environment Notes

{{environment_notes}}

Document any environment-specific behavior (OS, runtime version, feature flags,
external service stubs) that affects the baseline.
