# Investigation: epic-197-a9-dogfood

Investigation-Date: 2026-09-01
Mode: feature (brownfield)
Source: supplied Issue #197 summary plus `docs/ai-dlc-foundation-decision-v2.md` §§17,19

## Scope

This read-only investigation maps the repository surfaces needed to specify
sdd-forge's own Project Context and its first developer-tooling / cli-library
Capability Pack. It does not create `sdd/project-context.yaml`, alter a Registry,
or run a review gate. The requested `gh issue view 197 --repo
aharada54914/sdd-forge` call failed because `api.github.com` was unreachable;
issue-specific facts below are therefore limited to the requirements supplied by
the task, while the checked-in decision document is the authoritative recoverable
source.

Domain-Sync: `domain-sync skipped: no domain/ directory`

## Findings

| ID | Finding | Relevance | Evidence |
|---|---|---|---|
| INV-001 | The decision names sdd-forge as the first dogfood target and classifies it as developer tooling, CLI, and plugin package, distributed through GitHub Release and multi-runtime installation on Windows, macOS, and Linux for Claude Code, Codex CLI, and Copilot CLI. | Governs component characteristics and Pack triggers. | `docs/ai-dlc-foundation-decision-v2.md:481-489` |
| INV-002 | Epic A9 starts with `legacy-seven-layer` plus `advisory`, then promotes to `facet-hybrid` plus `required`. | Fixes the two lifecycle phases. | `docs/ai-dlc-foundation-decision-v2.md:551-555` |
| INV-003 | A required-to-advisory rollback is policy weakening. With one maintainer it uses first approval plus a 24-hour cooldown; with two or more real registered identities it requires distinct two-party approval. | Makes rollback approval a security/governance boundary. | `docs/adr/0019-approval-sidecar-protection.md:83-94` |
| INV-004 | The Project Context schema requires `schema` and `workflow`; workflow requires `spec_profile`, `artifact_layout`, and `capability_enforcement`. | Defines the live YAML contract. | `contracts/project-context.schema.json:1-20` |
| INV-005 | Component records can carry artifact kinds, runtime classes, OS/architecture targets, seven boolean characteristics, distribution, classification, provider bindings, and include/exclude paths. | Defines the component inventory decision surface. | `contracts/project-context.schema.json:21-65` |
| INV-006 | Shared paths are represented either by a component list or the `cross-cutting` classification. | Defines the ownership exception surface. | `contracts/project-context.schema.json:67-76` |
| INV-007 | The generic starter is explicitly not a live sdd-forge instance; it seeds `full`, `legacy-seven-layer`, `advisory`, an empty component list, and six cross-cutting patterns. | Useful starting point, but copying it would not complete dogfood. | `contracts/project-context.template.yaml:1-30` |
| INV-008 | The current Capability Registry contains one `durable-workflow` capability and one implementation gate; it contains no developer-tooling or cli-library entry. | The first Pack must be added rather than selected from existing content. | `contracts/capability-registry.json:1-43` |
| INV-009 | sdd-forge presents itself as a three-host plugin and documents the human approval transition from Draft tasks. | Confirms consumer surfaces and approval boundary. | `README.md:1-16` |
| INV-010 | Root installers cover macOS/Linux and Windows and register plugins and MCP services into Claude, Codex, and Copilot targets. | Installer/release paths must be owned or shared. | `README.md:148-175` |
| INV-011 | Three MCP servers are documented as read-only; `ci-mcp` alone consumes a read-only GitHub token. | Component characteristics must not flatten distinct credential/data boundaries. | `README.md:108-144` |
| INV-012 | The repository has seven top-level plugin packages: bootstrap, domain, implementation, lite, quality-loop, review-loop, and ship. | Candidate decomposition input; not a binding component decision. | `README.md:250-259`; directories under `plugins/` re-verify before implementation |
| INV-013 | CI has separate test, installer, loop/routing, version-gate, MCP, CLI-hook, and required-check jobs. | Promotion evidence should reuse existing CI topology. | `.github/workflows/test.yml:21,249,327,455,952,1013,1065,1114,1145` |
| INV-014 | Release publication depends on the existing loop gate and grants contents, OIDC, and attestation permissions. | Release paths are security-sensitive and must not be casually assigned. | `.github/workflows/release.yml:26-50` |
| INV-015 | Approval sidecars are protected from agent writes and use external-key HMAC; the canonicalizer, validator, weakening detector, resolver, and generated projection are protected machinery. | Live Context publication and rollback cannot be ordinary agent writes. | `docs/adr/0019-approval-sidecar-protection.md:49-82` |
| INV-016 | The first Pack order is developer-tooling / cli-library, followed by desktop, cloud-service, and durable-workflow. | A9 must not define later Packs. | `docs/ai-dlc-foundation-decision-v2.md:488-492` |
| INV-017 | A1–A8 define the prerequisite Context, Registry, ownership, Manifest, Resolver, Lite, compatibility, and three-environment integration machinery. | A9 implementation requires a fresh dependency readiness check. | `docs/ai-dlc-foundation-decision-v2.md:522-549` |
| INV-018 | The A5 spec exists on `origin/feature/epic-193-a5-capability-resolver` but not in this branch's working tree or Active Spec list. | Readiness cannot be inferred from another ref; implementation must verify merge state and contracts at its own HEAD. | `git ls-tree -r origin/feature/epic-193-a5-capability-resolver`; `AGENTS.md` Active Spec Directories |
| INV-019 | Workflow improvements are stored as numbered `docs/workflow-improvements/WFI-NNN.md` records with human-controlled status. | Dogfood friction must be captured in the established WFI lane, without self-approval. | `docs/workflow-improvements/WFI-045.md:1-31`; `README.md:257-259` |
| INV-020 | The checked-in bootstrap documentation requires Phase 1/2 review separation, but this delegated bootstrap explicitly requests first drafts and forbids review execution. | All authored statuses must remain pending/draft/planned. | `README.md:250-251`; task instruction |

## Candidate Decomposition (Non-binding)

The repository supports at least three plausible models: one component per
plugin/MCP service; capability-oriented groups (authoring, implementation,
quality, distribution); or a smaller hybrid with plugin packages, MCP services,
and distribution/tooling. The human must choose in OQ-001. Any proposed include,
exclude, or shared rule is likewise provisional until OQ-002 is resolved.

## Risks

- A component map that mirrors directories too literally may obscure shared
  release and guard policy.
- A broad cross-cutting rule may suppress meaningful unowned-path findings.
- Promotion criteria that only say “tests pass” could permit enforcement before
  resolver output and rollback evidence are reviewable.
- Treating a policy-weakening rollback as an ordinary YAML edit would bypass the
  accepted approval-sidecar model.

## Open Questions Carried Forward

OQ-001 component decomposition; OQ-002 path ownership; OQ-003 promotion
criteria; OQ-004 conditional rollback approval workflow; OQ-005 exact first-Pack
capabilities, facets, checks, gates, and delivery strategy.

