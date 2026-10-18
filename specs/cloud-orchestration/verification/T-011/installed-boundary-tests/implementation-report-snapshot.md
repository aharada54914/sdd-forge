# Implementation Report: T-011

- Task ID: T-011
- Model: openai/gpt-6-astra
- Effort: high

Report Schema: implementation-report/v2
Run ID: 01a15032-0b50-7872-9dff-c10464e2bdfc
Task Attempt Count: 3
Input manifest: `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/task-input-manifest.json`, SHA-256 `39e8c0911defbfe6c30515dffa08896cd52dcb83f326ed0b533385e36a2d1847`

**Snapshot Notice**: The numbers, statuses, and paths recorded below reflect
the state at this report's own authoring run only. A later same-feature
event -- another task's edit to the same surface, or a gate-phase artifact
normalization such as a path move -- may supersede them. The quality
verification gate's own report is the authority for the gate-time state;
this report is not edited after the fact to reconcile it.

## Target

cloud-orchestration / RT-20261018-CLOUD-BOOTSTRAP-PATH-TESTS / REQ-011, REQ-012 / AC-011, AC-012. Tests-only repair under existing approval.

spec_revision: `950f3369d7d8e3933cc30a3f149a6e70d646c0e4f94b803da7b20bc9153f4e32` (eight raw specification files; spec-revision.json). Initial revision: `7180cc35f3258c1424a1bc1bc045cf5ffaf9d1b4`.

## Summary

Added direct installed-bootstrap path refusal coverage without changing production. Eight selected installed test methods pass; 44 added negative provider/path combinations have complete valid arguments and matched real/spy controls. Both relevant semantic mutants now fail before delegation. This is coverage repair of existing correct guards, not a production defect or retroactive original Red.

### Pre-implementation field/counterpart/mismatch checklist

| Persisted field / claim | Counterpart | Executable mismatch check |
|---|---|---|
| Installed root admission, exact exit 2, schema/error_code/field | cloud-routing.py run(), cloud-input-error.schema.json; AC-011/012 | sensitivity.py: physical-path-policy mutant removes both overlapping physical guards; selected suite must kill it through a no-delegation assertion |
| CLI and all four shared modules: regular physical files before delegation | cloud-routing.py runtime loop; installed provider runtime | sensitivity.py: runtime-presence mutant retains physical checks but removes is_file; selected suite must kill it before subprocess execution |
| No delegation, unchanged request bytes, no output/evidence | same complete arguments and matched installed route controls, approved no-write boundary | new installed cases spy at actual installed helper subprocess.run (positive control must call once); missing/linked files must never reach spy; exact bytes and workspace inventory unchanged |
| Model/run/session/agent/tier/cost/isolation and input hashes | launcher-supplied identity, manifest schema and preserved initial snapshot | preflight-mismatches.log: mutate task_id, isolation and input hash independently; existing validator must reject each |
| Output SHA-256, spec_revision, reported test exits/counts | actual files, eight raw spec files, actual unittest and verification receipt | sensitivity.py asserts control succeeds, zero errors (no setup/import Red), every mutant has semantic assertion failures; final output hash checker independently compares each row; rollback restores initial test bytes and reproduces sensitivity failure |

Preflight and real surviving-mutant baseline were committed as `b9478c93797f9172d667248e18e780c8c136dd3a` before test edits. `before-sensitivity.log` records caller exit 1 while all five prior selected tests pass against each mutant and production. No setup/import failure is cited as semantic Red. Physical root/runtime guards overlap; the physical mutant removes both overlapping guards, not just a redundant line. The separate presence mutant retains physical checks.

## Files Changed

- `tests/cloud-orchestration-routing.tests.py`: 133 added test/helper lines only.
- This new report and own `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/` evidence/scripts.
- No production, task status, ticket, frozen spec, old report, native trial, guard, mirror, catalog or CI edits.

## Tests Added Or Updated

