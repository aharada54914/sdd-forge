# Remaining branch content recovery and retirement

The original remaining 53 non-main remote branch tips are retained by annotated
`archive/20261031/<original-branch>` tags. Every remote tag was peeled and compared
to its original branch SHA before retirement. `archive-index.json` records the
mapping. The 18 t011 experiment/baseline names have no literal references in the
current main tree. Historical experiment artifacts remain in the archived commits.

`content-audit.json` records the content decisions for the other old work branches.
Unlike the previous ancestry-only audit, this distinguishes existing/superseded
content, useful changes to recover, and separate product expansions not adopted.

## Selected changes

- PR #640 interrupted-review recovery: selectively port admission and saved-record
  validation while retaining current research/ADR conditional input support. Run
  positive and tampering/consumption tests; hashes do not authenticate human origin.
- MCP per-operation report lookup: recover commit 7850d3fb without the unrelated
  cloud product lineage. Reuse guarded report bytes within one synchronous call,
  never across requests or as an authorization/verdict cache.
- Update the pinned Claude action to verified v1.0.259 and js-yaml to 5.5.0 on the
  current lockfile, preserving newer existing dependencies. Production audit also
  identified GHSA-rmxm-3fg6-px4f; update the compatible @hono/node-server dependency
  in the three MCP lockfiles rather than ignoring the finding.

## Explicitly not adopted

The old AWS/Azure provider plugins, sdd-context continuity plugin, and replacement
CI selector are separate product expansions, not required by the current seven-
plugin integration. Their archived code is recoverable but is not claimed merged,
validated against the current product, or ready for live cloud use. Historical
human-copy/approval evidence stays frozen and is not applied as a fresh approval.

## Operational acceptance

Issue #678 remains separate: valid unpublished candidate checks and ordinary CI
are not advisory activation or a completed release cycle. The unsigned preparation
packet requires genuine owner-controlled signing before live activation. No agent
has generated a human approval or read signing-key bytes. A release/promotion
conclusion must follow actual observations, not this branch cleanup.
