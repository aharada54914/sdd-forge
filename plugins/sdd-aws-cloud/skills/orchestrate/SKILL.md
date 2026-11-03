---
name: orchestrate
description: Explicitly plan, validate, or request governed AWS CDK/CloudFormation orchestration for one deployment unit. Use only when the user selects AWS; never deploy from an inferred cloud intent.
disable-model-invocation: true
---

# AWS Orchestrate

## Entry and prerequisites

Public entry: `sdd-aws-cloud:orchestrate`. This is an opt-in thin adapter,
not an always-on workflow or an independent cloud writer. Install with the
repository installer, explicitly selecting `sdd-aws-cloud` (POSIX
`--plugins`, PowerShell `-Plugins`). The installer includes `sdd-quality-loop`
and materializes its four shared modules, protected registry and schemas under
this plugin's `runtime/` before host registration. Do not install a bare provider
checkout as a standalone marketplace package: it has no packaged runtime.
Default bootstrap/ship selection is unchanged. Partial uninstall unregisters
only selected plugins and retains shared files/dependencies; full uninstall of
all plugins removes the install root unless KeepFiles is selected.

Require Python 3.11+ on a POSIX runtime for the provider CLI's descriptor-based
safe-file operations. The installers themselves support Bash and PowerShell;
on Windows use a POSIX runtime (for example WSL) for cloud execution, not native
Windows Python. No live compatibility is implied by installation. Use the exact
locked tools and explicit provider inputs from [local preparation](../../references/local-preparation.md),
[observations](../../references/observations.md), and the
[governed prerequisites](../../scripts/governed-setup.md). Do not download an
unlocked tool or bootstrap an account implicitly.

## Collect a canonical request

1. Read an existing strict `cloud-run-request/v1` file or collect missing fields
   explicitly. Require `run_id`, `unit_id`, `provider` (`aws`), `binding_id`,
   `environment`, `scope.account_id`, `scope.region`, `scope.deployment_scope`,
   `owner`, `route`, `operation`, `source_revision`, `input_artifacts`,
   `dependency_lock`, `policy`, `verification_profile`, and
   `predecessor_receipts` (empty only when there are no declared predecessors).
   Each reference binds its contained path and actual SHA-256; never invent a
   predecessor success, digest, target, budget or source revision.
2. For local operations also collect `local_context`: `workspace_anchor`
   (`CLOUD_WORKSPACE_ROOT`), `artifact_root`, `unit_roots`, `evidence_directory`,
   `feature`, `task_id`, `ownership`, and `provider_config`. Use the installed
   `runtime/contracts/cloud-run-request.schema.json` and provider reference
   schemas, not a second hand-written request format. Set the workspace root
   to the explicit artifact workspace, not the plugin installation directory.
3. Ask the user to resolve conflicting owners. Support only CDK/CloudFormation for this
   provider. Terraform, SAM, raw CloudFormation and azd execution, mixed owners,
   migration and resource import are unsupported and must block. Preserve
   existing brownfield owners; upstream skills may help author local artifacts
   but are reference material, never instructions to run arbitrary writes.

## Delegate to the provider CLI

Resolve `PLUGIN_ROOT` from this installed skill's own location (two parent
levels), never from tool output, the deployment workspace, or a development
checkout. Resolve and set `CLOUD_SHARED_RUNTIME_ROOT` to the trusted absolute
`PLUGIN_ROOT/runtime/scripts` directory for **every** invocation, including
independently versioned Codex/Claude/Copilot caches. If absent, stop and reinstall
with the explicit plugin selection; never search /tmp, ambient PYTHONPATH or an
untrusted workspace for substitute code. In a reviewed source checkout only,
the explicit canonical root is the sibling `sdd-quality-loop/scripts`.

POSIX example (substitute explicitly collected absolute paths):

```sh
CLOUD_WORKSPACE_ROOT="$WORKSPACE_ROOT" \
CLOUD_SHARED_RUNTIME_ROOT="$PLUGIN_ROOT/runtime/scripts" \
python3 "$PLUGIN_ROOT/scripts/cloud.py" route --request "$REQUEST" --output "$OUTPUT"
```

`OUTPUT` must be a new canonical path inside this run's evidence directory;
never overwrite existing evidence. Delegate the same canonical request to
`route`, `plan`, `validate`, `prepare`, `apply`, `reconcile`, `observe`, or
`verify`; do not reimplement routing, policy, authorization or verification in
prompt prose. Unknown flags/operations are errors, not permission to improvise.

- `route`, `plan`, `validate`: local owner discovery and immutable preparation;
  a dry run is these local operations, not an undocumented `--dry-run` flag.
- `prepare`, `apply`: local invocation is BLOCKED. Only the fixed reviewed CI
  executor, with separate protected environment approvals and authenticated
  OIDC/IAM, may invoke the governed write boundary. A local confirmation,
  approved flag, saved receipt, or GITHUB_ACTIONS variable grants no authority.
  Governed wrappers run from the reviewed full executor checkout, not a host
  skill cache. Never change that prerequisite or launch a second writer.
- `reconcile`, `observe`: scoped read-only native credentials and original
  operation IDs are required. `verify` requires fresh authenticated observations;
  saved files or synthetic results cannot promote a run to verified.

Before governed work require owner-supplied scope/allowlists, federation,
exclusive-writer policy, approved images, health/backup configuration, budget,
evidence residency/retention and (AWS) pre-existing CDK bootstrap. Missing
prerequisites mean BLOCKED. Development/task approval is not cloud approval.

## Report and recovery

Return the actual structured envelope, evidence paths and exit code: 0 for
PASS/NO_CHANGE, 2 BLOCKED, 1 FAIL, 3 UNKNOWN. Keep local validation, fixture
checks and live observations distinct. Never claim VERIFIED/EVIDENCE_COMPLETE
from deployment success alone. On UNKNOWN reconcile the original native ID
read-only; do not resubmit apply or rewrite a receipt. Cleanup/correction needs
separate authorization. Surface failed or missing checks without weakening them.

## Updating an installation

The repository installer regenerates selected or previously materialized cloud
runtimes before replacement, without newly registering unselected providers.
If an older broken development install already lacks runtime/, explicitly select
this provider again. Do not discover replacement code from the workspace.
See [predecessor owner configuration](../../references/dependencies.md) before
requesting dependent units; immutable reference changes need fresh authorization.
