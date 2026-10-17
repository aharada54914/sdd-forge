# A9 advisory observation collection

This current implementation addendum implements REQ-006 and the release-evidence portion of REQ-007. Historical approvals and observations are unchanged. It does not activate a Context, issue an approval, authenticate a GitHub export, or authorize promotion.

## Collection and evidence boundary

Run `scripts/observe-a9-advisory.py` from trusted tooling against a disposable checkout of the exact final PR head. Required arguments are `--repo-root`, `--base-sha`, `--head-sha`, `--feature`, `--contract`, and `--output`. Revisions are full Git commit IDs, with a common Git ancestor; changed paths use the actual merge base, including when the base branch advanced independently. The contract is the actual task's existing verification-contract/v2 with completed observations and evidence files. The output is a fresh file in an existing private directory outside the observed checkout.

The checkout must have no tracked modifications before collection. Its committed Context in one exact supported phase, approval sidecar, approved anchor, and capability Registry must match their actual working bytes. Existing provider bindings, when present, must also match the committed head. Generated verification observations may be untracked, but must use ordinary files inside the checkout; links and reparse points are rejected. CI-generated output is not added to the PR's changed-path list.

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

To use collection for every real PR, the trusted CI/operator must supply the actual final PR head/base and feature/task verification contract, retain the output privately, and export the association with that invocation's exact check run. The automatic per-PR connection uses the explicit request below; it does not guess which task contract represents a PR. No live Context is currently activated by this change. A workflow that simply succeeds when Context or observations are absent must not be used as the advisory check.

Use the existing human-owned approval validator separately in the trusted signing environment. Never pass HMAC or Ed25519 secret material to a PR checkout. Successful collection, successful fixture CI, and authorization of the Phase-1 publication are distinct facts.

## Explicit per-PR CI request

Once Phase 1 is actually activated, commit `sdd/a9-advisory-request.json` with exactly these fields:

```json
{"schema":"a9-advisory-request/v1","feature":"actual-feature","verification_contract":"specs/actual-feature/verification/T-001/contract.json"}
```

The named contract belongs to that feature and matches its final-head Git blob. Its evidence files must already exist. The request cannot supply commit IDs, commands, keys, an output path, or an approval claim. Base/head come from the actual PR event. Manual collection can still consume generated untracked verification observations; the committed-request CI route requires a committed request and contract. Neither route executes the commands stored in a contract.

The existing test workflow detects Context presence in both the trusted base and PR head. If both are absent, the actual `capability-mode Gate` job is **skipped**, and the detection summary says no advisory observation occurred. Removing an activated Context from a PR cannot select that inactive branch. Once active, missing tooling, publication inputs, request, contract, or evidence fails closed; missing inputs are reported by field names without private paths. The required-checks aggregate requires success for active observation, permits only skipped observation for the explicit inactive state, and rejects failed/cancelled/unknown detection or mismatched state.

Collection checks out the trusted base separately from the exact PR head, with credential persistence disabled and read-only repository permission. Only trusted-base collector code runs. The isolated head is data; no PR script or contract command executes. A first activation whose base lacks the collector fails with `missing_inputs: ["trusted_collector"]`, so tooling must be merged before activation.

Raw bundles are written only to a private runner directory and are never uploaded. The public digest/check result is **not a durable private export**. The complete private observation may be retained privately or reconstructed using the exact trusted tooling and committed input bytes, as described below. The release consumer still requires the complete private observation and authentic check association, not merely this green job. This workflow does not claim a completed release cycle.

## Private reconstruction of a CI observation

An operator can re-run the collector in a separate private checkout using the original CI base/head, committed request and evidence, original trusted-base tooling, and a matching runtime. Runtime-dependent output bytes must also match; reconstruction does not normalize them. Supply `--expected-observation-sha256` with the whole-record digest obtained from the authentic latest check run. For example, with locally supplied values:

```sh
python3 "$TRUSTED_TOOLING/scripts/observe-a9-advisory.py" \
  --repo-root "$PRIVATE_CHECKOUT" --base-sha "$ORIGINAL_BASE" --head-sha "$ORIGINAL_HEAD" \
  --request sdd/a9-advisory-request.json --output "$PRIVATE_OUTPUT" \
  --expected-observation-sha256 "$AUTHENTIC_CHECK_DIGEST"
```

The collector compares the complete canonical observation before creating the output file. Missing original inputs, changed evidence, different trusted tooling, or any mismatched digest fails without publishing a bundle. Its `trusted_tooling_sha256` binds the executed collector, staged quality-consumer code and governing contracts/schema bytes; runtime bytecode and the generated projection are excluded. Runtime directory names are excluded. Separate-checkout regression tests compare actual consumer outputs, raw artifact bytes, and the whole observation, including coverage and projection.

A matching digest recovers the same content; it does not establish a new historical CI execution or authenticate a user-supplied digest. Recovery reports `expected_digest_matched: true`, `original_ci_authenticated: false`, and `authorization_checked: false`. The release export must separately retain the authentic original latest check/run association and original digest. A recovery run, synthetic test, mismatched record, or bare green workflow cannot replace that association or an approved Phase-1 publication.

## Continued operation after promotion

The same explicit request and trusted CI connection continue after authorized promotion. The collector accepts only the exact Phase-1 tuple (`full`, `legacy-seven-layer`, `advisory`) or Phase-2 tuple (`full`, `facet-hybrid`, `required`). It invokes the same existing consumers with the actual state, so required-mode coverage failures remain failures. Mixed tuples, malformed publication, and removal of an activated Context do not become skipped or successful observations.

Phase 2 emits `a9-required-observation/v1`, `state: required`, and the generic `observation_sha256` summary field. It never emits the advisory digest field. The release-cycle validator explicitly expects the advisory state/schema and rejects a required-mode record even if its check is green and its bundle is rehashed. Phase 1 additionally emits `advisory_observation_sha256` for its release-export contract. The CI job's neutral name is `capability-mode Gate`; its record carries the actual enforcement state.

Optional nonblocking advisory findings remain in the contract and selected plan as failed observations while delivery can pass. Existing contract requirements (including an explicit rationale for an optional failing check) still apply. The collector does not erase findings or waive required gates. The current candidate assigns the four fixed live publication metadata paths and the explicit request path as exact cross-cutting ownership rules, so real publication and promotion do not produce artificial UNOWNED failures.
