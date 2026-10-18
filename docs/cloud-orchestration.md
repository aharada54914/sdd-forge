# Azure / AWS cloud orchestration

Two **opt-in** adapters implement one Azure Bicep or AWS CDK/CloudFormation unit
at a time. They are not a generic IaC engine or a resident cloud service.
Local preparation, protected writes and authenticated observation are different
trust boundaries. A local PASS, native model invocation or release tag is **not**
live deployment acceptance or production readiness. Live TEST-003/005/009 and
affected task Done remain BLOCKED until the owner supplies a sandbox.

## Install and platform boundary

From a reviewed repository checkout (replace paths explicitly):

```sh
bash install.sh --source-directory "$PWD" --target Codex --plugins sdd-azure-cloud,sdd-aws-cloud
```

PowerShell installer equivalent (installation/registration, not native Windows cloud execution):

```powershell
./install.ps1 -SourceDirectory $PWD -Target Codex -Plugins sdd-azure-cloud,sdd-aws-cloud
```

The default selection remains `sdd-bootstrap,sdd-ship` plus their dependencies.
Cloud selection adds `sdd-quality-loop` and materializes `cloud_contracts.py`,
`cloud_authorization.py`, `cloud_verification.py`, `cloud_dependencies.py`, schemas
and protected registry under each provider's `runtime/` **before** registration.
A bare remote marketplace provider entry/source directory lacks that generated
runtime: use the repository installer, not marketplace-only installation.

Subsequent default/different-plugin updates regenerate selected **or previously
materialized** cloud runtimes from the new trusted staged source before replacing
the installation. Unselected providers are not newly registered. Missing required
staged entry files fail while preserving the old install. If an older broken
installation already lost `runtime/`, explicitly select that provider again;
there is no registration-discovery database. Partial uninstall retains shared
files/dependencies; full uninstall removes the install root unless KeepFiles.

Resolve `PLUGIN_ROOT` from the installed skill's own trusted location. Every
installed or independently versioned host-cache invocation must set
`CLOUD_SHARED_RUNTIME_ROOT="$PLUGIN_ROOT/runtime/scripts"`; never discover runtime
code in the deployment workspace, /tmp or ambient PYTHONPATH. Reviewed source
checkouts can explicitly use `plugins/sdd-quality-loop/scripts` instead.

Provider CLI needs Python 3.11+, physical absolute POSIX roots, no-follow/dir-fd
and exclusive publication primitives. Current executable tool pins are **Linux
x64**. macOS needs reviewed native tool pins even though POSIX safety fixtures
run there. Native Windows roots return `UNSAFE_ROOT`; shared primitives can
return `UNSUPPORTED_FILESYSTEM`. Native Windows installer/PowerShell guard and
schema/reducer tests are not provider-execution support. WSL must independently
meet Linux pins and physical POSIX filesystem requirements; NTFS paths are not
made safe by choosing a different shell. Native Windows junction coverage is a
separate CI obligation, not proved on Linux.

## Public entry and immutable request

`/sdd-azure-cloud:orchestrate` and `/sdd-aws-cloud:orchestrate` collect explicit
inputs and delegate the same canonical request used by bootstrap's
`cloud-routing.py` helper. They never infer cloud authorization.

```sh
CLOUD_WORKSPACE_ROOT="$WORKSPACE_ROOT" \
CLOUD_SHARED_RUNTIME_ROOT="$PLUGIN_ROOT/runtime/scripts" \
python3 -B "$PLUGIN_ROOT/scripts/cloud.py" route --request "$REQUEST" --output "$OUTPUT"
```

