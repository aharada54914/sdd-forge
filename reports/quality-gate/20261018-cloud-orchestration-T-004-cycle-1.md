# Quality Gate Report

Task ID: T-004
Feature: cloud-orchestration
Run ID: 01a14dbe-2a3a-7221-819e-f459ecb038a2
VERDICT: NEEDS_WORK
Critical: 1
Major: 1
Minor: 0

<!-- Identity header contract (WFI-020). Every line above is parsed by a     -->
<!-- deterministic consumer: Task ID by check-evidence-bundle and the         -->
<!-- run-record/cycle-limit counters (canonical task-identity field; the      -->
<!-- legacy separate `Task:` line is retired — do not add one); Feature by    -->
<!-- report selection and the exactly-one rule in check-evidence-bundle;      -->
<!-- Run ID by the retrospective's artifact rules (value = the evaluator run  -->
<!-- id reserved in the identity ledger for this gate run); Critical/Major/   -->
<!-- Minor by generate-evidence-bundle, which records zeros when absent.      -->
<!-- Keep each as a bare line before any prose, and never start a later line  -->
<!-- in the body with `Feature: ` or `Task ID: `.                             -->

## Target
Azure route/plan/validate and actual pinned local Bicep compilation, REQ-002 / REQ-003 / REQ-007.

- Model: openai/gpt-6-astra
- Effort: high

## Implementation Report Reviewed
Frozen canonical `reports/implementation/cloud-orchestration/T-004.md`; the exact input manifest, supplemental delivery and any declared post-fix inputs determine the bytes reviewed.

## Verification Results
Initial caller passed 40 routing and 31 contract tests plus static/deterministic gates. Independent review found an escaped CloudFormation key ownership bypass and missing later independent-review completion attestation. The bounded correction first committed a failing regression, isolated its temporary outputs and committed three genuine failing cases before production change. Current 42 routing and 31 contract tests, Ruff, mypy and scoped 42-candidate/40-restored rollback passed. Actual pinned Bicep checks ran through the routing suite; no cloud calls.

## Evidence Matrix

| Surface | Evidence Type | Evidence Path Or Command | Result | Notes |
|---|---|---|---|---|
| Initial caller checks | command_output | specs/cloud-orchestration/verification/T-004/quality-cycle-1/commands.json | PASS | pre-fix bytes |
| Independent findings | line_inspection | specs/cloud-orchestration/verification/T-004/quality-cycle-1/review/evaluator.txt | NEEDS_WORK | Critical 1 / Major 1 |
| Post-fix checks | command_output | specs/cloud-orchestration/verification/T-004/owner-fix/checks.json | PASS | fresh review required |
| Scoped disposable rollback | scripted_gate | specs/cloud-orchestration/verification/T-004/owner-fix/rollback.json | PASS | 42 candidate / 40 restored |

Implementation-report statements are claims, not evidence. Leave no in-scope
surface without a command, scripted gate, line inspection, or manual artifact.

## Cannot-Verify Items

| Surface | Missing Evidence | Blocking Ticket Or Resolution |
|---|---|---|
| None in T-004 local completion scope | none | live cloud remains blocking for the later affected tasks |

In-scope cannot-verify items block Done until evidence is collected or a review
ticket is created. Waivers are valid only for optional out-of-scope checks.

## Out-Of-Scope Waivers

| Surface | Why Out Of Scope | Waiver Reference |
|---|---|---|
| Governed deployment, live health and native Windows execution | Outside this POSIX local preparation task | Not waived for affected later tasks |

## Critical Review Cycles
Cycle 1: NEEDS_WORK, one Critical owner-detection bypass and one Major completion-evidence gap. Actual independent evaluator 01a14dbe-2a3a-7221-819e-f459ecb038a2; invocation SHA-256 144da457b2790b023da45d9581714185363a82cd5d4e3dc580bfba66880a7007. Delivery hashes equal the launched input set and every read stayed within the allowlist.

## UI Verification
Not applicable; no UI.

## Traceability And Drift
Canonical attempt-2 implementation report remains a frozen pre-review snapshot. Root addendum documents the named fresh evaluator plus caller formal checks and actual later completion record. No future PASS is asserted. JSON key decoding and fail-closed ambiguous YAML enforce existing exclusive-owner policy.

