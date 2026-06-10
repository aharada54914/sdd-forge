# Verification Policy

Detect commands from repository configuration; do not invent commands.

Check available lint, typecheck, unit, integration, E2E, build, OpenAPI lint,
JSON Schema validation, dependency audit, and secret scanning commands.

Audit GitHub Actions or GitLab CI when present. Report missing checks rather
than silently adding heavy tools.

If no executable verification commands exist, create a review ticket and do
not mark the task `Done`.
