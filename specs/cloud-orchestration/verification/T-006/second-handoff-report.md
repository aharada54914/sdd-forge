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

Run ID: 01a14e73-9069-76d0-a748-f448ad86b023
Task Attempt Count: 2
spec_revision: 65ee658c1b3e522eced2413aeb55bb897783bf1b
Input manifest: `specs/cloud-orchestration/verification/T-006/attempt-2/task-input-manifest.json`, SHA-256 `7b7a7e3c4850ed8407f9ddfcf080865ca44f3de6d17aafb9d90ed65947b621eb`

## Target

cloud-orchestration T-006 only.

## Summary

Attempt 2 has substantive corrective progress but remains **INCOMPLETE**. No Implementation Complete, Done, independent review or quality-gate PASS is claimed. Root owns those decisions. All seven first-handoff groups have been revisited; unresolved acceptance work is enumerated below, not hidden by local Green.

Both existing collectors/reducer remain prior candidate code. New AWS original-stack logical selector resolution, both providers' recovery discovery, Azure compiled/original-operation joins, protected fixed-phase completion proof, credential lease checks, closed schema contracts and synthetic orchestration tests were added. Freshness now bounds current minus sample, with bounded recent/post-completion metric requests; committed Red c65f628a reproduces the old deployment-age defect. Native GitHub completion uses an authenticated successful literal APPLY job with pinned W/E and exact request/preview, never ARM timestamp guessing or a fresh observe clock.

## Files Changed

Task-local test/evidence/report files; cloud_verification.py; both provider collector candidates; AWS native read allowlist; Azure inert governed template/local caller; both optional observation config schemas; provider observation docs; closed collection-context/check-result/evidence-manifest schemas; routing typed-error expectations and contract inventory tests. Other prior candidate execution/local/provider files are included in Outputs as necessary dependencies, not claimed as new attempt-2 implementations. No task/approval/frozen spec/registry/profile-dispatch/dependency scheduling/release changes.

## Tests Added Or Updated

36 verification tests (plus mismatch subcases) now include actual provider collector methods and both original prepare/apply/observe synthetic orchestration paths. Native raw XML/JSON fixtures are explicitly synthetic. Both end-to-end healthy cases reduce to PASS internally but remain public BLOCKED with evidence_complete=false. AWS created IDs are discovered without altering original request bytes; healthy substituted resources, copied operation journals, stack membership fields and expired leases are rejected. Azure original run/job/workflow metadata mismatches, compiled/native resource substitutions and literal phase separation execute real guards. Mandatory versus optional backup is tested with real collector dispatch; native denied/missing/stale/unhealthy branches remain.

The old misleading CLI test name/comment was corrected: it tests missing trusted-executor admission only and never claims an unread saved payload exercised provenance. AWS inline policy fixture is independent of the production guard constructor. Routing behavior changes only the expected observe/verify error to TRUSTED_COLLECTOR_REQUIRED; zero-write/output assertions and unrelated phases remain. The fixture setup was moved to a common test base instead of assigning sibling class methods, preserving the 86-test inventory while satisfying accurate fixture typing. Contract inventory now explicitly tests the three collector-only schema families without changing the standalone artifact parser or dispatch registry.

## Outputs

