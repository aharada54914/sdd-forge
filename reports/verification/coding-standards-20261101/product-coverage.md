# Product boundary review and test map

Reviewed integration `cc2006b5`. `context-review.json` binds reviewed checker and
guidance bytes to SHA256 and records all 30 rules, including non-applicable sinks
and the forced-timeout descendant cleanup limit. This is scoped implementation
review, not independent model adjudication or all-repository acceptance.

## Required checks and installed-project scope

`git diff 555bfb5f HEAD -- contracts plugins/sdd-quality-loop/contracts
plugins/sdd-lite/contracts` is empty. Guidance commit `17a7471a` adds no product
required check ID, task-state field or evidence schema. Repository native checks
are registered in `tests/verification-catalog.json`; the repository CI owns their
execution. Full check-contract, Lite discovery/capture and legacy track owners
are unchanged by that guidance.

Both relative coding-index links resolve in the source repository:
`implementation-policy.md` uses five parent steps from its references directory;
`verification-policy.md` uses three. Installed plugin layouts do not necessarily
contain repository `docs/`. The links are conditional on **sdd-forge source
development**, not an installed-project prerequisite. Installed projects use
their own adopted rules/configuration. A native model following that conditional
correctly has not been demonstrated here; source link validity is not host proof.

## Precise controls and evidence boundaries

| Requirement | Existing control | What it establishes |
| --- | --- | --- |
| Full required set retained | `tests/gates.tests.sh`, T-003.2–T-003.8 | Real check-contract accepts complete risk sets and rejects missing mandatory checks. Prior `gates-final.log`: 163/0. |
| Non-code rules do not become new gates | Same suite T-012.1–T-012.5 | Existing `stack: docs` compile-check waivers retain reason requirements and remaining checks; this does not prove model interpretation of non-code prose. |
| Legacy remains supported | Same suite T-004.1 | Real legacy contract without risk/required_workflow retains existing red/green treatment. |
| Lite actual discovery/invocation/capture | `tests/lite-gate-cli-chain.tests.sh` | Executes real POSIX children, captures stdout/stderr and exit7, tests timeout0.1, full-upgrade refusal, duplicate selection and missing explicit check. Prior `python-lite-cli.log`: 8/0. |
| Registry-required missing check cannot be N/A | `tests/lite-gate-summary-consumption.tests.sh`, TEST-016a/b | Simulation harness calls discovery and asserts FAIL for undiscoverable/invalid IDs. Corrected `python-lite-summary-final.log`: 15/0; earlier 6/9 failure logs are not successful evidence. |
| Missing active summary differs from disabled legacy | `tests/lite-gate-summary-absent-active-enforcement.tests.sh`, TEST-030a/b/c | Existing deterministic simulation covers required/advisory absence versus disabled legacy; no new execution run claimed in this review. |
| Project-skill PASS does not replace obligations | `tests/project-skill-observation.tests.py`, `test_task_projection_preserves_obligations`, `test_trial_never_projects` | Existing producer/consumer assertions preserve obligations and prevent trial projection; no model-independent review claim. |
| Default report cannot certify Done | `tests/template-validator-parity.tests.sh`, new default Lite report checks | Research owner exercised real task-state consumer: untouched FAIL/NOT_RUN default rejected, completed PASS report accepted. Source fix and run evidence owned by research. |
| Missing or unadopted coding standards | New guidance's explicit scope plus unchanged executable contracts | No runtime rule discovery dependency added. Actual model adherence in an installed project remains unverified, not PASS. |
| Native missing tool/config/history/timeout | `tests/coding-standards.tests.py` named fail-closed controls | Unit fault injection verifies error separation; native positive/negative controls and heldout evidence separately exercise real tools. |

All tool/code test results above are bounded to their named suites. A simulation
is not actual host invocation; a source assertion is not a behavioral model trial.
The new instructions do not relax existing missing-baseline-command policy: no
new analyzer is forced merely because rules are absent, while existing Full/Lite
required checks and review requirements still apply.

The root integration owns final CI, source changes after this snapshot, final
census/mirrors and actual OS/host coverage. #687/#692 acceptance must still account
for those results and the explicitly unverified behavior above.
