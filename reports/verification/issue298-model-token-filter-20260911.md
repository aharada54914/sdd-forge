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

## Repair verification addendum (2026-09-12)

Repair ticket: `docs/review-tickets/RT-20260912-001.yml`.
Verified commit: `64cd4ddd4055dacb34a434e1bff41a464585ae28`.
Run ID: issue298-repair-verification-20260912-64cd
Task Attempt Count: 1 (this addendum's verification run, not the historical task counter)
Host session: `01a06d01-11b5-7bd3-83a3-7e29bb3c96cd` (existing implementing context).

This is a retrospective repair record, not a pre-implementation preflight,
fresh-agent implementation report, independent verdict, or replacement for
`reports/implementation/epic-159-pillar-d/T-003.md`. The product repair and
its regression tests already existed when this addendum was recorded. The
old implementation report and historical task/review status were not edited.

### Risk and observable-output correspondence

| Output or boundary | Governing counterpart | Executed regression / inspection |
|---|---|---|
| Candidate tokens in issue body | AC-021 allowlist, conservative discovery heuristic | Bash `run_test_298` (lines 566-584) rejects numeric/markup noise and retains all three families; TEST-021 rejects hostile substrings |
| First divergence issue and stable marker | AC-007 filing and deduplication | Bash TEST-007 checks exactly one creation and zero repeated creation when the marker already exists |
| Unavailable-source notification instead of partial diff | AC-006 fail-soft behavior | Bash TEST-006 covers both sources unavailable and each individual source unavailable |
| No-diff external effects | AC-020 | Bash TEST-020 requires an empty fake CLI log |
| Registry and workflow privileges | Security boundaries B2/B3 | Diff against main changes only the token extractor and comments in production; registry, workflow, URLs, issue filing and permissions are unchanged |
| This record's hashes/results | Actual bytes and process exits | SHA-256 measurements below; both test processes exited 0; no PASS is asserted for an independent gate |

The tests above establish the exercised cases, not an exhaustive model-name
catalog. They do not prove a live scheduled invocation, native Windows
execution on this Mac, or isolation from this implementation session.

### Re-executed checks on the verified commit

- `bash tests/model-freshness-check.tests.sh`: 42 passed, 0 failed, exit 0.
  Real production script with fixture sources and fake external CLI.
  Log: `/tmp/pr409-repair-64cd-bash-20260912.log`, SHA-256
  `c374473ffc054b66e1df2f02df6bf6ea2a0b6096b5958e6d1eefedaafaf232cb`.
- `pwsh -NoProfile -File tests/model-freshness-check.tests.ps1`:
  31 passed, 0 failed, exit 0. Native contract implementation, not the
  production Bash script. Log: `/tmp/pr409-repair-64cd-pwsh-20260912.log`,
  SHA-256 `639fad77319f5ebb21837f76afcd6993625fa0498b69b5a96ef26961cf9c66b5`.
- `bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh`:
  `workflow-state: ok`, exit 0. Existing A7/A8 amendment-growth notices were
  tolerated by the validator. This validates persisted workflow state; it
  does not supply independent verification of this repair.

| Path | SHA-256 |
|---|---|
| `.github/scripts/check-model-freshness.sh` | `ffbed44f81fc2a582a22225ed2e352d130b25c9b843ca39f93e24bdfd55cef56` |
| `tests/model-freshness-check.tests.sh` | `d2fa483419eaf9451703dc30d79d67d27d4261666491743e76c089e80d8d3a75` |
| `tests/model-freshness-check.tests.ps1` | `456bbcd53bfd5681141d276e9df90f52c220398c639b4b8ff6ef38ced1b1b850` |

Remaining: supported repair-context binding and independent quality decision,
complete latest-head CI, merge, and postmerge verification. Approval-count
bypass does not satisfy those conditions. This addendum does not resolve the
two open provenance findings or authorize Issue #298 closure by itself.