| Path | SHA-256 |
|---|---|
| `contracts/cloud-authorization-receipt.schema.json` | `5c4f8efaaf458aba6f149a53967df7615eaf2a823c4ec6f75e44610a4c8ac8b8` |
| `contracts/cloud-check-result.schema.json` | `992b8f4d530d4aab0fe5bca1a28b459a6c9cd9bec7e6ed68b648f489127617c0` |
| `contracts/cloud-collection-context.schema.json` | `7706241bf1a949a64b18212ba09bd8a4aa66896df668084056ee6979fdb84272` |
| `contracts/cloud-dependency-lock.schema.json` | `e72395e755f13bff50f8f10d27a8181fcfa1894ef6c60499c01f84d4c2128cec` |
| `contracts/cloud-deployment-policy.schema.json` | `a064217e4a68838a3d719749fb751ba63ffabb2094d16cf13090afeaed080eb8` |
| `contracts/cloud-input-error.schema.json` | `d228ad47ea2c899022169a704c9408f6b5fee285be5be12ad3f0906bd2b4bc77` |
| `contracts/cloud-observation-evidence.schema.json` | `0d0dfccf3bd5982a2948a9db75fd459197b6bb683f19a993b5bfdce72df1d99e` |
| `contracts/cloud-observation.schema.json` | `5ce80d6fb77fde9bc966d00db75c2650f3a37166fcccfd1071f087208191c826` |
| `contracts/cloud-operation-result.schema.json` | `a92bdac86499052256112babe5ff559c2e071adba411f4a2e92ec38b6b5b2aa6` |
| `contracts/cloud-ownership.schema.json` | `71079e7320c968bce57fba67bd105d59ab57c00a51165a3598d522919141f25d` |
| `contracts/cloud-preview.schema.json` | `12afaf962e1bf1325496d985b21ffc5c970c1e2d14fc43933c5ad8aa8940eb99` |
| `contracts/cloud-run-request.schema.json` | `781d83fad3d8e883e2c4aa886c5356da12f93d5ef5e35f16a5d83e9c024c9d81` |
| `contracts/cloud-verification-profile.schema.json` | `b25112c7e73583b180941639cb8f137a89fcb7daa82b1afd7ec8eec66c9353bf` |
| `contracts/cloud-verification.schema.json` | `dcfd0760733951080efc1f0cb993bfc46a081b4eff4a82bd07968f868b2f3f2e` |
| `plugins/sdd-aws-cloud/examples/private-ec2/README.md` | `0caceb7832a0c3e467042a760789f03a47521eaca375e712ea15120931e2ea5a` |
| `plugins/sdd-aws-cloud/examples/private-ec2/app.js` | `710c6889188eac80e9f5e6b505c3796ded52747c9a56c305c58a53d05f3c2b25` |
| `plugins/sdd-aws-cloud/examples/private-ec2/cdk.json` | `7802e394180f0d618f4caf7d1a6647f406ad327fa0aaa38c84b8b6b8471b24a5` |
| `plugins/sdd-aws-cloud/examples/private-ec2/package-lock.json` | `b106084fff5e18ca94260509133337891b58d5269d77166ff9320a36419cccec` |
| `plugins/sdd-aws-cloud/examples/private-ec2/package.json` | `beddc07bfbf3d198ca58b3d500e746b7bd4ebc14a25b469033fb1c41ba50a00b` |
| `plugins/sdd-aws-cloud/references/aws-local-config.schema.json` | `1d8d1f63b8f2ff4836058d928752c5322b744727e03b14d2e34e1ec6b9d25f22` |
| `plugins/sdd-aws-cloud/references/aws-local-evidence.schema.json` | `d64402c81095bd9a0657d34f4723a02996d91bb93cb0d0906c4ca288aeaa3187` |
| `plugins/sdd-aws-cloud/references/local-preparation.md` | `2a890269fabb6128f125f5533d3eb4c6411589ca0d0843b642b47cc959f7a257` |
| `plugins/sdd-aws-cloud/references/observations.md` | `d1a030599615d1fc6cfe43f45868944bf06f8057e39950dcdb499ffa8e41e707` |
| `plugins/sdd-aws-cloud/references/toolchain-lock.json` | `c46bafb8869840c879739f424746eda64ca6c62aafab906d9e98012dee7c3f5d` |
| `plugins/sdd-aws-cloud/references/upstream-lock.json` | `1898ede044cc25e0fba804077559544f5f58e9e323d8d0701721b8545cc97766` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/SKILL.md` | `af178f8e909efd66496b09c7301c5e11ef96681fd62bf91406dcb340a18aacf6` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/bootstrap-and-project-setup.md` | `ce48bf13921481aa6d2df131f0bd32faa8cc07bb50b63b1805ddbfe6ca18a5f0` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/compliance-and-drift.md` | `4d576be561b16fd140c7f44de3b905ca81718752003a5072fec7062f2a2e782c` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/construct-patterns.md` | `029a6450cc738c220051c1e2df94cb08e82b9fd80b20ab6b1b31696015222d6c` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/fast-deployments.md` | `b6ddc7a418ed0d2f6e450c1835e3dc83c0648cbcdf4b582ebd66234918b22171` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/import-and-migrate.md` | `375e247190c3ebe29b2b8b211f665d4f463c7d959d3a6a067f8816d1a5df3a26` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/refactor-and-prevent-replacement.md` | `bdc1dacfaaaef810923699fc19803b492815b404190f055f90bd3558587b335c` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/troubleshooting-credentials.md` | `87b36861e1cf656fdb576536c20c61dfff5316e1b7465954f9b1b01cce0f0ee0` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/troubleshooting-deployment.md` | `80b97fe332046fb025cf6635b3add76046bf9b2933bd45394255585f1694a967` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/troubleshooting-synth.md` | `1397f0c8034ccafd1353c3053d119e721c4904b9dc2ba33a1f285f69bfb909ea` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/v1-to-v2-migration.md` | `f88efb1a4b7451fe194e5c617ea2c467be93ecaa7221264b80361cca035dc181` |
| `plugins/sdd-aws-cloud/scripts/aws_control.py` | `92842d7174dbb0bc8ba3ad796fd8a3bd7f46ed91178dfa80bbc6558762523d67` |
| `plugins/sdd-aws-cloud/scripts/aws_execution.py` | `69ba7b8b9fe43c1ddcb0a7af0b38f2c5f60affc7e86d02c3710e8a168b5974f7` |
| `plugins/sdd-aws-cloud/scripts/aws_governed.py` | `33dd06c2b3130d1357938f4b9f077aa6d855149a690d69fdd06d55f94e0cddff` |
| `plugins/sdd-aws-cloud/scripts/aws_graph.py` | `21896c758e64f5db7571c2c5209a4ab122cac8347dc18096c29e79f7396a42fd` |
| `plugins/sdd-aws-cloud/scripts/aws_local.py` | `82bbf762e80d62abdc77b56f850729c72d4ae83c3e59f4de09751867f16e4b31` |
| `plugins/sdd-aws-cloud/scripts/aws_native.py` | `1e2ea86be1852796c55c3858d40bef1afbcdc0594a95b0b160d88d1e5c817855` |
| `plugins/sdd-aws-cloud/scripts/aws_observation.py` | `56759940ccd05651c66e8458e7987d61f3eef845bce52bbf8db4e4bd39516d36` |
| `plugins/sdd-aws-cloud/scripts/cloud.py` | `167b3e37e88a5ab1c32344e226823ae0e9d1518d7927a7ab4221422a011cc933` |
| `plugins/sdd-aws-cloud/scripts/governed-setup.md` | `2bd8c9b4ddcd7d9879a5b58d1e7c30d4d9c8c0286501b6b4d066eaf967712578` |
| `plugins/sdd-azure-cloud/examples/README.md` | `18d4bac06d053a486ab77936c75cd7e4f0824fff90728431cbfdf7f89d9cc873` |
| `plugins/sdd-azure-cloud/examples/private-vm.bicep` | `81ba478fb3744e96496243358f3aef3477646027a58e1220f3c16b7b428c9422` |
| `plugins/sdd-azure-cloud/references/azure-local-config.schema.json` | `3950a56bc88e50c7ed498ff66d45545b302864fd972abbaa625d897a1ddc40cd` |
| `plugins/sdd-azure-cloud/references/azure-local-evidence.schema.json` | `e4584e317609585b3effc865412757ef730448d814b2ce7f78eebf485728b68a` |
| `plugins/sdd-azure-cloud/references/azure-parameters.schema.json` | `5922b55565b1a506db4cc424560cbfaa0b07766f1e26bf50dd4247ade18fc3ae` |
| `plugins/sdd-azure-cloud/references/local-contract.md` | `68850cae945e1e5357fedb284079cce67fec809a07cd1a35f6f923a39b89fdfc` |
| `plugins/sdd-azure-cloud/references/observations.md` | `7918d116b540160188b31cb5e8879fa8e9391824224ad3303aab80735553fe24` |
| `plugins/sdd-azure-cloud/references/upstream-lock.json` | `f7e22249f21c062e6207579460b1ad1042af52e4eb619d8566fd4d99db675644` |
| `plugins/sdd-azure-cloud/scripts/azure_arm.py` | `5ee98cf0fde60b1d8e9959cf17e7eb6e53fbaf179104ad0e080b849f936cff86` |
| `plugins/sdd-azure-cloud/scripts/azure_execution.py` | `cb8b14a85e305431aaf80eb568620aeb42b724aa13f485251338f9bde70c360a` |
| `plugins/sdd-azure-cloud/scripts/azure_governed.py` | `a4a759aca319fe34382d0dc0af3a409a3b54522e9e84baa88e584dfa95694a0e` |
| `plugins/sdd-azure-cloud/scripts/azure_graph.py` | `f46bdc77c12449d0f4befd0221b29687e7b4f48685cc6106080de62b3a4d075f` |
| `plugins/sdd-azure-cloud/scripts/azure_local.py` | `43d37a2ec9ae8e5bfc60690480c7ec607237b03b4c3d6fbb7f1e8d2ee7792f10` |
| `plugins/sdd-azure-cloud/scripts/azure_observation.py` | `75b58c3f6a1e100d82feb31f77b2ef406ff03d176d577afe91ad8cae5506d021` |
| `plugins/sdd-azure-cloud/scripts/cloud.py` | `4ae02ced280a8267a99fbd18b92d5fbd7a61b3d3e64c369b02e02c63c15b5636` |
| `plugins/sdd-azure-cloud/scripts/governed-setup.md` | `b2f038ab953175e2fab863d5cc8baada77a79c0b8cef1281df68142831343388` |
| `plugins/sdd-implementation/scripts/validate-implementation-report.sh` | `430e0e45c6bb417cd65f7f7f228bb59280d6d0817c8b34236223b8fbd4702029` |
| `plugins/sdd-implementation/scripts/validate-task-input-manifest.sh` | `5e209d11c50b9c580572adedee0c500fcc48233c1cafe5d22d08318c52059f73` |
| `plugins/sdd-implementation/templates/implementation-report.template.md` | `0c926d76c0aab214fe305ad5974dc6636aea81cc2764a0b37292ea61cb4f1f75` |
| `plugins/sdd-quality-loop/scripts/cloud_authorization.py` | `b165a6aa307a25721a63607f3c314bb6d290b1e1e450006be66c9a7d208ba916` |
| `plugins/sdd-quality-loop/scripts/cloud_contracts.py` | `c11225de15d8944a4183085b3df98f7b4da2d87227c473ad4eedde377b51164d` |
| `plugins/sdd-quality-loop/scripts/cloud_verification.py` | `76388e9f22feee45ed34a72e6b65cd45869fef38cc8bcb493b4abf0a525caf55` |
| `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` | `d19f258b904dd168410f184f7854d47a3790319832b5bda919b3f7049ab41a06` |
| `specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream/LICENSE` | `8a5d8efb70942e65032f930c761d097feeb41a7517ebd04c9d2e4ec3764071c5` |
| `specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream/reference.md` | `a4976e733b7793b0014b3be1d5a1c5282002ba16dd7be9a7fffd509c800b5505` |
| `specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream/skills/azure-compute/workflows/vm-creator/examples/bicep/README.md` | `61a52989ee67dfe4ee30aeb88a06bd15460d3d61d9f1101f3d0d58c19d1e4852` |
| `specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream/skills/azure-compute/workflows/vm-creator/examples/bicep/main.bicep` | `6fa0bd982a36436cc4a6929ce5a8bb2fff748248d2865000110de0a18ef51b5f` |
| `specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream/skills/azure-compute/workflows/vm-creator/references/output-adapters/bicep.md` | `ab54837a3cde78093ebb59875c0cb1f471c57ee786d8b7d417f808cf94b56439` |
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
| `specs/cloud-orchestration/verification/T-006/attempt-2/api/azure-dcr-rule.json` | `fd6dfe97584e643746b44bcb2d170f6764e1c74e79dd26b848dcea9dd6630b2b` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/api/azure-identity-closure/acquisition.json` | `72f57d1fc14a08103ee7e926127898c8c08813149dd7be73ffde07bd2784f3c5` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/api/azure-identity-closure/docs-acquisition.json` | `2034dc8ea3d9775bfb089bb18276dc2bb909901a5c7a65bd1ebbbdcd87895b4a` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/api/azure-identity-closure/list-rest.md` | `5a9f1d20ba042b5ab8a105faf19c996a72e42be250e485a655ec5493b8ad63c3` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/api/azure-identity-closure/managed-identities-best-practice.md` | `a4deef7ffa3b1da0bc5f6ac6cf6700927ce6c58faec05267fe6b90c155fd4a29` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/api/azure-identity-closure/role-assignments.json` | `0a4e9a83b672454c9005edd88fc7adde48a545a553cb6c74e921a72af67b5f43` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/api/backup-backupselection.html` | `f0f99a5a152a8db197542b3c77ea5546e0cc61a4d7c8086e6ebb4f56c1df9951` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/api/cloudwatch-alarm.html` | `f823f042822008f620d3bf9524413f07b84a84ebdbfbb272581454dfe2c0aad3` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/api/ec2-instance.html` | `f9d0241ad8d0369adac8d77267242168d851601e1c81a0be0754428d738bc4b9` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/api/ec2-securitygroup.html` | `0c8eb960911a6dd9710829bdd023efcd6bf1bc4e2732bb596bc6e1b15e9324b6` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/api/github-openapi.json` | `3177ad6a86ca04c57a9bef3fc24e28a339efb8eb040c6f950af3d3ed2fee7fa3` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/api/github-source.json` | `308b3b5f6e6ee3f514c74f4f9337a8388e17ede91c2c676ffc8d1ff30844561d` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/api/sources.json` | `a69b3354e6367b5817d2668368596e5bc4c3fbf9f22ca3ab0ccddf0e56184d48` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/azure-orchestration-first.log` | `9f3aadd1843907199299d9e60414b92211ed07bda5ad6091e09e145c66a6a971` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/azure-orchestration-second.log` | `2c15ece921cfef3891b5a7fa0597f707b0382650b5651f1c80908e6d9df4c1f1` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/azure-proof-test-exception-identity-error.log` | `2f0d2867e5a81974eed3d8615872e6db03a1e8c06975ec74f57b067b2fbc4837` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/baseline-routing.log` | `5635a97ce16188e28ef0acf2e578e4dae703f1f2b38e72f5a9d5c9fd03b710cc` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/baseline-verification.log` | `682b4f4e51c1a5ff0a6267bed57ccbf23c4b1c849a80b788c62403cbd225c81c` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/checks-invocation-error.json` | `3ff2f98a04d04dc17e71a190e66232fabde3bbb9c99b449cf27f8bdd83143bd8` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/checks.json` | `292d93f175049860420ae76bf34cbd39bfd9d81bc656a779cea7cc3c1185c4da` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/contracts-repair.log` | `795ba56aaa4aff0a968d471689cd75528f49a74e104d9456f0ac3bac308ad022` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/contracts.log` | `3d97e6a6744a7641f330811fd230bccdddb87cb49b968dc9255a9e2eed730dc3` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/dependency-input-manifest.json` | `99057d9d6c8c2e8d0f7161a3f3f6a926875bf1fd2ea73a858d289e32398801ba` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/dependency-manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/execution.log` | `e5cc7f6462f69f17fe1c2d7cabd2565899855b658284f6f3d98496030765371c` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/freshness-input-manifest.json` | `3799cedbca17a3f64fef27e44532561456d59157d17b281b9ccc79035665bf3b` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/freshness-manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/freshness-native-window-controls.log` | `3d48cfefe3391a50a0fe3852981e64f5c8a13b140338e80881678363b44c81d2` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/frozen-input-preservation.json` | `61f66de55a350a9d84ae16eb26e4fe8774215de915bbfac86976e8562345cb25` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/github-input-manifest.json` | `8bd943862f4865ad734322eadcf7c7d2319247e0ffb7389ee3ffcb16efc21cbe` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/github-manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/green-azure-bindings.log` | `e760d16b14b455be97a9c55f73bf55296c7e91b78d309b1af3ad032693bad050` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/green-azure-completion-first.log` | `a958eab61cfa7841cd29102e3eb8c31994f6bab146a39b1304f77a555c7a5666` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/green-azure-discovery.log` | `3ea8a02ca6a77f2c37806474ee48edb1f70d168e1181d8d210d9c0e41baedb65` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/green-azure-incomplete-native-proof.log` | `5891ab87abc9a1f42d90f6c5f98f2be619057c772f98879bacea1a177d40ff9e` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/green-contracts-orchestration.log` | `745ebea849839cbc7ef429d98fa405abef47e9f251ee0c5b8b38e726d8abc07e` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/green-first.log` | `281b475a11d503199a1921bef2232a394e92f5b724747ce3f3817b895b681b38` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/green-freshness.log` | `d132ee4c8fec51112463baa5bc716d18192b34de2b9eda18d34dc5e478cc0f06` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/green-second.log` | `8ce7daa9257be5055c72f9e631c3e99c4b958961f09af07e6f2baf985fe96db2` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/identity-closure-input-manifest.json` | `8892df4ddc3ae7d3617787e025d4d224768acf85e6305b6bae524f2bd239e077` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/identity-closure-manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/input-preservation.json` | `f52d3a684547bb6de2dde128c3f633c07d56f9fd1ff4cd0949dbc05e544fa926` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/local-verification-summary.json` | `b77f388eafbd2ce6220bd7f3a261b19b4d6721aad67746a566e7b587d7864b35` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/manifest-validation-execution.json` | `28e771c0c111b6dfaafbf669d2f602260d95709c49ac7ca4831796f69ce4aea4` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/manifest-validation-final.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/mypy-aws.log` | `d9c6451deed8166744636148c3a808ad57fbe9af67eab4c2d2f502106867b836` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/mypy-azure.log` | `49a37f28c04d8a7b9a4e4457f3008845f2b1a74ded46076c9aeb32ec4150c0eb` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/mypy-shared.log` | `21e61c438f2c045fe5796f8a3d8f93c99a9a3ffbcddf93ffe49a0facf8341b98` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/native-events.jsonl` | `0f629d91c939efb62d57910eb4a4df978e5980aa14ae09e4fcaa52a6dc8ad423` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/red-azure-completion.log` | `0eb33bbfb2c18c5623a956f476f74fa3d63641a6d96e5e0b47f71559e3313c79` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/red-azure-discovery.log` | `952f51ec50a21ab4091a6a22553578a7f94313a76d60de0893566b66e2f7e00f` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/red-azure-incomplete-native-proof.log` | `639c2fde9cdff913982a896ad570b428b22834d9598befc2433b132737b1062d` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/red-azure-membership.log` | `8365cfbee4c25ebeb1b0e6db1782b92a5f8d9d36cdfd14b45df6d48a329e762f` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/red-corrective.log` | `aaa4f72d13f453b16f5f090471c0e1dd07463f9d9939b7fea12dbf6bd1a83ac8` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/red-create.log` | `e3d388f0b534e3eeb8e14549e73480019d7e97a93e0e701f62666546c748584b` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/red-discovery-lease.log` | `266bc0631fbe1eee76571f130ae6ff374f5953c83ad4e3cd84dcdefb47ecdf67` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/red-freshness.log` | `fc943a95c13b06e8a9da4424b0778ebc743f4fa66da9ec24705e098d5ed46c44` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/red-http-outcome.log` | `dcafe0a61e949f925e022bac1a1a1865fb28a602e670ea0afeaf80919ea7f3dd` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/red-public-contracts.log` | `d3e45f6dbac568e711ea2e7a00d9fb22add0b9029b9cb4c892c151f90075ec4c` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/red-substitution.log` | `a66c465311395bad377b9d39201cf51a717127e55edf62dd05fec5ba244b6190` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/regression-input-manifest.json` | `f868697a8d941503efd12e88e0d2169830aad779045ffaf5615594498ca756ae` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/regression-manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/report-validation.log` | `a0eb36646f9654b7ef1b674fed63ad247a1febe005869fbf36ce295f5437a10c` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-before-freshness/rollback-candidate-verification.log` | `9154d8b1cbccc0c198ea330415402db68a38d771f214f4c433ca6e334f69fddf` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-before-freshness/rollback-create.log` | `1f1a7eddc92faf5d19b2bf6a5839779d46c153c9d7fe5853627040ac3d63be11` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-before-freshness/rollback-driver.log` | `281276952822b7b887a6f324c04ac3dd2418654b561724a39dd87645495974dd` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-before-freshness/rollback-entry-routing-known-red.log` | `3c570b7380cde4de0606ddbd2c717db5c5dd9381cbdd386ab0f09819766044e8` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-before-freshness/rollback-entry-verification.log` | `f5bdc009961bb8a1fb98659864ffeaddcb94e69ca8f019c4daaccaa0891a06d2` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-before-freshness/rollback-reapplied-verification.log` | `9154d8b1cbccc0c198ea330415402db68a38d771f214f4c433ca6e334f69fddf` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-before-freshness/rollback-remove.log` | `0b28e4a2da3095d99a90c3fb90ebc34513c53abd43eb80835041262752576773` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-before-freshness/rollback-restored-verification.log` | `a514a76571a89e520eba0de653a7480559e5a4e0847e86994175d7083a4c709a` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-before-freshness/rollback-sensitivity-restored.log` | `07cebd77757505623d28013aea57b91442e53209ee5ea0cc31ee98215346e7d1` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-before-freshness/rollback.json` | `b86c4c5b8ba88fafd7e691cd1c93f4711ea05878dc72d9431e843a0bcdb07c92` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-before-freshness/sensitivity-context-binding.log` | `95c259190122dfc2e60cfd296ac41de88b45ebd6c39f1ce52d68ee8ef59e4492` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-before-freshness/sensitivity-lease.log` | `ea6370bb936f8df15e4ced9f75b755f22c73f8000089d6ec9792653734b9b96b` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-before-freshness/sensitivity-membership-logical.log` | `1be9837fd6752ab3b3d5bed22c76253ce848f738c2770f3b8d700d79804111f4` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-before-freshness/sensitivity-membership-stack.log` | `464b4d56a40bb5d6da8d26a8fe58e87c6ea3e923a651533dfa17855f24b46bd4` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-before-freshness/sensitivity-membership-state.log` | `def6274dc0f1c53d624428c8106cf8fa710e0c39a7f296d31f316a446a038764` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-before-freshness/sensitivity-membership-type.log` | `625430c38168d7b1eded1c9c09af991ad4e1529a24f6615b3a94df12eb86b5c6` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-candidate-verification.log` | `8428c3397373ee0e42639a7c6359931afb0ac17c8458c2335fd18b5c7d39693a` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-create.log` | `1f1a7eddc92faf5d19b2bf6a5839779d46c153c9d7fe5853627040ac3d63be11` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-driver.log` | `a3744edb2f88afa2ddc536bafe180b48a320d073c7c380bf0f27d2e1e70bd144` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-entry-routing-known-red.log` | `82f04e127936bcc3ab4a3a63f13be5c83e15d4f8a02c5f1a47149eedf9b79fc9` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-entry-verification.log` | `d7227d27ab7659a8397426627dfb9896ee2a712ac6affc8cf64ffeb89d8e6f1f` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-first/rollback-candidate-verification.log` | `45b420497a022e6123c5b80c903f68e991d4ae6f6a2a642f0c39abac5e18b682` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-first/rollback-create.log` | `1f1a7eddc92faf5d19b2bf6a5839779d46c153c9d7fe5853627040ac3d63be11` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-first/rollback-driver.log` | `4ff433e4bc2350f69b9806c5fbf9d9c705670036537f834a550dafb77bbbe5ef` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-first/rollback-entry-routing-known-red.log` | `93c0b92df53ffdd55331642e3f5e4b396668fa591260f6427c07b9918042b732` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-first/rollback-entry-verification.log` | `08e706a8a31038bd6e70d6a416b2dad005d010f2400390b1bc3af3cac09f755f` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-first/rollback-reapplied-verification.log` | `f2ca243371ada761fcfd9f62bb29e8924fa851435e70711ef957423d086d5cfe` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-first/rollback-restored-verification.log` | `ecf2b7a01601ce7a901f51a79b1272ba2820a8c1b96e1c8ee3ba9e037ccb1e5f` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-first/rollback-sensitivity-restored.log` | `bd653e6784e73223c42110a0dba33910d20b6d2910b995ed6375d5ec2cb8d391` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-first/sensitivity-context-binding.log` | `ba6a16ac4d0a836d4d5eaf62c03523c1e45590c29f95bbbcbe6f9c74a13ad8a7` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-first/sensitivity-lease.log` | `641b9512f086eaab4cd88091b08d5265274e076fc271ab57afafeb468a2225ec` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-first/sensitivity-membership-logical.log` | `c26ee5b9bcae3e3f0b87d91fd02619d30de62a6e3f6398ba92ba6dd7e4cc9202` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-first/sensitivity-membership-stack.log` | `f0b7e495e9d466fb93ed014308d2a719d0f84cf723716addd2d980f679f98da3` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-first/sensitivity-membership-state.log` | `764e52f1f8db2376f00f7d803b6013aa133ab4098ad1c0a0556946c311f37375` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-first/sensitivity-membership-type.log` | `8ca6df01343b7ca35171e01457a4896e84fe900eabd8958811461fbc4e86f6fe` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/rollback-candidate-verification.log` | `2d6053745d244a2583c41c5fda52bdc6743b179d5d4233d187687344ad23d7cf` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/rollback-create.log` | `1f1a7eddc92faf5d19b2bf6a5839779d46c153c9d7fe5853627040ac3d63be11` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/rollback-driver.log` | `22688eb374eef671a2713aa5b6a004e25df5ac61b7dfb942cc31ccab2850436e` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/rollback-entry-routing-known-red.log` | `39a7b46066ff5b7e73b8be0a1c19d845f4e68f7c5184b00bcfeefedc45823540` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/rollback-entry-verification.log` | `0bdc8d71a9b0741dc4d06ca0b430e5e7f138e5600123edb830aa9644a3ab5091` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/rollback-reapplied-verification.log` | `171efa490a6900d115d4ecd2e66ae9fecd96711dca7cff4e2a4dac12e1725837` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/rollback-remove.log` | `0b28e4a2da3095d99a90c3fb90ebc34513c53abd43eb80835041262752576773` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/rollback-restored-verification.log` | `a5ab4401dc3b4503f493ce881580e8189e9995e0e92fbcefa46556639e8feb59` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/rollback-sensitivity-restored.log` | `4e431099d6ba3e1d016c3c2f15c8826f84dc3a5b410d6482514396445109af46` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/rollback.json` | `1ec4817f1fc226a00e357533db9cb4f8d348f671ba682a27ad5c28931684dc47` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/sensitivity-context-binding.log` | `95c259190122dfc2e60cfd296ac41de88b45ebd6c39f1ce52d68ee8ef59e4492` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/sensitivity-freshness-current-age.log` | `7782ff96aded3d1ee3d6d128d22f263bd404bcca36f5411a1adfc1c7254b9540` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/sensitivity-freshness-deployment-age-regression.log` | `53d8fb6a05d26c82d42deb8beb634906d8b832c432ede3d33d3ed18c22420740` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/sensitivity-freshness-query-window.log` | `27972202f73077765be4f5d30afb777e23c7ceccb70fc93623650baba085d1c6` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/sensitivity-freshness-time-order.log` | `3c3e114dc7794f0ff85357aaf17729f1853eb7a6f77933df8deb34ababd381cb` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/sensitivity-lease.log` | `d28eab918a637d1669415e2446586b67f6123284078425cfeaf0d145c459b5c9` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/sensitivity-membership-logical.log` | `b1e322b9efb844e0e55a9d534eb9bbeb07464fa1b48ffee94378a684263b8833` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/sensitivity-membership-stack.log` | `a768d23a710e51fad11990329d80f7bc11ceccbff1a44cbbc81565c06efb24e6` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/sensitivity-membership-state.log` | `a292a567b142c4f66d94c1d763fc6760910eea51899bbe323e1070e0e57e14cf` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-missing-routing-dependency/sensitivity-membership-type.log` | `e3bf8a9f5292d490dda014badfa5e25062a4854b682326d90a115106e75983bc` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-reapplied-verification.log` | `a942aa3bb43db1fe9e71706b6a9ab271ae24720fba90919555278de822341748` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-remove.log` | `0b28e4a2da3095d99a90c3fb90ebc34513c53abd43eb80835041262752576773` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-restored-verification.log` | `9383d2d052ba3504c9c7410e4c3ecda578ce788cf63e808f8b55133d6d70f8a8` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback-sensitivity-restored.log` | `0ddce2c8fc24e41688a7e0353029325b29cfd5f8e9b33517c72aa516f3c06c6e` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback.json` | `1e8431119e4172eb5685dda4aceac8984f811491e52a1f7584e2e07cefb9afe1` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/rollback.py` | `a662521ff6357ed07ce7293ed712099208f1e45e191d102acc97eef1dc2e5107` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/root-azure-permission-research.json` | `58d3815fcc164d2b14d3f64aae61be77ac747fa55c4f2f21155547af6ab61de9` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/root-check-driver-feedback.json` | `881c0d3beb83050a3f00e4128604added3de2adf236d20346142b7b2c391e330` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/root-completion-workflow-feedback.json` | `458989739b438b97797777615f2399599cf0d238b9e0605b2417f03395b27a5d` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/root-freshness-feedback.json` | `ce255753ca795b19cdd7d0a5e0e33eb29be986f74cbad214f7a01d92a573248d` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/root-freshness-probe.json` | `8a170c41a538c0821bfe46a810cde15f55fdfe0713fde5d1d4df63ab853eeef7` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/routing-fixture-input-manifest.json` | `d5724228d899c13fdb92f7c25239e96c947872156693a4eed4088ca283bd2836` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/routing-fixture-manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/routing-invocation-error.log` | `3f2c22c9d148a98ae3ea0411fe0ebb7bea4678dc03bd4757d161e2fa7cab1fcc` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/routing.log` | `2df9205944cb6eb199b5a2f986e7367dc1b1316b302e153d3b28b88e04291f16` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/ruff.log` | `6ccdd4d86cc66364f64c169216f406b921e4ee6cbdcb27323cad968634574c7b` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/sensitivity-azure-incomplete-native-proof.log` | `723070bdf8a560311adb39329b701e18cc795e7bb3802ca9db1a319d7cf552dc` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/sensitivity-context-binding.log` | `95c259190122dfc2e60cfd296ac41de88b45ebd6c39f1ce52d68ee8ef59e4492` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/sensitivity-freshness-current-age.log` | `7782ff96aded3d1ee3d6d128d22f263bd404bcca36f5411a1adfc1c7254b9540` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/sensitivity-freshness-deployment-age-regression.log` | `599c10b65117f710969a177f87e6ac84ab9fccf031ca09bcb407faafe57971df` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/sensitivity-freshness-query-window.log` | `915840df87612ef945b15fd27a5633c5a46a94066189db92355d76e9cad2aa67` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/sensitivity-freshness-time-order.log` | `3c3e114dc7794f0ff85357aaf17729f1853eb7a6f77933df8deb34ababd381cb` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/sensitivity-lease.log` | `1efb97a46eebb6eca2feaa0e7939a9dfc77788e725f0e24f0ef156c2d3eea71c` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/sensitivity-membership-logical.log` | `5f18757b8cbfae6866f103248ab783119f5b8c1b9bc12109d3741895132f1379` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/sensitivity-membership-stack.log` | `e7d8323824358e5462c1393fb04d0667b7e80be229a8d75a9dadcf96a151e202` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/sensitivity-membership-state.log` | `e3360de85928018ae22c8c87552585c68aaa73446a48285931859a2e1be7da62` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/sensitivity-membership-type.log` | `2d513e8cf5151bb8893518b2a02dc41045d0d1aa08af100155ec5e7b9a5ca7e2` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/source-input-manifest.json` | `d25164b6a8978dfc73e986c6f3308a653becb0c5a79c0dba37c956493ed86cdc` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/task-input-manifest.json` | `7b7a7e3c4850ed8407f9ddfcf080865ca44f3de6d17aafb9d90ed65947b621eb` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/tools.json` | `908f35d4c5602a8c725d5228f51c303ca209ac801168699d96da3e0e05ece1b3` |
| `specs/cloud-orchestration/verification/T-006/attempt-2/verification.log` | `25d2662aaa044bb09f0b160261373527f45b5d68707a77ee53a809e91aa41335` |
| `specs/cloud-orchestration/verification/T-006/first-handoff-report.md` | `1789c28cdb64af422c7b311065541b397415a5ba951b23f6c4d2695c53792926` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/config.json` | `ccc52fa5eb81253dec9a1edcbb6376c4f363cbcbe5cc6cd25e16bf51bdf1e6ea` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/generated/2171d811234c76745844acbc612901606f70bbbf00cace71420a7e4467b8972a.arm.json` | `5d433080a667406b0e7372252cd1e3cace0fee1b505a295dbdc65561c6e96c7c` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/generated/2171d811234c76745844acbc612901606f70bbbf00cace71420a7e4467b8972a.request.json` | `aa2abc4ddb432984ac48c57fdfe46778ea2fbe8356b6edc58307453324ed96a0` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/lock.json` | `5d2f63bf39f892ae40d578f257af645bf1eccbdf468f4fb047a4187157a797c7` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/ownership.json` | `5405208196f15113bc06f82ee538997a19415517561e79a07f0077259ed2022c` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/policy.json` | `ca75f6b9e1a6362ba36fa496974bff564a957003f73da3f32443f412469531e4` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/profile.json` | `4ec5f27f718f26f6086dad4216fc8e1a909aba5fed9ba971575c7d57c69747d4` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/unit/main.bicep` | `81ba478fb3744e96496243358f3aef3477646027a58e1220f3c16b7b428c9422` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/unit/parameters.json` | `361d0679465fa218a24786f54017a8b4441e8baf9691a4efdea02bd600fd0935` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/upstream/LICENSE` | `8a5d8efb70942e65032f930c761d097feeb41a7517ebd04c9d2e4ec3764071c5` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/upstream/reference.md` | `a4976e733b7793b0014b3be1d5a1c5282002ba16dd7be9a7fffd509c800b5505` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/upstream/skills/azure-compute/workflows/vm-creator/examples/bicep/README.md` | `61a52989ee67dfe4ee30aeb88a06bd15460d3d61d9f1101f3d0d58c19d1e4852` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/upstream/skills/azure-compute/workflows/vm-creator/examples/bicep/main.bicep` | `6fa0bd982a36436cc4a6929ce5a8bb2fff748248d2865000110de0a18ef51b5f` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/upstream/skills/azure-compute/workflows/vm-creator/references/output-adapters/bicep.md` | `ab54837a3cde78093ebb59875c0cb1f471c57ee786d8b7d417f808cf94b56439` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/config.json` | `44f0deeb6b510736a1e2fd4b8449f20aefc738762e145ad0219b93888ce9c799` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799.request.json` | `6fd2d502e01d1d5e93708e24157abdeaa7d64602a91795f559b2e968c44ea23e` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/Private.assets.json` | `61dc41017079b19bf33c9456734c5ac6a6b40321a36736618f5e9a1309a2404b` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/Private.metadata.json` | `eca3c5a792ec796bccd3933f8016a843cbe404c87adc30672d9b73d6e0c620ae` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/Private.template.json` | `5a38413c71992f0b05399d948f11b7853dfc2a34a4b59dee90ee7ea69e429113` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/cdk.out` | `2801c31b9ddf660f597e3c9d9ba2a9505ac144717ede055f34dc916602a35b25` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/manifest.json` | `5f9fef0f3c6a140e5899e8865438fa914b1c3ec5bb2790b01fbfdd8ea97d5139` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/tree.json` | `3761ef1db74a85d2947a3d83e28066d5ec59e9167d13b0ff87a84115c8bd8a1f` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/validation-report.json` | `37b01cf5f0a5b20784c30c5c70bddb00b633d76449ea5abec1fe334272da287a` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/lock.json` | `742c2c404cc22a8b93fef2e6958f431708643ae514eaf1ebbdda6cd70f990799` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/ownership.json` | `13714b3f1d710d9fe65c99901041d0fa2add43360017fd979e5b8e9243e66293` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/policy.json` | `9062f2dd81437a4c4b4072c84c6bedd63a5b58701b8becb2bfd43a3afcd3607d` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/profile.json` | `4ec5f27f718f26f6086dad4216fc8e1a909aba5fed9ba971575c7d57c69747d4` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/unit/app.js` | `710c6889188eac80e9f5e6b505c3796ded52747c9a56c305c58a53d05f3c2b25` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/unit/cdk.json` | `9727d1b2d1513b0863b75f81d75d95db66a53d79dafdd78ab00a1338f4239112` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/unit/package-lock.json` | `b106084fff5e18ca94260509133337891b58d5269d77166ff9320a36419cccec` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/unit/package.json` | `beddc07bfbf3d198ca58b3d500e746b7bd4ebc14a25b469033fb1c41ba50a00b` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/unit/parameters.json` | `1f5b55cda74fe4c5b95515db9b12c5e30df3feead79deb0ad19200c2aa7a8e02` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/SKILL.md` | `af178f8e909efd66496b09c7301c5e11ef96681fd62bf91406dcb340a18aacf6` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/bootstrap-and-project-setup.md` | `ce48bf13921481aa6d2df131f0bd32faa8cc07bb50b63b1805ddbfe6ca18a5f0` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/compliance-and-drift.md` | `4d576be561b16fd140c7f44de3b905ca81718752003a5072fec7062f2a2e782c` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/construct-patterns.md` | `029a6450cc738c220051c1e2df94cb08e82b9fd80b20ab6b1b31696015222d6c` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/fast-deployments.md` | `b6ddc7a418ed0d2f6e450c1835e3dc83c0648cbcdf4b582ebd66234918b22171` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/import-and-migrate.md` | `375e247190c3ebe29b2b8b211f665d4f463c7d959d3a6a067f8816d1a5df3a26` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/refactor-and-prevent-replacement.md` | `bdc1dacfaaaef810923699fc19803b492815b404190f055f90bd3558587b335c` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/troubleshooting-credentials.md` | `87b36861e1cf656fdb576536c20c61dfff5316e1b7465954f9b1b01cce0f0ee0` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/troubleshooting-deployment.md` | `80b97fe332046fb025cf6635b3add76046bf9b2933bd45394255585f1694a967` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/troubleshooting-synth.md` | `1397f0c8034ccafd1353c3053d119e721c4904b9dc2ba33a1f285f69bfb909ea` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/v1-to-v2-migration.md` | `f88efb1a4b7451fe194e5c617ea2c467be93ecaa7221264b80361cca035dc181` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/reference.md` | `a4976e733b7793b0014b3be1d5a1c5282002ba16dd7be9a7fffd509c800b5505` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/0/AGENTS.md` | `0b57a17a89b0ad81a6be9f0c884930af3ee7f1091a6f5056c28af8714ba6aed8` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/1/SKILL.md` | `9badd22a32e19cb884e46dfa8d3aae82bb81dfa5484105b8b4f0262df823a509` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/10/aws-s3-2006-03-01.json` | `84c3a4e6ac1c80ed49cb1ddf1f548ea7f51d8a41acbfa0f198b9ba0028d784e8` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/2/SKILL.md` | `e80544c3d1eac5b14f22022146bd91a6b0ecc30e099cf5181894853aeb81dee1` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/3/SKILL.md` | `b9eb6416eebc8dda046674f0a2dbb3be88aff526d182b60a0f55998d3d6d0d8d` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/4/SKILL.md` | `5b06be54d4852f60e6cf1b04c6e9a4748554334eb3e41af6c0959b544e6464ae` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/5/SKILL.md` | `3ff578665c61394aea0fbe5a4243e8d6280d841d6e73c12a4e81f81d2ccc9b06` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/6/aws-cloudformation-iam-unavailable.json` | `415eab6f564b8124a27d3564e61cf902bb6cdd7dd630161987b263eba9780bf3` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/7/aws-cloudformation-iam.html` | `4855e6faddb5f57c160a3eff7dcfc73700943471c806b6cef67f13ceb2f6f592` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/8/aws-acquisition.json` | `8e5413290f160504a505c78e121f07e2c8748156e9e9bd39f3979ae6c409d8b0` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/9/aws-cloudformation-2010-05-15.json` | `142ac136f30bf2ba93723536c67e66443b00d86cc2128448916d6d7ab145eec3` |
| `templates/cloud/github-aws.yml` | `72ddd25758096b0844ed9e3b14d3563f90e3f80d67acc4090fe3294222b2c7b4` |
| `templates/cloud/github-azure.yml` | `5c9c208f3cc0eb4ea0fe11617a159acdcde9cb3bb61a8a92bc0ebf178299b4ab` |
| `templates/cloud/iam/README.md` | `5b0b6827c7c9eaaa794aea10d8474dcd0156d26f5f0673fe5364f61c596128c6` |
| `templates/cloud/iam/aws-apply-permissions.json` | `9b6ab4f6f70b6d138b8f5b143e25b51abf82f2a00d5606484bb17578bb6342cb` |
| `templates/cloud/iam/aws-apply-trust.json` | `b6a668ac1c6d6bfecf347823a7bf7f4211eab6eedeb8b70e80d5b1095c88546a` |
| `templates/cloud/iam/aws-prepare-permissions.json` | `97b33e38eb4b5c62c45006b1fa82d101b3c745d89053b7aef1975ae63aaf5135` |
| `templates/cloud/iam/aws-prepare-trust.json` | `fb816c23c404a2c6dc664885da932bd208fdda8c4675c991ff694e03ab17406c` |
| `templates/cloud/iam/azure-apply-federation.json` | `edbece3a3e08ad661a37bb5bbad33e5738aee8ea96e66148fd8b948f3fb01a24` |
| `templates/cloud/iam/azure-apply-role.json` | `305f5622da98f47d3b81df756eb5ef1959069e47b59f7ec012c3d0fd4812d889` |
| `templates/cloud/iam/azure-prepare-federation.json` | `50d8cbc667ee96d6667bbbb5313562a426ab826966483b20c4187fa5b9934370` |
| `templates/cloud/iam/azure-prepare-role.json` | `18558291d8f2bd725926e1a99c532ebd4952a0a192aa7740c3be18e6c76cf61d` |
| `templates/cloud/iam/github-environment.json` | `5bf72c589d439d0dc23b02b92c62fb6b4d897f1b95a2653b2aaa4d0069ddd291` |
| `templates/cloud/iam/github-oidc-subject.json` | `69a4c0a488e543cb5bb6587ffd6ab9ccd66706ad0423db76b2d4fcc2dbbb1d60` |
| `templates/cloud/iam/trusted-policy.example.py` | `7e70f84eec5094a6b4a2aee3fe16dcaec968f2ec330fb7f51226969a01bd64e9` |
| `tests/cloud-orchestration-contracts.tests.py` | `c93c19356d8b26e2be5da3633359be5d69ec214c2e910fac77b97213ff4a548c` |
| `tests/cloud-orchestration-execution.tests.py` | `3ded22c4377536bfa7925555935d4e14a614263674c1d3acf2a973570cb14703` |
| `tests/cloud-orchestration-routing.tests.py` | `d038f799960a234e433dcc4a845ddb7b19394f4a5880c7ed9dd0f7f7037b243a` |
| `tests/cloud-orchestration-verification.tests.py` | `03b8011dcd36b3a1171f5ade95c70b6ca0574bf83eacb0d142a5efa72a40fa9d` |
| `tests/shared-launch-python/pyproject.toml` | `8308097d7ca9084f9e3a02add4d78f96514cefa947c25bab3ed24a7b74393f12` |

