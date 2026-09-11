# Issue #298: model freshness false positives

Base: `4366438f3b243210a4ece5a17f873ca2d920600a`.

## Cause and change

`extract_candidate_tokens` in `.github/scripts/check-model-freshness.sh`
previously accepted every whitespace-separated word containing a digit and
only letters, digits, dots or hyphens. CSS classes, SVG path fragments and
ordinary versions therefore reached the registry-divergence issue body.

Require a canonical lowercase model-family prefix (`claude-`, `gpt-`, or
`o` followed by a digit), retaining the charset and digit checks. No registry,
network source, workflow permission, deduplication or outage policy changes.
Synthetic positive fixtures now use fictional IDs within those families so
existing divergence tests still exercise actual filing, not an empty result.

This remains a discovery heuristic, not a complete model catalog or HTML
parser. New naming families need an explicit filter update; embedded markup
and digit-free aliases may be missed. A family-shaped token is a candidate,
not proof that a vendor offers that model.

## Executed verification

- Before the production change: Bash suite failed only the new noise case
  (40 passed, 1 failed: non-model markup triggered an issue).
- After the change: `bash tests/model-freshness-check.tests.sh`: 42 passed,
  0 failed. This executes the production Bash script using fixture inputs and
  fake external commands, with no live issue creation or source fetch.
- `pwsh -NoProfile -File tests/model-freshness-check.tests.ps1`: 31 passed,
  0 failed on macOS. This tests the existing independent native contract
  implementation, not the production Bash script or a Windows OS run.
- `git diff --check`: passed.

Regression cases cover CSS/SVG/version noise, all three supported families,
noncanonical case, digit-free tokens, existing known models, missing models,
deduplication, unavailable sources and untrusted-input filtering. The changed
diff was reviewed locally; no new dependencies, dynamic evaluation, secrets,
or registry writes were introduced. This is not third-party approval.

CI, required third-party review, merge and post-merge verification remain
pending. Issue #298 stays open until these are complete.
