# Issue #348: reject unrelated scope identifiers

Base: c6ae82bf943cc3de265076981bf8eecb1470519e (PR #371).
This records a limited contract correction, not an Issue completion or gate verdict.

## Root cause and scope

The three related-ID arrays accepted any string containing a non-whitespace
character. Even `REF-001` satisfied an `in_scope` assertion, contrary to the
Issue and the schema's existing REQ-*, AC-* and T-* descriptions. The old
positive test explicitly accepted that unrelated prefix.

Each array now enforces its documented, case-sensitive prefix and a nonempty
whitespace-free suffix. The separate whitespace exclusion also rejects trailing
newlines that a regex end anchor alone can admit. IDs with suffixes such as
`REQ-001a` remain valid; no numeric-only convention is invented.

This validates identifier shape, not existence or relevance in an approved
artifact. It does not implement a missing gate integration, authorize a fix,
change verdicts or task state, or retrofit frozen historical reports.

## Actual verification

- Test-first: `npm run pretest` followed by
  `node --test dist-test/tests/cross-critique-contract.test.js`:
  11 passed, 3 failed, exit 1. All three failures accepted `REF-001`.
- After correction: `npm test` in `mcp/sdd-forge-mcp`:
  262 passed, 0 failed, 0 skipped, exit 0.
- Actual macOS PowerShell `Test-Json -SchemaFile` using the same three fields,
  three assessments and eight inputs per combination: 72 passed, exit 0.
  Inputs: unrelated prefix, lowercase prefix, empty suffix, leading space,
  trailing space, trailing newline, embedded space, and valid `PREFIX-001a`.
- `git diff --check`: exit 0.
- `npm run typecheck`: exit 0; `npm audit --omit=dev`: zero vulnerabilities.

## Review and remaining work

Author-side reviewer pass found no Critical findings in the limited delta.
No dependency, file-reading permission, state transition, test skip or CI
requirement changed. Coverage percentage was not measured. Existing schema
consumers and all MCP tests remain compatible with documented IDs.
Latest-head CI, required third-party approval, safe merge, main verification,
and the remaining Issue #348 acceptance conditions are still required.
