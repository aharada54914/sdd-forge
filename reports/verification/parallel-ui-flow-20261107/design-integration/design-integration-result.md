# Claude Design capability probe

Result: **External design integration BLOCKED** in this native installed session.

Target: disposable full-profile SQLite task UI, `ds_profile: custom`. This was a capability-only probe; bootstrap and UI implementation were not run.

## Observed provider availability

The current callable/deferred `ALL_TOOLS` catalog was searched by tool name and description for DesignSync, Claude Design / claude.ai/design, Claude Preview, and the required operation names. All four searches returned zero matches. See `design-integration-evidence.json` for the recorded search results and dedicated tool-search availability. This conclusion is scoped to this session, not all possible installations.

| Required provider tools | Observed | Can run here? |
|---|---|---|
| DesignSync; `list_projects` | Absent | No project listing |
| `list_files`, `get_file` | Absent | No remote design/token/component read |
| `create_project` | Absent | No; also explicitly outside authorization |
| `finalize_plan`, `write_files` | Absent | No mockup upload or remote review cycle |
| Claude Preview `preview_start`, `preview_screenshot`, `preview_snapshot`, `preview_inspect`, `preview_resize` | All absent | No Claude Preview capture/inspect/improve roundtrip |

Available matching provider tools: **none**. Authentication was not tested; missing tools are the observed blocker. No credentials, project IDs, approvals, provider responses, or remote execution are assumed. No remote operation was attempted.

## Installed instructions read

- `/workspace/.tools/sdd-forge-dev/codex-verify/plugins/cache/sdd-plugins/sdd-bootstrap/1.23.1/skills/design-sync-loop/SKILL.md`
- `/workspace/.tools/sdd-forge-dev/codex-verify/plugins/cache/sdd-plugins/sdd-implementation/1.23.1/skills/visual-verify-loop/SKILL.md`
- Supporting fallback: `sdd-bootstrap/1.23.1/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md` under the same installed plugin cache.

Design sync requires actual provider discovery, project pull, generation, consent/policy resolution, a fresh egress scan, `finalize_plan` then `write_files`, and human browser review. None of those provider stages was demonstrated. The installed resolver explicitly has no provider/network access; its `proceed` result would not prove integration. No resolver or fixture was used as evidence.

Visual verification names the five Claude Preview tools above and directs an unavailable-tool path to record `visual verification unavailable — skipped: <reason>`. There is no implemented task/report in this probe to update.

## Local manual fallback

The installed design skill preserves local design-system contracts, file-only DTCG import, and disposable local HTML mockups when the provider is unavailable. Its manual marker is `design tools unavailable — manual workflow used`; external unavailability need not block specification work. Actual custom design-system generation/review and mockup work were outside this narrow probe and were not performed or marked approved. The fallback describes standalone local egress scanning before manual steps; no mockup payload exists here and no scan was claimed.

Local manual artifacts/review are distinct from Claude Design integration. They cannot demonstrate project listing, remote design reads, uploading/reviewing mockups, or a Claude Preview UI improvement roundtrip. Existing apps and the source repository were not changed; only these probe evidence files were added.
