# Implementation Report: T-010

- Task ID: T-010
- Model: openai/gpt-6-astra
- Effort: high

Report Schema: implementation-report/v2

**Snapshot Notice**: The numbers, statuses, and paths recorded below reflect
the state at this report's own authoring run only. A later same-feature
event -- another task's edit to the same surface, or a gate-phase artifact
normalization such as a path move -- may supersede them. The quality
verification gate's own report is the authority for the gate-time state;
this report is not edited after the fact to reconcile it.

## Target

cloud-orchestration / T-010 / RT-20261018-CLOUD-DEPENDENCY-EXPIRY / REQ-006 / AC-006 / TEST-006

Run ID: 01a14f7b-2c6f-7fd2-a9d1-dfb5c7efdc0c
Task Attempt Count: 3
spec_revision: 9b8a12e8d875cf283e0c4370426ecf3c6e4338feff27a69ff888a2888066c440
Input manifest: `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/task-input-manifest.json`, SHA-256 `942285cb354d2cdea8048d181ae8f006eebff17b5b62a69f73048a62872c9b58`

## Summary

Fixed callback-time predecessor expiry by carrying the admitted minimum freshness deadline into the existing authorization receipt expiry. Both providers consume that expiry in their existing final guards. Scoped Red→Green, regression/static checks and exact entry-candidate rollback/reapply completed. Independent review and quality gate remain root-owned.

## Files Changed

- `plugins/sdd-quality-loop/scripts/cloud_authorization.py`: retain first authenticated predecessor deadline; cap the existing expiry before immutable publication. No provider/dependency module or schema changes.
- `tests/cloud-orchestration-verification.tests.py`: append DependencyCallbackExpiryCases; prior tests remain unchanged.
- This separate report and `verification/T-010/dependency-expiry-fix/` evidence only. `task-delta.patch` binds the exact two-file entry-to-fix delta; `before/` retains entry bytes. Canonical T-010 report remains read-only.

## Tests Added Or Updated

Three focused tests, 52 matrix scenarios: Azure what-if/PUT validation and journal latency; AWS asset publication/CreateChangeSet/ExecuteChangeSet final-authentication latency, create/execute readback and execute history; receipt minimum across predecessor/OIDC/provider/policy/preview deadlines and the real empty-predecessor branch. Each callback case has a fresh control, exact deadline and expired case. Synthetic admitted deadline is explicitly not acquisition/provenance proof. Existing real acquisition/cross-provider/pin/revocation/expiry/replay/partial-failure cases remain separate.

Real final guards execute for Azure and all three AWS final-authentication paths. AWS history/early-readback expiry can stop earlier at the existing read-lease guard; tests record that exact failed guard rather than bypass it to reach a later guard. Native submission counters execute in every case.

## Outputs

One table row per produced file. Paths MUST be canonical repository-relative
paths: forward slashes only, with no absolute/drive prefix, backslash, empty
segment, `.` segment, or `..` segment. The independent evaluator launch
boundary authorizes changed/test/contract inputs ONLY from rows in exactly
this two-column, backtick-quoted form — keep the shape byte-precise.

