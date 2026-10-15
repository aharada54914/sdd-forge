# Fixed review approval issuer repair

Owner: `codex/fixed-approval-issuer`, dedicated managed checkout.
Baseline: `fc9c847743c17d4e0d5760e9e5917b4dccf1db2f`; clean before editing.
Scope: extend the existing staged approval issuer to `sdd-fixed-review-approval/v1`.
Risk: high (approval production). The user authorized implementation, regressions,
independent review and merge, and waived development-only signed approval for this
repair. Runtime registered identities, signatures and input verification remain
mandatory. No real signing credentials or approvals are used in tests.

Affected contracts: fixed-review approval consumer and legacy Project Context /
Provider Binding issuance. Reuse their canonicalization, registry and HMAC checks;
do not alter frozen records, lifecycle state, live installation or global trust.

## Evidence-field preflight

| Issued field | Existing counterpart | Required rejecting test |
|---|---|---|
| schema | fixed approval consumer | unsupported schema |
| commit / inputs (path, mode, SHA-256) | Git blobs / fixed input inventory | changed digest, mode, absent path, duplicate JSON |
| feature / stage / task_id | invocation scope / state consumer | scope mismatch |
| primary_approval.approver | registered approver IDs | unknown or missing registry |
| effective_at | shared UTC nonfuture check | future or malformed timestamp |
| hmac | shared canonical HMAC verifier | missing key, wrong key, mutated document |
| staged bytes / manifest | readback SHA-256 | existing destination not overwritten |

Validation: new issuer-to-consumer tests in the already CI-wired fixed state suite;
legacy Bash and PowerShell issuer suites; affected fixed input/launch suites;
independent diff review; exact-head required CI and postmerge checks. Diagnostic
and local checks are not formal acceptance or deployment proof.

## Executed validation

- Before implementation, the issuer-to-consumer regression failed because the
  existing CLI rejected the fixed schema. The implementation now passes it.
- Independent Codex review initially found partial final output after an
  interrupted write. An injected `KeyboardInterrupt` reproduced that failure.
  The repair uses the existing temporary-sibling/readback/publication pattern;
  interruption and I/O failure now leave no published bundle and allow retry.
- Final local run: all five `tests/fixed-review-*.tests.py` suites passed
  (33 + 50 + 7 + 6 + 12 = 108 tests). Legacy issuer suites passed in Bash
  (69 checks) and PowerShell (67 checks): 244 total, zero failures.
- Independent, no-history Codex re-review: PASS, no blocking findings. The
  reviewer independently ran the 12 fixed-state tests, 69 legacy Bash checks,
  and `git diff --check`, and inspected cleanup, collision preservation,
  registered identity, HMAC and input binding. Subsequent edits only clarify
  CLI help and document invocation; they do not change execution behavior.

No new dependency or workflow lane: the fixed-state and legacy issuer suites
already run in CI. Tests use synthetic signing material, not a human identity.
No frozen approval, task status, review verdict or installed plugin was changed.

Status: local implementation, regression and independent diff review complete.
Latest-head CI, merge and postmerge verification remain separate pending steps.