- Both provider identities: relative, absent, non-directory, symlinked and ancestor-symlink plugin roots.
- Each of scripts/cloud.py and four runtime modules: missing, directory and symlink; CLI/runtime ancestor directory symlinks.
- Import the actual installed helper and instrument its subprocess.run. Valid control reaches the exact argv/env once. Every negative forbids delegation and asserts exit 2, cloud-input-error/v1, CLOUD_ROUTE_BLOCKED, field route; actual installed CLI also returns the same envelope. Request bytes remain unchanged; no output/evidence/new workspace entries.
- Stdlib only. Existing real provider parity and native preparation tests unchanged. Symlink-unavailable subcases explicitly skip; Windows provider refusal is distinct from the reached bootstrap spy.

## Outputs

Changed tests, stable evidence and unchanged runtime/installer/test dependencies. Listing does not imply production edits. The report itself and private launcher streams are excluded.

| Path | SHA-256 |
|---|---|
| `.agents/plugins/marketplace.json` | `dd4a8d5efb2d2f8eb5918897d9a499b4e532ec5654bab2fdd539500c5eaee36a` |
| `.claude-plugin/marketplace.json` | `dd935489bca5a357c90eec68081717e451c1d0b0b5f807f33b6ca8dd3b216155` |
| `.codex/agents/sdd-evaluator.toml` | `31411fad2ea5bbdd06c3f3d8276b9b3535bb21717877522143a2512be7ec188a` |
| `.codex/agents/sdd-investigator.toml` | `5a10183be5d4ba742d7c80d929ac1cdd59b4d32109c48c7615ea05e4b6d6886d` |
| `.codex/agents/sdd-panelist-gemini.toml` | `cee875549343d2bc6bc8bee29694ee67b1f481819ed0a6e10a1044893c0ab270` |
| `.codex/agents/sdd-panelist-gpt.toml` | `7dc97360df3e6656f065fa207dcd67f4ccbd5eabbc7c41e7011c1f59bf824816` |
| `.github/workflows/test.yml` | `48698cda10fa3d2ae083368fdc378f3def72271eeeb074f290fc63aad0f4d27a` |
| `CHANGELOG.md` | `eb5c357606bf289013f6859d772bc759959ca08fc3177a6af806f1ad17d281e5` |
| `README.md` | `55d86469cedc7f5fd7f5cf8b3aea1bee4a95806d79168182aee6ee2026e80e67` |
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
| `contracts/task-input-manifest.schema.json` | `22a756c64a7c720b761b31d71c9fbb62c390a9f18b201673443e962998781749` |
| `install.ps1` | `2014193f4e31a234b0336087d434ed12d0f8d7f73ff87bd8bb9744c158ac42a7` |
| `install.sh` | `7827514addc02f00cb671d7963b8d70c80327113ea1bae5fa694bb69306e6f3d` |
| `mcp/sdd-forge-mcp/package-lock.json` | `2073331df48c2e05d7547aee4bde63a291c3940c5ece5bbb363a186b127c1608` |
| `mcp/sdd-forge-mcp/package.json` | `fdb9147028ded12a7470dcbb989390d669566f0f976151ecc5bc331311e07361` |
| `plugins/sdd-aws-cloud/.claude-plugin/plugin.json` | `901affde1f22fd7f03420455ad247b89e6104a090940113e0d49b9024229642c` |
| `plugins/sdd-aws-cloud/.codex-plugin/plugin.json` | `fbaee91e13ec9a1fb202d9505c27e519f09655cce0fcb1ab266c85a1057aebec` |
| `plugins/sdd-aws-cloud/.plugin/plugin.json` | `2cef9f5155320fb1164da6264f47b50c71800dd95663cfbc7bc53cda6e6e2773` |
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
| `plugins/sdd-aws-cloud/scripts/governed-setup.md` | `2bd8c9b4ddcd7d9879a5b58d1e7c30d4d9c8c0286501b6b4d066eaf967712578` |
| `plugins/sdd-aws-cloud/skills/orchestrate/SKILL.md` | `27af791f755d21eefbf817dfa7e9b11b88fac34b075dbc3f413c1f20a163845a` |
| `plugins/sdd-azure-cloud/.claude-plugin/plugin.json` | `53b2dc69739b8035499407c40318599557e6773bc0d64c2e627521f602e2bec3` |
| `plugins/sdd-azure-cloud/.codex-plugin/plugin.json` | `72994a2916deec39493318312a22b21a7e81a643577fdc9f70e595d41c0c3b07` |
| `plugins/sdd-azure-cloud/.plugin/plugin.json` | `b8a3c04ec499f65f81494958067cf946c719f506e71464e56e4c92d015fe4c14` |
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
| `plugins/sdd-azure-cloud/scripts/governed-setup.md` | `b2f038ab953175e2fab863d5cc8baada77a79c0b8cef1281df68142831343388` |
| `plugins/sdd-azure-cloud/skills/orchestrate/SKILL.md` | `5a906f317b352c84f1b38f39464f585ce66f2261651079a6c79df528a6c774e2` |
| `plugins/sdd-bootstrap/.claude-plugin/plugin.json` | `8a8bffda62ca60cbcd995a61895b661fb9092ed9bdddaa0816c767a583fe9b21` |
| `plugins/sdd-bootstrap/.codex-plugin/plugin.json` | `eab6d07fd3af9c1515ad1319af3d0f5675c9631060d9ae27a58439f06db0c474` |
| `plugins/sdd-bootstrap/.plugin/plugin.json` | `06332645cba0d780f671f9df1f03bbc281f0ff387950395ab926f37822e21e12` |
| `plugins/sdd-bootstrap/scripts/cloud-routing.py` | `2d20361ae77a726118b9cc565cf9c0bdb720346b5d8507c5e820fc8a7a80d11b` |
| `plugins/sdd-domain/.claude-plugin/plugin.json` | `c2e9846fca5fedd8357bc1cbf9bfd8c8ce3e2ee9e6cbc6c45a9a478c630a67f8` |
| `plugins/sdd-domain/.codex-plugin/plugin.json` | `a84504f1dd31b8554d5faa64b82e165ca4608d207ecfe28a369c4ac2c11e1729` |
| `plugins/sdd-domain/.plugin/plugin.json` | `e7ccb1b18c512710bb955336e3aeebd077dc9e20f95870156ab3e01faf768d2d` |
| `plugins/sdd-implementation/.claude-plugin/plugin.json` | `82a292a165f42ff82df185cdbc343d41537bc0a29d4d9f8bcded2d6beafdeb77` |
| `plugins/sdd-implementation/.codex-plugin/plugin.json` | `6c5e68a63928e967b15eb795d5835d6b3e10d291a4402048a5bc2054f7e2a546` |
| `plugins/sdd-implementation/.plugin/plugin.json` | `fc13bdbe1b6513c06015d8f72b949e8729d0fcb5044827d15ed231fc5f138e6c` |
| `plugins/sdd-implementation/scripts/validate-implementation-report.sh` | `430e0e45c6bb417cd65f7f7f228bb59280d6d0817c8b34236223b8fbd4702029` |
| `plugins/sdd-implementation/scripts/validate-task-input-manifest.sh` | `5e209d11c50b9c580572adedee0c500fcc48233c1cafe5d22d08318c52059f73` |
| `plugins/sdd-lite/.claude-plugin/plugin.json` | `5ae17da3db2d23496a20fb188c7253d66e2fd2cc3719b9300845043bf3593749` |
| `plugins/sdd-lite/.codex-plugin/plugin.json` | `4a7c37d3a1b44bfeafd34b0bea2c4ea863e9ea73e979bddcc7cfbf4fedca17fd` |
| `plugins/sdd-lite/.plugin/plugin.json` | `a4fddd29ed226d93d528729b3d439c1f27fcda8f745c68dcd4a78f4856789071` |
| `plugins/sdd-quality-loop/.claude-plugin/plugin.json` | `132ffb6eb6e23f1a4d772f76065ecd9cb299370e0ed4bc4bb9d38ae3d8ba66b9` |
| `plugins/sdd-quality-loop/.codex-plugin/plugin.json` | `d957210bf8057abae2ad16472e1d6c36a46ceccd3a4ee2a4133f0126dd60d011` |
| `plugins/sdd-quality-loop/.plugin/plugin.json` | `ae3dc271a5b56f88efb97949f6e2d66cfc906b3e5813bf1bcec9597e863ec099` |
| `plugins/sdd-quality-loop/contracts/selected-verification-plan-v2.schema.json` | `cddae6fd212bf40a10fa86a27f171f0342b578f7a651bc276448f7134f4e8fe5` |
| `plugins/sdd-quality-loop/contracts/verification-contract-v3.schema.json` | `c52f8795c274ea8dc8c3a54f2e6b0d55ca9a8f49164200065fff51e3d710345a` |
| `plugins/sdd-quality-loop/references/cloud-verification-registry.json` | `de0153f09def1b805818f9bef1ddea065a30d3fee95e12f026bdaec40720d06d` |
| `plugins/sdd-quality-loop/scripts/cloud_authorization.py` | `17f5ffd041fe2d32657452093c76f4eda87b37fc5bf5d8504a1c6352eaac9658` |
| `plugins/sdd-quality-loop/scripts/cloud_contracts.py` | `c11225de15d8944a4183085b3df98f7b4da2d87227c473ad4eedde377b51164d` |
| `plugins/sdd-quality-loop/scripts/cloud_dependencies.py` | `7974e7e9a8d7da0c60b219a58db54c4747f0250653fda3af0146091f1f4fb475` |
| `plugins/sdd-quality-loop/scripts/cloud_verification.py` | `b2488aa48d32716b270fd920fbf4b13f43cf19440e975b48721d91e38de62a68` |
| `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` | `d19f258b904dd168410f184f7854d47a3790319832b5bda919b3f7049ab41a06` |
| `plugins/sdd-review-loop/.claude-plugin/plugin.json` | `044d03a31bb19b077b607f1473aa6bdb456fd5993169a8389ecf587006941f03` |
| `plugins/sdd-review-loop/.codex-plugin/plugin.json` | `5cf0d64e677030216ecec03c012446318d69426af159f663aa62befd12154517` |
| `plugins/sdd-review-loop/.plugin/plugin.json` | `e6573a4ebb23fed3a4456e4467e9cb1a3bdc63e0aaf5cef769136a4a82543470` |
| `plugins/sdd-ship/.claude-plugin/plugin.json` | `be1c1dfe8cba928db9073c1c6ee2cee85aa76b7c0711a30b365054113adf9499` |
| `plugins/sdd-ship/.codex-plugin/plugin.json` | `b3454c5c54fb5cf00f2f7e6422ed2af44b549d73d00314a63578242b34bcb327` |
| `plugins/sdd-ship/.plugin/plugin.json` | `44a3d211bf3112bd4431fc32d5b900b8aee6524eed6d3eb2cd1efa03a869aff6` |
| `specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream/LICENSE` | `8a5d8efb70942e65032f930c761d097feeb41a7517ebd04c9d2e4ec3764071c5` |
| `specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream/reference.md` | `a4976e733b7793b0014b3be1d5a1c5282002ba16dd7be9a7fffd509c800b5505` |
| `specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream/skills/azure-compute/workflows/vm-creator/examples/bicep/README.md` | `61a52989ee67dfe4ee30aeb88a06bd15460d3d61d9f1101f3d0d58c19d1e4852` |
| `specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream/skills/azure-compute/workflows/vm-creator/examples/bicep/main.bicep` | `6fa0bd982a36436cc4a6929ce5a8bb2fff748248d2865000110de0a18ef51b5f` |
| `specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream/skills/azure-compute/workflows/vm-creator/references/output-adapters/bicep.md` | `ab54837a3cde78093ebb59875c0cb1f471c57ee786d8b7d417f808cf94b56439` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/after-sensitivity.log` | `0da90bc401c18f31a342a209a6db21bc82bf59ab188f30b6a02d762c021a83bf` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/after/control.log` | `1dca38ac96685887670dba8c02c56216eb0892063a8a1ca7c2cd1dc5e62b993e` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/after/physical-path-policy.log` | `a4cdf11f027a1a5e3696a33b57c95bb951b53b91aa1ba49a50cbfc3093d136e9` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/after/results.json` | `774c4637df27977cc79264d751c4746419d698cb6a405e45549f9b73f92cdc2a` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/after/runtime-presence.log` | `0ee1194068ac345acc97cfa3606b2671da03ff233919cf6537b02ea7bf406779` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/baseline-routing.py.txt` | `2ea10b036fcfe019f045b7912b15c11abf2975f61424f055b44822bc59fbf971` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/before-sensitivity.log` | `a4187a498d9c916a422fc1a92310c2d60f24e6cc86fefb21e634f95b3f057d64` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/before/control.log` | `0b2d3179229c7ec620debe44507237704b2c7123686b8fc68041faf9c9c24277` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/before/physical-path-policy.log` | `9f0cfb84d10c277678f53bfd0ff83a6a5997b09c150aa81be5d287bdbe328d22` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/before/results.json` | `f8828d89d621c0ceb9c1f85276deb26118bfcd12cb87ff1aa89d53e25046eb8b` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/before/runtime-presence.log` | `f7b76bc86d170b40c234ed3c07e009d21e5f7dc19f2147afc7c88ec79b257349` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/commands-and-limits.md` | `1858d2ac357d441c2fc12c08c4babdef2aeec1831c2db5531b72daa46a397974` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/initial-state.json` | `31b409cf13679872eeb74c80922a271ffb83d452e2d88d0f7d7e854e14798dd2` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/input-origins.json` | `f88cc6bef1d4f3bda7ba401de3a31bf2a11f905ca328faf7b512353a861771a3` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/manifest-final-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/mypy.log` | `14aba5bb92aee07d9d4e159614da813c80a3e0f5e7b0276431b587e6fa88318e` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/outputs-validation.log` | `43fc58bb850ac2f1f79c8d5661fba89976f705d871094c55a96873f73329e541` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/preflight-mismatches.log` | `3a880b5c4e92004701ea88fd97c6947a2630620c8b1ac7309a98b2f721c40c36` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/preflight.md` | `05ab89b7aa8b8ff5b5bb88b824fa5ca87df9c2bcd4ee99977fdcd2b96bf937c5` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/preservation.json` | `10d299577b8e2b42f485dcee3260c8d3f80d1fd8333c6fccddd7690820999422` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/report-validation.log` | `a0eb36646f9654b7ef1b674fed63ad247a1febe005869fbf36ce295f5437a10c` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/rollback.log` | `bcb56adde0907ab9e537010d66cc35dfb818d167d66f1b5fd53a3471243fc7a2` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/rollback.py` | `111e02bfb6849bdad9aa85adf92c8812bdf7a7e50ba565150a40082266194965` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/rollback/reapplied.log` | `774c4637df27977cc79264d751c4746419d698cb6a405e45549f9b73f92cdc2a` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/rollback/reapplied/control.log` | `75236a12b65025e367654b21afeabf88ce06c67642749062190abd497d1ec94b` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/rollback/reapplied/physical-path-policy.log` | `414fa0c36b549c00f909de7ef1b1474d3723b79100ba0e3d75ee79b1795238ee` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/rollback/reapplied/results.json` | `774c4637df27977cc79264d751c4746419d698cb6a405e45549f9b73f92cdc2a` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/rollback/reapplied/runtime-presence.log` | `7c3c381a76669564d8da2976d3284436e8aef346e356a0daada08b073344c76a` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/rollback/restored.log` | `c79c9061fc598af9ec11ec1e86e157404f356576056234d731381feba39a9184` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/rollback/restored/control.log` | `653081a0bb3958bd90396d7c51c09cc36a4e6b1bb82cef0fea13ea7074898eee` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/rollback/restored/physical-path-policy.log` | `b5297eb28d683a7c236c6f6b9f1a59e4da0e2e4ed49d3b5e8abd60e5be095a05` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/rollback/restored/results.json` | `f8828d89d621c0ceb9c1f85276deb26118bfcd12cb87ff1aa89d53e25046eb8b` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/rollback/restored/runtime-presence.log` | `f4326afa9a4e3eb19cb102fefecad6578409f48cbc36d7c72a71d1b34b95840f` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/rollback/rollback.json` | `dfc6c211a3cac52e6c3006db99c4e8821c1918db86e7d6505c7c87e52a54f9a2` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/routing-receipt.json` | `18edc17f73da900467edcc58c658b63fe88b89e4d3fa8c528615f288d4816b9d` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/routing.log` | `f7a2d4c815c5089dec494aceff46598c99d2371fbe1c2b448d7b7892902fb5ec` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/ruff.log` | `5adc759da3879ebc92d8ae1078ec72662b99055efb0db04b36f6b259bafa97f8` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/sensitivity.py` | `adde06fa0365844c7de335c9bcf0c4b022d16ffdb319bb11b42195b3f5357ab4` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/spec-revision.json` | `8028f8748d8635ee2931e9baa8018e057021cca193595b9c3e4ed92418ab3367` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/targeted-installed.log` | `19dca4d35413fc39f5544d1a9a37013c0d0f27a1bb0840b235cd59c33e76f4d4` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/task-input-manifest.json` | `39e8c0911defbfe6c30515dffa08896cd52dcb83f326ed0b533385e36a2d1847` |
| `specs/cloud-orchestration/verification/T-011/installed-boundary-tests/toolchain.json` | `128788f1c2469e6749fc42963e2bd732e36f3dd852f757c90efc1db43be3c5a8` |
| `tests/cloud-orchestration-routing.tests.py` | `b96a66910c6af9f648c79635e300b814529c24cd26b78e9c3261ebcd68f7d263` |
| `tests/install-cloud.tests.py` | `7885c0d30108a2a67d0d3454f40553376acb4f5a22950158960b7958f889b7b5` |
| `tests/shared-launch-python/pyproject.toml` | `8308097d7ca9084f9e3a02add4d78f96514cefa947c25bab3ed24a7b74393f12` |
| `tests/validate-repository.ps1` | `15d9932d0d6cbcc9f3244ffca09c74360c511c3aec81679cc61bf35d9c339d6f` |
| `tests/verification-catalog.json` | `74f67b89251c2b55c324e6b7e19f6923d2c0a53b871431f162949964f4e11d80` |
| `tests/verification-timings.json` | `dc20362834826bd087a00b42243d4436a8266e67d7616346fcde3649952a33fd` |
| `tests/verification-workflow.py` | `eb6b9185f7b70be56ca91a834eaa9ac3371be20c385450bf0ab0d0c33986d6b9` |
| `tests/verification.py` | `c77fb7ccb2942afae49d747328462e174e03a7479ac05322608990c6bf1daaf1` |
| `uninstall.ps1` | `b6deb1791e5509aeb538215f944c19d03913baa4e3f771cc93fdc1f45763baa7` |
| `uninstall.sh` | `6d038c1208abd9c66da3d4a9188286bf76d0eb601b9ace5f5db25081472c373f` |

