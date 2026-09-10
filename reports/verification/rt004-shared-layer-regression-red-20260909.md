# RT004 shared-layer regression — RED

Scope: approved RT-20260908-004 tests only. Historical repository evidence and production validators were not edited. The fixture copies review documents into a temporary directory; it executes the original Bash and PowerShell workflow validators, never copied candidate code.

Test source SHA-256: `48624478282782871586003aa7bca7e4f5d510ed5ff3d2b0bf8514d8d5c1a3cd`.

Command: `rtk proxy bash tests/impl-review-adr-inputs.tests.sh --workflow-only`

Exit: 1. Summary: 4 passed, 8 failed. Both runtimes ran on macOS; this is not native Windows evidence.

For each runtime:

- legacy: exit 0, expected 0.
- null-set: exit 0, expected 1.
- object-set: exit 0, expected 1.
- missing-precheck: exit 0, expected 1.
- equal-layer: exit 0, expected 0.
- conflicting-layer: exit 0, expected 1.

All unexpected acceptances printed `workflow-state: ok`.

The two added cases build an explicit empty ADR set and empty layer pin map, update the precheck digest, make reviewer A record one Major FAIL, synchronize its summary and reviewer B's summary hash, and retain matching per-reviewer contract/output manifests. The negative changes reviewer B's extra ux-spec hash in both its contract and output; reviewer A retains the other hash. This isolates the cross-reviewer shared-path disagreement rather than introducing a same-reviewer manifest mismatch. A fixture assertion requires exactly one Major FAIL before executing the validator.

Interpretation: original workflow opening accepts the conflicting record. This is RED evidence, not acceptance of the proposed fix. The equal-layer positive protects the existing optional-layer compatibility rule. Comprehensive fixture contract validation against the final applied implementation, independent test review, PowerShell candidate parity and native Windows verification remain pending. The candidate has not been applied or behaviorally validated.

`rtk proxy git diff --check` exited 0; the test source is untracked, so that command does not validate its contents. No commit, push, merge, historical verdict rewrite or ticket resolution was performed.

## Additional alias and optional-output cases

Later source SHA-256: `bfc1e9f9c375e82baf4c79662e7db70fd311af764b1db662d2c2b7040c31ee68`. The previous source/result above remains a historical observation, not the current suite total.

The same command now exits 1 with **6 passed, 10 failed**. Added cases in both actual runtimes:

- `output-only-layer`: exit 0, expected 0. Both output manifests include an equal-hash optional layer absent from both role contracts. This retains issue #71's layer-superset compatibility.
- `conflicting-layer-alias`: exit 0, expected 1. B's contract and output use the fixture-root absolute path, A uses the relative path, and their recorded hashes disagree. Both original validators print `workflow-state: ok`, demonstrating that the opening path misses this invalid shared-file binding too.

`bash -n tests/impl-review-adr-inputs.tests.sh` exits 0. No candidate implementation was executed. These are expected pre-fix failures, not a product PASS. Primary test review checked that the B alias is synchronized in its contract and output and that only fixture data is mutated. Independent review and applied-runtime validation are still pending.

PR394's exact-head checks were refreshed during this continuation: 23 successful, Windows test and required-checks failed on run 34023439393. This remains the previously diagnosed dependency on the formal PR400 repair chain (`pr394-fix-dependency-20260908.md`), not a new live job or evidence justifying an unchanged rerun. No PR mutation was made.

## Fixture digest correction — 2026-09-09

The earlier fixture versions above used `acceptance_tests_sha256`, but the
saved precheck contract uses `acceptance_sha256`. The missing field was joined
as an empty string, producing an invalid digest even in the equal-layer control.
The earlier exit observations remain real, but their assertion of an isolated
cross-reviewer mismatch is superseded: those inputs had a second defect.

A fixture-only independent Python SHA-256 assertion was added first. Running
`rtk proxy bash tests/impl-review-adr-inputs.tests.sh --workflow-only` stopped
with exit 1 and `fixture setup: input digest mismatch` at the first extended
control. The generator was then corrected to use `acceptance_sha256`, with
explicit failure on missing or malformed core pins and digest-command failure.
The Python assertion uses explicit field names and byte concatenation, not the
generator's jq join expression. It is fixture validation, not a copied product
validator or a replacement quality gate.

Current source SHA-256:
`12cbd8cd5c2372bec867239ec6c422531282ccfa0076a539ff94fecaa95f8c11`.
The same command after correction exited 1, with 6 passed and 10 failed.
For each of Bash and macOS PowerShell, the complete results were:

```text
legacy: exit 0, expected 0
null-set: exit 0, expected 1; workflow-state: ok
object-set: exit 0, expected 1; workflow-state: ok
missing-precheck: exit 0, expected 1; workflow-state: ok
equal-layer: exit 0, expected 0
output-only-layer: exit 0, expected 0
conflicting-layer: exit 0, expected 1; workflow-state: ok
conflicting-layer-alias: exit 0, expected 1; workflow-state: ok
```

All eight extended fixtures passed the independent core-input digest assertion.
That assertion does not certify the complete historical contract. Full candidate
application, independent security/contract review, complete cross-consumer tests
and native Windows evidence remain pending. This result is RED for the original
validators, not GREEN for the candidate.

Primary review of this correction: no Critical finding in the bounded test diff;
no expectation or required product check was weakened. `bash -n` exited 0.
Product validator hashes are unchanged: Bash
`15a4ef0a72c8be78c40b38e692ee7a46d8664d825e61ab99915086dae0f02d1e`,
PowerShell `7a4663e154e7877362d43916087986849dd7625121d5c058332d3e27eb7b2644`.
No review verdict, old evidence, ticket status, commit, push or merge was changed.

Next action: complete the PowerShell workflow-history candidate corresponding
to the Bash candidate before requesting independent review of the full patch.
The shared-layer helper-only slice is not a complete or applicable repair.