## Test Evidence

- **Test Command**: python3 -B tests/cloud-orchestration-verification.tests.py
- **Test Result**: PASS
- **Test Evidence Path**: specs/cloud-orchestration/verification/T-006/attempt-2/verification.log

PASS here describes the executed local suite, not task acceptance or live verification.

## Iteration And Escalation

- **Task Attempt Count**: 2
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Scratch Root**: /tmp/cloud-T006-01a14e73
- **Run ID**: 01a14e73-9069-76d0-a748-f448ad86b023
- **Session ID**: 01a14e73-9069-76d0-a748-f448ad86b023
- **Agent Instance ID**: 01a14e73-9069-76d0-a748-f448ad86b023
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

Final exact commands and exit codes are in attempt-2/checks.json and individual logs. Pinned Ruff/mypy use tests/shared-launch-python/pyproject.toml explicitly; mypy commands explicitly declare MYPYPATH=plugins/sdd-quality-loop/scripts:plugins/sdd-azure-cloud/scripts:plugins/sdd-aws-cloud/scripts, with separate provider groups. No missing-import or blanket type suppression. Native routing uses the actual pinned Bicep, Node and CDK toolchain, with no tool SKIP. Tool versions are in tools.json.

Entry verification baseline: 13 tests PASS. Entry routing baseline: 86 tests, 9 genuine typed-error failures, preserved in baseline-routing.log. Historical static failures are preserved in first-handoff evidence; not relabeled as unimplemented code. Related execution preserves original empty previews/NO_CHANGE, zero apply IDs/submissions and read-only reconciliation. No whole repository suite, cloud call or independent review was run.

