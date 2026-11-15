# ADR 0049: Session model preferences without weakening launch admission

Date: 2026-11-15
Status: Accepted for implementation under the user's Work development authorization

## Context

Users want a fresh model list and a confirmation of their main and role-specific
models on every new interactive Claude Code, Codex CLI, and Gemini CLI session.
Existing model-policy observations and launch controls carry stronger guarantees
than an alias or a saved preference. Review isolation must remain intact.

## Decision

Use a fast SessionStart context hook plus a public model-selection skill. Discover
models in the first interactive response, not inside the hook. Noninteractive runs,
workers, resume and compaction retain their existing behavior. Bootstrap and ship
provide the fallback when a host cannot run hooks.

Keep project-private preferences outside the project and bind each explicit
confirmation to the canonical project, native host and session ID. Store one main
preference per host and a shared role map. Unused roles can be explicitly disabled;
allocation of a disabled role fails until the user reselects. Do not require users
to install all three vendors simply to confirm a single-vendor session.

Model Discovery Interface lives in `model-discovery.py`: each CLI adapter returns
normalized IDs, display names, per-model efforts, default effort when exposed,
authentication-route classification and an explicit failure state. The shared
skill UI presents provider, model, effort and refresh; it never creates fixed
model or effort candidates. The selection store and launch admission remain separate.

Codex uses App Server `model/list` with pagination and `includeHidden=false`.
Claude uses the same control initialize response consumed by the official Agent
SDK's `supportedModels()`, including `supportedEffortLevels` and model IDs with
context suffixes. Gemini uses ACP `session/new` after the CLI resolves its existing
authentication, rather than the unauthenticated `models` command. Its current ACP
ModelInfo does not expose effort choices: CLI default is the only offered value.
The adapters invoke no model prompt and no direct provider API. OAuth/API-key/
external backend resolution stays with the CLI; no login or credential copying and
no API-key fallback is performed. `cli-managed` explicitly leaves billing mode
unclassified. A returned list is CLI-scoped, not proof of entitlement or inference.

Refresh on each new interactive session, on explicit request/authentication change,
and when reopening a picker whose catalog is at least 15 minutes old. Cancelled
sessions stay cancelled until an explicit refresh. A refresh
invalidates confirmation and rechecks saved choices. No background login/daemon is
introduced. Old v1 preferences remain readable; optional catalog metadata is
additive. A native-listed choice must still satisfy each existing launch adapter.

Keep selection and native launch admission separate. Codex review passes explicit
model and effort through the existing isolated idle-thread launcher, verifies its
returned configuration before reservation, then forwards them to the work turn.
Managed routes consume a pinned policy request and retain fresh observations,
validation, identity reservation and delivery checks. Panelists consume the
confirmed choice through their existing collection wrappers and preserve consent,
sanitization and vendor diversity. Unsupported role/provider adapters stop with a
reselection request; no generic CLI execution bypass is introduced.

## Alternatives and consequences

A terminal picker inside hooks cannot reliably read user input and would slow or
block startup. Persisting preferences into project files would share personal
choices. Injecting model environment variables could silently conflict with the
existing pinned controls. These alternatives are rejected.

Main changes still require the host's standard model/effort UI and explicit user
acknowledgment. Configured selection is not backend identity proof. Gemini generic
independent review remains unavailable rather than using an unisolated process.
Check the current role/transport admission tables before adding another adapter.

## Native verification follow-up

Claude loads the conventional hooks/hooks.json in addition to the manifest-selected
hook config. Codex therefore uses the explicit hooks/codex-hooks.json path so a
Claude session does not execute the Codex startup instruction as well. Gemini
interprets hook timeouts in milliseconds; its ten-second budget is 10000, while
Claude/Codex keep their native timeout units. These were confirmed using the real
CLI builds in the isolated verification workspace, independently of inference.
