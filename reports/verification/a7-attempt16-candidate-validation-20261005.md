# A7 attempt-16 failed-later-round recovery candidate validation

Nonfrozen candidate-only evidence. No owner review-gate source was patched, no
owner attempt-16 precheck was run, and no reviewer identity was reserved. The
temporary fixture transcript is local diagnostic input only; it must not be
published. This is not a formal specification-review verdict.

## Candidate and exact scope

`reports/verification/a7-attempt16-recovery-candidate-20261005/mechanical-integration.patch`
is mechanically generated from the four owner originals and temporary edited
copies. It changes `fresh-review-recovery.py`, `spec-review-precheck.sh`,
`spec-review-precheck.ps1`, and `spec-review-loop/SKILL.md`, and adds
`failed-last-attempt.py`: five target paths total. The new branch is opt-in via
`failed_final_round` and `failed_turn`; the existing no-output and
first-round partial forms remain unchanged. It returns earlier completed
NEEDS_WORK rounds for each caller's existing full contract validator. Existing
historical reservation validation remains in the wrapper.

The new failed-turn binding requires all five current input hashes, the
transcript path/hash, blocker hash, host session, and the exact
`prompt-truncated-before-role-manifest` diagnostic mode. It checks the actual
truncated first user input, missing-prompt answer, no reviewer output, no B
launch, and exact round inventory. This is narrow admission to a new review,
not a retrospective PASS or proof that the prior transition was legal.
For each historical round, both A and B invocation manifests are now checked
against the exact requirements, acceptance, calibration, optional investigation,
and precheck hashes recorded by that round's precheck; B must also bind that
round's integrated-summary bytes. Historical hashes are not compared with the
current specification bytes. This closes the independent audit's Major finding.

## Commands and observations

All commands were run from the owner checkout with `login:false` and `rtk
proxy`. The patch was applied only to isolated `/tmp` copies.

1. `python3 reports/verification/a7-attempt16-recovery-candidate-20261005/build-mechanical-patch.py /tmp/a7-failed-review-candidate.3oCV7K` — exit 0.
2. `git apply --check reports/verification/a7-attempt16-recovery-candidate-20261005/mechanical-integration.patch` — exit 0; no owner apply.
3. Isolated candidate Python `py_compile`, Bash `bash -n`, and PowerShell `Parser.ParseFile` — each exit 0.
4. `python3 /tmp/a7-failed-review-candidate.3oCV7K/fixture-root/specs/epic-195-a7-compatibility/verification/spec-review-fresh-recovery.fixture.py` — 24/24 PASS, Bash and PowerShell.
5. `python3 /tmp/a7-failed-review-candidate.3oCV7K/fixture-root/specs/epic-195-a7-compatibility/verification/spec-review-fresh-chain.fixture.py` — 32/32 PASS, Bash and PowerShell. These include unchanged normal-path PowerShell StrictMode behavior.
6. `python3 reports/verification/a7-attempt16-recovery-candidate-20261005/failed-last-attempt.fixture.py <local-a15r3-host-transcript>` — 18/18 PASS: one real-evidence-copy acceptance and seventeen negative cases. The six new negatives cover precheck-only, missing, extra, mismatched and duplicate manifest inputs, plus missing B summary. The incomplete-first-turn fixture repins the edited transcript and asserts rejection for absent `end_turn`, not an earlier hash mismatch.
7. `python3 reports/verification/a7-attempt16-recovery-candidate-20261005/full-caller.fixture.py /tmp/a7-failed-review-candidate.3oCV7K/fixture-root <local-a15r3-host-transcript>` — 4/4 PASS: Bash and PowerShell both admit isolated new attempt-16 round-1 precheck, and both reject changed blocker-hash binding. This fixture uses a synthetic authorization record only inside temporary copies; it does not claim or create real user approval.
8. `python3 reports/verification/a7-attempt16-recovery-candidate-20261005/human-apply.py --check` — exit 0, `READY`; no owner write. The apply script's fixed patch and new-helper hashes were updated to the post-audit candidate.

## SHA-256

| Artifact | SHA-256 |
|---|---|
| `mechanical-integration.patch` | `c618f47d1ebcbd66f7c1580a28e7583c8c4c3b5311faf8399555097efdc39fbd` |
| `failed-last-attempt.py.candidate` / new helper in temp | `f0172bcf8a5a4e1ae63741ab1566803075fc98ea782d2918469dbf5888cbf77a` |
| `failed-last-attempt.fixture.py` | `0e093b0a430b5c7ebad945549f8fb258c0430870cbe0ef66bd332817f7a16454` |
| `human-apply.py` | `d053e2c008b82b36a87df798742c2195bd1e47fbdad22ad7a509369eabf2a5f6` |
| `full-caller.fixture.py` | `c8ed80a2ca4e7a0cf20ace669064a6798b1f155a1389cea1f03dd3dfcad2a332` |
| candidate `fresh-review-recovery.py` in temp | `a276ae4fd2f8acb0bbe3e1898a6d53495cb113a300f3560f19e6d68e937478fc` |
| candidate `spec-review-precheck.sh` in temp | `0383b73b77cb9d0b9a0573c001f383b59cbafecb6283001231c6d6bd1ea11cf0` |
| candidate `spec-review-precheck.ps1` in temp | `1996a519da1063770b3593b4f21bfb5e94a3bc926acc9ceb8d002d233202fe51` |
| candidate `spec-review-loop/SKILL.md` in temp | `f11e6d93a45b3a43ac2b53075e50915d093bee24ce76e81b8f0591e3b6f5c323` |

Update 2026-10-05: the limited independent re-audit in
`a7-attempt16-recovery-reaudit-20261005.md` confirms resolution of the prior
Major and Minor findings and independently reruns 18 checks successfully.
This is not a whole-system security audit or formal SDD review.

Remaining: protected human application/readback, real attempt-16 admission,
and fresh independent A/B review. A subsequent read-only apply check still
returned READY (not applied). Do not use the fixture's synthetic authority or
raw transcript as public evidence.
