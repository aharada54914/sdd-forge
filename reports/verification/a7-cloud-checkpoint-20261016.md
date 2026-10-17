# A7 bounded cloud checkpoint — 2026-10-16

Existing remote branch: `codex/a7-issue195-closeout`.
Publication base: `d64cffcb22b114779202847be33e41700c4ba11f`.
Original owner HEAD: `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`.

The user authorized committing and pushing necessary uncommitted work. This
checkpoint transfers existing candidate bytes to an independent publication
checkout. Each selected path on the remote base was identical to the owner's
original HEAD, so no remote file change is overwritten. The owner checkout and
its index are untouched; official session-stop inspection is unavailable, and
no owner-idle assertion is made. No new live collection or actual refresh command
was executed.

## Existing scope and risk

This is high-risk existing A7 T-004 work and a separately authorized T-012 F2
collection/refresh. It is a candidate checkpoint, not a formal verdict or task
transition. The source repairs require bare and prefixed Status/Approval names,
compare the unchanged lite templates after substituting two predetermined
fixture values, and validate the existing F2 response. They do not infer
expected values from actual output. The existing F3 activation audit changes
are also preserved in the transferred suite; their execution depends on the
governing design in this publication base.

Trusted F2 inputs are `team-coffee-orders` and `注文登録を実装する`.
The owner records describe a fresh response, independent content inspection and
the sanctioned refresh; this publication does not recreate those events or
claim native runtime-model identity. Original raw responses and evidence stay
with the owner. The previous public corpus is preserved byte-for-byte at
`reports/verification/a7-cloud-checkpoint-20261016/f2-before-checkpoint.json`,
SHA-256 `4fe2eff3b2842f5e1228db5f06f99188756e8800608620ef0dfb662fd29b7b88`.
A verification helper initially used a mistyped expected-hash literal and
failed; direct comparison with the original Git blob and the correct hash
then succeeded. No corpus bytes were changed by that check.

| Source artifact | SHA-256 |
| --- | --- |
| `tests/structural-compatibility.tests.sh` | `2039826286ebb863c58cdf4a2e2ffa248aed95c765587e1d7c7a51a5970d2e1e` |
| `tests/structural-compatibility.tests.ps1` | `9fb808bf0f204a61a311af11a8215be967b5a9fc5689f13f8f0cc8f9dbbd0712` |
| `tests/structural-compatibility-live-refresh.tests.sh` | `66b6358e665bed2417a1fb3ce783dafe2b342552cc2657a6c84c213a359ef052` |
| `tests/structural-compatibility-live-refresh.tests.ps1` | `b971ec98124351e84e8e7123e95ef7534754bcc660544afeea72e7025a56785e` |
| `tests/fixtures/structural-fixture-corpus/f2-lite.json` | `21b4275c6eb498a533cf07cdc92fed64cf93e79bfc22f73c5ab426e9cc79dcfe` |

## Executed publication validation

- `bash tests/structural-compatibility.tests.sh`: 61 passed, 0 failed, exit 0.
- `pwsh -NoProfile -File tests/structural-compatibility.tests.ps1`:
  68 passed, 0 failed, exit 0 on macOS.
- Both F2 refresh entry points accepted the published fixture in dry-run mode,
  rejected malformed input without a write, and left the corpus unchanged.
  The PowerShell entry additionally checked reordered artifact handling.
- Bash syntax and `git diff --check` succeeded. Selected sources and the saved
  historical corpus were screened for private owner paths, private-key headers
  and common credential-token patterns before staging.

F3, F5 and F6 were allowlisted SKIPs on this remote base, not executed behavioral
PASSes. The owner's newer normative inputs activate F3 and produce different
counts; those inputs and their frozen review closure are not part of this
checkpoint. Do not transfer the owner's 77/84 counts to these public bytes or
silently declare the old public conditions current. Native Windows, exact-head
CI and independent review of this complete publication delta remain pending.

## Cloud continuation and held work

The canonical local 13-task plan remains: 3 Done, 6 Implementation Complete,
T-004/T-010 In Progress, and T-011/T-013 Planned. Those fields and all approvals
are unchanged. Frozen specifications, task plan, traceability and identity
ledger were not copied or rebound.

T-004's YAML acceptance gap remains blocking: existing canonicalizers accept
malformed flow inputs and no approved native complete parser/profile resolves
the broad frozen wording. This checkpoint does not narrow that contract or
claim the full T-004 exception review passed. Before implementation or formal
evaluation in the cloud, reconcile the owner's approved normative amendments
and immutable review inputs through an authorized private handoff, choose the
legitimate YAML repair/design route, then bind fresh inputs for independent
review. Existing focused status-field/rendering reviews do not replace that
whole-task gate.

Shared launch/guard repairs, unrelated tasks and temporary fixtures remain
outside this branch update. No protection bypass, install, trust change, merge,
force push or history rewrite is performed. No cloud session is launched here.
