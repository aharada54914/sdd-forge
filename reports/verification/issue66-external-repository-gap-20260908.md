# Issue 66: external repositories exist, registration requirement remains

Date: 2026-09-08
Disposition: OPEN; read-only discovery, no external repository edits.

Observed main revisions (resolved after document reads): knowledge-mcp
`39177299f7692a72066ae20cb8fde1299400e58c`; repo-knowledge-mirror
`e13ddde941b62e84a891f9d3a47ce1f959483981`. Before implementation, re-read
the cited documents at explicit revisions to eliminate moving-ref ambiguity.

The GitHub issue explicitly requires separate-repository delivery of the
mirror CLI, consumption by read-only knowledge-mcp, and its 2026-07-10
addendum requires install-time registration for both Claude Code and Codex
using the Codex config marker block.

Both non-archived repositories already exist:

- https://github.com/aharada54914/repo-knowledge-mirror
- https://github.com/aharada54914/knowledge-mcp

The mirror's main USERGUIDE documents sync/list/status, per-destination
KNOWLEDGE_MCP_ROOTS integration, and its CLI-only boundary. Its main tree
contains nine task quality-gate reports dated July 7-8. These reports predate
the July 10 requirement and have not been audited here; their existence is
not proof of the amended requirement.

The knowledge-mcp main USERGUIDE explicitly says v1 supports manual
registration only and has no automatic installer. It supplies Claude Code,
Cursor and VS Code instructions, but no Codex marker-block instructions.
The recursive main-tree path inventory returned no installer or Codex-named
files. This is a concrete documentation/acceptance gap, not proof based only
on the issue remaining open. Source implementation and other branches still
need inspection before declaring an installer absent from all existing work.

Next: reconcile existing branches/PRs in these two repositories and their
approved specifications, then address the July 10 installation requirement
through their workflow. Do not create duplicate repositories, invent a
second mirror MCP server, or close issue 66 based on repository existence.
No live user MCP configuration was read or changed in this investigation.
