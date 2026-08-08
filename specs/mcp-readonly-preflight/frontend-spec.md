# Frontend Spec: mcp-readonly-preflight

## Technology Stack

**N/A — no browser, no frontend bundle, no client-side code.**

The technology in scope is Markdown only. This feature edits four Markdown documents — two agent skill files (`plugins/sdd-bootstrap/skills/bootstrap/SKILL.md`, `plugins/sdd-ship/skills/ship/SKILL.md`) and two documentation files (`USERGUIDE.md`, `README.md`) — plus, conditionally, a staged copy and a manifest under `specs/mcp-readonly-preflight/human-copy/`.

There is no HTML, no CSS, no JavaScript, no build tooling, and no bundled asset produced or modified by this feature.

## The TypeScript that exists but is not touched

Stating this explicitly, because "MCP" in the feature name could reasonably suggest otherwise.

This repository does ship TypeScript that is bundled for distribution: `mcp/sdd-forge-mcp`, `mcp/local-env-mcp` and `mcp/ci-mcp` each build to a `dist/index.js` esbuild bundle, which the installer registers as a stdio child process (`install.sh:355-357`). ADR-0003 attaches a same-commit rebuild obligation to changes in those sources.

**None of it changes here.** BL-001 holds every file under `mcp/` untouched, so:

- no `dist/` output is regenerated;
- ADR-0003's same-commit rebuild obligation does not attach;
- `git diff --exit-code -- dist/` is not a leg of any acceptance criterion in this feature.

The three ACs that concern the MCP servers — AC-014, AC-015, AC-016 — are **assertions about existing state**, verified by reading the tool registry (`mcp/sdd-forge-mcp/src/server.ts:65-219` and its equivalents). They are regression protection for a property that is already true (INV-006: fourteen registered tools, none write), not a specification for new code.

Recorded as N/A rather than omitted, matching this repository's convention for non-frontend features.
