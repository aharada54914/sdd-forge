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

Codex discovery reuses its existing documented model/list adapter. Claude and Gemini
aliases and configured IDs are explicitly unverified candidates. Claude effort
choices require the installed public CLI help to advertise the carrier. Gemini
has no admitted generic effort carrier here and offers CLI default. Never convert
these candidates into a model-policy observation or infer inference availability.

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
