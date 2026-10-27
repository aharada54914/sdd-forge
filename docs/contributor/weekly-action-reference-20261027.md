# Pinned Action reference repair (#654)

On 2026-10-27 the actual pinned source was fetched from
`anthropics/claude-code-action` at `1d6de8cb0c237e7c15e9e1bdf973826ebae490cc`
(the workflow's v1.0.248 pin). Its `action.yml:308` sets
`DEFAULT_WORKFLOW_TOKEN: ${{ github.token }}`. `src/github/token.ts:158-168`
returns a provided `OVERRIDE_GITHUB_TOKEN` before requesting OIDC. The action
metadata still describes `anthropic_federation_rule_id` with organization ID
as a separate OIDC federation input. The workflow uses subscription OAuth and
supplies `with.github_token`, so neither of those OIDC paths is newly required.

Fetched source hashes: action.yml
`87b706489e63483c9c32c12af36467dd34e309becca35f7a8ead4d1e0664c4df`;
src/github/token.ts
`a820d517575513b2c13db2cf19b62c2d3e0dd4e646ef3ba49c69c0ea04d5836b`.
These are source observations, not token values or backend-model attestations.

The prompt now refers to the workflow's pinned version rather than duplicating
a stale release number. Workflow comments cite the actually checked pin and
override branch. Executable YAML values, permissions, token selection and
default-fail completion validation are unchanged. The existing guard suite
passes 71 checks and the credential preflight suite passes 10 tests.
