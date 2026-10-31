# PR 371 source-accuracy follow-up

Base reviewed: 34fc2f47cae606b60b069c45a34ed9b3a7c4537d.

Fresh local verification at that commit: `npm test` in mcp/sdd-forge-mcp
passed 263 tests, zero failures/skips; `npm run typecheck` exited 0.
Test log: `/tmp/sdd-pr371-mcp-34fc2f47-20260912.log`.

The follow-up changes only ADR 0026/0027 and this report. Primary-source
review of https://arxiv.org/html/2608.18167v1 on 2026-09-12 identified an
incorrect section citation and an overgeneralized cost comparison. The ADRs
now pin the version, scope the comparison, distinguish local hash fields from
paper recommendations, and remove a claim that a sequential-first entry point
exists. ADR 0027 Decision 3 and skills/adversarial-review/SKILL.md specify the
retained blind-first protocol. No protocol, schema, test, or verdict changed.

Main-agent review of this narrow diff: no Critical finding. Identifier sweep
confirmed both ADRs use the corrected cost scope and no longer claim a shipped
sequential option. `git diff --check` passed. This is not an independent gate
PASS, nor evidence that all acceptance conditions of issues 345–350 are met.
CI for the new commit, remaining acceptance evidence, merge and postmerge
verification must still be checked. The earlier green CI applies only to
34fc2f47, not automatically to this follow-up.
