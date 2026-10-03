# T-010 current-head implementation validation (2026-10-04)

This is a new, isolated implementation validation of commit
`84a3b65db45b42292d6f9c0bd21cb78625564b2a`. It is not the historical
implementation session, an independent quality-gate verdict, or a Done claim.
The host-issued scratch identifier for this validation is
`a7-t010-validation.zSInQiWV` (under the local temporary directory); it is
not evaluator scratch. Its absolute host path is local-only, not a public
artifact reference.

## Frozen input manifest before test execution

The following SHA-256 values were measured from the checkout before this
validation's tests. The canonical T-010 report has a concurrent owner edit;
this addendum does not claim that report as an input or change it.

| Repository-relative path | SHA-256 |
|---|---|
| `specs/epic-195-a7-compatibility/tasks.md` | `6c7f4f3599eff30a2b21eebbeb7c9d593447afe61cad1887faab17cbb6b76471` |
| `specs/epic-195-a7-compatibility/requirements.md` | `7af43a41f52d7fee4144ea603eba10cd5fe9ccf6468bcfe778afd212546f5a79` |
| `specs/epic-195-a7-compatibility/design.md` | `ef0a43714f623e92ba7b5e2a583a53bc7dbcd4b8e2481b0df2aa96cef2fa2c96` |
| `specs/epic-195-a7-compatibility/acceptance-tests.md` | `f77158ea4ad4263910439cd37ca0ed5296fc3f4e29e1d4e8c963d659ed799815` |
| `specs/epic-195-a7-compatibility/traceability.md` | `676d2e3de2c0e311b1aa796dd4a7b21950e5ac47a030dd0fba3611617805cd31` |
| `specs/epic-195-a7-compatibility/security-spec.md` | `4b31d724cd326ee89b87de867e0f857cf2b7ca69d794956ebb7ce4edc6ff8d31` |
| `tests/fixtures/skip-allowlist-manifest.json` | `5fa86d71e1e4a6667ecb2f668fb730eea09010c6d2cc7cafaba21ac4d29e5530` |
| `tests/lib/skip-allowlist-evaluator.sh` | `3e2430559547b6a06c27e19e70ac7003acb99924004c2a0ba259ef46e1c28b87` |
| `tests/lib/skip-allowlist-evaluator.ps1` | `6daae2e88a65ca7fd1b9f215f93e869215d21ee82380101cc69b5245229a1197` |
| `tests/skip-allowlist-manifest.tests.sh` | `c357c87c92c63e11acb59c1a0d5e0ef3b6365e2719a84c8c88a710f603fb7ddd` |
| `tests/skip-allowlist-manifest.tests.ps1` | `ac86327e8e4b43a2f3eeffa579cd91b1168dc77a8eb9eb871a325304f7bba586` |
| `tests/loop-consistency.tests.sh` | `15c8a87ed706a7c1476fde5695e5a7720498d9f34f8903c9fbe3ce4dcd3b7ba1` |
| `tests/loop-escalation.tests.sh` | `29793d24a93e27c193bfe82cfe89cf93adb2b9dd7e951e173a8fe1b1ed893111` |
| `tests/compatibility-byte-identical.tests.sh` | `eff2a7e26bf46db943d834b9188da5d6cac47076e794593add6a28ff6635ac62` |
| `tests/structural-compatibility.tests.sh` | `03c99523c8eedcb3caa5010f9f00ab48c1b9cb9efdef74904b28f729afc82fda` |
| `tests/structural-compatibility.tests.ps1` | `45de3d896127c43a6d1c89af365bf39a4ae3f38c04848f1cfede749ab02a4f2a` |
| `tests/run-all.sh` | `5af4435a91487ce2b7e825677b86966bfc5bc6f952e2dfabf7920b12dfb52dd5` |
| `tests/run-all.ps1` | `57ec5e6657afb475b93bae4f998d7c2a5fdb0df8df9ff6be25e24bc19016ad20` |

## Measured checks

All counts below are from this validation on the current checkout. These are
not the original implementation session's tests or an independent review.

| Check | Bash exit/result | PowerShell exit/result |
|---|---|---|
| Manifest suite after bounded repair | 0; 29 passed, 0 failed | 0; 32 passed, 0 failed |
| Zero-SKIP fingerprint and fail-closed cases | 0; 7 passed, 0 failed | 0; 7 passed, 0 failed |
| Structural compatibility | 0; 61 passed, 0 failed | 0; 68 passed, 0 failed |
| Byte-identical compatibility | 0; 25 passed, 0 failed | 0; 25 passed, 0 failed |
| Loop escalation | 0; 37 passed, 0 failed | 0; 36 passed, 0 failed |
| Loop consistency | 0; 34 passed, 0 failed | 0; 38 passed, 0 failed |

