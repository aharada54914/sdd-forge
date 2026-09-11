# PR #381 report timestamp validation

Review finding: https://github.com/aharada54914/sdd-forge/pull/381#discussion_r3991438209

Base commit: bdfa5363fa5c406008cb455bc06be4a58acc4b87

The currentness checker disabled JSON Schema format validation, so a report
with a matching receipt and invalid `created_at` could be accepted. Enable
Ajv's standard date-time validation using an explicit `ajv-formats` dependency.
No currentness, digest, or review acceptance condition was relaxed.

## Observed verification

- Added invalid-date regression cases first. The compiled focused test failed
  with actual exit status 0 versus expected 1 for invalid metadata.
- After the fix, the focused test passed (1 passed, 0 failed).
- Accept valid leap-day and timezone-offset timestamps; reject nonsense,
  February 30, date-only input, and a timestamp without a timezone.
- `npm ci --prefix mcp/sdd-forge-mcp --ignore-scripts`: exit 0; audit reported
  zero vulnerabilities. The lock already contained ajv-formats 3.0.1.
- `npm test --prefix mcp/sdd-forge-mcp`: 263 passed, 0 failed, 0 skipped.
- `npm run typecheck --prefix mcp/sdd-forge-mcp`: exit 0.
- `git diff --check`: exit 0.

These are local results, not a claim of latest-head CI or independent review
success. The evidence-publication, citation, and scratch-root review findings
remain unresolved; this change alone does not make PR #381 merge-ready.
