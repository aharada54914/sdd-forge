# T-003 CLI integration verification

Scope: Issue #423, T-003; owning branch `codex/issue423-cloud-publish`.
Baseline: `9b43aeab866ca61bfb744546055cd9a58eac3d6e`.
The pre-existing untracked device-path inventory is excluded from publication.

This bounded high-risk parser repair preserves production contracts,
historical verdicts, approvals and task states. It reuses the existing resolver
fixture installer and target profiles, but passes the actual resolver CLI output
unchanged into the selected-plan CLI. Fixture observations are not proof that
native host checks executed.

The original evaluator failed on all five target profiles: the resolver emits
JSON in `facet-manifest.yaml`, but the evaluator selected YAML parsing solely by
extension. The existing resolver-evidence reader already supports both formats
through the canonicalizer. Reuse that reader and its explicit failure type;
retain schema, digest, required-check and byte-binding validation unchanged.
The pre-fix integration run failed with five subtest failures (8.547 seconds).

## Preflight and required validation

| Persisted field | Counterpart | Mismatch rejection |
|---|---|---|
| selected checks | Registry implementation gates | missing required observation |
| check availability | Registry implementation reference | absent verifier |
| input binding | resolver-produced manifest bytes | malformed or missing manifest |
| verdict | required observations and input validity | negative cases must not PASS |

Run the existing T-001/T-002/T-003 suites plus these integration cases, obtain
independent diff review, and require CI on the resulting exact commit. This
record does not itself declare a quality-gate PASS or Done.

## Executed results

- T-001 consumer inventory: 17 tests passed.
- T-002 contract boundaries: 29 tests passed.
- T-003 selected-plan suite: 29 tests passed (29.333 seconds), including actual
  resolver-to-evaluator CLI execution for all five target profiles and four
  rejection cases per profile. Existing 28 tests were retained.
- Shared resolver-evidence reader suite: 138 checks passed, zero failed.
- Fresh independent Codex diff review: PASS, zero Critical/Major findings;
  reviewer independently reran all 29 tests (28.346 seconds), checked packaged
  execution, existing block-YAML equivalence and controlled non-UTF-8 rejection.
- Whitespace validation: passed.

The independent review is development-review evidence under the authorized
exception, not a replacement historical ledger entry. Exact final-commit CI and
the quality-gate completion decision remain separate. Native Windows execution
was not performed locally; observation fixtures do not prove live verifier
execution or deployment.
