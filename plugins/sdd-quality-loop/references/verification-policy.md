# Verification Policy

Detect commands from repository configuration; do not invent commands.

Check available lint, typecheck, unit, integration, E2E, build, OpenAPI lint,
JSON Schema validation, dependency audit, and secret scanning commands.

Audit GitHub Actions or GitLab CI when present. Report missing checks rather
than silently adding heavy tools.

If no executable verification commands exist, create a review ticket and do
not mark the task `Done`.

## Evidence Bundle Authoring

Evidence bundles MUST be produced with `generate-evidence-bundle.(sh|ps1)`,
not hand-authored. The runner computes SHA256 digests automatically and records
the current git HEAD commit, so every bundle is bound to both the artifact
content and the branch's commit history.

`check-evidence-bundle.(sh|ps1)` verifies:
1. The `git_commit` field matches a real commit that is HEAD or an ancestor of HEAD
   in the repository where the check runs (foreign or fabricated commits are rejected).
2. Every artifact digest matches the file on disk.

Bundles with a dirty working tree at generation time carry `git_generated_dirty: true`
as an informational warning; this does not cause a check failure but should be avoided
in production workflows.
