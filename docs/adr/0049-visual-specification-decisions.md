# ADR 0049: Specification decisions extend the status dashboard

Status: Accepted by the user's B approval and existing-dashboard integration request.

The existing parent-owned Sites/Artifacts dashboard is defined in ADR 0048.
Add an optional `decisionSets` projection to its v1 snapshot and a seventh
view. Absence preserves old snapshots and projects. Read the bounded
`specs/<feature>/decisions.json` only through the existing path guard. Require
basis hashes of sibling specifications; drift disables selection. Canonical
Markdown remains authoritative, including its freeze/amendment procedure.

Use plain text structured diagrams (screen elements, flows or state sequences)
and equal-axis option comparisons. This avoids HTML/script execution and adds
no renderer dependency. Browser selection stays in memory and generates a
revision-bound response for the user to send through conversation. It never
writes approval or workflow state. A recorded choice is not a gate verdict.

Reuse the same private transport, publisher, parent identity and last-good/error
handling. Reject malformed decision input at collection and hosted/browser
boundaries. A presentation failure falls back to diagrams/tables in conversation;
no invented native host API or public deployment is required.

A separate inbox application would duplicate state and publication ownership;
text-only choices preserve the cognitive burden. Shared optional projection is
the smallest extension that supports visual comparison with existing hosting.

Verify before-tasks collection, drift, malformed input, non-writing selection,
keyboard controls and 320px reflow. Native Claude creation/connector access and
actual private Site deployment require their respective live host evidence;
local tests do not establish either. Reverting this additive view requires no
workflow-source migration.