| Path | SHA-256 |
|---|---|
| `AGENTS.md` | `be21577343b8b2cc488c47b373ed68130ded00d994f58f1f81b7b69bddd6d537` |
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
| `contracts/cloud-verification-registry.schema.json` | `56c235d897412295cfa631906c8fd3688a43ae6918178753ee1ed934fd622392` |
| `contracts/cloud-verification.schema.json` | `dcfd0760733951080efc1f0cb993bfc46a081b4eff4a82bd07968f868b2f3f2e` |
| `contracts/selected-verification-plan-v2.schema.json` | `cddae6fd212bf40a10fa86a27f171f0342b578f7a651bc276448f7134f4e8fe5` |
| `contracts/task-input-manifest.schema.json` | `22a756c64a7c720b761b31d71c9fbb62c390a9f18b201673443e962998781749` |
| `contracts/verification-contract-v3.schema.json` | `c52f8795c274ea8dc8c3a54f2e6b0d55ca9a8f49164200065fff51e3d710345a` |
| `docs/adr/0036-thin-cloud-orchestration.md` | `d67248086011bcabfe482073b33d25bc39f066fd0f3763ee88bd70ee902656fc` |
| `docs/review-tickets/RT-20261018-CLOUD-DEPENDENCY-EXPIRY.yml` | `ba3da7adb68487d9047930c6f3ee1476eb9888ae980cf01d25a4486861bd1192` |
| `plugins/sdd-aws-cloud/examples/private-ec2/README.md` | `0caceb7832a0c3e467042a760789f03a47521eaca375e712ea15120931e2ea5a` |
| `plugins/sdd-aws-cloud/examples/private-ec2/app.js` | `710c6889188eac80e9f5e6b505c3796ded52747c9a56c305c58a53d05f3c2b25` |
| `plugins/sdd-aws-cloud/examples/private-ec2/cdk.json` | `7802e394180f0d618f4caf7d1a6647f406ad327fa0aaa38c84b8b6b8471b24a5` |
| `plugins/sdd-aws-cloud/examples/private-ec2/package-lock.json` | `b106084fff5e18ca94260509133337891b58d5269d77166ff9320a36419cccec` |
| `plugins/sdd-aws-cloud/examples/private-ec2/package.json` | `beddc07bfbf3d198ca58b3d500e746b7bd4ebc14a25b469033fb1c41ba50a00b` |
| `plugins/sdd-aws-cloud/references/aws-local-config.schema.json` | `1d8d1f63b8f2ff4836058d928752c5322b744727e03b14d2e34e1ec6b9d25f22` |
| `plugins/sdd-aws-cloud/references/aws-local-evidence.schema.json` | `d64402c81095bd9a0657d34f4723a02996d91bb93cb0d0906c4ca288aeaa3187` |
| `plugins/sdd-aws-cloud/references/local-preparation.md` | `2a890269fabb6128f125f5533d3eb4c6411589ca0d0843b642b47cc959f7a257` |
| `plugins/sdd-aws-cloud/references/observations.md` | `b474f3965405b3b5883d8550300aab4ac830261b14dc9cef615d47543794a748` |
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
| `plugins/sdd-aws-cloud/scripts/aws_governed.py` | `94f9f9c07aee2de6bb1e7229c0244cde7423441d59b813cc8c426e2a71943ff0` |
| `plugins/sdd-aws-cloud/scripts/aws_graph.py` | `21896c758e64f5db7571c2c5209a4ab122cac8347dc18096c29e79f7396a42fd` |
| `plugins/sdd-aws-cloud/scripts/aws_local.py` | `82bbf762e80d62abdc77b56f850729c72d4ae83c3e59f4de09751867f16e4b31` |
| `plugins/sdd-aws-cloud/scripts/aws_native.py` | `1e2ea86be1852796c55c3858d40bef1afbcdc0594a95b0b160d88d1e5c817855` |
| `plugins/sdd-aws-cloud/scripts/aws_observation.py` | `6c42f914d8c1b959542da30d614c673f50a78987b7dea95dd6638ac476420c81` |
| `plugins/sdd-aws-cloud/scripts/cloud.py` | `167b3e37e88a5ab1c32344e226823ae0e9d1518d7927a7ab4221422a011cc933` |
| `plugins/sdd-azure-cloud/examples/README.md` | `18d4bac06d053a486ab77936c75cd7e4f0824fff90728431cbfdf7f89d9cc873` |
| `plugins/sdd-azure-cloud/examples/private-vm.bicep` | `81ba478fb3744e96496243358f3aef3477646027a58e1220f3c16b7b428c9422` |
| `plugins/sdd-azure-cloud/references/azure-local-config.schema.json` | `c8390b8b18bf5f4c5cd961892b78f0d3d7f08641d14ae5052f62fe17f795fc3f` |
| `plugins/sdd-azure-cloud/references/azure-local-evidence.schema.json` | `e4584e317609585b3effc865412757ef730448d814b2ce7f78eebf485728b68a` |
| `plugins/sdd-azure-cloud/references/azure-parameters.schema.json` | `5922b55565b1a506db4cc424560cbfaa0b07766f1e26bf50dd4247ade18fc3ae` |
| `plugins/sdd-azure-cloud/references/local-contract.md` | `68850cae945e1e5357fedb284079cce67fec809a07cd1a35f6f923a39b89fdfc` |
| `plugins/sdd-azure-cloud/references/observations.md` | `e356a56677f3f26ada8f507c8fd2f90d06e28b9204e3ced96c13df0fe789c9f7` |
| `plugins/sdd-azure-cloud/references/upstream-lock.json` | `f7e22249f21c062e6207579460b1ad1042af52e4eb619d8566fd4d99db675644` |
| `plugins/sdd-azure-cloud/scripts/azure_arm.py` | `5ee98cf0fde60b1d8e9959cf17e7eb6e53fbaf179104ad0e080b849f936cff86` |
| `plugins/sdd-azure-cloud/scripts/azure_execution.py` | `cb8b14a85e305431aaf80eb568620aeb42b724aa13f485251338f9bde70c360a` |
| `plugins/sdd-azure-cloud/scripts/azure_governed.py` | `c919c2fe44f462db08ccfd5f766b7635ae3e9eb4bf416bac96e2c9ded1509bc8` |
| `plugins/sdd-azure-cloud/scripts/azure_graph.py` | `f46bdc77c12449d0f4befd0221b29687e7b4f48685cc6106080de62b3a4d075f` |
| `plugins/sdd-azure-cloud/scripts/azure_local.py` | `43d37a2ec9ae8e5bfc60690480c7ec607237b03b4c3d6fbb7f1e8d2ee7792f10` |
| `plugins/sdd-azure-cloud/scripts/azure_observation.py` | `4b56fcba4f3017eebea8e97c565e2df8a3b2691f8cce21478dc7bdf7819bc8b8` |
| `plugins/sdd-azure-cloud/scripts/cloud.py` | `4ae02ced280a8267a99fbd18b92d5fbd7a61b3d3e64c369b02e02c63c15b5636` |
| `plugins/sdd-bootstrap/scripts/check-sdd-structure.sh` | `0c3d60174684beb5796d4646b47c2d9e7fae0827ed548fcad0132b13703384fd` |
| `plugins/sdd-implementation/scripts/validate-implementation-report.sh` | `430e0e45c6bb417cd65f7f7f228bb59280d6d0817c8b34236223b8fbd4702029` |
| `plugins/sdd-implementation/scripts/validate-task-input-manifest.sh` | `5e209d11c50b9c580572adedee0c500fcc48233c1cafe5d22d08318c52059f73` |
| `plugins/sdd-implementation/skills/implement-task/SKILL.md` | `6a3bdc2efd1e8338a961c23e69240e27e5c7a366580d6fc3a1a532461a1b507c` |
| `plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md` | `d0622d44f13693cf6e32c918aba53efbcc5089dbfbba8a539bec3be601017051` |
| `plugins/sdd-implementation/skills/implement-task/references/implementation-craft-policy.md` | `5f00ddf2765b5086dfc83b3e24ad6873a7e08a08d419126fb619adcc82e0beff` |
| `plugins/sdd-implementation/skills/implement-task/references/implementation-policy.md` | `739173bcd97aaa185206b85ce0fc88cbee96e51447d0097a082fedead40b30e6` |
| `plugins/sdd-implementation/templates/implementation-report.template.md` | `0c926d76c0aab214fe305ad5974dc6636aea81cc2764a0b37292ea61cb4f1f75` |
| `plugins/sdd-quality-loop/contracts/capability-registry.json` | `dfc1b948bb085d3c86f1f7958b9564c1cb6cf6240ce9d57551656fffc2f15c75` |
| `plugins/sdd-quality-loop/contracts/capability-registry.schema.json` | `ef70a27785d325cc32d2c4a2faeed099e9df3058fd7a918e2efbd4013ed8f319` |
| `plugins/sdd-quality-loop/contracts/capability-summary.schema.json` | `09d4ace8cc599b4ef7632aaa09c7477e765bcfa69943f2231f8870aac4cbc42f` |
| `plugins/sdd-quality-loop/contracts/cloud-verification-registry.schema.json` | `56c235d897412295cfa631906c8fd3688a43ae6918178753ee1ed934fd622392` |
| `plugins/sdd-quality-loop/contracts/context-projection.schema.json` | `3c8e39c6a8dedf948cbd7e6a8f36369f2a68a3fc3dd92192f90bbce917d32643` |
| `plugins/sdd-quality-loop/contracts/facet-manifest.schema.json` | `81d4f1621923133e55875621ba81b30ad9d21688d9442c5a371fc1023b4a4c51` |
| `plugins/sdd-quality-loop/contracts/lite-check-catalog.json` | `c251b3e02a2c93c45a7ea590bc5a7e36eef8e5915c485b0c6a6e83519afe086a` |
| `plugins/sdd-quality-loop/contracts/lite-check-catalog.schema.json` | `a4e458242d68237cf16e66aa28b362c30dae4a6d20109cb4af51711f6fc1cd19` |
| `plugins/sdd-quality-loop/contracts/lite-upgrade-reason-catalog.json` | `e73a730f9edacd7d2dad2da3e13b9e3df01f7002c25f7e947316ca249118eb76` |
| `plugins/sdd-quality-loop/contracts/selected-verification-plan-v2.schema.json` | `cddae6fd212bf40a10fa86a27f171f0342b578f7a651bc276448f7134f4e8fe5` |
| `plugins/sdd-quality-loop/contracts/selected-verification-plan.schema.json` | `0da68ea6b5c880ee7db2dc0bf88e9ca4c31c01fe8d859dfb50c664eb8a2bd7fe` |
| `plugins/sdd-quality-loop/contracts/verification-contract-v3.schema.json` | `c52f8795c274ea8dc8c3a54f2e6b0d55ca9a8f49164200065fff51e3d710345a` |
| `plugins/sdd-quality-loop/references/cloud-verification-registry.json` | `de0153f09def1b805818f9bef1ddea065a30d3fee95e12f026bdaec40720d06d` |
| `plugins/sdd-quality-loop/references/debugging-recovery-policy.md` | `7b392649cdfa5d565df1e7fb37db0ee5ff528ee870ff3feb523bb57e1294254c` |
| `plugins/sdd-quality-loop/references/guard-invariants.json` | `4c43639cd9b90b2c7c4ac83d80b41b3808ad9f865550e465cb1db63743a523ae` |
| `plugins/sdd-quality-loop/scripts/check-contract.ps1` | `66505c65b073bc083d32b734a4e073bc85a216dd98a3b81a5bf581ae4956d9b3` |
| `plugins/sdd-quality-loop/scripts/check-contract.py` | `9bbc96658f775ed46c8d876e92803a8de46c9bf242bbc83d412776164e89e6b7` |
| `plugins/sdd-quality-loop/scripts/check-contract.sh` | `fc3a081d4e584ac13e4e09821815b8a14ca637e214fc70b8d470aff1bfecb416` |
| `plugins/sdd-quality-loop/scripts/cloud_authorization.py` | `17f5ffd041fe2d32657452093c76f4eda87b37fc5bf5d8504a1c6352eaac9658` |
| `plugins/sdd-quality-loop/scripts/cloud_contracts.py` | `c11225de15d8944a4183085b3df98f7b4da2d87227c473ad4eedde377b51164d` |
| `plugins/sdd-quality-loop/scripts/cloud_dependencies.py` | `7974e7e9a8d7da0c60b219a58db54c4747f0250653fda3af0146091f1f4fb475` |
| `plugins/sdd-quality-loop/scripts/cloud_verification.py` | `b2488aa48d32716b270fd920fbf4b13f43cf19440e975b48721d91e38de62a68` |
| `plugins/sdd-quality-loop/scripts/evaluate-predicate.py` | `4daa549e9bb06b71759580a0ed1389033745dee21c5a1ae7ef694c725a2b9156` |
| `plugins/sdd-quality-loop/scripts/evaluate-selected-plan.py` | `68b6ebecfb4996cae3e97e1723fa64d9e8d97ebbc2489058afddd442c7bd6e7c` |
| `plugins/sdd-quality-loop/scripts/generate-evidence-bundle.sh` | `92999f5c81fe4a7cf75c6e630427a9ff866d4973a60aa4bf4df7043ad546f448` |
| `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` | `a08c294f2a7fcfb0e9c574feda16db135a0d4f50509da98661769a6ddcee4aeb` |
| `plugins/sdd-quality-loop/scripts/generate-registry-digest.py` | `dd3a0642deeceac3d8def2c476c97fe6cf69fbfcebb2e1682bcd7939862b0aaf` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js` | `d3efd787196da964ed140a5bcb710c163840cbc25567e43676603e90ebb83230` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1` | `e5ba22671799fefccbd0f1f8a8f8d2aa8964a7cfc0e171ebbc4c50977f44cd58` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh` | `5224e41dd30ad2d594997f5a44891615f048e14b12a9fed5f59919afd9fcd1b0` |
| `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` | `e36f7c64f22fa347ed62fcedc9f85da7f784b13c9d602b1d11d6a7c3916a1013` |
| `plugins/sdd-quality-loop/scripts/lib/py-dispatch.ps1` | `b15ef1ee7b8b89fb7717ed09b4d7c0e6150bbbd87478594f61a146b6596b30fb` |
| `plugins/sdd-quality-loop/scripts/lib/py-dispatch.sh` | `abde8035c825c318a56a3d9e1b24b2fd618553f10f9784ceae8ab2173eeadf0c` |
| `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` | `d19f258b904dd168410f184f7854d47a3790319832b5bda919b3f7049ab41a06` |
| `plugins/sdd-quality-loop/scripts/validate-capability-registry.py` | `4aa0e97622b47687508e305b1832e182926d0595b7626180e5736b23e0ef174e` |
| `plugins/sdd-quality-loop/scripts/validate-facet-manifest.py` | `343895ffea39fe4459af667308d815bd75cc6d4f4eaad7ef4e51b5753994ce99` |
| `plugins/sdd-quality-loop/scripts/validate-resolver-evidence.py` | `11bbff0409344168c57095631c333c714cd9dbffb22da664989494e50dc5757e` |
| `plugins/sdd-quality-loop/skills/fix-by-review-ticket/SKILL.md` | `0215d3a6c097c893727276afc6078415cc83c3aa4273dc8bc62865bc3af6efa1` |
| `reports/implementation/cloud-orchestration/T-010.md` | `ede48a70e1eddc7fa60f90bb58444f330654f3921b7b0ecdcd724c0c151005b0` |
| `scripts/check-sdd-structure.sh` | `4b64e8027ce7cc5f99f788ea044ad54f8a5add23acc253419c5f26fc5b9671f6` |
| `specs/cloud-orchestration/acceptance-tests.md` | `4eb6f1a088bc175196ff6f9e33393b05190903e061186fe70cf4895f044f06e0` |
| `specs/cloud-orchestration/design.md` | `f3605c89c9522f3f167db695e2bbf2bcbe7e9e71c92610ff0032272b0bca5f89` |
| `specs/cloud-orchestration/frontend-spec.md` | `586d52fd577b5eaa24be9037f80fbc0334ab934906a9125ead71206eb8561d2b` |
| `specs/cloud-orchestration/infra-spec.md` | `9fcb3698f73022d60b8848785b05ca137620b97cd43586da63a0e75716bccf7d` |
| `specs/cloud-orchestration/investigation.md` | `38229c1b74b815780bfd752a353f1dc15bbcfeefa0285e4f8dc097721227f20c` |
| `specs/cloud-orchestration/requirements.md` | `31f5a76f5902e2d4361d89bb42c106fe2839dd0a9aa0dd9eb6f28822c7ec6922` |
| `specs/cloud-orchestration/security-spec.md` | `fe980874e34da14db58b088b0ae6f989a6e0dadc3a39757851457c0c5312e1db` |
| `specs/cloud-orchestration/tasks.md` | `54f6656997252564c6ab7aaa14004bd7022de52e7f7fbaa1374b2afd4325f847` |
| `specs/cloud-orchestration/traceability.md` | `c4bff8916b0f7f49b982ef20e04d2e02862ba20dd048a83bfd9451cb342e0774` |
| `specs/cloud-orchestration/ux-spec.md` | `d02d6d219266ca0b5c0ae9705a58e67b66682f3539ce2cd749e545abe5bad8bc` |
| `specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream/LICENSE` | `8a5d8efb70942e65032f930c761d097feeb41a7517ebd04c9d2e4ec3764071c5` |
| `specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream/reference.md` | `a4976e733b7793b0014b3be1d5a1c5282002ba16dd7be9a7fffd509c800b5505` |
| `specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream/skills/azure-compute/workflows/vm-creator/examples/bicep/README.md` | `61a52989ee67dfe4ee30aeb88a06bd15460d3d61d9f1101f3d0d58c19d1e4852` |
| `specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream/skills/azure-compute/workflows/vm-creator/examples/bicep/main.bicep` | `6fa0bd982a36436cc4a6929ce5a8bb2fff748248d2865000110de0a18ef51b5f` |
| `specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream/skills/azure-compute/workflows/vm-creator/references/output-adapters/bicep.md` | `ab54837a3cde78093ebb59875c0cb1f471c57ee786d8b7d417f808cf94b56439` |
| `specs/cloud-orchestration/verification/T-010/attempt-2/evidence/run-scoped.py` | `f5852721c7c39c9545f27aefd932f5e79f13b39dc5117236fa29b1b34b960bb4` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/after-commands.log` | `f1245349a161446e6953ab955064c4de88b69b4d3f65a85b90a7e70b3f12020d` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/after-contracts.log` | `5bfe06797a1e9b81e95b3e44502401abd638b65645e6d5945ee87a2dbba42681` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/after-execution.log` | `7e6c9e937d4e9804c492f56ceb63b2ce9e8b83cf4e992d7bf8fbace9a7cec0d5` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/after-routing.log` | `55822e2addd1b29d7cf7715bd26110c1e463687b8c94fae5e345c99125b25e08` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/after-verification.log` | `939850e9c0a7eb7579accca66a4878b0829fda7baef5809cfbd10cb34e6853a3` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/before-commands.log` | `f41439e387d725b905275550650e7bcf2288079d67e6b5ebde154bd4fe231e8a` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/before-contracts.log` | `5f24f8484e44897e5d8ecd906ac628af95436c03d2faaa657f22f44faa97a780` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/before-execution.log` | `d739ea2e0b54596dc6a369538c3bf41d09df6587774396118139a330844c55c5` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/before-routing.log` | `758f82fb4a965f244c1fb78488b6a6ae545e348fd084cf6694d576afe1cc68a6` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/before-verification.log` | `2974cc47c72698c09bf1520fd6221b8260def92222db6dbe52898c8a56b6997f` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/before/plugins/sdd-quality-loop/scripts/cloud_authorization.py` | `035bbb6e2d011e2f64ec7bd93674b5b547ff83907337a3b35ff5b16f8adaf688` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/before/tests/cloud-orchestration-verification.tests.py` | `3c7579045e94f627d88cd75cbb1ddda008934c869626ef0fd8ea91de60e82dc8` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/commands.json` | `2c411b6213c23717213c4c3900f2142707a4dc6faf9595af3584bb77d97fdcfc` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/diagnosis.md` | `b859a49a7b56e0aaa94322231f9207905fb7e6e259e604528c8e0cb0e0ec4d45` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/diagnostic.log` | `90ed107ce190e48c7cc47b09a4a816e3e27fd1c0fc24b619ccb354d0d12e4338` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/diff-check.log` | `91cff2af8d854cbbf356823ebc6b7b58911ae6a5b3c7c66183df9d3b5ee418ec` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/entry.json` | `e37b41a073affb6df38e8fd03822954b574ebc869c2f46b8321f0f7463e5dd32` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/final-verification-command.log` | `84eb57550d69d587d2f3508f37106f619cf648aa44bbdeb59dac160ad89ec547` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/final-verification.log` | `9a378733707c01672d455a704e2bc54bfed72c7a5a15ed0f54cbbdc69d85bcfd` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/green-first.log` | `47155b5bce61198e58df07a95639fe10baf0fab170e0eb1073bf4c9cb5a8c4b4` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/green.log` | `418d08c259ee5ba10b4c4f94b5f794bbb1dbc03b9e59ea408f4c51d86cdf93eb` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/identity.json` | `8bb5c840e5569d4a1f5b10edc9753e17299ee96e693c4f13747a931136c79407` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/input-preservation.json` | `f748067f10393aa718ba7935c8e6a98c5f0a03bb2068d36d23b884cb1ba85bf9` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/manifest-final-validation.log` | `79710f043ea7f2e2091cb936b7f1ea0efa792eeea798d8bb6d6d4e80946edc52` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/mypy-first.log` | `9b4dcd033e5348eac674aa7dc59b3b0383661ecfa8bb97fda81e5a54b9a6e1fe` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/mypy.log` | `050c52a2b0c61e8b681ef5c485e0bc03340b8d55148e0acef27d744c8be42033` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/preflight.md` | `055af15984806df85b610f2dbb1f99a85111c6b6b079972b1ea02a76b8e1cab9` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/red-commit.log` | `65b5cff7c4cc80ccbf7139cc6f570719897ade5f14e70d0b042483f0cc7b3224` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/red-ordering.json` | `88d4430e60cd3c3536cbcddef54a1deb82c2d9eac3aa17e7f58f7318984ac95d` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/red-second.log` | `faf2a386e3301a2080adc69008cc71697269ed3b236bf5e9c97b86a058f05baf` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/red-setup.log` | `0f240cc9cd3eb20a59b78d9dcfef55ad1a0799786d30815dd748dc4eb4704a1b` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/red-third.log` | `3913f2bea5f38229bc760b766a7313bfcf21f174948b15e5c0c1fe9277eecc12` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/red.log` | `5fce78786b86853d0d5082773e9b5bbf90c1f46591c4496112a1a4300013db03` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/regression-dependencies.json` | `0400c4a3e46a59eb71986ec1d5d46ce822f8587a1b2f79e3c965d7b348b4a1bf` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/regression-dependency-manifest.json` | `a9e1e75e74d1cd8fd2aea17460d9a00116b9fd52303691da635d52298e434995` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/regression-dependency-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/report-outputs-validation.log` | `422f97c62b5286baed894821684a475637be15bc3f79332ec05c675e4e249635` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/report-validation.log` | `a0eb36646f9654b7ef1b674fed63ad247a1febe005869fbf36ce295f5437a10c` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-candidate-focused.log` | `f166fa44a0bc716dba195d46156f6c1b23f2ca011ae3ec0241a5f39e73b2f63a` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-create.log` | `c1ebcba029cfc4f5870695b971f71858f315cb4e711cab94ad820f6a466792e0` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-defect-reproduced.log` | `29ca2f86f0ce9cc12b5f171facdd707a0dba247b93646f5b20a21d87a62a0a86` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-driver.log` | `617a94e3f4056b14a78e921f43aa7dad6702b823701120f7901b037e074c40ff` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-entry-contracts.log` | `bf2670b3ec5a3494646f0cbbd1d93a57c5b696f9c736d9b64394acf7be37adbe` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-entry-execution.log` | `df237c23b57c795906014cf677ccf65a642c4b78fb8e3caee30d3d466080122d` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-entry-verification.log` | `4fe44ec58119d011736427d370cd722a6c346a9b183e4141104a51467456ff47` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-first/driver-source.py` | `3fb95c463e9e2456cc2733ee358a7d4563d3b3d91b08b84a385f3aaf58095039` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-first/rollback-create.log` | `c1ebcba029cfc4f5870695b971f71858f315cb4e711cab94ad820f6a466792e0` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-first/rollback-driver.log` | `b70c9d9ea289f196167bc3d8cb49825083ab13f32cbe2169525b2ad08196769a` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-first/rollback-entry-execution.log` | `4af6e7063947cfdbc2485f2311c0111f8cb37f75cd24651241dc8bc2ae2d5652` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-first/rollback-entry-verification.log` | `3c9f971003287946a62fd4c579826b0b83a447d4b356d87bd6cd58612e41c2b7` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-first/rollback.json` | `0dbee656b54d7c7e6924044dc63a1fd9a223723b1964c88d4b19ba5c1ea444ca` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-procedure.md` | `b814904de8ebd7469ea0b3c9036d19346a3f7c65e75761f7abb9e98a3ecec41e` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-reapplied-contracts.log` | `ba4c82d97c192098bf14e3953d90ead30af5d3e8f0b23175ed1efef161b11916` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-reapplied-execution.log` | `dfd8cf5a79754810f536512811a0e6519333c604be52fa54a3261d1b5971a963` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-reapplied-verification.log` | `ac09b99d41e0d7c91ffeedf059903ee80735723303632eb83a4d581d5f34af2e` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-restored-contracts.log` | `59a0e2602070d122237ebf422487f5f1ba79e731a557cfa5247c7fb4450222de` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-restored-execution.log` | `240ce8b2a05437f783dd5f8a47e7df442cce67b9d54191aa08c9139572566d3a` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback-restored-verification.log` | `1400aeb2edd6c16f844b4fcfbdeef4d9f9ab4c147f8cdbd74c22bf4804d69867` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback.json` | `3155179665daccf43ad27ae859a922dd7848d05f7d1d2cd84e33de4a950cbf1a` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback.py` | `95a5c321734e6d88a211e066df05b8d319ef5be0088e52cf60bf0133cfeced87` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/ruff.log` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/run-regressions.sh` | `43b27331be89671b4c131ed03972e5b56344a044e3476c7af70eaf755842e54e` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/run-scoped.py` | `f5852721c7c39c9545f27aefd932f5e79f13b39dc5117236fa29b1b34b960bb4` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/run-static.sh` | `5318dea61d7c22726cfc4f440d6c55c293f16395d6bab15f4f164c1eb1d87564` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/static-commands.log` | `504b23c2a3486d17ab8a0881abbdee4cbdfd8854510440303afcfbae7c62eb51` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/static-first-commands.log` | `2def550c16109b0e01bf0214432ad4a115f5245b3f43641f85942dc291271ab7` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/supplemental-input-map.json` | `afc650f6238159dd237a0ebee041dbb68fd10832ae1a63568660248c37e9443c` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/supplemental-manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/supplemental-task-input-manifest.json` | `0ffe688708f1417b8aa05d8cd4d2f25131a144e9595d09e6ec129c90f7f2cc38` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/syntax.log` | `1cac66f0eb3994f4c55be361f2a6926d144f84a12c5d263d2f7a8200f2aaefb7` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/task-delta.json` | `f84421996ee508dc1e76d9acefe7db62e679234a3d0b1cf62e2ba05b6fc5bb5c` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/task-delta.patch` | `27a8cc6b5e0a9d3fd24199be27d3b66f860060b4d87a928e05379e327f49ddc2` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/task-input-manifest.json` | `942285cb354d2cdea8048d181ae8f006eebff17b5b62a69f73048a62872c9b58` |
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/tool-versions.log` | `93b8fa60c1c0c8bdd44e2e6bb66abf8e7107b27fdc3978396c44a98df6dead11` |
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
| `specs/cloud-orchestration/verification/T-013/inputs/external/9/aws-cloudformation-2010-05-15.json` | `142ac136f30bf2ba93723536c67e66443b00d86cc2128448916d6d7ab145eec3` |
| `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-loop/scripts/resolve-project-context.py` | `edbcad8326293e6c83cf96d9e457c819ebef64c19a9a4090ccb0cdcbc7a62b56` |
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
| `tests/cloud-orchestration-contracts.tests.py` | `dcd2c5a89119d26be5c983ac54cd586b4b6742b7cdff48b30f55a1e1fdaceba4` |
| `tests/cloud-orchestration-execution.tests.py` | `3ded22c4377536bfa7925555935d4e14a614263674c1d3acf2a973570cb14703` |
| `tests/cloud-orchestration-routing.tests.py` | `d038f799960a234e433dcc4a845ddb7b19394f4a5880c7ed9dd0f7f7037b243a` |
| `tests/cloud-orchestration-verification.tests.py` | `a3bfad88d8bff274ac3acc925cfb885b570aa931606e1a8a9a8580f26153de60` |
| `tests/sdd-domain-multitarget-T-003.tests.py` | `ca48739d79ee0e54bf002db7946ee5f2aefe1ffbec65bb72a11f4e051a6e57ae` |
| `tests/shared-launch-python/pyproject.toml` | `8308097d7ca9084f9e3a02add4d78f96514cefa947c25bab3ed24a7b74393f12` |

## Test Evidence

- **Test Command**: bash specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/run-regressions.sh after; python3 -B specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/run-scoped.py tests/cloud-orchestration-verification.tests.py; bash specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/run-static.sh; python3 -B specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback.py
- **Test Result**: PASS
- **Test Evidence Path**: specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/commands.json

`Test Evidence Path` follows the same canonical repository-relative path rules
as output paths.

## Iteration And Escalation

- **Task Attempt Count**: 3
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Scratch Root**: /tmp/cloud-T010-01a14f7b-2c6f-7fd2-a9d1-dfb5c7efdc0c
- **Run ID**: 01a14f7b-2c6f-7fd2-a9d1-dfb5c7efdc0c
- **Session ID**: 01a14f7b-2c6f-7fd2-a9d1-dfb5c7efdc0c
- **Agent Instance ID**: 01a14f7b-2c6f-7fd2-a9d1-dfb5c7efdc0c
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

- Entry candidate: **311 passing tests**, no skips (106 verification, 86 execution, 86 routing, 33 contracts). This newly executed baseline does not relabel historical canonical evidence.
- Fixed candidate: **314 passing tests**, no skips (109 verification, 86 execution, 86 routing, 33 contracts). `after-commands.log` records actual commands/exits. `final-verification-command.log` additionally binds an exact-final-source repeat of all 109 verification tests after the test-only type annotation correction.
- Corrected committed Red: 3 tests, 24 behavioral subtest failures, zero errors; ten fresh callback controls pass. Focused Green: 3 tests / 52 scenarios pass. `red.log`, `green.log`, `red-ordering.json` and `commands.json` retain chronology; fixture-construction failures remain labeled separately.
- Configured Ruff/mypy pass on seven source/test/evidence-driver files using `tests/shared-launch-python/pyproject.toml` and explicit `MYPYPATH=plugins/sdd-quality-loop/scripts:plugins/sdd-azure-cloud/scripts:plugins/sdd-aws-cloud/scripts`. No suppressions added. Python compilation and Bash syntax checks pass.
- Each scoped main/CLI/rollback invocation exercises network-denial sentinels in parent, direct Python, shell and real PowerShell child. Installed local Bicep/CDK compilation/synthesis runs under the fixed toolchain environment; PowerShell uses the required workspace wrapper. No live cloud authorization, IAM or health proof.
- Corrected disposable rollback: detached entry commit plus exact dirty-input snapshots and declared unchanged test dependencies; entry and restored baseline each pass 106 verification + 86 execution + 33 contracts. Candidate focused tests pass; exact two-file restoration matches entry hashes; refined focused tests against restored production reproduce 24 failures; reapply matches candidate hashes and passes focused/execution/contracts checks. `rollback.json` records all command exits and hashes. First missing-API-model reconstruction failure is preserved under `rollback-first/`, not relabeled.

## Specification Differences

None. No specification/approval/task/traceability/ticket status edits or new schema/API/architecture. Existing exclusive whole-second authorization expiry conservatively excludes the inclusive predecessor freshness endpoint; it never extends the deadline by rounding up. Empty predecessor sets preserve existing expiry behavior, and stricter consumer/preview deadlines still win. No acceptance/policy exception or T009-only waiver is used.

The initial manifest remains immutable. The validator forbids input/output overlap, so `before/` snapshot paths bind the two editable initial files; `entry.json` maps them to canonical repository paths. Supplemental manifests bind unchanged local-policy/shared-script/API-model dependencies; all validators pass against preserved private scratch snapshots. `input-preservation.json` verifies all initial snapshots and every non-task input, including the canonical report and frozen specifications. spec_revision is the repository algorithm: SHA-256 of requirements.md + design.md + acceptance-tests.md bytes, in that order; the old canonical report's revision remains historical.

## Unresolved Items

No known remaining implementation work for this ticket. Root owns ticket resolution, task statuses, independent named review/quality gate, final whole-repository/CI checks in an isolated committed checkout, and release. Live TEST-003/005/009 remains blocked on owner-supplied OQ-001 prerequisites; no cloud action occurred. No new environment-SKIP branch was enabled. No UI/visual work applies. No Done or quality-gate PASS is claimed.

## Quality Gate Focus

Verify the minimum expiry reaches unmodified native guards after callback latency; confirm initial and final dependency acquisition, consumer metadata/binding/revocation, replay/journal retention and empty-set behavior remain intact. Distinguish synthetic deadline handoff from separate genuine acquisition logic over synthetic transports. Inspect corrected rollback sensitivity, exact source hashes and conservative endpoint precision. This is implementer evidence, not an independent verdict.

## Working Notes

Record conclusions from delegated investigations here. One entry per
delegation unit: purpose, result, and file paths examined.

No subagents, cloud actions, pushes, tags or merges. Caller-supplied native identity is recorded in identity.json; never derived from inherited environment. Ponytail full and applicable ECC coding/security/verification guidance applied, with fix-by-review-ticket/debugging policy. Only local Red commit `2c2caf3f` was created. It also captures previously dirty bytes of the explicitly task-owned verification file; only the added class is this repair's new Red. Product bytes were unchanged at that commit (red-ordering.json).

`diagnosis.md` records cause, callback paths, initial fixture mistakes, post-fix guard-observation correction, missing mypy annotation and first rollback dependency gap without rewriting historical outcomes. Private native event/stderr streams are excluded from Outputs; retained locally only, not reviewer evidence.

## WFI-001 Pre-Implementation Mismatch Preflight

Recorded before production edits. `red.log`: 3 tests, 24 behavioral subtest failures,
zero errors. Ten fresh controls successfully submit; twenty stale/exact-deadline
cases wrongly submit once; four receipt-minimum cases retain consumer TTL rather
than predecessor expiry. These are executed real final guards and native fixture
submission counters, not inferred coverage. Earlier red-setup/red-second/red-third
logs contain fixture mistakes and are NOT the qualifying Red.

| Persisted field / acceptance claim | Counterpart | Executed mismatched-input Red |
|---|---|---|
| authorization.expires_at | minimum admitted predecessor deadline, OIDC exp, provider lease, iat + policy TTL, apply preview.expires_at | DependencyCallbackExpiryCases.test_receipt_expiry_minimum_and_empty_predecessors: both providers/stages emit 06:01:50Z instead of synthetic predecessor 06:00:10Z. Policy/OIDC/provider/preview and real empty-set controls pass. |
| provider result/state; native submissions zero when stale (AC-006) | Azure prepare what-if / apply PUT final receipt expiry guard after validation and journal work | test_azure_callback_freshness_validation_and_journal: fresh through last shared dependency admission, elapsed 10/11 only inside callback; one write observed instead of zero, real expiry guard executes. |
| provider result/state; native submissions zero when stale (AC-006) | AWS publish / CreateChangeSet / ExecuteChangeSet receipt lease guard after authentication, readback and execute history | test_aws_callback_freshness_readback_history_and_authentication: same injected deadline, elapsed 10/11 in callback while consumer/preview valid; target write observed once instead of zero. Prior legitimate prepare writes are not miscounted as target execute writes. |
| authorization receipt and submission journal retention (existing invariant) | exclusive publication/replay markers retained on failed final send | All callback cases assert actual journal existence. Existing admission/execution replay/revocation suites retained; no journal schema or identity field changes. |

The deadline stub is explicitly synthetic admitted-predecessor data, not provenance.
Real acquisition/cross-provider tests remain separate and unchanged. No final
provider guard is replaced: the assertion observer records then invokes the actual
assertion. No cloud/network calls are authorized.

Diagnosis: WriteBoundary discards first admit_predecessors return; expires_at lacks
its freshness bound. The later check is before provider callback work. Both provider
callbacks already consume the published expires_at in their final guards. The minimal
fix is to cap the existing receipt expiry before immutable publication, retaining
both authenticated acquisitions and all last consumer checks. No new wire schema.


## Session Handoff

Populate this section before ending a session mid-task.

- **Current Status**: Implementation Complete
- **Next Action**: Root: independent scoped review/quality gate, ticket/status decisions and final isolated full-suite verification.
- **Unresolved Items**: Root-owned independent review/gate and live prerequisites only; no scope waiver.

`Current Status` is one of `In Progress`, `Implementation Complete`, or
`Blocked`. Only the independent quality gate may set a task to `Done`.