Final scoped rollback (rollback.json / rollback-driver.log) uses a disposable detached checkout plus exact saved entry bytes and fixture dependencies: entry verification 13 PASS; entry routing 86 with exactly 9 known typed-error failures and no setup errors/skips; candidate verification 36 PASS; entry restore verification 13 PASS; candidate reapply verification 36 PASS. The shared tree is byte-checked unchanged and the disposable worktree removed. Eleven guard mutations (four membership guards, lease, context binding, freshness time-order/current-age/deployment-age/query-window and native Azure incomplete-proof quarantine) each produce the intended failing regression; restored candidate passes. This is selected guard sensitivity, not exhaustive WFI-001 coverage.

Earlier rollback attempts are preserved, not treated as clean baselines: rollback-first stopped on a shared-tree byte assertion after this session edited the candidate during the experiment; rollback-before-freshness and rollback-missing-routing-dependency preserve routing setup errors caused by an omitted unchanged upstream fixture snapshot. The final driver admits that fixture and asserts exactly the original nine routing failures. Earlier verification restore/sensitivity results remain narrower evidence, not proof of the missing routing setup.

Runner defect is preserved separately in routing-invocation-error.log / checks-invocation-error.json: extra paths were mistakenly passed as unittest selectors, producing two loader errors, not routing product failures. The corrected driver invokes verification/execution/contracts/routing separately. This artifact is not relabeled as product Red.