The eight exact phases are `route`, `plan`, `validate`, `prepare`, `apply`,
`reconcile`, `observe`, `verify`. Only `--request` and `--output` are public flags;
there is no `--approve`, `--dry-run`, implicit bootstrap or deploy/hotswap command.
`OUTPUT` must be new within the request's evidence directory. JSON goes to
stdout; diagnostics to stderr. Exits: 0 PASS/NO_CHANGE, 2 BLOCKED, 1 FAIL,
3 UNKNOWN. Invalid identity produces `cloud-input-error/v1`, not a fabricated
run receipt. Valid identity uses `cloud-operation-result/v1` with run/unit,
provider/phase/state/result/error, input manifest and evidence locator.

Authoritative closed shapes are [cloud contracts](../contracts/cloud-run-request.schema.json)
and the provider config schemas linked below. Unknown fields/versions, duplicate
keys, NaN, invalid UTC, mismatched digest or unsafe path are rejected. Digests
are lowercase SHA-256 of **exact bytes**, not semantic JSON equality. Paths are
canonical relative paths inside the explicit workspace/artifact root: no dot or
parent segments, absolute/drive paths, links, alias or overwrite. Precreate
private evidence/generated directories and prevent concurrent file replacement.

| Input | Exact shape / constraint |
|---|---|
| Request | `schema: cloud-run-request/v1`, `run_id`, `unit_id`, `provider`, `binding_id`, `environment`, `scope`, `owner`, `route`, `operation`, `source_revision`, `input_artifacts`, `dependency_lock`, `policy`, `verification_profile`, `predecessor_receipts`; local phases additionally require `local_context` |
| Scope | `account_id`, `region`, `deployment_scope` (subscription/resource group for Azure; account/stack for AWS); explicitly owner-selected, not inferred credentials |
| Routing | Azure `owner: bicep`, `route: azure-bicep`; AWS `owner: cdk`, `route: aws-cdk`. Discovery may use request operation `route` and null route. Plan requests keep original operation `apply`; CLI phase is separate, never rewrite locked request between phases |
| References | `{path, sha256}`; input artifacts additionally `kind` in source/compiled/asset/parameters/module; profile additionally `id`, `version`; source_revision is exact 40-hex commit |
| Local context | `workspace_anchor: CLOUD_WORKSPACE_ROOT`, `artifact_root`, `unit_roots`, `evidence_directory`, `feature`, `task_id`, `ownership`, `provider_config` |
| Evidence directory | Exactly `specs/<feature>/verification/<task>/cloud/<run>/<unit>`, disjoint from inputs; outputs cannot replace request or prior evidence |
| Ownership | `schema: cloud-ownership/v1`, `owners: [{owner, root}]`, `existing_resources: [{resource_id, owner, attachments: [{resource_type, name}]}]`; recursively scanned files must agree with inventory |
| Deployment policy | `schema: cloud-deployment-policy/v1`, `allowed_scopes`, `allowed_resource_types`, `backup_required`, `private_networking`, `budget: {ceiling_minor_units, currency}`, `evidence: {residency, retention_days, access: restricted}` |
| Profile | `schema: cloud-verification-profile/v1`, `id`, `version`, `required_check_ids`, `max_age_seconds`; governed selection is `cloud-compute` version `2`, verification-contract/v3 and selected-verification-plan/v2 |
| Lock | `schema: cloud-dependency-lock/v1`, `adapter_version`, `upstream` repository/commit/root/files with transitive references, `tools` name/version/sha256, `managed_endpoints` endpoint/tool_schema; no floating executable dependencies |

Exactly one supported owner is required. Terraform, SAM, azd, raw CloudFormation,
mixed/conflicting owners, import and migration are detected but **not executed**.
Existing resources keep their real owners and IDs. Only explicit additive
attachments to references are permitted, not mutations of those objects/parents.
Unknown resource graphs or asset kinds block rather than silently disappear.

## Credential-free local examples

[Azure local contract](../plugins/sdd-azure-cloud/references/local-contract.md),
[private VM example](../plugins/sdd-azure-cloud/examples/README.md),
[AWS local contract](../plugins/sdd-aws-cloud/references/local-preparation.md) and
[private EC2 example](../plugins/sdd-aws-cloud/examples/private-ec2/README.md)
list the full provider fields and bounded policy subsets. For a small executable
**synthetic routing-only** demonstration with real hashes and no credentials:

