# T-009 old/new version behavior at handoff

This records the incomplete candidate, not an acceptance verdict. Exact baseline
commands, check sets and exit codes are in boundary-probes.json; source hashes
are in consumer-reference-inventory.json and owned-change-inventory.json.

| Input | Before | Candidate behavior / evidence |
|---|---|---|
| absent contract schema | legacy path accepts matched controls | unchanged sets; selected-plan/gates regressions pass |
| verification-contract/v2 | legacy path accepts matched controls | unchanged checks/required flags; gates regressions pass |
| verification-contract/v1 | rejected | remains unsupported |
| verification-contract/v3 | rejected | explicit profile=cloud only; closed schema; check-contract CLI blocks overall success for saved-only provenance |
| verification-contract/v999 | rejected | remains unsupported |
| legacy version plus profile | unknown field ignored in baseline | explicit reserved profile discriminator rejected; executed Red then Green |
| legacy other unknown fields | legacy historical handling | not globally tightened; no claim legacy parser rejects all unknown fields |
| v3 missing/unknown/type-invalid fields | version rejected before candidate | strict saved_profile_plan field/type/reference checks; executed mutation matrix |
| selected-verification-plan/v1 | legacy output/schema | unchanged source and packaged schema |
| selected-verification-plan/v2 | absent | new cloud-only output; selected CLI positive selection but BLOCKED provenance verdict |
| cloud-verification-profile/v1 arbitrary legacy id/version | existing T006 reducer | unchanged unless reserved cloud-compute id/non1 version |
| cloud-compute version 1 | existing reducer | preserved old path by explicit non1 branch; final dedicated v1 coverage needs audit |
| cloud-compute version 2 | no protected dispatch | explicit protected allowlist, IaC/policy/preview and provider checks; mandatory backup conditional only on protected policy |
| cloud-compute version 999 | previously accepted by reducer | rejects at protected allowlist; actual Red/Green assertion |
| saved native-looking JSON | no profile selector | never establishes native provenance; selected BLOCKED |
| synthetic fresh collector | T006 incomplete evidence | selected cloud checks but BLOCKED |
| existing authenticated in-process collector | T006 reducer authority | explicit profile checks alongside real executor checks and original preview native bindings; positive path tested with native-class protocol doubles only |

Direct exercised consumers: Python check-contract, POSIX check-contract wrapper,
PowerShell check-contract, evaluate-selected-plan CLI, reducer and both public
provider observe paths. Detailed consumer/projection inventory is
consumer-inventory.md. Vendor and guard projections came from existing generators.
New PowerShell discovery/miscase test edits need a final-byte rerun and separate
case-sensitivity sweeps. Legacy stdlib/Python 3.6 path is not made dependent on
cloud runtime imports; cloud branch alone requires Python >=3.10. Actual 3.6
runtime and native Windows execution remain unverified.