The shipped manifest suite also exercises the dependency-present,
unrecognized-SKIP, and merged-fingerprint-drift native negative controls;
each hard-failed as expected in both runtimes. The clean fixture audited one
real allowlisted line in both runtimes. The matching-merged and unmerged
zero-line controls returned exit 0 and `audited 0 allowlisted lines`; the
merged-drift zero-line fixture returned exit 1 with the dependency drift
diagnostic. Invalid merge evidence and unreadable manifests returned nonzero.

The Bash and PowerShell aggregate `run-all` attempts were interrupted (exit
130) before completion, so no aggregate pass is claimed. The Bash aggregate
had reached `adversarial-review-contracts.tests.sh`, which failed because the
checkout lacked the lockfile-pinned Ajv installation. No dependency install
or production Gemini request was made in this validation. These aggregate
attempts do not establish a T-010 defect or a green full suite.

`git diff --check` and `bash -n` of the two changed Bash files both exited 0.
The current implementation changes only the two evaluator files and their
two manifest suites. The canonical implementation report, task status, and
frozen specification inputs remain under their existing owners and were not
edited by this validation.

## High-risk preflight for the bounded audit repair

Recorded before editing the evaluator or its suites. This repair concerns
merged fingerprints even when an output has zero allowlisted lines; it does
not change the frozen task or design artifacts.

| Persisted evidence field | Sibling contract / traceability counterpart | Failing mismatch test before implementation |
|---|---|---|
| `audit` process exit and `ERROR: AC-900 dependency A9 fingerprint drift` diagnostic | REQ-007 / AC-035c; security B4; T-010 Done When merged-drift hard failure | Both runtime suites' `merged-fingerprint-mismatch` fixture with output containing no SKIP line must return exit 1 with exact drift diagnostic; current evaluator instead exits 0 and says `audited 0 allowlisted lines`. |
| `audit` success and `audited 0 allowlisted lines` for a matching merged fingerprint | REQ-007 / AC-034 and AC-035c distinction between valid evidence and drift | Both runtime suites' `merged-fingerprint-match` fixture with no SKIP line must remain exit 0 and contain the exact zero-line audit count. |
| `audit` success and `audited 0 allowlisted lines` for an unmerged dependency | REQ-007 / AC-016 named degradation until merge | Both runtime suites' `unmerged` fixture with no SKIP line must remain exit 0 and contain the exact zero-line audit count. |

The three fixture cases are independent of the existing SKIP-shaped-line
checks. The first must be visibly RED at the current commit before evaluator
changes; the latter two prevent an overbroad fail-closed fix.

### Fresh RED (current evaluator, new tests, before evaluator edit)

| Command | Process exit | Exact result |
|---|---:|---|
| `bash tests/skip-allowlist-manifest.tests.sh --case=zero-skip-fingerprints` | 1 | `FAIL: AC-035c merged fingerprint drift hard-fails with zero SKIP lines (exit 0; audited 0 allowlisted lines)`; matching-merged and unmerged controls PASS; `2 passed, 1 failed` |
| `pwsh -NoLogo -NoProfile -File tests/skip-allowlist-manifest.tests.ps1 -Case zero-skip-fingerprints` | 1 | `FAIL: AC-035c merged fingerprint drift hard-fails with zero SKIP lines`; matching-merged and unmerged controls PASS; `2 passed, 1 failed` |

This RED is newly measured against the current evaluator, not a claim about
the original T-010 implementation sequence or a substitute for its historical
RED evidence.

### Additional fail-closed RED and GREEN

The scan now validates each manifest entry's dependency list before concluding
that zero SKIP lines are safe. Before the final PowerShell guard, the empty-
and missing-dependencies fixtures produced exit 1 for the suite with `5
passed, 2 failed`: each audit incorrectly returned success. The Bash
evaluator already rejected both shapes (`7 passed, 0 failed`). After the
PowerShell guard, the complete suites passed as recorded above. This is
limited audit-read validation, not a replacement for the manifest's full
schema validator.

## Open contract and provenance boundaries

The frozen `design.md` fixed the A5 source window at `1886-1915` and digest
`sha256:9b549...`, and specifies merged/fingerprint activation at the cited
AC-004/AC-021 sites. The checked-in manifest instead has A5 window
`2139-2179`, digest `sha256:1bf6...`, and an additional
`executable_contains(...)` activation predicate. The existing T-010
reconciliation addendum did not establish an approved supersession for this
design difference. No frozen artifact or manifest was changed here; the
parent must resolve the specification/provenance boundary before an
Implementation Complete claim.

The only actual host-issued identifier obtained for this session is the
temporary scratch basename above. The agent routing name is
`/root/other_pr_readiness/a7_t010_fresh_validation`; a separate host-issued
Run ID, Session ID, and Agent Instance ID were not exposed to this agent.
No identity value has been invented or retroactively attributed to the
historical implementation. This addendum cannot substitute for a complete
canonical v2 implementation report or the later quality gate.
