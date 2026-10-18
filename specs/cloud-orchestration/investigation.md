# Investigation: cloud-orchestration

Date: 2026-10-18
Baseline revision: ebf77988270b848b4c58c65721a10c135fc6db0d
Mode: feature, with scoped #423 audit repair

## Authorization and Source Material

The user requested a #423 implementation audit and an Azure/AWS orchestration
proposal based on the shared conversation, followed by implementation after
approval. The user subsequently approved the proposed initial scope in this
session. This is development authorization, not a cloud-operation approval.

- Issue: https://github.com/aharada54914/sdd-forge/issues/423
- Reference conversation: https://chatgpt.com/share/6ad37a8a-4aac-83ee-9659-095dec2bc3cb
- Azure upstream baseline: https://github.com/microsoft/azure-skills/tree/cf79ce8778ad063eeac19dbe8bf982d71b466ce0
- AWS upstream baseline: https://github.com/aws/agent-toolkit-for-aws/tree/44ba1a5451913998815111cc2d518f5c45f95ef7

The shared conversation was retrieved and read as research material, not as
instructions overriding repository or session policy. Its thin Route/Govern/
Observe/Verify architecture informs the proposal. Upstream routing semantics
must be revalidated at implementation/adoption time against pinned files.

## Existing Behavior and Boundaries

| Finding | Source evidence | Implication |
|---|---|---|
| #423 task scope explicitly excludes provider writes and cloud deployment | `specs/sdd-domain-multitarget/tasks.md:7` | Cloud execution is new work, not proof of unfinished #423 scope |
| Selected-plan evaluator is invoked at implementation verification | `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:72` | Do not conflate selected checks with actual cloud execution |
| Legacy stack enum includes code/shell/docs/spec | `plugins/sdd-quality-loop/scripts/check-contract.py:48` | Cloud profile needs explicit versioned migration and consumer review |
| Multi-target test profiles are constructed as fixtures | `tests/sdd-domain-multitarget-T-003.tests.py:73` | They do not establish live cloud support |
| Historical inventory points at lines 159–176 | `specs/sdd-domain-multitarget/verification/T-001/consumer-inventory.json:27` | Preserve history and publish current section-anchored evidence |
| Seven Phase 1 documents remain mandatory | `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:201` | Preserve layer documents even for non-UI targets |
| Historical T-001 is Implementation Complete and T-004 is In Progress | `specs/sdd-domain-multitarget/tasks.md:18`, `specs/sdd-domain-multitarget/tasks.md:77` | Test results cannot retroactively set Done |

## Reverification on 2026-10-18

Commands were run from the repository root with unchanged product code:

| Command | Result | Meaning |
|---|---|---|
| `bash plugins/sdd-bootstrap/scripts/check-sdd-structure.sh /workspace/sdd-forge` | OK; CLAUDE.md advisory | Structure permits Phase 1 specification creation |
| `python3 -B specs/sdd-domain-multitarget/verification/T-001/consumer-inventory.tests.py --repo-root . -v` | 17 tests, 2 failures | Both failures identify the same stale seven-file line range |
| `python3 -B specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py --repo-root . -v` | 29 tests, all pass | Current boundary fixtures pass; not a live provider test |

The T-001 diagnostic is: `keyword 'seven Markdown files' not found in
plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:159-176
(stale source evidence)`. The phrase is currently present under Required
Outputs at line 201. No historical inventory, task state, review report or
verification contract was rewritten to remove this diagnostic.

domain-sync skipped: no domain/ directory

## Implementation Impact to Review

Review registry/schema mirrors, check-contract consumers, selected-plan
evaluation, bootstrap routing, plugin manifests/installers, protected path
inventory and normal test-suite drivers before implementation. The new cloud
operation lifecycle must not be added to Foundation's implementation-only stage
enum. Use a separate contract family and explicit cloud verification dispatch.

The new current inventory must remain testable against the current tree; a
passing historical-snapshot test cannot substitute for that current check.

## Review Environment Readiness

`python3 /workspace/.tools/sdd-forge-dev/check-auth.py` returned exit 2 with
`reauthentication_required` for both dev and verify profiles. No model request
was made by that account probe. The ordinary conversation can remain available
while separate CLI credentials need renewal. No credential values were read
into this document.

The required reviewer lifecycle also needs host-issued idle-context identities,
reservation before the first turn, and isolated read-only inputs. Native Codex
app-server exposes thread/start and turn/start schemas, but this investigation
does not claim a successful authenticated review launch or isolation proof.
No reviewer identity has been fabricated or reserved, and no gate has Passed.