```sh
# Reviewed checkout; use a new absolute physical directory for each provider.
python3 plugins/sdd-azure-cloud/examples/local-route-example.py /tmp/cloud-route-azure
CLOUD_WORKSPACE_ROOT=/tmp/cloud-route-azure \
CLOUD_SHARED_RUNTIME_ROOT="$PWD/plugins/sdd-quality-loop/scripts" \
python3 -B plugins/sdd-azure-cloud/scripts/cloud.py route \
  --request /tmp/cloud-route-azure/request.json \
  --output specs/cloud-example/verification/T-001/cloud/example-run/example-unit/route.json
```

The generator supports `--provider aws` for a separate `/tmp/cloud-route-aws`
workspace; invoke `plugins/sdd-aws-cloud/scripts/cloud.py` against it. Its invented
scope, source revision, price ceiling and tool digest are clearly synthetic and
cannot pass real compilation or authorize deployment. Do not use them as live defaults.
On systems where /tmp is a symlink choose a physical directory instead.

For real planning, collect **all** owner values, use the shipped pinned upstream
closure and tool locks, and review source before executing it:

```sh
CLOUD_WORKSPACE_ROOT="$WORKSPACE_ROOT" CLOUD_SHARED_RUNTIME_ROOT="$SHARED_RUNTIME" \
CLOUD_BICEP_BIN="$BICEP_BIN" \
python3 -B "$AZURE_PLUGIN/scripts/cloud.py" plan --request "$REQUEST" --output "$PLAN_OUTPUT"
# Inspect the emitted evidence/locked request; use its actual path, not a guessed filename.
CLOUD_WORKSPACE_ROOT="$WORKSPACE_ROOT" CLOUD_SHARED_RUNTIME_ROOT="$SHARED_RUNTIME" \
CLOUD_BICEP_BIN="$BICEP_BIN" \
python3 -B "$AZURE_PLUGIN/scripts/cloud.py" validate --request "$LOCKED_REQUEST" --output "$VALIDATE_OUTPUT"
```

AWS uses the same plan/validate flags plus explicit `CLOUD_NODE_BIN` and
`CLOUD_CDK_ROOT`. Plan freezes the **whole** assembly; validate rehashes it without
running the app again. Only one stack's plain JSON template file asset is
supported, with complete assembly/asset manifests, tree, metadata and reports.
Zip/directory, non-template file, Docker/ECR, executable and external assets block.
Prepare publishes the exact versioned S3 template; apply never resynthesizes.
Azure compiles fixed Bicep inputs using `build --no-restore --stdout`, then consumes
exact compiled ARM/parameter bytes in incremental mode, without recompilation.

**CDK executes code; the adapter is not a filesystem/network sandbox.** Run
untrusted source only in an ephemeral credential-free planning job without OIDC,
cloud mounts/secrets, privileged Docker socket or host access. Credential detection
and a minimized environment are defense in depth, not exhaustive isolation.
Never run npm or source hooks in credentialed prepare/apply jobs.

### Reproducible Linux x64 tools