## Test Evidence

- **Test Command**: `source /tmp/cloud-native-test-env.sh; python3 -B tests/verification.py --suite tests/cloud-orchestration-routing.tests.py --run --receipt specs/cloud-orchestration/verification/T-011/installed-boundary-tests/routing-receipt.json`
- **Test Result**: PASS
- **Test Evidence Path**: specs/cloud-orchestration/verification/T-011/installed-boundary-tests/routing-receipt.json

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

- **Scratch Root**: /tmp/cloud-T011-installed-01a15032
- **Run ID**: 01a15032-0b50-7872-9dff-c10464e2bdfc
- **Session ID**: 01a15032-0b50-7872-9dff-c10464e2bdfc
- **Agent Instance ID**: 01a15032-0b50-7872-9dff-c10464e2bdfc
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

Registered routing: **96 methods PASS, no skips**, actual pinned Bicep 0.48.1/CDK 2.1145.0/Node 24.19.0; no cloud execution. Targeted BootstrapInstalled: **8 methods PASS**. After sensitivity: production healthy; physical policy and runtime presence each cause **20 semantic assertion failures, zero errors**, caller exits 0. Existing catalog/native-cell checks ran inside routing; wiring unchanged. Configured Ruff and mypy pass all three changed Python files with explicit shared MYPYPATH, no suppressions. Commands, exits and tool identities: commands-and-limits.md/toolchain.json.

