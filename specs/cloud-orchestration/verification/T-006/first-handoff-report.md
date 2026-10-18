# Implementation Report: T-006

- Task ID: T-006
- Model: openai/gpt-6-astra
- Effort: high

Report Schema: implementation-report/v2

**Snapshot Notice**: The numbers, statuses, and paths recorded below reflect
the state at this report's own authoring run only. A later same-feature
event -- another task's edit to the same surface, or a gate-phase artifact
normalization such as a path move -- may supersede them. The quality
verification gate's own report is the authority for the gate-time state;
this report is not edited after the fact to reconcile it.

Run ID: 01a14e57-c9ef-7892-a76f-bdaa02a2fde5
Task Attempt Count: 1
spec_revision: fb2d374ab671fa12856d0892dc8d958582b0d11f
Input manifest: `specs/cloud-orchestration/verification/T-006/task-input-manifest.json`, SHA-256 `9690828f7ae3d253d4c15ba0cd61990adadf310daac825f04fc279726db4779b`

## Target

cloud-orchestration T-006 only. No task status, approval, frozen specification or release changes.

## Summary

Incomplete candidate, not ready for quality evaluation. Shared reducer and two native read-only collector candidates exist, but resource provenance/CREATE discovery and other mandatory behavior remain unfinished. Work stopped at the required context boundary; no implementation-complete or gate verdict is claimed.

## Files Changed

New cloud_verification.py, aws_observation.py and azure_observation.py; observe/verify entry wiring in each cloud.py, execution/governed/local module; optional observation configuration in both local provider schemas. Test/evidence/report changes only otherwise. Existing unrelated candidate files remain untouched. The Outputs table includes unchanged runtime/test dependencies as well as changed files; inclusion is not a claim of ownership.

## Tests Added Or Updated

Added tests/cloud-orchestration-verification.tests.py: 13 top-level tests with reducer mismatch subcases and explicitly synthetic native transport fixtures. Native collector methods execute service protocol parsing for each required check. Tests do not yet cover complete production observe orchestration, stack-resource substitution or newly allocated physical IDs. EntryPreflight only checks direct CLI rejection; its stale name/comments/docstring overstate saved-payload coverage and must be corrected. No saved malicious payload is actually consumed by that test.

## Outputs

One table row per produced file. Paths MUST be canonical repository-relative
paths: forward slashes only, with no absolute/drive prefix, backslash, empty
segment, `.` segment, or `..` segment. The independent evaluator launch
boundary authorizes changed/test/contract inputs ONLY from rows in exactly
this two-column, backtick-quoted form — keep the shape byte-precise.

