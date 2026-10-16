# Cloud publication checkpoint — 2026-10-16

This is a publication and resumption record, not a quality-gate verdict, task
transition, release, baseline promotion or native-host activation receipt.
The user authorized selected commits and pushes to existing remote branches.
Original owner checkouts, indexes, approvals and historical evidence remain
untouched. Official session-stop inspection is unavailable in this environment;
the publication checkout is independent and does not certify any owner idle.

## T-002 provider-key repair

Publication base: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`, existing branch
`codex/issue423-boundary-checkpoint`. The remote head matched that base before
publication. This unit publishes an existing reviewed repair without changing
its source bytes or the task plan.

The Registry contamination walker previously visited dictionary values while
missing provider names in keys. The existing repair also visits keys; the
regression covers direct, nested and list-contained keys in trigger and
conditional predicates, including uppercase terms. No schema is changed.

| Published artifact | SHA-256 |
| --- | --- |
| `plugins/sdd-quality-loop/scripts/validate-capability-registry.py` | `843f473f1234572426d1a4b23e6a4cd03515dc214ae3b9b16590df7ed9f819c5` |
| `specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py` | `cb053e841ca41379ee7a0313e0132e9baca4efc05b66051a5f1fe143ff4793ca` |

Both hashes match the owner record
`reports/verification/issue423-t002-independent-codex-20261014.md` and the
earlier provider-key repair review. Those records remain local; this paragraph
is a derivative summary, not a replacement for their larger evidence closure.
The independent review was an explicitly authorized Codex exception outside
the formal identity ledger; no new reviewer reservation is claimed here.

Executed in the clean publication checkout on macOS:

- RED: copied only the existing regression to the unmodified publication base;
  `python3 -B specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py --repo-root .`
  ran 29 tests and exited 1 with 192 failing provider-key subcases.
- GREEN: after transferring the exact reviewed validator bytes, the same command
  ran 29 tests successfully, exit 0.
- `bash tests/validate-capability-registry.tests.sh`: 27 passed, 0 failed, exit 0.
- `pwsh -NoProfile -File tests/validate-capability-registry.tests.ps1`:
  27 passed, 0 failed, exit 0. This is PowerShell on macOS, not Windows evidence.
- An initial command used the nonexistent `tests/capability-registry.tests.sh`
  path and exited 127; the real suite paths above were then used.
- `git diff --check`: exit 0. The selected sources were checked for private
  owner paths, private-key headers and common credential-token patterns.

These results cover this repair on the publication base. The complete local
T-002 completion record, evidence bundle and later task transitions are not
published by this unit. No current-head CI, installer, full-task acceptance or
merge result is inferred from these local checks.

## T-003 implementation candidate

The second unit preserves the owner's existing selected-plan implementation as
a development candidate. It adds the canonical and packaged
`selected-verification-plan/v1` schema, evaluator, packaging registration and
focused tests, plus only the T-003 additions to the quality-gate caller and both
test runners. Unrelated launcher, ledger, identity and recovery changes in those
owner files are excluded. This checkpoint does not adopt an installed baseline.

| Exact source artifact | SHA-256 |
| --- | --- |
| `contracts/selected-verification-plan.schema.json` and matching packaged copy | `0da68ea6b5c880ee7db2dc0bf88e9ca4c31c01fe8d859dfb50c664eb8a2bd7fe` |
| `plugins/sdd-quality-loop/scripts/evaluate-selected-plan.py` | `3b882a53c72b8395992727ceab06b486e6a0f12284c7cbfa36820b3f3187a844` |
| `plugins/sdd-quality-loop/scripts/vendor-capability-registry.py` | `d5ee1d34c9fcd6cfd6deec47a80bfb01ea55263f34ef60fa1124f52df880b49b` |
| `tests/sdd-domain-multitarget-T-003.tests.py` | `69187b77ad54b2fed21099bf8dba38d5d1570f49814d5aef5767d33826074cd6` |
| `tests/registry-discovery.tests.sh` | `9597c9edda9bcb6e265816190009c3982f10e8ae6f9b03f682b92db3660a9478` |
| `tests/registry-discovery.tests.ps1` | `e144fccac70bc06dd96d071b0d48f3e8355d00f2cf53d568024377b1b3e317d3` |

Executed against these publication bytes, all exit 0:

- `python3 -B tests/sdd-domain-multitarget-T-003.tests.py`: 21 tests passed,
  including a standalone packaged layout. All verifier observations are synthetic.
- `python3 -B plugins/sdd-quality-loop/scripts/vendor-capability-registry.py --check`:
  canonical/package bytes match.
- `tests/registry-discovery.tests.sh` and `.ps1`: 21 passed each.
- `tests/generate-registry-digest.tests.sh` and `.ps1`: 17 passed each.
- `tests/facet-manifest-semantics.tests.sh` and `.ps1`: 15 passed each.
- Bash syntax for the changed Bash runners and PowerShell parser checks for
  the changed PowerShell runners passed; `git diff --check` passed.

PowerShell checks used `pwsh -NoProfile -File` on macOS. Full legacy/scenario
regressions, independent final-byte review, formal quality-gate, native Windows
and exact-head CI remain pending. In particular, the broad `gates.tests.sh`
suite was not invoked: its missing-runtime fixture temporarily removes its
live `check-contract.py`; later execution must remain isolated and serialized.
The focused suite's legacy controls are not a replacement for that full suite.

The owner's existing attempt10 report records historical preflight, RED/GREEN,
two corrective cycles and packaging evidence. It contains private local paths
and is retained locally rather than rewritten to look public or current. This
checkpoint neither recreates its manifest nor admits historical evidence into
a new gate. Required checks remain mandatory, unavailable/unexecuted required
checks block, and only originally optional unselected checks may be reasoned
N/A. Registry v1 supplies no conditional-gate definition to invent.

## Canonical owner observations and withheld units

Observed on 2026-10-16; counts describe local canonical plans, not public task
transitions. No task plan, approval, frozen specification or ledger was copied
by this checkpoint.

| Canonical plan | Local state | Publication boundary |
| --- | --- | --- |
| `specs/epic-195-a7-compatibility/tasks.md` | 3 Done, 6 Implementation Complete, 2 In Progress, 2 Planned | A separate bounded structural-test checkpoint is published below; T-004 YAML acceptance and normative/review evidence closure remain unresolved. |
| `specs/epic-196-a8-integration/tasks.md` | 1 Implementation Complete, 7 Planned | T-005 candidate and live-host proof are separate; several candidate paths differ on the existing remote branch, so whole-file replacement would overwrite remote work. |
| `specs/a9-interrupted-review-recovery/tasks.md` | 3 Approved / Planned | Protected baseline/read admission refusals remain unresolved. Its local branch is absent remotely; the existing A9 feature branch has later commits. Do not transplant approvals or replay refused repair commands. |
| `specs/sdd-domain-multitarget/tasks.md` | T-001/T-002 Done, T-003 In Progress, T-004..006 Planned; all Approved | This branch carries selected code candidates, not the local completion-evidence closure. |
| `specs/shared-review-launch-repair/tasks.md` | 5 Done | Production repair was already published separately; local snapshots, raw receipts, ledger and completion closure are not blanket-staged. |

A9 Dogfood as a whole is separate from its three recovery tasks; no whole-A9
task denominator is inferred. Local development-policy and AGENTS changes are
also withheld where mixed with shared freeze/guard contract changes. They must
not be silently replaced by another checkout's instructions.

## Cloud starting point

Start from `codex/issue423-boundary-checkpoint` and this checkpoint's final
commit. First inspect its exact diff, the approved six-task plan, governing
contracts and current local/public evidence boundary. The public plan retains
older Planned fields; do not infer that owner approval was missing or silently
mark the public copy Done from the local counts above.

The first cloud task is independent final-byte review and remaining isolated
regression preparation for T-003. Before formal lifecycle continuation, recover
the T-002 completion closure and attempt10 approved-policy/preflight provenance
through an authorized private handoff, or establish a new valid evidence path
without rewriting historical records. Fresh input admission must bind the
publication commit and exact changed bytes; old owner manifests are not current
merely because selected file hashes match. Keep the existing required-check
policy, reviewer independence and protected-application boundaries.

No cloud implementation session is launched by this publication. No merge,
production change, installation, signer operation or trust switch is authorized
or performed. This branch's test workflow runs on main pushes/PRs, so pushing
this feature checkpoint alone does not establish CI success.

## Final publication reconciliation

Remote heads were read back after the successful normal fast-forward pushes:

- #423 T-002 repair: `d6c098bf235975a2363d7a704615f7f965f79ba4`.
- #423 T-003 candidate: `0e8cb3babcffce3d4dc4751b455e5cbd1df79b80`.
- A7 candidate on `codex/a7-issue195-closeout`:
  `62e200dab02f680e23a3aaf05ee4fd7a6ba357b9`.
  [Exact bounded scope and evidence](https://github.com/aharada54914/sdd-forge/blob/62e200dab02f680e23a3aaf05ee4fd7a6ba357b9/reports/verification/a7-cloud-checkpoint-20261016.md).
  Its public-base suites passed 61 Bash and 68 PowerShell checks; F3/F5/F6
  remain SKIPs in that base. No owner 77/84 result is substituted.

An ordinary `git apply --check` of the A8 owner's selected eight-file delta
against remote `f525825e7a1ffb5021b80e3a0fbae20e36955d38` failed at four paths:
`plugins/sdd-quality-loop/scripts/check-installed-plugin-drift.ps1`,
`tests/fixtures/live-host-proof/run_cases.py`, and both
`tests/install-uninstall-matrix.tests.sh` / `.ps1`. These are concrete overlapping
remote changes, not a protection refusal. No three-way apply, merge, overwrite
or A8 push was attempted; the combined delta needs reconciliation and review.

All five original owners' HEADs and porcelain status digests matched the
pre-publication audit at final preservation check, and all selected source
hashes were stable. No index or task-state changes were made there. A private
local audit retains owner paths, status inventories, selected hashes and holds;
it is not a public evidence bundle or proof that old sessions were stopped.

At CI inspection, #423 candidate `0e8cb3ba` had no workflow runs; A7's exact
`62e200da` had a queued [pull-request test run](https://github.com/aharada54914/sdd-forge/actions/runs/38828095477).
Neither is recorded as CI PASS. This final reconciliation is documentation
only; executable and test bytes remain those validated above.
