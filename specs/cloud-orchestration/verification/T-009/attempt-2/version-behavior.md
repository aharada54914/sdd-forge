# Exact version behavior, T-009 attempt 2

Raw old/new subprocess outputs, commands, exits and legacy required sets are
bound in version-comparison.json (before: original boundary-probes.json;
after: versions.log). No old-version behavior is inferred from a new schema.

| Input | Original entry | Final candidate |
|---|---|---|
| absent schema | legacy success for matched controls | same |
| verification-contract/v2 | legacy success for matched controls | same required flags/check sets |
| verification-contract/v1 | unsupported | unsupported |
| verification-contract/v999 | unsupported | unsupported |
| cloud-verification/v1 as legacy input | rejected | rejected |
| v2 arbitrary unknown non-cloud field | ignored historically | unchanged, not falsely described as strict legacy rejection |
| v2 reserved profile discriminator | ignored historically | explicitly rejected; original executed Red cba7a7ad |
| verification-contract/v3 without cloud fields | unsupported version | explicit branch, closed-schema rejection |
| v3 valid saved cloud contract | unsupported version | selection succeeds; overall BLOCKED, no saved provenance authority |
| v3 unknown/miscased field or version | unsupported version | rejected before selection |
| selected-verification-plan/v1 | legacy only | old root/package schema bytes unchanged |
| selected-verification-plan/v2 | absent | explicit cloud output with schema and independently recomputed equality |
| reserved cloud-compute version 1 | legacy reducer | preserved, executed dedicated matched control |
| reserved cloud-compute version 2 | no protected profile | fixed IaC/policy/preview + resource/network/identity/monitoring/workload; backup mandatory when policy requires, otherwise profile may explicitly include it |
| reserved cloud-compute unknown version | accepted by former reducer | protected allowlist rejects; original executed Red cba7a7ad |
| saved synthetic or native-looking labels | not authority | always BLOCKED overall |
| fresh synthetic transport | incomplete evidence | selected but BLOCKED |
| existing fresh authenticated collector | T006 trust boundary | only positive cloud route; actual in-process path tested with synthetic native-class protocol doubles, NOT live IAM/provider proof |

All four direct consumers execute old/current/unknown cases: Python, POSIX,
PowerShell and selected-plan CLI. Valid v3 and selection negatives execute in
ProfileSavedConsumers. Fresh positive and mandatory failure/unavailable checks
execute both provider paths. Mismatch audit logs each executed subtest.

Legacy constants are equal to original baseline/risk tiers/stacks. No compile
waiver, code/shell/docs/spec test obligation, TDD evidence or required flag was
relaxed. Cloud never invents unit/TDD observations. New schemas remain closed.
Runtime cloud imports remain lazy and confined to v3; legacy AST 3.6 syntax and
import isolation pass, but no real Python 3.6 binary was available/executed.
Actual Linux PowerShell is exercised; native Windows remains untested.