## Specification Differences

Frozen specifications unchanged. Optional provider observation config and new public schemas are immediate API contract work expressly authorized by caller. Local v1 without observation retains its planning/validation behavior and explicitly blocks collection. AWS physical-ID observation config from the prior unfinished candidate is replaced with compiled logical selectors; future recovery IDs are removed for both providers.

The caller additionally authorized fixing shipped inactive Azure workflow integration. Generated jobs now separate prepare/apply/reconcile/observe/verify with literal phase commands and distinct protected environments; APPLY requires actual native completion, not a skipped/no-op/reconcile result. Existing ambiguous workflows must be regenerated and pinned as a new protected W after reviewing E. No deployed workflow or IAM policy was changed. These newly reachable observe/verify workflow branches remain pending first real execution at CI/release time (WFI-015); local template and synthetic metadata checks are not that execution.

## Unresolved Items

1. **Effective Azure permission scope and monitoring readback remain incomplete. Native positive verification is quarantined.** A temporary fail-closed barrier rejects the real native transport identity check (genuine Red 9301c049). This deliberately does not satisfy the required supported positive Azure native path; it prevents incomplete per-resource permission data from producing native EVIDENCE_COMPLETE while handing off. Current same-workload-identity caller-permissions checks cover explicit queried resource scopes, not a complete proof against grants at all relevant ancestor/other scopes. The fixture still derives Azure permission sets from the production ceiling helper; replace with independent policy data and supported complete scoped proof. DCR association is read, but complete DCR configuration readback is still missing. Do not equate role names, simulator output, or desired IaC with proof. This is an implementation gap, not OQ-001.
2. **Adversarial orchestration coverage remains incomplete.** AWS and Azure real production orchestration healthy paths now run with synthetic transports; helper and collector mismatch cases run. The exhaustive public path matrix for every required check / denied / missing / stale / tamper / wrong principal/run/unit/profile/scope combination and all publication failure/secret/symlink cases is not fully demonstrated. Existing reducer/contract tests are narrower evidence.
3. **Full WFI-001 guard sensitivity is not established.** Initial preflight rows inherited from attempt 1 include planned publication tests. Attempt-2 actual Red and guard execution are recorded separately below. Scoped guard-removal sensitivity covers selected membership/lease/reducer checks only, not every persisted field. No complete cross-artifact checklist claim is made.
4. **Azure completion integration still needs broader failure tests.** The new fixed template, authenticated original job helper and end-to-end synthetic observe execute, including no-op/reconcile/ID rejection in require_native_apply. Wider actual governed-main/API denial/pagination/publication cases and owner-provided read-only federation are still acceptance work. Native GitHub and provider transport fixtures are not live proof.
5. **Live TEST-003/005/009 remain BLOCKED (OQ-001).** No owner-supplied sandbox, scope/OIDC, health/backup, budget or retention configuration. No live reads/writes, privilege changes or production EVIDENCE_COMPLETE claims.

