# Retained corrective preflight plan

Retained from the initial repair-report draft before final report replacement. This is a plan, not historical execution evidence. No product implementation was changed.


Recorded before any corrective product implementation (none planned). Every row
requires matched control, real disagreement and a sensitivity mutation; pending
entries below are a plan, not an execution claim. Probe code itself is evidence
instrumentation; no product implementation starts while this table is pending.

| Row | Persisted fields | Counterpart | Actual mismatch probe plan |
|---|---|---|---|
| R1 | Request digest; run/unit/provider/scope; owner; policy/profile/lock/config; assembly/source | verified closure, trusted policy, preview binding | byte changes for every bound ref; preview identity and pin disagreement |
| R2 | Change Set ARN/name, stack/account/region, parameters/capabilities, semantics/template | DescribeChangeSet/GetTemplate Original and create request | actual native wire substitutions plus semantic drift |
| R3 | S3 bucket/key/version/etag/hash/encryption/owner; template URL | owner-pinned destination, versioned GetObject | identity/header/body substitutions and URL/create binding |
| R4 | Execution RoleARN, failure settings, original create/execute token | protected Control, create/execute query and stack readback | create disagreements, failure-policy serializer rejection, token-event mismatch |
| R5 | Receipt/principal/stage/lease | live fixture GitHub/OIDC/STS and receipt issuer | approval/principal/lease/stage disagreement plus emitted receipt observation |
| R6 | NO_CHANGE preview/result, no deployment ID | native exact FAILED/no-change diagnosis and empty changes | genuine no-op control; each no-op predicate disagreement |
| R7 | Intent/submission identity/status/time/body hash; UNKNOWN | original ARN/token, durable history, native events | journal fields, wire hash and replay/unknown observations |
| R8 | Recovery authority/scope, original journal identity | provider/account/region/deployment/policy/unit trusted pins before reads | each trusted pin disagreement; no native read assertion |
| R9 | Trace digests, health false, result/state/exit | actual transport bytes and operation-result contract | observed trace bytes, health flag, state/exit and contract contradictions |
