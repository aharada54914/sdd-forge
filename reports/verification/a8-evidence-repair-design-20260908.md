# A8 evidence repair: diagnosis and recovery boundary

Date: 2026-09-08
Ticket: docs/review-tickets/RT-20260908-003.yml
State: design under review; no recovery implementation or fresh review PASS

## Authorization and preserved state

The user approved preserving old records, creating a repair ticket, and repairing
and verifying the formal restart procedure. This is not authorization to deem
historical FAIL results passed. Ordinary required CI and independent review remain.

Source checkout: `/Users/jrmag/.local/share/sdd-forge-a8-verify-20260905`.
Source round: `reports/spec-review/epic-196-a8-integration/attempt-4/round-2`.
Read-only SHA256 observation (tool d09c4e):

| File | SHA256 |
| --- | --- |
| integrated-summary.json | 66c584c43a843060b9ae44c286fa57d97b28ba1ee3a3dffe8829afd250c92ac6 |
| integrated-verdict.json | 28c35b454e56f6e4c1fd38603a1bdf7fb04edcb69e4b1d8db580297b29ad0f97 |
| precheck-result.json | f8c88d794fd7920a8dbbdecb2c835235434ac5f368ca2007b03c5276946503c6 |
| review-context-spec-reviewer-a.json | 236237dce147e280fa40c967b7edb869d54178a3d83d0c836fba2eb3d87fe701 |
| review-context-spec-reviewer-b.json | cec29ef7f0db99f225f3b9cf2a14b4222785602cb923ad288f7d5ba11d9ef749 |
| reviewer-a.json | eef79627862ac2f4299d1c4b37930b8d439027c061480810086c76c3f5c3eb43 |
| reviewer-b.json | 60a33974eebda4db67ecc0e3419955f58b4d5fb489169e378c1ba5e2d0936a5a |
| spec-review-contract.json | 2e8fce17dc3133fc0a1360defa78cbd17605b6a592f568d8ffa853c2714d6586 |

These are observations, not a newly approved review contract. Preserve all other
files in the round as well, including initial outputs, launch records and proposal.
The canonical identity ledger must retain all historical reservations.

## Reproductions and diagnosis

1. Existing attempt 4 round 3 invocation with the human edit summary exits 1:
   `prior round contract is malformed or does not require work` (eddd7a).
2. `spec-review-precheck.sh epic-196-a8-integration 5 1 --reset` exits 1:
   `reset requires a terminal PASS or BLOCKED contract` (b2fed3).
3. Read-only JSON inspection confirms `generated_at` absent and reviewer B's
   manifest pins the exact old summary hash above (d09c4e).

Source evidence: `spec-review-precheck.sh:241` requires the exact summary key set;
`:388` starts normal reset validation. PowerShell applies the same summary keys
at `spec-review-precheck.ps1:316` and requires a string at `:330`.
Reverify line references against the candidate before review; this is shared code.

Three hypotheses: (a) summary schema omission, confirmed; (b) current spec input
changes incorrectly treated as historical tampering, not sufficient to explain
the explicit missing key; (c) supported reset can restart malformed evidence,
disproved by the actual reset invocation. No conclusion that all other old
evidence is valid follows from isolating the first rejection.

## Proposed formal transition

Normal continue and reset remain unchanged. A separate, explicit recovery request
would retire an unusable attempt for progression purposes only, not validate it.
Its append-only record must bind the ticket, exact feature, source attempt/round,
complete source file manifest, diagnosed defect, human approval evidence, and
the immediately following attempt's round 1. A boolean supplied by the caller is
not sufficient proof of human authorization.

The precheck must validate this authorization through an established trusted
approval mechanism, validate unchanged source bytes and canonical paths, require
a previously unused destination, acquire the existing lock, and recheck state
under that lock before persisting the transition. A stale or replayed request
fails without changing a status or writing review evidence. Old findings are
not waived: the new attempt runs the full review, with fresh identities and
complete current inputs. Pending remains Pending until a valid fresh merged PASS.

The unresolved design question is which existing trusted approval mechanism can
authorize this new transition without making caller-authored JSON a gate bypass.
Do not implement an authorization shortcut merely to advance A8.

Before reviewer B launch, enforce the complete summary schema including a real
creation timestamp; validate summary counts against A's checks before hashing and
reserving B's input. Never amend an already consumed summary in place.

