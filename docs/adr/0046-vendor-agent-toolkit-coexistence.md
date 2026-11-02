# ADR-0046: Vendor agent toolkits coexist; SDD Forge does not own cloud adapters

Status: Proposed. This needs a human decision. Until it is accepted it does not
amend ADR-0017, ADR-0018 or `docs/ai-dlc-foundation-decision-v2.md`.

## Context

ADR-0018 and decision document v2 anticipate Azure and AWS Provider Adapters,
a cloud-service Pack, a durable-workflow Pack and a new `sdd-operability`
plugin, to be built when a real cloud project exists.

Since then both cloud vendors have published official toolkits for coding
agents: Agent Toolkit for AWS (managed AWS MCP Server, skills, plugins; described
as generally available) and Azure Skills (skills plus Azure MCP Server
configuration). These were read from their public READMEs and announcements
only; they were not run. They cover cloud-product knowledge, IaC authoring
guidance and service operations for several hosts that SDD Forge also targets.
They do not, as far as those documents show, provide spec review, human approval,
independent verification or evidence-bound completion, which is what SDD Forge
provides.

Separately, the PreToolUse guard in `claude-hooks.json` and `hooks.json`
matches only editing and shell tools; only the kill switch matches every tool.
A cloud API call made through a vendor MCP server is therefore outside the
approval and protected-path guards. This was read from the definitions, not
exercised live.

## Proposed decision

1. SDD Forge does not implement cloud-product knowledge, cloud-service MCP
   tools or vendor-specific Adapters. Decision v2's cloud-service and
   durable-workflow Packs and `sdd-operability` stay unstarted, and are
   re-evaluated only if a real project shows a gap the vendor toolkits do not
   cover.
2. Provider Bindings stay declarative. They identify provider, product and
   purpose, and may name the external toolkit a project permits. They execute
   nothing.
3. `artifact` and `promotion` remain reserved Gate stages. A vendor-neutral
   gate that binds a tool's plan or preview output (what-if, `cdk diff`, change
   set) as evidence, and requires explicit human acknowledgement of deletions
   and replacements, is considered only after a pilot on a real project shows it
   is needed. It would be an `implementation`-stage gate within ADR-0017.
4. Documentation states the control boundary: SDD Forge hooks do not gate
   cloud API calls made through MCP servers, so the agent's cloud permissions
   are limited by the cloud's own mechanisms (IAM, role assignment).

## Alternatives considered

- Build Azure and AWS Adapters and Packs as planned. Rejected for now: it
  duplicates vendor-maintained knowledge across a very large service surface and
  would lag it.
- Ignore the vendor toolkits. Rejected: the agent will use them, and the
  control boundary above would go undocumented.

## Consequences and open verification

- If accepted, ADR-0018 clause on adapter paths and decision v2's Pack order
  items 3 and 4 need a supersession note; this ADR does not make it.
- The hook coverage statement must be confirmed on a live host with a vendor
  MCP server before it is relied on.
- Whether a plan-evidence gate adds enough value is unmeasured. The pilot in
  point 3 is the test.
