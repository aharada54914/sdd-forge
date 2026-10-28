# Copilot project-skill discovery and failed model attempt

GitHub Copilot CLI 1.0.104 was installed under a temporary tool prefix. In an
isolated verification workspace, the project-skill CLI sealed a synthetic skill
as `draft` and generated its Copilot wrapper. The native `copilot skill list
--json` found exactly one enabled project skill, and its reported directory
matched the generated wrapper's parent. The real product source hash and wrapper
hash are recorded in both results. The synthetic note and wrapper bytes remained
unchanged, and no `copilot-discovery-*` directory remained afterward.

Two attempts to run a model with that generated skill returned exit 1 before
quoting the note. The sanitized second result records authentication/token and
permission indicators; it does not distinguish the exact authentication or
entitlement cause. No successful model invocation, product execution, review,
or approval is claimed. The probes disabled built-in MCP servers, shell, writes
and subagents, and used a separate temporary Copilot state directory.

`probe.py` is the exact second-run probe with machine-local paths; adapting those
paths and providing an authorized Copilot session are needed for a rerun. Its
model output and credentials are not retained. The Codex observation remains a
separate real authenticated model observation; Claude was not authenticated.