Rollback in a disposable committed worktree restores original test hash `2ea10b036fcfe019f045b7912b15c11abf2975f61424f055b44822bc59fbf971` (rollback/rollback.json); baseline healthy suite passes and both mutants survive (caller exit 1). Reapplying tests restores healthy production and mutant kills (caller exit 0). Each installed mutation is restored and its fixture removed; checkout removed. No production behavior rollback or root-source temporary mutation occurred.

Receipt is honestly dirty/non-reusable; final full-suite exact committed checkout remains root-owned. Prior all-six/guard/native2 results are frozen prior evidence, not rerun or relabeled here.

## Specification Differences

None. Tests assert the current public boundary. Missing/non-directory roots reject through manifest I/O; no invented explicit root guard. No new authority, architecture, CLI contract, T009 exception or approval.

## Unresolved Items

Native Windows/macOS and junction execution await actual T008 CI. Linux symlink coverage does not prove those hosts. Live TEST-003/005/009 remain BLOCKED by OQ-001. Root owns full-suite committed verification, independent cycle2, ticket closure, statuses and release. No Done or gate PASS claimed.

## Quality Gate Focus

Verify 44 matched negative combinations, actual installed helper spy and subprocess CLI, semantic mutant failures versus setup errors, baseline-before-edit commit, output/manifest hashes and coverage-only rollback. No new independent review performed by this implementation context.

## Working Notes

Record conclusions from delegated investigations here. One entry per
delegation unit: purpose, result, and file paths examined.

No subagents. Used local Ponytail full, ECC coding/security/verification and applicable pstack blast-radius/behavior guidance. Reused installer/lifecycle fixture and stdlib; no new global framework. Preservation check compared 14,661 initially tracked files other than the selected test: unchanged. Canonical report remains SHA-256 `2956e2e48c00cfcb8b7e5380362ae9df7f6627bfa086ad9b987f869931c765ea`; prior repair report remains `2b99d5745ae2bd9ffe22799a6195364bd6ee9b1eed8cdd5eacdab554bdedf998`. Private native event/stderr streams, raw independent reviewer outputs and unrelated mirror bodies are excluded. No UI verification applies.

## Session Handoff

Populate this section before ending a session mid-task.

- **Current Status**: Implementation Complete
- **Next Action**: Root: independent cycle2 and final isolated committed verification; decide task/ticket state.
- **Unresolved Items**: Native OS CI, live prerequisites and root-owned independent/release checks above.

`Current Status` is one of `In Progress`, `Implementation Complete`, or
`Blocked`. Only the independent quality gate may set a task to `Done`.
