# Cloud orchestration development readiness

Date: 2026-10-18
Baseline revision: ebf77988270b848b4c58c65721a10c135fc6db0d
Development scope: approved by the user's `承認する` in this session
Implementation status: not started; mandatory independent reviews pending

## Prepared artifacts

- `specs/cloud-orchestration/`: requirements, acceptance tests, design, UX,
  frontend, infrastructure, security, and investigation.
- `docs/adr/0036-thin-cloud-orchestration.md`: proposed architecture decision.
- Root `AGENTS.md`: new active spec directory registered.
- `reports/spec-review/cloud-orchestration/attempt-1/round-1/precheck-result.json`:
  successful deterministic specification precheck and bound input hashes.

The design contains the normative detailed design and proposed contract
family. Executable schemas/adapters, cloud-profile migration, inventory repair,
task decomposition, independent verdicts and live cloud verification are not
claimed complete. Existing historical evidence and product code are unchanged.

## Checks

| Check | Result |
|---|---|
| Repository bootstrap structure | OK; CLAUDE.md advisory only |
| #423 T-001 current-tree historical inventory tests | 17 run; 15 pass, 2 fail on the same stale seven-file line reference |
| #423 T-002 contract-boundary tests | 29 pass |
| New specification precheck | Exit 0; canonical hashes persisted |
| Codex CLI dev/verify account probe | Both reauthentication_required; no model request tested |

The precheck success is not an independent review verdict. Review headers stay
Pending. No identity reservation, reviewer output, task approval record, Done
transition or live cloud execution was fabricated.

## Current blocker and resume conditions

Root `AGENTS.md`, Required Workflow steps 2–6, requires independent specification,
design and task review before implementation. The spec-review skill requires:
"Only after successful reservation and `REVIEW_CONTEXT_OK`, start the first
reviewer turn in exactly that reserved context." It also says: "If the host
cannot separate identity allocation from execution, stop; do not fabricate
IDs, start a provisional review, or reserve an already executed review
afterwards."

Restore the CLI's authenticated account connection first. Then verify that the
available host actually supports idle identity allocation, isolated read-only
review inputs and reservation-before-first-turn. Do not treat authentication
success alone as proof of these capabilities. Existing development approval
remains valid; do not request it again merely because authentication changed.

Before resuming the first round, verify that its precheck-bound inputs and the
identity ledger are still current. Use the prescribed attempt/round lifecycle
if inputs have changed; do not overwrite the original precheck. Run spec and
design review, finish schema contracts and the consumer impact inventory as
required by that design review, then generate/review the concrete task plan.
Implement tasks sequentially within the approved scope and run quality gates.

Live trials additionally require explicit sandbox scope, protected CI/OIDC
configuration, images, network/health/backup policy, budget and retention. Do
not substitute fixture evidence for those trials or treat development approval
as production deployment approval.
