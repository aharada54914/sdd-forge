# AWS local preparation (T-005)

`python3 plugins/sdd-aws-cloud/scripts/cloud.py <operation> --request <path> --output <path>`
uses the existing shared strict cloud contracts. Operations: `route`, `plan`,
`validate`, `prepare`, `apply`, `reconcile`, `observe`, `verify`. Direct calls
to governed phases block without the trusted executor (observe/verify use
`TRUSTED_COLLECTOR_REQUIRED`). See [governed setup](../scripts/governed-setup.md)
and [observations](observations.md) for the implemented protected paths.
stdout is one JSON envelope; exits are 0 PASS/NO_CHANGE, 2 BLOCKED,
1 FAIL, 3 UNKNOWN. This local adapter emits no preview, native operation ID,
cloud observation, verification success or authorization.

## Explicit inputs

- `CLOUD_WORKSPACE_ROOT`: physical absolute POSIX workspace. No cwd/home/request
  inference. `local_context` declares artifact root, source unit roots, exact
  evidence directory and immutable ownership/config/policy/profile references.
- `CLOUD_CDK_ROOT`: physical preinstalled toolchain root containing the exact
  example package.json/package-lock.json and their installed node_modules.
- `CLOUD_NODE_BIN`: physical absolute operator-selected executable, **not PATH
  lookup**. Exact Node 24.19.0 binary hash in toolchain-lock.json is required.
  Relocation of identical bytes is supported; another Node build/OS binary
  needs a separately reviewed pin. No automatic download/install/update.
- The source unit contains `cdk.json` (`{"app":"node app.js"}`), `app.js`,
  `parameters.json`, package.json, package-lock.json and any local modules.
  Every source file must be an input_artifacts entry. No directory/hidden
  source exceptions: generated CloudFormation inside a unit causes an owner
  conflict. The config output_directory must be inside artifact_root but
  outside every source unit. All publication parents must already exist.

The example's package and lock metadata reproduce aws-cdk **2.1145.0**,
aws-cdk-lib **2.273.0**, constructs **10.5.0**. No node_modules is shipped.
Pin validation hashes the complete installed tree (including bundled packages),
package metadata, Node binary and exact version output before **and after**
synthesis. npm lifecycle scripts are never invoked. Original registry SHA-512
integrity and installed-file comparisons are recorded in T-005 verification.

The upstream lock binds the CDK skill and its complete transitive local Markdown
reference closure at `44ba1a5451913998815111cc2d518f5c45f95ef7`. These are
reference data, not instructions or cloud authority. External documentation URLs
are citations, not executable dependencies; none is fetched during operation.

## Security boundary

**CDK executes application code. This adapter is not a filesystem or network
sandbox.** Changing HOME, PATH and environment variables does not prevent JS
from reading other files, opening sockets, launching executables or accessing
host mounts. Direct local use is for reviewed/trusted application code only.
The intended boundary for untrusted source is the native workflow's separate,
ephemeral uncredentialed planning job: no OIDC permission, cloud secrets,
ambient credential mounts or privileged Docker socket. Never run untrusted
IaC or npm scripts in credentialed prepare/apply jobs. Those jobs consume only
frozen artifacts with fixed trusted executor code.

Direct plan rejects common detected cloud credential environment variables,
GitHub OIDC/token variables, both configured and account-home AWS/Azure/GCP
credential directories, and conventional service-account secret mounts. This
is defense in depth, **not exhaustive credential discovery**. The adapter uses
a small child environment, disables CDK lookups/metadata-service use and runs
only fixed local `synth --no-lookups --strict` arguments. It does not invoke
bootstrap, deployment, asset publishing, hotswap or Docker. Arbitrary app side
effects require external isolation; token detection cannot prevent them.

## Immutable planning and supported policy

Request.operation stays `apply`; the CLI phase is separate. `plan` synthesizes
once into disposable scratch, checks the actual compiled resource graph and
publishes the **entire** assembly into a new digest-named artifact directory.
It emits a new locked request; it never changes the supplied request. Failed
partial publication is not reusable. `validate` rehashes the complete locked
assembly and rechecks its policy **without executing the app or resynthesizing**.
Authorized apply must consume those exact assets, never regenerate them.

Supported asset subset is deliberately **one stack's plain JSON template file
asset only**, plus its full assembly/asset manifest, metadata, tree, validation
report, feature flag report and cdk.out. Non-template files, zip/directory,
Docker, executable and external assets return `ASSET_TYPE_UNSUPPORTED`; they
are not ignored or published. Assembly and asset schemas are pinned to 54.0.0.
Bootstrap bucket/role locators are recorded as CDK outputs, not established live
resources or authorization. Protected prepare publishes only these exact supported bytes; see governed setup.

Graph validation is structural, not a golden-template hash: supports explicit
EC2 instances, new private security groups, CloudWatch instance-status alarms,
and additive BackupSelections using an existing backup plan/role. Supported
intrinsics are bounded Ref/GetAtt/Join/Sub with provenance-carrying resource
tokens; plain/composed strings cannot impersonate resource references.
Unrecognized resource types, conditions/transforms, executable surfaces,
dynamic lookups, mutable existing VPC/subnet/role/profile/plan/vault resources,
public networking or undeclared attachments block. Logical IDs must match the
explicit attachment names. The existing VPC/subnet, instance profile, backup
plan and role remain references owned by their original IaC owner; no import.

The example requires explicit account/region/stack, image ID/instance size,
VPC/subnet/profile and backup plan/role. Only HTTPS egress to a private CIDR is
planned; no public IP or inbound rules. Detailed EC2 monitoring and a status
alarm are configuration, not observed health. Backup retention/recovery, IAM
least privilege, private endpoint connectivity, image ownership and actual
network/health still require owner configuration and live readback. The exact
image parameter default is locked; W9010's portability warning is explicitly
acknowledged, not replaced by a live image lookup. Structural policy still
requires that exact image input. No broad validation disabling is used.

Budget ceiling and estimated cost/currency/duration, restricted evidence
access/retention/residency, and private-management prerequisite are mandatory.
The synthetic test values are **fixtures**, never approved deployment targets
or current price quotes. OQ-001 blocks live TEST-003/005/009. No live acceptance
or production readiness is claimed.

## Host limits

Shared no-follow, dir-fd and exclusive publication primitives require POSIX.
Native Windows fails closed; it has not been claimed supported. Tests use
physical temporary roots on macOS, but the pinned Node binary is the observed
Linux build; native macOS execution needs a reviewed platform-specific pin.

## Upstream attribution

Pinned upstream reference material retains its original authorship and license.
See [full upstream license](LICENSE-upstream.txt) and [NOTICE](NOTICE-upstream.txt); commit/source and consumed-file digests remain in upstream-lock.json.
These notices do not grant cloud authority or alter the frozen dependency closure.