First-handoff groups 1–3 have corrective implementations and local evidence but not blanket closure; group 4 remains partial, group 5's routing/static failures are repaired with scoped rollback/sensitivity evidence, group 6 has closed schemas but incomplete full-field sensitivity, and group 7 remains explicitly blocked.

## Quality Gate Focus

Root owns statuses, final scoped review, independent review and isolated full suite. Synthetic observations never prove production EVIDENCE_COMPLETE.

## Working Notes

No delegation. Read local Ponytail full, applicable ECC coding/security/verification and impact guidance. Source models/official documentation are admitted by primary and supplemental manifests with exact URLs/hashes. The original archived first-handoff report retains SHA-256 1789c28cdb64af422c7b311065541b397415a5ba951b23f6c4d2695c53792926. Initial immutable inputs are under /tmp/cloud-T006-01a14e73; spec_revision is the actual entry commit 65ee658c1b3e522eced2413aeb55bb897783bf1b, while raw frozen spec hashes are in the input manifest.

Source URLs/hashes for native resource identifier semantics, Backup list APIs, ARM operations and GitHub run/job/content APIs were inspected. GitHub models confirm run_attempt/head_sha/job steps/completed_at and total_count+jobs shape; proof rejects incomplete pages. No terminal timestamp semantics were invented for ARM. The user-authorized fixed workflow provides a conservative authenticated job-completion bound after original native success. Saved local receipts select only a candidate run; authenticated run/title/workflow/job proof is still required.

