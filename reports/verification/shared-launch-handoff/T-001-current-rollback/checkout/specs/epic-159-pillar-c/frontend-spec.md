# Frontend Specification: epic-159-pillar-c

N/A — no change: the deliverables are a JSON contract file, Bash/PowerShell
CLI scripts, generated Markdown-frontmatter/TOML-comment agent-definition
content, and a JSON run-record schema extension. There is no browser or
frontend application.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Registry contract | JSON | schema `agent-model-capabilities/v2` | machine-readable, jq/`json.load`-consumable by both the selector and the renderer | v1 file frozen; v2 additive-only relative to v1's field set |
| Selector | Bash (python3 heredoc) and PowerShell twins | existing supported runtimes | cross-host determinism, matches `select-agent-model.sh`'s existing implementation technique | `.sh`/`.ps1` pairs; welded-mode output byte-identical during Phase 1 |
| Agent-definition renderer | Bash and PowerShell twins | existing supported runtimes | generates Claude `.md` frontmatter and Codex `.toml` reference comments from one registry source | must never write any of the four R-10 protected reviewer `.md` targets directly |
| Run record | JSON (`sdd-run-record/v2`) | additive schema bump | WFI effect-measurement consumability | v1 records remain valid; no migration |
| CI | GitHub Actions | existing | 3-OS matrix, bash+pwsh lanes; new `--check` drift step | deterministic lane (#126 note) for all suites except T-007's own real Codex-host smoke check |

## Component Tree, State Shape, Routes, and API Client

N/A — no change: no component tree, browser state, route, API client, or
frontend bundle exists.

## Performance and Size Budget

N/A — no change: no frontend asset is built. Script/suite runtime is
governed by the Runtime Budget section of infra-spec.md.

## Dependencies

No new runtime dependency. The scripts use POSIX shell utilities,
PowerShell built-ins, `python3` (already required by
`select-agent-model.sh`'s existing heredoc technique and
`run-panelist-gpt.sh`'s existing JSON-extraction step), and `jq` where the
new test suites assert on JSON output — all already-established repository
dependencies. No new package, container, or service dependency is
introduced.

## Testing

TEST-001 through TEST-050 in acceptance-tests.md cover the v2 registry and
its parity lock, the selector's new flags and welded-golden byte-identical
guarantee, the agent-definition renderer's Claude/Codex output and
protected-file boundary, the run-record's effort fields, the closed twin
gap for routing tests, the Codex host's real effort application, the
Phase-2 flip's prerequisite gate, cross-host degradation coverage, and
documentation/version-bump conformance. No component, accessibility,
browser-performance, or frontend E2E test applies.

## Open Questions

None. Owner: maintainers; non-blocking.
