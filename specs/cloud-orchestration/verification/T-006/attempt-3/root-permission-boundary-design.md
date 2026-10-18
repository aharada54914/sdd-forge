# Azure observation permission boundary: implementation guidance

2026-10-18. Root design reasoning using the local Codex-adapted pstack-architect
procedure. This is not an independent review, a live acceptance result, a
permission grant, or an amendment to the frozen specifications.

Desired caller behavior remains `verify` of the original immutable approved
unit request. The governed collector authenticates the principal and performs
fixed read-only native queries, then emits the existing collection context,
observations and verification envelope. Missing, incomplete or unsupported
permission evidence blocks verification. A saved result cannot authorize it.

The frozen design's observation section requires effective least-privilege
identity, bound to the target and original operation. Existing request scope,
protected target policy, provider observation configuration and native resource
identity checks define the governed scope. There is no requirement for a new
cross-tenant general IAM interpreter.

| Shape considered | Evidence and limitation | Decision |
|---|---|---|
| Query permissions only on a few selected resources | Confirms those queries but can miss other effective grants within the governed subscription | Insufficient as complete scoped proof |
| General IAM evaluation across arbitrary tenants, resource types and policy languages | Large new public surface; no admitted complete native semantics or requirement | Outside this implementation |
| Bounded native assignment and role-definition closure for the declared subscription, plus actual permissions at the selected resources | Can explicitly restrict supported scopes/actions and reject groups, conditions, wildcards, missing pages and drift; relies on native service consistency | Chosen supported direction, subject to actual implementation/tests/review |

Use existing provider collector methods and shared context/reducer contracts.
Do not add an executable query language or an authority-bearing local assertion.
Official source snapshots and acquisition hashes are under
`attempt-2/api/azure-identity-closure/`; current attempt must admit any additional
sources before using them. The assignedTo and scope enumeration descriptions
are API research, not proof that candidate code implements the semantics.

A positive supported path must be internally feasible: every required read must
have an explicitly documented owner-provided read permission, and the declared
permission ceiling must account for those reads. No real role grants or policy
changes occur in this task. Metadata reads needed for a scoped audit do not
justify resource write privileges. Actual caller-permissions readback must
agree with the enumerated direct grants. Incomplete or changing enumeration
must block; a repeated read is a bounded stability check, not an atomic snapshot.

Managed-identity group/role caching is documented by the provider. Fresh
assignment enumeration is not evidence of instant revocation of cached tokens.
Reject unsupported group/conditional contexts and document the supported
operational prerequisites and consistency limits without a universal or live
least-privilege claim. Native positive verification must replace the temporary
unconditional Azure quarantine with real supported checks, not merely remove it.
Live TEST-003/005/009 remain blocked by the absent sandbox separately.