Dependency admission qualification: the reused T-013 execution bundle was first used by the corrective test before its separate dependency manifest was added. It was then snapshotted unchanged and validated; this was not a pre-use manifest admission and is not described as one. Later regression dependencies were admitted separately. No other-reviewer reports were copied into task evidence. Routing rollback additionally needed the unchanged provider upstream fixture tree. Its supplemental admission was after earlier routing use, not retroactive pre-use admission; exact bytes were preserved in routing-fixture-input-manifest.json before the corrected disposable rollback.

Azure closure research is preserved and admitted in identity-closure-input-manifest.json. Official role-assignment list models describe principal filters and complete scope enumeration; the docs describe assignedTo transitive group assignments and managed-identity group/role token caching (around 24 hours). This is a potential future narrow closure path, not implemented proof or permission to infer revocation from fresh enumeration. No generic IAM engine, graph/query execution or new cloud privilege was introduced.

Local test commits preserve genuine failure chronology: 29f3f2c4, bcfc2ec8, eb77044c, 87ac7ef7, a33afd09, 8c4d2aac, 00739cab, eb1b5b6e. Prior commits 98b54459, f21f5a80,65ee658c remain historical. Freshness correction and Azure incomplete-proof quarantine Red commits are c65f628a and 9301c049. No push, tag, merge or release action. No UI verification applies to this CLI-only task.

## Session Handoff

