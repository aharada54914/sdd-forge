# Issue 347: annex payload loss and severity requirement gap

Read-only diagnostic, 2026-09-09. Not a formal review verdict or a passing
acceptance record. No production, frozen specification or historical evidence
was changed.

## Authoritative inputs

- GitHub issue 347, fetched with `gh issue view 347 --repo
  aharada54914/sdd-forge --json title,body`: its example places `claim` under
  `basis` and requires evidence/concern to be separately stored and displayed.
- Recovery checkout `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`.
- `contracts/cross-critique.v1.schema.json`, observed SHA-256
  `994702bb1384a95a7437644eb3b4dee929408f49cae988a706f8c2bb4208527a`.
- Existing `tests/adversarial-review-contracts.tests.mjs`: Ajv strict settings
  with strictRequired/strictTypes/validateFormats disabled. This diagnostic
  reused those settings and installed `mcp/ci-mcp` Ajv, without installation.

## Executed probe (exit 0)

An inline Node probe compiled the actual checkout schema and validated four
in-memory annexes. Common fields were schema_version=cross-critique.v1,
round_id=diagnostic-only, status=complete, created_at=2026-09-09T00:00:00Z;
one verdict had target_finding_id=A-1, critic_role=reviewer-b and
scope.assessment=unclear. Each case independently supplied:

| Case | Verdict and basis | Actual result |
| --- | --- | --- |
| Concern without text | SUPPLEMENT; `{kind: "concern"}` | accepted |
| Concern with issue example's text field | SUPPLEMENT; `{kind: "concern", claim: "unverified risk"}` | rejected: `/verdicts/0/basis`, additional property `claim` |
| Severity change without destination severity | PROPOSE-SEVERITY-CHANGE; code_evidence with citation `{path: "src/example.ts", claim: "evidence"}`; no proposed_severity | accepted |
| Concern-only rejection control | PROPOSE-REJECT; `{kind: "concern"}` | rejected: missing citations and invalid evidence kind |

These are observed schema decisions, not four acceptance-test passes.
No host CLI, external reviewer or protected script was invoked.

## Consequence for repair and integration

The schema forbids `basis.claim`, stores claims only inside citations, and
forbids citations for concerns. Thus a concern cannot carry the issue's
specified text at that location. Optional `fix_critique` is not an equivalent
required concern claim. The proposed_severity description says it is required
for severity change, but no conditional requires it. The existing driver does
not exercise these cases.

Reconcile the owning approved specification/task before editing: define the
canonical claim location and backward-compatibility treatment, require a
destination severity for severity-change verdicts, and add original-path
positive/negative regressions. Do not remove PR381's existing concern-based
rejection protection. Both runtime validators, producer instructions, display
and storage consumers must follow the same contract. Blind input manifests and
persisted verdict/state transitions remain unchanged. Native runtime parity
and formal gates are still unverified; issue 347 must remain open.

PR371's latest failing MCP jobs are terminal, not a live wait. Their earlier
golden-test integration diagnosis is already recorded in
`pr371-mcp-failure-mapping-20260908.md`; do not duplicate that repair or rerun
unchanged historical heads hoping for green. This new annex evidence instead
narrows a separate substantive acceptance gap in PR371/PR381 integration.

## Owning workflow and consumer check

Follow-up inspection of the recovery checkout found no
`specs/review-cross-critique/tasks.md`; the PR371 pinned Git tree also contains
only investigation, requirements, design, acceptance tests and four layer
specifications for that feature. The current requirements line 3 is
`Spec-Review-Status: Pending` and design line 3 is
`Impl-Review-Status: Pending`. Therefore no Approved task was established for
this repair. A repository-wide merge request is not an Approved task record.

A bounded search of both working copies' `docs/review-tickets` for
`347|cross-critique|adversarial-review` found no matching issue/feature repair
ticket (the only numeric hit was an unrelated run sequence 0347).

Searching recovery `scripts`, `plugins`, and `tests` implementation files
(`.sh`, `.ps1`, `.py`, `.mjs`, `.ts`) for the full schema filename,
`cross-critique.json`, or `proposed_severity` returned no literal hits.
This is not proof of no consumer: the inspected MJS driver dynamically builds
the schema filename. It does mean that no Shell/PowerShell production consumer
has yet been identified by that search. Do not claim validator parity from
the single Ajv probe.

The inspected standalone `skills/adversarial-review/SKILL.md:124` references
the schema, but its protocol explicitly excludes SDD gate reviews. It must
not be repurposed as an alternate formal-entry path. Next implementation must
follow the restored bootstrap/spec/design/task sequence, incorporate the two
concrete payload regressions above, and identify both production validator
entry points before asserting issue 347 acceptance. No Draft task was
implemented and no new review attempt was launched in this follow-up.