| Path | SHA-256 |
|---|---|
| `contracts/cloud-authorization-receipt.schema.json` | `5c4f8efaaf458aba6f149a53967df7615eaf2a823c4ec6f75e44610a4c8ac8b8` |
| `contracts/cloud-dependency-lock.schema.json` | `e72395e755f13bff50f8f10d27a8181fcfa1894ef6c60499c01f84d4c2128cec` |
| `contracts/cloud-deployment-policy.schema.json` | `a064217e4a68838a3d719749fb751ba63ffabb2094d16cf13090afeaed080eb8` |
| `contracts/cloud-input-error.schema.json` | `d228ad47ea2c899022169a704c9408f6b5fee285be5be12ad3f0906bd2b4bc77` |
| `contracts/cloud-observation.schema.json` | `5ce80d6fb77fde9bc966d00db75c2650f3a37166fcccfd1071f087208191c826` |
| `contracts/cloud-operation-result.schema.json` | `a92bdac86499052256112babe5ff559c2e071adba411f4a2e92ec38b6b5b2aa6` |
| `contracts/cloud-ownership.schema.json` | `71079e7320c968bce57fba67bd105d59ab57c00a51165a3598d522919141f25d` |
| `contracts/cloud-preview.schema.json` | `12afaf962e1bf1325496d985b21ffc5c970c1e2d14fc43933c5ad8aa8940eb99` |
| `contracts/cloud-run-request.schema.json` | `781d83fad3d8e883e2c4aa886c5356da12f93d5ef5e35f16a5d83e9c024c9d81` |
| `contracts/cloud-verification-profile.schema.json` | `b25112c7e73583b180941639cb8f137a89fcb7daa82b1afd7ec8eec66c9353bf` |
| `contracts/cloud-verification.schema.json` | `dcfd0760733951080efc1f0cb993bfc46a081b4eff4a82bd07968f868b2f3f2e` |
| `contracts/task-input-manifest.schema.json` | `22a756c64a7c720b761b31d71c9fbb62c390a9f18b201673443e962998781749` |
| `plugins/sdd-aws-cloud/examples/private-ec2/README.md` | `0caceb7832a0c3e467042a760789f03a47521eaca375e712ea15120931e2ea5a` |
| `plugins/sdd-aws-cloud/examples/private-ec2/app.js` | `710c6889188eac80e9f5e6b505c3796ded52747c9a56c305c58a53d05f3c2b25` |
| `plugins/sdd-aws-cloud/examples/private-ec2/cdk.json` | `7802e394180f0d618f4caf7d1a6647f406ad327fa0aaa38c84b8b6b8471b24a5` |
| `plugins/sdd-aws-cloud/examples/private-ec2/package-lock.json` | `b106084fff5e18ca94260509133337891b58d5269d77166ff9320a36419cccec` |
| `plugins/sdd-aws-cloud/examples/private-ec2/package.json` | `beddc07bfbf3d198ca58b3d500e746b7bd4ebc14a25b469033fb1c41ba50a00b` |
| `plugins/sdd-aws-cloud/references/aws-local-config.schema.json` | `6d4c34982e844d29171b5d0d24b555df70bdb8ae57039854d91824a8af577778` |
| `plugins/sdd-aws-cloud/references/aws-local-evidence.schema.json` | `d64402c81095bd9a0657d34f4723a02996d91bb93cb0d0906c4ca288aeaa3187` |
| `plugins/sdd-aws-cloud/references/local-preparation.md` | `2a890269fabb6128f125f5533d3eb4c6411589ca0d0843b642b47cc959f7a257` |
| `plugins/sdd-aws-cloud/references/toolchain-lock.json` | `c46bafb8869840c879739f424746eda64ca6c62aafab906d9e98012dee7c3f5d` |
| `plugins/sdd-aws-cloud/references/upstream-lock.json` | `1898ede044cc25e0fba804077559544f5f58e9e323d8d0701721b8545cc97766` |
| `plugins/sdd-aws-cloud/scripts/aws_control.py` | `92842d7174dbb0bc8ba3ad796fd8a3bd7f46ed91178dfa80bbc6558762523d67` |
| `plugins/sdd-aws-cloud/scripts/aws_execution.py` | `69ba7b8b9fe43c1ddcb0a7af0b38f2c5f60affc7e86d02c3710e8a168b5974f7` |
| `plugins/sdd-aws-cloud/scripts/aws_governed.py` | `33dd06c2b3130d1357938f4b9f077aa6d855149a690d69fdd06d55f94e0cddff` |
| `plugins/sdd-aws-cloud/scripts/aws_graph.py` | `21896c758e64f5db7571c2c5209a4ab122cac8347dc18096c29e79f7396a42fd` |
| `plugins/sdd-aws-cloud/scripts/aws_local.py` | `82bbf762e80d62abdc77b56f850729c72d4ae83c3e59f4de09751867f16e4b31` |
| `plugins/sdd-aws-cloud/scripts/aws_native.py` | `c49dc00931cda5a913e896278da3ba1f48c5c97dbc365c4618edc5ff377fcf8e` |
| `plugins/sdd-aws-cloud/scripts/aws_observation.py` | `921876a68457547629c654f6ab5a3e9cb6cde85622357063718447a6df35bb2c` |
| `plugins/sdd-aws-cloud/scripts/cloud.py` | `167b3e37e88a5ab1c32344e226823ae0e9d1518d7927a7ab4221422a011cc933` |
| `plugins/sdd-aws-cloud/scripts/governed-setup.md` | `2bd8c9b4ddcd7d9879a5b58d1e7c30d4d9c8c0286501b6b4d066eaf967712578` |
| `plugins/sdd-azure-cloud/examples/README.md` | `18d4bac06d053a486ab77936c75cd7e4f0824fff90728431cbfdf7f89d9cc873` |
| `plugins/sdd-azure-cloud/examples/private-vm.bicep` | `81ba478fb3744e96496243358f3aef3477646027a58e1220f3c16b7b428c9422` |
| `plugins/sdd-azure-cloud/references/azure-local-config.schema.json` | `3343f9215bdf915764e4f68b89b5262746aa3b5509c122de192ff85bbdd6258d` |
| `plugins/sdd-azure-cloud/references/azure-local-evidence.schema.json` | `e4584e317609585b3effc865412757ef730448d814b2ce7f78eebf485728b68a` |
| `plugins/sdd-azure-cloud/references/azure-parameters.schema.json` | `5922b55565b1a506db4cc424560cbfaa0b07766f1e26bf50dd4247ade18fc3ae` |
| `plugins/sdd-azure-cloud/references/local-contract.md` | `68850cae945e1e5357fedb284079cce67fec809a07cd1a35f6f923a39b89fdfc` |
| `plugins/sdd-azure-cloud/references/upstream-lock.json` | `f7e22249f21c062e6207579460b1ad1042af52e4eb619d8566fd4d99db675644` |
| `plugins/sdd-azure-cloud/scripts/azure_arm.py` | `5ee98cf0fde60b1d8e9959cf17e7eb6e53fbaf179104ad0e080b849f936cff86` |
| `plugins/sdd-azure-cloud/scripts/azure_execution.py` | `cb8b14a85e305431aaf80eb568620aeb42b724aa13f485251338f9bde70c360a` |
| `plugins/sdd-azure-cloud/scripts/azure_governed.py` | `bcb77efc17062191fc803a536d38ec870565b74af8176358b6aae595e8885bd0` |
| `plugins/sdd-azure-cloud/scripts/azure_graph.py` | `f46bdc77c12449d0f4befd0221b29687e7b4f48685cc6106080de62b3a4d075f` |
| `plugins/sdd-azure-cloud/scripts/azure_local.py` | `43d37a2ec9ae8e5bfc60690480c7ec607237b03b4c3d6fbb7f1e8d2ee7792f10` |
| `plugins/sdd-azure-cloud/scripts/azure_observation.py` | `9e39eacfb0a64763198bb4ece1f3b2383dd0d72e9d1e572b25047a2d37844e02` |
| `plugins/sdd-azure-cloud/scripts/cloud.py` | `4ae02ced280a8267a99fbd18b92d5fbd7a61b3d3e64c369b02e02c63c15b5636` |
| `plugins/sdd-azure-cloud/scripts/governed-setup.md` | `b2f038ab953175e2fab863d5cc8baada77a79c0b8cef1281df68142831343388` |
| `plugins/sdd-implementation/scripts/validate-implementation-report.sh` | `430e0e45c6bb417cd65f7f7f228bb59280d6d0817c8b34236223b8fbd4702029` |
| `plugins/sdd-implementation/scripts/validate-task-input-manifest.sh` | `5e209d11c50b9c580572adedee0c500fcc48233c1cafe5d22d08318c52059f73` |
| `plugins/sdd-implementation/templates/implementation-report.template.md` | `0c926d76c0aab214fe305ad5974dc6636aea81cc2764a0b37292ea61cb4f1f75` |
| `plugins/sdd-quality-loop/scripts/cloud_authorization.py` | `b165a6aa307a25721a63607f3c314bb6d290b1e1e450006be66c9a7d208ba916` |
| `plugins/sdd-quality-loop/scripts/cloud_contracts.py` | `c11225de15d8944a4183085b3df98f7b4da2d87227c473ad4eedde377b51164d` |
| `plugins/sdd-quality-loop/scripts/cloud_verification.py` | `c00013163c46a0c2b2c8e85b1f8fc00f46a7210af0bf8f076401e9efbe626d33` |
| `specs/cloud-orchestration/verification/T-006/api/aws-deny-notaction.html` | `b16ee412e900a3877c6d4c065c2a2871baace949c9c102ac62410db077e72ae1` |
| `specs/cloud-orchestration/verification/T-006/api/aws-policy-evaluation.html` | `c89f839064a26a0832b99613f691ef312edd02778f951ff24e577766cb822b2f` |
| `specs/cloud-orchestration/verification/T-006/api/azure-backup.json` | `b970baf29949091c3d7ab7c73e4854e9870479f7e738c619150f949844053a97` |
| `specs/cloud-orchestration/verification/T-006/api/azure-dcr.json` | `faee1ef80a7cb33f15969e375a65fd3ae945a49c28c631f2b7e757a3fbe7e6db` |
| `specs/cloud-orchestration/verification/T-006/api/azure-identity.json` | `e5d776b4b7c62740fa4793bccbde62ab5a5fda40be27de2a2c815b711aa429c9` |
| `specs/cloud-orchestration/verification/T-006/api/azure-metrics.json` | `d7252e38426128a151a601d167b81da7cfc556070a87ec1809969af33517c6ba` |
| `specs/cloud-orchestration/verification/T-006/api/azure-monitor-types.json` | `ed9427b7ca942059dc06814a09d7cfb7938b6c96af6460d01e02e14b4c544544` |
| `specs/cloud-orchestration/verification/T-006/api/azure-network.json` | `f7570ba60ca00c7508c892eab12ffc3ff48de2d3fd771702f33c508e7a9fcb24` |
| `specs/cloud-orchestration/verification/T-006/api/azure-permissions.json` | `30d7eaad3b1c09e686affeefbd119bf2080a5ddb7bcba78e2955c20f343ffd59` |
| `specs/cloud-orchestration/verification/T-006/api/azure-vm.json` | `3f43b1a2e392756852cb57002678fd0dc32db2fea6c75602827afda6b0142da4` |
| `specs/cloud-orchestration/verification/T-006/api/backup.json` | `da49a9f7562e493e913fd387379ad7d29a443cd0f977321cca9885bc6dc8e73b` |
| `specs/cloud-orchestration/verification/T-006/api/cloudwatch.json` | `56b0a8bf43250cc80f9d74208da12665445d7b3ceba5a30111e2bc29e427272a` |
| `specs/cloud-orchestration/verification/T-006/api/ec2.json` | `5e5ef99b67df883ace51f0fecee5e79a7006ef66ad7f4d3c8ce607312a495394` |
| `specs/cloud-orchestration/verification/T-006/api/iam.json` | `15c70eaeb15bda321fbf0e9a0db35036d67c6ccd34d38acbcad3a086b89251c5` |
| `specs/cloud-orchestration/verification/T-006/api/sources.json` | `698f30b1934d924804d370a16d2251c3665c499a80a959b439e2596d8963ea88` |
| `specs/cloud-orchestration/verification/T-006/baseline-contracts.log` | `deb2ab6d27f2a27a6e7ec11b3e46fdf3b89c35329981bbd06c9d800aa8d6713d` |
| `specs/cloud-orchestration/verification/T-006/baseline-execution.log` | `98faa8e9b69a276af30dba5bd2d126ab98ea22f676de2dc16a79a39fb5169b05` |
| `specs/cloud-orchestration/verification/T-006/baseline-routing.log` | `817a9e2fe40cd3dca2743fca57b1cc608f40f883f694af0b6cf4fb9e438baa23` |
| `specs/cloud-orchestration/verification/T-006/before.json` | `6e43387da370d450a780b54eb0163f091da60c32edc10f48dbd264fc62fe4da0` |
| `specs/cloud-orchestration/verification/T-006/green-native-first.log` | `80593050da72e1d32f087aae6116319aa689d1745b3274f6b9fe6613f14bd5dd` |
| `specs/cloud-orchestration/verification/T-006/green-native-second.log` | `728b53d01e60c41ef3ba6a7aed031f818cb3a0bc8883a097b91d2706229a6a69` |
| `specs/cloud-orchestration/verification/T-006/green-reducer-first.log` | `8501a8111d8ebdd85867c60346242285f83773c9bad728612dae178cedf4ed6e` |
| `specs/cloud-orchestration/verification/T-006/handoff-checks.json` | `a652526e5760668d62e2772093f26813931f1b2e4ff051903bb1d59c2dc647d6` |
| `specs/cloud-orchestration/verification/T-006/handoff-contracts.log` | `1a1fcb1260cbd1e1dce27b136ac84b3276a086b43d4e1399a50520e545815e33` |
| `specs/cloud-orchestration/verification/T-006/handoff-execution.log` | `0f227794361a6483c393dbea158088f7b7b370294a1d89e15b78a60edae0bda4` |
| `specs/cloud-orchestration/verification/T-006/handoff-manifest.log` | `19a1a6cd7734753b5aa95ccba1d2ec6032e3c41e867992fdfbac4fc7e1d63268` |
| `specs/cloud-orchestration/verification/T-006/handoff-mypy-aws.log` | `2c5fcdbf688a2e7c94e8c9e2cb7fa9f10369e5bb74529943d465fb6901c8bab3` |
| `specs/cloud-orchestration/verification/T-006/handoff-mypy-azure.log` | `d549db364c7d17f8843150bbd8047a4dd74f4151ab118fba80f06196fc452cc1` |
| `specs/cloud-orchestration/verification/T-006/handoff-mypy-shared.log` | `b253f5d84271b351ec30c626de062000c142f37d5af790aebd130751f1582a65` |
| `specs/cloud-orchestration/verification/T-006/handoff-report-validation.log` | `a0eb36646f9654b7ef1b674fed63ad247a1febe005869fbf36ce295f5437a10c` |
| `specs/cloud-orchestration/verification/T-006/handoff-routing.log` | `0e0f8eb56979aedbc5250cca3d8863b3791783a52d053fa883fbe4eef25caf3a` |
| `specs/cloud-orchestration/verification/T-006/handoff-ruff.log` | `2d88eacdba9a248497b4155ee1040d1aef5ecdc0344620bac4f57165a1628e68` |
| `specs/cloud-orchestration/verification/T-006/handoff-verification.log` | `bba52bcb7d9f234f065e626465682d4166fef00c942671f21bbf06000bfb785f` |
| `specs/cloud-orchestration/verification/T-006/manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-006/red-components.log` | `8c7c56a85c62d3b1665ebf6042d4784fe6c0071761a775426be0f516f02614b6` |
| `specs/cloud-orchestration/verification/T-006/red-entry.log` | `4a388cea50330484de40d40ebd43d8b9496d3f52e07f76ffe8f75f48cdb117e7` |
| `specs/cloud-orchestration/verification/T-006/red-native.log` | `bbbcb22f9df46a0184095100fd01d24095775c41f8b4ddff654335a2a1c07f94` |
| `specs/cloud-orchestration/verification/T-006/red-preflight.log` | `dce50971d8676f3689980ba498a62f992bf9cfb50074d72802354374c204af57` |
| `specs/cloud-orchestration/verification/T-006/ruff-first.log` | `880e1752d98bd22b910e666f53304af5574f84f68b9594b3a79f092103b6f7d8` |
| `specs/cloud-orchestration/verification/T-006/source-manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-006/supplemental-source-manifest.json` | `2c7a8e8604181afe80368be198fbba40c5d6d83cb5c283630ae8b33c64d39a9d` |
| `specs/cloud-orchestration/verification/T-006/task-input-manifest.json` | `9690828f7ae3d253d4c15ba0cd61990adadf310daac825f04fc279726db4779b` |
| `tests/cloud-orchestration-contracts.tests.py` | `71b89cf257b302fe695f7bdb5b42e648eaec0edb7ef14ce2c7f927bb5cd1a90b` |
| `tests/cloud-orchestration-execution.tests.py` | `3ded22c4377536bfa7925555935d4e14a614263674c1d3acf2a973570cb14703` |
| `tests/cloud-orchestration-routing.tests.py` | `ed91ffb6d77b2c033574ad8db08abd81dc1b823f759399240f01ef910d80e21e` |
| `tests/cloud-orchestration-verification.tests.py` | `84459ff2eefb4b207515fcaaab760e6c7b1764444a160552c09ea1466065e2f7` |
| `tests/shared-launch-python/pyproject.toml` | `8308097d7ca9084f9e3a02add4d78f96514cefa947c25bab3ed24a7b74393f12` |

