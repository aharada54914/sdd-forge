# T-004 fresh quality-gate readiness — 2026-10-07

This is a non-frozen preparation record, not a verification contract, evaluator
manifest, independent verdict, or task-state transition. It does not supersede
the cycle-3 `NEEDS_WORK` report or close RT-20260814-001. No identity was
reserved and no evaluator was launched.

## Scope and baseline

- Task: A7 T-004, `Risk: high`; owner checkout:
  `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`.
- HEAD before this note: `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`
  (detached). `git status --short` showed 367 dirty paths across multiple
  owners; this note changes none of those existing paths.
- Affected contracts: T-004's amended Done When, REQ-002/AC-005,006,007,030,
  042,043; high-risk quality-gate evidence/admission; T-011's sole ownership
  of protected `.github/workflows/test.yml`.
- Required next validation is a fresh Default-FAIL contract, current-byte
  deterministic checks, independent evaluator, final-head CI, and the normal
  Done decision. This preparation claims none of those outcomes.

## Reusable observations, not gate PASS

| Current file | SHA-256 | Bounded observation |
|---|---|---|
| `red-accounting-correction-20260927.md` | `a6f770ce289e94680ff8d43727450fe86635333e002d2be6b42a4b151fbb1321` | Withdraws historical 115/1 as reproducible evidence and explains the replay. |
| `red-accounting-20260927-counts.log` | `c0ed9c2d55be145fd9cf33f5ac8906610d2f6616a212ba320703c371cbaf509b` | Per-mutation RED classification 113 killed / 3 survived; RED replay exits before the harness summary because an old PowerShell runner-contract restore check fails. GREEN records 116/0. |
| `activation-repair-20261004.md` | `d3c33c2366a08b606a9bebc0eb4517556aebd3b09aa8d2787859e1bb737d6b88` | Implementation-side F3 activation account. |
| `activation-donewhen-inventory-20261004.md` | `ec2517035712fbb6a2afb6bffa305ee018c6fb3841445179c2d61c26067c4af9` | Maps Done When evidence and unresolved gate/CI obligations. |
| `activation-final-sh-20261004.log` | `8fbbbacc542f6c53a34297a3c664b106c22398428b1b796f1f36879164c51425` | Historical current-tree local Bash 77 passed / 0 failed. |
| `activation-final-ps1-20261004.log` | `d4d9c9ef8185790ebf9ec8387978817b0e6f6179fb04f788d2b935982a30fed1` | Historical current-tree local PowerShell 84 passed / 0 failed. |
| `activation-mutation-sh-20261004.log` | `2be82c1dbc99095076bbe983c84b46b67b3e5ff5e6c6142e66c99d703a3e0dca` | Five focused Bash mutations killed / zero survived. |
| `activation-mutation-ps1-20261004.log` | `5f2975976787461cdd4b8d7f8c1e51a4ea2fb0bce1a44d6c26f56fcd3ec72823` | Five focused PowerShell mutations killed / zero survived. |

Paths in the table are relative to
`specs/epic-195-a7-compatibility/verification/T-004/`. These hashes were
recomputed for preparation, not used as an evaluator allowlist. Current test
source hashes are `8c763a5f321f6eaed481cc7d4b7756f074a1df562a7c3f3c15c318580ce76222`
for `tests/structural-compatibility.tests.sh` and
`f4a18da6ce7f898572d6a166bc303bd2866bb5df630aff1ce52b52110089af60`
for its `.ps1` twin. Rehash every admitted file immediately before any launch.

The T-004 Done When wording was amended in `tasks.md` to use a non-frozen
addendum rather than directly updating frozen `traceability.md`. Task-review
attempt 17 round 1 integrated verdict and contract both record `PASS`; current
task-plan SHA-256 is `238ff603536347109d5c9983d2dd2ecee45e24d59cf31fb36b2d86fdfde5fd50`.
That re-review rebinds the wording; it is not a T-004 quality verdict.

## Earlier traceability failure: resolved structurally only

`activation-gate-preparation-20261004.md` recorded `check-traceability ...
require-evidence` exit 1 because REQ-002/003/004/007 then had no evidence
entries. The subsequent `requirement-evidence-register-20261004.md` and
current `traceability.json` add explicitly partial evidence paths for those
four rows, without claiming requirement completion. On 2026-10-07:

- `derive-traceability-json.py --check`: exit 0, seven links in sync with
  current `traceability.md`.
- Bash `check-traceability.sh <traceability.json> . require-evidence`: exit 0,
  seven links. This proves structure, path safety/existence and non-empty
  evidence, not REQ-003/004/007 completion or T-004 acceptance.
- PowerShell `check-traceability.ps1 -TracePath <traceability.json> -RepoRoot .
  -RequireEvidence`: exit 0, seven links; the same bounded structural result.
- `traceability.json` SHA-256 at this check:
  `10513348986c5fb560283f0b13405a5d9c06f66f686900ef45e3fca1927ee1ef`.

Do not clear the independent gate's other checks because this structural
failure disappeared. The older `fresh-contract-candidate-20261004.json`
correctly remains Default-FAIL but has stale `spec_revision` and no current
passing gate-time evidence; neither it nor the historical T-004 contract can
be adopted as a passing contract.

## Protected CI ownership and admission boundary

T-011 alone owns `.github/workflows/test.yml` and cumulative CI registration
(`tasks.md` T-011 Planned Files); it depends on T-004 and the remaining suite
tasks. The old T-004-labelled whole-file `human-copy/.github/workflows/test.yml`
candidate and `MANIFEST.sha256` are historical, stale against the live workflow,
and not T-004's current CI deliverable. Do not apply, rebase, or include them
as proof of T-004 current-head CI. The evaluator must explicitly classify the
historical scope finding; a preparation note does not dispose of it. T-011's
later protected edit needs its own authorized application and validation.

The current T-004 implementation report's `## Outputs` table contains
historical hashes, including the withdrawn malformed RED and old suite/runner
bytes. The post-2026-09-27 correction and 2026-10-04 activation files above
are not rows in that table. The quality-gate skill's WFI-036 evaluator input
rule allows changed/test/evidence files only when their exact path/hash pair
is declared in the sole implementation report's Outputs table or in a pinned
prior gate report's Post-Fix Artifacts channel. This note is neither channel.
Do not hand an evaluator these files via prompt, direct tree access, or a
manifest invented from this table. A scoped decision is required on a lawful
declaration channel for the current bytes without rewriting an old verdict or
misattributing T-011's candidate. If neither channel can declare them under
the approved scope, stop before reservation.

## Remaining launch blockers and smallest continuation

1. `tasks.md` still says T-004 `In Progress`; quality-gate rejects anything
   other than `Implementation Complete`. The implementer/coordinator must
   establish that status through the approved task lifecycle after completing
   the current evidence report, not in this preparation.
2. Resolve the exact WFI-036 declaration channel above, build a fresh
   Default-FAIL T-004 contract from current inputs, and rerun the applicable
   deterministic/CI-equivalent checks. The 2026-10-04 local observations
   cannot be promoted to gate-time checks by copying their counts.
3. Keep RT-20260814-001 open until the independent gate evaluates the
   correction and explicitly accepts or rejects it. Preserve cycle-3
   `NEEDS_WORK` and all older artifacts. Only then may the normal fresh
   evaluator reservation/launch and eventual Done decision proceed.

No frozen artifact, approval/status field, old contract/verdict, ledger,
protected workflow, or source file was modified by this preparation.
