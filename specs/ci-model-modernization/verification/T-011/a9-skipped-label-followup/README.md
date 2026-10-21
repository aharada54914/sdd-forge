# Inactive A9 skipped-job labels and failed-baseline diagnosis

The observed hosted job was completed/skipped with no assigned runner and no executed steps, while retaining its workflow-requested `ubuntu-latest` label. The original collector incorrectly required an empty label list. The narrow candidate permits empty labels or exactly the declared requested runner label; unknown/additional/duplicate/non-list labels, assigned runners, executed steps and active-advisory skips remain rejected.

Failing regression tests were committed first at `08d45e4fa821cb3bbb335dd1786eea30dc2429e8`. Original Red has two positive-subcase failures while negative controls pass. Candidate full suite passes82 with0skips; original frozen collector rollback reproduces the same two positive failures and keeps negatives passing. `report.json` and `preflight.json` retain original command/proof scope and source pins. `root-static-observation.json` is an explicitly labeled transcription of Root’s actual exec tool result chunk: Ruff and mypy on both files pass with combined exit0. It is not a separately captured process log.

The original real B run39615251761 is **completed/failure** at `6c2b4e7139158674dfaa1148c009db7da261706f`. Its original M run39615327268 is **completed/cancelled**. B has30successful/15failed/1skipped jobs; M has14successful/6failed/24cancelled/1skipped. The sanitized final status files retain only run/job identifiers, names, revisions, public timestamps/status and original API-file hashes. Raw actor/account fields, URLs, headers, collection inputs and ZIPs remain outside Git.

Diagnostic replay of unchanged B observations with the corrected collector remains **FAIL/execution-failed**:138verified,1advisory-inactive and310execution-failed obligations. Those counts are collector obligation classifications, not GitHub job counts. Counterfactual replay is not baseline acceptance, mutation success, or permission to activate a category. A fresh exact-commit full baseline and subsequent rollout proof remain required.

The transport adapter is unchanged. Future manifests must pin corrected collector SHA `2705fb54c1cdaf5a0bfcadffe700153e401f0be240db40293dd60e9a72ddb6c1`. `original-collection-pins.json` preserves the old collector/report/trace hashes without rewriting historical controller records.

Public logs use LF, strip trailing ASCII spaces/tabs and redundant final blank lines, and retain one final LF when nonempty. Exact original external and published hashes are disclosed in `evidence-receipt.json`. Source patch uses zero context. No ordinary source/index edits, staging, commit or tests are performed by this curation.

Root’s pre-rebaseline workflow gate exited0; `pre-rebaseline-workflow.log` retains its historical amendment warnings and final workflow-state OK. The receipt records the command and tool environment scope. This is a workflow-state gate, not completed replacement CI.