## Test Evidence

- **Test Command**: python3 -B tests/cloud-orchestration-verification.tests.py
- **Test Result**: PASS
- **Test Evidence Path**: specs/cloud-orchestration/verification/T-006/handoff-verification.log

`Test Evidence Path` follows the same canonical repository-relative path rules
as output paths.

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Scratch Root**: /tmp/cloud-T006-01a14e57
- **Run ID**: 01a14e57-c9ef-7892-a76f-bdaa02a2fde5
- **Session ID**: 01a14e57-c9ef-7892-a76f-bdaa02a2fde5
- **Agent Instance ID**: 01a14e57-c9ef-7892-a76f-bdaa02a2fde5
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

Scratch Root, when declared, uses plain text or exactly one balanced
single-backtick Markdown span for the same path; malformed spans, controls
and duplicate declarations are invalid. A quality reservation additionally
requires a canonical absolute path with forward slashes and no empty/dot/parent
segments. Do not edit a frozen report to change its recorded root.

Fresh-agent reports MUST use `None` for both fallback fields. The only allowed
fallback is `same-session-file-reload`, whose exact reason is
`host-does-not-support-implementation-subagents` and whose evidence is a
lowercase 64-hex SHA-256.

## Regression Tests Run

- `handoff-verification`: exit 0; `specs/cloud-orchestration/verification/T-006/handoff-verification.log`.
- `handoff-contracts`: exit 0; `specs/cloud-orchestration/verification/T-006/handoff-contracts.log`.
- `handoff-execution`: exit 0; `specs/cloud-orchestration/verification/T-006/handoff-execution.log`.
- `handoff-routing`: exit 1; `specs/cloud-orchestration/verification/T-006/handoff-routing.log`.
- `handoff-ruff`: exit 1; `specs/cloud-orchestration/verification/T-006/handoff-ruff.log`.
- `handoff-mypy-shared`: exit 1; `specs/cloud-orchestration/verification/T-006/handoff-mypy-shared.log`.
- `handoff-mypy-aws`: exit 1; `specs/cloud-orchestration/verification/T-006/handoff-mypy-aws.log`.
- `handoff-mypy-azure`: exit 1; `specs/cloud-orchestration/verification/T-006/handoff-mypy-azure.log`.
- `handoff-manifest`: exit 0; `specs/cloud-orchestration/verification/T-006/handoff-manifest.log`.

