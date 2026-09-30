# Issue #137: native Windows junction coverage

Task: sdd-context-continuity / T-001 (Approved, In Progress).
Baseline: `9511bb94b046d27ab1192dd36b9e20027a124bdc`.

Added two synthetic negative cases to the existing Windows native suite:
the `context` leaf is a junction, and its `.sdd` parent is a junction.
Both require helper rejection and unchanged external content/ACL. The parent
case also requires no external `context` creation. The leaf control verifies
the correct owner, preventing an unrelated owner rejection from satisfying it.
Cleanup verifies and removes the junctions before any recursive directory removal;
failed link inspection stops cleanup rather than treating the link as absent.

Sol implemented the test; Codex reviewed it and requested the cleanup correction.
On macOS, PowerShell `Parser::ParseFile` and
`git diff --check -- tests/sdd-context/windows-store-native.tests.ps1`
both exited 0. This is syntax/diff evidence, not Windows execution evidence.

Native execution remains pending on the updated commit. The existing Windows
`mcp-tests` job runs this suite; no workflow or production code changed.
The earlier successful CI run 36765488490 does not prove these new cases.
No frozen artifact, approval, task status, review verdict or identity ledger
was changed. This does not establish T-001 Done or Issue resolution.