## Review Tickets
RT-20261018-CLOUD-OWNER correction and scoped checks complete. Fresh cycle 2 must independently evaluate the post-fix bytes and completion addendum.

## Decision
NEEDS_WORK preserves the actual cycle-1 findings. Retain Implementation Complete pending fresh independent evaluation and bundle validation.

## Post-Fix Artifacts

These bytes were produced after the finding from this cycle; they require a fresh review. The original verdict remains unchanged.

| Path | SHA-256 |
|---|---|
| `plugins/sdd-azure-cloud/scripts/cloud.py` | `74d83e53df2776de9b92a6fbdd6a1fa81e189a46173278d67bc11b1de8cae674` |
| `plugins/sdd-azure-cloud/references/local-contract.md` | `68850cae945e1e5357fedb284079cce67fec809a07cd1a35f6f923a39b89fdfc` |
| `tests/cloud-orchestration-routing.tests.py` | `8c7425a05465a229f380e4c19eaf68e7455b31737a1a465a36ef2c9b46acc34e` |
| `docs/review-tickets/RT-20261018-CLOUD-OWNER.yml` | `f4a2877f8d0bcefd5f9a5ce151a161011ff2f080c2dca98268e559b1b9bd89e5` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/red-initial.log` | `97acdd47c1b1c885542ec489f10ce71d58409dfdaf6371a9a700e0f779f8d834` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/finding-disposition.json` | `d697a51621cc53dc5d7132fc75fbfa5ac75587cd093a25d9dec8d20c354aa551` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/ruff.log` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/initial-red-driver.py` | `2a6383ba617957d1e3016d85d56c1bb118826b96cb12f276c3b5d4587e6353fd` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/green.log` | `7f512b0c8ffe3552ce075bfe8462a5b74817efd2caa2bc129c669aafedde0ab0` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/before.json` | `c48f47983a5dfb0e9cfb334077b25677a349839d5e3afe9b3cbd6ef85dec03e8` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/contracts.log` | `ae0dc02d75f6afbfb83cb798a549de7dd57eb0dd967db68835178e29dcf344c8` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/tests-before.py.txt` | `ced34d267e8a200e54013483f4f2ea7ce8a741321b45f1cbb2890046b966b330` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/contract-before.md.txt` | `c6ed05fc942c6e3c9e17ef66e0db0796243583536de3ee5f29f1081fdb934fc5` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/rollback-restored.log` | `2be019cadffdad2976bd4d1277f7b7e92f0b230f3b2c8920b24eca63d44ab1ac` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/rollback.json` | `fcab93ee9215f7fd7428b0bef84a03ce3154cabecb5757a373b99b0aac11255b` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/rollback-candidate.log` | `9ba8efedfd78932922a196b29cb6cc7d372ae3a6726716564e1c04736a945ef0` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/red-proof-initial.json` | `734bb9aea369febea4926f4e249370c087adbf9ed693cafc3ac1f982db47633c` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/red-proof.json` | `fefd9eab7da251e645bd43c1e24a9f704f0d07fc4deadd3a107fa8b86f01ca99` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/cloud-before.py.txt` | `f4789a61a5c95c235fb3108277678aca8058d35dd1b6a24153bffb6cc6261dda` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/mypy.log` | `f9b031e5c45aa702cd4fef028d465551cb20a2c4698e0913c7b00766b20ac4d8` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/red.log` | `554a0a306c0d817531e50eaa4f4cfbe41a2dc185d5424f575dd3284c2b9d8242` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/red-commit.log` | `454d6b7fdb8e462e6e47093846df9a4292c30626dd164a4b31832efa7e1cebc6` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/preflight.md` | `b9d16de1b01487f3dcdc89cda4ef1ce0366efdb99ab4908c487ef78212e9ccd0` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/rollback.py` | `ab7a6f19144f30a6a0150843610714dd61ca6ffb8f58321efa15acffe31a18b7` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/checks.json` | `1368c170c0cdbbe68b5351f4111323f530753384975c5d983965d739c66dae6b` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/red-isolated-commit.log` | `476d423343957882d2b2fc156fb9a283987e26df74347d0d0d9d4db5459c3b6c` |
| `specs/cloud-orchestration/verification/T-004/owner-fix/review-completion-policy.md` | `65b15d4e54aebc2d02d57e6b298c1f21f446a444eddf534a6553893c55c49d9f` |