Baseline contracts/execution/routing logs also returned exit 0. No whole repository suite, live cloud action or independent review was run.

## Specification Differences

Frozen specifications unchanged. Optional provider observation configuration is immediate API contract work authorized by the caller; current generated-ID shape is inadequate and must change before completion. Existing local v1 behavior without observation is retained; observe/verify explicitly blocks when configuration is absent.

## Unresolved Items

1. **Deployment provenance / CREATE (implementation defect):** AWS proves original stack/token completion but takes configured EC2 physical ID without native stack-resource membership. An unrelated healthy instance can satisfy that check. Resolve an explicit compiled logical selector with original stack readback and exact resource type/stack ID. Azure outputResources membership alone must be joined to the original compiled template/deployment operation. Root supplied static findings; no executed exploit is claimed.
2. **Immutable generated IDs (implementation defect):** instance/security-group/alarm/BackupSelection/recovery identifiers currently assume preknown physical IDs. Existing VPC/subnet/profile/plan/vault identifiers may remain explicit owner inputs. Created resources need fixed compiled logical selectors and native membership. Recovery points need bounded discovery joined to actual resource, approved plan/vault and post-completion window. Do not edit request/config after apply. Add genuine substituted-resource and unknown-ID CREATE tests and commit their Red before fixes.
3. **Native positive path not established:** AWS exact explicit-deny inline role guard and Azure same-workload-identity caller-permission reads are candidates, not live proof. Azure currently uses a fresh-read completion fence without bounded waiting; ordinary metrics/backups predate that fence. Establish authoritative completion semantics and bounded read-only collection with lease checks, or report the concrete architecture limitation. This is distinct from OQ-001.
4. Production orchestration/publication tests, copied/fake native receipt attacks, source membership, lease expiry, bounded polling, pagination, complete permission scope and fixture-independent policy oracle remain incomplete. AWS guard response fixture currently reuses production guard constructor; replace with independent authoritative fixture. DCR configuration needs complete native readback.
5. Related routing regression now fails 9 assertions: observe/verify returns TRUSTED_COLLECTOR_REQUIRED where preserved tests expect OPERATION_UNIMPLEMENTED. This error-contract change must be resolved without silently weakening or deleting routing tests. Ruff reports 112 errors; configured mypy reports 4 test fixture typing errors and one IPv4/IPv6 typing error in each collector; see handoff logs. No blanket suppression or missing-import suppression was added. Scoped sensitivity experiment and disposable-checkout rollback were **not run**; do not infer them from baseline Green.
6. New context/check-result/evidence-manifest runtime contracts need complete schema/documentation and all persisted-field counterpart coverage. Several preflight rows name planned tests rather than implemented tests; therefore full WFI-001 completion is not established.
7. Live TEST-003/005/009 remain **BLOCKED (OQ-001)**: no owner sandbox/scope/OIDC/health/backup setup. Local transport fixtures are synthetic and cannot establish production EVIDENCE_COMPLETE. Owner setup absence does not excuse items 1–6.