Bicep 0.48.1 (`cec7951cf6`) is pinned to binary SHA-256
`b09ec25a9d376c1f8e33ede6ed22b587f915ad68488d5db77a6f9541748c7f6e`.
Acquire the official [bicep-linux-x64 asset](https://github.com/Azure/bicep/releases/download/v0.48.1/bicep-linux-x64),
verify the digest before execution, protect it from replacement, and explicitly set
`CLOUD_BICEP_BIN` to its physical absolute executable path.

Node 24.19.0 official archive contains npm **11.17.0** (not the earlier host npm
11.9.0). Use an operator-selected tools directory, not a development /opt path:

```sh
# Acquisition only; inspect/verify before executing downloaded binaries.
curl --fail --location --output node-v24.19.0-linux-x64.tar.xz \
  https://nodejs.org/dist/v24.19.0/node-v24.19.0-linux-x64.tar.xz
printf '%s  %s\n' 14b342e71204f811bde6153be8e04b62aef63c236fef92b55f9c83154b409647 \
  node-v24.19.0-linux-x64.tar.xz | sha256sum -c -
tar -xf node-v24.19.0-linux-x64.tar.xz -C "$TOOLS_ROOT"
export CLOUD_NODE_BIN="$TOOLS_ROOT/node-v24.19.0-linux-x64/bin/node"
printf '%s  %s\n' bc17c508ffeed0ec622934f9b7fa72f8e78da65350e63c3eceb56fa688aa5e12 \
  "$CLOUD_NODE_BIN" | sha256sum -c -
# CLOUD_CDK_ROOT is a new physical directory with the shipped package/lock files.
cp "$AWS_PLUGIN/examples/private-ec2/package.json" "$AWS_PLUGIN/examples/private-ec2/package-lock.json" "$CLOUD_CDK_ROOT/"
(cd "$CLOUD_CDK_ROOT" && "$CLOUD_NODE_BIN" \
  "$TOOLS_ROOT/node-v24.19.0-linux-x64/lib/node_modules/npm/bin/npm-cli.js" \
  ci --ignore-scripts --no-audit --no-fund)
```

The official [SHA-256 list](https://nodejs.org/dist/v24.19.0/SHASUMS256.txt)
and archive acquisition were checked separately from execution. Native T-011
acquisition actually ran the bundled npm and reproduced the pinned 8,095-file
CDK tree SHA-256 `34824a391a509c6907a9e6bb64f3a370a473bfbacd6e7f1cf1987ddd7431c1e1`.
The lock enforces registry SRI and CDK 2.1145.0/library 2.273.0/constructs 10.5.0.
`--offline` is optional **only with a populated cache**; a new user normally omits
it. Neither installation nor synthesis proves live IAM or resource health.

## Governed end-to-end handoff

Use the full reviewed executor checkout, not a skill cache, for governed wrappers.
The original `templates/cloud/github-*.yml` sketches are **inactive, not production
recipes**. Render the current fixed JSON workflow (valid GitHub YAML) from
[Azure setup](../plugins/sdd-azure-cloud/scripts/governed-setup.md) or
[AWS setup](../plugins/sdd-aws-cloud/scripts/governed-setup.md).

1. Commit reviewed executor/shared code as immutable **E**. Render offline with
   exact owner repository/scope and E. Review/commit the control workflow as **W**.
2. Configure owner-protected per-phase Policy JSON, exact W, stable GitHub IDs,
   expected principals, target/policy digest and TTL. Provision native OIDC trust
   only after W exists: issuer token.actions.githubusercontent.com, Azure audience
   api://AzureADTokenExchange or AWS sts.amazonaws.com, exact customized subject
   keys repo/context/workflow_ref/workflow_sha. Changing E requires new W;
   changing W requires external federation and policy refresh. A branch alone is not a pin.
   Select a protected `CONTROL_REF` branch that resolves to exactly W.
   The GitHub API also accepts tag names, but this adapter Policy supports
   `refs/heads/...` only; tags are not a supported cloud-admission shortcut. The dispatch API takes a
   branch/tag name, not an arbitrary commit SHA; native workflow_sha and Policy
   still enforce W. A moved ref is rejected, not accepted as a substitute pin.
3. Configure separate `sandbox-prepare` / `sandbox-apply` approvals and identities,
   required named reviewers, no self-review/admin bypass, protected branches,
   first attempts only. Rerun/rejected/ambiguous history requires a new dispatch,
   not reuse of an old approval. A JSON flag/GITHUB_ACTIONS string grants nothing.
4. Upload the immutable local `request.json` and complete `bundle/` privately.
   Prepare dispatch uses exact artifact ID, producer run ID, request SHA-256 and
   preview SHA `none`. Acquisition verifies authenticated digest/expiry/run,
   bounds archives and paths, and never executes artifact-provided code.
5. Inspect retained whole-workspace preview/authorization/intent evidence. Apply
   is a separate dispatch using the original prepared artifact ID/run and exact
   request/preview digests. Authenticated policy/principal/approval/artifacts and
   deadlines are rechecked at every native write callback.
6. Azure fixed jobs are prepare/apply/reconcile/observe/verify; their separate
   `AZURE_*_POLICY` variables use corresponding sandbox environments. Regenerate
   old ambiguous workflow templates and repin W; observers reject lookalike jobs.
   AWS recovery uses `sandbox-recovery-apply` and read-only role. Both providers'
   verify job uses `sandbox-verify` and `<PROVIDER>_VERIFY_POLICY`, operation `apply`
   only as the original-operation discriminator; it cannot authorize writes.
7. Reconcile uncertainty read-only; observe actual resources; verify authenticated
   mandatory checks before releasing dependents. Apply success alone is OBSERVED.

Do not dispatch the following until **all** owner prerequisites exist; this is
command shape, not authorization or a tested live dispatch. `CONTROL_REF` is the
operator-selected protected branch name resolving to W, not W's raw SHA. The
GitHub API also accepts tags, but the current cloud Policy requires `refs/heads/...`.
The shipped examples use `refs/heads/main`; select `main` with that Policy. Confirm
resolution before dispatch; a check is not atomic, so exact W admission remains
mandatory. See [GitHub CLI workflow run](https://cli.github.com/manual/gh_workflow_run)
and [workflow_dispatch API](https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event):

```sh
gh workflow run cloud-azure.yml --repo "$CONTROL_REPOSITORY" --ref "$CONTROL_REF" \
  -f operation=prepare -f artifact_id="$INPUT_ARTIFACT_ID" \
  -f artifact_run_id="$INPUT_RUN_ID" -f request_sha256="$REQUEST_SHA256" -f preview_sha256=none
gh workflow run cloud-azure.yml --repo "$CONTROL_REPOSITORY" --ref "$CONTROL_REF" \
  -f operation=apply -f artifact_id="$PREPARED_ARTIFACT_ID" \
  -f artifact_run_id="$PREPARE_RUN_ID" -f request_sha256="$REQUEST_SHA256" -f preview_sha256="$PREVIEW_SHA256"
```

AWS uses cloud-aws.yml and its owner-configured execution control, pre-existing
CloudFormation service role and versioned private S3 bootstrap bucket. Prepare
may publish the supported exact asset/create a Change Set; apply executes only
its original ARN/token. KMS and non-template assets are unsupported. CREATE-time
physical IDs and backup recovery points are obtained from **original native
deployment resources**, not guessed before deployment or patched into immutable inputs.

## Dependencies and observations

The external protected control Policy pins `dependency_request_sha256` to the
exact consumer request and has one closed `predecessor_trust` record per declared
predecessor. [Dependency owner contract](../plugins/sdd-azure-cloud/references/dependencies.md)
lists every field and GitHub cross-repository read prerequisite. A digest or saved
PASS/native file alone is not authority. Changing immutable predecessor references
requires fresh consumer authorization and updated external request/trust pins.
Cycles/self/missing edges block before callbacks; failed/UNKNOWN predecessors block
transitive dependents while independent successes and receipts remain unchanged.
No atomic cross-cloud rollback exists. Receipt `expires_at` is capped by predecessor
freshness as well as provider/policy/preview/consumer limits, conservatively at an
exclusive whole second; both write callbacks enforce it without a new schema.

`max_age_seconds` bounds **observation freshness**, not deployment age. Recent
metrics for an older deployment are valid only after original completion and
inside the selected bounded native window. Collectors join original resources,
operation, scope, profile, principal, query byte hashes and UTC times. They request
both workload Minimum and Maximum; all buckets must satisfy the range. Missing
permission, stale/incomplete/unknown context blocks; actual unhealthy checks fail.
Optional backup is omitted only when original policy and selected profile permit it.

- [Azure observations](../plugins/sdd-azure-cloud/references/observations.md): original
  successful fixed apply job bounds completion; sole workload user-assigned principal,
  bounded direct scoped permission closure, exact Linux DCR/performance counter/
  Log Analytics flow and received platform/custom signal. Unsupported groups,
  conditions, wildcard/data rights or DCR shapes block.
- [AWS observations](../plugins/sdd-aws-cloud/references/observations.md): original
  stack/token/events and DescribeStackResource derive physical IDs; exact supported
  inline Deny/NotAction metric-only permission bound, private single-NIC shape,
  monitoring/alarm and RunId/UnitId/InstanceId metric context, bounded native backup
  discovery. Attached role names or arbitrary IAM simulation are not proof.

Raw native responses remain private/in memory; public evidence is allowlisted,
secret-scanned and digest-bound. Local saved observations cannot promote production
VERIFIED/EVIDENCE_COMPLETE; authenticated acquisition/recollection is required.

## Recovery, prerequisites and residual limits

- NO_CHANGE means a genuine empty native preview, **zero apply submissions** and
  no fabricated deployment ID. Do not create an apply just to obtain an ID.
- UNKNOWN means delivery may have occurred. Retain original request, native ID,
  intent journal and immutable artifacts. Reconcile that ID; never blind retry,
  reuse run IDs, delete fences or silently republish a lost AWS object version.
- Exclusive writer ownership is mandatory for the account/subscription-region.
  GitHub concurrency uses `cancel-in-progress: false` and is repository-local.
  Complete visible retained dispatch history must fit the supported 100-run page;
  at the limit stop for a reviewed durable-history upgrade, never delete history.
  Azure's fresh what-if cannot remove the final preview/PUT race with external writers.
- Before live prepare the owner supplies scope allowlists, federation/least privilege,
  existing bootstrap/resources, approved image/size, private management/connectivity,
  workload instrumentation, backup/retention/recovery, current cost estimate and
  budget ceiling, evidence residency/retention/access, reviewer and history controls.
  Missing prerequisites block. Cleanup/correction needs separate explicit authorization.
- Code rollback disables the entry/workflow and restores reviewed code only; it
  cannot roll back resources or erase uncertain submissions.

## Verification and release status

#423 foundation checks keep seven Full-track documents and legacy code/shell/docs/spec
obligations intact. Use `python3 -B tests/sdd-domain-multitarget-foundation.tests.py`
and the catalog-backed [verification workflow](verification.md); old frozen inventories
remain historical evidence, not current-source tests.

Local synthetic transport suites, actual native compiler/synthesizer runs and isolated
native host routing/guard trials are recorded separately. T-011's second host trial
covered all eight active SDD caches and ten local CLI calls; historical source pins
bind those bytes, not later docstring/version/skill edits. New metadata does not
retroactively rerun a native model. Exact release full-suite/CI/native OS/tag/assets
results belong to root's [release record](../reports/verification/cloud-orchestration-release.md).
They remain pending until the actions actually occur.

An earlier T-006 fixture alias may have attempted unauthenticated read-only Azure
HTTPS with a synthetic token/fictional subscription; delivery/count unknown, no
authenticated success/write. Affected old aggregate PASS is invalid guard evidence.
Final guarded tests prohibit real urllib I/O, including subprocess and rollback paths;
see the preserved [network-isolation correction](../specs/cloud-orchestration/verification/T-006/attempt-3/network-isolation.md).
Do not publish raw native-events.jsonl, native-stderr.log or account metadata.
