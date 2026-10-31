# A7 receipt delivery repair candidate — 2026-10-06

Owner: `a7-t005-intake/sdd-forge`, HEAD `654ce55d2b23b3a0cd0d72c3e45e46144399e90e`.
High-risk launch/evidence-contract correction. Existing dirty work is preserved.
No new reservation, verdict adoption, task-state change, commit, push or merge.

## Failure and bounded proposal

A19 sequence 1206 returned an inadmissible PASS: the reviewer did not compute
the reserved record digest. Its output and blocker note remain unchanged.
The existing fixed-prompt helper did not supply the boundary recipe or literal
record-hash commands. The candidate adds these to that helper, requiring the
reviewer to reconstruct the texts independently before executing the hashes.
This is not permission to trust caller-supplied digests or to read the ledger.

Only protected target:
`plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py`.

- Original SHA-256: `1fa826ac3b8a336c3ee9badadd0002a5078c9a660dff30b83e44b81900a6f075`
- Candidate SHA-256: `fcebcf252957ec4a0ff47879f5b0096d770fc9a59f30c2130c75c006d9c57abd`
- Patch SHA-256: `376ccf4d0fac0046762bb0ff9f838f65c76da422a14153f31c1ed98ea9e9a15f`

The user applied the source and its SHA-256 matches the candidate above.
Backup: `/private/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/a7-receipt-human-backup-l7gp1vd4/validate-nontty-spec-launch.py`.
Original-path regression passed all eight tests; see
`original-path-regression-20261006.md`. The application command below is retained
for provenance, not as an instruction to apply again:

```sh
rtk proxy python3 -B /Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge/reports/verification/a7-a20-receipt-candidate-20261006/human-apply.py --apply-human
```

## Executed checks

`receipt_prompt.tests.py`: 8 tests passed, including actual literal-command
digests, modified receipt/input/order/identity/chain rejection and newline
boundaries. Candidate Python compile and `git apply --check` passed.
These are candidate-only tests, not original-path regressions or formal review.

Unreserved Sonnet diagnostic `a1a16c05-73dd-4bbc-9ac0-827606960711` was
BLOCKED: exact whole-pipeline permissions did not permit the pipeline's stdin
hash segment. Its raw artifacts are retained under its `unreserved-*` directory.

With authorized exact `Bash(rtk proxy shasum -a 256)` additionally admitted
(no filename arguments or wildcard), diagnostic
`d05474c9-180a-4d87-85ec-0bccb7607af7` executed both literal pipelines using
the same CLI. Native tool outputs were independently inspected:

- Input digest: `6dd114c8b3d594b0ac0330813138a15698b4eb4edca6d7c5acece5082bb895fd`
- Record digest: `0599e72ba9a2382aad1b7540bfbc7f45b3424abaefc010fb686933e4d9964a95`

This demonstrates literal hash execution, not full diagnostic compliance:
the diagnostic role tried extra Python and variable-shell mutation checks,
which were refused, then performed a literal comparison. Also the record
command ran before the successful input command. Do not count this as strict
ordered admission, a new identity, or a review PASS. No hook was disabled.
GateGuard's facts requirement was answered normally; its refusal is retained.

Strict diagnostic `973633d1-a9c6-4580-b25b-da28b7aba481` completed with
the same permissions. Native transcript inspection confirmed only the input
literal command (facts refusal followed by the same-command retry), then the
record literal command, with both successful outputs equal to the digests
above. No extra Python, variable-shell or comparison command was used. The
diagnostic's changed-receipt comparison was reasoning only; executed negative
coverage comes from the eight fixture tests, not that comparison. This proves
ordered hash delivery only, not formal admission or a review verdict.

The numeric pre-append tip requirement is intentional for a fresh reservation.
Boundary lines 91–93 define `tip=-` as re-verification of an already-persisted
identity; it is not a fresh reservation receipt or a genesis exception.

Independent candidate diff review by `/root/boundary_verify` found no blocking
issue against the pinned patch. That reviewer independently ran all eight tests
successfully. This is a candidate review, not the formal A7 specification
review. `DELIVERY_OK` still does not establish tool execution: the actual native
transcript must be checked for both successful hashes on the next real launch.

## Remaining

The separate inventory-recovery repair remains unapplied. After its sanctioned
application and original-path verification: ordinary new-attempt precheck,
then fresh reviewer identity and one reservation only.
A19 remains consumed/inadmissible. Never reuse sequence 1205 or 1206.
