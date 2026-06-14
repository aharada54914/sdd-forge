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
3. For `high`/`critical` tasks: `spec_revision` (64-hex digest of the spec
   markdown), `build_env.os`, and `review_verdict.verdict == PASS` are present.
   Gating keys off the hash-validated *contract* risk, so stripping the bundle's
   own `risk` cannot dodge provenance.
4. For `critical` tasks: a verifiable HMAC `signature` whose key is resolved
   externally per `evidence-signing-policy.md` (the agent cannot read the key).

Bundles with a dirty working tree at generation time carry `git_generated_dirty: true`.
For `low`/`medium`/`high` this is an informational warning that does not fail the
check but should be avoided. For `critical` it is a **hard failure**:
`check-evidence-bundle` rejects a critical bundle generated against a dirty tree.