## Verification plan

- Negative controls: unchanged current continue/reset still reject the malformed
  historical round; missing timestamp rejected before B launch.
- Positive controls: existing valid normal continuation and terminal reset.
- Recovery controls: exact approved request can start only next attempt round 1;
  no historical verdict or reservation changes.
- Fail-closed controls: absent/untrusted approval, stale hashes, extra/missing
  source files, symlink/path escape, wrong feature, skipped attempt, round > 1,
  replay, concurrent destination creation, reused reviewer identity.
- Preserve schema/verdict/check-count consumers in both shell implementations
  and `check-workflow-state.{sh,ps1}`. Inspect other consumers before choosing
  the persisted recovery schema; this consumer list is not claimed exhaustive.
- Run regressions and independent review; verify native-platform requirements
  separately. A successful recovery precheck is not specification acceptance.

## Current result

Repair ticket created. Read-only defect and reset-boundary verification completed.
No gate scripts, historical evidence, requirements status, commits, PRs or merges
changed in this repair slice. Production recovery and its regressions remain
unimplemented until the authorization boundary is settled.

## Independent investigation and security decision

Read-only investigator `recovery_boundary_review` independently found no supported
malformed-evidence restart. Existing downstream-staleness tolerance concerns valid
historical contracts and amended inputs, not a missing required summary field.
This investigation is not a formal specification or quality-gate PASS.

The existing signed-approval validator recognizes only project-context and
provider-bindings families (`validate-approval-sidecar.py:153-158`), verifies
HMAC and registered approver identities, and enforces its content schemas. It
must not be tricked into signing a recovery record as project configuration.

Proposed decision: extend the trusted approval contract with a distinct,
purpose-bound review-recovery authorization, covering the exact source manifest
and next attempt. Preserve current schema families and their validation. This
is a newly identified security-contract change requiring explicit design
authorization under `debugging-recovery-policy.md`, Boundaries: when diagnosis
reveals an architecture/auth decision, stop and defer to a human. Accordingly,
the ticket remains open with `requires_human_decision: true`. Prior scope
authorization is retained and does not need to be repeated.

## Design authorization received (2026-09-08)

The user explicitly approved: 「既存の署名付き承認機構を拡張し、対象証跡のハッシュと次の試行番号を限定した『復旧専用承認』を追加してよい」.
This supersedes the pending authorization question and the
`requires_human_decision: true` statement above; the ticket now records false.
Implementation and regression verification remain outstanding. This conversation
approval authorizes the mechanism's implementation, not fabrication of a signed
human approval artifact. Existing signature and registered-approver checks remain
mandatory, as do exact manifest, purpose, and next-attempt binding. No historical
review result is upgraded by this decision.

## Implementation boundary and preflight (2026-09-08)

Scope is RT-20260908-003 only. The new sidecar purpose is
`sdd-review-recovery-approval/v1`, with content governed by
`contracts/review-recovery-request.schema.json`. Existing project-context and
provider-bindings semantics remain unchanged. The recovery consumer must use
full standard validation, never provenance-only verification: the latter does
not validate the content or registry (`validate-approval-sidecar.py:930-936`;
standard validation at `:911-927`). Reverify these shared-code references before
the independent review consumes them.

The signer currently resolves project-policy lineage through a live sidecar
and the policy-weakening detector (`generate-approval-sidecar.py:369-397`) and
stages publisher-oriented project anchors (`:438-445`). Merely adding a schema
name to its dispatch map is NOT a complete recovery implementation. Recovery
requires a separate staging destination and must not publish or overwrite a
project-context anchor. Signing remains human/CI-only (`:10-14`); tests must use
isolated disposable fixture keys, never resolve the user's production key.

### Persisted-field mismatch checklist

These tests are required before the corresponding runtime implementation;
only the purpose-registration Red tests exist so far.

