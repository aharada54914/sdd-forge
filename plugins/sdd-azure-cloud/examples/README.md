# Private VM Bicep example — local compilation only

`private-vm.bicep` has no public IP, inbound allow rule, password auth or role
assignment. It creates a new private NIC/VM, a user-assigned-identity AMA agent,
DCR association and backup protected item. Subnet, identity, versioned gallery
image, DCR and vault policy already exist; no network/identity is imported.

All 11 parameters are explicit, without live subscription/SKU/image/network/
backup/budget/profile defaults. The source selects a new Standard_LRS OS disk
with Detach deletion behavior; an owner must include storage and retention costs
in the estimate. The example is not a live-approved scope or price quote.

Before local use, provide the strict shared request/context/ownership/policy/
profile/lock and full provider config described in
[local-contract.md](../references/local-contract.md). Precreate the declared
private evidence and generated directories. Set physical `CLOUD_WORKSPACE_ROOT`
and the verified `CLOUD_BICEP_BIN` explicitly. No cloud login is needed.

```text
python3 <plugin>/scripts/cloud.py route --request <draft-request.json> --output <run-evidence>/route.json
python3 <plugin>/scripts/cloud.py plan --request <draft-request.json> --output <run-evidence>/plan.json
python3 <plugin>/scripts/cloud.py validate --request <locked-request-from-plan-manifest> --output <run-evidence>/validate.json
```

The task's attempt-2 verification addendum contains actual example and independently
varied modular CLI runs, complete **synthetic-target** inputs and exact compiled
ARM bytes. They demonstrate local compile/policy checks, not approved live IDs.
Replace every synthetic value with owner-supplied data; do not execute them in
Azure. The CLI deliberately blocks prepare/apply/reconcile/observe/verify.

Compilation can also be inspected without any deployment command:

```text
<verified-bicep> build <plugin>/examples/private-vm.bicep --no-restore --stdout
```

Effective subnet ingress/egress, private management connectivity, actual identity
privileges, received monitoring signals, workload health and backup recovery must
be checked later with owner-approved profiles and separate authorization. Missing
live values remain blockers; a local PASS or release tag is not that evidence.

## Current operator workflow

Use the repository installer with explicit cloud plugin selection; the bare
marketplace source has no generated shared runtime. All invocation examples
require an explicit trusted CLOUD_SHARED_RUNTIME_ROOT. The full operator guide
(`docs/cloud-orchestration.md` in the repository) supplies strict request fields,
credential-free plan/validate commands, official Linux x64 tool acquisition and
separate protected prepare/apply/verify setup. No example scope grants authority.
CREATE physical IDs/recovery points come from original native deployment resources,
not fabricated predeployment values or later edits to locked requests.

For a small local route-only fixture, run the repository's
`plugins/sdd-azure-cloud/examples/local-route-example.py NEW_PHYSICAL_DIRECTORY`
(with `--provider aws` for AWS). This is synthetic discovery, not compilation
or a complete deployment example. Full native compile/synth inputs remain the
strict provider configuration and source fixture described above.
