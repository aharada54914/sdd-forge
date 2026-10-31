# T-004 fresh recovery observations

Observed by fresh subagent context `/root/a8_fresh_recovery`, before a new
implementation report or evaluator reservation.

## Identity observations

- Codex thread ID: `01a106f8-2542-7a60-b956-e58bc00294b3` (environment
  `CODEX_THREAD_ID`, independently corroborated by rollout `session_meta.id`).
- Codex shared session ID: `01a06d01-11b5-7bd3-83a3-7e29bb3c96cd`
  (`CODEX_SESSION_ID` and rollout `session_meta.session_id`); this is also the
  parent thread ID, and is not claimed to be a distinct child host session.
- Turn ID: `01a106f8-25b7-7471-905f-8d8fe2f18fde` (rollout `turn_context`).
- Agent instance path: `/root/a8_fresh_recovery` (runtime collaboration inventory
  and rollout `session_meta.agent_path`).
- Model: `gpt-6-astra`; effort: `medium` (actual rollout `turn_context`, not
  inferred from the registry default). The live registry classifies this model
  as `strong`; its default and the high-risk effort matrix say `high`.
- Scratch Root: `/private/tmp/a8-t004-recovery-impl-aE3ufq` (actually allocated
  with `mktemp -d`; this belongs exclusively to this implementation context).

These are context identity observations, not native hook activation evidence.
No historical identity was reconstructed and no implementation or evaluator
reservation was inserted. The shared session identifier requires explicit
contract interpretation before any claim of distinct host-session provenance.

## Fresh observed checks

All commands ran through `rtk proxy`, `login=false`, in the owner checkout.

| Check | Result |
|---|---|
| `bash scripts/check-sdd-structure.sh` | exit 0; `check-sdd-structure: OK`; advisory `CLAUDE.md` |
| Eight `after` hashes in `reports/verification/a8-t004-recovery-v2-pins.json` | all match current bytes |
| Old canonical implementation report | SHA-256 `48bf3519745073238f230199b9f5dafdb52fdf1108b5e05071931209fc7c928f`, unchanged |
| Five exact old report Outputs paths/hashes | all match current bytes |
| `env TMPDIR=/private/tmp/a8-t004-recovery-impl-aE3ufq pwsh -NoProfile -ExecutionPolicy Bypass -File tests/cli-hook-enforcement.ps1` | exit 0; 17 passed, 0 failed; all three TEST-012 cases and TEST-017 observed |
| `sh plugins/sdd-quality-loop/scripts/check-traceability.sh specs/epic-196-a8-integration/verification/T-004/traceability.json . require-evidence` | exit 0; 1 link passed |
| Ordered-line comparison with `git show c886b790:tests/cli-hook-enforcement.ps1` | all 100 baseline lines preserved verbatim and in order |
| `git diff --check` | exit 0; empty output |

The baseline bytes hash to
`22f984afdf51698d575b375f6654a98310149f7ba5caba1a81af5ff0d9d17f40`;
the current suite hashes to
`343aa50f12d790619dc5d636831d6f1c7d1559745b9ca289ad67fb28564a3bec`.
The historical 101-line wording remains a documented spec discrepancy.

## Scope and remaining boundary

No implementation, task status, old report, historical handoff, or ledger was
changed. No Done decision or independent evaluator verdict is made. Current
local success is synthetic guard-contract evidence only; it does not satisfy
T-007/T-008 native proof, current-main integration CI, or a release condition.
The formal evaluator must remain read-only; an allocated scratch directory
does not authorize canary writes.