| Persisted field | Counterpart checked by consumer | Required failing mismatch test |
| --- | --- | --- |
| sidecar schema / request purpose | explicit recovery-only consumer | project approval presented as recovery; recovery presented as project approval |
| context_sha256 / HMAC | canonical complete request and trusted key | mutate each bound request field after signing; wrong key; absent signature |
| primary/second approval | trusted registered identities and existing distinctness rules | unknown approver; missing registry; duplicate second identity |
| ticket | requested repair ticket | substitution of another ticket |
| repository binding | canonical checkout identity | request replay in another checkout |
| feature / stage | invoked feature and spec-review gate | wrong feature or stage, including case variants |
| source attempt / round | latest actual attempt and last round | stale attempt, skipped source round, booleans instead of integers |
| source manifest paths / hashes | exact complete source file inventory and raw bytes | changed bytes; added/removed file; duplicate, traversal, absolute or symlink path |
| destination attempt / round | source attempt + 1, round exactly 1, unused destination | skipped attempt; round 2; existing destination; replay |
| recovery record's request digest | exact signed request validated under the gate lock | request replacement between preflight and locked commit |
| historical ledger reservations | preserved historical entries plus fresh new identities | reused identity; altered/deleted historical reservation |
| new precheck input hashes | complete current specification input set | edited input between initial check and locked publication |

Do not add an unchecked `approved` boolean, trust an arbitrary caller registry,
use a fabricated terminal verdict, or relax the normal continuation/reset paths.
Validation is repeated under the same gate lock before any transition record is
published. Crash handling must not turn a partial new attempt into a reusable
authorization; the subsequent invocation must refuse or follow an explicitly
tested recovery-of-publication path, never silently overwrite evidence.

### First regression result

Command: `rtk proxy python3 -B tests/review-recovery-approval.tests.py -v`.
Tool result: `63012c`, exit 1, 3 tests, 3 expected assertion failures, 0 errors.
The missing purpose is demonstrated independently in the sidecar schema,
signer dispatch and validator dispatch. This is TDD Red, not product acceptance
or coverage of the mismatch matrix above. No production signing or historical
evidence mutation occurred. Runtime implementation, negative controls, full
regressions and independent quality verification remain outstanding.

## Adversarial design review and disposition (2026-09-08)

Independent reviewer: `/root/recovery_design_security`. This is a preparatory
security design review, not an SDD Passed status. Findings: two Critical, one
Warning. No implementation has been accepted or merged.

1. **Critical: helper outside protection boundary.** The proposed new helper
   was absent from protected-target registration, unlike the existing signer
   and validator (`generate-guard-invariants.py:148-167`). Disposition: remove
   that helper from the plan and ticket. Recovery authorization remains in the
   already protected `validate-approval-sidecar.py`. Do not introduce a writable
   helper whose success a protected gate treats as authorization. Verify the
   protection of any newly consumed contract and durable state before adding it;
   a JSON schema must not be the sole enforcement of authorization semantics.
2. **Critical: registry authority.** Standard validation permits caller-selected
   registry paths (`validate-approval-sidecar.py:909-920,993-994`) and otherwise
   uses CWD-relative `sdd/approver-registry.yaml` (`:905-906`). Disposition: the
   recovery entrypoint must derive this exact relative path from the signed,
   canonical checkout root, reject a supplied registry override and linked path
   components, and revalidate under the transition lock. Normal existing CLI
   behavior is not changed. Add a negative test with a substitute registry in a
   different working directory. The signer does not grant authority to a name
   merely by embedding it in a signed sidecar.
3. **Warning: durable consumption and path races.** Proposed location is a
   digest-keyed receipt under the new attempt, never inside the old round.
   Exclusive creation of the next attempt claims the authorization before round
   artifacts are written. Any existing destination, even empty or partial,
   refuses reuse; an interrupted publication is not automatically rolled back
   or retried. A receipt alone does not authorize continuation: ordinary
   consumers must verify its signature, bindings and the completed precheck.
   Filesystem durability, protection of the claimed destination, and prevention
   of non-cooperating parent swaps are still implementation prerequisites:
   advisory locks and repeated string-path checks alone are insufficient.
   Specify and test platform-appropriate pinned-directory operations before
   enabling recovery, including interrupted writes, dangling links and swaps.

The first two decisions resolve design ambiguity but are not verified fixes.
The publication warning remains open until the receipt consumer inventory,
protection and atomic publication tests establish the complete transition.

Additional Red test: `6ee992`, same test command, exit 1, 4 assertion failures,
0 errors. The added test executes real provenance-only validation with an
isolated public fixture key: current code returns `HMAC_MISMATCH`, not the
required purpose-specific refusal `RECOVERY_REQUIRES_FULL_VALIDATION`. It does
not prove that a real signed recovery is currently accepted; no recovery purpose
is supported by the standard path yet. No real signing credentials were read.
