# A9 advisory observation collection

This current implementation addendum implements REQ-006 and the release-evidence portion of REQ-007. Historical approvals and observations are unchanged. It does not activate a Context, issue an approval, authenticate a GitHub export, or authorize promotion.

## Collection and evidence boundary

Run `scripts/observe-a9-advisory.py` from trusted tooling against a disposable checkout of the exact final PR head. Required arguments are `--repo-root`, `--base-sha`, `--head-sha`, `--feature`, `--contract`, and `--output`. Revisions are full Git commit IDs, with the base an ancestor of the head. The contract is the actual task's existing verification-contract/v2 with completed observations and evidence files. The output is a fresh file in an existing private directory outside the observed checkout.

The checkout must have no tracked modifications before collection. Its committed Phase-1 Context, approval sidecar, approved anchor, and capability Registry must match their actual working bytes. Existing provider bindings, when present, must also match the committed head. Generated verification observations may be untracked, but must use ordinary files inside the checkout; links and reparse points are rejected. CI-generated output is not added to the PR's changed-path list.

The collector stages trusted consumer code privately and invokes the existing Resolver, Manifest validator, Resolver Evidence validator, component coverage gate, and selected-plan evaluator. It never executes scripts from the observed PR. The Resolver's script-adjacent generated projection stays in this temporary tooling tree. The observed checkout receives the normal feature artifacts and selected plan. Inputs are rechecked before returning an observation. Existing gate execution results must be supplied by the task's verification contract; the collector does not invent or execute those commands.

An observation contains the exact input/output bytes and actual verification evidence, bound by SHA-256. It is private evidence and can contain sensitive task data. Never upload it automatically to public CI artifacts, issues, or comments. Standard output contains only state, result, authorization status, commit IDs, and the canonical whole-observation digest. Failure output contains a fixed category rather than paths, raw subprocess errors, or artifact contents. No credentials or signing keys are needed or supplied to PR code.

Exit 0 means that the real consumers executed successfully and their evidence passed consistency validation. It does **not** mean that the publication was authorized. Every observation retains `authorization_checked: false`. Missing live Context produces `not_activated` / `NOT_RUN` and exit 3, which cannot count as an advisory Gate. Failed or malformed observations exit 1.

## Release-cycle export

Each entry in the existing `a9-release-cycle/v1` `pull_requests` array now requires:

- `base_sha`: the actual base used for this PR's observation;
- `advisory_observation`: the complete private `a9-advisory-observation/v1` collection;
- `advisory_observation_sha256` on the latest check run whose name equals `advisory_check`: the `sha256:`-prefixed canonical digest printed by the collector.

The export must obtain this check-to-observation association from the trusted collection/check process. Merely inserting a claimed digest into an unauthenticated JSON file is not proof of GitHub execution. A previous successful advisory run cannot supply evidence for a newer run.

The release preflight verifies the final PR head's immutable Git blobs, actual base/head changed paths, Context revision, Registry digest, ownership digest, projection, dependency pointers, Resolver version/rules, predicate evaluations, Manifest, and coverage result. It replays the existing selected-plan evaluator against the captured contract and evidence files, checking the complete required-check set and results. Rehashing a forged partial plan or an internally consistent false ownership binding does not satisfy this contract.

The preflight remains a consistency checker and returns `promotion_authorized: false`. Approved Phase-1 publication authenticity, trusted export/check policy, the formal promotion decision, finding triage, rollback proof, and the real post-promotion feature remain separate required acceptance evidence. An unsigned candidate or synthetic fixture cannot establish an active release cycle.

## CI and operator use

The existing Bash and PowerShell A9 test entrypoints execute the collector regressions and propagate failures. This deterministic CI coverage is not a live advisory observation.

To use collection for every real PR, the trusted CI/operator must supply the actual final PR head/base and feature/task verification contract, retain the output privately, and export the association with that invocation's exact check run. This change provides that collection interface and its release consumer; it does not install an automatic per-PR workflow or guess which task contract represents a PR. No live Context is currently activated by this change. A workflow that simply succeeds when Context or observations are absent must not be used as the advisory check.

Use the existing human-owned approval validator separately in the trusted signing environment. Never pass HMAC or Ed25519 secret material to a PR checkout. Successful collection, successful fixture CI, and authorization of the Phase-1 publication are distinct facts.