- **Current Status**: In Progress
- **Next Action**: Resume only T-006 from this report/manifests. Replace the explicit native Azure quarantine with complete supported effective-permission proof (not merely removal of the guard); finish full DCR readback, independent Azure permission oracle, exhaustive public-path failure/persistence coverage and complete WFI-001 sensitivity before asking root for any completion decision.
- **Unresolved Items**: The five groups above; live OQ-001 remains BLOCKED. No task status changed. This context-boundary handoff is not acceptance completion.

## High-risk corrective preflight

Recorded before attempt-2 product changes. Prior test-only commits and failure points remain archived, not relabeled. The inherited matrix enumerates all persisted fields; its publication cases are still pending, not claimed executed. Corrective scope below changes only source resource binding and discovery, not the envelope field set.

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


| Corrective persisted field | Counterpart | Failing mismatch / control |
|---|---|---|
| context.resource_ids and observation.resource_ids | Original immutable template logical selector and native original StackId/LogicalResourceId/ResourceType/PhysicalResourceId/ResourceStatus | AwsObservationOrchestration.test_configured_healthy_substitute_is_not_original_resource; test_stack_membership_counterparts; test_unknown_create_ids_resolved_without_request_edits |
| context.request and request digest | Original request bytes unchanged across CREATE then observe | test_unknown_create_ids_resolved_without_request_edits |
| backup result and queries | Original resource / plan / vault and post-completion recovery point | NativeCollectorCases.test_native_healthy_and_each_unhealthy_denied_missing_stale (backup); discovery variants to be added before that change |

Actual Red: red-substitution.log executes existing prepare/apply/observe and fails because ValueError is not raised for an arbitrary configured physical ID. The initial red-create.log includes an incomplete timestamp fixture (subsequently repaired in tests), and selector cases fail during prepare configuration admission, before native membership validation. These are not claims of executed membership guards. Matched selector control and five counterpart bodies must execute after implementation.

Additional preflight before backup/lease changes: backup sampled_at/result/queries
counterpart is native ListRecoveryPointsByBackupVault, exact resource/plan/vault
and CreationDate/CompletionDate. test_backup_discovery_without_future_identifier
is the matched CREATE control; original per-check stale/missing/denied/unhealthy
bodies remain. Its initial failure is configuration admission, not query execution.
Collector expiry counterpart is fresh OIDC/provider lease; the executed
resource read in test_expired_collector_lease_has_zero_reads currently fails
the expected rejection (no exception), not a missing import. New evidence:
red-discovery-lease.log. No expiry or discovery success claimed yet.

Closed public-contract preflight: every emitted collection-context, check-result
and evidence-manifest field corresponds to its namesake JSON schema required
property (including nested request/context/observation/result/verification file
refs). test_emitted_contracts_are_closed exercises real synthetic production
orchestration, then schema-validates its actual emitted records and removes each
field/adds an unknown field. Initial Red is absent schema file, not executed
schema mismatch rejection. Existing reducer mismatch tests validate the inner
bindings separately. Publication copy/substituted-response tests added alongside
this contract test; no claim of a caller-supplied native label granting proof.

HTTP outcome preflight: persisted result.queries[].http_status must agree with
observation.status/exit_code, check.status/reason, and verification overall_result.
test_native_denial_cannot_be_overridden_by_healthy_label feeds status 202/403/500
into the implemented reducer while keeping a self-consistent healthy label and
updated payload digest; red-http-outcome.log shows all three wrongly return PASS.
This is executed mismatch validation, not missing setup/component Red. A genuine
200 response is covered by test_all_checks_synthetic_never_complete.

Azure completion correction authorized by caller after the identified gap:
inert phase template changes are in T-006. Before those product changes,
AzureCompletionCases checks literal separated phase jobs (actual current failure)
and feeds matched/mismatched original authenticated run/job/workflow metadata to
the intended original_apply_completion boundary (initial AttributeError: helper
absent, not executed metadata-guard Red). Persisted context.completed_at and
resource result query-trace counterparts: original pinned workflow W, pinned E,
exact request/preview title, repo/run/attempt, successful non-skipped literal
apply requiring native completion, job completed_at. Red log:
red-azure-completion.log. The archived ambiguous workflows cannot be used as proof.

Azure membership preflight: context/observation resource_ids and native_operation_id
must join the immutable compiled VM/NIC/DCR-association/backup resource identities
to original deployment operations' exact targetResource.id/type and successful
Create state. AzureResourceBindingCases feeds compiled/native substitutions,
wrong type/state and incomplete pagination with a matched control to the intended
helper; initial Red is AttributeError (helper absent), not an executed guard.
No matched-control or original deployment end-to-end claim follows from that Red.

Azure discovery preflight: backup sampled_at/result/query trace counterparts are
the configured protected item/policy and native RecoveryPoints_List IDs/times
within the original completion window. test_azure_backup_does_not_require_future_recovery_id
removes the future ID from original configuration and calls the existing collector;
initial Red is configuration required-field rejection before native list execution.
Existing stale/missing/denied/unhealthy backup cases remain mandatory controls.

## Attempt-2 freshness correction preflight (before product edits)

Root's deterministic helper probe (not live cloud or review) is reproduced in
`attempt-2/red-freshness.log`: four tests execute, with six assertion failures and
eleven STALE_SIGNAL errors from existing collectors. This is actual guard/query
execution, not missing-component Red. Test-only commit precedes correction.

| Persisted field | Counterpart | Genuine failing mismatch test |
|---|---|---|
| context.completed_at | original completion lower bound, not maximum deployment age | FreshnessCases.test_old_deployment_recent_samples_and_time_order |
| context.collected_at; payload.sampled_at; observation.timestamp | completed <= sample <= collected <= now; profile.max_age_seconds bounds current minus sample | FreshnessCases.test_old_deployment_native_recent_metric_and_backup |
| payload.status/reason; observation.status; verification verdict | recent healthy/unhealthy native metric and backup, independent of deployment age | FreshnessCases.test_old_deployment_native_recent_metric_and_backup |
| query locator/request_sha256 | actual bounded metric request StartTime/timespan and Period/interval; recent window intersected with original completion | FreshnessCases.test_metric_query_recent_postcompletion_minute_window |
| backup query locator/request_sha256 | native createdAfter parameter versus recent post-completion bound | FreshnessCases.test_aws_backup_native_recent_query_window |

No new persisted fields. Time-order negative controls and mixed unhealthy/healthy
samples are present; the first positive assertion in the helper test currently
fails before its later controls, which will be executed after correction.
Previously admitted official native models are re-admitted in
`attempt-2/freshness-input-manifest.json` and validated against scratch. CloudWatch
GetMetricStatisticsInput.StartTime documents inclusive start and rounding down to
whole minutes for <15-day windows; EndTime is exclusive. Azure TimespanParameter,
IntervalParameter and AutoAdjustTimegrain document the ISO range, PT1M and no
automatic adjustment, but do not assert a CloudWatch-like rounding rule. Use an
explicit inward minute-aligned lower bound, not an invented Azure server rule.
AWS Backup ListRecoveryPointsByBackupVaultInput.ByCreatedAfter is the native
creation-time filter. Azure recovery list supports a generic OData filter but
its admitted schema does not establish time-filter property syntax; do not
invent a native query. Its bounded complete list is time-selected locally,
without selecting by health. Incomplete native pagination still blocks.

## Native Azure proof quarantine preflight

Latest root guidance requires native positive results not contradict the explicit
permission-proof gap. Official closure research is admitted in
`attempt-2/identity-closure-input-manifest.json`. It is not an implemented or
validated proof. Assignment enumeration alone is not a claim about cached
managed-identity group/role tokens (official best-practice lines 103–111).

| Persisted field | Counterpart | Failing mismatch test |
|---|---|---|
| identity check status/reason; observation.status; verification.overall_result/evidence_complete | native proof completeness, not finite permission samples | NativeCollectorCases.test_native_azure_incomplete_permission_proof_cannot_pass |

`red-azure-incomplete-native-proof.log` executes the current identity collector
using the real native transport class with scoped, explicitly synthetic I/O.
The incomplete scoped data currently returns healthy (expected ContractError not
raised). This is genuine mismatch Red, not live native proof. A temporary
fail-closed barrier is necessary for safe incomplete handoff. It does **not**
satisfy the approved requirement for a supported positive Azure native path;
that work remains incomplete. Synthetic partial-path tests are not production
proof and cannot release the barrier. No new privileges or invented API facts.