## Quality Gate Focus

Caller owns independent review, final scoped review, task status and final full suite in an isolated committed checkout. Do not admit this candidate to later dependency scheduling as proof. Local tests passing are narrower than task acceptance.

## Working Notes

Record conclusions from delegated investigations here. One entry per
delegation unit: purpose, result, and file paths examined.

No delegation. Ponytail full, applicable ECC coding/security/verification guidance and local impact guidance were read. Initial snapshot resides under the declared scratch root; primary and supplemental manifest validations were recorded. Exact native source URL/hash inventory is in verification/T-006/api/sources.json; official JSON/HTML source snapshots are in that directory. Additional research downloads in scratch/api (BackupSelection reference, DCR rule, metric definitions) have not yet been incorporated in a supplemental input manifest and must be admitted before use in implementation.

Local explicit test commits: 98b54459 (initial contract/component Red), f21f5a80 (persisted-field preflight), 65ee658c (native wire fixture Red). Production changes are uncommitted. No push, tag, merge, cloud mutation, registry dispatch or dependency scheduling work occurred.

Rollback plan only: preserve current candidate bytes; in a disposable checkout overlay the before.json snapshot for existing task files and remove the three newly introduced collector/reducer modules, rerun baseline suites, then restore candidate bytes and retest. This experiment remains pending; never roll back the shared working tree or historical evidence.

