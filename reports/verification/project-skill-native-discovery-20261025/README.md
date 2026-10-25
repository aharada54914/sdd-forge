# Actual Codex project-skill discovery

The independent evaluation used the isolated verify profile, Codex CLI 0.159.2
and the existing doctor RPC helper. The actual product seal/project commands
created a synthetic read-only wrapper; native app-server initialize/skills/list
reported its exact name/path with repo scope and enabled=true. Removing the
fixture removed that skill from native discovery, and the verification workspace's
original entries were restored. Product source hashes did not change.

No account RPC, model request or project runner execution was made. The separate
supported auth probe still reports reauthentication_required; local credential
presence and discovery do not establish remote model access or obedience to the
wrapper's restrictions. Claude/Copilot were unavailable and not evaluated.

The files are synthetic fixture code, generated wrapper metadata and actual local
RPC logs. Original log files are retained here as .txt for repository inclusion.
result.json records scope, source hashes and cleanup checks. This is evidence for
the discovery portion of #602, not completion of all native host acceptance.

A separate bounded native model connectivity probe at 16:24 UTC failed with
HTTP 401 on model discovery and response endpoints, followed by turn.failed
requesting sign-in again. The sanitized model-connectivity-summary.json retains
the outcome and local raw-log hash; no model response or skill invocation succeeded.