## Session Handoff

Populate this section before ending a session mid-task.

- **Current Status**: In Progress
- **Next Action**: Resume in a fresh context by rereading tasks/report and initial snapshot; first add and commit failing native substitution and unknown-ID CREATE tests, then implement fixed logical-selector/native-membership resolution and bounded backup discovery. Do not treat this handoff as completed acceptance.
- **Unresolved Items**: Resource provenance, immutable generated IDs, real positive native observation path, bounded polls/leases, publication/sensitivity/rollback tests, static failures, schemas/docs and live OQ-001. Root retains all status/review decisions.

`Current Status` is one of `In Progress`, `Implementation Complete`, or
`Blocked`. Only the independent quality gate may set a task to `Done`.

## High-risk preflight

Recorded before product changes. First test commit: `98b54459`. Actual initial
Red: `red-components.log`. Mismatch tests construct and pass changed values to
`ReducerCases.reduce`; the import of the not-yet-present reducer fails there.
The **test bodies construct mismatches; no reducer guard ran in initial Red**.
The matched control fails at the same missing-component point. Entry tests are
CLI capability tests only, not field-binding validation. No unread saved payload
is relied on. Later Green and sensitivity runs must establish guard execution.

| Persisted field(s) | Counterpart / required invariant | Executable mismatch test |
|---|---|---|
| context.schema | cloud-collection-context/v1 closed shape | test_context_shape_and_window |
| context.request.path/sha256 | exact original request locator/bytes | test_each_context_counterpart_mismatch(request) |
| context.run_id/unit_id/provider | original request identity | test_each_context_counterpart_mismatch(run_id/unit_id/provider) |
| context.scope.account_id/region/deployment_scope | original request target | test_each_context_counterpart_mismatch(scope) |
| context.dependency_lock.path/sha256 | original request dependency lock | test_each_context_counterpart_mismatch(dependency_lock) |
| context.policy.path/sha256 | original request policy | test_each_context_counterpart_mismatch(policy) |
| context.verification_profile.id/version/path/sha256 | original request and strict profile exact bytes | test_each_context_counterpart_mismatch(verification_profile); test_profile_policy_and_check_set |
| context.native_operation_id | original provider execution ID, never a new operation | test_each_observation_counterpart_mismatch(native_operation_id); native collector operation cases |
| context.resource_ids | explicit configured resources and native readback IDs | test_each_observation_counterpart_mismatch(resource_ids); native collector identity cases |
| context.principal | fresh federated principal, bound to native transport | test_each_observation_counterpart_mismatch(principal); native collector principal cases |
| context.completed_at/collected_at/classification | native completion and fresh collection window; transport provenance | test_context_shape_and_window; test_all_checks_synthetic_never_complete |
| observation.schema | strict cloud-observation/v1 | test_each_observation_counterpart_mismatch; shared contract regressions |
| observation.run_id/unit_id/provider/native_operation_id/resource_ids/principal/classification | collection context, not caller assertions | test_each_observation_counterpart_mismatch |
| observation.query | selected profile check_id / fixed collector check | test_each_observation_counterpart_mismatch(query) |
| observation.timestamp | context.collected_at | test_each_observation_counterpart_mismatch(timestamp) |
| observation.exit_code/status | actual collection outcome and payload status | test_each_observation_counterpart_mismatch(exit_code/status) |
| observation.result.path/sha256 | exact redacted payload bytes and canonical contained locator | test_each_observation_counterpart_mismatch(result); test_check_fail_block_unknown_stale_missing_tampered |
| result.schema/context_sha256/check_id/status | closed check-result schema; exact context digest, selected check and observation outcome | test_each_payload_counterpart_mismatch |
| result.reason/sampled_at | fixed reason enum; actual native signal/check time in profile post-completion/freshness window | test_check_fail_block_unknown_stale_missing_tampered; test_context_shape_and_window |
| result.queries[].locator/request_sha256/response_sha256/http_status | fixed read-only request and exact native response digest/status; raw body is not published | test_query_trace_shape; native wire transport cases |
| verification.schema/run_id/unit_id/provider/profile/required_check_ids | cloud-verification/v1 and original request/profile | test_profile_policy_and_check_set; test_all_checks_synthetic_never_complete |
| verification.checks[].check_id/observation.path/sha256/result | exact collected observation bytes and evaluated status | test_check_fail_block_unknown_stale_missing_tampered |
| verification.overall_result/evidence_complete | all mandatory checks, freshness, trusted collection, no synthetic completion | test_all_checks_synthetic_never_complete; test_check_fail_block_unknown_stale_missing_tampered |
| evidence manifest context/request/observation refs/verification ref/classification | original immutable request, exact collection context/bytes and verdict | publication binding tests |
| operation envelope schema/run_id/unit_id/provider/operation/state/result/error_code/message/input_manifest_sha256/evidence_manifest_path/native_operation_id | cloud-operation-result/v1; canonical verification and collection manifest | native CLI publication tests; related execution/routing suites |

No registry dispatch, dependency admission, IAM changes, writes or signing
infrastructure is in scope. Native positive permission strategy must use actual
native evidence: Azure caller permissions for the same workload identity at
explicit resources, and AWS an exact explicit-deny role-policy guard whose upper
bound cannot be widened by other allows. Unsupported shape/context blocks.
The feasibility and exact API shapes are still under read-only research; no
product claim is made by this preflight plan.

## Handoff qualification

2026-10-18 context-boundary addendum: the preflight above is the historical plan,
not a declaration that every named test existed or executed. Initial Red logs
failed on missing components; they do not prove mismatch guards ran. Subsequent
ReducerCases tests invoke the implemented reducer with changed context,
observation and payload fields and assert rejection; the matched synthetic
control passes. NativeCollectorCases invokes actual native collector methods
through explicitly synthetic wire transports. These results do not cover the
production observe orchestration or the root's resource-substitution finding.
No guard-removal sensitivity experiment has run. The initial red-entry draft
and stale test comments are not evidence of saved-payload mismatch validation.
Full WFI-001 coverage, rollback and task acceptance remain incomplete.
